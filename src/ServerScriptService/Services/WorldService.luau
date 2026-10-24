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
    -- Each gym's floor: Title, Multiplier, RequiredCycles, GymTier and PaidOnly (the
    -- walk-in purchase offer, PurchaseOfferController).
    GymBay = "GymBay",
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
        if service.spaceport then service.spaceport.fit(service.siteEdge) end
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
    -- Spaceport: Mission Control, pads and hangars behind the pad; a campus and arrays beyond.
    service.spaceport = require(script.Parent.SpaceportService).build(world)
    service.spaceport.fit(service.siteEdge)
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
    -- The boarding trigger: an invisible box in front of the boarding station's door
    -- (BoardingStation); each tier moves it to its own station.
    local boarding = tag(part("BoardingZone", Vector3.new(0, 0.7, -100), Vector3.new(14, 0.2, 8), Color3.fromRGB(89, 210, 165)), World.Tags.Boarding)
    boarding.Transparency = 1
    boarding.CanCollide, boarding.CanQuery, boarding.CanTouch = false, false, false
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
    -- between them (x = -8..8). Gyms stand in tier order in rows of two either side of a
    -- central walkway, facing each other: FREE GYM and 2X at the entrance, then 5X / 10X,
    -- 25X / 50X and 75X / 100X. The paid-only SPACEX GYM (Config.SpaceXGym) closes the
    -- walkway, centred across the back. Each tier bay is 30 (x) by 24 (z) with its sign
    -- on the outer edge, facing the walkway; every bay is tagged GymBay (lock status for
    -- the walk-in offer, PurchaseOfferController).
    local DISTRICT_Z0, ROW_STEP, BAY_X = Layout.Gym.z0, Layout.Gym.step, Layout.Gym.x
    local groundEnd, archZ = Layout.Ground.z1, Layout.Gym.entrance
    local slots = 1 + #config.TrainingTiers
    local rows = math.ceil(slots / 2)
    local spaceX = config.SpaceXGym
    local SX_W, SX_D = Layout.Gym.spaceX.x, Layout.Gym.spaceX.z
    local sxFront = DISTRICT_Z0 + (rows - 1) * ROW_STEP + 12 + Layout.Gym.spaceX.gap
    local sxZ = sxFront + SX_D / 2
    local districtZ1 = sxFront + SX_D + 4
    local floorColor = Color3.fromRGB(58, 64, 78)
    -- Floor slab from the end of the ground (Layout.Ground.z1) to past the last bay, plus a
    -- painted walkway (up to the SpaceX hall) and an entrance arch facing back toward spawn.
    local districtFloor = part("GymDistrictFloor", Vector3.new(0, -1, (groundEnd + districtZ1) / 2), Vector3.new(110, 2, districtZ1 - groundEnd), floorColor)
    districtFloor.Material = Enum.Material.Rubber
    Planets.overlay(districtFloor, Enum.NormalId.Top, "GymFloor", 16, 0.2)
    local walkway = part("GymWalkway", Vector3.new(0, 0.03, (groundEnd - 8 + sxFront) / 2), Vector3.new(16, 0.06, sxFront - groundEnd + 8), Color3.fromRGB(232, 172, 66))
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
    -- A bay's floor: rubber with a darker trim round its edge.
    local function bayFloor(name, center, size, color, trim)
        local bay = part(name, center, Vector3.new(size.X, 0.1, size.Y), color)
        bay.Material = Enum.Material.Rubber
        Planets.overlay(bay, Enum.NormalId.Top, "GymFloor", 12, 0.35)
        local hx, hz = size.X / 2 - 0.4, size.Y / 2 - 0.4
        for _, edge in { { Vector3.new(0, 0, hz), Vector3.new(size.X, 0.14, 0.8) }, { Vector3.new(0, 0, -hz), Vector3.new(size.X, 0.14, 0.8) },
            { Vector3.new(hx, 0, 0), Vector3.new(0.8, 0.14, size.Y) }, { Vector3.new(-hx, 0, 0), Vector3.new(0.8, 0.14, size.Y) } } do
            local strip = part("GymBayTrim", center + Vector3.new(0, 0.02, 0) + edge[1], edge[2], trim)
            strip.CanCollide, strip.CanQuery, strip.CanTouch = false, false, false
        end
        return bay
    end
    -- One gym: its bay, sign and stations. `gym`: slot, title, multiplier, required
    -- (launches; math.huge for paid only), tier (the gym access pass key after "Gym"),
    -- paid, color, trim, center, size (x by z), sign = { position, size, face } and
    -- equipment = { { x offset, z offset, treadmill? } ... }.
    local function gymBay(gym)
        local gain = config.TrainingBaseGain * gym.multiplier
        local bay = bayFloor("GymBay" .. gym.slot, gym.center, gym.size, gym.color, gym.trim or gym.color:Lerp(Color3.new(0, 0, 0), 0.35))
        tag(bay, World.Tags.GymBay, { Title = gym.title, Multiplier = gym.multiplier, RequiredCycles = gym.required,
            GymTier = gym.tier, PaidOnly = gym.paid })
        -- The sign's face is drawn per player (GymSignController: lock status); the part
        -- itself is invisible, so only the rounded panel shows.
        local sign = tag(part("GymSign" .. gym.slot, gym.sign.position, gym.sign.size, Color3.fromRGB(35, 40, 50)),
            World.Tags.GymSign, { Title = gym.title, Multiplier = gym.multiplier, Gain = gain, TierColor = gym.color, Face = gym.sign.face.Name })
        sign.Transparency, sign.CastShadow = 1, false
        if gym.tier then
            sign:SetAttribute("RequiredCycles", gym.required)
            sign:SetAttribute("GymTier", gym.tier)
            sign:SetAttribute("PaidOnly", gym.paid)
        end
        for _, spot in gym.equipment do
            local treadmill = spot[3]
            local kind = treadmill and "Treadmill" or "Bench"
            local base = part(gym.title:gsub(" ", "") .. kind, gym.center + Vector3.new(spot[1], 0.95, spot[2]), Vector3.new(7, 2, 7), gym.color)
            equipment(base, treadmill)
            base:SetAttribute("Multiplier", gym.multiplier)
            base:SetAttribute("TierColor", gym.color)
            if gym.paid then base:SetAttribute("PaidOnly", true) end
            table.insert(stations, { part = base, name = gym.name .. " " .. kind:lower(), stat = treadmill and "speedLevel" or "strengthLevel",
                gain = gain, required = gym.required, tier = gym.tier, paid = gym.paid })
        end
        return bay
    end
    -- Slot 1 is the free gym; slot n + 1 is TrainingTiers[n]. Odd slots west, even east.
    for slot = 1, slots do
        local tier = config.TrainingTiers[slot - 1]
        local multiplier = tier and tier.multiplier or config.FreeGymMultiplier
        local side = slot % 2 == 1 and -1 or 1
        local x, z = side * BAY_X, DISTRICT_Z0 + ((slot + 1) // 2 - 1) * ROW_STEP
        gymBay({
            slot = slot, title = tier and multiplier .. "X GYM" or "FREE GYM", name = tier and multiplier .. "x gym" or "Free gym",
            multiplier = multiplier, required = tier and tier.cycles or 0, tier = tier and slot - 1 or nil,
            color = tierColors[slot] or tierColors[#tierColors], center = Vector3.new(x, 0.05, z), size = Vector2.new(30, 24),
            sign = { position = Vector3.new(side * (BAY_X + 15), 8, z), size = Vector3.new(0.5, 7, 22),
                face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left },
            equipment = { { -side * 2, -6, false }, { -side * 2, 6, true } },
        })
    end
    -- The SpaceX Gym: a wide black hall floor across the walkway's end, two benches and
    -- two treadmills facing the entrance, its sign on a tall backdrop and a white launch
    -- vehicle standing on a pad in each back corner.
    local sxWhite, sxBlack, sxBlue = Color3.fromRGB(236, 238, 242), Color3.fromRGB(28, 30, 36), Color3.fromRGB(70, 160, 255)
    local backZ = sxZ + SX_D / 2 - 0.5
    gymBay({
        slot = slots + 1, title = spaceX.title, name = "SpaceX gym", multiplier = spaceX.multiplier, required = math.huge,
        tier = spaceX.key:match("^Gym(.+)$"), paid = true, color = sxBlue, trim = sxWhite,
        center = Vector3.new(0, 0.05, sxZ), size = Vector2.new(SX_W, SX_D),
        sign = { position = Vector3.new(0, 9, backZ - 0.8), size = Vector3.new(22, 7, 0.5), face = Enum.NormalId.Front },
        equipment = { { -21, -2, false }, { -9, -2, false }, { 9, -2, true }, { 21, -2, true } },
    }).Color = sxBlack
    local sxDecor = Instance.new("Folder")
    sxDecor.Name = "SpaceXGym"
    sxDecor.Parent = world
    local function sxPiece(name, cframe, size, color, material, shape)
        local item = part(name, cframe.Position, size, color)
        item.CFrame = cframe
        if shape then item.Shape = shape end
        item.Material = material or Enum.Material.SmoothPlastic
        item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
        item.Parent = sxDecor
        return item
    end
    -- The backdrop: a black wall wider than the sign, a white band along its top and a
    -- glowing blue line along its foot.
    sxPiece("SpaceXBackdrop", CFrame.new(0, 7.5, backZ), Vector3.new(30, 15, 1), sxBlack, Enum.Material.Metal).CanCollide = true
    sxPiece("SpaceXBand", CFrame.new(0, 14.2, backZ - 0.55), Vector3.new(30, 0.8, 0.1), sxWhite)
    sxPiece("SpaceXGlow", CFrame.new(0, 0.6, backZ - 0.55), Vector3.new(30, 0.4, 0.1), sxBlue, Enum.Material.Neon)
    -- A two-stage launch vehicle in each back corner: white body, black interstage and
    -- grid fins, four landing legs, on a glowing pad. Scenery only.
    local upright = CFrame.Angles(0, 0, math.rad(90))
    for _, side in { -1, 1 } do
        local foot = Vector3.new(side * (SX_W / 2 - 6), 0.1, backZ - 5)
        local function at(y) return CFrame.new(foot + Vector3.new(0, y, 0)) end
        sxPiece("PadDisc", at(0.1) * upright, Vector3.new(0.25, 9, 9), sxBlack, Enum.Material.Metal, Enum.PartType.Cylinder)
        sxPiece("PadRing", at(0.05) * upright, Vector3.new(0.2, 9.8, 9.8), sxBlue, Enum.Material.Neon, Enum.PartType.Cylinder)
        sxPiece("Engines", at(1.6) * upright, Vector3.new(1.2, 3.2, 3.2), Color3.fromRGB(70, 74, 84), Enum.Material.Metal, Enum.PartType.Cylinder)
        sxPiece("BoosterBody", at(15.2) * upright, Vector3.new(26, 3.6, 3.6), sxWhite, nil, Enum.PartType.Cylinder)
        sxPiece("Interstage", at(29.4) * upright, Vector3.new(2.4, 3.66, 3.66), sxBlack, nil, Enum.PartType.Cylinder)
        sxPiece("UpperStage", at(33.6) * upright, Vector3.new(6, 3.6, 3.6), sxWhite, nil, Enum.PartType.Cylinder)
        sxPiece("Fairing", at(36.6), Vector3.new(3.6, 3.6, 3.6), sxWhite, nil, Enum.PartType.Ball)
        for index = 0, 3 do
            local angle = index * math.pi / 2 + math.pi / 4
            local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
            local top, bottom = foot + out * 1.6 + Vector3.new(0, 7, 0), foot + out * 4 + Vector3.new(0, 0.2, 0)
            sxPiece("LandingLeg", CFrame.lookAt((top + bottom) / 2, bottom), Vector3.new(0.5, 0.5, (top - bottom).Magnitude), sxBlack, Enum.Material.Metal)
            local fin = foot + out * 2.3 + Vector3.new(0, 27, 0)
            sxPiece("GridFin", CFrame.lookAt(fin, fin + out), Vector3.new(1.4, 1.4, 0.2), sxBlack, Enum.Material.Metal)
        end
    end
    -- The exclusive dressing; SpaceXGymController animates what's tagged here (searchlights,
    -- chase lights, engine test fires, the hologram, the EXCLUSIVE banner's shine), and
    -- PlanetController pulses what's tagged Pulse.
    local function tagged(item, name, attributes)
        CollectionService:AddTag(item, name)
        for key, value in attributes or {} do item:SetAttribute(key, value) end
        return item
    end
    local gold, red = Color3.fromRGB(255, 200, 60), Color3.fromRGB(170, 20, 40)
    -- Chase lights round the hall's open front and both sides, running in sequence.
    local chase = 0
    local function chaseLight(at, size)
        chase += 1
        tagged(sxPiece("ChaseLight", CFrame.new(at), size, sxBlue, Enum.Material.Neon), "SpaceXChase", { Index = chase })
    end
    for x = -SX_W / 2 + 1, SX_W / 2 - 1, 2.5 do chaseLight(Vector3.new(x, 0.15, sxFront + 0.6), Vector3.new(1.2, 0.12, 0.5)) end
    for _, side in { -1, 1 } do
        for z = sxFront + 2.5, backZ - 1, 2.5 do chaseLight(Vector3.new(side * (SX_W / 2 - 0.6), 0.15, z), Vector3.new(0.5, 0.12, 1.2)) end
    end
    -- A glowing inner outline on the floor that breathes, and an underglow under each station.
    for _, edge in { { Vector3.new(0, 0, -SX_D / 2 + 2), Vector3.new(SX_W - 4, 0.06, 0.3) }, { Vector3.new(0, 0, SX_D / 2 - 3), Vector3.new(SX_W - 4, 0.06, 0.3) },
        { Vector3.new(-SX_W / 2 + 2, 0, 0.5), Vector3.new(0.3, 0.06, SX_D - 5) }, { Vector3.new(SX_W / 2 - 2, 0, 0.5), Vector3.new(0.3, 0.06, SX_D - 5) } } do
        tagged(sxPiece("FloorGlow", CFrame.new(Vector3.new(0, 0.16, sxZ) + edge[1]), edge[2], sxBlue, Enum.Material.Neon), "Pulse", { Period = 2.4 })
    end
    for _, x in { -21, -9, 9, 21 } do
        local glow = tagged(sxPiece("StationGlow", CFrame.new(x, 0.13, sxZ - 2), Vector3.new(9.5, 0.06, 11.5), sxBlue, Enum.Material.Neon), "Pulse", { Period = 1.8 })
        local light = Instance.new("PointLight")
        light.Color, light.Range, light.Brightness = sxBlue, 10, 2
        light.Parent = glow
    end
    -- The red carpet from the walkway's end up to the stations, gold-edged, between
    -- velvet ropes on gold stanchions across the front (the carpet's gap stays open).
    local carpetZ0, carpetZ1 = sxFront - 3, sxZ - 7
    sxPiece("RedCarpet", CFrame.new(0, 0.14, (carpetZ0 + carpetZ1) / 2), Vector3.new(8, 0.06, carpetZ1 - carpetZ0), red, Enum.Material.Fabric)
    for _, side in { -1, 1 } do
        sxPiece("CarpetTrim", CFrame.new(side * 4.1, 0.15, (carpetZ0 + carpetZ1) / 2), Vector3.new(0.35, 0.07, carpetZ1 - carpetZ0), gold, Enum.Material.Metal)
    end
    for _, side in { -1, 1 } do
        local row = {}
        for x = 6, SX_W / 2 - 4, 6 do
            local foot = Vector3.new(side * x, 0, sxFront - 1.2)
            sxPiece("StanchionBase", CFrame.new(foot + Vector3.new(0, 0.12, 0)) * upright, Vector3.new(0.24, 1.6, 1.6), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
            sxPiece("Stanchion", CFrame.new(foot + Vector3.new(0, 1.6, 0)) * upright, Vector3.new(3.2, 0.35, 0.35), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
            local top = sxPiece("StanchionTop", CFrame.new(foot + Vector3.new(0, 3.3, 0)), Vector3.one * 0.6, gold, Enum.Material.Metal, Enum.PartType.Ball)
            local hook = Instance.new("Attachment")
            hook.Position = Vector3.new(0, -0.15, 0)
            hook.Parent = top
            table.insert(row, hook)
        end
        for index = 1, #row - 1 do
            local rope = Instance.new("Beam")
            rope.Attachment0, rope.Attachment1 = row[index], row[index + 1]
            rope.Color = ColorSequence.new(red)
            rope.Width0, rope.Width1 = 0.28, 0.28
            rope.CurveSize0, rope.CurveSize1 = -1.4, 1.4
            rope.Segments = 12
            rope.FaceCamera = true
            rope.LightInfluence = 1
            rope.Parent = row[index].Parent
        end
    end
    -- Engine test fires: flame and smoke under each display vehicle, off until the
    -- controller lights them; a light flickers with them.
    for _, engines in sxDecor:GetChildren() do
        if engines.Name == "Engines" then
            local flame = Instance.new("ParticleEmitter")
            flame.Name = "Flame"
            flame.Texture = "rbxasset://textures/particles/fire_main.dds"
            flame.Color = ColorSequence.new(Color3.fromRGB(140, 200, 255), Color3.fromRGB(255, 150, 60))
            flame.LightEmission, flame.LightInfluence = 1, 0
            -- Standing on its pad, the blast splashes out round the base and curls up.
            flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0.6) })
            flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 1) })
            flame.Lifetime = NumberRange.new(0.35, 0.55)
            flame.Speed = NumberRange.new(16, 24)
            flame.SpreadAngle = Vector2.new(80, 80)
            flame.Acceleration = Vector3.new(0, 55, 0)
            flame.Drag = 4
            flame.Rate = 160
            flame.Enabled = false
            flame.Parent = engines
            local smoke = Instance.new("ParticleEmitter")
            smoke.Name = "Smoke"
            smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
            smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
            smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
            smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
            smoke.Lifetime = NumberRange.new(1.4, 2.4)
            smoke.Speed = NumberRange.new(14, 22)
            smoke.SpreadAngle = Vector2.new(85, 85)
            smoke.Acceleration = Vector3.new(0, 10, 0)
            smoke.Drag = 2
            smoke.Rate = 40
            smoke.Enabled = false
            smoke.Parent = engines
            -- The engines part is a cylinder lying along X, stood up: its -X face is down.
            flame.EmissionDirection, smoke.EmissionDirection = Enum.NormalId.Left, Enum.NormalId.Left
            local light = Instance.new("PointLight")
            light.Name = "FireLight"
            light.Color, light.Range, light.Brightness, light.Enabled = Color3.fromRGB(255, 170, 90), 26, 0, true
            light.Parent = engines
            tagged(engines, "SpaceXEngine")
        end
    end
    -- Two searchlights at the front corners sweep the sky.
    for _, side in { -1, 1 } do
        local at = Vector3.new(side * (SX_W / 2 - 3), 1.2, sxFront + 3)
        sxPiece("SearchlightBase", CFrame.new(at - Vector3.new(0, 0.7, 0)), Vector3.new(2.6, 1, 2.6), sxBlack, Enum.Material.Metal)
        local lamp = tagged(sxPiece("Searchlight", CFrame.lookAt(at, at + Vector3.new(side * 0.3, 1, 0.4)), Vector3.new(2, 2, 2.4), Color3.fromRGB(220, 235, 255), Enum.Material.Neon),
            "SpaceXSearchlight", { Base = at, Side = side })
        local from, to = Instance.new("Attachment"), Instance.new("Attachment")
        from.Position, to.Position = Vector3.new(0, 0, -1.2), Vector3.new(0, 0, -160)
        from.Parent, to.Parent = lamp, lamp
        local beam = Instance.new("Beam")
        beam.Attachment0, beam.Attachment1 = from, to
        beam.Width0, beam.Width1 = 1.8, 22
        beam.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
        beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
        beam.LightEmission, beam.LightInfluence = 1, 0
        beam.FaceCamera = true
        beam.Segments = 1
        beam.Parent = lamp
    end
    -- Light pillars at the hall's four corners.
    for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
        local at = Vector3.new(corner.X * (SX_W / 2 - 0.8), 0.2, sxZ + corner.Z * (SX_D / 2 - 0.8))
        local foot = tagged(sxPiece("PillarFoot", CFrame.new(at), Vector3.new(1.6, 0.25, 1.6), sxBlue, Enum.Material.Neon), "Pulse", { Period = 2.4 })
        local from, to = Instance.new("Attachment"), Instance.new("Attachment")
        to.Position = Vector3.new(0, 70, 0)
        from.Parent, to.Parent = foot, foot
        local pillar = Instance.new("Beam")
        pillar.Attachment0, pillar.Attachment1 = from, to
        pillar.Width0, pillar.Width1 = 1.4, 0.4
        pillar.Color = ColorSequence.new(sxBlue, Color3.fromRGB(190, 230, 255))
        pillar.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
        pillar.LightEmission, pillar.LightInfluence = 1, 0
        pillar.FaceCamera = true
        pillar.Parent = foot
    end
    -- Glitter rising through the hall.
    local air = sxPiece("SpaceXGlitter", CFrame.new(0, 1, sxZ), Vector3.new(SX_W - 6, 1, SX_D - 6), sxBlue)
    air.Transparency = 1
    local glitter = Instance.new("ParticleEmitter")
    glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    glitter.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, sxBlue), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, gold) })
    glitter.LightEmission, glitter.LightInfluence = 1, 0
    glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) })
    glitter.Transparency = NumberSequence.new(0.1, 1)
    glitter.Lifetime = NumberRange.new(3, 5)
    glitter.Speed = NumberRange.new(1.5, 3)
    glitter.EmissionDirection = Enum.NormalId.Top
    glitter.SpreadAngle = Vector2.new(20, 20)
    glitter.Rate = 30
    glitter.Parent = air
    -- The hologram: a translucent rocket turning and bobbing over the hall, two rings
    -- round it (SpaceXGymController turns the model).
    local holo = Instance.new("Model")
    holo.Name = "SpaceXHologram"
    holo.Parent = sxDecor
    local center = Vector3.new(0, 25, sxZ + 2)
    local function holoPiece(name, cframe, size, shape)
        local item = sxPiece(name, cframe, size, Color3.fromRGB(120, 200, 255), Enum.Material.Neon, shape)
        item.Transparency = 0.45
        item.Parent = holo
        return item
    end
    local core = holoPiece("HoloBody", CFrame.new(center) * upright, Vector3.new(7, 1.8, 1.8), Enum.PartType.Cylinder)
    holoPiece("HoloNose", CFrame.new(center + Vector3.new(0, 3.5, 0)), Vector3.one * 1.8, Enum.PartType.Ball)
    for index = 0, 2 do
        local angle = index / 3 * math.pi * 2
        local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
        holoPiece("HoloFin", CFrame.lookAt(center + out * 1.3 + Vector3.new(0, -3, 0), center + out * 3 + Vector3.new(0, -3, 0)), Vector3.new(0.2, 2.2, 1.6))
    end
    -- Two tilted rings of glowing segments round it.
    for index, tilt in { 22, -22 } do
        local plane = CFrame.new(center) * CFrame.Angles(math.rad(tilt), 0, math.rad(index * 30))
        for segment = 1, 28 do
            local angle = segment / 28 * math.pi * 2
            local at = plane * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -5.5)
            holoPiece("HoloRing", at, Vector3.new(1.25, 0.18, 0.18)).Transparency = 0.15
        end
    end
    holo.PrimaryPart = core
    tagged(holo, "SpaceXHologram", { Center = center })
    local holoLight = Instance.new("PointLight")
    holoLight.Color, holoLight.Range, holoLight.Brightness = sxBlue, 24, 2
    holoLight.Parent = core
    -- ★ EXCLUSIVE ★ over the backdrop, its gold shining (SpaceXGymController).
    local bannerAnchor = sxPiece("ExclusiveBanner", CFrame.new(0, 17.6, backZ), Vector3.one, sxBlack)
    bannerAnchor.Transparency = 1
    local board = Instance.new("BillboardGui")
    board.Name = "Exclusive"
    board.Size = UDim2.fromScale(26, 4)
    board.LightInfluence = 0
    board.MaxDistance = 400
    board.Parent = bannerAnchor
    local words = Instance.new("TextLabel")
    words.Size = UDim2.fromScale(1, 1)
    words.BackgroundTransparency = 1
    words.Font = Enum.Font.FredokaOne
    words.TextScaled = true
    words.Text = "★ EXCLUSIVE · GAME PASS ★"
    words.TextColor3 = Color3.new(1, 1, 1)
    words.Parent = board
    local outline = Instance.new("UIStroke")
    outline.Thickness, outline.Color = 3, Color3.fromRGB(40, 24, 8)
    outline.Parent = words
    local shine = Instance.new("UIGradient")
    shine.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, gold), ColorSequenceKeypoint.new(0.42, gold),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.58, gold), ColorSequenceKeypoint.new(1, gold) })
    shine.Rotation = 15
    shine.Parent = words
    tagged(shine, "SpaceXShine")
    -- District dressing: chevrons down the walkway, lamp posts either side of it, and in
    -- the gaps between rows a planter and a bench on each side. None of it collides except
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
    for z = groundEnd + 4, sxFront - 6, 14 do
        for _, side in { -1, 1 } do
            local at = Vector3.new(side * 1.6, 0.1, z)
            decor("WalkwayChevron", at, Vector3.new(0.7, 0.03, 4.4), Color3.fromRGB(205, 140, 40), nil, false, CFrame.new(at) * CFrame.Angles(0, side * math.rad(40), 0))
        end
    end
    -- Lamps at the entrance and in every gap between rows (none in front of the SpaceX hall).
    for row = 0, rows - 1 do
        local z = row == 0 and DISTRICT_Z0 - 4 or DISTRICT_Z0 + (row - 1) * ROW_STEP + ROW_STEP / 2
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
    for row = 1, rows - 1 do
        -- The gap after this row, before the next.
        local z = DISTRICT_Z0 + (row - 1) * ROW_STEP + ROW_STEP / 2
        for _, side in { -1, 1 } do
            local planterAt = Vector3.new(side * 33, 0.9, z)
            decor("Planter", planterAt, Vector3.new(8, 1.8, 3), Color3.fromRGB(176, 170, 160), Enum.Material.Concrete, true)
            decor("PlanterSoil", planterAt + Vector3.new(0, 0.85, 0), Vector3.new(7.4, 0.2, 2.4), Color3.fromRGB(80, 58, 40), Enum.Material.Ground)
            for index = -1, 1 do
                Planets.blob(dressing, "Shrub", CFrame.new(planterAt + Vector3.new(index * 2.4, 2.2, 0)), Vector3.new(2.6, 2.6, 2.4),
                    Color3.fromRGB(70, 140, 64):Lerp(Color3.fromRGB(110, 160, 70), (index + 1) / 2), Enum.Material.Grass)
            end
            local benchAt = Vector3.new(side * 21, 0, z)
            decor("BenchSeat", benchAt + Vector3.new(0, 1.3, 0), Vector3.new(5, 0.35, 1.2), Color3.fromRGB(160, 110, 66), Enum.Material.WoodPlanks, true)
            decor("BenchBack", benchAt + Vector3.new(0, 2.2, 0.5), Vector3.new(5, 1.2, 0.25), Color3.fromRGB(160, 110, 66), Enum.Material.WoodPlanks)
            for _, dx in { -2, 2 } do decor("BenchLeg", benchAt + Vector3.new(dx, 0.6, 0), Vector3.new(0.3, 1.2, 1.2), Color3.fromRGB(46, 50, 60), Enum.Material.Metal) end
        end
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
            table.insert(stations, { part = base, name = treadmill and "Treadmill" or "Bench press", destination = tier,
                stat = treadmill and "speedLevel" or "strengthLevel", gain = config.Planet.GymGain * place.reward, required = 0 })
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
