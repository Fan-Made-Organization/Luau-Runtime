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

-- ==========================================
-- MODULE DIAGNOSTICS
-- ==========================================

print("===== FMO MODULE DIAGNOSTICS =====")

print("Services:", type(Services))
print("Workspace:", type(Workspace))
print("InstanceModule:", type(InstanceModule))
print("BuiltinServices:", type(BuiltinServices))
print("Scheduler:", type(Scheduler))
print("DataModel:", type(DataModel))
print("Task:", type(Task))
print("ValueObjects:", type(ValueObjects))
print("ObjectRegistry:", type(ObjectRegistry))
print("Physics:", type(Physics))
print("CollisionService:", type(CollisionService))
print("Diagnostics:", type(Diagnostics))
print("RuntimeManager:", type(RuntimeManager))
print("InstanceExtensions:", type(InstanceExtensions))
print("RuntimeEnvironment:", type(RuntimeEnvironment))
print("ErrorHandler:", type(ErrorHandler))
print("ScriptSandbox:", type(ScriptSandbox))
print("RuntimeStatistics:", type(RuntimeStatistics))

print("----------------------------------")

print("Task.Step:", type(Task.Step))
print("Scheduler.Step:", type(Scheduler.Step))
print("Physics.Step:", type(Physics.Step))
print("Physics.SetGravity:", type(Physics.SetGravity))
print("Physics.RegisterPart:", type(Physics.RegisterPart))
print("Physics.SetVelocity:", type(Physics.SetVelocity))
print("Physics.SetMass:", type(Physics.SetMass))
print("Physics.IsRegistered:", type(Physics.IsRegistered))
print("Physics.RemovePart:", type(Physics.RemovePart))

print("==================================")

-- ==========================================
-- MODULE VALIDATION
-- ==========================================

local function validateModule(name, module, requiredMethods)
    if type(module) ~= "table" then
        error(
            "[FMO] " .. name ..
            " debe devolver una tabla. Tipo recibido: " ..
            type(module)
        )
    end

    for _, methodName in ipairs(requiredMethods or {}) do
        if type(module[methodName]) ~= "function" then
            error(
                "[FMO] " .. name ..
                " no contiene el método " .. methodName ..
                ". Tipo recibido: " .. type(module[methodName])
            )
        end
    end
end

validateModule("Scheduler", Scheduler, {
    "Step",
    "Register",
    "Start",
})

validateModule("Task", Task, {
    "Step",
    "spawn",
})

validateModule("Physics", Physics, {
    "Step",
    "SetGravity",
    "RegisterPart",
    "SetVelocity",
    "SetMass",
    "IsRegistered",
    "RemovePart",
})

validateModule("RuntimeManager", RuntimeManager, {
    "Initialize",
    "Start",
    "ApplyConfiguration",
})

validateModule("RuntimeStatistics", RuntimeStatistics, {
    "BeginMeasure",
    "EndMeasure",
})

-- ==========================================
-- BUILTIN SERVICES VALIDATION
-- ==========================================

if type(BuiltinServices) ~= "table" then
    error(
        "BuiltinServices debe devolver una tabla. Tipo recibido: " ..
        type(BuiltinServices)
    )
end

-- ==========================================
-- GAME OBJECT
-- ==========================================

local Game = {}

Game.Services = Services
Game.Workspace = Workspace
Game.Instance = InstanceModule
Game.Scheduler = Scheduler
Game.DataModel = DataModel
Game.Task = Task

Game.ValueObjects = ValueObjects
Game.ObjectRegistry = ObjectRegistry
Game.Physics = Physics
Game.CollisionService = CollisionService
Game.Diagnostics = Diagnostics
Game.RuntimeManager = RuntimeManager
Game.InstanceExtensions = InstanceExtensions
Game.RuntimeEnvironment = RuntimeEnvironment
Game.ErrorHandler = ErrorHandler
Game.ScriptSandbox = ScriptSandbox
Game.RuntimeStatistics = RuntimeStatistics

-- ==========================================
-- SERVICE REGISTRATION
-- ==========================================

for name, service in pairs(BuiltinServices) do
    if type(service) == "table" then
        Services.Register(name, service)
        Scheduler:Register(name, service)
    end
end

-- ==========================================
-- STATISTICS PROVIDERS
-- ==========================================

if type(RuntimeStatistics.RegisterProvider) == "function" then
    RuntimeStatistics:RegisterProvider("Physics", function()
        return Physics:GetStatistics()
    end)

    RuntimeStatistics:RegisterProvider("Collision", function()
        return CollisionService:GetStatistics()
    end)

    RuntimeStatistics:RegisterProvider("Scheduler", function()
        return {
            Frame = Scheduler:GetFrame(),
            ElapsedTime = Scheduler:GetElapsedTime(),
            Running = Scheduler:IsRunning(),
        }
    end)
end

-- ==========================================
-- RUNTIME MANAGER CONFIGURATION
-- ==========================================

RuntimeManager:Configure({
    Scheduler = Scheduler,
    Physics = Physics,
    CollisionService = CollisionService,
    Diagnostics = Diagnostics,
    RuntimeStatistics = RuntimeStatistics,
})

-- ==========================================
-- GAME METHODS
-- ==========================================

function Game:GetService(name)
    return Services.GetService(name)
end

function Game:IsLoaded()
    return true
end

function Game:Step(deltaTime)
    deltaTime = deltaTime or 0

    local totalTimer = RuntimeStatistics:BeginMeasure("Game.Step")

    local schedulerTimer = RuntimeStatistics:BeginMeasure("Scheduler.Step")
    local schedulerResult = Scheduler:Step(deltaTime)
    RuntimeStatistics:EndMeasure(schedulerTimer)

    local physicsTimer = RuntimeStatistics:BeginMeasure("Physics.Step")
    local physicsResult = Physics:Step(deltaTime)
    RuntimeStatistics:EndMeasure(physicsTimer)

    local collisionTimer = RuntimeStatistics:BeginMeasure("Collision.Step")
    local collisionResult = CollisionService:Step()
    RuntimeStatistics:EndMeasure(collisionTimer)

    RuntimeStatistics:EndMeasure(totalTimer)

    return {
        Scheduler = schedulerResult,
        Physics = physicsResult,
        Collision = collisionResult,
    }
end

function Game:Start()
    return RuntimeManager:Start()
end

function Game:Stop()
    return RuntimeManager:Stop()
end

function Game:Initialize()
    return RuntimeManager:Initialize()
end

function Game:Shutdown()
    return RuntimeManager:Shutdown()
end

function Game:GetRuntimeStatus()
    return RuntimeManager:GetStatus()
end

function Game:GetStatistics()
    return RuntimeStatistics:GetStatistics()
end

function Game:GetFullName()
    return "game"
end

return Game
