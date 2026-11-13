local Workspace = {}

Workspace.Name = "Workspace"
Workspace.ClassName = "Workspace"
Workspace.Parent = nil

function Workspace:GetFullName()
    return "Workspace"
end

function Workspace:IsA(className)
    return className == "Workspace" or className == "Model"
end

function Workspace:GetChildren()
    return {}
end

function Workspace:FindFirstChild(name)
    return nil
end

return Workspace
