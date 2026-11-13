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
    }

    return setmetatable(self, Metatable)
end

function Methods:Fire(...)
    if self._destroyed then
        error("Cannot fire a destroyed BindableEvent")
    end

    self.Event:Fire(...)
end

function Methods:Destroy()
    if self._destroyed then
        return
    end

    self.Event:Destroy()
    self._destroyed = true
end

function Methods:GetConnectionCount()
    return self.Event:Count()
end

function Methods:IsDestroyed()
    return self._destroyed
end

function Methods:GetFullName()
    return self.Name
end

function Methods:IsA(className)
    return className == "BindableEvent"
        or className == "Instance"
end

return BindableEvent
