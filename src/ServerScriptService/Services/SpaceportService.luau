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
local Signs = require(script.Parent.SignService)
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
-- every side, so rooms meet door to door along the centre line and its wings. Their
-- hulls follow the walls (SiteModels stores Modular_* with precise collision), so
-- players walk in through the gate.
local M = 4
add("Modular_gate", 0, -462, 0, M, true)
add("Modular_room-large", 0, -505, 0, M, true)           -- z -545 .. -465
add("Modular_room-small", -64, -505, 0, M, true)
add("Modular_room-small", 64, -505, 0, M, true)
add("Modular_corridor", 0, -553, 90, M, true)              -- -561 .. -545
add("Modular_room-wide", 0, -585, 0, M, true)             -- -609 .. -561
add("Modular_corridor", 0, -617, 90, M, true)              -- -625 .. -609
add("Modular_room-large-variation", 0, -665, 0, M, true)  -- -705 .. -625
add("Modular_room-wide", -64, -665, 90, M, true)
add("Modular_room-wide", 64, -665, 90, M, true)
add("Modular_corridor", 0, -713, 90, M, true)              -- -721 .. -705
add("Modular_room-small-variation", 0, -745, 0, M, true)  -- -769 .. -721
-- Kit inside (furnish() adds the desks, screens, holo table and bunks).
add("Modular_cables", -24, -585, 0, M, false)
add("Station_display-wall", -30, -775, 0, 20, true)
add("Station_display-wall", 30, -775, 0, 20, true)
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
Spaceport.TrackEnd = -460 -- the track's apron end
for z = Spaceport.TrackEnd, -1430, -30 do
    add("Space_monorail_trackStraight", RAIL_X, z - 15, 0, RAIL, false, RAIL_Y)
    if (z - Spaceport.TrackEnd) % 90 == 0 then add("Space_monorail_trackSupport", RAIL_X, z - 15, 0, RAIL, false) end
end
-- The train (its own model, MonorailTrain; SpaceportController runs it up to the apron
-- and back): nose toward +Z, cars trailing behind, resting at the campus station.
Spaceport.Train = {}
Spaceport.TrainTravel = 810 -- from the campus station to the apron end of the track
for index, car in { "Space_monorail_trainFront", "Space_monorail_trainPassenger", "Space_monorail_trainPassenger", "Space_monorail_trainCargo", "Space_monorail_trainEnd" } do
    table.insert(Spaceport.Train, { car, RAIL_X, -1300 - (index - 1) * 30, 0, RAIL, false, RAIL_Y + 3.9 })
end
for z = -1300, -1420, -30 do
    add("Space_platform_long", RAIL_X + 18, z, 90, 15, true, Spaceport.SlabTop)
end

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

-- Furniture and screens from parts (the kits' furniture isn't imported): Mission Control's
-- consoles and holo table, the launch room's desks and wall screens, crew bunks and mess.
local DESK, DESK_TOP = Color3.fromRGB(70, 74, 92), Color3.fromRGB(200, 204, 216)
local GLOW, ORANGE = Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 150, 40)

local function block(parent, name, size, cframe, color, material, shape)
    local part = Instance.new("Part")
    part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
    part.Material = material or Enum.Material.SmoothPlastic
    if shape then part.Shape = shape end
    part.Anchored = true
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.CanCollide, part.CanQuery, part.CanTouch = true, true, false
    part.Parent = parent
    return part
end

-- A console desk looking along `cf`'s look direction, its chair behind it.
local function desk(parent, cf)
    block(parent, "DeskBody", Vector3.new(7, 3, 3), cf * CFrame.new(0, 1.5, 0), DESK, Enum.Material.Metal)
    block(parent, "DeskTop", Vector3.new(7.6, 0.4, 3.6), cf * CFrame.new(0, 3.2, 0.2), DESK_TOP)
    local tilt = cf * CFrame.new(0, 5.2, -0.9) * CFrame.Angles(math.rad(-10), 0, 0)
    block(parent, "Monitor", Vector3.new(6, 3.4, 0.3), tilt, Color3.fromRGB(24, 26, 34))
    local glow = block(parent, "Screen", Vector3.new(5.4, 2.8, 0.05), tilt * CFrame.new(0, 0, 0.18), GLOW, Enum.Material.Neon)
    glow.Transparency, glow.CanCollide, glow.CanQuery = 0.15, false, false
    block(parent, "ChairStem", Vector3.new(0.5, 1.8, 0.5), cf * CFrame.new(0, 0.9, 3.6), DESK, Enum.Material.Metal)
    block(parent, "ChairSeat", Vector3.new(2.4, 0.5, 2.4), cf * CFrame.new(0, 2, 3.6), ORANGE)
    block(parent, "ChairBack", Vector3.new(2.4, 2.6, 0.4), cf * CFrame.new(0, 3.5, 4.7), ORANGE)
end

-- A wall screen facing along `cf`'s look direction, with a status readout:
-- lines = { { label, bar colour, bar fill 0..1 }, ... }.
local function wallScreen(parent, cf, size, title, lines)
    block(parent, "WallScreenFrame", Vector3.new(size.X + 0.8, size.Y + 0.8, 0.5), cf, Color3.fromRGB(24, 26, 34), Enum.Material.Metal)
    local face = block(parent, "WallScreen", Vector3.new(size.X, size.Y, 0.1), cf * CFrame.new(0, 0, -0.3), Color3.fromRGB(10, 26, 44))
    face.CanCollide, face.CanQuery = false, false
    local gui = Instance.new("SurfaceGui")
    gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 24, 0
    gui.Parent = face
    local heading = Instance.new("TextLabel")
    heading.BackgroundTransparency, heading.Size, heading.Position = 1, UDim2.fromScale(0.92, 0.3), UDim2.fromScale(0.04, 0.06)
    heading.Font, heading.TextScaled, heading.TextColor3, heading.Text = Enum.Font.GothamBlack, true, GLOW, title
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.Parent = gui
    for index, line in lines do
        local bar = Instance.new("Frame")
        bar.BorderSizePixel, bar.BackgroundColor3 = 0, line[2]
        bar.Position, bar.Size = UDim2.fromScale(0.04, 0.42 + (index - 1) * 0.17), UDim2.fromScale(0.5 * line[3], 0.1)
        bar.Parent = gui
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency, label.Position, label.Size = 1, UDim2.fromScale(0.58, 0.39 + (index - 1) * 0.17), UDim2.fromScale(0.38, 0.16)
        label.Font, label.TextScaled, label.TextColor3, label.Text = Enum.Font.GothamBold, true, Color3.new(1, 1, 1), line[1]
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = gui
    end
end

-- Cylinders lie along X; turned 90 degrees about Z they stand up.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function holoTable(parent, at)
    block(parent, "HoloBase", Vector3.new(3, 18, 18), CFrame.new(at + Vector3.new(0, 1.5, 0)) * UPRIGHT, DESK, Enum.Material.Metal, Enum.PartType.Cylinder)
    -- The rim sits inside the base, so only a thin glowing edge shows round its top.
    local rim = block(parent, "HoloRim", Vector3.new(0.4, 18.8, 18.8), CFrame.new(at + Vector3.new(0, 2.7, 0)) * UPRIGHT, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
    rim.CanCollide = false
    local emitter = block(parent, "HoloEmitter", Vector3.new(0.3, 4, 4), CFrame.new(at + Vector3.new(0, 3.1, 0)) * UPRIGHT, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
    emitter.CanCollide = false
    local planet = block(parent, "HoloPlanet", Vector3.one * 6, CFrame.new(at + Vector3.new(0, 10, 0)), Color3.fromRGB(70, 150, 255), Enum.Material.Glass, Enum.PartType.Ball)
    planet.Transparency, planet.CanCollide = 0.3, false
    local orbit = block(parent, "HoloOrbit", Vector3.new(0.15, 11, 11), CFrame.new(at + Vector3.new(0, 10, 0)) * CFrame.Angles(math.rad(20), 0, 0) * UPRIGHT, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
    orbit.Transparency, orbit.CanCollide = 0.6, false
    local beam = block(parent, "HoloBeam", Vector3.new(6, 3.6, 3.6), CFrame.new(at + Vector3.new(0, 6.2, 0)) * UPRIGHT, GLOW, Enum.Material.ForceField, Enum.PartType.Cylinder)
    beam.CanCollide = false
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = GLOW, 20, 1.2
    light.Parent = planet
end

local function bunk(parent, cf)
    for _, y in { 1.6, 6 } do
        block(parent, "BunkFrame", Vector3.new(9, 0.6, 4), cf * CFrame.new(0, y, 0), DESK, Enum.Material.Metal)
        block(parent, "Mattress", Vector3.new(8.4, 0.8, 3.4), cf * CFrame.new(0, y + 0.7, 0), Color3.fromRGB(120, 140, 210))
        block(parent, "Pillow", Vector3.new(1.6, 0.5, 2.6), cf * CFrame.new(-3.2, y + 1.3, 0), Color3.fromRGB(235, 235, 245))
    end
    for _, x in { -4.3, 4.3 } do
        for _, z in { -1.8, 1.8 } do
            block(parent, "BunkPost", Vector3.new(0.4, 8, 0.4), cf * CFrame.new(x, 4, z), DESK, Enum.Material.Metal)
        end
    end
end

local function furnish(parent)
    local model = Instance.new("Model")
    model.Name = "MissionControlInterior"
    model.Parent = parent
    -- Operations room (0, -505): the holo table, four consoles round it.
    local ops = Vector3.new(0, 0, -505)
    holoTable(model, ops)
    for _, angle in { 45, 135, 225, 315 } do
        local at = ops + Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle))) * 22
        desk(model, CFrame.lookAt(at, ops))
    end
    -- Wings: a console each, looking out of the front.
    for _, x in { -64, 64 } do
        desk(model, CFrame.lookAt(Vector3.new(x, 0, -490), Vector3.new(x, 0, -470)))
    end
    -- Launch control (0, -585): two rows of desks facing the rocket, screens on its wall
    -- (between the wall's pillars at |x| = 16 and 33).
    for _, z in { -578, -596 } do
        for _, x in { -30, -18, 18, 30 } do
            desk(model, CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z + 10)))
        end
    end
    wallScreen(model, CFrame.lookAt(Vector3.new(-24.5, 8, -563.5), Vector3.new(-24.5, 8, -600)), Vector2.new(12.5, 7), "LAUNCH STATUS",
        { { "FUEL", Color3.fromRGB(255, 182, 71), 0.8 }, { "HULL", Color3.fromRGB(139, 200, 255), 0.65 }, { "WEATHER: GO", Color3.fromRGB(90, 230, 120), 1 } })
    wallScreen(model, CFrame.lookAt(Vector3.new(24.5, 8, -563.5), Vector3.new(24.5, 8, -600)), Vector2.new(12.5, 7), "TRAJECTORY",
        { { "MOON", Color3.fromRGB(220, 220, 230), 1 }, { "MARS", Color3.fromRGB(255, 120, 80), 0.6 }, { "SATURN", Color3.fromRGB(240, 210, 140), 0.3 } })
    -- Crew quarters (0, -665): bunks down the east side, lockers, the mess table (off the
    -- line between the wing doors).
    for _, z in { -645, -657, -669, -681 } do
        bunk(model, CFrame.new(28, 0, z))
    end
    block(model, "MessTable", Vector3.new(16, 0.5, 5), CFrame.new(-8, 3, -650), DESK_TOP)
    for _, x in { -15, -1 } do
        block(model, "MessLeg", Vector3.new(0.6, 2.8, 4), CFrame.new(x, 1.4, -650), DESK, Enum.Material.Metal)
    end
    for _, z in { -653.5, -646.5 } do
        block(model, "MessBench", Vector3.new(16, 0.5, 1.6), CFrame.new(-8, 1.9, z), ORANGE)
    end
    for index = 0, 5 do
        block(model, "Locker", Vector3.new(2.6, 7.5, 2), CFrame.new(-30 + index * 2.8, 3.75, -640),
            index % 2 == 0 and DESK or Color3.fromRGB(90, 96, 118), Enum.Material.Metal)
    end
end

-- A painted number on a landing pad, read from the site end.
local function padNumber(parent, at, number)
    local part = block(parent, "PadNumber", Vector3.new(14, 0.05, 14), CFrame.new(at), Color3.new(1, 1, 1))
    part.Transparency, part.CanCollide, part.CanQuery = 1, false, false
    local gui = Instance.new("SurfaceGui")
    gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Top, Enum.SurfaceGuiSizingMode.PixelsPerStud, 6
    gui.Parent = part
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
    label.Font, label.TextSize, label.TextColor3, label.Text = Enum.Font.GothamBlack, 80, ORANGE, tostring(number)
    label.Rotation = 90 -- the Top face's canvas runs along X; upright to anyone coming from the site
    label.Parent = gui
end

-- Signs naming each part of the spaceport, facing whoever comes from the site.
local function signs(parent)
    local model = Instance.new("Model")
    model.Name = "SpaceportSigns"
    model.Parent = parent
    local cyan = GLOW
    local function board(name, at, look, size, props, ground)
        props.ground = ground or 0
        Signs.board(model, name, CFrame.lookAt(at, at + look), size, props)
    end
    local toSite, top = Vector3.zAxis, Spaceport.SlabTop
    board("MissionControlSign", Vector3.new(0, 25, -456), toSite, Vector2.new(36, 7), { title = "MISSION CONTROL", subtitle = "LAUNCH OPERATIONS", icon = "🛰️", accent = cyan })
    board("LandingPadsSign", Vector3.new(190, 9, -458), toSite, Vector2.new(26, 5), { title = "LANDING PADS", subtitle = "VISITING CRAFT", icon = "🛸", accent = ORANGE })
    board("HangarsSign", Vector3.new(-160, 9, -468), toSite, Vector2.new(24, 5), { title = "HANGARS", subtitle = "SERVICE & REPAIR", icon = "🔧", accent = ORANGE })
    board("MonorailSign", Vector3.new(-210, 8, -458), toSite, Vector2.new(16, 4), { title = "MONORAIL", subtitle = "TO THE CAMPUS", icon = "🚝", accent = cyan })
    board("CampusSign", Vector3.new(0, 30, -1095), toSite, Vector2.new(70, 12), { title = "SPACEPORT CAMPUS", subtitle = "ROCKET GARDEN • HANGARS • TANK FARM", icon = "🚀", accent = ORANGE }, top)
    board("CampusStationSign", Vector3.new(-190, 8, -1272), toSite, Vector2.new(16, 4), { title = "CAMPUS STATION", subtitle = "MONORAIL", icon = "🚝", accent = cyan }, top)
    board("CommsArraySign", Vector3.new(-705, 14, -440), Vector3.xAxis, Vector2.new(30, 6), { title = "COMMS ARRAY", subtitle = "DEEP SPACE NETWORK", icon = "📡", accent = cyan }, top)
    board("AssemblySign", Vector3.new(705, 14, -540), -Vector3.xAxis, Vector2.new(30, 6), { title = "ASSEMBLY", subtitle = "STAGE INTEGRATION", icon = "🏗️", accent = ORANGE }, top)
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
    local train = Instance.new("Model")
    train.Name = "MonorailTrain"
    train:SetAttribute("Travel", Spaceport.TrainTravel)
    train.Parent = model
    for _, spot in Spaceport.Train do
        local name, x, z, yaw, scale, solid, y = table.unpack(spot)
        Props.place(train, name, CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0), scale, solid)
    end
    furnish(model)
    for index, pad in pads do
        padNumber(model, Vector3.new(190, 3.1, pad[1] + 21), index)
    end
    signs(model)
    model.Parent = world
    return model
end

return Spaceport
