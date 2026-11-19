--[[
    FMO Memory Profiler
    Snapshot and trend analysis for MemoryManager's logical allocations.

    This module does not measure or claim to measure the Luau VM heap.
    Persistent allocations are reported as leak candidates, never confirmed leaks.
]]
local MemoryManager = require("./memory_manager")

local MemoryProfiler = {
    Enabled = true,
    MaximumSnapshots = 100,
    DefaultTopLimit = 10,
    _history = {},
    _nextId = 0,
    _statistics = {
        Captures = 0,
        Comparisons = 0,
        Cleared = 0,
    },
}

local function finiteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function validPositiveInteger(value)
    return finiteNumber(value) and value >= 1 and value % 1 == 0
end

local function copyRecord(record)
    return {
        Id = record.Id,
        Bytes = record.Bytes,
        Tag = record.Tag,
        Owner = record.Owner,
        CreatedAt = record.CreatedAt,
        UpdatedAt = record.UpdatedAt,
        Metadata = record.Metadata,
    }
end

local function copySnapshot(snapshot)
    local result = {
        Id = snapshot.Id,
        Label = snapshot.Label,
        CapturedAt = snapshot.CapturedAt,
        TotalBytes = snapshot.TotalBytes,
        AllocationCount = snapshot.AllocationCount,
        Allocations = {},
        ByTag = {},
        ByOwner = {},
        Top = {},
    }

    for id, record in pairs(snapshot.Allocations) do
        result.Allocations[id] = copyRecord(record)
    end
    for key, value in pairs(snapshot.ByTag) do
        result.ByTag[key] = { Count = value.Count, Bytes = value.Bytes }
    end
    for key, value in pairs(snapshot.ByOwner) do
        result.ByOwner[key] = { Count = value.Count, Bytes = value.Bytes }
    end
    for index, record in ipairs(snapshot.Top) do
        result.Top[index] = copyRecord(record)
    end
    return result
end

local function aggregate(map, key, bytes)
    key = key or "Default"
    local item = map[key]
    if not item then
        item = { Count = 0, Bytes = 0 }
        map[key] = item
    end
    item.Count += 1
    item.Bytes += bytes
end

local function sortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function MemoryProfiler:Capture(label)
    if not self.Enabled then
        return false, "Memory profiler is disabled"
    end
    if label ~= nil and (type(label) ~= "string" or label == "") then
        error("Snapshot label must be a non-empty string", 2)
    end

    local managerSnapshot = MemoryManager:Snapshot()
    self._nextId += 1

    local snapshot = {
        Id = self._nextId,
        Label = label or ("Snapshot " .. tostring(self._nextId)),
        CapturedAt = os.clock(),
        TotalBytes = managerSnapshot.TotalBytes,
        AllocationCount = 0,
        Allocations = {},
        ByTag = {},
        ByOwner = {},
        Top = {},
    }

    for id in pairs(managerSnapshot.Allocations) do
        local record = MemoryManager:GetAllocation(id)
        if record then
            snapshot.Allocations[id] = record
            snapshot.AllocationCount += 1
            aggregate(snapshot.ByTag, record.Tag, record.Bytes)
            aggregate(snapshot.ByOwner, record.Owner, record.Bytes)
            snapshot.Top[#snapshot.Top + 1] = copyRecord(record)
        end
    end

    table.sort(snapshot.Top, function(a, b)
        if a.Bytes == b.Bytes then return a.Id < b.Id end
        return a.Bytes > b.Bytes
    end)
    while #snapshot.Top > self.DefaultTopLimit do
        table.remove(snapshot.Top)
    end

    self._history[#self._history + 1] = snapshot
    while #self._history > self.MaximumSnapshots do
        table.remove(self._history, 1)
    end

    self._statistics.Captures += 1
    return true, copySnapshot(snapshot)
end

function MemoryProfiler:GetSnapshot(id)
    if not validPositiveInteger(id) then
        error("Snapshot id must be a positive integer", 2)
    end
    for _, snapshot in ipairs(self._history) do
        if snapshot.Id == id then
            return copySnapshot(snapshot)
        end
    end
    return nil
end

function MemoryProfiler:GetLatest()
    local snapshot = self._history[#self._history]
    return snapshot and copySnapshot(snapshot) or nil
end

function MemoryProfiler:GetHistory()
    local result = {}
    for index, snapshot in ipairs(self._history) do
        result[index] = {
            Id = snapshot.Id,
            Label = snapshot.Label,
            CapturedAt = snapshot.CapturedAt,
            TotalBytes = snapshot.TotalBytes,
            AllocationCount = snapshot.AllocationCount,
        }
    end
    return result
end

function MemoryProfiler:Compare(fromId, toId)
    local before = self:GetSnapshot(fromId)
    local after = self:GetSnapshot(toId)
    if not before or not after then
        return false, "Snapshot not found in retained history"
    end
    if before.Id == after.Id then
        return false, "Cannot compare a snapshot with itself"
    end

    local added, removed, changed = {}, {}, {}
    local addedBytes, removedBytes, changedBytes = 0, 0, 0

    for id, record in pairs(after.Allocations) do
        local previous = before.Allocations[id]
        if not previous then
            added[id] = copyRecord(record)
            addedBytes += record.Bytes
        elseif previous.Bytes ~= record.Bytes then
            changed[id] = {
                Before = previous.Bytes,
                After = record.Bytes,
                Delta = record.Bytes - previous.Bytes,
                Tag = record.Tag,
                Owner = record.Owner,
            }
            changedBytes += record.Bytes - previous.Bytes
        end
    end

    for id, record in pairs(before.Allocations) do
        if not after.Allocations[id] then
            removed[id] = copyRecord(record)
            removedBytes += record.Bytes
        end
    end

    self._statistics.Comparisons += 1
    return true, {
        From = before.Id,
        To = after.Id,
        Added = added,
        Removed = removed,
        Changed = changed,
        AddedCount = (function() local n=0; for _ in pairs(added) do n+=1 end; return n end)(),
        RemovedCount = (function() local n=0; for _ in pairs(removed) do n+=1 end; return n end)(),
        ChangedCount = (function() local n=0; for _ in pairs(changed) do n+=1 end; return n end)(),
        AddedBytes = addedBytes,
        RemovedBytes = removedBytes,
        ChangedBytes = changedBytes,
        DeltaBytes = after.TotalBytes - before.TotalBytes,
        BeforeBytes = before.TotalBytes,
        AfterBytes = after.TotalBytes,
    }
end

function MemoryProfiler:GetLeakCandidates(minimumSnapshots)
    minimumSnapshots = minimumSnapshots or 3
    if not validPositiveInteger(minimumSnapshots) then
        error("Minimum snapshots must be a positive integer", 2)
    end
    if #self._history < minimumSnapshots then
        return {}, "Not enough snapshots to evaluate persistence"
    end

    local candidates = {}
    local first = #self._history - minimumSnapshots + 1
    local latest = self._history[#self._history]

    for id, latestRecord in pairs(latest.Allocations) do
        local presentEverywhere = true
        for index = first, #self._history do
            if not self._history[index].Allocations[id] then
                presentEverywhere = false
                break
            end
        end
        if presentEverywhere then
            candidates[#candidates + 1] = {
                Id = id,
                Bytes = latestRecord.Bytes,
                Tag = latestRecord.Tag,
                Owner = latestRecord.Owner,
                AgeSnapshots = minimumSnapshots,
                CreatedAt = latestRecord.CreatedAt,
                UpdatedAt = latestRecord.UpdatedAt,
                Classification = "Persistent allocation candidate; review ownership and lifecycle",
            }
        end
    end

    table.sort(candidates, function(a, b)
        if a.Bytes == b.Bytes then return a.Id < b.Id end
        return a.Bytes > b.Bytes
    end)
    return candidates
end

function MemoryProfiler:GetSummary()
    local latest = self._history[#self._history]
    local memory = MemoryManager:GetStatistics()
    return {
        Enabled = self.Enabled,
        SnapshotCount = #self._history,
        MaximumSnapshots = self.MaximumSnapshots,
        LatestSnapshotId = latest and latest.Id or nil,
        LogicalBytes = memory.TotalBytes,
        PeakLogicalBytes = memory.PeakBytes,
        AllocationCount = memory.AllocationCount,
        Captures = self._statistics.Captures,
        Comparisons = self._statistics.Comparisons,
        Cleared = self._statistics.Cleared,
        Measurement = "MemoryManager logical allocation accounting; not the Luau VM heap",
    }
end

function MemoryProfiler:GetBreakdown(snapshotId, dimension)
    local snapshot = snapshotId and self:GetSnapshot(snapshotId) or self:GetLatest()
    if not snapshot then return nil, "No memory snapshot available" end
    local source
    if dimension == "Tag" then
        source = snapshot.ByTag
    elseif dimension == "Owner" then
        source = snapshot.ByOwner
    else
        error("Breakdown dimension must be 'Tag' or 'Owner'", 2)
    end

    local result = {}
    for _, key in ipairs(sortedKeys(source)) do
        result[#result + 1] = {
            Name = key,
            Count = source[key].Count,
            Bytes = source[key].Bytes,
        }
    end
    table.sort(result, function(a, b)
        if a.Bytes == b.Bytes then return a.Name < b.Name end
        return a.Bytes > b.Bytes
    end)
    return result
end

function MemoryProfiler:SetEnabled(value)
    if type(value) ~= "boolean" then
        error("Enabled state must be a boolean", 2)
    end
    self.Enabled = value
    return self.Enabled
end

function MemoryProfiler:SetMaximumSnapshots(value)
    if not validPositiveInteger(value) then
        error("Maximum snapshots must be a positive integer", 2)
    end
    self.MaximumSnapshots = value
    while #self._history > value do
        table.remove(self._history, 1)
    end
    return true
end

function MemoryProfiler:SetTopLimit(value)
    if not validPositiveInteger(value) then
        error("Top limit must be a positive integer", 2)
    end
    self.DefaultTopLimit = value
    return true
end

function MemoryProfiler:Clear()
    local count = #self._history
    self._history = {}
    self._statistics.Cleared += count
    return count
end

function MemoryProfiler:Reset()
    self.Enabled = true
    self.MaximumSnapshots = 100
    self.DefaultTopLimit = 10
    self._history = {}
    self._nextId = 0
    self._statistics = { Captures = 0, Comparisons = 0, Cleared = 0 }
    return true
end

return MemoryProfiler
