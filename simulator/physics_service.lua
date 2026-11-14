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

local function isValidNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function vector(x, y, z)
    return {
        X = x or 0,
        Y = y or 0,
        Z = z or 0,
    }
end

local function isValidVector(value)
    if type(value) ~= "table" then
        return false
    end

    local x = value.X
    local y = value.Y
    local z = value.Z

    if x == nil then x = value.x end
    if y == nil then y = value.y end
    if z == nil then z = value.z end

    return isValidNumber(x or 0)
        and isValidNumber(y or 0)
        and isValidNumber(z or 0)
end

local function copyVector(value)
    if not isValidVector(value) then
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

local function isPart(object)
    return type(object) == "table"
        and object._isInstance == true
        and not object._destroyed
        and not object.Destroyed
        and (
            object.ClassName == "Part"
            or object.ClassName == "MeshPart"
            or object.ClassName == "UnionOperation"
        )
end

local function isDestroyed(part)
    if type(part) ~= "table" then
        return true
    end

    if part._destroyed or part.Destroyed then
        return true
    end

    if type(part.IsDestroyed) == "function" then
        local success, result = pcall(part.IsDestroyed, part)

        if success and result == true then
            return true
        end
    end

    return false
end

function Physics:RegisterPart(part)
    if not isPart(part) then
        error("Physics:RegisterPart expects a valid Part", 2)
    end

    if self._parts[part] then
        return false
    end

    local position = copyVector(part.Position)
    local velocity = copyVector(part.Velocity)
    local acceleration = copyVector(part.Acceleration)

    local mass = part.Mass

    if mass == nil then
        mass = 1
    end

    if not isValidNumber(mass) or mass <= 0 then
        error("Part Mass must be a positive finite number", 2)
    end

    self._parts[part] = {
        Position = position,
        Velocity = velocity,
        Acceleration = acceleration,
        Mass = mass,
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

function Physics:SetGravity(x, y, z)
    local newGravity

    if type(x) == "table" then
        if not isValidVector(x) then
            error("Gravity must contain valid numeric components", 2)
        end

        newGravity = copyVector(x)
    else
        if not isValidNumber(x or 0)
            or not isValidNumber(y or 0)
            or not isValidNumber(z or 0)
        then
            error("Gravity components must be finite numbers", 2)
        end

        newGravity = vector(x, y, z)
    end

    self.Gravity = newGravity

    return true
end

function Physics:GetGravity()
    return copyVector(self.Gravity)
end

function Physics:SetVelocity(part, velocity)
    if not isValidVector(velocity) then
        error("Velocity must be a valid vector table", 2)
    end

    if not self:IsRegistered(part) then
        self:RegisterPart(part)
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
    if not isValidVector(acceleration) then
        error("Acceleration must be a valid vector table", 2)
    end

    if not self:IsRegistered(part) then
        self:RegisterPart(part)
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

    -- Cache gravity once per simulation step.
    local gravity = self.Gravity

    local gravityX = gravity.X
    local gravityY = gravity.Y
    local gravityZ = gravity.Z

    for part, state in pairs(self._parts) do
        if isDestroyed(part) then
            self._parts[part] = nil
            self._statistics.RemovedParts += 1

        elseif part.Anchored then
            state.Position = copyVector(part.Position)
            state.Velocity = vector()

            part.Velocity = vector()

        else
            local acceleration = state.Acceleration

            local totalAccelerationX = gravityX + acceleration.X
            local totalAccelerationY = gravityY + acceleration.Y
            local totalAccelerationZ = gravityZ + acceleration.Z

            local velocity = state.Velocity

            velocity.X += totalAccelerationX * deltaTime
            velocity.Y += totalAccelerationY * deltaTime
            velocity.Z += totalAccelerationZ * deltaTime

            local position = state.Position

            position.X += velocity.X * deltaTime
            position.Y += velocity.Y * deltaTime
            position.Z += velocity.Z * deltaTime

            part.Position = copyVector(position)
            part.Velocity = copyVector(velocity)

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
