-- Explicit on-demand health aggregation; diagnostics are read-only.
local Snapshot = require("./snapshot")
local Health={Enabled=true,HistoryLimit=50,_history={},_sequence=0}
local function invoke(fn)
 if type(fn)~="function" then return nil,"Unavailable" end
 local ok,a,b=pcall(fn);if not ok then return nil,tostring(a) end;return a,b
end
function Health:Scan(game)
 if not self.Enabled then return false,"Health monitor disabled" end
 if type(game)~="table" then error("Game facade required",2) end
 local checks={}
 local ok,report=invoke(function() return game:ScanResourceHealth() end)
 checks.ResourceIntelligence={Success=ok==true,Report=report}
 local graphOk,graph=invoke(function() return game:BuildResourceDependencyGraph() end)
 checks.DependencyGraph={Success=graphOk==true,Report=graph}
 local status,statusErr=invoke(function() return game:GetRuntimeStatus() end)
 checks.RuntimeStatus={Success=status~=nil,Report=status,Error=statusErr}
 local health="HEALTHY"
 if not checks.ResourceIntelligence.Success or not checks.DependencyGraph.Success or not checks.RuntimeStatus.Success then health="DEGRADED"
 elseif report and report.Health then health=report.Health end
 self._sequence+=1
 local result={Id=self._sequence,At=os.clock(),Health=health,Checks=Snapshot.Clone(checks)}
 self._history[#self._history+1]=result
 while #self._history>self.HistoryLimit do table.remove(self._history,1) end
 return true,Snapshot.Clone(result)
end
function Health:GetLatest() return Snapshot.Clone(self._history[#self._history]) end
function Health:GetHistory() return Snapshot.Array(self._history) end
function Health:SetEnabled(v) self.Enabled=v==true;return self.Enabled end
function Health:SetHistoryLimit(n) if type(n)~="number" or n<1 or n%1~=0 then error("History limit must be positive integer",2) end;self.HistoryLimit=n;while #self._history>n do table.remove(self._history,1) end end
function Health:GetStatistics() return {Enabled=self.Enabled,Scans=#self._history,HistoryLimit=self.HistoryLimit} end
function Health:Reset() self.Enabled=true;self.HistoryLimit=50;self._history={};self._sequence=0 end
return Health
