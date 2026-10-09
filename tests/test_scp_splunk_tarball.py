import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scp-splunk-tarball.sh"


class ScpSplunkTarballTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bindir = self.root / "bin"
        self.bindir.mkdir()
        self.log = self.root / "calls"
        mock = self.bindir / "sshpass"
        mock.write_text(
            '#!/bin/sh\n'
            '[ "$1" = "-d" ] && [ "$2" = "3" ] || exit 90\n'
            'read -r supplied <&3 || exit 91\n'
            '[ "$supplied" = \'synthetic-test-value\' ] || exit 92\n'
            'shift 2\n'
            'printf "%s\\n" "$@" >> "$MOCK_LOG"\n'
            'if [ "$1" = "${MOCK_FAIL_COMMAND:-}" ]; then exit 7; fi\n'
        )
        mock.chmod(0o700)
        self.env = {
            **os.environ,
            "PATH": str(self.bindir),
            "MOCK_LOG": str(self.log),
            "MOCK_FAIL_COMMAND": "",
        }
        self.archive = self.root / "splunk-test.tgz"
        self.archive.touch()

    def run_script(self, *args, password="synthetic-test-value\n"):
        return subprocess.run(
            ["/bin/bash", str(SCRIPT), *args],
            cwd=self.root,
            env=self.env,
            input=password,
            capture_output=True,
            text=True,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_single_and_multiple_servers_reuse_password(self):
        for servers in ("server1", "server1,server2,192.0.2.1"):
            with self.subTest(servers=servers):
                if self.log.exists():
                    self.log.unlink()
                result = self.run_script("user", servers)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = []
                for server in servers.split(","):
                    expected.extend([
                        "ssh", "-o", "StrictHostKeyChecking=yes", "--",
                        f"user@{server}", 'mkdir -p "$HOME/Downloads"',
                        "scp", "-o", "StrictHostKeyChecking=yes", "--",
                        "./splunk-test.tgz", f"user@{server}:~/Downloads/",
                    ])
                self.assertEqual(self.calls(), expected)
                self.assertNotIn("synthetic-test-value", result.stdout + result.stderr)

    def test_invalid_servers_do_not_connect(self):
        for servers in ("", ",server", "server,", "server,,other",
                        "server, other", "-option", "server/path", "user@server"):
            with self.subTest(servers=servers):
                result = self.run_script("user", servers)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(self.calls(), [])

    def test_invalid_user_and_argument_count(self):
        for args in ((), ("user",), ("user@host", "server")):
            with self.subTest(args=args):
                self.assertEqual(self.run_script(*args).returncode, 2)
                self.assertEqual(self.calls(), [])

    def test_archive_selection_errors(self):
        self.archive.unlink()
        result = self.run_script("user", "server")
        self.assertEqual(result.returncode, 1)
        self.assertIn("no Splunk tarball", result.stderr)
        self.archive.touch()
        (self.root / "splunkforwarder-test.tgz").touch()
        result = self.run_script("user", "server")
        self.assertEqual(result.returncode, 1)
        self.assertIn("multiple Splunk tarballs", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_missing_sshpass(self):
        (self.bindir / "sshpass").unlink()
        result = self.run_script("user", "server")
        self.assertEqual(result.returncode, 1)
        self.assertIn("sshpass is required", result.stderr)

    def test_empty_password_and_eof(self):
        for password in ("\n", ""):
            with self.subTest(password=password):
                result = self.run_script("user", "server", password=password)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.calls(), [])

    def test_failure_stops_before_next_host(self):
        for command in ("ssh", "scp"):
            with self.subTest(command=command):
                if self.log.exists():
                    self.log.unlink()
                self.env["MOCK_FAIL_COMMAND"] = command
                result = self.run_script("user", "server1,server2")
                self.assertEqual(result.returncode, 7)
                self.assertNotIn("user@server2", self.calls())
                self.assertEqual(self.calls().count("scp"), command == "scp")


if __name__ == "__main__":
    unittest.main()
