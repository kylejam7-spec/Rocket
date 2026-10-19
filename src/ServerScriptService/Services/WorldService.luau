-- Builds the generated map and tags its gameplay anchors. Other services and
-- clients can find anchors by tag (WorldService.Tags) so art can be swapped later.
local CollectionService = game:GetService("CollectionService")
local Signs = require(script.Parent.SignService)
local Planets = require(script.Parent.Planets)
local World = {}
World.Tags = table.freeze({
    Spawn = "SpawnPoint",
    MaterialSource = "MaterialSource", -- attribute Material
    Frontier = "BuildFrontier",
    Boarding = "BoardingZone",
    -- Training stations and gym signs carry Multiplier and TierColor; stations also
    -- TrainingGain, TrainingStat, RequiredCycles (TrainingService), signs Title, Gain and
    -- RequiredCycles (tiered gyms). GymSignController draws both from these.
    Training = "TrainingStation",
    GymSign = "GymSign",
    Upgrades = "UpgradesHut", -- its "Open Upgrades" prompt opens the client panel
    UfoShop = "UfoShop", -- each counter's "Open UFO Shop" prompt opens the client panel
    UfoShopDisplay = "UfoShopDisplay", -- the saucer over each shop (clients spin it)
})

function World.new(ctx)
    local config = ctx.config
    local world = Instance.new("Folder")
    world.Name = "RocketWorld"
    local service = { world = world }
    local function tag(object, name, attributes)
        CollectionService:AddTag(object, name)
        for key, value in attributes or {} do object:SetAttribute(key, value) end
        return object
    end
    local function part(name, position, size, color, className)
        local object = Instance.new(className or "Part")
        object.Name = name
        object.Anchored = true
        object.Position = position
        object.Size = size
        object.Color = color
        object.TopSurface = Enum.SurfaceType.Smooth
        object.BottomSurface = Enum.SurfaceType.Smooth
        object.Parent = world
        return object
    end
    -- Chunky outlined text (the HUD's look), on a dark rounded tag.
    local function styledText(parent, text, color)
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = color or Color3.new(1, 1, 1)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.FredokaOne
        textLabel.Parent = parent
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2.5
        stroke.Color = Color3.fromRGB(22, 14, 32)
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = textLabel
        return textLabel
    end
    local function label(object, text)
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.fromOffset(150, 34)
        gui.StudsOffset = Vector3.new(0, 5, 0)
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        -- Hide distant labels so far-off signs don't stack on top of nearby ones.
        gui.MaxDistance = 70
        gui.Parent = object
        local pill = Instance.new("Frame")
        pill.AnchorPoint = Vector2.new(0.5, 0.5)
        pill.Position = UDim2.fromScale(0.5, 0.5)
        pill.Size = UDim2.fromScale(1, 1)
        pill.BackgroundColor3 = Color3.fromRGB(34, 26, 52)
        pill.BackgroundTransparency = 0.25
        pill.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = pill
        local padding = Instance.new("UIPadding")
        padding.PaddingTop, padding.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
        padding.Parent = pill
        styledText(pill, text)
    end
    function service.prompt(object, action, hold)
        local result = Instance.new("ProximityPrompt")
        result.ActionText = action
        result.ObjectText = object.Name
        result.MaxActivationDistance = config.InteractionDistance
        result.HoldDuration = hold or 0
        result.RequiresLineOfSight = false
        result.KeyboardKeyCode = Enum.KeyCode.E
        result.Parent = object
        return result
    end
    service.part, service.label = part, label

    local Layout = require(script.Parent.SiteLayout)
    local MaterialStations = require(script.Parent.MaterialStationService)
    -- The perimeter (SiteSurroundsService, built with the Gym District below) follows
    -- the ground's edge out as the site expands.
    local expand, surrounds = require(script.Parent.MapExpansionService).build(part, label, MaterialStations.Reserved), nil
    function service.expandMap(cycle)
        service.siteEdge = expand(cycle)
        if surrounds then surrounds.fit(service.siteEdge) end
    end
    service.expandMap(1)
    local spawn = tag(part("Spawn", Layout.Spawn, Vector3.new(8, 1, 8), Color3.fromRGB(225, 230, 238), "SpawnLocation"), World.Tags.Spawn)
    -- Invisible: players just appear on the ground, with no pad or label.
    spawn.Neutral, spawn.Transparency = true, 1
    spawn.CanCollide, spawn.CanQuery, spawn.CanTouch, spawn.CastShadow = false, false, false, false
    service.spawn = spawn
    -- Salvage Yard (Metal) and Fuel Depot (Fuel) flank spawn; the Gym District is behind it.
    service.materialStations = MaterialStations.build(world)
    for material, station in service.materialStations do tag(station.zone, World.Tags.MaterialSource, { Material = material }) end
    -- Roads, cranes, floodlights, containers, offices and buildings going up.
    require(script.Parent.SiteDressingService).build(world)
    -- Puddles, gravel, ruts and weeds; kerbs, manholes and crosswalks; pad markings.
    require(script.Parent.SiteDetails).build(world)
    service.materialColors = { Metal = Color3.fromRGB(139, 166, 185), Fuel = Color3.fromRGB(245, 182, 71) }
    -- Glowing ring at the rocket's lowest unfinished point. Players climb the ramp and
    -- the finished hull to reach it, then hold E to pour their scrap ball in.
    local frontier = tag(part("BuildFrontier", Layout.PadOrigin.Position - Vector3.new(0, 50, 0), Vector3.new(0.4, 6, 6), service.materialColors.Metal), World.Tags.Frontier)
    frontier.Shape = Enum.PartType.Cylinder
    frontier.Material = Enum.Material.Neon
    frontier.Transparency = 0.55
    frontier.CanCollide, frontier.CanQuery, frontier.CanTouch, frontier.CastShadow = false, false, false, false
    local frontierSign = Instance.new("BillboardGui")
    frontierSign.Size = UDim2.fromOffset(220, 34)
    frontierSign.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
    frontierSign.AlwaysOnTop = true
    frontierSign.MaxDistance = 400
    frontierSign.Adornee = frontier
    frontierSign.Parent = frontier
    local frontierText = Instance.new("TextLabel")
    frontierText.Size = UDim2.fromScale(1, 1)
    frontierText.BackgroundTransparency = 1
    frontierText.TextColor3 = Color3.new(1, 1, 1)
    frontierText.TextStrokeTransparency = 1
    frontierText.TextSize = 22
    frontierText.Font = Enum.Font.FredokaOne
    local frontierStroke = Instance.new("UIStroke")
    frontierStroke.Thickness = 2.5
    frontierStroke.Color = Color3.fromRGB(22, 14, 32)
    frontierStroke.Parent = frontierText
    frontierText.Text = "▼ BUILD HERE ▼"
    frontierText.Parent = frontierSign
    service.frontier, service.frontierSign = frontier, frontierSign
    -- Crew boarding zone; each tier moves it to the front of its own launch mount.
    local boarding = tag(part("BoardingZone", Vector3.new(0, 0.7, -100), Vector3.new(14, 0.2, 8), Color3.fromRGB(89, 210, 165)), World.Tags.Boarding)
    boarding.Transparency = 0.35
    boarding.CanCollide = false
    label(boarding, "BOARD")
    service.boarding = boarding
    -- Rockets are built on the permanent LaunchPad (MapExpansionService); y = pad top.
    service.rocketBuild = require(script.Parent.RocketBuildService).new(world, Layout.PadOrigin)
    -- The rocket cabin and the five destinations (DestinationService), far off the map.
    service.destinations, service.cabin = require(script.Parent.DestinationService).build(world, config)
    world.Parent = workspace

    -- The pieces are children of the base so GymAnimationController can find them:
    -- it scrolls the belt's slats and lifts the barbell (plates are its children).
    -- The user faces -Z on the treadmill and lies head to -Z on the bench.
    local function equipment(base, treadmill)
        local p = base.Position
        base.Size = Vector3.new(8, 0.4, 10)
        base.Position = Vector3.new(p.X, p.Y - 0.8, p.Z)
        local dark, steel = Color3.fromRGB(35, 40, 50), Color3.fromRGB(165, 175, 190)
        local function piece(parent, ...)
            local object = part(...)
            object.Parent = parent
            return object
        end
        if treadmill then
            local belt = piece(base, "TreadmillBelt", p, Vector3.new(4, 0.5, 7), dark)
            for index = 0, 6 do
                local slat = piece(belt, "TreadmillSlat", p + Vector3.new(0, 0.27, index - 3), Vector3.new(3.8, 0.05, 0.3), Color3.fromRGB(70, 78, 92))
                slat.CanCollide, slat.CanQuery, slat.CastShadow = false, false, false
            end
            -- Rollers hide the slats wrapping round at each end.
            for _, z in {-3.5, 3.5} do
                piece(base, "TreadmillRoller", p + Vector3.new(0, 0, z), Vector3.new(4, 0.7, 0.7), steel).Shape = Enum.PartType.Cylinder
            end
            for _, x in {-2.5, 2.5} do
                piece(base, "TreadmillRail", p + Vector3.new(x, 0.5, 0), Vector3.new(0.4, 1, 8), steel)
                piece(base, "TreadmillPost", p + Vector3.new(x, 2, -3), Vector3.new(0.4, 4, 0.4), steel)
            end
            piece(base, "TreadmillConsole", p + Vector3.new(0, 3.5, -3), Vector3.new(5, 1, 0.7), base.Color)
        else
            piece(base, "BenchCushion", p + Vector3.new(0, 1, 0), Vector3.new(2.5, 0.6, 6), dark)
            for _, x in {-2.5, 2.5} do
                piece(base, "BenchRack", p + Vector3.new(x, 1.5, -2), Vector3.new(0.4, 4, 0.4), steel)
            end
            local bar = piece(base, "Barbell", p + Vector3.new(0, 3, -2), Vector3.new(7.4, 0.25, 0.25), steel)
            bar.Shape, bar.CanCollide = Enum.PartType.Cylinder, false
            for _, x in {-3.1, 3.1} do
                local plate = piece(bar, "WeightPlate", p + Vector3.new(x, 3, -2), Vector3.new(0.5, 2.2, 2.2), dark)
                plate.Shape, plate.CanCollide = Enum.PartType.Cylinder, false
            end
        end
        tag(base, World.Tags.Training)
    end
    -- Gym District: its own plaza past the material stations, reached up the road
    -- between them (x = -8..8). Gyms run in tier order along a central walkway,
    -- alternating sides: FREE GYM at the entrance, then 2X, 5X ... 100X deepest in.
    -- Each bay is 30 (x) by 24 (z) with its sign on the outer edge, facing the walkway.
    local DISTRICT_Z0, BAY_STEP, BAY_X = Layout.Gym.z0, Layout.Gym.step, Layout.Gym.x
    local groundEnd, archZ = Layout.Ground.z1, Layout.Gym.entrance
    local slots = 1 + #config.TrainingTiers
    local districtZ1 = DISTRICT_Z0 + (slots - 1) * BAY_STEP + 22
    local floorColor = Color3.fromRGB(58, 64, 78)
    -- Floor slab from the end of the ground (Layout.Ground.z1) to past the last bay, plus a
    -- painted walkway and an entrance arch facing back toward spawn.
    local districtFloor = part("GymDistrictFloor", Vector3.new(0, -1, (groundEnd + districtZ1) / 2), Vector3.new(110, 2, districtZ1 - groundEnd), floorColor)
    districtFloor.Material = Enum.Material.Rubber
    Planets.overlay(districtFloor, Enum.NormalId.Top, "GymFloor", 16, 0.2)
    local walkway = part("GymWalkway", Vector3.new(0, 0.03, (groundEnd - 8 + districtZ1) / 2), Vector3.new(16, 0.06, districtZ1 - groundEnd + 8), Color3.fromRGB(232, 172, 66))
    walkway.CanCollide, walkway.Material = false, Enum.Material.Concrete
    Planets.overlay(walkway, Enum.NormalId.Top, "Concrete", 16, 0.45)
    for _, side in {-1, 1} do
        local edge = part("GymWalkwayEdge", Vector3.new(side * 7.7, 0.04, walkway.Position.Z), Vector3.new(0.6, 0.07, walkway.Size.Z), Color3.fromRGB(46, 42, 52))
        edge.CanCollide, edge.CanQuery, edge.CanTouch = false, false, false
    end
    for _, side in {-1, 1} do
        part("GymArchPost", Vector3.new(side * 10, 7, archZ), Vector3.new(2, 14, 2), Color3.fromRGB(165, 175, 190))
    end
    Signs.decorate(part("GymArchSign", Vector3.new(0, 15.5, archZ), Vector3.new(24, 4.4, 1), Signs.Backing), Enum.NormalId.Front,
        { title = "GYM DISTRICT", subtitle = "TRAIN STRENGTH & SPEED", icon = "💪", accent = Color3.fromRGB(255, 204, 40) })
    -- Low walls on the open sides and back so nobody walks off the plaza.
    -- Brick, with a pale cap.
    local wallColor = Color3.fromRGB(150, 84, 66)
    local function districtWall(center, size)
        part("GymDistrictWall", center, size, wallColor).Material = Enum.Material.Brick
        local cap = part("GymWallCap", center + Vector3.new(0, size.Y / 2 + 0.15, 0), size + Vector3.new(0.6, 0.3 - size.Y, 0.6), Color3.fromRGB(205, 200, 190))
        cap.Material, cap.CanCollide = Enum.Material.Concrete, false
    end
    for _, side in {-1, 1} do
        districtWall(Vector3.new(side * 55, 1.5, (groundEnd + districtZ1) / 2), Vector3.new(1, 3, districtZ1 - groundEnd))
    end
    districtWall(Vector3.new(0, 1.5, districtZ1), Vector3.new(111, 3, 1))
    -- Hoarding and barrier round the site and the District; the land beyond.
    surrounds = require(script.Parent.SiteSurroundsService).build(world, { x = 56, z1 = districtZ1 + 1 })
    surrounds.fit(service.siteEdge)

    local stations = {}
    local tierColors = {
        Color3.fromRGB(150, 155, 170), -- free
        Color3.fromRGB(225, 191, 98), Color3.fromRGB(80, 200, 160), Color3.fromRGB(75, 175, 235),
        Color3.fromRGB(180, 110, 235), Color3.fromRGB(245, 120, 75), Color3.fromRGB(235, 80, 140),
        Color3.fromRGB(255, 225, 90),
    }
    -- Slot 1 is the free gym; slot n + 1 is TrainingTiers[n].
    for slot = 1, slots do
        local tier = config.TrainingTiers[slot - 1]
        local multiplier = tier and tier.multiplier or config.FreeGymMultiplier
        local required = tier and tier.cycles or 0
        local gain = config.TrainingBaseGain * multiplier
        local title = tier and multiplier .. "X GYM" or "FREE GYM"
        local side = slot % 2 == 1 and -1 or 1
        local x, z = side * BAY_X, DISTRICT_Z0 + (slot - 1) * BAY_STEP
        local color = tierColors[slot] or tierColors[#tierColors]
        local bay = part("GymBay" .. slot, Vector3.new(x, 0.05, z), Vector3.new(30, 0.1, 24), color)
        bay.Material = Enum.Material.Rubber
        Planets.overlay(bay, Enum.NormalId.Top, "GymFloor", 12, 0.35)
        -- A darker trim round the bay's edge.
        local trim = color:Lerp(Color3.new(0, 0, 0), 0.35)
        for _, edge in { { Vector3.new(0, 0, 11.6), Vector3.new(30, 0.14, 0.8) }, { Vector3.new(0, 0, -11.6), Vector3.new(30, 0.14, 0.8) },
            { Vector3.new(14.6, 0, 0), Vector3.new(0.8, 0.14, 24) }, { Vector3.new(-14.6, 0, 0), Vector3.new(0.8, 0.14, 24) } } do
            local strip = part("GymBayTrim", Vector3.new(x, 0.07, z) + edge[1], edge[2], trim)
            strip.CanCollide, strip.CanQuery, strip.CanTouch = false, false, false
        end
        -- The sign's face is drawn per player (GymSignController: lock status); the part
        -- itself is invisible, so only the rounded panel shows.
        local sign = tag(part("GymSign" .. slot, Vector3.new(side * (BAY_X + 15), 8, z), Vector3.new(0.5, 7, 22), Color3.fromRGB(35, 40, 50)),
            World.Tags.GymSign, { Title = title, Multiplier = multiplier, Gain = gain, TierColor = color,
                Face = (side < 0 and Enum.NormalId.Right or Enum.NormalId.Left).Name })
        sign.Transparency, sign.CastShadow = 1, false
        if tier then sign:SetAttribute("RequiredCycles", required) end
        for _, treadmill in {false, true} do
            local kind = treadmill and "Treadmill" or "Bench"
            local base = part(title:gsub(" ", "") .. kind, Vector3.new(x - side * 2, 1, z + (treadmill and 6 or -6)), Vector3.new(7, 2, 7), color)
            equipment(base, treadmill)
            base:SetAttribute("Multiplier", multiplier)
            base:SetAttribute("TierColor", color)
            table.insert(stations, { part = base, name = title:lower():gsub("^%l", string.upper) .. " " .. kind:lower(),
                stat = treadmill and "speedLevel" or "strengthLevel", gain = gain, required = required })
        end
    end
    -- District dressing: chevrons down the walkway, lamp posts either side of it, and in
    -- the gaps between same-side bays a planter and a bench. None of it collides except
    -- the planters' and benches' bodies, which stand clear of every walking line.
    local dressing = Instance.new("Folder")
    dressing.Name = "GymDistrictDressing"
    dressing.Parent = world
    local function decor(name, position, size, color, material, solid, cframe)
        local item = part(name, position, size, color)
        if cframe then item.CFrame = cframe end
        item.Material = material or Enum.Material.SmoothPlastic
        if not solid then item.CanCollide, item.CanQuery, item.CanTouch = false, false, false end
        item.Parent = dressing
        return item
    end
    for z = groundEnd + 4, districtZ1 - 8, 14 do
        for _, side in { -1, 1 } do
            local at = Vector3.new(side * 1.6, 0.1, z)
            decor("WalkwayChevron", at, Vector3.new(0.7, 0.03, 4.4), Color3.fromRGB(205, 140, 40), nil, false, CFrame.new(at) * CFrame.Angles(0, side * math.rad(40), 0))
        end
    end
    for z = DISTRICT_Z0 - 4, districtZ1 - 10, 32 do
        for _, side in { -1, 1 } do
            local x = side * 10
            decor("LampPost", Vector3.new(x, 5, z), Vector3.new(0.45, 10, 0.45), Color3.fromRGB(46, 50, 60), Enum.Material.Metal, true)
            decor("LampArm", Vector3.new(x - side * 0.9, 9.9, z), Vector3.new(2, 0.25, 0.25), Color3.fromRGB(46, 50, 60), Enum.Material.Metal)
            decor("LampHousing", Vector3.new(x - side * 1.8, 10, z), Vector3.new(1.6, 0.5, 1.6), Color3.fromRGB(46, 50, 60), Enum.Material.Metal)
            local lamp = decor("Lamp", Vector3.new(x - side * 1.8, 9.65, z), Vector3.new(1.2, 0.3, 1.2), Color3.fromRGB(255, 176, 90), Enum.Material.Neon)
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 214, 160), 18, 1
            light.Parent = lamp
        end
    end
    for slot = 1, slots - 2 do
        -- The gap after this bay, before the next one on the same side.
        local side = slot % 2 == 1 and -1 or 1
        local z = DISTRICT_Z0 + (slot - 1) * BAY_STEP + 16
        local planterAt = Vector3.new(side * 33, 0.9, z)
        decor("Planter", planterAt, Vector3.new(8, 1.8, 3), Color3.fromRGB(176, 170, 160), Enum.Material.Concrete, true)
        decor("PlanterSoil", planterAt + Vector3.new(0, 0.85, 0), Vector3.new(7.4, 0.2, 2.4), Color3.fromRGB(80, 58, 40), Enum.Material.Ground)
        for index = -1, 1 do
            Planets.blob(dressing, "Shrub", CFrame.new(planterAt + Vector3.new(index * 2.4, 2.2, 0)), Vector3.new(2.6, 2.6, 2.4),
                Color3.fromRGB(70, 140, 64):Lerp(Color3.fromRGB(110, 160, 70), (index + 1) / 2), Enum.Material.Grass)
        end
        local benchAt = Vector3.new(side * 21, 0, z)
        decor("BenchSeat", benchAt + Vector3.new(0, 1.3, 0), Vector3.new(5, 0.35, 1.4), Color3.fromRGB(160, 110, 66), Enum.Material.WoodPlanks, true)
        decor("BenchBack", benchAt + Vector3.new(0, 2.2, side * 0.6), Vector3.new(5, 1.2, 0.25), Color3.fromRGB(160, 110, 66), Enum.Material.WoodPlanks)
        for _, dx in { -2, 2 } do decor("BenchLeg", benchAt + Vector3.new(dx, 0.6, 0), Vector3.new(0.3, 1.2, 1.2), Color3.fromRGB(46, 50, 60), Enum.Material.Metal) end
    end

    -- Each destination's own bench and treadmill: double that destination's per-second
    -- reward, usable only there during the reward stay (Main's phaseAllowed).
    for tier, place in service.destinations do
        for _, kind in { "bench", "treadmill" } do
            local treadmill = kind == "treadmill"
            -- Dark plate on the gold-trimmed mat (TierColor stays gold for the signs).
            local base = part((treadmill and "Treadmill" or "Bench") .. place.id, place.gym[kind], Vector3.new(7, 2, 7), Color3.fromRGB(74, 78, 92))
            equipment(base, treadmill)
            base.Material = Enum.Material.DiamondPlate
            base:SetAttribute("Destination", place.id)
            base:SetAttribute("TierColor", Color3.fromRGB(255, 190, 40))
            -- An outpost mat under it: rubber with a gold trim, posts at the back corners
            -- carrying lamps (decor, no collision).
            local ground = place.gym[kind] - Vector3.new(0, 1, 0)
            local mat = part("OutpostMat", ground + Vector3.new(0, 0.06, 0), Vector3.new(12, 0.12, 14), Color3.fromRGB(46, 50, 62))
            mat.Material, mat.CanCollide, mat.CanQuery, mat.CanTouch = Enum.Material.Rubber, false, false, false
            Planets.overlay(mat, Enum.NormalId.Top, "GymFloor", 10, 0.3)
            for _, edge in { { Vector3.new(0, 0, 6.7), Vector3.new(12, 0.16, 0.6) }, { Vector3.new(0, 0, -6.7), Vector3.new(12, 0.16, 0.6) },
                { Vector3.new(5.7, 0, 0), Vector3.new(0.6, 0.16, 14) }, { Vector3.new(-5.7, 0, 0), Vector3.new(0.6, 0.16, 14) } } do
                local trim = part("OutpostTrim", ground + Vector3.new(0, 0.08, 0) + edge[1], edge[2], Color3.fromRGB(255, 190, 40))
                trim.Material, trim.CanCollide, trim.CanQuery, trim.CanTouch = Enum.Material.Neon, false, false, false
            end
            for _, x in { -5.4, 5.4 } do
                local post = part("OutpostPost", ground + Vector3.new(x, 3, 6.4), Vector3.new(0.4, 6, 0.4), Color3.fromRGB(46, 50, 62))
                post.Material, post.CanCollide = Enum.Material.Metal, false
                local lamp = part("OutpostLamp", ground + Vector3.new(x, 6.2, 6.4), Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(255, 190, 40))
                lamp.Shape, lamp.Material, lamp.CanCollide = Enum.PartType.Ball, Enum.Material.Neon, false
                local glow = Instance.new("PointLight")
                glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 210, 140), 12, 1
                glow.Parent = lamp
            end
            local bonus = treadmill and config.Planet.SpeedBonus or config.Planet.StrengthBonus
            table.insert(stations, { part = base, name = treadmill and "Treadmill" or "Bench press", destination = tier,
                stat = treadmill and "speedLevel" or "strengthLevel", gain = 2 * bonus * place.reward, required = 0 })
        end
    end
    service.stations = stations

    -- The Upgrades workshop beside the lane between spawn and the launch pad, its door
    -- facing the lane (UpgradeShop). The tagged part is its service counter; the prompt
    -- only opens the panel (client); purchases go through BuyUpgrade.
    local hut = tag(require(script.Parent.UpgradeShop).build(world, Layout.Upgrades), World.Tags.Upgrades)
    local hutPrompt = service.prompt(hut, "Open Upgrades")
    hutPrompt.ObjectText = "Upgrades"
    hutPrompt.MaxActivationDistance = 14
    service.upgradesHut = hut

    -- UFO Shops (PetService sells there): a round pad with a counter, a sign and a
    -- big saucer beaming down over it. One at the spaceport, opposite the upgrades
    -- hut across the lane, and one on every destination. Only the counter collides.
    local PetModels = require(game:GetService("ReplicatedStorage").Shared.PetModels)
    local shopColor, shopGlow = Color3.fromRGB(60, 46, 96), Color3.fromRGB(120, 255, 110)
    local function ufoShop(ground, facing)
        local frame = CFrame.lookAt(ground, ground + facing)
        local folder = Instance.new("Model")
        folder.Name = "UfoShop"
        folder.Parent = world
        local function piece(name, cframe, size, color, shape)
            local object = part(name, cframe.Position, size, color)
            object.CFrame = cframe
            if shape then object.Shape = shape end
            object.Parent = folder
            return object
        end
        local upright = CFrame.Angles(0, 0, math.rad(90))
        local metal = Color3.fromRGB(165, 175, 190)
        piece("ShopPad", frame * CFrame.new(0, 0.2, 0) * upright, Vector3.new(0.4, 12, 12), shopColor, Enum.PartType.Cylinder).Material = Enum.Material.DiamondPlate
        local ring = piece("ShopRing", frame * CFrame.new(0, 0.15, 0) * upright, Vector3.new(0.3, 12.8, 12.8), shopGlow, Enum.PartType.Cylinder)
        ring.Material, ring.CanCollide = Enum.Material.Neon, false
        -- Landing lights round the pad's rim, blinking in turn.
        for index = 1, 12 do
            local angle = index / 12 * math.pi * 2
            local light = piece("PadLight", frame * CFrame.new(math.cos(angle) * 5.5, 0.45, math.sin(angle) * 5.5), Vector3.new(0.5, 0.25, 0.5), shopGlow)
            light.Material = Enum.Material.Neon
            light:SetAttribute("Period", 1.2 + (index % 3) * 0.15)
            CollectionService:AddTag(light, "Blinker")
        end
        -- The counter: a rounded kiosk body with a glowing band and a sloped glass top
        -- holding a row of pet eggs on display.
        local counter = tag(piece("UfoShopCounter", frame * CFrame.new(0, 1.9, 0), Vector3.new(7, 3, 2.4), shopColor), World.Tags.UfoShop)
        counter.Material = Enum.Material.Metal
        -- Rounded ends: upright cylinders (a Cylinder's axis is its X, so turn it up).
        for _, x in { -3.5, 3.5 } do
            local cap = piece("CounterEnd", frame * CFrame.new(x, 1.9, 0) * upright, Vector3.new(3, 2.4, 2.4), shopColor, Enum.PartType.Cylinder)
            cap.Material = Enum.Material.Metal
        end
        piece("CounterBand", frame * CFrame.new(0, 2.4, -1.22), Vector3.new(7, 0.4, 0.1), shopGlow).Material = Enum.Material.Neon
        piece("CounterTop", frame * CFrame.new(0, 3.5, 0), Vector3.new(8.2, 0.3, 2.8), Color3.fromRGB(40, 32, 70)).Material = Enum.Material.SmoothPlastic
        piece("CounterTrim", frame * CFrame.new(0, 3.4, -1.42), Vector3.new(8.2, 0.12, 0.12), shopGlow).Material = Enum.Material.Neon
        local eggColors = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 210, 80), Color3.fromRGB(150, 255, 130) }
        for index, color in eggColors do
            local x = -3 + (index - 1) * 2
            local stand = piece("EggStand", frame * CFrame.new(x, 3.75, 0.2) * upright, Vector3.new(0.2, 1, 1), metal, Enum.PartType.Cylinder)
            stand.Material = Enum.Material.Metal
            local egg = piece("Egg", frame * CFrame.new(x, 4.45, 0.2), Vector3.new(0.9, 1.2, 0.9), color)
            egg.Shape, egg.Material = Enum.PartType.Ball, Enum.Material.SmoothPlastic
            for _, spot in { Vector3.new(0.25, 0.2, -0.38), Vector3.new(-0.2, -0.15, -0.38) } do
                local dot = piece("EggSpot", frame * CFrame.new(x, 4.45, 0.2) * CFrame.new(spot), Vector3.new(0.3, 0.3, 0.1), Color3.new(1, 1, 1))
                dot.Shape = Enum.PartType.Ball
            end
        end
        for _, x in { -4.2, 4.2 } do
            piece("ShopPost", frame * CFrame.new(x, 4.5, 2.5), Vector3.new(0.5, 9, 0.5), metal).Material = Enum.Material.Metal
            local tip = piece("PostLight", frame * CFrame.new(x, 9.2, 2.5), Vector3.new(0.7, 0.7, 0.7), shopGlow)
            tip.Shape, tip.Material = Enum.PartType.Ball, Enum.Material.Neon
        end
        Signs.decorate(piece("ShopSign", frame * CFrame.new(0, 8, 2.5), Vector3.new(10, 3, 0.5), Signs.Backing), Enum.NormalId.Front,
            { title = "UFO SHOP", subtitle = "HATCH ALIEN PETS", icon = "🛸", accent = shopGlow })
        local beam = piece("ShopBeam", frame * CFrame.new(0, 7, 2.5) * upright, Vector3.new(11, 3.4, 3.4), shopGlow, Enum.PartType.Cylinder)
        beam.Material, beam.Transparency, beam.CanCollide, beam.CastShadow = Enum.Material.Neon, 0.85, false, false
        local display = PetModels.ufo(3)
        display.Name = "UfoShopDisplay"
        display:ScaleTo(1.8)
        display:PivotTo(frame * CFrame.new(0, 13.5, 2.5))
        display.Parent = folder
        tag(display, World.Tags.UfoShopDisplay)
        for _, object in folder:GetDescendants() do
            if object:IsA("BasePart") and object ~= counter then object.CanCollide, object.CanQuery = false, false end
        end
        local shopPrompt = service.prompt(counter, "Open UFO Shop")
        shopPrompt.ObjectText = "UFO Shop"
        shopPrompt.MaxActivationDistance = 14
        return counter
    end
    service.ufoShops = { ufoShop(Layout.UfoShop, Vector3.new(-1, 0, 0)) }
    for _, place in service.destinations do table.insert(service.ufoShops, ufoShop(place.shop, place.shopFacing)) end

    function service.anchors(name)
        local found = {}
        for _, object in CollectionService:GetTagged(name) do
            if object:IsDescendantOf(world) then table.insert(found, object) end
        end
        return found
    end
    return service
end
return World
