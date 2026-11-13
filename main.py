from pathlib import Path

from engine.interpreter import LuauInterpreter
from config import SCRIPTS_DIR


def main():
    print("=" * 40)
    print("       FMO LUAU RUNTIME")
    print("          UPDATE 1.0")
    print("=" * 40)

    interpreter = LuauInterpreter()

    script = SCRIPTS_DIR / "test.luau"

    print("\n[Runtime] Initializing...")
    print("[Runtime] Loading Luau engine...")

    result = interpreter.execute(script)

    if result["success"]:
        print("\n[Runtime] Script output:")
        print(result["output"])
        print("[Runtime] Execution completed.")
    else:
        print("\n[Runtime] Execution failed:")
        print(result["error"])


if __name__ == "__main__":
    main()