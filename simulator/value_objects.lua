local Instance = require("./instance")

local ValueObjects = {}

local definitions = {
    BoolValue = {
        Default = false,
        Validate = function(value)
            return type(value) == "boolean"
        end,
    },

    StringValue = {
        Default = "",
        Validate = function(value)
            return type(value) == "string"
        end,
    },

    IntValue = {
        Default = 0,
        Validate = function(value)
            return type(value) == "number"
                and value % 1 == 0
        end,
    },

    NumberValue = {
        Default = 0,
        Validate = function(value)
            return type(value) == "number"
                and value == value
                and value ~= math.huge
                and value ~= -math.huge
        end,
    },

    ObjectValue = {
        Default = nil,
        Validate = function(value)
            return value == nil
                or (
                    type(value) == "table"
                    and value._isInstance == true
                )
        end,
    },
}

function ValueObjects.IsValueObject(className)
    return definitions[className] ~= nil
end

function ValueObjects.GetTypes()
    local result = {}

    for className in pairs(definitions) do
        table.insert(result, className)
    end

    table.sort(result)

    return result
end

function ValueObjects.new(className, initialValue)
    local definition = definitions[className]

    if not definition then
        error(
            "Unknown ValueObject type: " .. tostring(className),
            2
        )
    end

    local value = initialValue

    if value == nil then
        value = definition.Default
    end

    if not definition.Validate(value) then
        error(
            "Invalid value for " .. className,
            2
        )
    end

    local object = Instance.new("Folder")

    object.Name = className
    object.ClassName = className
    object.Value = value

    rawset(object, "_valueType", className)

    rawset(object, "GetValue", function(self)
        return self.Value
    end)

    rawset(object, "SetValue", function(self, newValue)
        if self.Destroyed then
            error("Cannot modify a destroyed ValueObject", 2)
        end

        if not definition.Validate(newValue) then
            error(
                "Invalid value for " .. className,
                2
            )
        end

        self.Value = newValue

        return true
    end)

    rawset(object, "GetValueType", function(self)
        return self._valueType
    end)

    return object
end

function ValueObjects.BoolValue(value)
    return ValueObjects.new("BoolValue", value)
end

function ValueObjects.StringValue(value)
    return ValueObjects.new("StringValue", value)
end

function ValueObjects.IntValue(value)
    return ValueObjects.new("IntValue", value)
end

function ValueObjects.NumberValue(value)
    return ValueObjects.new("NumberValue", value)
end

function ValueObjects.ObjectValue(value)
    return ValueObjects.new("ObjectValue", value)
end

return ValueObjects
