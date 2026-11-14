local RuntimeManager = {
    State = "CREATED",

    _systems = {},
    _initialized = false,

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
    },
}

local function safeCall(callback)
    local results = table.pack(pcall(callback))

    if not results[1] then
        RuntimeManager._statistics.Errors += 1

        local diagnostics = RuntimeManager._systems.Diagnostics

        if diagnostics then
            pcall(function()
                diagnostics:Error(
                    "RuntimeManager",
                    tostring(results[2])
                )
            end)
        end

        return false, results[2]
    end

    return true, table.unpack(results, 2, results.n)
end

function RuntimeManager:Configure(systems)
    if type(systems) ~= "table" then
        error("Configure expects a systems table", 2)
    end

    if self.State == "RUNNING" then
        error("Cannot configure a running runtime", 2)
    end

    self._systems = systems

    return true
end

function RuntimeManager:SetConfiguration(name, value)
    if self._configuration[name] == nil then
        error(
            "Unknown runtime configuration: " .. tostring(name),
            2
        )
    end

    if name == "MaximumLogs" then
        if type(value) ~= "number"
            or value < 1
            or value % 1 ~= 0
        then
            error("MaximumLogs must be a positive integer", 2)
        end
    elseif type(value) ~= "boolean" then
        error(name .. " must be a boolean", 2)
    end

    self._configuration[name] = value

    if self._initialized then
        self:ApplyConfiguration()
    end

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
    local config = self._configuration
    local systems = self._systems

    if systems.Physics then
        systems.Physics:SetEnabled(config.PhysicsEnabled)
    end

    if systems.CollisionService then
        systems.CollisionService:SetEnabled(
            config.CollisionEnabled
        )
    end

    if systems.Diagnostics then
        systems.Diagnostics:SetEnabled(
            config.DiagnosticsEnabled
        )

        systems.Diagnostics:SetMaximumLogs(
            config.MaximumLogs
        )
    end

    return true
end

function RuntimeManager:Initialize()
    if self._initialized
        and self.State ~= "SHUTDOWN"
    then
        return true
    end

    local success, err = safeCall(function()
        self:ApplyConfiguration()

        self._initialized = true
        self.State = "READY"

        self._statistics.Initializations += 1
    end)

    if not success then
        self.State = "STOPPED"
        return false, err
    end

    local diagnostics = self._systems.Diagnostics

    if diagnostics then
        pcall(function()
            diagnostics:Info(
                "RuntimeManager",
                "Runtime initialized"
            )
        end)
    end

    return true
end

function RuntimeManager:Start()
    if self.State == "RUNNING" then
        return true
    end

    if not self._initialized
        or self.State == "SHUTDOWN"
    then
        local success, err = self:Initialize()

        if not success then
            return false, err
        end
    end

    local scheduler = self._systems.Scheduler

    if scheduler then
        local success, err = safeCall(function()
            scheduler:Start()
        end)

        if not success then
            return false, err
        end
    end

    self.State = "RUNNING"
    self._statistics.Starts += 1

    local diagnostics = self._systems.Diagnostics

    if diagnostics then
        pcall(function()
            diagnostics:Info(
                "RuntimeManager",
                "Runtime started"
            )
        end)
    end

    return true
end

function RuntimeManager:Stop()
    if self.State ~= "RUNNING" then
        return true
    end

    local scheduler = self._systems.Scheduler

    if scheduler then
        local success, err = safeCall(function()
            scheduler:Stop()
        end)

        if not success then
            return false, err
        end
    end

    self.State = "STOPPED"
    self._statistics.Stops += 1

    local diagnostics = self._systems.Diagnostics

    if diagnostics then
        pcall(function()
            diagnostics:Info(
                "RuntimeManager",
                "Runtime stopped"
            )
        end)
    end

    return true
end

function RuntimeManager:Restart()
    if self.State == "SHUTDOWN" then
        self._initialized = false
    end

    local success, err = self:Stop()

    if not success then
        return false, err
    end

    self._initialized = false

    success, err = self:Initialize()

    if not success then
        return false, err
    end

    self._statistics.Restarts += 1

    return self:Start()
end

function RuntimeManager:Shutdown()
    if self.State == "SHUTDOWN" then
        return true
    end

    local scheduler = self._systems.Scheduler

    if scheduler then
        local success, err = safeCall(function()
            scheduler:Stop()
        end)

        if not success then
            return false, err
        end
    end

    self.State = "SHUTDOWN"
    self._initialized = false

    self._statistics.Shutdowns += 1

    local diagnostics = self._systems.Diagnostics

    if diagnostics then
        pcall(function()
            diagnostics:Info(
                "RuntimeManager",
                "Runtime shutdown"
            )
        end)
    end

    return true
end

function RuntimeManager:GetState()
    return self.State
end

function RuntimeManager:IsRunning()
    return self.State == "RUNNING"
end

function RuntimeManager:IsInitialized()
    return self._initialized
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

function RuntimeManager:GetStatistics()
    return {
        Initializations = self._statistics.Initializations,
        Starts = self._statistics.Starts,
        Stops = self._statistics.Stops,
        Restarts = self._statistics.Restarts,
        Shutdowns = self._statistics.Shutdowns,
        Errors = self._statistics.Errors,
        State = self.State,
    }
end

function RuntimeManager:GetStatus()
    return {
        State = self.State,
        Initialized = self._initialized,
        Running = self:IsRunning(),

        Configuration = self:GetConfiguration(),
        Systems = self:GetSystemStatus(),
        Statistics = self:GetStatistics(),
    }
end

return RuntimeManager
