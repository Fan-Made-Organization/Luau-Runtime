--[[
    FMO Garbage Collector
    Deterministic mark-and-sweep for objects explicitly managed by Luau Runtime.

    This does not inspect or replace the Luau VM's native garbage collector.
    Only values registered with Track() participate in this managed heap.
]]
local MemoryManager = require("./memory_manager")

local GarbageCollector = {
    Enabled = true,
    AutomaticEnabled = false,
    AutomaticThreshold = 256,
    AutomaticInterval = 1,

    _objects = {},
    _roots = {},
    _lastAutomaticCollection = 0,
    _collecting = false,
    _statistics = {
        Tracked = 0,
        Collected = 0,
        CollectionCycles = 0,
        Marked = 0,
        FinalizerErrors = 0,
        ExplicitCollections = 0,
        AutomaticCollections = 0,
    },
}

local function validId(value)
    return type(value) == "string" and value ~= ""
end

local function sortedKeys(map)
    local result = {}
    for key in pairs(map) do
        result[#result + 1] = key
    end
    table.sort(result)
    return result
end

function GarbageCollector:Track(id, value, options)
    if not validId(id) then
        error("GarbageCollector: id must be a non-empty string", 2)
    end
    if self._objects[id] then
        return false, "Object is already tracked"
    end
    if not self.Enabled then
        return false, "Garbage collector is disabled"
    end

    options = options or {}
    if type(options) ~= "table" then
        error("GarbageCollector: options must be a table", 2)
    end
    if options.Finalize ~= nil and type(options.Finalize) ~= "function" then
        error("GarbageCollector: Finalize must be a function", 2)
    end
    if options.MemoryAllocationId ~= nil and not validId(options.MemoryAllocationId) then
        error("GarbageCollector: MemoryAllocationId must be a non-empty string", 2)
    end

    self._objects[id] = {
        Id = id,
        Value = value,
        References = {},
        Tag = options.Tag or "Default",
        Finalize = options.Finalize,
        MemoryAllocationId = options.MemoryAllocationId,
        Metadata = options.Metadata,
        CreatedAt = os.clock(),
    }
    self._statistics.Tracked += 1

    if options.Root == true then
        self._roots[id] = true
    end

    return true, id
end

function GarbageCollector:Untrack(id)
    local record = self._objects[id]
    if not record then
        return false
    end

    self._objects[id] = nil
    self._roots[id] = nil
    for _, other in pairs(self._objects) do
        other.References[id] = nil
    end
    self._statistics.Collected += 1
    return true, record.Value
end

function GarbageCollector:Get(id)
    local record = self._objects[id]
    return record and record.Value or nil
end

function GarbageCollector:GetRecord(id)
    local record = self._objects[id]
    if not record then
        return nil
    end
    local references = sortedKeys(record.References)
    return {
        Id = record.Id,
        Tag = record.Tag,
        References = references,
        Root = self._roots[id] == true,
        MemoryAllocationId = record.MemoryAllocationId,
        Metadata = record.Metadata,
        CreatedAt = record.CreatedAt,
    }
end

function GarbageCollector:Contains(id)
    return self._objects[id] ~= nil
end

function GarbageCollector:AddReference(sourceId, targetId)
    local source = self._objects[sourceId]
    if not source then
        return false, "Source object is not tracked"
    end
    if not self._objects[targetId] then
        return false, "Target object is not tracked"
    end
    source.References[targetId] = true
    return true
end

function GarbageCollector:RemoveReference(sourceId, targetId)
    local source = self._objects[sourceId]
    if not source or not source.References[targetId] then
        return false
    end
    source.References[targetId] = nil
    return true
end

function GarbageCollector:SetRoot(id, isRoot)
    if not self._objects[id] then
        return false, "Object is not tracked"
    end
    if isRoot == nil then
        isRoot = true
    end
    if type(isRoot) ~= "boolean" then
        error("GarbageCollector: root state must be a boolean", 2)
    end
    if isRoot then
        self._roots[id] = true
    else
        self._roots[id] = nil
    end
    return true
end

function GarbageCollector:IsRoot(id)
    return self._roots[id] == true
end

function GarbageCollector:GetCount()
    local count = 0
    for _ in pairs(self._objects) do
        count += 1
    end
    return count
end

function GarbageCollector:GetRoots()
    return sortedKeys(self._roots)
end

function GarbageCollector:Collect(options)
    options = options or {}
    if type(options) ~= "table" then
        error("GarbageCollector: collection options must be a table", 2)
    end
    if not self.Enabled then
        return false, "Garbage collector is disabled"
    end
    if self._collecting then
        return false, "Garbage collection is already in progress"
    end
    self._collecting = true

    local marked = {}
    local stack = self:GetRoots()

    while #stack > 0 do
        local id = table.remove(stack)
        if not marked[id] and self._objects[id] then
            marked[id] = true
            local references = sortedKeys(self._objects[id].References)
            for i = #references, 1, -1 do
                if not marked[references[i]] then
                    stack[#stack + 1] = references[i]
                end
            end
        end
    end

    local dead = {}
    for _, id in ipairs(sortedKeys(self._objects)) do
        if not marked[id] then
            dead[#dead + 1] = id
        end
    end

    local collected, failed = {}, {}
    for _, id in ipairs(dead) do
        local record = self._objects[id]
        if record then
            local ok, err = true, nil
            if record.Finalize then
                ok, err = pcall(record.Finalize, record.Value, id)
            end

            if ok then
                if record.MemoryAllocationId then
                    MemoryManager:Release(record.MemoryAllocationId)
                end
                self._objects[id] = nil
                self._roots[id] = nil
                collected[#collected + 1] = id
            else
                failed[#failed + 1] = { Id = id, Error = tostring(err) }
                self._statistics.FinalizerErrors += 1
            end
        end
    end

    for _, record in pairs(self._objects) do
        for id in pairs(record.References) do
            if not self._objects[id] then
                record.References[id] = nil
            end
        end
    end

    local markedCount = 0
    for _ in pairs(marked) do
        markedCount += 1
    end
    self._statistics.CollectionCycles += 1
    self._statistics.Marked += markedCount
    self._collecting = false
    self._statistics.Collected += #collected
    self._statistics.ExplicitCollections += options.Automatic == true and 0 or 1
    self._statistics.AutomaticCollections += options.Automatic == true and 1 or 0

    return true, {
        Collected = #collected,
        Retained = self:GetCount(),
        Marked = markedCount,
        Failed = failed,
        CollectedIds = collected,
    }
end

function GarbageCollector:Step(now)
    if not self.AutomaticEnabled or not self.Enabled then
        return false, "Automatic collection is disabled"
    end
    now = now or os.clock()
    if type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then
        error("GarbageCollector: Step time must be finite", 2)
    end
    if self:GetCount() < self.AutomaticThreshold then
        return false, "Automatic threshold not reached"
    end
    if now - self._lastAutomaticCollection < self.AutomaticInterval then
        return false, "Automatic collection interval has not elapsed"
    end

    self._lastAutomaticCollection = now
    return self:Collect({ Automatic = true })
end

function GarbageCollector:SetAutomaticEnabled(value)
    self.AutomaticEnabled = value == true
    return self.AutomaticEnabled
end

function GarbageCollector:SetAutomaticThreshold(value)
    if type(value) ~= "number" or value < 1 or value % 1 ~= 0 or value == math.huge then
        error("Automatic threshold must be a positive integer", 2)
    end
    self.AutomaticThreshold = value
    return true
end

function GarbageCollector:SetAutomaticInterval(value)
    if type(value) ~= "number" or value < 0 or value ~= value or value == math.huge then
        error("Automatic interval must be a finite non-negative number", 2)
    end
    self.AutomaticInterval = value
    return true
end

function GarbageCollector:SetEnabled(value)
    self.Enabled = value == true
    return self.Enabled
end

function GarbageCollector:GetStatistics()
    return {
        Enabled = self.Enabled,
        AutomaticEnabled = self.AutomaticEnabled,
        AutomaticThreshold = self.AutomaticThreshold,
        AutomaticInterval = self.AutomaticInterval,
        ObjectCount = self:GetCount(),
        RootCount = #self:GetRoots(),
        Tracked = self._statistics.Tracked,
        Collected = self._statistics.Collected,
        CollectionCycles = self._statistics.CollectionCycles,
        Marked = self._statistics.Marked,
        FinalizerErrors = self._statistics.FinalizerErrors,
        ExplicitCollections = self._statistics.ExplicitCollections,
        AutomaticCollections = self._statistics.AutomaticCollections,
    }
end

function GarbageCollector:Validate()
    for id, record in pairs(self._objects) do
        if record.Id ~= id then
            return false, "Object id mismatch: " .. tostring(id)
        end
        for targetId in pairs(record.References) do
            if not self._objects[targetId] then
                return false, "Dangling reference: " .. tostring(id) .. " -> " .. tostring(targetId)
            end
        end
    end
    for id in pairs(self._roots) do
        if not self._objects[id] then
            return false, "Root is not tracked: " .. tostring(id)
        end
    end
    return true, { ObjectCount = self:GetCount(), RootCount = #self:GetRoots() }
end

function GarbageCollector:Clear()
    local count = self:GetCount()
    self._objects = {}
    self._roots = {}
    return count
end

function GarbageCollector:Reset()
    self:Clear()
    self.Enabled = true
    self.AutomaticEnabled = false
    self.AutomaticThreshold = 256
    self.AutomaticInterval = 1
    self._lastAutomaticCollection = 0
    self._collecting = false
    self._statistics = {
        Tracked = 0,
        Collected = 0,
        CollectionCycles = 0,
        Marked = 0,
        FinalizerErrors = 0,
        ExplicitCollections = 0,
        AutomaticCollections = 0,
    }
    return true
end

return GarbageCollector
