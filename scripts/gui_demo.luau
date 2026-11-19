-- FMO Script GUI Simulator interactive demo.
-- This is a local Luau simulation, not a Roblox client.

local Game = require("../simulator/game")
local GuiBridge = require("../simulator/gui_bridge")
local Instance = Game.Instance

local screen = Instance.new("ScreenGui")
screen.Name = "FMO Demo Panel"

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = {0, 460, 0, 330}
panel.Position = {0, 24, 0, 24}
panel.BackgroundColor3 = {30, 35, 48}
panel.Parent = screen

local title = Instance.new("TextLabel")
title.Text = "FMO  /  SCRIPT GUI SIMULATOR"
title.TextSize = 18
title.Size = {0, 410, 0, 38}
title.Position = {0, 22, 0, 18}
title.Parent = panel

local description = Instance.new("TextLabel")
description.Name = "StatusLabel"
description.Text = "La interfaz fue construida desde Luau."
description.TextSize = 13
description.Size = {0, 410, 0, 42}
description.Position = {0, 22, 0, 62}
description.Parent = panel

local action = Instance.new("TextButton")
action.Name = "ActionButton"
action.Text = "PROBAR EVENTO CLICK"
action.Size = {0, 220, 0, 42}
action.Position = {0, 22, 0, 122}
action.Parent = panel

action.MouseButton1Click:Connect(function()
    description.Text = "¡El callback Luau del botón se ejecutó correctamente!"
    action.Text = "EVENTO EJECUTADO"
    print("[FMO GUI] MouseButton1Click ejecutado.")
end)

local input = Instance.new("TextBox")
input.Name = "MessageInput"
input.PlaceholderText = "Escribe algo y pulsa Enter..."
input.Size = {0, 300, 0, 38}
input.Position = {0, 22, 0, 180}
input.Parent = panel

input.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        description.Text = "Texto recibido: " .. input.Text
        print("[FMO GUI] TextBox recibió: " .. input.Text)
    end
end)

print("__FMO_GUI_SNAPSHOT__" .. GuiBridge.Export(screen))
print("[FMO GUI] Interfaz interactiva exportada.")
