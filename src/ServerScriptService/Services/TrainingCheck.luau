-- Isolated checks: no real player profiles or world changes.
return function()
    local Training = require(script.Parent.TrainingService)
    local config = require(game.ReplicatedStorage.Shared.Config)
    local remotes = Instance.new("Folder")
    local player = { UserId = -1, Character = {} }
    local root = { Parent = true, Position = Vector3.zero, Anchored = false }
    local humanoid = { Health = 100, AutoRotate = true, Sit = false }
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
        relocate = function(_, position) root.Position = position end,
        feedback = function() end, changed = function() end,
    })
    local ok, failure = pcall(function()
        assert(#stations == 14)
        -- Tiers are in walking order: each needs more launches and pays more than the last.
        local expected = { {1, 2}, {3, 3}, {8, 4}, {15, 6}, {25, 8}, {50, 10}, {100, 12} }
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
            service.tick(session.nextTick)
            assert(profile[station.stat] == station.gain, "Incorrect tier gain")
            -- No level cap: training well past the old playtest cap of 50 keeps going.
            profile[station.stat] = 10000
            service.tick(session.nextTick)
            assert(profile[station.stat] == 10000 + station.gain and service.sessions[player.UserId], "Training stopped at a cap")
            service.stop(player)
            assert(not service.sessions[player.UserId] and not station.occupant)
            assert(not root.Anchored and humanoid.AutoRotate and not humanoid.Sit)
        end
    end)
    for _, station in stations do station.part:Destroy() end
    remotes:Destroy()
    assert(ok, failure)
    -- Levels: each costs more than the last up to StatLevels.max, then exactly max;
    -- carry and walk start at the base and rise every level, walk gains shrink.
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
        assert((carry > lastCarry or carry == config.MaxCapacity) and walk > lastWalk and walk < config.MaxSpeed)
        assert(walk - lastWalk <= lastStep, "Walk gains shrink")
        lastCost, lastCarry, lastStep, lastWalk = cost, carry, walk - lastWalk, walk
    end
    assert(StatLevels.cost(config, 2000) == curve.max, "Late levels cost the cap")
    -- The starter gym (+1/s) gives level 1 within 10 s, and the profile path matches.
    local function stats(points)
        local p = { strengthLevel = points, speedLevel = points, planetBonuses = { strength = 0, speed = 0 } }
        return Stats.speed(p), Stats.capacity(p)
    end
    local speed0, carry0 = stats(0)
    assert(speed0 == config.BaseSpeed and carry0 == config.BaseCarryCapacity)
    assert(config.BaseSpeed >= 24 and config.BaseSpeed <= 32, "Base walk speed in the reference range")
    local speed1, carry1 = stats(config.TrainingBaseGain * 10)
    assert(carry1 > carry0 and speed1 > speed0, "Ten starter-gym ticks reach level 1")
    -- A boost, not game-breaking: even the top gym needs over 30 s per capped level.
    local top = config.TrainingBaseGain * config.TrainingTiers[#config.TrainingTiers].multiplier
    assert(curve.max / top >= 30, "Top gym levels too fast")
    return "All 14 tiered gym stations (2x-12x): locked below milestone, unlocked at milestone, correct gains, no cap, exit; level costs, carry and walk curves passed"
end
