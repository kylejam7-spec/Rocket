return function()
    local Rocket = require(script.Parent.RocketService)
    local Hold = require(script.Parent.HoldService)
    local Models = require(script.Parent.RocketModels)
    local Missions = require(game.ReplicatedStorage.Shared.Missions)
    local config = require(game.ReplicatedStorage.Shared.Config)
    assert(config.MaterialHoldSeconds == 0.05)
    -- Mission data: five missions, one rocket design each, rarer = more work.
    assert(Missions.Count == 5 and Missions.First == 1)
    local previous = 0
    for index = 1, Missions.Count do
        local mission = Missions.get(index)
        assert(mission.ModelTier == index and mission.Rank == index)
        local work = mission.ConstructionRequired + mission.FuelRequired
        assert(work > previous, "Rarer missions must need more work")
        previous = work
    end
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
                assert(math.abs(p.X) <= 174 and math.abs(p.Z) <= 132, spec.name .. " leaves the launch complex")
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
    -- The next rocket is the spun mission (the same one if nothing was spun).
    rocket:lockPassengers({ [1] = true })
    rocket.phase = "Resetting"
    local spun = rocket:nextCycle("next", 3)
    assert(spun.mission == 3 and spun.launches == 1 and spun.required.Metal == Missions.get(3).ConstructionRequired)
    local again = Rocket.new(config, "again", 4, 7)
    again.phase = "Resetting"
    assert(again:nextCycle("same").mission == 4 and again:nextCycle("same").launches == 8)
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
    -- Held button: transfers wherever the player is in range, one per tick.
    local holds = Hold.new(0.05)
    assert(holds:press(1, "cycle", 0) and not holds:press(1, "cycle", 0), "One hold per player")
    local entry = holds.active[1]
    local inRange = {}
    local function near(target) return inRange[target] end
    assert(holds:pick(entry, 0, { "pit", "ring" }, near) == nil, "Held while walking, out of range: nothing")
    inRange.pit = true
    assert(holds:pick(entry, 0.01, { "pit", "ring" }, near) == "pit", "Reaching a target with E held transfers at once")
    assert(holds:pick(entry, 0.03, { "pit", "ring" }, near) == nil, "Rate limited to one per tick")
    assert(holds:pick(entry, 0.06, { "pit", "ring" }, near) == "pit")
    holds:refused(entry, "pit")
    assert(holds:pick(entry, 0.2, { "pit", "ring" }, near) == nil, "A full ball stops pickups without spamming")
    inRange.pit, inRange.ring = nil, true
    assert(holds:pick(entry, 0.3, { "pit", "ring" }, near) == "ring", "Walk to the ring, still held: place")
    holds:refused(entry, "ring")
    inRange.ring, inRange.pit = nil, true
    assert(holds:pick(entry, 0.4, { "pit", "ring" }, near) == "pit", "Leaving range re-arms a refused target")
    holds:release(1)
    assert(not holds.active[1])
    return "Cycle config, tier bounds/heights, phase-gated pickup, capacity, delivery, cycle advance, program reset and coin credit checks passed"
end
