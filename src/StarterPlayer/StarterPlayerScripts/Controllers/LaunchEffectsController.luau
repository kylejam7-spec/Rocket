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

-- Fire, and a light, out of every engine nozzle of a rocket model (`height` tall).
-- Each nozzle gets a flame plume sized to the nozzle and the rocket: a deep orange
-- outer flame and a pale hot core, each stepped narrower toward the tip so it tapers,
-- flickering, plus particles round it. A 1000-stud rocket filmed from far off still has
-- a clear column of fire, and plumes stay visible at any graphics level (particles are
-- thinned out on low settings). Returns the emitters/lights and `burn(power, reach)`,
-- which sets every flame (0 = out, 1 = full), no longer than `reach` if given (a landing
-- rocket's height above the ground, so flames never sink into it).
local OUTER, CORE = Color3.fromRGB(255, 96, 24), Color3.fromRGB(255, 226, 150)
-- Flame layers: name, colour, width (x nozzle), length (x plume), opacity at the nozzle.
local LAYERS = { { "FlamePlume", OUTER, 0.9, 1, 0.35 }, { "FlameCore", CORE, 0.5, 0.5, 0.1 } }
-- Each layer is three segments: share of its length, width, and extra transparency.
local SEGMENTS = { { 0.4, 1, 0 }, { 0.33, 0.72, 0.2 }, { 0.27, 0.42, 0.42 } }
local function engineFire(model, exhaust, height)
    local emitters, nozzle, plumes = {}, nil, {}
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") and part:GetAttribute("Engine") then
            -- Cylinders are rotated upright: local -X points down out of the nozzle.
            local attachment = Instance.new("Attachment")
            attachment.Position = Vector3.new(-part.Size.X / 2, 0, 0)
            attachment.Parent = part
            nozzle = nozzle or attachment
            local d = part.Size.Y
            local length = math.min(d * (2.5 + 1.5 * exhaust), height * 0.25)
            table.insert(emitters, emitter(attachment, {
                Texture = FIRE, EmissionDirection = Enum.NormalId.Left, LightEmission = 1, Rate = 0,
                Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 160, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 30)) }),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.min(100, d * 0.7)), NumberSequenceKeypoint.new(1, math.min(100, d * 1.6)) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
                Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(length * 1.6, length * 2.2),
                SpreadAngle = Vector2.new(6, 6),
            }))
            local light = Instance.new("PointLight")
            -- Lights the ground and smoke under the nozzle, not the whole hull (with bloom,
            -- brighter lights washed the boosters white).
            light.Color, light.Range, light.Brightness, light.Enabled = Color3.fromRGB(255, 160, 70), math.min(60, d * 3), 0, true
            light.Parent = attachment
            table.insert(emitters, light)
            local seed = math.random() * 10
            for _, layer in LAYERS do
                local start = 0
                for _, segment in SEGMENTS do
                    local flame = Instance.new("Part")
                    flame.Name, flame.Shape, flame.Color, flame.Material = layer[1], Enum.PartType.Cylinder, layer[2], Enum.Material.Neon
                    flame.Anchored, flame.CanCollide, flame.CanQuery, flame.CanTouch, flame.CastShadow = true, false, false, false, false
                    flame.Transparency = 1
                    flame.Parent = model
                    table.insert(plumes, { part = flame, engine = part, length = length * layer[4], from = start, share = segment[1],
                        width = d * layer[3] * segment[2], opacity = layer[5] + (1 - layer[5]) * segment[3], seed = seed })
                    start += segment[1]
                end
            end
        end
    end
    local function burn(power, reach)
        local now = os.clock()
        for _, plume in plumes do
            local engine = plume.engine
            if power <= 0.02 then
                plume.part.Transparency = 1
            else
                local flicker = 1 + 0.12 * math.sin(now * 23 + plume.seed) + 0.06 * math.sin(now * 41 + plume.seed * 3)
                local total = math.max(1, math.min(plume.length * power * flicker, reach or math.huge))
                local length = math.max(0.5, total * plume.share)
                local width = plume.width * (0.7 + 0.3 * power)
                plume.part.Size = Vector3.new(length, width, width)
                plume.part.CFrame = engine.CFrame * CFrame.new(-engine.Size.X / 2 - total * plume.from - length / 2, 0, 0)
                plume.part.Transparency = 1 - (1 - plume.opacity) * math.min(1, power * 1.5)
            end
        end
        for _, item in emitters do
            if item:IsA("ParticleEmitter") then item.Rate = 60 * power else item.Brightness = 2 * power end
        end
    end
    return emitters, nozzle, burn
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

-- The launch's smoke, sized to the rocket (`height` tall; its hull is ~0.1 of that across):
-- a ring of columns rising round its base and a ring of low clouds billowing out across
-- the pad. Returns the pad part and { emitter, base rate } pairs (rates scale with power).
local function launchSmoke(cframe, height)
    local pad = Instance.new("Part")
    pad.Name = "LaunchSmoke"
    pad.Anchored, pad.CanCollide, pad.CanQuery, pad.CanTouch, pad.Transparency = true, false, false, false, 1
    pad.Size, pad.CFrame = Vector3.one, cframe
    pad.Parent = workspace
    local smoke = {}
    local grey = ColorSequence.new(Color3.fromRGB(225, 222, 218), Color3.fromRGB(170, 168, 172))
    local function add(position, up, props, rate)
        local attachment = Instance.new("Attachment")
        local side = up:Cross(Vector3.zAxis)
        local right = side.Magnitude > 0.1 and side.Unit or Vector3.xAxis
        attachment.CFrame = CFrame.fromMatrix(position, right, up)
        attachment.Parent = pad
        table.insert(smoke, { emitter(attachment, props), rate })
    end
    -- Columns: straight up round the engines.
    for index = 1, 12 do
        local angle = index / 12 * math.pi * 2
        add(Vector3.new(math.cos(angle), 0, math.sin(angle)) * height * 0.09, Vector3.yAxis, {
            Texture = SMOKE, Rate = 0, EmissionDirection = Enum.NormalId.Top, Color = grey,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.min(100, height * 0.05)), NumberSequenceKeypoint.new(1, math.min(100, height * 0.16)) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }),
            Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(height * 0.03, height * 0.06), SpreadAngle = Vector2.new(35, 35),
            Drag = 0.8, RotSpeed = NumberRange.new(-20, 20), Rotation = NumberRange.new(0, 360),
        }, 4)
    end
    -- Billows: out and a little up along the ground, slowing as they spread and climb.
    for index = 1, 16 do
        local angle = (index + 0.5) / 16 * math.pi * 2
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        add(out * height * 0.12, (out * 0.85 + Vector3.yAxis * 0.35).Unit, {
            Texture = SMOKE, Rate = 0, EmissionDirection = Enum.NormalId.Top, Color = grey,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.min(100, height * 0.06)), NumberSequenceKeypoint.new(1, math.min(100, height * 0.2)) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.5), NumberSequenceKeypoint.new(1, 1) }),
            Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(height * 0.08, height * 0.14), SpreadAngle = Vector2.new(25, 12),
            Drag = 0.5, Acceleration = Vector3.new(0, height * 0.004, 0), RotSpeed = NumberRange.new(-15, 15), Rotation = NumberRange.new(0, 360),
        }, 3)
    end
    return pad, smoke
end

-- The passengers' launch shot: one camera low over the ground off the east side of the
-- site (user, 2026-10-24: a high view showed the map end past the mountains; from down
-- here the horizon is the mountains). It rises at a tenth of the rocket's pace and
-- narrows its view as the rocket climbs away, so it soon looks up into the sky and the
-- rocket stays a good size. The spot is clear of buildings with a clear view of the pad.
local SHOT_FOV, SHOT_FOV_END = 70, 32
local SHOT_OFFSET = Vector3.new(280, 25, 265) -- from the pad's centre: x = 280, z = 0

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

    local emitters, nozzle, burn = engineFire(vehicle, exhaust, height)
    -- Smoke stays on the pad while the rocket climbs away; heavier rockets make more, up
    -- to twice the first's, and Reduced effects thins it out.
    local pad, smoke = launchSmoke(CFrame.new(origin.Position), height)
    local smokeRate = math.min(2, smokeScale) * (Settings.get("reducedEffects") and 0.4 or 1)

    -- Ignition bursts on the pad; the engine roar rides the rocket and swells with the
    -- exhaust through ignition, bigger rockets deeper, and turns duller as it climbs
    -- away (air soaks up the highs). Liftoff booms on the pad on the frame the rocket
    -- starts to rise. Not when joining mid-launch, long after those moments.
    -- Heavier rockets sound heavier: 0 for the Lunar Rocket up to 1 for the biggest.
    -- Their booms drop in pitch, the roar gains bass, and a sub rumble (the engine an
    -- octave down with its highs cut) swells in under it.
    local heavy = math.clamp((exhaust - 1) / 2.6, 0, 1)
    if workspace:GetServerTimeNow() - launchAt < 0.5 then Sfx.playAt("ignition", pad, { volume = math.min(1.5, exhaust), pitch = 1 - 0.3 * heavy }) end
    local engine = Sfx.attach("engine", nozzle or pad)
    local roar, air = engine and engine.Volume, nil
    local sub, subVolume
    if engine then
        engine.Volume = 0
        engine.PlaybackSpeed = 1 / math.sqrt(math.max(1, exhaust))
        air = Instance.new("EqualizerSoundEffect")
        air.LowGain, air.MidGain, air.HighGain = 10 * heavy, 0, 0
        air.Parent = engine
        engine:Play()
        if heavy > 0 then
            sub = Sfx.attach("engine", nozzle or pad)
            if sub then
                sub.PlaybackSpeed = engine.PlaybackSpeed * 0.5
                subVolume, sub.Volume = sub.Volume * 1.2 * heavy, 0
                local rumble = Instance.new("EqualizerSoundEffect")
                rumble.LowGain, rumble.MidGain, rumble.HighGain = 10, -18, -40
                rumble.Parent = sub
                sub:Play()
            end
        end
    end
    local lifted = false

    local camera = workspace.CurrentCamera
    local normalFov
    launches += 1
    local shakeName = "RocketLaunchShake" .. launches
    RunService:BindToRenderStep(shakeName, Enum.RenderPriority.Camera.Value + 2, function()
        if not vehicle.Parent then return end
        local t = workspace:GetServerTimeNow() - launchAt
        local power = math.clamp(t / math.max(0.1, ignition), 0, 1)
        local lift = math.max(0, t - ignition)
        local rise = 0.5 * accel * lift * lift
        vehicle:PivotTo(origin + Vector3.new(0, rise, 0))
        burn(power)
        for _, entry in smoke do entry[1].Rate = (t < duration * 0.8 and entry[2] or 0) * power * smokeRate end
        if engine then engine.Volume = roar * power end
        if sub then sub.Volume = subVolume * power end
        if not lifted and lift > 0 then
            lifted = true
            if lift < 0.5 then Sfx.playAt("liftoff", pad, { volume = math.min(1.5, exhaust), pitch = 1 - 0.25 * heavy }) end
        end
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
            normalFov = normalFov or camera.FieldOfView
            local climbed = math.clamp(rise / climb, 0, 1)
            camera.FieldOfView = SHOT_FOV + (SHOT_FOV_END - SHOT_FOV) * math.sqrt(climbed)
            local view = origin.Position + SHOT_OFFSET + Vector3.new(0, rise * 0.1, 0)
            -- Aimed below the middle, and at first lagging the climb, so the pad and its smoke
            -- stay in the bottom of the frame as the rocket clears it; then it catches up.
            local aim = origin.Position + Vector3.new(0, rise * (0.55 + 0.45 * math.sqrt(climbed)) + height * (0.3 + 0.15 * climbed), 0)
            camera.CFrame = CFrame.lookAt(view, aim)
            -- Roblox draws and lights in detail around Focus, which otherwise stays on the
            -- passenger in the far-off cabin: the pad would load late and drop out.
            camera.Focus = CFrame.new(rocketMid)
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
        for _, sound in { engine, sub } do
            if sound then
                TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 }):Play()
                task.delay(0.6, sound.Destroy, sound)
            end
        end
        if camera:GetAttribute("Cinematic") then
            camera:SetAttribute("Cinematic", nil)
            camera.CameraType = Enum.CameraType.Custom
        end
        if normalFov then camera.FieldOfView, normalFov = normalFov, nil end
        burn(0)
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
    local drop = 80 + height * 0.9
    -- Braking burns hard: bigger flames than the ascent.
    local emitters, nozzle, burn = engineFire(rocket, exhaust * 1.4, height)
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
    -- About a rocket height back (the rocket fills the frame), and never more than 220,
    -- so the camera stays inside every destination's ring of mountains. Where that is
    -- too close for the whole rocket and its flames (the big ones), the lens widens.
    local distance = math.min(height * 1.1 + 40, 220)
    local shot = Vector3.new(0.45, 0, 1).Unit * distance
    local fov = math.clamp(math.deg(2 * math.atan(height * 1.35 * 1.3 / 2 / distance)), 70, 90)
    local normalFov
    launches += 1
    local name = "RocketLanding" .. launches
    local function cleanup()
        RunService:UnbindFromRenderStep(name)
        if normalFov then camera.FieldOfView, normalFov = normalFov, nil end
        if fadeGui then fadeGui:Destroy() end
        if engine then engine:Destroy() end
        burn(0)
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
        -- Full burn high up, easing off as it settles.
        burn(burning and math.clamp(0.45 + h / drop, 0.45, 1) or 0, h + 1)
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
            normalFov = normalFov or camera.FieldOfView
            camera.FieldOfView = fov
            -- Low, riding down with it, aimed a little below its middle so the nose and
            -- the flames under it both stay in frame all the way down (checked per tier).
            local view = ground + shot + Vector3.new(0, height * 0.2 + h * 0.6, 0)
            camera.CFrame = CFrame.lookAt(view, ground + Vector3.new(0, h + height * 0.35, 0))
            camera.Focus = CFrame.new(ground)
        elseif cinematic and now >= finish then
            -- Under the black: hand the camera back as the server moves us out.
            cinematic = false
            if normalFov then camera.FieldOfView, normalFov = normalFov, nil end
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
