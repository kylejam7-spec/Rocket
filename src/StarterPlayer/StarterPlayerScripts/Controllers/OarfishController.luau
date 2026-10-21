--[[
    Europa's oarfish: a background event for whoever is at Europa, not a cutscene (the
    camera and controls stay the player's). The server stamps OarfishAt on the Europa
    folder OarfishDelay seconds into each stay (LaunchService); from that moment:
      0 s   the ice groans: a low earthquake rumble from below (7 s on its own),
      7 s   the ground shakes (3 s, building),
      10 s  the oarfish bursts out of the ice at OarfishExit with the ice mantle breaking
            (the rumble fades out under it),
            arcs high over the plain in front of Jupiter roaring, bending toward the
            landing site at the top, and dives into the ice at OarfishEntry with a
            second break that fades away as its body slides in after its head.
    Both holes are on the map for good (DestinationService breachHole). The fish is
    ReplicatedStorage.EuropaOarfish (tools/monster): six MeshParts skinned to 17 bones
    down its centre line (B00 head .. B16 tail). Each frame every bone is put on the
    flight path at its own distance behind the head, so the whole body bends along the
    arc, with a swimming wave rolling down it. Everything is local to this client and
    only drawn while this player is at Europa; Reduced effects drops the shaking.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Sfx"))
local Settings = require(script.Parent.Settings)
local OarfishController = {}

local SPEC = Config.Destinations[3]
local NEAR = 1500 -- studs from Europa's centre that count as "there"
-- Timeline, seconds from OarfishAt.
local QUAKE_AT, SHAKE_AT, BREACH_AT = 0, 7, 10
local QUAKE_FADE = 2.5 -- the rumble's fade, from the breakout
local DIVE_FADE_AT, DIVE_FADE = 1.6, 1.7 -- the dive's break fades from this far in, over this long
local LENGTH = 360 -- the fish, nose to tail, in studs
local APEX = 300 -- the arc's height over the ice
local SWAY = 70 -- how far the arc bows toward the landing site at the top
local SPEED = 125 -- along the path, under the ice; it slows toward the top of the arc
local LEAD = 70 -- path the head covers under the ice before it breaks out
local WAVE, WAVELENGTH, WAVE_SPEED = 9, 140, 2.2 -- the swimming wave (studs, studs, 1/s)
local GRAVITY = 50 -- for the flung ice (Europa's)

local player = Players.LocalPlayer
local template

-- Rest data for one copy of the fish: each bone's rest frame and the body's frame at
-- that bone (looking toward the head, dorsal fin up), both relative to the model's
-- pivot, so a bone's world frame for a target frame on the path is
-- target * body:Inverse() * rest wherever the model itself has been moved.
local function rig(model)
    local bones = {}
    for _, bone in model:GetDescendants() do
        local index = bone:IsA("Bone") and tonumber(bone.Name:match("^B(%d+)$"))
        if index then bones[index + 1] = bone end
    end
    if #bones < 3 then return nil end
    local pivot = model:GetPivot()
    local up = pivot.UpVector
    local rest, body, along = {}, {}, { 0 }
    for i, bone in bones do
        local ahead = bones[math.max(i - 1, 1)].WorldPosition
        local behind = bones[math.min(i + 1, #bones)].WorldPosition
        local at = bone.WorldPosition
        rest[i] = pivot:ToObjectSpace(bone.WorldCFrame)
        body[i] = pivot:ToObjectSpace(CFrame.lookAt(at, at + (ahead - behind).Unit, up)):Inverse()
        if i > 1 then along[i] = along[i - 1] + (at - bones[i - 1].WorldPosition).Magnitude end
    end
    return { bones = bones, rest = rest, body = body, along = along, length = along[#bones] }
end

-- The flight path: one parabola from exit to entry (bowed sideways toward the landing
-- site), carried on past both holes so it runs under the ice either side. Sampled by
-- arc length; also when the head crosses the ice at each hole.
local function flightPath(exit, entry, toward)
    local span = Vector3.new(entry.X - exit.X, 0, entry.Z - exit.Z)
    local side = Vector3.new(-span.Z, 0, span.X).Unit
    if side:Dot(toward - exit) < 0 then side = -side end
    local function at(t)
        return exit:Lerp(entry, t) + Vector3.new(0, 4 * APEX * t * (1 - t), 0) + side * SWAY * math.sin(math.pi * math.clamp(t, 0, 1))
    end
    local points, lengths = {}, {}
    local first, last, steps = -0.75, 1.75, 1000
    local total = 0
    for step = 0, steps do
        local point = at(first + (last - first) * step / steps)
        if step > 0 then total += (point - points[step]).Magnitude end
        points[step + 1], lengths[step + 1] = point, total
    end
    local function find(t)
        return lengths[math.floor((t - first) / (last - first) * steps + 0.5) + 1]
    end
    local function sample(s)
        s = math.clamp(s, 0, total)
        local low, high = 1, #lengths
        while high - low > 1 do
            local mid = (low + high) // 2
            if lengths[mid] <= s then low = mid else high = mid end
        end
        local span_ = lengths[high] - lengths[low]
        return points[low]:Lerp(points[high], span_ > 0 and (s - lengths[low]) / span_ or 0)
    end
    return { sample = sample, total = total, exitAt = find(0), entryAt = find(1), side = side, ice = exit.Y }
end

-- Head distance along the path over time: SPEED under the ice, easing to 55% of it at
-- the top of the arc (a heavy body fighting gravity). Returns s(time since the head set
-- off) and the time the head takes to reach a given distance.
local function schedule(path, start)
    local times, distances, dt = { 0 }, { start }, 1 / 60
    local s, t = start, 0
    while s < path.total do
        local height = math.max(0, path.sample(s).Y - path.ice)
        s += SPEED * (1 - 0.45 * math.min(1, height / APEX)) * dt
        t += dt
        table.insert(times, t)
        table.insert(distances, s)
    end
    local function distance(time)
        local index = math.clamp(time / dt, 0, #distances - 1)
        local low = math.floor(index)
        local high = math.min(low + 1, #distances - 1)
        return distances[low + 1] + (distances[high + 1] - distances[low + 1]) * (index - low)
    end
    local function reach(target)
        for index, value in distances do
            if value >= target then return times[index] end
        end
        return times[#times]
    end
    return distance, reach
end

-- A burst of ice at a hole: chunks flung up and out (simulated here, then gone) and
-- clouds of ice spray; the spray keeps coming while `spraying()` holds.
local function burst(at, radius, power)
    local folder = Instance.new("Folder")
    folder.Name = "OarfishBurst"
    folder.Parent = Workspace
    local chunks = {}
    for _ = 1, 36 do
        local size = math.random(20, 90) / 10 * power
        local part = Instance.new("Part")
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
        part.Material = math.random() < 0.5 and Enum.Material.Ice or Enum.Material.Glacier
        part.Color = Color3.fromRGB(200, 226, 246):Lerp(Color3.fromRGB(245, 250, 255), math.random())
        part.Size = Vector3.new(size * 1.3, size * 0.7, size)
        local angle = math.random() * math.pi * 2
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local start = at + out * math.random() * radius * 0.8
        part.CFrame = CFrame.new(start)
        part.Parent = folder
        table.insert(chunks, { part = part, at = start, velocity = out * math.random(15, 60) * power + Vector3.new(0, math.random(45, 110) * power, 0),
            spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8 })
    end
    local emitterPart = Instance.new("Part")
    emitterPart.Anchored, emitterPart.CanCollide, emitterPart.CanQuery, emitterPart.CanTouch = true, false, false, false
    emitterPart.Transparency, emitterPart.Size = 1, Vector3.new(radius * 1.6, 1, radius * 1.6)
    emitterPart.CFrame = CFrame.new(at)
    emitterPart.Parent = folder
    local spray = Instance.new("ParticleEmitter")
    spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
    spray.Shape, spray.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
    spray.EmissionDirection = Enum.NormalId.Top
    -- Kept low and short-lived: a big lingering cloud hid the fish from the landing site.
    spray.Speed, spray.SpreadAngle = NumberRange.new(18 * power, 50 * power), Vector2.new(35, 35)
    spray.Acceleration = Vector3.new(0, -GRAVITY * 0.6, 0)
    spray.Drag = 1.2
    spray.Lifetime = NumberRange.new(1.2, 2.4)
    spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6 * power), NumberSequenceKeypoint.new(1, 18 * power) })
    spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
    spray.Color = ColorSequence.new(Color3.fromRGB(236, 246, 255), Color3.fromRGB(190, 220, 245))
    spray.Rotation, spray.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
    spray.LightInfluence, spray.Rate = 0.6, 0
    spray.Parent = emitterPart
    local glitter = Instance.new("ParticleEmitter")
    glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    glitter.Shape = Enum.ParticleEmitterShape.Box
    glitter.EmissionDirection = Enum.NormalId.Top
    glitter.Speed, glitter.SpreadAngle = NumberRange.new(40 * power, 100 * power), Vector2.new(30, 30)
    glitter.Acceleration = Vector3.new(0, -GRAVITY, 0)
    glitter.Lifetime = NumberRange.new(2, 4)
    glitter.Size = NumberSequence.new(2.5 * power, 1)
    glitter.LightEmission, glitter.Rate = 0.8, 0
    glitter.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
    glitter.Parent = emitterPart
    spray:Emit(30)
    glitter:Emit(70)
    return { folder = folder, chunks = chunks, spray = spray, ice = at.Y }
end
-- Chunks fly until they fall back through the ice.
local function stepBurst(item, dt)
    for _, chunk in item.chunks do
        local part = chunk.part
        if part.Parent then
            chunk.velocity -= Vector3.new(0, GRAVITY * dt, 0)
            chunk.at += chunk.velocity * dt
            if chunk.velocity.Y < 0 and chunk.at.Y < item.ice - 2 then
                part:Destroy()
            else
                part.CFrame = CFrame.new(chunk.at) * part.CFrame.Rotation * CFrame.Angles(chunk.spin.X * dt, chunk.spin.Y * dt, chunk.spin.Z * dt)
            end
        end
    end
end

-- The camera shake: `amount` 1 is a few tenths of a stud and a fraction of a degree.
local shakeAmount = 0
local function shakeCamera()
    if shakeAmount <= 0 or Settings.get("reducedEffects") then return end
    local camera = Workspace.CurrentCamera
    local a = shakeAmount
    camera.CFrame *= CFrame.new((math.random() - 0.5) * 0.5 * a, (math.random() - 0.5) * 0.5 * a, 0)
        * CFrame.Angles((math.random() - 0.5) * 0.012 * a, (math.random() - 0.5) * 0.012 * a, (math.random() - 0.5) * 0.008 * a)
end

local function there()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root ~= nil and (root.Position - SPEC.position).Magnitude < NEAR
end

-- One breach, from the server's stamp `startAt`; returns when it's over or abandoned.
local function play(folder, startAt)
    local exit, entry = folder:GetAttribute("OarfishExit"), folder:GetAttribute("OarfishEntry")
    local radius = folder:GetAttribute("OarfishRadius") or 30
    if typeof(exit) ~= "Vector3" or typeof(entry) ~= "Vector3" or not template then return end
    local model = template:Clone()
    local probe = rig(model)
    if not probe then model:Destroy() return end
    model:ScaleTo(model:GetScale() * LENGTH / probe.length)
    local fish = rig(model)
    local path = flightPath(exit, entry, SPEC.position)
    local headStart = path.exitAt - LEAD
    local distance, reach = schedule(path, headStart)
    -- The head reaches the ice at the exit exactly at BREACH_AT; the dive is when it
    -- reaches the entry; it's over once the tail is well under.
    local setOff = BREACH_AT - reach(path.exitAt)
    local diveAt = setOff + reach(path.entryAt)
    local tailOut = setOff + reach(path.exitAt + fish.length)
    local tailIn = setOff + reach(path.entryAt + fish.length)
    local endAt = setOff + reach(math.min(path.total, path.entryAt + fish.length + 40))
    model.Parent = Workspace
    local voice = Instance.new("Part")
    voice.Name, voice.Anchored, voice.CanCollide, voice.CanQuery, voice.CanTouch = "OarfishVoice", true, false, false, false
    voice.Transparency, voice.Size, voice.CFrame = 1, Vector3.one, CFrame.new(exit)
    voice.Parent = Workspace
    local sounds, bursts, fired = {}, {}, {}
    local function distant(sound)
        local reverb = Instance.new("ReverbSoundEffect")
        reverb.DecayTime, reverb.Density, reverb.Diffusion, reverb.DryLevel, reverb.WetLevel = 3.2, 1, 1, -4, -2
        reverb.Parent = sound
        return sound
    end
    local function fadeOut(sound, after, seconds)
        task.delay(after, function()
            if sound.Parent then TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Volume = 0 }):Play() end
        end)
    end
    -- A cue at a spot on the ice (an invisible part there), playing once.
    local function playAt(name, at)
        local holder = Instance.new("Part")
        holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
        holder.Size, holder.CFrame, holder.Parent = Vector3.one, CFrame.new(at), Workspace
        local sound = Sfx.attach(name, holder)
        table.insert(sounds, holder)
        if sound then distant(sound):Play() end
        return sound
    end
    -- The rumble: a plain (not positional) sound, so it can fade as the fish breaks out.
    local quake = Instance.new("Sound")
    quake.Name, quake.SoundId, quake.Volume = "OarfishQuake", Sfx.source("europa/quake") or "", 0.9
    quake.SoundGroup = Settings.group("SFX")
    quake.Parent = SoundService
    local events = {
        { at = QUAKE_AT, run = function(late)
            if late < 2 then quake:Play() end
        end },
        { at = BREACH_AT, run = function(late)
            if quake.IsPlaying then TweenService:Create(quake, TweenInfo.new(QUAKE_FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Volume = 0 }):Play() end
            if late < 0.5 then playAt("oarfishBreakOut", exit) end
            table.insert(bursts, burst(exit, radius, 1))
            shakeAmount = math.max(shakeAmount, 1.2)
        end },
        { at = BREACH_AT + 0.3, run = function(late)
            if late > 1.5 then return end
            local roar = Sfx.attach("oarfishRoar", voice)
            if roar then distant(roar):Play() end
        end },
        { at = diveAt, run = function(late)
            if late < 0.5 then
                local sound = playAt("oarfishBreakIn", entry)
                if sound then fadeOut(sound, DIVE_FADE_AT, DIVE_FADE) end
            end
            table.insert(bursts, burst(entry, radius, 1.15))
            shakeAmount = math.max(shakeAmount, 0.8)
        end },
    }
    local finished = false
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        local t = Workspace:GetServerTimeNow() - startAt
        if t > endAt + 6 or not there() or folder:GetAttribute("OarfishAt") ~= startAt then
            finished = true
            return
        end
        for index, event in events do
            if not fired[index] and t >= event.at then
                fired[index] = true
                event.run(t - event.at)
            end
        end
        -- Shaking: building from SHAKE_AT to the breach, then the jolts fade.
        if t >= SHAKE_AT and t < BREACH_AT then
            shakeAmount = 0.25 + 0.75 * (t - SHAKE_AT) / (BREACH_AT - SHAKE_AT)
        elseif t >= BREACH_AT then
            shakeAmount = math.max(0, shakeAmount - dt * 1.6)
        end
        -- Spray keeps coming while the body slides through each hole.
        for index, item in bursts do
            item.spray.Rate = ((index == 1 and t < tailOut) or (index == 2 and t < tailIn)) and 6 or 0
            stepBurst(item, dt)
        end
        -- The fish: every bone at its own distance behind the head, with the swimming
        -- wave rolling down the body (stronger toward the tail).
        local head = distance(t - setOff)
        local positions = {}
        for i, along in fish.along do
            local s = head - along
            local wave = WAVE * (0.3 + 0.7 * along / fish.length) * math.sin((s / WAVELENGTH) * math.pi * 2 - t * WAVE_SPEED * math.pi * 2)
            positions[i] = path.sample(s) + path.side * wave
        end
        local count = #fish.bones
        model:PivotTo(CFrame.new(positions[(count + 1) // 2]))
        for i, bone in fish.bones do
            local ahead, behind = positions[math.max(i - 1, 1)], positions[math.min(i + 1, count)]
            local forward = ahead - behind
            if forward.Magnitude < 1e-3 then forward = Vector3.new(0, 1, 0) end
            local up = math.abs(forward.Unit.Y) > 0.98 and path.side or Vector3.yAxis
            bone.WorldCFrame = CFrame.lookAt(positions[i], positions[i] + forward, up) * fish.body[i] * fish.rest[i]
        end
        voice.CFrame = CFrame.new(positions[1])
    end)
    RunService:BindToRenderStep("OarfishShake", Enum.RenderPriority.Camera.Value + 2, shakeCamera)
    while not finished do task.wait(0.2) end
    connection:Disconnect()
    RunService:UnbindFromRenderStep("OarfishShake")
    shakeAmount = 0
    model:Destroy()
    voice:Destroy()
    quake:Destroy()
    for _, holder in sounds do holder:Destroy() end
    for _, item in bursts do item.folder:Destroy() end
end

function OarfishController.start()
    template = ReplicatedStorage:WaitForChild("EuropaOarfish", 60)
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
        local startAt = folder:GetAttribute("OarfishAt")
        if playing or type(startAt) ~= "number" or not there() then return end
        playing = true
        task.spawn(function()
            play(folder, startAt)
            playing = false
        end)
    end
    folder:GetAttributeChangedSignal("OarfishAt"):Connect(check)
    -- Arriving (or rejoining) partway through one still catches the rest of it.
    while true do
        task.wait(1)
        check()
    end
end

return OarfishController
