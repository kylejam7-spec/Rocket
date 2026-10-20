-- Leaderboards: every category has one panel, values come from the profile as whole
-- numbers, this server's live values replace stored ones (a player who spent their
-- coins drops at once), and the value column stays short.
return function()
    local Leaderboards = require(script.Parent.LeaderboardService)
    local shown = {}
    for _, stand in Leaderboards.Stands do
        assert(#stand == 3, "each stand shows three boards")
        for _, key in stand do
            assert(Leaderboards.byKey[key] and not shown[key], key .. " is unknown or on two panels")
            shown[key] = true
        end
    end
    for _, category in Leaderboards.Categories do assert(shown[category.key], category.key .. " has no panel") end

    local profile = { strengthLevel = 1200, speedLevel = 300, planetBonuses = { strength = 55.5, speed = 7 },
        coins = 42, completedLaunches = 9, lifetimeDeliveries = 31000 }
    assert(Leaderboards.value("Strength", profile) == 1255 and Leaderboards.value("Speed", profile) == 307, "points, not levels")
    assert(Leaderboards.value("Coins", profile) == 42 and Leaderboards.value("Launches", profile) == 9)
    assert(Leaderboards.value("Delivered", profile) == 31000 and Leaderboards.value("BlackHoles", profile) == 0)

    local stored = { { userId = 1, value = 500 }, { userId = 2, value = 400 }, { userId = 3, value = 300 } }
    local rows = Leaderboards.merge(stored, { [2] = 0, [4] = 450 }, 3)
    assert(#rows == 3 and rows[1].userId == 1 and rows[2].userId == 4 and rows[3].userId == 3, "live values replace stored ones")
    rows = Leaderboards.merge(stored, { [3] = 900 }, 2)
    assert(#rows == 2 and rows[1].userId == 3 and rows[1].value == 900 and rows[2].userId == 1, "top N only")
    rows = Leaderboards.merge({ { userId = 9, value = 5 }, { userId = 8, value = 5 } }, {}, 10)
    assert(rows[1].userId == 8, "ties by user ID")

    assert(Leaderboards.format(0) == "0" and Leaderboards.format(1234) == "1,234" and Leaderboards.format(9999999) == "9,999,999")
    assert(Leaderboards.format(12345678) == "12.3M" and Leaderboards.format(4567000000) == "4.56B" and Leaderboards.format(999999999) == "999M")
end
