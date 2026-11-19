local JSON = require("./json")

local GuiBridge = {}
local lastRoot = nil
local instancesById = {}

local PROPERTY_ALLOWLIST = {
    "Name", "ClassName", "Text", "PlaceholderText", "Visible",
    "Enabled", "DisplayOrder", "BackgroundColor3", "BackgroundTransparency",
    "TextColor3", "TextSize", "TextXAlignment", "TextYAlignment",
    "Font", "Size", "Position", "AnchorPoint", "ZIndex",
    "BorderSizePixel", "CanvasSize", "ScrollingDirection",
    "AutomaticCanvasSize", "LayoutOrder", "Rotation",
    "Image", "ImageColor3", "ImageTransparency", "ScaleType", "AutoButtonColor",
    "CornerRadius", "Color", "Thickness", "Transparency", "ApplyStrokeMode",
    "Scale", "FillDirection", "HorizontalAlignment", "VerticalAlignment",
    "SortOrder", "Padding", "CellSize", "CellPadding", "StartCorner",
    "ScrollBarThickness", "Offset",
}

local function safeValue(value, depth)
    depth = depth or 0
    if depth > 5 then return tostring(value) end

    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
        return value
    end
    if kind ~= "table" then return tostring(value) end

    -- Preserve contiguous numeric tables as JSON arrays. GUI geometry
    -- (UDim2-like {scale, offset, scale, offset}) depends on array decoding.
    local count = 0
    local maximum = 0
    local isArray = true
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            isArray = false
            break
        end
        count = count + 1
        if key > maximum then maximum = key end
    end
    isArray = isArray and count > 0 and count == maximum

    local result = {}
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            local safeKey = isArray and key or tostring(key)
            result[safeKey] = safeValue(item, depth + 1)
        end
    end
    return result
end

local function serialize(instance, depth, id)
    if depth > 20 then return nil end
    instancesById[id] = instance

    local node = { id = id, properties = {}, children = {} }
    for _, property in ipairs(PROPERTY_ALLOWLIST) do
        local value = instance[property]
        if value ~= nil then node.properties[property] = safeValue(value) end
    end

    for index, child in ipairs(instance:GetChildren()) do
        local childNode = serialize(child, depth + 1, id .. "/" .. tostring(index))
        if childNode then table.insert(node.children, childNode) end
    end
    return node
end

local function encodeSnapshot(root)
    instancesById = {}
    local snapshot = serialize(root, 0, "0")
    local success, encoded = pcall(JSON.encode, snapshot)
    if not success then error(encoded) end
    return encoded
end

function GuiBridge.Snapshot(root)
    assert(type(root) == "table" and root._isInstance, "Snapshot expects an Instance")
    lastRoot = root
    return encodeSnapshot(root)
end

-- Luau CLI may run without the IO library. Snapshots are returned over stdout.
function GuiBridge.Export(root)
    return GuiBridge.Snapshot(root)
end

-- GUI events are replayed in a fresh Luau process by the Python host.
-- The script is evaluated again, then this method fires the matching signal.
function GuiBridge.Dispatch(id, eventName, value)
    assert(type(id) == "string", "Dispatch expects an instance id")
    assert(type(eventName) == "string", "Dispatch expects an event name")
    assert(lastRoot ~= nil, "Export the GUI before dispatching events")

    local instance = instancesById[id]
    if not instance then error("GUI instance not found: " .. id) end

    if eventName == "click" then
        if instance.ClassName ~= "TextButton" and instance.ClassName ~= "ImageButton" then
            error("Click events require a TextButton or ImageButton")
        end
        instance.MouseButton1Click:Fire()
        instance.Activated:Fire()
    elseif eventName == "text" then
        if instance.ClassName ~= "TextBox" then
            error("Text events require a TextBox")
        end
        instance.Text = tostring(value or "")
        instance.FocusLost:Fire(true)
    else
        error("Unsupported GUI event: " .. eventName)
    end

    -- Surface callback errors that Signal isolates internally.
    local signals = instance._guiSignals or {}
    for _, signal in pairs(signals) do
        for _, connection in ipairs(signal._connections or {}) do
            if connection._lastError then
                warn("[FMO GUI] Callback error: " .. tostring(connection._lastError))
                connection._lastError = nil
            end
        end
    end

    return encodeSnapshot(lastRoot)
end

return GuiBridge
