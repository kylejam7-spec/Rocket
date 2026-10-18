--[[
    The two material pickup stations, sized for a full 50-player server, flanking spawn
    either side of the lane (SiteLayout), each facing it:
        Metal  SALVAGE YARD  west: a walled gravel yard of scrap mountains, a magnet crane,
                             a conveyor into a compactor, skips and crushed-car cubes
        Fuel   FUEL DEPOT    east: cryo spheres on legs, bullet tanks, a pipe rack and a
                             venting stack behind a fuelling gantry of dispensers

    Stations.build(parent) returns { Metal = station, Fuel = station }, where
    station.zone is the invisible pickup volume (players within InteractionDistance
    of it may pick up) and station.points are attachments spread over it, one
    pickup prompt each, so a crowd can work the station from every side.
    Stations.Reserved lists the footprints map expansion must leave alone.
]]
local Layout = require(script.Parent.SiteLayout)
local Stations = {}

local FOOTPRINT = Layout.StationFootprint
-- Prompt points are this far apart at most, so every spot in or at the edge of a
-- zone is within a prompt's reach (InteractionDistance = 10).
local POINT_SPACING = 12

Stations.Reserved = Layout.Reserved

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
    gui.Size = UDim2.fromOffset(300, 72)
    gui.StudsOffsetWorldSpace = offset
    gui.AlwaysOnTop = true
    gui.MaxDistance = 900
    gui.LightInfluence = 0
    gui.Parent = adornee
    for index, line in { { title, 34, color }, { subtitle, 20, Color3.new(1, 1, 1) } } do
        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromScale(1, index == 1 and 0.6 or 0.4)
        text.Position = UDim2.fromScale(0, index == 1 and 0 or 0.6)
        text.BackgroundTransparency = 1
        text.Text, text.TextSize, text.TextColor3 = line[1], line[2], line[3]
        text.Font = Enum.Font.FredokaOne
        text.Parent = gui
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = index == 1 and 3 or 2
        stroke.Color = Color3.fromRGB(22, 14, 32)
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = text
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

-- A scrap mountain: a sunken dome (collidable, so players scramble over it) under
-- loose junk. Returns its top.
local function scrapHeap(model, random, center, radius, rise, pieces)
    local ball = Vector3.new(center.X, center.Y + rise - radius, center.Z)
    make(model, "ScrapHeap", "Ball", Vector3.one * radius * 2, CFrame.new(ball), Color3.fromRGB(92, 66, 50), Enum.Material.CorrodedMetal)
    local foot = math.sqrt(radius ^ 2 - (radius - rise) ^ 2)
    for _ = 1, pieces do
        local angle, r = random:NextNumber(0, math.pi * 2), foot * math.sqrt(random:NextNumber()) * 0.97
        local surface = ball.Y + math.sqrt(radius ^ 2 - r ^ 2)
        scrapPiece(model, random, Vector3.new(center.X + math.cos(angle) * r, surface - random:NextNumber(0, 0.8), center.Z + math.sin(angle) * r))
    end
    return center + Vector3.new(0, rise, 0)
end

-- Corrugated site fencing from a to b on a low concrete footing (solid).
local function sheetFence(model, a, b, height)
    local length = (b - a).Magnitude
    local frame = CFrame.lookAt((a + b) / 2, b)
    make(model, "FenceFooting", "Block", Vector3.new(1.2, 1.5, length), frame * CFrame.new(0, 0.75, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
    make(model, "FenceSheet", "Block", Vector3.new(0.4, height, length), frame * CFrame.new(0, 1.5 + height / 2, 0), Color3.fromRGB(70, 92, 86), Enum.Material.CorrodedMetal)
    for along = -length / 2, length / 2, 10 do
        make(model, "FencePost", "Block", Vector3.new(0.7, height + 2, 0.7), frame * CFrame.new(0, (height + 2) / 2, along), Color3.fromRGB(60, 64, 70), Enum.Material.Metal, true)
    end
end

-- A gantry over an entrance: two posts and a crossbeam carrying a sign board.
local function gantry(model, base, facing, width, height, color)
    local frame = CFrame.lookAt(base, base + facing)
    for _, side in { -1, 1 } do
        make(model, "GantryPost", "Block", Vector3.new(1.2, height, 1.2), frame * CFrame.new(side * width / 2, height / 2, 0), color, Enum.Material.Metal)
    end
    make(model, "GantryBeam", "Block", Vector3.new(width + 2, 1.4, 1.4), frame * CFrame.new(0, height, 0), color, Enum.Material.Metal)
    return make(model, "GantrySign", "Block", Vector3.new(width - 4, 4, 0.5), frame * CFrame.new(0, height + 2.6, 0), Color3.fromRGB(35, 40, 50), Enum.Material.Metal)
end

local function buildSalvageYard(parent)
    local model = Instance.new("Model")
    model.Name = "SalvageYard"
    local c = Layout.Metal
    local half = FOOTPRINT / 2
    local random = Random.new(1957)
    local yellow, steel, dark = Color3.fromRGB(222, 170, 40), Color3.fromRGB(70, 74, 80), Color3.fromRGB(40, 42, 46)
    make(model, "YardFloor", "Block", Vector3.new(FOOTPRINT.X, 1.4, FOOTPRINT.Y), CFrame.new(c.X, -0.5, c.Z), Color3.fromRGB(96, 88, 80), Enum.Material.Pebble)
    -- Fencing on the back (-X) and both ends, with a gap toward the launch pad (-Z).
    local x0, x1, z0, z1 = c.X - half.X, c.X + half.X, c.Z - half.Y, c.Z + half.Y
    sheetFence(model, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), 7)
    sheetFence(model, Vector3.new(x0, 0, z1), Vector3.new(x1 - 6, 0, z1), 7)
    sheetFence(model, Vector3.new(x0, 0, z0), Vector3.new(c.X - 8, 0, z0), 7)
    sheetFence(model, Vector3.new(c.X + 14, 0, z0), Vector3.new(x1 - 6, 0, z0), 7)

    -- Three scrap mountains.
    scrapHeap(model, random, Vector3.new(c.X - 14, 0, c.Z - 26), 17, 9, 70)
    local big = scrapHeap(model, random, Vector3.new(c.X - 12, 0, c.Z + 22), 20, 12, 95)
    scrapHeap(model, random, Vector3.new(c.X + 14, 0, c.Z + 2), 12, 6, 45)
    for _ = 1, 40 do
        scrapPiece(model, random, Vector3.new(c.X + random:NextNumber(-half.X + 4, half.X - 6), 0.5, c.Z + random:NextNumber(-half.Y + 4, half.Y - 4)))
    end
    -- Crushed-car cubes stacked along the back fence.
    for row = 0, 7 do
        for layer = 0, random:NextInteger(0, 2) do
            local color = (row + layer) % 3 == 0 and PAINT[random:NextInteger(1, #PAINT)]:Lerp(RUST[1], 0.4) or RUST[random:NextInteger(1, #RUST)]
            make(model, "CrushedCube", "Block", Vector3.new(3.6, 3.2, 4.6),
                CFrame.new(x0 + 4, 1.6 + layer * 3.2, z0 + 10 + row * 11) * CFrame.Angles(0, random:NextNumber(-0.15, 0.15), 0), color, Enum.Material.CorrodedMetal)
        end
    end
    -- Skips (open bins) of scrap near the front.
    for index, z in { -38, -6, 34 } do
        local base = Vector3.new(x1 - 12, 0, c.Z + z)
        make(model, "SkipFloor", "Block", Vector3.new(6, 0.6, 10), CFrame.new(base + Vector3.new(0, 0.3, 0)), yellow, Enum.Material.Metal)
        for _, side in { -1, 1 } do
            make(model, "SkipSide", "Block", Vector3.new(0.4, 3, 10), CFrame.new(base + Vector3.new(side * 3, 1.8, 0)), yellow, Enum.Material.Metal)
            make(model, "SkipEnd", "Wedge", Vector3.new(6, 3, 2), CFrame.new(base + Vector3.new(0, 1.8, side * 5.5)) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0), yellow, Enum.Material.Metal)
        end
        for _ = 1, 6 + index do
            scrapPiece(model, random, base + Vector3.new(random:NextNumber(-2, 2), random:NextNumber(2.2, 3.6), random:NextNumber(-4, 4)))
        end
    end
    -- Conveyor from the big heap up into a compactor.
    local compactor = Vector3.new(c.X + 16, 0, c.Z + 40)
    make(model, "Compactor", "Block", Vector3.new(10, 9, 9), CFrame.new(compactor + Vector3.new(0, 4.5, 0)), yellow, Enum.Material.Metal)
    make(model, "CompactorBand", "Block", Vector3.new(10.2, 1.2, 9.2), CFrame.new(compactor + Vector3.new(0, 7, 0)), dark, Enum.Material.Metal, true)
    for _, side in { -1, 1 } do
        make(model, "Hopper", "Wedge", Vector3.new(10, 3, 3), CFrame.new(compactor + Vector3.new(0, 10.5, side * 3.4)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), steel, Enum.Material.Metal)
    end
    for index = 0, 2 do
        make(model, "CompactedCube", "Block", Vector3.new(2.6, 2.6, 2.6), CFrame.new(compactor + Vector3.new(8 + index * 3, 1.3, 2)), RUST[index + 1], Enum.Material.CorrodedMetal)
    end
    local beltFrom, beltTo = Vector3.new(c.X - 8, 2, c.Z + 34), compactor + Vector3.new(-4, 11, -2)
    beam(model, "ConveyorBelt", beltFrom, beltTo, 3.2, dark, Enum.Material.Rubber)
    for t = 0.1, 0.95, 0.2 do
        local at = beltFrom:Lerp(beltTo, t)
        make(model, "ConveyorLeg", "Block", Vector3.new(0.6, at.Y, 0.6), CFrame.new(at.X, at.Y / 2, at.Z), steel, Enum.Material.Metal, true)
    end
    -- Magnet crane in the back corner, swung out over the big heap.
    local craneBase = Vector3.new(x0 + 8, 0, z1 - 10)
    make(model, "CraneBase", "Block", Vector3.new(10, 2, 10), CFrame.new(craneBase + Vector3.new(0, 1, 0)), steel, Enum.Material.DiamondPlate)
    make(model, "CraneCab", "Block", Vector3.new(6, 5, 6), CFrame.new(craneBase + Vector3.new(0, 4.5, 0)), yellow, Enum.Material.Metal)
    local mastTop = craneBase + Vector3.new(0, 38, 0)
    for _, offset in { Vector3.new(-1.4, 0, -1.4), Vector3.new(1.4, 0, -1.4), Vector3.new(-1.4, 0, 1.4), Vector3.new(1.4, 0, 1.4) } do
        beam(model, "CraneMast", craneBase + Vector3.new(0, 7, 0) + offset, mastTop + offset, 0.6, yellow, Enum.Material.Metal)
    end
    for y = 10, 36, 4 do
        make(model, "CraneBrace", "Block", Vector3.new(3.4, 0.3, 3.4), CFrame.new(craneBase + Vector3.new(0, y, 0)), yellow, Enum.Material.Metal, true)
    end
    local tip = big + Vector3.new(4, 16, -2)
    beam(model, "CraneBoom", mastTop, tip, 1.4, yellow, Enum.Material.Metal)
    beam(model, "CraneJib", mastTop, mastTop + (mastTop - tip).Unit * 10, 1.4, yellow, Enum.Material.Metal)
    make(model, "CraneCounterweight", "Block", Vector3.new(4, 4, 4), CFrame.new(mastTop + (mastTop - tip).Unit * 10 - Vector3.new(0, 2, 0)), steel, Enum.Material.Concrete)
    beam(model, "CraneCable", tip, tip - Vector3.new(0, 9, 0), 0.25, Color3.fromRGB(30, 30, 30), nil, true)
    local magnet = tip - Vector3.new(0, 9.6, 0)
    column(model, "CraneMagnet", magnet - Vector3.new(0, 0.6, 0), 1.2, 8, steel, Enum.Material.DiamondPlate, true)
    for index = 1, 6 do
        scrapPiece(model, random, magnet - Vector3.new(math.cos(index) * 2.4, 1.4, math.sin(index) * 2.4))
    end
    -- Entrance gantry on the lane side, signed.
    local sign = gantry(model, Vector3.new(x1, 0, c.Z), Vector3.new(1, 0, 0), 28, 16, yellow)
    local pickup, points = zone(model, "Salvage Yard",
        CFrame.new(c.X - 2, 7, c.Z), Vector3.new(FOOTPRINT.X - 14, 16, FOOTPRINT.Y - 10), 2)
    banner(sign, Vector3.new(0, 6, 0), "SALVAGE YARD", "Pick up METAL here", Color3.fromRGB(175, 205, 230))
    model.Parent = parent
    return { model = model, zone = pickup, points = points }
end

local function buildFuelDepot(parent)
    local model = Instance.new("Model")
    model.Name = "FuelDepot"
    local c = Layout.Fuel
    local half = FOOTPRINT / 2
    local concrete, steel, dark = Color3.fromRGB(150, 152, 156), Color3.fromRGB(176, 182, 192), Color3.fromRGB(48, 52, 60)
    local white, orange, amber, cyan = Color3.fromRGB(236, 238, 240), Color3.fromRGB(232, 120, 40), Color3.fromRGB(255, 165, 55), Color3.fromRGB(90, 220, 255)
    local hazardA, hazardB = Color3.fromRGB(245, 200, 40), Color3.fromRGB(30, 30, 34)
    local padTop = 0.3
    make(model, "DepotPad", "Block", Vector3.new(FOOTPRINT.X, 2.3, FOOTPRINT.Y), CFrame.new(c.X, padTop - 1.15, c.Z), concrete, Enum.Material.Concrete)
    local function at(x, y, z) return Vector3.new(c.X + x, padTop + y, c.Z + z) end

    -- Fuelling gantry along the lane side (-X): the pickup. A steel roof with a
    -- hazard-striped edge over two rows of tall dispensers.
    local gantryX, gantryWidth, gantryLength, roofY = -half.X + 14, 26, 92, 15
    make(model, "GantryRoof", "Block", Vector3.new(gantryWidth, 1.2, gantryLength), CFrame.new(at(gantryX, roofY, 0)), white, Enum.Material.Metal)
    for index = 0, math.floor(gantryLength / 4) - 1 do
        local z = -gantryLength / 2 + 2 + index * 4
        for _, side in { -1, 1 } do
            make(model, "HazardEdge", "Block", Vector3.new(0.4, 1.8, 4), CFrame.new(at(gantryX + side * (gantryWidth / 2 + 0.2), roofY, z)),
                index % 2 == 0 and hazardA or hazardB, Enum.Material.SmoothPlastic, true)
        end
    end
    for z = -gantryLength / 2 + 4, gantryLength / 2 - 4, 4 do
        make(model, "GantryTruss", "Block", Vector3.new(gantryWidth - 1, 0.5, 0.5), CFrame.new(at(gantryX, roofY + 1.6, z)), steel, Enum.Material.Metal, true)
    end
    for _, dx in { -8, 8 } do
        make(model, "GantryLight", "Block", Vector3.new(1.2, 0.15, gantryLength - 4), CFrame.new(at(gantryX + dx, roofY - 0.68, 0)), Color3.fromRGB(230, 248, 255), Enum.Material.Neon, true)
    end
    for z = -40, 40, 20 do
        for _, dx in { -gantryWidth / 2 + 1, gantryWidth / 2 - 1 } do
            make(model, "GantryColumn", "Block", Vector3.new(1.4, roofY - 0.6, 1.4), CFrame.new(at(gantryX + dx, (roofY - 0.6) / 2, z)), steel, Enum.Material.Metal)
        end
    end
    for _, dx in { -5.5, 5.5 } do
        for z = -36, 36, 12 do
            local base = at(gantryX + dx, 0, z)
            make(model, "DispenserBase", "Block", Vector3.new(3.4, 0.6, 5), CFrame.new(base + Vector3.new(0, 0.3, 0)), Color3.fromRGB(190, 192, 196), Enum.Material.Concrete)
            make(model, "Dispenser", "Block", Vector3.new(2.4, 7, 3), CFrame.new(base + Vector3.new(0, 4.1, 0)), white, Enum.Material.SmoothPlastic)
            make(model, "DispenserPanel", "Block", Vector3.new(2.45, 2.2, 1.8), CFrame.new(base + Vector3.new(0, 5.4, 0)), z % 24 == 0 and cyan or amber, Enum.Material.Neon, true)
            make(model, "DispenserCap", "Block", Vector3.new(2.6, 0.8, 3.2), CFrame.new(base + Vector3.new(0, 8, 0)), orange, Enum.Material.SmoothPlastic, true)
            make(model, "HoseReel", "Cylinder", Vector3.new(0.8, 2.2, 2.2), CFrame.new(base + Vector3.new(-dx / 5.5 * 1.6, 3, 0)), dark, Enum.Material.Rubber, true)
        end
    end
    -- Pallets of jerry cans at both gantry ends: what you're here to fill.
    for _, z in { -half.Y + 4, half.Y - 4 } do
        local pallet = at(gantryX - 7, 0, z)
        make(model, "Pallet", "Block", Vector3.new(6, 0.5, 4), CFrame.new(pallet + Vector3.new(0, 0.25, 0)), Color3.fromRGB(150, 112, 70), Enum.Material.WoodPlanks)
        for ix = 0, 3 do
            for layer = 0, 1 do
                for _, dz in { 0, 1.2 } do
                    make(model, "JerryCanStack", "Block", Vector3.new(1.3, 1.8, 0.65),
                        CFrame.new(pallet + Vector3.new(-2.1 + ix * 1.4, 1.4 + layer * 1.85, dz)), Color3.fromRGB(196, 44, 36), Enum.Material.Metal, true)
                end
            end
        end
    end

    -- Pipe rack behind the gantry, high enough to walk under, feeding it.
    local rackX, rackY = gantryX + gantryWidth / 2 + 6, 11
    for z = -48, 48, 16 do
        make(model, "RackPost", "Block", Vector3.new(0.9, rackY, 0.9), CFrame.new(at(rackX, rackY / 2, z)), steel, Enum.Material.Metal)
        make(model, "RackArm", "Block", Vector3.new(6, 0.6, 0.9), CFrame.new(at(rackX, rackY, z)), steel, Enum.Material.Metal)
    end
    local pipeColors = { white, orange, Color3.fromRGB(80, 140, 200) }
    for index, color in pipeColors do
        pipe(model, "RackPipe", at(rackX + (index - 2) * 1.8, rackY + 1, -50), at(rackX + (index - 2) * 1.8, rackY + 1, 50), 1.3, color, Enum.Material.Metal)
    end
    for z = -24, 24, 24 do
        pipe(model, "FeedPipe", at(rackX, rackY + 1, z), at(gantryX + gantryWidth / 2, roofY - 1, z), 1, pipeColors[2], Enum.Material.Metal, true)
    end

    -- Two cryogenic spheres on legs with an equator walkway (oxidiser and fuel).
    for index, spec in { { z = -28, band = Color3.fromRGB(80, 140, 200) }, { z = 6, band = orange } } do
        local center = at(20, 17, spec.z)
        make(model, "CryoSphere", "Ball", Vector3.one * 24, CFrame.new(center), white, Enum.Material.SmoothPlastic)
        column(model, "CryoBand", center - Vector3.new(0, 0.9, 0), 1.8, 24.2, spec.band, Enum.Material.SmoothPlastic, true)
        column(model, "CryoWalkway", center - Vector3.new(0, 0.3, 0), 0.5, 29, Color3.fromRGB(230, 190, 50), Enum.Material.DiamondPlate, true)
        for leg = 1, 8 do
            local angle = leg / 8 * math.pi * 2
            local foot = at(20 + math.cos(angle) * 11.5, 0, spec.z + math.sin(angle) * 11.5)
            column(model, "CryoLeg", foot, 17, 1.2, steel, Enum.Material.Metal)
        end
        pipe(model, "CryoPipe", center - Vector3.new(0, 8, 0), at(rackX, rackY + 1, spec.z), 1.2, pipeColors[index == 1 and 3 or 2], Enum.Material.Metal, true)
    end
    -- Horizontal bullet tanks on saddles at the back.
    for _, x in { 10, 26 } do
        local center = at(x, 6, 38)
        make(model, "BulletTank", "Cylinder", Vector3.new(22, 8, 8), CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0), white, Enum.Material.Metal)
        for _, side in { -1, 1 } do
            make(model, "TankEnd", "Ball", Vector3.one * 8, CFrame.new(center + Vector3.new(0, 0, side * 11)), white, Enum.Material.Metal)
            make(model, "TankSaddle", "Block", Vector3.new(6, 2.4, 1.2), CFrame.new(at(x, 1.2, 38 + side * 6)), steel, Enum.Material.Metal)
        end
    end
    -- Vent stack, boiling off cold vapour.
    local vent = at(36, 0, -46)
    column(model, "VentStack", vent, 34, 1.8, steel, Enum.Material.Metal)
    local top = make(model, "VentTop", "Block", Vector3.new(2.4, 1, 2.4), CFrame.new(vent + Vector3.new(0, 34.5, 0)), dark, Enum.Material.Metal, true)
    local vapour = Instance.new("Smoke")
    vapour.Color, vapour.Opacity, vapour.RiseVelocity, vapour.Size = Color3.fromRGB(235, 240, 245), 0.25, 4, 3
    vapour.Parent = top
    -- A propellant tanker parked by the spheres.
    local truck = at(34, 0, 22)
    make(model, "TruckChassis", "Block", Vector3.new(4, 1, 20), CFrame.new(truck + Vector3.new(0, 1.6, 0)), dark, Enum.Material.Metal)
    make(model, "TruckCab", "Block", Vector3.new(4.4, 4.2, 4.6), CFrame.new(truck + Vector3.new(0, 4, -8)), orange, Enum.Material.Metal)
    make(model, "TruckWindow", "Block", Vector3.new(4.2, 1.6, 0.2), CFrame.new(truck + Vector3.new(0, 5, -10.35)), Color3.fromRGB(40, 60, 80), Enum.Material.Glass, true)
    make(model, "TruckTank", "Cylinder", Vector3.new(14, 4.6, 4.6), CFrame.new(truck + Vector3.new(0, 4.6, 2.5)) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal)
    for _, z in { -8, 1, 6 } do
        for _, side in { -1, 1 } do
            make(model, "TruckWheel", "Cylinder", Vector3.new(1, 2.4, 2.4), CFrame.new(truck + Vector3.new(side * 2.3, 1.2, z)), Color3.fromRGB(26, 26, 28), Enum.Material.Rubber, true)
        end
    end

    local pickup, points = zone(model, "Fuel Depot",
        CFrame.new(at(gantryX, 6, 0)), Vector3.new(gantryWidth + 2, 13, gantryLength + 2), padTop + 2.5)
    banner(model.GantryRoof, Vector3.new(0, 8, 0), "FUEL DEPOT", "Fill up on FUEL here", amber)
    model.Parent = parent
    return { model = model, zone = pickup, points = points }
end

function Stations.build(parent)
    return { Metal = buildSalvageYard(parent), Fuel = buildFuelDepot(parent) }
end

return Stations
