return table.freeze({
    -- Per-cycle requirements, countdown and launch timings live in Shared.RocketCycles.
    MaterialHoldSeconds = 0.05,
    RewardSeconds = 30,
    InteractionDistance = 10,
    ActionCooldown = 0.5,
    TrainingSeconds = 1,
    MaxLevel = 50,
    MaxPlanetBonus = 1000000,
    BaseSpeed = 16,
    SpeedPerLevel = 0.3,
    MaxSpeed = 32,
    -- Carry = BaseCarryCapacity + floor(strength / StrengthPerCarry), capped.
    -- Base 10 per ~10 s depot round trip gives a new solo player ~10 min on Cycle 1.
    BaseCarryCapacity = 10,
    StrengthPerCarry = 15,
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
    -- Reach from the glowing frontier ring; a bit more than InteractionDistance for wide tanks.
    FrontierReach = 12,
    -- Soft currency: coins per accepted delivery unit (Metal or Fuel), credited by the server.
    CoinsPerUnit = 1,
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
