-- Boarding countdown, passenger lock, launch, planet reward and the move to the next cycle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cycles = require(ReplicatedStorage.Shared.RocketCycles)
local Launch = {}

function Launch.new(ctx)
    local config, World, Remote, Movement, Cycle = ctx.config, ctx.World, ctx.Remote, ctx.Movement, ctx.Cycle
    local boarding, planet, spawn, rocketBuild = World.boarding, World.planet, World.spawn, World.rocketBuild
    local service = {}
    local function planetArrival()
        return planet.Position + Vector3.new(0, 6, 0)
    end
    function service.insideBoarding(player)
        local root = Movement.observed(player)
        if not root or not ctx.profiles:ready(player.UserId) then return false end
        local localPosition = boarding.CFrame:PointToObjectSpace(root.Position)
        return math.abs(localPosition.X) <= boarding.Size.X / 2 and math.abs(localPosition.Z) <= boarding.Size.Z / 2 and localPosition.Y >= 0 and localPosition.Y <= 9
    end
    function service.trackBoarding(player)
        if Cycle.rocket.phase == "Boarding" then Cycle.boarded[player.UserId] = service.insideBoarding(player) end
    end

    function service.beginBoarding()
        local rocket = Cycle.rocket
        local definition = rocket.definition
        local tier = definition.Tier
        Cycle.deadline = workspace:GetServerTimeNow() + tier.BoardingSeconds
        -- Lift anyone standing on the hull down to the boarding pad before it swings up.
        for _, player in Players:GetPlayers() do
            local root = Movement.body(player)
            if root and root.Position.Y - boarding.Position.Y > 5 and rocketBuild:isAboard(root.Position) then
                Movement.relocate(player, boarding.Position + Vector3.new(0, 4, 0))
            end
        end
        rocketBuild:erect(workspace:GetServerTimeNow(), config.ErectSeconds)
        ctx.Cargo.refreshPrompts()
        Remote.announce(definition.IsFinalCycle and "FINAL MISSION READY! Board the " .. tier.Name .. " now!" or "ROCKET READY! Board now: launch countdown started.")
        Cycle.broadcast()
        local cycle = rocket.cycle
        task.delay(tier.BoardingSeconds, function()
            if Cycle.rocket.cycle ~= cycle or rocket.phase ~= "Boarding" then return end
            local passengers = {}
            for _, player in Players:GetPlayers() do
                if service.insideBoarding(player) then passengers[player.UserId] = true end
            end
            if not rocket:lockPassengers(passengers) then return end
            Cycle.boarded = passengers
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
            rocketBuild:launch(launchAt, tier, definition.IsFinalCycle)
            Cycle.broadcast()
            task.wait(tier.LaunchSeconds)
            rocket.phase = "Rewarding"
            local rewardSeconds = definition.RewardSeconds or config.RewardSeconds
            local multiplier = definition.RewardMultiplier
            Cycle.deadline = workspace:GetServerTimeNow() + rewardSeconds
            for userId in rocket.passengers do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    local root = Movement.body(player)
                    if root then root.Anchored = false end
                    Movement.relocate(player, planetArrival())
                end
            end
            if definition.IsFinalCycle then
                Remote.announce("SPACE PROGRAM COMPLETE! All " .. Cycles.Count .. " rockets launched. A new program begins soon.")
            end
            Cycle.broadcast()
            -- Cumulative tick counts are idempotent even when a save retries; the
            -- multiplier scales the ticks so the ledger stays an integer total.
            for tick = 1, rewardSeconds do
                task.wait(1)
                for userId in rocket.passengers do
                    ctx.profiles:queueReward(userId, cycle, tick * multiplier)
                    local player = Players:GetPlayerByUserId(userId)
                    if player then Remote.feedback(player, "Meadows +" .. config.Planet.StrengthBonus * multiplier .. " strength / +" .. config.Planet.SpeedBonus * multiplier .. " speed (" .. tick .. "/" .. rewardSeconds .. ")") end
                end
                Cycle.broadcast()
            end
            rocket.phase = "Resetting"
            Cycle.deadline = 0
            Cycle.broadcast()
            for userId in rocket.passengers do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    player:SetAttribute("RocketPassenger", nil)
                    Movement.relocate(player, spawn.Position + Vector3.new(0, 5, 0))
                end
            end
            task.wait(1)
            -- Shared progression only: profiles (stats, launches, unlocks) are untouched.
            Cycle.boarded = {}
            Cycle.replace(rocket:nextCycle(Cycle.newId()))
            local upcoming = Cycle.rocket.definition
            if upcoming.Variant == 1 and upcoming.Number > 1 then
                Remote.announce("NEW ROCKET DESIGN: " .. upcoming.Tier.Name .. "! Cycle " .. upcoming.Number .. "/" .. Cycles.Count)
            elseif upcoming.Number == 1 and Cycle.rocket.programRuns > 0 then
                Remote.announce("A new space program begins! Cycle 1/" .. Cycles.Count)
            end
            Cycle.broadcast()
        end)
    end

    function service.characterAdded(player)
        local rocket = Cycle.rocket
        if rocket.phase == "Rewarding" and rocket.passengers[player.UserId] then Movement.relocate(player, planetArrival()) end
    end
    function service.forget(player)
        if Cycle.rocket.phase == "Boarding" then Cycle.boarded[player.UserId] = nil end
    end
    return service
end
return Launch
