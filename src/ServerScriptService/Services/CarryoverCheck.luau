-- Rocket carryover pool (CarryoverService): what a closing server keeps, which rocket
-- the next server takes, and how a saved rocket comes back.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Rocket = require(script.Parent.RocketService)
local Carry = require(script.Parent.CarryoverService)

return function()
    local now = 1000000
    local fresh = Rocket.new(Config, "a", 1, 0)
    assert(Carry.snapshot(fresh, 0, now) == nil, "an untouched first rocket isn't kept")

    local half = Rocket.new(Config, "b", 1, 2)
    half.totals.Metal = math.floor(half.required.Metal / 2)
    local entry = Carry.snapshot(half, 3, now)
    assert(entry and entry.mission == 1 and entry.launches == 2 and entry.misses == 3 and entry.metal == half.totals.Metal and entry.fuel == 0)
    assert(entry.progress > 0 and entry.progress < 1)

    -- Launched: kept as the next mission, empty, its launch counted.
    local flown = Rocket.new(Config, "c", 1, 4)
    flown.phase, flown.nextMission, flown.totals.Metal, flown.totals.Fuel = "Rewarding", 3, flown.required.Metal, flown.required.Fuel
    local after = Carry.snapshot(flown, 0, now)
    assert(after.mission == 3 and after.launches == 5 and after.metal == 0 and after.fuel == 0 and after.progress == 0)

    -- The pool keeps the best, the furthest along first.
    local pool = Carry.push(nil, after, 2)
    pool = Carry.push(pool, entry, 2)
    local fueled = table.clone(entry)
    fueled.progress = 0.9
    pool = Carry.push(pool, fueled, 2)
    assert(#pool == 2 and pool[1] == fueled and pool[2] == entry, "least built drops off")
    local best, rest = Carry.take(pool, now, 60)
    assert(best == fueled and #rest == 1 and rest[1] == entry)
    -- Stale and garbage entries are dropped.
    local old = table.clone(entry)
    old.savedAt = now - 61
    best, rest = Carry.take({ old, "junk", { progress = 1 } }, now, 60)
    assert(best == nil and #rest == 0)
    assert(Carry.take(nil, now, 60) == nil)

    -- Restoring: totals clamp to the mission, phases follow them.
    local building = Carry.rocket(Config, "d", entry)
    assert(building.phase == "Building" and building.totals.Metal == entry.metal and building.totals.Fuel == 0 and building.launches == 2 and building.cycle == "d")
    local full = Rocket.new(Config, "e", 2, 1)
    local metalOnly = { mission = 2, launches = 1, metal = full.required.Metal * 5, fuel = 3, progress = 0.6, savedAt = now }
    local fueling = Carry.rocket(Config, "f", metalOnly)
    assert(fueling.phase == "Fueling" and fueling.totals.Metal == full.required.Metal and fueling.totals.Fuel == 3)
    metalOnly.fuel = full.required.Fuel
    assert(Carry.rocket(Config, "g", metalOnly).phase == "Boarding")
    local stray = { mission = 1, launches = 0, metal = 0, fuel = 50, progress = 0.1, savedAt = now }
    assert(Carry.rocket(Config, "h", stray).totals.Fuel == 0, "no fuel before the metal is in")
    assert(Carry.rocket(Config, "i", { mission = 99, launches = 0, metal = 0, fuel = 0 }) == nil, "unknown mission")
    assert(Carry.rocket(Config, "j", { mission = 1, launches = -1, metal = 0, fuel = 0 }) == nil)
    assert(Carry.rocket(Config, "k", { mission = 1, launches = 0, metal = 0 / 0, fuel = 0 }) == nil)
    return "Rocket carryover passed"
end
