-- Resource Manager provides explicit ownership and deterministic cleanup scopes.
local ResourceManager = {
    Enabled = true, _resources = {}, _scopes = {}, _nextScope = 0,
    _statistics = { Registered = 0, Released = 0, CleanupErrors = 0 },
}
local function validName(value) return type(value) == "string" and value ~= "" end
local function safeCleanup(resource)
    if resource.Released then return true end
    resource.Released = true
    if type(resource.Cleanup) == "function" then
        local ok, err = pcall(resource.Cleanup, resource.Value)
        if not ok then ResourceManager._statistics.CleanupErrors += 1; return false, err end
    elseif type(resource.Value) == "table" and type(resource.Value.Destroy) == "function" then
        local ok, err = pcall(resource.Value.Destroy, resource.Value)
        if not ok then ResourceManager._statistics.CleanupErrors += 1; return false, err end
    end
    ResourceManager._statistics.Released += 1
    return true
end
function ResourceManager:Register(id, value, options)
    if not validName(id) then error("Resource id must be a non-empty string", 2) end
    if self._resources[id] then return false, "Resource already registered" end
    if not self.Enabled then return false, "Resource manager is disabled" end
    options = options or {}
    if type(options) ~= "table" then error("Resource options must be a table", 2) end
    if options.Cleanup ~= nil and type(options.Cleanup) ~= "function" then error("Cleanup must be a function", 2) end
    if options.Scope ~= nil and not self._scopes[options.Scope] then return false, "Unknown scope" end
    if options.Scope ~= nil and self._scopes[options.Scope].Closed then return false, "Scope is closed" end
    self._resources[id] = {
        Id = id, Value = value, Type = options.Type or type(value),
        Tag = options.Tag or "Default", Scope = options.Scope,
        Cleanup = options.Cleanup, Dependencies = {}, Released = false,
        CreatedAt = os.clock(), Metadata = options.Metadata,
    }
    self._statistics.Registered += 1
    if options.Scope then
        local scope = self._scopes[options.Scope]
        scope.Resources[#scope.Resources + 1] = id
    end
    return true, self:Get(id)
end
function ResourceManager:Get(id)
    local r = self._resources[id]
    if not r then return nil end
    return { Id = r.Id, Value = r.Value, Type = r.Type, Tag = r.Tag,
        Scope = r.Scope, Released = r.Released, Metadata = r.Metadata }
end
function ResourceManager:Has(id) return self._resources[id] ~= nil end
function ResourceManager:IsReleased(id)
    local r = self._resources[id]
    return r == nil or r.Released
end
function ResourceManager:SetCleanup(id, callback)
    if type(callback) ~= "function" then error("Cleanup must be a function", 2) end
    local r = self._resources[id]; if not r then return false end
    r.Cleanup = callback; return true
end
function ResourceManager:SetMetadata(id, metadata)
    local r = self._resources[id]; if not r then return false end
    r.Metadata = metadata; return true
end
function ResourceManager:SetTag(id, tag)
    if not validName(tag) then error("Tag must be a non-empty string", 2) end
    local r = self._resources[id]; if not r then return false end
    r.Tag = tag; return true
end
function ResourceManager:Transfer(id, scopeId)
    local r = self._resources[id]
    if not r then return false, "Resource not found" end
    if scopeId ~= nil and not self._scopes[scopeId] then return false, "Unknown scope" end
    if scopeId ~= nil and self._scopes[scopeId].Closed then return false, "Scope is closed" end
    if r.Scope and self._scopes[r.Scope] then
        local old = self._scopes[r.Scope].Resources
        for i = #old, 1, -1 do if old[i] == id then table.remove(old, i); break end end
    end
    r.Scope = scopeId
    if scopeId then table.insert(self._scopes[scopeId].Resources, id) end
    return true
end
function ResourceManager:Release(id)
    local r = self._resources[id]
    if not r then return false end
    local ok, err = safeCleanup(r)
    self._resources[id] = nil
    return ok, err
end
function ResourceManager:ReleaseByTag(tag)
    local ids = {}
    for id, r in pairs(self._resources) do if r.Tag == tag then ids[#ids + 1] = id end end
    local released, failed = 0, 0
    for _, id in ipairs(ids) do local ok = self:Release(id); if ok then released += 1 else failed += 1 end end
    return released, failed
end
function ResourceManager:ReleaseScope(scopeId)
    local scope = self._scopes[scopeId]
    if not scope then return false, "Scope not found" end
    local released, failed = 0, 0
    for i = #scope.Resources, 1, -1 do
        local ok = self:Release(scope.Resources[i])
        if ok then released += 1 else failed += 1 end
    end
    scope.Closed = true
    return true, { Released = released, Failed = failed }
end
function ResourceManager:CreateScope(name)
    if name ~= nil and not validName(name) then error("Scope name must be a non-empty string", 2) end
    self._nextScope += 1
    local id = "scope-" .. tostring(self._nextScope)
    self._scopes[id] = { Id = id, Name = name or id, Resources = {}, Closed = false }
    return id
end
function ResourceManager:GetScope(scopeId)
    local s = self._scopes[scopeId]; if not s then return nil end
    local resources = {}
    for i, id in ipairs(s.Resources) do resources[i] = id end
    return { Id = s.Id, Name = s.Name, Resources = resources, Closed = s.Closed }
end
function ResourceManager:GetScopeResources(scopeId)
    local s = self._scopes[scopeId]; if not s then return {} end
    local result = {}
    for _, id in ipairs(s.Resources) do if self._resources[id] then result[#result + 1] = self:Get(id) end end
    return result
end
function ResourceManager:Count()
    local n = 0; for _ in pairs(self._resources) do n += 1 end; return n
end
function ResourceManager:CountByType(resourceType)
    local n = 0; for _, r in pairs(self._resources) do if r.Type == resourceType then n += 1 end end; return n
end
function ResourceManager:FindByTag(tag)
    local result = {}
    for id, r in pairs(self._resources) do if r.Tag == tag then result[#result + 1] = self:Get(id) end end
    table.sort(result, function(a,b) return a.Id < b.Id end)
    return result
end
function ResourceManager:List()
    local result = {}
    for id in pairs(self._resources) do result[#result + 1] = id end
    table.sort(result); return result
end
function ResourceManager:AddDependency(id, dependencyId)
    local r = self._resources[id]
    if not r or not self._resources[dependencyId] then return false end
    if id == dependencyId then return false end
    r.Dependencies[dependencyId] = true
    return true
end
function ResourceManager:GetDependencies(id)
    local r = self._resources[id]; local result = {}
    if r then for dependency in pairs(r.Dependencies) do result[#result + 1] = dependency end end
    table.sort(result); return result
end
function ResourceManager:GetDependents(id)
    local result = {}
    for resourceId, r in pairs(self._resources) do
        if r.Dependencies[id] then result[#result + 1] = resourceId end
    end
    table.sort(result); return result
end
function ResourceManager:ReleaseDependents(id)
    local dependents = self:GetDependents(id)
    local released, failed = 0, 0
    for _, dependent in ipairs(dependents) do local ok = self:Release(dependent); if ok then released += 1 else failed += 1 end end
    return released, failed
end
function ResourceManager:SetEnabled(value) self.Enabled = value == true; return self.Enabled end
function ResourceManager:IsEnabled() return self.Enabled end
function ResourceManager:GetStatistics()
    local scopes = 0; for _ in pairs(self._scopes) do scopes += 1 end
    return { Enabled = self.Enabled, Resources = self:Count(), Scopes = scopes,
        Registered = self._statistics.Registered, Released = self._statistics.Released,
        CleanupErrors = self._statistics.CleanupErrors }
end
function ResourceManager:Validate()
    for id, r in pairs(self._resources) do
        if r.Id ~= id or r.Released then return false, "Invalid resource record: " .. tostring(id) end
        if r.Scope and not self._scopes[r.Scope] then return false, "Missing scope: " .. r.Scope end
    end
    return true
end
function ResourceManager:Clear()
    local ids = self:List(); local failed = 0
    for i = #ids, 1, -1 do local ok = self:Release(ids[i]); if not ok then failed += 1 end end
    self._scopes = {}
    return #ids, failed
end
function ResourceManager:Reset()
    self:Clear(); self.Enabled = true; self._nextScope = 0
    self._statistics = { Registered = 0, Released = 0, CleanupErrors = 0 }
    return true
end
return ResourceManager
