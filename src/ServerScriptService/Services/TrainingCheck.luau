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
    -- Stat curves: start at the base, rise every step, flatten out, stay under limits.
    local Stats = require(script.Parent.StatsService).new({ config = config })
    local function stats(points)
        local p = { strengthLevel = points, speedLevel = points, planetBonuses = { strength = 0, speed = 0 } }
        return Stats.speed(p), Stats.capacity(p)
    end
    local speed0, carry0 = stats(0)
    assert(speed0 == config.BaseSpeed and carry0 == config.BaseCarryCapacity)
    assert(config.BaseSpeed >= 24 and config.BaseSpeed <= 32, "Base walk speed in the reference range")
    -- The starter gym gives +2 a second.
    local _, carry1 = stats(2)
    assert(carry1 > carry0, "The first starter-bench tick visibly raises capacity")
    assert(math.floor(stats(2 * 5)) > math.floor(speed0), "Five starter-treadmill ticks raise whole walk speed")
    local lastSpeed, lastCarry, lastStep = speed0, carry0, math.huge
    for points = 60, 1e6, 60 * 7 do
        local speed, carry = stats(points)
        assert(speed > lastSpeed and carry >= lastCarry and speed < config.MaxSpeed and carry <= config.MaxCapacity)
        lastSpeed, lastCarry = speed, carry
    end
    local a, b, c = stats(100), stats(200), stats(300)
    assert(b - a > c - b, "Speed gains diminish")
    return "All 14 tiered gym stations (2x-100x): locked below milestone, unlocked at milestone, correct gains, no cap, exit; stat curves passed"
end
