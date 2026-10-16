-- Upgrade and rank math shared by the server (effects, purchases) and the client
-- (panel prices). Tunables live in Config.Upgrades / Config.UpgradePrices / Config.Ranks.
local Upgrades = {}

function Upgrades.level(profile, track)
    return profile.upgrades and profile.upgrades[track] or 0
end

-- Unrounded price of level n (1-based) on Config.UpgradePrices.
local function rawPrice(curve, n)
    local price, from = curve.base, 2
    for _, segment in curve.segments do
        local steps = math.min(n, segment.upTo) - from + 1
        if steps > 0 then price *= segment.factor ^ steps end
        from = segment.upTo + 1
    end
    return price
end

-- Coins for the next level of `track`, or nil when it is maxed. Every track shares
-- Config.UpgradePrices; prices are rounded to 5 under 1,000, else to 3 significant figures.
function Upgrades.price(config, track, level)
    local spec = config.Upgrades[track]
    if not spec or level >= spec.max then return nil end
    local price = rawPrice(config.UpgradePrices, level + 1)
    if price < 1000 then return math.max(5, math.round(price / 5) * 5) end
    local unit = 10 ^ (math.floor(math.log10(price)) - 2)
    return math.round(price / unit) * unit
end

-- Robux product ID and price for the next level of `track` (tier = which block of
-- levelsPerTier the next level falls in), or nil when maxed or that product isn't set up.
function Upgrades.robux(config, track, level)
    local spec, robux = config.Upgrades[track], config.RobuxUpgrades
    if not spec or level >= spec.max then return nil end
    local tier = level // robux.levelsPerTier + 1
    local id = robux.products[track] and robux.products[track][tier]
    if not id then return nil end
    return id, robux.prices[tier], tier
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
