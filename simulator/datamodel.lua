local Instance = require("./instance")

local DataModel = Instance.new("Folder")

DataModel.Name = "game"
DataModel.ClassName = "DataModel"

function DataModel:IsLoaded()
    return true
end

function DataModel:GetServiceCount()
    local count = 0

    for _, child in ipairs(self:GetChildren()) do
        count = count + 1
    end

    return count
end

function DataModel:GetServiceNames()
    local names = {}

    for _, child in ipairs(self:GetChildren()) do
        table.insert(names, child.Name)
    end

    table.sort(names)

    return names
end

return DataModel
