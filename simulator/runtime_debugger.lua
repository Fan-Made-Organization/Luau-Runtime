-- Runtime Debugger: bounded trace, breakpoint and watch-value registry.
local RuntimeDebugger = {
    Enabled = true, MaximumTraceEntries = 500,
    _breakpoints = {}, _watches = {}, _trace = {}, _snapshots = {},
    _statistics = { Traces = 0, Breakpoints = 0, WatchEvaluations = 0, WatchErrors = 0 },
}
local function validText(value) return type(value) == "string" and value ~= "" end
local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return "<cycle>" end
    local out = {}; seen[value] = out
    for k,v in pairs(value) do out[k] = copy(v, seen) end
    seen[value] = nil; return out
end
function RuntimeDebugger:SetEnabled(value) self.Enabled = value == true; return self.Enabled end
function RuntimeDebugger:IsEnabled() return self.Enabled end
function RuntimeDebugger:AddBreakpoint(source, line, options)
    if not validText(source) then error("Breakpoint source must be a non-empty string", 2) end
    if type(line) ~= "number" or line < 1 or line % 1 ~= 0 then error("Breakpoint line must be a positive integer", 2) end
    local key = source .. ":" .. tostring(line); options = options or {}
    self._breakpoints[key] = { Source = source, Line = line, Enabled = options.Enabled ~= false,
        Condition = options.Condition, HitCount = 0, HitLimit = options.HitLimit }
    self._statistics.Breakpoints += 1
    return key
end
function RuntimeDebugger:RemoveBreakpoint(source, line)
    local key = line == nil and source or (source .. ":" .. tostring(line))
    if not self._breakpoints[key] then return false end
    self._breakpoints[key] = nil; return true
end
function RuntimeDebugger:HasBreakpoint(source, line)
    local key = line == nil and source or (source .. ":" .. tostring(line))
    return self._breakpoints[key] ~= nil
end
function RuntimeDebugger:GetBreakpoint(source, line)
    local key = line == nil and source or (source .. ":" .. tostring(line))
    local bp = self._breakpoints[key]; if not bp then return nil end
    local result = {}; for k,v in pairs(bp) do if k ~= "Condition" then result[k] = v end end
    return result
end
function RuntimeDebugger:ListBreakpoints()
    local result = {}
    for key, bp in pairs(self._breakpoints) do
        local item = self:GetBreakpoint(key); item.Key = key; result[#result + 1] = item
    end
    table.sort(result, function(a,b) return a.Key < b.Key end); return result
end
function RuntimeDebugger:EnableBreakpoint(source, line, enabled)
    local key = line == nil and source or (source .. ":" .. tostring(line))
    local bp = self._breakpoints[key]; if not bp then return false end
    bp.Enabled = enabled ~= false; return true
end
function RuntimeDebugger:CheckBreakpoint(source, line, context)
    if not self.Enabled then return false end
    local bp = self._breakpoints[source .. ":" .. tostring(line)]
    if not bp or not bp.Enabled then return false end
    if bp.HitLimit and bp.HitCount >= bp.HitLimit then return false end
    if type(bp.Condition) == "function" then
        local ok, result = pcall(bp.Condition, context)
        if not ok or not result then return false end
    end
    bp.HitCount += 1; return true
end
function RuntimeDebugger:AddWatch(name, getter)
    if not validText(name) then error("Watch name must be a non-empty string", 2) end
    if type(getter) ~= "function" then error("Watch getter must be a function", 2) end
    self._watches[name] = getter; return true
end
function RuntimeDebugger:RemoveWatch(name)
    if not self._watches[name] then return false end
    self._watches[name] = nil; return true
end
function RuntimeDebugger:HasWatch(name) return self._watches[name] ~= nil end
function RuntimeDebugger:GetWatchNames()
    local names = {}; for name in pairs(self._watches) do names[#names + 1] = name end
    table.sort(names); return names
end
function RuntimeDebugger:EvaluateWatch(name)
    local getter = self._watches[name]; if not getter then return nil, "Watch not found" end
    self._statistics.WatchEvaluations += 1
    local ok, value = pcall(getter)
    if not ok then self._statistics.WatchErrors += 1; return nil, tostring(value) end
    return value
end
function RuntimeDebugger:EvaluateAllWatches()
    local result = {}
    for _, name in ipairs(self:GetWatchNames()) do
        local value, err = self:EvaluateWatch(name); result[name] = { Value = value, Error = err }
    end
    return result
end
function RuntimeDebugger:Trace(category, message, data)
    if not self.Enabled then return false end
    if not validText(category) or type(message) ~= "string" then error("Trace requires category and message strings", 2) end
    self._trace[#self._trace + 1] = { Category = category, Message = message, Data = copy(data), Timestamp = os.clock() }
    self._statistics.Traces += 1
    while #self._trace > self.MaximumTraceEntries do table.remove(self._trace, 1) end
    return true
end
function RuntimeDebugger:GetTrace(category)
    local result = {}
    for _, entry in ipairs(self._trace) do
        if category == nil or entry.Category == category then
            local item = {}; for k,v in pairs(entry) do item[k] = copy(v) end
            result[#result + 1] = item
        end
    end
    return result
end
function RuntimeDebugger:ClearTrace() local count = #self._trace; self._trace = {}; return count end
function RuntimeDebugger:SetMaximumTraceEntries(value)
    if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then error("Trace limit must be a non-negative integer", 2) end
    self.MaximumTraceEntries = value
    while #self._trace > value do table.remove(self._trace, 1) end
    return true
end
function RuntimeDebugger:Snapshot(name, value)
    if not validText(name) then error("Snapshot name must be a non-empty string", 2) end
    self._snapshots[name] = { Value = copy(value), Timestamp = os.clock() }; return true
end
function RuntimeDebugger:GetSnapshot(name)
    local snapshot = self._snapshots[name]
    if not snapshot then return nil end
    return { Value = copy(snapshot.Value), Timestamp = snapshot.Timestamp }
end
function RuntimeDebugger:CompareSnapshots(first, second)
    local a, b = self._snapshots[first], self._snapshots[second]
    if not a or not b then return nil, "Snapshot not found" end
    local changed = {}
    if type(a.Value) ~= "table" or type(b.Value) ~= "table" then
        return { Changed = a.Value ~= b.Value, Before = a.Value, After = b.Value }
    end
    for key, value in pairs(a.Value) do if b.Value[key] ~= value then changed[key] = { Before = value, After = b.Value[key] } end end
    for key, value in pairs(b.Value) do if a.Value[key] == nil then changed[key] = { Before = nil, After = value } end end
    return { Changed = next(changed) ~= nil, Properties = changed }
end
function RuntimeDebugger:Inspect(value)
    local result = { Type = type(value), Keys = {}, Preview = {} }
    if type(value) == "table" then
        for key, item in pairs(value) do
            result.Keys[#result.Keys + 1] = key
            if #result.Keys <= 20 then result.Preview[key] = copy(item) end
        end
        table.sort(result.Keys, function(a,b) return tostring(a) < tostring(b) end)
        result.Count = #result.Keys
    end
    return result
end
function RuntimeDebugger:GetStatistics()
    local snapshots = 0; for _ in pairs(self._snapshots) do snapshots += 1 end
    return { Enabled = self.Enabled, Breakpoints = #self:ListBreakpoints(),
        Watches = #self:GetWatchNames(), TraceEntries = #self._trace, Snapshots = snapshots,
        Traces = self._statistics.Traces, BreakpointRegistrations = self._statistics.Breakpoints,
        WatchEvaluations = self._statistics.WatchEvaluations, WatchErrors = self._statistics.WatchErrors }
end
function RuntimeDebugger:Clear()
    self._breakpoints = {}; self._watches = {}; self._snapshots = {}; self._trace = {}; return true
end
function RuntimeDebugger:Reset()
    self:Clear(); self.Enabled = true; self.MaximumTraceEntries = 500
    self._statistics = { Traces = 0, Breakpoints = 0, WatchEvaluations = 0, WatchErrors = 0 }
    return true
end
return RuntimeDebugger
