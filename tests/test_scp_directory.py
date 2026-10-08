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
        self.env = {**os.environ, "PATH": f"{bindir}:{os.environ['PATH']}",
                    "MOCK_SCP_EXIT": "0"}

    def run_script(self, *args):
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
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
                    ["-r", "--", f"./{name}", "user@server:~/"],
                )

    def test_absolute_directory_is_preserved(self):
        directory = self.root / "host:directory"
        directory.mkdir()
        result = self.run_script("user", "server", str(directory))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["-r", "--", str(directory), "user@server:~/"],
        )

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
        result = self.run_script("user", "server", "normal")
        self.assertEqual(result.returncode, 7)


if __name__ == "__main__":
    unittest.main()
