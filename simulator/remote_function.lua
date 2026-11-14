local RemoteFunction = {}

local Methods = {}

local Metatable = {
    __index = function(self, key)
        if key == "OnServerInvoke" then
            return rawget(self, "_serverCallback")
        end

        if key == "OnClientInvoke" then
            return rawget(self, "_clientCallback")
        end

        return Methods[key]
    end,

    __newindex = function(self, key, value)
        if key == "OnServerInvoke" then
            if value ~= nil and type(value) ~= "function" then
                error("OnServerInvoke must be a function or nil")
            end

            rawset(self, "_serverCallback", value)
            return
        end

        if key == "OnClientInvoke" then
            if value ~= nil and type(value) ~= "function" then
                error("OnClientInvoke must be a function or nil")
            end

            rawset(self, "_clientCallback", value)
            return
        end

        rawset(self, key, value)
    end,
}

function RemoteFunction.new()
    local self = {
        ClassName = "RemoteFunction",
        Name = "RemoteFunction",

        _serverCallback = nil,
        _clientCallback = nil,

        _localPlayer = nil,
        _destroyed = false,

        _serverInvocations = 0,
        _clientInvocations = 0,
        _errors = 0,
    }

    return setmetatable(self, Metatable)
end

local function checkDestroyed(self)
    if self._destroyed then
        error("RemoteFunction has been destroyed")
    end
end

local function invokeCallback(self, callback, ...)
    if type(callback) ~= "function" then
        error("RemoteFunction callback is not assigned")
    end

    local results = table.pack(pcall(callback, ...))

    if not results[1] then
        self._errors = self._errors + 1
        error(results[2])
    end

    return table.unpack(results, 2, results.n)
end

function Methods:SetLocalPlayer(player)
    checkDestroyed(self)

    if player ~= nil and type(player) ~= "table" then
        error("LocalPlayer must be a Player-like table or nil")
    end

    self._localPlayer = player

    return true
end

function Methods:GetLocalPlayer()
    return self._localPlayer
end

function Methods:InvokeServer(...)
    checkDestroyed(self)

    self._serverInvocations = self._serverInvocations + 1

    if self._localPlayer ~= nil then
        return invokeCallback(
            self,
            self._serverCallback,
            self._localPlayer,
            ...
        )
    end

    return invokeCallback(
        self,
        self._serverCallback,
        ...
    )
end

function Methods:InvokeClient(player, ...)
    checkDestroyed(self)

    if player == nil then
        error("InvokeClient expects a player")
    end

    if player ~= self._localPlayer then
        self._errors = self._errors + 1
        error("Player is not the active simulated client")
    end

    self._clientInvocations = self._clientInvocations + 1

    return invokeCallback(
        self,
        self._clientCallback,
        ...
    )
end

function Methods:GetStatistics()
    return {
        ServerInvocations = self._serverInvocations,
        ClientInvocations = self._clientInvocations,
        Errors = self._errors,
    }
end

function Methods:GetInvocationCount()
    return self._serverInvocations + self._clientInvocations
end

function Methods:GetErrorCount()
    return self._errors
end

function Methods:IsDestroyed()
    return self._destroyed
end

function Methods:GetFullName()
    return self.Name
end

function Methods:IsA(className)
    return className == "RemoteFunction"
        or className == "Instance"
end

function Methods:Destroy()
    if self._destroyed then
        return
    end

    self._serverCallback = nil
    self._clientCallback = nil
    self._localPlayer = nil

    self._destroyed = true
end

return RemoteFunction
