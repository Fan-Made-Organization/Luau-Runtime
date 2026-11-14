local Services = require("./services")
local Workspace = require("./workspace")
local InstanceModule = require("./instance")
local BuiltinServices = require("./builtin_services")
local Scheduler = require("./scheduler")
local DataModel = require("./datamodel")
local Task = require("./task")
local ValueObjects = require("./value_objects")
local ObjectRegistry = require("./object_registry")
local Physics = require("./physics_service")
local CollisionService = require("./collision_service")

local Game = {}

Services.Register("Workspace", Workspace)
Workspace.Parent = DataModel

for name, service in pairs(BuiltinServices) do
    Services.Register(name, service)
    Scheduler:Register(name, service)

    if type(service) == "table" and service._isInstance then
        service.Parent = DataModel
    end
end

Scheduler:Register("Workspace", Workspace)
Scheduler:Register("Task", Task)

Game.Instance = InstanceModule
Game.Scheduler = Scheduler
Game.DataModel = DataModel
Game.Task = Task

Game.ValueObjects = ValueObjects
Game.ObjectRegistry = ObjectRegistry
Game.Physics = Physics
Game.CollisionService = CollisionService

Game.ScriptService = BuiltinServices.ScriptService
Game.ScriptLifecycle = BuiltinServices.ScriptLifecycle

Game.BindableEvent = BuiltinServices.BindableEvent
Game.BindableFunction = BuiltinServices.BindableFunction

Game.RemoteEvent = BuiltinServices.RemoteEvent
Game.RemoteFunction = BuiltinServices.RemoteFunction

function Game:CreateValue(className, initialValue)
    return ValueObjects.new(className, initialValue)
end

function Game:RegisterObject(object)
    return ObjectRegistry:Register(object)
end

function Game:GetObjectById(id)
    return ObjectRegistry:GetById(id)
end

function Game:GetObjectId(object)
    return ObjectRegistry:GetId(object)
end

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
    local schedulerResult = Scheduler:Step(deltaTime)
    local physicsResult = Physics:Step(deltaTime)
    local collisionResult = CollisionService:Step()

    return {
        Scheduler = schedulerResult,
        Physics = physicsResult,
        Collisions = collisionResult,
    }
end

return Game
