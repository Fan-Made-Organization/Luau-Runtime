from pathlib import Path
import math
import os
import subprocess

from config import EXECUTION_TIMEOUT, LUAU_EXECUTABLE


class LuauInterpreter:
    """Runs Luau scripts through the official command-line interpreter."""

    def __init__(self, executable=None, timeout=None):
        self.executable = Path(executable or LUAU_EXECUTABLE).expanduser()
        self.timeout = EXECUTION_TIMEOUT if timeout is None else timeout

        if (
            isinstance(self.timeout, bool)
            or not isinstance(self.timeout, (int, float))
            or not math.isfinite(self.timeout)
            or self.timeout <= 0
        ):
            raise ValueError("Execution timeout must be a finite positive number")

    @staticmethod
    def _decode_output(value):
        if value is None:
            return ""
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return str(value)

    @staticmethod
    def _failure(message, output="", returncode=None):
        return {
            "success": False,
            "output": output,
            "error": str(message),
            "returncode": returncode,
        }

    def execute(self, script_path):
        try:
            script_path = Path(script_path).expanduser().resolve()
            executable = self.executable.expanduser().resolve()
        except (OSError, TypeError, ValueError) as error:
            return self._failure(f"Invalid execution path: {error}")

        if not executable.is_file():
            return self._failure(
                f"Luau engine not found: {executable}"
            )

        if os.name != "nt" and not os.access(executable, os.X_OK):
            return self._failure(
                f"Luau engine is not executable: {executable}"
            )

        if not script_path.is_file():
            return self._failure(
                f"Script file not found: {script_path}"
            )

        try:
            result = subprocess.run(
                [str(executable), str(script_path)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=self.timeout,
                check=False,
            )

            return {
                "success": result.returncode == 0,
                "output": result.stdout,
                "error": result.stderr,
                "returncode": result.returncode,
            }

        except subprocess.TimeoutExpired as error:
            partial_output = self._decode_output(error.stdout)
            partial_error = self._decode_output(error.stderr)

            details = f"Execution timed out after {self.timeout} seconds."
            if partial_error:
                details += f"\n{partial_error}"

            return self._failure(details, partial_output)

        except OSError as error:
            return self._failure(
                f"Unable to start Luau interpreter: {error}"
            )
