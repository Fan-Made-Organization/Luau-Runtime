-- Detached, cycle-safe snapshots for runtime diagnostics and reports.
-- Instance objects are identity-bearing runtime objects and must remain references.
local Snapshot = {}

function Snapshot.Clone(value, seen)
    if type(value) ~= "table" then
        return value
    end

    if rawget(value, "_isInstance") == true then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, item in pairs(value) do
        copy[Snapshot.Clone(key, seen)] = Snapshot.Clone(item, seen)
    end

    return copy
end

function Snapshot.Array(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = Snapshot.Clone(value)
    end
    return result
end

return Snapshot
