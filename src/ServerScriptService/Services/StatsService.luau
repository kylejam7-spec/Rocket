-- Derived character stats (walk speed, carry capacity) and the server leaderboard.
local Stats = {}

function Stats.new(ctx)
    local config = ctx.config
    local service = {}
    function service.speed(profile)
        return math.min(config.MaxSpeed, config.BaseSpeed + (profile.speedLevel + profile.planetBonuses.speed) * config.SpeedPerLevel)
    end
    -- Strength raises carry capacity, so stronger players make fewer trips.
    function service.capacity(profile)
        return math.min(config.MaxCapacity, config.BaseCarryCapacity
            + math.floor((profile.strengthLevel + profile.planetBonuses.strength) / config.StrengthPerCarry))
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
    end
    return service
end
return Stats
