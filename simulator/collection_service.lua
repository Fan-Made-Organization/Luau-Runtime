local Signal = require("./signal")

local CollectionService = {
    _tags = {},
    _addedSignals = {},
    _removedSignals = {},
}

local function validateInstance(instance)
    if type(instance) ~= "table" or not instance._isInstance then
        error("Expected an Instance")
    end

    if instance._destroyed then
        error("Cannot use a destroyed Instance")
    end
end

local function validateTag(tag)
    if type(tag) ~= "string" or tag == "" then
        error("Tag must be a non-empty string")
    end
end

function CollectionService:AddTag(instance, tag)
    validateInstance(instance)
    validateTag(tag)

    self._tags[tag] = self._tags[tag] or {}

    if self._tags[tag][instance] then
        return
    end

    self._tags[tag][instance] = true

    local signal = self._addedSignals[tag]

    if signal then
        signal:Fire(instance)
    end
end

function CollectionService:RemoveTag(instance, tag)
    validateInstance(instance)
    validateTag(tag)

    local tagged = self._tags[tag]

    if not tagged or not tagged[instance] then
        return
    end

    tagged[instance] = nil

    local signal = self._removedSignals[tag]

    if signal then
        signal:Fire(instance)
    end

    if next(tagged) == nil then
        self._tags[tag] = nil
    end
end

function CollectionService:HasTag(instance, tag)
    validateInstance(instance)
    validateTag(tag)

    return self._tags[tag] ~= nil
        and self._tags[tag][instance] == true
end

function CollectionService:GetTagged(tag)
    validateTag(tag)

    local result = {}

    for instance in pairs(self._tags[tag] or {}) do
        table.insert(result, instance)
    end

    return result
end

function CollectionService:GetAllTags()
    local result = {}

    for tag in pairs(self._tags) do
        table.insert(result, tag)
    end

    table.sort(result)

    return result
end

function CollectionService:GetInstanceAddedSignal(tag)
    validateTag(tag)

    if not self._addedSignals[tag] then
        self._addedSignals[tag] = Signal.new()
    end

    return self._addedSignals[tag]
end

function CollectionService:GetInstanceRemovedSignal(tag)
    validateTag(tag)

    if not self._removedSignals[tag] then
        self._removedSignals[tag] = Signal.new()
    end

    return self._removedSignals[tag]
end

function CollectionService:ClearTag(tag)
    validateTag(tag)

    local instances = self:GetTagged(tag)

    for _, instance in ipairs(instances) do
        self:RemoveTag(instance, tag)
    end
end

function CollectionService:GetTagCount(tag)
    validateTag(tag)

    local count = 0

    for _ in pairs(self._tags[tag] or {}) do
        count = count + 1
    end

    return count
end

function CollectionService:ClearAllTags()
    local tags = self:GetAllTags()

    for _, tag in ipairs(tags) do
        self:ClearTag(tag)
    end
end

return CollectionService
