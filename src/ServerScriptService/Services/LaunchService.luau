-- Boarding countdown, passenger lock, launch, destination reward and the move to the
-- next cycle. During boarding, stepping on the rocket's BOARD hatch takes you into the
-- cabin (the inside of the rocket, DestinationService); its exit hatch lets you out
-- until liftoff. Everyone in the cabin when the countdown ends flies to the design's
-- destination (Config.Destinations by ModelTier), gets the per-second bonus there,
-- then returns to spawn. WheelLeadSeconds before the stay ends the server spins the
-- mission wheel (Shared.Missions) for everyone; the next rocket is the result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Missions = require(ReplicatedStorage.Shared.Missions)
local Launch = {}

function Launch.new(ctx)
    local config, World, Remote, Movement, Cycle = ctx.config, ctx.World, ctx.Remote, ctx.Movement, ctx.Cycle
    local boarding, spawn, rocketBuild, cabin = World.boarding, World.spawn, World.rocketBuild, World.cabin
    local service = {}
    local random = Random.new()
    -- Spins once per stay: stamps Cycle.wheel (clients animate it in sync), updates
    -- the pity counter and announces the result when the wheel stops.
    local function spinWheel(rocket)
        local weights = Missions.weights(Cycle.misses)
        local result, pity = Missions.spin(random, Cycle.misses)
        Cycle.misses = Missions.afterSpin(Cycle.misses, result)
        rocket.nextMission = result
        local mission = Missions.get(result)
        -- `offset` (0..1 within the winning slice) makes every client's wheel stop on the same spot.
        Cycle.wheel = { result = result, mission = mission.Id, rarity = mission.Rarity, pity = pity, weights = weights,
            offset = random:NextNumber(0.2, 0.8), startAt = workspace:GetServerTimeNow(), seconds = config.WheelSpinSeconds }
        Cycle.broadcast()
        task.delay(config.WheelSpinSeconds, function()
            Remote.announce("NEXT MISSION: " .. config.Destinations[result].name .. "! (" .. mission.Rarity:upper() .. ")")
        end)
    end
    -- Spread arrivals so a full server doesn't land in one stack.
    local function spread(position, radius)
        local angle, distance = math.random() * math.pi * 2, math.random() * radius
        return position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    end
    local function destination()
        return World.destinations[Cycle.rocket.definition.ModelTier]
    end
    function service.onHatch(player)
        local root = Movement.observed(player)
        if not root or not ctx.profiles:ready(player.UserId) then return false end
        local localPosition = boarding.CFrame:PointToObjectSpace(root.Position)
        return math.abs(localPosition.X) <= boarding.Size.X / 2 and math.abs(localPosition.Z) <= boarding.Size.Z / 2 and localPosition.Y >= 0 and localPosition.Y <= 9
    end
    -- Inside the cabin box. Uses the raw body: a just-teleported player still counts.
    function service.inCabin(player)
        local root = Movement.body(player)
        if not root or not ctx.profiles:ready(player.UserId) then return false end
        local offset = root.Position - cabin.center
        return math.abs(offset.X) <= cabin.size.X / 2 and math.abs(offset.Z) <= cabin.size.Z / 2 and offset.Y >= -2 and offset.Y <= cabin.size.Y + 2
    end
    function service.trackBoarding(player)
        if Cycle.rocket.phase ~= "Boarding" then return end
        if not service.inCabin(player) and service.onHatch(player) then
            Movement.relocate(player, spread(cabin.arrival, 6))
            Remote.feedback(player, "You're aboard! Liftoff when the countdown ends. Use the hatch to get out.")
        end
        Cycle.boarded[player.UserId] = service.inCabin(player)
    end
    -- Just outside the BOARD hatch, on the side away from the rocket.
    local function besideHatch()
        local away = boarding.Position - rocketBuild.origin.Position
        away = Vector3.new(away.X, 0, away.Z)
        away = away.Magnitude > 0.1 and away.Unit or Vector3.zAxis
        return boarding.Position + away * (boarding.Size.Z / 2 + 6) + Vector3.new(0, 4, 0)
    end
    -- The exit hatch: back out in front of the BOARD hatch until liftoff.
    local exitPrompt = World.prompt(cabin.exit, "Leave rocket")
    exitPrompt.ObjectText = "Hatch"
    exitPrompt.Triggered:Connect(function(player)
        if Cycle.rocket.phase ~= "Boarding" or not service.inCabin(player) then return end
        Movement.relocate(player, besideHatch())
        Cycle.boarded[player.UserId] = false
        Cycle.send(player)
    end)

    function service.beginBoarding()
        local rocket = Cycle.rocket
        local definition = rocket.definition
        local tier = definition.Tier
        Cycle.deadline = workspace:GetServerTimeNow() + tier.BoardingSeconds
        -- Lift anyone standing on the hull down beside the hatch before it swings up.
        for _, player in Players:GetPlayers() do
            local root = Movement.body(player)
            if root and root.Position.Y - boarding.Position.Y > 5 and rocketBuild:isAboard(root.Position) then
                Movement.relocate(player, besideHatch())
            end
        end
        rocketBuild:erect(workspace:GetServerTimeNow(), config.ErectSeconds)
        ctx.Cargo.refreshPrompts()
        Remote.announce(definition.IsLegendary and "LEGENDARY MISSION READY! Board the " .. tier.Name .. " now!" or "ROCKET READY! Board now: launch countdown started.")
        Cycle.broadcast()
        local cycle = rocket.cycle
        task.delay(tier.BoardingSeconds, function()
            if Cycle.rocket.cycle ~= cycle or rocket.phase ~= "Boarding" then return end
            local passengers = {}
            for _, player in Players:GetPlayers() do
                if service.inCabin(player) then passengers[player.UserId] = true end
            end
            if not rocket:lockPassengers(passengers) then return end
            Cycle.boarded = passengers
            -- Anyone left in the cabin without a lock (profile not ready) goes home.
            for _, player in Players:GetPlayers() do
                if not passengers[player.UserId] and service.inCabin(player) then Movement.relocate(player, spawn.Position + Vector3.new(0, 5, 0)) end
            end
            -- Mark passengers before stamping LaunchAt so clients pick the ride camera.
            for userId in passengers do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    player:SetAttribute("RocketPassenger", true)
                    local root = Movement.body(player)
                    if root then root.Anchored = true end
                end
            end
            local launchAt = workspace:GetServerTimeNow()
            Cycle.deadline = launchAt + tier.LaunchSeconds
            rocketBuild:launch(launchAt, tier, definition.IsLegendary)
            Cycle.broadcast()
            task.wait(tier.LaunchSeconds)
            rocket.phase = "Rewarding"
            local rewardSeconds = definition.RewardSeconds or config.RewardSeconds
            local place = destination()
            -- Rarer destinations pay more (Config.Destinations reward x the mission's multiplier).
            local multiplier = definition.RewardMultiplier * place.reward
            for _, station in World.stations do
                if station.destination == definition.ModelTier then
                    local bonus = station.stat == "speedLevel" and config.Planet.SpeedBonus or config.Planet.StrengthBonus
                    station.gain = 2 * bonus * multiplier
                    station.part:SetAttribute("TrainingGain", station.gain)
                end
            end
            Cycle.deadline = workspace:GetServerTimeNow() + rewardSeconds
            for userId in rocket.passengers do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    local root = Movement.body(player)
                    if root then root.Anchored = false end
                    Movement.relocate(player, spread(place.arrival, 8))
                end
            end
            Cycle.broadcast()
            -- Cumulative tick counts are idempotent even when a save retries; the
            -- multiplier scales the ticks so the ledger stays an integer total.
            for tick = 1, rewardSeconds do
                task.wait(1)
                for userId in rocket.passengers do
                    ctx.profiles:queueReward(userId, cycle, tick * multiplier)
                    local player = Players:GetPlayerByUserId(userId)
                    if player then Remote.feedback(player, place.name .. " +" .. config.Planet.StrengthBonus * multiplier .. " strength / +" .. config.Planet.SpeedBonus * multiplier .. " speed (" .. tick .. "/" .. rewardSeconds .. ")") end
                end
                if rewardSeconds - tick == config.WheelLeadSeconds then spinWheel(rocket) end
                Cycle.broadcast()
            end
            rocket.phase = "Resetting"
            Cycle.deadline = 0
            Cycle.broadcast()
            for userId in rocket.passengers do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    player:SetAttribute("RocketPassenger", nil)
                    ctx.Training.stop(player)
                    Movement.relocate(player, spawn.Position + Vector3.new(0, 5, 0))
                end
            end
            task.wait(1)
            -- Shared progression only: profiles (stats, launches, unlocks) are untouched.
            Cycle.boarded = {}
            Cycle.replace(rocket:nextCycle(Cycle.newId(), rocket.nextMission))
            Cycle.wheel = nil
            Cycle.broadcast() -- clients banner the new mission
        end)
    end

    function service.characterAdded(player)
        local rocket = Cycle.rocket
        if rocket.phase == "Rewarding" and rocket.passengers[player.UserId] then Movement.relocate(player, spread(destination().arrival, 8)) end
    end
    function service.forget(player)
        if Cycle.rocket.phase == "Boarding" then Cycle.boarded[player.UserId] = nil end
    end
    return service
end
return Launch
