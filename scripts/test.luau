--[[
========================================================
             LUAU RUNTIME
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
print("             LUAU RUNTIME")
print("                SUPER TEST 1.3")
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

test("Instance clone deep-copies mutable properties", function()
    local original = Instance.new("Part")
    original.Position = {1, 2, 3}
    local clone = original:Clone()

    clone.Position[1] = 99

    equal(original.Position[1], 1)
    equal(clone.Position[1], 99)
    clone:Destroy()
    original:Destroy()
end)

test("Instance rejects forged parent tables", function()
    local object = Instance.new("Folder")
    local forged = {
        _isInstance = true,
        _children = {},
        _properties = {},
        _destroyed = false,
    }

    local ok = pcall(function()
        object.Parent = forged
    end)

    expect(not ok)
    equal(object.Parent, nil)
    object:Destroy()
end)

test("Instance rejects circular parent hierarchy", function()
    local parent = Instance.new("Folder")
    local child = Instance.new("Folder")
    child.Parent = parent

    local ok = pcall(function()
        parent.Parent = child
    end)

    expect(not ok)
    equal(parent.Parent, nil)
    equal(child.Parent, parent)
    parent:Destroy()
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

test("Signal DisconnectAll releases callbacks", function()
    local signal = Signal.new()
    local connection = signal:Connect(function() end)

    signal:DisconnectAll()

    expect(not connection:IsConnected())
    equal(connection._callback, nil)
    equal(connection._signal, nil)
    equal(signal:Count(), 0)
    signal:Destroy()
end)

test("Signal DisconnectAll is safe when repeated", function()
    local signal = Signal.new()
    signal:Connect(function() end)

    signal:DisconnectAll()
    signal:DisconnectAll()

    equal(signal:Count(), 0)
    signal:Destroy()
end)

test("Signal callback can disconnect another callback during Fire", function()
    local signal = Signal.new()
    local calls = 0
    local second

    signal:Connect(function()
        calls += 1
        second:Disconnect()
    end)
    second = signal:Connect(function()
        calls += 100
    end)

    signal:Fire()

    equal(calls, 1)
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

local loaderTestModule
local clearCacheTestModule

test("ModuleLoader loads and caches modules", function()
    loaderTestModule = Instance.new("ModuleScript")
    loaderTestModule.Name = "FMO_ModuleLoader_Cache_Test"
    loaderTestModule.Source = "return { Value = 42 }"

    local firstResult = ModuleLoader:Require(loaderTestModule)
    local secondResult = ModuleLoader:Require(loaderTestModule)

    equal(firstResult.Value, 42)
    expect(firstResult == secondResult)
    expect(ModuleLoader:IsLoaded(loaderTestModule))
end)

test("ModuleLoader unload releases cached modules", function()
    expect(ModuleLoader:Unload(loaderTestModule))
    expect(not ModuleLoader:IsLoaded(loaderTestModule))

    loaderTestModule:Destroy()
    loaderTestModule = nil
end)

test("ModuleLoader ClearCache tracks unloaded modules", function()
    clearCacheTestModule = Instance.new("ModuleScript")
    clearCacheTestModule.Name = "FMO_ModuleLoader_ClearCache_Test"
    clearCacheTestModule.Source = "return { Cached = true }"

    ModuleLoader:Require(clearCacheTestModule)

    local previousUnloads = ModuleLoader:GetStatistics().Unloads
    local removed = ModuleLoader:ClearCache()

    expect(removed >= 1)
    expect(not ModuleLoader:IsLoaded(clearCacheTestModule))
    expect(ModuleLoader:GetStatistics().Unloads >= previousUnloads + 1)

    clearCacheTestModule:Destroy()
    clearCacheTestModule = nil
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
-- 30. RUNTIME PROFILER
--------------------------------------------------------

section("30. RUNTIME PROFILER")

local Profiler = Game.RuntimeProfiler
local profilerToken

test("RuntimeProfiler exists and is integrated", function()
    expect(type(Profiler) == "table")
    expect(type(Game.BeginProfile) == "function")
    expect(type(Game.EndProfile) == "function")
    expect(type(Game.Profile) == "function")
end)

test("Profiler begin and end measurement", function()
    profilerToken = Game:BeginProfile("FMO_Test_Profile")

    expect(type(profilerToken) == "table")
    expect(profilerToken.Active)

    -- Public token fields must not be able to rewrite private timing data.
    profilerToken.Name = "FMO_Tampered_Profile"
    profilerToken.StartedAt = -1000000000

    local elapsed = Game:EndProfile(profilerToken)

    expect(type(elapsed) == "number")
    expect(elapsed >= 0)
    expect(not profilerToken.Active)
    expect(Profiler:GetProfile("FMO_Test_Profile") ~= nil)
    equal(Profiler:GetProfile("FMO_Tampered_Profile"), nil)
end)

test("Profiler rejects reused tokens", function()
    local elapsed, message = Game:EndProfile(profilerToken)

    equal(elapsed, nil)
    expect(type(message) == "string")
end)

test("Profiler Measure preserves multiple return values", function()
    local first, second, third = Game:Profile(
        "FMO_Measure_Returns",
        function(a, b)
            return a + b, "FMO", true
        end,
        10,
        15
    )

    equal(first, 25)
    equal(second, "FMO")
    equal(third, true)
end)

test("Profiler records callback errors and rethrows them", function()
    local successResult, message = pcall(function()
        Game:Profile("FMO_Measure_Error", function()
            error("FMO_PROFILE_EXPECTED_ERROR")
        end)
    end)

    expect(not successResult)
    expect(string.find(tostring(message), "FMO_PROFILE_EXPECTED_ERROR", 1, true) ~= nil)
    expect(Profiler:GetStatistics().Failed >= 1)
end)

test("Profiler report contains timing statistics", function()
    local report = Game:GetProfileReport()
    local profile = Profiler:GetProfile("FMO_Measure_Returns")

    expect(type(report) == "table")
    expect(type(profile) == "table")
    equal(profile.Count, 1)
    expect(profile.Total >= 0)
    expect(profile.Average >= 0)
    expect(profile.Latest >= 0)
end)

test("Profiler sample limit is enforced", function()
    Profiler:SetMaximumSamples(2)

    for index = 1, 4 do
        Game:Profile("FMO_Sample_Limit", function()
            return index
        end)
    end

    local profile = Profiler:GetProfile("FMO_Sample_Limit")

    equal(#profile.Samples, 2)
    Profiler:SetMaximumSamples(500)
end)

test("Profiler can be disabled and re-enabled", function()
    Profiler:SetEnabled(false)

    equal(Game:BeginProfile("FMO_Disabled_Profile"), nil)
    equal(Game:Profile("FMO_Disabled_Measure", function()
        return 42
    end), 42)

    Profiler:SetEnabled(true)
    local reenabled = Game:BeginProfile("FMO_Reenabled_Profile")
    expect(reenabled ~= nil)
    expect(Game:EndProfile(reenabled) ~= nil)

    local active = Game:BeginProfile("FMO_Reenabled_Cleanup")
    expect(Game:EndProfile(active) ~= nil)
end)

test("Profiler clear removes completed profile data", function()
    local result = Profiler:Clear("FMO_Sample_Limit")

    expect(result)
    equal(Profiler:GetProfile("FMO_Sample_Limit"), nil)
end)

test("Profiler statistics provider is registered", function()
    local providers = Statistics:GetProviderData()

    expect(type(providers.RuntimeProfiler) == "table")
    expect(providers.RuntimeProfiler.ProfileCount >= 1)
end)


--------------------------------------------------------
-- 30A. MEMORY MANAGER
--------------------------------------------------------

section("30A. MEMORY MANAGER")

local MemoryManager = Game.MemoryManager

test("MemoryManager is integrated", function()
    expect(type(MemoryManager) == "table")
    expect(type(Game.AllocateMemory) == "function")
    expect(type(Game.ReleaseMemory) == "function")
end)

test("Memory allocation", function()
    MemoryManager:Reset()
    local ok, record = MemoryManager:Allocate("test-a", 128, { Tag = "Tests", Owner = "Suite" })
    expect(ok)
    equal(record.Bytes, 128)
    equal(MemoryManager:GetTotalBytes(), 128)
end)

test("Duplicate allocation is rejected", function()
    local ok = MemoryManager:Allocate("test-a", 1)
    expect(not ok)
end)

test("Allocation lookup and existence", function()
    expect(MemoryManager:HasAllocation("test-a"))
    equal(MemoryManager:GetAllocation("test-a").Bytes, 128)
end)

test("Allocation count", function()
    equal(MemoryManager:GetAllocationCount(), 1)
end)

test("Memory resize updates accounting", function()
    expect(MemoryManager:Resize("test-a", 256))
    equal(MemoryManager:GetTotalBytes(), 256)
end)

test("Memory tag update and filtering", function()
    expect(MemoryManager:SetTag("test-a", "Updated"))
    equal(MemoryManager:CountByTag("Updated"), 1)
    expect(MemoryManager:GetByTag("Updated")["test-a"] ~= nil)
end)

test("Memory owner update and filtering", function()
    expect(MemoryManager:TransferOwner("test-a", "Worker"))
    equal(MemoryManager:CountByOwner("Worker"), 1)
    expect(MemoryManager:GetByOwner("Worker")["test-a"] ~= nil)
end)

test("Memory limit rejects over-allocation", function()
    MemoryManager:SetLimit(300)
    local ok = MemoryManager:Allocate("too-large", 100)
    expect(not ok)
    equal(MemoryManager:GetTotalBytes(), 256)
end)

test("Memory available and over-limit information", function()
    equal(MemoryManager:GetAvailableBytes(), 44)
    expect(not MemoryManager:IsOverLimit())
end)

test("Memory snapshot and diff", function()
    local snapshot = MemoryManager:Snapshot()
    MemoryManager:Resize("test-a", 200)
    local diff = MemoryManager:Diff(snapshot)
    equal(diff.Changed["test-a"].Before, 256)
    equal(diff.Changed["test-a"].After, 200)
    equal(diff.DeltaBytes, -56)
end)

test("Memory largest and smallest allocation", function()
    MemoryManager:Allocate("small", 10)
    equal(MemoryManager:GetLargest().Id, "test-a")
    equal(MemoryManager:GetSmallest().Id, "small")
end)

test("Memory top allocations are sorted", function()
    local top = MemoryManager:GetTop(2)
    equal(#top, 2)
    equal(top[1].Id, "test-a")
end)

test("Memory validation confirms accounting", function()
    local ok, details = MemoryManager:Validate()
    expect(ok)
    expect(details.AllocationCount == 2)
end)

test("Memory statistics expose counters", function()
    local stats = MemoryManager:GetStatistics()
    expect(stats.Allocations >= 2)
    expect(stats.Resizes >= 2)
end)

test("Memory release is idempotent", function()
    expect(MemoryManager:Release("small"))
    expect(not MemoryManager:Release("small"))
end)

test("Memory manager can be disabled", function()
    MemoryManager:SetEnabled(false)
    local ok = MemoryManager:Allocate("disabled", 1)
    expect(not ok)
    MemoryManager:SetEnabled(true)
end)

test("Memory manager clear releases all records", function()
    equal(MemoryManager:Clear(), 1)
    equal(MemoryManager:GetAllocationCount(), 0)
    equal(MemoryManager:GetTotalBytes(), 0)
end)

test("Memory manager reset restores defaults", function()
    MemoryManager:SetLimit(100)
    MemoryManager:Reset()
    equal(MemoryManager:GetLimit(), math.huge)
    equal(MemoryManager:GetPeakBytes(), 0)
end)

--------------------------------------------------------
-- 30B. EVENT MANAGER
--------------------------------------------------------

section("30B. EVENT MANAGER")

local EventManager = Game.EventManager

test("EventManager is integrated", function()
    expect(type(EventManager) == "table")
    expect(type(Game.SubscribeEvent) == "function")
    expect(type(Game.PublishEvent) == "function")
end)

test("Event creation and existence", function()
    EventManager:Reset()
    equal(EventManager:Create("Suite.Ready"), "Suite.Ready")
    expect(EventManager:Exists("Suite.Ready"))
end)

test("Event subscription and delivery", function()
    local received
    EventManager:Subscribe("Suite.Ready", function(value) received = value end)
    local delivered, failed = EventManager:Publish("Suite.Ready", 42)
    equal(received, 42)
    equal(delivered, 1)
    equal(failed, 0)
end)

test("Event listener count", function()
    equal(EventManager:GetListenerCount("Suite.Ready"), 1)
    expect(EventManager:HasListeners("Suite.Ready"))
end)

test("Event connection disconnect", function()
    local connection = EventManager:Subscribe("Suite.Disconnect", function() end)
    expect(connection:IsConnected())
    expect(connection:Disconnect())
    expect(not connection:IsConnected())
end)

test("Event once subscription", function()
    local count = 0
    EventManager:Once("Suite.Once", function() count += 1 end)
    EventManager:Publish("Suite.Once")
    EventManager:Publish("Suite.Once")
    equal(count, 1)
end)

test("Event listener priority", function()
    local order = {}
    EventManager:Subscribe("Suite.Priority", function() order[#order + 1] = "low" end, { Priority = 1 })
    EventManager:Subscribe("Suite.Priority", function() order[#order + 1] = "high" end, { Priority = 10 })
    EventManager:Publish("Suite.Priority")
    equal(order[1], "high")
    equal(order[2], "low")
end)

test("Event callback failures are isolated", function()
    EventManager:Subscribe("Suite.Errors", function() error("expected event failure") end)
    EventManager:Subscribe("Suite.Errors", function() end)
    local delivered, failed = EventManager:Publish("Suite.Errors")
    equal(delivered, 1)
    equal(failed, 1)
end)

test("Safe event publishing reports failures", function()
    local ok, delivered, failed = EventManager:PublishSafe("Suite.Errors")
    expect(not ok)
    equal(delivered, 1)
    equal(failed, 1)
end)

test("Event pause and resume", function()
    local count = 0
    EventManager:Subscribe("Suite.Pause", function() count += 1 end)
    expect(EventManager:Pause("Suite.Pause"))
    EventManager:Publish("Suite.Pause")
    equal(count, 0)
    expect(EventManager:Resume("Suite.Pause"))
    EventManager:Publish("Suite.Pause")
    equal(count, 1)
end)

test("Global event disable and enable", function()
    local count = 0
    EventManager:Subscribe("Suite.Enabled", function() count += 1 end)
    EventManager:SetEnabled(false)
    EventManager:Publish("Suite.Enabled")
    equal(count, 0)
    EventManager:SetEnabled(true)
    EventManager:Publish("Suite.Enabled")
    equal(count, 1)
end)

test("Event listener limit", function()
    EventManager:SetMaximumListeners(1)
    EventManager:Clear("Suite.Limit")
    EventManager:Subscribe("Suite.Limit", function() end)
    local connection = EventManager:Subscribe("Suite.Limit", function() end)
    equal(connection, nil)
    EventManager:SetMaximumListeners(100)
end)

test("Event history is bounded", function()
    EventManager:SetHistoryLimit(2)
    EventManager:Publish("Suite.History", 1)
    EventManager:Publish("Suite.History", 2)
    EventManager:Publish("Suite.History", 3)
    equal(#EventManager:GetHistory(), 2)
    EventManager:SetHistoryLimit(100)
end)

test("Event history filtering", function()
    local history = EventManager:GetHistory("Suite.History")
    equal(#history, 2)
    equal(history[2].Arguments[1], 3)
end)

test("Event batch publishing", function()
    local sum = 0
    EventManager:Subscribe("Suite.Batch", function(value) sum += value end)
    local delivered, failed = EventManager:EmitMany("Suite.Batch", {{1}, {2}, {3}})
    equal(delivered, 3)
    equal(failed, 0)
    equal(sum, 6)
end)

test("Event names are sorted", function()
    local names = EventManager:GetEventNames()
    expect(#names > 0)
    for index = 2, #names do expect(names[index - 1] <= names[index]) end
end)

test("Event statistics report activity", function()
    local stats = EventManager:GetStatistics()
    expect(stats.Published >= 1)
    expect(stats.Subscriptions >= 1)
    expect(stats.Delivered >= 1)
end)

test("Event clear removes listeners", function()
    expect(EventManager:Clear("Suite.Ready"))
    equal(EventManager:GetListenerCount("Suite.Ready"), 0)
end)

test("Event manager reset restores defaults", function()
    EventManager:Reset()
    expect(EventManager:IsEnabled())
    equal(EventManager:GetMaximumListeners(), 100)
    equal(EventManager:GetStatistics().Events, 0)
end)



--------------------------------------------------------
-- 30C. RESOURCE MANAGER
--------------------------------------------------------

section("30C. RESOURCE MANAGER")

local ResourceManager = Game.ResourceManager

test("ResourceManager is integrated", function()
    expect(type(ResourceManager) == "table")
    expect(type(Game.RegisterResource) == "function")
end)

test("Resource registration and lookup", function()
    ResourceManager:Reset()
    local ok, resource = ResourceManager:Register("resource-a", { Value = 7 }, { Tag = "Suite" })
    expect(ok)
    equal(resource.Id, "resource-a")
    expect(ResourceManager:Has("resource-a"))
    equal(ResourceManager:Get("resource-a").Value.Value, 7)
end)

test("Resource duplicate registration is rejected", function()
    local ok = ResourceManager:Register("resource-a", {})
    expect(not ok)
end)

test("Resource metadata and tag updates", function()
    expect(ResourceManager:SetMetadata("resource-a", { Revision = 2 }))
    expect(ResourceManager:SetTag("resource-a", "Changed"))
    equal(ResourceManager:FindByTag("Changed")[1].Id, "resource-a")
end)

test("Resource type counts and listing", function()
    ResourceManager:Register("resource-b", function() end, { Type = "Callback" })
    equal(ResourceManager:CountByType("Callback"), 1)
    equal(#ResourceManager:List(), 2)
end)

test("Resource scope registration", function()
    local scope = ResourceManager:CreateScope("test-scope")
    local ok = ResourceManager:Register("scoped", {}, { Scope = scope })
    expect(ok)
    equal(#ResourceManager:GetScopeResources(scope), 1)
end)

test("Resource transfer between scopes", function()
    local other = ResourceManager:CreateScope("other")
    expect(ResourceManager:Transfer("scoped", other))
    equal(#ResourceManager:GetScopeResources(other), 1)
end)

test("Resource dependencies are tracked", function()
    expect(ResourceManager:AddDependency("resource-a", "resource-b"))
    equal(ResourceManager:GetDependencies("resource-a")[1], "resource-b")
    equal(ResourceManager:GetDependents("resource-b")[1], "resource-a")
end)

test("Resource cleanup callback runs once", function()
    local calls = 0
    ResourceManager:Register("cleanup", {}, { Cleanup = function() calls += 1 end })
    expect(ResourceManager:Release("cleanup"))
    expect(not ResourceManager:Release("cleanup"))
    equal(calls, 1)
end)

test("Resource release by tag", function()
    ResourceManager:Register("tagged-a", {}, { Tag = "bulk" })
    ResourceManager:Register("tagged-b", {}, { Tag = "bulk" })
    local released, failed = ResourceManager:ReleaseByTag("bulk")
    equal(released, 2)
    equal(failed, 0)
end)

test("Resource scope releases in reverse order", function()
    local order = {}
    local scope = ResourceManager:CreateScope("cleanup-order")
    ResourceManager:Register("order-1", {}, { Scope = scope, Cleanup = function() order[#order + 1] = 1 end })
    ResourceManager:Register("order-2", {}, { Scope = scope, Cleanup = function() order[#order + 1] = 2 end })
    local ok, report = ResourceManager:ReleaseScope(scope)
    expect(ok)
    equal(report.Released, 2)
    equal(order[1], 2)
    equal(order[2], 1)
end)

test("Resource manager validates records", function()
    expect(ResourceManager:Validate())
end)

test("Resource manager statistics are available", function()
    local stats = ResourceManager:GetStatistics()
    expect(stats.Registered >= 5)
    expect(stats.Released >= 3)
end)

test("Resource manager clear removes remaining resources", function()
    ResourceManager:Clear()
    equal(ResourceManager:Count(), 0)
end)

test("Resource manager reset restores counters", function()
    ResourceManager:Reset()
    equal(ResourceManager:GetStatistics().Registered, 0)
end)

--------------------------------------------------------
-- 30D. RUNTIME DEBUGGER
--------------------------------------------------------

section("30D. RUNTIME DEBUGGER")

local RuntimeDebugger = Game.RuntimeDebugger

test("RuntimeDebugger is integrated", function()
    expect(type(RuntimeDebugger) == "table")
end)

test("Debugger breakpoint creation and lookup", function()
    RuntimeDebugger:Reset()
    local key = RuntimeDebugger:AddBreakpoint("sample.luau", 12)
    equal(key, "sample.luau:12")
    expect(RuntimeDebugger:HasBreakpoint("sample.luau", 12))
    equal(RuntimeDebugger:GetBreakpoint("sample.luau", 12).Line, 12)
end)

test("Debugger breakpoint hit tracking", function()
    expect(RuntimeDebugger:CheckBreakpoint("sample.luau", 12))
    equal(RuntimeDebugger:GetBreakpoint("sample.luau", 12).HitCount, 1)
end)

test("Debugger breakpoint conditions", function()
    RuntimeDebugger:AddBreakpoint("conditional.luau", 3, { Condition = function(context) return context.Ready end })
    expect(not RuntimeDebugger:CheckBreakpoint("conditional.luau", 3, { Ready = false }))
    expect(RuntimeDebugger:CheckBreakpoint("conditional.luau", 3, { Ready = true }))
end)

test("Debugger breakpoint hit limit", function()
    RuntimeDebugger:AddBreakpoint("limited.luau", 4, { HitLimit = 1 })
    expect(RuntimeDebugger:CheckBreakpoint("limited.luau", 4))
    expect(not RuntimeDebugger:CheckBreakpoint("limited.luau", 4))
end)

test("Debugger breakpoint enable and remove", function()
    RuntimeDebugger:AddBreakpoint("toggle.luau", 5)
    expect(RuntimeDebugger:EnableBreakpoint("toggle.luau", 5, false))
    expect(not RuntimeDebugger:CheckBreakpoint("toggle.luau", 5))
    expect(RuntimeDebugger:RemoveBreakpoint("toggle.luau", 5))
end)

test("Debugger lists breakpoints deterministically", function()
    local list = RuntimeDebugger:ListBreakpoints()
    expect(#list >= 1)
    for index = 2, #list do expect(list[index - 1].Key <= list[index].Key) end
end)

test("Debugger watch registration and evaluation", function()
    local value = 15
    RuntimeDebugger:AddWatch("value", function() return value end)
    equal(RuntimeDebugger:EvaluateWatch("value"), 15)
    value = 22
    equal(RuntimeDebugger:EvaluateWatch("value"), 22)
end)

test("Debugger watch errors are isolated", function()
    RuntimeDebugger:AddWatch("broken", function() error("watch failed") end)
    local result, err = RuntimeDebugger:EvaluateWatch("broken")
    equal(result, nil)
    expect(type(err) == "string")
end)

test("Debugger evaluates all watches", function()
    local result = RuntimeDebugger:EvaluateAllWatches()
    equal(result.value.Value, 22)
    expect(result.broken.Error ~= nil)
end)

test("Debugger removes watches", function()
    expect(RuntimeDebugger:RemoveWatch("value"))
    expect(not RuntimeDebugger:HasWatch("value"))
end)

test("Debugger trace recording and filtering", function()
    RuntimeDebugger:Trace("INFO", "started", { Frame = 1 })
    RuntimeDebugger:Trace("WARN", "slow frame")
    equal(#RuntimeDebugger:GetTrace("INFO"), 1)
    equal(RuntimeDebugger:GetTrace("INFO")[1].Data.Frame, 1)
end)

test("Debugger trace history is bounded", function()
    RuntimeDebugger:SetMaximumTraceEntries(2)
    RuntimeDebugger:Trace("TEST", "one")
    RuntimeDebugger:Trace("TEST", "two")
    RuntimeDebugger:Trace("TEST", "three")
    equal(#RuntimeDebugger:GetTrace(), 2)
    RuntimeDebugger:SetMaximumTraceEntries(500)
end)

test("Debugger snapshots are copied", function()
    local original = { Score = 10 }
    RuntimeDebugger:Snapshot("before", original)
    original.Score = 99
    equal(RuntimeDebugger:GetSnapshot("before").Value.Score, 10)
end)

test("Debugger compares snapshots", function()
    RuntimeDebugger:Snapshot("after", { Score = 20, Level = 2 })
    local diff = RuntimeDebugger:CompareSnapshots("before", "after")
    expect(diff.Changed)
    equal(diff.Properties.Score.Before, 10)
    equal(diff.Properties.Score.After, 20)
end)

test("Debugger inspects values", function()
    local info = RuntimeDebugger:Inspect({ A = 1, B = true })
    equal(info.Type, "table")
    equal(info.Count, 2)
    equal(info.Preview.A, 1)
end)

test("Debugger disable suppresses tracing and breakpoints", function()
    RuntimeDebugger:SetEnabled(false)
    expect(not RuntimeDebugger:Trace("OFF", "ignored"))
    expect(not RuntimeDebugger:CheckBreakpoint("sample.luau", 12))
    RuntimeDebugger:SetEnabled(true)
end)

test("Debugger statistics and clear", function()
    expect(RuntimeDebugger:GetStatistics().Traces >= 2)
    RuntimeDebugger:Clear()
    equal(#RuntimeDebugger:ListBreakpoints(), 0)
    equal(#RuntimeDebugger:GetTrace(), 0)
end)



--------------------------------------------------------
-- 30E. PERFORMANCE MONITOR
--------------------------------------------------------

section("30E. PERFORMANCE MONITOR")

local PerformanceMonitor = Game.PerformanceMonitor

test("PerformanceMonitor is integrated", function()
    expect(type(PerformanceMonitor) == "table")
    expect(type(Game.MeasurePerformance) == "function")
end)

test("Performance metric recording", function()
    PerformanceMonitor:Reset()
    expect(PerformanceMonitor:Record("frame", 10))
    expect(PerformanceMonitor:Record("frame", 20))
    equal(PerformanceMonitor:GetCount("frame"), 2)
    equal(PerformanceMonitor:GetAverage("frame"), 15)
end)

test("Performance metric min max and latest", function()
    equal(PerformanceMonitor:GetMinimum("frame"), 10)
    equal(PerformanceMonitor:GetMaximum("frame"), 20)
    equal(PerformanceMonitor:GetLatest("frame"), 20)
end)

test("Performance timer lifecycle", function()
    local timer = PerformanceMonitor:StartTimer("manual")
    expect(timer ~= nil)
    local elapsed = PerformanceMonitor:StopTimer(timer)
    expect(type(elapsed) == "number")
    expect(elapsed >= 0)
    equal(PerformanceMonitor:StopTimer(timer), nil)
end)

test("Performance callback measurement preserves results", function()
    local first, second = PerformanceMonitor:Measure("callback", function(a,b) return a+b,"ok" end, 2,3)
    equal(first, 5)
    equal(second, "ok")
    expect(PerformanceMonitor:GetCount("callback") == 1)
end)

test("Performance measurement rethrows callback errors", function()
    local ok = pcall(function()
        PerformanceMonitor:Measure("failure", function() error("expected") end)
    end)
    expect(not ok)
    expect(PerformanceMonitor:GetStatistics().Errors >= 1)
end)

test("Performance sample limit is enforced", function()
    PerformanceMonitor:SetSampleLimit(2)
    PerformanceMonitor:Record("bounded", 1)
    PerformanceMonitor:Record("bounded", 2)
    PerformanceMonitor:Record("bounded", 3)
    equal(#PerformanceMonitor:GetSamples("bounded"), 2)
    equal(PerformanceMonitor:GetAverage("bounded"), 2.5)
    PerformanceMonitor:SetSampleLimit(500)
end)

test("Performance budgets detect overruns", function()
    PerformanceMonitor:SetBudget("frame", 15)
    expect(PerformanceMonitor:IsOverBudget("frame"))
    equal(PerformanceMonitor:GetOverBudgetMetrics()[1], "frame")
end)

test("Performance marks and snapshots", function()
    PerformanceMonitor:Mark("checkpoint", { Frame = 3 })
    PerformanceMonitor:Snapshot("first")
    PerformanceMonitor:Record("frame", 30)
    PerformanceMonitor:Snapshot("second")
    expect(PerformanceMonitor:CompareSnapshots("first", "second").Changed)
    equal(#PerformanceMonitor:GetMarks("checkpoint"), 1)
end)

test("Performance metric names are sorted", function()
    local names = PerformanceMonitor:GetMetricNames()
    for index = 2, #names do expect(names[index - 1] <= names[index]) end
end)

test("Performance metric clear and enable controls", function()
    expect(PerformanceMonitor:ClearMetric("bounded"))
    PerformanceMonitor:SetEnabled(false)
    expect(not PerformanceMonitor:Record("ignored", 1))
    PerformanceMonitor:SetEnabled(true)
end)

test("Performance monitor statistics and reset", function()
    expect(PerformanceMonitor:GetStatistics().Records >= 1)
    PerformanceMonitor:Reset()
    equal(PerformanceMonitor:GetStatistics().MetricCount, 0)
end)

--------------------------------------------------------
-- 30F. TASK QUEUE
--------------------------------------------------------

section("30F. TASK QUEUE")

local TaskQueue = Game.TaskQueue

test("TaskQueue is integrated", function()
    expect(type(TaskQueue) == "table")
    expect(type(Game.EnqueueTask) == "function")
end)

test("Task queue enqueue and lookup", function()
    TaskQueue:Reset()
    local id = TaskQueue:Enqueue(function() return 7 end, { Label = "lookup" })
    expect(TaskQueue:Has(id))
    equal(TaskQueue:Get(id).Label, "lookup")
    equal(TaskQueue:GetCount(), 1)
end)

test("Task queue executes ready tasks", function()
    local value
    TaskQueue:Enqueue(function() value = 99 end)
    local ran, failed = TaskQueue:RunAll()
    equal(ran, 1)
    equal(failed, 0)
    equal(value, 99)
end)

test("Task queue respects priority", function()
    local order = {}
    TaskQueue:Enqueue(function() order[#order+1] = "low" end, { Priority = 1 })
    TaskQueue:Enqueue(function() order[#order+1] = "high" end, { Priority = 10 })
    TaskQueue:RunAll()
    equal(order[1], "high")
    equal(order[2], "low")
end)

test("Task queue delays tasks until clock advances", function()
    local ran = false
    TaskQueue:Delay(5, function() ran = true end)
    TaskQueue:RunAll()
    expect(not ran)
    equal(TaskQueue:Advance(5), 5)
    TaskQueue:RunAll()
    expect(ran)
end)

test("Task queue cancellation", function()
    local id = TaskQueue:Defer(function() error("must not run") end)
    expect(TaskQueue:Cancel(id))
    expect(not TaskQueue:Has(id))
end)

test("Task queue pause and resume", function()
    local count = 0
    TaskQueue:Enqueue(function() count += 1 end)
    TaskQueue:Pause()
    TaskQueue:RunAll()
    equal(count, 0)
    TaskQueue:Resume()
    TaskQueue:RunAll()
    equal(count, 1)
end)

test("Task queue isolates callback errors", function()
    TaskQueue:Enqueue(function() error("expected task error") end)
    TaskQueue:Enqueue(function() end)
    local ran, failed = TaskQueue:RunAll()
    equal(ran, 2)
    equal(failed, 1)
end)

test("Task queue execution limit", function()
    TaskQueue:Enqueue(function() end)
    TaskQueue:Enqueue(function() end)
    local ran = TaskQueue:RunAll(1)
    equal(ran, 1)
    equal(TaskQueue:GetPendingCount(), 1)
end)

test("Task queue history and statistics", function()
    TaskQueue:RunAll()
    expect(#TaskQueue:GetHistory() >= 1)
    expect(TaskQueue:GetStatistics().Executed >= 1)
    expect(TaskQueue:GetStatistics().Failed >= 1)
end)

test("Task queue history limit", function()
    TaskQueue:SetHistoryLimit(1)
    TaskQueue:Enqueue(function() end)
    TaskQueue:Enqueue(function() end)
    TaskQueue:RunAll()
    equal(#TaskQueue:GetHistory(), 1)
    TaskQueue:SetHistoryLimit(200)
end)

test("Task queue capacity", function()
    TaskQueue:SetMaximumTasks(1)
    TaskQueue:Enqueue(function() end)
    local id = TaskQueue:Enqueue(function() end)
    equal(id, nil)
    TaskQueue:Clear()
    TaskQueue:SetMaximumTasks(10000)
end)

test("Task queue reset restores defaults", function()
    TaskQueue:Reset()
    equal(TaskQueue:GetTime(), 0)
    equal(TaskQueue:GetMaximumTasks(), 10000)
    expect(TaskQueue:IsEnabled())
end)


--------------------------------------------------------
-- 31. INTEGRATED RUNTIME
--------------------------------------------------------

section("31. INTEGRATED RUNTIME")

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

    expect(Profiler:GetProfile("Game.Step") ~= nil)
    expect(Profiler:GetProfile("Scheduler.Step") ~= nil)
    expect(Profiler:GetProfile("Physics.Step") ~= nil)
    expect(Profiler:GetProfile("Collision.Step") ~= nil)
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
print("             LUAU RUNTIME")
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

print("       LUAU RUNTIME - SUPER TEST 1.3")
line()

print("")
print("[Runtime] Super Test completed.")
print("[Runtime] Test execution finished.")

-- Return values are useful to callers, but the CLI also needs a failing
-- process exit code so CI cannot report a false positive.
if failedTests > 0 then
    error(
        string.format(
            "Luau Super Test failed: %d of %d tests failed",
            failedTests,
            totalTests
        ),
        0
    )
end

return {
    Total = totalTests,
    Passed = passedTests,
    Failed = failedTests,
    Skipped = skippedTests,
    SuccessRate = percentage,
    ExecutionTime = elapsed,
    Failures = failures,
}
