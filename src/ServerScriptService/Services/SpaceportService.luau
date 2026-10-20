--[[
    The spaceport round the launch site, from Kenney's space, modular space and space
    station kits (SiteModels, via SiteProps.place). Two areas:
    - Apron (inside the fence, behind the pad, z < -445): a walk-in Mission Control base
      on the centre line under the leaning rocket, landing pads with parked craft to the
      east, hangars and a monorail to the west. Every tier's tilted rocket clears this
      ground by 230+ studs, so nothing here stands taller than Spaceport.ApronCap.
    - Beyond (outside the widest the site ever grows): a campus past the back fence (a
      display rocket, hangars, a dish array and a tank farm, with the monorail running
      out to it), a comms array to the west and assembly hangars to the east, each on its
      own concrete slab. Spaceport.Clear lists those slabs so the trees keep off them.

    Spaceport.Props: { model, x, z, yaw (degrees), studs per kit metre, solid, y? }.
]]
local Props = require(script.Parent.SiteProps)
local Spaceport = {}

-- Tallest anything on the apron behind the pad may stand (the rockets clear 230+).
Spaceport.ApronCap = 150
-- Apron props stay behind this line (the pad and its floodlights end at z = -440).
Spaceport.ApronFront = -445

-- Concrete slabs outside the site: x0, x1, z0, z1. Their tops sit at Spaceport.SlabTop,
-- clear of the plain (y = -0.35) so the two never flicker.
Spaceport.SlabTop = 0.6
Spaceport.Slabs = {
    Campus = { -430, 430, -1490, -1085 },
    CommsArray = { -900, -690, -720, -180 },
    Assembly = { 690, 900, -720, -180 },
}
Spaceport.Clear = Spaceport.Slabs

local list = {}
local function add(name, x, z, yaw, scale, solid, y)
    table.insert(list, { name, x, z, yaw, scale, solid, y })
end

-- Mission Control: modular rooms at 4 studs per metre (walls 17 high), doors centred on
-- every side, so rooms meet door to door along the centre line and its wings.
local M = 4
add("Modular_gate-lasers", 0, -462, 0, M, true)
add("Modular_room-large", 0, -505, 0, M, true)           -- z -545 .. -465
add("Modular_room-small", -64, -505, 0, M, true)
add("Modular_room-small", 64, -505, 0, M, true)
add("Modular_corridor", 0, -553, 0, M, true)              -- -561 .. -545
add("Modular_room-wide", 0, -585, 0, M, true)             -- -609 .. -561
add("Modular_corridor", 0, -617, 0, M, true)              -- -625 .. -609
add("Modular_room-large-variation", 0, -665, 0, M, true)  -- -705 .. -625
add("Modular_room-wide", -64, -665, 90, M, true)
add("Modular_room-wide", 64, -665, 90, M, true)
add("Modular_corridor", 0, -713, 0, M, true)              -- -721 .. -705
add("Modular_room-small-variation", 0, -745, 0, M, true)  -- -769 .. -721
-- Kit inside: consoles, crates and cabling.
for _, spot in { { -20, -490 }, { 20, -490 }, { -20, -680 }, { 20, -650 } } do
    add("Station_display-wall", spot[1], spot[2], 0, 20, true)
end
add("Modular_cables", 0, -520, 0, M, false)
add("Space_machine_wireless", -64, -505, 30, 14, true)
add("Space_machine_generator", 64, -505, -20, 14, true)
add("Station_container-flat", -70, -660, 0, 20, true)
add("Station_container-flat-open", 70, -670, 0, 20, true)
add("Space_satelliteDish", 0, -745, 180, 18, false)

-- East: landing pads down the apron's edge, a craft on each, service kit between them.
local pads = { { -500, "Space_craft_speederA", 200 }, { -585, "Space_craft_racer", 160 }, { -670, "Space_craft_miner", 215 },
    { -755, "Space_craft_speederD", 190 }, { -840, "Space_craft_cargoB", 180 } }
for _, pad in pads do
    add("Space_platform_large", 190, pad[1], 0, 30, true)
    add(pad[2], 190, pad[1], pad[3], 15, true, 3)
end
for _, z in { -542, -627, -712, -797 } do
    add("Space_machine_barrel", 236, z, 0, 8, true)
    add("Station_container-flat", 140, z, 90, 20, true)
end
add("Space_machine_generatorLarge", 140, -880, 90, 9, true)
add("Space_pipe_supportLow", 236, -880, 0, 10, true)

-- West: hangars down the apron's edge (doors toward the centre line).
add("Space_hangar_roundB", -165, -520, 90, 20, true)
add("Space_hangar_smallA", -160, -620, 90, 20, true)
add("Space_hangar_smallB", -160, -690, 90, 20, true)
add("Space_hangar_roundA", -165, -790, 90, 20, true)
add("Space_rover", -120, -560, 60, 6, true)
add("Space_rover", -116, -650, 100, 6, true)
add("Space_craft_cargoA", -150, -890, 180, 15, true)

-- Far end of the apron: a gantry of frames and spare stages waiting their turn.
for _, x in { -60, -20, 20, 60 } do
    add("Space_structure", x, -960, 0, 40, true)
    add("Space_structure_diagonal", x, -960, 0, 40, true, 40)
end
add("Space_rocket_baseB", -120, -955, 0, 18, true)
add("Space_rocket_fuelB", -120, -955, 0, 18, true, 23.4)
add("Space_rocket_topB", -120, -955, 0, 18, true, 41.4)
add("Space_rocket_baseA", 120, -955, 0, 18, true)
add("Space_rocket_finsA", 120, -955, 45, 18, false)
add("Space_rocket_fuelA", 120, -955, 0, 18, true, 28.8)
add("Space_rocket_topA", 120, -955, 0, 18, true, 37.8)

-- Monorail: down the west edge at 15 studs up, over the back fence and out to the campus,
-- with a train standing at the campus end. Track pieces are 30 long at scale 30.
local RAIL, RAIL_X, RAIL_Y = 30, -228, 15
for z = -460, -1430, -30 do
    add("Space_monorail_trackStraight", RAIL_X, z - 15, 0, RAIL, false, RAIL_Y)
    if (z + 460) % 90 == 0 then add("Space_monorail_trackSupport", RAIL_X, z - 15, 0, RAIL, false) end
end
local trainZ = -1300
for index, car in { "Space_monorail_trainFront", "Space_monorail_trainPassenger", "Space_monorail_trainPassenger", "Space_monorail_trainCargo", "Space_monorail_trainEnd" } do
    add(car, RAIL_X, trainZ - (index - 1) * 30, 180, RAIL, false, RAIL_Y + 3.9)
end
add("Space_platform_long", RAIL_X + 25, -1360, 90, 15, true, Spaceport.SlabTop)

-- Campus past the back fence.
local top = Spaceport.SlabTop
-- The Rocket Garden: a 270-stud display rocket on a round pad, craft parked round it.
add("Space_platform_large", 0, -1290, 0, 70, true, top)
local stack, y = { { "Space_rocket_baseA", 1.6 }, { "Space_rocket_fuelB", 1.0 }, { "Space_rocket_fuelB", 1.0 }, { "Space_rocket_topA", 0.8 } }, top + 7
for _, piece in stack do
    add(piece[1], 0, -1290, 0, 60, true, y)
    y += piece[2] * 60
end
add("Space_rocket_finsB", 0, -1290, 0, 60, false, top + 7)
add("Space_craft_speederA", -110, -1215, 150, 15, true, top)
add("Space_craft_racer", 105, -1210, 210, 15, true, top)
add("Space_astronautA", -40, -1200, 0, 14, true, top)
add("Space_astronautB", 40, -1200, 0, 14, true, top)
-- Hangar row facing the fence, joined by corridor tubes.
for _, h in { { -300, "Space_hangar_largeA" }, { -170, "Space_hangar_largeB" }, { 170, "Space_hangar_largeB" }, { 300, "Space_hangar_largeA" } } do
    add(h[2], h[1], -1160, 180, 30, true, top)
end
for _, x in { -261.25, -243.75, -226.25, -208.75, 208.75, 226.25, 243.75, 261.25 } do
    add("Space_corridor_window", x, -1160, 90, 17.5, true, top)
end
-- Dish array (south-west) and tank farm (south-east).
for index, z in { -1290, -1370, -1450 } do
    add("Space_satelliteDish_large", -385, z, 140 + index * 12, 80, false, top)
end
for _, d in { { -280, -1280 }, { -280, -1370 }, { -190, -1440 } } do
    add("Space_satelliteDish_detailed", d[1], d[2], 160, 60, false, top)
end
for _, t in { { 280, -1280 }, { 340, -1280 }, { 310, -1340 }, { 370, -1340 }, { 280, -1400 } } do
    add("Space_machine_barrelLarge", t[1], t[2], 0, 60, true, top)
end
add("Space_chimney_detailed", 200, -1430, 0, 30, true, top)
add("Space_machine_generatorLarge", 200, -1360, 90, 20, true, top)

-- Comms array to the west: a line of big dishes with their transmitter huts.
for index, z in { -260, -380, -500, -620 } do
    add("Space_satelliteDish_large", -800, z, 90 + index * 8, 90, false, top)
    add("Space_machine_wirelessCable", -735, z, 90, 14, true, top)
end
add("Space_hangar_smallB", -840, -690, 90, 22, true, top)
-- Assembly hangars to the east, with a stage on a transporter at each door.
for index, z in { -270, -450, -630 } do
    add(index == 2 and "Space_hangar_roundGlass" or "Space_hangar_roundB", 810, z, -90, 40, true, top)
    add("Space_platform_low", 725, z, 0, 40, true, top)
    add("Space_rocket_sidesB", 725, z, 0, 30, true, top + 20)
end

Spaceport.Props = list

local CONCRETE = Color3.fromRGB(118, 120, 124)
local LINE = Color3.fromRGB(240, 196, 40)

local function slab(parent, name, rect)
    local x0, x1, z0, z1 = table.unpack(rect)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = Vector3.new(x1 - x0, 1, z1 - z0)
    part.CFrame = CFrame.new((x0 + x1) / 2, Spaceport.SlabTop - 0.5, (z0 + z1) / 2)
    part.Color, part.Material = CONCRETE, Enum.Material.Concrete
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.CanTouch = false
    part.Parent = parent
    require(script.Parent.MapExpansionService).concrete(part, 30)
    -- A painted border so each slab reads as a laid-out yard, not a grey sheet.
    local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0 - 6, z1 - z0 - 6
    for _, edge in { { cx, z0 + 3, w, 1.2 }, { cx, z1 - 3, w, 1.2 }, { x0 + 3, cz, 1.2, d }, { x1 - 3, cz, 1.2, d } } do
        local line = Instance.new("Part")
        line.Name = name .. "Line"
        line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch = true, false, false, false
        line.Size = Vector3.new(edge[3], 0.1, edge[4])
        line.Position = Vector3.new(edge[1], Spaceport.SlabTop + 0.05, edge[2])
        line.Color, line.Material = LINE, Enum.Material.SmoothPlastic
        line.Parent = parent
    end
end

function Spaceport.build(world)
    local model = Instance.new("Model")
    model.Name = "Spaceport"
    for name, rect in Spaceport.Slabs do
        slab(model, name .. "Slab", rect)
    end
    local props = Instance.new("Model")
    props.Name = "SpaceportProps"
    props.Parent = model
    for index, spot in list do
        local name, x, z, yaw, scale, solid, y = table.unpack(spot)
        Props.place(props, name, CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0), scale, solid)
        if index % 40 == 0 then task.wait() end
    end
    model.Parent = world
    return model
end

return Spaceport
