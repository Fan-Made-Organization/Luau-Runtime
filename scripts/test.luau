--[[
========================================================
             FMO LUAU RUNTIME
                SUPER TEST
                  VERSION 1.0
========================================================

  Integrated Runtime Verification System

  Tests:
    01. DataModel
    02. Instance System
    03. Instance Extensions
    04. Services
    05. Signals
    06. Task Scheduler
    07. RunService
    08. Players
    09. CollectionService
    10. Debris
    11. HTTP Service
    12. Tween Service
    13. Script Service
    14. Module Loader
    15. Script Lifecycle
    16. BindableEvent
    17. BindableFunction
    18. RemoteEvent
    19. RemoteFunction
    20. ValueObjects
    21. Object Registry
    22. Physics
    23. Collision System
    24. Runtime Diagnostics
    25. Runtime Manager
    26. Runtime Environment
    27. Error Handler
    28. Script Sandbox
    29. Runtime Statistics
    30. Integrated Runtime

========================================================
]]

local Game = require("../simulator/game")

game = Game
task = Game.Task

local Instance = Game.Instance

local totalTests = 0
local passedTests = 0
local failedTests = 0
local skippedTests = 0

local failures = {}

local startTime = os.clock()

--------------------------------------------------------
-- CONSOLE
--------------------------------------------------------

local function line()
    print("--------------------------------------------------------")
end

local function section(name)
    print("")
    line()
    print("  " .. name)
    line()
end

local function success(message)
    print("[PASS] " .. message)
end

local function failure(message)
    print("[FAIL] " .. message)
end

local function warning(message)
    print("[WARN] " .. message)
end

--------------------------------------------------------
-- ASSERTIONS
--------------------------------------------------------

local function expect(condition, message)
    if not condition then
        error(message or "Assertion failed", 2)
    end

    return true
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(
            (message or "Values are different")
            .. " | Expected: "
            .. tostring(expected)
            .. " | Received: "
            .. tostring(actual),
            2
        )
    end

    return true
end

local function expectType(value, expected, message)
    equal(type(value), expected, message or "Unexpected type")
end

--------------------------------------------------------
-- TEST RUNNER
--------------------------------------------------------

local function test(name, callback)
    totalTests += 1

    local ok, result = pcall(callback)

    if ok then
        passedTests += 1
        success(name)
    else
        failedTests += 1

        local message = tostring(result)

        table.insert(failures, {
            Name = name,
            Error = message,
        })

        failure(name)
        print("       " .. message)
    end
end

local function skip(name, reason)
    totalTests += 1
    skippedTests += 1

    warning(name .. " - " .. tostring(reason))
end

--------------------------------------------------------
-- START
--------------------------------------------------------

print("")
print("========================================================")
print("             FMO LUAU RUNTIME")
print("                SUPER TEST 1.0")
print("========================================================")
print("")
print("[Runtime] Initializing...")
print("[Runtime] Loading Game module...")
print("[Runtime] Preparing test environment...")

--------------------------------------------------------
-- 01. DATAMODEL
--------------------------------------------------------

section("01. DATAMODEL")

test("DataModel exists", function()
    expect(Game.DataModel ~= nil)
end)

test("DataModel is loaded", function()
    expect(Game:IsLoaded())
end)

test("Game full name", function()
    equal(Game:GetFullName(), "game")
end)

test("Workspace service exists", function()
    expect(Game:GetService("Workspace") ~= nil)
end)

test("Service count", function()
    expect(Game:GetServiceCount() > 0)
end)

--------------------------------------------------------
-- 02. INSTANCE SYSTEM
--------------------------------------------------------

section("02. INSTANCE SYSTEM")

local testFolder
local testPart

test("Instance creation", function()
    testFolder = Instance.new("Folder")
    testFolder.Name = "FMO_SuperTest"

    expect(testFolder ~= nil)
    equal(testFolder.Name, "FMO_SuperTest")
end)

test("Part creation", function()
    testPart = Instance.new("Part")
    testPart.Name = "TestPart"

    expect(testPart:IsA("Part"))
end)

test("Parent assignment", function()
    testFolder.Parent = Game:GetService("Workspace")
    testPart.Parent = testFolder

    equal(testPart.Parent, testFolder)
end)

test("GetChildren", function()
    local children = testFolder:GetChildren()

    expect(#children >= 1)
end)

test("GetDescendants", function()
    local descendants = testFolder:GetDescendants()

    expect(#descendants >= 1)
end)

test("FindFirstChild", function()
    local found = testFolder:FindFirstChild("TestPart")

    equal(found, testPart)
end)

test("IsDescendantOf", function()
    expect(testPart:IsDescendantOf(testFolder))
end)

test("GetFullName", function()
    expect(type(testPart:GetFullName()) == "string")
end)

test("Instance attributes", function()
    testPart:SetAttribute("FMOTest", true)

    equal(testPart:GetAttribute("FMOTest"), true)
end)

test("Instance cloning", function()
    local clone = testPart:Clone()

    expect(clone ~= nil)
    equal(clone.Name, testPart.Name)

    clone:Destroy()
end)

--------------------------------------------------------
-- 03. INSTANCE EXTENSIONS
--------------------------------------------------------

section("03. INSTANCE EXTENSIONS")

local Extensions = Game.InstanceExtensions

test("GetAncestors", function()
    local ancestors = Extensions.GetAncestors(testPart)

    expect(#ancestors >= 1)
end)

test("GetRoot", function()
    local root = Extensions.GetRoot(testPart)

    expect(root ~= nil)
end)

test("GetDepth", function()
    local depth = Extensions.GetDepth(testPart)

    expect(type(depth) == "number")
    expect(depth >= 0)
end)

test("GetChildrenOfClass", function()
    local children = Extensions.GetChildrenOfClass(
        testFolder,
        "Part"
    )

    expect(#children >= 1)
end)

test("GetDescendantsOfClass", function()
    local descendants = Extensions.GetDescendantsOfClass(
        Game:GetService("Workspace"),
        "Part"
    )

    expect(#descendants >= 1)
end)

test("FindFirstDescendant", function()
    local found = Extensions.FindFirstDescendant(
        Game:GetService("Workspace"),
        "TestPart"
    )

    equal(found, testPart)
end)

test("GetInstanceInformation", function()
    local information = Game:GetInstanceInformation(testPart)

    expect(type(information) == "table")
    equal(information.Name, "TestPart")
end)

test("GetTree", function()
    local tree = Extensions.GetTree(testFolder)

    expect(type(tree) == "table")
end)

--------------------------------------------------------
-- 04. SERVICES
--------------------------------------------------------

section("04. SERVICES")

test("GetService", function()
    expect(Game:GetService("Players") ~= nil)
end)

test("FindService", function()
    expect(Game:FindService("Workspace") ~= nil)
end)

test("GetServiceNames", function()
    local names = Game:GetServiceNames()

    expect(type(names) == "table")
    expect(#names > 0)
end)

test("Builtin service registration", function()
    expect(Game:GetService("Lighting") ~= nil)
    expect(Game:GetService("ReplicatedStorage") ~= nil)
end)

--------------------------------------------------------
-- 05. SIGNALS
--------------------------------------------------------

section("05. SIGNAL SYSTEM")

local Signal = require("../simulator/signal")

test("Signal creation", function()
    local signal = Signal.new()

    expect(signal ~= nil)

    signal:Destroy()
end)

test("Signal connection and firing", function()
    local signal = Signal.new()
    local received = false

    local connection = signal:Connect(function(value)
        received = value
    end)

    signal:Fire(true)

    expect(received)

    connection:Disconnect()
    signal:Destroy()
end)

test("Signal connection count", function()
    local signal = Signal.new()

    signal:Connect(function() end)

    equal(signal:Count(), 1)

    signal:Destroy()
end)

test("Signal Once", function()
    local signal = Signal.new()
    local count = 0

    signal:Once(function()
        count += 1
    end)

    signal:Fire()
    signal:Fire()

    equal(count, 1)

    signal:Destroy()
end)

--------------------------------------------------------
-- 06. TASK SCHEDULER
--------------------------------------------------------

section("06. TASK SCHEDULER")

test("Task API exists", function()
    expect(type(task.spawn) == "function")
    expect(type(task.defer) == "function")
    expect(type(task.delay) == "function")
    expect(type(task.wait) == "function")
end)

test("Task clock", function()
    expect(type(task.GetClock()) == "number")
end)

test("Task spawn", function()
    local executed = false

    task.spawn(function()
        executed = true
    end)

    Game:Step(0.1)

    expect(executed)
end)

test("Task pending count", function()
    expect(type(task.GetPendingCount()) == "number")
end)

--------------------------------------------------------
-- 07. RUN SERVICE
--------------------------------------------------------

section("07. RUN SERVICE")

local RunService = Game:GetService("RunService")

test("RunService exists", function()
    expect(RunService ~= nil)
end)

test("RunService signals", function()
    expect(RunService.Heartbeat ~= nil)
    expect(RunService.Stepped ~= nil)
    expect(RunService.RenderStepped ~= nil)
end)

test("RunService client/server information", function()
    expect(type(RunService:IsClient()) == "boolean")
    expect(type(RunService:IsServer()) == "boolean")
end)

--------------------------------------------------------
-- 08. PLAYERS
--------------------------------------------------------

section("08. PLAYERS")

local Players = Game:GetService("Players")

test("Players service exists", function()
    expect(Players ~= nil)
end)

test("Players signals", function()
    expect(Players.PlayerAdded ~= nil)
    expect(Players.PlayerRemoving ~= nil)
end)

test("GetPlayers", function()
    local players = Players:GetPlayers()

    expect(type(players) == "table")
end)

test("Player count", function()
    expect(type(Players:GetPlayers()) == "table")
end)

--------------------------------------------------------
-- 09. COLLECTION SERVICE
--------------------------------------------------------

section("09. COLLECTION SERVICE")

local CollectionService = Game:GetService("CollectionService")

test("CollectionService exists", function()
    expect(CollectionService ~= nil)
end)

test("CollectionService tag registration", function()
    CollectionService:AddTag(testPart, "FMO_TestTag")

    expect(CollectionService:HasTag(testPart, "FMO_TestTag"))
end)

test("CollectionService tag retrieval", function()
    local tags = CollectionService:GetTags(testPart)

    expect(type(tags) == "table")
end)

test("CollectionService tag removal", function()
    CollectionService:RemoveTag(testPart, "FMO_TestTag")

    expect(not CollectionService:HasTag(testPart, "FMO_TestTag"))
end)

--------------------------------------------------------
-- 10. DEBRIS
--------------------------------------------------------

section("10. DEBRIS SERVICE")

local Debris = Game:GetService("Debris")

test("Debris service exists", function()
    expect(Debris ~= nil)
end)

test("Debris API exists", function()
    expect(type(Debris.AddItem) == "function")
end)

--------------------------------------------------------
-- 11. HTTP SERVICE
--------------------------------------------------------

section("11. HTTP SERVICE")

local HttpService = Game:GetService("HttpService")

test("HTTP service exists", function()
    expect(HttpService ~= nil)
end)

test("GenerateGUID", function()
    local guid = HttpService:GenerateGUID()

    expect(type(guid) == "string")
    expect(#guid > 0)
end)

test("JSONEncode", function()
    local encoded = HttpService:JSONEncode({
        Name = "FMO",
        Version = 1,
    })

    expect(type(encoded) == "string")
end)

test("JSONDecode", function()
    local decoded = HttpService:JSONDecode(
        '{"Name":"FMO","Version":1}'
    )

    expect(type(decoded) == "table")
    equal(decoded.Name, "FMO")
end)

test("URL encoding", function()
    local encoded = HttpService:UrlEncode("FMO Runtime")

    expect(type(encoded) == "string")
end)

--------------------------------------------------------
-- 12. TWEEN SERVICE
--------------------------------------------------------

section("12. TWEEN SERVICE")

local TweenService = Game:GetService("TweenService")

test("TweenService exists", function()
    expect(TweenService ~= nil)
end)

test("TweenService methods", function()
    expect(type(TweenService.Create) == "function")
end)

--------------------------------------------------------
-- 13. SCRIPT SERVICE
--------------------------------------------------------

section("13. SCRIPT SERVICE")

local ScriptService = Game.ScriptService

test("ScriptService exists", function()
    expect(ScriptService ~= nil)
end)

test("ScriptService execution API", function()
    expect(type(ScriptService.Execute) == "function")
end)

test("ScriptService module API", function()
    expect(type(ScriptService.Require) == "function")
end)

test("ScriptService context API", function()
    expect(type(ScriptService.SetExecutionContext) == "function")
end)

--------------------------------------------------------
-- 14. MODULE LOADER
--------------------------------------------------------

section("14. MODULE LOADER")

local ModuleLoader = require("../simulator/module_loader")

test("ModuleLoader exists", function()
    expect(ModuleLoader ~= nil)
end)

test("ModuleLoader cache API", function()
    expect(type(ModuleLoader.GetLoadedCount) == "function")
end)

test("ModuleLoader statistics", function()
    expect(type(ModuleLoader.GetStatistics) == "function")
end)

--------------------------------------------------------
-- 15. SCRIPT LIFECYCLE
--------------------------------------------------------

section("15. SCRIPT LIFECYCLE")

local ScriptLifecycle = Game.ScriptLifecycle

local lifecycleScript

test("ScriptLifecycle exists", function()
    expect(ScriptLifecycle ~= nil)
end)

test("Script lifecycle registration", function()
    lifecycleScript = Instance.new("Script")
    lifecycleScript.Name = "FMO_Lifecycle_Test"

    local result = ScriptLifecycle:Register(lifecycleScript)

    expect(result ~= false)
end)

test("Script lifecycle state", function()
    local state = ScriptLifecycle:GetState(lifecycleScript)

    expect(state ~= nil)
end)

test("Script lifecycle start", function()
    local result = ScriptLifecycle:Start(lifecycleScript)

    expect(result ~= false)
end)

test("Script lifecycle stop", function()
    local result = ScriptLifecycle:Stop(lifecycleScript)

    expect(result ~= false)
end)

--------------------------------------------------------
-- 16. BINDABLE EVENT
--------------------------------------------------------

section("16. BINDABLE EVENT")

local BindableEvent = Game.BindableEvent

test("BindableEvent creation", function()
    local event = BindableEvent.new()

    expect(event ~= nil)

    event:Destroy()
end)

test("BindableEvent firing", function()
    local event = BindableEvent.new()
    local received = false

    event.Event:Connect(function(value)
        received = value
    end)

    event:Fire(true)

    expect(received)

    event:Destroy()
end)

--------------------------------------------------------
-- 17. BINDABLE FUNCTION
--------------------------------------------------------

section("17. BINDABLE FUNCTION")

test("BindableFunction creation", function()
    local callback = Game.BindableFunction.new()

    expect(callback ~= nil)

    callback:Destroy()
end)

test("BindableFunction invocation", function()
    local callback = Game.BindableFunction.new()

    callback.OnInvoke = function(value)
        return value * 2
    end

    local result = callback:Invoke(5)

    equal(result, 10)

    callback:Destroy()
end)

--------------------------------------------------------
-- 18. REMOTE EVENT
--------------------------------------------------------

section("18. REMOTE EVENT")

test("RemoteEvent creation", function()
    local remote = Game.RemoteEvent.new()

    expect(remote ~= nil)

    remote:Destroy()
end)

test("RemoteEvent local player configuration", function()
    local remote = Game.RemoteEvent.new()

    expect(type(remote.SetLocalPlayer) == "function")

    remote:Destroy()
end)

test("RemoteEvent server signal", function()
    local remote = Game.RemoteEvent.new()

    expect(remote.OnServerEvent ~= nil)

    remote:Destroy()
end)

--------------------------------------------------------
-- 19. REMOTE FUNCTION
--------------------------------------------------------

section("19. REMOTE FUNCTION")

test("RemoteFunction creation", function()
    local remote = Game.RemoteFunction.new()

    expect(remote ~= nil)

    remote:Destroy()
end)

test("RemoteFunction callback", function()
    local remote = Game.RemoteFunction.new()

    remote.OnServerInvoke = function(value)
        return value + 10
    end

    local result = remote:InvokeServer(5)

    equal(result, 15)

    remote:Destroy()
end)

--------------------------------------------------------
-- 20. VALUE OBJECTS
--------------------------------------------------------

section("20. VALUE OBJECTS")

local ValueObjects = Game.ValueObjects

test("BoolValue creation", function()
    local object = ValueObjects.new("BoolValue", true)

    equal(object.Value, true)

    object:Destroy()
end)

test("StringValue creation", function()
    local object = ValueObjects.new("StringValue", "FMO")

    equal(object.Value, "FMO")

    object:Destroy()
end)

test("IntValue creation", function()
    local object = ValueObjects.new("IntValue", 42)

    equal(object.Value, 42)

    object:Destroy()
end)

test("NumberValue creation", function()
    local object = ValueObjects.new("NumberValue", 3.14)

    equal(object.Value, 3.14)

    object:Destroy()
end)

test("ObjectValue creation", function()
    local object = ValueObjects.new("ObjectValue", testPart)

    equal(object.Value, testPart)

    object:Destroy()
end)

--------------------------------------------------------
-- 21. OBJECT REGISTRY
--------------------------------------------------------

section("21. OBJECT REGISTRY")

local Registry = Game.ObjectRegistry
local registryPart = Instance.new("Part")

test("Register object", function()
    local id = Game:RegisterObject(registryPart)

    expect(type(id) == "string")
end)

test("Get object ID", function()
    local id = Game:GetObjectId(registryPart)

    expect(type(id) == "string")
end)

test("Get object by ID", function()
    local id = Game:GetObjectId(registryPart)
    local object = Game:GetObjectById(id)

    equal(object, registryPart)
end)

test("Registry contains object", function()
    expect(Registry:Contains(registryPart))
end)

test("Registry statistics", function()
    local stats = Registry:GetStatistics()

    expect(type(stats) == "table")
end)

--------------------------------------------------------
-- 22. PHYSICS
--------------------------------------------------------

section("22. PHYSICS")

local Physics = Game.Physics

local physicsPart = Instance.new("Part")
physicsPart.Name = "FMO_Physics_Test"

physicsPart.Position = {
    X = 0,
    Y = 10,
    Z = 0,
}

physicsPart.Size = {
    X = 2,
    Y = 2,
    Z = 2,
}

test("Physics service exists", function()
    expect(Physics ~= nil)
end)

test("Set gravity", function()
    Physics:SetGravity({
        X = 0,
        Y = -10,
        Z = 0,
    })

    local gravity = Physics:GetGravity()

    equal(gravity.Y, -10)
end)

test("Physics part registration", function()
    local result = Physics:RegisterPart(physicsPart)

    expect(result ~= false)
end)

test("Physics velocity", function()
    Physics:SetVelocity(physicsPart, {
        X = 0,
        Y = 0,
        Z = 0,
    })

    local velocity = Physics:GetVelocity(physicsPart)

    expect(type(velocity) == "table")
end)

test("Physics mass", function()
    Physics:SetMass(physicsPart, 2)

    equal(Physics:GetMass(physicsPart), 2)
end)

test("Physics step", function()
    local result = Physics:Step(0.016)

    expect(result ~= nil)
end)

test("Physics registration status", function()
    expect(Physics:IsRegistered(physicsPart))
end)

--------------------------------------------------------
-- 23. COLLISION SYSTEM
--------------------------------------------------------

section("23. COLLISION SYSTEM")

local CollisionService = Game.CollisionService

local collisionA = Instance.new("Part")
local collisionB = Instance.new("Part")

collisionA.Position = {
    X = 0,
    Y = 0,
    Z = 0,
}

collisionB.Position = {
    X = 0.5,
    Y = 0,
    Z = 0,
}

collisionA.Size = {
    X = 2,
    Y = 2,
    Z = 2,
}

collisionB.Size = {
    X = 2,
    Y = 2,
    Z = 2,
}

test("Collision service exists", function()
    expect(CollisionService ~= nil)
end)

test("Collision registration", function()
    CollisionService:RegisterPart(collisionA)
    CollisionService:RegisterPart(collisionB)

    expect(CollisionService:IsRegistered(collisionA))
    expect(CollisionService:IsRegistered(collisionB))
end)

test("AABB collision detection", function()
    local result = CollisionService:CheckCollision(
        collisionA,
        collisionB
    )

    expect(result == true)
end)

test("Collision step", function()
    local result = CollisionService:Step()

    expect(result ~= nil)
end)

test("Collision statistics", function()
    local stats = CollisionService:GetStatistics()

    expect(type(stats) == "table")
end)

--------------------------------------------------------
-- 24. RUNTIME DIAGNOSTICS
--------------------------------------------------------

section("24. RUNTIME DIAGNOSTICS")

local Diagnostics = Game.Diagnostics

test("Diagnostics exists", function()
    expect(Diagnostics ~= nil)
end)

test("Diagnostics INFO", function()
    local result = Diagnostics:Info(
        "FMO Super Test information",
        "SuperTest"
    )

    expect(result ~= false)
end)

test("Diagnostics WARNING", function()
    local result = Diagnostics:Warning(
        "FMO Super Test warning",
        "SuperTest"
    )

    expect(result ~= false)
end)

test("Diagnostics ERROR", function()
    local result = Diagnostics:Error(
        "FMO Super Test error",
        "SuperTest"
    )

    expect(result ~= false)
end)

test("Diagnostics log retrieval", function()
    local logs = Diagnostics:GetLogs()

    expect(type(logs) == "table")
    expect(#logs > 0)
end)

test("Diagnostics statistics", function()
    local stats = Diagnostics:GetStatistics()

    expect(type(stats) == "table")
end)

--------------------------------------------------------
-- 25. RUNTIME MANAGER
--------------------------------------------------------

section("25. RUNTIME MANAGER")

local RuntimeManager = Game.RuntimeManager

test("RuntimeManager exists", function()
    expect(RuntimeManager ~= nil)
end)

test("RuntimeManager configuration", function()
    local config = RuntimeManager:GetConfiguration()

    expect(type(config) == "table")
end)

test("RuntimeManager status", function()
    local status = Game:GetRuntimeStatus()

    expect(status ~= nil)
end)

test("RuntimeManager statistics", function()
    local stats = RuntimeManager:GetStatistics()

    expect(type(stats) == "table")
end)

--------------------------------------------------------
-- 26. RUNTIME ENVIRONMENT
--------------------------------------------------------

section("26. RUNTIME ENVIRONMENT")

local Environment = Game.Environment

test("Default environment exists", function()
    expect(Environment ~= nil)
end)

test("Default globals", function()
    expect(Environment:GetGlobal("print") ~= nil)
    expect(Environment:GetGlobal("math") ~= nil)
end)

test("Create child environment", function()
    local child = Game:CreateEnvironment("FMO_Test_Environment")

    expect(child ~= nil)
end)

test("Environment inheritance", function()
    local child = Game:CreateEnvironment(
        "FMO_Inheritance_Test",
        {
            FMO_TEST_GLOBAL = 123,
        }
    )

    equal(child:GetGlobal("FMO_TEST_GLOBAL"), 123)
    equal(child:GetGlobal("print"), Environment:GetGlobal("print"))
end)

test("Environment global registration", function()
    local child = Game:CreateEnvironment("FMO_Global_Test")

    local result = child:SetGlobal("FMO_VALUE", 456)

    expect(result)
    equal(child:GetGlobal("FMO_VALUE"), 456)
end)

test("Environment read-only protection", function()
    local child = Game:CreateEnvironment("FMO_ReadOnly_Test")

    child:SetGlobal("LOCKED_VALUE", 10)
    child:SetReadOnly("LOCKED_VALUE", true)

    local result = child:SetGlobal("LOCKED_VALUE", 20)

    expect(not result)
    equal(child:GetGlobal("LOCKED_VALUE"), 10)
end)

test("Environment lock", function()
    local child = Game:CreateEnvironment("FMO_Lock_Test")

    child:Lock()

    expect(child:IsLocked())
end)

--------------------------------------------------------
-- 27. ERROR HANDLER
--------------------------------------------------------

section("27. ERROR HANDLER")

local ErrorHandler = Game.ErrorHandler

test("ErrorHandler exists", function()
    expect(ErrorHandler ~= nil)
end)

local reportedError

test("Error reporting", function()
    reportedError = Game:ReportError(
        "FMO Super Test generated error",
        {
            Source = "SuperTest",
            Category = "TEST",
        }
    )

    expect(reportedError ~= nil)
    expect(reportedError.Id ~= nil)
end)

test("Error retrieval", function()
    local result = ErrorHandler:GetError(reportedError.Id)

    expect(result ~= nil)
    equal(result.Id, reportedError.Id)
end)

test("Error classification", function()
    local result = ErrorHandler:Report(
        "attempt to index a nil value",
        {
            Source = "SuperTest",
        }
    )

    equal(result.Category, "RUNTIME")
end)

test("Error capture", function()
    local successResult = ErrorHandler:Capture(function()
        return 25
    end)

    expect(successResult)
end)

test("Error capture failure", function()
    local successResult = ErrorHandler:Capture(function()
        error("FMO_CAPTURE_TEST")
    end)

    expect(not successResult)
end)

test("Error statistics", function()
    local stats = ErrorHandler:GetStatistics()

    expect(stats.TotalErrors >= 1)
end)

--------------------------------------------------------
-- 28. SCRIPT SANDBOX
--------------------------------------------------------

section("28. SCRIPT SANDBOX")

local sandbox

test("Sandbox creation", function()
    sandbox = Game:CreateSandbox("FMO_SuperTest_Sandbox")

    expect(sandbox ~= nil)
    expect(sandbox:IsActive())
end)

test("Sandbox ID", function()
    expect(type(sandbox:GetId()) == "string")
end)

test("Sandbox default permissions", function()
    expect(sandbox:HasPermission("Basic"))
    expect(sandbox:HasPermission("Math"))

    expect(not sandbox:HasPermission("Game"))
end)

test("Sandbox environment", function()
    local environment = sandbox:GetEnvironment()

    expect(type(environment) == "table")
    expect(environment.math ~= nil)
    expect(environment.print ~= nil)
end)

test("Sandbox restricted Game access", function()
    local environment = sandbox:GetEnvironment()

    expect(environment.game == nil)
end)

test("Sandbox permission granting", function()
    local result = sandbox:Grant("Game")

    expect(result)
    equal(sandbox:GetEnvironment().game, Game)
end)

test("Sandbox global modification protection", function()
    local result = sandbox:SetGlobal("FMO_TEST", 123)

    expect(not result)
end)

test("Sandbox permission-controlled globals", function()
    sandbox:Grant("EnvironmentModification")

    local result = sandbox:SetGlobal("FMO_TEST", 123)

    expect(result)
    equal(sandbox:GetGlobal("FMO_TEST"), 123)
end)

test("Sandbox destruction", function()
    local result = sandbox:Destroy()

    expect(result)
    expect(not sandbox:IsActive())
end)

--------------------------------------------------------
-- 29. RUNTIME STATISTICS
--------------------------------------------------------

section("29. RUNTIME STATISTICS")

local Statistics = Game.RuntimeStatistics

test("RuntimeStatistics exists", function()
    expect(Statistics ~= nil)
end)

test("Counter increment", function()
    Statistics:Increment("FMO_TestCounter", 5)

    equal(
        Statistics:GetCounter("FMO_TestCounter"),
        5
    )
end)

test("Custom values", function()
    Statistics:SetValue("FMO_TestValue", 100)

    equal(
        Statistics:GetValue("FMO_TestValue"),
        100
    )
end)

test("Performance measurement", function()
    local timer = Statistics:BeginMeasure("FMO_TestMeasurement")

    expect(timer ~= nil)

    local elapsed = Statistics:EndMeasure(timer)

    expect(type(elapsed) == "number")
    expect(elapsed >= 0)
end)

test("Performance samples", function()
    Statistics:Record("FMO_TestSamples", 10)
    Statistics:Record("FMO_TestSamples", 20)
    Statistics:Record("FMO_TestSamples", 30)

    local result = Statistics:GetSampleStatistics(
        "FMO_TestSamples"
    )

    expect(result ~= nil)
    equal(result.Count, 3)
    equal(result.Average, 20)
end)

test("Memory information", function()
    local memory = Statistics:GetMemoryUsage()

    expect(type(memory) == "table")
    expect(type(memory.Available) == "boolean")
end)

test("Statistics providers", function()
    local providers = Statistics:GetProviderData()

    expect(type(providers) == "table")
    expect(providers.Scheduler ~= nil)
end)

test("Complete performance report", function()
    local report = Game:GetPerformanceStatistics()

    expect(type(report) == "table")
    expect(report.Counters ~= nil)
    expect(report.Memory ~= nil)
    expect(report.Providers ~= nil)
end)

--------------------------------------------------------
-- 30. INTEGRATED RUNTIME
--------------------------------------------------------

section("30. INTEGRATED RUNTIME")

test("Runtime initialization", function()
    local result = Game:Initialize()

    expect(result ~= false)
end)

test("Runtime start", function()
    local result = Game:Start()

    expect(result ~= false)
end)

test("Integrated runtime step", function()
    local result = Game:Step(0.016)

    expect(type(result) == "table")
    expect(result.Scheduler ~= nil)
    expect(result.Physics ~= nil)
    expect(result.Collisions ~= nil)
end)

test("Frame statistics", function()
    expect(Statistics:GetCounter("Frames") >= 1)
end)

test("Integrated runtime status", function()
    local status = Game:GetRuntimeStatus()

    expect(status ~= nil)
end)

test("Runtime stop", function()
    local result = Game:Stop()

    expect(result ~= false)
end)

--------------------------------------------------------
-- CLEANUP
--------------------------------------------------------

section("CLEANUP")

test("Physics unregister", function()
    Physics:RemovePart(physicsPart)

    expect(not Physics:IsRegistered(physicsPart))
end)

test("Collision unregister", function()
    CollisionService:UnregisterPart(collisionA)
    CollisionService:UnregisterPart(collisionB)

    expect(not CollisionService:IsRegistered(collisionA))
end)

test("Object registry unregister", function()
    local id = Game:GetObjectId(registryPart)

    Registry:Unregister(id)

    expect(not Registry:Contains(registryPart))
end)

test("Instance cleanup", function()
    testFolder:Destroy()
    registryPart:Destroy()
    physicsPart:Destroy()
    collisionA:Destroy()
    collisionB:Destroy()
    lifecycleScript:Destroy()

    expect(testFolder.Parent == nil)
end)

--------------------------------------------------------
-- FINAL REPORT
--------------------------------------------------------

local elapsed = os.clock() - startTime

print("")
print("")
print("========================================================")
print("             FMO LUAU RUNTIME")
print("              FINAL TEST REPORT")
print("========================================================")
print("")

print("Total tests:    " .. tostring(totalTests))
print("Passed:         " .. tostring(passedTests))
print("Failed:         " .. tostring(failedTests))
print("Skipped:        " .. tostring(skippedTests))

print("")
print("Execution time: " .. string.format("%.6f", elapsed) .. " seconds")

local percentage = 0

if totalTests > 0 then
    percentage = (passedTests / totalTests) * 100
end

print("Success rate:   " .. string.format("%.2f", percentage) .. "%")

if #failures > 0 then
    print("")
    print("FAILED TESTS:")
    line()

    for index, item in ipairs(failures) do
        print(
            tostring(index)
            .. ". "
            .. item.Name
        )

        print("   " .. item.Error)
    end
end

print("")
line()

if failedTests == 0 then
    print("       ALL EXECUTED TESTS PASSED!")
else
    print("       SOME TESTS NEED ATTENTION.")
end

print("       FMO LUAU RUNTIME - SUPER TEST 1.0")
line()

print("")
print("[Runtime] Super Test completed.")
print("[Runtime] Test execution finished.")

return {
    Total = totalTests,
    Passed = passedTests,
    Failed = failedTests,
    Skipped = skippedTests,
    SuccessRate = percentage,
    ExecutionTime = elapsed,
    Failures = failures,
}
