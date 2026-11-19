-- Read-only scheduler/task-queue sampling and trend analysis.
local Snapshot = require("./snapshot")
local SchedulerAnalyzer={Enabled=true,Limit=100,_history={},_sequence=0}
local function safeStats(component)
 if type(component)~="table" or type(component.GetStatistics)~="function" then return nil end
 local ok,value=pcall(component.GetStatistics,component);if ok and type(value)=="table" then return Snapshot.Clone(value) end
 return nil
end
function SchedulerAnalyzer:Capture(scheduler,queue)
 if not self.Enabled then return false,"Analyzer disabled" end
 local sample={At=os.clock(),Scheduler=safeStats(scheduler),TaskQueue=safeStats(queue)}
 self._sequence+=1;sample.Id=self._sequence;self._history[#self._history+1]=sample
 while #self._history>self.Limit do table.remove(self._history,1) end
 return true,sample
end
function SchedulerAnalyzer:GetLatest() return Snapshot.Clone(self._history[#self._history]) end
function SchedulerAnalyzer:GetHistory() return Snapshot.Array(self._history) end
function SchedulerAnalyzer:SetLimit(n) if type(n)~="number" or n<1 or n%1~=0 then error("Limit must be positive integer",2) end;self.Limit=n;while #self._history>n do table.remove(self._history,1) end end
function SchedulerAnalyzer:SetEnabled(v) self.Enabled=v==true;return self.Enabled end
function SchedulerAnalyzer:GetStatistics() return {Enabled=self.Enabled,Samples=#self._history,Limit=self.Limit} end
function SchedulerAnalyzer:Reset() self.Enabled=true;self.Limit=100;self._history={};self._sequence=0 end
return SchedulerAnalyzer
