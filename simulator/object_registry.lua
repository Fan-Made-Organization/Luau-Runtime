local ObjectRegistry = {}

local Registry = {
    _objects = {},
    _objectIds = {},
    _nextId = 0,

    _stats = {
        Registered = 0,
        Unregistered = 0,
        Lookups = 0,
        FailedLookups = 0,
    },
}

local function isValidObject(object)
    return type(object) == "table"
        and object._isInstance == true
end

local function generateId(self)
    self._nextId += 1

    return "FMO-" .. string.format("%08d", self._nextId)
end

function Registry:Register(object)
    if not isValidObject(object) then
        error("ObjectRegistry: expected an Instance", 2)
    end

    local existingId = self._objectIds[object]

    if existingId then
        return existingId
    end

    local id = generateId(self)

    self._objects[id] = object
    self._objectIds[object] = id

    self._stats.Registered += 1

    return id
end

function Registry:Unregister(objectOrId)
    local id

    if type(objectOrId) == "string" then
        id = objectOrId
    elseif type(objectOrId) == "table" then
        id = self._objectIds[objectOrId]
    end

    if not id then
        return false
    end

    local object = self._objects[id]

    if not object then
        return false
    end

    self._objects[id] = nil
    self._objectIds[object] = nil

    self._stats.Unregistered += 1

    return true
end

function Registry:GetById(id)
    self._stats.Lookups += 1

    local object = self._objects[id]

    if not object then
        self._stats.FailedLookups += 1
    end

    return object
end

function Registry:GetId(object)
    self._stats.Lookups += 1

    local id = self._objectIds[object]

    if not id then
        self._stats.FailedLookups += 1
    end

    return id
end

function Registry:FindByName(name)
    local results = {}

    for _, object in pairs(self._objects) do
        if object.Name == name then
            table.insert(results, object)
        end
    end

    table.sort(results, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)

    return results
end

function Registry:FindByClass(className)
    local results = {}

    for _, object in pairs(self._objects) do
        if object.ClassName == className then
            table.insert(results, object)
        end
    end

    return results
end

function Registry:GetAll()
    local results = {}

    for id, object in pairs(self._objects) do
        table.insert(results, {
            Id = id,
            Object = object,
            Name = object.Name,
            ClassName = object.ClassName,
        })
    end

    table.sort(results, function(a, b)
        return a.Id < b.Id
    end)

    return results
end

function Registry:GetCount()
    local count = 0

    for _ in pairs(self._objects) do
        count += 1
    end

    return count
end

function Registry:Contains(objectOrId)
    if type(objectOrId) == "string" then
        return self._objects[objectOrId] ~= nil
    end

    if type(objectOrId) == "table" then
        return self._objectIds[objectOrId] ~= nil
    end

    return false
end

function Registry:GetStatistics()
    return {
        Registered = self._stats.Registered,
        Unregistered = self._stats.Unregistered,
        Lookups = self._stats.Lookups,
        FailedLookups = self._stats.FailedLookups,
        CurrentObjects = self:GetCount(),
        NextId = self._nextId,
    }
end

function Registry:ResetStatistics()
    self._stats = {
        Registered = 0,
        Unregistered = 0,
        Lookups = 0,
        FailedLookups = 0,
    }
end

function Registry:Clear()
    local count = self:GetCount()

    self._objects = {}
    self._objectIds = {}

    return count
end

function Registry:Reset()
    self:Clear()

    self._nextId = 0
    self:ResetStatistics()
end

return Registry
