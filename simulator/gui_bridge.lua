local JSON = require("./json")

local GuiBridge = {}

local PROPERTY_ALLOWLIST = {
    "Name", "ClassName", "Text", "PlaceholderText", "Visible",
    "Enabled", "DisplayOrder", "BackgroundColor3", "BackgroundTransparency",
    "TextColor3", "TextSize", "TextXAlignment", "TextYAlignment",
    "Font", "Size", "Position", "AnchorPoint", "ZIndex",
    "BorderSizePixel", "CanvasSize", "ScrollingDirection",
    "AutomaticCanvasSize", "LayoutOrder", "Rotation",
}

local function safeValue(value, depth)
    depth = depth or 0
    if depth > 5 then return tostring(value) end
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
        return value
    end
    if kind ~= "table" then return tostring(value) end
    local result = {}
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            result[tostring(key)] = safeValue(item, depth + 1)
        end
    end
    return result
end

local function serialize(instance, depth)
    if depth > 20 then return nil end
    local node = { properties = {}, children = {} }
    for _, property in ipairs(PROPERTY_ALLOWLIST) do
        local value = instance[property]
        if value ~= nil then node.properties[property] = safeValue(value) end
    end
    for _, child in ipairs(instance:GetChildren()) do
        local childNode = serialize(child, depth + 1)
        if childNode then table.insert(node.children, childNode) end
    end
    return node
end

function GuiBridge.Snapshot(root)
    assert(type(root) == "table" and root._isInstance, "Snapshot expects an Instance")
    return serialize(root, 0)
end

function GuiBridge.Export(root, outputPath)
    assert(type(outputPath) == "string" and outputPath ~= "", "Export expects an output path")
    local file, openError = io.open(outputPath, "w")
    if not file then error("Unable to open GUI snapshot: " .. tostring(openError)) end
    local success, encoded = pcall(JSON.encode, GuiBridge.Snapshot(root))
    if not success then file:close(); error(encoded) end
    file:write(encoded)
    file:close()
    return true
end

return GuiBridge
