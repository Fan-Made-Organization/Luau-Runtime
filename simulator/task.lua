local Task = {}

local WAIT_TOKEN = {}
local DEFAULT_WAIT = 1 / 30

local scheduler = {
    Clock = 0,
    Sequence = 0,
    Pending = {},
    Tasks = {},
    Errors = {},
    IsStepping = false,

    Statistics = {
        Created = 0,
        Started = 0,
        Completed = 0,
        Cancelled = 0,
        Failed = 0,
        Resumed = 0,
        Steps = 0,
    },
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function createTask(callback, arguments)
    if type(callback) ~= "function" then
        error("Expected a function")
    end

    local thread = coroutine.create(function()
        callback(table.unpack(arguments, 1, arguments.n))
    end)

    local taskData = {
        Thread = thread,
        Cancelled = false,
        Completed = false,
        Failed = false,
        WakeTime = nil,
        LastResume = scheduler.Clock,
        CreatedAt = scheduler.Clock,
        Sequence = nil,
        LastError = nil,
    }

    scheduler.Tasks[thread] = taskData
    scheduler.Statistics.Created =
        scheduler.Statistics.Created + 1

    return taskData
end

local function schedule(taskData, duration)
    scheduler.Sequence = scheduler.Sequence + 1

    taskData.WakeTime = scheduler.Clock + duration
    taskData.Sequence = scheduler.Sequence

    table.insert(scheduler.Pending, taskData)
end

local function removeTask(taskData)
    scheduler.Tasks[taskData.Thread] = nil
end

local function recordError(taskData, message)
    taskData.Failed = true
    taskData.Completed = true
    taskData.LastError = tostring(message)

    removeTask(taskData)

    scheduler.Statistics.Failed =
        scheduler.Statistics.Failed + 1

    table.insert(scheduler.Errors, {
        Thread = taskData.Thread,
        Message = tostring(message),
        Time = scheduler.Clock,
    })
end

local function resumeTask(taskData)
    if taskData.Cancelled or taskData.Completed then
        return
    end

    local success, yielded, duration = coroutine.resume(
        taskData.Thread,
        scheduler.Clock - taskData.LastResume
    )

    scheduler.Statistics.Resumed =
        scheduler.Statistics.Resumed + 1

    if not success then
        recordError(taskData, yielded)
        return
    end

    taskData.LastResume = scheduler.Clock

    if coroutine.status(taskData.Thread) == "dead" then
        taskData.Completed = true

        removeTask(taskData)

        scheduler.Statistics.Completed =
            scheduler.Statistics.Completed + 1

        return
    end

    if yielded == WAIT_TOKEN then
        if not isFiniteNumber(duration) or duration < 0 then
            duration = DEFAULT_WAIT
        end

        schedule(taskData, duration)
        return
    end

    recordError(
        taskData,
        "Unsupported coroutine yield"
    )
end

function Task.spawn(callback, ...)
    local arguments = table.pack(...)

    local taskData = createTask(callback, arguments)

    scheduler.Statistics.Started =
        scheduler.Statistics.Started + 1

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
    if not isFiniteNumber(duration) or duration < 0 then
        error("Delay must be a finite non-negative number")
    end

    local arguments = table.pack(...)

    local taskData = createTask(callback, arguments)

    schedule(taskData, duration)

    return taskData.Thread
end

function Task.wait(duration)
    duration = duration or DEFAULT_WAIT

    if not isFiniteNumber(duration) or duration < 0 then
        error("Wait duration must be a finite non-negative number")
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

    removeTask(taskData)

    for i = #scheduler.Pending, 1, -1 do
        if scheduler.Pending[i] == taskData then
            table.remove(scheduler.Pending, i)
        end
    end

    scheduler.Statistics.Cancelled =
        scheduler.Statistics.Cancelled + 1

    return true
end

function Task.Step(deltaTime)
    if not isFiniteNumber(deltaTime) or deltaTime < 0 then
        error("deltaTime must be a finite non-negative number")
    end

    if scheduler.IsStepping then
        error("Task.Step cannot be called recursively")
    end

    scheduler.IsStepping = true

    scheduler.Clock = scheduler.Clock + deltaTime
    scheduler.Statistics.Steps =
        scheduler.Statistics.Steps + 1

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
        if not taskData.Cancelled and not taskData.Completed then
            scheduler.Statistics.Started =
                scheduler.Statistics.Started + 1

            resumeTask(taskData)
        end
    end

    scheduler.IsStepping = false
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

function Task.GetErrors()
    local result = {}

    for i, entry in ipairs(scheduler.Errors) do
        result[i] = {
            Thread = entry.Thread,
            Message = entry.Message,
            Time = entry.Time,
        }
    end

    return result
end

function Task.GetErrorCount()
    return #scheduler.Errors
end

function Task.ClearErrors()
    scheduler.Errors = {}
end

function Task.GetStatistics()
    local result = {}

    for key, value in pairs(scheduler.Statistics) do
        result[key] = value
    end

    result.Active = Task.GetActiveCount()
    result.Pending = Task.GetPendingCount()
    result.Errors = Task.GetErrorCount()
    result.Clock = scheduler.Clock

    return result
end

function Task.Reset()
    for _, taskData in pairs(scheduler.Tasks) do
        taskData.Cancelled = true
        taskData.Completed = true
    end

    scheduler.Tasks = {}
    scheduler.Pending = {}
    scheduler.Errors = {}

    scheduler.Clock = 0
    scheduler.Sequence = 0
    scheduler.IsStepping = false

    for key in pairs(scheduler.Statistics) do
        scheduler.Statistics[key] = 0
    end
end

return Task
