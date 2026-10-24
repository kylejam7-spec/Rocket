-- Buying a suit or gym access (a Gym District tier or the SpaceX Gym) celebrates, for the
-- buyer only: a volley of small fireworks bursts round their character (each shot climbs
-- on a sparkling trail, pops into a ring of coloured sparks and crackles), a fanfare plays
-- and an "UNLOCKED!" banner with the item's picture drops in at the top of the screen.
-- Driven by the server's PassBought (ShopService, when a purchase finishes), so a purchase
-- made anywhere (the SHOP, a walk-in offer, a suit stand) celebrates once, and passes
-- loading on join don't. Reduced effects fires fewer shots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Sfx = require(UI.Sfx)
local StrokedText = require(UI.StrokedText)
local Icon = require(UI.Icon)
local PurchaseCelebrationController = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SHOTS, SHOTS_REDUCED = 7, 3
local PALETTES = {
    { Color3.fromRGB(255, 214, 70), Color3.fromRGB(255, 140, 40) },
    { Color3.fromRGB(90, 200, 255), Color3.fromRGB(150, 90, 255) },
    { Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 220, 120) },
    { Color3.fromRGB(110, 255, 140), Color3.fromRGB(60, 200, 255) },
}

-- What a newly owned key is, for the banner: { title, emoji, accent } or nil to skip it.
local function describe(key)
    local skin = Skins.get(key)
    if skin and key ~= "Astronaut" then
        return { title = skin.name:upper(), emoji = skin.icon, accent = Skins.accent(skin), kind = "SUIT UNLOCKED!" }
    end
    if key == Config.SpaceXGym.key then
        return { title = Config.SpaceXGym.title, emoji = Theme.icon.Launch, accent = Color3.fromRGB(70, 160, 255), kind = "EXCLUSIVE GYM UNLOCKED!" }
    end
    local tier = tonumber(key:match("^Gym(%d+)$"))
    local spec = tier and Config.TrainingTiers[tier]
    if spec then
        return { title = spec.multiplier .. "X GYM", emoji = "🏋", accent = Theme.color.Strength, kind = "GYM UNLOCKED!" }
    end
    return nil
end

-- One firework: a spark climbs from near `origin` on a trail, then bursts.
local function shot(origin, palette, delay)
    task.delay(delay, function()
        local start = origin + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
        local peak = start + Vector3.new(math.random(-3, 3), math.random(9, 15), math.random(-3, 3))
        local rocket = Instance.new("Part")
        rocket.Name = "Firework"
        rocket.Anchored, rocket.CanCollide, rocket.CanQuery, rocket.CanTouch, rocket.CastShadow = true, false, false, false, false
        rocket.Shape = Enum.PartType.Ball
        rocket.Size = Vector3.one * 0.5
        rocket.Material = Enum.Material.Neon
        rocket.Color = palette[1]
        rocket.CFrame = CFrame.new(start)
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Position, a1.Position = Vector3.new(0, 0.2, 0), Vector3.new(0, -0.2, 0)
        a0.Parent, a1.Parent = rocket, rocket
        local trail = Instance.new("Trail")
        trail.Attachment0, trail.Attachment1 = a0, a1
        trail.Lifetime = 0.35
        trail.LightEmission = 1
        trail.Color = ColorSequence.new(palette[1], palette[2])
        trail.Transparency = NumberSequence.new(0, 1)
        trail.WidthScale = NumberSequence.new(1, 0)
        trail.Parent = rocket
        local burst = Instance.new("ParticleEmitter")
        burst.Texture = SPARK
        burst.Enabled = false
        burst.Color = ColorSequence.new(palette[1], palette[2])
        burst.LightEmission = 1
        burst.LightInfluence = 0
        burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
        burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
        burst.Lifetime = NumberRange.new(0.7, 1.2)
        burst.Speed = NumberRange.new(14, 22)
        burst.SpreadAngle = Vector2.new(180, 180)
        burst.Drag = 3
        burst.Acceleration = Vector3.new(0, -12, 0)
        burst.Rotation = NumberRange.new(0, 360)
        burst.RotSpeed = NumberRange.new(-200, 200)
        burst.Parent = rocket
        local glints = burst:Clone()
        glints.Color = ColorSequence.new(Color3.new(1, 1, 1))
        glints.Size = NumberSequence.new(0.35)
        glints.Speed = NumberRange.new(6, 12)
        glints.Lifetime = NumberRange.new(0.9, 1.6)
        glints.Parent = rocket
        local flash = Instance.new("PointLight")
        flash.Color, flash.Range, flash.Brightness, flash.Enabled = palette[1], 18, 0, true
        flash.Parent = rocket
        rocket.Parent = workspace
        local rise = TweenService:Create(rocket, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) })
        rise:Play()
        Sfx.play("tick", { pitch = 1.6 + math.random() * 0.3, volume = 0.6 })
        rise.Completed:Wait()
        rocket.Transparency = 1
        burst:Emit(45)
        glints:Emit(20)
        flash.Brightness = 4
        TweenService:Create(flash, TweenInfo.new(0.6), { Brightness = 0 }):Play()
        Sfx.play("pop", { pitch = 0.7 + math.random() * 0.5, volume = 1.4 })
        task.delay(0.15, function() Sfx.play("coin", { pitch = 1.3 + math.random() * 0.4, volume = 2 }) end)
        task.delay(2, function() rocket:Destroy() end)
    end)
end

function PurchaseCelebrationController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("PurchaseCelebration")
    gui.DisplayOrder = 14
    -- The banner: drops in from the top, holds, then slides back up.
    local banner = Create.new("Frame", {
        Name = "Banner", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -10), Size = UDim2.fromOffset(440, 96),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.05, Visible = false, Parent = gui,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 20), Parent = banner })
    local rim = Create.new("UIStroke", { Thickness = 4, Color = Theme.color.Gold, Parent = banner })
    local picture = Create.new("Frame", { Name = "Picture", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(80, 80),
        BackgroundTransparency = 1, Parent = banner })
    local kind = StrokedText.new({ Name = "Kind", Position = UDim2.fromOffset(104, 10), Size = UDim2.new(1, -116, 0, 30),
        Font = Theme.font.Display, TextScaled = true, TextColor3 = Theme.color.Gold, TextXAlignment = Enum.TextXAlignment.Left,
        stroke = 2.5, Parent = banner })
    local title = StrokedText.new({ Name = "Title", Position = UDim2.fromOffset(104, 44), Size = UDim2.new(1, -116, 0, 40),
        Font = Theme.font.Display, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3, Parent = banner })
    local shine = Create.new("UIGradient", { Rotation = 20, Parent = kind,
        Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 60)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 60)) }) })
    local showing = 0

    local function celebrate(info, key)
        -- Fireworks round the character.
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            local count = Settings.get("reducedEffects") and SHOTS_REDUCED or SHOTS
            for index = 1, count do
                shot(root.Position + Vector3.new(0, 2, 0), PALETTES[(index - 1) % #PALETTES + 1], (index - 1) * 0.22 + math.random() * 0.08)
            end
        end
        Sfx.play("fanfare5")
        task.delay(0.35, function() Sfx.play("jingle") end)
        -- The banner.
        showing += 1
        local mine = showing
        for _, child in picture:GetChildren() do child:Destroy() end
        Icon.new(key, info.emoji, { Size = UDim2.fromScale(1, 1), TextSize = 56, Parent = picture })
        kind.Text, title.Text = info.kind, info.title
        rim.Color = info.accent
        banner.Visible = true
        banner.Position = UDim2.new(0.5, 0, 0, -10)
        TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 120) }):Play()
        shine.Offset = Vector2.new(-1, 0)
        TweenService:Create(shine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2), { Offset = Vector2.new(1, 0) }):Play()
        task.delay(3.6, function()
            if showing ~= mine then return end
            local away = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -10) })
            away:Play()
            away.Completed:Wait()
            if showing == mine then banner.Visible = false end
        end)
    end

    State.remote("PassBought").OnClientEvent:Connect(function(key)
        local info = type(key) == "string" and describe(key)
        if info then celebrate(info, key) end
    end)
end

return PurchaseCelebrationController
