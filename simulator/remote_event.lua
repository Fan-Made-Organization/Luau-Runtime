local Signal = require("./signal")

local RemoteEvent = {}
local Methods = {}

local Metatable = {
    __index = Methods,
}

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
    }

    return setmetatable(self, Metatable)
end

local function checkDestroyed(self)
    if self._destroyed then
        error("RemoteEvent has been destroyed")
    end
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

function Methods:FireServer(...)
    checkDestroyed(self)

    self._serverMessages = self._serverMessages + 1

    self.OnServerEvent:Fire(
        self._localPlayer,
        ...
    )

    return true
end

function Methods:FireClient(player, ...)
    checkDestroyed(self)

    if player == nil then
        error("FireClient expects a player")
    end

    if player ~= self._localPlayer then
        self._rejectedMessages = self._rejectedMessages + 1
        return false, "Player is not the active simulated client"
    end

    self._clientMessages = self._clientMessages + 1

    self.OnClientEvent:Fire(...)

    return true
end

function Methods:FireAllClients(...)
    checkDestroyed(self)

    if self._localPlayer == nil then
        return 0
    end

    self._clientMessages = self._clientMessages + 1

    self.OnClientEvent:Fire(...)

    return 1
end

function Methods:GetStatistics()
    return {
        ServerMessages = self._serverMessages,
        ClientMessages = self._clientMessages,
        RejectedMessages = self._rejectedMessages,

        ServerConnections = self.OnServerEvent:Count(),
        ClientConnections = self.OnClientEvent:Count(),
    }
end

function Methods:GetConnectionCount()
    return self.OnServerEvent:Count()
        + self.OnClientEvent:Count()
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

    self.OnServerEvent:Destroy()
    self.OnClientEvent:Destroy()

    self._localPlayer = nil
    self._destroyed = true
end

return RemoteEvent
