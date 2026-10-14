--[[
    RocketCycles — the single source of truth for SHARED server progression.

    A server runs Cycles 1..#Cycles, then the final cycle's launch completes the
    space program and the server resets to Cycle 1. Player progression (stats,
    launches, unlocks) is stored in profiles and is never touched by this reset.

    Rebalancing: edit the numbers below. No game logic depends on specific values.

    Cycles[n]
        ModelTier            which entry of Tiers (visual rocket) this cycle uses
        ConstructionRequired Metal units to build the rocket (phase 1)
        FuelRequired         Fuel units to fuel the rocket (phase 2)
        RewardMultiplier     integer multiplier on the destination's per-second reward
        IsFinalCycle         true on the last cycle only: special launch + program reset
        RewardSeconds        optional override of Config.RewardSeconds

    Tiers[n]  (presentation only; geometry lives in ServerScriptService RocketModels)
        Name, BoardingSeconds (countdown), LaunchSeconds, IgnitionSeconds,
        ExhaustScale, SmokeScale, Shake (camera shake amplitude, studs)

    Units: one unit = one carried material. Cycle 1 (600 units) is tuned so a brand
    new solo player (Config.BaseCarryCapacity = 10 per ~10 s trip) needs ~10 minutes.
]]

local Tiers = {
    { Name = "Starter Rocket", BoardingSeconds = 20, LaunchSeconds = 7, IgnitionSeconds = 1.5, ExhaustScale = 1, SmokeScale = 1, Shake = 0 },
    { Name = "Orbital Rocket", BoardingSeconds = 20, LaunchSeconds = 8, IgnitionSeconds = 2, ExhaustScale = 1.3, SmokeScale = 1.5, Shake = 0.05 },
    { Name = "Heavy-Lift Rocket", BoardingSeconds = 22, LaunchSeconds = 9, IgnitionSeconds = 2.5, ExhaustScale = 1.7, SmokeScale = 2.2, Shake = 0.15 },
    { Name = "Super Heavy Rocket", BoardingSeconds = 25, LaunchSeconds = 10, IgnitionSeconds = 3, ExhaustScale = 2.2, SmokeScale = 3, Shake = 0.3 },
    { Name = "Interplanetary Rocket", BoardingSeconds = 30, LaunchSeconds = 12, IgnitionSeconds = 4, ExhaustScale = 2.8, SmokeScale = 4, Shake = 0.45 },
}

-- Total work follows the design curve (600 → 8,250); fuel share grows from 33% to ~44%.
local Cycles = {
    { ModelTier = 1, ConstructionRequired = 400, FuelRequired = 200, RewardMultiplier = 1 }, --   600
    { ModelTier = 1, ConstructionRequired = 500, FuelRequired = 250, RewardMultiplier = 1 }, --   750
    { ModelTier = 1, ConstructionRequired = 600, FuelRequired = 300, RewardMultiplier = 1 }, --   900
    { ModelTier = 2, ConstructionRequired = 750, FuelRequired = 400, RewardMultiplier = 1 }, -- 1,150
    { ModelTier = 2, ConstructionRequired = 900, FuelRequired = 500, RewardMultiplier = 1 }, -- 1,400
    { ModelTier = 2, ConstructionRequired = 1075, FuelRequired = 625, RewardMultiplier = 1 }, -- 1,700
    { ModelTier = 3, ConstructionRequired = 1300, FuelRequired = 800, RewardMultiplier = 2 }, -- 2,100
    { ModelTier = 3, ConstructionRequired = 1550, FuelRequired = 1000, RewardMultiplier = 2 }, -- 2,550
    { ModelTier = 3, ConstructionRequired = 1825, FuelRequired = 1225, RewardMultiplier = 2 }, -- 3,050
    { ModelTier = 4, ConstructionRequired = 2200, FuelRequired = 1500, RewardMultiplier = 2 }, -- 3,700
    { ModelTier = 4, ConstructionRequired = 2575, FuelRequired = 1825, RewardMultiplier = 2 }, -- 4,400
    { ModelTier = 4, ConstructionRequired = 3000, FuelRequired = 2200, RewardMultiplier = 2 }, -- 5,200
    { ModelTier = 5, ConstructionRequired = 3475, FuelRequired = 2625, RewardMultiplier = 3 }, -- 6,100
    { ModelTier = 5, ConstructionRequired = 4000, FuelRequired = 3100, RewardMultiplier = 3 }, -- 7,100
    { ModelTier = 5, ConstructionRequired = 4600, FuelRequired = 3650, RewardMultiplier = 5, IsFinalCycle = true, RewardSeconds = 45 }, -- 8,250
}

-- Resolve each cycle once: validated, with its tier and variant (1st/2nd/3rd use of a tier).
local resolved, seen = {}, {}
for number, cycle in Cycles do
    local tier = Tiers[cycle.ModelTier]
    assert(tier, "RocketCycles: cycle " .. number .. " has unknown ModelTier")
    for _, key in { "ConstructionRequired", "FuelRequired", "RewardMultiplier" } do
        local value = cycle[key]
        assert(type(value) == "number" and value >= 1 and value % 1 == 0, "RocketCycles: cycle " .. number .. " " .. key .. " must be a positive integer")
    end
    assert(not cycle.IsFinalCycle or number == #Cycles, "RocketCycles: only the last cycle may be final")
    seen[cycle.ModelTier] = (seen[cycle.ModelTier] or 0) + 1
    local entry = table.clone(cycle)
    entry.Number, entry.Variant, entry.Tier, entry.IsFinalCycle = number, seen[cycle.ModelTier], tier, cycle.IsFinalCycle == true
    resolved[number] = table.freeze(entry)
end
for _, tier in Tiers do table.freeze(tier) end

local RocketCycles = { Count = #Cycles, Tiers = table.freeze(Tiers) }

function RocketCycles.get(number)
    return assert(resolved[number], "RocketCycles: no cycle " .. tostring(number))
end

-- After the final cycle the shared program starts over at Cycle 1.
function RocketCycles.next(number)
    return number >= #Cycles and 1 or number + 1
end

-- Launches until the launchpad shows a different rocket design (nil on the last tier).
function RocketCycles.launchesUntilNextTier(number)
    local tier = resolved[number].ModelTier
    for later = number + 1, #Cycles do
        if resolved[later].ModelTier ~= tier then return later - number end
    end
    return nil
end

return table.freeze(RocketCycles)
