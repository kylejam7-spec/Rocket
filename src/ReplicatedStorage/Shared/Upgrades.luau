-- Upgrade and rank math shared by the server (effects, purchases) and the client
-- (panel prices). Tunables live in Config.Upgrades / Config.UpgradePrices / Config.Ranks.
local Upgrades = {}

function Upgrades.level(profile, track)
    return profile.upgrades and profile.upgrades[track] or 0
end

-- Coins for the next level of `track`, or nil when it is maxed. Every track shares
-- Config.UpgradePrices: the listed first prices, then x growth per level.
function Upgrades.price(config, track, level)
    local spec = config.Upgrades[track]
    if not spec or level >= spec.max then return nil end
    local curve = config.UpgradePrices
    local listed = #curve.first
    if level < listed then return curve.first[level + 1] end
    return math.max(5, math.round(curve.first[listed] * curve.growth ^ (level + 1 - listed) / 5) * 5)
end

-- Cheapest next level across all tracks (nil when everything is maxed).
function Upgrades.cheapest(config, profile)
    local best
    for _, track in config.UpgradeOrder do
        local price = Upgrades.price(config, track, Upgrades.level(profile, track))
        if price and (not best or price < best) then best = price end
    end
    return best
end

local function bonus(config, profile, track)
    return Upgrades.level(profile, track) * config.Upgrades[track].step
end
-- Units moved per pickup tick.
function Upgrades.pickupUnits(config, profile)
    return 1 + bonus(config, profile, "BulkPickup")
end
-- Units poured into the rocket per place tick.
function Upgrades.placeUnits(config, profile)
    return 1 + bonus(config, profile, "BulkPlace")
end
-- Place reach in studs.
function Upgrades.reach(config, profile)
    return config.FrontierReach * (1 + bonus(config, profile, "PlacementRange"))
end

-- Rank index and name from lifetime deliveries and completed launches.
function Upgrades.rank(config, deliveries, launches)
    local index = 1
    for i, rank in config.Ranks do
        if deliveries >= rank.deliveries and launches >= rank.launches then index = i end
    end
    return index, config.Ranks[index].name
end

return Upgrades
