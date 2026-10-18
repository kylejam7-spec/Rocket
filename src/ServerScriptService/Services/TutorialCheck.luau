-- Tutorial step rules and the v3 profile migration; no players or world needed.
return function()
    local Tutorial = require(script.Parent.TutorialService)
    local Profiles = require(script.Parent.ProfileService)
    local config = require(game.ReplicatedStorage.Shared.Config)
    local steps = Tutorial.Steps

    -- Every step finishes only on its own event, in order, and ends at Done.
    local step = steps[1]
    for index, name in steps do
        for _, other in steps do
            if other ~= name then assert(Tutorial.advance(step, other) == nil, "out-of-order " .. other .. " skipped " .. step) end
        end
        step = Tutorial.advance(step, name)
        assert(step == (steps[index + 1] or Tutorial.Done), "bad advance from " .. name)
    end
    assert(step == Tutorial.Done)
    assert(Tutorial.advance("Place", "Place") == "Upgrade", "first upgrade comes right after the first delivery")
    for _, name in steps do assert(Tutorial.advance(Tutorial.Done, name) == nil, "Done must be final") end
    assert(Tutorial.advance(steps[1], "Skip") == nil and not Tutorial.valid("Skip") and Tutorial.valid(Tutorial.Done))

    -- New profiles start the tutorial with nothing seen.
    local fresh = Profiles.validate(nil, config)
    assert(fresh.schemaVersion == 7 and fresh.tutorialStep == steps[1] and #fresh.seenCallouts == 0)
    -- v2 players who already delivered skip it; brand-new v2 (and v1) profiles get it.
    local function v2(deliveries)
        return { schemaVersion = 2, strengthLevel = 0, speedLevel = 0, planetBonuses = { strength = 0, speed = 0 },
            completedLaunches = 0, lifetimeDeliveries = deliveries, coins = 0, rewardedLaunchIds = {} }
    end
    assert(Profiles.validate(v2(25), config).tutorialStep == Tutorial.Done)
    assert(Profiles.validate(v2(0), config).tutorialStep == steps[1])
    local v1 = v2(0); v1.schemaVersion, v1.coins = 1, nil
    local migrated = Profiles.validate(v1, config)
    assert(migrated.schemaVersion == 7 and migrated.coins == 0 and migrated.tutorialStep == steps[1])
    -- Saved v3 progress round-trips; bad values are refused rather than overwritten.
    local saved = Profiles.validate(v2(0), config)
    saved.tutorialStep, saved.seenCallouts = "Bench", { "Fuel" }
    local loaded = Profiles.validate(saved, config)
    assert(loaded.tutorialStep == "Bench" and loaded.seenCallouts[1] == "Fuel" and loaded.seenCallouts ~= saved.seenCallouts)
    for _, bad in { { tutorialStep = "Nope" }, { tutorialStep = 3 }, { seenCallouts = "Fuel" }, { seenCallouts = { 1 } } } do
        local raw = table.clone(saved)
        for key, value in bad do raw[key] = value end
        assert(not pcall(Profiles.validate, raw, config), "accepted bad tutorial data")
    end
end
