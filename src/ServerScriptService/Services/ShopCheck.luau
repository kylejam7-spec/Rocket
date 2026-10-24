-- The Robux SHOP: the catalog and config agree; receipts are claimed atomically in the
-- buyer's ledger and applied once across servers (a failed or lost-answer write means
-- NotProcessedYet and no second grant), banks stay owed by PurchaseId until used and a
-- crashed or closed server's are taken over once; product effects (boost stacking, fill
-- banked across phases, stay extensions, guaranteed missions) and pass effects (pet slots,
-- Triple Hatch's 3 UFOs at once, 2x Coins, trims when a slot pass is gone, refunded passes,
-- failed ownership checks, Studio test purchases).
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
    for _, skin in require(ReplicatedStorage.Shared.Skins).List do table.insert(keys, skin.key) end
    for tier in config.TrainingTiers do table.insert(keys, Shop.gymKey(tier)) end
    table.insert(keys, config.SpaceXGym.key)
    for _, units in Shop.Fills do table.insert(keys, Shop.fillKey(units)) end
    for mission = 1, Missions.Count do table.insert(keys, Shop.nextKey(mission)) end
    for tier = 3, #Pets.Ufos do table.insert(keys, Shop.ufoKey(tier)) end
    assert(Shop.ufoKey(3) == "UfoRare" and Shop.ufoKey(5) == "UfoLegendary" and Shop.ufoKey(9) == nil)
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
    -- Robux UFOs: only with a free UFO slot (1, or 3 with Triple Hatch), in any phase.
    assert(Shop.available(config, "UfoEpic", { phase = "Launching", ufos = 0, maxUfos = 1 }))
    assert(not Shop.available(config, "UfoEpic", { ufos = 1, maxUfos = 1 }) and Shop.available(config, "UfoRare", { ufos = 2, maxUfos = 3 }))

    -- Receipts: claimed atomically in the buyer's ledger (one store, many servers), applied
    -- once, what's banked kept owed there until used, recovered after a crash or shutdown.
    local store = Service.memoryStore()
    local clock = { now = 1000 }
    local function server(name)
        local h = { grants = 0, held = {}, failWrite = false, loseResponse = false, applyResult = nil }
        h.state = { owner = name, applied = {}, busy = {} }
        h.update = function(userId, transform)
            if h.failWrite then return false end
            store:UpdateAsync("Buyer_" .. userId, function(raw)
                local ledger = Service.ledger(raw)
                if not transform(ledger, clock.now) then return nil end
                return ledger
            end)
            -- The write went through but its answer was lost.
            if h.loseResponse then return false end
            return true
        end
        h.deps = {
            key = function(productId) return productId == 7 and "Fill2000" or productId == 8 and "UfoRare" or nil end,
            amount = function(key) return key == "Fill2000" and 2000 or 1 end,
            update = h.update,
            apply = function(key, _, value)
                if h.applyResult ~= nil then return h.applyResult end
                h.grants += 1
                return key == "Fill2000" and value or 0
            end,
            hold = function(_, id, _, left) h.held[id] = left end,
        }
        h.settle = function(release)
            local finished
            h.update(1, function(ledger, now) finished = Service.settle(ledger, name, h.held, now, release); return true end)
            for id in finished or {} do h.held[id] = nil end
            return finished
        end
        return h
    end
    local function ledger() return Service.ledger(store.data.Buyer_1) end
    local receipt = { PurchaseId = "p1", ProductId = 7, PlayerId = 1 }
    local a, b = server("A"), server("B")
    assert(Service.process(a.state, receipt, a.deps) == Service.GRANTED and a.grants == 1 and a.held.p1 == 2000)
    assert(ledger().open.p1.owner == "A" and ledger().open.p1.amount == 2000, "claim not recorded with what's owed")
    assert(Service.process(a.state, receipt, a.deps) == Service.GRANTED and a.grants == 1, "repeat receipt granted twice")
    -- Another server while A's claim is live: not granted there (the cross-server double grant).
    assert(Service.process(b.state, receipt, b.deps) == Service.RETRY and b.grants == 0)
    -- A uses the bank up: done; B then grants with nothing applied.
    a.held.p1 = 0
    assert(a.settle().p1 == "done" and ledger().open.p1 == nil and table.find(ledger().done, "p1"))
    assert(Service.process(b.state, receipt, b.deps) == Service.GRANTED and b.grants == 0)
    -- Ledger write fails: NotProcessedYet and nothing applied; the retry grants once.
    local c = server("C")
    c.failWrite = true
    local r2 = { PurchaseId = "p2", ProductId = 7, PlayerId = 1 }
    assert(Service.process(c.state, r2, c.deps) == Service.RETRY and c.grants == 0 and not ledger().open.p2)
    c.failWrite = false
    assert(Service.process(c.state, r2, c.deps) == Service.GRANTED and c.grants == 1)
    -- Claim committed but its answer lost: NotProcessedYet, nothing applied; the retry
    -- finds its own claim and applies once; another server never does.
    local d = server("D")
    d.loseResponse = true
    local r3 = { PurchaseId = "p3", ProductId = 7, PlayerId = 1 }
    assert(Service.process(d.state, r3, d.deps) == Service.RETRY and d.grants == 0 and ledger().open.p3.owner == "D")
    d.loseResponse = false
    assert(Service.process(b.state, r3, b.deps) == Service.RETRY and b.grants == 0)
    assert(Service.process(d.state, r3, d.deps) == Service.GRANTED and d.grants == 1)
    -- D crashes holding 1,500 units banked: after the lease runs out the buyer's next
    -- server takes the claim over with what's still owed, once. C (alive) renews p2.
    d.held.p3 = 1500
    d.settle()
    clock.now += Service.LeaseSeconds + 1
    c.held.p2 = 700
    c.settle()
    local taken
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, Service.isUfo); return next(taken) ~= nil end)
    assert(taken.p3 and taken.p3.amount == 1500 and not taken.p2, "crashed server's bank not recovered (or a live one taken)")
    assert(ledger().open.p3.owner == "B")
    b.update(1, function(l, now) taken = Service.takeover(l, "E", now, Service.isUfo); return next(taken) ~= nil end)
    assert(next(taken) == nil, "a recovered claim was taken twice")
    -- If D comes back it finds the claim gone and drops its own bank of it.
    assert(d.settle().p3 == "gone")
    local effects = Service.newEffects()
    Service.bankFill(effects, 500, "p3")
    Service.bankFill(effects, 300, "p9")
    Service.guarantee(effects, 2, "p3")
    Service.forfeit(effects, "p3")
    assert(effects.fillBank == 300 and #effects.fills == 1 and #effects.guarantees == 0)
    -- Shutdown lets go: the buyer's next server takes over at once (no lease wait).
    c.settle(true)
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, Service.isUfo); return next(taken) ~= nil end)
    assert(taken.p2 and taken.p2.amount == 700, "released claim not taken over")
    -- A UFO that can't be applied here (buyer gone, or their save failed): NotProcessedYet
    -- and the claim let go, so the server they're on now can claim it at once. Recovery on
    -- join leaves UFOs to Roblox's own retry.
    local ufo = { PurchaseId = "u1", ProductId = 8, PlayerId = 1 }
    a.applyResult = false
    assert(Service.process(a.state, ufo, a.deps) == Service.RETRY and ledger().open.u1.leaseUntil == 0)
    a.applyResult = nil
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, Service.isUfo); return next(taken) ~= nil end)
    assert(not taken.u1, "takeover took a UFO")
    assert(Service.process(b.state, ufo, b.deps) == Service.GRANTED and b.grants == 1 and b.held.u1 == 0)
    -- A UFO's apply repeats safely (the profile's ledger), so its retry applies again.
    assert(not b.state.applied.u1)
    -- Unknown product, bad PurchaseId or buyer: never granted.
    assert(Service.process(a.state, { PurchaseId = "p4", ProductId = 99, PlayerId = 1 }, a.deps) == Service.RETRY)
    assert(Service.process(a.state, { PurchaseId = "", ProductId = 7, PlayerId = 1 }, a.deps) == Service.RETRY)
    assert(Service.process(a.state, { PurchaseId = "p4", ProductId = 7 }, a.deps) == Service.RETRY and a.grants == 1)
    -- A receipt already being processed (yielding) isn't processed again meanwhile.
    a.state.busy.p5 = true
    assert(Service.process(a.state, { PurchaseId = "p5", ProductId = 7, PlayerId = 1 }, a.deps) == Service.RETRY and a.grants == 1)
    -- The done list stays bounded.
    local long = Service.ledger(nil)
    for index = 1, Service.DoneLimit + 20 do
        Service.claim(long, "q" .. index, { key = "Fill2000", amount = 1 }, "A", 0)
        Service.settle(long, "A", { ["q" .. index] = 0 }, 0)
    end
    assert(#long.done == Service.DoneLimit and long.done[1] == "q21" and Service.claim(long, "q30", {}, "B", 0) == "done")

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
    assert(#Shop.Fills == 5 and Shop.Fills[1] == 2000 and Shop.Fills[4] == 11000 and Shop.Fills[5] == 27500)
    assert(config.Shop.products.Fill27500.id == 3720426887 and config.Shop.products.Fill27500.price == 239)
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
    -- Banked fill remembers whose purchase it is: used oldest first, what's left owed
    -- per purchase (what the ledger records, so a crash can't lose it).
    local fresh = Rocket.new(config, "c2", 1, 0)
    effects = Service.newEffects()
    fresh.totals.Metal = fresh.required.Metal - 500
    fresh.totals.Fuel = 0
    Service.bankFill(effects, 300, "f1")
    Service.bankFill(effects, 2000, "f2")
    fresh.phase = "Boarding"
    assert(Service.fill(fresh, effects) == 0 and Service.owed(effects, "f1") == 300 and Service.owed(effects, "f2") == 2000)
    fresh.phase = "Building"
    added = Service.fill(fresh, effects)
    assert(added == 500 and Service.owed(effects, "f1") == 0 and Service.owed(effects, "f2") == 1800 and effects.fillBank == 1800)

    -- Stay: into the running stay, else banked for the next one.
    effects = Service.newEffects()
    assert(not Service.extendStay(effects, nil, 60, "s1") and effects.stayBank == 60 and Service.owed(effects, "s1") == 60)
    local stay = Service.beginStay(effects, 120)
    assert(stay.total == 180 and stay.extra == 60 and effects.stayBank == 0 and Service.owed(effects, "s1") == 0, "a used stay bank still owed")
    assert(Service.extendStay(effects, stay, 60) and stay.total == 240 and stay.extra == 120)
    -- Guarantees: first bought, first used.
    Service.guarantee(effects, 3, "g1")
    Service.guarantee(effects, 5, "g2")
    assert(Service.owed(effects, "g2") == 1)
    assert(Service.takeGuarantee(effects) == 3 and Service.takeGuarantee(effects) == 5 and Service.takeGuarantee(effects) == nil)

    -- Pass sync: failed checks are unknown, not "not owned".
    local real = { Shop = { passes = { DoubleCoins = { id = 1, price = 1 }, PetSlot1 = { id = 2, price = 1 }, PetSlot2 = { id = 3, price = 1 }, FastHatch = { price = 1 } } } }
    local owned, checked = Service.sync(real, function(id)
        if id == 3 then error("throttled") end
        return id == 2
    end)
    assert(owned.PetSlot1 and not owned.DoubleCoins and checked.DoubleCoins and checked.PetSlot1 and not checked.PetSlot2 and not checked.FastHatch)
    -- Passes saved on the profile (bought here): Roblox's answer wins (a refunded pass is
    -- gone), the saved key stands in when the check fails or the pass has no ID.
    local function saying(id)
        if id == 3 then error("throttled") end
        return false
    end
    owned, checked = Service.sync(real, saying, { "DoubleCoins", "PetSlot2", "FastHatch" })
    assert(not owned.DoubleCoins and checked.DoubleCoins, "a refunded pass still counts")
    assert(owned.PetSlot2 and checked.PetSlot2 and owned.FastHatch and not owned.PetSlot1 and checked.PetSlot1, "saved key not used when the check failed")
    -- Studio (trustSaved): test purchases never show up in the check, so saved keys count.
    owned = Service.sync(real, saying, { "DoubleCoins" }, true)
    assert(owned.DoubleCoins, "Studio test purchase lost")

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

    -- Triple Hatch: up to 3 UFOs fly at once, each at its normal price, counting down
    -- together; without it, one at a time.
    local random = Random.new(7)
    profile = Profiles.validate(nil, config)
    profile.coins = 5000
    assert(PetService.buy(profile, 1, "t1", random) == 500 and select(2, PetService.buy(profile, 1, "t2", random)) == "busy")
    assert(PetService.buy(profile, 1, "t2", random, 3) == 500 and PetService.buy(profile, 2, "t3", random, 3) == nil, "Uncommon costs 5K")
    profile.coins = 1000
    assert(PetService.buy(profile, 1, "t3", random, 3) == 500 and profile.coins == 500 and #profile.ufos == 3)
    assert(select(2, PetService.buy(profile, 1, "t4", random, 3)) == "busy" and profile.coins == 500, "a fourth UFO")
    local saved = Profiles.validate(profile, config)
    local ids = { profile.ufos[1].id, profile.ufos[2].id, profile.ufos[3].id }
    assert(ids[1] ~= ids[2] and ids[2] ~= ids[3] and ids[1] ~= ids[3], "UFO ids repeat on a profile")
    assert(#saved.ufos == 3 and saved.ufos[1] ~= profile.ufos[1] and saved.ufos[2].id == ids[2], "UFOs survive a save as copies")
    assert(PetService.advance(profile, 100, 3) == nil and profile.ufos[3].remaining == 200, "all count down together")
    profile.ufos[2].remaining = 50
    local first, _, others = PetService.advance(profile, 60, 3)
    assert(first and #others == 0 and #profile.ufos == 2 and profile.ufos[2].id == ids[3], "the due one lands, order kept")
    first, _, others = PetService.advance(profile, 1e6, 3)
    local total = 0
    for _, count in profile.pets do total += count end
    assert(first and #others == 1 and total == 3 and #profile.ufos == 0 and #profile.equippedPets == 3)
    -- Robux UFOs (PetService.add): a profile never holds more than 3.
    local held = Profiles.validate(nil, config)
    for _ = 1, 3 do assert(PetService.add(held, 5, random)) end
    assert(not PetService.add(held, 4, random) and #held.ufos == 3 and held.ufos[1].tier == 5 and held.ufos[1].remaining == Pets.Ufos[5].Seconds)
    -- Fast Hatch is just a faster countdown: twice the seconds per tick.
    profile.coins = 500
    PetService.buy(profile, 1, "t5", random)
    assert(PetService.advance(profile, 150 * 2) and #profile.ufos == 0)

    -- 2x Coins: the multiplier only scales coins, not deliveries.
    profile = Profiles.validate(nil, config)
    assert(Profiles.credit(profile, 10, config, 2) == 20 * config.CoinsPerUnit and profile.lifetimeDeliveries == 10)
    assert(Profiles.credit(profile, 10, config) == 10 * config.CoinsPerUnit)
end
