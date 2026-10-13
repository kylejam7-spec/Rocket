local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
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
    result.RequiresLineOfSight = true
    result.Parent = object
    table.insert(prompts, result)
    return result
end

part("Ground", Vector3.new(0, -1, 0), Vector3.new(150, 2, 130), Color3.fromRGB(62, 103, 72))
local spawn = part("Spawn", Vector3.new(0, 1, 36), Vector3.new(8, 1, 8), Color3.fromRGB(225, 230, 238), "SpawnLocation")
spawn.Neutral = true
label(spawn, "ROCKET • Train, gather, launch together")
local metal = part("Metal", Vector3.new(-24, 2, 12), Vector3.new(6, 4, 6), Color3.fromRGB(139, 166, 185))
label(metal, "METAL • Pick up a piece")
local delivery = part("Delivery", Vector3.new(0, 1, 4), Vector3.new(10, 2, 6), Color3.fromRGB(86, 174, 215))
label(delivery, "DELIVER • Shared rocket")
local boarding = part("BoardingZone", Vector3.new(0, 0.2, -12), Vector3.new(16, 0.4, 16), Color3.fromRGB(89, 210, 165))
label(boarding, "BOARD HERE • Stay on the green pad")
local rocketVisual = part("Rocket", Vector3.new(0, 9, -26), Vector3.new(6, 18, 6), Color3.fromRGB(235, 238, 244))
local rocketHome = rocketVisual.CFrame
local strengthStation = part("StrengthGym", Vector3.new(-26, 1, 38), Vector3.new(7, 2, 7), Color3.fromRGB(191, 94, 109))
local speedStation = part("SpeedGym", Vector3.new(26, 1, 38), Vector3.new(7, 2, 7), Color3.fromRGB(110, 115, 218))
local advanced = part("AdvancedGym", Vector3.new(-44, 1, 38), Vector3.new(7, 2, 7), Color3.fromRGB(225, 191, 98))
label(strengthStation, "STRENGTH • Hold to train")
label(speedStation, "SPEED • Hold to train")
label(advanced, "ADVANCED GYM • Requires 1 launch")
local planet = part("MeadowPlanet", Vector3.new(0, 2, -220), Vector3.new(65, 4, 65), Color3.fromRGB(113, 177, 95))
label(planet, "MEADOW • +1 permanent strength & speed")
world.Parent = workspace

local rocket = Rocket.new(Config, HttpService:GenerateGUID(false))
local motion, lastAction, holds, lastTraining = {}, {}, {}, {}
local deadline = 0
local boarded = {}
local profiles
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
        totals = table.clone(rocket.totals), required = Config.Materials,
        cargo = rocket.cargo[player.UserId], contribution = rocket.contributions[player.UserId] or 0,
        boarded = boarded[player.UserId] == true, passenger = rocket.passengers[player.UserId] == true,
        profile = profile and { strength = profile.strengthLevel + profile.planetBonuses.strength, speed = profile.speedLevel + profile.planetBonuses.speed, completedLaunches = profile.completedLaunches, lifetimeDeliveries = profile.lifetimeDeliveries, walkSpeed = speed(profile), capacity = capacity(profile) },
        saveStatus = record and record.status or "Loading",
        persistent = Config.PersistenceEnabled,
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
    return profiles:ready(player.UserId) and root and object:IsA("BasePart") and object.Anchored and object:IsDescendantOf(world) and (root.Position - object.Position).Magnitude <= Config.InteractionDistance
end
local function insideBoarding(player)
    local root = observed(player)
    if not root or not profiles:ready(player.UserId) then return false end
    local localPosition = boarding.CFrame:PointToObjectSpace(root.Position)
    return math.abs(localPosition.X) <= boarding.Size.X / 2 and math.abs(localPosition.Z) <= boarding.Size.Z / 2 and localPosition.Y >= 0 and localPosition.Y <= 8
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
        if item.Parent == metal or item.Parent == delivery then item.Enabled = false end
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
        TweenService:Create(rocketVisual, TweenInfo.new(Config.LaunchSeconds), { CFrame = rocketHome + Vector3.new(0, 90, 0) }):Play()
        task.wait(Config.LaunchSeconds)
        rocket.phase = "Rewarding"
        deadline = workspace:GetServerTimeNow() + Config.RewardSeconds
        for userId in rocket.passengers do
            profiles:queueReward(userId, cycle)
            local player = Players:GetPlayerByUserId(userId)
            if player then relocate(player, planet.Position + Vector3.new(0, 6, 0)) end
        end
        broadcast()
        task.wait(Config.RewardSeconds)
        rocket.phase = "Resetting"
        deadline = 0
        broadcast()
        for userId in rocket.passengers do
            local player = Players:GetPlayerByUserId(userId)
            if player then relocate(player, spawn.Position + Vector3.new(0, 5, 0)) end
        end
        task.wait(1)
        rocket = Rocket.new(Config, HttpService:GenerateGUID(false))
        rocketVisual.CFrame = rocketHome
        boarded = {}
        for _, item in prompts do item.Enabled = true end
        broadcast()
    end)
end

prompt(metal, "Pick up Metal").Triggered:Connect(function(player)
    if not allowed(player, "pickup") then return end
    if not near(player, metal) then feedback(player, "Move closer and wait for your profile to load.", "pickup proximity/profile"); return end
    if rocket:pickup(player.UserId, "Metal", capacity(profiles.records[player.UserId].profile)) then
        send(player)
    else feedback(player, "Your cargo is full, or all needed Metal is already delivered or being carried.") end
end)
prompt(delivery, "Deliver carried materials").Triggered:Connect(function(player)
    if not allowed(player, "deliver") then return end
    if not near(player, delivery) then feedback(player, "Move closer to the delivery pad.", "delivery proximity/profile"); return end
    local accepted = rocket:deliver(player.UserId)
    if accepted == 0 then feedback(player, "No carried material is needed right now."); return end
    profiles.records[player.UserId].profile.lifetimeDeliveries += accepted
    profiles:dirty(player.UserId)
    updateStats(player)
    if rocket.phase == "Boarding" then beginBoarding() else broadcast() end
end)

for _, station in { { part = strengthStation, stat = "strengthLevel", gain = 1 }, { part = speedStation, stat = "speedLevel", gain = 1 }, { part = advanced, stat = "strengthLevel", gain = 2, required = Config.AdvancedGymCompletions } } do
    local item = prompt(station.part, "Train (hold)", Config.TrainingSeconds)
    item.PromptButtonHoldBegan:Connect(function(player)
        if rocket.phase ~= "Building" and rocket.phase ~= "Boarding" then return end
        if not allowed(player, "trainStart") or not near(player, station.part) then return end
        holds[player.UserId] = { prompt = item, started = os.clock(), cycle = rocket.cycle }
    end)
    item.Triggered:Connect(function(player)
        local hold = holds[player.UserId]
        holds[player.UserId] = nil
        if rocket.phase ~= "Building" and rocket.phase ~= "Boarding" then return end
        if not hold or hold.prompt ~= item or hold.cycle ~= rocket.cycle or os.clock() - hold.started < Config.TrainingSeconds - 0.05 or not near(player, station.part) then
            feedback(player, "Stay beside the station and hold to train.", "training hold/proximity")
            return
        end
        local now = os.clock()
        if now - (lastTraining[player.UserId] or -math.huge) < Config.TrainingCooldown then feedback(player, "Rest a moment before training again."); return end
        local profile = profiles.records[player.UserId].profile
        if profile.completedLaunches < (station.required or 0) then feedback(player, "Complete your first launch to unlock the advanced gym."); return end
        lastTraining[player.UserId] = now
        profile[station.stat] = math.min(Config.MaxLevel, profile[station.stat] + station.gain)
        profiles:dirty(player.UserId)
        updateStats(player)
        send(player)
    end)
end

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
        if rocket.phase == "Rewarding" and rocket.passengers[player.UserId] then relocate(player, planet.Position + Vector3.new(0, 6, 0)) end
    end
    player.CharacterAdded:Connect(characterAdded)
    if player.Character then task.spawn(characterAdded, player.Character) end
    profiles:load(player.UserId)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    rocket:forget(player.UserId)
    if rocket.phase == "Boarding" then boarded[player.UserId] = nil end
    motion[player.UserId], lastAction[player.UserId], holds[player.UserId], lastTraining[player.UserId] = nil, nil, nil, nil
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
                holds[player.UserId] = nil
            end
            sample.position, sample.safe, sample.time = root.Position, root.CFrame, now
            local hold = holds[player.UserId]
            if hold and not near(player, hold.prompt.Parent) then holds[player.UserId] = nil end
        end
        if rocket.phase == "Boarding" then boarded[player.UserId] = insideBoarding(player) end
    end
    if broadcastElapsed >= 1 then broadcastElapsed = 0; broadcast() end
end)
