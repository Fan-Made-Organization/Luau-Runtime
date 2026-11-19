-- Instance Manager adds indexed lookup, tags, groups and lifecycle tracking.
local Manager = {
    _records = {}, _byName = {}, _byClass = {}, _nextId = 0,
    _statistics = { Registered = 0, Unregistered = 0, Lookups = 0, Destroyed = 0 },
}
local function alive(instance)
    return type(instance)=="table" and instance._isInstance==true
        and instance._destroyed~=true and instance.Destroyed~=true
end
local function addIndex(index,key,id)
    if key==nil then return end
    index[key]=index[key] or {}; index[key][id]=true
end
local function removeIndex(index,key,id)
    if key==nil or not index[key] then return end
    index[key][id]=nil; if next(index[key])==nil then index[key]=nil end
end
local function idsFrom(index,key)
    local result={}; for id in pairs(index[key] or {}) do result[#result+1]=id end
    table.sort(result); return result
end
function Manager:Register(instance,options)
    if not alive(instance) then error("Register expects a live Instance",2) end
    local existing=self:GetId(instance); if existing then return existing,false end
    options=options or {}; self._nextId+=1
    local id="instance-"..tostring(self._nextId)
    self._records[id]={Id=id,Instance=instance,Name=instance.Name,ClassName=instance.ClassName,
        Tags={},Group=options.Group,Metadata=options.Metadata,RegisteredAt=os.clock()}
    addIndex(self._byName,instance.Name,id); addIndex(self._byClass,instance.ClassName,id)
    self._statistics.Registered+=1
    return id,true
end
function Manager:GetId(instance)
    for id,record in pairs(self._records) do if record.Instance==instance then return id end end
    return nil
end
function Manager:GetById(id)
    local r=self._records[id]; return r and alive(r.Instance) and r.Instance or nil
end
function Manager:Has(id) return self._records[id]~=nil end
function Manager:Unregister(id)
    local r=self._records[id]; if not r then return false end
    removeIndex(self._byName,r.Name,id); removeIndex(self._byClass,r.ClassName,id)
    self._records[id]=nil; self._statistics.Unregistered+=1; return true
end
function Manager:GetCount()
    local n=0; for _ in pairs(self._records) do n+=1 end; return n
end
function Manager:GetAll()
    local result={}; for _,id in ipairs(self:GetIds()) do local instance=self:GetById(id); if instance then result[#result+1]=instance end end
    return result
end
function Manager:GetIds()
    local result={}; for id in pairs(self._records) do result[#result+1]=id end; table.sort(result); return result
end
function Manager:FindByName(name)
    self._statistics.Lookups+=1; local result={}
    for _,id in ipairs(idsFrom(self._byName,name)) do local item=self:GetById(id); if item then result[#result+1]=item end end
    return result
end
function Manager:FindFirstByName(name) return self:FindByName(name)[1] end
function Manager:FindByClass(className)
    self._statistics.Lookups+=1; local result={}
    for _,id in ipairs(idsFrom(self._byClass,className)) do local item=self:GetById(id); if item then result[#result+1]=item end end
    return result
end
function Manager:FindFirstByClass(className) return self:FindByClass(className)[1] end
function Manager:AddTag(id,tag)
    if type(tag)~="string" or tag=="" then error("Tag must be a non-empty string",2) end
    local r=self._records[id]; if not r then return false end
    r.Tags[tag]=true; return true
end
function Manager:RemoveTag(id,tag)
    local r=self._records[id]; if not r or not r.Tags[tag] then return false end
    r.Tags[tag]=nil; return true
end
function Manager:HasTag(id,tag)
    local r=self._records[id]; return r~=nil and r.Tags[tag]==true
end
function Manager:GetTags(id)
    local r=self._records[id]; local result={}
    if r then for tag in pairs(r.Tags) do result[#result+1]=tag end end
    table.sort(result); return result
end
function Manager:FindByTag(tag)
    local result={}
    for _,id in ipairs(self:GetIds()) do if self:HasTag(id,tag) then local item=self:GetById(id); if item then result[#result+1]=item end end end
    return result
end
function Manager:SetGroup(id,group)
    local r=self._records[id]; if not r then return false end
    if group~=nil and (type(group)~="string" or group=="") then error("Group must be a non-empty string or nil",2) end
    r.Group=group; return true
end
function Manager:GetGroup(id) local r=self._records[id]; return r and r.Group or nil end
function Manager:FindByGroup(group)
    local result={}
    for _,id in ipairs(self:GetIds()) do local r=self._records[id]; if r.Group==group then local item=self:GetById(id); if item then result[#result+1]=item end end end
    return result
end
function Manager:SetMetadata(id,metadata)
    local r=self._records[id]; if not r then return false end
    r.Metadata=metadata; return true
end
function Manager:GetMetadata(id)
    local r=self._records[id]; return r and r.Metadata or nil
end
function Manager:Refresh(instance)
    local id=self:GetId(instance); if not id or not alive(instance) then return false end
    local r=self._records[id]
    if r.Name~=instance.Name then
        removeIndex(self._byName,r.Name,id); r.Name=instance.Name; addIndex(self._byName,r.Name,id)
    end
    if r.ClassName~=instance.ClassName then
        removeIndex(self._byClass,r.ClassName,id); r.ClassName=instance.ClassName; addIndex(self._byClass,r.ClassName,id)
    end
    return true
end
function Manager:RebuildIndexes()
    self._byName={}; self._byClass={}
    for id,r in pairs(self._records) do
        if alive(r.Instance) then
            r.Name=r.Instance.Name; r.ClassName=r.Instance.ClassName
            addIndex(self._byName,r.Name,id); addIndex(self._byClass,r.ClassName,id)
        end
    end
    return true
end
function Manager:Validate()
    for id,r in pairs(self._records) do
        if r.Id~=id or not alive(r.Instance) then return false,"Invalid or destroyed instance: "..tostring(id) end
        if not (self._byName[r.Name] and self._byName[r.Name][id]) then return false,"Missing name index: "..id end
        if not (self._byClass[r.ClassName] and self._byClass[r.ClassName][id]) then return false,"Missing class index: "..id end
    end
    return true
end
function Manager:Destroy(id)
    local instance=self:GetById(id); if not instance then return false end
    self:Unregister(id)
    if type(instance.Destroy)=="function" then instance:Destroy() end
    self._statistics.Destroyed+=1; return true
end
function Manager:DestroyAll()
    local ids=self:GetIds(); local destroyed=0
    for i=#ids,1,-1 do if self:Destroy(ids[i]) then destroyed+=1 end end
    return destroyed
end
function Manager:GetStatistics()
    return {Count=self:GetCount(),Registered=self._statistics.Registered,
        Unregistered=self._statistics.Unregistered,Lookups=self._statistics.Lookups,
        Destroyed=self._statistics.Destroyed}
end
function Manager:Clear()
    local count=self:GetCount(); self._records={}; self._byName={}; self._byClass={}; return count
end
function Manager:Reset()
    self:Clear(); self._nextId=0
    self._statistics={Registered=0,Unregistered=0,Lookups=0,Destroyed=0}; return true
end
return Manager
