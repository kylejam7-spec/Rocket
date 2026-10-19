-- Builds the rocket cabin (where boarded players wait for liftoff) and one isolated
-- destination per rocket design (Config.Destinations, by ModelTier), far from the
-- main map. Primitives only; Phase 5 swaps in art and sky. Each destination has a
-- walled play area, an ArrivalPad tagged DestinationArrival (attribute Tier), two
-- gym spots (WorldService puts a bench and a treadmill there), a UFO Shop spot
-- (WorldService builds it, right of the arrival facing it) and a landing spot
-- behind the welcome sign, where the rocket touches down (LaunchService).
local CollectionService = game:GetService("CollectionService")
local Signs = require(script.Parent.SignService)
local Mountains = require(script.Parent.Mountains)
local Planets = require(script.Parent.Planets)
local Missions = require(game:GetService("ReplicatedStorage").Shared.Missions)
local Destinations = {}
Destinations.ArrivalTag = "DestinationArrival"
Destinations.CabinTag = "RocketCabin"

local function make(parent, name, props)
    local item = Instance.new(props.ClassName or "Part")
    item.Name = name
    item.Anchored = true
    item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for key, value in props do
        if key ~= "ClassName" then item[key] = value end
    end
    item.Parent = parent
    return item
end
-- Decor never blocks, touches or gets hit by raycasts.
local function decor(parent, name, props)
    local item = make(parent, name, props)
    item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = false, false, false, false
    return item
end
-- A flat round ground: cylinders lie along X, so turn it upright.
local function disc(parent, name, center, radius, thickness, color, material)
    return make(parent, name, {
        Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, radius * 2, radius * 2),
        CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material or Enum.Material.Slate,
    })
end
-- Invisible walls in a ring so nobody falls off a destination.
local function fence(parent, center, radius, height)
    for index = 1, 24 do
        local angle = index / 24 * math.pi * 2
        local position = center + Vector3.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
        make(parent, "Fence", {
            Size = Vector3.new(2, height, radius * 2 * math.sin(math.pi / 24) + 2), Transparency = 1, CanQuery = false,
            CFrame = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)) * CFrame.Angles(0, math.rad(90), 0),
        })
    end
end
-- What surrounds a destination's platform (radius `radius`), so it reads as a place on
-- a world rather than a disc in space: a rim of crags just outside the invisible fence,
-- a plain a few studs lower out to `look.reach`, strewn with boulders, and a continuous
-- ring of mountains (look.ring, Mountains.ring) closing the horizon inside the plain's
-- edge, low enough to leave the backdrop planet in view.
-- Optional, for worlds that should read as worn rather than jagged (the Moon):
-- look.ridge (a smooth wall of sunk balls instead of the crags: true for crag-coloured,
-- or { color, material }), look.round
-- (rounded boulders), look.craters (count of rimmed bowls carved into the plain, which is
-- then look.plainDepth thick), look.overlays ({ texture key, studs per tile, transparency? } over
-- the plain; a 4th entry tints it), look.farRing (a second, taller mountain row behind
-- the first), look.keep(offset) (false leaves out the crag or boulder there, e.g. over a
-- canyon), look.cut(plain) (returns the plain with more cut out of it) and look.horizon
-- (builds the skyline instead of look.ring).
local function surroundings(parent, center, radius, look)
    local random = Random.new(look.seed)
    if look.ridge then
        local ridge = look.ridge == true and { color = look.crag, material = look.cragMaterial } or look.ridge
        local count = math.floor(radius * 0.55)
        for index = 1, count do
            local angle = (index + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
            local width = random:NextNumber(18, 26)
            local at = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + width * 0.5)
            local height, color = random:NextNumber(4, 7.5), ridge.color:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.06))
            if not look.keep or look.keep(at - center) then
                Planets.mound(parent, "CraterWall", at, width, height, color, ridge.material)
            end
        end
    else
        local corner = CFrame.fromAxisAngle(Vector3.new(-1, 0, 1).Unit, math.acos(1 / math.sqrt(3)))
        local count = math.floor(radius * 0.42)
        for index = 1, count do
            local angle = (index + random:NextNumber(-0.25, 0.25)) / count * math.pi * 2
            local size = random:NextNumber(10, 19)
            local at = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + size * 0.35)
            local color = look.crag:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.18))
            local spin = random:NextNumber(0, 6.28)
            if not look.keep or look.keep(at - center) then
                decor(parent, "RimCrag", { Size = Vector3.one * size, Color = color, Material = look.cragMaterial,
                    CFrame = CFrame.new(at - Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(0, spin, 0) * corner })
            end
        end
    end
    -- The plain's top stays 3 below the platform however thick it is.
    local depth = look.plainDepth or 4
    local plain = disc(parent, "Plain", center - Vector3.new(0, 3 + depth / 2, 0), look.reach, depth, look.ground, look.material)
    plain.CanCollide = false
    if look.craters then
        local bowls = {}
        for _ = 1, look.craters * 4 do
            if #bowls >= look.craters then break end
            local size = random:NextNumber(18, 85)
            local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(radius + 50 + size, look.ring.radius - look.ring.spread - size * 1.4)
            local at = center + Vector3.new(math.cos(angle) * distance, -3, math.sin(angle) * distance)
            local free = true
            for _, bowl in bowls do
                if (bowl.at - at).Magnitude < (bowl.radius + size) * 1.35 then free = false end
            end
            if free then table.insert(bowls, { at = at, radius = size, depth = math.min(size * 0.2, depth - 2), rim = size * random:NextNumber(0.08, 0.14) }) end
        end
        plain = Planets.carve(plain, bowls, false)
        for _, bowl in bowls do
            if bowl.radius > 55 then
                Planets.mound(parent, "CentralPeak", bowl.at - Vector3.new(0, bowl.depth, 0), bowl.radius * 0.22, bowl.depth + bowl.radius * 0.06, look.crag, look.cragMaterial)
            end
        end
    end
    if look.cut then plain = look.cut(plain) end
    for _, overlay in look.overlays or {} do
        Planets.overlay(plain, Enum.NormalId.Right, overlay[1], overlay[2], overlay[3], overlay[4])
    end
    local function mountain(folder, name, size, cframe, color, material, shape)
        return decor(folder, name, { Shape = shape or Enum.PartType.Block, Size = size, CFrame = cframe, Color = color, Material = material })
    end
    if look.ring then Mountains.ring(parent, center - Vector3.new(0, 3, 0), look.ring, mountain) end
    -- A taller second row behind (look.farRing) layers the skyline.
    if look.farRing then Mountains.ring(parent, center - Vector3.new(0, 3, 0), look.farRing, mountain) end
    if look.horizon then look.horizon(parent) end
    for _ = 1, 14 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(radius + 60, look.reach * 0.8)
        local size = random:NextNumber(14, 40)
        local at = center + Vector3.new(math.cos(angle) * distance, size * 0.15 - 3, math.sin(angle) * distance)
        if look.keep and not look.keep(at - center) then
            continue
        elseif look.round then
            Planets.boulder(parent, at - Vector3.new(0, size * 0.15, 0), size, look.crag, look.cragMaterial, random, false)
        else
            decor(parent, "Boulder", { Size = Vector3.new(size * 1.4, size, size * 1.1), Color = look.crag, Material = look.cragMaterial,
                CFrame = CFrame.new(at) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6.28), random:NextNumber(-0.3, 0.3)) })
        end
    end
end
-- The welcome sign stands on posts out to the left of the arrival pad, turned toward it:
-- clear of the landed rocket (behind the pad, up to 68 studs wide), the gym, the UFO shop
-- and every destination's set pieces (scatter keeps off it too, CLEAR).
Destinations.SignOffset = Vector3.new(-56, 0, 18)
local ICONS = { Moon = "🌕", Mars = "🔴", Europa = "🧊", Saturn = "🪐", BlackHole = "🌀" }
local function sign(parent, center, arrivalOffset, spec, rarity)
    local at = center + Destinations.SignOffset + Vector3.new(0, 10, 0)
    local toward = center + arrivalOffset + Vector3.new(0, 10, 0)
    return Signs.board(parent, "WelcomeSign", CFrame.lookAt(at, toward), Vector2.new(24, 7), {
        title = "WELCOME TO " .. spec.name .. "!", subtitle = rarity and rarity:upper() .. " DESTINATION" or nil,
        icon = ICONS[spec.id], accent = spec.color, ground = center.Y,
    })
end
local function arrival(parent, position, tier, color)
    local pad = make(parent, "ArrivalPad", {
        Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 18, 18), Color = color, Material = Enum.Material.Neon,
        Transparency = 0.4, CanCollide = false, CanQuery = false, CanTouch = false,
        CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
    })
    pad:SetAttribute("Tier", tier)
    CollectionService:AddTag(pad, Destinations.ArrivalTag)
    return pad
end
-- Every destination keeps these clear (offsets from its centre, with a radius): the
-- gym (bench left, treadmill right of the arrival), the arrival itself and the landing
-- spot. The widest rocket (tier 5) spans 68 x 32 studs, and every rocket fits its own
-- destination's ground there.
Destinations.GymOffsets = { bench = Vector3.new(-28, 0, 24), treadmill = Vector3.new(28, 0, 24) }
Destinations.LandingOffset = Vector3.new(0, 0, -42)
Destinations.ShopOffset = Vector3.new(38, 0, -4)
local CLEAR = { { Destinations.GymOffsets.bench, 14 }, { Destinations.GymOffsets.treadmill, 14 }, { Vector3.new(0, 0, 18), 14 },
    { Destinations.LandingOffset, 30 }, { Destinations.ShopOffset, 14 }, { Destinations.SignOffset, 16 } }
-- A coloured band around a planet ball: a thin disc through it at `height`, just wider
-- than the planet there. (Ball parts are always round, so bands can't be squashed balls.)
local function band(parent, name, center, radius, height, thickness, color)
    local width = 2 * math.sqrt(math.max(0, radius * radius - height * height)) + 6
    return decor(parent, name, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, width, width),
        CFrame = CFrame.new(center + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color })
end
-- Deterministic scatter so every server builds the same destination; skips the clear spots.
local function scatter(seed, count, radius, fn)
    local random = Random.new(seed)
    for index = 1, count do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(0.25, 0.9) * radius
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local blocked = false
        for _, spot in CLEAR do
            if (offset - spot[1]).Magnitude < spot[2] then blocked = true end
        end
        if not blocked then fn(index, offset, random) end
    end
end

local builders = {}
-- 1 (Common): the floor of an old crater on the Moon. Bowl craters carved into the
-- ground with soft raised rims, rounded boulders, an Apollo-style lander with a blinking
-- beacon, a flag and boot prints between them, and moon dust hanging in the light. A low
-- crater wall rings the platform; beyond it a cratered plain with dark seas runs out to
-- worn, rounded highlands, and a textured, cloudy Earth turns overhead.
-- The sun stands low (Shared.Skies "Moon"), so every rim and rock throws a long shadow.
local MOON = { regolith = Color3.fromRGB(166, 166, 170), rock = Color3.fromRGB(128, 128, 134), foil = Color3.fromRGB(222, 170, 60),
    metal = Color3.fromRGB(196, 198, 204), dark = Color3.fromRGB(46, 48, 56) }
Destinations.LanderOffset = Vector3.new(-18, 0, -16)
local FLAG_OFFSET = Vector3.new(14, 0, -10)
local EXPERIMENT_OFFSET = Vector3.new(22, 0, 4)
-- True if a feature `reach` wide at `offset` keeps off every clear spot, the given props
-- ({ offset, radius }) and the platform's edge.
local function isClear(offset, reach, props)
    for _, spot in CLEAR do
        if (offset - spot[1]).Magnitude < spot[2] + reach then return false end
    end
    for _, prop in props do
        if (offset - prop[1]).Magnitude < prop[2] + reach then return false end
    end
    return offset.Magnitude + reach < 72
end
local MOON_PROPS = { { Destinations.LanderOffset, 8 }, { FLAG_OFFSET, 4 }, { EXPERIMENT_OFFSET, 5 } }
local function moonClear(offset, reach)
    return isClear(offset, reach, MOON_PROPS)
end
-- A strut between two points.
local function strut(parent, name, a, b, thickness, color, material)
    return decor(parent, name, { Size = Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = material or Enum.Material.Metal })
end
local function lander(parent, at)
    local model = Instance.new("Model")
    model.Name = "Lander"
    model.Parent = parent
    -- Descent stage: an octagon of gold foil (two boxes, one turned 45 degrees).
    for _, turn in { 0, 45 } do
        make(model, "DescentStage", { Size = Vector3.new(7, 3.4, 7), CFrame = CFrame.new(at + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, math.rad(turn), 0), Color = MOON.foil, Material = Enum.Material.Foil })
    end
    decor(model, "EngineBell", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2.2, 2.2), CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = MOON.dark, Material = Enum.Material.Metal })
    for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
        local top, foot = at + corner * 3.2 + Vector3.new(0, 4.4, 0), at + corner * 5.4 + Vector3.new(0, 0.3, 0)
        strut(model, "LanderLeg", top, foot, 0.4, MOON.metal)
        strut(model, "LegBrace", at + corner * 3.3 + Vector3.new(0, 2, 0), foot + Vector3.new(0, 0.6, 0) - corner * 0.4, 0.22, MOON.metal)
        decor(model, "FootPad", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.8, 1.8), CFrame = CFrame.new(foot) * CFrame.Angles(0, 0, math.rad(90)), Color = MOON.metal, Material = Enum.Material.Metal })
    end
    -- Ladder on the side toward the flag.
    for step = 1, 5 do
        decor(model, "LadderRung", { Size = Vector3.new(0.12, 0.12, 1.1), CFrame = CFrame.new(at + Vector3.new(4.6 - step * 0.2, 0.4 + step * 0.65, 0)), Color = MOON.metal, Material = Enum.Material.Metal })
    end
    -- Ascent stage: a faceted silver cabin with two dark windows facing the arrival.
    local cabin = make(model, "AscentStage", { Size = Vector3.new(5.2, 3.4, 4.6), CFrame = CFrame.new(at + Vector3.new(0, 6.8, 0)), Color = MOON.metal, Material = Enum.Material.Metal })
    make(model, "AscentFront", { ClassName = "WedgePart", Size = Vector3.new(5.2, 2.4, 1.6), CFrame = cabin.CFrame * CFrame.new(0, -0.5, 3.1), Color = Color3.fromRGB(176, 178, 186), Material = Enum.Material.Metal })
    for _, side in { -1, 1 } do
        decor(model, "Window", { Size = Vector3.new(1.3, 1, 0.12), CFrame = cabin.CFrame * CFrame.new(side * 1.3, 0.9, 2.31) * CFrame.Angles(0, 0, side * 0.35), Color = MOON.dark, Material = Enum.Material.Glass })
        -- Thruster quads on the cabin's sides.
        decor(model, "Thrusters", { Size = Vector3.new(0.9, 0.9, 0.9), CFrame = cabin.CFrame * CFrame.new(side * 3, 1, 0) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(150, 152, 160), Material = Enum.Material.Metal })
    end
    decor(model, "DockingHatch", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.8, 1.8), CFrame = cabin.CFrame * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = MOON.metal, Material = Enum.Material.Metal })
    strut(model, "AntennaMast", cabin.Position + Vector3.new(-1.6, 1.7, -1.2), cabin.Position + Vector3.new(-2.2, 4.2, -1.8), 0.15, MOON.metal)
    decor(model, "AntennaDish", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2, 2), CFrame = CFrame.new(cabin.Position + Vector3.new(-2.2, 4.3, -1.8)) * CFrame.Angles(0.5, 0.6, math.rad(70)), Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.SmoothPlastic })
    local beacon = decor(model, "Beacon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = CFrame.new(cabin.Position + Vector3.new(1.4, 2.2, -1.2)), Color = Color3.fromRGB(255, 60, 50), Material = Enum.Material.Neon })
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = beacon.Color, 10, 2
    light.Parent = beacon
    beacon:SetAttribute("Period", 1.6)
    CollectionService:AddTag(beacon, "Blinker")
end
local function flag(parent, at)
    make(parent, "FlagPole", { Size = Vector3.new(0.3, 11, 0.3), CFrame = CFrame.new(at + Vector3.new(0, 5.5, 0)), Color = Color3.fromRGB(230, 230, 230), Material = Enum.Material.Metal })
    -- No air to fly it: a rod along the top holds it out, and it keeps the creases it
    -- was packed with (three panels at slight angles).
    decor(parent, "FlagRod", { Size = Vector3.new(6, 0.14, 0.14), CFrame = CFrame.new(at + Vector3.new(3, 10.7, 0)), Color = Color3.fromRGB(230, 230, 230), Material = Enum.Material.Metal })
    for index, lean in { 0.12, -0.1, 0.08 } do
        decor(parent, "Flag", { Size = Vector3.new(2, 3.8, 0.08), CFrame = CFrame.new(at + Vector3.new(index * 2 - 1, 8.75, 0)) * CFrame.Angles(0, lean, 0), Color = Color3.fromRGB(215, 45, 45), Material = Enum.Material.SmoothPlastic })
    end
end
-- A small science station: a foil box with two solar wings and a dish.
local function experiment(parent, at)
    make(parent, "Experiment", { Size = Vector3.new(1.6, 1.2, 1.6), CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)), Color = MOON.foil, Material = Enum.Material.Foil })
    for _, side in { -1, 1 } do
        decor(parent, "SolarWing", { Size = Vector3.new(2.6, 0.1, 1.5), CFrame = CFrame.new(at + Vector3.new(side * 2.1, 1.1, 0)) * CFrame.Angles(0, 0, side * -0.25), Color = Color3.fromRGB(40, 60, 130), Material = Enum.Material.Glass })
    end
    strut(parent, "ExperimentMast", at + Vector3.new(0, 1.2, 0), at + Vector3.new(0, 2.6, 0), 0.1, MOON.metal)
    decor(parent, "ExperimentDish", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1, 1), CFrame = CFrame.new(at + Vector3.new(0, 2.65, 0)) * CFrame.Angles(0, 0.4, math.rad(60)), Color = Color3.fromRGB(235, 235, 240) })
end
-- Boot prints along a path, alternating feet, skipping anything over a bowl.
local function prints(parent, from, to, bowls)
    local step = (to - from) * Vector3.new(1, 0, 1)
    local count = math.floor(step.Magnitude / 1.6)
    local across = Vector3.new(-step.Z, 0, step.X).Unit
    for index = 1, count do
        local at = from + step * (index / count) + across * (index % 2 == 0 and 0.45 or -0.45)
        local inBowl = false
        for _, bowl in bowls do
            if ((at - bowl.at) * Vector3.new(1, 0, 1)).Magnitude < bowl.radius * 1.5 + 1 then inBowl = true end
        end
        if not inBowl then
            decor(parent, "BootPrint", { Size = Vector3.new(0.5, 0.04, 1), CFrame = CFrame.lookAt(at + Vector3.new(0, 0.02, 0), at + step + Vector3.new(0, 0.02, 0)), Color = Color3.fromRGB(122, 122, 128), Material = Enum.Material.Slate })
        end
    end
end
builders[1] = function(folder, c)
    local random = Random.new(2)
    folder:SetAttribute("Dust", Color3.fromRGB(196, 196, 202))
    folder:SetAttribute("Meteors", true)
    -- Thick enough for bowls three studs deep.
    local ground = disc(folder, "Regolith", c - Vector3.new(0, 3, 0), 75, 6, MOON.regolith, Enum.Material.Slate)
    local bowls = {}
    for _ = 1, 200 do
        if #bowls >= 8 then break end
        local radius = random:NextNumber(4.5, 10)
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(0, 70)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local free = moonClear(offset, radius * 1.5)
        for _, bowl in bowls do
            if (bowl.at - c - offset).Magnitude < (bowl.radius + radius) * 1.5 then free = false end
        end
        if free then table.insert(bowls, { at = c + offset, radius = radius, depth = math.min(3, radius * 0.3), rim = math.min(1.4, radius * 0.15) }) end
    end
    ground = Planets.carve(ground, bowls, true)
    Planets.overlay(ground, Enum.NormalId.Right, "MoonRegolith", 36)
    -- Rounded rocks in what room is left.
    for _ = 1, 60 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 70)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local size = random:NextNumber(1.5, 4.5)
        local free = moonClear(offset, size)
        for _, bowl in bowls do
            if (bowl.at - c - offset).Magnitude < bowl.radius * 1.5 + size then free = false end
        end
        if free then Planets.boulder(folder, c + offset, size, MOON.rock, Enum.Material.Slate, random, true) end
    end
    lander(folder, c + Destinations.LanderOffset)
    flag(folder, c + FLAG_OFFSET)
    experiment(folder, c + EXPERIMENT_OFFSET)
    prints(folder, c + Destinations.LanderOffset + Vector3.new(5.5, 0, 0), c + FLAG_OFFSET - Vector3.new(1, 0, 0), bowls)
    prints(folder, c + FLAG_OFFSET + Vector3.new(1, 0, 1), c + EXPERIMENT_OFFSET - Vector3.new(1, 0, 1), bowls)
    -- Dust kicked up long ago, still settling: faint specks drifting in the sunlight.
    local haze = decor(folder, "DustHaze", { Size = Vector3.new(140, 6, 140), CFrame = CFrame.new(c + Vector3.new(0, 4, 0)), Transparency = 1 })
    local motes = Instance.new("ParticleEmitter")
    motes.Shape = Enum.ParticleEmitterShape.Box
    motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    motes.Rate, motes.Lifetime = 14, NumberRange.new(6, 10)
    motes.Speed, motes.SpreadAngle = NumberRange.new(0.2, 0.8), Vector2.new(180, 180)
    motes.Acceleration = Vector3.new(0, -0.08, 0)
    motes.Size = NumberSequence.new(0.12, 0.22)
    motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
    motes.LightEmission, motes.LightInfluence = 0.6, 0.4
    motes.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
    motes.Parent = haze
    -- Earth rises over the highlands beyond the landing site, half in sunlight, low
    -- enough to sit in the default camera's view (its lower edge can dip behind the
    -- tallest hills: an earthrise).
    Planets.globe(folder, "Earth", { center = c + Vector3.new(300, 290, -760), diameter = 260, texture = "Earth",
        atmosphere = Color3.fromRGB(110, 175, 255), glow = 0.1, tilt = 23, spin = 0.025, color = Color3.fromRGB(50, 120, 220) })
    surroundings(folder, c, 75, { seed = 11, reach = 1000, ridge = true, round = true, craters = 12, plainDepth = 20,
        overlays = { { "MoonMaria", 520 }, { "MoonRegolith", 120, 0.35 } },
        ring = { radius = 690, spread = 140, count = 30, size = { 140, 320 }, dome = true, rock = Color3.fromRGB(150, 150, 156), rockAlt = Color3.fromRGB(118, 118, 126), material = Enum.Material.Slate, seed = 21 },
        farRing = { radius = 900, spread = 60, count = 26, size = { 260, 410 }, dome = true, rock = Color3.fromRGB(136, 136, 144), rockAlt = Color3.fromRGB(112, 112, 120), material = Enum.Material.Slate, seed = 31 },
        ground = Color3.fromRGB(150, 150, 156), material = Enum.Material.Slate, crag = MOON.rock, cragMaterial = Enum.Material.Slate })
    fence(folder, c, 75, 60)
    return ground, Vector3.new(0, 0, 20)
end
-- 2 (Uncommon): a base on the rim of a great canyon on Mars. Beyond the landing site the
-- ground drops away in banded terraces to a canyon floor with buttes and dunes; layered
-- mesas close the horizon and dunes ripple across the plain. The base: white habitat
-- domes, a glowing greenhouse, solar panels, a mast with a beacon, a six-wheeled rover
-- with its tracks, and a little helicopter hovering on spinning rotors. Dust devils
-- wander the plain, dust blows across the platform, and Phobos and Deimos cross the
-- butterscotch sky (Shared.Skies "Mars": warm, hazy afternoon light).
local MARS = { dust = Color3.fromRGB(178, 90, 54), sand = Color3.fromRGB(198, 112, 68), rock = Color3.fromRGB(118, 58, 40), dark = Color3.fromRGB(82, 44, 34),
    hull = Color3.fromRGB(236, 232, 226), trim = Color3.fromRGB(150, 152, 160), panel = Color3.fromRGB(34, 48, 100), metal = Color3.fromRGB(190, 192, 198),
    beds = { Color3.fromRGB(150, 72, 44), Color3.fromRGB(186, 108, 64), Color3.fromRGB(204, 142, 94), Color3.fromRGB(124, 60, 40), Color3.fromRGB(170, 92, 56) } }
-- The canyon runs along X beyond the landing site: its near rim this far toward -Z from
-- the centre, stepping down in terraces (each narrower and deeper, centred on the first).
local CANYON = { rim = 95, reach = 840, steps = { { width = 420, depth = 36 }, { width = 350, depth = 76 }, { width = 270, depth = 114 } } }
-- How far below the plain's top the canyon floor is at `offset` (0 off the canyon).
local function canyonDepth(offset)
    local depth = 0
    for _, step in CANYON.steps do
        local near = CANYON.rim + (CANYON.steps[1].width - step.width) / 2
        if -offset.Z > near and -offset.Z < near + step.width and math.abs(offset.X) < CANYON.reach then depth = step.depth end
    end
    return depth
end
-- Off the canyon and its near rim (the plain's crags and boulders keep off it, and the
-- rim stays open so the platform looks down into it).
local function offCanyon(offset)
    return not (offset.Z < -(CANYON.rim - 30) and offset.Z > -(CANYON.rim + CANYON.steps[1].width + 30) and math.abs(offset.X) < CANYON.reach + 30)
end
local function canyonCut(c)
    return function(plain)
        local cutters = {}
        for _, step in CANYON.steps do
            local near = CANYON.rim + (CANYON.steps[1].width - step.width) / 2
            local box = Instance.new("Part")
            box.Anchored = true
            box.Size = Vector3.new(CANYON.reach * 2, step.depth + 100, step.width)
            box.CFrame = CFrame.new(c.X, c.Y - 3 - step.depth + box.Size.Y / 2, c.Z - near - step.width / 2)
            table.insert(cutters, box)
        end
        plain = Planets.subtract(plain, cutters, false)
        -- Banded rock on every wall (the plain is a disc on its side: its other four
        -- faces look sideways).
        for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Top, Enum.NormalId.Bottom } do
            Planets.overlay(plain, face, "MarsStrata", 60)
        end
        return plain
    end
end
-- A flat-topped mesa: a broad talus apron, then beds of rock stepping in as they rise,
-- under a darker caprock. Its outline is two or three overlapping lobes of different
-- heights (one bed colour per layer across all of them, so the strata line up), so none
-- reads as a plain drum.
local function mesa(parent, base, radius, height, random)
    -- A low apron of fallen rock, the colour of the ground it spreads onto.
    Planets.mound(parent, "Talus", base, radius * 1.4, height * 0.22, MARS.dust:Lerp(MARS.rock, 0.15), Enum.Material.Sand)
    local layers = random:NextInteger(3, 5)
    local colors = {}
    for index = 1, layers do colors[index] = MARS.beds[random:NextInteger(1, #MARS.beds)] end
    for lobe = 1, random:NextInteger(2, 3) do
        local shift = lobe == 1 and Vector3.zero or Vector3.new(random:NextNumber(-0.5, 0.5), 0, random:NextNumber(-0.5, 0.5)) * radius
        local r = radius * (lobe == 1 and 1 or random:NextNumber(0.5, 0.8))
        local top = height * (lobe == 1 and 1 or random:NextNumber(0.7, 0.95))
        for index = 1, layers do
            local h = top / layers
            local bed = r * (1 - 0.1 * (index - 1))
            decor(parent, "MesaBed", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h + 0.2, bed * 2, bed * 2), Material = Enum.Material.Sandstone,
                CFrame = CFrame.new(base + shift + Vector3.new(0, h * (index - 0.5), 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = colors[index] }).CastShadow = true
        end
        local cap = r * (1 - 0.1 * (layers - 1)) * 2 - 1
        decor(parent, "Caprock", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.5, cap, cap), Material = Enum.Material.Rock,
            CFrame = CFrame.new(base + shift + Vector3.new(0, top + 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = MARS.dark })
    end
end
-- The skyline: a ring of mesas and narrow buttes; any standing in the canyon rise from
-- its floor (the deepest point under their footprint), taller by that much.
local function mesas(c)
    return function(parent)
        local random = Random.new(27)
        local count = 20
        for index = 1, count do
            local angle = (index + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
            local distance = random:NextNumber(640, 820)
            local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
            local butte = random:NextNumber() < 0.25
            local radius = butte and random:NextNumber(32, 50) or random:NextNumber(80, 150)
            local height = butte and random:NextNumber(75, 110) or random:NextNumber(45, 85)
            local drop = math.max(canyonDepth(offset), canyonDepth(offset + Vector3.new(0, 0, radius * 1.6)), canyonDepth(offset - Vector3.new(0, 0, radius * 1.6)))
            mesa(parent, c + offset - Vector3.new(0, 3 + drop, 0), radius, height + drop, random)
        end
        -- A few buttes on the canyon floor itself, and dunes and fallen rock along it.
        local floor = CANYON.steps[#CANYON.steps]
        local near = CANYON.rim + (CANYON.steps[1].width - floor.width) / 2
        for _, x in { -380, -90, 260, 520 } do
            local z = -(near + floor.width * random:NextNumber(0.35, 0.65))
            mesa(parent, c + Vector3.new(x, -3 - floor.depth, z), random:NextNumber(24, 40), random:NextNumber(45, 75), random)
        end
        for _ = 1, 14 do
            local at = c + Vector3.new(random:NextNumber(-700, 700), -3 - floor.depth, -(near + random:NextNumber(30, floor.width - 30)))
            Planets.dune(parent, at, random:NextNumber(50, 110), random:NextNumber(30, 60), random:NextNumber(3, 7), math.pi / 2 + random:NextNumber(-0.3, 0.3), MARS.dust:Lerp(MARS.sand, 0.5))
        end
        for _, step in CANYON.steps do
            local edge = CANYON.rim + (CANYON.steps[1].width - step.width) / 2
            for _ = 1, 10 do
                for _, side in { 1, -1 } do
                    -- At the foot of each wall: just inside the next step down.
                    local z = side == 1 and -(edge + 6) or -(edge + step.width - 6)
                    Planets.boulder(parent, c + Vector3.new(random:NextNumber(-780, 780), -3 - step.depth, z), random:NextNumber(6, 16), MARS.rock, Enum.Material.Rock, random, false)
                end
            end
        end
    end
end
local HAB, GREENHOUSE, SOLAR = Vector3.new(-42, 0, -24), Vector3.new(-64, 0, -12), Vector3.new(-40, 0, -48)
local ROVER, HELI = Vector3.new(24, 0, -18), Vector3.new(8, 0, -4)
local MARS_PROPS = { { HAB, 11 }, { GREENHOUSE, 7 }, { SOLAR, 8 }, { ROVER, 6 }, { HELI, 4 } }
local function habitat(parent, c)
    local at = c + HAB
    decor(parent, "HabDome", { Shape = Enum.PartType.Ball, Size = Vector3.one * 20, CFrame = CFrame.new(at), Color = MARS.hull, Material = Enum.Material.SmoothPlastic }).CastShadow = true
    make(parent, "HabRing", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 21, 21), CFrame = CFrame.new(at + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = MARS.trim, Material = Enum.Material.Metal })
    for index = 1, 5 do
        local angle = index / 5 * math.pi * 2 + 0.3
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        decor(parent, "HabWindow", { Size = Vector3.new(2.6, 1, 0.2), CFrame = CFrame.lookAt(at + out * 9.2 + Vector3.new(0, 4, 0), at + out * 20 + Vector3.new(0, 1.5, 0)),
            Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon })
    end
    -- The airlock faces the arrival.
    local toward = (Vector3.new(0, 0, 20) - HAB) * Vector3.new(1, 0, 1)
    local door = CFrame.lookAt(at + toward.Unit * 10, at + toward.Unit * 20) * CFrame.new(0, 3, 0)
    make(parent, "Airlock", { Size = Vector3.new(6, 6, 4), CFrame = door, Color = MARS.hull, Material = Enum.Material.SmoothPlastic })
    decor(parent, "AirlockDoor", { Size = Vector3.new(3, 4.4, 0.2), CFrame = door * CFrame.new(0, -0.6, -2.05), Color = MARS.trim, Material = Enum.Material.Metal })
    decor(parent, "AirlockLight", { Size = Vector3.new(3, 0.3, 0.2), CFrame = door * CFrame.new(0, 2.1, -2.05), Color = Color3.fromRGB(120, 255, 160), Material = Enum.Material.Neon })
    -- Tunnel to the greenhouse.
    local g = c + GREENHOUSE
    local a, b = at + (g - at).Unit * 8 + Vector3.new(0, 2, 0), g - (g - at).Unit * 5 + Vector3.new(0, 2, 0)
    make(parent, "Tunnel", { Shape = Enum.PartType.Cylinder, Size = Vector3.new((b - a).Magnitude, 4, 4), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), Color = MARS.hull, Material = Enum.Material.SmoothPlastic })
    -- Greenhouse: a glass dome over rows of plants under pink grow lights.
    decor(parent, "Greenhouse", { Shape = Enum.PartType.Ball, Size = Vector3.one * 13, CFrame = CFrame.new(g), Color = Color3.fromRGB(200, 235, 245), Material = Enum.Material.Glass, Transparency = 0.45 })
    make(parent, "GreenhouseRing", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 13.6, 13.6), CFrame = CFrame.new(g + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = MARS.trim, Material = Enum.Material.Metal })
    for row = -1, 1 do
        decor(parent, "PlantBed", { Size = Vector3.new(8, 0.8, 1.6), CFrame = CFrame.new(g + Vector3.new(0, 0.4, row * 2.8)), Color = Color3.fromRGB(70, 46, 34), Material = Enum.Material.Ground })
        for x = -3, 3, 1.5 do
            decor(parent, "Plant", { Shape = Enum.PartType.Ball, Size = Vector3.one * (1.1 + (x + row) % 0.5), CFrame = CFrame.new(g + Vector3.new(x, 1.3, row * 2.8)), Color = Color3.fromRGB(70, 170, 70), Material = Enum.Material.Grass })
        end
    end
    local grow = decor(parent, "GrowLight", { Size = Vector3.new(8, 0.2, 0.6), CFrame = CFrame.new(g + Vector3.new(0, 4.6, 0)), Color = Color3.fromRGB(255, 110, 220), Material = Enum.Material.Neon })
    local glow = Instance.new("PointLight")
    glow.Color, glow.Range, glow.Brightness = grow.Color, 14, 2.5
    glow.Parent = grow
    -- Mast with a dish and a beacon, beside the dome.
    local mast = at + Vector3.new(9, 0, -9)
    make(parent, "Mast", { Size = Vector3.new(0.6, 16, 0.6), CFrame = CFrame.new(mast + Vector3.new(0, 8, 0)), Color = MARS.metal, Material = Enum.Material.Metal })
    decor(parent, "MastDish", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = CFrame.new(mast + Vector3.new(0.8, 12, 0)) * CFrame.Angles(0, 0.8, math.rad(60)), Color = MARS.hull, Material = Enum.Material.SmoothPlastic })
    local beacon = decor(parent, "Beacon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = CFrame.new(mast + Vector3.new(0, 16.4, 0)), Color = Color3.fromRGB(255, 70, 50), Material = Enum.Material.Neon })
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = beacon.Color, 12, 2
    light.Parent = beacon
    beacon:SetAttribute("Period", 2.2)
    CollectionService:AddTag(beacon, "Blinker")
    -- Solar panels on posts, tilted toward the afternoon sun (in the west, -X).
    for row = 0, 1 do
        for col = -1, 1 do
            local spot = c + SOLAR + Vector3.new(row * 4.5 - 2.25, 0, col * 3)
            make(parent, "PanelPost", { Size = Vector3.new(0.3, 2, 0.3), CFrame = CFrame.new(spot + Vector3.new(0, 1, 0)), Color = MARS.metal, Material = Enum.Material.Metal })
            decor(parent, "SolarPanel", { Size = Vector3.new(4, 0.15, 2.8), CFrame = CFrame.new(spot + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(25)), Color = MARS.panel, Material = Enum.Material.Glass }).CastShadow = true
        end
    end
end
local function rover(parent, c)
    local at = c + ROVER
    local model = Instance.new("Model")
    model.Name = "Rover"
    model.Parent = parent
    local body = make(model, "RoverBody", { Size = Vector3.new(7, 1.6, 4.2), CFrame = CFrame.new(at + Vector3.new(0, 2.6, 0)), Color = MARS.hull, Material = Enum.Material.SmoothPlastic })
    decor(model, "SolarDeck", { Size = Vector3.new(7.6, 0.15, 4.8), CFrame = body.CFrame * CFrame.new(0, 0.9, 0), Color = MARS.panel, Material = Enum.Material.Glass })
    for _, x in { -2.8, 0, 2.8 } do
        for _, z in { -2.5, 2.5 } do
            decor(model, "RoverWheel", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 1.8, 1.8), CFrame = CFrame.new(at + Vector3.new(x, 0.9, z)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal })
            strut(model, "Rocker", at + Vector3.new(x, 0.9, z * 0.85), at + Vector3.new(x * 0.6, 2.2, z * 0.8), 0.25, MARS.metal)
        end
    end
    -- Camera mast, with its head looking out over the canyon.
    strut(model, "CameraMast", body.Position + Vector3.new(2.6, 0.8, 1.4), body.Position + Vector3.new(2.6, 4.2, 1.4), 0.3, MARS.metal)
    make(model, "CameraHead", { Size = Vector3.new(1.4, 0.7, 0.8), CFrame = CFrame.lookAt(body.Position + Vector3.new(2.6, 4.5, 1.4), body.Position + Vector3.new(2.6, 4, -20)), Color = MARS.hull, Material = Enum.Material.SmoothPlastic })
    decor(model, "Dish", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2, 2), CFrame = CFrame.new(body.Position + Vector3.new(-1.4, 1.6, -1.2)) * CFrame.Angles(0, 0.5, math.rad(70)), Color = MARS.hull, Material = Enum.Material.SmoothPlastic })
    decor(model, "Power", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 1, 1), CFrame = body.CFrame * CFrame.new(-3.6, 0.2, 0) * CFrame.Angles(0, 0, math.rad(35)), Color = MARS.dark, Material = Enum.Material.Metal })
    -- Its tracks: two lines of tread marks curving back the way it came.
    for _, side in { -2.5, 2.5 } do
        for index = 1, 26 do
            local t = index / 26
            local spot = at + Vector3.new(4 + t * 34, 0, side + math.sin(t * 2.4) * -14)
            local nextSpot = at + Vector3.new(4 + (t + 0.02) * 34, 0, side + math.sin((t + 0.02) * 2.4) * -14)
            decor(parent, "Track", { Size = Vector3.new(0.9, 0.04, 1.5), CFrame = CFrame.lookAt(spot + Vector3.new(0, 0.03, 0), nextSpot + Vector3.new(0, 0.03, 0)), Color = MARS.dark:Lerp(MARS.dust, 0.4), Material = Enum.Material.Sand })
        end
    end
end
-- A small helicopter hovering on two counter-turning rotors (PlanetController spins the
-- blades and bobs the model: tags PlanetSpin, Hover).
local function helicopter(parent, c)
    local at = c + HELI + Vector3.new(0, 4, 0)
    local model = Instance.new("Model")
    model.Name = "Helicopter"
    model.Parent = parent
    local body = decor(model, "HeliBody", { Size = Vector3.new(1.3, 1, 1.3), CFrame = CFrame.new(at), Color = Color3.fromRGB(205, 180, 120), Material = Enum.Material.Foil })
    for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
        strut(model, "HeliLeg", at + corner * 0.5 - Vector3.new(0, 0.4, 0), at + corner * 1.4 - Vector3.new(0, 1.6, 0), 0.08, MARS.metal)
    end
    strut(model, "HeliMast", at + Vector3.new(0, 0.5, 0), at + Vector3.new(0, 2.2, 0), 0.12, MARS.metal)
    decor(model, "HeliSolar", { Size = Vector3.new(1.6, 0.06, 0.9), CFrame = CFrame.new(at + Vector3.new(0, 2.3, 0)), Color = MARS.panel, Material = Enum.Material.Glass })
    for index, height in { 1.2, 1.7 } do
        local blade = decor(model, "Rotor", { Size = Vector3.new(4.8, 0.06, 0.35), CFrame = CFrame.new(at + Vector3.new(0, height, 0)) * CFrame.Angles(0, index, 0), Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.SmoothPlastic })
        blade:SetAttribute("SpinRate", index == 1 and 24 or -24)
        CollectionService:AddTag(blade, Planets.SpinTag)
    end
    model.PrimaryPart = body
    model:SetAttribute("Amplitude", 1.2)
    model:SetAttribute("Period", 3.5)
    CollectionService:AddTag(model, "Hover")
end
-- A whirl of dust that PlanetController walks round its home (tag DustDevil).
local function dustDevil(parent, at, roam)
    local base = decor(parent, "DustDevil", { Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(at), Transparency = 1 })
    base:SetAttribute("Home", at)
    base:SetAttribute("Roam", roam)
    CollectionService:AddTag(base, "DustDevil")
    local funnel = Instance.new("ParticleEmitter")
    funnel.Texture = "rbxasset://textures/particles/smoke_main.dds"
    funnel.EmissionDirection = Enum.NormalId.Top
    funnel.Rate, funnel.Lifetime = 45, NumberRange.new(2.5, 3.5)
    funnel.Speed, funnel.SpreadAngle = NumberRange.new(18, 26), Vector2.new(6, 6)
    funnel.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 16) })
    funnel.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
    funnel.Rotation, funnel.RotSpeed = NumberRange.new(0, 360), NumberRange.new(120, 240)
    funnel.Color = ColorSequence.new(MARS.sand)
    funnel.Drag = 0.3
    funnel.Parent = base
end
builders[2] = function(folder, c)
    local random = Random.new(3)
    folder:SetAttribute("Dust", MARS.sand)
    local ground = disc(folder, "Dust", c - Vector3.new(0, 2, 0), 75, 4, MARS.dust, Enum.Material.Sand)
    Planets.overlay(ground, Enum.NormalId.Right, "MarsGround", 40)
    -- Low drifts and rocks, angular and rounded, where there's room.
    for _ = 1, 60 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 70)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local kind = random:NextNumber()
        if kind < 0.15 then
            local radius = random:NextNumber(6, 10)
            if isClear(offset, radius, MARS_PROPS) then Planets.mound(folder, "Drift", c + offset, radius, random:NextNumber(0.6, 1.2), MARS.sand, Enum.Material.Sand, true) end
        else
            local size = random:NextNumber(1.2, 4)
            if isClear(offset, size, MARS_PROPS) then
                if kind < 0.6 then
                    -- Angular basalt: a block tumbled at random and half buried, so only
                    -- a few faces and edges show.
                    make(folder, "Rock", { Size = Vector3.new(size * 1.2, size * 0.8, size), Color = MARS.rock:Lerp(MARS.dark, random:NextNumber(0, 0.5)), Material = Enum.Material.Rock,
                        CFrame = CFrame.new(c + offset + Vector3.new(0, size * 0.1, 0)) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28)) })
                else
                    Planets.boulder(folder, c + offset, size, MARS.rock, Enum.Material.Rock, random, true)
                end
            end
        end
    end
    habitat(folder, c)
    rover(folder, c)
    helicopter(folder, c)
    -- Dust blowing across the platform on the west wind.
    local gust = decor(folder, "WindDust", { Size = Vector3.new(2, 4, 170), CFrame = CFrame.new(c + Vector3.new(-95, 2, 0)), Transparency = 1 })
    local streak = Instance.new("ParticleEmitter")
    streak.Texture = "rbxasset://textures/particles/smoke_main.dds"
    streak.EmissionDirection = Enum.NormalId.Right
    streak.Shape = Enum.ParticleEmitterShape.Box
    streak.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    streak.Rate, streak.Lifetime = 10, NumberRange.new(7, 10)
    streak.Speed, streak.SpreadAngle = NumberRange.new(18, 26), Vector2.new(4, 12)
    streak.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
    streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.84), NumberSequenceKeypoint.new(0.8, 0.88), NumberSequenceKeypoint.new(1, 1) })
    streak.Rotation, streak.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-20, 20)
    streak.Color = ColorSequence.new(MARS.sand)
    streak.Parent = gust
    for _, spot in { Vector3.new(260, -3, 140), Vector3.new(-320, -3, 240), Vector3.new(430, -3, -10) } do
        dustDevil(folder, c + spot, 120)
    end
    -- Dunes across the plain on either side: broad, low swells in loose fields, crests
    -- across the west wind, barely lighter than the ground.
    for _ = 1, 40 do
        local side = random:NextNumber() < 0.5 and -1 or 1
        local offset = Vector3.new(side * random:NextNumber(140, 560), 0, random:NextNumber(-40, 520))
        Planets.dune(folder, c + offset - Vector3.new(0, 3, 0), random:NextNumber(70, 150), random:NextNumber(40, 80), random:NextNumber(4, 10),
            math.pi / 2 + random:NextNumber(-0.35, 0.35), MARS.dust:Lerp(MARS.sand, random:NextNumber(0.2, 0.6)))
    end
    -- Phobos sails across the sky in a few minutes, peaking 37 degrees up over the canyon,
    -- and sets behind the mesas; Deimos, small and far, peaks lower and barely moves. Both
    -- orbit a point below the ground on tilted circles, so they rise and set. Each starts
    -- `lead` radians before its highest point (orbits only run while Mars is drawn, so a
    -- first visit sees Phobos climb; Deimos starts past its peak, apart from it).
    local function moon(name, size, radius, axis, rate, lead, spin)
        axis = axis.Unit
        local center = c - Vector3.new(0, radius * 0.32, 0)
        local up = (Vector3.yAxis - axis * axis:Dot(Vector3.yAxis)).Unit
        local peak, height = 0, -math.huge
        for degree = 0, 359 do
            local y = (CFrame.fromAxisAngle(axis, math.rad(degree)) * up).Y
            if y > height then peak, height = math.rad(degree), y end
        end
        Planets.globe(folder, name, { center = center + CFrame.fromAxisAngle(axis, peak - lead) * (up * radius), size = size, texture = "Phobos",
            spin = spin, color = Color3.fromRGB(150, 120, 100), orbit = { center = center, axis = axis, rate = rate } })
    end
    moon("Phobos", Vector3.new(64, 46, 52), 1250, Vector3.new(0.25, 0.8, 1), 0.012, 0.6, 0.03)
    moon("Deimos", Vector3.new(28, 22, 24), 1500, Vector3.new(-0.4, 1.1, 1), 0.004, -0.7, 0.02)
    surroundings(folder, c, 75, { seed = 12, reach = 1000, plainDepth = 130, keep = offCanyon, cut = canyonCut(c), horizon = mesas(c),
        ridge = { color = MARS.dust:Lerp(MARS.sand, 0.4), material = Enum.Material.Sand }, round = true,
        overlays = { { "MoonMaria", 600, 0.2, Color3.fromRGB(150, 60, 36) }, { "MarsGround", 50, 0.3 } },
        ground = MARS.dust, material = Enum.Material.Sand, crag = MARS.rock, cragMaterial = Enum.Material.Rock })
    fence(folder, c, 75, 45)
    return ground, Vector3.new(0, 0, 20)
end
-- 3 (Rare): Jupiter's ice moon. A cracked ice shell with glowing cyan fissures, ice
-- ridges and geyser vents (tagged for the geyser mechanic), under a giant banded Jupiter.
builders[3] = function(folder, c)
    local ground = disc(folder, "IceShell", c - Vector3.new(0, 2, 0), 75, 4, Color3.fromRGB(225, 235, 245), Enum.Material.Glacier)
    scatter(31, 16, 70, function(index, offset, random)
        decor(folder, "Fissure", { Size = Vector3.new(random:NextNumber(14, 34), 0.12, random:NextNumber(0.4, 0.9)),
            CFrame = CFrame.new(c + offset + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0),
            Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon })
    end)
    scatter(32, 6, 62, function(index, offset, random)
        disc(folder, "GeyserRim", c + offset + Vector3.new(0, 0.2, 0), 4.5, 0.6, Color3.fromRGB(200, 225, 240), Enum.Material.Ice)
        local vent = disc(folder, "GeyserVent", c + offset + Vector3.new(0, 0.35, 0), 2.8, 0.6, Color3.fromRGB(20, 60, 110), Enum.Material.Neon)
        vent.CanCollide = false
        CollectionService:AddTag(vent, "GeyserVent")
    end)
    scatter(33, 8, 68, function(index, offset, random)
        local height = random:NextNumber(3, 7)
        make(folder, "IceRidge", { ClassName = "WedgePart", Size = Vector3.new(random:NextNumber(10, 18), height, 5),
            CFrame = CFrame.new(c + offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0),
            Color = Color3.fromRGB(190, 220, 245), Material = Enum.Material.Ice })
    end)
    local jupiter = c + Vector3.new(320, 300, -1100)
    decor(folder, "Jupiter", { Shape = Enum.PartType.Ball, Size = Vector3.one * 900, CFrame = CFrame.new(jupiter), Color = Color3.fromRGB(215, 170, 125) })
    for index, stripe in { { 250, 70, Color3.fromRGB(170, 105, 70) }, { 120, 45, Color3.fromRGB(235, 205, 170) },
        { -30, 80, Color3.fromRGB(185, 120, 80) }, { -210, 60, Color3.fromRGB(160, 100, 70) } } do
        band(folder, "JupiterBand" .. index, jupiter, 450, stripe[1], stripe[2], stripe[3])
    end
    local facing = (c - jupiter).Unit
    decor(folder, "GreatRedSpot", { Shape = Enum.PartType.Ball, Size = Vector3.one * 130,
        CFrame = CFrame.new(jupiter + facing * 405 + Vector3.new(0, -150, 0)), Color = Color3.fromRGB(200, 80, 50) })
    surroundings(folder, c, 75, { seed = 13, reach = 750, ring = { radius = 520, spread = 40, count = 20, size = { 200, 320 }, rock = Color3.fromRGB(190, 215, 240), rockAlt = Color3.fromRGB(160, 195, 230), material = Enum.Material.Ice, seed = 23 },  ground = Color3.fromRGB(205, 220, 235), material = Enum.Material.Glacier, crag = Color3.fromRGB(185, 215, 240), cragMaterial = Enum.Material.Ice })
    fence(folder, c, 75, 70)
    return ground, Vector3.new(0, 0, 20)
end
-- 4 (Epic): an icy chunk of Saturn's rings under the giant ringed planet.
builders[4] = function(folder, c)
    local ground = disc(folder, "RingRock", c - Vector3.new(0, 2, 0), 65, 4, Color3.fromRGB(205, 195, 170), Enum.Material.Rock)
    scatter(4, 10, 60, function(index, offset, random)
        local size = random:NextNumber(3, 7)
        make(folder, "IceChunk", { Size = Vector3.one * size, CFrame = CFrame.new(c + offset + Vector3.new(0, size / 2 - 0.6, 0)) * CFrame.Angles(random:NextNumber(0, 1), random:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(225, 235, 245), Material = Enum.Material.Ice })
    end)
    local saturn = c + Vector3.new(0, 220, -900)
    decor(folder, "Saturn", { Shape = Enum.PartType.Ball, Size = Vector3.one * 640, CFrame = CFrame.new(saturn), Color = Color3.fromRGB(225, 195, 140) })
    band(folder, "SaturnBand", saturn, 320, 90, 70, Color3.fromRGB(200, 160, 105))
    band(folder, "SaturnBand2", saturn, 320, -60, 40, Color3.fromRGB(240, 215, 165))
    decor(folder, "SaturnRings", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1500, 1500), CFrame = CFrame.new(saturn) * CFrame.Angles(math.rad(14), 0, math.rad(90)), Color = Color3.fromRGB(215, 200, 165), Transparency = 0.45 })
    scatter(40, 12, 260, function(index, offset, random)
        local size = random:NextNumber(6, 18)
        decor(folder, "FloatingRock", { Size = Vector3.one * size, CFrame = CFrame.new(c + offset + Vector3.new(0, random:NextNumber(30, 90), 0)) * CFrame.Angles(random:NextNumber(0, 3), random:NextNumber(0, 3), 0), Color = Color3.fromRGB(190, 180, 160), Material = Enum.Material.Rock })
    end)
    surroundings(folder, c, 65, { seed = 14, reach = 650, ring = { radius = 440, spread = 40, count = 20, size = { 180, 300 }, rock = Color3.fromRGB(200, 190, 165), rockAlt = Color3.fromRGB(225, 232, 240), seed = 24 },  ground = Color3.fromRGB(185, 175, 150), material = Enum.Material.Rock, crag = Color3.fromRGB(220, 230, 240), cragMaterial = Enum.Material.Ice })
    fence(folder, c, 65, 50)
    return ground, Vector3.new(0, 0, 18)
end
-- 5 (Legendary): an obsidian shard at the edge of a black hole. Purple fissures and
-- floating debris; above, the hole itself (neon black, so lighting never greys it)
-- with its tilted accretion disk and the lensed far side as a halo behind it.
builders[5] = function(folder, c)
    local ground = disc(folder, "Obsidian", c - Vector3.new(0, 2, 0), 70, 4, Color3.fromRGB(28, 22, 40), Enum.Material.Basalt)
    disc(folder, "EdgeGlow", c - Vector3.new(0, 2.6, 0), 72, 0.6, Color3.fromRGB(170, 80, 255), Enum.Material.Neon).CanCollide = false
    scatter(51, 14, 66, function(index, offset, random)
        decor(folder, "VoidFissure", { Size = Vector3.new(random:NextNumber(12, 30), 0.12, random:NextNumber(0.4, 0.8)),
            CFrame = CFrame.new(c + offset + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0),
            Color = Color3.fromRGB(180, 90, 255), Material = Enum.Material.Neon })
    end)
    scatter(52, 16, 240, function(index, offset, random)
        local size = random:NextNumber(5, 16)
        decor(folder, "Debris", { Size = Vector3.new(size, size * 0.6, size * 0.8),
            CFrame = CFrame.new(c + offset + Vector3.new(0, random:NextNumber(20, 110), 0)) * CFrame.Angles(random:NextNumber(0, 3), random:NextNumber(0, 3), 0),
            Color = Color3.fromRGB(40, 32, 60), Material = Enum.Material.Basalt })
    end)
    -- High enough that the tilted disk's near rim stays above the plain round the shard.
    local hole = c + Vector3.new(0, 330, -1100)
    decor(folder, "AccretionDisk", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1500, 1500),
        CFrame = CFrame.new(hole) * CFrame.Angles(math.rad(25), 0, math.rad(90)), Color = Color3.fromRGB(255, 130, 40), Material = Enum.Material.Neon, Transparency = 0.3 })
    decor(folder, "InnerDisk", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 820, 820),
        CFrame = CFrame.new(hole) * CFrame.Angles(math.rad(25), 0, math.rad(90)), Color = Color3.fromRGB(255, 225, 160), Material = Enum.Material.Neon, Transparency = 0.2 })
    decor(folder, "LensedArc", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 900, 900),
        CFrame = CFrame.new(hole) * CFrame.Angles(math.rad(80), 0, math.rad(90)), Color = Color3.fromRGB(255, 170, 80), Material = Enum.Material.Neon, Transparency = 0.45 })
    decor(folder, "EventHorizon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 500, CFrame = CFrame.new(hole), Color = Color3.new(0, 0, 0), Material = Enum.Material.Neon })
    surroundings(folder, c, 70, { seed = 15, reach = 800, ring = { radius = 630, spread = 30, count = 32, size = { 150, 220 }, rock = Color3.fromRGB(40, 32, 60), rockAlt = Color3.fromRGB(28, 22, 40), material = Enum.Material.Basalt, seed = 25 },  ground = Color3.fromRGB(22, 18, 32), material = Enum.Material.Basalt, crag = Color3.fromRGB(40, 32, 60), cragMaterial = Enum.Material.Basalt })
    fence(folder, c, 70, 60)
    return ground, Vector3.new(0, 0, 20)
end

-- Returns { [tier] = { id, name, gravity, reward, arrival = Vector3, center, landing = Vector3 (on the ground),
-- gym = { bench, treadmill }, shop = Vector3 (on the ground), shopFacing } } and the cabin
-- { center, size, arrival, exit (part with the Leave prompt) }.
function Destinations.build(world, config)
    local root = Instance.new("Folder")
    root.Name = "Destinations"
    root.Parent = world
    local built = {}
    for tier, spec in config.Destinations do
        local folder = Instance.new("Folder")
        folder.Name = spec.id
        folder.Parent = root
        local center = spec.position
        local ground, arrivalOffset = builders[tier](folder, center)
        ground:SetAttribute("Destination", spec.id)
        local arrivalAt = center + arrivalOffset
        arrival(folder, arrivalAt + Vector3.new(0, 0.2, 0), tier, spec.color)
        local mission = Missions.get(tier)
        sign(folder, center, arrivalOffset, spec, mission and mission.Rarity)
        built[tier] = { id = spec.id, name = spec.name, gravity = spec.gravity, reward = spec.reward, folder = folder,
            arrival = arrivalAt + Vector3.new(0, 4, 0), center = center, landing = center + Destinations.LandingOffset,
            shop = center + Destinations.ShopOffset, shopFacing = (arrivalOffset - Destinations.ShopOffset).Unit,
            gym = { bench = center + Destinations.GymOffsets.bench + Vector3.new(0, 1, 0), treadmill = center + Destinations.GymOffsets.treadmill + Vector3.new(0, 1, 0) } }
    end

    -- The cabin: the inside of the rocket, an enclosed room with seats, portholes,
    -- a countdown screen (client fills it in) and the exit hatch.
    local cabinFolder = Instance.new("Folder")
    cabinFolder.Name = "RocketCabin"
    cabinFolder.Parent = root
    local cc, size = config.CabinPosition, Vector3.new(48, 16, 34)
    local hull, light = Color3.fromRGB(225, 228, 236), Color3.fromRGB(150, 220, 255)
    local floor = make(cabinFolder, "CabinFloor", { Size = Vector3.new(size.X, 1, size.Z), CFrame = CFrame.new(cc - Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(70, 76, 92), Material = Enum.Material.DiamondPlate })
    CollectionService:AddTag(floor, Destinations.CabinTag)
    floor:SetAttribute("CabinSize", size)
    make(cabinFolder, "CabinCeiling", { Size = Vector3.new(size.X, 1, size.Z), CFrame = CFrame.new(cc + Vector3.new(0, size.Y + 0.5, 0)), Color = hull })
    for _, side in { -1, 1 } do
        -- The long walls run past the end walls so the corners are closed (flush, they
        -- left a 1-stud gap at each corner that showed the outside through it).
        make(cabinFolder, "CabinWall", { Size = Vector3.new(size.X + 2, size.Y + 2, 1), CFrame = CFrame.new(cc + Vector3.new(0, size.Y / 2, side * (size.Z / 2 + 0.5))), Color = hull })
        make(cabinFolder, "CabinWall", { Size = Vector3.new(1, size.Y + 2, size.Z), CFrame = CFrame.new(cc + Vector3.new(side * (size.X / 2 + 0.5), size.Y / 2, 0)), Color = hull })
        decor(cabinFolder, "LightStrip", { Size = Vector3.new(size.X - 4, 0.3, 1), CFrame = CFrame.new(cc + Vector3.new(0, size.Y - 0.2, side * 8)), Color = light, Material = Enum.Material.Neon })
        for x = -16, 16, 8 do
            decor(cabinFolder, "Porthole", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5, 5), CFrame = CFrame.new(cc + Vector3.new(x, 9, side * size.Z / 2)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(20, 30, 70), Material = Enum.Material.Neon })
        end
    end
    -- Seat rows face the screen on the -X wall, split by a centre aisle (z = 0) that
    -- runs from the screen to the exit hatch.
    for row = 0, 3 do
        for _, seat in { -2.4, -1.4, 1.4, 2.4 } do
            local at = cc + Vector3.new(-8 + row * 7, 1, seat * 5.5)
            make(cabinFolder, "SeatBase", { Size = Vector3.new(3, 1.6, 3.4), CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)), Color = Color3.fromRGB(60, 90, 170) })
            make(cabinFolder, "SeatBack", { Size = Vector3.new(0.8, 4, 3.4), CFrame = CFrame.new(at + Vector3.new(1.6, 2, 0)), Color = Color3.fromRGB(50, 75, 150) })
        end
    end
    local screen = make(cabinFolder, "CountdownScreen", { Size = Vector3.new(0.4, 8, 20), CFrame = CFrame.new(cc + Vector3.new(-size.X / 2 + 0.3, 8, 0)), Color = Color3.fromRGB(10, 14, 28), Material = Enum.Material.Neon })
    local surface = Instance.new("SurfaceGui")
    surface.Name = "Display"
    surface.Face = Enum.NormalId.Right
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 25
    surface.Parent = screen
    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.Font = Enum.Font.FredokaOne
    text.TextColor3 = Color3.fromRGB(120, 255, 140)
    text.Text = "PREPARE FOR LIFTOFF"
    text.Parent = surface
    local exit = make(cabinFolder, "ExitHatch", { Size = Vector3.new(0.6, 9, 6), CFrame = CFrame.new(cc + Vector3.new(size.X / 2 - 0.2, 4.5, 0)), Color = Color3.fromRGB(255, 190, 40) })
    local cabin = { center = cc, size = size, arrival = cc + Vector3.new(4, 3, 0), exit = exit, screen = screen }
    return built, cabin
end

return Destinations
