-- FMO GUI Simulator 2.0 showcase.
-- Local Luau compatibility simulation; not a Roblox client or executor.

local Game = require("../simulator/game")
local GuiBridge = require("../simulator/gui_bridge")
local Instance = Game.Instance

local function create(className, parent, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local screen = Instance.new("ScreenGui")
screen.Name = "FMO GUI Simulator 2.0"

local panel = create("Frame", screen, {
    Name = "MainPanel",
    Size = {0, 820, 0, 560},
    Position = {0, 30, 0, 24},
    BackgroundColor3 = {29, 34, 48},
    BackgroundTransparency = 0,
})
create("UICorner", panel, {CornerRadius = {0, 14}})
create("UIStroke", panel, {
    Color = {100, 125, 185},
    Thickness = 2,
    Transparency = 0.15,
})
create("UIGradient", panel, {
    Color = {{34, 42, 62}, {23, 27, 39}},
    Rotation = 90,
})

local title = create("TextLabel", panel, {
    Name = "Title",
    Text = "FMO  /  SCRIPT GUI SIMULATOR 2.0",
    TextSize = 22,
    Font = "GothamBold",
    TextColor3 = {245, 247, 255},
    Size = {0, 480, 0, 42},
    Position = {0, 26, 0, 22},
})

local description = create("TextLabel", panel, {
    Name = "StatusLabel",
    Text = "Image widgets, layouts, modifiers and interactive Luau callbacks.",
    TextSize = 14,
    TextColor3 = {190, 201, 222},
    TextXAlignment = "Left",
    Size = {0, 480, 0, 48},
    Position = {0, 26, 0, 70},
})

local action = create("TextButton", panel, {
    Name = "ActionButton",
    Text = "RUN LUAU CALLBACK",
    TextSize = 14,
    Font = "GothamBold",
    BackgroundColor3 = {68, 105, 190},
    TextColor3 = {255, 255, 255},
    Size = {0, 220, 0, 44},
    Position = {0, 26, 0, 132},
})
create("UICorner", action, {CornerRadius = {0, 8}})
create("UIStroke", action, {Color = {130, 160, 240}, Thickness = 1})

action.MouseButton1Click:Connect(function()
    description.Text = "The TextButton callback ran inside Luau."
    action.Text = "CALLBACK EXECUTED"
    print("[FMO GUI] TextButton callback executed.")
end)

local input = create("TextBox", panel, {
    Name = "MessageInput",
    PlaceholderText = "Type a message and press Enter...",
    Text = "",
    TextSize = 14,
    BackgroundColor3 = {43, 50, 68},
    TextColor3 = {245, 247, 255},
    Size = {0, 340, 0, 40},
    Position = {0, 26, 0, 190},
})
create("UICorner", input, {CornerRadius = {0, 7}})

input.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        description.Text = "TextBox received: " .. input.Text
        print("[FMO GUI] TextBox received: " .. input.Text)
    end
end)

local imageTitle = create("TextLabel", panel, {
    Text = "IMAGE WIDGETS",
    TextSize = 12,
    Font = "GothamBold",
    TextColor3 = {155, 174, 210},
    Size = {0, 220, 0, 24},
    Position = {0, 26, 0, 258},
})

create("ImageLabel", panel, {
    Name = "ImagePreview",
    Image = "",
    ScaleType = "Fit",
    BackgroundColor3 = {39, 47, 64},
    BackgroundTransparency = 0,
    Size = {0, 100, 0, 78},
    Position = {0, 26, 0, 290},
})
local imageButton = create("ImageButton", panel, {
    Name = "ImageAction",
    Image = "",
    BackgroundColor3 = {55, 78, 125},
    Size = {0, 100, 0, 78},
    Position = {0, 142, 0, 290},
})
create("UICorner", imageButton, {CornerRadius = {0, 8}})
imageButton.Activated:Connect(function()
    description.Text = "ImageButton activation was bridged to Luau."
    print("[FMO GUI] ImageButton Activated.")
end)

local card = create("Frame", panel, {
    Name = "LayoutShowcase",
    Size = {0, 250, 0, 360},
    Position = {0, 535, 0, 22},
    BackgroundColor3 = {37, 44, 61},
})
create("UICorner", card, {CornerRadius = {0, 12}})
create("UIStroke", card, {Color = {83, 101, 143}, Thickness = 1})

create("TextLabel", card, {
    Text = "AUTOMATIC LAYOUT",
    TextSize = 13,
    Font = "GothamBold",
    TextColor3 = {225, 231, 245},
    Size = {0, 220, 0, 30},
    Position = {0, 15, 0, 12},
})

local list = Instance.new("UIListLayout")
list.FillDirection = "Vertical"
list.SortOrder = "LayoutOrder"
list.Padding = {0, 10}
list.Parent = card

for index = 1, 3 do
    local item = create("TextButton", card, {
        Name = "LayoutButton" .. tostring(index),
        Text = "LAYOUT ITEM 0" .. tostring(index),
        TextSize = 12,
        LayoutOrder = index,
        BackgroundColor3 = {57 + index * 8, 76 + index * 5, 116 + index * 8},
        TextColor3 = {255, 255, 255},
        Size = {0, 210, 0, 48},
        Position = {0, 15, 0, 55 + (index - 1) * 58},
    })
    create("UICorner", item, {CornerRadius = {0, 7}})
    item.Activated:Connect(function()
        description.Text = "Layout item " .. tostring(index) .. " clicked."
        print("[FMO GUI] Layout item " .. tostring(index) .. " clicked.")
    end)
end

local gridCard = create("Frame", panel, {
    Name = "GridShowcase",
    Size = {0, 250, 0, 145},
    Position = {0, 270, 0, 340},
    BackgroundColor3 = {36, 43, 59},
})
create("UICorner", gridCard, {CornerRadius = {0, 10}})
local grid = Instance.new("UIGridLayout")
grid.CellSize = {0, 100, 0, 42}
grid.CellPadding = {0, 8, 0, 8}
grid.SortOrder = "LayoutOrder"
grid.Parent = gridCard

for index = 1, 4 do
    create("TextButton", gridCard, {
        Name = "GridItem" .. tostring(index),
        Text = "GRID " .. tostring(index),
        TextSize = 11,
        LayoutOrder = index,
        BackgroundColor3 = {68, 83, 117},
        TextColor3 = {255, 255, 255},
        Size = {0, 100, 0, 42},
        Position = {0, 12, 0, 40},
    })
end

local scroll = create("ScrollingFrame", panel, {
    Name = "ScrollShowcase",
    Size = {0, 250, 0, 135},
    Position = {0, 270, 0, 190},
    CanvasSize = {0, 250, 0, 310},
    ScrollingDirection = "Y",
    BackgroundColor3 = {35, 42, 58},
})
create("UICorner", scroll, {CornerRadius = {0, 9}})
for index = 1, 6 do
    create("TextLabel", scroll, {
        Text = "Scrollable content row " .. tostring(index),
        TextSize = 12,
        TextColor3 = {220, 228, 244},
        Size = {0, 220, 0, 34},
        Position = {0, 12, 0, 8 + (index - 1) * 48},
    })
end

print("__FMO_GUI_SNAPSHOT__" .. GuiBridge.Export(screen))
print("[FMO GUI] Simulator 2.0 showcase exported.")
