from pathlib import Path

PROJECT_ROOT = Path(__file__).parent

LUAU_EXECUTABLE = Path.home() / "luau" / "build" / "luau"

SCRIPTS_DIR = PROJECT_ROOT / "scripts"

EXECUTION_TIMEOUT = 10
