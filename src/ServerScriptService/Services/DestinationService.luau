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
-- Invisible walls in a ring so nobody leaves a destination, their inner faces `radius` - 1
-- from the centre. FenceHeight over the platform's top: the fastest walker (MaxSpeed 400)
-- thrown straight up off a slope and jumping, in Europa's gravity (50), could rise ~2,000
-- studs, so each wall is two parts stacked (a part is at most 2048 tall). From
-- FENCE_DEPTH under the top, so nothing slips under; FENCE_THICKNESS thick, outward, as at
-- 400 studs/s a character moves ~1.7 studs a physics step.
Destinations.FenceHeight = 4000
local FENCE_THICKNESS, FENCE_DEPTH, FENCE_PIECE = 12, 40, 2000
local function fence(parent, center, radius)
    local middle = radius - 1 + FENCE_THICKNESS / 2
    local width = (radius + FENCE_THICKNESS) * 2 * math.sin(math.pi / 24) + 2
    for index = 1, 24 do
        local angle = index / 24 * math.pi * 2
        local at = center + Vector3.new(math.cos(angle) * middle, 0, math.sin(angle) * middle)
        local facing = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)) * CFrame.Angles(0, math.rad(90), 0)
        for bottom = -FENCE_DEPTH, Destinations.FenceHeight - 1, FENCE_PIECE do
            local height = math.min(FENCE_PIECE, Destinations.FenceHeight - bottom)
            make(parent, "Fence", {
                Size = Vector3.new(FENCE_THICKNESS, height, width), Transparency = 1, CanQuery = false,
                CFrame = facing + Vector3.new(0, bottom + height / 2, 0),
            })
        end
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
-- The arrival spot: a low metal landing pad in the destination's colour, not a glaring
-- disc: a dark plate with a glowing outer ring, a thin inner ring, four chevrons
-- pointing in, and a beacon in the middle. The tagged part is the plate.
local function arrival(parent, position, tier, color)
    local flat = CFrame.Angles(0, 0, math.rad(90))
    local pad = make(parent, "ArrivalPad", {
        Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 17, 17), Color = Color3.fromRGB(52, 56, 68), Material = Enum.Material.DiamondPlate,
        CanCollide = false, CanQuery = false, CanTouch = false, CFrame = CFrame.new(position) * flat,
    })
    pad:SetAttribute("Tier", tier)
    CollectionService:AddTag(pad, Destinations.ArrivalTag)
    decor(parent, "ArrivalRing", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.26, 18, 18), Color = color, Material = Enum.Material.Neon,
        CFrame = CFrame.new(position - Vector3.new(0, 0.03, 0)) * flat })
    decor(parent, "ArrivalInner", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 9, 9), Color = color, Material = Enum.Material.Neon, Transparency = 0.5,
        CFrame = CFrame.new(position + Vector3.new(0, 0.01, 0)) * flat })
    decor(parent, "ArrivalCore", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 8, 8), Color = Color3.fromRGB(52, 56, 68), Material = Enum.Material.DiamondPlate,
        CFrame = CFrame.new(position + Vector3.new(0, 0.02, 0)) * flat })
    for index = 0, 3 do
        local angle = index * math.pi / 2 + math.pi / 4
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        for _, side in { -1, 1 } do
            local tip = position + out * 5.6 + Vector3.new(0, 0.18, 0)
            local across = Vector3.new(-out.Z, 0, out.X) * side
            local mid = tip + out * 0.9 + across * 0.9
            decor(parent, "ArrivalChevron", { Size = Vector3.new(0.5, 0.06, 2.4), CFrame = CFrame.lookAt(mid, tip), Color = color, Material = Enum.Material.Neon })
        end
    end
    local beacon = decor(parent, "ArrivalBeacon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)), Color = color, Material = Enum.Material.Neon })
    beacon:SetAttribute("Period", 2.4)
    CollectionService:AddTag(beacon, "Pulse")
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
-- ({ offset, radius }) and the platform's edge (`edge` from the centre, 72 by default).
local function isClear(offset, reach, props, edge)
    for _, spot in CLEAR do
        if (offset - spot[1]).Magnitude < spot[2] + reach then return false end
    end
    for _, prop in props do
        if (offset - prop[1]).Magnitude < prop[2] + reach then return false end
    end
    return offset.Magnitude + reach < (edge or 72)
end
-- A small moon on a tilted circle round a point below the centre `c`, so it rises and
-- sets, starting `spec.lead` radians before its highest point (orbits only run while the
-- destination is drawn, so a first visit sees it there). spec = { size, radius, axis,
-- rate, lead, spin, texture, color }.
local function orbitingMoon(folder, c, name, spec)
    local axis = spec.axis.Unit
    local center = c - Vector3.new(0, spec.radius * 0.32, 0)
    local up = (Vector3.yAxis - axis * axis:Dot(Vector3.yAxis)).Unit
    local peak, height = 0, -math.huge
    for degree = 0, 359 do
        local y = (CFrame.fromAxisAngle(axis, math.rad(degree)) * up).Y
        if y > height then peak, height = math.rad(degree), y end
    end
    return Planets.globe(folder, name, { center = center + CFrame.fromAxisAngle(axis, peak - spec.lead) * (up * spec.radius), size = spec.size,
        texture = spec.texture, spin = spec.spin, color = spec.color, orbit = { center = center, axis = axis, rate = spec.rate } })
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
    fence(folder, c, 75)
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
    -- and sets behind the mesas (a first visit sees it climb); Deimos, small and far, peaks
    -- lower and barely moves, starting past its peak, apart from Phobos.
    local dusty = Color3.fromRGB(150, 120, 100)
    orbitingMoon(folder, c, "Phobos", { size = Vector3.new(64, 46, 52), radius = 1250, axis = Vector3.new(0.25, 0.8, 1), rate = 0.012, lead = 0.6, spin = 0.03, texture = "Phobos", color = dusty })
    orbitingMoon(folder, c, "Deimos", { size = Vector3.new(28, 22, 24), radius = 1500, axis = Vector3.new(-0.4, 1.1, 1), rate = 0.004, lead = -0.7, spin = 0.02, texture = "Phobos", color = dusty })
    surroundings(folder, c, 75, { seed = 12, reach = 1000, plainDepth = 130, keep = offCanyon, cut = canyonCut(c), horizon = mesas(c),
        ridge = { color = MARS.dust:Lerp(MARS.sand, 0.4), material = Enum.Material.Sand }, round = true,
        overlays = { { "MoonMaria", 600, 0.2, Color3.fromRGB(150, 60, 36) }, { "MarsGround", 50, 0.3 } },
        ground = MARS.dust, material = Enum.Material.Sand, crag = MARS.rock, cragMaterial = Enum.Material.Rock })
    fence(folder, c, 75)
    return ground, Vector3.new(0, 0, 20)
end
-- 3 (Rare): Europa, Jupiter's ice moon. Glowing crevasses cut into the ice shell, geyser
-- vents on little ice cones (tagged GeyserVent: they erupt on each client, and the geyser
-- mechanic can use them), reddish lineae across the ice, and a drilling rig over a hole
-- that glows with the ocean below, beside a habitat pod. Beyond: double ridges, fields
-- of jumbled ice rafts, distant geysers, blades of ice in front of icy peaks, and a
-- giant banded Jupiter rising behind them (Io crosses its face). Ice crystals sparkle
-- down through the cold light (Shared.Skies "Europa").
local EUROPA = { ice = Color3.fromRGB(222, 232, 242), snow = Color3.fromRGB(240, 246, 252), blue = Color3.fromRGB(160, 208, 240), pale = Color3.fromRGB(196, 222, 244),
    glow = Color3.fromRGB(90, 220, 255), deep = Color3.fromRGB(30, 120, 220), metal = Color3.fromRGB(196, 198, 206), rig = Color3.fromRGB(236, 160, 50), hull = Color3.fromRGB(232, 236, 240) }
local DRILL, POD = Vector3.new(-40, 0, -18), Vector3.new(36, 0, -32)
local EUROPA_PROPS = { { DRILL, 10 }, { POD, 8 } }
-- The drilling rig: a hole through the ice with the ocean glowing in it, a railing round
-- it, a truss tower with a winch, and a probe hanging into the hole on its cable.
local function drillRig(parent, c)
    local at = c + DRILL
    local glow = decor(parent, "OceanGlow", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7, 7), CFrame = CFrame.new(at - Vector3.new(0, 4.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Color = EUROPA.deep, Material = Enum.Material.Neon })
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = EUROPA.glow, 20, 3
    light.Parent = glow
    glow:SetAttribute("Period", 3)
    CollectionService:AddTag(glow, "Pulse")
    for index = 1, 10 do
        local angle = index / 10 * math.pi * 2
        local post = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 5.2
        make(parent, "RailPost", { Size = Vector3.new(0.25, 3.2, 0.25), CFrame = CFrame.new(post + Vector3.new(0, 1.6, 0)), Color = EUROPA.rig, Material = Enum.Material.Metal })
        local nextPost = at + Vector3.new(math.cos(angle + math.pi / 5), 0, math.sin(angle + math.pi / 5)) * 5.2
        make(parent, "Rail", { Size = Vector3.new(0.18, 0.18, (nextPost - post).Magnitude), CFrame = CFrame.lookAt((post + nextPost) / 2 + Vector3.new(0, 3, 0), nextPost + Vector3.new(0, 3, 0)), Color = EUROPA.rig, Material = Enum.Material.Metal })
        -- An invisible wall behind the rail, so nobody drops into the hole.
        make(parent, "RailGuard", { Size = Vector3.new(0.2, 6, (nextPost - post).Magnitude), CFrame = CFrame.lookAt((post + nextPost) / 2 + Vector3.new(0, 3, 0), nextPost + Vector3.new(0, 3, 0)), Transparency = 1, CanQuery = false })
    end
    local apex = at + Vector3.new(0, 15, 0)
    for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
        strut(parent, "RigLeg", at + corner * 6.5, apex + corner * 0.6, 0.45, EUROPA.rig)
        strut(parent, "RigBrace", at + corner * 4.8 + Vector3.new(0, 4, 0), at + Vector3.new(corner.Z, 0, -corner.X) * 4.8 + Vector3.new(0, 4, 0), 0.2, EUROPA.rig)
    end
    make(parent, "Winch", { Size = Vector3.new(2.4, 1.6, 2.4), CFrame = CFrame.new(apex + Vector3.new(0, 0.8, 0)), Color = EUROPA.metal, Material = Enum.Material.Metal })
    decor(parent, "Sheave", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2, 2), CFrame = CFrame.new(apex + Vector3.new(0, -0.6, 0)), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Metal })
    local beacon = decor(parent, "Beacon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = CFrame.new(apex + Vector3.new(0, 1.9, 0)), Color = Color3.fromRGB(255, 70, 50), Material = Enum.Material.Neon })
    local red = Instance.new("PointLight")
    red.Color, red.Range, red.Brightness = beacon.Color, 12, 2
    red.Parent = beacon
    beacon:SetAttribute("Period", 1.8)
    CollectionService:AddTag(beacon, "Blinker")
    -- The probe and its cable bob together (tag Hover), as if the winch were paying out.
    local probe = Instance.new("Model")
    probe.Name = "Probe"
    probe.Parent = parent
    local body = decor(probe, "ProbeBody", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 1.4, 1.4), CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = EUROPA.hull, Material = Enum.Material.SmoothPlastic })
    decor(probe, "ProbeNose", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CFrame.new(at + Vector3.new(0, -1.3, 0)), Color = EUROPA.hull, Material = Enum.Material.SmoothPlastic })
    decor(probe, "ProbeLight", { Size = Vector3.new(1.45, 0.25, 1.45), CFrame = CFrame.new(at + Vector3.new(0, 1, 0)), Color = EUROPA.glow, Material = Enum.Material.Neon })
    strut(probe, "Cable", at + Vector3.new(0, 2.1, 0), apex - Vector3.new(0, 1.4, 0), 0.08, Color3.fromRGB(40, 40, 46))
    probe.PrimaryPart = body
    probe:SetAttribute("Amplitude", 0.9)
    probe:SetAttribute("Period", 6)
    CollectionService:AddTag(probe, "Hover")
end
-- The crew's pod: a capsule on legs with warm windows, a ladder, a dish, and crates.
local function europaPod(parent, c)
    local at = c + POD
    local turn = CFrame.Angles(0, math.rad(30), 0)
    local frame = CFrame.new(at + Vector3.new(0, 4.4, 0)) * turn
    make(parent, "Pod", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 5, 5), CFrame = frame, Color = EUROPA.hull, Material = Enum.Material.SmoothPlastic })
    for _, side in { -1, 1 } do
        decor(parent, "PodCap", { Shape = Enum.PartType.Ball, Size = Vector3.one * 5, CFrame = frame * CFrame.new(side * 4.5, 0, 0), Color = EUROPA.hull, Material = Enum.Material.SmoothPlastic })
        for _, end_ in { -1, 1 } do
            strut(parent, "PodLeg", (frame * CFrame.new(end_ * 3, -1.6, side * 1.4)).Position, (frame * CFrame.new(end_ * 3.8, -4.4, side * 2.6)).Position, 0.3, EUROPA.metal)
        end
        for x = -2, 2, 2 do
            decor(parent, "PodWindow", { Size = Vector3.new(1.2, 0.8, 0.15), CFrame = frame * CFrame.new(x, 0.6, side * 2.47), Color = Color3.fromRGB(255, 210, 140), Material = Enum.Material.Neon })
        end
    end
    for step = 1, 4 do
        decor(parent, "PodRung", { Size = Vector3.new(1.2, 0.12, 0.12), CFrame = frame * CFrame.new(0, -1.6 - step * 0.6, 2.9), Color = EUROPA.metal, Material = Enum.Material.Metal })
    end
    strut(parent, "PodMast", (frame * CFrame.new(-2, 2.4, 0)).Position, (frame * CFrame.new(-2, 5, 0)).Position, 0.15, EUROPA.metal)
    decor(parent, "PodDish", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.4, 2.4), CFrame = CFrame.new((frame * CFrame.new(-2, 5.2, 0)).Position) * CFrame.Angles(0.4, 0.8, math.rad(65)), Color = EUROPA.hull, Material = Enum.Material.SmoothPlastic })
    for index, offset in { Vector3.new(-6, 0, 3), Vector3.new(-7.5, 0, 0.5), Vector3.new(-6.6, 1.4, 1.6) } do
        make(parent, "Crate", { Size = Vector3.new(1.8, 1.4, 1.4), CFrame = CFrame.new(at + turn * offset + Vector3.new(0, 0.7, 0)) * turn * CFrame.Angles(0, index * 0.3, 0), Color = index == 2 and EUROPA.rig or EUROPA.metal, Material = Enum.Material.Metal })
    end
end
-- A pointed blade (of ice, by default): two wedges back to back make a tall thin
-- triangle, standing on `frame` (its base centre).
local function iceBlade(parent, frame, width, height, thickness, color, material)
    for _, side in { -1, 1 } do
        decor(parent, "IceBlade", { ClassName = "WedgePart", Size = Vector3.new(thickness, height, width / 2), Material = material or Enum.Material.Glacier, Color = color,
            CFrame = frame * CFrame.new(0, height / 2, side * width / 4) * CFrame.Angles(0, side == 1 and math.pi or 0, 0) }).CastShadow = true
    end
end
-- The horizon: clusters of ice blades, leaning a little, in front of a ring of icy peaks.
local function iceBlades(c)
    return function(parent)
        local random = Random.new(37)
        local count = 26
        for index = 1, count do
            local angle = (index + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
            local distance = random:NextNumber(470, 580)
            local base = c + Vector3.new(math.cos(angle) * distance, -3, math.sin(angle) * distance)
            for _ = 1, random:NextInteger(3, 7) do
                local height = random:NextNumber(40, 150)
                local spot = base + Vector3.new(random:NextNumber(-40, 40), -height * 0.08, random:NextNumber(-40, 40))
                iceBlade(parent, CFrame.new(spot) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0) * CFrame.Angles(random:NextNumber(-0.15, 0.15), 0, random:NextNumber(-0.15, 0.15)),
                    height * random:NextNumber(0.35, 0.6), height, random:NextNumber(4, 9), EUROPA.pale:Lerp(EUROPA.snow, random:NextNumber()))
            end
        end
    end
end
-- A geyser vent: a neon pool in the bottom of a little ice cone (the cone is carved into
-- the ground by the caller; `scale` sizes its plumes).
local function geyser(parent, at, radius, depth, scale)
    local vent = decor(parent, "GeyserVent", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, radius * 1.3, radius * 1.3),
        CFrame = CFrame.new(at - Vector3.new(0, depth - 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 140, 220), Material = Enum.Material.Neon })
    vent:SetAttribute("Scale", scale)
    CollectionService:AddTag(vent, "GeyserVent")
    return vent
end
-- The oarfish's breach holes (OarfishController: it bursts out of BREACH_EXIT, arcs over
-- past Jupiter's edge and dives into BREACH_ENTRY), out on the plain 360-430 studs from the
-- landing site, front right: the landed rocket (behind the pad) hides about 23° either
-- side of straight ahead from the pad, so the whole arc stays right of it. Each is open
-- black-blue water with floes adrift in it, a rim of ice slabs shoved up and tipped
-- outward, rubble flung across the ice and cracks running out from it. The folder
-- carries both spots as OarfishExit / OarfishEntry (world, on the ice).
local BREACH_EXIT, BREACH_ENTRY, BREACH_RADIUS = Vector3.new(190, 0, -300), Vector3.new(430, 0, 40), 34
local function breachHole(parent, at, radius, random)
    local model = Instance.new("Model")
    model.Name = "BreachHole"
    model.Parent = parent
    local water = Color3.fromRGB(10, 30, 52)
    disc(model, "SlushMargin", at + Vector3.new(0, 0.05, 0), radius + 5, 0.2, Color3.fromRGB(176, 212, 236), Enum.Material.Ice).CanCollide = false
    local pool = disc(model, "OpenWater", at + Vector3.new(0, 0.1, 0), radius, 0.4, water, Enum.Material.Glass)
    pool.CanCollide, pool.Reflectance = false, 0.2
    -- The ocean's glow coming up through the opening, faint under the water.
    disc(model, "OceanGlow", at + Vector3.new(0, 0.12, 0), radius * 0.55, 0.2, Color3.fromRGB(30, 110, 190), Enum.Material.Neon).Transparency = 0.6
    for _ = 1, random:NextInteger(6, 9) do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(0, radius * 0.75)
        local size = random:NextNumber(5, 12)
        decor(model, "Floe", { Size = Vector3.new(size, 0.9, size * random:NextNumber(0.5, 0.9)), Material = Enum.Material.Glacier,
            Color = EUROPA.ice:Lerp(EUROPA.blue, random:NextNumber(0.1, 0.5)),
            CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * distance, 0.35, math.sin(angle) * distance)) * CFrame.Angles(random:NextNumber(-0.08, 0.08), random:NextNumber(0, 6.28), random:NextNumber(-0.08, 0.08)) })
    end
    -- The rim: slabs of the shell shoved up round the opening, tipped outward.
    local count = math.floor(radius * 0.8)
    for index = 1, count do
        local angle = (index + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local width, height, thick = random:NextNumber(10, 20), random:NextNumber(12, 28), random:NextNumber(2.5, 5)
        local base = at + out * (radius + random:NextNumber(0.5, 4))
        local frame = CFrame.lookAt(base, base + out) * CFrame.Angles(-random:NextNumber(0.3, 0.95), 0, random:NextNumber(-0.25, 0.25))
        decor(model, "RimSlab", { Size = Vector3.new(width, height, thick), Material = index % 3 == 0 and Enum.Material.Ice or Enum.Material.Glacier,
            Color = EUROPA.pale:Lerp(EUROPA.snow, random:NextNumber(0, 0.7)), CFrame = frame * CFrame.new(0, height * 0.32, 0) }).CastShadow = true
    end
    -- Rubble flung out over the ice.
    for _ = 1, 34 do
        local angle, distance = random:NextNumber(0, math.pi * 2), radius + random:NextNumber(5, 50)
        local size = random:NextNumber(1.5, 6) * (1 - (distance - radius) / 70)
        decor(model, "IceRubble", { Size = Vector3.new(size * 1.3, size * 0.7, size), Material = Enum.Material.Ice,
            Color = EUROPA.blue:Lerp(EUROPA.snow, random:NextNumber(0.2, 0.8)),
            CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * distance, size * 0.2, math.sin(angle) * distance)) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28)) })
    end
    -- Cracks running out across the shell, some forking.
    local crack = Color3.fromRGB(70, 110, 150)
    for index = 1, 11 do
        local angle = (index + random:NextNumber(-0.35, 0.35)) / 11 * math.pi * 2
        local from = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 2)
        local length = random:NextNumber(30, 90)
        for step = 1, 3 do
            local turn = angle + random:NextNumber(-0.35, 0.35)
            local to = from + Vector3.new(math.cos(turn), 0, math.sin(turn)) * (length / 3)
            local width = 2.2 - step * 0.5
            decor(model, "IceCrack", { Size = Vector3.new(width, 0.12, (to - from).Magnitude + width), Material = Enum.Material.SmoothPlastic, Color = crack,
                CFrame = CFrame.lookAt((from + to) / 2 + Vector3.new(0, 0.06, 0), to + Vector3.new(0, 0.06, 0)) })
            if step == 1 and random:NextNumber() < 0.5 then
                local fork = turn + random:NextNumber(0.5, 0.9) * (random:NextNumber() < 0.5 and -1 or 1)
                local tip = to + Vector3.new(math.cos(fork), 0, math.sin(fork)) * random:NextNumber(10, 22)
                decor(model, "IceCrack", { Size = Vector3.new(0.9, 0.12, (tip - to).Magnitude), Material = Enum.Material.SmoothPlastic, Color = crack,
                    CFrame = CFrame.lookAt((to + tip) / 2 + Vector3.new(0, 0.06, 0), tip + Vector3.new(0, 0.06, 0)) })
            end
            from = to
        end
    end
    for _ = 1, 5 do
        local angle, distance = random:NextNumber(0, math.pi * 2), radius + random:NextNumber(8, 30)
        Planets.mound(model, "SprayDrift", at + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance), random:NextNumber(6, 12), random:NextNumber(1, 2.5), EUROPA.snow, Enum.Material.Snow)
    end
    return model
end
builders[3] = function(folder, c)
    local random = Random.new(31)
    folder:SetAttribute("Dust", Color3.fromRGB(226, 238, 250))
    folder:SetAttribute("Meteors", true)
    local ground = disc(folder, "IceShell", c - Vector3.new(0, 3, 0), 75, 6, EUROPA.ice, Enum.Material.Glacier)
    -- Geyser cones, then crevasses and the drill hole, all cut into the ice.
    local vents = {}
    for _ = 1, 120 do
        if #vents >= 5 then break end
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 66)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local free = isClear(offset, 6, EUROPA_PROPS)
        for _, vent in vents do
            if (vent.at - c - offset).Magnitude < 16 then free = false end
        end
        if free then table.insert(vents, { at = c + offset, radius = 2.4, depth = 1.1, rim = 1.6 }) end
    end
    ground = Planets.carve(ground, vents, true)
    local cracks, glows = {}, {}
    for _ = 1, 160 do
        if #cracks >= 11 then break end
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(8, 62)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local length = random:NextNumber(12, 28)
        local free = isClear(offset, length / 2 + 1, EUROPA_PROPS)
        for _, vent in vents do
            if (vent.at - c - offset).Magnitude < length / 2 + 6 then free = false end
        end
        if free then
            local frame = CFrame.new(c + offset) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
            local cut = Instance.new("Part")
            cut.Anchored = true
            cut.Size = Vector3.new(1.5, 4.4, length)
            cut.CFrame = frame * CFrame.new(0, 0.2, 0)
            table.insert(cracks, cut)
            table.insert(glows, { frame = frame, length = length })
        end
    end
    local hole = Instance.new("Part")
    hole.Anchored = true
    hole.Shape = Enum.PartType.Cylinder
    hole.Size = Vector3.new(10, 7.2, 7.2)
    hole.CFrame = CFrame.new(c + DRILL) * CFrame.Angles(0, 0, math.rad(90))
    table.insert(cracks, hole)
    ground = Planets.subtract(ground, cracks, true)
    Planets.overlay(ground, Enum.NormalId.Right, "EuropaIce", 90, 0.15)
    -- Glowing water in the bottom of each crevasse, pulsing out of step with the others.
    for index, crack in glows do
        local strip = decor(folder, "Fissure", { Size = Vector3.new(1.2, 0.2, crack.length - 0.6), CFrame = crack.frame * CFrame.new(0, -1.9, 0), Color = EUROPA.glow, Material = Enum.Material.Neon })
        strip:SetAttribute("Period", 2.5 + index % 4 * 0.6)
        CollectionService:AddTag(strip, "Pulse")
    end
    for _, vent in vents do geyser(folder, vent.at, vent.radius, vent.depth, 1) end
    -- Ice chunks and frost drifts where there's room.
    for _ = 1, 50 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 70)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local size = random:NextNumber(1.2, 3.6)
        local free = isClear(offset, size + 1, EUROPA_PROPS)
        for _, vent in vents do
            if (vent.at - c - offset).Magnitude < 7 + size then free = false end
        end
        for _, crack in glows do
            if ((crack.frame.Position - c) - offset).Magnitude < crack.length / 2 + size + 1 then free = false end
        end
        if free then
            if random:NextNumber() < 0.7 then
                make(folder, "IceChunk", { Size = Vector3.new(size * 1.3, size * 0.8, size), Color = EUROPA.blue:Lerp(EUROPA.snow, random:NextNumber(0, 0.6)), Material = Enum.Material.Ice,
                    CFrame = CFrame.new(c + offset + Vector3.new(0, size * 0.15, 0)) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28)) })
            else
                Planets.mound(folder, "FrostDrift", c + offset, size * 2.5, size * 0.3, EUROPA.snow, Enum.Material.Snow, true)
            end
        end
    end
    drillRig(folder, c)
    europaPod(folder, c)
    -- Ice crystals glinting as they drift down (geyser fallout).
    local sky = decor(folder, "IceCrystals", { Size = Vector3.new(150, 2, 150), CFrame = CFrame.new(c + Vector3.new(0, 40, 0)), Transparency = 1 })
    local crystals = Instance.new("ParticleEmitter")
    crystals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    crystals.Shape = Enum.ParticleEmitterShape.Box
    crystals.EmissionDirection = Enum.NormalId.Bottom
    crystals.Rate, crystals.Lifetime = 26, NumberRange.new(10, 14)
    crystals.Speed, crystals.SpreadAngle = NumberRange.new(2, 4), Vector2.new(25, 25)
    crystals.Size = NumberSequence.new(0.25, 0.4)
    crystals.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 1) })
    crystals.Rotation, crystals.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-90, 90)
    crystals.LightEmission, crystals.LightInfluence = 0.8, 0.3
    crystals.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
    crystals.Parent = sky
    -- Jupiter fills the sky beyond the landing site, rising behind the ice; Io swings round
    -- it, crossing its face when on the near side (it starts there, about to cross).
    local jupiter = c + Vector3.new(260, 380, -1260)
    Planets.globe(folder, "Jupiter", { center = jupiter, diameter = 1100, texture = "Jupiter", tilt = 3, spin = 0.012,
        atmosphere = Color3.fromRGB(236, 200, 160), glow = 0.35, color = Color3.fromRGB(215, 170, 125) })
    local ioAxis = Vector3.new(0, 1, 0.08).Unit
    local toward = ((c - jupiter) - ioAxis * (c - jupiter):Dot(ioAxis)).Unit
    Planets.globe(folder, "Io", { center = jupiter + CFrame.fromAxisAngle(ioAxis, -0.35) * (toward * 760), diameter = 64, texture = "Io", spin = 0.02,
        color = Color3.fromRGB(222, 196, 92), orbit = { center = jupiter, axis = ioAxis, rate = 0.02 } })
    surroundings(folder, c, 75, { seed = 13, reach = 750, horizon = iceBlades(c), ridge = { color = EUROPA.snow, material = Enum.Material.Snow },
        overlays = { { "MoonMaria", 640, 0.35, Color3.fromRGB(170, 112, 86) }, { "EuropaIce", 300, 0.1 } },
        ring = { radius = 640, spread = 60, count = 22, size = { 180, 300 }, rock = Color3.fromRGB(200, 222, 242), rockAlt = Color3.fromRGB(168, 200, 232), material = Enum.Material.Glacier, seed = 23 },
        ground = EUROPA.ice, material = Enum.Material.Glacier, crag = EUROPA.pale, cragMaterial = Enum.Material.Ice })
    -- Out on the plain: double ridges (two parallel walls with a trough between), rafts
    -- of jumbled ice, and three big geysers that erupt on the horizon.
    local outer = Random.new(34)
    for _ = 1, 9 do
        local angle, distance = outer:NextNumber(0, math.pi * 2), outer:NextNumber(160, 420)
        local at = c + Vector3.new(math.cos(angle) * distance, -3, math.sin(angle) * distance)
        local yaw, length = outer:NextNumber(0, math.pi), outer:NextNumber(180, 420)
        local across = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
        for _, side in { -1, 1 } do
            Planets.dune(folder, at + across * side * 9, length, 12, outer:NextNumber(6, 10), yaw, EUROPA.pale, Enum.Material.Glacier)
        end
    end
    for _ = 1, 4 do
        local angle, distance = outer:NextNumber(0, math.pi * 2), outer:NextNumber(200, 400)
        local field = c + Vector3.new(math.cos(angle) * distance, -3, math.sin(angle) * distance)
        for _ = 1, 16 do
            local size = outer:NextNumber(8, 26)
            decor(folder, "IceRaft", { Size = Vector3.new(size, size * 0.3, size * outer:NextNumber(0.6, 1)), Material = Enum.Material.Glacier,
                Color = EUROPA.ice:Lerp(Color3.fromRGB(176, 128, 104), outer:NextNumber(0, 0.3)),
                CFrame = CFrame.new(field + Vector3.new(outer:NextNumber(-60, 60), 0, outer:NextNumber(-60, 60))) * CFrame.Angles(outer:NextNumber(-0.35, 0.35), outer:NextNumber(0, 6.28), outer:NextNumber(-0.35, 0.35)) }).CastShadow = true
        end
    end
    for _, spot in { Vector3.new(-260, -3, -330), Vector3.new(330, -3, -240), Vector3.new(-380, -3, 160) } do
        Planets.mound(folder, "GeyserCone", c + spot, 26, 9, EUROPA.snow, Enum.Material.Snow)
        geyser(folder, c + spot + Vector3.new(0, 9, 0), 5, 0, 4)
    end
    local breach = Random.new(41)
    for _, spot in { BREACH_EXIT, BREACH_ENTRY } do breachHole(folder, c + spot - Vector3.new(0, 3, 0), BREACH_RADIUS, breach) end
    folder:SetAttribute("OarfishExit", c + BREACH_EXIT - Vector3.new(0, 3, 0))
    folder:SetAttribute("OarfishEntry", c + BREACH_ENTRY - Vector3.new(0, 3, 0))
    folder:SetAttribute("OarfishRadius", BREACH_RADIUS)
    fence(folder, c, 75)
    return ground, Vector3.new(0, 0, 20)
end
-- 4 (Epic): a chunk of Saturn's rings. The platform is a big ring particle of frosted
-- rock (its lumpy underside shows past the edge) with glowing ice crystals, a lighthouse
-- beacon sweeping two beams, an ice harvester with a sled of glowing blocks, and a crew
-- pod tethered down so it can't drift off. No ground beyond: below lie three see-through
-- layers of glittering ring particles drifting at different speeds, with space showing
-- between them, and on the horizon the rings narrow to a bright edge-on line (the sky).
-- Chunks of ice float all round at every size, sliding past in opposite directions on
-- either side (ring particles nearer Saturn orbit faster) and tumbling. Beyond the
-- landing site Saturn hangs tilted with its whole ring system (C ring, bright B ring,
-- the Cassini division, A ring, thin F ring) wide open to view, their shadow across it;
-- Enceladus crosses the sky and hazy Titan hangs far off. The rings light everything a
-- little from below (Shared.Skies "Saturn").
local SATURN = { rock = Color3.fromRGB(146, 150, 162), frost = Color3.fromRGB(226, 232, 240), ice = Color3.fromRGB(208, 226, 244), dark = Color3.fromRGB(96, 100, 112),
    glow = Color3.fromRGB(120, 230, 255), metal = Color3.fromRGB(196, 198, 206), paint = Color3.fromRGB(236, 176, 60), hull = Color3.fromRGB(232, 234, 238) }
-- The ring plane lies this far below the platform's top.
local RING_PLANE = 60
local BEACON, HARVESTER, TETHERED = Vector3.new(-40, 0, -20), Vector3.new(42, 0, -26), Vector3.new(-24, 0, 46)
-- The UFO's crash site, on the platform's top at its rim: on the right, between the UFO
-- shop and the treadmill (the landed Saturn rocket, 58 studs across, hides about 32° either
-- side of straight ahead from the arrival). Kept clear of drifts, crystals and the rim's
-- boulders, so the wreck (30 across) settles on bare rock.
local UFO_CRASH = Vector3.new(62, 0, 14)
local SATURN_PROPS = { { BEACON, 6 }, { HARVESTER, 8 }, { TETHERED, 7 }, { UFO_CRASH, 17 } }
-- The lighthouse: a lattice mast whose head carries one long beam through it, so it
-- sweeps two beams round as it turns (PlanetSpin), a spotlight at each end.
local function lighthouse(parent, c)
    local at = c + BEACON
    local head = at + Vector3.new(0, 18, 0)
    for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
        strut(parent, "MastLeg", at + corner * 2.4, head + corner * 0.6 - Vector3.new(0, 1, 0), 0.3, SATURN.metal)
    end
    for height = 4, 14, 5 do
        local s = 2.4 - height / 18 * 1.8
        for _, edge in { { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1) }, { Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) }, { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1) }, { Vector3.new(1, 0, -1), Vector3.new(1, 0, 1) } } do
            strut(parent, "MastBrace", at + edge[1] * s + Vector3.new(0, height, 0), at + edge[2] * s + Vector3.new(0, height, 0), 0.15, SATURN.metal)
        end
    end
    make(parent, "MastBase", { Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)), Color = SATURN.dark, Material = Enum.Material.DiamondPlate })
    make(parent, "LampHouse", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.6, 2.6), CFrame = CFrame.new(head) * CFrame.Angles(0, 0, math.rad(90)), Color = SATURN.paint, Material = Enum.Material.Metal })
    local beam = decor(parent, "Beam", { Size = Vector3.new(70, 1.4, 1.4), CFrame = CFrame.new(head + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(255, 244, 200), Material = Enum.Material.Neon, Transparency = 0.82 })
    for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
        local spot = Instance.new("SpotLight")
        spot.Face, spot.Angle, spot.Range, spot.Brightness, spot.Color = face, 25, 60, 3, beam.Color
        spot.Parent = beam
    end
    beam:SetAttribute("SpinRate", 0.9)
    CollectionService:AddTag(beam, Planets.SpinTag)
    local beacon = decor(parent, "Beacon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = CFrame.new(head + Vector3.new(0, 1.8, 0)), Color = Color3.fromRGB(255, 70, 50), Material = Enum.Material.Neon })
    local red = Instance.new("PointLight")
    red.Color, red.Range, red.Brightness = beacon.Color, 12, 2
    red.Parent = beacon
    beacon:SetAttribute("Period", 1.4)
    CollectionService:AddTag(beacon, "Blinker")
end
-- The ice harvester: a machine with a drill arm in the rock, a conveyor, and a sled of
-- cut ice blocks glowing from within.
local function harvester(parent, c)
    local turn = CFrame.Angles(0, math.rad(-35), 0)
    local frame = CFrame.new(c + HARVESTER) * turn
    make(parent, "Harvester", { Size = Vector3.new(6, 3.4, 4.4), CFrame = frame * CFrame.new(0, 1.7, 0), Color = SATURN.paint, Material = Enum.Material.Metal })
    make(parent, "HarvesterCab", { Size = Vector3.new(2.6, 2, 3.6), CFrame = frame * CFrame.new(-1.6, 4.4, 0), Color = SATURN.hull, Material = Enum.Material.SmoothPlastic })
    decor(parent, "CabWindow", { Size = Vector3.new(0.15, 1, 2.8), CFrame = frame * CFrame.new(-2.95, 4.5, 0), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon })
    strut(parent, "DrillArm", (frame * CFrame.new(3, 2.6, 0)).Position, (frame * CFrame.new(5.6, -0.2, 0)).Position, 0.7, SATURN.metal)
    decor(parent, "DrillBit", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = frame * CFrame.new(5.6, 0, 0), Color = SATURN.dark, Material = Enum.Material.Metal })
    decor(parent, "Conveyor", { ClassName = "WedgePart", Size = Vector3.new(1.6, 2.6, 4), CFrame = frame * CFrame.new(0, 1.3, -4.2) * CFrame.Angles(0, math.pi, 0), Color = SATURN.dark, Material = Enum.Material.DiamondPlate })
    make(parent, "Sled", { Size = Vector3.new(5, 0.5, 4), CFrame = frame * CFrame.new(0, 0.25, -8.4), Color = SATURN.metal, Material = Enum.Material.Metal })
    for index, offset in { Vector3.new(-1.2, 1.1, -7.6), Vector3.new(1.2, 1.1, -7.6), Vector3.new(-1.2, 1.1, -9.2), Vector3.new(1.2, 1.1, -9.2), Vector3.new(0, 2.7, -8.4) } do
        local block = decor(parent, "IceBlock", { Size = Vector3.one * 1.6, CFrame = frame * CFrame.new(offset) * CFrame.Angles(0, index * 0.2, 0), Color = SATURN.glow, Material = Enum.Material.Glass, Transparency = 0.25 })
        if index == 5 then
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = SATURN.glow, 12, 1.5
            light.Parent = block
        end
    end
end
-- The crew pod: a dome tied down to pegs in the rock with four cables.
local function tetheredPod(parent, c)
    local at = c + TETHERED
    decor(parent, "PodDome", { Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(at), Color = SATURN.hull, Material = Enum.Material.SmoothPlastic }).CastShadow = true
    make(parent, "PodRing", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 9.6, 9.6), CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = SATURN.paint, Material = Enum.Material.Metal })
    for index = 1, 4 do
        local angle = index / 4 * math.pi * 2 + 0.4
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        decor(parent, "PodWindow", { Size = Vector3.new(1.6, 0.7, 0.15), CFrame = CFrame.lookAt(at + out * 4.25 + Vector3.new(0, 1.7, 0), at + out * 10 + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon })
        local peg = at + out * 8.5
        make(parent, "TetherPeg", { Size = Vector3.new(0.6, 1, 0.6), CFrame = CFrame.new(peg + Vector3.new(0, 0.5, 0)), Color = SATURN.dark, Material = Enum.Material.Metal })
        strut(parent, "Tether", at + out * 3.4 + Vector3.new(0, 2.6, 0), peg + Vector3.new(0, 0.9, 0), 0.1, SATURN.paint)
    end
end
-- A cluster of crystals (ice, by default) splaying from a glowing core (the core
-- breathes: Pulse).
local function crystals(parent, at, random, glow, glass)
    glow, glass = glow or SATURN.glow, glass or SATURN.ice
    local core = decor(parent, "CrystalCore", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)), Color = glow, Material = Enum.Material.Neon })
    core:SetAttribute("Period", random:NextNumber(2, 4))
    CollectionService:AddTag(core, "Pulse")
    local light = Instance.new("PointLight")
    light.Color, light.Range = glow, 9
    light.Parent = core
    for _ = 1, random:NextInteger(4, 7) do
        local height = random:NextNumber(2, 5)
        local lean = CFrame.Angles(0, random:NextNumber(0, 6.28), 0) * CFrame.Angles(random:NextNumber(0.2, 0.6), 0, 0)
        make(parent, "Crystal", { Size = Vector3.new(0.6, height, 0.6), CFrame = CFrame.new(at) * lean * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
            Color = glass, Material = Enum.Material.Glass, Transparency = 0.3 })
    end
end
builders[4] = function(folder, c)
    local random = Random.new(4)
    folder:SetAttribute("Dust", Color3.fromRGB(230, 236, 246))
    folder:SetAttribute("Meteors", true)
    local ground = disc(folder, "RingRock", c - Vector3.new(0, 3, 0), 65, 6, SATURN.rock, Enum.Material.Slate)
    Planets.overlay(ground, Enum.NormalId.Right, "RingRock", 40)
    -- The rest of the ring particle: lumpy rock and ice below and round the platform, its
    -- tops just under the surface, bulging out past the edge.
    Planets.blob(folder, "ChunkBody", CFrame.new(c - Vector3.new(0, 40, 0)), Vector3.new(156, 70, 146), SATURN.rock, Enum.Material.Slate)
    for index = 1, 14 do
        local angle = index / 14 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
        local size = Vector3.new(random:NextNumber(40, 80), random:NextNumber(30, 60), random:NextNumber(40, 80))
        local at = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(45, 72) - Vector3.new(0, size.Y / 2 + random:NextNumber(2, 25), 0)
        local pose = CFrame.new(at) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6.28), 0)
        local color = index % 3 == 0 and SATURN.ice or SATURN.rock:Lerp(SATURN.dark, random:NextNumber(0, 0.4))
        local material = index % 3 == 0 and Enum.Material.Glacier or Enum.Material.Slate
        if index % 2 == 0 then
            -- Angular slabs between the rounded lumps, so the underside reads as broken rock.
            decor(folder, "ChunkSlab", { Size = size * 0.7, CFrame = pose * CFrame.Angles(random:NextNumber(0, 6.28), 0, random:NextNumber(0, 6.28)), Color = color, Material = material }).CastShadow = true
        else
            Planets.blob(folder, "ChunkLump", pose, size, color, material)
        end
    end
    -- A rough lip of frosted boulders round the edge, so it isn't a cut disc.
    for index = 1, 30 do
        local angle = index / 30 * math.pi * 2 + random:NextNumber(-0.08, 0.08)
        local at = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(66, 70)
        if (at - c - Destinations.SignOffset).Magnitude > 10 and (at - c - UFO_CRASH).Magnitude > 20 then
            Planets.boulder(folder, at - Vector3.new(0, 2, 0), random:NextNumber(5, 10), SATURN.rock:Lerp(SATURN.frost, random:NextNumber(0, 0.6)), Enum.Material.Slate, random, false)
        end
    end
    -- Frost drifts, ice lumps and crystal clusters where there's room.
    for _ = 1, 50 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 60)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local kind, size = random:NextNumber(), random:NextNumber(1.2, 3.5)
        if isClear(offset, size + 1, SATURN_PROPS, 62) then
            if kind < 0.15 then
                crystals(folder, c + offset, random)
            elseif kind < 0.45 then
                Planets.mound(folder, "FrostDrift", c + offset, size * 2.5, size * 0.3, SATURN.frost, Enum.Material.Snow, true)
            else
                make(folder, "IceLump", { Size = Vector3.new(size * 1.2, size * 0.8, size), Color = SATURN.ice:Lerp(SATURN.rock, random:NextNumber(0, 0.5)), Material = Enum.Material.Ice,
                    CFrame = CFrame.new(c + offset + Vector3.new(0, size * 0.1, 0)) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28)) })
            end
        end
    end
    lighthouse(folder, c)
    harvester(folder, c)
    tetheredPod(folder, c)
    -- The ring plane: three see-through layers of ring particles round RING_PLANE (each a
    -- 4 x 4 grid of invisible 2048-stud tiles carrying the texture, out to the horizon
    -- line), at different scales, drifting along at different speeds (tag TextureDrift;
    -- PlanetController moves the textures), so they read as a deep, moving swarm.
    for _, layer in { { -RING_PLANE + 14, 256, 5 }, { -RING_PLANE, 512, -2.5 }, { -RING_PLANE - 16, 1024, 1 } } do
        for gx = -1.5, 1.5 do
            for gz = -1.5, 1.5 do
                local tile = decor(folder, "RingLayer", { Size = Vector3.new(2048, 1, 2048), CFrame = CFrame.new(c + Vector3.new(gx * 2048, layer[1], gz * 2048)), Transparency = 1 })
                local texture = Planets.overlay(tile, Enum.NormalId.Top, "RingSpeckle", layer[2])
                texture:SetAttribute("Speed", layer[3])
                CollectionService:AddTag(texture, "TextureDrift")
            end
        end
    end
    -- Chunks of ice everywhere, sliding along X at a speed set by how far they are toward
    -- or away from Saturn (tag RingDrift; PlanetController wraps them round), tumbling.
    -- Within reach of the landing camera's line and the rocket's descent (z from -120 to
    -- 260) they keep below the platform.
    local field = Random.new(44)
    for _ = 1, 150 do
        local offset = Vector3.new(field:NextNumber(-1400, 1400), 0, field:NextNumber(-1400, 1400))
        local flat = offset.Magnitude
        if flat > 95 then
            local low = offset.Z > -120 and offset.Z < 260
            local y = low and field:NextNumber(-RING_PLANE + 4, -14) or field:NextNumber(-RING_PLANE + 4, 120)
            local size = field:NextNumber(0.6, 1.4) * (3 + flat * 0.025)
            local spot = c + offset + Vector3.new(0, y, 0)
            local spin = CFrame.Angles(field:NextNumber(0, 6.28), field:NextNumber(0, 6.28), field:NextNumber(0, 6.28))
            -- Mostly lumpy ellipsoids of dirty ice; now and then a flat shard.
            local chunk
            if field:NextNumber() < 0.8 then
                chunk = Planets.blob(folder, "RingChunk", CFrame.new(spot) * spin, Vector3.new(size, size * field:NextNumber(0.45, 0.85), size * field:NextNumber(0.55, 0.95)),
                    SATURN.frost:Lerp(SATURN.rock, field:NextNumber(0, 0.7)), field:NextNumber() < 0.5 and Enum.Material.Ice or Enum.Material.Glacier)
            else
                chunk = decor(folder, "RingChunk", { Size = Vector3.new(size, size * field:NextNumber(0.15, 0.3), size * field:NextNumber(0.4, 0.7)), CFrame = CFrame.new(spot) * spin,
                    Material = Enum.Material.Ice, Color = SATURN.ice:Lerp(SATURN.rock, field:NextNumber(0, 0.4)) })
                chunk.CastShadow = true
            end
            chunk:SetAttribute("Speed", -offset.Z * 0.012)
            chunk:SetAttribute("Origin", c.X)
            chunk:SetAttribute("Span", 1400)
            CollectionService:AddTag(chunk, "RingDrift")
            if size < 14 then
                chunk:SetAttribute("SpinRate", field:NextNumber(-0.4, 0.4))
                CollectionService:AddTag(chunk, Planets.SpinTag)
            end
        end
    end
    -- Glitter: fine ice drifting past the platform.
    local glitterBox = decor(folder, "RingGlitter", { Size = Vector3.new(260, 60, 260), CFrame = CFrame.new(c + Vector3.new(0, 10, 0)), Transparency = 1 })
    local glitter = Instance.new("ParticleEmitter")
    glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    glitter.Shape = Enum.ParticleEmitterShape.Box
    glitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    glitter.EmissionDirection = Enum.NormalId.Right
    glitter.Rate, glitter.Lifetime = 30, NumberRange.new(6, 10)
    glitter.Speed, glitter.SpreadAngle = NumberRange.new(0.5, 2), Vector2.new(30, 30)
    glitter.Size = NumberSequence.new(0.18, 0.3)
    glitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
    glitter.Rotation, glitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-60, 60)
    glitter.LightEmission, glitter.LightInfluence = 0.8, 0.3
    glitter.Color = ColorSequence.new(Color3.fromRGB(240, 246, 255))
    glitter.Parent = glitterBox
    -- Saturn off to the left of the landing site (41 degrees from the arrival, so even a
    -- Tier 5 rocket hides no more than its rings' tip), its pole tipped 28 degrees toward
    -- us and leaning a little, so its rings open into a wide ellipse above the horizon.
    local saturnAt, pose = c + Vector3.new(-1500, 400, -1700), CFrame.Angles(0, 0, math.rad(-12)) * CFrame.Angles(math.rad(28), 0, 0)
    Planets.globe(folder, "Saturn", { center = saturnAt, diameter = 860, rotation = pose, texture = "Saturn", spin = 0.004,
        atmosphere = Color3.fromRGB(240, 220, 180), glow = 0.4, color = Color3.fromRGB(225, 195, 140) })
    -- The faint C ring, the B ring (brighter outside), the Cassini division, the A ring
    -- split by the Encke gap, and the thin F ring. Neon, darkened: the sun lights the rings
    -- at a low angle, which left them a dull grey-brown; this keeps them glowing warm.
    local glow = Enum.Material.Neon
    Planets.rings(folder, "SaturnRings", CFrame.new(saturnAt) * pose, 430, {
        { 1.24, 1.52, Color3.fromRGB(96, 88, 74), 0.5, glow },
        { 1.52, 1.68, Color3.fromRGB(150, 136, 110), 0.1, glow },
        { 1.68, 1.95, Color3.fromRGB(178, 164, 134), 0, glow },
        { 2.03, 2.2, Color3.fromRGB(146, 134, 110), 0.12, glow },
        { 2.215, 2.27, Color3.fromRGB(128, 118, 98), 0.2, glow },
        { 2.31, 2.33, Color3.fromRGB(160, 150, 130), 0.3, glow },
    })
    orbitingMoon(folder, c, "Enceladus", { size = Vector3.one * 46, radius = 1300, axis = Vector3.new(-0.3, 0.9, 1), rate = 0.01, lead = 0.5, spin = 0.02,
        texture = "Enceladus", color = SATURN.frost })
    -- Titan high above Saturn, on the sunward side, so its day side faces us.
    Planets.globe(folder, "Titan", { center = c + Vector3.new(-900, 1100, -1400), diameter = 80, texture = "Titan", spin = 0.005,
        atmosphere = Color3.fromRGB(230, 170, 90), glow = 0.3, color = Color3.fromRGB(214, 150, 70) })
    -- Where the UFO crashes (SaturnUfoController).
    folder:SetAttribute("UfoCrash", c + UFO_CRASH)
    fence(folder, c, 65)
    return ground, Vector3.new(0, 0, 18)
end
-- 5 (Legendary): a shard of obsidian adrift at the edge of a black hole. The shard has
-- fissures glowing violet (cut into it, breathing), a rim and an underside of jagged
-- obsidian blades, crystal clusters, an observatory scope trained on the hole, and
-- shards floating and turning over it. No ground: the shard hangs in the void among
-- debris that wheels slowly round the hole. The hole, off to the right of the landing
-- site: a black horizon ringed by a thin photon ring and a lensed halo (the far side
-- of the disk bent into view over and under it; both face the player), an accretion
-- disk seen nearly edge on, white-hot inside to deep red out, with hot clumps whirling
-- round it (faster the closer in), twin jets from its poles, and streams of matter
-- (from the debris and from the shard's own edge) spiralling in. The disk is the light:
-- the sun stands behind it, hidden (Shared.Skies "BlackHole").
local VOID = { rock = Color3.fromRGB(26, 20, 38), shard = Color3.fromRGB(46, 36, 66), glass = Color3.fromRGB(130, 70, 210), glow = Color3.fromRGB(180, 90, 255),
    hot = Color3.fromRGB(255, 214, 160), metal = Color3.fromRGB(150, 150, 172), jet = Color3.fromRGB(176, 166, 255) }
-- The hole, relative to the centre, and its horizon's radius.
local HOLE, HORIZON = Vector3.new(700, 330, -1100), 210
local SCOPE = Vector3.new(-40, 0, -22)
local VOID_PROPS = { { SCOPE, 8 } }
-- Puts `part` in orbit round `center` about `axis` (tag PlanetOrbit; PlanetController).
local function orbit(part, center, axis, rate)
    part:SetAttribute("OrbitCenter", center)
    part:SetAttribute("OrbitAxis", axis.Unit)
    part:SetAttribute("OrbitRate", rate)
    CollectionService:AddTag(part, Planets.OrbitTag)
end
local function spin(part, rate)
    part:SetAttribute("SpinRate", rate)
    CollectionService:AddTag(part, Planets.SpinTag)
end
-- An obsidian shard: a pointed blade, or a tumbled slab, or a rounded lump.
local function shard(parent, at, size, random)
    local kind = random:NextNumber()
    local color = VOID.shard:Lerp(VOID.rock, random:NextNumber())
    local tumble = CFrame.new(at) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28))
    if kind < 0.45 then
        return decor(parent, "Shard", { ClassName = "WedgePart", Size = Vector3.new(size * 0.3, size, size * 0.6), CFrame = tumble, Color = color, Material = Enum.Material.Glass })
    elseif kind < 0.8 then
        return decor(parent, "Shard", { Size = Vector3.new(size, size * 0.4, size * 0.7), CFrame = tumble, Color = color, Material = Enum.Material.Basalt })
    end
    return Planets.blob(parent, "Shard", tumble, Vector3.new(size, size * 0.6, size * 0.8), color, Enum.Material.Basalt)
end
-- The scope: a tripod, a long tube aimed at the hole, a sunshade, and a dish beside it.
local function observatory(parent, c, hole)
    local at = c + SCOPE
    local mount = at + Vector3.new(0, 5, 0)
    for index = 1, 3 do
        local angle = index / 3 * math.pi * 2
        strut(parent, "TripodLeg", mount, at + Vector3.new(math.cos(angle) * 3.4, 0, math.sin(angle) * 3.4), 0.3, VOID.metal)
    end
    local aim = CFrame.lookAt(mount, hole)
    make(parent, "ScopeTube", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 1.8, 1.8), CFrame = aim * CFrame.new(0, 0.8, -2) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(230, 230, 236), Material = Enum.Material.SmoothPlastic })
    decor(parent, "ScopeShade", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 2.3, 2.3), CFrame = aim * CFrame.new(0, 0.8, -6.8) * CFrame.Angles(0, math.rad(90), 0), Color = VOID.rock, Material = Enum.Material.Metal })
    decor(parent, "ScopeLens", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.9, 1.9), CFrame = aim * CFrame.new(0, 0.8, -7.65) * CFrame.Angles(0, math.rad(90), 0), Color = VOID.hot, Material = Enum.Material.Neon })
    make(parent, "ScopeMount", { Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(mount), Color = VOID.metal, Material = Enum.Material.Metal })
    local console = at + Vector3.new(4.5, 0, 3)
    make(parent, "Console", { Size = Vector3.new(2.6, 2.4, 1.4), CFrame = CFrame.lookAt(console + Vector3.new(0, 1.2, 0), at + Vector3.new(0, 1.2, 0)), Color = Color3.fromRGB(60, 58, 74), Material = Enum.Material.Metal })
    local screen = decor(parent, "ConsoleScreen", { Size = Vector3.new(2, 1.1, 0.1), CFrame = CFrame.lookAt(console + Vector3.new(0, 2.1, 0), at + Vector3.new(0, 2.6, 0)) * CFrame.new(0, 0, -0.72), Color = VOID.glow, Material = Enum.Material.Neon })
    screen:SetAttribute("Period", 2.4)
    CollectionService:AddTag(screen, "Pulse")
    strut(parent, "DishMast", at + Vector3.new(-5, 0, 3), at + Vector3.new(-5, 4.5, 3), 0.2, VOID.metal)
    decor(parent, "Dish", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.6, 3.6), CFrame = CFrame.lookAt(at + Vector3.new(-5, 5, 3), hole) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(230, 230, 236), Material = Enum.Material.SmoothPlastic })
end
-- A stream of matter flowing from `from` into the disk at `to`, arcing (a Beam whose
-- texture scrolls along it).
local function stream(parent, from, to, width, curve)
    local anchor = decor(parent, "StreamAnchor", { Size = Vector3.one, CFrame = CFrame.new(from), Transparency = 1 })
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent = anchor
    a1.Parent = anchor
    a1.WorldPosition = to
    local beam = Instance.new("Beam")
    beam.Attachment0, beam.Attachment1 = a0, a1
    beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    beam.TextureMode, beam.TextureLength, beam.TextureSpeed = Enum.TextureMode.Wrap, 60, 0.6
    beam.Width0, beam.Width1 = width, width * 0.25
    beam.CurveSize0, beam.CurveSize1 = curve, -curve * 0.5
    beam.FaceCamera = true
    beam.LightEmission, beam.LightInfluence = 1, 0
    beam.Segments = 40
    beam.Color = ColorSequence.new(VOID.glow, Color3.fromRGB(255, 170, 90))
    beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0.2) })
    beam.Parent = anchor
    return beam
end
builders[5] = function(folder, c)
    local random = Random.new(51)
    folder:SetAttribute("Dust", Color3.fromRGB(140, 100, 200))
    local hole = c + HOLE
    -- Glossy black glass (Basalt went sandy under the warm light).
    local ground = disc(folder, "Obsidian", c - Vector3.new(0, 3, 0), 70, 6, Color3.fromRGB(16, 12, 24), Enum.Material.Glass)
    -- Fissures cut into the shard, glowing violet in their depths.
    local cracks, glows = {}, {}
    for _ = 1, 160 do
        if #cracks >= 10 then break end
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 60)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local length = random:NextNumber(14, 30)
        if isClear(offset, length / 2 + 1, VOID_PROPS) then
            local frame = CFrame.new(c + offset) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
            local cut = Instance.new("Part")
            cut.Anchored = true
            cut.Size = Vector3.new(1.4, 4.4, length)
            cut.CFrame = frame * CFrame.new(0, 0.2, 0)
            table.insert(cracks, cut)
            table.insert(glows, { frame = frame, length = length })
        end
    end
    ground = Planets.subtract(ground, cracks, true)
    -- Faint veins over the glassy rock (Europa's lineae, tinted violet).
    Planets.overlay(ground, Enum.NormalId.Right, "EuropaIce", 60, 0.35, Color3.fromRGB(190, 120, 255))
    for index, crack in glows do
        local strip = decor(folder, "VoidFissure", { Size = Vector3.new(1.1, 0.2, crack.length - 0.6), CFrame = crack.frame * CFrame.new(0, -1.9, 0), Color = VOID.glow, Material = Enum.Material.Neon })
        strip:SetAttribute("Period", 2 + index % 3 * 0.7)
        CollectionService:AddTag(strip, "Pulse")
    end
    -- A rim of obsidian blades leaning outward (clear of the landing spot and the sign),
    -- and the underside: blades hanging point down round a lumpy core.
    for index = 1, 34 do
        local angle = index / 34 * math.pi * 2 + random:NextNumber(-0.06, 0.06)
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local at = c + out * random:NextNumber(67, 71)
        local height = random:NextNumber(5, 16)
        local frame = CFrame.lookAt(at - Vector3.new(0, 1.5, 0), at - Vector3.new(0, 1.5, 0) + out) * CFrame.Angles(math.rad(-random:NextNumber(10, 30)), 0, 0)
        if (at - c - Destinations.LandingOffset).Magnitude > 38 and (at - c - Destinations.SignOffset).Magnitude > 12 then
            iceBlade(folder, frame, height * 0.55, height, random:NextNumber(1.5, 3), VOID.shard:Lerp(VOID.rock, random:NextNumber()), Enum.Material.Glass)
        end
    end
    Planets.blob(folder, "ShardBody", CFrame.new(c - Vector3.new(0, 30, 0)), Vector3.new(150, 50, 140), VOID.rock, Enum.Material.Basalt)
    for _ = 1, 22 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(0, 62)
        local height = random:NextNumber(30, 95)
        local at = c + Vector3.new(math.cos(angle) * distance, -4, math.sin(angle) * distance)
        iceBlade(folder, CFrame.new(at) * CFrame.Angles(math.pi + random:NextNumber(-0.2, 0.2), random:NextNumber(0, 6.28), random:NextNumber(-0.2, 0.2)),
            height * random:NextNumber(0.35, 0.55), height, random:NextNumber(5, 12), VOID.rock:Lerp(VOID.shard, random:NextNumber()), Enum.Material.Basalt)
    end
    -- Crystal clusters and loose shards where there's room.
    for _ = 1, 40 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(10, 62)
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local size = random:NextNumber(1.2, 3)
        local free = isClear(offset, size + 1, VOID_PROPS)
        for _, crack in glows do
            if ((crack.frame.Position - c) - offset).Magnitude < crack.length / 2 + size + 1 then free = false end
        end
        if free then
            if random:NextNumber() < 0.3 then
                crystals(folder, c + offset, random, VOID.glow, VOID.glass)
            else
                make(folder, "Obsidian", { ClassName = "WedgePart", Size = Vector3.new(size * 0.6, size * 1.4, size), Color = VOID.shard, Material = Enum.Material.Glass,
                    CFrame = CFrame.new(c + offset + Vector3.new(0, size * 0.5, 0)) * CFrame.Angles(random:NextNumber(-0.4, 0.4), random:NextNumber(0, 6.28), random:NextNumber(-0.4, 0.4)) })
            end
        end
    end
    observatory(folder, c, hole)
    -- Shards floating over the platform, turning slowly (clear of the rocket's descent).
    for _ = 1, 30 do
        local offset = Vector3.new(random:NextNumber(-220, 220), random:NextNumber(18, 110), random:NextNumber(-220, 220))
        if (offset * Vector3.new(1, 0, 1) - Destinations.LandingOffset).Magnitude > 95 then
            spin(shard(folder, c + offset, random:NextNumber(3, 12), random), random:NextNumber(-0.3, 0.3))
        end
    end
    -- Violet motes drifting up off the shard toward the hole.
    local motesBox = decor(folder, "VoidMotes", { Size = Vector3.new(140, 2, 140), CFrame = CFrame.new(c + Vector3.new(0, 1, 0)), Transparency = 1 })
    local motes = Instance.new("ParticleEmitter")
    motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    motes.Shape = Enum.ParticleEmitterShape.Box
    motes.EmissionDirection = Enum.NormalId.Top
    motes.Rate, motes.Lifetime = 18, NumberRange.new(8, 12)
    motes.Speed, motes.SpreadAngle = NumberRange.new(0.5, 1.5), Vector2.new(20, 20)
    motes.Acceleration = HOLE.Unit * 0.6
    motes.Size = NumberSequence.new(0.3, 0.15)
    motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
    motes.LightEmission = 1
    motes.Color = ColorSequence.new(VOID.glow, VOID.hot)
    motes.Parent = motesBox
    -- The hole. `view` faces the platform: the photon ring and the lensed halo lie square
    -- to it; the disk is tipped 12 degrees off edge on (so its top shows) and rolled a
    -- little.
    local view = CFrame.lookAt(hole, c)
    local diskFrame = view * CFrame.Angles(0, 0, math.rad(8)) * CFrame.Angles(math.rad(-12), 0, 0)
    local glow = Enum.Material.Neon
    decor(folder, "EventHorizon", { Shape = Enum.PartType.Ball, Size = Vector3.one * HORIZON * 2, CFrame = CFrame.new(hole), Color = Color3.new(0, 0, 0), Material = Enum.Material.Neon })
    -- The disk and the lensed halo are nested flattened spheres, not cut rings (server-
    -- made CSG rings drew unreliably here on clients). Each smaller layer is thicker, so it
    -- bulges through the one round it: graded bands, white-hot inside to deep red out,
    -- with the horizon covering the middle.
    local function layers(name, frame, bands)
        local model = Instance.new("Model")
        model.Name = name
        model.Parent = folder
        for index, band in bands do
            local part = Planets.blob(model, "Layer" .. index, frame, Vector3.new(band[1] * HORIZON * 2, band[2], band[1] * HORIZON * 2), band[3], glow)
            part.Transparency, part.CastShadow = band[4], false
        end
    end
    -- (Darker than they look: Neon blooms, and full orange read as yellow.)
    layers("AccretionDisk", diskFrame, {
        { 4.8, 4, Color3.fromRGB(140, 36, 28), 0.5 },
        { 3.3, 8, Color3.fromRGB(230, 96, 40), 0.1 },
        { 2.2, 14, Color3.fromRGB(255, 222, 176), 0 },
    })
    layers("Lensing", view * CFrame.Angles(math.rad(90), 0, 0), {
        { 2.3, 6, Color3.fromRGB(220, 110, 60), 0.85 },
        { 1.45, 12, Color3.fromRGB(255, 176, 96), 0.5 },
        { 1.09, 20, Color3.fromRGB(255, 248, 230), 0 },
    })
    -- Hot clumps whirling round the disk, faster the closer in.
    for _ = 1, 26 do
        local r = random:NextNumber(1.6, 4.4) * HORIZON
        local angle = random:NextNumber(0, math.pi * 2)
        local at = hole + diskFrame:VectorToWorldSpace(Vector3.new(math.cos(angle), random:NextNumber(-0.01, 0.01), math.sin(angle))) * r
        local size = random:NextNumber(16, 40)
        local clump = Planets.blob(folder, "HotClump", CFrame.new(at), Vector3.new(size, size * 0.4, size), VOID.hot:Lerp(Color3.fromRGB(255, 120, 60), (r / HORIZON - 1.6) / 2.8), glow)
        clump.CastShadow = false
        orbit(clump, hole, diskFrame.UpVector, 0.25 * (2 / (r / HORIZON)) ^ 1.5)
    end
    -- Twin jets from the poles, tapering and fading out.
    for _, side in { 1, -1 } do
        local axis = diskFrame.UpVector * side
        for index = 1, 4 do
            local length = 400
            local mid = hole + axis * (HORIZON * 0.6 + length * (index - 0.5))
            local width = 70 - index * 12
            -- A bright core inside a wide, faint sheath.
            decor(folder, "Jet", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, width * 0.3, width * 0.3), CFrame = CFrame.lookAt(mid, mid + axis) * CFrame.Angles(0, math.rad(90), 0),
                Color = VOID.jet, Material = glow, Transparency = 0.3 + index * 0.14 })
            decor(folder, "JetSheath", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, width, width), CFrame = CFrame.lookAt(mid, mid + axis) * CFrame.Angles(0, math.rad(90), 0),
                Color = Color3.fromRGB(110, 120, 255), Material = glow, Transparency = 0.8 + index * 0.04 })
        end
    end
    -- Streams spiralling in: from three far shards, and one torn off the platform's edge.
    local edge = diskFrame:VectorToWorldSpace(Vector3.new(-1, 0, 0.3)).Unit * HORIZON * 4.2
    stream(folder, c + Vector3.new(60, -8, -55), hole + edge, 16, 260)
    stream(folder, c + Vector3.new(-700, 160, -900), hole + diskFrame:VectorToWorldSpace(Vector3.new(-0.6, 0, -0.8)) * HORIZON * 4.4, 36, 420)
    stream(folder, c + Vector3.new(1600, -120, -700), hole + diskFrame:VectorToWorldSpace(Vector3.new(0.9, 0, 0.4)) * HORIZON * 4.4, 40, -380)
    stream(folder, c + Vector3.new(500, 520, -400), hole + diskFrame:VectorToWorldSpace(Vector3.new(0.2, 0, 1)) * HORIZON * 4, 30, 300)
    -- Warning beacons round the rim, blinking red, and more matter torn off the shard's
    -- own edge, close enough to watch it go (BlackHoleController adds the tremors, the
    -- hole swelling through the stay and the singularity at its end).
    for index = 1, 10 do
        local angle = index / 10 * math.pi * 2 + 0.15
        local at = c + Vector3.new(math.cos(angle) * 63, 0, math.sin(angle) * 63)
        if (at - c - Destinations.LandingOffset).Magnitude > 40 and (at - c - Destinations.SignOffset).Magnitude > 14 then
            strut(folder, "BeaconPost", at, at + Vector3.new(0, 7, 0), 0.25, VOID.metal)
            local lamp = decor(folder, "WarningBeacon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CFrame.new(at + Vector3.new(0, 7.6, 0)),
                Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon })
            lamp:SetAttribute("Period", 1.1 + index % 2 * 0.3)
            CollectionService:AddTag(lamp, "Pulse")
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 50, 40), 16, 1.5
            light.Parent = lamp
        end
    end
    for _, torn in { { Vector3.new(-55, -8, -38), Vector3.new(-0.9, 0, 0.5) }, { Vector3.new(28, -12, -64), Vector3.new(-0.3, 0, 1) }, { Vector3.new(68, -6, 12), Vector3.new(0.7, 0, 0.7) } } do
        stream(folder, c + torn[1], hole + diskFrame:VectorToWorldSpace(torn[2].Unit) * HORIZON * 3.4, 12, 220)
    end
    -- The debris field: shards of every size all round, wheeling slowly about the hole
    -- (about the disk's axis). Ones whose path would come near the platform only turn.
    local field = Random.new(53)
    local axis = diskFrame.UpVector
    for _ = 1, 140 do
        local offset = Vector3.new(field:NextNumber(-1500, 1500), field:NextNumber(-260, 320), field:NextNumber(-1500, 1300))
        local at = c + offset
        if (offset * Vector3.new(1, 0, 1)).Magnitude > 180 and (at - hole).Magnitude > HORIZON * 5.2 then
            local size = field:NextNumber(0.6, 1.4) * (6 + (offset * Vector3.new(1, 0, 1)).Magnitude * 0.03)
            local piece = shard(folder, at, size, field)
            local rate = 0.004 * (1100 / math.max(400, (at - hole).Magnitude)) ^ 1.5
            local clear = true
            for step = 1, 36 do
                local point = hole + CFrame.fromAxisAngle(axis, step / 36 * math.pi * 2) * (at - hole)
                if (point - c).Magnitude < 260 then clear = false break end
            end
            if clear then orbit(piece, hole, axis, rate) end
            if size < 30 then spin(piece, field:NextNumber(-0.25, 0.25)) end
        end
    end
    fence(folder, c, 70)
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
    -- a countdown screen (client fills it in) and the exit hatch. Panelled walls with
    -- ribs, sloped panels into the ceiling corners (a rounded hull), padded seats with
    -- headrests and harnesses, framed portholes looking out on stars, aisle lights to
    -- the hatch, consoles either side of the screen, and pipes and vents overhead.
    local cabinFolder = Instance.new("Folder")
    cabinFolder.Name = "RocketCabin"
    cabinFolder.Parent = root
    -- Three times the floor of the first cabin (48 x 34, user 2026-10-20), a little taller.
    local cc, size = config.CabinPosition, Vector3.new(84, 20, 60)
    local hull, panel, rib = Color3.fromRGB(226, 230, 238), Color3.fromRGB(206, 212, 224), Color3.fromRGB(150, 158, 174)
    local light, accent, dark = Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 176, 40), Color3.fromRGB(40, 44, 56)
    local floor = make(cabinFolder, "CabinFloor", { Size = Vector3.new(size.X, 1, size.Z), CFrame = CFrame.new(cc - Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(70, 76, 92), Material = Enum.Material.DiamondPlate })
    CollectionService:AddTag(floor, Destinations.CabinTag)
    floor:SetAttribute("CabinSize", size)
    make(cabinFolder, "CabinCeiling", { Size = Vector3.new(size.X, 1, size.Z), CFrame = CFrame.new(cc + Vector3.new(0, size.Y + 0.5, 0)), Color = hull })
    -- A carpet runner down the aisle, its edges lit in blue.
    decor(cabinFolder, "AisleCarpet", { Size = Vector3.new(size.X - 4, 0.06, 4), CFrame = CFrame.new(cc + Vector3.new(0, 0.03, 0)), Color = Color3.fromRGB(46, 60, 110), Material = Enum.Material.Fabric })
    for _, side in { -1, 1 } do
        decor(cabinFolder, "AisleLight", { Size = Vector3.new(size.X - 4, 0.08, 0.2), CFrame = CFrame.new(cc + Vector3.new(0, 0.05, side * 2.1)), Color = light, Material = Enum.Material.Neon })
    end
    for _, side in { -1, 1 } do
        -- The long walls run past the end walls so the corners are closed (flush, they
        -- left a 1-stud gap at each corner that showed the outside through it).
        make(cabinFolder, "CabinWall", { Size = Vector3.new(size.X + 2, size.Y + 2, 1), CFrame = CFrame.new(cc + Vector3.new(0, size.Y / 2, side * (size.Z / 2 + 0.5))), Color = hull })
        make(cabinFolder, "CabinWall", { Size = Vector3.new(1, size.Y + 2, size.Z), CFrame = CFrame.new(cc + Vector3.new(side * (size.X / 2 + 0.5), size.Y / 2, 0)), Color = hull })
        local z = side * (size.Z / 2 - 0.05)
        -- A dark kick panel along the bottom and an accent stripe at shoulder height.
        decor(cabinFolder, "KickPanel", { Size = Vector3.new(size.X, 2, 0.15), CFrame = CFrame.new(cc + Vector3.new(0, 1, z)), Color = dark, Material = Enum.Material.Metal })
        decor(cabinFolder, "WallStripe", { Size = Vector3.new(size.X, 0.35, 0.15), CFrame = CFrame.new(cc + Vector3.new(0, 6.2, z)), Color = accent })
        -- Sloped panels into the ceiling corners.
        decor(cabinFolder, "CeilingSlope", { Size = Vector3.new(size.X, 0.4, 6), CFrame = CFrame.new(cc + Vector3.new(0, size.Y - 1.6, side * (size.Z / 2 - 2.4))) * CFrame.Angles(side * math.rad(-35), 0, 0), Color = panel })
        -- Ribs: the hull frames, every eight studs up the wall, between the portholes.
        for x = -size.X / 2 + 6, size.X / 2 - 6, 8 do
            decor(cabinFolder, "Rib", { Size = Vector3.new(0.6, size.Y - 3, 0.5), CFrame = CFrame.new(cc + Vector3.new(x, (size.Y - 3) / 2, z - side * 0.2)), Color = rib, Material = Enum.Material.Metal })
        end
        -- Ceiling light strip in a housing, a pipe run and vents above.
        decor(cabinFolder, "LightHousing", { Size = Vector3.new(size.X - 4, 0.4, 1.6), CFrame = CFrame.new(cc + Vector3.new(0, size.Y - 0.2, side * size.Z * 0.24)), Color = rib, Material = Enum.Material.Metal })
        decor(cabinFolder, "LightStrip", { Size = Vector3.new(size.X - 4.4, 0.3, 1), CFrame = CFrame.new(cc + Vector3.new(0, size.Y - 0.4, side * size.Z * 0.24)), Color = light, Material = Enum.Material.Neon })
        decor(cabinFolder, "Pipe", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.X, 0.5, 0.5), CFrame = CFrame.new(cc + Vector3.new(0, size.Y - 0.6, side * (size.Z / 2 - 4.5))), Color = Color3.fromRGB(180, 186, 198), Material = Enum.Material.Metal })
        for x = -size.X / 2 + 9, size.X / 2 - 9, 10 do
            decor(cabinFolder, "Vent", { Size = Vector3.new(2, 0.15, 1.2), CFrame = CFrame.new(cc + Vector3.new(x, size.Y - 0.05, side * 3)), Color = dark, Material = Enum.Material.DiamondPlate })
        end
        -- Portholes: a thick bolted frame, a dark rim and a pane of starry space.
        for x = -size.X / 2 + 10, size.X / 2 - 10, 8 do
            local at = cc + Vector3.new(x, 10.5, z)
            local turn = CFrame.Angles(0, math.rad(90), 0)
            decor(cabinFolder, "PortholeFrame", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 6.2, 6.2), CFrame = CFrame.new(at) * turn, Color = rib, Material = Enum.Material.Metal })
            decor(cabinFolder, "PortholeRim", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5.2, 5.2), CFrame = CFrame.new(at) * turn, Color = dark, Material = Enum.Material.Metal })
            decor(cabinFolder, "Porthole", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 4.6, 4.6), CFrame = CFrame.new(at) * turn, Color = Color3.fromRGB(18, 26, 70), Material = Enum.Material.Neon })
            for index = 1, 3 do
                local star = decor(cabinFolder, "Star", { Shape = Enum.PartType.Ball, Size = Vector3.one * (0.18 + index * 0.06),
                    CFrame = CFrame.new(at + Vector3.new(math.sin(x + index * 2.1) * 1.5, math.cos(x * 0.7 + index) * 1.4, -side * 0.4)), Color = Color3.fromRGB(230, 236, 255), Material = Enum.Material.Neon })
                star:SetAttribute("Period", 2 + index * 0.7)
                CollectionService:AddTag(star, "Pulse")
            end
            for bolt = 1, 8 do
                local angle = bolt / 8 * math.pi * 2
                decor(cabinFolder, "Bolt", { Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 2.85, math.sin(angle) * 2.85, -side * 0.3)), Color = Color3.fromRGB(110, 116, 130), Material = Enum.Material.Metal })
            end
        end
    end
    -- Seat rows face the screen on the -X wall, split by a centre aisle (z = 0) that
    -- runs from the screen to the exit hatch. Each seat: a pedestal, a padded cushion and
    -- reclined back, a headrest, armrests and a pair of harness straps.
    local seatColor, seatDark = Color3.fromRGB(70, 104, 196), Color3.fromRGB(54, 82, 160)
    -- Rows every 7 studs from just behind the consoles to a clear stretch before the
    -- hatch; seats every 5.5 studs out from the aisle to the walls.
    local seatZ = {}
    for z = 7.7, size.Z / 2 - 4, 5.5 do
        table.insert(seatZ, z)
        table.insert(seatZ, -z)
    end
    for x = -size.X / 2 + 12, size.X / 2 - 16, 7 do
        for _, z in seatZ do
            local at = cc + Vector3.new(x, 1, z)
            make(cabinFolder, "SeatPedestal", { Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(at + Vector3.new(0, -0.6, 0)), Color = dark, Material = Enum.Material.Metal })
            make(cabinFolder, "SeatBase", { Size = Vector3.new(3, 1.2, 3.4), CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)), Color = seatColor, Material = Enum.Material.SmoothPlastic })
            make(cabinFolder, "SeatBack", { Size = Vector3.new(0.8, 4, 3.4), CFrame = CFrame.new(at + Vector3.new(1.6, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(-8)), Color = seatDark, Material = Enum.Material.SmoothPlastic })
            decor(cabinFolder, "Headrest", { Size = Vector3.new(0.9, 1.2, 2.2), CFrame = CFrame.new(at + Vector3.new(1.9, 4.9, 0)), Color = seatColor, Material = Enum.Material.SmoothPlastic })
            for _, arm in { -1.8, 1.8 } do
                decor(cabinFolder, "Armrest", { Size = Vector3.new(2.6, 0.4, 0.4), CFrame = CFrame.new(at + Vector3.new(0.2, 1.6, arm)), Color = dark, Material = Enum.Material.Metal })
            end
            for _, strap in { -0.8, 0.8 } do
                decor(cabinFolder, "Harness", { Size = Vector3.new(0.12, 3, 0.35), CFrame = CFrame.new(at + Vector3.new(1.15, 2.4, strap)) * CFrame.Angles(0, 0, math.rad(-8)), Color = accent, Material = Enum.Material.Fabric })
            end
        end
    end
    local screen = make(cabinFolder, "CountdownScreen", { Size = Vector3.new(0.4, 11, 32), CFrame = CFrame.new(cc + Vector3.new(-size.X / 2 + 0.3, 10, 0)), Color = Color3.fromRGB(10, 14, 28), Material = Enum.Material.Neon })
    decor(cabinFolder, "ScreenBezel", { Size = Vector3.new(0.3, 12.2, 33.2), CFrame = CFrame.new(cc + Vector3.new(-size.X / 2 + 0.1, 10, 0)), Color = dark, Material = Enum.Material.Metal })
    -- Consoles either side of the screen: angled desks of blinking buttons.
    for _, side in { -1, 1 } do
        local at = cc + Vector3.new(-size.X / 2 + 2, 0, side * 20)
        make(cabinFolder, "Console", { Size = Vector3.new(3, 3.2, 6), CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0)), Color = rib, Material = Enum.Material.Metal })
        local desk = CFrame.new(at + Vector3.new(0.4, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(-25))
        decor(cabinFolder, "ConsoleDesk", { Size = Vector3.new(2.6, 0.3, 6), CFrame = desk, Color = dark })
        local colors = { Color3.fromRGB(255, 80, 70), Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 210, 70), light }
        for index = 0, 7 do
            local button = decor(cabinFolder, "Button", { Size = Vector3.new(0.5, 0.2, 0.5), CFrame = desk * CFrame.new(-0.5 + (index % 2), 0.2, -2.2 + math.floor(index / 2) * 1.4), Color = colors[index % 4 + 1], Material = Enum.Material.Neon })
            button:SetAttribute("Period", 0.9 + index * 0.23)
            CollectionService:AddTag(button, "Blinker")
        end
    end
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
    -- The exit hatch: a metal door in a hazard-striped frame, a wheel on it and a green
    -- EXIT light over it.
    local exit = make(cabinFolder, "ExitHatch", { Size = Vector3.new(0.6, 9, 6), CFrame = CFrame.new(cc + Vector3.new(size.X / 2 - 0.2, 4.5, 0)), Color = Color3.fromRGB(190, 196, 210), Material = Enum.Material.Metal })
    for index = 0, 8 do
        for _, z in { -3.4, 3.4 } do
            decor(cabinFolder, "HatchStripe", { Size = Vector3.new(0.3, 1, 0.8), CFrame = CFrame.new(cc + Vector3.new(size.X / 2 - 0.1, 0.5 + index, z)), Color = index % 2 == 0 and accent or dark })
        end
    end
    decor(cabinFolder, "HatchWheel", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.4, 2.4), CFrame = CFrame.new(cc + Vector3.new(size.X / 2 - 0.6, 5, 0)), Color = Color3.fromRGB(220, 60, 50), Material = Enum.Material.Metal })
    decor(cabinFolder, "ExitSign", { Size = Vector3.new(0.3, 1, 3), CFrame = CFrame.new(cc + Vector3.new(size.X / 2 - 0.2, 10.2, 0)), Color = Color3.fromRGB(80, 255, 120), Material = Enum.Material.Neon })
    local cabin = { center = cc, size = size, arrival = cc + Vector3.new(4, 3, 0), exit = exit, screen = screen }
    return built, cabin
end

return Destinations
