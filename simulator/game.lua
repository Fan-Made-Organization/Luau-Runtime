local Services = require("simulator.services")
local Workspace = require("simulator.workspace")

local Game = {}

Services.Register("Workspace", Workspace)

function Game:GetService(name)
    return Services.GetService(name)
end

function Game:IsLoaded()
    return true
end

function Game:GetFullName()
    return "game"
end

return Game
