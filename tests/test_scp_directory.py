import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scp-directory.sh"


class ScpDirectoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        bindir = self.root / "bin"
        bindir.mkdir()
        mock = bindir / "scp"
        mock.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$@"\nexit "${MOCK_SCP_EXIT:-0}"\n'
        )
        mock.chmod(0o700)
        sshpass = bindir / "sshpass"
        sshpass.write_text(
            '#!/bin/sh\n'
            '[ "$1" = "-d" ] && [ "$2" = "3" ] || exit 90\n'
            'IFS= read -r password <&3 || exit 91\n'
            '[ "$password" = \'test password\\with spaces\' ] || exit 92\n'
            'shift 2\n'
            'exec "$@"\n'
        )
        sshpass.chmod(0o700)
        self.bindir = bindir
        self.env = {**os.environ, "PATH": f"{bindir}:{os.environ['PATH']}",
                    "MOCK_SCP_EXIT": "0"}

    def run_script(self, *args, password="test password\\with spaces\n"):
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            input=password,
        )

    def test_relative_directories_are_explicitly_local(self):
        for name in ("normal", "host:directory", "Configurations - Base",
                     "-leading-dash", "nested/host:directory", "./normal"):
            with self.subTest(name=name):
                (self.root / name).mkdir(parents=True, exist_ok=True)
                result = self.run_script("user", "server", name)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    result.stdout.splitlines(),
                    ["-o", "StrictHostKeyChecking=yes", "-r", "--",
                     f"./{name}", "user@server:~/"],
                )

    def test_absolute_directory_is_preserved(self):
        directory = self.root / "host:directory"
        directory.mkdir()
        result = self.run_script("user", "server", str(directory))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["-o", "StrictHostKeyChecking=yes", "-r", "--",
             str(directory), "user@server:~/"],
        )

    def test_multiple_servers_share_one_password(self):
        (self.root / "normal").mkdir()
        result = self.run_script("user", "server1,server2.example.com,192.0.2.10", "normal")
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = []
        for server in ("server1", "server2.example.com", "192.0.2.10"):
            expected.extend(["-o", "StrictHostKeyChecking=yes", "-r", "--",
                             "./normal", f"user@{server}:~/"])
        self.assertEqual(result.stdout.splitlines(), expected)
        self.assertNotIn("test password", result.stdout + result.stderr)

    def test_invalid_server_lists(self):
        (self.root / "normal").mkdir()
        for servers in ("", ",server", "server,", "server,,other",
                        "server, other", "-server", "user@server",
                        "server\nother"):
            with self.subTest(servers=servers):
                result = self.run_script("user", servers, "normal")
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")

    def test_invalid_username(self):
        result = self.run_script("-user", "server", "normal")
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid login username", result.stderr)

    def test_empty_or_unreadable_password(self):
        (self.root / "normal").mkdir()
        for password, message in (("\n", "must not be empty"),
                                  ("", "unable to read")):
            with self.subTest(password=password):
                result = self.run_script("user", "server", "normal", password=password)
                self.assertEqual(result.returncode, 1)
                self.assertIn(message, result.stderr)
                self.assertEqual(result.stdout, "")

    def test_missing_sshpass(self):
        (self.root / "normal").mkdir()
        self.env["PATH"] = str(self.bindir)
        (self.bindir / "sshpass").rename(self.bindir / "disabled-sshpass")
        (self.bindir / "bash").symlink_to("/bin/bash")
        result = self.run_script("user", "server", "normal")
        self.assertEqual(result.returncode, 1)
        self.assertIn("sshpass is required", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_wrong_argument_count(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_missing_directory(self):
        result = self.run_script("user", "server", "missing")
        self.assertEqual(result.returncode, 1)
        self.assertIn("directory not found", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_transfer_failure_is_propagated(self):
        (self.root / "normal").mkdir()
        self.env["MOCK_SCP_EXIT"] = "7"
        result = self.run_script("user", "server,other", "normal")
        self.assertEqual(result.returncode, 7)
        self.assertIn("user@server:~/", result.stdout)
        self.assertNotIn("user@other:~/", result.stdout)


if __name__ == "__main__":
    unittest.main()
