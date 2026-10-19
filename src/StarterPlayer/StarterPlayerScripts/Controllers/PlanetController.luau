-- What keeps a destination from feeling frozen, all local to this client:
-- - Planets (and their cloud shells) tagged PlanetSpin turn at their SpinRate.
-- - Lights tagged Blinker flash on and off every Period seconds.
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

local function spinAndBlink(dt)
    for _, part in CollectionService:GetTagged("PlanetSpin") do
        if part:IsDescendantOf(workspace) then
            part.CFrame *= CFrame.Angles(0, (part:GetAttribute("SpinRate") or 0) * dt, 0)
        end
    end
    local now = os.clock()
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
    RunService.RenderStepped:Connect(spinAndBlink)
    task.spawn(meteors)
    local player = Players.LocalPlayer
    if player.Character then task.spawn(footDust, player.Character) end
    player.CharacterAdded:Connect(footDust)
end

return PlanetController
