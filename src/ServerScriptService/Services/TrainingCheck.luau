-- Isolated checks: no real player profiles or world changes.
return function()
    local Training = require(script.Parent.TrainingService)
    local config = require(game.ReplicatedStorage.Shared.Config)
    local Shop = require(game.ReplicatedStorage.Shared.Shop)
    local remotes = Instance.new("Folder")
    local player = { UserId = -1, Character = {} }
    local root = { Parent = true, Position = Vector3.zero, Anchored = false, Size = Vector3.new(2, 2, 1) }
    local humanoid = { Health = 100, AutoRotate = true, Sit = false, PlatformStand = false, HipHeight = 2 }
    local profile = { completedLaunches = 0, strengthLevel = 0, speedLevel = 0 }
    local callbacks, stations = {}, {}
    local profiles = { records = {}, ready = function() return true end, dirty = function() end }
    for _, tier in config.TrainingTiers do
        for _, stat in {"strengthLevel", "speedLevel"} do
            table.insert(stations, {part = Instance.new("Part"), name = stat,
                stat = stat, gain = config.TrainingBaseGain * tier.multiplier, required = tier.cycles})
        end
    end
    local service = Training.new({
        config = config, remotes = remotes, stations = stations,
        players = { GetPlayerByUserId = function() return player end },
        profiles = profiles,
        prompt = function(part)
            return {Triggered = {Connect = function(_, callback) callbacks[part] = callback end}}
        end,
        allowed = function() return true end, near = function() return true end,
        phaseAllowed = function() return true end, body = function() return root, humanoid end,
        relocate = function(_, target) root.Position = typeof(target) == "CFrame" and target.Position or target end,
        feedback = function() end, changed = function() end,
    })
    local ok, failure = pcall(function()
        assert(#stations == 14)
        -- Tiers are in walking order: each needs more launches and pays more than the last.
        local expected = { {1, 2}, {3, 5}, {8, 10}, {15, 25}, {25, 50}, {50, 75}, {100, 100} }
        for index, tier in config.TrainingTiers do
            assert(tier.cycles == expected[index][1] and tier.multiplier == expected[index][2], "Gym tier table changed")
        end
        for _, station in stations do
            -- Use a different simulated player for each attempt to avoid exit cooldowns.
            player.UserId -= 1
            profiles.records[player.UserId] = {profile = profile}
            profile.completedLaunches = station.required - 1
            profile[station.stat] = 0
            callbacks[station.part](player)
            assert(not service.sessions[player.UserId], "Locked tier accepted training")
            profile.completedLaunches = station.required
            callbacks[station.part](player)
            local session = assert(service.sessions[player.UserId], "Exact milestone failed to unlock")
            assert(root.Anchored and not humanoid.AutoRotate)
            assert(humanoid.PlatformStand == (station.stat == "strengthLevel"), "Bench lies down, treadmill stands")
            assert(station.part:GetAttribute("Occupant_" .. player.UserId), "Occupant stamped with the mount time")
            service.tick(session.nextTick)
            assert(profile[station.stat] == station.gain, "Incorrect tier gain")
            -- No level cap: training well past the old playtest cap of 50 keeps going.
            profile[station.stat] = 10000
            service.tick(session.nextTick)
            assert(profile[station.stat] == 10000 + station.gain and service.sessions[player.UserId], "Training stopped at a cap")
            service.stop(player)
            assert(not service.sessions[player.UserId] and not next(station.occupants))
            assert(not root.Anchored and humanoid.AutoRotate and not humanoid.Sit and not humanoid.PlatformStand)
            assert(station.part:GetAttribute("Occupant_" .. player.UserId) == nil, "Occupant cleared on exit")
        end
        -- Benches and treadmills both take several users at once (each sees only themselves).
        local bench, treadmill
        for _, station in stations do
            if station.required == stations[1].required then
                if station.stat == "strengthLevel" then bench = station else treadmill = station end
            end
        end
        profile.completedLaunches = math.huge
        for _, station in { bench, treadmill } do
            local first = { UserId = player.UserId - 1, Character = player.Character }
            local second = { UserId = player.UserId - 2, Character = player.Character }
            player.UserId -= 2
            profiles.records[first.UserId], profiles.records[second.UserId] = { profile = profile }, { profile = profile }
            callbacks[station.part](first)
            callbacks[station.part](second)
            assert(service.sessions[first.UserId], "First user mounts")
            assert(service.sessions[second.UserId], "Second user shares the station")
            service.stop(first)
            service.stop(second)
            assert(not next(station.occupants))
        end
        -- The paid-only SpaceX gym: locked at any launch count, open with its pass.
        local paidPart = Instance.new("Part")
        local paidCallback
        local passOwned = false
        local paid = Training.new({
            config = config, remotes = remotes, players = { GetPlayerByUserId = function() return player end }, profiles = profiles,
            stations = { { part = paidPart, name = "SpaceX gym bench", stat = "strengthLevel", gain = config.SpaceXGym.multiplier,
                required = math.huge, tier = "SpaceX", paid = true } },
            prompt = function() return { Triggered = { Connect = function(_, callback) paidCallback = callback end } } end,
            allowed = function() return true end, near = function() return true end, phaseAllowed = function() return true end,
            body = function() return root, humanoid end, relocate = function() end, feedback = function() end, changed = function() end,
            unlocked = function(_, station) return passOwned and station.tier == "SpaceX" end,
        })
        player.UserId -= 1
        profiles.records[player.UserId] = { profile = profile }
        profile.completedLaunches = 1e6
        paidCallback(player)
        assert(not paid.sessions[player.UserId], "Launches opened the paid-only gym")
        passOwned = true
        paidCallback(player)
        assert(paid.sessions[player.UserId], "The SpaceX pass didn't open its gym")
        assert(paidPart:GetAttribute("RequiredCycles") == math.huge and paidPart:GetAttribute("GymTier") == "SpaceX")
        paid.stop(player)
        paidPart:Destroy()
        assert(Shop.gymKey("SpaceX") == config.SpaceXGym.key and Shop.enabled(config, config.SpaceXGym.key), "SpaceX Gym pass on sale")
    end)
    for _, station in stations do station.part:Destroy() end
    remotes:Destroy()
    assert(ok, failure)
    -- Levels: each costs more than the last up to StatLevels.max, then exactly max;
    -- carry and walk start at the base and rise every level (walk until MaxSpeed), walk gains never grow.
    local StatLevels = require(game.ReplicatedStorage.Shared.StatLevels)
    local Stats = require(script.Parent.StatsService).new({ config = config })
    local curve = config.StatLevels
    assert(StatLevels.cost(config, 1) == curve.base and StatLevels.total(config, 0) == 0)
    assert(curve.max >= 400 and curve.max <= 500, "Level cost cap in the 400-500 range")
    local lastCost, lastCarry, lastWalk, lastStep = 0, -1, -1, math.huge
    for level = 1, 2000 do
        local cost = StatLevels.cost(config, level)
        assert(cost >= lastCost and cost <= curve.max and cost % 5 == 0, "Level costs never fall and stay under the cap")
        assert(StatLevels.total(config, level) - StatLevels.total(config, level - 1) == cost)
        local total = StatLevels.total(config, level)
        local at, into, need = StatLevels.level(config, total)
        assert(at == level and into == 0 and need == StatLevels.cost(config, level + 1), "Exact total reaches the level")
        assert(StatLevels.level(config, total - 0.5) == level - 1, "Half a point short stays a level below")
        local carry, walk = StatLevels.capacity(config, level), StatLevels.walk(config, level)
        assert(carry > lastCarry and (walk > lastWalk or walk == config.MaxSpeed) and walk <= config.MaxSpeed)
        assert(walk - lastWalk <= lastStep + 1e-9, "Walk gains never grow")
        lastCost, lastCarry, lastStep, lastWalk = cost, carry, walk - lastWalk, walk
    end
    assert(StatLevels.cost(config, 2000) == curve.max, "Late levels cost the cap")
    -- A gentle climb for new players (user, 2026-10-25): the cap kicks in around level 450-500.
    local capFrom = 1
    while StatLevels.cost(config, capFrom) < curve.max do capFrom += 1 end
    assert(capFrom >= 450 and capFrom <= 500, "Level cost cap reached around level 450-500")
    -- The walk curve's shape (user, 2026-10-20): ~29 at level 1, ~121 at 100, top speed 400
    -- reached around level 560 and never passed.
    local function near(level, want) return math.abs(StatLevels.walk(config, level) - want) < 1.5 end
    assert(near(1, 29) and near(8, 48.8) and near(100, 121) and near(300, 243), "Walk curve changed")
    assert(config.MaxSpeed == 400 and StatLevels.walk(config, 555) < 400 and StatLevels.walk(config, 565) == 400 and StatLevels.walk(config, 5000) == 400)
    -- The free gym (+1/s) gives level 1 within 10 s, and the profile path matches.
    local function stats(points)
        local p = { strengthLevel = points, speedLevel = points, planetBonuses = { strength = 0, speed = 0 } }
        return Stats.speed(p), Stats.capacity(p)
    end
    local speed0, carry0 = stats(0)
    assert(speed0 == config.BaseSpeed and carry0 == config.BaseCarryCapacity)
    assert(config.BaseSpeed >= 24 and config.BaseSpeed <= 32, "Base walk speed in the reference range")
    local speed1, carry1 = stats(config.TrainingBaseGain * config.FreeGymMultiplier * 10)
    assert(carry1 > carry0 and speed1 > speed0, "Ten free-gym ticks reach level 1")
    -- Gyms tick 3 times a second (user, 2026-10-20). The top gym (100x: 300 a second, 100
    -- launches or the SHOP pass) still takes over a second per capped level.
    assert(math.abs(1 / config.TrainingSeconds - 3) < 1e-9, "Gyms tick 3 times a second")
    local top = config.TrainingBaseGain * config.TrainingTiers[#config.TrainingTiers].multiplier / config.TrainingSeconds
    assert(math.round(top) == 300 and curve.max / top >= 1, "Top gym levels too fast")
    return "All 14 tiered gym stations (2x-100x): locked below milestone, unlocked at milestone, correct gains, no cap, exit, shared benches and treadmills; SpaceX gym pass only; level costs, carry and walk curves passed"
end
