--[[
    The land round the Gym District (z > 112, outside the district's walls; the site never
    grows there), so no view from the gyms is an empty field:
    - East: a running track round a sports field, stands and floodlights; past it a farm
      (crop strips, barn, silo, fence).
    - West: astronaut training (a centrifuge whose arm turns, a training pool with a
      mock capsule under a gantry); past it a pine wood with a campsite.
    - Behind: a lake with a sandy shore, a jetty, boats, reeds and benches; then rolling
      hills under a forest, an observatory on the highest.
    Parkland.Clear lists the footprints the plain's random trees and clutter keep off.
    All scenery: nothing collides (the perimeter's barrier keeps players out anyway).
]]
local CollectionService = game:GetService("CollectionService")
local Planets = require(script.Parent.Planets)
local Parkland = {}

local PLAIN = -0.35 -- the plain's top (SiteSurroundsService.PlainDepth)
local GRASS = Color3.fromRGB(104, 124, 82)
local CONCRETE, STEEL, WHITE = Color3.fromRGB(176, 176, 170), Color3.fromRGB(150, 156, 166), Color3.fromRGB(236, 238, 242)
local WOOD, WATER, SAND = Color3.fromRGB(128, 92, 60), Color3.fromRGB(62, 128, 176), Color3.fromRGB(214, 196, 150)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

-- x0, x1, z0, z1 of each piece, for the plain's trees and clutter to avoid.
Parkland.Clear = {
    { 115, 260, 120, 320 },     -- running track and stands
    { 260, 600, 130, 470 },     -- farm
    { -250, -110, 130, 260 },   -- centrifuge
    { -290, -140, 265, 345 },   -- training pool
    { -230, 230, 300, 600 },    -- lake
    { -90, 90, 720, 880 },      -- observatory hill top
}

local HILLS = {
    { Vector3.new(0, PLAIN, 800), 230, 70 },
    { Vector3.new(-330, PLAIN, 760), 200, 46 },
    { Vector3.new(340, PLAIN, 740), 210, 52 },
    { Vector3.new(-640, PLAIN, 620), 220, 60 },
    { Vector3.new(650, PLAIN, 640), 200, 44 },
    { Vector3.new(-170, PLAIN, 1060), 260, 64 },
    { Vector3.new(260, PLAIN, 1080), 240, 58 },
    -- A bigger, farther row closing the gap to the mountains, and out to the sides.
    { Vector3.new(-700, PLAIN, 1350), 380, 120 },
    { Vector3.new(0, PLAIN, 1500), 420, 150 },
    { Vector3.new(720, PLAIN, 1320), 360, 110 },
    { Vector3.new(-1150, PLAIN, 900), 340, 100 },
    { Vector3.new(1180, PLAIN, 860), 320, 95 },
    { Vector3.new(-1250, PLAIN, 420), 300, 80 },
    { Vector3.new(1260, PLAIN, 380), 300, 85 },
}

-- Height of the hills' ground at `x, z` (each mound a sphere cap), for trees on them.
local function groundAt(x, z)
    local best = PLAIN
    for _, hill in HILLS do
        local center, radius, height = hill[1], hill[2], hill[3]
        local diameter = radius * radius / height + height
        local r = diameter / 2
        local d = Vector2.new(x - center.X, z - center.Z).Magnitude
        if d < radius then best = math.max(best, PLAIN + height - r + math.sqrt(r * r - d * d)) end
    end
    return best
end

function Parkland.clear(at)
    for _, r in Parkland.Clear do
        if at.X > r[1] - 30 and at.X < r[2] + 30 and at.Z > r[3] - 30 and at.Z < r[4] + 30 then return false end
    end
    return true
end

-- A running track: an oval band (two straights joined by half circles) round a pitch.
local function track(parent, make, center, straight, radius)
    local model = Instance.new("Model")
    model.Name = "RunningTrack"
    model.Parent = parent
    local red, width = Color3.fromRGB(184, 78, 58), 10
    make(model, "Pitch", Vector3.new(radius * 2 - width, 0.2, straight + radius), CFrame.new(center + Vector3.new(0, 0.12, 0)), Color3.fromRGB(96, 150, 70), Enum.Material.Grass)
    for _, side in { -1, 1 } do
        make(model, "Lane", Vector3.new(width, 0.25, straight), CFrame.new(center + Vector3.new(side * radius, 0.15, 0)), red, Enum.Material.Concrete)
        make(model, "LaneLine", Vector3.new(0.4, 0.27, straight), CFrame.new(center + Vector3.new(side * radius, 0.16, 0)), WHITE)
        local turn = center + Vector3.new(0, 0.15, side * straight / 2)
        for step = 0, 11 do
            local angle = (step + 0.5) / 12 * math.pi
            local at = turn + Vector3.new(math.cos(angle) * radius, 0, side * math.sin(angle) * radius)
            local tangent = Vector3.new(-math.sin(angle), 0, side * math.cos(angle))
            local length = 2 * radius * math.sin(math.pi / 24) + 0.6
            make(model, "Lane", Vector3.new(width, 0.25, length), CFrame.lookAt(at, at + tangent), red, Enum.Material.Concrete)
            make(model, "LaneLine", Vector3.new(0.4, 0.27, length), CFrame.lookAt(at + Vector3.new(0, 0.01, 0), at + tangent), WHITE)
        end
        -- Goal posts at each end of the pitch.
        local goal = center + Vector3.new(0, 0, side * (straight / 2 + radius - width - 6))
        for _, x in { -7, 7 } do
            make(model, "GoalPost", Vector3.new(0.6, 8, 0.6), CFrame.new(goal + Vector3.new(x, 4, 0)), WHITE)
        end
        make(model, "GoalBar", Vector3.new(14.6, 0.6, 0.6), CFrame.new(goal + Vector3.new(0, 8, 0)), WHITE)
    end
    -- Stands down the outer side, and floodlights at the corners.
    local stands = center + Vector3.new(radius + width + 10, 0, 0)
    for row = 0, 4 do
        make(model, "Stand", Vector3.new(4, 1.5 + row * 1.5, straight * 0.8), CFrame.new(stands + Vector3.new(row * 4 - 8, (1.5 + row * 1.5) / 2, 0)),
            row % 2 == 0 and Color3.fromRGB(70, 110, 190) or Color3.fromRGB(220, 220, 226))
    end
    make(model, "StandRoof", Vector3.new(24, 1, straight * 0.8), CFrame.new(stands + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(-8)), WHITE)
    for _, z in { -0.4, 0.4 } do
        make(model, "StandPost", Vector3.new(1, 13, 1), CFrame.new(stands + Vector3.new(10, 6.5, z * straight * 0.8)), STEEL, Enum.Material.Metal)
    end
    for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
        local at = center + Vector3.new(corner[1] * (radius + 9), 0, corner[2] * (straight / 2 + radius * 0.7))
        make(model, "FloodPole", Vector3.new(1.4, 40, 1.4), CFrame.new(at + Vector3.new(0, 20, 0)), STEEL, Enum.Material.Metal)
        make(model, "FloodLamp", Vector3.new(7, 4, 1.5), CFrame.lookAt(at + Vector3.new(0, 41, 0), center), Color3.fromRGB(255, 248, 220), Enum.Material.Neon)
    end
end

-- A centrifuge: a round pad, a hub tower and a long arm with a capsule at each end,
-- the arm turning (tagged WindTurbineRotor: SpaceportController turns it about its hub).
local function centrifuge(parent, make, at)
    local model = Instance.new("Model")
    model.Name = "Centrifuge"
    model.Parent = parent
    make(model, "CentrifugePad", Vector3.new(1, 76, 76), CFrame.new(at + Vector3.new(0, 0.3, 0)) * UPRIGHT, CONCRETE, Enum.Material.Concrete).Shape = Enum.PartType.Cylinder
    make(model, "CentrifugeRing", Vector3.new(1.2, 70, 70), CFrame.new(at + Vector3.new(0, 0.35, 0)) * UPRIGHT, Color3.fromRGB(240, 180, 30)).Shape = Enum.PartType.Cylinder
    make(model, "CentrifugeFloor", Vector3.new(1.4, 66, 66), CFrame.new(at + Vector3.new(0, 0.4, 0)) * UPRIGHT, CONCRETE, Enum.Material.Concrete).Shape = Enum.PartType.Cylinder
    make(model, "CentrifugeTower", Vector3.new(14, 8, 8), CFrame.new(at + Vector3.new(0, 7, 0)) * UPRIGHT, STEEL, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
    local rotor = Instance.new("Model")
    rotor.Name = "Rotor"
    rotor.Parent = model
    -- The hub looks straight up, so turning about its look axis sweeps the arm round.
    local hub = make(rotor, "Hub", Vector3.new(6, 6, 6), CFrame.lookAt(at + Vector3.new(0, 15, 0), at + Vector3.new(0, 30, 0)), WHITE)
    hub.Shape = Enum.PartType.Ball
    rotor.PrimaryPart = hub
    make(rotor, "Arm", Vector3.new(58, 2.4, 2.4), hub.CFrame, Color3.fromRGB(70, 110, 190), Enum.Material.Metal)
    for _, side in { -1, 1 } do
        local capsule = make(rotor, "Capsule", Vector3.new(8, 6, 6), hub.CFrame * CFrame.new(side * 30, 0, -1), WHITE)
        capsule.Shape = Enum.PartType.Ball
        make(rotor, "CapsuleWindow", Vector3.new(2, 2, 0.4), hub.CFrame * CFrame.new(side * 30, 0, -4.1) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(40, 60, 90), Enum.Material.Glass)
    end
    CollectionService:AddTag(rotor, "WindTurbineRotor")
    -- Control booth beside it.
    local booth = at + Vector3.new(48, 0, -10)
    make(model, "Booth", Vector3.new(14, 9, 10), CFrame.new(booth + Vector3.new(0, 4.5, 0)), WHITE)
    make(model, "BoothWindow", Vector3.new(0.4, 3, 8), CFrame.new(booth + Vector3.new(-7.1, 6, 0)), Color3.fromRGB(60, 90, 130), Enum.Material.Glass)
    make(model, "BoothRoof", Vector3.new(15, 0.8, 11), CFrame.new(booth + Vector3.new(0, 9.4, 0)), Color3.fromRGB(70, 110, 190))
end

-- The training pool: a rimmed pool of water with a mock capsule under the surface and a
-- gantry crane over it.
local function pool(parent, make, center, size)
    local model = Instance.new("Model")
    model.Name = "TrainingPool"
    model.Parent = parent
    make(model, "PoolRim", Vector3.new(size.X + 8, 2.4, size.Y + 8), CFrame.new(center + Vector3.new(0, 0.85, 0)), CONCRETE, Enum.Material.Concrete)
    make(model, "PoolBasin", Vector3.new(size.X, 0.4, size.Y), CFrame.new(center + Vector3.new(0, 1.9, 0)), Color3.fromRGB(40, 120, 150), Enum.Material.SmoothPlastic)
    make(model, "MockCapsule", Vector3.new(14, 10, 10), CFrame.new(center + Vector3.new(-10, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(210, 214, 222), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
    local water = make(model, "PoolWater", Vector3.new(size.X, 0.3, size.Y), CFrame.new(center + Vector3.new(0, 2.15, 0)), Color3.fromRGB(80, 170, 210), Enum.Material.Glass)
    water.Transparency, water.Reflectance = 0.35, 0.15
    for _, x in { -size.X / 2 + 4, size.X / 2 - 4 } do
        for _, z in { -size.Y / 2 - 3, size.Y / 2 + 3 } do
            make(model, "GantryLeg", Vector3.new(1.4, 26, 1.4), CFrame.new(center + Vector3.new(x, 13, z)), Color3.fromRGB(240, 180, 30), Enum.Material.Metal)
        end
        make(model, "GantryBeam", Vector3.new(1.6, 1.6, size.Y + 8), CFrame.new(center + Vector3.new(x, 26, 0)), Color3.fromRGB(240, 180, 30), Enum.Material.Metal)
    end
    make(model, "GantryBridge", Vector3.new(size.X - 6, 2, 3), CFrame.new(center + Vector3.new(0, 26.5, 0)), Color3.fromRGB(240, 180, 30), Enum.Material.Metal)
    make(model, "GantryCable", Vector3.new(0.3, 18, 0.3), CFrame.new(center + Vector3.new(-10, 17, 0)), Color3.fromRGB(40, 40, 46))
end

-- The lake: overlapping discs of water over a wider sandy shore, a jetty with boats,
-- reeds round the edge and benches on the shore.
local LAKE = {
    { Vector3.new(0, 0, 450), 250 },
    { Vector3.new(-100, 0, 410), 170 },
    { Vector3.new(110, 0, 480), 180 },
    { Vector3.new(40, 0, 360), 130 },
}
local function lake(parent, make, random)
    local model = Instance.new("Model")
    model.Name = "Lake"
    model.Parent = parent
    for index, disc in LAKE do
        make(model, "Shore", Vector3.new(0.3, disc[2] + 24, disc[2] + 24), CFrame.new(disc[1] + Vector3.new(0, PLAIN + 0.05 + index * 0.01, 0)) * UPRIGHT, SAND, Enum.Material.Sand).Shape = Enum.PartType.Cylinder
    end
    for index, disc in LAKE do
        local water = make(model, "Water", Vector3.new(0.3, disc[2], disc[2]), CFrame.new(disc[1] + Vector3.new(0, PLAIN + 0.2 + index * 0.01, 0)) * UPRIGHT, WATER, Enum.Material.Glass)
        water.Shape, water.Reflectance, water.Transparency = Enum.PartType.Cylinder, 0.25, 0.05
    end
    -- The jetty out from the near shore, two rowboats tied up.
    local jetty = Vector3.new(30, PLAIN + 1.2, 300)
    make(model, "Jetty", Vector3.new(8, 0.6, 70), CFrame.new(jetty + Vector3.new(0, 0, 35)), WOOD, Enum.Material.WoodPlanks)
    for z = 4, 66, 12 do
        for _, x in { -3.6, 3.6 } do
            make(model, "JettyPost", Vector3.new(0.8, 3, 0.8), CFrame.new(jetty + Vector3.new(x, -0.6, z)), Color3.fromRGB(96, 70, 48), Enum.Material.Wood)
        end
    end
    for _, spot in { { 9, 48, 10 }, { -9, 58, -15 } } do
        local frame = CFrame.new(jetty + Vector3.new(spot[1], -0.6, spot[2])) * CFrame.Angles(0, math.rad(spot[3]), 0)
        make(model, "Boat", Vector3.new(4, 1.4, 11), frame, Color3.fromRGB(196, 70, 54), Enum.Material.Wood)
        make(model, "BoatSeat", Vector3.new(3.6, 0.3, 1.2), frame * CFrame.new(0, 0.6, 0), WOOD, Enum.Material.Wood)
    end
    -- Reeds and rocks round the water's edge, benches on the shore facing the water.
    for _ = 1, 70 do
        local disc = LAKE[random:NextInteger(1, #LAKE)]
        local angle = random:NextNumber(0, math.pi * 2)
        local at = disc[1] + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (disc[2] / 2 + random:NextNumber(-2, 6))
        local inside = false
        for _, other in LAKE do
            if other ~= disc and (Vector2.new(at.X, at.Z) - Vector2.new(other[1].X, other[1].Z)).Magnitude < other[2] / 2 - 4 then inside = true end
        end
        if not inside then
            if random:NextNumber() < 0.75 then
                for _ = 1, random:NextInteger(3, 6) do
                    local height = random:NextNumber(3, 6)
                    make(model, "Reed", Vector3.new(0.35, height, 0.35), CFrame.new(at + Vector3.new(random:NextNumber(-2, 2), PLAIN + height / 2, random:NextNumber(-2, 2))) * CFrame.Angles(random:NextNumber(-0.15, 0.15), 0, random:NextNumber(-0.15, 0.15)),
                        Color3.fromRGB(110, 140, 70):Lerp(Color3.fromRGB(170, 160, 90), random:NextNumber()), Enum.Material.Grass)
                end
            else
                Planets.boulder(model, at + Vector3.new(0, PLAIN, 0), random:NextNumber(3, 7), Color3.fromRGB(128, 124, 116), Enum.Material.Slate, random)
            end
        end
    end
    for _, spot in { { -150, 330 }, { 170, 360 }, { -200, 470 }, { 210, 540 } } do
        local at = Vector3.new(spot[1], PLAIN, spot[2])
        local look = CFrame.lookAt(at, Vector3.new(0, PLAIN, 450))
        make(model, "BenchSeat", Vector3.new(6, 0.4, 1.8), look * CFrame.new(0, 1.8, 0), WOOD, Enum.Material.Wood)
        make(model, "BenchBack", Vector3.new(6, 1.6, 0.3), look * CFrame.new(0, 2.8, 0.9), WOOD, Enum.Material.Wood)
        for _, x in { -2.6, 2.6 } do
            make(model, "BenchLeg", Vector3.new(0.4, 1.8, 1.6), look * CFrame.new(x, 0.9, 0), STEEL, Enum.Material.Metal)
        end
    end
end

-- The farm: crop strips in two colours, a red barn with a pitched roof, a silo and a
-- post-and-rail fence round the fields.
local function farm(parent, make, random)
    local model = Instance.new("Model")
    model.Name = "Farm"
    model.Parent = parent
    local x0, x1, z0, z1 = 290, 580, 150, 450
    local crops = { Color3.fromRGB(196, 176, 84), Color3.fromRGB(120, 150, 64), Color3.fromRGB(150, 120, 80) }
    local fields = { { x0, 430, z0, 300 }, { 440, x1, z0, 300 }, { x0, 430, 310, z1 } }
    for index, f in fields do
        local color = crops[(index - 1) % #crops + 1]
        for x = f[1], f[2] - 8, 8 do
            make(model, "CropRow", Vector3.new(5, 1.2 + random:NextNumber(0, 0.4), f[4] - f[3]), CFrame.new(x + 4, PLAIN + 0.6, (f[3] + f[4]) / 2),
                color:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.08)), Enum.Material.Grass)
        end
    end
    -- Barn and silo in the corner left by the fields.
    local barn = Vector3.new(510, PLAIN, 380)
    make(model, "Barn", Vector3.new(40, 22, 30), CFrame.new(barn + Vector3.new(0, 11, 0)), Color3.fromRGB(170, 52, 42), Enum.Material.WoodPlanks)
    -- The gable: a square beam turned 45 degrees along the ridge, half in the walls; the
    -- roof's two slopes lie on its upper faces.
    make(model, "BarnGable", Vector3.new(39.6, 21.2, 21.2), CFrame.new(barn + Vector3.new(0, 22, 0)) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(170, 52, 42), Enum.Material.WoodPlanks)
    for _, side in { -1, 1 } do
        make(model, "BarnRoof", Vector3.new(42, 1, 23), CFrame.new(barn + Vector3.new(0, 29.8, side * 7.8)) * CFrame.Angles(math.rad(side * 45), 0, 0), Color3.fromRGB(80, 70, 66), Enum.Material.Metal)
    end
    make(model, "BarnDoor", Vector3.new(0.4, 14, 12), CFrame.new(barn + Vector3.new(-20.1, 7, 0)), WHITE, Enum.Material.WoodPlanks)
    local silo = Vector3.new(555, PLAIN, 420)
    make(model, "Silo", Vector3.new(44, 14, 14), CFrame.new(silo + Vector3.new(0, 22, 0)) * UPRIGHT, Color3.fromRGB(196, 200, 206), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
    make(model, "SiloCap", Vector3.new(14, 14, 14), CFrame.new(silo + Vector3.new(0, 44, 0)), Color3.fromRGB(120, 130, 140), Enum.Material.Metal).Shape = Enum.PartType.Ball
    -- Fence round the fields.
    for _, edge in { { x0 - 6, z0 - 6, x1 + 6, z0 - 6 }, { x0 - 6, z0 - 6, x0 - 6, z1 + 6 }, { x1 + 6, z0 - 6, x1 + 6, 340 } } do
        local a, b = Vector3.new(edge[1], PLAIN, edge[2]), Vector3.new(edge[3], PLAIN, edge[4])
        local length = (b - a).Magnitude
        local frame = CFrame.lookAt((a + b) / 2, b)
        for _, y in { 2, 3.6 } do
            make(model, "FenceRail", Vector3.new(0.3, 0.4, length), frame * CFrame.new(0, y, 0), WOOD, Enum.Material.Wood)
        end
        for offset = -length / 2, length / 2, 12 do
            make(model, "FencePost", Vector3.new(0.6, 4.4, 0.6), frame * CFrame.new(0, 2.2, offset), Color3.fromRGB(96, 70, 48), Enum.Material.Wood)
        end
    end
end

-- A campsite in the west wood: tents round a fire that glows and smokes.
local function campsite(parent, make, at)
    local model = Instance.new("Model")
    model.Name = "Campsite"
    model.Parent = parent
    local fire = make(model, "Campfire", Vector3.new(2.4, 1.2, 2.4), CFrame.new(at + Vector3.new(0, PLAIN + 0.6, 0)), Color3.fromRGB(255, 130, 40), Enum.Material.Neon)
    local flames = Instance.new("Fire")
    flames.Size, flames.Heat = 5, 8
    flames.Parent = fire
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 150, 70), 22, 2
    light.Parent = fire
    for index, color in { Color3.fromRGB(230, 120, 40), Color3.fromRGB(60, 130, 200), Color3.fromRGB(110, 160, 70) } do
        local angle = index / 3 * math.pi * 2
        local spot = at + Vector3.new(math.cos(angle) * 14, PLAIN, math.sin(angle) * 14)
        local face = CFrame.lookAt(spot, Vector3.new(at.X, PLAIN, at.Z))
        for _, side in { -1, 1 } do
            make(model, "TentSide", Vector3.new(0.3, 7, 8), face * CFrame.new(side * 2.4, 2.8, 0) * CFrame.Angles(0, 0, math.rad(side * -35)), color, Enum.Material.Fabric)
        end
    end
    for _, angle in { 0.5, 2.6, 4.6 } do
        make(model, "Log", Vector3.new(6, 1.4, 1.4), CFrame.new(at + Vector3.new(math.cos(angle) * 6, PLAIN + 0.7, math.sin(angle) * 6)) * CFrame.Angles(0, -angle + math.pi / 2, 0), WOOD, Enum.Material.Wood).Shape = Enum.PartType.Cylinder
    end
end

-- The observatory: a drum and a dome with its slit open, on top of the highest hill.
local function observatory(parent, make, at)
    local model = Instance.new("Model")
    model.Name = "Observatory"
    model.Parent = parent
    make(model, "ObservatoryDrum", Vector3.new(16, 30, 30), CFrame.new(at + Vector3.new(0, 8, 0)) * UPRIGHT, WHITE).Shape = Enum.PartType.Cylinder
    make(model, "ObservatoryDome", Vector3.new(30, 30, 30), CFrame.new(at + Vector3.new(0, 16, 0)), Color3.fromRGB(214, 218, 226), Enum.Material.Metal).Shape = Enum.PartType.Ball
    make(model, "DomeSlit", Vector3.new(5, 15, 0.6), CFrame.new(at + Vector3.new(0, 24, 0)) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, 0, -14.6), Color3.fromRGB(30, 34, 44))
    make(model, "ObservatoryBand", Vector3.new(1.4, 30.4, 30.4), CFrame.new(at + Vector3.new(0, 15.5, 0)) * UPRIGHT, Color3.fromRGB(70, 110, 190)).Shape = Enum.PartType.Cylinder
end

-- A big broadleaf for the far woods: big enough to still draw from the gyms (small
-- trees drop out at lower graphics quality long before the hills do).
local function bigTree(parent, at, random)
    local height = random:NextNumber(34, 52)
    local trunk = Instance.new("Part")
    trunk.Name, trunk.Anchored, trunk.CanCollide, trunk.CanQuery, trunk.CanTouch = "Trunk", true, false, false, false
    trunk.Size, trunk.CFrame = Vector3.new(3, height * 0.55, 3), CFrame.new(at + Vector3.new(0, height * 0.27, 0))
    trunk.Color, trunk.Material = Color3.fromRGB(100, 74, 52), Enum.Material.Wood
    trunk.Parent = parent
    local green = Color3.fromRGB(64, 104, 52):Lerp(Color3.fromRGB(112, 140, 64), random:NextNumber())
    for index = 1, 3 do
        local size = height * random:NextNumber(0.5, 0.7)
        local offset = index == 1 and Vector3.zero or Vector3.new(random:NextNumber(-0.25, 0.25), random:NextNumber(-0.1, 0.1), random:NextNumber(-0.25, 0.25)) * height
        Planets.blob(parent, "Canopy", CFrame.new(at + Vector3.new(0, height * 0.72, 0) + offset), Vector3.new(size, size * 0.8, size),
            green:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.12)), Enum.Material.Grass)
    end
end

-- helpers: { make, tree, roundTree, clutter } from SiteSurroundsService.
function Parkland.build(land, helpers)
    local make = helpers.make
    local random = Random.new(2610)
    local model = Instance.new("Model")
    model.Name = "Parkland"
    model.Parent = land
    for index, hill in HILLS do
        Planets.mound(model, "Hill", hill[1], hill[2], hill[3], GRASS:Lerp(Color3.fromRGB(86, 116, 66), index % 3 / 3), Enum.Material.Grass)
    end
    track(model, make, Vector3.new(180, PLAIN, 220), 90, 40)
    centrifuge(model, make, Vector3.new(-180, PLAIN, 195))
    pool(model, make, Vector3.new(-215, PLAIN, 300), Vector2.new(120, 50))
    lake(model, make, random)
    farm(model, make, random)
    campsite(model, make, Vector3.new(-420, 0, 330))
    observatory(model, make, Vector3.new(0, groundAt(0, 800) - 1, 800))
    -- Woods: pines west (round the campsite) and a broadleaf band over the hills behind
    -- the lake, thinning out toward the mountains; bushes and flowers between.
    local woods = Instance.new("Folder")
    woods.Name = "Woods"
    woods.Parent = model
    local function plant(kind, x, z)
        local at = Vector3.new(x, groundAt(x, z), z)
        if Parkland.clear(at) then kind(woods, at, random) return true end
        return false
    end
    local planted = 0
    while planted < 90 do
        local x, z = random:NextNumber(-640, -260), random:NextNumber(150, 560)
        if (Vector2.new(x, z) - Vector2.new(-420, 330)).Magnitude > 24 and plant(helpers.tree, x, z) then planted += 1 end
    end
    planted = 0
    while planted < 120 do
        local x, z = random:NextNumber(-900, 900), random:NextNumber(600, 1250)
        if plant(random:NextNumber() < 0.35 and helpers.tree or helpers.roundTree, x, z) then planted += 1 end
    end
    -- Big trees over the hills, near and far, in clumps.
    planted = 0
    while planted < 170 do
        local hill = HILLS[random:NextInteger(1, #HILLS)]
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(0, hill[2] * 0.9)
        local x, z = hill[1].X + math.cos(angle) * distance, hill[1].Z + math.sin(angle) * distance
        for _ = 1, random:NextInteger(2, 4) do
            local tx, tz = x + random:NextNumber(-30, 30), z + random:NextNumber(-30, 30)
            if plant(bigTree, tx, tz) then planted += 1 end
        end
    end
    planted = 0
    while planted < 60 do
        local x, z = random:NextNumber(-260, 260), random:NextNumber(270, 640)
        if plant(helpers.roundTree, x, z) then planted += 1 end
    end
    for _ = 1, 120 do
        local x, z = random:NextNumber(-700, 700), random:NextNumber(130, 900)
        local at = Vector3.new(x, groundAt(x, z), z)
        if math.abs(x) > 70 or z > 290 then
            if Parkland.clear(at) then helpers.clutter(woods, at, random) end
        end
    end
    return model
end

return Parkland
