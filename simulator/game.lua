local Services = require("./services")
local Workspace = require("./workspace")
local InstanceModule = require("./instance")
local BuiltinServices = require("./builtin_services")
local Scheduler = require("./scheduler")
local DataModel = require("./datamodel")

local Game = {}

-- Registrar Workspace
Services.Register("Workspace", Workspace)

-- Colocar Workspace dentro del DataModel
Workspace.Parent = DataModel

-- Registrar los servicios integrados
for name, service in pairs(BuiltinServices) do
    Services.Register(name, service)
    Scheduler:Register(name, service)

    -- Los servicios que son Instances forman parte de la jerarquía.
    if type(service) == "table" and service._isInstance then
        service.Parent = DataModel
    end
end

-- Registrar Workspace en el Scheduler
Scheduler:Register("Workspace", Workspace)

Game.Instance = InstanceModule
Game.Scheduler = Scheduler
Game.DataModel = DataModel

function Game:GetService(name)
    return Services.GetService(name)
end

function Game:FindService(name)
    return Services.FindService(name)
end

function Game:GetChildren()
    return DataModel:GetChildren()
end

function Game:GetDescendants()
    return DataModel:GetDescendants()
end

function Game:FindFirstChild(name, recursive)
    return DataModel:FindFirstChild(name, recursive)
end

function Game:GetFullName()
    return "game"
end

function Game:IsLoaded()
    return DataModel:IsLoaded()
end

function Game:GetServiceCount()
    return DataModel:GetServiceCount()
end

function Game:GetServiceNames()
    return DataModel:GetServiceNames()
end

function Game:Start()
    Scheduler:Start()
end

function Game:Stop()
    Scheduler:Stop()
end

function Game:Step(deltaTime)
    return Scheduler:Step(deltaTime)
end

return Game
