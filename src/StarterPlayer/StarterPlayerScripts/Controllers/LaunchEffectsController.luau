-- Client-only launch presentation. The server only stamps attributes on
-- RocketVehicle (LaunchAt, LaunchSeconds, ExhaustScale, ...); every client moves
-- its own local copy, so a 150-part ascent costs no replication bandwidth.
-- Passengers get a cinematic follow camera; everyone nearby gets tier-scaled shake.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Settings = require(script.Parent.Settings)
local Sfx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Sfx"))
local player = Players.LocalPlayer
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local LaunchEffectsController = {}

local function emitter(parent, props)
    local item = Instance.new("ParticleEmitter")
    for key, value in props do item[key] = value end
    item.Parent = parent
    return item
end

local playing, launches = {}, 0
local function play(vehicle)
    local launchAt = vehicle:GetAttribute("LaunchAt")
    if not launchAt or playing[vehicle] then return end
    playing[vehicle] = true
    local duration = vehicle:GetAttribute("LaunchSeconds")
    local ignition = vehicle:GetAttribute("IgnitionSeconds")
    local exhaust = vehicle:GetAttribute("ExhaustScale")
    local smokeScale = vehicle:GetAttribute("SmokeScale")
    local shake = vehicle:GetAttribute("Shake")
    local final = vehicle:GetAttribute("Final")
    local height = vehicle:GetAttribute("Height") or 60
    local origin = vehicle:GetPivot()
    -- Climb far enough that every tier leaves the sky before the reward phase.
    local climb = 900 + height * 4
    local accel = 2 * climb / math.max(1, duration - ignition) ^ 2

    local emitters, nozzle = {}, nil
    for _, part in vehicle:GetDescendants() do
        if part:IsA("BasePart") and part:GetAttribute("Engine") then
            -- Cylinders are rotated upright: local -X points down out of the nozzle.
            local attachment = Instance.new("Attachment")
            attachment.Position = Vector3.new(-part.Size.X / 2, 0, 0)
            attachment.Parent = part
            nozzle = nozzle or attachment
            local d = part.Size.Y
            table.insert(emitters, emitter(attachment, {
                Texture = FIRE, EmissionDirection = Enum.NormalId.Left, LightEmission = 1, Rate = 0,
                Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 160, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 30)) }),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d * 0.5 * exhaust), NumberSequenceKeypoint.new(1, d * 1.3 * exhaust) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
                Lifetime = NumberRange.new(0.35 * exhaust, 0.6 * exhaust), Speed = NumberRange.new(20 * exhaust, 30 * exhaust),
                SpreadAngle = Vector2.new(6, 6),
            }))
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness, light.Enabled = Color3.fromRGB(255, 160, 70), math.min(60, 12 * exhaust), 0, true
            light.Parent = attachment
            table.insert(emitters, light)
        end
    end
    -- Smoke stays on the pad while the rocket climbs away.
    local pad = Instance.new("Part")
    pad.Name = "LaunchSmoke"
    pad.Anchored, pad.CanCollide, pad.CanQuery, pad.CanTouch, pad.Transparency = true, false, false, false, 1
    pad.Size, pad.CFrame = Vector3.one, origin
    pad.Parent = workspace
    local smoke = {}
    for index = 1, math.clamp(math.round(3 * smokeScale), 3, 12) do
        local angle = index / math.round(3 * smokeScale) * math.pi * 2
        local attachment = Instance.new("Attachment")
        attachment.Position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (4 + 3 * smokeScale)
        attachment.Parent = pad
        table.insert(smoke, emitter(attachment, {
            Texture = SMOKE, Rate = 0, EmissionDirection = Enum.NormalId.Top,
            Color = ColorSequence.new(Color3.fromRGB(205, 205, 210)),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4 * smokeScale), NumberSequenceKeypoint.new(1, 12 * smokeScale) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
            Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(70, 70),
            Drag = 1, RotSpeed = NumberRange.new(-30, 30),
        }))
    end

    -- Ignition bursts on the pad; the engine roar rides the rocket and swells with the
    -- exhaust through ignition, bigger rockets deeper, and turns duller as it climbs
    -- away (air soaks up the highs). Liftoff booms on the pad on the frame the rocket
    -- starts to rise. Not when joining mid-launch, long after those moments.
    if workspace:GetServerTimeNow() - launchAt < 0.5 then Sfx.playAt("ignition", pad, { volume = math.min(1.5, exhaust) }) end
    local engine = Sfx.attach("engine", nozzle or pad)
    local roar, air = engine and engine.Volume, nil
    if engine then
        engine.Volume = 0
        engine.PlaybackSpeed = 1 / math.sqrt(math.max(1, exhaust))
        air = Instance.new("EqualizerSoundEffect")
        air.LowGain, air.MidGain, air.HighGain = 0, 0, 0
        air.Parent = engine
        engine:Play()
    end
    local lifted = false

    local camera = workspace.CurrentCamera
    launches += 1
    local shakeName = "RocketLaunchShake" .. launches
    RunService:BindToRenderStep(shakeName, Enum.RenderPriority.Camera.Value + 2, function()
        if not vehicle.Parent then return end
        local t = workspace:GetServerTimeNow() - launchAt
        local power = math.clamp(t / math.max(0.1, ignition), 0, 1)
        local lift = math.max(0, t - ignition)
        local rise = 0.5 * accel * lift * lift
        for _, item in emitters do
            if item:IsA("ParticleEmitter") then item.Rate = 60 * power else item.Brightness = 4 * power end
        end
        for _, item in smoke do item.Rate = (t < duration * 0.8 and 8 or 0) * power * smokeScale end
        if engine then engine.Volume = roar * power end
        if not lifted and lift > 0 then
            lifted = true
            if lift < 0.5 then Sfx.playAt("liftoff", pad, { volume = math.min(1.5, exhaust) }) end
        end
        vehicle:PivotTo(origin + Vector3.new(0, rise, 0))
        local rocketMid = origin.Position + Vector3.new(0, rise + height * 0.5, 0)
        if air then
            local distance = (camera.CFrame.Position - rocketMid).Magnitude
            air.HighGain = -math.clamp(distance / 25, 0, 40)
            air.MidGain = -math.clamp(distance / 100, 0, 12)
        end
        -- Read live: attribute replication order is not guaranteed relative to LaunchAt.
        if player:GetAttribute("RocketPassenger") and t < duration then
            camera:SetAttribute("Cinematic", true)
            camera.CameraType = Enum.CameraType.Scriptable
            local view = origin.Position + Vector3.new(height * 0.9, 12 + rise * 0.85, height * 1.2)
            camera.CFrame = CFrame.lookAt(view, rocketMid)
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local distance = root and (root.Position - origin.Position).Magnitude or 0
        local fade = math.max(0, 1 - math.max(0, lift - 1) / math.max(1, duration - ignition))
        local amplitude = shake * power * fade * math.clamp(1 - distance / 500, 0.25, 1)
        if amplitude > 0 and t < duration and not Settings.get("reducedEffects") then
            camera.CFrame *= CFrame.new((math.random() - 0.5) * amplitude, (math.random() - 0.5) * amplitude, 0)
                * CFrame.Angles(0, 0, (math.random() - 0.5) * amplitude * 0.02)
        end
    end)
    task.delay(math.max(0, launchAt + duration - workspace:GetServerTimeNow()), function()
        RunService:UnbindFromRenderStep(shakeName)
        if engine then
            TweenService:Create(engine, TweenInfo.new(0.6), { Volume = 0 }):Play()
            task.delay(0.6, engine.Destroy, engine)
        end
        if camera:GetAttribute("Cinematic") then
            camera:SetAttribute("Cinematic", nil)
            camera.CameraType = Enum.CameraType.Custom
        end
        for _, item in emitters do if item:IsA("ParticleEmitter") then item.Enabled = false end end
        -- Park the departed rocket out of sight until the server builds the next one.
        if vehicle.Parent then vehicle:PivotTo(origin + Vector3.new(0, 20000, 0)) end
        task.wait(final and 8 or 5)
        pad:Destroy()
    end)
end

-- The rocket is built tilted on a hinge at its base; when the server stamps ErectAt,
-- swing it upright about that hinge. The server snaps to the same pose afterwards.
local erecting = {}
local function erect(vehicle)
    local erectAt, seconds = vehicle:GetAttribute("ErectAt"), vehicle:GetAttribute("ErectSeconds")
    local hinge, upright, tilt = vehicle:GetAttribute("Hinge"), vehicle:GetAttribute("Upright"), vehicle:GetAttribute("Tilt")
    if not erectAt or not seconds or not hinge or not upright or not tilt or erecting[vehicle] then return end
    if workspace:GetServerTimeNow() >= erectAt + seconds then return end
    erecting[vehicle] = true
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local alpha = math.clamp((workspace:GetServerTimeNow() - erectAt) / seconds, 0, 1)
        local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        if vehicle.Parent and not vehicle:GetAttribute("LaunchAt") then
            vehicle:PivotTo(hinge * CFrame.Angles(-math.rad(tilt) * (1 - eased), 0, 0) * hinge:Inverse() * upright)
        end
        if alpha >= 1 or not vehicle.Parent then connection:Disconnect() end
    end)
end

local function watch(site)
    local function track(child)
        if child.Name ~= "RocketVehicle" then return end
        child:GetAttributeChangedSignal("LaunchAt"):Connect(function() play(child) end)
        child:GetAttributeChangedSignal("ErectAt"):Connect(function() erect(child) end)
        child.Destroying:Connect(function() playing[child], erecting[child] = nil, nil end)
        erect(child)
        play(child)
    end
    site.ChildAdded:Connect(track)
    for _, child in site:GetChildren() do track(child) end
end

function LaunchEffectsController.start()
    watch(workspace:WaitForChild("RocketWorld"):WaitForChild("RocketSite"))
end

return LaunchEffectsController
