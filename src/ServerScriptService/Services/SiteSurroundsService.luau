--[[
    What lies around the Earth site, so it reads as a place on a planet rather than a slab
    in the sky. Two pieces:
    - A perimeter: construction hoarding round the site and the Gym District, with an
      invisible barrier on the same line that nobody can jump or climb over. `fit(edge)`
      rebuilds it whenever map expansion widens the site (ground half-width `edge`).
    - The land beyond: a grass plain out past the horizon and trees outside the fence.
      The plain has a hole where the site is (refitted with the perimeter), never lying
      under the site's ground: seen from a launching rocket, two surfaces that close
      flicker through each other. Two staggered rows of low-poly mountains (Mountains)
      close the horizon all round, well inside the draw distance (Roblox shortens it when
      the frame rate dips, as in a launch); Earth's sky carries matching land behind them.
]]
local Planets = require(script.Parent.Planets)
local Layout = require(script.Parent.SiteLayout)
local Signs = require(script.Parent.SignService)
local Mountains = require(script.Parent.Mountains)
local Spaceport = require(script.Parent.SpaceportService)
local Surrounds = {}

Surrounds.WallHeight = 10
Surrounds.BarrierHeight = 120
-- The plain's top sits this far under the site's ground (y = 0).
Surrounds.PlainDepth = 0.35
Surrounds.PlainReach = 5120
Surrounds.Tile = 2048
-- Two staggered rows of mountains (Mountains.ring) closing the horizon all round.
local ROCK, ROCK_ALT = Color3.fromRGB(112, 104, 128), Color3.fromRGB(140, 120, 110)
Surrounds.Mountains = {
    { radius = 2350, spread = 150, count = 34, size = { 520, 820 }, rock = ROCK, rockAlt = ROCK_ALT, snow = 700, seed = 1969 },
    { radius = 2850, spread = 250, count = 32, size = { 650, 950 }, rock = ROCK, rockAlt = ROCK_ALT, snow = 750, seed = 1971 },
}

local HOARDING = Color3.fromRGB(52, 58, 74)
local HAZARD = Color3.fromRGB(240, 180, 30)
local STEEL = Color3.fromRGB(150, 156, 166)

local function make(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
    part.Parent = parent
    return part
end

-- The fence lines, as { from, to } on the ground: the site rectangle (open where the
-- Gym District joins it) and the District's three sides.
function Surrounds.lines(edge, district)
    local z0, z1 = Layout.Ground.z0, Layout.Ground.z1
    local dx, dz = district.x, district.z1
    return {
        { Vector2.new(-edge, z0), Vector2.new(edge, z0) },
        { Vector2.new(-edge, z0), Vector2.new(-edge, z1) },
        { Vector2.new(edge, z0), Vector2.new(edge, z1) },
        { Vector2.new(-edge, z1), Vector2.new(-dx, z1) },
        { Vector2.new(dx, z1), Vector2.new(edge, z1) },
        { Vector2.new(-dx, z1), Vector2.new(-dx, dz) },
        { Vector2.new(dx, z1), Vector2.new(dx, dz) },
        { Vector2.new(-dx, dz), Vector2.new(dx, dz) },
    }
end

-- One run of hoarding from a to b (ground points), its inner face toward `inside`:
-- panels on a kerb, a hazard rail along the top, steel posts every 40 studs, and the
-- invisible barrier.
local function run(parent, a, b, inside)
    local length = (b - a).Magnitude
    local mid = (a + b) / 2
    local frame = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Y), Vector3.new(b.X, 0, b.Y))
    local h = Surrounds.WallHeight
    make(parent, "HoardingKerb", Vector3.new(1.8, 1, length + 1.8), frame * CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
    make(parent, "Hoarding", Vector3.new(1, h, length), frame * CFrame.new(0, h / 2, 0), HOARDING, Enum.Material.Metal)
    make(parent, "HoardingRail", Vector3.new(1.4, 0.8, length + 1.4), frame * CFrame.new(0, h + 0.4, 0), HAZARD, Enum.Material.SmoothPlastic)
    for offset = -length / 2, length / 2, 40 do
        make(parent, "HoardingPost", Vector3.new(1.8, h + 1.6, 1.8), frame * CFrame.new(0, (h + 1.6) / 2, offset), STEEL, Enum.Material.Metal)
    end
    local barrier = make(parent, "Barrier", Vector3.new(2, Surrounds.BarrierHeight, length + 2), frame * CFrame.new(0, Surrounds.BarrierHeight / 2, 0), HOARDING)
    barrier.Transparency, barrier.CanCollide = 1, true
    -- Long runs carry a notice on their inner face every 240 studs.
    if length >= 240 then
        local facing = (inside - mid)
        local side = (frame:VectorToObjectSpace(Vector3.new(facing.X, 0, facing.Y)).X > 0) and 1 or -1
        for offset = -length / 2 + 120, length / 2 - 119, 240 do
            local at = frame * CFrame.new(side * 1.1, h * 0.55, offset)
            Signs.board(parent, "HoardingNotice", CFrame.lookAt(at.Position, at.Position + at.RightVector * side), Vector2.new(24, 4.4),
                { title = "SPACEPORT EARTH", subtitle = "HARD HATS ON  •  NO ENTRY BEYOND THIS POINT", icon = "⛑️", accent = HAZARD })
        end
    end
end

-- The plain as x/z rectangles no bigger than a part can be: the square round the site
-- with the site (ground half-width `edge`) and the Gym District cut out.
function Surrounds.plainPieces(edge, district)
    local carve = require(script.Parent.MapExpansionService).carve
    local centerZ = (Layout.Ground.z0 + Layout.Ground.z1) / 2
    local reach, tile = Surrounds.PlainReach, Surrounds.Tile
    local holes = {
        { x0 = -edge, x1 = edge, z0 = Layout.Ground.z0, z1 = Layout.Ground.z1 },
        { x0 = -district.x, x1 = district.x, z0 = Layout.Ground.z1, z1 = district.z1 },
    }
    local pieces = {}
    for _, r in carve({ x0 = -reach, x1 = reach, z0 = centerZ - reach, z1 = centerZ + reach }, holes) do
        for x = r.x0, r.x1 - 0.01, tile do
            for z = r.z0, r.z1 - 0.01, tile do
                table.insert(pieces, { x0 = x, x1 = math.min(x + tile, r.x1), z0 = z, z1 = math.min(z + tile, r.z1) })
            end
        end
    end
    return pieces
end

local function plain(parent, edge, district)
    for _, r in Surrounds.plainPieces(edge, district) do
        local piece = make(parent, "Plain", Vector3.new(r.x1 - r.x0, 4, r.z1 - r.z0),
            CFrame.new((r.x0 + r.x1) / 2, -Surrounds.PlainDepth - 2, (r.z0 + r.z1) / 2), Color3.fromRGB(104, 124, 82), Enum.Material.Grass)
        Planets.overlay(piece, Enum.NormalId.Top, "Grass", 34, 0.1)
        Planets.overlay(piece, Enum.NormalId.Top, "MoonMaria", 640, 0.45, Color3.fromRGB(56, 74, 38))
        piece.CanCollide = true
    end
end

-- A low-poly tree: a trunk and two faceted canopy blocks.
local function tree(parent, at, random)
    local height = random:NextNumber(14, 26)
    make(parent, "Trunk", Vector3.new(1.6, height * 0.5, 1.6), CFrame.new(at + Vector3.new(0, height * 0.25, 0)), Color3.fromRGB(96, 70, 52), Enum.Material.Wood)
    local green = Color3.fromRGB(70, 112, 64):Lerp(Color3.fromRGB(110, 140, 70), random:NextNumber())
    for index = 1, 2 do
        local size = height * (index == 1 and 0.55 or 0.38)
        make(parent, "Canopy", Vector3.one * size,
            CFrame.new(at + Vector3.new(0, height * (0.55 + index * 0.17), 0)) * CFrame.Angles(random:NextNumber(0, 1), random:NextNumber(0, 6.28), random:NextNumber(0, 1)),
            green, Enum.Material.Grass)
    end
end

-- A broadleaf tree: a trunk and a round canopy of three overlapping soft blobs.
local function roundTree(parent, at, random)
    local height = random:NextNumber(12, 22)
    make(parent, "Trunk", Vector3.new(1.4, height * 0.55, 1.4), CFrame.new(at + Vector3.new(0, height * 0.27, 0)), Color3.fromRGB(104, 76, 54), Enum.Material.Wood)
    local green = Color3.fromRGB(78, 128, 60):Lerp(Color3.fromRGB(128, 156, 70), random:NextNumber())
    for index = 1, 3 do
        local size = height * random:NextNumber(0.42, 0.6)
        local offset = index == 1 and Vector3.zero or Vector3.new(random:NextNumber(-0.25, 0.25), random:NextNumber(-0.1, 0.1), random:NextNumber(-0.25, 0.25)) * height
        Planets.blob(parent, "Canopy", CFrame.new(at + Vector3.new(0, height * 0.72, 0) + offset), Vector3.new(size, size * 0.85, size),
            green:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.12)), Enum.Material.Grass)
    end
end
-- Low clutter on the plain: a bush, a grey rock, or a patch of flowers.
local function clutter(parent, at, random)
    local kind = random:NextNumber()
    if kind < 0.45 then
        local size = random:NextNumber(3, 7)
        Planets.blob(parent, "Bush", CFrame.new(at + Vector3.new(0, size * 0.25, 0)), Vector3.new(size * 1.3, size * 0.75, size),
            Color3.fromRGB(72, 116, 56):Lerp(Color3.fromRGB(120, 140, 64), random:NextNumber()), Enum.Material.Grass)
    elseif kind < 0.7 then
        local size = random:NextNumber(3, 9)
        Planets.blob(parent, "Rock", CFrame.new(at + Vector3.new(0, size * 0.15, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0),
            Vector3.new(size * 1.4, size * 0.7, size), Color3.fromRGB(130, 128, 122):Lerp(Color3.fromRGB(100, 96, 90), random:NextNumber()), Enum.Material.Slate)
    else
        local colors = { Color3.fromRGB(250, 220, 60), Color3.fromRGB(245, 245, 240), Color3.fromRGB(230, 110, 190), Color3.fromRGB(160, 140, 250) }
        local color = colors[random:NextInteger(1, #colors)]
        for _ = 1, random:NextInteger(5, 9) do
            local flower = make(parent, "Flower", Vector3.new(0.9, 0.5, 0.9), CFrame.new(at + Vector3.new(random:NextNumber(-4, 4), 0.25, random:NextNumber(-4, 4))), color, Enum.Material.SmoothPlastic)
            flower.Shape = Enum.PartType.Ball
        end
    end
end

function Surrounds.build(world, district)
    local model = Instance.new("Model")
    model.Name = "SiteSurrounds"
    model.Parent = world
    local land = Instance.new("Folder")
    land.Name = "Land"
    land.Parent = model
    local centerZ = (Layout.Ground.z0 + Layout.Ground.z1) / 2
    local center = Vector3.new(0, 0, centerZ)
    local random = Random.new(1969)
    for _, row in Surrounds.Mountains do
        Mountains.ring(land, center, row, make)
    end
    -- Trees in loose clumps outside the widest the site ever gets (4 expansions).
    local widest = Layout.Ground.x + 4 * 80 + 60
    -- ...and off the spaceport's slabs (with room for a clump's spread).
    local function outsideSite(at)
        for _, r in Spaceport.Clear do
            if at.X > r[1] - 40 and at.X < r[2] + 40 and at.Z > r[3] - 40 and at.Z < r[4] + 40 then return false end
        end
        return math.abs(at.X) > widest or at.Z < Layout.Ground.z0 - 60 or at.Z > district.z1 + 60
    end
    local placed = 0
    while placed < 70 do
        local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(700, 1350)
        local at = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        if outsideSite(at) then
            for _ = 1, random:NextInteger(2, 4) do
                tree(land, at + Vector3.new(random:NextNumber(-18, 18), -Surrounds.PlainDepth, random:NextNumber(-18, 18)), random)
                placed += 1
            end
        end
    end
    -- Broadleaf clumps, and bushes, rocks and flowers, nearer in (still outside the
    -- widest site), on their own seed so the faceted trees stay where they were.
    local extra = Random.new(2024)
    local broadleaf = 0
    while broadleaf < 60 do
        local angle, distance = extra:NextNumber(0, math.pi * 2), extra:NextNumber(690, 1250)
        local at = center + Vector3.new(math.cos(angle) * distance, -Surrounds.PlainDepth, math.sin(angle) * distance)
        if outsideSite(at) then
            for _ = 1, extra:NextInteger(2, 5) do
                roundTree(land, at + Vector3.new(extra:NextNumber(-22, 22), 0, extra:NextNumber(-22, 22)), extra)
                broadleaf += 1
            end
        end
    end
    local scattered = 0
    while scattered < 140 do
        local angle, distance = extra:NextNumber(0, math.pi * 2), extra:NextNumber(680, 1100)
        local at = center + Vector3.new(math.cos(angle) * distance, -Surrounds.PlainDepth, math.sin(angle) * distance)
        if outsideSite(at) then
            clutter(land, at, extra)
            scattered += 1
        end
    end

    local perimeter, plainFolder
    local service = {}
    function service.fit(edge)
        if perimeter then perimeter:Destroy() end
        if plainFolder then plainFolder:Destroy() end
        plainFolder = Instance.new("Folder")
        plainFolder.Name = "Plain"
        plainFolder.Parent = land
        plain(plainFolder, edge, district)
        perimeter = Instance.new("Folder")
        perimeter.Name = "Perimeter"
        perimeter.Parent = model
        local inside = Vector2.new(0, centerZ)
        for _, line in Surrounds.lines(edge, district) do
            -- The District's runs face into the District.
            local into = (line[1].Y > Layout.Ground.z1 or line[2].Y > Layout.Ground.z1) and Vector2.new(0, (Layout.Ground.z1 + district.z1) / 2) or inside
            run(perimeter, line[1], line[2], into)
        end
        service.edge = edge
    end
    service.model = model
    return service
end

return Surrounds
