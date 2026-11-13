local Signal = require("./signal")

local Instance = {}

local InstanceMethods = {}
local InstanceMetatable = {}

local classDefaults = {
    Workspace = {
        Name = "Workspace",
    },

    Part = {
        Name = "Part",
        Anchored = false,
        CanCollide = true,
        Transparency = 0,
        Position = {0, 0, 0},
        Size = {4, 1, 2},
    },

    Model = {
        Name = "Model",
    },

    Folder = {
        Name = "Folder",
    },

    Script = {
        Name = "Script",
        Disabled = false,
        Source = "",
    },

    LocalScript = {
        Name = "LocalScript",
        Disabled = false,
        Source = "",
    },

    ModuleScript = {
        Name = "ModuleScript",
        Source = "",
    },
}

local function removeChild(parent, child)
    if not parent then
        return
    end

    for i, existing in ipairs(parent._children) do
        if existing == child then
            table.remove(parent._children, i)
            break
        end
    end
end

local function isAncestor(object, possibleAncestor)
    local current = object

    while current do
        if current == possibleAncestor then
            return true
        end

        current = current.Parent
    end

    return false
end

local function notifyChanged(self, property)
    self.Changed:Fire(property)

    local signal = self._propertySignals[property]

    if signal then
        signal:Fire()
    end
end

InstanceMetatable.__index = function(self, key)
    if key == "Parent" then
        return rawget(self, "_parent")
    end

    local method = InstanceMethods[key]

    if method then
        return method
    end

    return self._properties[key]
end

InstanceMetatable.__newindex = function(self, key, value)
    if key == "Parent" then
        if self._destroyed then
            error("Cannot modify a destroyed Instance")
        end

        if value == self then
            error("An Instance cannot be its own parent")
        end

        if value ~= nil then
            if type(value) ~= "table" or not value._isInstance then
                error("Parent must be an Instance or nil")
            end

            if value._destroyed then
                error("Cannot parent to a destroyed Instance")
            end

            if isAncestor(value, self) then
                error("Cannot create a circular hierarchy")
            end
        end

        local oldParent = self._parent

        if oldParent == value then
            return
        end

        removeChild(oldParent, self)

        rawset(self, "_parent", value)

        if value then
            table.insert(value._children, self)
        end

        notifyChanged(self, "Parent")
        return
    end

    if self._properties[key] ~= value then
        self._properties[key] = value
        notifyChanged(self, key)
    end
end

function Instance.new(className)
    if type(className) ~= "string" then
        error("Instance.new expects a class name")
    end

    local defaults = classDefaults[className]

    if not defaults then
        error("Unknown class: " .. className)
    end

    local properties = {}

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            local copy = {}

            for k, v in pairs(value) do
                copy[k] = v
            end

            properties[key] = copy
        else
            properties[key] = value
        end
    end

    properties.ClassName = className
    properties.Archivable = true

    local object = {
        _properties = properties,
        _parent = nil,
        _children = {},
        _attributes = {},
        _propertySignals = {},
        _destroyed = false,
        _isInstance = true,
        Changed = Signal.new(),
    }

    return setmetatable(object, InstanceMetatable)
end

function InstanceMethods:IsA(className)
    if self.ClassName == className or className == "Instance" then
        return true
    end

    local inheritance = {
        Workspace = {
            Model = true,
            WorldRoot = true,
        },

        Part = {
            BasePart = true,
        },

        Script = {
            BaseScript = true,
            LuaSourceContainer = true,
        },

        LocalScript = {
            BaseScript = true,
            LuaSourceContainer = true,
        },

        ModuleScript = {
            LuaSourceContainer = true,
        },
    }

    return inheritance[self.ClassName]
        and inheritance[self.ClassName][className] == true
        or false
end

function InstanceMethods:GetChildren()
    local children = {}

    for i, child in ipairs(self._children) do
        children[i] = child
    end

    return children
end

function InstanceMethods:GetDescendants()
    local descendants = {}

    local function collect(parent)
        for _, child in ipairs(parent._children) do
            table.insert(descendants, child)
            collect(child)
        end
    end

    collect(self)

    return descendants
end

function InstanceMethods:FindFirstChild(name, recursive)
    for _, child in ipairs(self._children) do
        if child.Name == name then
            return child
        end
    end

    if recursive then
        for _, child in ipairs(self._children) do
            local found = child:FindFirstChild(name, true)

            if found then
                return found
            end
        end
    end

    return nil
end

function InstanceMethods:FindFirstChildOfClass(className)
    for _, child in ipairs(self._children) do
        if child.ClassName == className then
            return child
        end
    end

    return nil
end

function InstanceMethods:FindFirstChildWhichIsA(className, recursive)
    for _, child in ipairs(self._children) do
        if child:IsA(className) then
            return child
        end
    end

    if recursive then
        for _, child in ipairs(self._children) do
            local found = child:FindFirstChildWhichIsA(className, true)

            if found then
                return found
            end
        end
    end

    return nil
end

function InstanceMethods:FindFirstAncestor(name)
    local current = self.Parent

    while current do
        if current.Name == name then
            return current
        end

        current = current.Parent
    end

    return nil
end

function InstanceMethods:IsDescendantOf(ancestor)
    local current = self.Parent

    while current do
        if current == ancestor then
            return true
        end

        current = current.Parent
    end

    return false
end

function InstanceMethods:IsAncestorOf(descendant)
    return descendant:IsDescendantOf(self)
end

function InstanceMethods:GetFullName()
    if not self.Parent then
        return self.Name
    end

    return self.Parent:GetFullName() .. "." .. self.Name
end

function InstanceMethods:GetPropertyChangedSignal(property)
    if type(property) ~= "string" then
        error("Property name must be a string")
    end

    if not self._propertySignals[property] then
        self._propertySignals[property] = Signal.new()
    end

    return self._propertySignals[property]
end

function InstanceMethods:SetAttribute(name, value)
    if type(name) ~= "string" then
        error("Attribute name must be a string")
    end

    self._attributes[name] = value
end

function InstanceMethods:GetAttribute(name)
    return self._attributes[name]
end

function InstanceMethods:GetAttributes()
    local attributes = {}

    for name, value in pairs(self._attributes) do
        attributes[name] = value
    end

    return attributes
end

function InstanceMethods:ClearAllChildren()
    local children = self:GetChildren()

    for _, child in ipairs(children) do
        child:Destroy()
    end
end

function InstanceMethods:Clone()
    if not self.Archivable then
        return nil
    end

    local clone = Instance.new(self.ClassName)

    for key, value in pairs(self._properties) do
        if type(value) == "table" then
            local copy = {}

            for k, v in pairs(value) do
                copy[k] = v
            end

            clone[key] = copy
        else
            clone[key] = value
        end
    end

    for name, value in pairs(self._attributes) do
        clone:SetAttribute(name, value)
    end

    for _, child in ipairs(self._children) do
        local childClone = child:Clone()

        if childClone then
            childClone.Parent = clone
        end
    end

    return clone
end

function InstanceMethods:Destroy()
    if self._destroyed then
        return
    end

    self:ClearAllChildren()
    self.Parent = nil

    self.Changed:Destroy()

    for _, signal in pairs(self._propertySignals) do
        signal:Destroy()
    end

    self._destroyed = true
end

return Instance
