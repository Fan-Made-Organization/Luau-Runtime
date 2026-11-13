local ModuleLoader = {
    _cache = {},
    _loading = {},
    _loadStack = {},
    _stats = {
        Loads = 0,
        CacheHits = 0,
        Errors = 0,
        CircularDependencies = 0,
    },
}

local function isModule(instance)
    return type(instance) == "table"
        and instance.ClassName == "ModuleScript"
end

local function getModuleName(moduleScript)
    if type(moduleScript.GetFullName) == "function" then
        return moduleScript:GetFullName()
    end

    return tostring(moduleScript.Name or "UnknownModule")
end

local function compile(moduleScript)
    if type(moduleScript.Source) ~= "string" then
        return nil, "ModuleScript Source must be a string"
    end

    if type(loadstring) ~= "function" then
        return nil, "loadstring is not available"
    end

    local chunkName = "=" .. getModuleName(moduleScript)

    local chunk, compileError = loadstring(
        moduleScript.Source,
        chunkName
    )

    if not chunk then
        return nil, compileError
    end

    return chunk
end

local function createCircularError(moduleScript)
    local chain = {}

    for _, name in ipairs(ModuleLoader._loadStack) do
        table.insert(chain, name)
    end

    table.insert(chain, getModuleName(moduleScript))

    return "Circular module dependency detected: "
        .. table.concat(chain, " -> ")
end

function ModuleLoader:Require(moduleScript)
    if not isModule(moduleScript) then
        error("Require expects a ModuleScript")
    end

    if moduleScript.Destroyed then
        error("Cannot require a destroyed ModuleScript")
    end

    if moduleScript.Disabled then
        error("Cannot require a disabled ModuleScript")
    end

    local cached = self._cache[moduleScript]

    if cached ~= nil then
        self._stats.CacheHits = self._stats.CacheHits + 1
        return cached.Value
    end

    if self._loading[moduleScript] then
        self._stats.CircularDependencies =
            self._stats.CircularDependencies + 1

        self._stats.Errors = self._stats.Errors + 1

        error(createCircularError(moduleScript))
    end

    self._loading[moduleScript] = true

    local moduleName = getModuleName(moduleScript)

    table.insert(self._loadStack, moduleName)

    local function finish()
        self._loading[moduleScript] = nil
        table.remove(self._loadStack)
    end

    local chunk, compileError = compile(moduleScript)

    if not chunk then
        finish()

        self._stats.Errors = self._stats.Errors + 1

        error(compileError)
    end

    local success, result = pcall(chunk)

    if not success then
        finish()

        self._stats.Errors = self._stats.Errors + 1

        error(result)
    end

    if result == nil then
        finish()

        self._stats.Errors = self._stats.Errors + 1

        error(
            "ModuleScript must return a value: "
            .. moduleName
        )
    end

    self._cache[moduleScript] = {
        Value = result,
        Name = moduleName,
        LoadedAt = os.clock(),
    }

    finish()

    self._stats.Loads = self._stats.Loads + 1

    return result
end

function ModuleLoader:IsLoaded(moduleScript)
    return self._cache[moduleScript] ~= nil
end

function ModuleLoader:Unload(moduleScript)
    if not isModule(moduleScript) then
        return false
    end

    local existed = self._cache[moduleScript] ~= nil

    self._cache[moduleScript] = nil

    return existed
end

function ModuleLoader:ClearCache()
    self._cache = {}
    self._loading = {}
    self._loadStack = {}
end

function ModuleLoader:GetLoadedModules()
    local modules = {}

    for moduleScript, information in pairs(self._cache) do
        table.insert(modules, {
            Instance = moduleScript,
            Name = information.Name,
            LoadedAt = information.LoadedAt,
        })
    end

    table.sort(modules, function(a, b)
        return a.Name < b.Name
    end)

    return modules
end

function ModuleLoader:GetLoadedCount()
    local count = 0

    for _ in pairs(self._cache) do
        count = count + 1
    end

    return count
end

function ModuleLoader:GetStatistics()
    return {
        Loads = self._stats.Loads,
        CacheHits = self._stats.CacheHits,
        Errors = self._stats.Errors,
        CircularDependencies = self._stats.CircularDependencies,
        LoadedModules = self:GetLoadedCount(),
    }
end

function ModuleLoader:ResetStatistics()
    self._stats = {
        Loads = 0,
        CacheHits = 0,
        Errors = 0,
        CircularDependencies = 0,
    }
end

return ModuleLoader
