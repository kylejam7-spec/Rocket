--[[
    Saturn's UFO: a background event for whoever is at Saturn's rings, not a cutscene (the
    camera and controls stay the player's). The server stamps UfoAt on the Saturn folder
    UfoDelay seconds into each stay (LaunchService); from that moment the flying saucer,
    two alien pilots under its canopy, swoops in from Saturn's side of the sky, spirals
    down and circles the platform once, banking. A chunk of the rings comes tumbling along
    the belt and smacks into it out on the left:
      hit         the crash of rock on hull sounds where they meet and the fly-by sound
                  starts from the UFO as it's knocked out of its circle,
                  sparking and smoking, and spins away across the platform, over the
                  arrival,
      +FALL       it crashes on the right-hand rim (the folder's UfoCrash) with the impact
                  sound, a flash, a burst of rock and frost, and a jolt for anyone close,
                  skids and rocks to a stop nosed over onto the rock (settled on whatever
                  is under it, never sunk in), its tail out over the edge and its canopy
                  toward the platform, inside an invisible wall nobody can climb,
      after that  it stays down until the stay ends: smoking, its lights flickering, a red
                  alarm pulsing, the pilots freaking out (hands clamped on their heads,
                  pounding the console, waving for help), its systems beeping and chirping
                  (heard round about it, not across the platform).
    The fly-by and impact play from the UFO, so they pan and carry with it. The UFO is
    ReplicatedStorage.SaturnUFO (tools/monster): nine MeshParts skinned to the pilots'
    bones. Everything is local to this client and only drawn while this player is at
    Saturn; Reduced effects drops the jolt.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Sfx"))
local Settings = require(script.Parent.Settings)
local SaturnUfoController = {}

local SPEC = Config.Destinations[4]
local NEAR = 1500 -- studs from the platform's centre that count as "there"
local DIAMETER = 30 -- the saucer, across, in studs
local RADIUS, HEIGHT = 150, 42 -- its circle round the platform: from the centre, over the top
local SPEED = 95 -- round the circle; faster on the way in
local FROM_DISTANCE, FROM_HEIGHT = 1300, 360 -- where it comes in from, toward Saturn
local SATURN = Vector3.new(-1500, 0, -1700) -- Saturn from the platform (DestinationService)
local BANK = math.rad(16) -- leaning into the turn
local FALL = 2.2 -- seconds from the hit to touchdown: the fly-by's swell and peak
local SPIN_TURNS = 3 -- turns it spins through on the way down
local SKID, SKID_TIME = 8, 0.6 -- studs it skids after touching down, and how long for
local REST_TILT = math.rad(18) -- nosed over toward the platform, its canopy facing it
-- The saucer's underside, from the centre out: { fraction of its radius, height under its
-- middle in diameters } (tools/monster/rig_ufo.py's mesh; the engine dome hangs lowest).
local UNDERSIDE = { { 0, -0.143 }, { 0.3, -0.14 }, { 0.45, -0.128 }, { 0.6, -0.097 }, { 0.75, -0.072 }, { 0.9, -0.046 }, { 1, -0.015 } }
-- The invisible wall round the wreck: as tall as the destination fences, so even the
-- fastest walker thrown up off a slope can't land on it.
local BARRIER_HEIGHT = 2000
local ROCK_SIZE = Vector3.new(20, 14, 17)
local ROCK_SPEED = 190
local ROCK_LEAD = 7 -- seconds the chunk is in view before the hit (and after)
local GRAVITY = 60 -- for flung debris
local ROCK = Color3.fromRGB(146, 150, 162)
local FROST = Color3.fromRGB(226, 232, 240)

local player = Players.LocalPlayer
local template

-- The way in and round: a spiral from far out toward Saturn closing onto the circle,
-- then counter-clockwise (seen from above) round the platform to `hit`'s bearing. The
-- hit spot is the path's end. Returns position(time) and the time it gets there.
local function flightPath(center, hit)
    local top = center.Y + HEIGHT
    local from = math.atan2(SATURN.Z, SATURN.X)
    local to = math.atan2(hit.Z - center.Z, hit.X - center.X)
    while to < from + math.pi * 1.5 do to += math.pi * 2 end
    local sweep, settle = to - from, 0.8
    local tail = math.exp(-sweep / settle)
    local function at(u)
        local far = (math.exp(-u / settle) - tail) / (1 - tail)
        local r = RADIUS + (FROM_DISTANCE - RADIUS) * far
        local angle = from + u
        local bob = 3 * math.sin(u * 2.5) * (1 - far)
        return Vector3.new(center.X + math.cos(angle) * r, top + FROM_HEIGHT * far + bob, center.Z + math.sin(angle) * r), r
    end
    local steps = 1500
    local times, points = { 0 }, { (at(0)) }
    local total = 0
    for step = 1, steps do
        local point, r = at(sweep * step / steps)
        total += (point - points[step]).Magnitude / (SPEED + (r - RADIUS) * 0.4)
        times[step + 1], points[step + 1] = total, point
    end
    local function position(time)
        if time <= 0 then return points[1] end
        if time >= total then return points[#points] end
        local low, high = 1, #times
        while high - low > 1 do
            local mid = (low + high) // 2
            if times[mid] <= time then low = mid else high = mid end
        end
        return points[low]:Lerp(points[high], (time - times[low]) / (times[high] - times[low]))
    end
    return position, total
end

local function bezier(a, b, c, d, u)
    local v = 1 - u
    return a * (v * v * v) + b * (3 * v * v * u) + c * (3 * v * u * u) + d * (u * u * u)
end

-- The pilots' bones, each with its rest turn relative to the UFO's pivot, so a turn
-- given in the UFO's own frame (X right, Y up, Z back) becomes the bone's Transform.
local function joints(model)
    local pivot, found = model:GetPivot(), {}
    for _, bone in model:GetDescendants() do
        if bone:IsA("Bone") then found[bone.Name] = { bone = bone, rest = pivot:ToObjectSpace(bone.WorldCFrame).Rotation } end
    end
    return found
end
local function pose(joint, rotation)
    if joint then joint.bone.Transform = joint.rest:Inverse() * rotation * joint.rest end
end

-- A burst of debris at `at`: chunks flung up and out (simulated here, then gone) and a
-- cloud of dust or sparks. kind: "rock" (the crash) or "ice" (the asteroid's hit).
local function burst(folder, at, kind, floor)
    local chunks = {}
    local count, colors = kind == "rock" and 30 or 18, kind == "rock" and { ROCK, FROST, Color3.fromRGB(96, 100, 112) } or { FROST, Color3.fromRGB(208, 226, 244) }
    for _ = 1, count do
        local size = math.random(10, 45) / 10
        local part = Instance.new("Part")
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
        part.Material = kind == "rock" and Enum.Material.Slate or Enum.Material.Ice
        part.Color = colors[math.random(#colors)]
        part.Size = Vector3.new(size * 1.3, size * 0.8, size)
        local angle = math.random() * math.pi * 2
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        part.CFrame = CFrame.new(at + out * math.random() * 4)
        part.Parent = folder
        table.insert(chunks, { part = part, at = part.Position, velocity = out * math.random(12, 45) + Vector3.new(0, math.random(20, 60), 0),
            spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10 })
    end
    local holder = Instance.new("Part")
    holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
    holder.Size, holder.CFrame, holder.Parent = Vector3.new(10, 1, 10), CFrame.new(at), folder
    local dust = Instance.new("ParticleEmitter")
    dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
    dust.Speed, dust.SpreadAngle = NumberRange.new(10, 35), Vector2.new(70, 70)
    dust.Drag, dust.Acceleration = 1.5, Vector3.new(0, -4, 0)
    dust.Lifetime = NumberRange.new(1.5, 3)
    dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 16) })
    dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
    dust.Color = ColorSequence.new(FROST, ROCK)
    dust.Rotation, dust.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-40, 40)
    dust.LightInfluence, dust.Rate = 0.7, 0
    dust.Parent = holder
    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Speed, sparks.SpreadAngle = NumberRange.new(40, 90), Vector2.new(80, 80)
    sparks.Acceleration = Vector3.new(0, -GRAVITY, 0)
    sparks.Lifetime = NumberRange.new(0.5, 1.4)
    sparks.Size = NumberSequence.new(1.4, 0.2)
    sparks.LightEmission, sparks.Rate = 1, 0
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 120, 40))
    sparks.Parent = holder
    dust:Emit(kind == "rock" and 40 or 14)
    sparks:Emit(kind == "rock" and 60 or 80)
    return { chunks = chunks, floor = floor or at.Y - 200 }
end
local function stepBurst(item, dt)
    for _, chunk in item.chunks do
        local part = chunk.part
        if part.Parent then
            chunk.velocity -= Vector3.new(0, GRAVITY * dt, 0)
            chunk.at += chunk.velocity * dt
            if chunk.velocity.Y < 0 and chunk.at.Y < item.floor then
                part:Destroy()
            else
                part.CFrame = CFrame.new(chunk.at) * part.CFrame.Rotation * CFrame.Angles(chunk.spin.X * dt, chunk.spin.Y * dt, chunk.spin.Z * dt)
            end
        end
    end
end

-- The asteroid: three lumps of one of the platform's own drifting ring chunks (so it looks
-- like the rest of the belt, but knobbly), freed from the drift; a Model moved by PivotTo.
local function asteroid(destination)
    local best
    for _, item in destination:GetChildren() do
        if item.Name == "RingChunk" and item:IsA("BasePart") and item.Size.X > 10 and item.Size.X < 40 then
            best = item
            break
        end
    end
    local function lump(name, size, offset, color, material)
        local part
        if best then
            part = best:Clone()
            for _, tag in CollectionService:GetTags(part) do CollectionService:RemoveTag(part, tag) end
            for key in part:GetAttributes() do part:SetAttribute(key, nil) end
            part:ClearAllChildren()
        else
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Ball
        end
        part.Name = name
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, true
        part.Size, part.Material, part.Color = size, material, color
        part.CFrame = CFrame.new(offset) * CFrame.Angles(offset.Z * 0.3, offset.X * 0.2, offset.Y * 0.4)
        return part
    end
    local model = Instance.new("Model")
    model.Name = "UfoAsteroid"
    local rock = lump("Core", ROCK_SIZE, Vector3.zero, FROST:Lerp(ROCK, 0.45), Enum.Material.Glacier)
    rock.Parent = model
    lump("Knob", ROCK_SIZE * Vector3.new(0.6, 0.65, 0.55), Vector3.new(6, 3, -3), ROCK:Lerp(FROST, 0.3), Enum.Material.Slate).Parent = model
    lump("Knob", ROCK_SIZE * Vector3.new(0.5, 0.55, 0.6), Vector3.new(-5, -3, 4), FROST:Lerp(ROCK, 0.25), Enum.Material.Ice).Parent = model
    model.PrimaryPart = rock
    local trail = Instance.new("ParticleEmitter")
    trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    trail.Rate, trail.Lifetime, trail.Speed = 40, NumberRange.new(1, 2), NumberRange.new(0, 2)
    trail.Size = NumberSequence.new(1.2, 0.2)
    trail.Transparency = NumberSequence.new(0.2, 1)
    trail.LightEmission, trail.LockedToPart = 0.8, false
    trail.Color = ColorSequence.new(Color3.fromRGB(230, 242, 255))
    trail.Parent = rock
    return model
end

-- A flash of light at `at` that fades out (the hit, the crash).
local function flash(folder, at, color, range, brightness, seconds)
    local holder = Instance.new("Part")
    holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
    holder.Size, holder.CFrame, holder.Parent = Vector3.one, CFrame.new(at), folder
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness, light.Shadows = color, range, brightness, false
    light.Parent = holder
    TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
    task.delay(seconds, function() holder:Destroy() end)
end

-- The top of an ellipsoid part (a Ball, or the map's stretched sphere meshes: lumps,
-- blobs, boulders) over (x, z), or nil. Worked out exactly: their collision shapes are
-- coarser than what's drawn, and a ray stopped by one would leave the UFO hovering.
local function ellipsoidTop(part, x, z)
    local radii = part.Size / 2
    local start = part.CFrame:PointToObjectSpace(Vector3.new(x, 0, z)) / radii
    local up = part.CFrame:VectorToObjectSpace(Vector3.yAxis) / radii
    local a, b, c = up:Dot(up), 2 * start:Dot(up), start:Dot(start) - 1
    local discriminant = b * b - 4 * a * c
    return discriminant >= 0 and (-b + math.sqrt(discriminant)) / (2 * a) or nil
end

-- The height for the UFO's centre that sets it, turned `rotation`, down on whatever lies
-- under it at `at` (x, z) without sinking in: points round its underside are dropped
-- onto the platform's rock, ice and boulders (ellipsoids worked out, anything else cast
-- down onto; scenery is mostly CanQuery off, so those parts are made queryable here for
-- the casts, locally, and put back).
local function settle(destination, at, rotation)
    local round, other = {}, {}
    for _, part in destination:GetDescendants() do
        if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "RingChunk" then
            local flat = Vector3.new(part.Position.X - at.X, 0, part.Position.Z - at.Z).Magnitude
            if flat < DIAMETER + part.Size.Magnitude / 2 then
                local ellipsoid = part:IsA("MeshPart") or (part:IsA("Part") and part.Shape == Enum.PartType.Ball)
                table.insert(ellipsoid and round or other, part)
            end
        end
    end
    local saved = {}
    for _, part in other do
        saved[part] = part.CanQuery
        part.CanQuery = true
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = other
    local height = -math.huge
    for _, sample in UNDERSIDE do
        for step = 0, sample[1] == 0 and 0 or 23 do
            local angle = step / 24 * math.pi * 2
            local offset = rotation * Vector3.new(math.cos(angle) * sample[1] * DIAMETER / 2, sample[2] * DIAMETER, math.sin(angle) * sample[1] * DIAMETER / 2)
            local x, z = at.X + offset.X, at.Z + offset.Z
            local ground = -math.huge
            local hit = Workspace:Raycast(Vector3.new(x, at.Y + 200, z), Vector3.new(0, -400, 0), params)
            if hit then ground = hit.Position.Y end
            for _, part in round do ground = math.max(ground, ellipsoidTop(part, x, z) or -math.huge) end
            height = math.max(height, ground - offset.Y)
        end
    end
    for part, value in saved do part.CanQuery = value end
    return height > -math.huge and height or at.Y + DIAMETER * 0.143
end

-- The camera jolt at the crash: `amount` 1 is a few tenths of a stud and a fraction of a degree.
local shakeAmount = 0
local function shakeCamera()
    if shakeAmount <= 0 or Settings.get("reducedEffects") then return end
    local camera = Workspace.CurrentCamera
    local a = shakeAmount
    camera.CFrame *= CFrame.new((math.random() - 0.5) * 0.5 * a, (math.random() - 0.5) * 0.5 * a, 0)
        * CFrame.Angles((math.random() - 0.5) * 0.012 * a, (math.random() - 0.5) * 0.012 * a, (math.random() - 0.5) * 0.008 * a)
end

local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function there()
    local root = rootPart()
    return root ~= nil and (root.Position - SPEC.position).Magnitude < NEAR
end

local function smoothstep(edge0, edge1, x)
    local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

-- Each arm's hands-on-head pose in the UFO's frame: { arm Angles x, y, z, forearm Angles
-- x, z }, solved against the mesh so each hand lands on the side of its head and the
-- whole arm stays under the canopy all the way in from rest. Pilot 2's mirror pilot 1's.
local HANDS_ON_HEAD = {
    ["Pilot1_-1"] = { 1.928, 0.074, 0.304, -0.614, -1.944 }, ["Pilot1_1"] = { 1.905, -0.33, -0.484, -0.761, 2.722 },
    ["Pilot2_-1"] = { 1.905, 0.33, 0.484, -0.761, -2.722 }, ["Pilot2_1"] = { 1.928, -0.074, -0.304, -0.614, 1.944 },
}
-- Once down the pilots freak out in a loop (pilot 2 4.5 s behind pilot 1): hands clamped on
-- their heads, shaking them (0-4.2 s), pounding the console, eyes darting (4-7.2 s), one
-- hand on the head and the other waving up for help (7-9 s).
local FREAK_CYCLE = 9
local function window(x, from, to)
    return smoothstep(from, from + 0.35, x) * (1 - smoothstep(to - 0.35, to, x))
end

-- The pilots: working the controls in flight, arms up and heads shaking from the hit until
-- just after the crash, then freaking out until the stay ends, trembling. t from UfoAt.
-- Their heads sit only ~6 cm (in the model's metres) under the canopy, so heads turn (yaw)
-- but barely nod and never roll, and the torsos stay put: every pose and blend here keeps
-- clear of the glass (checked against the mesh over the whole timeline).
local function animatePilots(bones, t, hitAt, touchAt)
    local panic = smoothstep(hitAt - 0.1, hitAt + 0.25, t) * (1 - smoothstep(touchAt + 0.3, touchAt + 0.9, t))
    local down = smoothstep(touchAt + 0.3, touchAt + 0.9, t)
    local since = t - touchAt
    for index = 1, 2 do
        local name, phase = "Pilot" .. index .. "_", index * 1.7
        local flying = 1 - math.max(panic, down)
        local cycle = since >= 0 and (since + (index - 1) * 4.5) % FREAK_CYCLE or 0
        local onHead = since >= 0 and math.max(window(cycle, 0, 4.2), smoothstep(FREAK_CYCLE - 0.35, FREAK_CYCLE, cycle)) or 0
        local pounding, waving = window(cycle, 4, 7.2), window(cycle, 7, FREAK_CYCLE)
        -- Head: yaw (shaking "no", darting looks), nod (up +) with a tremble.
        local yaw = flying * 0.15 * math.sin(t * 0.7 + phase) + panic * 0.45 * math.sin(t * 9 + phase)
            + down * (onHead * 0.32 * math.sin(since * 13 + phase) + pounding * 0.5 * math.tanh(3 * math.sin(since * 2.3 + phase)) + waving * 0.25)
        local nod = down * (0.03 * math.sin(t * 37 + phase) + waving * 0.08)
        pose(bones[name .. "Head"], CFrame.Angles(0, yaw, 0) * CFrame.Angles(nod, 0, 0))
        for side, arm in { "-1", "1" } do
            local hands = HANDS_ON_HEAD[name .. arm]
            local outer = (arm == "-1") == (index == 1)
            local flail = panic * (1.9 + 0.35 * math.sin(t * 13 + phase + side * 2))
            local pump = 0.45 + 0.6 * math.max(0, math.sin(since * 11 + side * math.pi))
            -- Waving: the outer arm reaches up and waves, the inner hand stays on the head.
            local x = down * (onHead * hands[1] + pounding * pump + waving * (outer and 2.1 or hands[1])) + flail
            local y = down * (onHead * hands[2] + waving * (outer and 0 or hands[2]))
            local z = down * (onHead * hands[3] + waving * (outer and 0 or hands[3]))
            local forearmX = down * (onHead * hands[4] + pounding * 0.25 * math.sin(since * 11 + side * math.pi) + waving * (outer and 0 or hands[4]))
                + flying * 0.12 * math.sin(t * 3 + phase + side)
            local forearmZ = down * (onHead * hands[5] + waving * (outer and 0.45 * math.sin(since * 9) or hands[5]))
            pose(bones[name .. arm .. "Arm"], CFrame.Angles(x, y, z))
            pose(bones[name .. arm .. "Forearm"], CFrame.Angles(forearmX, 0, forearmZ))
        end
    end
end

-- One crash, from the server's stamp `startAt`; returns when the stay ends (UfoAt
-- cleared or restamped) or this player leaves.
local function play(destination, startAt)
    local crash = destination:GetAttribute("UfoCrash")
    if typeof(crash) ~= "Vector3" or not template then return end
    local center = SPEC.position
    -- Where the asteroid hits: on the circle, out to the left of the crash site along X
    -- (the way the belt drifts there), so the knock carries it straight across to it.
    local rel = crash - center
    local hz = math.clamp(rel.Z * 1.45, -RADIUS * 0.9, RADIUS * 0.9)
    local position, hitAt = flightPath(center, center + Vector3.new(-math.sqrt(RADIUS * RADIUS - hz * hz), 0, hz))
    local touchAt = hitAt + FALL
    local hit = position(hitAt)
    local hitVelocity = (position(hitAt) - position(hitAt - 0.1)) / 0.1
    local knock = Vector3.new(crash.X - hit.X, 0, crash.Z - hit.Z).Unit
    local inward = Vector3.new(center.X - crash.X, 0, center.Z - crash.Z).Unit
    -- At rest: nosed over toward the platform, its rim on the rock there and its tail up
    -- over the edge, so the canopy and the pilots (facing the platform's centre) are in
    -- view; set down on the rock under it, touching but not sunk in.
    local restUp = (Vector3.yAxis * math.cos(REST_TILT) + inward * math.sin(REST_TILT)).Unit
    local restForward = (inward - restUp * inward:Dot(restUp)).Unit
    local restTurn = CFrame.lookAt(Vector3.zero, restForward, restUp)
    local rest = Vector3.new(crash.X, settle(destination, crash, restTurn) - 0.1, crash.Z)
    local restFrame = CFrame.new(rest) * restTurn
    local touchFlat = rest - knock * SKID
    local touch = Vector3.new(touchFlat.X, math.max(rest.Y, settle(destination, touchFlat, restTurn)), touchFlat.Z)
    local span = (touch - hit).Magnitude
    local fallPoints = { hit, hit + (hitVelocity.Unit + knock * 1.6).Unit * span * 0.4, touch + Vector3.new(0, 40, 0) - knock * span * 0.2, touch }
    local side = inward:Cross(Vector3.yAxis).Unit
    -- The asteroid: down the belt along `knock`, its front meeting the UFO's rim at the
    -- hit, then on its way, glancing up off the UFO and well clear of it as it falls.
    local rockDirection = (knock + Vector3.new(0, -0.1, 0)).Unit
    local contact = hit - rockDirection * (ROCK_SIZE.X / 2 + DIAMETER * 0.3) + Vector3.new(0, 5, 0)
    local rockAway = (rockDirection + Vector3.new(0, 0.4, 0)).Unit

    local folder = Instance.new("Folder")
    folder.Name = "SaturnUfo"
    folder.Parent = Workspace
    local model = template:Clone()
    local hull = model:FindFirstChild("UFOTitanium", true)
    model:ScaleTo(model:GetScale() * DIAMETER / math.max(hull.Size.X, hull.Size.Z))
    model:PivotTo(CFrame.new(position(0)))
    local bones = joints(model)
    local lights = { amber = model:FindFirstChild("UFOAmber", true), ion = model:FindFirstChild("UFOIon", true), coral = model:FindFirstChild("UFOCoral", true) }
    local lit = {}
    for key, part in lights do lit[key] = part and part.Color end
    model.Parent = folder
    -- Its voice and its smoke ride along at its centre.
    local voice = Instance.new("Part")
    voice.Name, voice.Anchored, voice.CanCollide, voice.CanQuery, voice.CanTouch = "UfoVoice", true, false, false, false
    voice.Transparency, voice.Size, voice.CFrame = 1, Vector3.one * 4, CFrame.new(position(0))
    voice.Parent = folder
    local smoke = Instance.new("ParticleEmitter")
    smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
    smoke.Speed, smoke.SpreadAngle = NumberRange.new(2, 6), Vector2.new(25, 25)
    -- Rising and drifting off the way the belt goes, so the wreck's plume leans.
    smoke.Acceleration, smoke.Drag = Vector3.new(3, 5, 0), 0.5
    smoke.Lifetime = NumberRange.new(2.5, 5)
    smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 14) })
    smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
    smoke.Color = ColorSequence.new(Color3.fromRGB(70, 70, 76), Color3.fromRGB(150, 150, 158))
    smoke.Rotation, smoke.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-30, 30)
    smoke.LightInfluence, smoke.Rate = 0.8, 0
    smoke.Parent = voice
    local embers = Instance.new("ParticleEmitter")
    embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    embers.Speed, embers.SpreadAngle = NumberRange.new(10, 30), Vector2.new(60, 60)
    embers.Acceleration = Vector3.new(0, -GRAVITY * 0.5, 0)
    embers.Lifetime = NumberRange.new(0.4, 1)
    embers.Size = NumberSequence.new(0.9, 0.1)
    embers.LightEmission, embers.Rate = 1, 0
    embers.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 120, 40))
    embers.Parent = voice
    local alarm = Instance.new("PointLight")
    alarm.Color, alarm.Range, alarm.Brightness, alarm.Enabled = Color3.fromRGB(255, 40, 30), 24, 0, true
    alarm.Parent = voice
    local rock = asteroid(destination)
    local bursts, fired = {}, {}
    local beeps

    local events = {
        { at = hitAt - ROCK_LEAD, run = function()
            rock.Parent = folder
        end },
        { at = hitAt, run = function(late)
            if late < 0.4 then
                -- The crash of rock on hull, from where they met (it stays there as the
                -- UFO careens off with the fly-by).
                local holder = Instance.new("Part")
                holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
                holder.Size, holder.CFrame, holder.Parent = Vector3.one, CFrame.new(hit + (contact - hit) * 0.5), folder
                local crack = Sfx.attach("ufoHit", holder)
                if crack then
                    crack.TimePosition = late
                    crack:Play()
                end
            end
            if late < 1 then
                local flyby = Sfx.attach("ufoFlyby", voice)
                if flyby then
                    flyby.TimePosition = late
                    flyby:Play()
                end
                table.insert(bursts, burst(folder, hit + (contact - hit) * 0.5, "ice"))
                flash(folder, hit, Color3.fromRGB(255, 200, 140), 70, 6, 0.5)
            end
            smoke.Rate = 40
            embers.Rate = 25
        end },
        { at = touchAt, run = function(late)
            if late < 0.6 then
                local impact = Sfx.attach("ufoImpact", voice)
                if impact then
                    impact.TimePosition = late
                    impact:Play()
                end
                table.insert(bursts, burst(folder, Vector3.new(touch.X, crash.Y + 1, touch.Z) + inward * DIAMETER * 0.4, "rock", crash.Y - 3))
                flash(folder, touch, Color3.fromRGB(255, 170, 90), 90, 8, 0.8)
                local root = rootPart()
                local distance = root and (root.Position - touch).Magnitude or math.huge
                shakeAmount = math.max(shakeAmount, 1.6 * math.clamp(1 - distance / 260, 0, 1))
            end
            smoke.Rate = 14
            embers.Rate = 0
            -- Rubble thrown up in front of its nose, where it came down, staying with the
            -- wreck (inside its wall, on the platform's top).
            local random = Random.new(7)
            for _ = 1, 9 do
                local spread = inward * random:NextNumber(DIAMETER * 0.42, DIAMETER * 0.55) + side * random:NextNumber(-10, 10)
                local size = random:NextNumber(1.2, 3.5)
                local slab = Instance.new("Part")
                slab.Anchored, slab.CanCollide, slab.CanQuery, slab.CanTouch, slab.CastShadow = true, false, false, false, true
                slab.Material, slab.Color = Enum.Material.Slate, ROCK:Lerp(Color3.fromRGB(60, 62, 70), random:NextNumber(0, 0.6))
                slab.Size = Vector3.new(size * 1.4, size * 0.7, size)
                slab.CFrame = CFrame.new(Vector3.new(rest.X, crash.Y + size * 0.2, rest.Z) + spread)
                    * CFrame.Angles(random:NextNumber(-0.6, 0.6), random:NextNumber(0, 6.28), random:NextNumber(-0.6, 0.6))
                slab.Parent = folder
            end
            -- An invisible wall round the wreck, far too tall to get onto: nobody climbs it
            -- (and off over the rim, where it hangs past the platform's own fence).
            local barrier = Instance.new("Part")
            barrier.Name, barrier.Shape = "UfoBarrier", Enum.PartType.Cylinder
            barrier.Anchored, barrier.CanCollide, barrier.CanTouch, barrier.CastShadow, barrier.Transparency = true, true, false, false, 1
            barrier.Size = Vector3.new(BARRIER_HEIGHT, DIAMETER + 3, DIAMETER + 3)
            barrier.CFrame = CFrame.new(rest.X, crash.Y + BARRIER_HEIGHT / 2 - 1, rest.Z) * CFrame.Angles(0, 0, math.rad(90))
            barrier.Parent = folder
        end },
        { at = touchAt + SKID_TIME, run = function()
            beeps = Sfx.attach("ufoBeeps", voice)
            if beeps then
                beeps.TimePosition = math.random() * 10
                beeps:Play()
            end
        end },
        { at = hitAt + ROCK_LEAD, run = function()
            rock:Destroy()
        end },
    }

    local finished = false
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        local t = Workspace:GetServerTimeNow() - startAt
        if not there() or destination:GetAttribute("UfoAt") ~= startAt then
            finished = true
            return
        end
        for index, event in events do
            if not fired[index] and t >= event.at then
                fired[index] = true
                event.run(t - event.at)
            end
        end
        shakeAmount = math.max(0, shakeAmount - dt * 1.4)
        for _, item in bursts do stepBurst(item, dt) end

        -- The UFO.
        local frame
        if t < hitAt then
            local at = position(t)
            local velocity = position(t + 0.05) - position(t - 0.05)
            local forward = Vector3.new(velocity.X, 0, velocity.Z)
            forward = forward.Magnitude > 1e-3 and forward.Unit or Vector3.new(0, 0, -1)
            local toward = Vector3.new(center.X - at.X, 0, center.Z - at.Z).Unit
            local up = (Vector3.yAxis + toward * math.tan(BANK) + Vector3.new(math.sin(t * 1.3), 0, math.cos(t * 1.1)) * 0.04).Unit
            frame = CFrame.lookAt(at, at + forward, up)
        elseif t < touchAt then
            local u = (t - hitAt) / FALL
            local spin = -math.pi * 2 * SPIN_TURNS * (1 - u) ^ 1.6
            local wobble = 0.35 * math.sin(math.pi * u)
            local tumbling = restFrame.Rotation * CFrame.Angles(wobble * math.sin(u * 17), spin, wobble * math.cos(u * 13))
            local flying = CFrame.lookAt(Vector3.zero, Vector3.new(hitVelocity.X, 0, hitVelocity.Z).Unit, Vector3.yAxis)
            frame = CFrame.new(bezier(fallPoints[1], fallPoints[2], fallPoints[3], fallPoints[4], u)) * flying:Lerp(tumbling, math.min(1, u * 5))
        else
            -- Skidding to a stop, bouncing and rocking as it settles (lifted by however
            -- far the rocking tips its rim, so it never dips into the rock).
            local since = t - touchAt
            local slide = 1 - (1 - math.min(since / SKID_TIME, 1)) ^ 2
            local rocking = 0.1 * math.exp(-3 * since) * math.sin(10 * since)
            local bounce = 1.5 * math.exp(-4 * since) * math.abs(math.sin(8 * since)) + math.abs(rocking) * DIAMETER / 2
            frame = CFrame.new(touch:Lerp(rest, slide) + Vector3.new(0, bounce, 0)) * CFrame.fromAxisAngle(side, rocking) * restFrame.Rotation
        end
        model:PivotTo(frame)
        voice.CFrame = CFrame.new(frame.Position)
        animatePilots(bones, t, hitAt, touchAt)

        -- Lights: steady in flight; flickering from the hit; once down the ion ring is
        -- mostly dark, the running lights stutter and a red alarm pulses.
        local damaged = t >= hitAt
        local down = t >= touchAt
        local function set(key, on, dim)
            local part = lights[key]
            if part then
                part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
                part.Color = on and lit[key] or lit[key]:Lerp(Color3.new(0, 0, 0), dim)
            end
        end
        set("amber", not damaged or math.noise(t * 7, 1.3) > (down and 0.05 or -0.25), 0.6)
        set("ion", not damaged or math.noise(t * 9, 4.7) > (down and 0.35 or -0.1), 0.75)
        set("coral", not down or (t * 1.25) % 1 < 0.5, 0.5)
        alarm.Brightness = down and 2.5 * math.max(0, math.sin(t * math.pi * 1.25)) or 0
        if down and math.random() < dt * 0.6 then embers:Emit(math.random(6, 14)) end

        -- The asteroid.
        if rock.Parent then
            local since = t - hitAt
            local at = since < 0 and contact + rockDirection * ROCK_SPEED * since or contact + rockAway * ROCK_SPEED * 0.85 * since
            rock:PivotTo(CFrame.new(at) * CFrame.Angles(t * 0.9, t * 0.6 + math.max(0, since) * 2, t * 0.4))
        end
    end)
    RunService:BindToRenderStep("SaturnUfoShake", Enum.RenderPriority.Camera.Value + 2, shakeCamera)
    while not finished do task.wait(0.2) end
    connection:Disconnect()
    RunService:UnbindFromRenderStep("SaturnUfoShake")
    shakeAmount = 0
    if beeps then beeps:Stop() end
    folder:Destroy()
    rock:Destroy()
end

function SaturnUfoController.start()
    template = ReplicatedStorage:WaitForChild("SaturnUFO", 60)
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
        local startAt = folder:GetAttribute("UfoAt")
        if playing or type(startAt) ~= "number" or not there() then return end
        playing = true
        task.spawn(function()
            play(folder, startAt)
            playing = false
        end)
    end
    folder:GetAttributeChangedSignal("UfoAt"):Connect(check)
    -- Arriving (or rejoining) partway through still catches the rest of it, or the wreck.
    while true do
        task.wait(1)
        check()
    end
end

return SaturnUfoController
