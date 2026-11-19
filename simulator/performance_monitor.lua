-- Bounded performance metrics, timers, budgets and comparison snapshots.
local Monitor = {
    Enabled = true, MaximumSamples = 500, _metrics = {}, _timers = {},
    _budgets = {}, _marks = {}, _snapshots = {},
    _statistics = { Records = 0, TimersStarted = 0, TimersCompleted = 0, Errors = 0 },
}
local function validName(v) return type(v) == "string" and v ~= "" end
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function metric(self, name)
    if not self._metrics[name] then self._metrics[name] = { Samples = {}, Total = 0, Minimum = nil, Maximum = nil } end
    return self._metrics[name]
end
function Monitor:Record(name, value)
    if not validName(name) or not finite(value) then error("Record requires a name and finite numeric value", 2) end
    if not self.Enabled then return false end
    local m = metric(self, name); m.Samples[#m.Samples + 1] = value
    m.Total += value; m.Minimum = m.Minimum and math.min(m.Minimum, value) or value
    m.Maximum = m.Maximum and math.max(m.Maximum, value) or value
    while #m.Samples > self.MaximumSamples do
        local removed = table.remove(m.Samples, 1); m.Total -= removed
    end
    self._statistics.Records += 1
    return true
end
function Monitor:StartTimer(name)
    if not validName(name) then error("Timer name must be a non-empty string", 2) end
    if not self.Enabled then return nil end
    local token = { Active = true }
    self._timers[token] = { Name = name, StartedAt = os.clock() }; self._statistics.TimersStarted += 1
    return token
end
function Monitor:StopTimer(token)
    if type(token) ~= "table" or not self._timers[token] or not token.Active then return nil, "Invalid timer token" end
    local timer = self._timers[token]
    local elapsed = math.max(0, os.clock() - timer.StartedAt)
    token.Active = false; self._timers[token] = nil
    self._statistics.TimersCompleted += 1
    self:Record(timer.Name, elapsed)
    return elapsed
end
function Monitor:Measure(name, callback, ...)
    if type(callback) ~= "function" then error("Measure callback must be a function", 2) end
    local token = self:StartTimer(name)
    local args = {...}
    local results = table.pack(pcall(function() return callback(table.unpack(args)) end))
    if token then self:StopTimer(token) end
    if not results[1] then self._statistics.Errors += 1; error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end
function Monitor:GetSamples(name)
    local m = self._metrics[name]; if not m then return {} end
    local result = {}; for i,v in ipairs(m.Samples) do result[i] = v end; return result
end
function Monitor:GetMetric(name)
    local m = self._metrics[name]; if not m then return nil end
    local count = #m.Samples
    return { Name = name, Count = count, Total = m.Total, Minimum = m.Minimum,
        Maximum = m.Maximum, Average = count > 0 and m.Total / count or 0,
        Latest = m.Samples[count] }
end
function Monitor:GetAverage(name) local m=self:GetMetric(name); return m and m.Average or nil end
function Monitor:GetMinimum(name) local m=self:GetMetric(name); return m and m.Minimum or nil end
function Monitor:GetMaximum(name) local m=self:GetMetric(name); return m and m.Maximum or nil end
function Monitor:GetLatest(name) local m=self:GetMetric(name); return m and m.Latest or nil end
function Monitor:GetCount(name) local m=self:GetMetric(name); return m and m.Count or 0 end
function Monitor:GetMetricNames()
    local names={}; for name in pairs(self._metrics) do names[#names+1]=name end; table.sort(names); return names
end
function Monitor:SetSampleLimit(value)
    if type(value)~="number" or value<1 or value%1~=0 then error("Sample limit must be a positive integer",2) end
    self.MaximumSamples=value
    for _,m in pairs(self._metrics) do while #m.Samples>value do m.Total-=table.remove(m.Samples,1) end end
    return true
end
function Monitor:SetEnabled(value) self.Enabled=value==true; return self.Enabled end
function Monitor:IsEnabled() return self.Enabled end
function Monitor:SetBudget(name, limit)
    if not validName(name) or not finite(limit) or limit<0 then error("Budget requires a name and non-negative finite limit",2) end
    self._budgets[name]=limit; return true
end
function Monitor:GetBudget(name) return self._budgets[name] end
function Monitor:IsOverBudget(name)
    local latest=self:GetLatest(name); local budget=self._budgets[name]
    return latest~=nil and budget~=nil and latest>budget
end
function Monitor:GetOverBudgetMetrics()
    local result={}
    for name in pairs(self._budgets) do if self:IsOverBudget(name) then result[#result+1]=name end end
    table.sort(result); return result
end
function Monitor:Mark(name, data)
    if not validName(name) then error("Mark name must be a non-empty string",2) end
    self._marks[#self._marks+1]={Name=name,Data=data,Timestamp=os.clock()}
    return #self._marks
end
function Monitor:GetMarks(name)
    local result={}
    for _,mark in ipairs(self._marks) do if name==nil or mark.Name==name then result[#result+1]=mark end end
    return result
end
function Monitor:ClearMarks() local n=#self._marks; self._marks={}; return n end
function Monitor:Snapshot(name)
    if not validName(name) then error("Snapshot name must be a non-empty string",2) end
    local values={}
    for key in pairs(self._metrics) do values[key]=self:GetMetric(key) end
    self._snapshots[name]={Values=values,Timestamp=os.clock()}; return true
end
function Monitor:CompareSnapshots(aName,bName)
    local a,b=self._snapshots[aName],self._snapshots[bName]
    if not a or not b then return nil,"Snapshot not found" end
    local changes={}
    for name,bMetric in pairs(b.Values) do
        local aMetric=a.Values[name]
        if not aMetric or aMetric.Average~=bMetric.Average then
            changes[name]={Before=aMetric and aMetric.Average or nil,After=bMetric.Average}
        end
    end
    return {Changes=changes,Changed=next(changes)~=nil}
end
function Monitor:ClearMetric(name)
    if not self._metrics[name] then return false end
    self._metrics[name]=nil; return true
end
function Monitor:Clear()
    self._metrics={}; self._timers={}; self._budgets={}; self._marks={}; self._snapshots={}
    return true
end
function Monitor:GetStatistics()
    local active=0; for _ in pairs(self._timers) do active+=1 end
    return {Enabled=self.Enabled,MetricCount=#self:GetMetricNames(),ActiveTimers=active,
        MarkCount=#self._marks,Records=self._statistics.Records,
        TimersStarted=self._statistics.TimersStarted,TimersCompleted=self._statistics.TimersCompleted,
        Errors=self._statistics.Errors}
end
function Monitor:Reset()
    self:Clear(); self.Enabled=true; self.MaximumSamples=500
    self._statistics={Records=0,TimersStarted=0,TimersCompleted=0,Errors=0}; return true
end
return Monitor
