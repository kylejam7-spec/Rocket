-- Builds the generated map and tags its gameplay anchors. Other services and
-- clients can find anchors by tag (WorldService.Tags) so art can be swapped later.
local CollectionService = game:GetService("CollectionService")
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

    local MaterialStations = require(script.Parent.MaterialStationService)
    service.expandMap = require(script.Parent.MapExpansionService).build(part, label, MaterialStations.Reserved)
    service.expandMap(1)
    local spawn = tag(part("Spawn", Vector3.new(0, 1, 36), Vector3.new(8, 1, 8), Color3.fromRGB(225, 230, 238), "SpawnLocation"), World.Tags.Spawn)
    spawn.Neutral = true
    label(spawn, "SPAWN")
    service.spawn = spawn
    -- Scrap pit (Metal) and oil refinery (Fuel) sit right behind spawn; the Gym District is past them.
    service.materialStations = MaterialStations.build(world)
    for material, station in service.materialStations do tag(station.zone, World.Tags.MaterialSource, { Material = material }) end
    service.materialColors = { Metal = Color3.fromRGB(139, 166, 185), Fuel = Color3.fromRGB(245, 182, 71) }
    -- Glowing ring at the rocket's lowest unfinished point. Players climb the ramp and
    -- the finished hull to reach it, then hold E to pour their scrap ball in.
    local frontier = tag(part("BuildFrontier", Vector3.new(0, -50, -112), Vector3.new(0.4, 6, 6), service.materialColors.Metal), World.Tags.Frontier)
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
    service.rocketBuild = require(script.Parent.RocketBuildService).new(world, CFrame.new(0, 0.58, -112))
    -- The rocket cabin and the five destinations (DestinationService), far off the map.
    service.destinations, service.cabin = require(script.Parent.DestinationService).build(world, config)
    world.Parent = workspace

    local function equipment(base, treadmill)
        local p = base.Position
        base.Size = Vector3.new(8, 0.4, 10)
        base.Position = Vector3.new(p.X, p.Y - 0.8, p.Z)
        local dark, steel = Color3.fromRGB(35, 40, 50), Color3.fromRGB(165, 175, 190)
        if treadmill then
            part("TreadmillBelt", p, Vector3.new(4, 0.5, 7), dark)
            for _, x in {-2.5, 2.5} do
                part("TreadmillRail", p + Vector3.new(x, 0.5, 0), Vector3.new(0.4, 1, 8), steel)
                part("TreadmillPost", p + Vector3.new(x, 2, -3), Vector3.new(0.4, 4, 0.4), steel)
            end
            part("TreadmillConsole", p + Vector3.new(0, 3.5, -3), Vector3.new(5, 1, 0.7), base.Color)
        else
            part("BenchCushion", p + Vector3.new(0, 1, 0), Vector3.new(2.5, 0.6, 6), dark)
            for _, x in {-2.5, 2.5} do
                part("BenchRack", p + Vector3.new(x, 1.5, -2), Vector3.new(0.4, 4, 0.4), steel)
                part("WeightPlate", p + Vector3.new(x, 3, -2), Vector3.new(0.7, 2.2, 2.2), dark)
            end
            part("Barbell", p + Vector3.new(0, 3, -2), Vector3.new(7, 0.25, 0.25), steel)
        end
        tag(base, World.Tags.Training)
    end
    -- Gym District: its own plaza past the material stations, reached up the road
    -- between them (x = -8..8). Gyms run in tier order along a central walkway,
    -- alternating sides: FREE GYM at the entrance, then 2X, 5X ... 100X deepest in.
    -- Each bay is 30 (x) by 24 (z) with its sign on the outer edge, facing the walkway.
    local DISTRICT_Z0, BAY_STEP, BAY_X = 176, 16, 27
    local slots = 1 + #config.TrainingTiers
    local districtZ1 = DISTRICT_Z0 + (slots - 1) * BAY_STEP + 22
    local floorColor = Color3.fromRGB(58, 64, 78)
    local function signText(sign, face, lines)
        local surface = Instance.new("SurfaceGui")
        surface.Name = "SignText"
        surface.Face = face
        surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        surface.PixelsPerStud = 40
        surface.Parent = sign
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0.03, 0)
        layout.Parent = surface
        for order, line in lines do
            local textLabel = Instance.new("TextLabel")
            textLabel.Name = line.name
            textLabel.LayoutOrder = order
            textLabel.Size = UDim2.fromScale(1, line.height)
            textLabel.BackgroundTransparency = 1
            textLabel.Text = line.text
            textLabel.TextScaled = true
            textLabel.TextColor3 = Color3.new(1, 1, 1)
            textLabel.Font = Enum.Font.FredokaOne
            textLabel.Parent = surface
            local stroke = Instance.new("UIStroke")
            stroke.Thickness = 6
            stroke.Color = Color3.fromRGB(22, 14, 32)
            stroke.LineJoinMode = Enum.LineJoinMode.Round
            stroke.Parent = textLabel
        end
    end
    -- Floor slab from the end of the ground (z = 160) to past the last bay, plus a
    -- painted walkway and an entrance arch facing back toward spawn.
    part("GymDistrictFloor", Vector3.new(0, -1, (160 + districtZ1) / 2), Vector3.new(110, 2, districtZ1 - 160), floorColor)
    part("GymWalkway", Vector3.new(0, 0.03, (152 + districtZ1) / 2), Vector3.new(16, 0.06, districtZ1 - 152), Color3.fromRGB(245, 182, 71)).CanCollide = false
    for _, side in {-1, 1} do
        part("GymArchPost", Vector3.new(side * 10, 7, 164), Vector3.new(2, 14, 2), Color3.fromRGB(165, 175, 190))
    end
    signText(part("GymArchSign", Vector3.new(0, 15.5, 164), Vector3.new(24, 4, 1), Color3.fromRGB(35, 40, 50)),
        Enum.NormalId.Front, { { name = "Title", text = "GYM DISTRICT", height = 0.8 } })
    -- Low walls on the open sides and back so nobody walks off the plaza.
    local wallColor = Color3.fromRGB(81, 91, 107)
    for _, side in {-1, 1} do
        part("GymDistrictWall", Vector3.new(side * 55, 1.5, (160 + districtZ1) / 2), Vector3.new(1, 3, districtZ1 - 160), wallColor)
    end
    part("GymDistrictWall", Vector3.new(0, 1.5, districtZ1), Vector3.new(111, 3, 1), wallColor)

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
        local multiplier = tier and tier.multiplier or 1
        local required = tier and tier.cycles or 0
        local gain = config.TrainingBaseGain * multiplier
        local title = tier and multiplier .. "X GYM" or "FREE GYM"
        local side = slot % 2 == 1 and -1 or 1
        local x, z = side * BAY_X, DISTRICT_Z0 + (slot - 1) * BAY_STEP
        local color = tierColors[slot] or tierColors[#tierColors]
        part("GymBay" .. slot, Vector3.new(x, 0.05, z), Vector3.new(30, 0.1, 24), color)
        -- The sign's face is drawn per player (GymSignController: lock status).
        local sign = tag(part("GymSign" .. slot, Vector3.new(side * (BAY_X + 15), 8, z), Vector3.new(0.5, 7, 22), Color3.fromRGB(35, 40, 50)),
            World.Tags.GymSign, { Title = title, Multiplier = multiplier, Gain = gain, TierColor = color,
                Face = (side < 0 and Enum.NormalId.Right or Enum.NormalId.Left).Name })
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
    -- Each destination's own bench and treadmill: double that destination's per-second
    -- reward, usable only there during the reward stay (Main's phaseAllowed).
    for tier, place in service.destinations do
        for _, kind in { "bench", "treadmill" } do
            local treadmill = kind == "treadmill"
            local base = part((treadmill and "Treadmill" or "Bench") .. place.id, place.gym[kind], Vector3.new(7, 2, 7), Color3.fromRGB(255, 190, 40))
            equipment(base, treadmill)
            base:SetAttribute("Destination", place.id)
            base:SetAttribute("Multiplier", 2)
            base:SetAttribute("TierColor", Color3.fromRGB(255, 190, 40))
            local bonus = treadmill and config.Planet.SpeedBonus or config.Planet.StrengthBonus
            table.insert(stations, { part = base, name = treadmill and "Treadmill" or "Bench press", destination = tier,
                stat = treadmill and "speedLevel" or "strengthLevel", gain = 2 * bonus * place.reward, required = 0 })
        end
    end
    service.stations = stations

    -- Upgrades hut beside the lane between spawn and the launch pad, door facing the
    -- lane. Its prompt only opens the panel (client); purchases go through BuyUpgrade.
    local hutColor, roofColor = Color3.fromRGB(70, 175, 95), Color3.fromRGB(255, 204, 40)
    local hut = tag(part("UpgradesHut", Vector3.new(-26, 4, -32), Vector3.new(12, 8, 14), hutColor), World.Tags.Upgrades)
    part("UpgradesRoof", Vector3.new(-26, 8.6, -32), Vector3.new(14, 1.2, 16), roofColor)
    part("UpgradesDoor", Vector3.new(-19.9, 3, -32), Vector3.new(0.2, 6, 4), Color3.fromRGB(40, 32, 60))
    local hutSign = part("UpgradesSign", Vector3.new(-19.6, 10.6, -32), Vector3.new(0.4, 3, 12), roofColor)
    signText(hutSign, Enum.NormalId.Right, { { name = "Title", text = "UPGRADES", height = 0.8 } })
    local hutPrompt = service.prompt(hut, "Open Upgrades")
    hutPrompt.ObjectText = "Upgrades"
    hutPrompt.MaxActivationDistance = 14
    service.upgradesHut = hut

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
