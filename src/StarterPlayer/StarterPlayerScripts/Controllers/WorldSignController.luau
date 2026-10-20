-- Every world sign tagged WorldSign (SignService), drawn per player in the gym signs'
-- style: a dark rounded panel with a thick accent border and a soft sheen, an optional
-- round accent badge with an icon that gently pulses and sways, a big outlined title
-- and a subtitle in the accent colour under a thin accent rule. Sized from the sign's
-- face, so one style fits a door plate and a 30-stud arch. Badge and text are measured
-- and centred on the panel as one group, so wide signs don't leave the text hugging
-- the left with empty panel to its right; long text shrinks to fit.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local WorldSignController = {}

local PIXELS_PER_STUD = 40
local SHEEN = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170))

local function faceSize(part, face)
    local size = part.Size
    if face == Enum.NormalId.Front or face == Enum.NormalId.Back then return Vector2.new(size.X, size.Y) end
    if face == Enum.NormalId.Left or face == Enum.NormalId.Right then return Vector2.new(size.Z, size.Y) end
    return Vector2.new(size.X, size.Z)
end

local function build(part, playerGui)
    local face = Enum.NormalId[part:GetAttribute("Face") or "Front"]
    local studs = faceSize(part, face)
    local height = studs.Y * PIXELS_PER_STUD
    local accent = part:GetAttribute("Accent") or Theme.color.Gold
    local surface = Create.new("SurfaceGui", {
        Name = "WorldSign_" .. part.Name, Adornee = part, Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = PIXELS_PER_STUD, LightInfluence = 0, ResetOnSpawn = false, Parent = playerGui,
    })
    local inset = math.max(4, height * 0.05)
    local panel = Create.new("Frame", {
        Name = "Panel", Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
        BackgroundColor3 = Theme.color.Panel, Parent = surface,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, height * 0.18), Parent = panel })
    Create.new("UIStroke", { Thickness = math.max(3, height * 0.06), Color = accent, Parent = panel })
    Create.new("UIGradient", { Color = SHEEN, Rotation = 90, Transparency = NumberSequence.new(0.82, 1), Parent = panel })
    -- An inner hairline a little inside the border.
    local hairline = Create.new("Frame", {
        Name = "Hairline", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -height * 0.14, 1, -height * 0.14), BackgroundTransparency = 1, Parent = panel,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, height * 0.12), Parent = hairline })
    Create.new("UIStroke", { Thickness = math.max(1, height * 0.012), Color = Color3.new(1, 1, 1), Transparency = 0.75, Parent = hairline })

    local inner = height - 2 * inset
    local width = studs.X * PIXELS_PER_STUD - 2 * inset
    local font = Theme.font.Display
    local title = part:GetAttribute("Title") or ""
    local subtitle = part:GetAttribute("Subtitle")
    local hasSubtitle = subtitle ~= nil and subtitle ~= ""
    local icon = part:GetAttribute("Icon")
    local hasIcon = icon ~= nil and icon ~= ""
    local function measure(text, size) return TextService:GetTextSize(text, size, font, Vector2.new(1e5, 1e5)).X end
    -- TextLabels draw at most 100 px text.
    local titleSize = math.min(100, inner * (hasSubtitle and 0.46 or 0.6))
    local subtitleSize = math.min(100, inner * 0.21)
    local textWidth = math.max(measure(title, titleSize), hasSubtitle and measure(subtitle, subtitleSize) or 0)
    local badge = hasIcon and inner * 0.78 or 0
    local gap = hasIcon and inner * 0.16 or 0
    local room = width - inner * 0.3 - badge - gap
    if textWidth > room then
        local shrink = room / textWidth
        titleSize, subtitleSize, textWidth = titleSize * shrink, subtitleSize * shrink, room
    end
    local left = (width - badge - gap - textWidth) / 2
    if hasIcon then
        local circle = Create.new("Frame", {
            Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, left + badge / 2, 0.5, 0),
            Size = UDim2.fromOffset(badge, badge), BackgroundColor3 = accent, Parent = panel,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = circle })
        Create.new("UIStroke", { Thickness = math.max(2, badge * 0.05), Color = Theme.color.Stroke, Parent = circle })
        local glyph = Create.new("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72),
            BackgroundTransparency = 1, Text = icon, TextScaled = true, Font = font, Rotation = -8, Parent = circle,
        })
        local scale = Create.new("UIScale", { Parent = circle })
        TweenService:Create(scale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()
        TweenService:Create(glyph, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
    end
    -- The text block: title over a short accent rule over the subtitle, centred as a
    -- stack on the panel's middle.
    local textLeft = left + badge + gap
    local titleHeight, subtitleHeight, ruleGap = titleSize * 1.05, subtitleSize * 1.1, inner * 0.05
    local stack = titleHeight + (hasSubtitle and ruleGap * 2 + subtitleHeight or 0)
    local top = (inner - stack) / 2
    StrokedText.new({
        Name = "Title", Position = UDim2.fromOffset(textLeft, top), Size = UDim2.fromOffset(textWidth, titleHeight),
        Text = title, Font = font, TextSize = titleSize, stroke = math.max(2, titleSize * 0.09), Parent = panel,
    })
    if hasSubtitle then
        Create.new("Frame", {
            Name = "Rule", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(textLeft + textWidth / 2, top + titleHeight + ruleGap),
            Size = UDim2.fromOffset(textWidth * 0.55, math.max(2, inner * 0.018)), BackgroundColor3 = accent, BackgroundTransparency = 0.3,
            BorderSizePixel = 0, Parent = panel,
        })
        StrokedText.new({
            Name = "Subtitle", Position = UDim2.fromOffset(textLeft, top + titleHeight + ruleGap * 2), Size = UDim2.fromOffset(textWidth, subtitleHeight),
            Text = subtitle, Font = font, TextSize = subtitleSize, TextColor3 = accent, stroke = math.max(1.5, subtitleSize * 0.12), Parent = panel,
        })
    end
    return surface
end

function WorldSignController.start()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local drawn = {}
    local function add(part)
        if drawn[part] or not part:IsA("BasePart") then return end
        drawn[part] = build(part, playerGui)
        part.Destroying:Connect(function()
            if drawn[part] then drawn[part]:Destroy() end
            drawn[part] = nil
        end)
    end
    for _, part in CollectionService:GetTagged("WorldSign") do add(part) end
    CollectionService:GetInstanceAddedSignal("WorldSign"):Connect(add)
end

return WorldSignController
