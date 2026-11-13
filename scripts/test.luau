local Game = require("../simulator/game")

game = Game
task = Game.Task

print("FMO TASK SCHEDULER TEST")
print("========================")

game:Start()

task.spawn(function()
    print("[Spawn] Task started")

    task.wait(1)

    print("[Spawn] One second passed")
end)

task.defer(function()
    print("[Defer] Deferred task executed")
end)

task.delay(2, function()
    print("[Delay] Two seconds passed")
end)

print("\n--- Scheduler ---")

for i = 1, 3 do
    game:Step(1)

    print(
        "Frame:",
        game.Scheduler:GetFrame(),
        "Clock:",
        task.GetClock()
    )
end

game:Stop()

print("\nTask Scheduler test completed.")
