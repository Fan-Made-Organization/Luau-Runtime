local Instance = require("./instance")

local BuiltinServices = {}

local serviceNames = {
    "Players",
    "Lighting",
    "ReplicatedStorage",
    "ServerStorage",
    "StarterGui",
    "StarterPlayer",
    "SoundService",
    "Teams",
    "RunService",
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

return BuiltinServices
