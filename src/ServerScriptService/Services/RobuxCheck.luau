-- Robux upgrade levels (Game Passes): the configured passes, the next-level lookup the panel
-- and prompt use, raising a pass level (never lowering it, capped at max, kept apart from
-- the saved coin levels), the join-time ownership sync (highest pass wins, a refunded pass
-- stops counting, failed checks fall back to passes saved as bought here, Studio test
-- purchases count), and the v6 profile cap.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
    local Service = require(script.Parent.RobuxUpgradeService)
    local Profiles = require(script.Parent.ProfileService)

    -- Real config: one price and one pass per level on every track; IDs unique positive integers.
    local robux = config.RobuxUpgrades
    local seen = {}
    for _, track in config.UpgradeOrder do
        local max = config.Upgrades[track].max
        assert(#robux.prices == max and #robux.passes[track] == max, track .. " needs a pass and price per level")
        for level, id in robux.passes[track] do
            assert(type(id) == "number" and id > 0 and id % 1 == 0 and not seen[id], track .. " level " .. level .. " bad pass ID")
            seen[id] = true
        end
    end
    for level = 2, #robux.prices do assert(robux.prices[level] > robux.prices[level - 1], "Robux prices must rise") end
    local map = Service.passes(config)
    local first = robux.passes.BulkPlace[1]
    assert(map[first].track == "BulkPlace" and map[first].level == 1)

    -- Next level's pass and price; nil at max or for an unknown track.
    local MAX = config.Upgrades.BulkPickup.max
    assert(Upgrades.robux(config, "BulkPickup", 0) == robux.passes.BulkPickup[1] and select(2, Upgrades.robux(config, "BulkPickup", 0)) == 53)
    assert(Upgrades.robux(config, "PlacementRange", MAX - 1) == robux.passes.PlacementRange[MAX] and select(2, Upgrades.robux(config, "PlacementRange", MAX - 1)) == 143)
    assert(Upgrades.robux(config, "BulkPickup", MAX) == nil, "maxed track still sells")
    assert(Upgrades.robux(config, "Nope", 0) == nil)
    local partial = table.clone(config)
    partial.RobuxUpgrades = { prices = robux.prices, passes = { BulkPickup = { 101 } } }
    assert(Upgrades.robux(partial, "BulkPickup", 1) == nil and Upgrades.robux(partial, "BulkPlace", 0) == nil, "missing pass shows")

    -- apply: raises only, capped at max, ignores unknown tracks; never touches the saved
    -- coin levels.
    local profile = Profiles.validate(nil, config)
    assert(Service.apply(config, profile, "BulkPickup", 3) and Upgrades.level(profile, "BulkPickup") == 3 and profile.upgrades.BulkPickup == nil)
    assert(not Service.apply(config, profile, "BulkPickup", 2) and Upgrades.level(profile, "BulkPickup") == 3, "pass lowered a level")
    assert(not Service.apply(config, profile, "BulkPickup", 3), "same level counted as a change")
    assert(Service.apply(config, profile, "BulkPlace", 99) and Upgrades.level(profile, "BulkPlace") == MAX, "pass level not capped")
    assert(Upgrades.levels(config, profile).BulkPickup == 3, "snapshot levels miss the pass level")
    assert(not Service.apply(config, profile, "Nope", 1) and not Service.apply(config, profile, "BulkPickup", "5"))

    -- Coin levels continue from a pass level.
    profile.coins = 1e7
    local UpgradeService = require(script.Parent.UpgradeService)
    assert(UpgradeService.buy(config, profile, "BulkPickup", "after-pass") == Upgrades.price(config, "BulkPickup", 3) and profile.upgrades.BulkPickup == 4)

    -- sync: the highest owned pass per track wins; owned passes below the level change nothing;
    -- an ownership check that errors leaves the track alone.
    local function owning(list)
        local set = {}
        for _, id in list do set[id] = true end
        local calls = 0
        return function(id) calls += 1; return set[id] == true end, function() return calls end
    end
    local fresh = Profiles.validate(nil, config)
    local owns = owning({ robux.passes.BulkPickup[2], robux.passes.BulkPickup[5], robux.passes.PlacementRange[1] })
    local raised = Service.sync(config, fresh, owns)
    assert(Upgrades.level(fresh, "BulkPickup") == 5 and Upgrades.level(fresh, "BulkPlace") == 0 and Upgrades.level(fresh, "PlacementRange") == 1)
    assert(next(fresh.upgrades) == nil, "pass levels went into the saved coin levels")
    assert(#raised == 2 and table.find(raised, "BulkPickup") and table.find(raised, "PlacementRange"))
    assert(#Service.sync(config, fresh, owns) == 0, "re-sync changed levels")
    local coined = Profiles.validate(nil, config)
    coined.upgrades.BulkPickup = 7
    local owns2, calls2 = owning({ robux.passes.BulkPickup[3] })
    assert(#Service.sync(config, coined, owns2) == 0 and coined.upgrades.BulkPickup == 7, "lower pass lowered a coin level")
    assert(calls2() == 3 + MAX + MAX, "sync checked passes at or below the current level")
    local failing = Profiles.validate(nil, config)
    assert(#Service.sync(config, failing, function() error("Marketplace down") end) == 0 and next(failing.upgrades) == nil)
    -- A refunded pass stops counting on the next sync: back to the coin level.
    local refunded = Profiles.validate(nil, config)
    refunded.upgrades.BulkPickup = 2
    Service.sync(config, refunded, (owning({ robux.passes.BulkPickup[6] })))
    assert(Upgrades.level(refunded, "BulkPickup") == 6)
    local dropped = Service.sync(config, refunded, (owning({})))
    assert(Upgrades.level(refunded, "BulkPickup") == 2 and table.find(dropped, "BulkPickup"), "refunded pass still counts")
    -- A failed check falls back to the pass saved as bought here; Studio (trustSaved)
    -- counts saved passes even when Roblox says no.
    local saved = { Service.savedKey("BulkPickup", 4), "DoubleCoins" }
    Service.sync(config, refunded, function() error("Marketplace down") end, saved)
    assert(Upgrades.level(refunded, "BulkPickup") == 4, "saved pass not used when the check failed")
    Service.sync(config, refunded, (owning({})), saved)
    assert(Upgrades.level(refunded, "BulkPickup") == 2, "saved pass beat Roblox outside Studio")
    Service.sync(config, refunded, (owning({})), saved, true)
    assert(Upgrades.level(refunded, "BulkPickup") == 4, "Studio test purchase lost")
    local maxed = Profiles.validate(nil, config)
    maxed.upgrades = { BulkPickup = MAX, BulkPlace = MAX, PlacementRange = MAX }
    local owns3, calls3 = owning({})
    assert(#Service.sync(config, maxed, owns3) == 0 and calls3() == 0, "maxed tracks still checked")

    -- Profile v6: v5 levels above the new max are capped; the caller's table is untouched.
    local v5 = Profiles.validate(nil, config)
    assert(v5.schemaVersion == 7)
    v5.schemaVersion, v5.upgrades = 5, { BulkPickup = 40, BulkPlace = 3 }
    local migrated = Profiles.validate(v5, config)
    assert(migrated.schemaVersion == 7 and migrated.upgrades.BulkPickup == MAX and migrated.upgrades.BulkPlace == 3)
    assert(v5.upgrades.BulkPickup == 40, "migration changed the caller's table")
end
