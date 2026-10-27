"""Mocked Bash rsync tests; no network or real credentials.

Run: python3 -m unittest -v test_scp_multi test_rsync_multi
Set BASH_UNDER_TEST to an absolute Bash executable to test another version.
"""

import json
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import unittest

import test_scp_multi as fixtures


SCRIPT = Path(__file__).resolve().with_name("rsync-multi.sh")


@unittest.skipUnless(fixtures.BASH, "Bash is required")
class RsyncMultiTests(unittest.TestCase):
    calls = fixtures.ScpMultiTests.calls
    assert_error = fixtures.ScpMultiTests.assert_error

    def setUp(self):
        fixtures.ScpMultiTests.setUp(self)
        executable = self.bin / "rsync"
        executable.write_text("#!" + sys.executable + "\n" + fixtures.MOCK)
        executable.chmod(0o700)
        self.config = {
            "servers": "one.example,two.example",
            "username": "tester",
            "source_dir": str(self.file),
            "destination": "~",
            "transfer_timeout": "120",
        }
        self.script = self.root / "rsync-under-test.sh"

    def run_script(self, *args):
        # Patch only a temporary copy of the edit-in-script configuration.
        text = SCRIPT.read_text()
        for key, value in self.config.items():
            text, count = re.subn(
                "^" + key + "=.*$", lambda _: key + "=" + shlex.quote(value),
                text, count=1, flags=re.MULTILINE,
            )
            self.assertEqual(count, 1)
        self.script.write_text(text)
        return subprocess.run(
            [fixtures.BASH, str(self.script), *args],
            cwd=self.root, env=self.env, stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=10,
        )

    def test_syntax(self):
        result = subprocess.run(
            [fixtures.BASH, "-n", str(SCRIPT)], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_help_without_dependencies(self):
        self.env["PATH"] = "/nonexistent"
        self.env.pop("SSHPASS")
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Usage:", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_multi_host_transfer(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Succeeded:   2", result.stdout)
        self.assertIn("Failed:      0", result.stdout)
        copies = self.calls("rsync")
        self.assertEqual(len(copies), 2)
        for args, host in zip(copies, ("one.example", "two.example")):
            self.assertEqual(args[-2:], [str(self.file), f"tester@{host}:./"])
            for option in ("-az", "--partial", "--progress", "--timeout=120"):
                self.assertIn(option, args)
            ssh_command = args[args.index("-e") + 1]
            self.assertIn("StrictHostKeyChecking=no", ssh_command)
            self.assertIn("UserKnownHostsFile=/dev/null", ssh_command)
            self.assertNotIn("--delete", args)
        self.assertNotIn(self.env["SSHPASS"], result.stdout + result.stderr)
        self.assertNotIn(self.env["SSHPASS"], self.log.read_text())

    def test_dry_run_still_calls_rsync(self):
        result = self.run_script("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls("rsync")), 2)
        for args in self.calls("rsync"):
            self.assertIn("--dry-run", args)
            self.assertIn("--itemize-changes", args)
        self.assertIn("All dry runs completed", result.stdout)

    def test_directory_and_absolute_destination(self):
        self.config.update(source_dir=str(self.directory) + "/",
                           destination="/backup/", transfer_timeout="00009")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        for args in self.calls("rsync"):
            self.assertEqual(args[-2], str(self.directory))
            self.assertTrue(args[-1].endswith(":/backup/"))
            self.assertIn("--timeout=9", args)

    def test_failure_continues_and_reports_first_index(self):
        self.env["MOCK_FAILURES"] = json.dumps({"rsync:one.example": 23})
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.calls("rsync")), 2)
        self.assertIn("Succeeded:   1", result.stdout)
        self.assertIn("one.example — exit 23", result.stdout)

    def test_all_failures_reported(self):
        self.env["MOCK_FAILURES"] = json.dumps(
            {"rsync:one.example": 23, "rsync:two.example": 255})
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Failed:      2", result.stdout)
        self.assertIn("one.example — exit 23", result.stdout)
        self.assertIn("two.example — exit 255", result.stdout)

    def test_invalid_source(self):
        for value in ("/", "relative", str(self.root / "missing")):
            with self.subTest(value=value):
                self.config["source_dir"] = value
                self.assert_error(self.run_script(), "Source must")

    def test_invalid_timeout(self):
        for value in ("0", "-1", "abc", "99999999999999999999"):
            with self.subTest(value=value):
                self.config["transfer_timeout"] = value
                self.assert_error(self.run_script(), "positive integer")

    def test_invalid_server_list(self):
        for value in ("", ",one", "one,", "one,,two", "one, two", "-option",
                      "one\nignored", "one\rignored"):
            with self.subTest(value=value):
                self.config["servers"] = value
                self.assert_error(self.run_script(), "ERROR:")

    def test_invalid_destination(self):
        self.config["destination"] = "/has space"
        self.assert_error(self.run_script(), "Destination may contain")

    def test_unknown_option(self):
        self.assert_error(self.run_script("--bogus"), "Unknown argument")

    def test_missing_dependency(self):
        (self.bin / "rsync").unlink()
        self.assert_error(self.run_script(), "Missing dependency: rsync")

    def test_missing_noninteractive_password(self):
        self.env.pop("SSHPASS")
        self.assert_error(self.run_script(), "No interactive terminal")

    def test_signal_exit_status(self):
        for signum, expected in ((signal.SIGINT, 130), (signal.SIGTERM, 143)):
            with self.subTest(signum=signum):
                self.env["MOCK_SIGNAL"] = str(int(signum))
                result = self.run_script()
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertNotIn("summary", result.stdout)


if __name__ == "__main__":
    unittest.main()
