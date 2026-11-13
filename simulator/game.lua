local Services = require("simulator.services")
local Workspace = require("simulator.workspace")
local InstanceModule = require("simulator.instance")

local Game = {}

Services.Register("Workspace", Workspace)

Game.Instance = InstanceModule

function Game:GetService(name)
    return Services.GetService(name)
end

function Game:IsLoaded()
    return true
end

function Game:GetFullName()
    return "game"
end

return Game
