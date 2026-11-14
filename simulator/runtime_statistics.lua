local RuntimeStatistics = {}

RuntimeStatistics.Enabled = true
RuntimeStatistics.MaximumSamples = 500

RuntimeStatistics._counters = {}
RuntimeStatistics._values = {}
RuntimeStatistics._timers = {}
RuntimeStatistics._samples = {}
RuntimeStatistics._providers = {}

RuntimeStatistics._statistics = {
    TotalMeasurements = 0,
    TotalSamples = 0,
    TotalIncrements = 0,
    TotalSnapshots = 0,
}

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end

    return result
end

local function getClock()
    return os.clock()
end

function RuntimeStatistics:Increment(name, amount)
    if not self.Enabled then
        return false
    end

    assert(type(name) == "string", "Counter name must be a string")

    amount = amount or 1

    assert(type(amount) == "number", "Amount must be a number")

    self._counters[name] = (self._counters[name] or 0) + amount
    self._statistics.TotalIncrements += 1

    return self._counters[name]
end

function RuntimeStatistics:SetCounter(name, value)
    if not self.Enabled then
        return false
    end

    assert(type(name) == "string", "Counter name must be a string")
    assert(type(value) == "number", "Value must be a number")

    self._counters[name] = value

    return true
end

function RuntimeStatistics:GetCounter(name)
    return self._counters[name] or 0
end

function RuntimeStatistics:SetValue(name, value)
    if not self.Enabled then
        return false
    end

    assert(type(name) == "string", "Value name must be a string")

    self._values[name] = value

    return true
end

function RuntimeStatistics:GetValue(name)
    return self._values[name]
end

function RuntimeStatistics:BeginMeasure(name)
    if not self.Enabled then
        return nil
    end

    assert(type(name) == "string", "Measurement name must be a string")

    local token = {
        Name = name,
        StartedAt = getClock(),
        Active = true,
    }

    self._timers[token] = true

    return token
end

function RuntimeStatistics:EndMeasure(token)
    if not token or not token.Active then
        return nil, "Invalid measurement token"
    end

    local elapsed = getClock() - token.StartedAt

    token.Active = false
    self._timers[token] = nil

    self:Record(token.Name, elapsed)

    self._statistics.TotalMeasurements += 1

    return elapsed
end

function RuntimeStatistics:Record(name, value)
    if not self.Enabled then
        return false
    end

    assert(type(name) == "string", "Sample name must be a string")
    assert(type(value) == "number", "Sample value must be a number")

    local samples = self._samples[name]

    if not samples then
        samples = {}
        self._samples[name] = samples
    end

    table.insert(samples, value)

    if #samples > self.MaximumSamples then
        table.remove(samples, 1)
    end

    self._statistics.TotalSamples += 1

    return true
end

function RuntimeStatistics:GetSamples(name)
    return copyTable(self._samples[name] or {})
end

function RuntimeStatistics:GetSampleStatistics(name)
    local samples = self._samples[name]

    if not samples or #samples == 0 then
        return nil
    end

    local minimum = math.huge
    local maximum = -math.huge
    local total = 0

    for _, value in ipairs(samples) do
        minimum = math.min(minimum, value)
        maximum = math.max(maximum, value)
        total += value
    end

    local average = total / #samples

    return {
        Count = #samples,
        Minimum = minimum,
        Maximum = maximum,
        Average = average,
        Latest = samples[#samples],
        Total = total,
    }
end

function RuntimeStatistics:RegisterProvider(name, callback)
    assert(type(name) == "string", "Provider name must be a string")
    assert(type(callback) == "function", "Provider must be a function")

    self._providers[name] = callback

    return true
end

function RuntimeStatistics:UnregisterProvider(name)
    if not self._providers[name] then
        return false
    end

    self._providers[name] = nil

    return true
end

function RuntimeStatistics:GetProviderData()
    local result = {}

    for name, callback in pairs(self._providers) do
        local success, data = pcall(callback)

        if success then
            result[name] = data
        else
            result[name] = {
                Error = tostring(data),
            }
        end
    end

    return result
end

function RuntimeStatistics:GetMemoryUsage()
    local result = {
        Available = false,
        Kilobytes = nil,
        Megabytes = nil,
    }

    if type(collectgarbage) == "function" then
        local success, memory = pcall(collectgarbage, "count")

        if success and type(memory) == "number" then
            result.Available = true
            result.Kilobytes = memory
            result.Megabytes = memory / 1024
        end
    end

    return result
end

function RuntimeStatistics:GetCounters()
    return copyTable(self._counters)
end

function RuntimeStatistics:GetValues()
    return copyTable(self._values)
end

function RuntimeStatistics:GetAllSamples()
    return copyTable(self._samples)
end

function RuntimeStatistics:GetSystemStatistics()
    return {
        Counters = self:GetCounters(),
        Values = self:GetValues(),
        Samples = self:GetAllSamples(),
        Memory = self:GetMemoryUsage(),
        Providers = self:GetProviderData(),
    }
end

function RuntimeStatistics:GetStatistics()
    local result = copyTable(self._statistics)

    result.Enabled = self.Enabled
    result.RegisteredProviders = 0
    result.ActiveMeasurements = 0

    for _ in pairs(self._providers) do
        result.RegisteredProviders += 1
    end

    for _ in pairs(self._timers) do
        result.ActiveMeasurements += 1
    end

    result.Counters = self:GetCounters()

    return result
end

function RuntimeStatistics:SetMaximumSamples(amount)
    assert(type(amount) == "number" and amount >= 1,
        "Maximum samples must be a positive number")

    self.MaximumSamples = math.floor(amount)

    for _, samples in pairs(self._samples) do
        while #samples > self.MaximumSamples do
            table.remove(samples, 1)
        end
    end

    return true
end

function RuntimeStatistics:SetEnabled(enabled)
    self.Enabled = enabled == true
end

function RuntimeStatistics:IsEnabled()
    return self.Enabled
end

function RuntimeStatistics:ClearSamples()
    self._samples = {}

    return true
end

function RuntimeStatistics:ClearCounters()
    self._counters = {}

    return true
end

function RuntimeStatistics:Reset()
    self._counters = {}
    self._values = {}
    self._timers = {}
    self._samples = {}
    self._providers = {}

    for key in pairs(self._statistics) do
        self._statistics[key] = 0
    end

    self.Enabled = true
    self.MaximumSamples = 500

    return true
end

return RuntimeStatistics
