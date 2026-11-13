import subprocess

from config import LUAU_EXECUTABLE, EXECUTION_TIMEOUT


class LuauInterpreter:

    def __init__(self):
        self.executable = LUAU_EXECUTABLE

    def execute(self, script_path):

        if not self.executable.is_file():
            return {
                "success": False,
                "output": "",
                "error": "Luau executable not found."
            }

        try:
            result = subprocess.run(
                [str(self.executable), str(script_path)],
                capture_output=True,
                text=True,
                timeout=EXECUTION_TIMEOUT
            )

            return {
                "success": result.returncode == 0,
                "output": result.stdout,
                "error": result.stderr
            }

        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "output": "",
                "error": "Execution timeout."
            }

        except Exception as error:
            return {
                "success": False,
                "output": "",
                "error": str(error)
            }
