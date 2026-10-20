-- The Robux SHOP: the catalog and config agree, receipts are granted once per
-- PurchaseId and recorded before PurchaseGranted (a failed journal read or write means
-- NotProcessedYet and no second grant), product effects (boost stacking, fill banked
-- across phases, stay extensions, guaranteed missions) and pass effects (pet slots,
-- Triple Hatch, 2x Coins, trims when a slot pass is gone, failed ownership checks).
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Shop = require(ReplicatedStorage.Shared.Shop)
    local Pets = require(ReplicatedStorage.Shared.Pets)
    local Missions = require(ReplicatedStorage.Shared.Missions)
    local Service = require(script.Parent.ShopService)
    local PetService = require(script.Parent.PetService)
    local Profiles = require(script.Parent.ProfileService)
    local Rocket = require(script.Parent.RocketService)

    -- Config: every catalog key has a price; IDs (once set) are unique positive integers;
    -- one gym pass per District tier, one product per fill size, one mission product per mission.
    local keys = {}
    for _, pass in Shop.Passes do table.insert(keys, pass.key) end
    for tier in config.TrainingTiers do table.insert(keys, Shop.gymKey(tier)) end
    for _, units in Shop.Fills do table.insert(keys, Shop.fillKey(units)) end
    for mission = 1, Missions.Count do table.insert(keys, Shop.nextKey(mission)) end
    table.insert(keys, "ServerTraining")
    table.insert(keys, "ExtraStay")
    local ids = {}
    for _, key in keys do
        local entry = Shop.entry(config, key)
        assert(entry and type(entry.price) == "number" and entry.price > 0 and entry.price % 1 == 0, key .. " needs a price")
        if entry.id ~= nil then
            assert(type(entry.id) == "number" and entry.id > 0 and entry.id % 1 == 0 and not ids[entry.id], key .. " has a bad or duplicate ID")
            ids[entry.id] = true
        end
    end
    for _, ids2 in config.RobuxUpgrades.passes do for _, id in ids2 do assert(not ids[id], "shop ID reuses an upgrade pass") end end
    local counted = 0
    for _ in config.Shop.passes do counted += 1 end
    for _ in config.Shop.products do counted += 1 end
    assert(counted == #keys, "Config.Shop has keys the catalog doesn't show")

    -- A missing ID turns the offer off.
    local fake = { Shop = { passes = { DoubleCoins = { price = 5 } }, products = { Fill2000 = { id = 11, price = 5 } } } }
    assert(not Shop.enabled(fake, "DoubleCoins") and Shop.enabled(fake, "Fill2000") and not Shop.enabled(fake, "Nope"))
    assert(next(Service.ids(fake, "passes")) == nil and Service.ids(fake, "products")[11] == "Fill2000")

    -- Availability: fills while building or fueling; stay and mission only for
    -- passengers at the destination, the mission before the spin and only once.
    assert(Shop.available(config, "Fill2000", { phase = "Building" }) and Shop.available(config, "Fill11000", { phase = "Fueling" }))
    assert(not Shop.available(config, "Fill2000", { phase = "Boarding" }) and Shop.available(config, "ServerTraining", { phase = "Launching" }))
    local there = { phase = "Rewarding", passenger = true, wheelSpun = false, guaranteed = false, stayExtra = 0 }
    assert(Shop.available(config, "ExtraStay", there) and Shop.available(config, "NextMars", there))
    assert(not Shop.available(config, "ExtraStay", { phase = "Rewarding", passenger = false }))
    assert(not Shop.available(config, "ExtraStay", { phase = "Rewarding", passenger = true, stayExtra = config.Shop.ExtraStayMax }))
    assert(not Shop.available(config, "NextMars", { phase = "Rewarding", passenger = true, wheelSpun = true }))
    assert(not Shop.available(config, "NextMars", { phase = "Rewarding", passenger = true, guaranteed = true }))

    -- Receipts: granted once, recorded before PurchaseGranted.
    local function harness()
        local h = { journal = {}, grants = 0, failRead = false, failWrite = false }
        h.state = { granted = {}, busy = {} }
        h.deps = {
            key = function(productId) return productId == 7 and "Fill2000" or nil end,
            seen = function(id) if h.failRead then return false end; return true, h.journal[id] ~= nil end,
            record = function(id) if h.failWrite then return false end; h.journal[id] = true; return true end,
            grant = function() h.grants += 1 end,
        }
        return h
    end
    local receipt = { PurchaseId = "p1", ProductId = 7, PlayerId = 1 }
    local h = harness()
    assert(Service.process(h.state, receipt, h.deps) == Service.GRANTED and h.grants == 1 and h.journal.p1)
    assert(Service.process(h.state, receipt, h.deps) == Service.GRANTED and h.grants == 1, "repeat receipt granted twice")
    -- Another server (fresh memory) sees the journal and doesn't grant again.
    local other = harness()
    other.journal = h.journal
    assert(Service.process(other.state, receipt, other.deps) == Service.GRANTED and other.grants == 0)
    -- Journal write fails: NotProcessedYet; the retry records without granting again.
    h = harness()
    h.failWrite = true
    assert(Service.process(h.state, receipt, h.deps) == Service.RETRY and h.grants == 1 and not h.journal.p1)
    h.failWrite = false
    assert(Service.process(h.state, receipt, h.deps) == Service.GRANTED and h.grants == 1 and h.journal.p1)
    -- Journal read fails: nothing granted yet.
    h = harness()
    h.failRead = true
    assert(Service.process(h.state, receipt, h.deps) == Service.RETRY and h.grants == 0)
    -- Unknown product or a bad PurchaseId: never granted.
    assert(Service.process(h.state, { PurchaseId = "p2", ProductId = 99 }, h.deps) == Service.RETRY)
    h.failRead = false
    assert(Service.process(h.state, { PurchaseId = "", ProductId = 7 }, h.deps) == Service.RETRY and h.grants == 0)
    -- A receipt already being processed (yielding) isn't processed again meanwhile.
    h.state.busy.p3 = true
    assert(Service.process(h.state, { PurchaseId = "p3", ProductId = 7 }, h.deps) == Service.RETRY and h.grants == 0)

    -- Training boost: stacks after what's left; 2x only while it runs.
    local effects = Service.newEffects()
    assert(Service.trainingMultiplier(config, effects, 100) == 1)
    Service.boost(effects, 100, 600)
    Service.boost(effects, 400, 600)
    assert(effects.boostUntil == 1300 and Service.trainingMultiplier(config, effects, 1299) == config.Shop.ServerTrainingMultiplier)
    assert(Service.trainingMultiplier(config, effects, 1300) == 1)
    Service.boost(effects, 5000, 600)
    assert(effects.boostUntil == 5600, "an expired boost restarts from now")

    -- Fill: flat units into whichever material the rocket needs now; Metal overflow
    -- carries into Fuel, Fuel overflow waits for the next rocket. Nobody's contribution.
    assert(#Shop.Fills == 4 and Shop.Fills[1] == 2000 and Shop.Fills[4] == 11000)
    local rocket = Rocket.new(config, "c1", 1, 0)
    local metal, fuel = rocket.required.Metal, rocket.required.Fuel
    effects.fillBank = 2000
    local added, advanced = Service.fill(rocket, effects)
    assert(added == 2000 and not advanced and rocket.totals.Metal == 2000 and effects.fillBank == 0 and next(rocket.contributions) == nil)
    rocket.totals.Metal = metal - 100
    rocket.cargo[5] = { count = 3, materials = { Metal = 3 } }
    effects.fillBank = 7000
    added, advanced = Service.fill(rocket, effects)
    assert(added == 100 and advanced and rocket.phase == "Fueling" and rocket.cargo[5] == nil, "fill finishes the phase like a delivery")
    assert(effects.fillBank == 6900)
    added, advanced = Service.fill(rocket, effects)
    assert(added == 6900 and not advanced and rocket.totals.Fuel == 6900 and effects.fillBank == 0, "Metal overflow goes into Fuel")
    effects.fillBank = 11000
    added = Service.fill(rocket, effects)
    assert(added == 11000 and rocket.totals.Fuel == 17900)
    rocket.totals.Fuel = fuel - 1
    effects.fillBank = 4000
    added, advanced = Service.fill(rocket, effects)
    assert(added == 1 and advanced and rocket.phase == "Boarding" and effects.fillBank == 3999)
    assert(Service.fill(rocket, effects) == 0 and effects.fillBank == 3999, "no fill outside delivery phases")
    assert(rocket:fill(-5) == 0 and rocket:fill("x") == 0)

    -- Stay: into the running stay, else banked for the next one.
    effects = Service.newEffects()
    assert(not Service.extendStay(effects, nil, 60) and effects.stayBank == 60)
    local stay = Service.beginStay(effects, 120)
    assert(stay.total == 180 and stay.extra == 60 and effects.stayBank == 0)
    assert(Service.extendStay(effects, stay, 60) and stay.total == 240 and stay.extra == 120)
    -- Guarantees: first bought, first used.
    table.insert(effects.guarantees, 3)
    table.insert(effects.guarantees, 5)
    assert(Service.takeGuarantee(effects) == 3 and Service.takeGuarantee(effects) == 5 and Service.takeGuarantee(effects) == nil)

    -- Pass sync: failed checks are unknown, not "not owned".
    local real = { Shop = { passes = { DoubleCoins = { id = 1, price = 1 }, PetSlot1 = { id = 2, price = 1 }, PetSlot2 = { id = 3, price = 1 }, FastHatch = { price = 1 } } } }
    local owned, checked = Service.sync(real, function(id)
        if id == 3 then error("throttled") end
        return id == 2
    end)
    assert(owned.PetSlot1 and not owned.DoubleCoins and checked.DoubleCoins and checked.PetSlot1 and not checked.PetSlot2 and not checked.FastHatch)

    -- Pet slots: 3, +1, +2, both = 6; equips and landings respect them; trims when gone.
    assert(Shop.petSlots({}) == 3 and Shop.petSlots({ PetSlot1 = true }) == 4 and Shop.petSlots({ PetSlot2 = true }) == 5)
    assert(Shop.petSlots({ PetSlot1 = true, PetSlot2 = true }) == 6 and Shop.MaxPetSlots == 6)
    local profile = Profiles.validate(nil, config)
    local id = Pets.Catalog[1].Id
    profile.pets[id] = 6
    for _ = 1, 3 do assert(PetService.equip(profile, id, true)) end
    assert(select(2, PetService.equip(profile, id, true)) == "full")
    assert(PetService.equip(profile, id, true, 6) and PetService.equip(profile, id, true, 6) and PetService.equip(profile, id, true, 6))
    assert(#profile.equippedPets == 6 and Profiles.validate(profile, config), "six equipped pets must save")
    assert(Service.trim(profile, 4) and #profile.equippedPets == 4 and not Service.trim(profile, 4))

    -- Triple Hatch: 3x the coins, one UFO, three pets granted on landing.
    local random = Random.new(7)
    profile = Profiles.validate(nil, config)
    profile.coins = 1500
    assert(PetService.buy(profile, 1, "t1", random, 3) == 1500 and profile.coins == 0 and #profile.ufo.extra == 2)
    assert(PetService.buy(profile, 1, "t2", random, 4) == nil, "at most 3 per UFO")
    local saved = Profiles.validate(profile, config)
    assert(#saved.ufo.extra == 2 and saved.ufo.extra ~= profile.ufo.extra, "extra pets survive a save")
    local first, _, extra = PetService.advance(profile, 1e6, 3)
    local total = 0
    for _, count in profile.pets do total += count end
    assert(first and #extra == 2 and total == 3 and #profile.equippedPets == 3)
    -- Fast Hatch is just a faster countdown: twice the seconds per tick.
    profile.coins = 500
    PetService.buy(profile, 1, "t3", random)
    assert(PetService.advance(profile, 150 * 2) and profile.ufo == nil)

    -- 2x Coins: the multiplier only scales coins, not deliveries.
    profile = Profiles.validate(nil, config)
    assert(Profiles.credit(profile, 10, config, 2) == 20 * config.CoinsPerUnit and profile.lifetimeDeliveries == 10)
    assert(Profiles.credit(profile, 10, config) == 10 * config.CoinsPerUnit)
end
