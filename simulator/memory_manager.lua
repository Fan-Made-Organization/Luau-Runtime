-- Memory Manager: explicit accounting for runtime-owned allocations.
-- This is logical accounting, not a measurement of the Luau VM heap.
local MemoryManager = {
    Enabled = true,
    MaximumBytes = math.huge,
    _allocations = {},
    _totalBytes = 0,
    _peakBytes = 0,
    _statistics = { Allocations = 0, Releases = 0, Resizes = 0, Rejections = 0 },
}

local function validName(value)
    return type(value) == "string" and value ~= ""
end

local function validBytes(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

local function copyRecord(record)
    if not record then return nil end
    return {
        Id = record.Id, Bytes = record.Bytes, Tag = record.Tag,
        Owner = record.Owner, CreatedAt = record.CreatedAt,
        UpdatedAt = record.UpdatedAt, Metadata = record.Metadata,
    }
end

function MemoryManager:Allocate(id, bytes, options)
    if not validName(id) then error("Allocation id must be a non-empty string", 2) end
    if not validBytes(bytes) then error("Allocation size must be a finite non-negative number", 2) end
    if self._allocations[id] then return false, "Allocation already exists" end
    if not self.Enabled then return false, "Memory manager is disabled" end
    if self._totalBytes + bytes > self.MaximumBytes then
        self._statistics.Rejections += 1
        return false, "Memory limit exceeded"
    end
    options = options or {}
    if type(options) ~= "table" then error("Allocation options must be a table", 2) end
    local now = os.clock()
    local record = {
        Id = id, Bytes = bytes, Tag = options.Tag or "Default",
        Owner = options.Owner or "Runtime", CreatedAt = now,
        UpdatedAt = now, Metadata = options.Metadata,
    }
    self._allocations[id] = record
    self._totalBytes += bytes
    self._peakBytes = math.max(self._peakBytes, self._totalBytes)
    self._statistics.Allocations += 1
    return true, copyRecord(record)
end

function MemoryManager:Release(id)
    local record = self._allocations[id]
    if not record then return false end
    self._totalBytes -= record.Bytes
    self._allocations[id] = nil
    self._statistics.Releases += 1
    return true, record.Bytes
end

function MemoryManager:HasAllocation(id) return self._allocations[id] ~= nil end
function MemoryManager:GetAllocation(id) return copyRecord(self._allocations[id]) end
function MemoryManager:GetAllocationCount()
    local count = 0
    for _ in pairs(self._allocations) do count += 1 end
    return count
end
function MemoryManager:GetTotalBytes() return self._totalBytes end
function MemoryManager:GetPeakBytes() return self._peakBytes end
function MemoryManager:GetLimit() return self.MaximumBytes end
function MemoryManager:SetLimit(bytes)
    if not validBytes(bytes) then error("Memory limit must be finite and non-negative", 2) end
    self.MaximumBytes = bytes
    return self._totalBytes <= bytes
end
function MemoryManager:GetAvailableBytes()
    if self.MaximumBytes == math.huge then return math.huge end
    return math.max(0, self.MaximumBytes - self._totalBytes)
end
function MemoryManager:IsOverLimit() return self._totalBytes > self.MaximumBytes end
function MemoryManager:SetEnabled(value) self.Enabled = value == true; return self.Enabled end
function MemoryManager:IsEnabled() return self.Enabled end

function MemoryManager:Resize(id, bytes)
    if not validBytes(bytes) then error("Allocation size must be finite and non-negative", 2) end
    local record = self._allocations[id]
    if not record then return false, "Allocation not found" end
    local nextTotal = self._totalBytes - record.Bytes + bytes
    if nextTotal > self.MaximumBytes then
        self._statistics.Rejections += 1
        return false, "Memory limit exceeded"
    end
    self._totalBytes = nextTotal
    record.Bytes = bytes
    record.UpdatedAt = os.clock()
    self._peakBytes = math.max(self._peakBytes, self._totalBytes)
    self._statistics.Resizes += 1
    return true, copyRecord(record)
end

function MemoryManager:SetTag(id, tag)
    if not validName(tag) then error("Tag must be a non-empty string", 2) end
    local record = self._allocations[id]
    if not record then return false end
    record.Tag = tag; record.UpdatedAt = os.clock()
    return true
end
function MemoryManager:SetOwner(id, owner)
    if not validName(owner) then error("Owner must be a non-empty string", 2) end
    local record = self._allocations[id]
    if not record then return false end
    record.Owner = owner; record.UpdatedAt = os.clock()
    return true
end
function MemoryManager:TransferOwner(id, owner) return self:SetOwner(id, owner) end

function MemoryManager:GetByTag(tag)
    local result = {}
    for id, record in pairs(self._allocations) do
        if record.Tag == tag then result[id] = copyRecord(record) end
    end
    return result
end
function MemoryManager:GetByOwner(owner)
    local result = {}
    for id, record in pairs(self._allocations) do
        if record.Owner == owner then result[id] = copyRecord(record) end
    end
    return result
end
function MemoryManager:CountByTag(tag)
    local count = 0
    for _, record in pairs(self._allocations) do
        if record.Tag == tag then count += 1 end
    end
    return count
end
function MemoryManager:CountByOwner(owner)
    local count = 0
    for _, record in pairs(self._allocations) do
        if record.Owner == owner then count += 1 end
    end
    return count
end
function MemoryManager:GetLargest()
    local best
    for _, record in pairs(self._allocations) do
        if not best or record.Bytes > best.Bytes then best = record end
    end
    return copyRecord(best)
end
function MemoryManager:GetSmallest()
    local best
    for _, record in pairs(self._allocations) do
        if not best or record.Bytes < best.Bytes then best = record end
    end
    return copyRecord(best)
end
function MemoryManager:GetTop(limit)
    limit = limit or 10
    if type(limit) ~= "number" or limit < 0 or limit % 1 ~= 0 then
        error("Limit must be a non-negative integer", 2)
    end
    local result = {}
    for _, record in pairs(self._allocations) do result[#result + 1] = copyRecord(record) end
    table.sort(result, function(a, b)
        if a.Bytes == b.Bytes then return a.Id < b.Id end
        return a.Bytes > b.Bytes
    end)
    while #result > limit do table.remove(result) end
    return result
end
function MemoryManager:Snapshot()
    local snapshot = { TotalBytes = self._totalBytes, Allocations = {} }
    for id, record in pairs(self._allocations) do snapshot.Allocations[id] = record.Bytes end
    return snapshot
end
function MemoryManager:Diff(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Allocations) ~= "table" then
        error("Invalid memory snapshot", 2)
    end
    local added, removed, changed = {}, {}, {}
    for id, record in pairs(self._allocations) do
        local previous = snapshot.Allocations[id]
        if previous == nil then added[id] = record.Bytes
        elseif previous ~= record.Bytes then changed[id] = { Before = previous, After = record.Bytes } end
    end
    for id, bytes in pairs(snapshot.Allocations) do
        if self._allocations[id] == nil then removed[id] = bytes end
    end
    return { Added = added, Removed = removed, Changed = changed,
        DeltaBytes = self._totalBytes - (snapshot.TotalBytes or 0) }
end
function MemoryManager:GetStatistics()
    return {
        Enabled = self.Enabled, AllocationCount = self:GetAllocationCount(),
        TotalBytes = self._totalBytes, PeakBytes = self._peakBytes,
        MaximumBytes = self.MaximumBytes, AvailableBytes = self:GetAvailableBytes(),
        OverLimit = self:IsOverLimit(), Allocations = self._statistics.Allocations,
        Releases = self._statistics.Releases, Resizes = self._statistics.Resizes,
        Rejections = self._statistics.Rejections,
    }
end
function MemoryManager:Validate()
    local total, count = 0, 0
    for id, record in pairs(self._allocations) do
        if not validName(id) or record.Id ~= id or not validBytes(record.Bytes) then
            return false, "Invalid allocation record: " .. tostring(id)
        end
        total += record.Bytes; count += 1
    end
    if total ~= self._totalBytes then return false, "Tracked byte total mismatch" end
    return true, { TotalBytes = total, AllocationCount = count }
end
function MemoryManager:Clear()
    local released = self:GetAllocationCount()
    self._allocations = {}; self._totalBytes = 0
    return released
end
function MemoryManager:Reset()
    self:Clear()
    self._peakBytes = 0
    self._statistics = { Allocations = 0, Releases = 0, Resizes = 0, Rejections = 0 }
    self.MaximumBytes = math.huge; self.Enabled = true
    return true
end

return MemoryManager
