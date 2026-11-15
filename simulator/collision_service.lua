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
        RemovedParts = 0,
        SignalErrors = 0,
    },
}

-- ==========================================
-- VALIDATION
-- ==========================================

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function isDestroyed(part)
    if type(part) ~= "table" then
        return true
    end

    if part._destroyed == true or part.Destroyed == true then
        return true
    end

    if type(part.IsDestroyed) == "function" then
        local success, result = pcall(part.IsDestroyed, part)

        if not success or result == true then
            return true
        end
    end

    return false
end

local function isValidPart(part)
    return type(part) == "table"
        and part._isInstance == true
        and not isDestroyed(part)
        and (
            part.ClassName == "Part"
            or part.ClassName == "MeshPart"
            or part.ClassName == "UnionOperation"
        )
end

-- ==========================================
-- VECTOR UTILITIES
-- ==========================================

local function getVector(value, default)
    if type(value) ~= "table" then
        return {
            X = default,
            Y = default,
            Z = default,
        }
    end

    local x = value.X or value.x
    local y = value.Y or value.y
    local z = value.Z or value.z

    if not isFiniteNumber(x) then
        x = default
    end

    if not isFiniteNumber(y) then
        y = default
    end

    if not isFiniteNumber(z) then
        z = default
    end

    return {
        X = x,
        Y = y,
        Z = z,
    }
end

-- ==========================================
-- BOUNDING BOX
-- ==========================================

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

-- ==========================================
-- COLLISION PAIRS
-- ==========================================

local function makePairKey(a, b)
    local first = tostring(a)
    local second = tostring(b)

    if first > second then
        first, second = second, first
    end

    return first .. "|" .. second
end

-- ==========================================
-- SIGNAL HANDLING
-- ==========================================

local function fireSignal(part, signalName, otherPart)
    if isDestroyed(part) then
        return false
    end

    local signal = part[signalName]

    if type(signal) ~= "table"
        or type(signal.Fire) ~= "function" then
        return false
    end

    local success = pcall(function()
        signal:Fire(otherPart)
    end)

    if not success then
        CollisionService._statistics.SignalErrors += 1
        return false
    end

    return true
end

local function fireTouched(part, otherPart)
    return fireSignal(part, "Touched", otherPart)
end

local function fireTouchEnded(part, otherPart)
    return fireSignal(part, "TouchEnded", otherPart)
end

local function endCollision(pair)
    fireTouchEnded(pair.A, pair.B)
    fireTouchEnded(pair.B, pair.A)

    CollisionService._statistics.Ended += 1
end

-- ==========================================
-- REGISTRATION
-- ==========================================

function CollisionService:RegisterPart(part)
    if not isValidPart(part) then
        error("CollisionService:RegisterPart expects a valid Part", 2)
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
    if type(part) ~= "table" or not self._parts[part] then
        return false
    end

    local ended = {}

    for key, pair in pairs(self._activeCollisions) do
        if pair.A == part or pair.B == part then
            ended[#ended + 1] = {
                Key = key,
                A = pair.A,
                B = pair.B,
            }
        end
    end

    for _, pair in ipairs(ended) do
        self._activeCollisions[pair.Key] = nil

        endCollision(pair)
    end

    self._parts[part] = nil

    return true
end

function CollisionService:IsRegistered(part)
    return type(part) == "table"
        and self._parts[part] == true
end

-- ==========================================
-- COLLISION CHECKING
-- ==========================================

function CollisionService:CheckCollision(partA, partB)
    if not isValidPart(partA) or not isValidPart(partB) then
        error("CheckCollision expects two valid Parts", 2)
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

-- ==========================================
-- PHYSICS STEP
-- ==========================================

function CollisionService:Step()
    if not self.Enabled then
        return 0
    end

    local parts = {}
    local bounds = {}

    -- Collect valid parts and calculate bounds once.

    for part in pairs(self._parts) do
        if not isValidPart(part) then
            self._parts[part] = nil
            self._statistics.RemovedParts += 1

        elseif part.CanCollide ~= false then
            parts[#parts + 1] = part
            bounds[part] = getBounds(part)
        end
    end

    local currentCollisions = {}
    local collisionCount = 0

    -- Detect collisions.

    for i = 1, #parts do
        local partA = parts[i]
        local boundsA = bounds[partA]

        for j = i + 1, #parts do
            local partB = parts[j]

            self._statistics.Checks += 1

            if intersects(boundsA, bounds[partB]) then
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

    -- Detect ended collisions.

    for key, pair in pairs(self._activeCollisions) do
        if not currentCollisions[key] then
            endCollision(pair)
        end
    end

    -- Update active collision state.

    self._activeCollisions = currentCollisions

    self._statistics.Collisions += collisionCount

    return collisionCount
end

-- ==========================================
-- CONFIGURATION
-- ==========================================

function CollisionService:SetEnabled(enabled)
    self.Enabled = enabled == true

    if not self.Enabled then
        local ended = {}

        for key, pair in pairs(self._activeCollisions) do
            ended[#ended + 1] = {
                Key = key,
                Pair = pair,
            }
        end

        for _, entry in ipairs(ended) do
            self._activeCollisions[entry.Key] = nil
            endCollision(entry.Pair)
        end
    end
end

function CollisionService:IsEnabled()
    return self.Enabled
end

-- ==========================================
-- STATISTICS
-- ==========================================

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

        RemovedParts = self._statistics.RemovedParts,
        SignalErrors = self._statistics.SignalErrors,

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
        RemovedParts = 0,
        SignalErrors = 0,
    }
end

-- ==========================================
-- CLEANUP
-- ==========================================

function CollisionService:Clear()
    self:SetEnabled(false)

    self._parts = {}
    self._activeCollisions = {}

    self.Enabled = true
end

return CollisionService
