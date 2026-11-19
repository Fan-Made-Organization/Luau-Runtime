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
local ErrorHandler = require("./error_handler")
local ScriptSandbox = require("./script_sandbox")
local RuntimeStatistics = require("./runtime_statistics")
local RuntimeProfiler = require("./runtime_profiler")
local MemoryManager = require("./memory_manager")
local EventManager = require("./event_manager")
local ResourceManager = require("./resource_manager")
local RuntimeDebugger = require("./runtime_debugger")
local PerformanceMonitor = require("./performance_monitor")
local TaskQueue = require("./task_queue")
local InstanceManager = require("./instance_manager")

if type(BuiltinServices) ~= "table" then
    error(
        "BuiltinServices debe devolver una tabla. Tipo recibido: "
        .. type(BuiltinServices)
    )
end

local Game = {}

-- Workspace
Services.Register("Workspace", Workspace)
Workspace.Parent = DataModel

-- Servicios integrados
for name, service in pairs(BuiltinServices) do
    Services.Register(name, service)
    Scheduler:Register(name, service)

    if type(service) == "table" and service._isInstance then
        service.Parent = DataModel
    end
end

Scheduler:Register("Workspace", Workspace)
Scheduler:Register("Task", Task)

-- Runtime Manager
RuntimeManager:Configure({
    Scheduler = Scheduler,
    Physics = Physics,
    CollisionService = CollisionService,
    Diagnostics = Diagnostics,
    Task = Task,
    Workspace = Workspace,
})

-- Sistemas principales
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

Game.ErrorHandler = ErrorHandler
Game.ScriptSandbox = ScriptSandbox
Game.RuntimeStatistics = RuntimeStatistics
Game.RuntimeProfiler = RuntimeProfiler
Game.MemoryManager = MemoryManager
Game.EventManager = EventManager
Game.ResourceManager = ResourceManager
Game.RuntimeDebugger = RuntimeDebugger
Game.PerformanceMonitor = PerformanceMonitor
Game.TaskQueue = TaskQueue
Game.InstanceManager = InstanceManager

-- Servicios especiales
Game.ScriptService = BuiltinServices.ScriptService
Game.ScriptLifecycle = BuiltinServices.ScriptLifecycle

Game.BindableEvent = BuiltinServices.BindableEvent
Game.BindableFunction = BuiltinServices.BindableFunction

Game.RemoteEvent = BuiltinServices.RemoteEvent
Game.RemoteFunction = BuiltinServices.RemoteFunction

-- Proveedores de estadísticas
RuntimeStatistics:RegisterProvider("PerformanceMonitor", function()
    return PerformanceMonitor:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("TaskQueue", function()
    return TaskQueue:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("ResourceManager", function()
    return ResourceManager:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("RuntimeDebugger", function()
    return RuntimeDebugger:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("MemoryManager", function()
    return MemoryManager:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("EventManager", function()
    return EventManager:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("RuntimeProfiler", function()
    return RuntimeProfiler:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("RuntimeManager", function()
    return RuntimeManager:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("Scheduler", function()
    return Scheduler:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("Physics", function()
    return Physics:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("Collisions", function()
    return CollisionService:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("Diagnostics", function()
    return Diagnostics:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("Errors", function()
    return ErrorHandler:GetStatistics()
end)

RuntimeStatistics:RegisterProvider("ObjectRegistry", function()
    return ObjectRegistry:GetStatistics()
end)

-- ValueObjects
function Game:CreateValue(className, initialValue)
    return ValueObjects.new(className, initialValue)
end

-- Object Registry
function Game:RegisterObject(object)
    return ObjectRegistry:Register(object)
end

function Game:GetObjectById(id)
    return ObjectRegistry:GetById(id)
end

function Game:GetObjectId(object)
    return ObjectRegistry:GetId(object)
end

-- Instance Extensions
function Game:GetInstanceInformation(object)
    return InstanceExtensions.GetInformation(object)
end

function Game:FindInstanceByPath(object, path)
    return InstanceExtensions.FindByPath(object, path)
end

-- Runtime Environment
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

-- Script Sandbox
function Game:CreateSandbox(name, options)
    options = options or {}

    options.Game = self
    options.Workspace = Workspace
    options.Task = Task
    options.Instance = InstanceModule

    return ScriptSandbox.Create(name, options)
end

function Game:GetSandbox(id)
    return ScriptSandbox.Get(id)
end

function Game:GetSandboxes()
    return ScriptSandbox.GetAll()
end

function Game:GetSandboxCount()
    return ScriptSandbox.GetCount()
end

function Game:DestroyAllSandboxes()
    return ScriptSandbox.DestroyAll()
end

-- Error Handler
function Game:ReportError(message, options)
    return ErrorHandler:Report(message, options)
end

function Game:CaptureError(callback, ...)
    return ErrorHandler:Capture(callback, ...)
end

function Game:GetErrors()
    return ErrorHandler:GetErrors()
end

function Game:GetErrorStatistics()
    return ErrorHandler:GetStatistics()
end

-- Memory Manager
function Game:AllocateMemory(id, bytes, options)
    return MemoryManager:Allocate(id, bytes, options)
end

function Game:ReleaseMemory(id)
    return MemoryManager:Release(id)
end

function Game:GetMemoryStatistics()
    return MemoryManager:GetStatistics()
end

-- Instance Manager
function Game:RegisterInstance(instance, options)
    return InstanceManager:Register(instance, options)
end

function Game:FindInstancesByName(name)
    return InstanceManager:FindByName(name)
end

-- Performance Monitor
function Game:MeasurePerformance(name, callback, ... )
    return PerformanceMonitor:Measure(name, callback, ...)
end

-- Task Queue
function Game:EnqueueTask(callback, options)
    return TaskQueue:Enqueue(callback, options)
end

-- Resource Manager
function Game:RegisterResource(id, value, options)
    return ResourceManager:Register(id, value, options)
end

function Game:ReleaseResource(id)
    return ResourceManager:Release(id)
end

-- Event Manager
function Game:SubscribeEvent(name, callback, options)
    return EventManager:Subscribe(name, callback, options)
end

function Game:PublishEvent(name, ...)
    return EventManager:Publish(name, ...)
end

-- Runtime Profiler
function Game:BeginProfile(name)
    return RuntimeProfiler:Begin(name)
end

function Game:EndProfile(token)
    return RuntimeProfiler:End(token)
end

function Game:Profile(name, callback, ...)
    return RuntimeProfiler:Measure(name, callback, ...)
end

function Game:GetProfileReport()
    return RuntimeProfiler:GetReport()
end

-- Runtime Statistics
function Game:IncrementStatistic(name, amount)
    return RuntimeStatistics:Increment(name, amount)
end

function Game:SetStatistic(name, value)
    return RuntimeStatistics:SetValue(name, value)
end

function Game:GetStatistic(name)
    return RuntimeStatistics:GetValue(name)
end

function Game:GetPerformanceStatistics()
    return RuntimeStatistics:GetSystemStatistics()
end

function Game:GetRuntimeStatistics()
    return RuntimeStatistics:GetStatistics()
end

-- DataModel / Services
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

-- Runtime Lifecycle
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

-- Main Runtime Step
function Game:Step(deltaTime)
    deltaTime = deltaTime or 0

    local totalTimer = RuntimeStatistics:BeginMeasure("Game.Step")

    local stepResult = RuntimeProfiler:Measure("Game.Step", function()
        local schedulerTimer = RuntimeStatistics:BeginMeasure("Scheduler.Step")
        local schedulerResult = RuntimeProfiler:Measure(
            "Scheduler.Step",
            function()
                return Scheduler:Step(deltaTime)
            end
        )
        RuntimeStatistics:EndMeasure(schedulerTimer)

        local physicsTimer = RuntimeStatistics:BeginMeasure("Physics.Step")
        local physicsResult = RuntimeProfiler:Measure(
            "Physics.Step",
            function()
                return Physics:Step(deltaTime)
            end
        )
        RuntimeStatistics:EndMeasure(physicsTimer)

        local collisionTimer = RuntimeStatistics:BeginMeasure("Collision.Step")
        local collisionResult = RuntimeProfiler:Measure(
            "Collision.Step",
            function()
                return CollisionService:Step()
            end
        )
        RuntimeStatistics:EndMeasure(collisionTimer)

        return {
            Scheduler = schedulerResult,
            Physics = physicsResult,
            Collisions = collisionResult,
        }
    end)

    RuntimeStatistics:Increment("Frames")
    RuntimeStatistics:Increment("SchedulerSteps")
    RuntimeStatistics:Increment("PhysicsSteps")
    RuntimeStatistics:Increment("CollisionSteps")

    RuntimeStatistics:Record("FrameDeltaTime", deltaTime)

    RuntimeStatistics:EndMeasure(totalTimer)

    return stepResult
end

return Game
