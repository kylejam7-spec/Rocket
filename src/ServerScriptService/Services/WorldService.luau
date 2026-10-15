-- Builds the generated map and tags its gameplay anchors. Other services and
-- clients can find anchors by tag (WorldService.Tags) so art can be swapped later.
local CollectionService = game:GetService("CollectionService")
local World = {}
World.Tags = table.freeze({
    Spawn = "SpawnPoint",
    MaterialSource = "MaterialSource", -- attribute Material
    Frontier = "BuildFrontier",
    Boarding = "BoardingZone",
    Training = "TrainingStation", -- attributes TrainingGain, RequiredCycles (TrainingService)
    GymSign = "GymSign", -- attribute RequiredCycles on tiered gyms
    Planet = "PlanetDestination", -- attribute PlanetId
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
    local function label(object, text)
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.fromOffset(160, 24)
        gui.StudsOffset = Vector3.new(0, 5, 0)
        gui.AlwaysOnTop = true
        -- Hide distant labels so far-off signs don't stack on top of nearby ones.
        gui.MaxDistance = 70
        gui.Parent = object
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0.3
        textLabel.TextSize = 13
        textLabel.Font = Enum.Font.GothamBold
        textLabel.Parent = gui
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
    -- Scrap pit (Metal) and oil refinery (Fuel) sit right behind spawn; the gyms are off to the sides.
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
    frontierSign.Size = UDim2.fromOffset(170, 26)
    frontierSign.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
    frontierSign.AlwaysOnTop = true
    frontierSign.MaxDistance = 400
    frontierSign.Adornee = frontier
    frontierSign.Parent = frontier
    local frontierText = Instance.new("TextLabel")
    frontierText.Size = UDim2.fromScale(1, 1)
    frontierText.BackgroundTransparency = 1
    frontierText.TextColor3 = Color3.new(1, 1, 1)
    frontierText.TextStrokeTransparency = 0.2
    frontierText.TextSize = 15
    frontierText.Font = Enum.Font.GothamBold
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
    -- Gym bays line both sides of the lane from spawn to the rocket, alternating sides and
    -- getting stronger further from spawn: starter gym nearest, GYM 5 at the far edge
    -- (x = -111..111). Slot 1 is the starter gym, slot n + 1 is GYM n.
    local GYM_Z = 8
    local function gymX(slot)
        return (slot % 2 == 1 and -1 or 1) * (28 + 34 * math.floor((slot - 1) / 2))
    end
    local strengthStation = part("StrengthGym", Vector3.new(gymX(1) - 7, 1, GYM_Z), Vector3.new(7, 2, 7), Color3.fromRGB(191, 94, 109))
    local speedStation = part("SpeedGym", Vector3.new(gymX(1) + 7, 1, GYM_Z), Vector3.new(7, 2, 7), Color3.fromRGB(110, 115, 218))
    label(strengthStation, "BENCH")
    label(speedStation, "TREADMILL")
    -- Well past the tilted Tier 5 rocket, which leans ~150 studs out over -Z.
    service.planet = tag(part("MeadowPlanet", Vector3.new(0, 2, -420), Vector3.new(65, 4, 65), Color3.fromRGB(113, 177, 95)), World.Tags.Planet, { PlanetId = config.Planet.Id })
    world.Parent = workspace

    local function equipment(base, treadmill)
        local p = base.Position
        base.Size = Vector3.new(8, 0.4, 10)
        base.Position = Vector3.new(p.X, 0.2, p.Z)
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
    equipment(strengthStation, false)
    equipment(speedStation, true)
    -- TrainingService definitions; it stamps their attributes when it starts.
    local stations = {
        { part = strengthStation, name = "Bench press", stat = "strengthLevel", gain = 2 },
        { part = speedStation, name = "Treadmill", stat = "speedLevel", gain = 2 },
    }
    local tierColors = {
        Color3.fromRGB(225, 191, 98), Color3.fromRGB(80, 200, 160),
        Color3.fromRGB(75, 175, 235), Color3.fromRGB(180, 110, 235), Color3.fromRGB(245, 120, 75),
    }
    -- Text is painted on the sign board itself so neighbouring gyms never overlap.
    -- It faces +Z, back toward spawn.
    local function signText(sign, lines)
        local surface = Instance.new("SurfaceGui")
        surface.Name = "SignText"
        surface.Face = Enum.NormalId.Back
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
            textLabel.TextStrokeTransparency = 0.4
            textLabel.Font = Enum.Font.GothamBold
            textLabel.Parent = surface
        end
    end
    -- Bays are 30 x 24 with the sign on the rocket-side edge, above the equipment so
    -- nothing hides it from spawn.
    local function gymBay(bayName, signName, x, color)
        part(bayName, Vector3.new(x, 0.05, GYM_Z), Vector3.new(30, 0.1, 24), color)
        return tag(part(signName, Vector3.new(x, 8, GYM_Z - 13), Vector3.new(26, 7, 0.5), color), World.Tags.GymSign)
    end
    signText(gymBay("StarterBay", "StarterSign", gymX(1), Color3.fromRGB(150, 155, 170)), {
        { name = "Title", text = "STARTER GYM", height = 0.3 },
        { name = "Gain", text = "+2 strength & speed / sec", height = 0.2 },
        { name = "Status", text = "Open to everyone", height = 0.2 },
    })
    for index, tier in config.TrainingTiers do
        local x = gymX(index + 1)
        local color = tierColors[index]
        local sign = gymBay("TrainingBay" .. tier.cycles, "TrainingSign" .. tier.cycles, x, color)
        sign:SetAttribute("RequiredCycles", tier.cycles)
        signText(sign, {
            { name = "Title", text = "GYM " .. index, height = 0.3 },
            { name = "Gain", text = "+" .. tier.gain .. " strength & speed / sec", height = 0.2 },
            { name = "Status", text = "Unlocks after " .. tier.cycles .. (tier.cycles == 1 and " launch" or " launches"), height = 0.2 },
        })
        for _, treadmill in {false, true} do
            local kind = treadmill and "Treadmill" or "Bench"
            local base = part("Advanced" .. kind .. tier.cycles,
                Vector3.new(x + (treadmill and 7 or -7), 1, GYM_Z), Vector3.new(7, 2, 7), color)
            equipment(base, treadmill)
            table.insert(stations, { part = base, name = tier.cycles .. "-cycle " .. kind,
                stat = treadmill and "speedLevel" or "strengthLevel", gain = tier.gain, required = tier.cycles })
        end
    end
    service.stations = stations

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
