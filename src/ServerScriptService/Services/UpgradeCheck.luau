-- Upgrade prices, the purchase rule (validation, idempotency), effects, ranks, the
-- v4/v5 profile migrations, and the price curve against the agreed pacing: level 1 is
-- cheap, level 2 about a minute of a new player's work, level 3 a few minutes, then
-- ever pricier up to 100 levels that coins alone can't realistically reach.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
    local Service = require(script.Parent.UpgradeService)
    local Profiles = require(script.Parent.ProfileService)

    -- Prices: rounded to 5, rising, at least 10% per level from level 3 on (so the steps
    -- keep growing in coins), nil at max; every track in the order list, 100 levels each.
    assert(#config.UpgradeOrder == 3 and config.Upgrades.CarryCapacity == nil)
    for _, track in config.UpgradeOrder do
        local spec = config.Upgrades[track]
        assert(spec and spec.max == 100, track)
        local last = 0
        for level = 0, spec.max - 1 do
            local price = Upgrades.price(config, track, level)
            assert(price and price % 5 == 0 and price > last, track .. " price curve")
            assert(level < 3 or price >= last * 1.1, track .. " flattens at level " .. level + 1)
            last = price
        end
        assert(last >= 1e9, track .. " top level is too cheap: " .. last)
        assert(Upgrades.price(config, track, spec.max) == nil, track .. " must max out")
    end
    assert(Upgrades.price(config, "BulkPickup", 0) == 10 and Upgrades.price(config, "Nope", 0) == nil)

    -- Purchases: validated, charged once per request ID, ledger bounded.
    local profile = Profiles.validate(nil, config)
    assert(profile.schemaVersion == 5 and next(profile.upgrades) == nil and #profile.purchaseIds == 0)
    assert(Upgrades.cheapest(config, profile) == 10)
    assert(Service.buy(config, profile, "BulkPickup", "a") == nil, "bought without coins")
    profile.coins = 100
    assert(Service.buy(config, profile, "Nope", "a") == nil and Service.buy(config, profile, "BulkPickup", "") == nil)
    assert(Service.buy(config, profile, "CarryCapacity", "a") == nil, "retired track still sells")
    assert(Service.buy(config, profile, "BulkPickup", 7) == nil and Service.buy(config, profile, "BulkPickup", string.rep("x", 65)) == nil)
    assert(Service.buy(config, profile, "BulkPickup", "a") == 10 and profile.coins == 90 and profile.upgrades.BulkPickup == 1)
    assert(Service.buy(config, profile, "BulkPickup", "a") == 0 and profile.coins == 90 and profile.upgrades.BulkPickup == 1, "retry charged twice")
    assert(Service.buy(config, profile, "BulkPickup", "b") == 30 and profile.coins == 60 and profile.upgrades.BulkPickup == 2)
    profile.coins = 1e15
    for i = 1, 120 do Service.buy(config, profile, "BulkPickup", "id" .. i) end
    assert(profile.upgrades.BulkPickup == config.Upgrades.BulkPickup.max)
    assert(select(2, Service.buy(config, profile, "BulkPickup", "late")) == "maxed")
    assert(#profile.purchaseIds <= Service.LedgerSize)

    -- Effects: +1 unit per tick per level for pickup and place, +10% reach per level.
    local some = { upgrades = { BulkPickup = 3, BulkPlace = 2, PlacementRange = 5 } }
    assert(Upgrades.pickupUnits(config, some) == 4 and Upgrades.placeUnits(config, some) == 3)
    assert(math.abs(Upgrades.reach(config, some) - config.FrontierReach * 1.5) < 1e-9)
    assert(Upgrades.pickupUnits(config, {}) == 1 and Upgrades.placeUnits(config, {}) == 1 and Upgrades.reach(config, {}) == config.FrontierReach)
    local top = { upgrades = { BulkPickup = 100, BulkPlace = 100, PlacementRange = 100 } }
    assert(Upgrades.pickupUnits(config, top) == 101 and Upgrades.placeUnits(config, top) == 101)
    assert(math.abs(Upgrades.reach(config, top) - config.FrontierReach * 11) < 1e-9)

    -- Ranks need both deliveries and launches.
    assert(select(2, Upgrades.rank(config, 0, 0)) == "APPRENTICE")
    assert(select(2, Upgrades.rank(config, 250, 0)) == "MECHANIC")
    assert(select(2, Upgrades.rank(config, 1e6, 0)) == "MECHANIC", "launches gate higher ranks")
    assert(select(2, Upgrades.rank(config, 1e6, 100)) == "COMMANDER")

    -- v3 profiles gain empty upgrades; v4 ones lose Carry Capacity and keep the rest;
    -- bad levels are refused, not overwritten.
    local v3 = Profiles.validate(nil, config)
    v3.schemaVersion, v3.upgrades, v3.purchaseIds = 3, nil, nil
    local migrated = Profiles.validate(v3, config)
    assert(migrated.schemaVersion == 5 and next(migrated.upgrades) == nil and #migrated.purchaseIds == 0)
    local v4 = Profiles.validate(nil, config)
    v4.schemaVersion, v4.upgrades = 4, { BulkPickup = 3, CarryCapacity = 6 }
    migrated = Profiles.validate(v4, config)
    assert(migrated.schemaVersion == 5 and migrated.upgrades.BulkPickup == 3 and migrated.upgrades.CarryCapacity == nil)
    assert(v4.upgrades.CarryCapacity == 6, "migration changed the caller's table")
    for _, bad in { { Nope = 1 }, { BulkPickup = -1 }, { BulkPickup = 1.5 }, { BulkPickup = 101 }, { CarryCapacity = 1 } } do
        local raw = Profiles.validate(nil, config)
        raw.upgrades = bad
        assert(not pcall(Profiles.validate, raw, config), "accepted bad upgrades")
    end

    -- Pacing: a brand-new player (base stats, no training) delivering nonstop and putting
    -- every coin into one track. Trip model from Studio: ~460 studs per round trip at walk
    -- speed, plus pickup and place ticks and 2 s handling.
    for _, track in config.UpgradeOrder do
        local fresh = Profiles.validate(nil, config)
        local t, bought = 0, {}
        while #bought < 3 do
            local capacity = config.BaseCarryCapacity
            local distance = 460 - 2 * (Upgrades.reach(config, fresh) - config.FrontierReach)
            t += distance / config.BaseSpeed + math.ceil(capacity / Upgrades.pickupUnits(config, fresh)) * config.MaterialHoldSeconds
                + math.ceil(capacity / Upgrades.placeUnits(config, fresh)) * config.MaterialHoldSeconds + 2
            fresh.coins += capacity * config.CoinsPerUnit
            if Service.buy(config, fresh, track, "pace" .. #bought) then table.insert(bought, t) end
        end
        assert(bought[1] < 60, ("%s level 1 after %.0f s"):format(track, bought[1]))
        local second, third = bought[2] - bought[1], bought[3] - bought[2]
        assert(second >= 30 and second <= 120, ("%s level 2 took %.0f s of work"):format(track, second))
        assert(third >= 120 and third <= 480, ("%s level 3 took %.0f s of work"):format(track, third))
    end
end
