local Signal = require("./signal")

local RunService = {
    Heartbeat = Signal.new(),
    Stepped = Signal.new(),
    RenderStepped = Signal.new(),

    _running = false,
    _boundCallbacks = {},
}

function RunService:IsRunning()
    return self._running
end

function RunService:IsClient()
    return true
end

function RunService:IsServer()
    return false
end

function RunService:BindToRenderStep(name, priority, callback)
    if type(name) ~= "string" then
        error("Callback name must be a string")
    end

    if type(priority) ~= "number" then
        error("Priority must be a number")
    end

    if type(callback) ~= "function" then
        error("Callback must be a function")
    end

    self._boundCallbacks[name] = {
        Priority = priority,
        Callback = callback,
    }
end

function RunService:UnbindFromRenderStep(name)
    self._boundCallbacks[name] = nil
end

function RunService:Step(deltaTime)
    if type(deltaTime) ~= "number" or deltaTime < 0 then
        error("deltaTime must be a non-negative number")
    end

    self._running = true

    self.Stepped:Fire(deltaTime, deltaTime)

    local callbacks = {}

    for name, data in pairs(self._boundCallbacks) do
        table.insert(callbacks, {
            Name = name,
            Priority = data.Priority,
            Callback = data.Callback,
        })
    end

    table.sort(callbacks, function(a, b)
        if a.Priority == b.Priority then
            return a.Name < b.Name
        end

        return a.Priority < b.Priority
    end)

    for _, data in ipairs(callbacks) do
        data.Callback(deltaTime)
    end

    self.RenderStepped:Fire(deltaTime)
    self.Heartbeat:Fire(deltaTime)
end

function RunService:Stop()
    self._running = false
end

function RunService:ClearBindings()
    self._boundCallbacks = {}
end

function RunService:GetBoundCallbackCount()
    local count = 0

    for _ in pairs(self._boundCallbacks) do
        count = count + 1
    end

    return count
end

return RunService
