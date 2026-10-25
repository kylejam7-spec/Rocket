-- Profile saving against an in-memory DataStore: loads take the session, saves write the
-- profile tagged with the user ID, a leaving player's session is released so another
-- server loads them at once, a kept lease (locked passenger) holds them off, a lock is
-- waited on rather than failed, and Studio without API access falls back to unsaved.
-- Also: nothing is ready or saved while a load still waits (placeholder defaults), the
-- committed snapshot only follows successful saves, a locked passenger's trip is on the
-- profile from the lock and recovered once after a lost server, and departed records
-- are pruned once settled.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Profiles = require(script.Parent.ProfileService)

    local function deep(value)
        if type(value) ~= "table" then return value end
        local out = {}
        for k, v in value do out[k] = deep(v) end
        return out
    end
    local function fakeStore()
        local store = { data = {}, userIds = {}, writes = 0 }
        function store:UpdateAsync(key, transform)
            local value, userIds = transform(deep(self.data[key]))
            if value == nil then return nil end
            self.data[key], self.userIds[key] = deep(value), userIds
            self.writes += 1
            return deep(value)
        end
        return store
    end
    local function server(store)
        local profiles = Profiles.new(config, function() end)
        profiles.store, profiles.retrySeconds, profiles.waitSeconds = store, 0.05, 0.3
        -- Save-soon spacing shortened; a full write budget unless a test says otherwise.
        profiles.rewardSaveSeconds, profiles.budget = 0.3, function() return 1000 end
        return profiles
    end
    local function waitFor(condition)
        local deadline = os.clock() + 5
        while not condition() and os.clock() < deadline do task.wait(0.02) end
        return condition()
    end

    local store = fakeStore()
    local a, b = server(store), server(store)
    -- Load and save: the session is A's, the key carries the user ID.
    assert(a:load(1) and a:ready(1) and a:persistent())
    assert(store.data.Player_1.session.owner == a.owner and store.userIds.Player_1[1] == 1)
    a.records[1].profile.coins = 1234
    a:dirty(1)
    assert(a:save(1) and store.data.Player_1.coins == 1234 and store.userIds.Player_1[1] == 1)
    -- B can't take a held session: it waits, then fails without overwriting.
    assert(not b:load(1) and store.data.Player_1.session.owner == a.owner)
    -- A's player leaves: the last save releases the session and B loads them at once.
    a:remove(1)
    assert(waitFor(function() return a.records[1].released end), "leaving save didn't release")
    assert(store.data.Player_1.session == nil and store.data.Player_1.coins == 1234)
    local c = server(store)
    assert(c:load(1) and c.records[1].profile.coins == 1234 and store.data.Player_1.session.owner == c.owner)
    -- A released record never writes again (it would undo C's session).
    local writes = store.writes
    assert(not a:save(1) or store.writes == writes)
    assert(store.data.Player_1.session.owner == c.owner)
    -- A locked passenger (a launch still open) keeps the lease after leaving.
    assert(c:lockLaunch(1, "Lk", { ticks = 4, launches = 1 }))
    c:remove(1, true)
    assert(waitFor(function() return not c.records[1].busy end))
    assert(store.data.Player_1.session and store.data.Player_1.session.owner == c.owner and not c.records[1].released)
    -- A lock that frees while the load waits: loaded on a retry.
    local d = server(store)
    d.waitSeconds = 2
    task.delay(0.2, function()
        local raw = store.data.Player_1
        raw.session = nil
    end)
    assert(d:load(1) and store.data.Player_1.session.owner == d.owner, "waiting load didn't retry")
    -- Rejoining the same server after release loads afresh.
    d:remove(1)
    assert(waitFor(function() return d.records[1].released end))
    assert(d:load(1) and not d.records[1].released and store.data.Player_1.session.owner == d.owner)

    -- Stay rewards: each tick shows at once, saves come at most one per
    -- RewardSaveSeconds, and a save never counts the previewed ticks twice.
    local rewards = fakeStore()
    local e = server(rewards)
    assert(e:load(2))
    local unit, record = config.Planet.StrengthBonus, e.records[2]
    e:queueReward(2, "L1", 1)
    assert(record.profile.planetBonuses.strength == unit and record.profile.planetBonuses.speed == config.Planet.SpeedBonus, "tick not previewed")
    e:queueReward(2, "L1", 2)
    e:queueReward(2, "L1", 3)
    assert(record.profile.planetBonuses.strength == 3 * unit)
    assert(waitFor(function() return not next(record.pending) and not record.saveQueued and not record.busy end), "reward save didn't run")
    assert(rewards.data.Player_2.planetBonuses.strength == 3 * unit and rewards.data.Player_2.completedLaunches == 1)
    assert(record.profile.planetBonuses.strength == 3 * unit and record.profile.completedLaunches == 1)
    local before = rewards.writes
    e:queueReward(2, "L1", 4)
    e:queueReward(2, "L1", 5)
    task.wait(0.1)
    assert(rewards.writes == before and record.profile.planetBonuses.strength == 5 * unit, "reward save not throttled")
    assert(waitFor(function() return not next(record.pending) and not record.busy end))
    assert(rewards.writes == before + 1 and rewards.data.Player_2.planetBonuses.strength == 5 * unit)
    assert(record.profile.planetBonuses.strength == 5 * unit and record.profile.completedLaunches == 1)

    -- Black Hole visits: a launch's first reward counts one, other destinations none;
    -- profiles saved before the counter load with 0.
    local visits = fakeStore()
    local f = server(visits)
    assert(f:load(3))
    f:queueReward(3, "B1", 1, true)
    f:queueReward(3, "B1", 2, true)
    f:queueReward(3, "M1", 1, false)
    assert(waitFor(function() return not next(f.records[3].pending) and not f.records[3].busy end), "visit rewards didn't save")
    assert(visits.data.Player_3.blackHolesVisited == 1 and visits.data.Player_3.completedLaunches == 2, "one visit for the Black Hole launch")
    assert(f.records[3].profile.blackHolesVisited == 1)
    local legacy = deep(visits.data.Player_3)
    legacy.blackHolesVisited = nil
    assert(Profiles.validate(legacy, config).blackHolesVisited == 0, "older profiles start at 0 visits")

    -- SHOP passes bought in game: saved, kept when a save from a stale copy lacks them,
    -- and older profiles load with none.
    assert(Profiles.validate(legacy, config).passes and #Profiles.validate(legacy, config).passes == 0, "older profiles start with no passes")
    table.insert(f.records[3].profile.passes, "FastHatch")
    f:dirty(3)
    assert(f:saveNow(3) and table.find(visits.data.Player_3.passes, "FastHatch"), "a bought pass saves")
    f.records[3].profile.passes = { "PetSlot1" }
    assert(f:saveNow(3), "pass save failed")
    local stored = visits.data.Player_3.passes
    assert(#stored == 2 and table.find(stored, "FastHatch") and table.find(stored, "PetSlot1"), "saved passes are never dropped")

    -- Finding 1: while a load waits out another server's lease the record holds placeholder
    -- defaults: not ready, nothing saves, so a grant can't land on them and be "saved".
    local leased = fakeStore()
    leased.data.Player_8 = deep(Profiles.validate(nil, config))
    leased.data.Player_8.coins = 77
    leased.data.Player_8.session = { owner = "elsewhere", expires = os.time() + 3600 }
    local g = server(leased)
    g.waitSeconds = 3
    local loaded
    task.spawn(function() loaded = g:load(8) end)
    assert(waitFor(function() return g.records[8] and g.records[8].status:find("finishing", 1, true) end), "load didn't wait")
    assert(not g:ready(8) and not g:save(8), "placeholder profile counted as ready")
    g:queueReward(8, "Lw", 1)
    assert(next(g.records[8].pending) == nil, "reward queued onto a placeholder")
    task.delay(0.2, function() leased.data.Player_8.session = nil end)
    assert(waitFor(function() return loaded ~= nil end) and loaded and g:ready(8) and g.records[8].profile.coins == 77)

    -- Finding 7: `committed` is the last profile known stored; a failed save leaves it.
    local flaky = fakeStore()
    local k = server(flaky)
    assert(k:load(9) and k.records[9].committed.coins == 0)
    k.records[9].profile.coins = 50
    assert(k:save(9) and k.records[9].committed.coins == 50)
    k.records[9].profile.coins = 999
    local realUpdate = flaky.UpdateAsync
    flaky.UpdateAsync = function() error("DataStore down") end
    assert(not k:save(9) and k.records[9].committed.coins == 50, "committed follows unsaved changes")
    flaky.UpdateAsync = realUpdate

    -- Findings 6 and 10: the trip is on the profile from the lock. A passenger whose
    -- server dies mid-flight (nothing queued yet) is paid the whole stay on their next
    -- load, once, with their suit's launch count; a stay that finished closes it.
    local trips = fakeStore()
    local m = server(trips)
    assert(m:load(10))
    local writesBefore = trips.writes
    assert(m:lockLaunch(10, "T1", { ticks = 8, launches = 4, blackHole = true }))
    -- The lock alone writes nothing; commitLaunch returns only once the trip is stored
    -- (Launch waits on it before liftoff).
    assert(trips.writes == writesBefore)
    local committed = m:commitLaunch({ [10] = true }, 5)
    assert(committed[10] and trips.data.Player_10.openLaunches.T1 and trips.data.Player_10.openLaunches.T1.ticks == 8, "commitLaunch returned before the trip was stored")
    -- A save that can't finish in time: commitLaunch gives up at its timeout, unconfirmed.
    local stuck = fakeStore()
    local stuckServer = server(stuck)
    assert(stuckServer:load(13) and stuckServer:lockLaunch(13, "Ts", { ticks = 1, launches = 1 }))
    local realStuck = stuck.UpdateAsync
    stuck.UpdateAsync = function(...) task.wait(3); return realStuck(...) end
    local started = os.clock()
    assert(not stuckServer:commitLaunch({ [13] = true }, 0.3)[13] and os.clock() - started < 1, "commitLaunch ignored its timeout")
    stuck.UpdateAsync = realStuck
    -- The server dies: its lease runs out, another server loads them.
    trips.data.Player_10.session.expires = 0
    local n = server(trips)
    assert(n:load(10))
    local stored = trips.data.Player_10
    assert(next(stored.openLaunches) == nil and stored.completedLaunches == 4 and stored.blackHolesVisited == 1
        and stored.planetBonuses.strength == 8 * unit and stored.rewardedLaunchTicks.T1 == 8, "lost trip not recovered")
    assert(n.records[10].profile.completedLaunches == 4)
    -- Loading again never pays it twice.
    n:remove(10)
    assert(waitFor(function() return n.records[10].released end))
    assert(server(trips):load(10) and trips.data.Player_10.completedLaunches == 4 and trips.data.Player_10.planetBonuses.strength == 8 * unit)
    -- A stay that grew (ExtraStay: 8 ticks -> 12) and was then lost: the whole longer stay
    -- is paid, not just the base one.
    local longer = fakeStore()
    local lg = server(longer)
    assert(lg:load(14) and lg:lockLaunch(14, "Tx", { ticks = 8, launches = 1 }) and lg:commitLaunch({ [14] = true }, 5)[14])
    lg:extendLaunch(14, "Tx", 12)
    lg:extendLaunch(14, "Tx", 10) -- never shrinks
    lg:queueReward(14, "Tx", 2)
    assert(waitFor(function() return longer.data.Player_14.openLaunches.Tx.ticks == 12 and not lg.records[14].busy and not lg.records[14].saveQueued end), "extension not saved")
    longer.data.Player_14.session.expires = 0
    assert(server(longer):load(14))
    assert(longer.data.Player_14.planetBonuses.strength == 12 * unit and longer.data.Player_14.completedLaunches == 1, "extended stay not recovered in full")
    -- A stay paid part-way (3 ticks saved) and then lost: only the rest is paid.
    local part = fakeStore()
    local q = server(part)
    assert(q:load(11) and q:lockLaunch(11, "T2", { ticks = 10, launches = 2 }))
    q:queueReward(11, "T2", 3)
    -- The passenger leaves mid-stay: their suit boost was taken at the lock (Launch passes
    -- it on every tick; a departed player no longer has one to read).
    q:remove(11, true)
    q:queueReward(11, "T2", 4, false, 2)
    assert(waitFor(function() return not next(q.records[11].pending) and not q.records[11].busy and not q.records[11].saveQueued end))
    assert(part.data.Player_11.completedLaunches == 2 and part.data.Player_11.rewardedLaunchTicks.T2 == 4 and part.data.Player_11.session, "left passenger's lease or launch count lost")
    part.data.Player_11.session.expires = 0
    assert(server(part):load(11))
    assert(part.data.Player_11.completedLaunches == 2 and part.data.Player_11.planetBonuses.strength == 10 * unit, "recovery paid more or less than the rest")
    -- A stay that ends normally closes the launch in the save that commits it, and a
    -- passenger who left lets go of the session then.
    local done = fakeStore()
    local r = server(done)
    assert(r:load(12) and r:lockLaunch(12, "T3", { ticks = 2, launches = 1 }))
    r:remove(12, true)
    r:queueReward(12, "T3", 2)
    r:finishLaunch(12, "T3")
    assert(waitFor(function() return r.records[12].released end), "finished passenger's session not released")
    assert(next(done.data.Player_12.openLaunches) == nil and done.data.Player_12.completedLaunches == 1 and done.data.Player_12.session == nil)

    -- Finding 11: departed, settled records are let go; a locked passenger's stays until
    -- the launch closes, and so does anyone still here.
    local pool = fakeStore()
    local s = server(pool)
    assert(s:load(20) and s:load(21) and s:load(22))
    assert(s:lockLaunch(21, "P1", { ticks = 1, launches = 1 }))
    s:remove(20)
    s:remove(21, true)
    assert(waitFor(function() return s.records[20].released and not s.records[21].busy and not s.records[21].saveQueued end))
    assert(s:prune() == 1 and s.records[20] == nil and s.records[21] and s.records[22], "wrong records pruned")
    s:queueReward(21, "P1", 1)
    s:finishLaunch(21, "P1")
    assert(waitFor(function() return s.records[21].released end))
    assert(s:prune() == 1 and s.records[21] == nil and s.records[22])
    -- A rejoin after pruning loads afresh.
    assert(s:load(20) and s:ready(20) and pool.data.Player_20.session.owner == s.owner)

    -- A passenger whose trip couldn't be saved in time stays behind: the trip comes off
    -- the profile again, so even the late save that finally lands owes nothing.
    local late = fakeStore()
    local lt = server(late)
    assert(lt:load(30) and lt:lockLaunch(30, "Tc", { ticks = 9, launches = 1 }))
    local realLate = late.UpdateAsync
    late.UpdateAsync = function(...) task.wait(0.6); return realLate(...) end
    assert(not lt:commitLaunch({ [30] = true }, 0.2)[30])
    lt:cancelLaunch(30, "Tc")
    late.UpdateAsync = realLate
    assert(waitFor(function() return not lt.records[30].busy and not lt.records[30].saveQueued and not lt.records[30].dirty end), "cancel not saved")
    assert(late.data.Player_30.openLaunches.Tc == nil and next(lt.records[30].profile.openLaunches) == nil, "a cancelled trip is still owed")
    late.data.Player_30.session.expires = 0
    assert(server(late):load(30) and late.data.Player_30.completedLaunches == 0, "a trip not taken was paid")

    -- A suit chosen while a save is running, then leaving: the leaving save waits for the
    -- running one and then stores the suit (it used to be lost, the record marked clean).
    local suits = fakeStore()
    local su = server(suits)
    assert(su:load(31))
    local realSuits = suits.UpdateAsync
    suits.UpdateAsync = function(...) task.wait(0.4); return realSuits(...) end
    su:dirty(31)
    task.spawn(function() su:save(31) end)
    task.wait(0.1)
    su.records[31].profile.suit = "SuitGold"
    su:dirty(31)
    su:remove(31)
    suits.UpdateAsync = realSuits
    assert(waitFor(function() return su.records[31].released end), "leaving save didn't run after the busy one")
    assert(suits.data.Player_31.suit == "SuitGold", "suit lost on departure")
    -- A change made during a save keeps the record dirty even if no compared field moved.
    local rev = fakeStore()
    local rv = server(rev)
    assert(rv:load(32))
    local realRev = rev.UpdateAsync
    rev.UpdateAsync = function(...) task.wait(0.3); return realRev(...) end
    rv:dirty(32)
    task.spawn(function() rv:save(32) end)
    task.wait(0.1)
    rv.records[32].profile.suit = "SuitGalaxy"
    rv:dirty(32)
    assert(waitFor(function() return not rv.records[32].busy end))
    rev.UpdateAsync = realRev
    assert(rv.records[32].dirty, "a change during a save was marked saved")

    -- Saves that can wait: many changes make one save per spacing, and none goes while the
    -- DataStore write budget is at the reserve (saveNow, for receipts and commits, does).
    local budgeted = fakeStore()
    local bu = server(budgeted)
    assert(bu:load(33))
    local writes0 = budgeted.writes
    for _ = 1, 20 do bu:dirty(33); bu:saveSoon(33) end
    assert(waitFor(function() return budgeted.writes > writes0 and not bu.records[33].busy end))
    task.wait(0.4)
    assert(budgeted.writes == writes0 + 1, "save-soon calls weren't coalesced")
    local left = 5
    bu.budget = function() return left end
    bu.records[33].profile.coins = 7
    bu:dirty(33)
    bu:saveSoon(33)
    task.wait(0.8)
    assert(budgeted.writes == writes0 + 1, "a save that could wait went out with no budget left")
    assert(bu:saveNow(33) and budgeted.writes == writes0 + 2, "saveNow waited for budget")
    left = 1000
    assert(waitFor(function() return not bu.records[33].saveQueued end), "deferred save never went")

    -- Studio without API access: unsaved progress instead of a failed load.
    local denied = Profiles.new(config, function() end)
    denied.store = { UpdateAsync = function() error("StudioAccessToApisNotAllowed: Studio access to APIs is not allowed.") end }
    if game:GetService("RunService"):IsStudio() then
        assert(denied:load(7) and not denied:persistent() and denied:ready(7))
    end
end
