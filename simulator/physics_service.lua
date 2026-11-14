local Physics = {
    Gravity = {
        X = 0,
        Y = -196.2,
        Z = 0,
    },

    Enabled = true,

    _parts = {},
    _clock = 0,

    _statistics = {
        Steps = 0,
        UpdatedParts = 0,
        RegisteredParts = 0,
        RemovedParts = 0,
    },
}

local function vector(x, y, z)
    return {
        X = x or 0,
        Y = y or 0,
        Z = z or 0,
    }
end

local function copyVector(value)
    if type(value) ~= "table" then
        return vector()
    end

    return vector(
        value.X or value.x,
        value.Y or value.y,
        value.Z or value.z
    )
end

local function add(a, b)
    return vector(
        a.X + b.X,
        a.Y + b.Y,
        a.Z + b.Z
    )
end

local function multiply(value, scalar)
    return vector(
        value.X * scalar,
        value.Y * scalar,
        value.Z * scalar
    )
end

local function isValidNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function isPart(object)
    return type(object) == "table"
        and object._isInstance == true
        and (
            object.ClassName == "Part"
            or object.ClassName == "MeshPart"
            or object.ClassName == "UnionOperation"
        )
end

function Physics:RegisterPart(part)
    if not isPart(part) then
        error("Physics:RegisterPart expects a Part", 2)
    end

    if self._parts[part] then
        return false
    end

    local position = copyVector(part.Position)
    local velocity = copyVector(part.Velocity)
    local acceleration = copyVector(part.Acceleration)

    self._parts[part] = {
        Position = position,
        Velocity = velocity,
        Acceleration = acceleration,
        Mass = part.Mass or 1,
    }

    part.Position = copyVector(position)
    part.Velocity = copyVector(velocity)
    part.Acceleration = copyVector(acceleration)

    self._statistics.RegisteredParts += 1

    return true
end

function Physics:RemovePart(part)
    if not self._parts[part] then
        return false
    end

    self._parts[part] = nil
    self._statistics.RemovedParts += 1

    return true
end

function Physics:IsRegistered(part)
    return self._parts[part] ~= nil
end

-- Supports both:
-- SetGravity({X = 0, Y = -10, Z = 0})
-- SetGravity(0, -10, 0)
function Physics:SetGravity(x, y, z)
    local newGravity

    if type(x) == "table" then
        newGravity = copyVector(x)
    else
        newGravity = vector(x, y, z)
    end

    if not isValidNumber(newGravity.X)
        or not isValidNumber(newGravity.Y)
        or not isValidNumber(newGravity.Z)
    then
        error("Gravity must contain valid numeric X, Y and Z components", 2)
    end

    self.Gravity = newGravity

    return true
end

function Physics:GetGravity()
    return copyVector(self.Gravity)
end

function Physics:SetVelocity(part, velocity)
    if not self:IsRegistered(part) then
        self:RegisterPart(part)
    end

    if type(velocity) ~= "table" then
        error("Velocity must be a vector table", 2)
    end

    local newVelocity = copyVector(velocity)

    self._parts[part].Velocity = newVelocity
    part.Velocity = copyVector(newVelocity)

    return true
end

function Physics:GetVelocity(part)
    local state = self._parts[part]

    if not state then
        return nil
    end

    return copyVector(state.Velocity)
end

function Physics:SetAcceleration(part, acceleration)
    if not self:IsRegistered(part) then
        self:RegisterPart(part)
    end

    if type(acceleration) ~= "table" then
        error("Acceleration must be a vector table", 2)
    end

    local newAcceleration = copyVector(acceleration)

    self._parts[part].Acceleration = newAcceleration
    part.Acceleration = copyVector(newAcceleration)

    return true
end

function Physics:GetPosition(part)
    local state = self._parts[part]

    if not state then
        return nil
    end

    return copyVector(state.Position)
end

function Physics:SetMass(part, mass)
    if not isValidNumber(mass) or mass <= 0 then
        error("Mass must be a positive finite number", 2)
    end

    if not self:IsRegistered(part) then
        self:RegisterPart(part)
    end

    self._parts[part].Mass = mass
    part.Mass = mass

    return true
end

function Physics:GetMass(part)
    local state = self._parts[part]

    if not state then
        return nil
    end

    return state.Mass
end

function Physics:Step(deltaTime)
    if not self.Enabled then
        return 0
    end

    if not isValidNumber(deltaTime) or deltaTime < 0 then
        error("Physics:Step expects a valid non-negative deltaTime", 2)
    end

    self._clock += deltaTime
    self._statistics.Steps += 1

    local updated = 0

    for part, state in pairs(self._parts) do
        if part.Destroyed or part._destroyed then
            self._parts[part] = nil
            self._statistics.RemovedParts += 1

        elseif part.Anchored then
            state.Position = copyVector(part.Position)
            state.Velocity = vector()

            part.Velocity = vector()

        else
            local gravity = copyVector(self.Gravity)
            local acceleration = copyVector(state.Acceleration)

            local totalAcceleration = add(
                gravity,
                acceleration
            )

            state.Velocity = add(
                state.Velocity,
                multiply(totalAcceleration, deltaTime)
            )

            state.Position = add(
                state.Position,
                multiply(state.Velocity, deltaTime)
            )

            part.Position = copyVector(state.Position)
            part.Velocity = copyVector(state.Velocity)

            updated += 1
        end
    end

    self._statistics.UpdatedParts += updated

    return updated
end

function Physics:SetEnabled(enabled)
    self.Enabled = enabled == true

    return self.Enabled
end

function Physics:IsEnabled()
    return self.Enabled
end

function Physics:GetPartCount()
    local count = 0

    for _ in pairs(self._parts) do
        count += 1
    end

    return count
end

function Physics:GetClock()
    return self._clock
end

function Physics:GetStatistics()
    return {
        Steps = self._statistics.Steps,
        UpdatedParts = self._statistics.UpdatedParts,
        RegisteredParts = self._statistics.RegisteredParts,
        RemovedParts = self._statistics.RemovedParts,
        CurrentParts = self:GetPartCount(),
        Clock = self._clock,
    }
end

function Physics:Reset()
    self._parts = {}
    self._clock = 0
    self.Enabled = true

    self.Gravity = vector(0, -196.2, 0)

    self._statistics = {
        Steps = 0,
        UpdatedParts = 0,
        RegisteredParts = 0,
        RemovedParts = 0,
    }

    return true
end

return Physics
