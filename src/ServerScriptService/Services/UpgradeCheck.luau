-- Upgrade prices, the purchase rule (validation, idempotency), effects, ranks, the
-- v4 profile migration, and a first-hour economy sim against the Phase 4 targets.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
    local Service = require(script.Parent.UpgradeService)
    local Profiles = require(script.Parent.ProfileService)

    -- Prices: rounded to 5, doubling, nil at max; every track in the order list.
    assert(#config.UpgradeOrder == 4)
    for _, track in config.UpgradeOrder do
        local spec = config.Upgrades[track]
        assert(spec, track)
        local last = 0
        for level = 0, spec.max - 1 do
            local price = Upgrades.price(config, track, level)
            assert(price and price % 5 == 0 and price > last, track .. " price curve")
            last = price
        end
        assert(Upgrades.price(config, track, spec.max) == nil, track .. " must max out")
    end
    assert(Upgrades.price(config, "BulkPickup", 0) == 10 and Upgrades.price(config, "Nope", 0) == nil)

    -- Purchases: validated, charged once per request ID, ledger bounded.
    local profile = Profiles.validate(nil, config)
    assert(profile.schemaVersion == 4 and next(profile.upgrades) == nil and #profile.purchaseIds == 0)
    assert(Upgrades.cheapest(config, profile) == 10)
    assert(Service.buy(config, profile, "BulkPickup", "a") == nil, "bought without coins")
    profile.coins = 100
    assert(Service.buy(config, profile, "Nope", "a") == nil and Service.buy(config, profile, "BulkPickup", "") == nil)
    assert(Service.buy(config, profile, "BulkPickup", 7) == nil and Service.buy(config, profile, "BulkPickup", string.rep("x", 65)) == nil)
    assert(Service.buy(config, profile, "BulkPickup", "a") == 10 and profile.coins == 90 and profile.upgrades.BulkPickup == 1)
    assert(Service.buy(config, profile, "BulkPickup", "a") == 0 and profile.coins == 90 and profile.upgrades.BulkPickup == 1, "retry charged twice")
    assert(Service.buy(config, profile, "BulkPickup", "b") == 20 and profile.coins == 70 and profile.upgrades.BulkPickup == 2)
    profile.coins = 1e9
    for i = 1, 50 do Service.buy(config, profile, "BulkPickup", "id" .. i) end
    assert(profile.upgrades.BulkPickup == config.Upgrades.BulkPickup.max)
    assert(select(2, Service.buy(config, profile, "BulkPickup", "late")) == "maxed")
    assert(#profile.purchaseIds <= Service.LedgerSize)

    -- Effects follow the levels.
    local maxed = { upgrades = { BulkPickup = 3, BulkPlace = 2, PlacementRange = 4, CarryCapacity = 1 } }
    assert(Upgrades.pickupUnits(config, maxed) == 4)
    assert(math.abs(Upgrades.pourSeconds(config, maxed) - config.PourSeconds / 1.5) < 1e-9)
    assert(Upgrades.reach(config, maxed) == config.FrontierReach + 8)
    assert(Upgrades.capacityBonus(config, maxed) == 5 and Upgrades.pickupUnits(config, {}) == 1)

    -- Ranks need both deliveries and launches.
    assert(select(2, Upgrades.rank(config, 0, 0)) == "APPRENTICE")
    assert(select(2, Upgrades.rank(config, 250, 0)) == "MECHANIC")
    assert(select(2, Upgrades.rank(config, 1e6, 0)) == "MECHANIC", "launches gate higher ranks")
    assert(select(2, Upgrades.rank(config, 1e6, 100)) == "COMMANDER")

    -- v3 profiles gain empty upgrades; bad levels are refused, not overwritten.
    local v3 = Profiles.validate(nil, config)
    v3.schemaVersion, v3.upgrades, v3.purchaseIds = 3, nil, nil
    local migrated = Profiles.validate(v3, config)
    assert(migrated.schemaVersion == 4 and next(migrated.upgrades) == nil and #migrated.purchaseIds == 0)
    for _, bad in { { Nope = 1 }, { BulkPickup = -1 }, { BulkPickup = 1.5 }, { BulkPickup = 99 } } do
        local raw = Profiles.validate(nil, config)
        raw.upgrades = bad
        assert(not pcall(Profiles.validate, raw, config), "accepted bad upgrades")
    end

    -- First hour: a player who delivers nonstop (and, optionally, spends 1 min of every
    -- 5 on the starter gym), buying the cheapest affordable upgrade. Trip model from
    -- Studio: ~460 studs per round trip at walk speed, plus pickup and pour time.
    local function simulate(train)
        local profile = Profiles.validate(nil, config)
        local t, nextTrain, buys = 0, 300, {}
        while t < 3600 do
            if train and t >= nextTrain then
                t += 60
                profile.strengthLevel += 60
                profile.speedLevel += 60
                nextTrain += 300
            end
            local points = profile.speedLevel
            local walk = config.BaseSpeed + (config.MaxSpeed - config.BaseSpeed) * points / (points + config.SpeedHalfPoints)
            local capacity = config.BaseCarryCapacity + math.floor(config.StrengthCarryScale * math.sqrt(profile.strengthLevel))
                + Upgrades.capacityBonus(config, profile)
            local distance = 460 - 2 * (Upgrades.reach(config, profile) - config.FrontierReach)
            t += distance / walk + math.ceil(capacity / Upgrades.pickupUnits(config, profile)) * config.MaterialHoldSeconds
                + Upgrades.pourSeconds(config, profile) + 2
            profile.coins += capacity * config.CoinsPerUnit
            while true do
                local best, bestPrice
                for _, track in config.UpgradeOrder do
                    local price = Upgrades.price(config, track, Upgrades.level(profile, track))
                    if price and (not bestPrice or price < bestPrice) then best, bestPrice = track, price end
                end
                if not best or profile.coins < bestPrice then break end
                Service.buy(config, profile, best, "sim" .. #buys)
                table.insert(buys, t)
            end
        end
        local total = 0
        for i = 3, #buys do total += buys[i] - buys[i - 1] end
        return buys[1], total / (#buys - 2), #buys
    end
    for _, train in { true, false } do
        local first, meanGap, count = simulate(train)
        assert(first < 60, "first upgrade after " .. first .. " s")
        assert(meanGap >= 180 and meanGap <= 330, ("mean gap %.0f s (train=%s)"):format(meanGap, tostring(train)))
        assert(count >= 10, "only " .. count .. " upgrades in the first hour")
    end
end
