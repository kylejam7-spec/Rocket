local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Cycles = require(ReplicatedStorage.Shared.RocketCycles)
local Rocket = require(script.Parent.Services.RocketService)
local RocketBuild = require(script.Parent.Services.RocketBuildService)
local Profiles = require(script.Parent.Services.ProfileService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "StateUpdated"
stateEvent.Parent = remotes
local requestState = Instance.new("RemoteEvent")
requestState.Name = "RequestState"
requestState.Parent = remotes
local feedbackEvent = Instance.new("RemoteEvent")
feedbackEvent.Name = "Feedback"
feedbackEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

local world = Instance.new("Folder")
world.Name = "RocketWorld"
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
local prompts = {}
local function prompt(object, action, hold)
    local result = Instance.new("ProximityPrompt")
    result.ActionText = action
    result.ObjectText = object.Name
    result.MaxActivationDistance = Config.InteractionDistance
    result.HoldDuration = hold or 0
    result.RequiresLineOfSight = false
    result.KeyboardKeyCode = Enum.KeyCode.E
    result.Parent = object
    table.insert(prompts, result)
    return result
end

local MaterialStations = require(script.Parent.Services.MaterialStationService)
local expandMap = require(script.Parent.Services.MapExpansionService).build(part, label, MaterialStations.Reserved)
expandMap(1)
local spawn = part("Spawn", Vector3.new(0, 1, 36), Vector3.new(8, 1, 8), Color3.fromRGB(225, 230, 238), "SpawnLocation")
spawn.Neutral = true
label(spawn, "SPAWN")
-- Scrap pit (Metal) and oil refinery (Fuel) sit right behind spawn; the gyms are off to the sides.
local materialStations = MaterialStations.build(world)
local MATERIAL_COLORS = { Metal = Color3.fromRGB(139, 166, 185), Fuel = Color3.fromRGB(245, 182, 71) }
-- Glowing ring at the rocket's lowest unfinished point. Players climb the ramp and
-- the finished hull to reach it, then hold E to pour their scrap ball in.
local frontier = part("BuildFrontier", Vector3.new(0, -50, -112), Vector3.new(0.4, 6, 6), MATERIAL_COLORS.Metal)
frontier.Shape = Enum.PartType.Cylinder
frontier.Material = Enum.Material.Neon
frontier.Transparency = 0.55
frontier.CanCollide, frontier.CanQuery, frontier.CanTouch, frontier.CastShadow = false, false, false, false
local PLACE_POINTS = 7
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
-- Crew boarding zone; each tier moves it to the front of its own launch mount.
local boarding = part("BoardingZone", Vector3.new(0, 0.7, -100), Vector3.new(14, 0.2, 8), Color3.fromRGB(89, 210, 165))
boarding.Transparency = 0.35
boarding.CanCollide = false
label(boarding, "BOARD")
-- Rockets are built on the permanent LaunchPad (MapExpansionService); y = pad top.
local rocketBuild = RocketBuild.new(world, CFrame.new(0, 0.58, -112))
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
local planet = part("MeadowPlanet", Vector3.new(0, 2, -420), Vector3.new(65, 4, 65), Color3.fromRGB(113, 177, 95))
world.Parent = workspace

local rocket = Rocket.new(Config, HttpService:GenerateGUID(false), 1, 0)
local function loadRocket()
    local definition = rocket.definition
    boarding.CFrame, boarding.Size = rocketBuild:load(definition.ModelTier, definition.Variant)
    rocketBuild:setProgress(0, 0)
end
loadRocket()
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
end
equipment(strengthStation, false)
equipment(speedStation, true)
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
    return part(signName, Vector3.new(x, 8, GYM_Z - 13), Vector3.new(26, 7, 0.5), color)
end
signText(gymBay("StarterBay", "StarterSign", gymX(1), Color3.fromRGB(150, 155, 170)), {
    { name = "Title", text = "STARTER GYM", height = 0.3 },
    { name = "Gain", text = "+2 strength & speed / sec", height = 0.2 },
    { name = "Status", text = "Open to everyone", height = 0.2 },
})
for index, tier in Config.TrainingTiers do
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
local CargoVisual = require(script.Parent.Services.CargoVisualService)
local function cargoVisual(player)
    local cargo = rocket.cargo[player.UserId]
    CargoVisual.update(player.Character, cargo and cargo.materials, MATERIAL_COLORS)
end
local motion, lastAction = {}, {}
local training
local deadline = 0
local boarded = {}
local profiles
local holds = require(script.Parent.Services.HoldService).new(Config.MaterialHoldSeconds)
local lastReject = {}
local function feedback(player, message, rejection)
    feedbackEvent:FireClient(player, message)
    if rejection and os.clock() - (lastReject[player.UserId] or -math.huge) >= 5 then
        lastReject[player.UserId] = os.clock()
        warn("Rocket rejected interaction", player.UserId, rejection)
    end
end
local function speed(profile)
    return math.min(Config.MaxSpeed, Config.BaseSpeed + (profile.speedLevel + profile.planetBonuses.speed) * Config.SpeedPerLevel)
end
local function capacity(profile)
    return math.min(Config.MaxCapacity, Config.BaseCarryCapacity
        + math.floor((profile.strengthLevel + profile.planetBonuses.strength) / Config.StrengthPerCarry))
end
local function updateStats(player)
    local record = profiles.records[player.UserId]
    if not record then return end
    local profile = record.profile
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = speed(profile) end
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        stats.CompletedLaunches.Value = profile.completedLaunches
        stats.LifetimeDeliveries.Value = profile.lifetimeDeliveries
    end
end
local function send(player)
    local record = profiles.records[player.UserId]
    local profile = record and record.profile
    local definition = rocket.definition
    stateEvent:FireClient(player, {
        phase = rocket.phase, deadline = deadline,
        cycle = rocket.cycleNumber, cycleCount = Cycles.Count, tierName = definition.Tier.Name,
        modelTier = definition.ModelTier, variant = definition.Variant, isFinal = definition.IsFinalCycle,
        programRuns = rocket.programRuns, nextTierIn = Cycles.launchesUntilNextTier(rocket.cycleNumber),
        totals = table.clone(rocket.totals), required = rocket.required,
        cargo = rocket.cargo[player.UserId], contribution = rocket.contributions[player.UserId] or 0,
        boarded = boarded[player.UserId] == true, passenger = rocket.passengers[player.UserId] == true,
        profile = profile and { strength = profile.strengthLevel + profile.planetBonuses.strength, speed = profile.speedLevel + profile.planetBonuses.speed, completedLaunches = profile.completedLaunches, lifetimeDeliveries = profile.lifetimeDeliveries, walkSpeed = speed(profile), capacity = capacity(profile) },
        saveStatus = record and record.status or "Loading",
        persistent = Config.PersistenceEnabled,
        training = training and training.sessions[player.UserId] and training.sessions[player.UserId].station.name,
    })
end
local function broadcast()
    for _, player in Players:GetPlayers() do send(player) end
end
profiles = Profiles.new(Config, function(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player then updateStats(player); send(player) end
end)

local function finite(vector)
    return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z and vector.Magnitude < 1e7
end
local function body(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or not finite(root.Position) then return nil end
    return root, humanoid
end
local function observed(player)
    local root = body(player)
    if not root then return nil end
    local sample = motion[player.UserId]
    if not sample or sample.root ~= root or os.clock() < sample.blockedUntil then return nil end
    -- Check again in the interaction handler, covering the gap between samples.
    local delta = root.Position - sample.position
    local elapsed = math.max(0, os.clock() - sample.time)
    if Vector3.new(delta.X, 0, delta.Z).Magnitude > Config.MaxSpeed * elapsed + 3 then return nil end
    return root
end
local function near(player, object)
    local root = observed(player)
    return not (training and training.sessions[player.UserId]) and profiles:ready(player.UserId) and root and object:IsA("BasePart") and object.Anchored and object:IsDescendantOf(world) and (root.Position - object.Position).Magnitude <= Config.InteractionDistance
end
local function insideBoarding(player)
    local root = observed(player)
    if not root or not profiles:ready(player.UserId) then return false end
    local localPosition = boarding.CFrame:PointToObjectSpace(root.Position)
    return math.abs(localPosition.X) <= boarding.Size.X / 2 and math.abs(localPosition.Z) <= boarding.Size.Z / 2 and localPosition.Y >= 0 and localPosition.Y <= 9
end
local function allowed(player, action)
    local now = os.clock()
    local history = lastAction[player.UserId] or {}
    lastAction[player.UserId] = history
    if now - (history[action] or -math.huge) < Config.ActionCooldown then return false end
    history[action] = now
    return true
end
local function relocate(player, position)
    local root = body(player)
    if not root then return end
    player.Character:PivotTo(CFrame.new(position))
    root.AssemblyLinearVelocity = Vector3.zero
    motion[player.UserId] = { root = root, position = root.Position, safe = root.CFrame, time = os.clock(), blockedUntil = os.clock() + 0.5 }
end
local depotPrompts, placePrompts = {}, {}
-- Moves the ring and its prompt to the current fill point; hidden outside delivery phases.
local function updateFrontier()
    local material = Rocket.PhaseMaterial[rocket.phase]
    local cframe, diameter, points = rocketBuild:frontier(PLACE_POINTS)
    local active = material ~= nil and cframe ~= nil
    frontierSign.Enabled = active
    frontier.Transparency = active and 0.55 or 1
    for index, item in placePrompts do
        item.Enabled = active
        if active then item.Parent.WorldPosition = points[index] end
    end
    if not active then return end
    frontier.CFrame, frontier.Size = cframe, Vector3.new(0.4, diameter, diameter)
    frontier.Color = MATERIAL_COLORS[material]
end
-- Only the material the current phase needs can be picked up or placed.
local function refreshPrompts()
    local material = Rocket.PhaseMaterial[rocket.phase]
    for kind, items in depotPrompts do
        for _, item in items do item.Enabled = material == kind end
    end
    for _, item in placePrompts do item.ActionText = "Place " .. (material or "materials") end
    updateFrontier()
end
local function announce(message)
    for _, player in Players:GetPlayers() do feedback(player, message) end
end
local function beginBoarding()
    local definition = rocket.definition
    local tier = definition.Tier
    deadline = workspace:GetServerTimeNow() + tier.BoardingSeconds
    -- Lift anyone standing on the hull down to the boarding pad before it swings up.
    for _, player in Players:GetPlayers() do
        local root = body(player)
        if root and root.Position.Y - boarding.Position.Y > 5 and rocketBuild:isAboard(root.Position) then
            relocate(player, boarding.Position + Vector3.new(0, 4, 0))
        end
    end
    rocketBuild:erect(workspace:GetServerTimeNow(), Config.ErectSeconds)
    refreshPrompts()
    announce(definition.IsFinalCycle and "FINAL MISSION READY! Board the " .. tier.Name .. " now!" or "ROCKET READY! Board now: launch countdown started.")
    broadcast()
    local cycle = rocket.cycle
    task.delay(tier.BoardingSeconds, function()
        if rocket.cycle ~= cycle or rocket.phase ~= "Boarding" then return end
        local passengers = {}
        for _, player in Players:GetPlayers() do
            if insideBoarding(player) then passengers[player.UserId] = true end
        end
        if not rocket:lockPassengers(passengers) then return end
        boarded = passengers
        -- Mark passengers before stamping LaunchAt so clients pick the ride camera.
        for userId in passengers do
            local player = Players:GetPlayerByUserId(userId)
            if player then
                player:SetAttribute("RocketPassenger", true)
                local root = body(player)
                if root then root.Anchored = true end
            end
        end
        local launchAt = workspace:GetServerTimeNow()
        deadline = launchAt + tier.LaunchSeconds
        rocketBuild:launch(launchAt, tier, definition.IsFinalCycle)
        broadcast()
        task.wait(tier.LaunchSeconds)
        rocket.phase = "Rewarding"
        local rewardSeconds = definition.RewardSeconds or Config.RewardSeconds
        local multiplier = definition.RewardMultiplier
        deadline = workspace:GetServerTimeNow() + rewardSeconds
        for userId in rocket.passengers do

            local player = Players:GetPlayerByUserId(userId)
            if player then
                local root = body(player)
                if root then root.Anchored = false end
                relocate(player, planet.Position + Vector3.new(0, 6, 0))
            end
        end
        if definition.IsFinalCycle then
            announce("SPACE PROGRAM COMPLETE! All " .. Cycles.Count .. " rockets launched. A new program begins soon.")
        end
        broadcast()
        -- Cumulative tick counts are idempotent even when a save retries; the
        -- multiplier scales the ticks so the ledger stays an integer total.
        for tick = 1, rewardSeconds do
            task.wait(1)
            for userId in rocket.passengers do
                profiles:queueReward(userId, cycle, tick * multiplier)
                local player = Players:GetPlayerByUserId(userId)
                if player then feedback(player, "Meadows +" .. Config.Planet.StrengthBonus * multiplier .. " strength / +" .. Config.Planet.SpeedBonus * multiplier .. " speed (" .. tick .. "/" .. rewardSeconds .. ")") end
            end
            broadcast()
        end
        rocket.phase = "Resetting"
        deadline = 0
        broadcast()
        for userId in rocket.passengers do
            local player = Players:GetPlayerByUserId(userId)
            if player then
                player:SetAttribute("RocketPassenger", nil)
                relocate(player, spawn.Position + Vector3.new(0, 5, 0))
            end
        end
        task.wait(1)
        -- Shared progression only: profiles (stats, launches, unlocks) are untouched.
        rocket = rocket:nextCycle(HttpService:GenerateGUID(false))
        loadRocket()
        expandMap(rocket.cycleNumber)

        for _, player in Players:GetPlayers() do cargoVisual(player) end
        boarded = {}
        refreshPrompts()
        local upcoming = rocket.definition
        if upcoming.Variant == 1 and upcoming.Number > 1 then
            announce("NEW ROCKET DESIGN: " .. upcoming.Tier.Name .. "! Cycle " .. upcoming.Number .. "/" .. Cycles.Count)
        elseif upcoming.Number == 1 and rocket.programRuns > 0 then
            announce("A new space program begins! Cycle 1/" .. Cycles.Count)
        end
        broadcast()
    end)
end

local function materialNear(player, object)
    local root = observed(player)
    if not root or not profiles:ready(player.UserId) or (training and training.sessions[player.UserId]) then return false end
    if not Rocket.PhaseMaterial[rocket.phase] then return false end
    local point = object.CFrame:PointToObjectSpace(root.Position)
    local half = object.Size / 2
    local closest = Vector3.new(math.clamp(point.X, -half.X, half.X), math.clamp(point.Y, -half.Y, half.Y), math.clamp(point.Z, -half.Z, half.Z))
    return (point - closest).Magnitude <= (object == frontier and Config.FrontierReach or Config.InteractionDistance)
end
local materialTargets, materialCallbacks = {}, {}
local materialHold = Instance.new("RemoteEvent")
materialHold.Name = "MaterialHold"
materialHold.Parent = remotes
-- `point` (an attachment) places the prompt somewhere on a large object; range is
-- still checked against the whole object.
local function holdPrompt(object, action, callback, point)
    local item = prompt(object, action, Config.MaterialHoldSeconds)
    if point then
        item.Parent = point
        -- A station has many prompt points; show only the nearest one.
        item.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    end
    materialTargets[item], materialCallbacks[item] = object, callback
    return item
end
-- One unit moves per MaterialHoldSeconds. Each callback returns false to end the hold.
local lastTransfer, sendSoon = {}, {}
local function stepHold(player, entry, now)
    if now - entry.started < Config.MaterialHoldSeconds then return end
    -- Catch up at most one missed tick so a stalled frame can't burst transfers.
    entry.started = math.max(entry.started + Config.MaterialHoldSeconds, now - Config.MaterialHoldSeconds)
    lastTransfer[player.UserId] = now
    if not materialCallbacks[entry.target](player) then holds:cancel(player.UserId) end
end
materialHold.OnServerEvent:Connect(function(player, item, holding)
    if holding == false then
        holds:cancel(player.UserId)
        return
    end
    local object = materialTargets[item]
    if holding ~= true or not object or not item.Enabled or not materialNear(player, object) then return end
    local entry = holds.active[player.UserId]
    if entry and entry.target == item and entry.cycle == rocket.cycle then return end
    -- A press moves a unit right away so taps count; spacing from the last transfer
    -- keeps spam-tapping at the same rate as holding.
    local now = os.clock()
    holds:begin(player.UserId, item, rocket.cycle, math.max(lastTransfer[player.UserId] or -math.huge, now - Config.MaterialHoldSeconds))
    stepHold(player, holds.active[player.UserId], now)
end)
-- Strength raises carry capacity, so stronger players make fewer trips.
for material, station in materialStations do
    local function pickup(player)
        local amount = rocket:pickup(player.UserId, material, capacity(profiles.records[player.UserId].profile), 1)
        if amount == 0 then
            feedback(player, "Cargo full: carry it up to the glowing ring on the rocket.")
            return false
        end
        cargoVisual(player)
        sendSoon[player.UserId] = true
        return true
    end
    depotPrompts[material] = {}
    for _, point in station.points do
        table.insert(depotPrompts[material], holdPrompt(station.zone, "Pick up " .. material, pickup, point))
    end
end
local broadcastSoon = false
-- Shared by player deliveries and the Studio debug hook.
local function delivered(advanced)
    rocketBuild:setProgress(rocket:progress("Metal"), rocket:progress("Fuel"))
    updateFrontier()
    if not advanced then broadcastSoon = true; return end
    if rocket.phase == "Fueling" then
        for _, player in Players:GetPlayers() do cargoVisual(player) end
        refreshPrompts()
        announce("ROCKET BUILT! Carry Fuel up and pour it into the tanks.")
        broadcast()
    else
        beginBoarding()
    end
end
-- Pouring scales with carry capacity so any full ball empties in ~PourSeconds;
-- a base 10-unit ball still moves one unit per tick.
local function place(player)
    local material = Rocket.PhaseMaterial[rocket.phase]
    local pour = math.ceil(capacity(profiles.records[player.UserId].profile) * Config.MaterialHoldSeconds / Config.PourSeconds)
    local amount, advanced = rocket:deliver(player.UserId, math.max(1, pour))
    if amount == 0 then
        feedback(player, material == "Fuel" and "Fill up on Fuel at the OIL REFINERY first."
            or "Pick up Metal at the SCRAP PIT first.")
        return false
    end
    cargoVisual(player)
    profiles.records[player.UserId].profile.lifetimeDeliveries += amount
    profiles:dirty(player.UserId)
    updateStats(player)
    local emptied = rocket.cargo[player.UserId] == nil
    if emptied then feedback(player, material .. " placed! Your deliveries this cycle: " .. (rocket.contributions[player.UserId] or 0)) end
    delivered(advanced)
    return not (emptied or advanced)
end
-- Several prompt points span the fill line; the nearest one shows, so players can
-- place anywhere along the rocket's lowest level instead of aiming at one spot.
for _ = 1, PLACE_POINTS do
    local point = Instance.new("Attachment")
    point.Name = "PlacePoint"
    point.Parent = frontier
    local item = holdPrompt(frontier, "Place Metal", place, point)
    item.ObjectText = "Rocket"
    item.MaxActivationDistance = Config.FrontierReach
    table.insert(placePrompts, item)
end
refreshPrompts()
if RunService:IsStudio() then
    -- Studio-only playtest hook: Invoke("fill", fraction) adds that share of the current
    -- phase's requirement; Invoke("cycle", n) jumps to cycle n while building.
    local debugHook = Instance.new("BindableFunction")
    debugHook.Name = "RocketDebug"
    debugHook.OnInvoke = function(action, value)
        local material = Rocket.PhaseMaterial[rocket.phase]
        if action == "fill" and material then
            local amount = math.max(1, math.ceil(rocket.required[material] * (value or 1)))
            rocket.cargo[0] = { count = amount, materials = { [material] = amount } }
            local _, advanced = rocket:deliver(0)
            rocket.cargo[0] = nil
            delivered(advanced)
        elseif action == "cycle" and material then
            rocket = Rocket.new(Config, HttpService:GenerateGUID(false), value, rocket.programRuns)
            loadRocket()
            expandMap(rocket.cycleNumber)
            for _, player in Players:GetPlayers() do cargoVisual(player) end
            refreshPrompts()
            broadcast()
        end
        return rocket.cycleNumber, rocket.phase, rocket.totals.Metal, rocket.totals.Fuel
    end
    debugHook.Parent = script
end
-- Repeat on the server while the prompt button remains held.
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for userId, entry in holds.active do
        local player = Players:GetPlayerByUserId(userId)
        local target = materialTargets[entry.target]
        if not player or not target or not entry.target.Enabled or entry.cycle ~= rocket.cycle
            or not materialNear(player, target) then
            holds:cancel(userId)
        else
            stepHold(player, entry, now)
        end
    end
end)
local discardCargo = Instance.new("RemoteEvent")
discardCargo.Name = "DiscardCargo"
discardCargo.Parent = remotes
discardCargo.OnServerEvent:Connect(function(player)
    if not allowed(player, "discard") or not rocket.cargo[player.UserId] then return end
    rocket.cargo[player.UserId] = nil
    cargoVisual(player)
    feedback(player, "Cargo cleared. Pick up another material.")
    send(player)
end)
training = require(script.Parent.Services.TrainingService).new({
    players = Players, config = Config, profiles = profiles, remotes = remotes,
    prompt = prompt, allowed = allowed, near = near, body = body, relocate = relocate,
    feedback = feedback, changed = function(player) updateStats(player); send(player) end,
    phaseAllowed = function() return rocket.phase == "Building" or rocket.phase == "Fueling" or rocket.phase == "Boarding" end,
    stations = stations,
})
local function joined(player)
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    for _, name in { "CompletedLaunches", "LifetimeDeliveries" } do
        local value = Instance.new("IntValue")
        value.Name = name
        value.Parent = stats
    end
    stats.Parent = player
    local function characterAdded(character)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or player.Character ~= character then return end
        motion[player.UserId] = { root = root, position = root.Position, safe = root.CFrame, time = os.clock(), blockedUntil = os.clock() + 1 }
        updateStats(player)
        cargoVisual(player)
        if rocket.phase == "Rewarding" and rocket.passengers[player.UserId] then relocate(player, planet.Position + Vector3.new(0, 6, 0)) end
    end
    player.CharacterAdded:Connect(characterAdded)
    if player.Character then task.spawn(characterAdded, player.Character) end
    profiles:load(player.UserId)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    holds:cancel(player.UserId)
    training.stop(player)
    rocket:forget(player.UserId)
    if rocket.phase == "Boarding" then boarded[player.UserId] = nil end
    motion[player.UserId], lastAction[player.UserId] = nil, nil
    lastReject[player.UserId] = nil
    lastTransfer[player.UserId], sendSoon[player.UserId] = nil, nil
    profiles:remove(player.UserId)
end)
for _, player in Players:GetPlayers() do task.spawn(joined, player) end
requestState.OnServerEvent:Connect(function(player)
    if allowed(player, "snapshot") then send(player) end
end)
profiles:start()

local sampleElapsed, broadcastElapsed = 0, 0
RunService.Heartbeat:Connect(function(dt)
    sampleElapsed += dt
    broadcastElapsed += dt
    if sampleElapsed < 0.2 then return end
    sampleElapsed = 0
    training.tick(os.clock())
    local now = os.clock()
    for _, player in Players:GetPlayers() do
        local root = body(player)
        local sample = motion[player.UserId]
        if root and sample and sample.root == root then
            local delta = root.Position - sample.position
            if Vector3.new(delta.X, 0, delta.Z).Magnitude > Config.MaxSpeed * (now - sample.time) + 3 then
                root.CFrame = sample.safe
                root.AssemblyLinearVelocity = Vector3.zero
                sample.blockedUntil = now + 2

            end
            sample.position, sample.safe, sample.time = root.Position, root.CFrame, now

        end
        if rocket.phase == "Boarding" then boarded[player.UserId] = insideBoarding(player) end
    end
    -- Deliveries request a broadcast; batching keeps 50-player servers to <=4 sends/s each.
    if broadcastElapsed >= 1 or (broadcastSoon and broadcastElapsed >= 0.25) then
        broadcastElapsed, broadcastSoon = 0, false
        table.clear(sendSoon)
        broadcast()
    end
    -- Pickups tick 20x/s; batch each player's HUD refresh to the sample rate.
    for userId in sendSoon do
        local player = Players:GetPlayerByUserId(userId)
        if player then send(player) end
    end
    table.clear(sendSoon)
end)
