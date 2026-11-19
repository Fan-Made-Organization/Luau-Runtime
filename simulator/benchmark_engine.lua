-- Deterministic callback benchmark harness; no external commands or IO.
local Snapshot = require("./snapshot")
local Benchmark={Enabled=true,MaximumIterations=100000,HistoryLimit=50,_history={},_sequence=0}
function Benchmark:Run(name,callback,iterations,...)
 if not self.Enabled then return false,"Benchmark engine disabled" end
 if type(name)~="string" or name=="" then error("Benchmark name required",2) end
 if type(callback)~="function" then error("Benchmark callback required",2) end
 iterations=iterations or 1
 if type(iterations)~="number" or iterations<1 or iterations%1~=0 or iterations>self.MaximumIterations then error("Invalid benchmark iteration count",2) end
 local args=table.pack(...);local start=os.clock();local failures=0;local last
 for i=1,iterations do local ok,result=pcall(function() return callback(table.unpack(args,1,args.n)) end);if ok then last=result else failures+=1 end end
 local elapsed=os.clock()-start
 self._sequence+=1
 local result={Id=self._sequence,Name=name,Iterations=iterations,Elapsed=elapsed,Average=elapsed/iterations,OperationsPerSecond=elapsed>0 and iterations/elapsed or math.huge,Failures=failures,LastResult=Snapshot.Clone(last)}
 self._history[#self._history+1]=result;while #self._history>self.HistoryLimit do table.remove(self._history,1) end
 return true,Snapshot.Clone(result)
end
function Benchmark:GetHistory() return Snapshot.Array(self._history) end
function Benchmark:GetLatest() return Snapshot.Clone(self._history[#self._history]) end
function Benchmark:SetMaximumIterations(n) if type(n)~="number" or n<1 or n%1~=0 then error("Maximum iterations must be positive integer",2) end;self.MaximumIterations=n end
function Benchmark:SetHistoryLimit(n) if type(n)~="number" or n<1 or n%1~=0 then error("History limit must be positive integer",2) end;self.HistoryLimit=n;while #self._history>n do table.remove(self._history,1) end end
function Benchmark:SetEnabled(v) self.Enabled=v==true;return self.Enabled end
function Benchmark:GetStatistics() return {Enabled=self.Enabled,History=#self._history,HistoryLimit=self.HistoryLimit,MaximumIterations=self.MaximumIterations} end
function Benchmark:Reset() self.Enabled=true;self.MaximumIterations=100000;self.HistoryLimit=50;self._history={};self._sequence=0 end
return Benchmark
