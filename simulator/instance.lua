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
    },

    LocalScript = {
        Name = "LocalScript",
        Disabled = false,
    },

    ModuleScript = {
        Name = "ModuleScript",
    },
}

local function removeChild(parent, child)
    if not parent or not parent._children then
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

InstanceMetatable.__index = function(self, key)
    if key == "Parent" then
        return rawget(self, "_parent")
    end

    return InstanceMethods[key] or rawget(self, key)
end

InstanceMetatable.__newindex = function(self, key, value)
    if key ~= "Parent" then
        rawset(self, key, value)
        return
    end

    if self._destroyed then
        error("Cannot modify a destroyed Instance")
    end

    if value == self then
        error("An Instance cannot be its own parent")
    end

    if value ~= nil then
        if type(value) ~= "table" or not value._children then
            error("Parent must be an Instance or nil")
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
end

function Instance.new(className)
    if type(className) ~= "string" then
        error("Instance.new expects a class name")
    end

    local defaults = classDefaults[className]

    if not defaults then
        error("Unknown class: " .. className)
    end

    local object = {}

    for key, value in pairs(defaults) do
        object[key] = value
    end

    object.ClassName = className
    object._parent = nil
    object._children = {}
    object._destroyed = false

    return setmetatable(object, InstanceMetatable)
end

function InstanceMethods:IsA(className)
    if self.ClassName == className or className == "Instance" then
        return true
    end

    if self.ClassName == "Workspace" and className == "Model" then
        return true
    end

    return false
end

function InstanceMethods:GetChildren()
    local children = {}

    for i, child in ipairs(self._children) do
        children[i] = child
    end

    return children
end

function InstanceMethods:FindFirstChild(name)
    for _, child in ipairs(self._children) do
        if child.Name == name then
            return child
        end
    end

    return nil
end

function InstanceMethods:GetFullName()
    if not self.Parent then
        return self.Name
    end

    return self.Parent:GetFullName() .. "." .. self.Name
end

function InstanceMethods:Destroy()
    if self._destroyed then
        return
    end

    local children = self:GetChildren()

    for _, child in ipairs(children) do
        child:Destroy()
    end

    self.Parent = nil
    self._destroyed = true
end

return Instance
