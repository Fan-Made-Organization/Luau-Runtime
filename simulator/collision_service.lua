local Signal = require("./signal")

local CollisionService = {
    Enabled = true,

    _parts = {},
    _activeCollisions = {},

    _statistics = {
        Checks = 0,
        Collisions = 0,
        Started = 0,
        Ended = 0,
    },
}

local function getVector(value, default)
    if type(value) ~= "table" then
        return {
            X = default,
            Y = default,
            Z = default,
        }
    end

    return {
        X = value.X or value.x or default,
        Y = value.Y or value.y or default,
        Z = value.Z or value.z or default,
    }
end

local function isValidPart(part)
    return type(part) == "table"
        and part._isInstance == true
        and (
            part.ClassName == "Part"
            or part.ClassName == "MeshPart"
            or part.ClassName == "UnionOperation"
        )
end

local function getBounds(part)
    local position = getVector(part.Position, 0)
    local size = getVector(part.Size, 1)

    local halfX = math.abs(size.X) / 2
    local halfY = math.abs(size.Y) / 2
    local halfZ = math.abs(size.Z) / 2

    return {
        MinX = position.X - halfX,
        MaxX = position.X + halfX,

        MinY = position.Y - halfY,
        MaxY = position.Y + halfY,

        MinZ = position.Z - halfZ,
        MaxZ = position.Z + halfZ,
    }
end

local function intersects(a, b)
    return a.MinX <= b.MaxX
        and a.MaxX >= b.MinX
        and a.MinY <= b.MaxY
        and a.MaxY >= b.MinY
        and a.MinZ <= b.MaxZ
        and a.MaxZ >= b.MinZ
end

local function makePairKey(a, b)
    local first = tostring(a)
    local second = tostring(b)

    if first > second then
        first, second = second, first
    end

    return first .. "|" .. second
end

local function fireTouched(part, otherPart)
    if part.Destroyed then
        return
    end

    local touched = part.Touched

    if touched and type(touched.Fire) == "function" then
        touched:Fire(otherPart)
    end
end

local function fireTouchEnded(part, otherPart)
    if part.Destroyed then
        return
    end

    local touchEnded = part.TouchEnded

    if touchEnded and type(touchEnded.Fire) == "function" then
        touchEnded:Fire(otherPart)
    end
end

function CollisionService:RegisterPart(part)
    if not isValidPart(part) then
        error("CollisionService:RegisterPart expects a Part", 2)
    end

    if self._parts[part] then
        return false
    end

    if not part.Touched then
        part.Touched = Signal.new()
    end

    if not part.TouchEnded then
        part.TouchEnded = Signal.new()
    end

    self._parts[part] = true

    return true
end

function CollisionService:UnregisterPart(part)
    if not self._parts[part] then
        return false
    end

    local ended = {}

    for key, pair in pairs(self._activeCollisions) do
        if pair.A == part or pair.B == part then
            table.insert(ended, {
                Key = key,
                A = pair.A,
                B = pair.B,
            })
        end
    end

    for _, pair in ipairs(ended) do
        self._activeCollisions[pair.Key] = nil

        fireTouchEnded(pair.A, pair.B)
        fireTouchEnded(pair.B, pair.A)

        self._statistics.Ended += 1
    end

    self._parts[part] = nil

    return true
end

function CollisionService:IsRegistered(part)
    return self._parts[part] == true
end

function CollisionService:CheckCollision(partA, partB)
    if not isValidPart(partA) or not isValidPart(partB) then
        error("CheckCollision expects two Parts", 2)
    end

    self._statistics.Checks += 1

    if partA == partB then
        return false
    end

    if partA.CanCollide == false or partB.CanCollide == false then
        return false
    end

    return intersects(
        getBounds(partA),
        getBounds(partB)
    )
end

function CollisionService:Step()
    if not self.Enabled then
        return 0
    end

    local parts = {}

    for part in pairs(self._parts) do
        if part.Destroyed then
            self._parts[part] = nil
        elseif part.CanCollide ~= false then
            table.insert(parts, part)
        end
    end

    local currentCollisions = {}
    local collisionCount = 0

    for i = 1, #parts do
        local partA = parts[i]

        for j = i + 1, #parts do
            local partB = parts[j]

            self._statistics.Checks += 1

            if intersects(
                getBounds(partA),
                getBounds(partB)
            ) then
                local key = makePairKey(partA, partB)

                currentCollisions[key] = {
                    A = partA,
                    B = partB,
                }

                collisionCount += 1

                if not self._activeCollisions[key] then
                    fireTouched(partA, partB)
                    fireTouched(partB, partA)

                    self._statistics.Started += 1
                end
            end
        end
    end

    for key, pair in pairs(self._activeCollisions) do
        if not currentCollisions[key] then
            fireTouchEnded(pair.A, pair.B)
            fireTouchEnded(pair.B, pair.A)

            self._statistics.Ended += 1
        end
    end

    self._activeCollisions = currentCollisions

    self._statistics.Collisions += collisionCount

    return collisionCount
end

function CollisionService:SetEnabled(enabled)
    self.Enabled = enabled == true

    if not self.Enabled then
        for key, pair in pairs(self._activeCollisions) do
            fireTouchEnded(pair.A, pair.B)
            fireTouchEnded(pair.B, pair.A)

            self._statistics.Ended += 1

            self._activeCollisions[key] = nil
        end
    end
end

function CollisionService:IsEnabled()
    return self.Enabled
end

function CollisionService:GetPartCount()
    local count = 0

    for _ in pairs(self._parts) do
        count += 1
    end

    return count
end

function CollisionService:GetCollisionCount()
    local count = 0

    for _ in pairs(self._activeCollisions) do
        count += 1
    end

    return count
end

function CollisionService:GetStatistics()
    return {
        Checks = self._statistics.Checks,
        Collisions = self._statistics.Collisions,
        Started = self._statistics.Started,
        Ended = self._statistics.Ended,

        CurrentCollisions = self:GetCollisionCount(),
        RegisteredParts = self:GetPartCount(),
    }
end

function CollisionService:ResetStatistics()
    self._statistics = {
        Checks = 0,
        Collisions = 0,
        Started = 0,
        Ended = 0,
    }
end

function CollisionService:Clear()
    self:SetEnabled(false)

    self._parts = {}
    self._activeCollisions = {}

    self.Enabled = true
end

return CollisionService
