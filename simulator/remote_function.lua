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
        if key == "OnServerInvoke" or key == "OnClientInvoke" then
            if rawget(self, "_destroyed") then
                error("Cannot modify a destroyed RemoteFunction")
            end

            if value ~= nil and type(value) ~= "function" then
                error(key .. " must be a function or nil")
            end

            if key == "OnServerInvoke" then
                rawset(self, "_serverCallback", value)
            else
                rawset(self, "_clientCallback", value)
            end

            return
        end

        rawset(self, key, value)
    end,
}

local function checkDestroyed(self)
    if self._destroyed then
        error("RemoteFunction has been destroyed")
    end
end

local function isValidPlayer(player)
    if type(player) ~= "table" then
        return false
    end

    if player._destroyed == true then
        return false
    end

    if type(player.IsDestroyed) == "function" then
        local success, result = pcall(
            player.IsDestroyed,
            player
        )

        if success and result == true then
            return false
        end
    end

    return true
end

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

        _activeInvocations = 0,
        _maximumDepth = 0,
        _lastError = nil,
    }

    return setmetatable(self, Metatable)
end

local function invokeCallback(self, callback, ...)
    if type(callback) ~= "function" then
        self._errors = self._errors + 1
        self._lastError = "RemoteFunction callback is not assigned"

        error(self._lastError)
    end

    self._activeInvocations = self._activeInvocations + 1

    if self._activeInvocations > self._maximumDepth then
        self._maximumDepth = self._activeInvocations
    end

    local results = table.pack(
        pcall(callback, ...)
    )

    self._activeInvocations = self._activeInvocations - 1

    if not results[1] then
        self._errors = self._errors + 1
        self._lastError = tostring(results[2])

        error(results[2])
    end

    self._lastError = nil

    return table.unpack(results, 2, results.n)
end

function Methods:SetLocalPlayer(player)
    checkDestroyed(self)

    if player ~= nil and not isValidPlayer(player) then
        error("LocalPlayer must be a valid Player-like table or nil")
    end

    self._localPlayer = player

    return true
end

function Methods:GetLocalPlayer()
    checkDestroyed(self)

    return self._localPlayer
end

function Methods:InvokeServer(...)
    checkDestroyed(self)

    if self._localPlayer ~= nil
        and not isValidPlayer(self._localPlayer) then
        self._localPlayer = nil
        self._errors = self._errors + 1
        self._lastError = "Active simulated player is invalid"

        error(self._lastError)
    end

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

    if not isValidPlayer(player) then
        self._errors = self._errors + 1
        self._lastError = "Player is invalid or destroyed"

        error(self._lastError)
    end

    if player ~= self._localPlayer then
        self._errors = self._errors + 1
        self._lastError = "Player is not the active simulated client"

        error(self._lastError)
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
        ActiveInvocations = self._activeInvocations,
        MaximumDepth = self._maximumDepth,
        LastError = self._lastError,
    }
end

function Methods:GetInvocationCount()
    return self._serverInvocations + self._clientInvocations
end

function Methods:GetErrorCount()
    return self._errors
end

function Methods:GetActiveInvocationCount()
    return self._activeInvocations
end

function Methods:GetLastError()
    return self._lastError
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

    self._destroyed = true

    self._serverCallback = nil
    self._clientCallback = nil
    self._localPlayer = nil
    self._lastError = nil
end

return RemoteFunction
