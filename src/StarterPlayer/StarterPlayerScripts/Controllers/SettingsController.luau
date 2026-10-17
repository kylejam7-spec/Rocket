-- The round ⚙ button (top right) and the SETTINGS panel: Music and SFX volume
-- sliders and a Reduced effects switch, all writing to Controllers/Settings.
local Settings = require(script.Parent.Settings)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local StrokedText = require(UI.StrokedText)
local Slider = require(UI.Slider)
local Toggle = require(UI.Toggle)
local Tween = require(UI.Tween)
local Actions = require(script.Parent.ActionController)
local SettingsController = {}

local function rowLabel(text, y, parent)
    return StrokedText.new({
        Text = text, Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(150, 34),
        Font = Theme.font.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
        stroke = 2, Parent = parent,
    })
end

function SettingsController.start()
    local gui = Create.screen("RocketSettings")
    gui.DisplayOrder = 10
    local panel = Panel.new({
        Name = "SettingsPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(420, 236), BackgroundTransparency = 0.05, radius = 18,
        stroke = 4, strokeColor = Theme.color.Gold, Visible = false, Parent = gui,
    })
    StrokedText.new({
        Text = "SETTINGS", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(300, 40), Font = Theme.font.Display, TextSize = 36, stroke = 3, Parent = panel,
    })
    local function close()
        panel.Visible = false
    end
    Button.new({
        Name = "Close", shape = "circle", icon = Theme.icon.Leave, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 46),
        onActivated = close, Parent = panel,
    })
    rowLabel("🎵 Music", 74, panel)
    local music = Slider.new({
        Name = "Music", Position = UDim2.fromOffset(190, 80), Size = UDim2.fromOffset(200, 22), color = Theme.color.Launch,
        value = Settings.get("music"), onChanged = function(value) Settings.set("music", value) end, Parent = panel,
    })
    rowLabel("🔊 Sounds", 128, panel)
    local sfx = Slider.new({
        Name = "SFX", Position = UDim2.fromOffset(190, 134), Size = UDim2.fromOffset(200, 22), color = Theme.color.Speed,
        value = Settings.get("sfx"), onChanged = function(value) Settings.set("sfx", value) end, Parent = panel,
    })
    rowLabel("✨ Reduced effects", 182, panel).Size = UDim2.fromOffset(240, 34)
    local reduced = Toggle.new({
        Name = "ReducedEffects", Position = UDim2.fromOffset(318, 182), value = Settings.get("reducedEffects"),
        onChanged = function(value) Settings.set("reducedEffects", value) end, Parent = panel,
    })
    Settings.subscribe(function(values)
        music:set(values.music)
        sfx:set(values.sfx)
        if reduced.value ~= values.reducedEffects then reduced:set(values.reducedEffects) end
    end)

    local button = Button.new({
        -- Gold: the grey ⚙️ emoji disappears on the purple used elsewhere.
        Name = "SettingsButton", shape = "circle", icon = Theme.icon.Settings, color = Theme.color.Gold,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -Theme.gutter, 0, Theme.gutter),
        -- Phones scale the HUD to ~0.46: 78 keeps it a ~36 px thumb target there.
        Size = Actions.touch and UDim2.fromOffset(78, 78) or UDim2.fromOffset(56, 56),
        onActivated = function()
            panel.Visible = not panel.Visible
            if panel.Visible then Tween.bounce(panel, 1.12, 0.3) end
        end,
        Parent = gui,
    })
    -- Phones: up in the free right side of the Roblox top bar row.
    if Actions.touch then Create.inTopBar(button, gui) end
end

return SettingsController
