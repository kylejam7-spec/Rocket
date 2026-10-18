-- The owner's card when a UFO lands their pet (PetController calls show at the pop):
-- the pet live in 3D doing its celebration, its name, a star rarity pill and where it
-- went (following you, or into the backpack). Rarer cards hold longer; Epic and
-- Legendary ones have turning light rays behind them, and Legendary names shimmer
-- gold. Pops in with a bounce, then floats up and fades; a click dismisses it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Pets = require(ReplicatedStorage.Shared.Pets)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local PetAnimator = require(ReplicatedStorage.Shared.PetAnimator)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local PetRevealCard = {}

local WIDTH, HEIGHT = 460, 170
local CELEBRATE = { "Dance", "Wave", "Yes", "Headbutt" }
local current

local function tween(item, seconds, goals, style, direction)
    local playing = TweenService:Create(item, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
    playing:Play()
    return playing
end

-- Turning light rays: `count` rays from the centre, as bars through it (a GUI object
-- turns about its own middle) that fade toward both tips.
local function rays(parent, color, count)
    local holder = Create.new("Frame", { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(620, 620), BackgroundTransparency = 1, ZIndex = 0, Parent = parent })
    for index = 1, count // 2 do
        local bar = Create.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(26, 620), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = index / (count // 2) * 180,
            ZIndex = 0, Parent = holder })
        Create.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) }), Parent = bar })
    end
    TweenService:Create(holder, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
    return holder
end

function PetRevealCard.show(id, owner)
    local spec = Pets.get(id)
    if not spec then return end
    local player = Players.LocalPlayer
    if current then current() end
    local gui = Create.screen("RocketPetReveal")
    gui.DisplayOrder = 20
    local color = Theme.rarity[spec.Rarity]
    local root = Create.new("Frame", { Name = "PetReveal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32),
        Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundTransparency = 1, Parent = gui })
    local scale = Create.new("UIScale", { Scale = 0.4, Parent = root })
    if spec.Rank >= 4 then rays(root, color, spec.Rank == 5 and 16 or 10) end
    local card = Create.new("CanvasGroup", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.color.Panel,
        BackgroundTransparency = 0.04, GroupTransparency = 1, ZIndex = 2, Parent = root })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = card })
    local rim = Create.new("UIStroke", { Thickness = 4, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = root })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = root })
    -- A rarity-tinted wash behind the contents (a gradient on the CanvasGroup itself
    -- would tint everything in it).
    local wash = Create.new("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 0, Parent = card })
    Create.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.lighten(Theme.color.Panel, 0.12):Lerp(color, 0.3), Theme.color.Panel), Parent = wash })

    -- The pet, live: celebrating, turning slowly.
    local viewport = Create.new("ViewportFrame", { Name = "Pet", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(150, 150),
        BackgroundTransparency = 1, Ambient = Color3.fromRGB(180, 180, 200), LightDirection = Vector3.new(-0.4, -1, -0.7), Parent = card })
    local world = Create.new("WorldModel", { Parent = viewport })
    local model = PetModels.pet(id)
    model.Parent = world
    local animator = PetAnimator.new(model, spec.Form)
    if animator then
        for _, move in CELEBRATE do if animator:play(move) then break end end
    end
    local box, size = PetModels.bounds(model)
    local reach = spec.Form == "Large" and size.Y * 1.1 or math.max(size.X, size.Y, size.Z)
    local camera = Create.new("Camera", { FieldOfView = 30, Parent = viewport })
    camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, reach * 0.25, reach * 2.5), box.Position)
    viewport.CurrentCamera = camera

    StrokedText.new({ Name = "Kicker", Position = UDim2.fromOffset(172, 14), Size = UDim2.fromOffset(270, 22),
        Text = spec.Rank == 5 and "LEGENDARY DELIVERY!" or "NEW PET!", Font = Theme.font.Display, TextSize = 19,
        TextColor3 = Theme.color.Gold, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = card })
    local name = StrokedText.new({ Name = "PetName", Position = UDim2.fromOffset(172, 38), Size = UDim2.fromOffset(276, 46),
        Text = spec.Name, Font = Theme.font.Display, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = spec.Rank == 5 and Color3.fromRGB(255, 225, 120) or Theme.color.White, stroke = 3, Parent = card })
    if spec.Rank == 5 then
        local shimmer = Create.new("UIGradient", { Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 50)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 50)) }), Offset = Vector2.new(-1, 0), Parent = name })
        TweenService:Create(shimmer, TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()
    end
    local pill = Create.new("Frame", { Name = "Rarity", Position = UDim2.fromOffset(172, 92), Size = UDim2.fromOffset(170, 30),
        BackgroundColor3 = color, Parent = card })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
    Theme.shine(pill)
    StrokedText.new({ Size = UDim2.fromScale(1, 1), Text = string.rep("★", spec.Rank) .. " " .. spec.Rarity:upper(),
        Font = Theme.font.Display, TextSize = 18, stroke = 2, Parent = pill })
    local following = false
    for _, other in ((owner or player):GetAttribute("Pets") or ""):split(",") do
        if other == id then following = true end
    end
    StrokedText.new({ Name = "Where", Position = UDim2.fromOffset(172, 130), Size = UDim2.fromOffset(276, 22),
        Text = spec.Form:upper() .. "  ·  " .. (following and "now following you!" or "sent to your " .. Theme.icon.Backpack .. " backpack"),
        Font = Theme.font.Display, TextSize = 17, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        stroke = 1.5, Parent = card })

    local closing = false
    local spin = 0
    local connection = RunService.RenderStepped:Connect(function(dt)
        spin += dt * 0.6
        model:PivotTo(CFrame.Angles(0, math.rad(200) + math.sin(spin) * 0.6, 0))
        if animator then animator:step(dt, 0) end
    end)
    local function close()
        if closing then return end
        closing = true
        if current == close then current = nil end
        tween(card, 0.35, { GroupTransparency = 1 })
        tween(rim, 0.35, { Transparency = 1 })
        tween(root, 0.35, { Position = UDim2.fromScale(0.5, 0.25) })
        local rayHolder = root:FindFirstChild("Rays")
        if rayHolder then
            for _, bar in rayHolder:GetChildren() do tween(bar, 0.3, { BackgroundTransparency = 1 }) end
        end
        task.delay(0.4, function()
            connection:Disconnect()
            root:Destroy()
        end)
    end
    current = close
    Create.new("TextButton", { Name = "Dismiss", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5,
        Parent = root }).Activated:Connect(close)
    -- Pop in.
    tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
    tween(card, 0.2, { GroupTransparency = 0 })
    task.delay(3.2 + spec.Rank * 0.5, close)
end

return PetRevealCard
