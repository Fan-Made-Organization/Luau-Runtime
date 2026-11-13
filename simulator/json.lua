local JSON = {}

local function isArray(value)
    local count = 0
    local maximum = 0

    for key in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key % 1 ~= 0 then
            return false
        end

        count = count + 1

        if key > maximum then
            maximum = key
        end
    end

    return count == maximum, maximum
end

local function encodeString(value)
    local replacements = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t',
    }

    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        return replacements[character]
            or string.format("\\u%04x", string.byte(character))
    end) .. '"'
end

local function encode(value, visited)
    local valueType = type(value)

    if value == JSON.null then
        return "null"
    end

    if valueType == "nil" then
        error("Cannot encode nil as JSON")
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("Cannot encode non-finite numbers")
        end

        return string.format("%.17g", value)
    elseif valueType == "string" then
        return encodeString(value)
    elseif valueType ~= "table" then
        error("Unsupported JSON value: " .. valueType)
    end

    if visited[value] then
        error("Circular reference detected")
    end

    visited[value] = true

    local array, length = isArray(value)
    local result = {}

    if array then
        for index = 1, length do
            table.insert(result, encode(value[index], visited))
        end

        visited[value] = nil

        return "[" .. table.concat(result, ",") .. "]"
    end

    local keys = {}

    for key in pairs(value) do
        if type(key) ~= "string" then
            error("JSON object keys must be strings")
        end

        table.insert(keys, key)
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        table.insert(
            result,
            encodeString(key) .. ":" .. encode(value[key], visited)
        )
    end

    visited[value] = nil

    return "{" .. table.concat(result, ",") .. "}"
end

function JSON.encode(value)
    return encode(value, {})
end

local function decodeError(message, position)
    error(
        "JSON error at position "
        .. tostring(position)
        .. ": "
        .. message
    )
end

local function decodeString(source, position)
    position = position + 1

    local result = {}

    while position <= #source do
        local character = source:sub(position, position)

        if character == '"' then
            return table.concat(result), position + 1
        end

        if character == "\\" then
            position = position + 1

            local escaped = source:sub(position, position)

            local replacements = {
                ['"'] = '"',
                ["\\"] = "\\",
                ["/"] = "/",
                ["b"] = "\b",
                ["f"] = "\f",
                ["n"] = "\n",
                ["r"] = "\r",
                ["t"] = "\t",
            }

            if replacements[escaped] then
                table.insert(result, replacements[escaped])
                position = position + 1

            elseif escaped == "u" then
                local hex = source:sub(position + 1, position + 4)

                if not hex:match("^%x%x%x%x$") then
                    decodeError("Invalid Unicode escape", position)
                end

                local codepoint = tonumber(hex, 16)
                position = position + 5

                if codepoint >= 0xD800 and codepoint <= 0xDBFF then
                    if source:sub(position, position + 1) ~= "\\u" then
                        decodeError("Invalid Unicode surrogate", position)
                    end

                    local lowHex = source:sub(position + 2, position + 5)

                    if not lowHex:match("^%x%x%x%x$") then
                        decodeError("Invalid Unicode surrogate", position)
                    end

                    local low = tonumber(lowHex, 16)

                    if low < 0xDC00 or low > 0xDFFF then
                        decodeError("Invalid Unicode surrogate", position)
                    end

                    codepoint = 0x10000
                        + (codepoint - 0xD800) * 0x400
                        + (low - 0xDC00)

                    position = position + 6

                elseif codepoint >= 0xDC00 and codepoint <= 0xDFFF then
                    decodeError("Unexpected low surrogate", position)
                end

                if codepoint <= 0x7F then
                    table.insert(result, string.char(codepoint))
                elseif codepoint <= 0x7FF then
                    table.insert(result, string.char(
                        0xC0 + math.floor(codepoint / 64),
                        0x80 + codepoint % 64
                    ))
                elseif codepoint <= 0xFFFF then
                    table.insert(result, string.char(
                        0xE0 + math.floor(codepoint / 4096),
                        0x80 + math.floor(codepoint / 64) % 64,
                        0x80 + codepoint % 64
                    ))
                else
                    table.insert(result, string.char(
                        0xF0 + math.floor(codepoint / 262144),
                        0x80 + math.floor(codepoint / 4096) % 64,
                        0x80 + math.floor(codepoint / 64) % 64,
                        0x80 + codepoint % 64
                    ))
                end

            else
                decodeError("Invalid escape character", position)
            end

        else
            if string.byte(character) < 32 then
                decodeError("Unescaped control character", position)
            end

            table.insert(result, character)
            position = position + 1
        end
    end

    decodeError("Unterminated string", position)
end

local function skipWhitespace(source, position)
    while position <= #source do
        local character = source:sub(position, position)

        if character == " "
            or character == "\n"
            or character == "\r"
            or character == "\t" then
            position = position + 1
        else
            break
        end
    end

    return position
end

local parseValue

local function parseArray(source, position)
    position = skipWhitespace(source, position + 1)

    local result = {}

    if source:sub(position, position) == "]" then
        return result, position + 1
    end

    while true do
        local value

        value, position = parseValue(source, position)

        table.insert(result, value)

        position = skipWhitespace(source, position)

        local character = source:sub(position, position)

        if character == "]" then
            return result, position + 1
        elseif character ~= "," then
            decodeError("Expected ',' or ']'", position)
        end

        position = skipWhitespace(source, position + 1)
    end
end

local function parseObject(source, position)
    position = skipWhitespace(source, position + 1)

    local result = {}

    if source:sub(position, position) == "}" then
        return result, position + 1
    end

    while true do
        if source:sub(position, position) ~= '"' then
            decodeError("Expected object key", position)
        end

        local key
        key, position = decodeString(source, position)

        position = skipWhitespace(source, position)

        if source:sub(position, position) ~= ":" then
            decodeError("Expected ':'", position)
        end

        position = skipWhitespace(source, position + 1)

        local value
        value, position = parseValue(source, position)

        result[key] = value

        position = skipWhitespace(source, position)

        local character = source:sub(position, position)

        if character == "}" then
            return result, position + 1
        elseif character ~= "," then
            decodeError("Expected ',' or '}'", position)
        end

        position = skipWhitespace(source, position + 1)
    end
end

parseValue = function(source, position)
    position = skipWhitespace(source, position)

    local character = source:sub(position, position)

    if character == '"' then
        return decodeString(source, position)
    elseif character == "{" then
        return parseObject(source, position)
    elseif character == "[" then
        return parseArray(source, position)
    elseif source:sub(position, position + 3) == "true" then
        return true, position + 4
    elseif source:sub(position, position + 4) == "false" then
        return false, position + 5
    elseif source:sub(position, position + 3) == "null" then
        return JSON.null, position + 4
    end

    local remaining = source:sub(position)

    local number = remaining:match(
        "^-?%d+%.?%d*[eE]?[+-]?%d*"
    )

    if not number or number == "" then
        decodeError("Unexpected value", position)
    end

    if not number:match(
        "^-?(0|[1-9]%d*)(%.%d+)?([eE][+-]?%d+)?$"
    ) then
        -- Validación adicional abajo.
    end

    local value = tonumber(number)

    if not value or value == math.huge or value == -math.huge then
        decodeError("Invalid number", position)
    end

    return value, position + #number
end

function JSON.decode(source)
    if type(source) ~= "string" then
        error("JSONDecode expects a string")
    end

    local result, position = parseValue(source, 1)

    position = skipWhitespace(source, position)

    if position <= #source then
        decodeError("Unexpected trailing data", position)
    end

    return result
end

JSON.null = {}

return JSON
