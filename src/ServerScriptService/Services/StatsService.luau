-- Derived character stats (walk speed, carry capacity) and the server leaderboard.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Stats = {}

function Stats.new(ctx)
    local config = ctx.config
    local service = {}
    -- Soft curves (see Config): fast early gains, diminishing later, no level cap.
    function service.speed(profile)
        local points = profile.speedLevel + profile.planetBonuses.speed
        return config.BaseSpeed + (config.MaxSpeed - config.BaseSpeed) * points / (points + config.SpeedHalfPoints)
    end
    -- Strength (and the Carry Capacity upgrade) raise capacity, so stronger players make fewer trips.
    function service.capacity(profile)
        local points = profile.strengthLevel + profile.planetBonuses.strength
        return math.min(config.MaxCapacity, config.BaseCarryCapacity + math.floor(config.StrengthCarryScale * math.sqrt(points))
            + Upgrades.capacityBonus(config, profile))
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
