local Signal = require("./signal")

local TweenService = {
    _activeTweens = {},
}

local TweenMethods = {}
local TweenMetatable = {
    __index = TweenMethods,
}

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = item
    end

    return result
end

local function interpolate(startValue, endValue, alpha)
    if type(startValue) == "number"
        and type(endValue) == "number" then

        return startValue + (endValue - startValue) * alpha
    end

    if type(startValue) == "table"
        and type(endValue) == "table" then

        local result = {}

        for key, target in pairs(endValue) do
            local start = startValue[key]

            if type(start) ~= "number"
                or type(target) ~= "number" then
                error("Tween table values must contain matching numbers")
            end

            result[key] = start + (target - start) * alpha
        end

        return result
    end

    error("Tween only supports numbers and numeric tables")
end

local function ease(alpha, style, direction)
    if style == "Linear" then
        return alpha
    end

    if style == "Quad" then
        if direction == "In" then
            return alpha * alpha
        elseif direction == "Out" then
            return 1 - (1 - alpha) * (1 - alpha)
        elseif direction == "InOut" then
            if alpha < 0.5 then
                return 2 * alpha * alpha
            end

            return 1 - ((-2 * alpha + 2) ^ 2) / 2
        end
    end

    if style == "Sine" then
        if direction == "In" then
            return 1 - math.cos((alpha * math.pi) / 2)
        elseif direction == "Out" then
            return math.sin((alpha * math.pi) / 2)
        elseif direction == "InOut" then
            return -(math.cos(math.pi * alpha) - 1) / 2
        end
    end

    error("Unsupported easing style or direction")
end

function TweenMethods:Play()
    if self.PlaybackState == "Playing" then
        return
    end

    if self.Instance._destroyed then
        error("Cannot play a tween on a destroyed Instance")
    end

    self._startValues = {}

    for property, target in pairs(self.Goals) do
        local current = self.Instance[property]

        if type(current) ~= type(target) then
            error("Tween property types must match: " .. property)
        end

        self._startValues[property] = copyValue(current)
    end

    self._elapsed = 0
    self.PlaybackState = "Playing"

    table.insert(TweenService._activeTweens, self)
end

function TweenMethods:Pause()
    if self.PlaybackState ~= "Playing" then
        return
    end

    self.PlaybackState = "Paused"

    for i, tween in ipairs(TweenService._activeTweens) do
        if tween == self then
            table.remove(TweenService._activeTweens, i)
            break
        end
    end
end

function TweenMethods:Cancel()
    for i, tween in ipairs(TweenService._activeTweens) do
        if tween == self then
            table.remove(TweenService._activeTweens, i)
            break
        end
    end

    self._elapsed = 0
    self.PlaybackState = "Cancelled"
    self.Completed:Fire("Cancelled")
end

function TweenMethods:Destroy()
    self:Cancel()
    self.Completed:Destroy()
end

function TweenService:Create(instance, tweenInfo, goals)
    if type(instance) ~= "table"
        or not instance._isInstance then
        error("Create expects an Instance")
    end

    if instance._destroyed then
        error("Cannot tween a destroyed Instance")
    end

    if type(tweenInfo) ~= "table" then
        error("TweenInfo must be a table")
    end

    if type(goals) ~= "table" then
        error("Tween goals must be a table")
    end

    local duration = tweenInfo.Time or 1

    if type(duration) ~= "number" or duration < 0 then
        error("Tween duration must be non-negative")
    end

    local style = tweenInfo.EasingStyle or "Linear"
    local direction = tweenInfo.EasingDirection or "InOut"

    local supportedStyles = {
        Linear = true,
        Quad = true,
        Sine = true,
    }

    local supportedDirections = {
        In = true,
        Out = true,
        InOut = true,
    }

    if not supportedStyles[style] then
        error("Unsupported easing style: " .. tostring(style))
    end

    if not supportedDirections[direction] then
        error("Unsupported easing direction: " .. tostring(direction))
    end

    if next(goals) == nil then
        error("Tween goals cannot be empty")
    end

    return setmetatable({
        Instance = instance,
        TweenInfo = tweenInfo,
        Goals = goals,

        PlaybackState = "Begin",
        Completed = Signal.new(),

        _duration = duration,
        _style = style,
        _direction = direction,
        _elapsed = 0,
        _startValues = {},
    }, TweenMetatable)
end

function TweenService:Step(deltaTime)
    if type(deltaTime) ~= "number" or deltaTime < 0 then
        error("deltaTime must be non-negative")
    end

    local active = {}

    for _, tween in ipairs(self._activeTweens) do
        table.insert(active, tween)
    end

    for _, tween in ipairs(active) do
        if tween.PlaybackState ~= "Playing" then
            -- No actualizar tweens pausados o cancelados.

        elseif tween.Instance._destroyed then
            tween:Cancel()

        else
            tween._elapsed = tween._elapsed + deltaTime

            local alpha

            if tween._duration == 0 then
                alpha = 1
            else
                alpha = math.min(
                    tween._elapsed / tween._duration,
                    1
                )
            end

            local easedAlpha = ease(
                alpha,
                tween._style,
                tween._direction
            )

            for property, target in pairs(tween.Goals) do
                tween.Instance[property] = interpolate(
                    tween._startValues[property],
                    target,
                    easedAlpha
                )
            end

            if alpha >= 1 then
                tween.PlaybackState = "Completed"

                for i, existing in ipairs(self._activeTweens) do
                    if existing == tween then
                        table.remove(self._activeTweens, i)
                        break
                    end
                end

                tween.Completed:Fire("Completed")
            end
        end
    end
end

function TweenService:GetActiveTweenCount()
    return #self._activeTweens
end

function TweenService:CancelAll()
    local active = {}

    for _, tween in ipairs(self._activeTweens) do
        table.insert(active, tween)
    end

    for _, tween in ipairs(active) do
        tween:Cancel()
    end
end

return TweenService
