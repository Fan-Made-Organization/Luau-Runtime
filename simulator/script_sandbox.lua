local RuntimeEnvironment = require("./runtime_environment")

local ScriptSandbox = {}

ScriptSandbox._sandboxes = {}
ScriptSandbox._nextId = 1

ScriptSandbox._statistics = {
    Created = 0,
    Destroyed = 0,
    Active = 0,
    PermissionChanges = 0,
    GlobalRegistrations = 0,
    RejectedAccesses = 0,
}

local Sandbox = {}
Sandbox.__index = Sandbox

local DEFAULT_PERMISSIONS = {
    Basic = true,
    Math = true,
    String = true,
    Table = true,
    Coroutine = true,
    Game = false,
    Workspace = false,
    Services = false,
    InstanceCreation = false,
    Task = false,
    EnvironmentModification = false,
}

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function deepReadOnly(source, cache)
    if type(source) ~= "table" then
        return source
    end

    cache = cache or {}

    if cache[source] then
        return cache[source]
    end

    local proxy = {}
    cache[source] = proxy

    local values = {}

    for key, value in pairs(source) do
        values[key] = deepReadOnly(value, cache)
    end

    return setmetatable(proxy, {
        __index = values,

        __newindex = function()
            error("Attempt to modify a read-only library", 2)
        end,

        __pairs = function()
            return pairs(values)
        end,

        __len = function()
            return #values
        end,

        __metatable = "Protected",
    })
end

local function getSafeGlobals(permissions)
    local default = RuntimeEnvironment.GetDefault()
    local globals = {}

    local basicGlobals = {
        "assert",
        "error",
        "ipairs",
        "pairs",
        "next",
        "pcall",
        "xpcall",
        "select",
        "tonumber",
        "tostring",
        "type",
        "typeof",
        "print",
        "warn",
        "unpack",
    }

    if permissions.Basic then
        for _, name in ipairs(basicGlobals) do
            local value = default:GetGlobal(name)

            if value ~= nil then
                globals[name] = value
            end
        end
    end

    if permissions.Math then
        globals.math = deepReadOnly(default:GetGlobal("math"))
    end

    if permissions.String then
        globals.string = deepReadOnly(default:GetGlobal("string"))
    end

    if permissions.Table then
        globals.table = deepReadOnly(default:GetGlobal("table"))
    end

    if permissions.Coroutine then
        globals.coroutine = deepReadOnly(default:GetGlobal("coroutine"))
    end

    return globals
end

function Sandbox:GetId()
    return self.Id
end

function Sandbox:GetName()
    return self.Name
end

function Sandbox:IsActive()
    return self.Active
end

function Sandbox:GetPermission(name)
    return self.Permissions[name] == true
end

function Sandbox:GetPermissions()
    return copyTable(self.Permissions)
end

function Sandbox:SetPermission(name, enabled)
    if not self.Active then
        return false, "Sandbox is destroyed"
    end

    if type(name) ~= "string" then
        return false, "Permission name must be a string"
    end

    self.Permissions[name] = enabled == true

    self._statistics.PermissionChanges += 1
    ScriptSandbox._statistics.PermissionChanges += 1

    self:RefreshEnvironment()

    return true
end

function Sandbox:Grant(name)
    return self:SetPermission(name, true)
end

function Sandbox:Revoke(name)
    return self:SetPermission(name, false)
end

function Sandbox:HasPermission(name)
    return self.Permissions[name] == true
end

function Sandbox:SetGlobal(name, value)
    if not self.Active then
        return false, "Sandbox is destroyed"
    end

    if not self:HasPermission("EnvironmentModification") then
        ScriptSandbox._statistics.RejectedAccesses += 1
        self._statistics.RejectedAccesses += 1

        return false, "Environment modification is not permitted"
    end

    if type(name) ~= "string" then
        return false, "Global name must be a string"
    end

    self._globals[name] = value
    self._statistics.GlobalRegistrations += 1

    self:RefreshEnvironment()

    return true
end

function Sandbox:GetGlobal(name)
    if not self.Active then
        return nil
    end

    return self._globals[name]
end

function Sandbox:RemoveGlobal(name)
    if not self.Active then
        return false, "Sandbox is destroyed"
    end

    if not self:HasPermission("EnvironmentModification") then
        ScriptSandbox._statistics.RejectedAccesses += 1
        self._statistics.RejectedAccesses += 1

        return false, "Environment modification is not permitted"
    end

    self._globals[name] = nil

    self:RefreshEnvironment()

    return true
end

function Sandbox:RefreshEnvironment()
    if not self.Active then
        return false
    end

    local environment = getSafeGlobals(self.Permissions)

    for name, value in pairs(self._globals) do
        environment[name] = value
    end

    if self.Permissions.Game and self._game then
        environment.game = self._game
    end

    if self.Permissions.Workspace and self._workspace then
        environment.workspace = self._workspace
    end

    if self.Permissions.Task and self._task then
        environment.task = self._task
    end

    if self.Permissions.InstanceCreation and self._instance then
        environment.Instance = self._instance
    end

    self._environment = environment

    return true
end

function Sandbox:GetEnvironment()
    if not self.Active then
        return nil
    end

    return self._environment
end

function Sandbox:GetStatistics()
    local result = copyTable(self._statistics)

    result.Id = self.Id
    result.Name = self.Name
    result.Active = self.Active

    return result
end

function Sandbox:Destroy()
    if not self.Active then
        return false
    end

    self.Active = false
    self._environment = nil
    self._globals = {}

    ScriptSandbox._sandboxes[self.Id] = nil

    ScriptSandbox._statistics.Destroyed += 1
    ScriptSandbox._statistics.Active -= 1

    return true
end

function ScriptSandbox.Create(name, options)
    options = options or {}

    local id = string.format("FMO-SBX-%08d", ScriptSandbox._nextId)
    ScriptSandbox._nextId += 1

    local permissions = copyTable(DEFAULT_PERMISSIONS)

    if options.Permissions then
        for permission, enabled in pairs(options.Permissions) do
            permissions[permission] = enabled == true
        end
    end

    local sandbox = setmetatable({
        Id = id,
        Name = name or "Sandbox",
        Active = true,

        Permissions = permissions,

        _globals = {},
        _environment = {},

        _game = options.Game,
        _workspace = options.Workspace,
        _task = options.Task,
        _instance = options.Instance,

        _statistics = {
            PermissionChanges = 0,
            GlobalRegistrations = 0,
            RejectedAccesses = 0,
        },
    }, Sandbox)

    sandbox:RefreshEnvironment()

    ScriptSandbox._sandboxes[id] = sandbox

    ScriptSandbox._statistics.Created += 1
    ScriptSandbox._statistics.Active += 1

    return sandbox
end

function ScriptSandbox.Get(id)
    return ScriptSandbox._sandboxes[id]
end

function ScriptSandbox.GetAll()
    local result = {}

    for _, sandbox in pairs(ScriptSandbox._sandboxes) do
        table.insert(result, sandbox)
    end

    return result
end

function ScriptSandbox.GetCount()
    return ScriptSandbox._statistics.Active
end

function ScriptSandbox.GetStatistics()
    return copyTable(ScriptSandbox._statistics)
end

function ScriptSandbox.DestroyAll()
    local sandboxes = ScriptSandbox.GetAll()

    for _, sandbox in ipairs(sandboxes) do
        sandbox:Destroy()
    end

    return true
end

function ScriptSandbox.Reset()
    ScriptSandbox.DestroyAll()

    ScriptSandbox._sandboxes = {}
    ScriptSandbox._nextId = 1

    for key in pairs(ScriptSandbox._statistics) do
        ScriptSandbox._statistics[key] = 0
    end

    return true
end

ScriptSandbox.Sandbox = Sandbox
ScriptSandbox.DefaultPermissions = copyTable(DEFAULT_PERMISSIONS)

return ScriptSandbox
