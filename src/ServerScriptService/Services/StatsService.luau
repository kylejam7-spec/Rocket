-- Derived character stats (walk speed, carry capacity) and the server leaderboard.
local StatLevels = require(game:GetService("ReplicatedStorage").Shared.StatLevels)
local Stats = {}

function Stats.new(ctx)
    local config = ctx.config
    local service = {}
    -- Points (training plus destination rewards) become levels (Shared.StatLevels);
    -- each level adds a fixed carry or a shrinking walk-speed step.
    function service.levels(profile)
        return StatLevels.level(config, profile.strengthLevel + profile.planetBonuses.strength),
            StatLevels.level(config, profile.speedLevel + profile.planetBonuses.speed)
    end
    function service.speed(profile)
        local _, speed = service.levels(profile)
        return StatLevels.walk(config, speed)
    end
    -- Strength raises capacity, so stronger players make fewer trips.
    function service.capacity(profile)
        return StatLevels.capacity(config, (service.levels(profile)))
    end
    function service.attach(player)
        local stats = Instance.new("Folder")
        stats.Name = "leaderstats"
        for _, name in { "CompletedLaunches", "LifetimeDeliveries" } do
            local value = Instance.new("IntValue")
            value.Name = name
            value.Parent = stats
        end
        stats.Parent = player
    end
    function service.update(player)
        local record = ctx.profiles.records[player.UserId]
        if not record then return end
        local profile = record.profile
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = service.speed(profile) end
        local stats = player:FindFirstChild("leaderstats")
        if stats then
            stats.CompletedLaunches.Value = profile.completedLaunches
            stats.LifetimeDeliveries.Value = profile.lifetimeDeliveries
        end
        if ctx.Upgrades then ctx.Upgrades.showRank(player, profile) end
    end
    return service
end
return Stats
