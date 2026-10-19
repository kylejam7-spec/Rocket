--[[
    Dresses the Earth launch site as a spaceport under construction ("ground zero"):
    concrete roads, two tower cranes swung over the pad, floodlight towers on the apron,
    shipping-container stacks, girder stockpiles, portacabin site offices, the steel
    skeletons of Mission Control and a hangar going up in scaffolding, cones and
    barriers, and a SPACEPORT EARTH arch over the lane. Positions come from SiteLayout;
    nothing here is gameplay, so only what players could walk into collides, and every
    prop stays off the lane, the stations, the forecourt huts and the walk from the
    stations to the ramps. Primitives for now; Kenney meshes can replace pieces later
    (tools/map).
]]
local Layout = require(script.Parent.SiteLayout)
local Props = require(script.Parent.SiteProps)
local Dressing = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local YELLOW = Color3.fromRGB(240, 180, 30)
local STEEL = Color3.fromRGB(150, 156, 166)
local DARK = Color3.fromRGB(46, 50, 56)
local CONCRETE = Color3.fromRGB(165, 165, 160)

local function make(parent, name, size, cframe, color, material, solid, shape)
    local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
    if shape and shape ~= "Wedge" then part.Shape = Enum.PartType[shape] end
    part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    if not solid then part.CanCollide, part.CanQuery, part.CanTouch = false, false, false end
    part.Parent = parent
    return part
end
local function beam(parent, name, a, b, thickness, color, material, solid)
    return make(parent, name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, solid)
end
local function folder(parent, name)
    local item = Instance.new("Model")
    item.Name = name
    item.Parent = parent
    return item
end
local function signText(part, face, text, color)
    local surface = Instance.new("SurfaceGui")
    surface.Face = face
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 30
    surface.Parent = part
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.Parent = surface
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 4
    stroke.Color = Color3.fromRGB(22, 14, 32)
    stroke.Parent = label
end

-- Roads: the lane from the Gym District to the apron, spurs to each station's gate,
-- and a cross road along the front of the pad. Flat, so they never trip anyone.
local function roads(parent)
    local model = folder(parent, "Roads")
    local asphalt, line = Color3.fromRGB(78, 80, 86), Color3.fromRGB(250, 205, 60)
    local lane = Layout.Lane
    local length = lane.z1 - lane.z0
    make(model, "LaneRoad", Vector3.new(lane.width, 0.2, length), CFrame.new(0, 0.1, (lane.z0 + lane.z1) / 2), asphalt, Enum.Material.Asphalt)
    for z = lane.z0 + 6, lane.z1 - 6, 12 do
        make(model, "LaneDash", Vector3.new(0.6, 0.05, 6), CFrame.new(0, 0.22, z), line, Enum.Material.SmoothPlastic)
    end
    for _, side in { -1, 1 } do
        make(model, "LaneEdge", Vector3.new(0.5, 0.05, length), CFrame.new(side * (lane.width / 2 - 0.8), 0.22, (lane.z0 + lane.z1) / 2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
        local station = side < 0 and Layout.Metal or Layout.Fuel
        local gate = station.X - side * Layout.StationFootprint.X / 2
        local spur = math.abs(gate) - lane.width / 2
        make(model, "StationRoad", Vector3.new(spur, 0.18, 16), CFrame.new(side * (lane.width / 2 + spur / 2), 0.09, station.Z), asphalt, Enum.Material.Asphalt)
    end
    local front = Layout.Apron.z1 + 14
    make(model, "PadRoad", Vector3.new(Layout.Apron.x * 2, 0.18, 18), CFrame.new(0, 0.09, front), asphalt, Enum.Material.Asphalt)
end

-- A lattice tower crane: mast, slewing cab, jib with trolley and hook, counter-jib
-- with weights, an apex tied to both ends, and a red aviation light on top.
local function towerCrane(parent, base, height, jib, yaw)
    local model = folder(parent, "TowerCrane")
    local frame = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
    local w = 2.2
    make(model, "CraneFooting", Vector3.new(10, 2, 10), frame * CFrame.new(0, 1, 0), CONCRETE, Enum.Material.Concrete, true)
    for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
        beam(model, "MastLeg", (frame * CFrame.new(c[1] * w, 2, c[2] * w)).Position, (frame * CFrame.new(c[1] * w, height, c[2] * w)).Position, 0.6, YELLOW, Enum.Material.Metal, true)
    end
    local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
    for y = 2, height - 6, 7 do
        for index, c in corners do
            local n = corners[index % 4 + 1]
            beam(model, "MastBrace", (frame * CFrame.new(c[1] * w, y, c[2] * w)).Position, (frame * CFrame.new(n[1] * w, y + 7, n[2] * w)).Position, 0.3, YELLOW, Enum.Material.Metal)
        end
    end
    local top = height
    make(model, "SlewingUnit", Vector3.new(6, 3, 6), frame * CFrame.new(0, top + 1.5, 0), DARK, Enum.Material.Metal)
    make(model, "CraneCab", Vector3.new(3.6, 3.4, 4), frame * CFrame.new(3.6, top + 1.8, -1.5), YELLOW, Enum.Material.Metal)
    make(model, "CabWindow", Vector3.new(0.2, 2, 3.4), frame * CFrame.new(5.45, top + 2.2, -1.5), Color3.fromRGB(60, 90, 120), Enum.Material.Glass)
    -- Jib toward -Z of the crane's frame, counter-jib behind.
    local function point(x, y, z) return (frame * CFrame.new(x, y, z)).Position end
    for _, x in { -1.2, 1.2 } do
        beam(model, "JibChord", point(x, top + 3, 0), point(x, top + 3, -jib), 0.4, YELLOW, Enum.Material.Metal)
        beam(model, "CounterChord", point(x, top + 3, 0), point(x, top + 3, jib * 0.32), 0.4, YELLOW, Enum.Material.Metal)
    end
    beam(model, "JibTopChord", point(0, top + 5.2, 0), point(0, top + 5.2, -jib), 0.35, YELLOW, Enum.Material.Metal)
    for z = 0, jib - 5, 5 do
        for _, x in { -1.2, 1.2 } do
            beam(model, "JibBrace", point(x, top + 3, -z), point(0, top + 5.2, -z - 2.5), 0.22, YELLOW, Enum.Material.Metal)
        end
    end
    for index = 0, 2 do
        make(model, "Counterweight", Vector3.new(4, 3, 1.8), frame * CFrame.new(0, top + 1.5, jib * 0.32 - 1 - index * 2), CONCRETE, Enum.Material.Concrete)
    end
    local apex = point(0, top + 14, 0)
    beam(model, "ApexLeg", point(-1.2, top + 3, 0), apex, 0.5, YELLOW, Enum.Material.Metal)
    beam(model, "ApexLeg", point(1.2, top + 3, 0), apex, 0.5, YELLOW, Enum.Material.Metal)
    beam(model, "JibTie", apex, point(0, top + 5.2, -jib * 0.7), 0.15, DARK, Enum.Material.Metal)
    beam(model, "CounterTie", apex, point(0, top + 3, jib * 0.32), 0.15, DARK, Enum.Material.Metal)
    local beacon = make(model, "AviationLight", Vector3.one * 0.9, CFrame.new(apex + Vector3.new(0, 0.7, 0)), Color3.fromRGB(255, 50, 40), Enum.Material.Neon, false, "Ball")
    local glow = Instance.new("PointLight")
    glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 60, 40), 14, 2
    glow.Parent = beacon
    -- Trolley partway out with a hook block on its cable.
    local trolley = point(0, top + 2.6, -jib * 0.62)
    make(model, "Trolley", Vector3.new(3, 1, 2.4), CFrame.new(trolley) * frame.Rotation, DARK, Enum.Material.Metal)
    local hook = trolley - Vector3.new(0, height * 0.45, 0)
    beam(model, "HookCable", trolley, hook, 0.12, Color3.fromRGB(25, 25, 25), Enum.Material.Metal)
    make(model, "HookBlock", Vector3.new(1.6, 2.2, 1), CFrame.new(hook) * frame.Rotation, YELLOW, Enum.Material.Metal)
    -- A steel beam slung from the hook.
    make(model, "SlungGirder", Vector3.new(1.2, 1.2, 16), CFrame.new(hook - Vector3.new(0, 4, 0)) * CFrame.Angles(0, yaw + 0.6, 0), Color3.fromRGB(180, 70, 50), Enum.Material.Metal)
end

-- A floodlight mast with a bank of lamps aimed at `target`.
local function floodlight(parent, base, target)
    local model = folder(parent, "Floodlight")
    local height = 42
    make(model, "FloodFooting", Vector3.new(4, 1.5, 4), CFrame.new(base + Vector3.new(0, 0.75, 0)), CONCRETE, Enum.Material.Concrete, true)
    make(model, "FloodMast", Vector3.new(height, 1.4, 1.4), CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT, STEEL, Enum.Material.Metal, true, "Cylinder")
    local head = CFrame.lookAt(base + Vector3.new(0, height + 1.5, 0), Vector3.new(target.X, 0, target.Z))
    make(model, "FloodFrame", Vector3.new(7, 4, 0.8), head, DARK, Enum.Material.Metal)
    for _, x in { -2.3, 0, 2.3 } do
        for _, y in { -1, 1 } do
            make(model, "FloodLamp", Vector3.new(1.8, 1.6, 0.3), head * CFrame.new(x, y, -0.5), Color3.fromRGB(255, 248, 220), Enum.Material.Neon)
        end
    end
    local light = Instance.new("SpotLight")
    light.Face, light.Angle, light.Range, light.Brightness = Enum.NormalId.Front, 60, 60, 2
    light.Color = Color3.fromRGB(255, 244, 220)
    light.Parent = model.FloodFrame
end

-- A shipping container (solid), its doors at one end and ribs down the sides.
local function container(parent, cframe, color)
    local box = make(parent, "Container", Vector3.new(8, 8.6, 20), cframe, color, Enum.Material.CorrodedMetal, true)
    local trim = color:Lerp(Color3.new(0, 0, 0), 0.3)
    make(parent, "ContainerDoors", Vector3.new(7.6, 8.2, 0.2), cframe * CFrame.new(0, 0, 10.05), trim, Enum.Material.Metal)
    for z = -8, 8, 4 do
        for _, side in { -1, 1 } do
            make(parent, "ContainerRib", Vector3.new(0.15, 8.2, 0.6), cframe * CFrame.new(side * 4.05, 0, z), trim, Enum.Material.Metal)
        end
    end
    return box
end
local CONTAINER_COLORS = { Color3.fromRGB(196, 72, 48), Color3.fromRGB(46, 104, 160), Color3.fromRGB(60, 130, 80), Color3.fromRGB(214, 160, 40), Color3.fromRGB(140, 146, 154) }
local function containerStack(parent, base, yaw, layout, seed)
    local model = folder(parent, "ContainerStack")
    local random = Random.new(seed)
    for _, slot in layout do
        local cframe = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.new(slot[1] * 8.4, 4.3 + slot[2] * 8.7, 0) * CFrame.Angles(0, random:NextNumber(-0.03, 0.03), 0)
        container(model, cframe, CONTAINER_COLORS[random:NextInteger(1, #CONTAINER_COLORS)])
    end
end

-- A pile of steel I-beams on timber bearers.
local function girderStack(parent, base, yaw)
    local model = folder(parent, "GirderStack")
    local frame = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
    local red = Color3.fromRGB(176, 64, 44)
    for _, z in { -7, 0, 7 } do
        make(model, "Bearer", Vector3.new(9, 0.6, 0.8), frame * CFrame.new(0, 0.3, z), Color3.fromRGB(140, 104, 66), Enum.Material.WoodPlanks, true)
    end
    for layer = 0, 2 do
        for index = -2 + layer % 2, 2 - layer % 2 do
            local at = frame * CFrame.new(index * 1.7, 1.1 + layer * 1.25, 0)
            make(model, "GirderWeb", Vector3.new(0.25, 1.1, 18), at, red, Enum.Material.Metal, true)
            make(model, "GirderFlange", Vector3.new(1.2, 0.15, 18), at * CFrame.new(0, 0.55, 0), red, Enum.Material.Metal)
            make(model, "GirderFlange", Vector3.new(1.2, 0.15, 18), at * CFrame.new(0, -0.55, 0), red, Enum.Material.Metal)
        end
    end
end

-- Stacked portacabin site offices with an outside stair, facing `facing`.
local function siteOffices(parent, base, facing)
    local model = folder(parent, "SiteOffices")
    local frame = CFrame.lookAt(base, base + facing)
    local walls, roof, window = Color3.fromRGB(226, 228, 230), Color3.fromRGB(120, 126, 134), Color3.fromRGB(110, 170, 210)
    for floor = 0, 1 do
        for _, x in { -6.5, 6.5 } do
            if floor == 0 or x < 0 then
                local cabin = frame * CFrame.new(x, 1.6 + floor * 3.4 + 1.5, 0)
                make(model, "Portacabin", Vector3.new(12.6, 3.2, 6), cabin, walls, Enum.Material.SmoothPlastic, true)
                make(model, "CabinRoof", Vector3.new(12.8, 0.3, 6.2), cabin * CFrame.new(0, 1.75, 0), roof, Enum.Material.Metal)
                for _, wx in { -3.5, 0, 3.5 } do
                    make(model, "CabinWindow", Vector3.new(2.2, 1.2, 0.1), cabin * CFrame.new(wx, 0.3, -3.05), window, Enum.Material.Glass)
                end
            end
        end
    end
    make(model, "CabinBlocks", Vector3.new(26, 1.6, 6.4), frame * CFrame.new(0, 0.8, 0), CONCRETE, Enum.Material.Concrete, true)
    make(model, "Stair", Vector3.new(2.6, 4.9, 8), frame * CFrame.new(7.5, 2.45 + 1.6, -6.6) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.DiamondPlate, true, "Wedge")
    local board = make(model, "OfficeSign", Vector3.new(10, 1.6, 0.2), frame * CFrame.new(-6.5, 9.3, -3.1), Color3.fromRGB(30, 60, 120), Enum.Material.SmoothPlastic)
    signText(board, Enum.NormalId.Front, "SITE OFFICE")
end

-- A building going up: a steel frame (columns, beams per floor), a part-poured slab,
-- scaffolding with planks on one face, and a hoarding board naming it.
local function skeleton(parent, base, facing, width, depth, floors, name)
    local model = folder(parent, "Skeleton")
    local frame = CFrame.lookAt(base, base + facing)
    local red, scaffold = Color3.fromRGB(176, 64, 44), Color3.fromRGB(190, 196, 204)
    local storey = 6
    local top = floors * storey
    make(model, "GroundSlab", Vector3.new(width + 2, 0.8, depth + 2), frame * CFrame.new(0, 0.4, 0), CONCRETE, Enum.Material.Concrete, true)
    for x = -width / 2, width / 2, width / 3 do
        for z = -depth / 2, depth / 2, depth / 2 do
            local h = (math.abs(x) > width / 3 and z > 0) and top - storey or top
            make(model, "Column", Vector3.new(0.9, h, 0.9), frame * CFrame.new(x, h / 2, z), red, Enum.Material.Metal, true)
        end
    end
    for floor = 1, floors do
        local y = floor * storey
        for _, z in { -depth / 2, 0, depth / 2 } do
            make(model, "FloorBeam", Vector3.new(width, 0.7, 0.7), frame * CFrame.new(0, y, z), red, Enum.Material.Metal)
        end
        for x = -width / 2, width / 2, width / 3 do
            make(model, "FloorBeam", Vector3.new(0.7, 0.7, depth), frame * CFrame.new(x, y, 0), red, Enum.Material.Metal)
        end
        if floor <= 2 then
            make(model, "Slab", Vector3.new(width, 0.4, depth), frame * CFrame.new(0, y + 0.55, 0), CONCRETE, Enum.Material.Concrete)
        end
    end
    -- Scaffolding on the front face.
    local front = -depth / 2 - 2
    for x = -width / 2, width / 2, 4 do
        make(model, "ScaffoldPole", Vector3.new(0.25, top + 2, 0.25), frame * CFrame.new(x, (top + 2) / 2, front), scaffold, Enum.Material.Metal)
    end
    for y = 2, top, 3 do
        make(model, "ScaffoldRail", Vector3.new(width, 0.2, 0.2), frame * CFrame.new(0, y, front), scaffold, Enum.Material.Metal)
        if y % 6 == 2 then
            make(model, "ScaffoldBoard", Vector3.new(width, 0.25, 1.6), frame * CFrame.new(0, y - 0.3, front + 0.9), Color3.fromRGB(170, 130, 80), Enum.Material.WoodPlanks)
        end
    end
    for y = 2, top - 3, 6 do
        beam(model, "ScaffoldBrace", (frame * CFrame.new(-width / 2, y, front)).Position, (frame * CFrame.new(-width / 2 + 8, y + 6, front)).Position, 0.2, scaffold, Enum.Material.Metal)
    end
    local hoarding = make(model, "Hoarding", Vector3.new(width * 0.8, 4, 0.3), frame * CFrame.new(0, 3, front - 2), Color3.fromRGB(30, 60, 120), Enum.Material.SmoothPlastic, true)
    signText(hoarding, Enum.NormalId.Front, name)
end

local function cone(parent, at)
    if Props.place(parent, "Factory_cone", CFrame.new(at), 7) then return end
    make(parent, "Cone", Vector3.new(1.2, 0.2, 1.2), CFrame.new(at + Vector3.new(0, 0.1, 0)), Color3.fromRGB(30, 30, 30), Enum.Material.Rubber)
    make(parent, "ConeBody", Vector3.new(1.4, 0.7, 0.7), CFrame.new(at + Vector3.new(0, 0.85, 0)) * UPRIGHT, Color3.fromRGB(250, 110, 30), Enum.Material.SmoothPlastic, false, "Cylinder")
    make(parent, "ConeStripe", Vector3.new(0.3, 0.75, 0.75), CFrame.new(at + Vector3.new(0, 1, 0)) * UPRIGHT, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false, "Cylinder")
end
local function barrier(parent, cframe)
    make(parent, "JerseyBarrier", Vector3.new(1.6, 2.6, 8), cframe * CFrame.new(0, 1.3, 0), CONCRETE, Enum.Material.Concrete, true)
    make(parent, "BarrierStripe", Vector3.new(1.65, 0.5, 8.05), cframe * CFrame.new(0, 2, 0), Color3.fromRGB(230, 60, 40), Enum.Material.SmoothPlastic)
end

-- The arch over the lane at the start of the forecourt.
local function arch(parent, z)
    local model = folder(parent, "SpaceportArch")
    local span = Layout.Lane.width + 8
    for _, side in { -1, 1 } do
        make(model, "ArchTower", Vector3.new(2.4, 20, 2.4), CFrame.new(side * span / 2, 10, z), YELLOW, Enum.Material.Metal, true)
        make(model, "ArchFoot", Vector3.new(4, 1.2, 4), CFrame.new(side * span / 2, 0.6, z), CONCRETE, Enum.Material.Concrete, true)
    end
    make(model, "ArchBeam", Vector3.new(span + 4, 2, 2), CFrame.new(0, 20, z), YELLOW, Enum.Material.Metal)
    local board = make(model, "ArchSign", Vector3.new(span + 2, 5, 0.6), CFrame.new(0, 23.5, z), Color3.fromRGB(30, 34, 44), Enum.Material.Metal)
    signText(board, Enum.NormalId.Back, "SPACEPORT EARTH", Color3.fromRGB(255, 210, 60))
    signText(board, Enum.NormalId.Front, "GROUND ZERO", Color3.fromRGB(255, 210, 60))
    for _, side in { -1, 1 } do
        local lamp = make(model, "ArchLamp", Vector3.one * 0.8, CFrame.new(side * (span / 2 + 2), 21.5, z), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, false, "Ball")
        local light = Instance.new("PointLight")
        light.Color, light.Range = Color3.fromRGB(255, 140, 60), 10
        light.Parent = lamp
    end
end

-- Kenney props: { model, x, z, yaw (degrees), studs per kit metre, solid }. They fill
-- the open ground outside the stations and along the apron's edges (|x| >= 250, clear
-- of the launch pad at |x| <= 245), so none is on a walk players need.
Dressing.Props = {
    -- Recycling line beside the Salvage Yard: conveyors out of the yard, under a
    -- hopper, into the crushers; skips of sorted rock and crates of salvage by them.
    { "Factory_conveyor-long", -188, 50, 0, 15, true },
    { "Factory_conveyor-long", -218, 50, 0, 15, true },
    { "Factory_hopper-high-square", -218, 50, 0, 15, true },
    { "Factory_machine-fortified", -248, 50, 180, 15, true },
    { "Factory_machine", -272, 50, 180, 15, true },
    { "Factory_robot-arm-a", -200, 70, 200, 10, false },
    { "Station_skip-rocks", -222, 90, 90, 18, true },
    { "Station_skip", -256, 92, 90, 18, true },
    { "Factory_box-large", -264, -24, 10, 16, true },
    { "Factory_box-long", -242, -32, -5, 16, true },
    { "Factory_box-wide", -266, -44, 0, 16, true },
    { "Factory_warning-traffic", -177, 66, 0, 10, false },
    -- Fuel farm beside the Fuel Depot: a pipe run out to the tanks, a generator and
    -- drum stores, and a dish keeping in touch with the launch.
    { "Factory_pipe-large-long", 182, 55, 0, 6, true },
    { "Factory_pipe-large-long", 194, 55, 0, 6, true },
    { "Factory_pipe-large-valve", 203, 55, 0, 6, true },
    { "Factory_pipe-large-long", 212, 55, 0, 6, true },
    { "Factory_pipe-large-long", 224, 55, 0, 6, true },
    { "Space_machine_barrelLarge", 237, 55, 0, 26, true },
    { "Space_machine_barrelLarge", 237, 28, 0, 26, true },
    { "Space_machine_barrelLarge", 264, 28, 0, 26, true },
    { "Space_machine_generatorLarge", 266, 60, -90, 22, true },
    { "Space_barrels", 218, 84, 20, 22, true },
    { "Space_barrels_rail", 240, 88, 0, 22, true },
    { "Space_satelliteDish_large", 268, 92, 200, 26, false },
    { "Factory_warning-orange", 176, 64, 0, 8, false },
    { "Station_container-tall", 230, -20, 0, 14, true },
    { "Station_container-wide", 244, -20, 0, 14, true },
    { "Station_container", 237, -20, 0, 14, true },
    -- Spawn: astronaut statues by the Gym District entrance and a parked rover.
    { "Space_astronautA", -18, 98, 180, 14, true },
    { "Space_astronautB", 18, 98, 180, 14, true },
    { "Space_rover", 34, 52, 35, 20, true },
    -- Apron edges: hangars with their doors toward spawn, cargo craft and service
    -- kit between them, container stacks and dishes.
    { "Space_hangar_largeA", -268, -190, 0, 17, true },
    { "Space_craft_cargoA", -268, -290, 180, 18, true },
    { "Space_hangar_roundGlass", -268, -400, 90, 13, true },
    { "Space_machine_wireless", -268, -470, 90, 22, false },
    { "Space_satelliteDish_detailed", -268, -620, 160, 26, false },
    { "Space_hangar_largeB", -268, -720, 0, 17, true },
    { "Space_structure_detailed", -268, -820, 0, 26, true },
    { "Space_hangar_largeB", 268, -190, 0, 17, true },
    { "Space_craft_cargoB", 268, -300, 180, 18, true },
    { "Station_container-tall", 262, -380, 0, 14, true },
    { "Station_container-wide", 274, -380, 0, 14, true },
    { "Station_container", 268, -392, 0, 14, true },
    { "Space_satelliteDish_large", 268, -470, 200, 26, false },
    { "Space_hangar_roundA", 268, -640, -90, 13, true },
    { "Space_supports_high", 268, -740, 0, 22, true },
    { "Space_chimney_detailed", 268, -820, 0, 22, true },
}

local function kenney(parent)
    local model = folder(parent, "KenneyProps")
    for _, spot in Dressing.Props do
        local name, x, z, yaw, scale, solid = table.unpack(spot)
        Props.place(model, name, CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0), scale, solid)
    end
end

function Dressing.build(world)
    local site = folder(world, "SiteDressing")
    roads(site)
    local apron, pad = Layout.Apron, Layout.Pad
    -- Two tower cranes either side of the forecourt, jibs over the pad.
    towerCrane(site, Vector3.new(-168, 0, -74), 128, 72, math.rad(-62))
    towerCrane(site, Vector3.new(170, 0, -80), 150, 78, math.rad(58))
    -- Floodlights on the apron's corners, aimed at the rocket.
    local target = pad.center
    for _, corner in { Vector3.new(-apron.x + 5, 0, apron.z1 - 6), Vector3.new(apron.x - 5, 0, apron.z1 - 6),
        Vector3.new(-apron.x + 5, 0, (apron.z0 + apron.z1) / 2), Vector3.new(apron.x - 5, 0, (apron.z0 + apron.z1) / 2) } do
        floodlight(site, corner, target)
    end
    -- Container stacks on the forecourt's outer corners; girder piles by the new buildings.
    containerStack(site, Vector3.new(-140, 0, -78), math.rad(90), { { 0, 0 }, { 1, 0 }, { 0, 1 } }, 11)
    containerStack(site, Vector3.new(140, 0, -76), math.rad(90), { { -1, 0 }, { 0, 0 }, { -1, 1 }, { 0, 1 }, { -0.5, 2 } }, 12)
    containerStack(site, Vector3.new(-188, 0, 10), 0, { { 0, 0 }, { 0, 1 } }, 13)
    containerStack(site, Vector3.new(188, 0, 30), 0, { { 0, 0 } }, 14)
    girderStack(site, Vector3.new(-112, 0, 96), math.rad(90))
    girderStack(site, Vector3.new(112, 0, 96), math.rad(80))
    -- Site offices beside spawn, facing the lane.
    siteOffices(site, Vector3.new(-50, 0, 80), Vector3.new(1, 0, 0))
    siteOffices(site, Vector3.new(50, 0, 80), Vector3.new(-1, 0, 0))
    -- Buildings going up behind the stations.
    skeleton(site, Vector3.new(-150, 0, 92), Vector3.new(0, 0, -1), 30, 14, 4, "MISSION CONTROL - COMING SOON")
    skeleton(site, Vector3.new(150, 0, 92), Vector3.new(0, 0, -1), 36, 16, 3, "ASSEMBLY HANGAR - COMING SOON")
    -- Cones along the lane, barriers at the forecourt corners.
    local cones = folder(site, "Cones")
    for z = Layout.Lane.z0 + 20, Layout.Spawn.Z - 16, 24 do
        for _, side in { -1, 1 } do cone(cones, Vector3.new(side * (Layout.Lane.width / 2 + 1.5), 0, z)) end
    end
    local barriers = folder(site, "Barriers")
    for _, spot in { { -160, -30, 90 }, { 160, -30, 90 }, { -186, -50, 0 }, { 186, -50, 0 } } do
        barrier(barriers, CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0))
    end
    arch(site, Layout.Spawn.Z - 30)
    kenney(site)
    return site
end

return Dressing
