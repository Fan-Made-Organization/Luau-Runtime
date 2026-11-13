local Instance = require("./instance")
local Players = require("./players")
local RunService = require("./run_service")
local CollectionService = require("./collection_service")

local BuiltinServices = {}

local serviceNames = {
    "Lighting",
    "ReplicatedStorage",
    "ServerStorage",
    "StarterGui",
    "StarterPlayer",
    "SoundService",
    "Teams",
    "UserInputService",
    "HttpService",
    "TweenService",
}

for _, name in ipairs(serviceNames) do
    local service = Instance.new("Folder")

    service.Name = name
    service.ClassName = name

    BuiltinServices[name] = service
end

BuiltinServices.Players = Players
BuiltinServices.RunService = RunService
BuiltinServices.CollectionService = CollectionService

return BuiltinServices
