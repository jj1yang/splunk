import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "set-lab-ips_live.sh"
HOSTS = ("SH1", "MC1", "IDX1", "IDX2", "UF1")


class TestLabEnvironment(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.table = self.root / "lab table.md"
        # Synthetic credentials exercise shell quoting without using real secrets.
        self.password = """test ' " $HOME $(touch injected) `touch injected` ; &"""
        self.table.write_text(
            "| Role | Public IP | Private IP | Splunk User Name | Password | SSH Username |\n"
            "| --- | --- | --- | --- | --- | --- |\n"
            + "".join(
                f"| {host} | 192.0.2.{i} | 10.0.0.{i} | admin user | "
                f"{self.password} | lab user |\n"
                for i, host in enumerate(HOSTS, 1)
            )
        )
        self.expected = {
            "LAB_SERVER_FILE": str(self.table),
            "LAB_SERVERS": ",".join(f"192.0.2.{i}" for i in range(1, 5)),
            "LAB_UF_SERVERS": "192.0.2.5",
            "ADMIN_USER": "admin user",
            "ADMIN_PASSWORD": self.password,
            "LOGIN_USER": "lab user",
            "LOGIN_PASSWORD": self.password,
            "SSHPASS": self.password,
        }
        for i, host in enumerate(HOSTS, 1):
            self.expected[host] = f"192.0.2.{i}"
            self.expected[host + "_PRIV"] = f"10.0.0.{i}"
        self.environment = os.environ.copy()
        for name in self.expected:
            self.environment.pop(name, None)
        self.environment["LAB_SERVER_FILE"] = str(self.table)
        self.output = self.root / "set-ip_env.sh"

    def run_shell(self, command, shell="bash", arguments=()):
        return subprocess.run(
            [shell, "-c", command, "lab-test", *map(str, arguments)],
            cwd=self.root, env=self.environment, capture_output=True, text=True,
        )

    def load_environment(self, path, shell="bash"):
        names = json.dumps(list(self.expected))
        reader = (
            "import json, os; "
            f"print(json.dumps({{k: os.environ.get(k) for k in {names}}}))"
        )
        result = self.run_shell(
            'source "$1" >/dev/null && python3 -c "$2"',
            shell=shell, arguments=(path, reader),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), self.expected)

    def test_all_exports_round_trip_and_permissions(self):
        self.load_environment(SCRIPT)
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)
        self.table.unlink()
        self.load_environment(self.output)
        self.assertFalse((self.root / "injected").exists())
        self.assertEqual(list(self.root.glob(".set-ip_env.*")), [])

    def test_refresh_replaces_file_and_tightens_permissions(self):
        self.output.write_text("old settings\n")
        self.output.chmod(0o644)
        self.load_environment(SCRIPT)
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)
        self.load_environment(self.output)

    def test_missing_table_preserves_previous_environment_file(self):
        self.load_environment(SCRIPT)
        previous = self.output.read_bytes()
        self.table.unlink()
        result = self.run_shell(
            'export SH1=previous; source "$1" >/dev/null; '
            'status=$?; test "$status" -ne 0 && test "$SH1" = previous',
            arguments=(SCRIPT,),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_bytes(), previous)

    def test_write_failure_does_not_export_new_values(self):
        self.output.mkdir()
        result = self.run_shell(
            'export SH1=previous; source "$1" >/dev/null; '
            'status=$?; test "$status" -ne 0 && test "$SH1" = previous',
            arguments=(SCRIPT,),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.output.is_dir())
        self.assertEqual(list(self.root.glob(".set-ip_env.*")), [])

    def test_direct_execution_still_requires_sourcing(self):
        result = self.run_shell('bash "$1"', arguments=(SCRIPT,))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Source this file", result.stderr)
        self.assertFalse(self.output.exists())

    @unittest.skipUnless(shutil.which("zsh"), "zsh is not installed")
    def test_zsh_round_trip(self):
        self.load_environment(SCRIPT, shell="zsh")
        self.load_environment(self.output, shell="zsh")


if __name__ == "__main__":
    unittest.main()