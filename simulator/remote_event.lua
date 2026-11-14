local Signal = require("./signal")

local RemoteEvent = {}
local Methods = {}

local Metatable = {
    __index = Methods,
}

local function checkDestroyed(self)
    if self._destroyed then
        error("RemoteEvent has been destroyed")
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

function RemoteEvent.new()
    local self = {
        ClassName = "RemoteEvent",
        Name = "RemoteEvent",

        OnServerEvent = Signal.new(),
        OnClientEvent = Signal.new(),

        _localPlayer = nil,
        _destroyed = false,

        _serverMessages = 0,
        _clientMessages = 0,
        _rejectedMessages = 0,
        _errors = 0,
    }

    return setmetatable(self, Metatable)
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

function Methods:FireServer(...)
    checkDestroyed(self)

    if self._localPlayer ~= nil
        and not isValidPlayer(self._localPlayer) then
        self._localPlayer = nil
        self._rejectedMessages = self._rejectedMessages + 1

        return false, "Active simulated player is invalid"
    end

    self._serverMessages = self._serverMessages + 1

    local success, result = pcall(
        self.OnServerEvent.Fire,
        self.OnServerEvent,
        self._localPlayer,
        ...
    )

    if not success then
        self._errors = self._errors + 1
        return false, result
    end

    return true
end

function Methods:FireClient(player, ...)
    checkDestroyed(self)

    if player == nil then
        error("FireClient expects a player")
    end

    if not isValidPlayer(player) then
        self._rejectedMessages = self._rejectedMessages + 1
        return false, "Player is invalid or destroyed"
    end

    if player ~= self._localPlayer then
        self._rejectedMessages = self._rejectedMessages + 1
        return false, "Player is not the active simulated client"
    end

    self._clientMessages = self._clientMessages + 1

    local success, result = pcall(
        self.OnClientEvent.Fire,
        self.OnClientEvent,
        ...
    )

    if not success then
        self._errors = self._errors + 1
        return false, result
    end

    return true
end

function Methods:FireAllClients(...)
    checkDestroyed(self)

    if self._localPlayer == nil then
        return 0
    end

    if not isValidPlayer(self._localPlayer) then
        self._localPlayer = nil
        self._rejectedMessages = self._rejectedMessages + 1

        return 0
    end

    self._clientMessages = self._clientMessages + 1

    local success = pcall(
        self.OnClientEvent.Fire,
        self.OnClientEvent,
        ...
    )

    if not success then
        self._errors = self._errors + 1
        return 0
    end

    return 1
end

function Methods:DisconnectAll()
    checkDestroyed(self)

    self.OnServerEvent:DisconnectAll()
    self.OnClientEvent:DisconnectAll()

    return true
end

function Methods:GetStatistics()
    checkDestroyed(self)

    return {
        ServerMessages = self._serverMessages,
        ClientMessages = self._clientMessages,
        RejectedMessages = self._rejectedMessages,
        Errors = self._errors,

        ServerConnections = self.OnServerEvent:Count(),
        ClientConnections = self.OnClientEvent:Count(),

        TotalConnections = self:GetConnectionCount(),
    }
end

function Methods:GetConnectionCount()
    if self._destroyed then
        return 0
    end

    return self.OnServerEvent:Count()
        + self.OnClientEvent:Count()
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
    return className == "RemoteEvent"
        or className == "Instance"
end

function Methods:Destroy()
    if self._destroyed then
        return
    end

    self._destroyed = true

    self.OnServerEvent:Destroy()
    self.OnClientEvent:Destroy()

    self._localPlayer = nil
end

return RemoteEvent
