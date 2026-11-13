from pathlib import Path

# Project configuration
PROJECT_ROOT = Path(__file__).parent

# Luau engine
LUAU_EXECUTABLE = Path.home() / "luau" / "build" / "luau"

# Project directories
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
LOGS_DIR = PROJECT_ROOT / "logs"

# Execution settings
EXECUTION_TIMEOUT = 10
