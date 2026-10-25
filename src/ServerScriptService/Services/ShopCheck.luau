-- The Robux SHOP: the catalog and config agree; receipts are claimed atomically in the
-- buyer's ledger and applied once across servers; units are marked used in the ledger
-- before any server uses them (write-ahead), so failed or lost-answer writes, crashes and
-- lease expiry can't apply a purchase twice, and a crashed or closed server's unmarked
-- units are taken over once; offer limits hold for receipts too (ExtraStayMax, one
-- locked mission a spin); product effects (boost stacking, fill banked across phases,
-- stay extensions, guaranteed missions) and pass effects (pet slots, Triple Hatch's 3 UFOs
-- at once, 2x Coins, trims when a slot pass is gone, refunded passes, failed ownership
-- checks, Studio test purchases); Robux UFOs (paid random items) off for players
-- PolicyService restricts or doesn't answer for, coin UFOs open to everyone.
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

    -- Paid random items (PolicyService): Robux UFOs don't prompt for a restricted player,
    -- or one whose lookup never answered (fail closed: unknown counts as restricted); they
    -- do for an unrestricted one. Nothing else in the shop is a paid random item.
    for tier = 3, #Pets.Ufos do
        local key = Shop.ufoKey(tier)
        assert(Shop.paidRandom(key) and Service.policyRefusal(key, true) and Service.policyRefusal(key, nil), key .. " prompted for a restricted player")
        assert(Service.policyRefusal(key, false) == nil, key .. " refused for an unrestricted player")
    end
    for _, key in keys do
        if not key:match("^Ufo") then assert(not Shop.paidRandom(key) and Service.policyRefusal(key, true) == nil, key .. " counted as paid random") end
    end
    local tries, pauses = 0, 0
    local function asked(answer) return function() tries += 1; return answer() end end
    local function pause() pauses += 1 end
    assert(select(1, Service.policyRestricted(asked(function() return { ArePaidRandomItemsRestricted = true } end), 3, pause)) == true and tries == 1)
    tries = 0
    local restricted, answered = Service.policyRestricted(asked(function() return { ArePaidRandomItemsRestricted = false } end), 3, pause)
    assert(restricted == false and answered and tries == 1 and pauses == 0)
    -- Failing every time: restricted, after all 3 tries.
    tries = 0
    restricted, answered = Service.policyRestricted(asked(function() error("PolicyService down") end), 3, pause)
    assert(restricted == true and not answered and tries == 3 and pauses == 2, "a failed policy lookup must count as restricted")
    -- A bad answer counts as a failure; a retry that answers wins.
    tries = 0
    restricted = Service.policyRestricted(asked(function()
        if tries < 2 then return {} end
        return { ArePaidRandomItemsRestricted = false }
    end), 3, pause)
    assert(restricted == false and tries == 2)
    -- Coin UFOs (BuyUfo, PetService.buy) never ask the policy: a restricted player buys
    -- the Rare UFO for coins.
    local coinBuyer = Profiles.validate(nil, config)
    coinBuyer.coins = Pets.Ufos[3].Price
    assert(PetService.buy(coinBuyer, 3, "policy1", Random.new(1)) == Pets.Ufos[3].Price and #coinBuyer.ufos == 1, "coin UFOs must stay buyable")

    -- Receipts: claimed atomically in the buyer's ledger (one store, many servers). Units
    -- are marked used there before any server uses them (write-ahead), so failed writes,
    -- lost answers, crashes and lease expiry can't apply a purchase twice.
    local store = Service.memoryStore()
    local clock = { now = 1000 }
    local function server(name)
        local h = { grants = 0, applied = {}, held = {}, failWrite = false, loseResponse = false, applyOk = true, plans = {} }
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
            key = function(productId) return productId == 7 and "Fill2000" or productId == 8 and "UfoRare" or productId == 9 and "ServerTraining" or nil end,
            amount = function(key) return key == "Fill2000" and 2000 or key == "ServerTraining" and 600 or 1 end,
            plan = function(key, owed) return math.min(owed, h.plans[key] or 0) end,
            instant = function(key) return key == "ServerTraining" end,
            update = h.update,
            apply = function(_, receipt, value, used)
                if not h.applyOk then return false end
                h.grants += 1
                h.applied[receipt.PurchaseId] = { value = value, used = used }
                return true
            end,
            hold = function(_, id, _, owed) h.held[id] = owed end,
        }
        -- This server's writes to its claims (Service.settle).
        h.write = function(changes, release)
            local results
            h.update(1, function(l, now) results = Service.settle(l, name, changes, now, release); return true end)
            return results
        end
        return h
    end
    local function ledger() return Service.ledger(store.data.Buyer_1) end
    local function skipUfo(_, entry) return Service.isUfo(entry.key) end
    local receipt = { PurchaseId = "p1", ProductId = 7, PlayerId = 1 }
    local a, b = server("A"), server("B")
    -- A fill the rocket can take 500 of now: those 500 are marked (pending) in the claim itself.
    a.plans.Fill2000 = 500
    assert(Service.process(a.state, receipt, a.deps) == Service.GRANTED and a.grants == 1)
    assert(a.applied.p1.value == 2000 and a.applied.p1.used == 500 and a.held.p1 == 1500)
    assert(ledger().open.p1.owner == "A" and ledger().open.p1.amount == 1500 and ledger().open.p1.pending == 500, "claim didn't mark what's used at once")
    assert(Service.process(a.state, receipt, a.deps) == Service.GRANTED and a.grants == 1, "repeat receipt granted twice")
    -- Another server while A's claim is live: not granted there (the cross-server double grant).
    assert(Service.process(b.state, receipt, b.deps) == Service.RETRY and b.grants == 0)
    -- Write-ahead: A marks more before using it (never more than is owed) and confirms what
    -- it used; it closes only once everything marked is confirmed.
    local r = a.write({ p1 = { use = 1000, deliver = 400 } })
    assert(r.p1.status == "held" and r.p1.used == 1000 and r.p1.delivered == 400 and ledger().open.p1.amount == 500 and ledger().open.p1.pending == 1100)
    r = a.write({ p1 = { use = 9999, close = true } })
    assert(r.p1.used == 500 and r.p1.status == "held" and ledger().open.p1.pending == 1600, "closed with marked units unconfirmed")
    r = a.write({ p1 = { deliver = 1600, close = true } })
    assert(r.p1.status == "done" and ledger().open.p1 == nil and table.find(ledger().done, "p1"))
    assert(Service.process(b.state, receipt, b.deps) == Service.GRANTED and b.grants == 0)
    -- A boost used at once, then A's writes fail past its lease. The claim already recorded
    -- all 600 seconds used (not pending: it's applied in the same instant), so no server
    -- can apply them again.
    local boost = { PurchaseId = "p9", ProductId = 9, PlayerId = 1 }
    a.plans.ServerTraining = 600
    assert(Service.process(a.state, boost, a.deps) == Service.GRANTED and a.applied.p9.used == 600 and ledger().open.p9.amount == 0 and ledger().open.p9.pending == 0)
    clock.now += Service.LeaseSeconds + 1
    local taken
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, skipUfo); return true end)
    assert(not taken.p9 and ledger().open.p9 == nil and table.find(ledger().done, "p9"), "a used-up claim was recovered")
    assert(Service.process(b.state, boost, b.deps) == Service.GRANTED and b.grants == 0, "boost applied on a second server")
    -- Ledger write fails: NotProcessedYet and nothing applied; the retry grants once.
    local c = server("C")
    c.failWrite = true
    local r2 = { PurchaseId = "p2", ProductId = 7, PlayerId = 1 }
    assert(Service.process(c.state, r2, c.deps) == Service.RETRY and c.grants == 0 and not ledger().open.p2)
    c.failWrite = false
    assert(Service.process(c.state, r2, c.deps) == Service.GRANTED and c.grants == 1 and c.applied.p2.used == 0)
    -- Claim committed but its answer lost (300 units already marked for D): NotProcessedYet,
    -- nothing applied; D's retry applies those same 300 (marking no more), once; another
    -- server never does.
    local d = server("D")
    d.plans.Fill2000 = 300
    d.loseResponse = true
    local r3 = { PurchaseId = "p3", ProductId = 7, PlayerId = 1 }
    assert(Service.process(d.state, r3, d.deps) == Service.RETRY and d.grants == 0 and ledger().open.p3.owner == "D" and ledger().open.p3.amount == 1700)
    d.loseResponse = false
    assert(Service.process(b.state, r3, b.deps) == Service.RETRY and b.grants == 0)
    d.plans.Fill2000 = 0
    assert(Service.process(d.state, r3, d.deps) == Service.GRANTED and d.grants == 1)
    assert(d.applied.p3.used == 300 and d.applied.p3.value == 2000 and ledger().open.p3.amount == 1700, "lost-answer retry lost or doubled the marked units")
    -- D crashes holding 500 units marked but never confirmed used. When its lease runs out
    -- the claim isn't free yet: those 500 might still be in use on a D that merely can't
    -- write. PendingGraceSeconds later the buyer's next server takes over the claim with
    -- all 2,000 owed again (nothing paid for is lost), once. C (alive) renews p2.
    d.write({ p3 = { use = 200 } })
    local dLease = ledger().open.p3.leaseUntil
    clock.now = dLease + 1
    c.write({ p2 = {} })
    local retryAt
    b.update(1, function(l, now) taken, retryAt = Service.takeover(l, "B", now, skipUfo); return next(taken) ~= nil end)
    assert(not taken.p3 and Service.freeAt(ledger().open.p3) == dLease + Service.PendingGraceSeconds and retryAt ~= nil,
        "a claim with unconfirmed units was taken before its grace")
    assert(Service.process(b.state, r3, b.deps) == Service.RETRY and b.grants == 0)
    clock.now = dLease + Service.PendingGraceSeconds
    c.write({ p2 = {} })
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, skipUfo); return next(taken) ~= nil end)
    assert(taken.p3 and taken.p3.amount == 2000 and taken.p3.pending == 0 and not taken.p2, "crashed server's marked units not recovered (or a live claim taken)")
    b.update(1, function(l, now) taken = Service.takeover(l, "E", now, skipUfo); return next(taken) ~= nil end)
    assert(next(taken) == nil, "a recovered claim was taken twice")
    -- If D comes back it finds the claim gone and can't mark any more of it.
    r = d.write({ p3 = { use = 100, deliver = 100 } })
    assert(r.p3.status == "gone" and r.p3.used == 0 and r.p3.delivered == 0 and ledger().open.p3.amount == 2000)
    -- Shutdown confirms what was used, hands back marked-but-unused units and lets go: the
    -- next server takes the rest at once.
    c.write({ p2 = { use = 400, deliver = 250 } })
    c.write({ p2 = { give = 150 } }, true)
    assert(ledger().open.p2.amount == 1750 and ledger().open.p2.pending == 0 and ledger().open.p2.leaseUntil == clock.now)
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, skipUfo); return next(taken) ~= nil end)
    assert(taken.p2 and taken.p2.amount == 1750, "released claim not taken over")
    -- A UFO that can't be applied here (buyer gone, or their save failed): NotProcessedYet
    -- and the claim let go, so the server they're on now can claim it at once. Recovery on
    -- join leaves UFOs to Roblox's own retry.
    local ufo = { PurchaseId = "u1", ProductId = 8, PlayerId = 1 }
    a.applyOk = false
    assert(Service.process(a.state, ufo, a.deps) == Service.RETRY and ledger().open.u1.leaseUntil == clock.now)
    a.applyOk = true
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, skipUfo); return true end)
    assert(not taken.u1, "takeover took a UFO")
    local bGrants = b.grants
    assert(Service.process(b.state, ufo, b.deps) == Service.GRANTED and b.grants == bGrants + 1 and b.held.u1 == 1)
    -- The audit's case: 60 s of ExtraStay marked for a running stay, then the server stops
    -- before applying them (its trips were still saving). The seconds are pending, not
    -- lost: the buyer's next server gets all 60 once the lease and the grace have run out.
    local stop = server("S")
    stop.update(1, function(l, now)
        Service.claim(l, "x1", { key = "ExtraStay", amount = 60 }, "S", now, function(owed) return owed end)
        return true
    end)
    local x = ledger().open.x1
    assert(x.amount == 0 and x.pending == 60)
    clock.now = x.leaseUntil + 1
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, skipUfo); return true end)
    assert(not taken.x1 and ledger().open.x1 and Service.freeAt(ledger().open.x1) == x.leaseUntil + Service.PendingGraceSeconds, "marked seconds closed or taken too soon")
    clock.now = Service.freeAt(ledger().open.x1)
    b.update(1, function(l, now) taken = Service.takeover(l, "B", now, skipUfo); return true end)
    assert(taken.x1 and taken.x1.amount == 60 and taken.x1.pending == 0, "marked but undelivered seconds lost")
    -- A UFO's apply repeats safely (the profile's ledger), so its retry applies again.
    assert(not b.state.applied.u1)
    -- Unknown product, bad PurchaseId or buyer: never granted.
    local aGrants = a.grants
    assert(Service.process(a.state, { PurchaseId = "p4", ProductId = 99, PlayerId = 1 }, a.deps) == Service.RETRY)
    assert(Service.process(a.state, { PurchaseId = "", ProductId = 7, PlayerId = 1 }, a.deps) == Service.RETRY)
    assert(Service.process(a.state, { PurchaseId = "p4", ProductId = 7 }, a.deps) == Service.RETRY and a.grants == aGrants)
    -- A receipt already being processed (yielding) isn't processed again meanwhile.
    a.state.busy.p5 = true
    assert(Service.process(a.state, { PurchaseId = "p5", ProductId = 7, PlayerId = 1 }, a.deps) == Service.RETRY and a.grants == aGrants)

    -- A buyer who rejoins while a crashed server's lease still runs gets nothing yet, and
    -- is told when to try again: the moment that lease runs out.
    local retryStore = Service.memoryStore()
    local function retryUpdate(owner, now)
        local taken2, retryAt
        retryStore:UpdateAsync("Buyer_1", function(raw)
            local l = Service.ledger(raw)
            -- (Claims it took are held, so skipped, as the service does.)
            taken2, retryAt = Service.takeover(l, owner, now, function(_, e) return Service.isUfo(e.key) or e.owner == owner end)
            return l
        end)
        return taken2, retryAt
    end
    retryStore:UpdateAsync("Buyer_1", function(raw)
        local l = Service.ledger(raw)
        Service.claim(l, "m1", { key = "NextMars", amount = 1 }, "Crashed", 5000)
        Service.claim(l, "m2", { key = "ExtraStay", amount = 60 }, "Crashed", 5100)
        return l
    end)
    local taken2, retryAt = retryUpdate("New", 5001)
    assert(next(taken2) == nil and retryAt == 5000 + Service.LeaseSeconds, "no retry time for a live lease")
    taken2, retryAt = retryUpdate("New", retryAt)
    assert(taken2.m1 and not taken2.m2 and retryAt == 5100 + Service.LeaseSeconds, "retry didn't take the expired claim")
    taken2, retryAt = retryUpdate("New", retryAt)
    assert(taken2.m2 and retryAt == nil)
    -- A claim this server still holds is never taken back from itself; one it let go of
    -- (or stopped renewing) is, once its lease has run out.
    retryStore:UpdateAsync("Buyer_1", function(raw)
        local l = Service.ledger(raw)
        Service.claim(l, "m3", { key = "Fill2000", amount = 2000 }, "New", 9000)
        return l
    end)
    local stillHeld = { m3 = true }
    local function skipHeld(id, entry) return Service.isUfo(entry.key) or stillHeld[id] end
    local t3
    retryStore:UpdateAsync("Buyer_1", function(raw)
        local l = Service.ledger(raw)
        t3 = Service.takeover(l, "New", 9000 + Service.LeaseSeconds, skipHeld)
        return l
    end)
    assert(not t3.m3, "took back a claim it still holds")
    stillHeld.m3 = nil
    retryStore:UpdateAsync("Buyer_1", function(raw)
        local l = Service.ledger(raw)
        t3 = Service.takeover(l, "New", 9000 + Service.LeaseSeconds, skipHeld)
        return l
    end)
    assert(t3.m3 and t3.m3.amount == 2000, "a claim let go of wasn't recovered")

    -- The done list stays bounded.
    local long = Service.ledger(nil)
    for index = 1, Service.DoneLimit + 20 do
        Service.claim(long, "q" .. index, { key = "Fill2000", amount = 1 }, "A", 0)
        Service.settle(long, "A", { ["q" .. index] = { use = 1, deliver = 1, close = true } }, 0)
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
    -- Only reserved units (marked used in the ledger) are ever poured.
    assert(#Shop.Fills == 5 and Shop.Fills[1] == 2000 and Shop.Fills[4] == 11000 and Shop.Fills[5] == 27500)
    assert(config.Shop.products.Fill27500.id == 3720426887 and config.Shop.products.Fill27500.price == 239)
    local rocket = Rocket.new(config, "c1", 1, 0)
    local metal, fuel = rocket.required.Metal, rocket.required.Fuel
    assert(Service.room(rocket) == metal + fuel, "room while building counts the fuel after it")
    Service.bankFill(effects, 2000, "a", 2000)
    local added, advanced = Service.fill(rocket, effects)
    assert(added == 2000 and not advanced and rocket.totals.Metal == 2000 and effects.fillBank == 0 and next(rocket.contributions) == nil)
    rocket.totals.Metal = metal - 100
    rocket.cargo[5] = { count = 3, materials = { Metal = 3 } }
    Service.bankFill(effects, 7000, "b", 7000)
    added, advanced = Service.fill(rocket, effects)
    assert(added == 100 and advanced and rocket.phase == "Fueling" and rocket.cargo[5] == nil, "fill finishes the phase like a delivery")
    assert(effects.fillBank == 6900 and Service.room(rocket) == fuel)
    added, advanced = Service.fill(rocket, effects)
    assert(added == 6900 and not advanced and rocket.totals.Fuel == 6900 and effects.fillBank == 0, "Metal overflow goes into Fuel")
    Service.bankFill(effects, 11000, "c", 11000)
    added = Service.fill(rocket, effects)
    assert(added == 11000 and rocket.totals.Fuel == 17900)
    rocket.totals.Fuel = fuel - 1
    Service.bankFill(effects, 4000, "d", 4000)
    added, advanced = Service.fill(rocket, effects)
    assert(added == 1 and advanced and rocket.phase == "Boarding" and effects.fillBank == 3999)
    assert(Service.fill(rocket, effects) == 0 and effects.fillBank == 3999 and Service.room(rocket) == 0, "no fill outside delivery phases")
    assert(rocket:fill(-5) == 0 and rocket:fill("x") == 0)
    -- Unreserved fill is never poured; reserving lets exactly that much in, oldest first.
    local fresh = Rocket.new(config, "c2", 1, 0)
    effects = Service.newEffects()
    fresh.totals.Metal = fresh.required.Metal - 500
    Service.bankFill(effects, 300, "f1", 0)
    Service.bankFill(effects, 2000, "f2", 0)
    assert(Service.fill(fresh, effects) == 0, "unreserved fill was poured")
    Service.reserve(effects, "f1", 300)
    Service.reserve(effects, "f2", 200)
    assert(Service.reservedFill(effects) == 500)
    added = Service.fill(fresh, effects)
    local left, reserved = Service.owed(effects, "f2")
    assert(added == 500 and Service.owed(effects, "f1") == 0 and left == 1800 and reserved == 0 and effects.fillBank == 1800)
    -- Another server took f2's claim over: what isn't reserved here goes; reserved stays.
    Service.reserve(effects, "f2", 100)
    Service.forfeit(effects, "f2")
    left, reserved = Service.owed(effects, "f2")
    assert(left == 100 and reserved == 100 and effects.fillBank == 100, "forfeit dropped reserved units or kept unreserved ones")

    -- Stay: reserved time into the running stay up to ExtraStayMax extra; the rest (or
    -- unreserved time) banks for a later stay, which takes reserved banked time up to the cap.
    local max = config.Shop.ExtraStayMax
    effects = Service.newEffects()
    assert(Service.extendStay(effects, nil, 60, "s1", max, 0) == 0 and effects.stayBank == 60 and Service.owed(effects, "s1") == 60)
    assert(Service.stayReady(effects, max) == 0)
    local stay = Service.beginStay(effects, 120, Service.stayReady(effects, max))
    assert(stay.total == 120 and stay.extra == 0 and effects.stayBank == 60, "unreserved banked time joined a stay")
    Service.reserve(effects, "s1", 60)
    stay = Service.beginStay(effects, 120, Service.stayReady(effects, max))
    assert(stay.total == 180 and stay.extra == 60 and effects.stayBank == 0 and Service.owed(effects, "s1") == 0, "a used stay bank still owed")
    assert(Service.extendStay(effects, stay, 60, "s2", max, 60) == 60 and stay.total == 240 and stay.extra == 120)
    -- At the cap: a receipt (bought without the prompt) adds only up to it; the rest banks.
    stay.extra = max - 30
    local before = stay.total
    assert(Service.extendStay(effects, stay, 60, "s3", max, 60) == 30 and stay.extra == max and stay.total == before + 30)
    left, reserved = Service.owed(effects, "s3")
    assert(left == 30 and reserved == 30, "time past the cap not banked")
    assert(Service.extendStay(effects, stay, 60, "s4", max, 60) == 0 and stay.extra == max, "stay grew past ExtraStayMax")
    -- A stay starts with at most ExtraStayMax of banked time.
    for index = 1, 8 do Service.extendStay(effects, nil, 60, "b" .. index, max, 60) end
    assert(Service.stayReady(effects, max) == max)
    stay = Service.beginStay(effects, 120, Service.stayReady(effects, max))
    assert(stay.extra == max and effects.stayBank > 0, "banked time past the cap used at once")
    -- Guarantees: one a spin, reserved ones only, first bought first used.
    Service.guarantee(effects, 3, "g1", false)
    Service.guarantee(effects, 5, "g2", true)
    assert(Service.owed(effects, "g2") == 1)
    assert(Service.takeGuarantee(effects) == 5 and Service.takeGuarantee(effects) == nil, "unreserved guarantee used")
    Service.reserve(effects, "g1", 1)
    assert(Service.takeGuarantee(effects) == 3 and Service.takeGuarantee(effects) == nil)

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
    -- Robux UFOs past the player's limit (receipts for UFOs bought without the prompt) wait
    -- their turn: only the first `flying` count down, and the landing times line up behind.
    local queued = Profiles.validate(nil, config)
    for _ = 1, 3 do assert(PetService.add(queued, 1, random)) end
    assert(PetService.advance(queued, 100, 3, 1) == nil and queued.ufos[1].remaining == 200 and queued.ufos[2].remaining == 300, "a waiting UFO counted down")
    local times = PetService.landings(queued, 1)
    assert(times[1] == 200 and times[2] == 500 and times[3] == 800, "waiting UFOs' landing times")
    assert(PetService.landings(queued, 3)[3] == 300)
    -- Fast Hatch is just a faster countdown: twice the seconds per tick.
    profile.coins = 500
    PetService.buy(profile, 1, "t5", random)
    assert(PetService.advance(profile, 150 * 2) and #profile.ufos == 0)

    -- 2x Coins: the multiplier only scales coins, not deliveries.
    profile = Profiles.validate(nil, config)
    assert(Profiles.credit(profile, 10, config, 2) == 20 * config.CoinsPerUnit and profile.lifetimeDeliveries == 10)
    assert(Profiles.credit(profile, 10, config) == 10 * config.CoinsPerUnit)
end
