
from engine.interpreter import LuauInterpreter

interpreter = LuauInterpreter()

result = interpreter.execute("scripts/test.luau")

print("========== FMO RUNTIME ==========")

if result["success"]:
    print(result["output"])
    print("Execution completed successfully!")
else:
    print("Execution failed!")
    print(result["error"])
