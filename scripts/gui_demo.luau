-- FMO Script GUI Simulator demo.
-- This script runs locally in Luau Runtime; it does not connect to Roblox.

local Game = require("../simulator/game")
local GuiBridge = require("../simulator/gui_bridge")
local Instance = Game.Instance

local screen = Instance.new("ScreenGui")
screen.Name = "FMO Demo Panel"

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = {0, 420, 0, 280}
panel.Position = {0, 24, 0, 24}
panel.BackgroundColor3 = {30, 35, 48}
panel.Parent = screen

local title = Instance.new("TextLabel")
title.Text = "FMO  /  SCRIPT GUI SIMULATOR"
title.TextSize = 18
title.Size = {0, 370, 0, 38}
title.Position = {0, 22, 0, 18}
title.Parent = panel

local description = Instance.new("TextLabel")
description.Text = "Tu interfaz Luau se representa en una ventana de escritorio."
description.TextSize = 13
description.Size = {0, 370, 0, 42}
description.Position = {0, 22, 0, 62}
description.Parent = panel

local action = Instance.new("TextButton")
action.Text = "BOTÓN DE EJEMPLO"
action.Size = {0, 220, 0, 42}
action.Position = {0, 22, 0, 122}
action.Parent = panel

local input = Instance.new("TextBox")
input.PlaceholderText = "Escribe algo..."
input.Size = {0, 220, 0, 38}
input.Position = {0, 22, 0, 180}
input.Parent = panel

local outputPath = os.getenv("FMO_GUI_OUTPUT")
assert(outputPath, "FMO_GUI_OUTPUT was not provided by the desktop launcher")
GuiBridge.Export(screen, outputPath)
print("[FMO GUI] Interfaz exportada correctamente.")
