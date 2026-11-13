local ScriptService = {
    _moduleCache = {},
    _executionCount = 0,
    _errorCount = 0,
}

local function isScript(instance)
    if type(instance) ~= "table" then
        return false
    end

    local className = instance.ClassName

    return className == "Script"
        or className == "LocalScript"
        or className == "ModuleScript"
end

local function prepareScript(instance)
    if instance.Source == nil then
        instance.Source = ""
    end

    if instance.Disabled == nil then
        instance.Disabled = false
    end

    if instance.RunContext == nil then
        if instance.ClassName == "LocalScript" then
            instance.RunContext = "Client"
        else
            instance.RunContext = "Legacy"
        end
    end
end

local function compile(instance)
    if type(loadstring) ~= "function" then
        return nil, "loadstring is not available"
    end

    local source = instance.Source

    if type(source) ~= "string" then
        return nil, "Script Source must be a string"
    end

    local chunkName = "=" .. instance:GetFullName()

    local chunk, compileError = loadstring(source, chunkName)

    if not chunk then
        return nil, compileError
    end

    return chunk
end

function ScriptService:Execute(instance)
    if not isScript(instance) then
        error("Execute expects a Script, LocalScript or ModuleScript")
    end

    if instance.ClassName == "ModuleScript" then
        error("Use ScriptService:Require() for ModuleScripts")
    end

    prepareScript(instance)

    if instance.Disabled then
        return false, "Script is disabled"
    end

    local chunk, compileError = compile(instance)

    if not chunk then
        self._errorCount = self._errorCount + 1
        return false, compileError
    end

    local success, result = pcall(chunk)

    if not success then
        self._errorCount = self._errorCount + 1
        return false, result
    end

    self._executionCount = self._executionCount + 1

    return true, result
end

function ScriptService:Require(moduleScript)
    if not isScript(moduleScript)
        or moduleScript.ClassName ~= "ModuleScript" then
        error("Require expects a ModuleScript")
    end

    prepareScript(moduleScript)

    if moduleScript.Disabled then
        error("Cannot require a disabled ModuleScript")
    end

    if self._moduleCache[moduleScript] ~= nil then
        return self._moduleCache[moduleScript]
    end

    local chunk, compileError = compile(moduleScript)

    if not chunk then
        self._errorCount = self._errorCount + 1
        error(compileError)
    end

    local success, result = pcall(chunk)

    if not success then
        self._errorCount = self._errorCount + 1
        error(result)
    end

    if result == nil then
        error("ModuleScript must return a value")
    end

    self._moduleCache[moduleScript] = result
    self._executionCount = self._executionCount + 1

    return result
end

function ScriptService:ClearCache(moduleScript)
    if moduleScript then
        self._moduleCache[moduleScript] = nil
    else
        self._moduleCache = {}
    end
end

function ScriptService:GetCachedModuleCount()
    local count = 0

    for _ in pairs(self._moduleCache) do
        count = count + 1
    end

    return count
end

function ScriptService:GetExecutionCount()
    return self._executionCount
end

function ScriptService:GetErrorCount()
    return self._errorCount
end

function ScriptService:ResetStats()
    self._executionCount = 0
    self._errorCount = 0
end

return ScriptService
