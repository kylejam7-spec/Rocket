-- Every world sign tagged WorldSign (SignService), drawn per player in the gym signs'
-- style: a dark rounded panel with a thick accent border and a soft sheen, an optional
-- round accent badge with an icon (or a product picture) that gently pulses and sways,
-- a big outlined title and a subtitle in the accent colour. Sized from the sign's face, so one style fits a
-- door plate and a 30-stud arch.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local Icon = require(UI.Icon)
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
    local inner = height - 2 * inset
    local left = inner * 0.18
    local icon = part:GetAttribute("Icon")
    if icon and icon ~= "" then
        local size = inner * 0.78
        local circle = Create.new("Frame", {
            Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, inner * 0.12 + size / 2, 0.5, 0),
            Size = UDim2.fromOffset(size, size), BackgroundColor3 = accent, Parent = panel,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = circle })
        Create.new("UIStroke", { Thickness = math.max(2, size * 0.05), Color = Theme.color.Stroke, Parent = circle })
        local glyph = Create.new("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72),
            BackgroundTransparency = 1, Text = icon, TextScaled = true, Font = Theme.font.Display, Rotation = -8, Parent = circle,
        })
        local scale = Create.new("UIScale", { Parent = circle })
        TweenService:Create(scale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()
        TweenService:Create(glyph, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
        -- A product picture (the Image attribute) fills the badge over the glyph; if it
        -- fails to load, UI.Icon removes it and the glyph shows.
        local imageKey = part:GetAttribute("Image")
        if Icon.image(imageKey) then
            local picture = Icon.new(imageKey, nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = circle })
            picture:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
        end
        left = inner * 0.24 + size
    end
    local subtitle = part:GetAttribute("Subtitle")
    local hasSubtitle = subtitle ~= nil and subtitle ~= ""
    StrokedText.new({
        Name = "Title", Position = UDim2.new(0, left, hasSubtitle and 0.08 or 0.14, 0), Size = UDim2.new(1, -left - inner * 0.18, hasSubtitle and 0.56 or 0.72, 0),
        Text = part:GetAttribute("Title") or "", Font = Theme.font.Display, TextScaled = true,
        TextXAlignment = icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, stroke = math.max(2, inner * 0.045), Parent = panel,
    })
    if hasSubtitle then
        StrokedText.new({
            Name = "Subtitle", Position = UDim2.new(0, left, 0.64, 0), Size = UDim2.new(1, -left - inner * 0.18, 0.26, 0),
            Text = subtitle, Font = Theme.font.Display, TextScaled = true, TextColor3 = accent,
            TextXAlignment = icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, stroke = math.max(1.5, inner * 0.03), Parent = panel,
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
        -- A sign whose part is Hidden (the boarding station until boarding) isn't drawn.
        local function hide()
            if drawn[part] then drawn[part].Enabled = not part:GetAttribute("Hidden") end
        end
        hide()
        part:GetAttributeChangedSignal("Hidden"):Connect(hide)
        part.Destroying:Connect(function()
            if drawn[part] then drawn[part]:Destroy() end
            drawn[part] = nil
        end)
        -- Live signs (the boarding station's status) redraw when their words change.
        for _, name in { "Title", "Subtitle", "Icon", "Image", "Accent" } do
            part:GetAttributeChangedSignal(name):Connect(function()
                if not drawn[part] then return end
                drawn[part]:Destroy()
                drawn[part] = build(part, playerGui)
                hide()
            end)
        end
    end
    for _, part in CollectionService:GetTagged("WorldSign") do add(part) end
    CollectionService:GetInstanceAddedSignal("WorldSign"):Connect(add)
end

return WorldSignController
