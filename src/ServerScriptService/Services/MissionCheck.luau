-- The mission wheel: odds as designed, pity after four spins below Rare, pity pool
-- Rare-or-better only, and the long-run share each mission really gets.
return function()
    local Missions = require(game:GetService("ReplicatedStorage").Shared.Missions)
    local config = require(game:GetService("ReplicatedStorage").Shared.Config)
    assert(Missions.Count == #config.Destinations, "one destination per mission")
    assert(Missions.get(Missions.First).Id == "Moon", "new servers start on the Moon")

    -- Designed odds: 40 / 28 / 19 / 10 / 3, pity 0 / 0 / 34 / 33 / 33.
    local expected = { 40, 28, 19, 10, 3 }
    local pityExpected = { 0, 0, 34, 33, 33 }
    local normal, pity = Missions.weights(0)
    assert(not pity)
    local pityWeights, isPity = Missions.weights(Missions.PityAfter)
    assert(isPity and Missions.PityAfter == 4)
    for index = 1, Missions.Count do
        assert(normal[index] == expected[index], "weight " .. index)
        assert(pityWeights[index] == pityExpected[index], "pity weight " .. index)
        assert((pityWeights[index] > 0) == (Missions.get(index).Rank >= Missions.PityRank), "pity pool is exactly Rare and up")
    end
    assert(not select(2, Missions.weights(Missions.PityAfter - 1)), "pity only after four misses")

    -- The counter: misses add up below Rare, any Rare+ resets.
    assert(Missions.afterSpin(0, 1) == 1 and Missions.afterSpin(3, 2) == 4)
    assert(Missions.afterSpin(3, 3) == 0 and Missions.afterSpin(4, 5) == 0)

    -- Sampled spins match the weights (seeded, so the check is deterministic).
    local random = Random.new(1969)
    local counts, samples = {}, 50000
    for _ = 1, samples do
        local index = Missions.spin(random, 0)
        counts[index] = (counts[index] or 0) + 1
    end
    for index, weight in expected do
        local share = (counts[index] or 0) / samples * 100
        assert(math.abs(share - weight) < 1, ("mission %d drew %.1f%%, expected %d%%"):format(index, share, weight))
    end
    for _ = 1, 2000 do
        local index, wasPity = Missions.spin(random, Missions.PityAfter)
        assert(wasPity and Missions.get(index).Rank >= Missions.PityRank, "a pity spin landed below Rare")
    end

    -- Simulated server: never five misses in a row; long-run shares match the exact chain.
    local misses, streak, longest, landed = 0, 0, 0, {}
    for _ = 1, 100000 do
        local index = Missions.spin(random, misses)
        misses = Missions.afterSpin(misses, index)
        streak = misses == 0 and 0 or streak + 1
        longest = math.max(longest, streak)
        landed[index] = (landed[index] or 0) + 1
    end
    assert(longest <= Missions.PityAfter, "more than four misses in a row")
    local exact, total = Missions.longRun(), 0
    for index = 1, Missions.Count do
        total += exact[index]
        assert(math.abs(landed[index] / 100000 - exact[index]) < 0.01, "long-run share of mission " .. index)
    end
    assert(math.abs(total - 1) < 1e-6)
    -- The legendary stays special even with pity: under one launch in ten.
    assert(exact[5] > 0.03 and exact[5] < 0.1, ("Black Hole long-run share %.1f%%"):format(exact[5] * 100))
end
