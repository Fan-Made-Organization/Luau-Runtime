local InstanceExtensions = {}

local function isInstance(object)
    return type(object) == "table"
        and object._isInstance == true
end

function InstanceExtensions.GetAncestors(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local ancestors = {}
    local current = object.Parent

    while current do
        table.insert(ancestors, current)
        current = current.Parent
    end

    return ancestors
end

function InstanceExtensions.GetRoot(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local current = object

    while current.Parent do
        current = current.Parent
    end

    return current
end

function InstanceExtensions.GetDepth(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local depth = 0
    local current = object.Parent

    while current do
        depth += 1
        current = current.Parent
    end

    return depth
end

function InstanceExtensions.GetChildrenOfClass(object, className)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local results = {}

    for _, child in ipairs(object:GetChildren()) do
        if child:IsA(className) then
            table.insert(results, child)
        end
    end

    return results
end

function InstanceExtensions.GetDescendantsOfClass(object, className)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local results = {}

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA(className) then
            table.insert(results, descendant)
        end
    end

    return results
end

function InstanceExtensions.FindFirstDescendant(object, name)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant.Name == name then
            return descendant
        end
    end

    return nil
end

function InstanceExtensions.FindFirstDescendantOfClass(object, className)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA(className) then
            return descendant
        end
    end

    return nil
end

function InstanceExtensions.FindByPath(object, path)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    if type(path) ~= "string" then
        error("Path must be a string", 2)
    end

    local current = object

    for segment in string.gmatch(path, "[^%.]+") do
        if segment == ".." then
            current = current.Parent
        elseif segment == "." then
            -- Mantener el objeto actual.
        else
            if not current then
                return nil
            end

            current = current:FindFirstChild(segment)
        end

        if not current then
            return nil
        end
    end

    return current
end

function InstanceExtensions.GetPath(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local segments = {}
    local current = object

    while current do
        table.insert(segments, 1, current.Name)
        current = current.Parent
    end

    return table.concat(segments, ".")
end

function InstanceExtensions.GetInformation(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local children = object:GetChildren()
    local descendants = object:GetDescendants()

    return {
        Name = object.Name,
        ClassName = object.ClassName,
        FullName = object:GetFullName(),
        Path = InstanceExtensions.GetPath(object),

        Depth = InstanceExtensions.GetDepth(object),

        ChildCount = #children,
        DescendantCount = #descendants,

        IsRoot = object.Parent == nil,
        Parent = object.Parent,

        Ancestors = InstanceExtensions.GetAncestors(object),
    }
end

function InstanceExtensions.GetTree(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    local function buildNode(instance)
        local node = {
            Name = instance.Name,
            ClassName = instance.ClassName,
            Children = {},
        }

        for _, child in ipairs(instance:GetChildren()) do
            table.insert(node.Children, buildNode(child))
        end

        return node
    end

    return buildNode(object)
end

function InstanceExtensions.SetAttributes(object, attributes)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    if type(attributes) ~= "table" then
        error("Attributes must be a table", 2)
    end

    for name, value in pairs(attributes) do
        object:SetAttribute(name, value)
    end

    return true
end

function InstanceExtensions.GetAttributeSnapshot(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    if type(object.GetAttributes) == "function" then
        return object:GetAttributes()
    end

    return {}
end

function InstanceExtensions.CloneHierarchy(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    return object:Clone()
end

function InstanceExtensions.GetHierarchyCount(object)
    if not isInstance(object) then
        error("Expected an Instance", 2)
    end

    return 1 + #object:GetDescendants()
end

return InstanceExtensions
