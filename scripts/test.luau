local Game = require("../simulator/game")

game = Game
local Instance = game.Instance

print("FMO DataModel Test")
print("========================")

print("Game name:", game.DataModel.Name)
print("Game class:", game.DataModel.ClassName)

print("\n--- Services ---")

for _, name in ipairs(game:GetServiceNames()) do
    print("Service:", name)
end

print("\nTotal services:", game:GetServiceCount())

print("\n--- Workspace ---")

local workspace = game:GetService("Workspace")

local part = Instance.new("Part")
part.Name = "TestPart"
part.Parent = workspace

print("Part:", part.Name)
print("Full name:", part:GetFullName())
print("Is descendant:", part:IsDescendantOf(game.DataModel))

print("\nDataModel test completed.")
