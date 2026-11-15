local RuntimeManager = {
    State = "CREATED",

    _systems = {},
    _initialized = false,
    _transitioning = false,
    _lastError = nil,

    _configuration = {
        PhysicsEnabled = true,
        CollisionEnabled = true,
        DiagnosticsEnabled = true,
        MaximumLogs = 2000,
    },

    _statistics = {
        Initializations = 0,
        Starts = 0,
        Stops = 0,
        Restarts = 0,
        Shutdowns = 0,
        Errors = 0,
        ConfigurationUpdates = 0,
    },
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function reportError(message)
    RuntimeManager._lastError = tostring(message)
    RuntimeManager._statistics.Errors += 1

    local diagnostics = RuntimeManager._systems.Diagnostics

    if diagnostics and type(diagnostics.Error) == "function" then
        pcall(function()
            diagnostics:Error(
                "RuntimeManager",
                RuntimeManager._lastError
            )
        end)
    end
end

local function logInfo(message)
    local diagnostics = RuntimeManager._systems.Diagnostics

    if diagnostics and type(diagnostics.Info) == "function" then
        pcall(function()
            diagnostics:Info("RuntimeManager", message)
        end)
    end
end

local function safeCall(callback)
    if type(callback) ~= "function" then
        return false, "Expected a function"
    end

    local results = table.pack(pcall(callback))

    if not results[1] then
        reportError(results[2])
        return false, results[2]
    end

    return true, table.unpack(results, 2, results.n)
end

local function runTransition(callback)
    if RuntimeManager._transitioning then
        return false, "Runtime transition already in progress"
    end

    RuntimeManager._transitioning = true

    local results = table.pack(safeCall(callback))

    RuntimeManager._transitioning = false

    return table.unpack(results, 1, results.n)
end

local function callSystem(system, methodName, ...)
    if not system then
        return true
    end

    local method = system[methodName]

    if type(method) ~= "function" then
        return true
    end

    local args = table.pack(...)

    return safeCall(function()
        return method(system, table.unpack(args, 1, args.n))
    end)
end

--------------------------------------------------------
-- INTERNAL CONFIGURATION
--------------------------------------------------------

local function applyConfigurationInternal()
    local config = RuntimeManager._configuration
    local systems = RuntimeManager._systems

    local success, err

    success, err = callSystem(
        systems.Physics,
        "SetEnabled",
        config.PhysicsEnabled
    )

    if not success then
        return false, err
    end

    success, err = callSystem(
        systems.CollisionService,
        "SetEnabled",
        config.CollisionEnabled
    )

    if not success then
        return false, err
    end

    local diagnostics = systems.Diagnostics

    success, err = callSystem(
        diagnostics,
        "SetEnabled",
        config.DiagnosticsEnabled
    )

    if not success then
        return false, err
    end

    success, err = callSystem(
        diagnostics,
        "SetMaximumLogs",
        config.MaximumLogs
    )

    if not success then
        return false, err
    end

    return true
end

--------------------------------------------------------
-- INTERNAL LIFECYCLE
--------------------------------------------------------

local function initializeInternal()
    if RuntimeManager._initialized
        and RuntimeManager.State ~= "SHUTDOWN"
    then
        return true
    end

    local success, err = applyConfigurationInternal()

    if not success then
        error(err, 0)
    end

    RuntimeManager._initialized = true
    RuntimeManager.State = "READY"

    RuntimeManager._statistics.Initializations += 1

    return true
end

local function startInternal()
    if RuntimeManager.State == "RUNNING" then
        return true
    end

    if RuntimeManager.State == "SHUTDOWN"
        or not RuntimeManager._initialized
    then
        initializeInternal()
    end

    local scheduler = RuntimeManager._systems.Scheduler

    local success, err = callSystem(
        scheduler,
        "Start"
    )

    if not success then
        error(err, 0)
    end

    RuntimeManager.State = "RUNNING"
    RuntimeManager._statistics.Starts += 1

    return true
end

local function stopInternal()
    if RuntimeManager.State ~= "RUNNING" then
        return true
    end

    local scheduler = RuntimeManager._systems.Scheduler

    local success, err = callSystem(
        scheduler,
        "Stop"
    )

    if not success then
        error(err, 0)
    end

    RuntimeManager.State = "STOPPED"
    RuntimeManager._statistics.Stops += 1

    return true
end

--------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------

function RuntimeManager:Configure(systems)
    if type(systems) ~= "table" then
        error("Configure expects a systems table", 2)
    end

    if self.State == "RUNNING" then
        error("Cannot configure a running runtime", 2)
    end

    if self._transitioning then
        error("Cannot configure during a runtime transition", 2)
    end

    self._systems = systems

    if self._initialized then
        local success, err = applyConfigurationInternal()

        if not success then
            return false, err
        end
    end

    return true
end

function RuntimeManager:SetConfiguration(name, value)
    if self._configuration[name] == nil then
        error(
            "Unknown runtime configuration: " .. tostring(name),
            2
        )
    end

    if self._transitioning then
        return false, "Cannot change configuration during a transition"
    end

    if name == "MaximumLogs" then
        if not isFiniteNumber(value)
            or value < 1
            or value % 1 ~= 0
        then
            error("MaximumLogs must be a positive integer", 2)
        end
    elseif type(value) ~= "boolean" then
        error(name .. " must be a boolean", 2)
    end

    local previousValue = self._configuration[name]

    if previousValue == value then
        return true
    end

    self._configuration[name] = value

    if self._initialized then
        local success, err = applyConfigurationInternal()

        if not success then
            self._configuration[name] = previousValue

            applyConfigurationInternal()

            return false, err
        end
    end

    self._statistics.ConfigurationUpdates += 1

    return true
end

function RuntimeManager:GetConfiguration()
    local result = {}

    for name, value in pairs(self._configuration) do
        result[name] = value
    end

    return result
end

function RuntimeManager:ApplyConfiguration()
    if self._transitioning then
        return false, "Runtime transition already in progress"
    end

    return runTransition(function()
        local success, err = applyConfigurationInternal()

        if not success then
            error(err, 0)
        end

        return true
    end)
end

--------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------

function RuntimeManager:Initialize()
    if self._initialized and self.State ~= "SHUTDOWN" then
        return true
    end

    if self._transitioning then
        return false, "Runtime transition already in progress"
    end

    local success, err = runTransition(function()
        return initializeInternal()
    end)

    if not success then
        self.State = "STOPPED"
        self._initialized = false

        return false, err
    end

    logInfo("Runtime initialized")

    return true
end

--------------------------------------------------------
-- START
--------------------------------------------------------

function RuntimeManager:Start()
    if self.State == "RUNNING" then
        return true
    end

    if self._transitioning then
        return false, "Runtime transition already in progress"
    end

    local success, err = runTransition(function()
        return startInternal()
    end)

    if not success then
        self.State = "STOPPED"
        return false, err
    end

    logInfo("Runtime started")

    return true
end

--------------------------------------------------------
-- STOP
--------------------------------------------------------

function RuntimeManager:Stop()
    if self.State ~= "RUNNING" then
        return true
    end

    if self._transitioning then
        return false, "Runtime transition already in progress"
    end

    local success, err = runTransition(function()
        return stopInternal()
    end)

    if not success then
        return false, err
    end

    logInfo("Runtime stopped")

    return true
end

--------------------------------------------------------
-- RESTART
--------------------------------------------------------

function RuntimeManager:Restart()
    if self._transitioning then
        return false, "Runtime transition already in progress"
    end

    local success, err = runTransition(function()
        local scheduler = self._systems.Scheduler

        local stopped, stopError = callSystem(
            scheduler,
            "Stop"
        )

        if not stopped then
            error(stopError, 0)
        end

        self.State = "STOPPED"
        self._initialized = false

        initializeInternal()

        local started, startError = callSystem(
            scheduler,
            "Start"
        )

        if not started then
            error(startError, 0)
        end

        self.State = "RUNNING"

        self._statistics.Restarts += 1
        self._statistics.Starts += 1

        return true
    end)

    if not success then
        self.State = "STOPPED"
        self._initialized = false

        return false, err
    end

    logInfo("Runtime restarted")

    return true
end

--------------------------------------------------------
-- SHUTDOWN
--------------------------------------------------------

function RuntimeManager:Shutdown()
    if self.State == "SHUTDOWN" then
        return true
    end

    if self._transitioning then
        return false, "Runtime transition already in progress"
    end

    local success, err = runTransition(function()
        local scheduler = self._systems.Scheduler

        local stopped, stopError = callSystem(
            scheduler,
            "Stop"
        )

        if not stopped then
            error(stopError, 0)
        end

        self.State = "SHUTDOWN"
        self._initialized = false

        self._statistics.Shutdowns += 1

        return true
    end)

    if not success then
        return false, err
    end

    logInfo("Runtime shutdown")

    return true
end

--------------------------------------------------------
-- STATE
--------------------------------------------------------

function RuntimeManager:GetState()
    return self.State
end

function RuntimeManager:IsRunning()
    return self.State == "RUNNING"
end

function RuntimeManager:IsInitialized()
    return self._initialized
end

function RuntimeManager:IsShutdown()
    return self.State == "SHUTDOWN"
end

--------------------------------------------------------
-- SYSTEMS
--------------------------------------------------------

function RuntimeManager:GetSystem(name)
    return self._systems[name]
end

function RuntimeManager:GetSystemStatus()
    local result = {}

    for name, system in pairs(self._systems) do
        result[name] = {
            Available = system ~= nil,
            Type = type(system),
        }
    end

    return result
end

--------------------------------------------------------
-- ERRORS
--------------------------------------------------------

function RuntimeManager:GetLastError()
    return self._lastError
end

function RuntimeManager:ClearLastError()
    self._lastError = nil
    return true
end

--------------------------------------------------------
-- STATISTICS
--------------------------------------------------------

function RuntimeManager:GetStatistics()
    return {
        Initializations = self._statistics.Initializations,
        Starts = self._statistics.Starts,
        Stops = self._statistics.Stops,
        Restarts = self._statistics.Restarts,
        Shutdowns = self._statistics.Shutdowns,
        Errors = self._statistics.Errors,
        ConfigurationUpdates = self._statistics.ConfigurationUpdates,

        State = self.State,
        Transitioning = self._transitioning,
        Initialized = self._initialized,
    }
end

function RuntimeManager:GetStatus()
    return {
        State = self.State,
        Initialized = self._initialized,
        Running = self:IsRunning(),
        Shutdown = self:IsShutdown(),
        Transitioning = self._transitioning,

        LastError = self._lastError,

        Configuration = self:GetConfiguration(),
        Systems = self:GetSystemStatus(),
        Statistics = self:GetStatistics(),
    }
end

function RuntimeManager:ResetStatistics()
    for name in pairs(self._statistics) do
        self._statistics[name] = 0
    end

    return true
end

return RuntimeManager
