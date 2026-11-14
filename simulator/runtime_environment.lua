local RuntimeEnvironment = {}

local Environment = {}
Environment.__index = Environment

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function createBaseGlobals()
    local globals = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        pairs = pairs,
        next = next,
        pcall = pcall,
        xpcall = xpcall,
        select = select,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        print = print,
        math = math,
        string = string,
        table = table,
        coroutine = coroutine,
        os = os,
    }

    globals.unpack = table.unpack or unpack

    if typeof then
        globals.typeof = typeof
    end

    if warn then
        globals.warn = warn
    end

    return globals
end

function RuntimeEnvironment.new(name, parent)
    local self = setmetatable({}, Environment)

    self.Name = name or "Environment"
    self.Parent = parent

    self._globals = {}
    self._readonly = {}
    self._locked = false

    self._statistics = {
        GlobalRegistrations = 0,
        GlobalReads = 0,
        GlobalUpdates = 0,
        GlobalRemovals = 0,
        EnvironmentsCreated = 0,
    }

    return self
end

function Environment:SetGlobal(name, value)
    assert(type(name) == "string", "Global name must be a string")

    if self._locked then
        return false, "Environment is locked"
    end

    if self._readonly[name] then
        return false, "Global is read-only: " .. name
    end

    if self._globals[name] ~= nil then
        self._statistics.GlobalUpdates += 1
    else
        self._statistics.GlobalRegistrations += 1
    end

    self._globals[name] = value

    return true
end

function Environment:GetGlobal(name)
    assert(type(name) == "string", "Global name must be a string")

    self._statistics.GlobalReads += 1

    local value = self._globals[name]

    if value ~= nil then
        return value
    end

    if self.Parent then
        return self.Parent:GetGlobal(name)
    end

    return nil
end

function Environment:HasGlobal(name)
    if self._globals[name] ~= nil then
        return true
    end

    if self.Parent then
        return self.Parent:HasGlobal(name)
    end

    return false
end

function Environment:RemoveGlobal(name)
    assert(type(name) == "string", "Global name must be a string")

    if self._locked then
        return false, "Environment is locked"
    end

    if self._readonly[name] then
        return false, "Global is read-only: " .. name
    end

    if self._globals[name] == nil then
        return false, "Global does not exist"
    end

    self._globals[name] = nil
    self._statistics.GlobalRemovals += 1

    return true
end

function Environment:GetGlobals(includeParent)
    local result = {}

    if includeParent and self.Parent then
        result = self.Parent:GetGlobals(true)
    end

    for name, value in pairs(self._globals) do
        result[name] = value
    end

    return result
end

function Environment:SetReadOnly(name, enabled)
    assert(type(name) == "string", "Global name must be a string")

    if self._locked then
        return false, "Environment is locked"
    end

    self._readonly[name] = enabled ~= false

    return true
end

function Environment:IsReadOnly(name)
    return self._readonly[name] == true
end

function Environment:Lock()
    self._locked = true
    return true
end

function Environment:Unlock()
    self._locked = false
    return true
end

function Environment:IsLocked()
    return self._locked
end

function Environment:Merge(globals)
    assert(type(globals) == "table", "Expected a table")

    if self._locked then
        return false, "Environment is locked"
    end

    for name, value in pairs(globals) do
        local success, message = self:SetGlobal(name, value)

        if not success then
            return false, message
        end
    end

    return true
end

function Environment:CreateEnvironment(name, overrides)
    local child = RuntimeEnvironment.new(name, self)

    if overrides then
        local success, message = child:Merge(overrides)

        if not success then
            return nil, message
        end
    end

    self._statistics.EnvironmentsCreated += 1

    return child
end

function Environment:GetStatistics()
    return copyTable(self._statistics)
end

function Environment:ResetStatistics()
    for key in pairs(self._statistics) do
        self._statistics[key] = 0
    end
end

function Environment:Clear()
    if self._locked then
        return false, "Environment is locked"
    end

    self._globals = {}
    self._readonly = {}

    return true
end

function Environment:GetName()
    return self.Name
end

function Environment:GetParent()
    return self.Parent
end

local Default = RuntimeEnvironment.new(
    "FMO_Default",
    nil
)

Default:Merge(createBaseGlobals())

Default:SetReadOnly("assert", true)
Default:SetReadOnly("error", true)
Default:SetReadOnly("type", true)
Default:SetReadOnly("typeof", true)
Default:SetReadOnly("pairs", true)
Default:SetReadOnly("ipairs", true)
Default:SetReadOnly("math", true)
Default:SetReadOnly("string", true)
Default:SetReadOnly("table", true)
Default:SetReadOnly("coroutine", true)

RuntimeEnvironment.Environment = Environment
RuntimeEnvironment.Default = Default

function RuntimeEnvironment.Create(name, parent)
    return RuntimeEnvironment.new(name, parent or Default)
end

function RuntimeEnvironment.GetDefault()
    return Default
end

function RuntimeEnvironment.ResetDefault()
    Default:Clear()
    Default:Merge(createBaseGlobals())

    return true
end

return RuntimeEnvironment
