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
    }

    return setmetatable(self, Metatable)
end

function Methods:Invoke(...)
    if self._destroyed then
        error("Cannot invoke a destroyed BindableFunction")
    end

    if type(self._callback) ~= "function" then
        error("BindableFunction.OnInvoke is not assigned")
    end

    self._invokeCount = self._invokeCount + 1

    local results = table.pack(
        pcall(self._callback, ...)
    )

    if not results[1] then
        self._errorCount = self._errorCount + 1
        error(results[2])
    end

    return table.unpack(results, 2, results.n)
end

function Methods:SetCallback(callback)
    if callback ~= nil and type(callback) ~= "function" then
        error("Callback must be a function or nil")
    end

    if self._destroyed then
        error("Cannot modify a destroyed BindableFunction")
    end

    self._callback = callback

    return true
end

function Methods:GetCallback()
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

function Methods:GetStatistics()
    return {
        Invocations = self._invokeCount,
        Errors = self._errorCount,
    }
end

function Methods:Destroy()
    if self._destroyed then
        return
    end

    self._callback = nil
    self._destroyed = true
end

function Methods:GetFullName()
    return self.Name
end

function Methods:IsA(className)
    return className == "BindableFunction"
        or className == "Instance"
end

return BindableFunction
