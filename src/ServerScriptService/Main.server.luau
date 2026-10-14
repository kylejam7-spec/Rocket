local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Rocket = require(script.Parent.Services.RocketService)
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
    gui.Size = UDim2.fromOffset(260, 60)
    gui.StudsOffset = Vector3.new(0, 5, 0)
    gui.AlwaysOnTop = true
    gui.Parent = object
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0.3
    textLabel.TextSize = 18
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

local expandMap = require(script.Parent.Services.MapExpansionService).build(part, label)
local mapCycle = 1
expandMap(mapCycle)
local spawn = part("Spawn", Vector3.new(0, 1, 36), Vector3.new(8, 1, 8), Color3.fromRGB(225, 230, 238), "SpawnLocation")
spawn.Neutral = true
label(spawn, "ROCKET • Train, gather, launch together")
local metal = part("Metal", Vector3.new(-24, 2, 12), Vector3.new(6, 4, 6), Color3.fromRGB(139, 166, 185))
local fuel = part("Fuel", Vector3.new(24, 2, 12), Vector3.new(6, 4, 6), Color3.fromRGB(245, 182, 71))
label(metal, "METAL • Pick up a piece")
label(fuel, "FUEL • Pick up a canister")
-- Move the complete assembly together; rocket attributes remain unchanged.
local function rocketPart(name, position, size, color, className)
    return part(name, position + Vector3.new(0, 0, -88), size, color, className)
end
-- Horizontal, walkable chassis. Ghost hull slots become solid as players build.
local chassis = rocketPart("RocketChassis", Vector3.new(0, 1, -22), Vector3.new(38, 2, 12), Color3.fromRGB(70, 83, 103))
local boarding = rocketPart("CabinInterior", Vector3.new(0, 2.1, -22), Vector3.new(34, 0.2, 9), Color3.fromRGB(89, 210, 165))
boarding.Transparency = 0.35
boarding.CanCollide = false
label(chassis, "ROCKET TEMPLATE • Hold E at a matching outlined block")
local entrance = rocketPart("CabinEntrance", Vector3.new(-20, 0.5, -22), Vector3.new(4, 1, 9), Color3.fromRGB(89, 210, 165))
label(entrance, "BOARD INSIDE • Enter at this open end")
-- Permanent stairs let builders reach the roof without trapping the cabin entrance.
for index = 1, 6 do
    rocketPart("RoofStep" .. index, Vector3.new(-21 + index * 3, index, -32), Vector3.new(3, index * 2, 5), Color3.fromRGB(98, 111, 131))
end
local slots = {}
local function slot(id, material, position, size)
    local block = rocketPart(id, position, size, material == "Metal" and Color3.fromRGB(194, 211, 226) or Color3.fromRGB(245, 182, 71))
    block.Transparency = 0.78
    block.CanCollide = false
    block:SetAttribute("MaterialId", material)
    block:SetAttribute("Placed", false)
    local outline = Instance.new("SelectionBox")
    outline.Adornee = block
    outline.LineThickness = 0.05
    outline.Color3 = block.Color
    outline.Parent = block
    slots[id] = { part = block, material = material, outline = outline }
end
for index, x in {-9, 9} do
    slot("MetalLeft" .. index, "Metal", Vector3.new(x, 7, -28), Vector3.new(18, 10, 1))
    slot("MetalRight" .. index, "Metal", Vector3.new(x, 7, -16), Vector3.new(18, 10, 1))
    slot("MetalRoof" .. index, "Metal", Vector3.new(x, 12.5, -22), Vector3.new(18, 1, 13))
end
for index, z in {-27, -17} do
    slot("FuelEngine" .. index, "Fuel", Vector3.new(-20, 4, z), Vector3.new(4, 4, 3))
    slot("FuelNose" .. index, "Fuel", Vector3.new(20, 5, z), Vector3.new(4, 6, 3))
end
local nose = rocketPart("RocketNose", Vector3.new(22, 5, -22), Vector3.new(6, 8, 8), Color3.fromRGB(216, 91, 73), "WedgePart")
nose.CFrame = CFrame.new(nose.Position) * CFrame.Angles(0, math.rad(90), 0)
local frontWall = rocketPart("CabinFront", Vector3.new(18.5, 7, -22), Vector3.new(1, 10, 12), Color3.fromRGB(70, 83, 103))
local function resetTemplate()
    for _, item in slots do
        item.part.Transparency = 0.78
        item.part.CanCollide = false
        item.part:SetAttribute("Placed", false)
        item.outline.Visible = true
    end
end
local strengthStation = part("StrengthGym", Vector3.new(-26, 1, 38), Vector3.new(7, 2, 7), Color3.fromRGB(191, 94, 109))
local speedStation = part("SpeedGym", Vector3.new(26, 1, 38), Vector3.new(7, 2, 7), Color3.fromRGB(110, 115, 218))
label(strengthStation, "BENCH PRESS • E to train")
label(speedStation, "TREADMILL • E to train")
local planet = part("MeadowPlanet", Vector3.new(0, 2, -220), Vector3.new(65, 4, 65), Color3.fromRGB(113, 177, 95))
label(planet, "MEADOWS • +3 strength & speed / second for 30 seconds")
world.Parent = workspace

local rocket = Rocket.new(Config, HttpService:GenerateGUID(false))
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
for index, tier in Config.TrainingTiers do
    local x = (index - 3) * 24
    local color = tierColors[index]
    part("TrainingBay" .. tier.cycles, Vector3.new(x, 0.05, 56), Vector3.new(20, 0.1, 24), color)
    local sign = part("TrainingSign" .. tier.cycles, Vector3.new(x, 4, 69), Vector3.new(18, 5, 0.5), color)
    label(sign, "ADVANCED GYM • " .. tier.cycles .. " CYCLES\n+" .. tier.gain .. " strength / speed per second")
    for _, treadmill in {false, true} do
        local kind = treadmill and "Treadmill" or "Bench"
        local base = part("Advanced" .. kind .. tier.cycles,
            Vector3.new(x + (treadmill and 5 or -5), 1, 56), Vector3.new(7, 2, 7), color)
        equipment(base, treadmill)
        label(base, kind:upper() .. " • " .. tier.cycles .. " cycles • +" .. tier.gain .. "/s")
        table.insert(stations, { part = base, name = tier.cycles .. "-cycle " .. kind,
            stat = treadmill and "speedLevel" or "strengthLevel", gain = tier.gain, required = tier.cycles })
    end
end
local CargoVisual = require(script.Parent.Services.CargoVisualService)
local function cargoVisual(player)
    local cargo = rocket.cargo[player.UserId]
    CargoVisual.update(player.Character, cargo and cargo.materials, {Metal = metal.Color, Fuel = fuel.Color})
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
    return math.min(Config.MaxCapacity, 1 + math.floor((profile.strengthLevel + profile.planetBonuses.strength) / 5))
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
    stateEvent:FireClient(player, {
        phase = rocket.phase, cycle = rocket.cycle, deadline = deadline,
        totals = table.clone(rocket.totals), required = rocket.required, successfulLaunches = rocket.successfulLaunches, slotCost = rocket.slotCost,
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
local function beginBoarding()
    deadline = workspace:GetServerTimeNow() + Config.BoardingSeconds
    for _, item in prompts do
        if item.Parent == metal or item.Parent == fuel then item.Enabled = false end
    end
    broadcast()
    local cycle = rocket.cycle
    task.delay(Config.BoardingSeconds, function()
        if rocket.cycle ~= cycle or rocket.phase ~= "Boarding" then return end
        local passengers = {}
        for _, player in Players:GetPlayers() do
            if insideBoarding(player) then passengers[player.UserId] = true end
        end
        if not rocket:lockPassengers(passengers) then return end
        boarded = passengers
        deadline = workspace:GetServerTimeNow() + Config.LaunchSeconds
        broadcast()
        for userId in passengers do
            local player = Players:GetPlayerByUserId(userId)
            if player then
                local root = body(player)
                if root then root.Anchored = true end
            end
        end
        task.wait(Config.LaunchSeconds)
        rocket.phase = "Rewarding"
        deadline = workspace:GetServerTimeNow() + Config.RewardSeconds
        for userId in rocket.passengers do

            local player = Players:GetPlayerByUserId(userId)
            if player then
                local root = body(player)
                if root then root.Anchored = false end
                relocate(player, planet.Position + Vector3.new(0, 6, 0))
            end
        end
        broadcast()
        -- Cumulative tick counts are idempotent even when a save retries.
        for tick = 1, Config.RewardSeconds do
            task.wait(1)
            for userId in rocket.passengers do
                profiles:queueReward(userId, cycle, tick)
                local player = Players:GetPlayerByUserId(userId)
                if player then feedback(player, "Meadows +" .. Config.Planet.StrengthBonus .. " strength / +" .. Config.Planet.SpeedBonus .. " speed (" .. tick .. "/" .. Config.RewardSeconds .. ")") end
            end
            broadcast()
        end
        rocket.phase = "Resetting"
        deadline = 0
        broadcast()
        for userId in rocket.passengers do
            local player = Players:GetPlayerByUserId(userId)
            if player then relocate(player, spawn.Position + Vector3.new(0, 5, 0)) end
        end
        task.wait(1)
        rocket = rocket:nextCycle(HttpService:GenerateGUID(false))
        mapCycle += 1
        expandMap(mapCycle)

        for _, player in Players:GetPlayers() do cargoVisual(player) end
        resetTemplate()
        boarded = {}
        for _, item in prompts do item.Enabled = true end
        for _, data in slots do
            data.part:SetAttribute("MaterialsPlaced", 0)
            data.part:SetAttribute("MaterialsRequired", rocket.slotCost)
            data.prompt.ObjectText = data.material .. " section 0/" .. rocket.slotCost
        end
        broadcast()
    end)
end

local function materialNear(player, object)
    local root = observed(player)
    if not root or not profiles:ready(player.UserId) or (training and training.sessions[player.UserId]) then return false end
    if rocket.phase ~= "Building" then return false end
    local point = object.CFrame:PointToObjectSpace(root.Position)
    local half = object.Size / 2
    local closest = Vector3.new(math.clamp(point.X, -half.X, half.X), math.clamp(point.Y, -half.Y, half.Y), math.clamp(point.Z, -half.Z, half.Z))
    return (point - closest).Magnitude <= Config.InteractionDistance
end
local materialTargets, materialCallbacks = {}, {}
local materialHold = Instance.new("RemoteEvent")
materialHold.Name = "MaterialHold"
materialHold.Parent = remotes
local function holdPrompt(object, action, callback)
    local item = prompt(object, action, Config.MaterialHoldSeconds)
    materialTargets[item], materialCallbacks[item] = object, callback
    return item
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
    holds:begin(player.UserId, item, rocket.cycle, os.clock())
end)
for material, source in { Metal = metal, Fuel = fuel } do
    holdPrompt(source, "Pick up " .. material, function(player)
        if rocket:pickup(player.UserId, material, capacity(profiles.records[player.UserId].profile)) then
            cargoVisual(player)
            feedback(player, "Picked up " .. material .. ". Hold E at a matching rocket section.")
            send(player)
        else feedback(player, "Cargo full or this material is complete.") end
    end)
end
local function refreshSlot(id, data)
    local progress = rocket.slotProgress[id] or 0
    local complete = rocket.placedSlots[id] == true
    data.part.Transparency = complete and 0 or 0.78 - 0.4 * progress / rocket.slotCost
    data.part.CanCollide = complete
    data.part:SetAttribute("Placed", complete)
    data.part:SetAttribute("MaterialsPlaced", progress)
    data.part:SetAttribute("MaterialsRequired", rocket.slotCost)
    data.outline.Visible = not complete
    data.prompt.Enabled = rocket.phase == "Building" and not complete
    data.prompt.ObjectText = data.material .. " section " .. progress .. "/" .. rocket.slotCost
end
for id, data in slots do
    data.prompt = holdPrompt(data.part, "Place " .. data.material, function(player)
        if rocket:place(player.UserId, id, data.material) == 0 then
            feedback(player, "Carry " .. data.material .. " for this unfinished section.")
            return
        end
        refreshSlot(id, data)
        cargoVisual(player)
        profiles.records[player.UserId].profile.lifetimeDeliveries += 1
        profiles:dirty(player.UserId)
        updateStats(player)
        feedback(player, data.material .. " section: " .. rocket.slotProgress[id] .. "/" .. rocket.slotCost)
        if rocket.phase == "Boarding" then beginBoarding() else broadcast() end
    end)
    refreshSlot(id, data)
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
        elseif now - entry.started >= Config.MaterialHoldSeconds then
            entry.started = now
            materialCallbacks[entry.target](player)
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
    phaseAllowed = function() return rocket.phase == "Building" or rocket.phase == "Boarding" end,
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
    if broadcastElapsed >= 1 then broadcastElapsed = 0; broadcast() end
end)
