-- Deterministic in-process event bus with bounded history and listener limits.
local EventManager = {
    Enabled = true,
    MaximumListeners = 100,
    HistoryLimit = 100,
    _events = {},
    _history = {},
    _paused = {},
    _nextId = 0,
    _statistics = { Published = 0, Delivered = 0, Failed = 0, Subscriptions = 0, Unsubscriptions = 0 },
}

local function validName(name)
    return type(name) == "string" and name ~= ""
end
local function getEvent(self, name, create)
    local event = self._events[name]
    if not event and create then
        event = { Listeners = {}, Paused = false }
        self._events[name] = event
    end
    return event
end
local function appendHistory(self, name, arguments, delivered, failed)
    if self.HistoryLimit <= 0 then return end
    self._history[#self._history + 1] = {
        Name = name, Arguments = arguments, Delivered = delivered,
        Failed = failed, Timestamp = os.clock(),
    }
    while #self._history > self.HistoryLimit do table.remove(self._history, 1) end
end

function EventManager:Create(name)
    if not validName(name) then error("Event name must be a non-empty string", 2) end
    getEvent(self, name, true)
    return name
end
function EventManager:Exists(name) return self._events[name] ~= nil end
function EventManager:Subscribe(name, callback, options)
    if not validName(name) then error("Event name must be a non-empty string", 2) end
    if type(callback) ~= "function" then error("Callback must be a function", 2) end
    local event = getEvent(self, name, true)
    local count = 0
    for _, listener in pairs(event.Listeners) do if listener.Active then count += 1 end end
    if count >= self.MaximumListeners then return nil, "Maximum listeners reached" end
    options = options or {}
    self._nextId += 1
    local listener = {
        Id = self._nextId, Callback = callback, Active = true,
        Once = options.Once == true, Priority = options.Priority or 0,
        Order = self._nextId,
    }
    if type(listener.Priority) ~= "number" or listener.Priority ~= listener.Priority then
        error("Listener priority must be a valid number", 2)
    end
    event.Listeners[listener.Id] = listener
    self._statistics.Subscriptions += 1
    local manager = self
    local connection = { Id = listener.Id, Event = name, _manager = manager }
    function connection:Disconnect()
        if not self._manager then return false end
        local result = self._manager:Unsubscribe(self.Event, self.Id)
        self._manager = nil
        return result
    end
    function connection:IsConnected() return self._manager ~= nil end
    return connection
end
function EventManager:Once(name, callback, options)
    options = options or {}
    local copy = {}
    for key, value in pairs(options) do copy[key] = value end
    copy.Once = true
    return self:Subscribe(name, callback, copy)
end
function EventManager:Unsubscribe(name, id)
    local event = self._events[name]
    local listener = event and event.Listeners[id]
    if not listener or not listener.Active then return false end
    listener.Active = false; listener.Callback = nil
    event.Listeners[id] = nil
    self._statistics.Unsubscriptions += 1
    return true
end
function EventManager:Publish(name, ...)
    if not validName(name) then error("Event name must be a non-empty string", 2) end
    self._statistics.Published += 1
    local event = self._events[name]
    if not self.Enabled or not event or event.Paused then
        appendHistory(self, name, {...}, 0, 0)
        return 0, 0
    end
    local listeners = {}
    for _, listener in pairs(event.Listeners) do listeners[#listeners + 1] = listener end
    table.sort(listeners, function(a, b)
        if a.Priority == b.Priority then return a.Order < b.Order end
        return a.Priority > b.Priority
    end)
    local args, delivered, failed = {...}, 0, 0
    for _, listener in ipairs(listeners) do
        if listener.Active and type(listener.Callback) == "function" then
            local ok = pcall(listener.Callback, table.unpack(args))
            if ok then delivered += 1 else failed += 1 end
            if listener.Once then self:Unsubscribe(name, listener.Id) end
        end
    end
    self._statistics.Delivered += delivered
    self._statistics.Failed += failed
    appendHistory(self, name, args, delivered, failed)
    return delivered, failed
end
function EventManager:PublishSafe(name, ...)
    local delivered, failed = self:Publish(name, ...)
    return failed == 0, delivered, failed
end
function EventManager:EmitMany(name, payloads)
    if type(payloads) ~= "table" then error("Payloads must be an array", 2) end
    local totalDelivered, totalFailed = 0, 0
    for _, payload in ipairs(payloads) do
        if type(payload) == "table" then
            local delivered, failed = self:Publish(name, table.unpack(payload))
            totalDelivered += delivered; totalFailed += failed
        else
            error("Each payload must be an argument array", 2)
        end
    end
    return totalDelivered, totalFailed
end
function EventManager:GetListenerCount(name)
    local event, count = self._events[name], 0
    if event then for _, listener in pairs(event.Listeners) do if listener.Active then count += 1 end end end
    return count
end
function EventManager:HasListeners(name) return self:GetListenerCount(name) > 0 end
function EventManager:GetEventNames()
    local names = {}
    for name in pairs(self._events) do names[#names + 1] = name end
    table.sort(names)
    return names
end
function EventManager:Pause(name)
    local event = self._events[name]
    if not event then return false end
    event.Paused = true
    return true
end
function EventManager:Resume(name)
    local event = self._events[name]
    if not event then return false end
    event.Paused = false
    return true
end
function EventManager:IsPaused(name)
    local event = self._events[name]
    return event ~= nil and event.Paused
end
function EventManager:SetEnabled(value) self.Enabled = value == true; return self.Enabled end
function EventManager:IsEnabled() return self.Enabled end
function EventManager:SetMaximumListeners(value)
    if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then
        error("Maximum listeners must be a non-negative integer", 2)
    end
    self.MaximumListeners = value
    return true
end
function EventManager:GetMaximumListeners() return self.MaximumListeners end
function EventManager:SetHistoryLimit(value)
    if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then
        error("History limit must be a non-negative integer", 2)
    end
    self.HistoryLimit = value
    while #self._history > value do table.remove(self._history, 1) end
    return true
end
function EventManager:GetHistory(name)
    local result = {}
    for _, entry in ipairs(self._history) do
        if name == nil or entry.Name == name then result[#result + 1] = entry end
    end
    return result
end
function EventManager:ClearHistory() local count = #self._history; self._history = {}; return count end
function EventManager:Clear(name)
    local event = self._events[name]
    if not event then return false end
    for id in pairs(event.Listeners) do self:Unsubscribe(name, id) end
    self._events[name] = nil
    return true
end
function EventManager:ClearAll()
    local names = self:GetEventNames()
    for _, name in ipairs(names) do self:Clear(name) end
    self:ClearHistory()
    return #names
end
function EventManager:GetStatistics()
    local eventCount, listenerCount = 0, 0
    for _, event in pairs(self._events) do
        eventCount += 1
        for _, listener in pairs(event.Listeners) do if listener.Active then listenerCount += 1 end end
    end
    return {
        Enabled = self.Enabled, Events = eventCount, Listeners = listenerCount,
        HistoryEntries = #self._history, Published = self._statistics.Published,
        Delivered = self._statistics.Delivered, Failed = self._statistics.Failed,
        Subscriptions = self._statistics.Subscriptions,
        Unsubscriptions = self._statistics.Unsubscriptions,
    }
end
function EventManager:Reset()
    self:ClearAll()
    self.Enabled = true; self.MaximumListeners = 100; self.HistoryLimit = 100
    self._nextId = 0
    self._statistics = { Published = 0, Delivered = 0, Failed = 0, Subscriptions = 0, Unsubscriptions = 0 }
    return true
end

return EventManager
