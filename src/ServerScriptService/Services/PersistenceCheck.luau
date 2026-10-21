-- Profile saving against an in-memory DataStore: loads take the session, saves write the
-- profile tagged with the user ID, a leaving player's session is released so another
-- server loads them at once, a kept lease (locked passenger) holds them off, a lock is
-- waited on rather than failed, and Studio without API access falls back to unsaved.
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
    -- A locked passenger keeps the lease after leaving.
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

    -- Studio without API access: unsaved progress instead of a failed load.
    local denied = Profiles.new(config, function() end)
    denied.store = { UpdateAsync = function() error("StudioAccessToApisNotAllowed: Studio access to APIs is not allowed.") end }
    if game:GetService("RunService"):IsStudio() then
        assert(denied:load(7) and not denied:persistent() and denied:ready(7))
    end
end
