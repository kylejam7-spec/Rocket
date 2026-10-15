return function()
    local Rocket = require(script.Parent.RocketService)
    local Hold = require(script.Parent.HoldService)
    local Models = require(script.Parent.RocketModels)
    local Cycles = require(game.ReplicatedStorage.Shared.RocketCycles)
    local config = require(game.ReplicatedStorage.Shared.Config)
    assert(config.MaterialHoldSeconds == 0.05)
    -- Cycle data: 15 cycles, 5 tiers x 3, rising work, final cycle wraps to 1.
    assert(Cycles.Count == 15 and Cycles.next(15) == 1 and Cycles.get(15).IsFinalCycle)
    local previous = 0
    for number = 1, Cycles.Count do
        local cycle = Cycles.get(number)
        assert(cycle.ModelTier == math.ceil(number / 3) and cycle.Variant == (number - 1) % 3 + 1)
        local work = cycle.ConstructionRequired + cycle.FuelRequired
        assert(work > previous, "Each cycle must need more work")
        previous = work
    end
    assert(Cycles.launchesUntilNextTier(2) == 2 and Cycles.launchesUntilNextTier(13) == nil)
    -- Tiers fit the reserved launch complex and grow visibly taller.
    local lastHeight = 0
    for tier = 1, 5 do
        local data = Models[tier]()
        assert(data.height > lastHeight + 15, "Tier " .. tier .. " is not visibly taller")
        lastHeight = data.height
        assert(#data.build >= 15 and #data.build + #data.fuel + #data.infra <= 160, "Tier " .. tier .. " part budget")
        for _, list in { data.build, data.fuel, data.infra } do
            for _, spec in list do
                local p = spec.cframe.Position
                assert(math.abs(p.X) <= 58 and math.abs(p.Z) <= 44, spec.name .. " leaves the launch complex")
            end
        end
    end
    -- Phase flow: Metal only while building, Fuel only while fuelling, capacity per trip.
    local rocket = Rocket.new(config, "check", 1)
    rocket.required = { Metal = 25, Fuel = 10 }
    assert(rocket:pickup(1, "Fuel", 10) == 0, "Fuel is not accepted before the rocket is built")
    -- Holds/taps move one unit per tick.
    assert(rocket:pickup(1, "Metal", 10, 1) == 1 and rocket.cargo[1].count == 1)
    assert(rocket:deliver(1, 1) == 1 and rocket.cargo[1] == nil and rocket.totals.Metal == 1)
    rocket.totals.Metal, rocket.contributions[1] = 0, nil
    assert(rocket:pickup(1, "Metal", 10) == 10)
    assert(rocket:pickup(1, "Metal", 10) == 0, "Cargo full")
    assert(rocket:pickup(2, "Metal", 40) == 25, "Pickup is capped by what the rocket still needs")
    local accepted, advanced = rocket:deliver(1)
    assert(accepted == 10 and not advanced and rocket.cargo[1] == nil)
    accepted, advanced = rocket:deliver(2)
    assert(accepted == 15 and advanced and rocket.phase == "Fueling")
    assert(rocket.cargo[2] == nil, "Leftover Metal is dropped when construction completes")
    assert(rocket:pickup(1, "Metal", 10) == 0 and rocket:pickup(1, "Fuel", 10) == 10)
    accepted, advanced = rocket:deliver(1)
    assert(accepted == 10 and advanced and rocket.phase == "Boarding")
    assert(rocket.contributions[1] == 20 and rocket.contributions[2] == 15)
    -- Cycle advance only on a crewed launch; the final cycle restarts the program.
    rocket:lockPassengers({ [1] = true })
    rocket.phase = "Resetting"
    assert(rocket:nextCycle("next").cycleNumber == 2)
    local empty = Rocket.new(config, "empty", 4)
    empty.phase = "Resetting"
    assert(empty:nextCycle("retry").cycleNumber == 4, "An uncrewed launch repeats the cycle")
    local final = Rocket.new(config, "final", 15, 0)
    final.passengers, final.phase = { [1] = true }, "Resetting"
    local restarted = final:nextCycle("restart")
    assert(restarted.cycleNumber == 1 and restarted.programRuns == 1)
    -- Coins: credited only for units the rocket accepted, never twice, never for
    -- empty, discarded or leftover cargo.
    local Profiles = require(script.Parent.ProfileService)
    local profile = { lifetimeDeliveries = 0, coins = 0 }
    local paid = Rocket.new(config, "coins", 1)
    paid.required = { Metal = 12, Fuel = 5 }
    local function credit(userId, limit)
        local amount, done = paid:deliver(userId, limit)
        Profiles.credit(profile, amount, config)
        return amount, done
    end
    assert(paid:pickup(1, "Metal", 10) == 10)
    for _ = 1, 20 do credit(1, 1) end
    assert(profile.coins == 10 * config.CoinsPerUnit and profile.lifetimeDeliveries == 10, "Coins match delivered units")
    assert(credit(1) == 0 and profile.coins == 10 * config.CoinsPerUnit, "Empty cargo grants nothing")
    paid:pickup(1, "Metal", 10)
    paid.cargo[1] = nil -- DiscardCargo
    assert(credit(1) == 0 and profile.coins == 10 * config.CoinsPerUnit, "Discarded cargo grants nothing")
    paid:pickup(1, "Metal", 10)
    paid:pickup(2, "Metal", 10)
    assert(select(2, credit(1)) and profile.coins == 12 * config.CoinsPerUnit, "Only units the rocket needs pay")
    assert(paid:deliver(2) == 0, "Leftover Metal is dropped, so it can't pay later")
    for _, bad in { -5, 0, 0.5, 0 / 0, math.huge } do
        assert(Profiles.credit(profile, bad, config) == 0, "Invalid amount " .. tostring(bad))
    end
    assert(profile.coins == 12 * config.CoinsPerUnit and profile.lifetimeDeliveries == 12)
    local holds = Hold.new(0.05)
    holds:begin(1, "prompt", "cycle", 0)
    assert(holds.active[1].started == 0 and holds.duration == 0.05)
    holds:ended(1, "other")
    assert(holds.active[1])
    holds:ended(1, "prompt")
    assert(not holds.active[1])
    return "Cycle config, tier bounds/heights, phase-gated pickup, capacity, delivery, cycle advance, program reset and coin credit checks passed"
end
