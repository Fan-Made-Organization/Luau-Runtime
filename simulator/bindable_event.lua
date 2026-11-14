local Signal = require("./signal")

local BindableEvent = {}
local Methods = {}

local Metatable = {
    __index = Methods,
}

function BindableEvent.new()
    local self = {
        ClassName = "BindableEvent",
        Name = "BindableEvent",

        Event = Signal.new(),

        _destroyed = false,
        _fireCount = 0,
    }

    return setmetatable(self, Metatable)
end

function Methods:Fire(...)
    if self._destroyed then
        error("Cannot fire a destroyed BindableEvent")
    end

    self._fireCount = self._fireCount + 1

    self.Event:Fire(...)

    return true
end

function Methods:DisconnectAll()
    if self._destroyed then
        return false
    end

    self.Event:DisconnectAll()

    return true
end

function Methods:GetConnectionCount()
    if self._destroyed then
        return 0
    end

    return self.Event:Count()
end

function Methods:GetFireCount()
    return self._fireCount
end

function Methods:GetStatistics()
    local signalStats = {}

    if not self._destroyed
        and type(self.Event.GetStatistics) == "function" then
        signalStats = self.Event:GetStatistics()
    end

    return {
        Fires = self._fireCount,
        Connections = self:GetConnectionCount(),
        Destroyed = self._destroyed,
        Signal = signalStats,
    }
end

function Methods:IsDestroyed()
    return self._destroyed
end

function Methods:Destroy()
    if self._destroyed then
        return
    end

    self._destroyed = true

    if self.Event then
        self.Event:Destroy()
    end
end

function Methods:GetFullName()
    return self.Name
end

function Methods:IsA(className)
    return className == "BindableEvent"
        or className == "Instance"
end

return BindableEvent
