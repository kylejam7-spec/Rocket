-- Pacing report: simulates a server's first `launches` missions (Moon, then the seeded
-- mission wheel with pity) with N identical players from the live tunables (Config,
-- Shared.Missions, Shared.Upgrades), so balance changes show up here before anyone
-- plays them. Every player count sees the same mission sequence (same `seed`).
-- Not a check: it reports, it doesn't assert.
-- From the Studio command bar or MCP (server):
--   print(require(game.ServerScriptService.ProgressionReport)())
--   print(require(game.ServerScriptService.ProgressionReport)({ players = { 1, 8 }, train = 0.3, launches = 30, seed = 7 }))
--
-- Model (timings measured in Studio, 2026-10-15): a trip is 230 studs from the pit or
-- refinery to the ramp foot and back, plus the climb along the tilted rocket to the
-- fill line (rocket length x fill), at walk speed; plus pickup and place ticks and 2 s handling.
-- Players spend `train` of their time on the best unlocked map gym (half bench, half
-- treadmill), buy the cheapest affordable upgrade, and at each destination stand for
-- the passive bonus and spend `gymShare` of the stay on its 2x gym.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Shared.Config)
local Missions = require(ReplicatedStorage.Shared.Missions)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local StatLevels = require(ReplicatedStorage.Shared.StatLevels)

-- Rocket lengths per design (RocketModels header comments), for the ramp climb.
local HEIGHT = { 53, 78, 109, 143, 194 }
local TRIP_BASE, HANDLING, RESET_SECONDS = 230, 2, 6

local function simulate(players, train, gymShare, sequence)
    local profile = { strengthLevel = 0, speedLevel = 0, planetBonuses = { strength = 0, speed = 0 }, upgrades = {}, coins = 0 }
    local launches, buys, t, fromDestinations, fromGyms = 0, 0, 0, 0, 0
    local rows = {}
    local function capacity()
        return StatLevels.capacity(config, (StatLevels.level(config, profile.strengthLevel)))
    end
    local function walk()
        return StatLevels.walk(config, (StatLevels.level(config, profile.speedLevel)))
    end
    local function gymGain()
        local best = config.TrainingBaseGain * config.FreeGymMultiplier -- free gym
        for _, tier in config.TrainingTiers do
            if launches >= tier.cycles then best = math.max(best, config.TrainingBaseGain * tier.multiplier) end
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
    for number, mission in sequence do
        local cycle = Missions.get(mission)
        local tier = cycle.ModelTier
        local started = t
        for _, need in { cycle.ConstructionRequired, cycle.FuelRequired } do
            local done = 0
            while done < need do
                local carry = capacity()
                local fill = done / need
                local distance = 2 * (TRIP_BASE + HEIGHT[tier] * fill) - 2 * (Upgrades.reach(config, profile) - config.FrontierReach)
                local trip = distance / walk() + math.ceil(carry / Upgrades.pickupUnits(config, profile)) * config.MaterialHoldSeconds
                    + math.ceil(carry / Upgrades.placeUnits(config, profile)) * config.MaterialHoldSeconds + HANDLING
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
        local tierInfo = cycle.Tier
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
            cycle = number, design = tier, id = cycle.Id, minutes = (t - started) / 60, total = t / 60, capacity = capacity(), walk = walk(),
            strength = profile.strengthLevel, speed = profile.speedLevel, upgrades = buys,
            level = (StatLevels.level(config, profile.strengthLevel)),
            destinationShare = fromDestinations / math.max(1, fromDestinations + fromGyms), coins = profile.coins,
            levels = table.clone(profile.upgrades),
        })
    end
    return rows
end

return function(options)
    options = options or {}
    local train, gymShare = options.train or 0.15, options.gymShare or 0.66
    -- One mission sequence for every player count: Moon first, then wheel spins.
    local random, misses, sequence = Random.new(options.seed or 1969), 0, { Missions.First }
    for _ = 2, options.launches or 20 do
        local mission = Missions.spin(random, misses)
        misses = Missions.afterSpin(misses, mission)
        table.insert(sequence, mission)
    end
    local lines, results = {}, {}
    local shares = Missions.longRun()
    local odds = {}
    for index = 1, Missions.Count do odds[index] = ("%s %.1f%%"):format(Missions.get(index).Id, shares[index] * 100) end
    table.insert(lines, "Long-run mission share with pity: " .. table.concat(odds, ", "))
    table.insert(lines, "")
    for _, players in options.players or { 1, 4, 8 } do
        local rows = simulate(players, train, gymShare, sequence)
        results[players] = rows
        table.insert(lines, ("%d player(s), %d%% of time training — %d launches in %.0f min"):format(players, train * 100, #rows, rows[#rows].total))
        table.insert(lines, " #   mission     min  total   cap  walk  level  strength   speed  upg  from-destinations")
        for _, r in rows do
            table.insert(lines, (" %2d  %-9s %5.1f %6.1f  %4d  %4.1f  %5d  %8.0f  %6.0f  %3d  %3.0f%%"):format(
                r.cycle, r.id, r.minutes, r.total, r.capacity, r.walk, r.level, r.strength, r.speed, r.upgrades, r.destinationShare * 100))
        end
        local levels = {}
        for _, track in config.UpgradeOrder do table.insert(levels, track .. " " .. (rows[#rows].levels[track] or 0)) end
        table.insert(lines, "Upgrade levels at the end: " .. table.concat(levels, ", ") .. ("; %d coins unspent"):format(rows[#rows].coins))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n"), results
end
