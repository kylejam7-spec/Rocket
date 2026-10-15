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
    -- 24 at 0, ~34 after a minute on the starter treadmill, never above MaxSpeed
    -- (which MovementService also uses as its anti-teleport limit).
    BaseSpeed = 24,
    MaxSpeed = 44,
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
    TrainingTiers = table.freeze({
        table.freeze({ cycles = 1, gain = 4 }),
        table.freeze({ cycles = 3, gain = 6 }),
        table.freeze({ cycles = 5, gain = 8 }),
        table.freeze({ cycles = 10, gain = 10 }),
        table.freeze({ cycles = 12, gain = 12 }),
    }),
    Planet = table.freeze({ Id = "Meadow", StrengthBonus = 3, SpeedBonus = 3 }),
    -- Persistence stays off for reproducible, non-production Studio tests.
    PersistenceEnabled = false,
    DataStoreName = "RocketProfiles_v1_test",
    AutosaveSeconds = 30,
    LeaseSeconds = 120,
    RecentRewardLimit = 64,
})
