-- Client-only launch presentation. The server only stamps attributes on
-- RocketVehicle (LaunchAt, LaunchSeconds, ExhaustScale, ...); every client moves
-- its own local copy, so a 150-part ascent costs no replication bandwidth.
-- Passengers get a cinematic follow camera; everyone nearby gets tier-scaled shake.
-- Then the landing: the server stands a LandedRocket copy on the destination
-- (DescentAt, DescentSeconds, CutsceneEnd) and each client flies it down from the
-- sky onto that spot, engines braking, while passengers watch from the ground.
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

-- Fire, and a light, out of every engine nozzle of a rocket model.
local function engineFire(model, exhaust)
    local emitters, nozzle = {}, nil
    for _, part in model:GetDescendants() do
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
    return emitters, nozzle
end

-- A ring of smoke emitters on an invisible part at `cframe` (launch pad or landing spot).
local function smokeRing(name, cframe, smokeScale)
    local pad = Instance.new("Part")
    pad.Name = name
    pad.Anchored, pad.CanCollide, pad.CanQuery, pad.CanTouch, pad.Transparency = true, false, false, false, 1
    pad.Size, pad.CFrame = Vector3.one, cframe
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
    return pad, smoke
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

    local emitters, nozzle = engineFire(vehicle, exhaust)
    -- Smoke stays on the pad while the rocket climbs away.
    local pad, smoke = smokeRing("LaunchSmoke", origin, smokeScale)

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
        -- Two shots: alongside as it clears the pad, then a high, wide view from the
        -- other side of the pad looking up as it shrinks into the sky. That one sits well
        -- above everything on the ground (the UFO Shop, the hut, players on the apron),
        -- so nothing walks into the frame. For the big rockets both stand out past the
        -- site's hoarding (SiteSurroundsService), so the first starts high enough to see
        -- the pad over it.
        if player:GetAttribute("RocketPassenger") and t < duration then
            camera:SetAttribute("Cinematic", true)
            camera.CameraType = Enum.CameraType.Scriptable
            local view = origin.Position + Vector3.new(height * 0.9, 12 + height * 0.1 + rise * 0.85, height * 1.2)
            if lift > (duration - ignition) * 0.45 then
                view = origin.Position + Vector3.new(-height * 0.7, 40 + height * 0.5, height * 1.3)
            end
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

-- Black over the screen, 0..1, for the passengers' cuts between shots.
local function fader()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CutsceneFade"
    gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 100
    local frame = Instance.new("Frame")
    frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency, frame.BorderSizePixel = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 1, 0
    frame.Parent = gui
    gui.Parent = player:WaitForChild("PlayerGui")
    return function(alpha) frame.BackgroundTransparency = 1 - alpha end, gui
end
-- 1 at `at`, ramping up over `before` and back down over `after`.
local function bump(t, at, before, after)
    if t < at then return math.clamp(1 - (at - t) / before, 0, 1) end
    return math.clamp(1 - (t - at) / after, 0, 1)
end

-- The descent onto the destination. Before DescentAt the copy waits out of sight;
-- it then drops from high above, slowing to a stop on the landing spot with the
-- engines braking and dust blowing out as it nears the ground. Passengers' screens
-- fade from the ascent into a shot from the ground, then fade out as they step out.
local landing = {}
local function land(rocket)
    local descentAt, seconds, finish = rocket:GetAttribute("DescentAt"), rocket:GetAttribute("DescentSeconds"), rocket:GetAttribute("CutsceneEnd")
    if not descentAt or not seconds or not finish or landing[rocket] then return end
    -- Joining long after: it's simply standing there.
    if workspace:GetServerTimeNow() > finish + 1 then return end
    landing[rocket] = true
    local rest = rocket:GetPivot()
    local ground = rocket:GetAttribute("Ground") or rest.Position
    local height = rocket:GetAttribute("Height") or 60
    local exhaust = rocket:GetAttribute("ExhaustScale") or 1
    local drop = 120 + height * 1.2
    -- Braking burns hard: bigger flames than the ascent.
    local emitters, nozzle = engineFire(rocket, exhaust * 1.4)
    local dust, plumes = smokeRing("LandingDust", CFrame.new(ground), 1 + exhaust)
    local engine = Sfx.attach("engine", nozzle or dust)
    local roar = engine and engine.Volume
    if engine then
        engine.Volume = 0
        engine.PlaybackSpeed = 1 / math.sqrt(math.max(1, exhaust))
        engine:Play()
    end
    local camera = workspace.CurrentCamera
    local fade, fadeGui
    local touched, cinematic = false, false
    -- Far enough back to keep both the falling rocket and the ground in frame.
    local shot = Vector3.new(0.45, 0, 1).Unit * (height * 2.4 + 80)
    launches += 1
    local name = "RocketLanding" .. launches
    local function cleanup()
        RunService:UnbindFromRenderStep(name)
        if fadeGui then fadeGui:Destroy() end
        if engine then engine:Destroy() end
        for _, item in emitters do if item:IsA("ParticleEmitter") then item.Enabled = false end end
        task.delay(6, dust.Destroy, dust)
        landing[rocket] = nil
    end
    RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
        local now = workspace:GetServerTimeNow()
        if not rocket.Parent or now > finish + 0.7 then cleanup() return end
        local t = now - descentAt
        local progress = math.clamp(t / seconds, 0, 1)
        local h = drop * (1 - progress) ^ 2.2
        rocket:PivotTo(t < 0 and rest + Vector3.new(0, 20000, 0) or rest + Vector3.new(0, h, 0))
        local burning = t >= 0 and progress < 1
        for _, item in emitters do
            if item:IsA("ParticleEmitter") then item.Rate = burning and 60 or 0 else item.Brightness = burning and 4 or 0 end
        end
        for _, item in plumes do item.Rate = (burning and h < 40 + height * 0.3) and 12 * (1 + exhaust) or 0 end
        if engine then engine.Volume = roar * (burning and math.min(1, t / 0.5) or 0) end
        if progress >= 1 and not touched then
            touched = true
            for _, item in plumes do item:Emit(10) end
            Sfx.playAt("liftoff", dust, { volume = math.min(1.5, exhaust) })
        end
        local passenger = player:GetAttribute("RocketPassenger")
        if passenger and not fade then fade, fadeGui = fader() end
        if fade then fade(math.max(bump(now, descentAt, 0.5, 0.6), bump(now, finish, 0.4, 0.6))) end
        if passenger and t >= 0 and now < finish then
            cinematic = true
            camera:SetAttribute("Cinematic", true)
            camera.CameraType = Enum.CameraType.Scriptable
            local view = ground + shot + Vector3.new(0, 20 + h * 0.3, 0)
            camera.CFrame = CFrame.lookAt(view, ground + Vector3.new(0, (h + height * 0.45) * 0.45, 0))
        elseif cinematic and now >= finish then
            -- Under the black: hand the camera back as the server moves us out.
            cinematic = false
            camera:SetAttribute("Cinematic", nil)
            camera.CameraType = Enum.CameraType.Custom
        end
    end)
end

function LaunchEffectsController.start()
    local world = workspace:WaitForChild("RocketWorld")
    watch(world:WaitForChild("RocketSite"))
    local destinations = world:WaitForChild("Destinations")
    -- DestinationController parks far destinations in ReplicatedStorage.HiddenDestinations
    -- and brings them back, which re-adds their contents: land each rocket once.
    local seen = setmetatable({}, { __mode = "k" })
    local function track(item)
        if item.Name == "LandedRocket" and item:IsA("Model") and not seen[item] then
            seen[item] = true
            task.defer(land, item)
        end
    end
    local hidden = game:GetService("ReplicatedStorage"):WaitForChild("HiddenDestinations")
    for _, container in { destinations, hidden } do
        container.DescendantAdded:Connect(track)
        for _, item in container:GetDescendants() do track(item) end
    end
end

return LaunchEffectsController
