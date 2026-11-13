local ModuleLoader = require("./module_loader")

local ScriptService = {
    _executionCount = 0,
    _errorCount = 0,
    _executionContext = "Server",
    _moduleLoader = ModuleLoader,
}

local VALID_CONTEXTS = {
    Server = true,
    Client = true,
    Plugin = true,
}

local VALID_RUN_CONTEXTS = {
    Legacy = true,
    Server = true,
    Client = true,
    Plugin = true,
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
        instance.RunContext = "Legacy"
    end
end

local function compile(instance)
    if type(loadstring) ~= "function" then
        return nil, "loadstring is not available"
    end

    if type(instance.Source) ~= "string" then
        return nil, "Script Source must be a string"
    end

    local chunkName = "=" .. instance:GetFullName()

    local chunk, compileError = loadstring(
        instance.Source,
        chunkName
    )

    if not chunk then
        return nil, compileError
    end

    return chunk
end

function ScriptService:SetExecutionContext(context)
    if not VALID_CONTEXTS[context] then
        error("Invalid execution context: " .. tostring(context))
    end

    self._executionContext = context

    return true
end

function ScriptService:GetExecutionContext()
    return self._executionContext
end

function ScriptService:GetRequiredContext(instance)
    if not isScript(instance) then
        error("Expected a Script instance")
    end

    prepareScript(instance)

    if instance.ClassName == "ModuleScript" then
        return "Any"
    end

    local runContext = instance.RunContext

    if not VALID_RUN_CONTEXTS[runContext] then
        error("Invalid RunContext: " .. tostring(runContext))
    end

    if runContext == "Legacy" then
        if instance.ClassName == "LocalScript" then
            return "Client"
        end

        return "Server"
    end

    return runContext
end

function ScriptService:CanExecute(instance, context)
    if not isScript(instance) then
        return false, "Invalid script instance"
    end

    prepareScript(instance)

    if instance.ClassName == "ModuleScript" then
        return false, "ModuleScripts must be loaded using Require"
    end

    if instance.Disabled then
        return false, "Script is disabled"
    end

    context = context or self._executionContext

    if not VALID_CONTEXTS[context] then
        return false, "Invalid execution context"
    end

    local requiredContext = self:GetRequiredContext(instance)

    if requiredContext ~= context then
        return false,
            "Context mismatch: requires "
            .. requiredContext
            .. ", current context is "
            .. context
    end

    return true
end

function ScriptService:Execute(instance, context)
    local allowed, reason = self:CanExecute(instance, context)

    if not allowed then
        return false, reason
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

    local success, result = pcall(function()
        return self._moduleLoader:Require(moduleScript)
    end)

    if not success then
        self._errorCount = self._errorCount + 1
        error(result)
    end

    self._executionCount = self._executionCount + 1

    return result
end

function ScriptService:ClearCache(moduleScript)
    if moduleScript then
        return self._moduleLoader:Unload(moduleScript)
    end

    self._moduleLoader:ClearCache()

    return true
end

function ScriptService:GetCachedModuleCount()
    return self._moduleLoader:GetLoadedCount()
end

function ScriptService:GetLoadedModules()
    return self._moduleLoader:GetLoadedModules()
end

function ScriptService:GetModuleStatistics()
    return self._moduleLoader:GetStatistics()
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
    self._moduleLoader:ResetStatistics()
end

return ScriptService
