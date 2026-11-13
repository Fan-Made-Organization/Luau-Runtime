local Game = require("../simulator/game")

game = Game
workspace = game:GetService("Workspace")
Instance = game.Instance

print("FMO Luau Runtime")
print("Execution Engine: Operational")

local version = "Update 1.0"

print("Version: " .. version)

print("\n--- Simulator Test ---")

local part = Instance.new("Part")

part.Name = "MiPart"
part.Parent = workspace

print("Part created: " .. part.Name)
print("Class: " .. part.ClassName)
print("Full Name: " .. part:GetFullName())
print("Children: " .. #workspace:GetChildren())

print("\nSimulator test completed.")
