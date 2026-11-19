--[[
    FMO Runtime Resource Intelligence
    Read-only cross-system audits for logical memory, managed GC and resources.
    Findings are diagnostics, not automatic cleanup decisions.
]]
local MemoryManager = require("./memory_manager")
local ResourceManager = require("./resource_manager")
local GarbageCollector = require("./garbage_collector")
local InstanceManager = require("./instance_manager")

local Intelligence = {
    Enabled = true,
    MaximumReports = 50,
    LongLivedAllocationSeconds = 300,
    LargeAllocationBytes = 16 * 1024 * 1024,
    _history = {},
    _nextId = 0,
    _statistics = { Scans = 0, Findings = 0, Errors = 0 },
}

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
    return result
end

local function add(findings, severity, code, message, details)
    findings[#findings + 1] = {
        Severity = severity, Code = code, Message = message,
        Details = details or {},
    }
end

local function safeValidate(system, label, findings)
    if type(system.Validate) ~= "function" then return end
    local ok, valid, details = pcall(system.Validate, system)
    if not ok then
        add(findings, "ERROR", label .. "_VALIDATION_ERROR",
            label .. " validation raised an error", { Error = tostring(valid) })
    elseif not valid then
        add(findings, "ERROR", label .. "_INVALID",
            label .. " reported an inconsistent state", { Details = details })
    end
end

function Intelligence:Scan(options)
    if not self.Enabled then return false, "Resource Intelligence is disabled" end
    options = options or {}
    if type(options) ~= "table" then error("Scan options must be a table", 2) end

    local findings = {}
    local now = os.clock()
    local memory = MemoryManager:GetStatistics()
    local gc = GarbageCollector:GetStatistics()
    local resources = ResourceManager:GetStatistics()

    safeValidate(MemoryManager, "MEMORY", findings)
    safeValidate(ResourceManager, "RESOURCE", findings)
    safeValidate(GarbageCollector, "GARBAGE_COLLECTOR", findings)
    safeValidate(InstanceManager, "INSTANCE_MANAGER", findings)

    if memory.OverLimit then
        add(findings, "CRITICAL", "MEMORY_OVER_LIMIT",
            "Logical memory accounting exceeds the configured limit",
            { Bytes = memory.TotalBytes, Limit = memory.MaximumBytes })
    end

    local allocations = {}
    for _, id in ipairs(MemoryManager:GetTop(options.TopLimit or 100000)) do
        allocations[id.Id] = id
        if id.Bytes >= self.LargeAllocationBytes then
            add(findings, "WARNING", "LARGE_ALLOCATION",
                "A logical allocation exceeds the large-allocation threshold",
                { Id = id.Id, Bytes = id.Bytes, Owner = id.Owner, Tag = id.Tag })
        end
        local age = math.max(0, now - (id.CreatedAt or now))
        if age >= self.LongLivedAllocationSeconds then
            add(findings, "INFO", "LONG_LIVED_ALLOCATION",
                "A logical allocation has remained active for an extended period",
                { Id = id.Id, AgeSeconds = age, Bytes = id.Bytes, Owner = id.Owner })
        end
    end

    local gcRecords = {}
    for _, id in ipairs(GarbageCollector:GetTrackedIds()) do
        gcRecords[id] = true
    end
    for id, record in pairs(allocations) do
        if record.Owner == "Runtime" and not gcRecords[id] then
            add(findings, "INFO", "UNLINKED_RUNTIME_ALLOCATION",
                "A Runtime-owned allocation is not linked by the managed collector",
                { Id = id, Bytes = record.Bytes })
        end
    end

    local resourceIds = ResourceManager:List()
    for _, id in ipairs(resourceIds) do
        local resource = ResourceManager:Get(id)
        if resource and resource.Scope then
            local scope = ResourceManager:GetScope(resource.Scope)
            if not scope then
                add(findings, "ERROR", "RESOURCE_SCOPE_MISSING",
                    "A registered resource references a missing scope",
                    { ResourceId = id, Scope = resource.Scope })
            elseif scope.Closed then
                add(findings, "WARNING", "RESOURCE_IN_CLOSED_SCOPE",
                    "A resource remains registered in a closed scope",
                    { ResourceId = id, Scope = resource.Scope })
            end
        end
    end

    table.sort(findings, function(a, b)
        if a.Severity ~= b.Severity then
            local rank = { CRITICAL = 1, ERROR = 2, WARNING = 3, INFO = 4 }
            return (rank[a.Severity] or 9) < (rank[b.Severity] or 9)
        end
        if a.Code ~= b.Code then return a.Code < b.Code end
        return tostring(a.Details.Id or a.Details.ResourceId or "") <
            tostring(b.Details.Id or b.Details.ResourceId or "")
    end)

    self._nextId += 1
    local report = {
        Id = self._nextId,
        CapturedAt = now,
        Findings = findings,
        FindingCount = #findings,
        Memory = memory,
        GarbageCollector = gc,
        Resources = resources,
        Instances = InstanceManager:GetStatistics(),
        Health = "HEALTHY",
    }
    for _, finding in ipairs(findings) do
        if finding.Severity == "CRITICAL" or finding.Severity == "ERROR" then
            report.Health = "DEGRADED"; break
        elseif finding.Severity == "WARNING" then
            report.Health = "WARNING"
        end
    end

    self._history[#self._history + 1] = report
    while #self._history > self.MaximumReports do table.remove(self._history, 1) end
    self._statistics.Scans += 1
    self._statistics.Findings += #findings
    return true, copy(report)
end

function Intelligence:GetLatest()
    local report = self._history[#self._history]
    return report and copy(report) or nil
end

function Intelligence:GetReport(id)
    for _, report in ipairs(self._history) do
        if report.Id == id then return copy(report) end
    end
    return nil
end

function Intelligence:GetHistory()
    local result = {}
    for _, report in ipairs(self._history) do
        result[#result + 1] = {
            Id = report.Id, CapturedAt = report.CapturedAt,
            FindingCount = report.FindingCount, Health = report.Health,
        }
    end
    return result
end

function Intelligence:GetFindings(severity)
    local report = self._history[#self._history]
    local result = {}
    if not report then return result end
    for _, finding in ipairs(report.Findings) do
        if severity == nil or finding.Severity == severity then
            result[#result + 1] = copy(finding)
        end
    end
    return result
end

function Intelligence:SetThresholds(options)
    if type(options) ~= "table" then error("Thresholds must be a table", 2) end
    local age = options.LongLivedAllocationSeconds
    local bytes = options.LargeAllocationBytes
    if age ~= nil and (type(age) ~= "number" or age < 0 or age ~= age or age == math.huge) then
        error("Long-lived threshold must be a finite non-negative number", 2)
    end
    if bytes ~= nil and (type(bytes) ~= "number" or bytes < 0 or bytes ~= bytes or bytes == math.huge) then
        error("Large allocation threshold must be a finite non-negative number", 2)
    end
    if age ~= nil then self.LongLivedAllocationSeconds = age end
    if bytes ~= nil then self.LargeAllocationBytes = bytes end
    return true
end

function Intelligence:SetMaximumReports(value)
    if type(value) ~= "number" or value < 1 or value % 1 ~= 0 then
        error("Maximum reports must be a positive integer", 2)
    end
    self.MaximumReports = value
    while #self._history > value do table.remove(self._history, 1) end
    return true
end

function Intelligence:SetEnabled(value)
    self.Enabled = value == true
    return self.Enabled
end

function Intelligence:Clear()
    local count = #self._history
    self._history = {}
    return count
end

function Intelligence:GetStatistics()
    return {
        Enabled = self.Enabled, Reports = #self._history,
        MaximumReports = self.MaximumReports,
        Scans = self._statistics.Scans,
        Findings = self._statistics.Findings,
        Errors = self._statistics.Errors,
    }
end

function Intelligence:Reset()
    self:Clear()
    self.Enabled = true
    self.MaximumReports = 50
    self.LongLivedAllocationSeconds = 300
    self.LargeAllocationBytes = 16 * 1024 * 1024
    self._nextId = 0
    self._statistics = { Scans = 0, Findings = 0, Errors = 0 }
    return true
end

return Intelligence
