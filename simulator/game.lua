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
local Diagnostics = require("./runtime_diagnostics")
local RuntimeManager = require("./runtime_manager")
local InstanceExtensions = require("./instance_extensions")
local RuntimeEnvironment = require("./runtime_environment")

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

RuntimeManager:Configure({
    Scheduler = Scheduler,
    Physics = Physics,
    CollisionService = CollisionService,
    Diagnostics = Diagnostics,
    Task = Task,
    Workspace = Workspace,
})

Game.Instance = InstanceModule
Game.InstanceExtensions = InstanceExtensions

Game.Scheduler = Scheduler
Game.DataModel = DataModel
Game.Task = Task

Game.ValueObjects = ValueObjects
Game.ObjectRegistry = ObjectRegistry
Game.Physics = Physics
Game.CollisionService = CollisionService
Game.Diagnostics = Diagnostics
Game.RuntimeManager = RuntimeManager

Game.RuntimeEnvironment = RuntimeEnvironment
Game.Environment = RuntimeEnvironment.GetDefault()

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

function Game:GetInstanceInformation(object)
    return InstanceExtensions.GetInformation(object)
end

function Game:FindInstanceByPath(object, path)
    return InstanceExtensions.FindByPath(object, path)
end

function Game:CreateEnvironment(name, overrides)
    return self.Environment:CreateEnvironment(name, overrides)
end

function Game:RegisterGlobal(name, value)
    return self.Environment:SetGlobal(name, value)
end

function Game:GetGlobal(name)
    return self.Environment:GetGlobal(name)
end

function Game:RemoveGlobal(name)
    return self.Environment:RemoveGlobal(name)
end

function Game:GetGlobals(includeParent)
    return self.Environment:GetGlobals(includeParent)
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

function Game:Initialize()
    return RuntimeManager:Initialize()
end

function Game:Start()
    return RuntimeManager:Start()
end

function Game:Stop()
    return RuntimeManager:Stop()
end

function Game:Restart()
    return RuntimeManager:Restart()
end

function Game:Shutdown()
    return RuntimeManager:Shutdown()
end

function Game:GetRuntimeStatus()
    return RuntimeManager:GetStatus()
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
