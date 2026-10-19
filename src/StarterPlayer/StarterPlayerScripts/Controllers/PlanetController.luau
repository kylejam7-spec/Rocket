-- What keeps a destination from feeling frozen, all local to this client:
-- - Parts tagged PlanetSpin (planets, rotor blades) turn at their SpinRate; those tagged
--   PlanetOrbit also travel round their OrbitCenter about OrbitAxis at OrbitRate.
-- - Models tagged Hover bob up and down (Amplitude studs, every Period seconds).
-- - Dust devils (tag DustDevil) wander within Roam studs of their Home.
-- - Lights tagged Blinker flash on and off every Period seconds; glows tagged Pulse
--   brighten and dim every Period seconds.
-- - Geyser vents (tag GeyserVent) erupt every 7-15 s: a jet of ice crystals and a
--   column of vapour, sized by the vent's Scale, with a faint wisp in between.
-- - A destination folder with a Meteors attribute gets a shooting star across its sky
--   now and then while this player's camera is there.
-- - Walking on a destination whose folder has a Dust colour kicks up slow puffs that
--   hang in the low gravity, and a landing throws a bigger one.
-- Only what's drawn is touched: DestinationController parks far destinations outside
-- workspace.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local PlanetController = {}

local METEOR_DISTANCE = 2500
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local hoverBase = setmetatable({}, { __mode = "k" })
local function animate(dt)
    for _, part in CollectionService:GetTagged("PlanetSpin") do
        if part:IsDescendantOf(workspace) then
            part.CFrame *= CFrame.Angles(0, (part:GetAttribute("SpinRate") or 0) * dt, 0)
        end
    end
    for _, part in CollectionService:GetTagged("PlanetOrbit") do
        if part:IsDescendantOf(workspace) then
            local center = part:GetAttribute("OrbitCenter")
            local step = CFrame.fromAxisAngle(part:GetAttribute("OrbitAxis"), part:GetAttribute("OrbitRate") * dt)
            part.CFrame = CFrame.new(center + step * (part.Position - center)) * part.CFrame.Rotation
        end
    end
    local now = os.clock()
    for _, model in CollectionService:GetTagged("Hover") do
        if model:IsDescendantOf(workspace) and model.PrimaryPart then
            hoverBase[model] = hoverBase[model] or model:GetPivot()
            local period = model:GetAttribute("Period") or 3
            model:PivotTo(hoverBase[model] + Vector3.new(0, math.sin(now / period * math.pi * 2) * (model:GetAttribute("Amplitude") or 1), 0))
        end
    end
    for _, part in CollectionService:GetTagged("DustDevil") do
        if part:IsDescendantOf(workspace) then
            local home, roam = part:GetAttribute("Home"), part:GetAttribute("Roam") or 100
            local phase = home.X * 0.013 + home.Z * 0.007
            part.CFrame = CFrame.new(home + Vector3.new(math.sin(now * 0.05 + phase) * roam, 0, math.sin(now * 0.037 + phase * 2) * roam * 0.8))
        end
    end
    for _, part in CollectionService:GetTagged("Pulse") do
        if part:IsDescendantOf(workspace) then
            local glow = 0.5 + 0.5 * math.sin(now / (part:GetAttribute("Period") or 3) * math.pi * 2)
            part.Transparency = 0.45 - glow * 0.4
            local light = part:FindFirstChildOfClass("PointLight")
            if light then light.Brightness = 1.5 + glow * 2 end
        end
    end
    for _, part in CollectionService:GetTagged("Blinker") do
        if part:IsDescendantOf(workspace) then
            local period = part:GetAttribute("Period") or 1.5
            local on = now % period < period * 0.35
            part.Transparency = on and 0 or 0.8
            local light = part:FindFirstChildOfClass("PointLight")
            if light then light.Enabled = on end
        end
    end
end

-- A streak high over `center`: a bright head with a fading trail crossing the sky.
local function meteor(center, random)
    local angle = random:NextNumber(0, math.pi * 2)
    local across = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local start = center + Vector3.new(random:NextNumber(-500, 500), random:NextNumber(500, 800), random:NextNumber(-700, -200)) - across * 600
    local finish = start + across * random:NextNumber(900, 1300) + Vector3.new(0, -random:NextNumber(150, 300), 0)
    local head = Instance.new("Part")
    head.Name = "Meteor"
    head.Anchored, head.CanCollide, head.CanQuery, head.CanTouch, head.CastShadow = true, false, false, false, false
    head.Size = Vector3.one * 2.5
    head.Shape = Enum.PartType.Ball
    head.Material = Enum.Material.Neon
    head.Color = Color3.fromRGB(220, 235, 255)
    head.CFrame = CFrame.new(start)
    local back, front = Instance.new("Attachment"), Instance.new("Attachment")
    back.Position, front.Position = Vector3.new(0, -1, 0), Vector3.new(0, 1, 0)
    back.Parent, front.Parent = head, head
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = back, front
    trail.Lifetime = 0.6
    trail.LightEmission = 1
    trail.FaceCamera = true
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.Transparency = NumberSequence.new(0.1, 1)
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 180, 255))
    trail.Parent = head
    head.Parent = workspace.CurrentCamera
    local duration, started = random:NextNumber(0.9, 1.4), os.clock()
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local t = (os.clock() - started) / duration
        if t >= 1 then
            connection:Disconnect()
            task.delay(trail.Lifetime, function() head:Destroy() end)
            head.Transparency = 1
            return
        end
        head.CFrame = CFrame.new(start:Lerp(finish, t))
    end)
end

local function meteors()
    local random = Random.new()
    local root = workspace:WaitForChild("RocketWorld"):WaitForChild("Destinations")
    while true do
        task.wait(random:NextNumber(5, 12))
        local camera = workspace.CurrentCamera
        for _, spec in Config.Destinations do
            local folder = root:FindFirstChild(spec.id)
            if folder and folder:GetAttribute("Meteors") and camera and (camera.CFrame.Position - spec.position).Magnitude < METEOR_DISTANCE then
                meteor(spec.position, random)
            end
        end
    end
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local function geyserEmitters(vent)
    local scale = vent:GetAttribute("Scale") or 1
    local mouth = Instance.new("Attachment")
    mouth.Name = "GeyserMouth"
    mouth.Parent = vent
    mouth.WorldCFrame = CFrame.new(vent.Position)
    local jet = Instance.new("ParticleEmitter")
    jet.Name = "Jet"
    jet.Texture = SPARKLE
    jet.Enabled = false
    jet.Rate = 140
    jet.Lifetime = NumberRange.new(3, 4.5)
    jet.Speed = NumberRange.new(22 * scale ^ 0.75, 36 * scale ^ 0.75)
    jet.SpreadAngle = Vector2.new(7, 7)
    jet.Acceleration = Vector3.new(0, -9 * scale ^ 0.5, 0)
    jet.Size = NumberSequence.new(0.5 * scale ^ 0.5, 0.25 * scale ^ 0.5)
    jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
    jet.LightEmission = 0.8
    jet.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
    jet.Parent = mouth
    local steam = Instance.new("ParticleEmitter")
    steam.Name = "Steam"
    steam.Texture = SMOKE
    steam.Rate = 2
    steam.Lifetime = NumberRange.new(3, 5)
    steam.Speed = NumberRange.new(10 * scale ^ 0.75, 18 * scale ^ 0.75)
    steam.SpreadAngle = Vector2.new(10, 10)
    steam.Drag = 0.6
    steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3 * scale ^ 0.6), NumberSequenceKeypoint.new(1, 14 * scale ^ 0.6) })
    steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
    steam.Rotation, steam.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
    steam.LightInfluence = 0.6
    steam.Color = ColorSequence.new(Color3.fromRGB(230, 242, 255))
    steam.Parent = mouth
    return { jet = jet, steam = steam }
end

local function geysers()
    local random = Random.new()
    local state = setmetatable({}, { __mode = "k" })
    while true do
        task.wait(0.25)
        local now = os.clock()
        for _, vent in CollectionService:GetTagged("GeyserVent") do
            if vent:IsDescendantOf(workspace) then
                local s = state[vent]
                if not s then
                    s = geyserEmitters(vent)
                    s.nextAt = now + random:NextNumber(1, 10)
                    state[vent] = s
                end
                if s.untilAt and now >= s.untilAt then
                    s.jet.Enabled, s.steam.Rate, s.untilAt = false, 2, nil
                    s.nextAt = now + random:NextNumber(7, 15)
                elseif not s.untilAt and now >= s.nextAt then
                    s.jet.Enabled, s.steam.Rate, s.untilAt = true, 30, now + random:NextNumber(2.5, 4)
                end
            end
        end
    end
end

-- The destination folder (carrying a Dust colour) that `part` belongs to, if any.
local function dustOf(part)
    local node = part
    while node and node ~= workspace do
        local color = node:GetAttribute("Dust")
        if color then return color end
        node = node.Parent
    end
    return nil
end

local function footDust(character)
    local root = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    local feet = Instance.new("Attachment")
    feet.Name = "DustFeet"
    feet.Position = Vector3.new(0, -humanoid.HipHeight - root.Size.Y / 2 + 0.3, 0)
    feet.Parent = root
    local puff = Instance.new("ParticleEmitter")
    puff.Name = "FootDust"
    puff.Texture = SMOKE
    puff.Enabled = false
    puff.Lifetime = NumberRange.new(1.2, 2.2)
    puff.Speed = NumberRange.new(1.5, 4)
    puff.SpreadAngle = Vector2.new(80, 80)
    puff.EmissionDirection = Enum.NormalId.Top
    -- Barely falls: there is no air to hold it, but this reads better than a vacuum arc.
    puff.Acceleration = Vector3.new(0, -2.5, 0)
    puff.Drag = 1.2
    puff.Rotation, puff.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-30, 30)
    puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 3) })
    puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
    puff.LightInfluence = 1
    puff.Parent = feet
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local function groundDust()
        local hit = workspace:Raycast(root.Position, Vector3.new(0, -(humanoid.HipHeight + root.Size.Y / 2 + 1.5), 0), params)
        return hit and dustOf(hit.Instance)
    end
    humanoid.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed then
            local color = groundDust()
            if color then
                puff.Color = ColorSequence.new(color)
                puff:Emit(20)
            end
        end
    end)
    local nextStep = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not root.Parent then connection:Disconnect() return end
        local now = os.clock()
        if now < nextStep then return end
        nextStep = now + 0.22
        if humanoid.FloorMaterial == Enum.Material.Air or humanoid.MoveDirection.Magnitude < 0.1 then return end
        local color = groundDust()
        if color then
            puff.Color = ColorSequence.new(color)
            puff:Emit(4)
        end
    end)
end

function PlanetController.start()
    RunService.RenderStepped:Connect(animate)
    task.spawn(meteors)
    task.spawn(geysers) -- ice and vapour from every GeyserVent
    local player = Players.LocalPlayer
    if player.Character then task.spawn(footDust, player.Character) end
    player.CharacterAdded:Connect(footDust)
end

return PlanetController
