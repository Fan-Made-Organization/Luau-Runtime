local Instance = require("./instance")
local Players = require("./players")
local RunService = require("./run_service")
local CollectionService = require("./collection_service")
local DebrisService = require("./debris_service")
local HttpService = require("./http_service")
local TweenService = require("./tween_service")

local ScriptService = require("./script_service")
local ScriptLifecycle = require("./script_lifecycle")

local BindableEvent = require("./bindable_event")
local BindableFunction = require("./bindable_function")

local RemoteEvent = require("./remote_event")
local RemoteFunction = require("./remote_function")

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
BuiltinServices.Debris = DebrisService
BuiltinServices.HttpService = HttpService
BuiltinServices.TweenService = TweenService

BuiltinServices.ScriptService = ScriptService
BuiltinServices.ScriptLifecycle = ScriptLifecycle

BuiltinServices.BindableEvent = BindableEvent
BuiltinServices.BindableFunction = BindableFunction

BuiltinServices.RemoteEvent = RemoteEvent
BuiltinServices.RemoteFunction = RemoteFunction

return BuiltinServices

return BuiltinServices
