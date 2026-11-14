local Diagnostics = {
    Enabled = true,

    _logs = {},
    _nextId = 0,

    _statistics = {
        Total = 0,
        Info = 0,
        Warning = 0,
        Error = 0,
        Debug = 0,
    },

    _maximumLogs = 2000,
}

local VALID_LEVELS = {
    INFO = true,
    WARNING = true,
    ERROR = true,
    DEBUG = true,
}

local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function normalizeLevel(level)
    if type(level) ~= "string" then
        return nil
    end

    level = string.upper(level)

    if not VALID_LEVELS[level] then
        return nil
    end

    return level
end

local function safeString(value)
    local success, result = pcall(tostring, value)

    if success then
        return result
    end

    return "<unprintable value>"
end

function Diagnostics:Log(level, category, message, metadata)
    if not self.Enabled then
        return nil
    end

    level = normalizeLevel(level)

    if not level then
        error("Invalid diagnostic log level", 2)
    end

    self._nextId += 1

    local entry = {
        Id = self._nextId,
        Timestamp = getTimestamp(),
        Clock = os.clock(),

        Level = level,
        Category = safeString(category or "General"),
        Message = safeString(message or ""),

        Metadata = metadata,
    }

    table.insert(self._logs, entry)

    self._statistics.Total += 1

    if level == "INFO" then
        self._statistics.Info += 1
    elseif level == "WARNING" then
        self._statistics.Warning += 1
    elseif level == "ERROR" then
        self._statistics.Error += 1
    elseif level == "DEBUG" then
        self._statistics.Debug += 1
    end

    while #self._logs > self._maximumLogs do
        table.remove(self._logs, 1)
    end

    return entry
end

function Diagnostics:Info(category, message, metadata)
    return self:Log("INFO", category, message, metadata)
end

function Diagnostics:Warning(category, message, metadata)
    return self:Log("WARNING", category, message, metadata)
end

function Diagnostics:Error(category, message, metadata)
    return self:Log("ERROR", category, message, metadata)
end

function Diagnostics:Debug(category, message, metadata)
    return self:Log("DEBUG", category, message, metadata)
end

function Diagnostics:CaptureError(category, callback, ...)
    if type(callback) ~= "function" then
        error("CaptureError expects a function", 2)
    end

    local arguments = table.pack(...)

    local results = table.pack(
        pcall(function()
            return callback(table.unpack(
                arguments,
                1,
                arguments.n
            ))
        end)
    )

    if not results[1] then
        self:Error(category, results[2], {
            Captured = true,
        })

        return false, results[2]
    end

    return true, table.unpack(results, 2, results.n)
end

function Diagnostics:GetLogs()
    local result = {}

    for index, entry in ipairs(self._logs) do
        result[index] = entry
    end

    return result
end

function Diagnostics:GetLogsByLevel(level)
    level = normalizeLevel(level)

    if not level then
        error("Invalid diagnostic log level", 2)
    end

    local results = {}

    for _, entry in ipairs(self._logs) do
        if entry.Level == level then
            table.insert(results, entry)
        end
    end

    return results
end

function Diagnostics:GetLogsByCategory(category)
    category = safeString(category)

    local results = {}

    for _, entry in ipairs(self._logs) do
        if entry.Category == category then
            table.insert(results, entry)
        end
    end

    return results
end

function Diagnostics:Search(query)
    query = string.lower(safeString(query))

    local results = {}

    for _, entry in ipairs(self._logs) do
        local message = string.lower(entry.Message)
        local category = string.lower(entry.Category)

        if string.find(message, query, 1, true)
            or string.find(category, query, 1, true)
        then
            table.insert(results, entry)
        end
    end

    return results
end

function Diagnostics:GetLatest(count)
    count = math.max(0, math.floor(count or 10))

    local results = {}
    local first = math.max(1, #self._logs - count + 1)

    for index = first, #self._logs do
        table.insert(results, self._logs[index])
    end

    return results
end

function Diagnostics:GetStatistics()
    return {
        Total = self._statistics.Total,
        Info = self._statistics.Info,
        Warning = self._statistics.Warning,
        Error = self._statistics.Error,
        Debug = self._statistics.Debug,

        Stored = #self._logs,
        MaximumLogs = self._maximumLogs,
    }
end

function Diagnostics:SetMaximumLogs(maximum)
    if type(maximum) ~= "number"
        or maximum < 1
        or maximum % 1 ~= 0
    then
        error("Maximum logs must be a positive integer", 2)
    end

    self._maximumLogs = maximum

    while #self._logs > maximum do
        table.remove(self._logs, 1)
    end
end

function Diagnostics:SetEnabled(enabled)
    self.Enabled = enabled == true
end

function Diagnostics:IsEnabled()
    return self.Enabled
end

function Diagnostics:Export()
    local lines = {
        "FMO LUAU RUNTIME - DIAGNOSTICS",
        "================================",
        "",
    }

    for _, entry in ipairs(self._logs) do
        table.insert(
            lines,
            string.format(
                "[%s] [%s] [%s] %s",
                entry.Timestamp,
                entry.Level,
                entry.Category,
                entry.Message
            )
        )
    end

    return table.concat(lines, "\n")
end

function Diagnostics:Clear()
    local previousCount = #self._logs

    self._logs = {}

    return previousCount
end

function Diagnostics:Reset()
    self._logs = {}
    self._nextId = 0

    self._statistics = {
        Total = 0,
        Info = 0,
        Warning = 0,
        Error = 0,
        Debug = 0,
    }

    self.Enabled = true
    self._maximumLogs = 2000
end

return Diagnostics
