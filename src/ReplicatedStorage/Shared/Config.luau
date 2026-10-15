return table.freeze({
    -- Per-cycle requirements, countdown and launch timings live in Shared.RocketCycles.
    MaterialHoldSeconds = 0.05,
    RewardSeconds = 30,
    InteractionDistance = 10,
    ActionCooldown = 0.5,
    TrainingSeconds = 1,
    -- Strength and speed are uncapped point totals; soft curves turn them into stats.
    MaxPlanetBonus = 1000000,
    -- Walk = BaseSpeed + (MaxSpeed - BaseSpeed) * points / (points + SpeedHalfPoints):
    -- 24 at 0, ~42 after a minute on the starter treadmill, never above MaxSpeed
    -- (which MovementService also uses as its anti-teleport limit).
    BaseSpeed = 24,
    MaxSpeed = 60,
    SpeedHalfPoints = 120,
    -- Carry = BaseCarryCapacity + floor(StrengthCarryScale * sqrt(strength)), capped:
    -- the first starter-bench tick (+2) already adds 2, a minute there gives 26, then
    -- growth slows (1,000 strength -> 57).
    -- Base 10 per ~10 s depot round trip gives a new solo player ~10 min on Cycle 1.
    BaseCarryCapacity = 10,
    StrengthCarryScale = 1.5,
    MaxCapacity = 1000,
    -- Carried cargo is one scrap ball overhead: diameter = Base * (count / BaseCarryCapacity) ^ Growth.
    ScrapBallBaseDiameter = 2,
    ScrapBallGrowth = 0.55,
    ScrapBallMaxDiameter = 24,
    -- The rocket is built tilted against its ramp, then erected upright for boarding.
    RocketTiltDegrees = 45,
    ErectSeconds = 5,
    -- Holding E at the build frontier pours a full ball in about this long, whatever its size.
    PourSeconds = 1.5,
    -- Place reach: from the glowing frontier ring, or along the rocket from the fill line
    -- while standing on a ramp (Build:inPlaceReach); also the place prompt's range.
    FrontierReach = 12,
    -- Soft currency: coins per accepted delivery unit (Metal or Fuel), credited by the server.
    CoinsPerUnit = 1,
    -- The tutorial's closing "work with everyone" step stays up this long, then ends.
    TutorialFinalSeconds = 8,
    -- Coin upgrades (Shared.Upgrades has the math). Price of level n+1 = base * growth^n,
    -- rounded to 5. Tuned by UpgradeCheck's first-hour sim: first buy < 1 min, then
    -- one every 3-5 min on average.
    Upgrades = table.freeze({
        BulkPickup = table.freeze({ name = "Bulk Pickup", icon = "✋", base = 10, growth = 2.2, max = 10, step = 1 }), -- +1 unit per pickup tick
        BulkPlace = table.freeze({ name = "Bulk Place", icon = "⚡", base = 90, growth = 2.2, max = 10, step = 0.25 }), -- pour speed +25%
        PlacementRange = table.freeze({ name = "Placement Range", icon = "📏", base = 120, growth = 2.2, max = 8, step = 2 }), -- +2 studs reach
        CarryCapacity = table.freeze({ name = "Carry Capacity", icon = "🎒", base = 120, growth = 2.2, max = 10, step = 5 }), -- +5 carry
    }),
    UpgradeOrder = table.freeze({ "BulkPickup", "BulkPlace", "PlacementRange", "CarryCapacity" }),
    -- Rank titles above names: the highest rank whose deliveries and launches you have.
    Ranks = table.freeze({
        table.freeze({ name = "APPRENTICE", deliveries = 0, launches = 0 }),
        table.freeze({ name = "MECHANIC", deliveries = 250, launches = 0 }),
        table.freeze({ name = "ENGINEER", deliveries = 1500, launches = 1 }),
        table.freeze({ name = "FLIGHT DIRECTOR", deliveries = 6000, launches = 3 }),
        table.freeze({ name = "COMMANDER", deliveries = 20000, launches = 8 }),
    }),
    TrainingTiers = table.freeze({
        table.freeze({ cycles = 1, gain = 4 }),
        table.freeze({ cycles = 3, gain = 6 }),
        table.freeze({ cycles = 5, gain = 8 }),
        table.freeze({ cycles = 10, gain = 10 }),
        table.freeze({ cycles = 12, gain = 12 }),
    }),
    -- Per-second stat reward unit for passengers at a destination: x the destination's
    -- reward (further out pays more) x the cycle's RewardMultiplier (final mission x2).
    -- Each destination's own bench and treadmill give double its per-second reward.
    Planet = table.freeze({ StrengthBonus = 3, SpeedBonus = 3 }),
    -- Where each rocket design flies (by RocketCycles ModelTier): isolated areas far
    -- from the main map and 10,000 studs apart (Saturn's rings carry ~4,000) so their giant backdrops never overlap.
    -- Gravity is applied on the passenger's client while there.
    Destinations = table.freeze({
        table.freeze({ id = "SpaceStation", reward = 1, name = "THE SPACE STATION", gravity = 196.2, color = Color3.fromRGB(120, 200, 255), position = Vector3.new(10000, 200, 10000) }),
        table.freeze({ id = "Moon", reward = 2, name = "THE MOON", gravity = 60, color = Color3.fromRGB(200, 200, 210), position = Vector3.new(20000, 200, 10000) }),
        table.freeze({ id = "Mars", reward = 3, name = "MARS", gravity = 110, color = Color3.fromRGB(235, 110, 60), position = Vector3.new(30000, 200, 10000) }),
        table.freeze({ id = "Saturn", reward = 4, name = "SATURN", gravity = 90, color = Color3.fromRGB(230, 200, 130), position = Vector3.new(40000, 200, 10000) }),
        table.freeze({ id = "Pluto", reward = 6, name = "PLUTO", gravity = 50, color = Color3.fromRGB(180, 215, 255), position = Vector3.new(50000, 200, 10000) }),
    }),
    -- The inside of the rocket: boarding players wait here for liftoff.
    CabinPosition = Vector3.new(-3000, 200, 0),
    -- Persistence stays off for reproducible, non-production Studio tests.
    PersistenceEnabled = false,
    DataStoreName = "RocketProfiles_v1_test",
    AutosaveSeconds = 30,
    LeaseSeconds = 120,
    RecentRewardLimit = 64,
})
