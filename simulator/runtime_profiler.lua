local RuntimeProfiler = {
    Enabled = true,
    MaximumSamples = 500,

    _profiles = {},
    _active = {},
    _nextId = 0,

    _statistics = {
        Started = 0,
        Completed = 0,
        Failed = 0,
        TotalDuration = 0,
    },
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function getOrCreateProfile(self, name)
    local profile = self._profiles[name]

    if not profile then
        profile = {
            Name = name,
            Count = 0,
            Total = 0,
            Minimum = math.huge,
            Maximum = 0,
            Latest = 0,
            Samples = {},
        }

        self._profiles[name] = profile
    end

    return profile
end

function RuntimeProfiler:Begin(name)
    if not self.Enabled then
        return nil
    end

    if type(name) ~= "string" or name == "" then
        error("Profile name must be a non-empty string", 2)
    end

    self._nextId += 1

    local token = {
        Id = self._nextId,
        Name = name,
        StartedAt = os.clock(),
        Active = true,
        Owner = self,
    }

    self._active[token] = true
    self._statistics.Started += 1

    return token
end

function RuntimeProfiler:End(token)
    if type(token) ~= "table"
        or token.Owner ~= self
        or token.Active ~= true
        or self._active[token] ~= true
    then
        return nil, "Invalid or inactive profile token"
    end

    local elapsed = os.clock() - token.StartedAt

    if not isFiniteNumber(elapsed) or elapsed < 0 then
        token.Active = false
        self._active[token] = nil
        self._statistics.Failed += 1
        return nil, "Profiler clock returned an invalid duration"
    end

    token.Active = false
    self._active[token] = nil

    local profile = getOrCreateProfile(self, token.Name)

    profile.Count += 1
    profile.Total += elapsed
    profile.Minimum = math.min(profile.Minimum, elapsed)
    profile.Maximum = math.max(profile.Maximum, elapsed)
    profile.Latest = elapsed

    table.insert(profile.Samples, elapsed)

    while #profile.Samples > self.MaximumSamples do
        table.remove(profile.Samples, 1)
    end

    self._statistics.Completed += 1
    self._statistics.TotalDuration += elapsed

    return elapsed
end

function RuntimeProfiler:Measure(name, callback, ...)
    if type(callback) ~= "function" then
        error("Measure expects a callback function", 2)
    end

    if not self.Enabled then
        return callback(...)
    end

    local token = self:Begin(name)
    local arguments = table.pack(...)
    local results = table.pack(pcall(function()
        return callback(table.unpack(arguments, 1, arguments.n))
    end))

    local elapsed, endError = self:End(token)

    if not results[1] then
        self._statistics.Failed += 1
        error(results[2], 0)
    end

    if elapsed == nil then
        error(endError or "Unable to finish profile measurement", 0)
    end

    return table.unpack(results, 2, results.n)
end

function RuntimeProfiler:GetProfile(name)
    local profile = self._profiles[name]

    if not profile then
        return nil
    end

    local samples = {}
    for index, value in ipairs(profile.Samples) do
        samples[index] = value
    end

    return {
        Name = profile.Name,
        Count = profile.Count,
        Total = profile.Total,
        Average = profile.Count > 0 and profile.Total / profile.Count or 0,
        Minimum = profile.Count > 0 and profile.Minimum or 0,
        Maximum = profile.Maximum,
        Latest = profile.Latest,
        Samples = samples,
    }
end

function RuntimeProfiler:GetReport()
    local report = {}

    for name in pairs(self._profiles) do
        table.insert(report, self:GetProfile(name))
    end

    table.sort(report, function(a, b)
        if a.Total == b.Total then
            return a.Name < b.Name
        end

        return a.Total > b.Total
    end)

    return report
end

function RuntimeProfiler:GetStatistics()
    local result = {
        Started = self._statistics.Started,
        Completed = self._statistics.Completed,
        Failed = self._statistics.Failed,
        TotalDuration = self._statistics.TotalDuration,
        Active = 0,
        ProfileCount = 0,
        Enabled = self.Enabled,
        MaximumSamples = self.MaximumSamples,
    }

    for _ in pairs(self._active) do
        result.Active += 1
    end

    for _ in pairs(self._profiles) do
        result.ProfileCount += 1
    end

    return result
end

function RuntimeProfiler:SetEnabled(enabled)
    if type(enabled) ~= "boolean" then
        error("Profiler enabled state must be a boolean", 2)
    end

    self.Enabled = enabled
    return self.Enabled
end

function RuntimeProfiler:SetMaximumSamples(amount)
    if not isFiniteNumber(amount)
        or amount < 1
        or amount % 1 ~= 0
    then
        error("Maximum samples must be a positive integer", 2)
    end

    self.MaximumSamples = amount

    for _, profile in pairs(self._profiles) do
        while #profile.Samples > amount do
            table.remove(profile.Samples, 1)
        end
    end

    return true
end

function RuntimeProfiler:Clear(name)
    if name ~= nil then
        if type(name) ~= "string" then
            error("Profile name must be a string", 2)
        end

        for token in pairs(self._active) do
            if token.Name == name then
                return false, "Cannot clear a profile while it is active"
            end
        end

        if self._profiles[name] == nil then
            return false
        end

        self._profiles[name] = nil
        return true
    end

    if next(self._active) ~= nil then
        return false, "Cannot clear profiles while measurements are active"
    end

    self._profiles = {}
    return true
end

function RuntimeProfiler:Reset()
    for token in pairs(self._active) do
        token.Active = false
    end

    self._active = {}
    self._profiles = {}
    self._nextId = 0

    self._statistics = {
        Started = 0,
        Completed = 0,
        Failed = 0,
        TotalDuration = 0,
    }

    self.Enabled = true
    self.MaximumSamples = 500

    return true
end

return RuntimeProfiler
