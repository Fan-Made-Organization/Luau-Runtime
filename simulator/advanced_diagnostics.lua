-- Structured diagnostic reports with bounded, categorized issue records.
local Snapshot = require("./snapshot")
local Diagnostics={Enabled=true,Limit=300,_items={},_sequence=0,_counts={}}
local valid={INFO=true,WARNING=true,ERROR=true,CRITICAL=true}
function Diagnostics:Report(category,severity,message,details)
 if not self.Enabled then return false end
 if type(category)~="string" or category=="" then error("Category required",2) end
 if not valid[severity] then error("Invalid diagnostic severity",2) end
 if type(message)~="string" or message=="" then error("Message required",2) end
 self._sequence+=1
 local item={Id=self._sequence,At=os.clock(),Category=category,Severity=severity,Message=message,Details=Snapshot.Clone(details)}
 self._items[#self._items+1]=item;while #self._items>self.Limit do table.remove(self._items,1) end
 self._counts[severity]=(self._counts[severity] or 0)+1
 return item.Id
end
function Diagnostics:CaptureHealth(game)
 local ok,report=pcall(function() return game:ScanResourceHealth() end)
 if not ok then return self:Report("HealthMonitor","ERROR","Health scan failed",{Error=tostring(report)}) end
 local count=0
 for _,finding in ipairs(report.Findings or {}) do self:Report("ResourceIntelligence",finding.Severity,finding.Message,finding);count+=1 end
 return count
end
function Diagnostics:Get(id) for _,v in ipairs(self._items) do if v.Id==id then return Snapshot.Clone(v) end end end
function Diagnostics:GetAll(category,severity)
 local out={};for _,v in ipairs(self._items) do if (not category or v.Category==category) and (not severity or v.Severity==severity) then out[#out+1]=Snapshot.Clone(v) end end;return out
end
function Diagnostics:Clear() local n=#self._items;self._items={};return n end
function Diagnostics:SetLimit(n) if type(n)~="number" or n<1 or n%1~=0 then error("Limit must be positive integer",2) end;self.Limit=n;while #self._items>n do table.remove(self._items,1) end end
function Diagnostics:SetEnabled(v) self.Enabled=v==true;return self.Enabled end
function Diagnostics:GetStatistics() local out={Enabled=self.Enabled,Count=#self._items,Limit=self.Limit};for k,v in pairs(self._counts) do out[k]=v end;return out end
function Diagnostics:Reset() self.Enabled=true;self.Limit=300;self._items={};self._sequence=0;self._counts={} end
return Diagnostics
