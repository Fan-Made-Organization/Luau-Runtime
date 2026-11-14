local ErrorHandler = {}

ErrorHandler.Enabled = true
ErrorHandler.MaximumErrors = 1000

ErrorHandler._errors = {}
ErrorHandler._handlers = {}
ErrorHandler._nextId = 1

ErrorHandler._statistics = {
    TotalErrors = 0,
    Warnings = 0,
    CriticalErrors = 0,
    CapturedErrors = 0,
    HandledErrors = 0,
    UnhandledErrors = 0,
}

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function createErrorId()
    local id = ErrorHandler._nextId
    ErrorHandler._nextId += 1

    return string.format("FMO-ERR-%08d", id)
end

local function classifyError(message)
    local text = string.lower(tostring(message))

    if string.find(text, "syntax", 1, true)
        or string.find(text, "parse", 1, true) then
        return "SYNTAX"
    end

    if string.find(text, "attempt to", 1, true)
        or string.find(text, "nil value", 1, true) then
        return "RUNTIME"
    end

    if string.find(text, "timeout", 1, true) then
        return "TIMEOUT"
    end

    if string.find(text, "memory", 1, true) then
        return "MEMORY"
    end

    if string.find(text, "permission", 1, true)
        or string.find(text, "access denied", 1, true) then
        return "PERMISSION"
    end

    return "GENERAL"
end

function ErrorHandler:Report(message, options)
    options = options or {}

    if not self.Enabled then
        return nil
    end

    local errorData = {
        Id = createErrorId(),
        Message = tostring(message),
        Category = options.Category or classifyError(message),
        Severity = options.Severity or "ERROR",
        Source = options.Source or "Unknown",
        Script = options.Script,
        Timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        Clock = os.clock(),
        Traceback = options.Traceback,
        Metadata = options.Metadata or {},
        Handled = false,
    }

    table.insert(self._errors, errorData)

    self._statistics.TotalErrors += 1

    if errorData.Severity == "WARNING" then
        self._statistics.Warnings += 1
    end

    if errorData.Severity == "CRITICAL" then
        self._statistics.CriticalErrors += 1
    end

    if #self._errors > self.MaximumErrors then
        table.remove(self._errors, 1)
    end

    for _, callback in ipairs(self._handlers) do
        pcall(callback, errorData)
    end

    return errorData
end

function ErrorHandler:Warning(message, options)
    options = options or {}
    options.Severity = "WARNING"

    return self:Report(message, options)
end

function ErrorHandler:Critical(message, options)
    options = options or {}
    options.Severity = "CRITICAL"

    return self:Report(message, options)
end

function ErrorHandler:Capture(callback, ...)
    assert(type(callback) == "function", "Expected a function")

    local arguments = table.pack(...)

    local results = table.pack(pcall(function()
        return callback(table.unpack(arguments, 1, arguments.n))
    end))

    if not results[1] then
        local errorData = self:Report(results[2], {
            Category = classifyError(results[2]),
            Source = "Capture",
            Traceback = debug and debug.traceback
                and debug.traceback("", 2)
                or nil,
        })

        self._statistics.CapturedErrors += 1
        self._statistics.UnhandledErrors += 1

        return false, results[2], errorData
    end

    return true, table.unpack(results, 2, results.n)
end

function ErrorHandler:Handle(errorId)
    for _, errorData in ipairs(self._errors) do
        if errorData.Id == errorId then
            if not errorData.Handled then
                errorData.Handled = true
                self._statistics.HandledErrors += 1

                if self._statistics.UnhandledErrors > 0 then
                    self._statistics.UnhandledErrors -= 1
                end
            end

            return true, errorData
        end
    end

    return false, "Error not found"
end

function ErrorHandler:GetError(errorId)
    for _, errorData in ipairs(self._errors) do
        if errorData.Id == errorId then
            return copyTable(errorData)
        end
    end

    return nil
end

function ErrorHandler:GetErrors()
    local result = {}

    for index, errorData in ipairs(self._errors) do
        result[index] = copyTable(errorData)
    end

    return result
end

function ErrorHandler:GetErrorsByCategory(category)
    local result = {}

    for _, errorData in ipairs(self._errors) do
        if errorData.Category == category then
            table.insert(result, copyTable(errorData))
        end
    end

    return result
end

function ErrorHandler:GetErrorsBySeverity(severity)
    local result = {}

    for _, errorData in ipairs(self._errors) do
        if errorData.Severity == severity then
            table.insert(result, copyTable(errorData))
        end
    end

    return result
end

function ErrorHandler:GetUnhandledErrors()
    local result = {}

    for _, errorData in ipairs(self._errors) do
        if not errorData.Handled then
            table.insert(result, copyTable(errorData))
        end
    end

    return result
end

function ErrorHandler:GetLatest()
    local errorData = self._errors[#self._errors]

    if errorData then
        return copyTable(errorData)
    end

    return nil
end

function ErrorHandler:Search(query)
    query = string.lower(tostring(query))
    local result = {}

    for _, errorData in ipairs(self._errors) do
        local message = string.lower(errorData.Message)
        local source = string.lower(errorData.Source)
        local category = string.lower(errorData.Category)

        if string.find(message, query, 1, true)
            or string.find(source, query, 1, true)
            or string.find(category, query, 1, true) then
            table.insert(result, copyTable(errorData))
        end
    end

    return result
end

function ErrorHandler:Connect(callback)
    assert(type(callback) == "function", "Expected a function")

    table.insert(self._handlers, callback)

    local connection = {
        Connected = true,
    }

    function connection:Disconnect()
        if not self.Connected then
            return
        end

        self.Connected = false

        for index, handler in ipairs(ErrorHandler._handlers) do
            if handler == callback then
                table.remove(ErrorHandler._handlers, index)
                break
            end
        end
    end

    return connection
end

function ErrorHandler:GetStatistics()
    local result = copyTable(self._statistics)

    result.StoredErrors = #self._errors
    result.RegisteredHandlers = #self._handlers

    return result
end

function ErrorHandler:SetEnabled(enabled)
    self.Enabled = enabled == true
end

function ErrorHandler:IsEnabled()
    return self.Enabled
end

function ErrorHandler:SetMaximumErrors(amount)
    assert(type(amount) == "number" and amount >= 1,
        "Maximum errors must be a positive number")

    self.MaximumErrors = math.floor(amount)

    while #self._errors > self.MaximumErrors do
        table.remove(self._errors, 1)
    end
end

function ErrorHandler:Clear()
    self._errors = {}
    self._statistics.UnhandledErrors = 0

    return true
end

function ErrorHandler:Reset()
    self:Clear()

    self._handlers = {}
    self._nextId = 1

    for key in pairs(self._statistics) do
        self._statistics[key] = 0
    end

    self.Enabled = true
    self.MaximumErrors = 1000

    return true
end

return ErrorHandler
