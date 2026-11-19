from engine.interpreter import LuauInterpreter
from config import SCRIPTS_DIR


def main():
    print("=" * 40)
    print("       FMO LUAU RUNTIME")
    print("          UPDATE 1.2")
    print("=" * 40)

    interpreter = LuauInterpreter()
    script = SCRIPTS_DIR / "test.luau"

    print("\n[Runtime] Initializing...")
    print("[Runtime] Loading Luau engine...")

    result = interpreter.execute(script)

    if result["success"]:
        print("\n[Runtime] Script output:")
        print(result["output"], end="" if result["output"].endswith("\n") else "\n")
        print("[Runtime] Execution completed.")
        return 0

    print("\n[Runtime] Execution failed:")
    print(result["error"])

    if result.get("output"):
        print("\n[Runtime] Output before failure:")
        print(result["output"])

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
