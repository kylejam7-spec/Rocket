-- Full-program pacing report: simulates the 15 rockets with N identical players from
-- the live tunables (Config, RocketCycles, Shared.Upgrades), so balance changes show
-- up here before anyone plays them. Not a check: it reports, it doesn't assert.
-- From the Studio command bar or MCP (server):
--   print(require(game.ServerScriptService.ProgressionReport)())
--   print(require(game.ServerScriptService.ProgressionReport)({ players = { 1, 8 }, train = 0.3 }))
--
-- Model (timings measured in Studio, 2026-10-15): a trip is 230 studs from the pit or
-- refinery to the ramp foot and back, plus the climb along the tilted rocket to the
-- fill line (rocket length x fill), at walk speed; plus pickup, pour and 2 s handling.
-- Players spend `train` of their time on the best unlocked map gym (half bench, half
-- treadmill), buy the cheapest affordable upgrade, and at each destination stand for
-- the passive bonus and spend `gymShare` of the stay on its 2x gym.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Shared.Config)
local Cycles = require(ReplicatedStorage.Shared.RocketCycles)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

-- Rocket lengths per design (RocketModels header comments), for the ramp climb.
local HEIGHT = { 53, 78, 109, 143, 194 }
local TRIP_BASE, HANDLING, RESET_SECONDS = 230, 2, 6

local function simulate(players, train, gymShare)
    local profile = { strengthLevel = 0, speedLevel = 0, planetBonuses = { strength = 0, speed = 0 }, upgrades = {}, coins = 0 }
    local launches, buys, t, fromDestinations, fromGyms = 0, 0, 0, 0, 0
    local rows = {}
    local function capacity()
        local points = profile.strengthLevel
        return math.min(config.MaxCapacity, config.BaseCarryCapacity + math.floor(config.StrengthCarryScale * math.sqrt(points))
            + Upgrades.capacityBonus(config, profile))
    end
    local function walk()
        local points = profile.speedLevel
        return config.BaseSpeed + (config.MaxSpeed - config.BaseSpeed) * points / (points + config.SpeedHalfPoints)
    end
    local function gymGain()
        local best = 2 -- starter gym
        for _, tier in config.TrainingTiers do
            if launches >= tier.cycles then best = math.max(best, tier.gain) end
        end
        return best
    end
    local function shop()
        while true do
            local best, bestPrice
            for _, track in config.UpgradeOrder do
                local price = Upgrades.price(config, track, Upgrades.level(profile, track))
                if price and (not bestPrice or price < bestPrice) then best, bestPrice = track, price end
            end
            if not best or profile.coins < bestPrice then return end
            profile.coins -= bestPrice
            profile.upgrades[best] = Upgrades.level(profile, best) + 1
            buys += 1
        end
    end
    for number = 1, Cycles.Count do
        local cycle = Cycles.get(number)
        local tier = cycle.ModelTier
        local started = t
        for _, need in { cycle.ConstructionRequired, cycle.FuelRequired } do
            local done = 0
            while done < need do
                local carry = capacity()
                local fill = done / need
                local distance = 2 * (TRIP_BASE + HEIGHT[tier] * fill) - 2 * (Upgrades.reach(config, profile) - config.FrontierReach)
                local trip = distance / walk() + math.ceil(carry / Upgrades.pickupUnits(config, profile)) * config.MaterialHoldSeconds
                    + Upgrades.pourSeconds(config, profile) + HANDLING
                local gained = gymGain() * trip * train / (1 - train)
                profile.strengthLevel += gained / 2
                profile.speedLevel += gained / 2
                fromGyms += gained
                local units = math.min(carry * players, need - done)
                done += units
                profile.coins += units / players * config.CoinsPerUnit
                shop()
                t += trip / (1 - train)
            end
        end
        local tierInfo = Cycles.Tiers[tier]
        local stay = cycle.RewardSeconds or config.RewardSeconds
        local perSecond = config.Planet.StrengthBonus * config.Destinations[tier].reward * cycle.RewardMultiplier
        local passive = perSecond * stay
        local gym = 2 * perSecond * stay * gymShare
        profile.strengthLevel += passive + gym / 2
        profile.speedLevel += passive + gym / 2
        fromDestinations += 2 * passive + gym
        t += tierInfo.BoardingSeconds + tierInfo.LaunchSeconds + stay + RESET_SECONDS
        launches += 1
        table.insert(rows, {
            cycle = number, design = tier, minutes = (t - started) / 60, total = t / 60, capacity = capacity(), walk = walk(),
            strength = profile.strengthLevel, speed = profile.speedLevel, upgrades = buys,
            destinationShare = fromDestinations / math.max(1, fromDestinations + fromGyms),
        })
    end
    return rows
end

return function(options)
    options = options or {}
    local train, gymShare = options.train or 0.15, options.gymShare or 0.66
    local lines, results = {}, {}
    for _, players in options.players or { 1, 4, 8 } do
        local rows = simulate(players, train, gymShare)
        results[players] = rows
        table.insert(lines, ("%d player(s), %d%% of time training — full program %.0f min"):format(players, train * 100, rows[#rows].total))
        table.insert(lines, " cyc des   min  total   cap  walk  strength   speed  upg  from-destinations")
        for _, r in rows do
            table.insert(lines, ("  %2d   %d  %5.1f %6.1f  %4d  %4.1f  %8.0f  %6.0f  %3d  %3.0f%%"):format(
                r.cycle, r.design, r.minutes, r.total, r.capacity, r.walk, r.strength, r.speed, r.upgrades, r.destinationShare * 100))
        end
        table.insert(lines, "")
    end
    return table.concat(lines, "\n"), results
end
