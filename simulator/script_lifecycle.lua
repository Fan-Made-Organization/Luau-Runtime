local ScriptLifecycle = {
    _scripts = {},
    _nextId = 0,
    _stats = {
        Registered = 0,
        Started = 0,
        Stopped = 0,
        Failed = 0,
    },
}

local VALID_STATES = {
    Registered = true,
    Running = true,
    Paused = true,
    Stopped = true,
    Failed = true,
}

local function isScript(instance)
    if type(instance) ~= "table" then
        return false
    end

    return instance.ClassName == "Script"
        or instance.ClassName == "LocalScript"
end

local function findRecord(self, instance)
    return self._scripts[instance]
end

function ScriptLifecycle:Register(instance)
    if not isScript(instance) then
        error("Register expects a Script or LocalScript")
    end

    if instance.Destroyed then
        error("Cannot register a destroyed script")
    end

    if self._scripts[instance] then
        return self._scripts[instance].Id
    end

    self._nextId = self._nextId + 1

    local record = {
        Id = self._nextId,
        Instance = instance,
        Name = instance.Name,
        State = "Registered",
        CreatedAt = os.clock(),
        StartedAt = nil,
        StoppedAt = nil,
        LastError = nil,
        ExecutionCount = 0,
    }

    self._scripts[instance] = record
    self._stats.Registered = self._stats.Registered + 1

    return record.Id
end

function ScriptLifecycle:Start(instance)
    local record = findRecord(self, instance)

    if not record then
        error("Script is not registered")
    end

    if instance.Destroyed then
        return false, "Script was destroyed"
    end

    if instance.Disabled then
        return false, "Script is disabled"
    end

    if record.State == "Running" then
        return false, "Script is already running"
    end

    if record.State == "Failed" then
        return false, "Failed scripts must be reset before restarting"
    end

    record.State = "Running"
    record.StartedAt = os.clock()
    record.StoppedAt = nil

    self._stats.Started = self._stats.Started + 1

    return true
end

function ScriptLifecycle:Pause(instance)
    local record = findRecord(self, instance)

    if not record then
        return false, "Script is not registered"
    end

    if record.State ~= "Running" then
        return false, "Only running scripts can be paused"
    end

    record.State = "Paused"

    return true
end

function ScriptLifecycle:Resume(instance)
    local record = findRecord(self, instance)

    if not record then
        return false, "Script is not registered"
    end

    if record.State ~= "Paused" then
        return false, "Script is not paused"
    end

    if instance.Destroyed then
        return false, "Script was destroyed"
    end

    if instance.Disabled then
        return false, "Script is disabled"
    end

    record.State = "Running"

    return true
end

function ScriptLifecycle:Stop(instance)
    local record = findRecord(self, instance)

    if not record then
        return false, "Script is not registered"
    end

    if record.State == "Stopped" then
        return false, "Script is already stopped"
    end

    record.State = "Stopped"
    record.StoppedAt = os.clock()

    self._stats.Stopped = self._stats.Stopped + 1

    return true
end

function ScriptLifecycle:Fail(instance, reason)
    local record = findRecord(self, instance)

    if not record then
        return false, "Script is not registered"
    end

    record.State = "Failed"
    record.LastError = tostring(reason or "Unknown error")

    self._stats.Failed = self._stats.Failed + 1

    return true
end

function ScriptLifecycle:Reset(instance)
    local record = findRecord(self, instance)

    if not record then
        return false, "Script is not registered"
    end

    record.State = "Registered"
    record.LastError = nil
    record.StartedAt = nil
    record.StoppedAt = nil

    return true
end

function ScriptLifecycle:Unregister(instance)
    local record = findRecord(self, instance)

    if not record then
        return false
    end

    self._scripts[instance] = nil

    return true
end

function ScriptLifecycle:GetState(instance)
    local record = findRecord(self, instance)

    if not record then
        return nil
    end

    return record.State
end

function ScriptLifecycle:GetInformation(instance)
    local record = findRecord(self, instance)

    if not record then
        return nil
    end

    local information = {}

    for key, value in pairs(record) do
        information[key] = value
    end

    return information
end

function ScriptLifecycle:GetAll()
    local result = {}

    for _, record in pairs(self._scripts) do
        table.insert(result, record)
    end

    table.sort(result, function(a, b)
        return a.Id < b.Id
    end)

    return result
end

function ScriptLifecycle:GetCount()
    local count = 0

    for _ in pairs(self._scripts) do
        count = count + 1
    end

    return count
end

function ScriptLifecycle:GetCountByState(state)
    if not VALID_STATES[state] then
        error("Invalid script state: " .. tostring(state))
    end

    local count = 0

    for _, record in pairs(self._scripts) do
        if record.State == state then
            count = count + 1
        end
    end

    return count
end

function ScriptLifecycle:GetStatistics()
    local statistics = {}

    for key, value in pairs(self._stats) do
        statistics[key] = value
    end

    statistics.Total = self:GetCount()
    statistics.Running = self:GetCountByState("Running")
    statistics.Paused = self:GetCountByState("Paused")
    statistics.Failed = self:GetCountByState("Failed")

    return statistics
end

function ScriptLifecycle:Clear()
    self._scripts = {}
    self._nextId = 0

    self._stats = {
        Registered = 0,
        Started = 0,
        Stopped = 0,
        Failed = 0,
    }
end

return ScriptLifecycle
