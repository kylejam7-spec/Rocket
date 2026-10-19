--[[
    Small things that make the Earth site look lived in, all flat or soft and none of it
    collidable (so nothing trips a player or blocks a path):
    - on the dirt: puddles, gravel patches, tyre ruts curving across the open ground,
      and weeds along the hoarding and round the edges of things;
    - on the roads: kerbs along the lane, manhole covers, crosswalks where the spurs and
      the pad road meet the lane, and darker repaired patches;
    - on the apron and pad: oil stains and yellow hazard lines round the pad.
    Scatter keeps off the roads, spawn, the stations, the forecourt huts, the launch
    complex and the Gym District, and is seeded, so every server builds the same.
]]
local Layout = require(script.Parent.SiteLayout)
local Planets = require(script.Parent.Planets)
local Details = {}

local function make(parent, name, size, cframe, color, material, shape)
    local part = Instance.new("Part")
    if shape then part.Shape = Enum.PartType[shape] end
    part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end
local FLAT = CFrame.Angles(0, 0, math.rad(90))
local function disc(parent, name, at, radius, color, material)
    return make(parent, name, Vector3.new(0.06, radius * 2, radius * 2), CFrame.new(at) * FLAT, color, material, "Cylinder")
end

-- Rectangles (x0, x1, z0, z1) the scatter keeps out of.
local function keepOut()
    local lane, front = Layout.Lane, Layout.Apron.z1 + 14
    local zones = {
        { -lane.width / 2 - 3, lane.width / 2 + 3, lane.z0 - 4, lane.z1 },
        { -Layout.Apron.x - 4, Layout.Apron.x + 4, Layout.Apron.z0, front + 12 },
        { Layout.Spawn.X - 16, Layout.Spawn.X + 16, Layout.Spawn.Z - 16, Layout.Spawn.Z + 16 },
        { -60, 60, Layout.Ground.z1 - 6, math.huge },
    }
    for _, hut in { Layout.Upgrades, Layout.UfoShop } do
        table.insert(zones, { hut.X - 17, hut.X + 17, hut.Z - 17, hut.Z + 17 })
    end
    for _, r in Layout.Reserved do
        table.insert(zones, { r.x0 - 4, r.x1 + 4, r.z0 - 4, r.z1 + 4 })
    end
    for _, station in { Layout.Metal, Layout.Fuel } do
        local gate = station.X - math.sign(station.X) * Layout.StationFootprint.X / 2
        table.insert(zones, { math.min(0, gate) - 2, math.max(0, gate) + 2, station.Z - 11, station.Z + 11 })
    end
    return zones
end
local function free(zones, x, z, radius)
    if math.abs(x) + radius > Layout.Ground.x - 4 or z - radius < Layout.Apron.z1 or z + radius > Layout.Ground.z1 - 4 then return false end
    for _, zone in zones do
        if x + radius > zone[1] and x - radius < zone[2] and z + radius > zone[3] and z - radius < zone[4] then return false end
    end
    return true
end

local function dirtDetails(parent, random, zones)
    local function spot(radius)
        for _ = 1, 40 do
            local x, z = random:NextNumber(-Layout.Ground.x, Layout.Ground.x), random:NextNumber(Layout.Apron.z1, Layout.Ground.z1)
            if free(zones, x, z, radius) then return x, z end
        end
        return nil
    end
    -- Puddles: two or three overlapping discs, glossy.
    for _ = 1, 26 do
        local x, z = spot(6)
        if x then
            for index = 1, random:NextInteger(2, 3) do
                local radius = random:NextNumber(1.5, 4)
                local puddle = disc(parent, "Puddle", Vector3.new(x + random:NextNumber(-2.5, 2.5), 0.03 + index * 0.002, z + random:NextNumber(-2.5, 2.5)), radius,
                    Color3.fromRGB(78, 72, 64), Enum.Material.SmoothPlastic)
                -- Muddy water: dull brown, a little see-through, with a faint sheen
                -- (Glass picked up the purple sky and read as violet).
                puddle.Reflectance, puddle.Transparency = 0.05, 0.25
            end
        end
    end
    -- Gravel patches: low grey mounds.
    for _ = 1, 22 do
        local radius = random:NextNumber(4, 9)
        local x, z = spot(radius)
        if x then
            local mound = Planets.mound(parent, "Gravel", Vector3.new(x, 0, z), radius, random:NextNumber(0.2, 0.45),
                Color3.fromRGB(150, 146, 138):Lerp(Color3.fromRGB(120, 108, 92), random:NextNumber()), Enum.Material.Pebble)
            mound.CastShadow = false
        end
    end
    -- Tyre ruts: two darker tracks curving across open ground in short straight steps.
    for _ = 1, 9 do
        local x, z = spot(4)
        if x then
            local heading = random:NextNumber(0, math.pi * 2)
            local bend = random:NextNumber(-0.06, 0.06)
            for _ = 1, random:NextInteger(6, 14) do
                local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
                local nextX, nextZ = x + dir.X * 6, z + dir.Z * 6
                if not free(zones, nextX, nextZ, 3) then break end
                local across = Vector3.new(-dir.Z, 0, dir.X)
                for _, side in { -1, 1 } do
                    local mid = Vector3.new((x + nextX) / 2, 0.025, (z + nextZ) / 2) + across * side * 2.2
                    make(parent, "Rut", Vector3.new(1, 0.05, 6.4), CFrame.lookAt(mid, mid + dir), Color3.fromRGB(96, 74, 54), Enum.Material.Mud)
                end
                x, z, heading = nextX, nextZ, heading + bend
            end
        end
    end
    -- Weeds along the hoarding (inside the ground's edge) and scattered tufts.
    local function tuft(at)
        local size = random:NextNumber(0.9, 1.8)
        local blob = Planets.blob(parent, "Weed", CFrame.new(at + Vector3.new(0, size * 0.25, 0)), Vector3.new(size * 1.3, size * 0.8, size * 1.3),
            Color3.fromRGB(86, 120, 58):Lerp(Color3.fromRGB(130, 140, 70), random:NextNumber()), Enum.Material.Grass)
        blob.CanCollide, blob.CanQuery, blob.CanTouch, blob.CastShadow = false, false, false, false
    end
    for _, side in { -1, 1 } do
        for z = Layout.Apron.z1 + 4, Layout.Ground.z1 - 8, 7 do
            if random:NextNumber() < 0.6 then tuft(Vector3.new(side * (Layout.Ground.x - random:NextNumber(1.5, 4)), 0, z + random:NextNumber(-3, 3))) end
        end
    end
    for _ = 1, 60 do
        local x, z = spot(1.5)
        if x then tuft(Vector3.new(x, 0, z)) end
    end
end

local function roadDetails(parent, random)
    local lane = Layout.Lane
    local asphalt = Color3.fromRGB(40, 42, 46)
    -- Kerbs: pale concrete flush with the road top along both lane edges.
    for _, side in { -1, 1 } do
        local kerb = make(parent, "Kerb", Vector3.new(0.8, 0.21, lane.z1 - lane.z0), CFrame.new(side * (lane.width / 2 + 0.4), 0.105, (lane.z0 + lane.z1) / 2),
            Color3.fromRGB(175, 172, 165), Enum.Material.Concrete)
        Planets.overlay(kerb, Enum.NormalId.Top, "Concrete", 6, 0.4)
    end
    -- Manholes down the lane, off the centre line.
    for z = lane.z0 + 30, lane.z1 - 20, 56 do
        local at = Vector3.new(random:NextNumber() < 0.5 and -5 or 5, 0.215, z)
        disc(parent, "Manhole", at, 1.3, Color3.fromRGB(60, 60, 64), Enum.Material.DiamondPlate)
        disc(parent, "ManholeRim", at - Vector3.new(0, 0.005, 0), 1.5, Color3.fromRGB(90, 90, 94), Enum.Material.Metal)
    end
    -- Crosswalks where each station spur and the pad road meet the lane.
    local function crosswalk(center, along)
        local across = Vector3.new(-along.Z, 0, along.X)
        for index = -4, 4 do
            local at = center + across * index * 1.8 + Vector3.new(0, 0.215, 0)
            make(parent, "Crosswalk", Vector3.new(0.9, 0.04, 5), CFrame.lookAt(at, at + along), Color3.fromRGB(240, 240, 235))
        end
    end
    for _, station in { Layout.Metal, Layout.Fuel } do
        crosswalk(Vector3.new(math.sign(station.X) * (lane.width / 2 + 4), 0, station.Z), Vector3.new(1, 0, 0))
    end
    crosswalk(Vector3.new(0, 0, Layout.Apron.z1 + 24), Vector3.new(0, 0, 1))
    -- Repaired patches: darker, slightly shinier asphalt.
    for _ = 1, 7 do
        local at = Vector3.new(random:NextNumber(-6, 6), 0.205, random:NextNumber(lane.z0 + 10, lane.z1 - 10))
        make(parent, "RoadPatch", Vector3.new(random:NextNumber(2.5, 5), 0.02, random:NextNumber(3, 7)), CFrame.new(at) * CFrame.Angles(0, random:NextNumber(-0.2, 0.2), 0),
            asphalt, Enum.Material.Asphalt)
    end
end

local function padDetails(parent, random)
    local pad = Layout.Pad
    local top = pad.center.Y + pad.size.Y / 2 + 0.01
    -- Hazard lines inset round the pad's edge: yellow dashes.
    local hx, hz = pad.size.X / 2 - 4, pad.size.Z / 2 - 4
    for _, edge in { { Vector3.new(0, 0, hz), hx, true }, { Vector3.new(0, 0, -hz), hx, true }, { Vector3.new(hx, 0, 0), hz, false }, { Vector3.new(-hx, 0, 0), hz, false } } do
        local length = edge[2] * 2
        for offset = -length / 2 + 4, length / 2 - 4, 8 do
            local at = pad.center + edge[1] + (edge[3] and Vector3.new(offset, 0, 0) or Vector3.new(0, 0, offset))
            make(parent, "PadHazard", edge[3] and Vector3.new(5, 0.03, 1) or Vector3.new(1, 0.03, 5), CFrame.new(at.X, top, at.Z), Color3.fromRGB(245, 190, 40))
        end
    end
    -- Oil stains and scorch marks on the pad and apron.
    for _ = 1, 30 do
        local at = Vector3.new(random:NextNumber(-Layout.Apron.x + 10, Layout.Apron.x - 10), 0, random:NextNumber(Layout.Apron.z0 + 20, Layout.Apron.z1 - 10))
        local onPad = math.abs(at.X - pad.center.X) < pad.size.X / 2 and math.abs(at.Z - pad.center.Z) < pad.size.Z / 2
        local y = onPad and top + 0.01 or 0.1
        local stain = disc(parent, "Stain", Vector3.new(at.X, y, at.Z), random:NextNumber(2, 7), Color3.fromRGB(40, 40, 44), Enum.Material.SmoothPlastic)
        stain.Transparency = random:NextNumber(0.55, 0.8)
    end
end

function Details.build(world)
    local folder = Instance.new("Folder")
    folder.Name = "SiteDetails"
    folder.Parent = world
    local random = Random.new(77)
    local zones = keepOut()
    dirtDetails(folder, random, zones)
    roadDetails(folder, random)
    padDetails(folder, random)
    return folder
end

return Details
