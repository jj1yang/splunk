"""Run: python3 -m unittest -v test_scp_multi.py

All external commands are mocked on an isolated PATH. No server is contacted,
no real credentials are used, and fixtures are removed after each test.
These tests verify orchestration/arguments, not OpenSSH or SFTP behavior.
"""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest
import uuid


SCRIPT = Path(__file__).resolve().with_name("scp-multi.sh")
BASH = os.environ.get("BASH_UNDER_TEST") or shutil.which("bash")

MOCK = r'''
import json
import os
from pathlib import Path
import signal
import sys

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps([tool, args]) + "\n")
if tool == "sshpass":
    if args[0] != "-e" or not os.environ.get("SSHPASS"):
        sys.exit(90)
    os.execv(str(Path(sys.argv[0]).with_name(args[1])), args[1:])
if os.environ.get("MOCK_SIGNAL") and tool in ("ssh", "rsync"):
    os.kill(os.getppid(), int(os.environ["MOCK_SIGNAL"]))
    sys.exit(1)
target = args[-2] if tool == "ssh" else args[-1]
host = target.split("@", 1)[1].split(":", 1)[0]
failures = json.loads(os.environ.get("MOCK_FAILURES", "{}"))
sys.exit(failures.get(tool + ":" + host, 0))
'''


@unittest.skipUnless(BASH, "Bash is required")
class ScpMultiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="scp-multi-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.jsonl"
        for tool in ("sshpass", "ssh", "scp"):
            executable = self.bin / tool
            executable.write_text("#!" + sys.executable + "\n" + MOCK)
            executable.chmod(0o700)
        self.file = self.root / "file with spaces (1).txt"
        self.file.write_text("fixture\n")
        self.directory = self.root / "folder"
        (self.directory / "nested").mkdir(parents=True)
        (self.directory / "nested" / ".hidden").write_text("fixture\n")
        self.env = os.environ.copy()
        # Random synthetic credential; never print or log its value.
        self.env.update(
            PATH=str(self.bin),
            SSHPASS=uuid.uuid4().hex,
            MOCK_LOG=str(self.log),
        )
        for key in ("MOCK_FAILURES", "MOCK_SIGNAL"):
            self.env.pop(key, None)

    def run_script(self, *args, sources=None, env=None):
        if sources is None:
            sources = [self.file, self.directory]
        return subprocess.run(
            [
                BASH, str(SCRIPT),
                "--servers", "one.example,two.example",
                "--user", "tester",
                *map(str, args),
                "--", *map(str, sources),
            ],
            cwd=self.root,
            env=self.env if env is None else env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def calls(self, tool=None):
        entries = (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists() else []
        )
        return [args for name, args in entries if tool is None or name == tool]

    def assert_error(self, result, message):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)
        self.assertEqual(self.calls(), [])

    def test_syntax(self):
        result = subprocess.run([BASH, "-n", str(SCRIPT)], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_help_without_dependencies_or_sources(self):
        self.env["PATH"] = "/nonexistent"
        self.env.pop("SSHPASS")
        result = self.run_script("--help", sources=[self.root / "missing"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"Usage: {SCRIPT}", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_preview_is_offline_and_needs_no_dependencies(self):
        self.env["PATH"] = "/nonexistent"
        self.env.pop("SSHPASS")
        result = self.run_script("-n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("local validation only", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_multiple_sources_and_hosts(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Succeeded: 2  Failed: 0", result.stdout)
        self.assertEqual(len(self.calls("ssh")), 2)
        copies = self.calls("scp")
        self.assertEqual(len(copies), 2)
        for args, host in zip(copies, ("one.example", "two.example")):
            self.assertEqual(
                args[args.index("--") + 1:],
                [str(self.file), str(self.directory), f"tester@{host}:./"],
            )
            for option in ("-r", "-p", "StrictHostKeyChecking=no",
                           "UserKnownHostsFile=/dev/null",
                           "ConnectionAttempts=1", "NumberOfPasswordPrompts=1",
                           "ServerAliveInterval=15", "ServerAliveCountMax=3"):
                self.assertIn(option, args)
        for args in self.calls("ssh"):
            self.assertIn("StrictHostKeyChecking=no", args)
            self.assertIn("UserKnownHostsFile=/dev/null", args)
        for args in self.calls("sshpass"):
            self.assertEqual(args[0], "-e")
            self.assertNotIn(self.env["SSHPASS"], args)
        self.assertNotIn(self.env["SSHPASS"], result.stdout + result.stderr)
        self.assertNotIn(self.env["SSHPASS"], self.log.read_text())

    def test_destination_and_numeric_options(self):
        result = self.run_script(
            "--destination", "/opt/uploads/", "--port", "02222",
            "--connect-timeout", "00009",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        for args in self.calls("scp"):
            self.assertEqual(args[args.index("-P") + 1], "2222")
            self.assertIn("ConnectTimeout=9", args)
            self.assertTrue(args[-1].endswith(":/opt/uploads/"))
        for args in self.calls("ssh"):
            self.assertEqual(args[args.index("-p") + 1], "2222")
            self.assertIn("test -d '/opt/uploads/'", args[-1])
            self.assertIn("test -w ", args[-1])
            self.assertIn("test -x ", args[-1])

    def test_root_destination(self):
        result = self.run_script("--destination", "/")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(args[-1].endswith(":/") for args in self.calls("scp")))

    def test_relative_and_dash_prefixed_sources(self):
        source = self.root / "-report:2026.txt"
        source.write_text("fixture")
        result = self.run_script(sources=[source.name, "folder/"])
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.calls("scp")[0]
        self.assertEqual(args[args.index("--") + 1:-1],
                         [str(source), str(self.directory)])

    def test_dot_and_parent_path_normalization(self):
        result = self.run_script(sources=["folder/.././" + self.file.name])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls("scp")[0][-2], str(self.file))

    def test_root_alias_rejected(self):
        self.assert_error(self.run_script(sources=["/tmp/.."]), "filesystem root")

    def test_empty_directory(self):
        empty = self.root / "empty"
        empty.mkdir()
        result = self.run_script(sources=[empty])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls("scp")[0][-2], str(empty))

    def test_newline_and_glob_characters_in_filename(self):
        source = self.root / "literal[*]\nname.txt"
        source.write_text("fixture")
        result = self.run_script(sources=[source])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls("scp")[0][-2], str(source))

    def test_newline_host_rejected_before_bash_read(self):
        self.assert_error(self.run_script("--servers", "one.example\nignored"),
                          "Invalid server list")

    def test_scp_failure_continues(self):
        self.env["MOCK_FAILURES"] = json.dumps({"scp:one.example": 1})
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.calls("scp")), 2)
        self.assertIn("Succeeded: 1  Failed: 1", result.stdout)
        self.assertIn("FAILED: one.example (exit 1)", result.stdout)
        self.assertIn("Partial files may remain", result.stderr)

    def test_preflight_failure_skips_copy_and_continues(self):
        # Covers SSH connectivity/host-key errors and sshpass auth/key codes.
        for code in (1, 5, 6, 7, 255):
            with self.subTest(code=code):
                self.log.unlink(missing_ok=True)
                self.env["MOCK_FAILURES"] = json.dumps({"ssh:one.example": code})
                result = self.run_script()
                self.assertEqual(result.returncode, 1)
                self.assertEqual(len(self.calls("ssh")), 2)
                self.assertEqual(len(self.calls("scp")), 1)
                self.assertIn("two.example:", self.calls("scp")[0][-1])
                self.assertIn(f"FAILED: one.example (exit {code})", result.stdout)

    def test_all_servers_fail(self):
        self.env["MOCK_FAILURES"] = json.dumps(
            {"scp:one.example": 1, "scp:two.example": 255})
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Succeeded: 0  Failed: 2", result.stdout)

    def test_invalid_hosts(self):
        for value in ("", ",one", "one,", "one,,two", "one, two",
                      "-option", "user@host", "host;id", "::1", "one,one"):
            with self.subTest(value=value):
                self.assert_error(self.run_script("--servers", value), "ERROR:")

    def test_invalid_users(self):
        for value in ("", "-option", "user name", "user;id", "user@host"):
            with self.subTest(value=value):
                self.assert_error(self.run_script("--user", value), "ERROR:")

    def test_invalid_destinations(self):
        for value in ("relative", "/has space", "/tmp/'", "/tmp;id", "~/folder"):
            with self.subTest(value=value):
                self.assert_error(self.run_script("--destination", value),
                                  "Destination must")

    def test_invalid_numbers(self):
        for flag, values in (
            ("--port", ("0", "-1", "65536", "abc", "99999999999999999999")),
            ("--connect-timeout", ("0", "-1", "86401", "1.5", "abc")),
        ):
            for value in values:
                with self.subTest(flag=flag, value=value):
                    self.assert_error(self.run_script(flag, value), "ERROR:")

    def test_unknown_option(self):
        self.assert_error(self.run_script("--bogus"), "Unknown option")

    def test_missing_option_value(self):
        result = subprocess.run(
            [BASH, str(SCRIPT), "--servers"], env=self.env,
            capture_output=True, text=True, timeout=10,
        )
        self.assert_error(result, "Missing value")

    def test_missing_empty_and_root_sources(self):
        for source in (self.root / "missing", "", "/"):
            with self.subTest(source=str(source)):
                self.assert_error(self.run_script(sources=[source]), "ERROR:")

    def test_duplicate_source_names(self):
        other = self.root / "other"
        other.mkdir()
        duplicate = other / self.file.name
        duplicate.write_text("fixture")
        self.assert_error(self.run_script(sources=[self.file, duplicate]),
                          "same destination name")

    def test_symlink_source_and_trailing_slash(self):
        link = self.root / "link"
        link.symlink_to(self.directory, target_is_directory=True)
        for source in (link, str(link) + "/"):
            with self.subTest(source=str(source)):
                self.assert_error(self.run_script(sources=[source]), "Symlinks")

    def test_nested_hidden_symlink_and_cycle(self):
        link = self.directory / "nested" / ".link"
        link.symlink_to(self.directory, target_is_directory=True)
        self.assert_error(self.run_script(), "Symlinks")

    def test_broken_symlink(self):
        link = self.directory / ".broken"
        link.symlink_to(self.root / "missing")
        self.assert_error(self.run_script(), "Symlinks")

    def test_special_file(self):
        fifo = self.directory / "pipe"
        os.mkfifo(fifo)
        self.assert_error(self.run_script(), "unsupported special file")

    @unittest.skipIf(hasattr(os, "geteuid") and os.geteuid() == 0,
                     "root can read permission-restricted fixtures")
    def test_unreadable_entries(self):
        self.file.chmod(0)
        self.addCleanup(self.file.chmod, 0o600)
        self.assert_error(self.run_script(), "Unreadable file")

    @unittest.skipIf(hasattr(os, "geteuid") and os.geteuid() == 0,
                     "root can traverse permission-restricted fixtures")
    def test_unsearchable_directory(self):
        self.directory.chmod(0o600)
        self.addCleanup(self.directory.chmod, 0o700)
        self.assert_error(self.run_script(), "Unreadable directory")

    def test_missing_dependencies(self):
        for tool in ("sshpass", "ssh", "scp"):
            with self.subTest(tool=tool):
                executable = self.bin / tool
                saved = executable.read_bytes()
                executable.unlink()
                try:
                    self.assert_error(self.run_script(), f"Missing dependency: {tool}")
                finally:
                    executable.write_bytes(saved)
                    executable.chmod(0o700)

    def test_noninteractive_missing_password(self):
        self.env.pop("SSHPASS")
        self.assert_error(self.run_script(), "No interactive terminal")

    def test_signal_exit_status(self):
        for signum, expected in ((signal.SIGINT, 130), (signal.SIGTERM, 143)):
            with self.subTest(signum=signum):
                self.env["MOCK_SIGNAL"] = str(int(signum))
                result = self.run_script()
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertNotIn("Transfer summary", result.stdout)


if __name__ == "__main__":
    unittest.main()
