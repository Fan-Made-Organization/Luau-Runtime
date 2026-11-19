-- Deterministic task queue with priority, delay, cancellation and execution budgets.
local Queue = {
    Enabled = true, Paused = false, MaximumTasks = 10000, HistoryLimit = 200,
    _tasks = {}, _history = {}, _nextId = 0, _clock = 0,
    _statistics = { Enqueued = 0, Executed = 0, Failed = 0, Cancelled = 0 },
}
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
function Queue:Enqueue(callback, options)
    if type(callback)~="function" then error("Task callback must be a function",2) end
    options=options or {}; if type(options)~="table" then error("Task options must be a table",2) end
    if #self._tasks>=self.MaximumTasks then return nil,"Task queue is full" end
    local delay=options.Delay or 0; local priority=options.Priority or 0
    if not finite(delay) or delay<0 or not finite(priority) then error("Invalid task delay or priority",2) end
    self._nextId+=1
    local task={Id=self._nextId,Callback=callback,Priority=priority,DueAt=self._clock+delay,
        State="PENDING",Label=options.Label or ("Task-"..tostring(self._nextId)),CreatedAt=self._clock}
    self._tasks[task.Id]=task; self._statistics.Enqueued+=1
    return task.Id
end
function Queue:Defer(callback, options)
    options=options or {}; options.Delay=0; return self:Enqueue(callback,options)
end
function Queue:Delay(seconds, callback, options)
    if not finite(seconds) or seconds<0 then error("Delay must be non-negative and finite",2) end
    options=options or {}; options.Delay=seconds; return self:Enqueue(callback,options)
end
function Queue:Get(id)
    local t=self._tasks[id]; if not t then return nil end
    return {Id=t.Id,Priority=t.Priority,DueAt=t.DueAt,State=t.State,Label=t.Label,CreatedAt=t.CreatedAt}
end
function Queue:Has(id) return self._tasks[id]~=nil end
function Queue:Cancel(id)
    local t=self._tasks[id]; if not t or t.State~="PENDING" then return false end
    t.State="CANCELLED"; t.Callback=nil; self._tasks[id]=nil; self._statistics.Cancelled+=1
    return true
end
function Queue:GetCount()
    local n=0; for _ in pairs(self._tasks) do n+=1 end; return n
end
function Queue:GetPendingCount() return self:GetCount() end
function Queue:GetRunningCount() return 0 end
function Queue:SetEnabled(value) self.Enabled=value==true; return self.Enabled end
function Queue:IsEnabled() return self.Enabled end
function Queue:Pause() self.Paused=true; return true end
function Queue:Resume() self.Paused=false; return true end
function Queue:IsPaused() return self.Paused end
function Queue:SetMaximumTasks(value)
    if type(value)~="number" or value<1 or value%1~=0 then error("Maximum tasks must be a positive integer",2) end
    self.MaximumTasks=value; return true
end
function Queue:GetMaximumTasks() return self.MaximumTasks end
function Queue:GetTime() return self._clock end
function Queue:Advance(delta)
    if not finite(delta) or delta<0 then error("Delta must be non-negative and finite",2) end
    self._clock+=delta; return self._clock
end
function Queue:_record(task,ok,result)
    self._history[#self._history+1]={Id=task.Id,Label=task.Label,Success=ok,Result=ok and result or tostring(result),Time=self._clock}
    while #self._history>self.HistoryLimit do table.remove(self._history,1) end
end
function Queue:RunNext()
    if not self.Enabled or self.Paused then return false,"Queue is paused or disabled" end
    local selected
    for _,task in pairs(self._tasks) do
        if task.State=="PENDING" and task.DueAt<=self._clock then
            if not selected or task.Priority>selected.Priority or
                (task.Priority==selected.Priority and task.Id<selected.Id) then selected=task end
        end
    end
    if not selected then return false,"No task is ready" end
    selected.State="RUNNING"
    local ok,result=pcall(selected.Callback)
    selected.State=ok and "COMPLETED" or "FAILED"
    selected.Callback=nil; self._tasks[selected.Id]=nil
    if ok then self._statistics.Executed+=1 else self._statistics.Failed+=1 end
    self:_record(selected,ok,result)
    return true,selected.Id,ok,result
end
function Queue:RunAll(maximum)
    maximum=maximum or self.MaximumTasks
    if type(maximum)~="number" or maximum<0 or maximum%1~=0 then error("Maximum execution count must be a non-negative integer",2) end
    local ran=0; local failed=0
    while ran<maximum do
        local ok,_,success=self:RunNext()
        if not ok then break end
        ran+=1; if not success then failed+=1 end
    end
    return ran,failed
end
function Queue:RunBudget(maximum)
    if not finite(maximum) or maximum<0 then error("Budget must be non-negative and finite",2) end
    local start=os.clock(); local ran=0; local failed=0
    while os.clock()-start<maximum do
        local ok,_,success=self:RunNext()
        if not ok then break end
        ran+=1; if not success then failed+=1 end
    end
    return ran,failed,os.clock()-start
end
function Queue:GetHistory()
    local result={}; for i,item in ipairs(self._history) do result[i]=item end; return result
end
function Queue:SetHistoryLimit(value)
    if type(value)~="number" or value<0 or value%1~=0 then error("History limit must be a non-negative integer",2) end
    self.HistoryLimit=value; while #self._history>value do table.remove(self._history,1) end; return true
end
function Queue:Clear()
    local count=self:GetCount(); self._tasks={}; return count
end
function Queue:ClearHistory() local count=#self._history; self._history={}; return count end
function Queue:GetStatistics()
    return {Enabled=self.Enabled,Paused=self.Paused,Pending=self:GetPendingCount(),
        Enqueued=self._statistics.Enqueued,Executed=self._statistics.Executed,
        Failed=self._statistics.Failed,Cancelled=self._statistics.Cancelled,
        History=#self._history,Clock=self._clock}
end
function Queue:Reset()
    self:Clear(); self:ClearHistory(); self.Enabled=true; self.Paused=false
    self.MaximumTasks=10000; self.HistoryLimit=200; self._nextId=0; self._clock=0
    self._statistics={Enqueued=0,Executed=0,Failed=0,Cancelled=0}; return true
end
return Queue
