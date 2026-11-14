import os
import shutil

from pathlib import Path


# ==========================================
# FMO LUAU RUNTIME
# CONFIGURATION SYSTEM
# ==========================================

PROJECT_ROOT = Path(__file__).resolve().parent

SCRIPTS_DIR = PROJECT_ROOT / "scripts"
LOGS_DIR = PROJECT_ROOT / "logs"

EXECUTION_TIMEOUT = 10


# ==========================================
# LUAU EXECUTABLE DETECTION
# ==========================================

def find_luau_executable():

    # 1. Custom environment variable

    custom_path = os.environ.get("FMO_LUAU_PATH")

    if custom_path:

        path = Path(custom_path).expanduser()

        if path.is_file():
            return path.resolve()

    # 2. Search in system PATH

    for executable in ("luau", "luau.exe"):

        detected = shutil.which(executable)

        if detected:
            return Path(detected).resolve()

    # 3. Common installation locations

    home = Path.home()

    candidates = [

        home / "luau" / "build" / "luau",

        home / "luau" / "build" / "luau.exe",

        home / "Luau" / "build" / "luau",

        home / "Luau" / "build" / "luau.exe",

    ]

    for candidate in candidates:

        if candidate.is_file():
            return candidate.resolve()

    # 4. Return default path if nothing was found.
    # The interpreter will report that it is missing.

    return home / "luau" / "build" / "luau"


# Automatically detected Luau executable

LUAU_EXECUTABLE = find_luau_executable()


# ==========================================
# CONFIGURATION INFORMATION
# ==========================================

def get_configuration():

    return {

        "project_root": str(PROJECT_ROOT),

        "luau_executable": str(LUAU_EXECUTABLE),

        "luau_found": LUAU_EXECUTABLE.is_file(),

        "scripts_directory": str(SCRIPTS_DIR),

        "logs_directory": str(LOGS_DIR),

        "execution_timeout": EXECUTION_TIMEOUT,

    }
