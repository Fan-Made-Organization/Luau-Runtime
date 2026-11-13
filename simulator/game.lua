local Services = require("./services")
local Workspace = require("./workspace")
local InstanceModule = require("./instance")

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
