-- The move check's budget (MovementService): walking and every legitimate fast move
-- (late-game speed, ramp slides, airborne runs, moves bunched up after lag) fit in it;
-- a client moving faster than its profile's walk speed allows is snapped back within a
-- couple of seconds; the limit comes from the profile, not the Humanoid.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local StatLevels = require(ReplicatedStorage.Shared.StatLevels)
    local Movement = require(script.Parent.MovementService)
    local Profiles = require(script.Parent.ProfileService)
    local factor = config.MoveLimitFactor

    -- Runs `seconds` of samples every 0.2 s at `speed` studs/s (horizontal); `lag` = { at,
    -- seconds }: no movement seen for that long, then it all arrives in one sample.
    -- Returns the lowest budget seen and when it first went below zero (nil: never).
    local function run(walk, speed, seconds, lag)
        local rate = walk * factor
        local budget, lowest, failedAt, held = Movement.cap(config, rate), math.huge, nil, 0
        for step = 1, math.round(seconds / 0.2) do
            local t = step * 0.2
            local moved = speed * 0.2
            if lag and t > lag.at and t <= lag.at + lag.seconds then
                held += moved
                moved = 0
            elseif held > 0 then
                moved += held
                held = 0
            end
            budget = Movement.spend(config, budget, rate, 0.2, moved)
            lowest = math.min(lowest, budget)
            if budget < 0 and not failedAt then failedAt = t end
        end
        return lowest, failedAt
    end
    local base = config.BaseSpeed
    -- Normal play: walking, jumping and airborne runs (SpeedController caps them at 1.3x
    -- walk), and ramp slides (walk speed along a 40-degree slope) never fail.
    assert(select(2, run(base, base, 60)) == nil, "walking snapped back")
    assert(select(2, run(base, base * 1.3, 60)) == nil, "airborne run snapped back")
    assert(select(2, run(config.MaxSpeed, config.MaxSpeed, 60)) == nil, "late-game run snapped back")
    assert(select(2, run(config.MaxSpeed, config.MaxSpeed * math.cos(math.rad(40)), 60)) == nil, "ramp slide snapped back")
    -- A second and a half of lag, then it all arrives at once: still fine.
    assert(select(2, run(base, base, 20, { at = 5, seconds = 1.5 })) == nil, "a lag burst snapped back")
    -- A new player at 70 studs/s (the old floor let up to ~85 through) is caught within 3 s;
    -- just over the limit is caught too, only later.
    local _, caught = run(base, 70, 10)
    assert(caught and caught <= 3, "speed hack not caught")
    assert(select(2, run(base, base * factor * 1.1, 60)) ~= nil, "sustained overspeed not caught")
    -- One jump bigger than the bank: caught at once.
    assert(Movement.spend(config, Movement.cap(config, base * factor), base * factor, 0.2, Movement.cap(config, base * factor) + base * factor * 0.2 + 1) < 0)

    -- The service: limit from the profile's walk speed, not the Humanoid's (a client
    -- can't raise it), snap back to the last good spot, then walking carries on.
    local rig = Instance.new("Model")
    local root = Instance.new("Part")
    root.Name, root.Anchored, root.Position = "HumanoidRootPart", true, Vector3.new(0, 1000, 0)
    root.Parent = rig
    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = 400
    humanoid.Parent = rig
    local player = { UserId = -4242, Character = rig }
    local profile = Profiles.validate(nil, config)
    local ctx = { config = config, profiles = { records = { [player.UserId] = { profile = profile } } },
        Stats = { speed = function(p) return StatLevels.walk(config, StatLevels.level(config, p.speedLevel + p.planetBonuses.speed)) end } }
    local service = Movement.new(ctx)
    service.track(player, root, 0)
    local now = os.clock()
    -- Walking (base speed) for 2 s: never snapped.
    for _ = 1, 10 do
        now += 0.2
        root.Position += Vector3.new(base * 0.2, 0, 0)
        service.sample(player, now)
    end
    local good = root.Position
    assert((good - Vector3.new(base * 2, 1000, 0)).Magnitude < 0.01, "walking was snapped back")
    -- 100 studs/s (fine for a Humanoid at 400, not for this profile): snapped back.
    local snapped = false
    for _ = 1, 15 do
        now += 0.2
        local before = root.Position
        root.Position += Vector3.new(100 * 0.2, 0, 0)
        service.sample(player, now)
        if (root.Position - before).Magnitude < 0.01 then snapped = true break end
    end
    assert(snapped, "speed above the profile's limit not snapped back")
    -- A server teleport (relocate's track) is a fresh start, never a snap.
    service.track(player, root, 0)
    now = os.clock()
    root.Position += Vector3.new(5000, 0, 0)
    service.track(player, root, 0)
    now += 0.2
    local there = root.Position
    service.sample(player, now)
    assert(root.Position == there, "a server teleport was snapped back")
    -- A faster profile raises the limit.
    profile.speedLevel = 100000
    for _ = 1, 10 do
        now += 0.2
        root.Position += Vector3.new(100 * 0.2, 0, 0)
        service.sample(player, now)
    end
    assert((root.Position - there).Magnitude > 150, "a fast profile was held to base speed")
    service.forget(player)
    rig:Destroy()
end
