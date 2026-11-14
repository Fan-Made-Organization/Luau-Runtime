local ModuleLoader = {
    _cache = {},
    _loading = {},
    _loadStack = {},

    _stats = {
        Loads = 0,
        CacheHits = 0,
        Errors = 0,
        CircularDependencies = 0,
        Unloads = 0,
    },
}

local function isModule(instance)
    return type(instance) == "table"
        and instance.ClassName == "ModuleScript"
end

local function isDestroyed(instance)
    if instance._destroyed == true
        or instance.Destroyed == true then
        return true
    end

    if type(instance.IsDestroyed) == "function" then
        local success, result = pcall(instance.IsDestroyed, instance)

        if success and result == true then
            return true
        end
    end

    return false
end

local function getModuleName(moduleScript)
    if type(moduleScript.GetFullName) == "function" then
        local success, result = pcall(
            moduleScript.GetFullName,
            moduleScript
        )

        if success and type(result) == "string" then
            return result
        end
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

local function finishLoading(loader, moduleScript)
    loader._loading[moduleScript] = nil

    for i = #loader._loadStack, 1, -1 do
        if loader._loadStack[i].Module == moduleScript then
            table.remove(loader._loadStack, i)
            break
        end
    end
end

function ModuleLoader:Require(moduleScript)
    if not isModule(moduleScript) then
        error("Require expects a ModuleScript")
    end

    if isDestroyed(moduleScript) then
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

    table.insert(self._loadStack, {
        Module = moduleScript,
        Name = moduleName,
    })

    local chunk, compileError = compile(moduleScript)

    if not chunk then
        finishLoading(self, moduleScript)

        self._stats.Errors = self._stats.Errors + 1

        error(compileError)
    end

    local success, result = pcall(chunk)

    if not success then
        finishLoading(self, moduleScript)

        self._stats.Errors = self._stats.Errors + 1

        error(result)
    end

    if result == nil then
        finishLoading(self, moduleScript)

        self._stats.Errors = self._stats.Errors + 1

        error(
            "ModuleScript must return a value: "
            .. moduleName
        )
    end

    if isDestroyed(moduleScript) then
        finishLoading(self, moduleScript)

        self._stats.Errors = self._stats.Errors + 1

        error(
            "ModuleScript was destroyed while loading: "
            .. moduleName
        )
    end

    self._cache[moduleScript] = {
        Value = result,
        Name = moduleName,
        LoadedAt = os.clock(),
    }

    finishLoading(self, moduleScript)

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

    if self._loading[moduleScript] then
        return false
    end

    local existed = self._cache[moduleScript] ~= nil

    if existed then
        self._cache[moduleScript] = nil
        self._stats.Unloads = self._stats.Unloads + 1
    end

    return existed
end

function ModuleLoader:ClearCache()
    self._cache = {}
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
        Unloads = self._stats.Unloads,
        LoadedModules = self:GetLoadedCount(),
    }
end

function ModuleLoader:ResetStatistics()
    self._stats = {
        Loads = 0,
        CacheHits = 0,
        Errors = 0,
        CircularDependencies = 0,
        Unloads = 0,
    }
end

return ModuleLoader
