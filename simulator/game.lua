local Services = require("./services")
local Workspace = require("./workspace")
local InstanceModule = require("./instance")
local BuiltinServices = require("./builtin_services")

local Game = {}

Services.Register("Workspace", Workspace)

for name, service in pairs(BuiltinServices) do
    Services.Register(name, service)
end

Game.Instance = InstanceModule

function Game:GetService(name)
    return Services.GetService(name)
end

function Game:FindService(name)
    return Services.FindService(name)
end

function Game:IsLoaded()
    return true
end

function Game:GetFullName()
    return "game"
end

return Game
