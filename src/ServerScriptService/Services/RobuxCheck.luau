-- Robux upgrade levels: product/tier lookup, the v6 receipt ledger, and ProcessReceipt
-- against fake profiles and journal: unknown product, absent player, duplicate receipt,
-- failed save then retry, failed journal, max level, and a player leaving mid-receipt.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
    local Service = require(script.Parent.RobuxUpgradeService)
    local Profiles = require(script.Parent.ProfileService)
    local Decision = Enum.ProductPurchaseDecision

    -- Real config: a price per tier covering every level, IDs (once set) unique positive integers.
    local robux = config.RobuxUpgrades
    local seen = {}
    for _, track in config.UpgradeOrder do
        assert(#robux.prices * robux.levelsPerTier == config.Upgrades[track].max, track .. " tiers don't cover all levels")
        for tier, id in robux.products[track] do
            assert(type(id) == "number" and id > 0 and id % 1 == 0 and not seen[id], track .. " tier " .. tier .. " bad product ID")
            assert(tier >= 1 and tier <= #robux.prices, track .. " tier out of range")
            seen[id] = true
        end
    end

    -- Test config with fake IDs (track index * 100 + tier); one product per level.
    local MAX = config.Upgrades.BulkPickup.max
    assert(robux.levelsPerTier == 1 and #robux.prices == MAX, "one Robux price per level")
    local products = {}
    for index, track in config.UpgradeOrder do
        products[track] = {}
        for tier = 1, #robux.prices do products[track][tier] = index * 100 + tier end
    end
    local test = table.clone(config)
    test.RobuxUpgrades = { levelsPerTier = robux.levelsPerTier, prices = robux.prices, products = products }
    assert(select(3, Upgrades.robux(test, "BulkPickup", 0)) == 1 and select(2, Upgrades.robux(test, "BulkPickup", 0)) == 53)
    assert(Upgrades.robux(test, "BulkPickup", 1) == 102 and select(2, Upgrades.robux(test, "BulkPickup", 1)) == 63)
    assert(select(2, Upgrades.robux(test, "PlacementRange", MAX - 1)) == 143 and Upgrades.robux(test, "PlacementRange", MAX - 1) == 310)
    assert(Upgrades.robux(test, "BulkPickup", MAX) == nil, "maxed track still sells")
    assert(Upgrades.robux(test, "Nope", 0) == nil)
    local partial = table.clone(test)
    partial.RobuxUpgrades = { levelsPerTier = 1, prices = robux.prices, products = { BulkPickup = { 101 } } }
    assert(Upgrades.robux(partial, "BulkPickup", 1) == nil and Upgrades.robux(partial, "BulkPlace", 0) == nil, "missing product shows")

    -- Profile v6: v5 gains an empty receipt ledger and levels capped at the new max; a bad
    -- ledger is refused.
    local v5 = Profiles.validate(nil, config)
    assert(v5.schemaVersion == 6 and #v5.receiptIds == 0)
    v5.schemaVersion, v5.receiptIds, v5.upgrades = 5, nil, { BulkPickup = 40, BulkPlace = 3 }
    local migrated = Profiles.validate(v5, config)
    assert(migrated.schemaVersion == 6 and #migrated.receiptIds == 0)
    assert(migrated.upgrades.BulkPickup == MAX and migrated.upgrades.BulkPlace == 3 and v5.upgrades.BulkPickup == 40, "v5 levels not capped")
    for _, bad in { "x", { 1 } } do
        local raw = Profiles.validate(nil, config)
        raw.receiptIds = bad
        assert(not pcall(Profiles.validate, raw, config), "accepted a bad receipt ledger")
    end

    -- ProcessReceipt against fakes.
    local USER = 7
    local function setup()
        local profiles = { records = { [USER] = { profile = Profiles.validate(nil, config) } }, saves = 0, failSave = false }
        function profiles:ready(id) local r = self.records[id]; return r ~= nil and not r.leaving end
        function profiles:dirty() end
        function profiles:commit(id)
            self.saves += 1
            if self.failSave then return false end
            self.stored = table.clone(self.records[id].profile.upgrades)
            return true
        end
        local journal = Service.journal(test) -- persistence off: in memory
        local deps = { config = test, products = Service.products(test), profiles = profiles, journal = journal, here = true, grants = 0 }
        deps.present = function() return deps.here end
        deps.granted = function() deps.grants += 1 end
        return deps, profiles.records[USER].profile, profiles
    end
    local function receipt(id, product) return { PurchaseId = id, PlayerId = USER, ProductId = product or 101 } end

    local deps, profile, profiles = setup()
    assert(Service.process(deps, receipt("u", 999)) == Decision.NotProcessedYet and deps.journal.entries.u == nil, "unknown product")
    deps.here = false
    assert(Service.process(deps, receipt("a")) == Decision.NotProcessedYet and (profile.upgrades.BulkPickup or 0) == 0, "absent player granted")
    deps.here = true
    assert(Service.process(deps, receipt("a")) == Decision.PurchaseGranted and profile.upgrades.BulkPickup == 1)
    assert(profiles.stored.BulkPickup == 1 and deps.journal.entries.a.state == "granted" and deps.journal.entries.a.outcome == "level")
    assert(Service.process(deps, receipt("a")) == Decision.PurchaseGranted and profile.upgrades.BulkPickup == 1 and deps.grants == 1, "duplicate receipt granted twice")
    assert(Service.process(deps, receipt("b", 201)) == Decision.PurchaseGranted and profile.upgrades.BulkPlace == 1, "wrong track")

    -- Save fails: not granted to Roblox yet, level applied once; the retry saves without a second level.
    profiles.failSave = true
    assert(Service.process(deps, receipt("c")) == Decision.NotProcessedYet and profile.upgrades.BulkPickup == 2)
    assert(deps.journal.entries.c.state == "pending")
    profiles.failSave = false
    assert(Service.process(deps, receipt("c")) == Decision.PurchaseGranted and profile.upgrades.BulkPickup == 2 and profiles.stored.BulkPickup == 2, "retry granted twice")

    -- Journal write fails: nothing granted.
    local open = deps.journal.open
    deps.journal.open = function() error("DataStore down") end
    assert(Service.process(deps, receipt("d")) == Decision.NotProcessedYet and profile.upgrades.BulkPickup == 2, "granted without a journal entry")
    deps.journal.open = open

    -- Player leaves during the journal write: the grant still lands and saves.
    deps.journal.open = function(info) open(info); profiles.records[USER].leaving = true; deps.here = false end
    assert(Service.process(deps, receipt("e")) == Decision.PurchaseGranted and profile.upgrades.BulkPickup == 3 and profiles.stored.BulkPickup == 3, "left mid-receipt")
    deps.journal.open = open
    profiles.records[USER].leaving, deps.here = nil, true

    -- At max: coins instead of a level (the cheapest next two levels on any track), once.
    -- Here BulkPickup 3, BulkPlace 1: next are BulkPlace 2 (150) then BulkPlace 3 (450).
    profile.upgrades.PlacementRange = MAX
    local before = profile.coins
    local paid = Upgrades.price(test, "BulkPlace", 1) + Upgrades.price(test, "BulkPlace", 2)
    assert(Service.payback(test, profile, 2) == paid and paid == 600)
    assert(Service.process(deps, receipt("f", 310)) == Decision.PurchaseGranted and profile.upgrades.PlacementRange == MAX)
    assert(profile.coins == before + paid and deps.journal.entries.f.outcome == "coins", "max-level payback")
    assert(Service.process(deps, receipt("f", 310)) == Decision.PurchaseGranted and profile.coins == before + paid, "payback twice")
    assert(Service.payback(test, { upgrades = { BulkPickup = MAX, BulkPlace = MAX - 1, PlacementRange = MAX } }, 2) == Upgrades.price(test, "BulkPlace", MAX - 1))
    assert(Service.payback(test, { upgrades = { BulkPickup = MAX, BulkPlace = MAX, PlacementRange = MAX } }, 2) == 0)

    -- Ledger stays bounded.
    for i = 1, 100 do Service.grant(test, profile, "BulkPickup", "bulk" .. i) end
    assert(#profile.receiptIds == Service.LedgerSize and profile.upgrades.BulkPickup == MAX)
end
