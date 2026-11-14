local BindableFunction = {}

local Methods = {}

local Metatable = {
    __index = function(self, key)
        if key == "OnInvoke" then
            return rawget(self, "_callback")
        end

        return Methods[key]
    end,

    __newindex = function(self, key, value)
        if key == "OnInvoke" then
            if rawget(self, "_destroyed") then
                error("Cannot modify a destroyed BindableFunction")
            end

            if value ~= nil and type(value) ~= "function" then
                error("OnInvoke must be a function or nil")
            end

            rawset(self, "_callback", value)
            return
        end

        rawset(self, key, value)
    end,
}

function BindableFunction.new()
    local self = {
        ClassName = "BindableFunction",
        Name = "BindableFunction",

        _callback = nil,
        _destroyed = false,

        _invokeCount = 0,
        _errorCount = 0,
        _activeInvocations = 0,
        _maximumDepth = 0,
        _lastError = nil,
    }

    return setmetatable(self, Metatable)
end

function Methods:Invoke(...)
    if self._destroyed then
        error("Cannot invoke a destroyed BindableFunction")
    end

    local callback = self._callback

    if type(callback) ~= "function" then
        error("BindableFunction.OnInvoke is not assigned")
    end

    self._invokeCount = self._invokeCount + 1
    self._activeInvocations = self._activeInvocations + 1

    if self._activeInvocations > self._maximumDepth then
        self._maximumDepth = self._activeInvocations
    end

    local results = table.pack(
        pcall(callback, ...)
    )

    self._activeInvocations = self._activeInvocations - 1

    if not results[1] then
        self._errorCount = self._errorCount + 1
        self._lastError = tostring(results[2])

        error(results[2])
    end

    self._lastError = nil

    return table.unpack(results, 2, results.n)
end

function Methods:SetCallback(callback)
    if self._destroyed then
        error("Cannot modify a destroyed BindableFunction")
    end

    if callback ~= nil and type(callback) ~= "function" then
        error("Callback must be a function or nil")
    end

    self._callback = callback

    return true
end

function Methods:GetCallback()
    if self._destroyed then
        return nil
    end

    return self._callback
end

function Methods:IsDestroyed()
    return self._destroyed
end

function Methods:GetInvokeCount()
    return self._invokeCount
end

function Methods:GetErrorCount()
    return self._errorCount
end

function Methods:GetActiveInvocationCount()
    return self._activeInvocations
end

function Methods:GetLastError()
    return self._lastError
end

function Methods:GetStatistics()
    return {
        Invocations = self._invokeCount,
        Errors = self._errorCount,
        ActiveInvocations = self._activeInvocations,
        MaximumDepth = self._maximumDepth,
        LastError = self._lastError,
    }
end

function Methods:Destroy()
    if self._destroyed then
        return
    end

    self._destroyed = true
    self._callback = nil
    self._lastError = nil
end

function Methods:GetFullName()
    return self.Name
end

function Methods:IsA(className)
    return className == "BindableFunction"
        or className == "Instance"
end

return BindableFunction
