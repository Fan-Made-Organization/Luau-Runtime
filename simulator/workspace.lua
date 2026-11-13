local Instance = require("./instance")

local Workspace = Instance.new("Workspace")

Workspace.Name = "Workspace"

function Workspace:GetPartBoundsInBox()
    error("GetPartBoundsInBox is not implemented yet")
end

function Workspace:GetPartBoundsInRadius()
    error("GetPartBoundsInRadius is not implemented yet")
end

function Workspace:GetPartsInPart()
    error("GetPartsInPart is not implemented yet")
end

function Workspace:Raycast()
    error("Raycast is not implemented yet")
end

return Workspace
