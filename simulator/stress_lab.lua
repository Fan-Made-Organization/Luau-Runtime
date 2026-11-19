-- Bounded, opt-in stress harness. Every callback is protected and iteration-limited.
local StressLab={Enabled=true,MaximumIterations=100000,HistoryLimit=50,_history={},_sequence=0}
function StressLab:Run(name,callback,iterations,...)
 if not self.Enabled then return false,"Stress Lab disabled" end
 if type(name)~="string" or name=="" then error("Scenario name required",2) end
 if type(callback)~="function" then error("Scenario callback required",2) end
 iterations=iterations or 1
 if type(iterations)~="number" or iterations<1 or iterations%1~=0 or iterations>self.MaximumIterations then error("Invalid stress iteration count",2) end
 local args=table.pack(...);local started=os.clock();local failures=0;local firstError
 for i=1,iterations do local ok,err=pcall(function() return callback(i,table.unpack(args,1,args.n)) end);if not ok then failures+=1;if not firstError then firstError=tostring(err) end end end
 local elapsed=os.clock()-started;self._sequence+=1
 local report={Id=self._sequence,Name=name,Iterations=iterations,Completed=iterations-failures,Failures=failures,Elapsed=elapsed,FirstError=firstError}
 self._history[#self._history+1]=report;while #self._history>self.HistoryLimit do table.remove(self._history,1) end
 return true,report
end
function StressLab:GetLatest() return self._history[#self._history] end
function StressLab:GetHistory() local out={};for i,v in ipairs(self._history) do out[i]=v end;return out end
function StressLab:SetMaximumIterations(n) if type(n)~="number" or n<1 or n%1~=0 then error("Maximum iterations must be positive integer",2) end;self.MaximumIterations=n end
function StressLab:SetHistoryLimit(n) if type(n)~="number" or n<1 or n%1~=0 then error("History limit must be positive integer",2) end;self.HistoryLimit=n;while #self._history>n do table.remove(self._history,1) end end
function StressLab:SetEnabled(v) self.Enabled=v==true;return self.Enabled end
function StressLab:GetStatistics() return {Enabled=self.Enabled,History=#self._history,HistoryLimit=self.HistoryLimit,MaximumIterations=self.MaximumIterations} end
function StressLab:Reset() self.Enabled=true;self.MaximumIterations=100000;self.HistoryLimit=50;self._history={};self._sequence=0 end
return StressLab
