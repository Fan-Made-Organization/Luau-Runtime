local Scheduler = {
    _services = {},
    _running = false,
    _frame = 0,
    _elapsed = 0,
}

function Scheduler:Register(name, service)
    if type(name) ~= "string" then
        error("Service name must be a string")
    end

    if type(service) ~= "table" then
        error("Service must be a table")
    end

    self._services[name] = service

    return service
end

function Scheduler:GetService(name)
    return self._services[name]
end

function Scheduler:Start()
    self._running = true
end

function Scheduler:Stop()
    self._running = false
end

function Scheduler:IsRunning()
    return self._running
end

function Scheduler:GetFrame()
    return self._frame
end

function Scheduler:GetElapsedTime()
    return self._elapsed
end

function Scheduler:Step(deltaTime)
    if not self._running then
        return false
    end

    if type(deltaTime) ~= "number" or deltaTime < 0 then
        error("deltaTime must be non-negative")
    end

    self._frame = self._frame + 1
    self._elapsed = self._elapsed + deltaTime

    local runService = self._services.RunService
    local taskService = self._services.Task
    local tweenService = self._services.TweenService
    local debris = self._services.Debris

    if taskService then
        taskService.Step(deltaTime)
    end

    if runService then
        runService:Step(deltaTime)
    end

    if tweenService then
        tweenService:Step(deltaTime)
    end

    if debris then
        debris:Step(deltaTime)
    end

    return true
end

function Scheduler:Reset()
    self._running = false
    self._frame = 0
    self._elapsed = 0
end

return Scheduler
