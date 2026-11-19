import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from engine.interpreter import LuauInterpreter


class LuauInterpreterTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.executable = self.root / "luau"
        self.script = self.root / "sample.luau"

        self.executable.write_text("placeholder", encoding="utf-8")
        self.executable.chmod(0o755)
        self.script.write_text('print("hello")', encoding="utf-8")

    def tearDown(self):
        self.temp_dir.cleanup()

    def make_interpreter(self, timeout=5):
        return LuauInterpreter(
            executable=self.executable,
            timeout=timeout,
        )

    def test_rejects_invalid_timeouts(self):
        for timeout in (0, -1, float("nan"), float("inf"), True):
            with self.subTest(timeout=timeout):
                with self.assertRaises(ValueError):
                    self.make_interpreter(timeout=timeout)

    def test_reports_missing_executable(self):
        interpreter = LuauInterpreter(
            executable=self.root / "missing-luau"
        )

        result = interpreter.execute(self.script)

        self.assertFalse(result["success"])
        self.assertIn("Luau engine not found", result["error"])

    def test_reports_missing_script(self):
        result = self.make_interpreter().execute(
            self.root / "missing.luau"
        )

        self.assertFalse(result["success"])
        self.assertIn("Script file not found", result["error"])

    def test_reports_non_executable_binary(self):
        self.executable.chmod(0o644)

        result = self.make_interpreter().execute(self.script)

        self.assertFalse(result["success"])
        self.assertIn("not executable", result["error"])

    @patch("engine.interpreter.subprocess.run")
    def test_returns_successful_execution_result(self, run):
        run.return_value = subprocess.CompletedProcess(
            args=["luau", "sample.luau"],
            returncode=0,
            stdout="hello\n",
            stderr="",
        )

        result = self.make_interpreter().execute(self.script)

        self.assertTrue(result["success"])
        self.assertEqual(result["output"], "hello\n")
        self.assertEqual(result["error"], "")
        self.assertEqual(result["returncode"], 0)

    @patch("engine.interpreter.subprocess.run")
    def test_preserves_nonzero_exit_code(self, run):
        run.return_value = subprocess.CompletedProcess(
            args=["luau", "sample.luau"],
            returncode=7,
            stdout="partial output",
            stderr="runtime error",
        )

        result = self.make_interpreter().execute(self.script)

        self.assertFalse(result["success"])
        self.assertEqual(result["returncode"], 7)
        self.assertEqual(result["output"], "partial output")
        self.assertEqual(result["error"], "runtime error")

    @patch("engine.interpreter.subprocess.run")
    def test_timeout_preserves_partial_output(self, run):
        run.side_effect = subprocess.TimeoutExpired(
            cmd=["luau", "sample.luau"],
            timeout=5,
            output=b"partial output",
            stderr=b"still running",
        )

        result = self.make_interpreter().execute(self.script)

        self.assertFalse(result["success"])
        self.assertEqual(result["output"], "partial output")
        self.assertIn("timed out", result["error"])
        self.assertIn("still running", result["error"])

    @patch("engine.interpreter.subprocess.run")
    def test_handles_process_start_errors(self, run):
        run.side_effect = OSError("permission denied")

        result = self.make_interpreter().execute(self.script)

        self.assertFalse(result["success"])
        self.assertIn("Unable to start", result["error"])

    def test_handles_invalid_script_path(self):
        result = self.make_interpreter().execute(None)

        self.assertFalse(result["success"])
        self.assertIn("Invalid execution path", result["error"])


if __name__ == "__main__":
    unittest.main()
