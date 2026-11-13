local JSON = require("./json")

local HttpService = {
    JSONNull = JSON.null,
}

function HttpService:JSONEncode(value)
    return JSON.encode(value)
end

function HttpService:JSONDecode(value)
    return JSON.decode(value)
end

function HttpService:GenerateGUID(wrapInBraces)
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

    local guid = template:gsub("[xy]", function(character)
        local random = math.random(0, 15)

        if character == "y" then
            random = math.floor(random / 4) + 8
        end

        return string.format("%x", random)
    end)

    if wrapInBraces then
        return "{" .. guid .. "}"
    end

    return guid
end

function HttpService:UrlEncode(value)
    if type(value) ~= "string" then
        error("UrlEncode expects a string")
    end

    return value:gsub("([^%w%-_%.~])", function(character)
        return string.format("%%%02X", string.byte(character))
    end)
end

function HttpService:UrlDecode(value)
    if type(value) ~= "string" then
        error("UrlDecode expects a string")
    end

    return value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

return HttpService
