--[[
    Mars's dust storm: a background event for whoever is at Mars, not a cutscene (the
    camera and controls stay the player's). The server stamps StormAt on the Mars folder
    StormDelay seconds into each stay (LaunchService); from that moment:
      0 s   a towering wall of dust rises beyond the canyon (straight ahead from the
            landing site) and rolls across it toward the base, the sky dimming as it nears,
      16 s  the front sweeps over the base: the air goes thick and brown, the sun fades,
            dust billows and grit streaks past on the wind toward the landing site, and
            gusts buffet the camera,
      36 s  the wind drops and the air clears over 12 s, back to the hazy afternoon.
    The haze and light are Shared.Skies "Mars" mixed toward STORM by the storm's strength,
    worked out from the time each frame (so arriving partway joins it at the right point),
    and set back to Mars's own when it ends. Everything is local to this client and only
    drawn while this player is at Mars; Reduced effects drops the buffeting.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Skies = require(ReplicatedStorage.Shared.Skies)
local Settings = require(script.Parent.Settings)
local DustStormController = {}

local SPEC = Config.Destinations[2]
local NEAR = 1500 -- studs from the platform's centre that count as "there"
-- Timeline, seconds from StormAt.
local ARRIVE = 16 -- the front reaches the base
local THICKEN = 3 -- from the front's arrival to the storm's full strength
local CALM, CLEAR = 36, 48 -- the wind drops, and the air is clear again
-- The wall: from this far out beyond the canyon (-Z, the way the landing site faces),
-- across the whole view (X), moving along WIND at the speed that brings it to the base
-- at ARRIVE; the wind blows the same way.
local WIND = Vector3.new(0, 0, 1)
local FRONT_FROM, FRONT_TO = -1500, 1700
local FRONT_SPEED = -FRONT_FROM / ARRIVE
local FRONT_SPAN, FRONT_STEP = 1300, 100
local DUST = Color3.fromRGB(176, 104, 66)
local DUST_DARK = Color3.fromRGB(132, 72, 46)
-- The wind's dust is lighter than the haze it blows through, or it disappears into it.
local BILLOW = Color3.fromRGB(214, 146, 100)
local SAND = Color3.fromRGB(244, 196, 146)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
-- Full strength: the haze, light and tint the storm mixes Mars's toward.
local STORM = {
    atmosphere = { Density = 0.62, Offset = 0.15, Color = Color3.fromRGB(150, 86, 52), Decay = Color3.fromRGB(116, 60, 38), Glare = 0, Haze = 3 },
    lighting = { Brightness = 1, Ambient = Color3.fromRGB(70, 42, 30), OutdoorAmbient = Color3.fromRGB(118, 70, 48), ColorShift_Top = Color3.fromRGB(180, 110, 72) },
    tint = Color3.fromRGB(255, 208, 170),
}

local player = Players.LocalPlayer

local function smooth(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

-- The storm's strength at `t`: a little as the wall nears, full once it's over the base.
local function strength(t)
    if t < 0 then return 0 end
    if t < ARRIVE then return 0.3 * (t / ARRIVE) ^ 2 end
    if t < CALM then return 0.3 + 0.7 * smooth((t - ARRIVE) / THICKEN) end
    return 1 - smooth((t - CALM) / (CLEAR - CALM))
end

local function mix(a, b, k)
    if typeof(a) == "Color3" then return a:Lerp(b, k) end
    return a + (b - a) * k
end

-- Mars's haze and light mixed toward STORM by `k` (0 puts Mars's own back).
local function weather(k)
    local mars = Skies.Sets.Mars
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        for key, value in STORM.atmosphere do atmosphere[key] = mix(mars.atmosphere[key], value, k) end
    end
    for key, value in STORM.lighting do Lighting[key] = mix(mars.lighting[key], value, k) end
end

local function decor(name, props, parent)
    local part = Instance.new("Part")
    part.Name, part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = name, true, false, false, false, false
    part.Material = Enum.Material.SmoothPlastic
    for key, value in props do part[key] = value end
    part.Parent = parent
    return part
end

-- The dust wall: a ragged bank of billowing balls across the view, half sunk into the
-- ground, roiling smoke off the top. Built over the base, its pivot the base's centre,
-- so it's moved along WIND from there.
local function buildWall(center)
    local random = Random.new(22)
    local model = Instance.new("Model")
    model.Name = "DustStormFront"
    local parts = {}
    local across = WIND:Cross(Vector3.yAxis)
    for along = -FRONT_SPAN, FRONT_SPAN, FRONT_STEP do
        local base = random:NextNumber(220, 320)
        local behind = random:NextNumber(-60, 60)
        local layers = {
            { size = base, y = -40, transparency = 0.12 },
            { size = base * random:NextNumber(0.7, 0.9), y = -40 + base * 0.45, transparency = 0.3 },
            { size = base * random:NextNumber(0.45, 0.6), y = -40 + base * 0.8, transparency = 0.5 },
        }
        for index, layer in layers do
            local ball = decor("Billow", {
                Shape = Enum.PartType.Ball, Size = Vector3.one * layer.size, Transparency = layer.transparency,
                Color = DUST:Lerp(DUST_DARK, random:NextNumber(0, 0.6)),
                CFrame = CFrame.new(center + WIND * (behind + random:NextNumber(-30, 30)) + across * (along + random:NextNumber(-30, 30)) + Vector3.new(0, layer.y, 0)),
            }, model)
            table.insert(parts, { part = ball, transparency = layer.transparency })
            if index == 2 then
                local roil = Instance.new("ParticleEmitter")
                roil.Texture, roil.Color = SMOKE, ColorSequence.new(DUST)
                roil.Size = NumberSequence.new(80, 140)
                roil.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 1) })
                roil.Lifetime, roil.Rate = NumberRange.new(5, 7), 1.5
                roil.Speed, roil.SpreadAngle = NumberRange.new(10, 25), Vector2.new(40, 40)
                roil.EmissionDirection = Enum.NormalId.Top
                roil.Rotation, roil.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-12, 12)
                roil.LightInfluence = 1
                roil.Parent = ball
            end
        end
    end
    model.WorldPivot = CFrame.new(center)
    model.Parent = Workspace
    return model, parts
end

-- The wind round the camera: billows of dust and streaks of grit blowing along WIND
-- (the box's +X, its Right face, points along WIND).
local function buildGust()
    local box = decor("DustStormGust", { Size = Vector3.new(120, 60, 140), Transparency = 1 }, Workspace)
    local billow = Instance.new("ParticleEmitter")
    billow.Texture, billow.Color = SMOKE, ColorSequence.new(BILLOW)
    billow.Size = NumberSequence.new(8, 20)
    billow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(1, 1) })
    billow.Lifetime, billow.Rate = NumberRange.new(3, 4.5), 0
    billow.Speed, billow.SpreadAngle = NumberRange.new(50, 80), Vector2.new(15, 10)
    billow.EmissionDirection = Enum.NormalId.Right
    billow.Rotation, billow.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
    billow.LightInfluence, billow.LightEmission = 0.4, 0.1
    billow.Parent = box
    local grit = Instance.new("ParticleEmitter")
    grit.Texture, grit.Color = SMOKE, ColorSequence.new(SAND)
    grit.Size = NumberSequence.new(0.5, 0.9)
    grit.Squash = NumberSequence.new(-2.5)
    grit.Orientation = Enum.ParticleOrientation.VelocityParallel
    grit.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 1) })
    grit.Lifetime, grit.Rate = NumberRange.new(1.5, 2.5), 0
    grit.Speed, grit.SpreadAngle = NumberRange.new(110, 150), Vector2.new(6, 4)
    grit.EmissionDirection = Enum.NormalId.Right
    grit.LightInfluence, grit.LightEmission = 0.3, 0.3
    grit.Parent = box
    return box, billow, grit
end

-- Gusts buffeting the camera: `amount` 1 is a few tenths of a stud and a fraction of a degree.
local shakeAmount = 0
local function shakeCamera()
    if shakeAmount <= 0 or Settings.get("reducedEffects") then return end
    local camera = Workspace.CurrentCamera
    local a = shakeAmount
    camera.CFrame *= CFrame.new((math.random() - 0.5) * 0.4 * a, (math.random() - 0.5) * 0.25 * a, 0)
        * CFrame.Angles((math.random() - 0.5) * 0.006 * a, (math.random() - 0.5) * 0.01 * a, (math.random() - 0.5) * 0.008 * a)
end

local function there()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root ~= nil and (root.Position - SPEC.position).Magnitude < NEAR
end

-- One storm, from the server's stamp `startAt`; returns when it's over or abandoned.
local function play(folder, startAt)
    local center = SPEC.position
    local wall, billows = buildWall(center)
    local gust, billow, grit = buildGust()
    local tint = Instance.new("ColorCorrectionEffect")
    tint.Name = "DustStormTint"
    tint.Parent = Lighting
    local finished, left = false, false
    local connection = RunService.RenderStepped:Connect(function()
        local t = Workspace:GetServerTimeNow() - startAt
        if t > CLEAR + 1 or folder:GetAttribute("StormAt") ~= startAt then
            finished = true
            return
        end
        if not there() then
            -- Gone: leave the sky to Skies (it's already another place's).
            finished, left = true, true
            return
        end
        local k = strength(t)
        weather(k)
        tint.TintColor = Color3.new(1, 1, 1):Lerp(STORM.tint, k)
        tint.Saturation, tint.Contrast, tint.Brightness = -0.2 * k, -0.08 * k, -0.04 * k
        -- The wall rolls in; once past the base it thins away (the storm is all round now).
        local front = FRONT_FROM + FRONT_SPEED * t
        if front < FRONT_TO then
            wall:PivotTo(CFrame.new(center + WIND * front))
            local fade = smooth((front - 150) / 500)
            for _, item in billows do item.part.Transparency = item.transparency + (1 - item.transparency) * fade end
        elseif wall.Parent then
            wall.Parent = nil
        end
        -- Wind round the camera, blowing from upwind of it.
        local camera = Workspace.CurrentCamera
        gust.CFrame = CFrame.fromMatrix(camera.CFrame.Position - WIND * 70, WIND, Vector3.yAxis)
        local wind = t >= ARRIVE and k or 0
        billow.Rate, grit.Rate = 90 * wind, 400 * wind
        -- Gusts: rolling bursts while it's strong.
        local burst = (math.sin(t * 1.7) + math.sin(t * 2.9 + 1)) / 2
        shakeAmount = wind > 0.5 and wind * (0.25 + 0.45 * math.max(0, burst)) or 0
    end)
    RunService:BindToRenderStep("DustStormShake", Enum.RenderPriority.Camera.Value + 2, shakeCamera)
    while not finished do task.wait(0.2) end
    connection:Disconnect()
    RunService:UnbindFromRenderStep("DustStormShake")
    shakeAmount = 0
    if not left then weather(0) end
    wall:Destroy()
    gust:Destroy()
    tint:Destroy()
end

function DustStormController.start()
    -- DestinationController parks far-off destinations in ReplicatedStorage; the folder
    -- (and its attributes) is the same instance either way.
    local root = Workspace:WaitForChild("RocketWorld"):WaitForChild("Destinations")
    local folder
    repeat
        local hidden = ReplicatedStorage:FindFirstChild("HiddenDestinations")
        folder = root:FindFirstChild(SPEC.id) or (hidden and hidden:FindFirstChild(SPEC.id))
        if not folder then task.wait(0.5) end
    until folder
    local playing = false
    local function check()
        local startAt = folder:GetAttribute("StormAt")
        if playing or type(startAt) ~= "number" or not there() or Workspace:GetServerTimeNow() - startAt > CLEAR then return end
        playing = true
        task.spawn(function()
            play(folder, startAt)
            playing = false
        end)
    end
    folder:GetAttributeChangedSignal("StormAt"):Connect(check)
    -- Arriving (or rejoining) partway through one still catches the rest of it.
    while true do
        task.wait(1)
        check()
    end
end

return DustStormController
