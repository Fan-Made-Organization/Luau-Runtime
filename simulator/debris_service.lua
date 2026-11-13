local DebrisService = {
    _items = {},
    _clock = 0,
    MaxItems = 1000,
}

function DebrisService:AddItem(instance, lifetime)
    if type(instance) ~= "table" or not instance._isInstance then
        error("AddItem expects an Instance")
    end

    if instance._destroyed then
        error("Cannot schedule a destroyed Instance")
    end

    if type(lifetime) ~= "number" or lifetime < 0 then
        error("Lifetime must be a non-negative number")
    end

    if #self._items >= self.MaxItems then
        error("DebrisService item limit reached")
    end

    table.insert(self._items, {
        Instance = instance,
        DestroyTime = self._clock + lifetime,
    })
end

function DebrisService:RemoveItem(instance)
    local removed = false

    for i = #self._items, 1, -1 do
        if self._items[i].Instance == instance then
            table.remove(self._items, i)
            removed = true
        end
    end

    return removed
end

function DebrisService:Step(deltaTime)
    if type(deltaTime) ~= "number" or deltaTime < 0 then
        error("deltaTime must be a non-negative number")
    end

    self._clock = self._clock + deltaTime

    local remaining = {}
    local destroyedCount = 0

    for _, item in ipairs(self._items) do
        local instance = item.Instance

        if instance._destroyed then
            -- Ya fue destruido; no hace falta conservarlo.

        elseif self._clock >= item.DestroyTime then
            instance:Destroy()
            destroyedCount = destroyedCount + 1

        else
            table.insert(remaining, item)
        end
    end

    self._items = remaining

    return destroyedCount
end

function DebrisService:GetPendingCount()
    return #self._items
end

function DebrisService:GetClock()
    return self._clock
end

function DebrisService:Clear()
    self._items = {}
    self._clock = 0
end

return DebrisService
