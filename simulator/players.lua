local Instance = require("./instance")
local Signal = require("./signal")

local Players = Instance.new("Folder")

Players.Name = "Players"
Players.ClassName = "Players"

Players.PlayerAdded = Signal.new()
Players.PlayerRemoving = Signal.new()

local playerList = {}

local function findPlayer(name)
    for _, player in ipairs(playerList) do
        if player.Name == name then
            return player
        end
    end

    return nil
end

function Players:GetPlayers()
    local result = {}

    for i, player in ipairs(playerList) do
        result[i] = player
    end

    return result
end

function Players:GetPlayerByUserId(userId)
    for _, player in ipairs(playerList) do
        if player.UserId == userId then
            return player
        end
    end

    return nil
end

function Players:FindFirstChild(name)
    return findPlayer(name)
end

function Players:GetPlayerFromCharacter(character)
    for _, player in ipairs(playerList) do
        if player.Character == character then
            return player
        end
    end

    return nil
end

function Players:AddPlayer(name, userId)
    if type(name) ~= "string" then
        error("Player name must be a string")
    end

    if findPlayer(name) then
        error("Player already exists")
    end

    local player = Instance.new("Folder")

    player.Name = name
    player.ClassName = "Player"
    player.UserId = userId or 0
    player.DisplayName = name
    player.Character = nil

    table.insert(playerList, player)

    player.Parent = self

    self.PlayerAdded:Fire(player)

    return player
end

function Players:RemovePlayer(name)
    local player = findPlayer(name)

    if not player then
        return false
    end

    self.PlayerRemoving:Fire(player)

    for i, existing in ipairs(playerList) do
        if existing == player then
            table.remove(playerList, i)
            break
        end
    end

    player:Destroy()

    return true
end

function Players:GetPlayerCount()
    return #playerList
end

function Players:ClearPlayers()
    local players = self:GetPlayers()

    for _, player in ipairs(players) do
        self:RemovePlayer(player.Name)
    end
end

return Players
