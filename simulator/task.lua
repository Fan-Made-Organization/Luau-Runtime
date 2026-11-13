local Task = {}

local WAIT_TOKEN = {}

local scheduler = {
    Clock = 0,
    Sequence = 0,
    Pending = {},
    Tasks = {},
}

local DEFAULT_WAIT = 1 / 30

local function createTask(callback, arguments)
    if type(callback) ~= "function" then
        error("Expected a function")
    end

    local thread = coroutine.create(function()
        callback(table.unpack(arguments))
    end)

    local taskData = {
        Thread = thread,
        Cancelled = false,
        Completed = false,
        WakeTime = nil,
        LastResume = scheduler.Clock,
    }

    scheduler.Tasks[thread] = taskData

    return taskData
end

local function schedule(taskData, delay)
    scheduler.Sequence = scheduler.Sequence + 1

    taskData.WakeTime = scheduler.Clock + delay
    taskData.Sequence = scheduler.Sequence

    table.insert(scheduler.Pending, taskData)
end

local function resumeTask(taskData)
    if taskData.Cancelled or taskData.Completed then
        return
    end

    local success, yielded, duration = coroutine.resume(
        taskData.Thread,
        scheduler.Clock - taskData.LastResume
    )

    if not success then
        taskData.Completed = true
        scheduler.Tasks[taskData.Thread] = nil
        error(yielded)
    end

    taskData.LastResume = scheduler.Clock

    if coroutine.status(taskData.Thread) == "dead" then
        taskData.Completed = true
        scheduler.Tasks[taskData.Thread] = nil
        return
    end

    if yielded == WAIT_TOKEN then
        if type(duration) ~= "number" or duration < 0 then
            duration = DEFAULT_WAIT
        end

        schedule(taskData, duration)
    else
        taskData.Completed = true
        scheduler.Tasks[taskData.Thread] = nil
        error("Unsupported coroutine yield")
    end
end

function Task.spawn(callback, ...)
    local arguments = table.pack(...)

    local taskData = createTask(callback, arguments)

    resumeTask(taskData)

    return taskData.Thread
end

function Task.defer(callback, ...)
    local arguments = table.pack(...)

    local taskData = createTask(callback, arguments)

    schedule(taskData, 0)

    return taskData.Thread
end

function Task.delay(duration, callback, ...)
    if type(duration) ~= "number" or duration < 0 then
        error("Delay must be a non-negative number")
    end

    local arguments = table.pack(...)

    local taskData = createTask(callback, arguments)

    schedule(taskData, duration)

    return taskData.Thread
end

function Task.wait(duration)
    duration = duration or DEFAULT_WAIT

    if type(duration) ~= "number" or duration < 0 then
        error("Wait duration must be non-negative")
    end

    local thread = coroutine.running()
    local taskData = scheduler.Tasks[thread]

    if not taskData then
        error("task.wait must be called inside a scheduled task")
    end

    return coroutine.yield(WAIT_TOKEN, duration)
end

function Task.cancel(thread)
    local taskData = scheduler.Tasks[thread]

    if not taskData then
        return false
    end

    taskData.Cancelled = true
    taskData.Completed = true

    scheduler.Tasks[thread] = nil

    for i = #scheduler.Pending, 1, -1 do
        if scheduler.Pending[i] == taskData then
            table.remove(scheduler.Pending, i)
        end
    end

    return true
end

function Task.Step(deltaTime)
    if type(deltaTime) ~= "number" or deltaTime < 0 then
        error("deltaTime must be non-negative")
    end

    scheduler.Clock = scheduler.Clock + deltaTime

    local ready = {}
    local remaining = {}

    for _, taskData in ipairs(scheduler.Pending) do
        if taskData.WakeTime <= scheduler.Clock then
            table.insert(ready, taskData)
        else
            table.insert(remaining, taskData)
        end
    end

    scheduler.Pending = remaining

    table.sort(ready, function(a, b)
        if a.WakeTime == b.WakeTime then
            return a.Sequence < b.Sequence
        end

        return a.WakeTime < b.WakeTime
    end)

    for _, taskData in ipairs(ready) do
        if not taskData.Cancelled then
            resumeTask(taskData)
        end
    end
end

function Task.GetClock()
    return scheduler.Clock
end

function Task.GetPendingCount()
    return #scheduler.Pending
end

function Task.GetActiveCount()
    local count = 0

    for _ in pairs(scheduler.Tasks) do
        count = count + 1
    end

    return count
end

function Task.Reset()
    for _, taskData in pairs(scheduler.Tasks) do
        taskData.Cancelled = true
        taskData.Completed = true
    end

    scheduler.Tasks = {}
    scheduler.Pending = {}
    scheduler.Clock = 0
    scheduler.Sequence = 0
end

return Task
