local Signal = require("./signal")

local Instance = {}

local InstanceMethods = {}
local InstanceMetatable = {}

-- ==========================================
-- CLASS INHERITANCE
-- ==========================================

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

-- ==========================================
-- CLASS DEFAULTS
-- ==========================================

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

-- ==========================================
-- INTERNAL VALIDATION
-- ==========================================

local function checkAlive(self)
    if self._destroyed then
        error("Cannot modify a destroyed Instance", 3)
    end
end

local function isValidInstance(object)
    return type(object) == "table"
        and object._isInstance == true
        and type(object._children) == "table"
        and type(object._properties) == "table"
end

local function validateInstance(object)
    if not isValidInstance(object) then
        error("Expected an Instance", 3)
    end

    if object._destroyed then
        error("Cannot use a destroyed Instance", 3)
    end
end

-- ==========================================
-- TABLE COPYING
-- ==========================================

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    -- Preserve references to Instances.
    if value._isInstance then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}

    seen[value] = copy

    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end

    local metatable = getmetatable(value)

    if metatable then
        setmetatable(copy, metatable)
    end

    return copy
end

-- ==========================================
-- HIERARCHY HELPERS
-- ==========================================

local function removeChild(parent, child)
    if not parent then
        return
    end

    for i = #parent._children, 1, -1 do
        if parent._children[i] == child then
            table.remove(parent._children, i)
            return
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
    if self._destroyed then
        return
    end

    if self.Changed and not self.Changed:IsDestroyed() then
        self.Changed:Fire(property)
    end

    local signal = self._propertySignals[property]

    if signal and not signal:IsDestroyed() then
        signal:Fire()
    end
end

-- ==========================================
-- METATABLE
-- ==========================================

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
        checkAlive(self)

        if value == self then
            error("An Instance cannot be its own parent", 2)
        end

        if value ~= nil then
            if not isValidInstance(value) then
                error("Parent must be an Instance or nil", 2)
            end

            if value._destroyed then
                error("Cannot parent to a destroyed Instance", 2)
            end

            if isAncestor(value, self) then
                error("Cannot create a circular hierarchy", 2)
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

    checkAlive(self)

    if self._properties[key] ~= value then
        self._properties[key] = value
        notifyChanged(self, key)
    end
end

-- ==========================================
-- INSTANCE CREATION
-- ==========================================

function Instance.new(className)
    if type(className) ~= "string" then
        error("Instance.new expects a class name", 2)
    end

    local defaults = classDefaults[className]

    if not defaults then
        error("Unknown class: " .. className, 2)
    end

    local properties = {}

    for key, value in pairs(defaults) do
        properties[key] = deepCopy(value)
    end

    properties.ClassName = className
    properties.Archivable = true

    local object = {
        _properties = properties,

        _parent = nil,
        _children = {},

        _attributes = {},

        _propertySignals = {},
        _attributeSignals = {},

        _destroyed = false,
        _isInstance = true,

        Changed = Signal.new(),
    }

    return setmetatable(object, InstanceMetatable)
end

-- ==========================================
-- CLASS INFORMATION
-- ==========================================

function InstanceMethods:IsA(className)
    if type(className) ~= "string" then
        return false
    end

    local currentClass = self.ClassName

    if currentClass == className or className == "Instance" then
        return true
    end

    local classes = inheritance[currentClass]

    return classes ~= nil and classes[className] == true
end

function InstanceMethods:IsDestroyed()
    return self._destroyed
end

-- ==========================================
-- CHILDREN
-- ==========================================

function InstanceMethods:GetChildren()
    local children = {}

    for i, child in ipairs(self._children) do
        children[i] = child
    end

    return children
end

function InstanceMethods:GetDescendants()
    local descendants = {}
    local stack = {}

    for i = #self._children, 1, -1 do
        table.insert(stack, self._children[i])
    end

    while #stack > 0 do
        local current = table.remove(stack)

        table.insert(descendants, current)

        for i = #current._children, 1, -1 do
            table.insert(stack, current._children[i])
        end
    end

    return descendants
end

-- ==========================================
-- CHILD SEARCH
-- ==========================================

function InstanceMethods:FindFirstChild(name, recursive)
    for _, child in ipairs(self._children) do
        if child.Name == name then
            return child
        end
    end

    if recursive then
        local descendants = self:GetDescendants()

        for _, descendant in ipairs(descendants) do
            if descendant.Name == name then
                return descendant
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
        for _, descendant in ipairs(self:GetDescendants()) do
            if descendant:IsA(className) then
                return descendant
            end
        end
    end

    return nil
end

-- ==========================================
-- ANCESTORS
-- ==========================================

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
    if not isValidInstance(ancestor) then
        return false
    end

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
    if not isValidInstance(descendant) then
        return false
    end

    return descendant:IsDescendantOf(self)
end

-- ==========================================
-- FULL NAME
-- ==========================================

function InstanceMethods:GetFullName()
    local names = {}
    local current = self

    while current do
        table.insert(names, 1, tostring(current.Name))
        current = current.Parent
    end

    return table.concat(names, ".")
end

-- ==========================================
-- PROPERTY SIGNALS
-- ==========================================

function InstanceMethods:GetPropertyChangedSignal(property)
    if type(property) ~= "string" then
        error("Property name must be a string", 2)
    end

    checkAlive(self)

    if not self._propertySignals[property] then
        self._propertySignals[property] = Signal.new()
    end

    return self._propertySignals[property]
end

-- ==========================================
-- ATTRIBUTES
-- ==========================================

function InstanceMethods:SetAttribute(name, value)
    checkAlive(self)

    if type(name) ~= "string" then
        error("Attribute name must be a string", 2)
    end

    if self._attributes[name] == value then
        return
    end

    self._attributes[name] = value

    local signal = self._attributeSignals[name]

    if signal then
        signal:Fire()
    end
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

function InstanceMethods:RemoveAttribute(name)
    checkAlive(self)

    if type(name) ~= "string" then
        error("Attribute name must be a string", 2)
    end

    if self._attributes[name] == nil then
        return
    end

    self._attributes[name] = nil

    local signal = self._attributeSignals[name]

    if signal then
        signal:Fire()
    end
end

function InstanceMethods:GetAttributeChangedSignal(name)
    if type(name) ~= "string" then
        error("Attribute name must be a string", 2)
    end

    checkAlive(self)

    if not self._attributeSignals[name] then
        self._attributeSignals[name] = Signal.new()
    end

    return self._attributeSignals[name]
end

function InstanceMethods:GetAttributesCount()
    local count = 0

    for _ in pairs(self._attributes) do
        count = count + 1
    end

    return count
end

-- ==========================================
-- CLEAR CHILDREN
-- ==========================================

function InstanceMethods:ClearAllChildren()
    checkAlive(self)

    local children = self:GetChildren()

    for _, child in ipairs(children) do
        child:Destroy()
    end
end

-- ==========================================
-- CLONE
-- ==========================================

function InstanceMethods:Clone()
    if self._destroyed then
        error("Cannot clone a destroyed Instance", 2)
    end

    if not self.Archivable then
        return nil
    end

    local clone = Instance.new(self.ClassName)

    for key, value in pairs(self._properties) do
        clone._properties[key] = deepCopy(value)
    end

    for name, value in pairs(self._attributes) do
        clone:SetAttribute(name, deepCopy(value))
    end

    for _, child in ipairs(self._children) do
        local childClone = child:Clone()

        if childClone then
            childClone.Parent = clone
        end
    end

    return clone
end

-- ==========================================
-- DESTROY
-- ==========================================

function InstanceMethods:Destroy()
    if self._destroyed then
        return
    end

    -- Mark destroyed first to prevent re-entry.
    self._destroyed = true

    -- Destroy children.
    local children = self:GetChildren()

    for _, child in ipairs(children) do
        child:Destroy()
    end

    -- Detach from parent without invoking Parent setter.
    local oldParent = self._parent

    if oldParent then
        removeChild(oldParent, self)
        rawset(self, "_parent", nil)
    end

    -- Destroy Changed signal.
    if self.Changed then
        self.Changed:Destroy()
    end

    -- Destroy property signals.
    for _, signal in pairs(self._propertySignals) do
        signal:Destroy()
    end

    -- Destroy attribute signals.
    for _, signal in pairs(self._attributeSignals) do
        signal:Destroy()
    end

    -- Release internal signal references.
    self._propertySignals = {}
    self._attributeSignals = {}

    -- Release attributes.
    self._attributes = {}
end

-- ==========================================
-- MODULE EXPORT
-- ==========================================

return Instance
