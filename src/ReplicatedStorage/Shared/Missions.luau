--[[
    Missions — what a server builds and where it flies. Each mission is one rocket
    design flying to its own destination (Config.Destinations, same index). A new
    server always starts on the Moon; after that, 10 s before each reward stay ends,
    the server spins the wheel for the next mission.

    Wheel: weights 40 / 28 / 19 / 10 / 3 (Common → Legendary). Pity: after PityAfter
    spins in a row below Rare, the next spin draws only from the PityWeight entries
    (Europa 34 / Saturn 33 / Black Hole 33); any Rare-or-better result resets it.

    Missions[n]
        Id, Rarity           destination id (Config.Destinations[n].id) and rarity label
        Weight, PityWeight   wheel odds (percent) and pity-spin odds (0 = not in pity)
        ConstructionRequired Metal units to build the rocket (phase 1)
        FuelRequired         Fuel units to fuel it (phase 2)
        RewardMultiplier     extra multiplier on the destination's per-second reward
        RewardSeconds        optional override of Config.RewardSeconds
    Tiers[n]  rocket presentation (geometry lives in ServerScriptService RocketModels):
        Name, BoardingSeconds (countdown), LaunchSeconds (ignition and ascent),
        LandingSeconds (the descent onto the destination, after the ascent),
        IgnitionSeconds, ExhaustScale, SmokeScale, Shake (camera shake amplitude, studs)
]]

local Tiers = {
    { Name = "Lunar Rocket", BoardingSeconds = 20, LaunchSeconds = 11, LandingSeconds = 8, IgnitionSeconds = 1.5, ExhaustScale = 1, SmokeScale = 1, Shake = 0 },
    { Name = "Mars Rocket", BoardingSeconds = 20, LaunchSeconds = 12, LandingSeconds = 8, IgnitionSeconds = 2, ExhaustScale = 1.3, SmokeScale = 1.5, Shake = 0.05 },
    { Name = "Europa Heavy-Lift", BoardingSeconds = 22, LaunchSeconds = 13, LandingSeconds = 9, IgnitionSeconds = 2.5, ExhaustScale = 1.7, SmokeScale = 2.2, Shake = 0.15 },
    { Name = "Saturn Super Heavy", BoardingSeconds = 25, LaunchSeconds = 14, LandingSeconds = 9, IgnitionSeconds = 3, ExhaustScale = 2.2, SmokeScale = 3, Shake = 0.3 },
    { Name = "Event Horizon Explorer", BoardingSeconds = 30, LaunchSeconds = 16, LandingSeconds = 10, IgnitionSeconds = 4, ExhaustScale = 3.6, SmokeScale = 6, Shake = 0.7 },
}

-- Build sizes (2026-10-16 balance pass): 73k / 98k / 137k / 182k / 215k units in all,
-- the same for every lobby size so the whole server has to work together; the fuel
-- share rises with rarity. Rarer missions are bigger builds that pay more at the destination.
local List = {
    { Id = "Moon", Rarity = "Common", Weight = 40, PityWeight = 0, ConstructionRequired = 48500, FuelRequired = 24500, RewardMultiplier = 1 },
    { Id = "Mars", Rarity = "Uncommon", Weight = 28, PityWeight = 0, ConstructionRequired = 64000, FuelRequired = 34000, RewardMultiplier = 1 },
    { Id = "Europa", Rarity = "Rare", Weight = 19, PityWeight = 34, ConstructionRequired = 85000, FuelRequired = 52000, RewardMultiplier = 1 },
    { Id = "Saturn", Rarity = "Epic", Weight = 10, PityWeight = 33, ConstructionRequired = 108000, FuelRequired = 74000, RewardMultiplier = 1 },
    { Id = "BlackHole", Rarity = "Legendary", Weight = 3, PityWeight = 33, ConstructionRequired = 122500, FuelRequired = 92500, RewardMultiplier = 1 },
}

local Missions = { Count = #List, First = 1, PityAfter = 4, Tiers = table.freeze(Tiers) }
-- Rarity rank (1 Common .. 5 Legendary) and the rank pity guarantees.
Missions.RarityRank = table.freeze({ Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 })
Missions.PityRank = 3

local resolved, byId = {}, {}
for index, mission in List do
    local tier = Tiers[index]
    assert(tier, "Missions: mission " .. index .. " has no rocket tier")
    for _, key in { "ConstructionRequired", "FuelRequired", "RewardMultiplier", "Weight", "PityWeight" } do
        local value = mission[key]
        assert(type(value) == "number" and value >= 0 and value % 1 == 0, "Missions: " .. mission.Id .. " " .. key .. " must be a whole number")
    end
    local entry = table.clone(mission)
    -- ModelTier = rocket design and destination index; Variant 3 = the full design.
    entry.Number, entry.ModelTier, entry.Variant, entry.Tier = index, index, 3, tier
    entry.Rank = Missions.RarityRank[mission.Rarity]
    entry.IsLegendary = entry.Rank == 5
    resolved[index] = table.freeze(entry)
    byId[mission.Id] = index
end
for _, tier in Tiers do table.freeze(tier) end

function Missions.get(index)
    return assert(resolved[index], "Missions: no mission " .. tostring(index))
end
function Missions.index(id)
    return byId[id]
end

-- The weights a spin uses: the pity pool once `misses` spins in a row were below Rare.
function Missions.weights(misses)
    local pity = misses >= Missions.PityAfter
    local weights = {}
    for index, mission in resolved do weights[index] = pity and mission.PityWeight or mission.Weight end
    return weights, pity
end

-- Spins the wheel: returns the mission index and whether it was a pity spin.
-- `random` is a Random (seeded in checks).
function Missions.spin(random, misses)
    local weights, pity = Missions.weights(misses)
    local total = 0
    for _, weight in weights do total += weight end
    local roll = random:NextNumber(0, total)
    for index, weight in weights do
        if roll < weight then return index, pity end
        roll -= weight
    end
    return #weights, pity
end

-- The pity counter after a spin landed on `index`.
function Missions.afterSpin(misses, index)
    return resolved[index].Rank >= Missions.PityRank and 0 or misses + 1
end

-- Long-run share of launches per mission (exact, from the pity Markov chain).
function Missions.longRun()
    local state = { [0] = 1 }
    for _ = 0, Missions.PityAfter do state[_] = state[_] or 0 end
    local share = {}
    for _ = 1, 400 do
        local nextState, step = {}, {}
        for misses = 0, Missions.PityAfter do nextState[misses] = 0 end
        for misses, chance in state do
            local weights = Missions.weights(misses)
            local total = 0
            for _, weight in weights do total += weight end
            for index, weight in weights do
                local p = chance * weight / total
                step[index] = (step[index] or 0) + p
                local after = math.min(Missions.afterSpin(misses, index), Missions.PityAfter)
                nextState[after] += p
            end
        end
        state, share = nextState, step
    end
    return share
end

return table.freeze(Missions)
