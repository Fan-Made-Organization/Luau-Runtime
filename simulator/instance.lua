
local Instance = {}

local InstanceMethods = {}
InstanceMethods.__index = InstanceMethods

local classDefaults = {
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
    object.Parent = nil
    object._children = {}
    object._destroyed = false

    return setmetatable(object, InstanceMethods)
end

function InstanceMethods:IsA(className)
    return self.ClassName == className or className == "Instance"
end

function InstanceMethods:GetChildren()
    return self._children
end

function InstanceMethods:FindFirstChild(name)
    for _, child in ipairs(self._children) do
        if child.Name == name then
            return child
        end
    end

    return nil
end

function InstanceMethods:AddChild(child)
    if child.Parent then
        error("Instance already has a parent")
    end

    child.Parent = self
    table.insert(self._children, child)

    return child
end

function InstanceMethods:GetFullName()
    if not self.Parent then
        return self.Name
    end

    return self.Parent:GetFullName() .. "." .. self.Name
end

function InstanceMethods:Destroy()
    for _, child in ipairs(self._children) do
        child:Destroy()
    end

    self._children = {}
    self._destroyed = true
    self.Parent = nil
end

return Instance
