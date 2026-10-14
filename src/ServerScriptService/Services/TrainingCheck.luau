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
                stat = stat, gain = tier.gain, required = tier.cycles})
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
        assert(#stations == 10)
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
            profile[station.stat] = config.MaxLevel - 1
            service.tick(session.nextTick)
            assert(profile[station.stat] == config.MaxLevel, "Training exceeded cap")
            assert(not service.sessions[player.UserId] and not station.occupant)
            assert(not root.Anchored and humanoid.AutoRotate and not humanoid.Sit)
        end
    end)
    for _, station in stations do station.part:Destroy() end
    remotes:Destroy()
    assert(ok, failure)
    return "All 10 advanced stations: locked below milestone, unlocked at milestone, correct gains, cap and exit passed"
end
