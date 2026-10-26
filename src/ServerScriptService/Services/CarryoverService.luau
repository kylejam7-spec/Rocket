-- The rocket outlives its server. When a server closes (the last player left, or an
-- update restarts it) BindToClose puts its rocket in a shared pool: the mission, launch
-- count, wheel pity counter and the Metal/Fuel placed so far. The next server to start
-- takes the furthest-along rocket from the pool and the build carries on from there.
-- UpdateAsync hands each rocket to one server only, so it never runs in two places.
-- Private servers keep their own pool; Studio writes its own store. A server that
-- crashes (no BindToClose) keeps nothing.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Rocket = require(script.Parent.RocketService)
local Missions = require(game:GetService("ReplicatedStorage").Shared.Missions)
local Carry = {}

local function count(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- The furthest-along rocket first; then the one with more launches (bigger map).
local function better(a, b)
    if a.progress ~= b.progress then return a.progress > b.progress end
    return a.launches > b.launches
end

-- What's worth keeping of `rocket` at `now` (os.time), or nil. One already launched
-- (Launching on: its passengers are paid through their profiles) is kept as the next
-- rocket, empty, with its launch counted.
function Carry.snapshot(rocket, misses, now)
    local entry = { mission = rocket.mission, launches = rocket.launches, misses = misses or 0,
        metal = rocket.totals.Metal, fuel = rocket.totals.Fuel, savedAt = now }
    if not Rocket.PhaseMaterial[rocket.phase] and rocket.phase ~= "Boarding" then
        entry.mission, entry.launches, entry.metal, entry.fuel = rocket.nextMission or rocket.mission, rocket.launches + 1, 0, 0
    end
    entry.progress = (entry.metal + entry.fuel) / (rocket.required.Metal + rocket.required.Fuel)
    if entry.progress <= 0 and entry.launches == 0 and entry.misses == 0 then return nil end
    return entry
end

-- Adds `entry` to `pool`, keeping the best `size`.
function Carry.push(pool, entry, size)
    pool = type(pool) == "table" and pool or {}
    table.insert(pool, entry)
    table.sort(pool, better)
    while #pool > size do table.remove(pool) end
    return pool
end

-- The best entry no older than `maxAge` seconds, and the pool left without it (stale
-- and unreadable entries dropped).
function Carry.take(pool, now, maxAge)
    local kept = {}
    for _, entry in type(pool) == "table" and pool or {} do
        if type(entry) == "table" and count(entry.savedAt) and now - entry.savedAt <= maxAge
            and count(entry.progress) and count(entry.launches) then
            table.insert(kept, entry)
        end
    end
    table.sort(kept, better)
    return table.remove(kept, 1), kept
end

-- A fresh rocket (new reward ledger id) rebuilt from `entry`, or nil if it doesn't read.
-- Totals are clamped to the mission's current requirements; Fuel only counts once the
-- Metal is all in, and a full rocket comes back ready to board.
function Carry.rocket(config, id, entry)
    if type(entry) ~= "table" or not count(entry.launches) or not count(entry.metal) or not count(entry.fuel) then return nil end
    if type(entry.mission) ~= "number" or not pcall(Missions.get, entry.mission) then return nil end
    local rocket = Rocket.new(config, id, entry.mission, math.floor(entry.launches))
    rocket.totals.Metal = math.min(math.floor(entry.metal), rocket.required.Metal)
    if rocket.totals.Metal >= rocket.required.Metal then
        rocket.phase = "Fueling"
        rocket.totals.Fuel = math.min(math.floor(entry.fuel), rocket.required.Fuel)
        if rocket.totals.Fuel >= rocket.required.Fuel then rocket.phase = "Boarding" end
    end
    return rocket
end

function Carry.new(ctx)
    local config, settings = ctx.config, ctx.config.Carryover
    local service = {}
    local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, settings.Store)
    if not ok then store = nil end
    local key = game.PrivateServerId ~= "" and "private_" .. game.PrivateServerId or "public"

    local function update(transform)
        if not store then return false end
        for attempt = 1, 3 do
            local done, err = pcall(store.UpdateAsync, store, key, transform)
            if done then return true end
            -- Studio without API access fails every time: once is enough.
            if attempt == 3 or RunService:IsStudio() then
                warn("Rocket carryover: couldn't reach the pool:", err)
                return false
            end
            task.wait(attempt)
        end
        return false
    end

    -- Puts `entry` on the pad if this server's own rocket is still untouched. True when
    -- the entry was used up (restored, or unreadable and dropped).
    local function restore(entry)
        local Cycle = ctx.Cycle
        local current = Cycle.rocket
        if current.phase ~= "Building" or current.launches > 0 or current.totals.Metal > 0 then return false end
        local rocket = Carry.rocket(config, Cycle.newId(), entry)
        if not rocket then return true end
        Cycle.misses = count(entry.misses) and math.floor(entry.misses) or 0
        Cycle.replace(rocket)
        ctx.Cargo.delivered(false)
        if rocket.phase == "Boarding" then
            ctx.Launch.beginBoarding()
        elseif entry.progress > 0 then
            ctx.Remote.announce("The last crew's rocket is back on the pad, " .. math.floor(entry.progress * 100) .. "% done. Finish it!")
        end
        Cycle.broadcast()
        return true
    end

    function service.start()
        task.spawn(function()
            local taken
            local claimed = update(function(pool)
                local best, rest = Carry.take(pool, os.time(), settings.MaxAgeSeconds)
                taken = best
                if not best then return nil end
                return rest
            end)
            if not claimed or not taken then return end
            -- Someone already started on this server's rocket: the claimed one goes back.
            if not restore(taken) then
                update(function(pool) return Carry.push(pool, taken, settings.PoolSize) end)
            end
        end)
        game:BindToClose(function()
            local entry = Carry.snapshot(ctx.Cycle.rocket, ctx.Cycle.misses, os.time())
            if entry then update(function(pool) return Carry.push(pool, entry, settings.PoolSize) end) end
        end)
    end
    return service
end

return Carry
