-- Builds the rocket cabin (where boarded players wait for liftoff) and one isolated
-- destination per rocket design (Config.Destinations, by ModelTier), far from the
-- main map. Primitives only; Phase 5 swaps in art and sky. Each destination has a
-- walled play area, an ArrivalPad tagged DestinationArrival (attribute Tier) and two
-- gym spots (WorldService puts a bench and a treadmill there).
local CollectionService = game:GetService("CollectionService")
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
local function sign(parent, position, facing, text, color)
    local board = make(parent, "WelcomeSign", { Size = Vector3.new(30, 7, 0.6), CFrame = CFrame.lookAt(position, position + facing), Color = color })
    local surface = Instance.new("SurfaceGui")
    surface.Face = Enum.NormalId.Front
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 30
    surface.Parent = board
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.2
    label.Parent = surface
    return board
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
-- Every destination keeps these clear (offsets from its centre): the gym (bench left,
-- treadmill right of the arrival) and the arrival itself.
Destinations.GymOffsets = { bench = Vector3.new(-28, 0, 24), treadmill = Vector3.new(28, 0, 24) }
local CLEAR = { Destinations.GymOffsets.bench, Destinations.GymOffsets.treadmill, Vector3.new(0, 0, 18) }
-- Deterministic scatter so every server builds the same destination; skips the clear spots.
local function scatter(seed, count, radius, fn)
    local random = Random.new(seed)
    for index = 1, count do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(0.25, 0.9) * radius
        local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local blocked = false
        for _, spot in CLEAR do
            if (offset - spot).Magnitude < 14 then blocked = true end
        end
        if not blocked then fn(index, offset, random) end
    end
end

local builders = {}
-- 1: an orbital deck with glass rails, a hub, solar wings, and Earth below.
builders[1] = function(folder, c)
    local floor = make(folder, "Deck", { Size = Vector3.new(110, 2, 70), CFrame = CFrame.new(c - Vector3.new(0, 1, 0)), Color = Color3.fromRGB(190, 196, 206), Material = Enum.Material.DiamondPlate })
    for x = -50, 50, 10 do decor(folder, "DeckStripe", { Size = Vector3.new(0.6, 0.1, 70), CFrame = CFrame.new(c + Vector3.new(x, 0.05, 0)), Color = Color3.fromRGB(120, 128, 140) }) end
    for _, side in { -1, 1 } do
        make(folder, "GlassRail", { Size = Vector3.new(110, 8, 1), CFrame = CFrame.new(c + Vector3.new(0, 4, side * 35)), Color = Color3.fromRGB(170, 220, 255), Transparency = 0.6, Material = Enum.Material.Glass })
        make(folder, "GlassRail", { Size = Vector3.new(1, 8, 70), CFrame = CFrame.new(c + Vector3.new(side * 55, 4, 0)), Color = Color3.fromRGB(170, 220, 255), Transparency = 0.6, Material = Enum.Material.Glass })
        decor(folder, "SolarWing", { Size = Vector3.new(80, 0.4, 24), CFrame = CFrame.new(c + Vector3.new(side * 100, 6, 0)), Color = Color3.fromRGB(40, 70, 160), Material = Enum.Material.Glass })
        decor(folder, "WingTruss", { Size = Vector3.new(50, 1.5, 1.5), CFrame = CFrame.new(c + Vector3.new(side * 70, 6, 0)), Color = Color3.fromRGB(150, 150, 160) })
    end
    make(folder, "Hub", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 22, 22), CFrame = CFrame.new(c + Vector3.new(0, 8, -22)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 238, 245) })
    decor(folder, "HubWindows", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 22.4, 22.4), CFrame = CFrame.new(c + Vector3.new(0, 11, -22)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon })
    for _, x in { -36, 36 } do
        make(folder, "Module", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 10, 10), CFrame = CFrame.new(c + Vector3.new(x, 5, -24)), Color = Color3.fromRGB(225, 228, 236) })
    end
    decor(folder, "Earth", { Shape = Enum.PartType.Ball, Size = Vector3.one * 700, CFrame = CFrame.new(c + Vector3.new(0, -520, -700)), Color = Color3.fromRGB(50, 120, 220) })
    decor(folder, "EarthLand", { Shape = Enum.PartType.Ball, Size = Vector3.one * 702, CFrame = CFrame.new(c + Vector3.new(0, -520, -700)), Color = Color3.fromRGB(70, 160, 80), Transparency = 0.55 })
    fence(folder, c, 72, 40)
    return floor, Vector3.new(0, 0, 12)
end
-- 2: grey regolith with craters, a flag and a lander; Earth hangs in the sky.
builders[2] = function(folder, c)
    local ground = disc(folder, "Regolith", c - Vector3.new(0, 2, 0), 75, 4, Color3.fromRGB(170, 170, 175), Enum.Material.Slate)
    scatter(2, 7, 70, function(index, offset, random)
        local r = random:NextNumber(5, 11)
        disc(folder, "CraterRim", c + offset + Vector3.new(0, 0.3, 0), r + 2, 0.8, Color3.fromRGB(150, 150, 156))
        disc(folder, "Crater", c + offset + Vector3.new(0, 0.45, 0), r, 0.8, Color3.fromRGB(110, 110, 118))
    end)
    make(folder, "FlagPole", { Size = Vector3.new(0.4, 12, 0.4), CFrame = CFrame.new(c + Vector3.new(14, 6, -10)), Color = Color3.fromRGB(230, 230, 230) })
    decor(folder, "Flag", { Size = Vector3.new(6, 4, 0.2), CFrame = CFrame.new(c + Vector3.new(17, 10, -10)), Color = Color3.fromRGB(220, 50, 50) })
    make(folder, "Lander", { Size = Vector3.new(8, 6, 8), CFrame = CFrame.new(c + Vector3.new(-18, 6, -16)), Color = Color3.fromRGB(230, 180, 50), Material = Enum.Material.Foil })
    for _, corner in { Vector3.new(5, 0, 5), Vector3.new(-5, 0, 5), Vector3.new(5, 0, -5), Vector3.new(-5, 0, -5) } do
        make(folder, "LanderLeg", { Size = Vector3.new(0.6, 5, 0.6), CFrame = CFrame.new(c + Vector3.new(-18, 2.5, -16) + corner), Color = Color3.fromRGB(160, 160, 165) })
    end
    decor(folder, "Earth", { Shape = Enum.PartType.Ball, Size = Vector3.one * 160, CFrame = CFrame.new(c + Vector3.new(250, 260, -520)), Color = Color3.fromRGB(50, 120, 220) })
    fence(folder, c, 75, 60)
    return ground, Vector3.new(0, 0, 20)
end
-- 3: red dust, rocks and dunes, a glass habitat dome and a rover.
builders[3] = function(folder, c)
    local ground = disc(folder, "Dust", c - Vector3.new(0, 2, 0), 75, 4, Color3.fromRGB(196, 92, 52), Enum.Material.Sand)
    scatter(3, 14, 70, function(index, offset, random)
        local size = random:NextNumber(2, 6)
        make(folder, "Rock", { Size = Vector3.new(size * 1.3, size, size), CFrame = CFrame.new(c + offset + Vector3.new(0, size / 2 - 0.5, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), random:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(130, 60, 40), Material = Enum.Material.Rock })
    end)
    for _, x in { -40, 40 } do
        make(folder, "Dune", { ClassName = "WedgePart", Size = Vector3.new(30, 6, 16), CFrame = CFrame.new(c + Vector3.new(x, 3, 40)), Color = Color3.fromRGB(205, 110, 65), Material = Enum.Material.Sand })
    end
    decor(folder, "HabitatDome", { Shape = Enum.PartType.Ball, Size = Vector3.one * 26, CFrame = CFrame.new(c + Vector3.new(-26, 0, -30)), Color = Color3.fromRGB(200, 230, 255), Transparency = 0.5, Material = Enum.Material.Glass })
    make(folder, "HabitatBase", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 26, 26), CFrame = CFrame.new(c + Vector3.new(-26, 0.5, -30)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(220, 220, 225) })
    make(folder, "RoverBody", { Size = Vector3.new(8, 2.5, 5), CFrame = CFrame.new(c + Vector3.new(24, 2.6, -18)), Color = Color3.fromRGB(235, 235, 240) })
    for _, w in { Vector3.new(3, 0, 3), Vector3.new(-3, 0, 3), Vector3.new(3, 0, -3), Vector3.new(-3, 0, -3) } do
        make(folder, "RoverWheel", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 2.4, 2.4), CFrame = CFrame.new(c + Vector3.new(24, 1.2, -18) + w) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(50, 50, 55) })
    end
    fence(folder, c, 75, 45)
    return ground, Vector3.new(0, 0, 20)
end
-- 4: an icy chunk of Saturn's rings under the giant planet.
builders[4] = function(folder, c)
    local ground = disc(folder, "RingRock", c - Vector3.new(0, 2, 0), 65, 4, Color3.fromRGB(205, 195, 170), Enum.Material.Rock)
    scatter(4, 10, 60, function(index, offset, random)
        local size = random:NextNumber(3, 7)
        make(folder, "IceChunk", { Size = Vector3.one * size, CFrame = CFrame.new(c + offset + Vector3.new(0, size / 2 - 0.6, 0)) * CFrame.Angles(random:NextNumber(0, 1), random:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(225, 235, 245), Material = Enum.Material.Ice })
    end)
    local saturn = c + Vector3.new(0, 220, -900)
    decor(folder, "Saturn", { Shape = Enum.PartType.Ball, Size = Vector3.one * 640, CFrame = CFrame.new(saturn), Color = Color3.fromRGB(225, 195, 140) })
    decor(folder, "SaturnBand", { Shape = Enum.PartType.Ball, Size = Vector3.new(646, 120, 646), CFrame = CFrame.new(saturn + Vector3.new(0, 80, 0)), Color = Color3.fromRGB(200, 160, 105), Transparency = 0.3 })
    decor(folder, "SaturnRings", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1500, 1500), CFrame = CFrame.new(saturn) * CFrame.Angles(math.rad(14), 0, math.rad(90)), Color = Color3.fromRGB(215, 200, 165), Transparency = 0.45 })
    scatter(40, 12, 260, function(index, offset, random)
        local size = random:NextNumber(6, 18)
        decor(folder, "FloatingRock", { Size = Vector3.one * size, CFrame = CFrame.new(c + offset + Vector3.new(0, random:NextNumber(30, 90), 0)) * CFrame.Angles(random:NextNumber(0, 3), random:NextNumber(0, 3), 0), Color = Color3.fromRGB(190, 180, 160), Material = Enum.Material.Rock })
    end)
    fence(folder, c, 65, 50)
    return ground, Vector3.new(0, 0, 18)
end
-- 5: pale ice plains with spikes, the bright heart plain, and Charon overhead.
builders[5] = function(folder, c)
    local ground = disc(folder, "IcePlain", c - Vector3.new(0, 2, 0), 75, 4, Color3.fromRGB(205, 215, 230), Enum.Material.Glacier)
    disc(folder, "HeartPlainLeft", c + Vector3.new(-9, 0.1, -28), 14, 0.4, Color3.fromRGB(245, 235, 225), Enum.Material.Snow)
    disc(folder, "HeartPlainRight", c + Vector3.new(9, 0.1, -28), 14, 0.4, Color3.fromRGB(245, 235, 225), Enum.Material.Snow)
    scatter(5, 12, 70, function(index, offset, random)
        local height = random:NextNumber(6, 16)
        make(folder, "IceSpike", { ClassName = "WedgePart", Size = Vector3.new(3, height, 4), CFrame = CFrame.new(c + offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(170, 205, 240), Material = Enum.Material.Ice })
    end)
    decor(folder, "Charon", { Shape = Enum.PartType.Ball, Size = Vector3.one * 220, CFrame = CFrame.new(c + Vector3.new(-300, 280, -600)), Color = Color3.fromRGB(150, 145, 150) })
    fence(folder, c, 75, 60)
    return ground, Vector3.new(0, 0, 20)
end

-- Returns { [tier] = { id, name, gravity, reward, arrival = Vector3, center, gym = { bench, treadmill } } } and the cabin
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
        -- Players arrive facing -Z (the main map's view toward the rocket): sign ahead, facing them.
        sign(folder, center + Vector3.new(0, 22, arrivalOffset.Z - 40), Vector3.new(0, 0, 1), "WELCOME TO " .. spec.name .. "!", spec.color)
        built[tier] = { id = spec.id, name = spec.name, gravity = spec.gravity, reward = spec.reward, folder = folder,
            arrival = arrivalAt + Vector3.new(0, 4, 0), center = center,
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
        make(cabinFolder, "CabinWall", { Size = Vector3.new(size.X, size.Y, 1), CFrame = CFrame.new(cc + Vector3.new(0, size.Y / 2, side * (size.Z / 2 + 0.5))), Color = hull })
        make(cabinFolder, "CabinWall", { Size = Vector3.new(1, size.Y, size.Z), CFrame = CFrame.new(cc + Vector3.new(side * (size.X / 2 + 0.5), size.Y / 2, 0)), Color = hull })
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
