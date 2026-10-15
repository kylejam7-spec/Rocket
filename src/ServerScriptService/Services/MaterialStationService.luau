--[[
    The two material pickup stations, sized for a full 50-player server.

    Both sit side by side right behind spawn (+Z), the first thing a new player sees
    on turning around, with a road between them; the Gym District lies past them (WorldService):
        Metal  SCRAP PIT      x = -52, a dug pit with a heap of scrap in it
        Fuel   OIL REFINERY   x = +52, derrick, tanks and a fuelling canopy

    Stations.build(parent) returns { Metal = station, Fuel = station }, where
    station.zone is the invisible pickup volume (players within InteractionDistance
    of it may pick up) and station.points are attachments spread over it, one
    pickup prompt each, so a crowd can work the station from every side.
    Stations.Reserved lists the footprints map expansion must leave alone.
]]
local Stations = {}

local METAL_CENTER = Vector3.new(-52, 0, 100)
local FUEL_CENTER = Vector3.new(52, 0, 100)
-- Footprint of each station on the ground plane (x by z).
local FOOTPRINT = Vector2.new(80, 100)
-- Pit hole and depth; jump height (7.2) is more than the depth, so nobody gets stuck.
local PIT_HALF, PIT_DEPTH = Vector2.new(26, 33), 5
-- Prompt points are this far apart at most, so every spot in or at the edge of a
-- zone is within a prompt's reach (InteractionDistance = 10).
local POINT_SPACING = 12

Stations.Reserved = {}
for _, center in { METAL_CENTER, FUEL_CENTER } do
    table.insert(Stations.Reserved, {
        x0 = center.X - FOOTPRINT.X / 2, x1 = center.X + FOOTPRINT.X / 2,
        z0 = center.Z - FOOTPRINT.Y / 2, z1 = center.Z + FOOTPRINT.Y / 2,
    })
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local SHAPES = { Block = "Part", Cylinder = "Part", Ball = "Part", Wedge = "WedgePart" }

-- Solid by default; `decor` pieces are visual only (no collision or queries).
local function make(parent, name, shape, size, cframe, color, material, decor)
    local part = Instance.new(SHAPES[shape])
    if part:IsA("Part") then part.Shape = Enum.PartType[shape] end
    part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    if decor then part.CanCollide, part.CanQuery, part.CanTouch = false, false, false end
    part.Parent = parent
    return part
end

-- A square beam from a to b.
local function beam(parent, name, a, b, thickness, color, material, decor)
    return make(parent, name, "Block", Vector3.new(thickness, thickness, (b - a).Magnitude),
        CFrame.lookAt((a + b) / 2, b), color, material, decor)
end

-- A round pipe from a to b (a Cylinder's axis is its X).
local function pipe(parent, name, a, b, diameter, color, material, decor)
    return make(parent, name, "Cylinder", Vector3.new((b - a).Magnitude, diameter, diameter),
        CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material, decor)
end

-- Upright cylinder standing on `base`.
local function column(parent, name, base, height, diameter, color, material, decor)
    return make(parent, name, "Cylinder", Vector3.new(height, diameter, diameter),
        CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT, color, material, decor)
end

-- Big floating station name, readable from spawn so new players know where to go.
local function banner(adornee, offset, title, subtitle, color)
    local gui = Instance.new("BillboardGui")
    gui.Name = "StationBanner"
    gui.Size = UDim2.fromOffset(260, 64)
    gui.StudsOffsetWorldSpace = offset
    gui.AlwaysOnTop = true
    gui.MaxDistance = 900
    gui.LightInfluence = 0
    gui.Parent = adornee
    for index, line in { { title, 30, color }, { subtitle, 18, Color3.new(1, 1, 1) } } do
        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromScale(1, index == 1 and 0.6 or 0.4)
        text.Position = UDim2.fromScale(0, index == 1 and 0 or 0.6)
        text.BackgroundTransparency = 1
        text.Text, text.TextSize, text.TextColor3 = line[1], line[2], line[3]
        text.TextStrokeTransparency = 0.2
        text.Font = Enum.Font.GothamBlack
        text.Parent = gui
    end
end

-- Invisible pickup volume plus a grid of prompt attachments over its footprint.
local function zone(parent, name, cframe, size, pointHeight)
    local part = make(parent, name, "Block", size, cframe, Color3.new(1, 1, 1), nil, true)
    part.Transparency = 1
    part.CastShadow = false
    local points = {}
    -- The outer points sit on the zone's edges, so a prompt shows from as far out as
    -- the server's distance-to-zone check allows.
    local nx = math.ceil(size.X / POINT_SPACING) + 1
    local nz = math.ceil(size.Z / POINT_SPACING) + 1
    for ix = 1, nx do
        for iz = 1, nz do
            local x = -size.X / 2 + size.X * (ix - 1) / (nx - 1)
            local z = -size.Z / 2 + size.Z * (iz - 1) / (nz - 1)
            local point = Instance.new("Attachment")
            point.Name = "PickupPoint"
            point.Position = Vector3.new(x, pointHeight - cframe.Y, z)
            point.Parent = part
            table.insert(points, point)
        end
    end
    return part, points
end

local RUST = {
    Color3.fromRGB(122, 74, 46), Color3.fromRGB(98, 82, 72), Color3.fromRGB(143, 92, 56),
    Color3.fromRGB(112, 112, 118), Color3.fromRGB(78, 72, 70), Color3.fromRGB(150, 140, 128),
}
local PAINT = {
    Color3.fromRGB(70, 96, 140), Color3.fromRGB(150, 56, 46), Color3.fromRGB(182, 152, 62),
    Color3.fromRGB(82, 122, 84), Color3.fromRGB(200, 200, 205),
}
local SCRAP_MATERIALS = { Enum.Material.CorrodedMetal, Enum.Material.Metal, Enum.Material.DiamondPlate, Enum.Material.CorrodedMetal }

-- One random piece of junk: plates, girders, pipes, barrels, tyres, car panels, chunks.
local function scrapPiece(parent, random, position)
    local kind = random:NextInteger(1, 7)
    local color = RUST[random:NextInteger(1, #RUST)]
    local material = SCRAP_MATERIALS[random:NextInteger(1, #SCRAP_MATERIALS)]
    local shape, size = "Block", nil
    if kind == 1 then
        size = Vector3.new(random:NextNumber(3, 7), random:NextNumber(0.3, 0.6), random:NextNumber(2, 5))
    elseif kind == 2 then
        size = Vector3.new(random:NextNumber(0.6, 1.1), random:NextNumber(0.6, 1.1), random:NextNumber(6, 12))
    elseif kind == 3 then
        local d = random:NextNumber(1, 2.2)
        shape, size = "Cylinder", Vector3.new(random:NextNumber(5, 10), d, d)
    elseif kind == 4 then
        shape, size, material = "Cylinder", Vector3.new(3.2, 2.4, 2.4), Enum.Material.Metal
        color = PAINT[random:NextInteger(1, #PAINT)]:Lerp(RUST[1], 0.35)
    elseif kind == 5 then
        shape, size, material = "Cylinder", Vector3.new(1.2, 3.6, 3.6), Enum.Material.Fabric
        color = Color3.fromRGB(30, 30, 32)
    elseif kind == 6 then
        size, material = Vector3.new(random:NextNumber(4, 6), random:NextNumber(2.5, 4), 0.3), Enum.Material.Metal
        color = PAINT[random:NextInteger(1, #PAINT)]:Lerp(RUST[2], 0.3)
    else
        size = Vector3.new(random:NextNumber(2, 4), random:NextNumber(2, 4), random:NextNumber(2, 4))
    end
    local rotation = CFrame.Angles(random:NextNumber(0, math.pi * 2), random:NextNumber(0, math.pi * 2), random:NextNumber(0, math.pi * 2))
    return make(parent, "Scrap", shape, size, CFrame.new(position) * rotation, color, material, true)
end

local function buildScrapPit(parent)
    local model = Instance.new("Model")
    model.Name = "ScrapPit"
    local c = METAL_CENTER
    local half = FOOTPRINT / 2
    local dirt, wall, floorColor = Color3.fromRGB(118, 92, 66), Color3.fromRGB(96, 74, 54), Color3.fromRGB(84, 66, 50)
    local ground = Enum.Material.Ground
    -- Rim: four banks around the hole, reaching down to the pit floor so they form its walls.
    local bankHeight = PIT_DEPTH + 2
    local bankY = -bankHeight / 2
    local endDepth = half.Y - PIT_HALF.Y
    local sideWidth = half.X - PIT_HALF.X
    for _, side in { -1, 1 } do
        make(model, "PitRim", "Block", Vector3.new(FOOTPRINT.X, bankHeight, endDepth),
            CFrame.new(c.X, bankY, c.Z + side * (PIT_HALF.Y + endDepth / 2)), dirt, ground)
        make(model, "PitRim", "Block", Vector3.new(sideWidth, bankHeight, PIT_HALF.Y * 2),
            CFrame.new(c.X + side * (PIT_HALF.X + sideWidth / 2), bankY, c.Z), dirt, ground)
    end
    make(model, "PitFloor", "Block", Vector3.new(PIT_HALF.X * 2, 2, PIT_HALF.Y * 2),
        CFrame.new(c.X, -PIT_DEPTH - 1, c.Z), floorColor, Enum.Material.Mud)
    -- Darker inner faces so the hole reads as a hole from the rim.
    for _, side in { -1, 1 } do
        make(model, "PitWall", "Block", Vector3.new(PIT_HALF.X * 2, PIT_DEPTH, 0.2),
            CFrame.new(c.X, -PIT_DEPTH / 2, c.Z + side * (PIT_HALF.Y - 0.1)), wall, ground, true)
        make(model, "PitWall", "Block", Vector3.new(0.2, PIT_DEPTH, PIT_HALF.Y * 2),
            CFrame.new(c.X + side * (PIT_HALF.X - 0.1), -PIT_DEPTH / 2, c.Z), wall, ground, true)
    end
    -- Hazard edge around the hole.
    local hazard = Color3.fromRGB(240, 190, 40)
    for _, side in { -1, 1 } do
        make(model, "PitEdge", "Block", Vector3.new(PIT_HALF.X * 2 + 2, 0.1, 1),
            CFrame.new(c.X, 0.05, c.Z + side * (PIT_HALF.Y + 0.5)), hazard, nil, true)
        make(model, "PitEdge", "Block", Vector3.new(1, 0.1, PIT_HALF.Y * 2),
            CFrame.new(c.X + side * (PIT_HALF.X + 0.5), 0.05, c.Z), hazard, nil, true)
    end
    -- Walk-down ramps on the road (+X) and spawn (-Z) sides (WedgePart is high at +Z).
    local ramps = {
        { Vector3.new(c.X + PIT_HALF.X - 8, 0, c.Z + 22), Vector3.xAxis },
        { Vector3.new(c.X + PIT_HALF.X - 8, 0, c.Z - 22), Vector3.xAxis },
        { Vector3.new(c.X - 12, 0, c.Z - PIT_HALF.Y + 8), -Vector3.zAxis },
    }
    for _, ramp in ramps do
        local center = ramp[1] + Vector3.new(0, -PIT_DEPTH / 2, 0)
        make(model, "PitRamp", "Wedge", Vector3.new(10, PIT_DEPTH, 16),
            CFrame.lookAt(center, center - ramp[2]), dirt, ground)
    end
    -- The heap: a sunken dome of scrap, collidable so players can scramble over it.
    local heapRadius, heapRise = 20, 11
    local heapCenter = Vector3.new(c.X, -PIT_DEPTH + heapRise - heapRadius, c.Z)
    make(model, "ScrapHeap", "Ball", Vector3.one * heapRadius * 2, CFrame.new(heapCenter),
        Color3.fromRGB(92, 66, 50), Enum.Material.CorrodedMetal)
    local footRadius = math.sqrt(heapRadius ^ 2 - (heapRadius - heapRise) ^ 2)
    local random = Random.new(1957)
    for _ = 1, 120 do
        local angle, r = random:NextNumber(0, math.pi * 2), footRadius * math.sqrt(random:NextNumber()) * 0.97
        local surface = heapCenter.Y + math.sqrt(heapRadius ^ 2 - r ^ 2)
        scrapPiece(model, random, Vector3.new(c.X + math.cos(angle) * r, surface - random:NextNumber(0, 0.8), c.Z + math.sin(angle) * r))
    end
    -- Loose junk across the pit floor and a little spilled over the rim.
    for _ = 1, 45 do
        local x, z = random:NextNumber(-PIT_HALF.X + 2, PIT_HALF.X - 2), random:NextNumber(-PIT_HALF.Y + 2, PIT_HALF.Y - 2)
        if Vector2.new(x, z).Magnitude > footRadius then
            scrapPiece(model, random, Vector3.new(c.X + x, -PIT_DEPTH + 0.4, c.Z + z))
        end
    end
    for _ = 1, 14 do
        local x, z = random:NextNumber(-half.X + 2, -PIT_HALF.X - 3), random:NextNumber(-half.Y + 3, half.Y - 3)
        scrapPiece(model, random, Vector3.new(c.X + x, 0.4, c.Z + z))
    end
    -- Magnet crane on the far rim, swung out over the heap.
    local yellow, steel = Color3.fromRGB(222, 170, 40), Color3.fromRGB(70, 74, 80)
    local craneBase = Vector3.new(c.X - half.X + 7, 0, c.Z + half.Y - 9)
    make(model, "CraneBase", "Block", Vector3.new(8, 2, 8), CFrame.new(craneBase + Vector3.new(0, 1, 0)), steel, Enum.Material.DiamondPlate)
    make(model, "CraneCab", "Block", Vector3.new(5, 4, 5), CFrame.new(craneBase + Vector3.new(0, 4, 0)), yellow, Enum.Material.Metal)
    local mastTop = craneBase + Vector3.new(0, 26, 0)
    for _, offset in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
        beam(model, "CraneMast", craneBase + Vector3.new(0, 6, 0) + offset, mastTop + offset, 0.5, yellow, Enum.Material.Metal)
    end
    for y = 9, 24, 3 do
        make(model, "CraneBrace", "Block", Vector3.new(2.5, 0.3, 2.5), CFrame.new(craneBase + Vector3.new(0, y, 0)), yellow, Enum.Material.Metal, true)
    end
    local tip = Vector3.new(c.X - 4, 22, c.Z + 6)
    beam(model, "CraneBoom", mastTop, tip, 1.2, yellow, Enum.Material.Metal)
    beam(model, "CraneJib", mastTop, mastTop + (mastTop - tip).Unit * 8, 1.2, yellow, Enum.Material.Metal)
    make(model, "CraneCounterweight", "Block", Vector3.new(3, 3, 3), CFrame.new(mastTop + (mastTop - tip).Unit * 8 - Vector3.new(0, 1.5, 0)), steel, Enum.Material.Concrete)
    beam(model, "CraneCable", tip, tip - Vector3.new(0, 8, 0), 0.25, Color3.fromRGB(30, 30, 30), nil, true)
    local magnet = tip - Vector3.new(0, 8.6, 0)
    column(model, "CraneMagnet", magnet - Vector3.new(0, 0.6, 0), 1.2, 7, steel, Enum.Material.DiamondPlate, true)
    for index = 1, 5 do
        scrapPiece(model, random, magnet - Vector3.new(math.cos(index) * 2, 1.4, math.sin(index) * 2))
    end
    -- Signpost on the road-side rim, at the spawn end.
    local signBase = Vector3.new(c.X + half.X - 4, 0, c.Z - half.Y + 12)
    for _, dz in { -4, 4 } do
        make(model, "SignPost", "Block", Vector3.new(0.6, 9, 0.6), CFrame.new(signBase + Vector3.new(0, 4.5, dz)), steel, Enum.Material.Metal)
    end
    local board = make(model, "SignBoard", "Block", Vector3.new(0.4, 3.5, 10), CFrame.new(signBase + Vector3.new(0, 8, 0)), yellow, Enum.Material.Metal)

    local pickup, points = zone(model, "Scrap Pit",
        CFrame.new(c.X, (heapRise - PIT_DEPTH + 3) / 2, c.Z), Vector3.new(PIT_HALF.X * 2, heapRise + PIT_DEPTH + 3, PIT_HALF.Y * 2), 2)
    banner(board, Vector3.new(0, 8, 0), "SCRAP PIT", "Pick up METAL here", Color3.fromRGB(175, 205, 230))
    model.Parent = parent
    return { model = model, zone = pickup, points = points }
end

local function buildRefinery(parent)
    local model = Instance.new("Model")
    model.Name = "OilRefinery"
    local c = FUEL_CENTER
    local half = FOOTPRINT / 2
    local concrete, steel, dark = Color3.fromRGB(122, 126, 132), Color3.fromRGB(168, 174, 184), Color3.fromRGB(48, 52, 60)
    local white, red, amber = Color3.fromRGB(232, 234, 236), Color3.fromRGB(196, 44, 36), Color3.fromRGB(255, 165, 55)
    local padTop = 0.3
    make(model, "RefineryPad", "Block", Vector3.new(FOOTPRINT.X, 2.3, FOOTPRINT.Y),
        CFrame.new(c.X, padTop - 1.15, c.Z), concrete, Enum.Material.Concrete)
    local function at(x, y, z) return Vector3.new(c.X + x, padTop + y, c.Z + z) end

    -- Fuelling canopy along the front edge, facing the launch pad: this is the pickup.
    local canopyX, canopyWidth, canopyLength, roofY = -half.X + 13, 24, 88, 14
    make(model, "CanopyRoof", "Block", Vector3.new(canopyWidth, 1.2, canopyLength), CFrame.new(at(canopyX, roofY, 0)), white, Enum.Material.Metal)
    for _, side in { -1, 1 } do
        make(model, "CanopyFascia", "Block", Vector3.new(0.4, 2, canopyLength + 0.8),
            CFrame.new(at(canopyX + side * (canopyWidth / 2 + 0.2), roofY, 0)), red, Enum.Material.SmoothPlastic, true)
        make(model, "CanopyFascia", "Block", Vector3.new(canopyWidth, 2, 0.4),
            CFrame.new(at(canopyX, roofY, side * (canopyLength / 2 + 0.2))), red, Enum.Material.SmoothPlastic, true)
    end
    for _, dx in { -7, 7 } do
        make(model, "CanopyLight", "Block", Vector3.new(1.2, 0.15, canopyLength - 4),
            CFrame.new(at(canopyX + dx, roofY - 0.68, 0)), Color3.fromRGB(255, 244, 214), Enum.Material.Neon, true)
    end
    for z = -36, 36, 18 do
        make(model, "CanopyColumn", "Block", Vector3.new(1.4, roofY - 0.6, 1.4), CFrame.new(at(canopyX, (roofY - 0.6) / 2, z)), steel, Enum.Material.Metal)
    end
    -- Two rows of pump islands under the canopy.
    for _, dx in { -6, 6 } do
        for z = -36, 36, 12 do
            local base = at(canopyX + dx, 0, z)
            make(model, "PumpIsland", "Block", Vector3.new(3, 0.6, 7), CFrame.new(base + Vector3.new(0, 0.3, 0)), Color3.fromRGB(190, 192, 196), Enum.Material.Concrete)
            make(model, "FuelPump", "Block", Vector3.new(2, 5, 2.6), CFrame.new(base + Vector3.new(0, 3.1, 0)), white, Enum.Material.SmoothPlastic)
            make(model, "PumpTop", "Block", Vector3.new(2.1, 0.9, 2.7), CFrame.new(base + Vector3.new(0, 5.4, 0)), red, Enum.Material.SmoothPlastic, true)
            make(model, "PumpScreen", "Block", Vector3.new(2.15, 1, 1.6), CFrame.new(base + Vector3.new(0, 4, 0)), amber, Enum.Material.Neon, true)
            local nozzle = base + Vector3.new(-dx / 6 * 1.1, 2.6, 0.8)
            pipe(model, "PumpHose", base + Vector3.new(-dx / 6 * 1.05, 4.6, 0.8), nozzle, 0.25, dark, nil, true)
            make(model, "PumpNozzle", "Block", Vector3.new(0.4, 0.9, 0.4), CFrame.new(nozzle), dark, Enum.Material.Metal, true)
        end
    end
    -- Pallets of jerry cans at both canopy ends: what you're here to fill.
    for _, z in { -half.Y + 4, half.Y - 4 } do
        local pallet = at(canopyX - 6, 0, z)
        make(model, "Pallet", "Block", Vector3.new(6, 0.5, 4), CFrame.new(pallet + Vector3.new(0, 0.25, 0)), Color3.fromRGB(150, 112, 70), Enum.Material.WoodPlanks)
        for ix = 0, 3 do
            for layer = 0, 1 do
                make(model, "JerryCanStack", "Block", Vector3.new(1.3, 1.8, 0.65),
                    CFrame.new(pallet + Vector3.new(-2.1 + ix * 1.4, 1.4 + layer * 1.85, 0)), red, Enum.Material.Metal, true)
                make(model, "JerryCanStack", "Block", Vector3.new(1.3, 1.8, 0.65),
                    CFrame.new(pallet + Vector3.new(-2.1 + ix * 1.4, 1.4 + layer * 1.85, 1.2)), red, Enum.Material.Metal, true)
            end
        end
    end

    -- Elevated pipe rack between the canopy and the plant (high enough to walk under).
    local rackX, rackY = -half.X + 30, 10
    for z = -40, 40, 16 do
        make(model, "RackPost", "Block", Vector3.new(0.8, rackY, 0.8), CFrame.new(at(rackX, rackY / 2, z)), steel, Enum.Material.Metal)
        make(model, "RackArm", "Block", Vector3.new(5, 0.6, 0.8), CFrame.new(at(rackX, rackY, z)), steel, Enum.Material.Metal)
    end
    local pipeColors = { Color3.fromRGB(230, 190, 50), Color3.fromRGB(150, 156, 166), red }
    for index, color in pipeColors do
        local dx = (index - 2) * 1.6
        pipe(model, "RackPipe", at(rackX + dx, rackY + 0.9, -44), at(rackX + dx, rackY + 0.9, 44), 1.2, color, Enum.Material.Metal)
    end
    -- Feed pipes drop from the rack into the canopy roof.
    for z = -24, 24, 24 do
        pipe(model, "FeedPipe", at(rackX, rackY + 0.9, z), at(canopyX + canopyWidth / 2, roofY - 1, z), 0.9, pipeColors[1], Enum.Material.Metal, true)
    end

    -- Storage tanks.
    for index, z in { -34, -12 } do
        local base = at(14, 0, z)
        column(model, "StorageTank", base, 14, 18, white, Enum.Material.Metal)
        column(model, "TankBand", base + Vector3.new(0, 10, 0), 1.6, 18.2, index == 1 and red or Color3.fromRGB(60, 110, 170), Enum.Material.SmoothPlastic, true)
        make(model, "TankRoof", "Ball", Vector3.one * 18, CFrame.new(base + Vector3.new(0, 7.5, 0)), white, Enum.Material.Metal)
        pipe(model, "TankPipe", base + Vector3.new(-9, 3, 0), at(rackX, 3, z), 1, pipeColors[2], Enum.Material.Metal, true)
        pipe(model, "TankRiser", at(rackX, 3, z), at(rackX, rackY + 0.9, z), 1, pipeColors[2], Enum.Material.Metal)
    end
    -- Distillation columns with walkway rings.
    for _, spec in { { z = 12, height = 40, d = 6 }, { z = 24, height = 28, d = 5 } } do
        local base = at(6, 0, spec.z)
        column(model, "DistillationColumn", base, spec.height, spec.d, steel, Enum.Material.Metal)
        make(model, "ColumnCap", "Ball", Vector3.one * spec.d, CFrame.new(base + Vector3.new(0, spec.height, 0)), steel, Enum.Material.Metal, true)
        for y = 8, spec.height - 4, 9 do
            column(model, "ColumnWalkway", base + Vector3.new(0, y, 0), 0.4, spec.d + 3, Color3.fromRGB(230, 190, 50), Enum.Material.DiamondPlate, true)
        end
        pipe(model, "ColumnPipe", base + Vector3.new(-spec.d / 2, 6, 0), at(rackX, 6, spec.z), 1, pipeColors[3], Enum.Material.Metal, true)
        pipe(model, "ColumnRiser", at(rackX, 6, spec.z), at(rackX, rackY + 0.9, spec.z), 1, pipeColors[3], Enum.Material.Metal)
    end

    -- Oil derrick in the back corner: tapered lattice tower over a drill floor.
    local derrickColor = Color3.fromRGB(205, 82, 44)
    local derrick, height, baseHalf, topHalf = at(28, 0, 30), 48, 6, 1.6
    local function corner(y, sx, sz)
        local h = baseHalf + (topHalf - baseHalf) * (y / height)
        return derrick + Vector3.new(sx * h, y, sz * h)
    end
    local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
    for _, s in corners do
        beam(model, "DerrickLeg", corner(0, s[1], s[2]), corner(height, s[1], s[2]), 0.7, derrickColor, Enum.Material.Metal)
    end
    for level = 1, 6 do
        local y0, y1 = (level - 1) * 8, level * 8
        for index, s in corners do
            local n = corners[index % 4 + 1]
            beam(model, "DerrickBrace", corner(y1, s[1], s[2]), corner(y1, n[1], n[2]), 0.4, derrickColor, Enum.Material.Metal, true)
            if level > 1 then
                beam(model, "DerrickBrace", corner(y0, s[1], s[2]), corner(y1, n[1], n[2]), 0.3, derrickColor, Enum.Material.Metal, true)
            end
        end
    end
    make(model, "DrillFloor", "Block", Vector3.new(14, 1, 14), CFrame.new(derrick + Vector3.new(0, 6, 0)), dark, Enum.Material.DiamondPlate)
    make(model, "CrownBlock", "Block", Vector3.new(4.5, 2, 4.5), CFrame.new(derrick + Vector3.new(0, height + 1, 0)), dark, Enum.Material.Metal)
    beam(model, "DrillString", derrick + Vector3.new(0, 6.5, 0), derrick + Vector3.new(0, height, 0), 0.5, Color3.fromRGB(40, 40, 42), nil, true)
    make(model, "Doghouse", "Block", Vector3.new(6, 5, 8), CFrame.new(derrick + Vector3.new(-10, 2.5, -2)), Color3.fromRGB(230, 190, 50), Enum.Material.Metal)
    -- Pumpjack ("nodding donkey").
    local jack = at(28, 0, 2)
    make(model, "PumpjackBase", "Block", Vector3.new(4, 1, 18), CFrame.new(jack + Vector3.new(0, 0.5, 0)), dark, Enum.Material.Metal)
    for _, s in { -1, 1 } do
        beam(model, "PumpjackPost", jack + Vector3.new(s * 1.6, 1, -2), jack + Vector3.new(0, 9, 0), 0.7, dark, Enum.Material.Metal)
        beam(model, "PumpjackPost", jack + Vector3.new(s * 1.6, 1, 2), jack + Vector3.new(0, 9, 0), 0.7, dark, Enum.Material.Metal)
    end
    local tilt = CFrame.new(jack + Vector3.new(0, 9.5, 0)) * CFrame.Angles(math.rad(12), 0, 0)
    make(model, "WalkingBeam", "Block", Vector3.new(1.2, 1.4, 18), tilt, Color3.fromRGB(230, 190, 50), Enum.Material.Metal)
    make(model, "Horsehead", "Block", Vector3.new(1.6, 4.5, 2), tilt * CFrame.new(0, -1, -9.4), Color3.fromRGB(230, 190, 50), Enum.Material.Metal)
    beam(model, "PolishedRod", (tilt * CFrame.new(0, -3.3, -9.4)).Position, jack + Vector3.new(0, 1, -9.6), 0.2, steel, nil, true)
    column(model, "Wellhead", jack + Vector3.new(0, 0, -9.6), 1.5, 1.6, red, Enum.Material.Metal)
    make(model, "Counterweight", "Cylinder", Vector3.new(1, 5, 5), CFrame.new(jack + Vector3.new(0, 3.5, 7)), dark, Enum.Material.Metal)
    -- Flare stack, burning off gas.
    local flare = at(34, 0, -44)
    column(model, "FlareStack", flare, 46, 1.6, steel, Enum.Material.Metal)
    local flame = make(model, "Flare", "Ball", Vector3.one * 3, CFrame.new(flare + Vector3.new(0, 47.4, 0)), amber, Enum.Material.Neon, true)
    flame.CastShadow = false
    local fire = Instance.new("Fire")
    fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 8, 12, amber, Color3.fromRGB(255, 80, 30)
    fire.Parent = flame
    local glow = Instance.new("PointLight")
    glow.Color, glow.Range, glow.Brightness = amber, 30, 2
    glow.Parent = flame

    local pickup, points = zone(model, "Oil Refinery",
        CFrame.new(at(canopyX, 6, 0)), Vector3.new(canopyWidth + 2, 13, canopyLength + 2), padTop + 2.5)
    banner(model.CanopyRoof, Vector3.new(0, 8, 0), "OIL REFINERY", "Fill up on FUEL here", amber)
    model.Parent = parent
    return { model = model, zone = pickup, points = points }
end

-- One packed-gravel road from the apron edge, past spawn and on between the two stations.
local function roads(parent)
    local width = 16
    local a = Vector3.new(0, 0.1, -50 + width / 2)
    local b = Vector3.new(0, 0.1, METAL_CENTER.Z + FOOTPRINT.Y / 2 - width / 2)
    make(parent, "StationRoad", "Block", Vector3.new(width, 0.2, (b - a).Magnitude + width),
        CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(150, 138, 118), Enum.Material.Pebble, true)
end

function Stations.build(parent)
    roads(parent)
    return { Metal = buildScrapPit(parent), Fuel = buildRefinery(parent) }
end

return Stations
