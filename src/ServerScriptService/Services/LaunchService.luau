-- Boarding countdown, passenger lock, launch, destination reward and the move to the
-- next cycle. During boarding, walking up the boarding station's ramp and into its lit
-- BOARD door (BoardingStation) takes you into the cabin (the inside of the rocket,
-- DestinationService); its exit hatch lets you out until liftoff. Anyone who leaves the
-- cabin any other way (a fast runner can slip through a wall) is put straight back. Everyone in the cabin when the countdown ends flies to the design's
-- destination (Config.Destinations by ModelTier): the ascent, then a copy of the
-- rocket descends onto the destination's landing spot (both client-animated, with
-- the passengers watching), and stays there for the reward stay. Passengers get the
-- per-second bonus there, then return to spawn. WheelLeadSeconds before the stay ends the server spins the
-- mission wheel (Shared.Missions) for everyone; the next rocket is the result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Missions = require(ReplicatedStorage.Shared.Missions)
local Launch = {}
-- The landed rocket stands this long, dust settling, before passengers step out.
local TOUCHDOWN_HOLD = 1.5
-- The Black Hole's stay ends in a singularity: this many seconds before the stay ends
-- (just after the wheel stops) the hole starts swallowing the rocket, then the shard
-- with everyone on it (BlackHoleController draws it from the destination folder's
-- SingularityAt); the reset waits for the whole SingularityLength, then they wake at
-- spawn.
Launch.SingularitySeconds = 4
Launch.SingularityLength = 7.5
local BLACK_HOLE = 5
-- Europa's oarfish breaches this far into each stay: the server stamps OarfishAt on the
-- destination folder and every passenger's client plays it (OarfishController).
Launch.OarfishDelay = 20
local EUROPA = 3
-- Saturn's UFO comes round the platform this far into each stay and crashes on it
-- (UfoAt on the destination folder; UfoController).
Launch.UfoDelay = 35
local SATURN = 4
-- Mars's dust storm rolls in this far into each stay and blows over (StormAt on the
-- destination folder; DustStormController).
Launch.StormDelay = 25
local MARS = 2

function Launch.new(ctx)
    local config, World, Remote, Movement, Cycle = ctx.config, ctx.World, ctx.Remote, ctx.Movement, ctx.Cycle
    local boarding, spawn, rocketBuild, cabin = World.boarding, World.spawn, World.rocketBuild, World.cabin
    -- Studio playtests (DebugService "launch") may shorten the next countdown and stay:
    -- { countdown = seconds?, stay = seconds? }, cleared when that flight resets.
    local service = { debug = nil }
    -- Boarded this countdown and not since let out by the exit hatch (userId = true).
    local aboard = {}
    local random = Random.new()
    -- Spins once per stay: stamps Cycle.wheel (clients animate it in sync), updates
    -- the pity counter and announces the result when the wheel stops.
    local function spinWheel(rocket)
        local weights = Missions.weights(Cycle.misses)
        local result, pity = Missions.spin(random, Cycle.misses)
        -- A guaranteed mission (ShopService) replaces the roll; the pity counter moves as usual.
        local guaranteed = ctx.Shop and ctx.Shop.takeGuarantee()
        if guaranteed then result, pity = guaranteed, false end
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
    -- Whether the segment a..b (the trigger box's frame) passes through the box `half`.
    local function crosses(a, b, half)
        local enter, leave = 0, 1
        for _, axis in { "X", "Y", "Z" } do
            local from, step = a[axis], b[axis] - a[axis]
            if math.abs(step) < 1e-6 then
                if math.abs(from) > half[axis] then return false end
            else
                local t1, t2 = (-half[axis] - from) / step, (half[axis] - from) / step
                enter, leave = math.max(enter, math.min(t1, t2)), math.min(leave, math.max(t1, t2))
                if enter > leave then return false end
            end
        end
        return true
    end
    -- In the trigger box just in front of the BOARD door, or ran through it since the
    -- last sample (a late-game runner crosses it, and the door, between two samples).
    function service.onHatch(player)
        local root = Movement.observed(player)
        if not root or not ctx.profiles:ready(player.UserId) then return false end
        local half = boarding.Size / 2 + Vector3.new(0, 2, 0)
        local from, to = Movement.lastStep(player)
        local here = boarding.CFrame:PointToObjectSpace(root.Position)
        if math.abs(here.X) <= half.X and math.abs(here.Y) <= half.Y and math.abs(here.Z) <= half.Z then return true end
        return from ~= nil and crosses(boarding.CFrame:PointToObjectSpace(from), boarding.CFrame:PointToObjectSpace(to), half)
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
        if not service.inCabin(player) then
            if aboard[player.UserId] then
                -- Out of the cabin without the exit hatch: back in.
                Movement.relocate(player, spread(cabin.arrival, 6))
            elseif service.onHatch(player) then
                aboard[player.UserId] = true
                Movement.relocate(player, spread(cabin.arrival, 6))
                Remote.feedback(player, "You're aboard! Liftoff when the countdown ends. Use the hatch to get out.")
            end
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
        aboard[player.UserId] = nil
        Movement.relocate(player, besideHatch())
        Cycle.boarded[player.UserId] = false
        Cycle.send(player)
    end)

    function service.beginBoarding()
        local rocket = Cycle.rocket
        local definition = rocket.definition
        local tier = definition.Tier
        local countdown = service.debug and service.debug.countdown or tier.BoardingSeconds
        Cycle.deadline = workspace:GetServerTimeNow() + countdown
        -- Lift anyone standing on the hull or the ramps down beside the hatch before it
        -- swings up (the ramps retract).
        for _, player in Players:GetPlayers() do
            local root = Movement.body(player)
            if root and root.Position.Y - boarding.Position.Y > 5 and (rocketBuild:isAboard(root.Position) or rocketBuild:isOnRamps(root.Position)) then
                Movement.relocate(player, besideHatch())
            end
        end
        rocketBuild:erect(workspace:GetServerTimeNow(), config.ErectSeconds)
        aboard = {}
        ctx.Cargo.refreshPrompts()
        Remote.announce(definition.IsLegendary and "LEGENDARY MISSION READY! Board the " .. tier.Name .. " now!" or "ROCKET READY! Board now: launch countdown started.")
        Cycle.broadcast()
        local cycle = rocket.cycle
        task.delay(countdown, function()
            if Cycle.rocket.cycle ~= cycle or rocket.phase ~= "Boarding" then return end
            local passengers = {}
            for _, player in Players:GetPlayers() do
                if service.inCabin(player) then passengers[player.UserId] = true end
            end
            -- Boarded but outside the cabin this very tick (put back next tick): still flying.
            for userId in aboard do
                local player = Players:GetPlayerByUserId(userId)
                if player and not passengers[userId] and ctx.profiles:ready(userId) then
                    Movement.relocate(player, spread(cabin.arrival, 6))
                    passengers[userId] = true
                end
            end
            aboard = {}
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
            local flight = tier.LaunchSeconds + tier.LandingSeconds
            Cycle.deadline = launchAt + flight
            rocketBuild:launch(launchAt, tier, definition.IsLegendary)
            local place = destination()
            for _, other in World.destinations do
                local old = other.folder:FindFirstChild("LandedRocket")
                if old then old:Destroy() end
            end
            local landed = rocketBuild:landedCopy(place.landing, place.folder, {
                DescentAt = launchAt + tier.LaunchSeconds, DescentSeconds = tier.LandingSeconds - TOUCHDOWN_HOLD,
                CutsceneEnd = launchAt + flight, ExhaustScale = tier.ExhaustScale * (definition.IsLegendary and 1.3 or 1),
            })
            Cycle.broadcast()
            task.wait(flight)
            rocket.phase = "Rewarding"
            local rewardSeconds = service.debug and service.debug.stay or definition.RewardSeconds or config.RewardSeconds
            -- Rarer destinations pay more (Config.Destinations reward x the mission's multiplier).
            local multiplier = definition.RewardMultiplier * place.reward
            for _, station in World.stations do
                if station.destination == definition.ModelTier then
                    station.gain = config.Planet.GymGain * multiplier
                    station.part:SetAttribute("TrainingGain", station.gain)
                end
            end
            -- The stay can grow while it runs (ShopService ExtraStay moves the deadline too).
            local stay = ctx.Shop and ctx.Shop.beginStay(rewardSeconds) or { total = rewardSeconds, extra = 0 }
            Cycle.deadline = workspace:GetServerTimeNow() + stay.total
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
            -- Planet.TicksPerSecond ticks a second; the rest of the stay runs in seconds.
            local rate = config.Planet.TicksPerSecond
            local tick, spun, swallowed, breached, crashed, stormed = 0, false, false, false, false, false
            while tick < stay.total * rate do
                task.wait(1 / rate)
                tick += 1
                local elapsed, second = tick / rate, tick % rate == 0
                for userId in rocket.passengers do
                    local player = Players:GetPlayerByUserId(userId)
                    -- A suit makes the ride count for more launches (SkinService).
                    ctx.profiles:queueReward(userId, cycle, tick * multiplier, definition.ModelTier == BLACK_HOLE, player and ctx.Skins and ctx.Skins.multiplier(player))
                    if player and second then Remote.feedback(player, place.name .. " +" .. config.Planet.StrengthBonus * multiplier * rate .. " strength / +" .. config.Planet.SpeedBonus * multiplier * rate .. " speed (" .. elapsed .. "/" .. stay.total .. ")") end
                end
                if not spun and stay.total - elapsed <= config.WheelLeadSeconds then
                    spun = true
                    spinWheel(rocket)
                end
                -- The Black Hole's stay ends in the singularity, SingularitySeconds before
                -- its (possibly extended) end. It closes the stay for the shop, so time
                -- bought now goes to the next stay rather than this frozen one.
                if definition.ModelTier == BLACK_HOLE and not swallowed and stay.total - elapsed <= Launch.SingularitySeconds then
                    swallowed = true
                    if ctx.Shop then ctx.Shop.endStay() end
                    -- Hold everyone still while the hole takes them (their clients draw it).
                    for userId in rocket.passengers do
                        local player = Players:GetPlayerByUserId(userId)
                        local root = player and Movement.body(player)
                        if root then root.Anchored = true end
                    end
                    place.folder:SetAttribute("SingularityAt", workspace:GetServerTimeNow())
                end
                if definition.ModelTier == EUROPA and not breached and elapsed >= Launch.OarfishDelay then
                    breached = true
                    place.folder:SetAttribute("OarfishAt", workspace:GetServerTimeNow())
                end
                if definition.ModelTier == SATURN and not crashed and elapsed >= Launch.UfoDelay then
                    crashed = true
                    place.folder:SetAttribute("UfoAt", workspace:GetServerTimeNow())
                end
                if definition.ModelTier == MARS and not stormed and elapsed >= Launch.StormDelay then
                    stormed = true
                    place.folder:SetAttribute("StormAt", workspace:GetServerTimeNow())
                end
                if second then Cycle.broadcast() end
            end
            if ctx.Shop then ctx.Shop.endStay() end
            if definition.ModelTier == BLACK_HOLE then task.wait(Launch.SingularityLength - Launch.SingularitySeconds) end
            place.folder:SetAttribute("SingularityAt", nil)
            place.folder:SetAttribute("OarfishAt", nil)
            place.folder:SetAttribute("UfoAt", nil)
            place.folder:SetAttribute("StormAt", nil)
            service.debug = nil
            rocket.phase = "Resetting"
            Cycle.deadline = 0
            Cycle.broadcast()
            landed:Destroy()
            for userId in rocket.passengers do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    player:SetAttribute("RocketPassenger", nil)
                    ctx.Training.stop(player)
                    Movement.relocate(player, spawn.Position + Vector3.new(0, 5, 0))
                    local root = Movement.body(player)
                    if root then root.Anchored = false end
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
