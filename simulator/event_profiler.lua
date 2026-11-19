-- Bounded event instrumentation and latency aggregation.
local Profiler={Enabled=true,Limit=500,_samples={},_totals={},_sequence=0}
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
function Profiler:Record(name,duration,metadata)
 if not self.Enabled then return false end
 if type(name)~="string" or name=="" then error("Event name required",2) end
 if not finite(duration) or duration<0 then error("Duration must be finite and non-negative",2) end
 self._sequence+=1
 local item={Id=self._sequence,Name=name,Duration=duration,At=os.clock(),Metadata=metadata}
 self._samples[#self._samples+1]=item
 while #self._samples>self.Limit do table.remove(self._samples,1) end
 local t=self._totals[name] or {Count=0,Total=0,Maximum=0,Failures=0}
 t.Count+=1;t.Total+=duration;t.Maximum=math.max(t.Maximum,duration);self._totals[name]=t
 return item.Id
end
function Profiler:Measure(name,callback,...)
 if type(callback)~="function" then error("Callback required",2) end
 local args=table.pack(...);local start=os.clock()
 local result=table.pack(pcall(function() return callback(table.unpack(args,1,args.n)) end))
 self:Record(name,os.clock()-start,{Success=result[1]})
 if not result[1] then self._totals[name].Failures+=1;error(result[2],0) end
 return table.unpack(result,2,result.n)
end
function Profiler:GetReport()
 local out={}
 for name,t in pairs(self._totals) do out[#out+1]={Name=name,Count=t.Count,Total=t.Total,Average=t.Total/t.Count,Maximum=t.Maximum,Failures=t.Failures} end
 table.sort(out,function(a,b)return a.Name<b.Name end);return out
end
function Profiler:GetSamples() local out={};for i,v in ipairs(self._samples) do out[i]={Id=v.Id,Name=v.Name,Duration=v.Duration,At=v.At,Metadata=v.Metadata} end;return out end
function Profiler:SetLimit(n) if type(n)~="number" or n<1 or n%1~=0 then error("Limit must be a positive integer",2) end;self.Limit=n;while #self._samples>n do table.remove(self._samples,1) end end
function Profiler:SetEnabled(v) self.Enabled=v==true;return self.Enabled end
function Profiler:GetStatistics() local n=0;for _ in pairs(self._totals) do n+=1 end;return {Enabled=self.Enabled,Samples=#self._samples,EventNames=n,Limit=self.Limit} end
function Profiler:Reset() self._samples={};self._totals={};self._sequence=0;self.Enabled=true;self.Limit=500 end
return Profiler
