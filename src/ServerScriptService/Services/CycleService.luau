-- Owns the current rocket (one mission) and replicates its snapshot to clients. Other
-- services read ctx.Cycle.rocket each time; replace() swaps in the next rocket.
-- Also holds the mission wheel: `wheel` is the current spin (sent to clients so they
-- animate it in sync) and `misses` the pity counter (spins in a row below Rare).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Missions = require(ReplicatedStorage.Shared.Missions)
local Rocket = require(script.Parent.RocketService)
local Cycle = {}

function Cycle.new(ctx)
    local config = ctx.config
    local service = { deadline = 0, boarded = {}, wheel = nil, misses = 0 }
    service.rocket = Rocket.new(config, HttpService:GenerateGUID(false), Missions.First, 0)
    local function loadRocket()
        local definition = service.rocket.definition
        local boarding = ctx.World.boarding
        boarding.CFrame, boarding.Size = ctx.World.rocketBuild:load(definition.ModelTier, definition.Variant)
        ctx.World.rocketBuild:setProgress(0, 0)
    end
    loadRocket()
    -- Installs the next cycle: rocket model, map expansion, cargo visuals and prompts.
    function service.replace(rocket)
        service.rocket = rocket
        loadRocket()
        -- The spaceport grows every three launches, up to four expansions.
        ctx.World.expandMap(math.min(rocket.launches + 1, 13))
        ctx.Cargo.refreshVisuals()
        ctx.Cargo.refreshPrompts()
    end
    function service.newId()
        return HttpService:GenerateGUID(false)
    end

    function service.send(player)
        local rocket, stats = service.rocket, ctx.Stats
        local record = ctx.profiles.records[player.UserId]
        local profile = record and record.profile
        local definition = rocket.definition
        local training = ctx.Training and ctx.Training.sessions[player.UserId]
        ctx.Remote.StateUpdated:FireClient(player, {
            phase = rocket.phase, deadline = service.deadline,
            cycle = rocket.launches + 1, tierName = definition.Tier.Name,
            destination = config.Destinations[definition.ModelTier].name, destinationTier = definition.ModelTier,
            modelTier = definition.ModelTier, mission = definition.Id, rarity = definition.Rarity, legendary = definition.IsLegendary,
            wheel = service.wheel, pityIn = math.max(0, Missions.PityAfter - service.misses),
            totals = table.clone(rocket.totals), required = rocket.required,
            cargo = rocket.cargo[player.UserId], contribution = rocket.contributions[player.UserId] or 0,
            boarded = service.boarded[player.UserId] == true, passenger = rocket.passengers[player.UserId] == true,
            profile = profile and { strength = profile.strengthLevel + profile.planetBonuses.strength, speed = profile.speedLevel + profile.planetBonuses.speed, completedLaunches = profile.completedLaunches, lifetimeDeliveries = profile.lifetimeDeliveries, coins = profile.coins, walkSpeed = stats.speed(profile), capacity = stats.capacity(profile),
                tutorialStep = profile.tutorialStep, seenCallouts = table.clone(profile.seenCallouts),
                upgrades = table.clone(profile.upgrades), rank = player:GetAttribute("Rank"),
                -- The UFO's pet stays secret until it lands.
                pets = table.clone(profile.pets), equippedPets = table.clone(profile.equippedPets),
                ufo = profile.ufo and { tier = profile.ufo.tier, hatchAt = workspace:GetServerTimeNow() + profile.ufo.remaining } },
            saveStatus = record and record.status or "Loading",
            persistent = config.PersistenceEnabled,
            training = training and training.station.name,
        })
    end
    function service.broadcast()
        for _, player in Players:GetPlayers() do service.send(player) end
    end
    -- Batched sends: deliveries request a broadcast; pickups mark one player's HUD.
    local broadcastSoon, sendSoon = false, {}
    function service.broadcastSoon() broadcastSoon = true end
    function service.sendSoon(player) sendSoon[player.UserId] = true end
    function service.forget(player) sendSoon[player.UserId] = nil end

    function service.start()
        ctx.Remote.RequestState.OnServerEvent:Connect(function(player)
            if ctx.Interaction.allowed(player, "snapshot") then service.send(player) end
        end)
        local sampleElapsed, broadcastElapsed = 0, 0
        RunService.Heartbeat:Connect(function(dt)
            sampleElapsed += dt
            broadcastElapsed += dt
            if sampleElapsed < 0.2 then return end
            sampleElapsed = 0
            ctx.Training.tick(os.clock())
            local now = os.clock()
            for _, player in Players:GetPlayers() do
                ctx.Movement.sample(player, now)
                ctx.Launch.trackBoarding(player)
                ctx.Tutorial.sample(player)
            end
            -- Deliveries request a broadcast; batching keeps 50-player servers to <=4 sends/s each.
            if broadcastElapsed >= 1 or (broadcastSoon and broadcastElapsed >= 0.25) then
                broadcastElapsed, broadcastSoon = 0, false
                table.clear(sendSoon)
                service.broadcast()
            end
            -- Pickups tick 20x/s; batch each player's HUD refresh to the sample rate.
            for userId in sendSoon do
                local player = Players:GetPlayerByUserId(userId)
                if player then service.send(player) end
            end
            table.clear(sendSoon)
        end)
    end
    return service
end
return Cycle
