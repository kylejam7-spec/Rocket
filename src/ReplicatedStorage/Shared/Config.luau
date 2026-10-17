return table.freeze({
    -- Mission build sizes, wheel odds, countdown and launch timings live in Shared.Missions.
    MaterialHoldSeconds = 0.05,
    -- Every destination stay lasts two minutes.
    RewardSeconds = 120,
    InteractionDistance = 10,
    ActionCooldown = 0.5,
    TrainingSeconds = 1,
    -- Strength and speed are uncapped point totals turned into levels (Shared.StatLevels):
    -- level 1 costs 10 points, each level after x1.2, never more than 450 (from level 22,
    -- ~2,700 points in). Free gym (2/s): level 1 in 5 s, level 10 in ~2 min.
    StatLevels = table.freeze({ base = 10, growth = 1.2, max = 450 }),
    MaxPlanetBonus = 1000000,
    -- Carry = BaseCarryCapacity + CarryPerLevel * strength level, capped at MaxCapacity.
    BaseCarryCapacity = 10,
    CarryPerLevel = 3,
    MaxCapacity = 1000,
    -- Walk = BaseSpeed + (MaxSpeed - BaseSpeed) * level / (level + SpeedHalfLevel): +5
    -- at speed level 1, 47 at level 8, never above MaxSpeed (which MovementService also
    -- uses as its anti-teleport limit). Early levels match strength's first levels in
    -- delivery rate; later ones are worth less (see notes/BALANCE.md).
    BaseSpeed = 24,
    MaxSpeed = 70,
    SpeedHalfLevel = 8,
    -- Carried cargo is one scrap ball overhead: diameter = Base * (count / BaseCarryCapacity) ^ Growth.
    ScrapBallBaseDiameter = 2,
    ScrapBallGrowth = 0.55,
    ScrapBallMaxDiameter = 24,
    -- The rocket is built tilted against its ramp, then erected upright for boarding.
    RocketTiltDegrees = 45,
    ErectSeconds = 5,
    -- Place reach: from the glowing frontier ring, or along the rocket from the fill line
    -- while standing on a ramp (Build:inPlaceReach); also the place prompt's range.
    -- Placement Range adds 10% of it per level.
    FrontierReach = 12,
    -- Soft currency: coins per accepted delivery unit (Metal or Fuel), credited by the server.
    CoinsPerUnit = 1,
    -- The tutorial's closing "work with everyone" step stays up this long, then ends.
    TutorialFinalSeconds = 8,
    -- Coin upgrades (Shared.Upgrades has the math), 10 levels each, all on one price
    -- curve: level 1 costs UpgradePrices.base, and each level after costs the factor of
    -- the first segment it falls in times the last (x3 per level: 50 ... 984K). Each level
    -- is also a Robux Game Pass (RobuxUpgrades). Prices show as 3 significant figures
    -- (under 1,000: rounded to 5).
    Upgrades = table.freeze({
        BulkPickup = table.freeze({ name = "Bulk Pickup", icon = "✋", max = 10, step = 1 }), -- +1 unit per pickup tick
        BulkPlace = table.freeze({ name = "Bulk Place", icon = "⚡", max = 10, step = 1 }), -- +1 unit per place tick
        PlacementRange = table.freeze({ name = "Placement Range", icon = "📏", max = 10, step = 0.1 }), -- +10% reach
    }),
    UpgradePrices = table.freeze({
        base = 50,
        segments = table.freeze({
            table.freeze({ upTo = 10, factor = 3 }),
        }),
    }),
    UpgradeOrder = table.freeze({ "BulkPickup", "BulkPlace", "PlacementRange" }),
    -- Robux upgrades (RobuxUpgradeService): one Game Pass per track per level; owning the
    -- level-N pass keeps that track at level N or higher, re-checked on every join.
    -- `prices[level]` mirror the Creator Dashboard (the panel shows them); `passes[track][level]`
    -- are the dashboard pass IDs. Never invent IDs: copy them from the dashboard.
    RobuxUpgrades = table.freeze({
        prices = table.freeze({ 53, 63, 73, 83, 93, 103, 113, 123, 133, 143 }),
        passes = table.freeze({
            BulkPickup = table.freeze({ 2040698288, 2040812274, 2036912792, 2036780773, 2040140377, 2039792557, 2037242818, 2040440308, 2040044519, 2038148781 }),
            BulkPlace = table.freeze({ 2036864764, 2037932794, 2038226786, 2036618761, 2037752757, 2036804805, 2037332787, 2036612743, 2037698751, 2037980759 }),
            PlacementRange = table.freeze({ 2039762544, 2036090762, 2039702563, 2036288776, 2037332789, 2037314800, 2036072766, 2040734288, 2038064735, 2036804806 }),
        }),
    }),
    -- Rank titles above names: the highest rank whose deliveries and launches you have.
    Ranks = table.freeze({
        table.freeze({ name = "APPRENTICE", deliveries = 0, launches = 0 }),
        table.freeze({ name = "MECHANIC", deliveries = 250, launches = 0 }),
        table.freeze({ name = "ENGINEER", deliveries = 1500, launches = 1 }),
        table.freeze({ name = "FLIGHT DIRECTOR", deliveries = 6000, launches = 3 }),
        table.freeze({ name = "COMMANDER", deliveries = 20000, launches = 8 }),
    }),
    -- Gym District tiers, in walking order after the free gym. Each station gains
    -- TrainingBaseGain * multiplier strength or speed per TrainingSeconds tick (the free
    -- gym uses FreeGymMultiplier), and its sign's "xN" badge is that multiplier: a boost,
    -- not the main source (the top gym, 13/s, needs ~35 s per capped level).
    TrainingBaseGain = 1,
    FreeGymMultiplier = 2,
    TrainingTiers = table.freeze({
        table.freeze({ cycles = 1, multiplier = 3 }),
        table.freeze({ cycles = 3, multiplier = 4 }),
        table.freeze({ cycles = 8, multiplier = 5 }),
        table.freeze({ cycles = 15, multiplier = 7 }),
        table.freeze({ cycles = 25, multiplier = 9 }),
        table.freeze({ cycles = 50, multiplier = 11 }),
        table.freeze({ cycles = 100, multiplier = 13 }),
    }),
    -- Per-second stat reward unit for passengers at a destination: x the destination's
    -- reward (rarer missions pay more) x the mission's RewardMultiplier (Shared.Missions).
    -- Each destination's own bench and treadmill give double its per-second reward.
    -- Rewards step up evenly by rarity: 3 / 6 / 9 / 12 / 15 of each stat per second
    -- (Moon → Black Hole, reward 1-5). Standing through a Moon stay gives 360 of each,
    -- the Black Hole 1,800; their 2x gyms (6-30/s) are the best training in the game.
    Planet = table.freeze({ StrengthBonus = 3, SpeedBonus = 3 }),
    -- Mission wheel: it starts this many seconds before a reward stay ends and spins
    -- for WheelSpinSeconds; everyone sees it (WheelController).
    WheelLeadSeconds = 10,
    WheelSpinSeconds = 6,
    -- Where each mission flies (same index as Shared.Missions: Common → Legendary):
    -- isolated areas far from the main map, 10,000 studs apart so their giant
    -- backdrops (Saturn's rings carry ~4,000) never show in another sky. Gravity is
    -- applied on the passenger's client while there.
    Destinations = table.freeze({
        table.freeze({ id = "Moon", reward = 1, name = "THE MOON", gravity = 60, color = Color3.fromRGB(200, 200, 210), position = Vector3.new(10000, 200, 10000) }),
        table.freeze({ id = "Mars", reward = 2, name = "MARS", gravity = 110, color = Color3.fromRGB(235, 110, 60), position = Vector3.new(20000, 200, 10000) }),
        table.freeze({ id = "Europa", reward = 3, name = "EUROPA", gravity = 50, color = Color3.fromRGB(150, 225, 255), position = Vector3.new(30000, 200, 10000) }),
        table.freeze({ id = "Saturn", reward = 4, name = "SATURN'S RINGS", gravity = 90, color = Color3.fromRGB(230, 200, 130), position = Vector3.new(40000, 200, 10000) }),
        table.freeze({ id = "BlackHole", reward = 5, name = "THE BLACK HOLE", gravity = 80, color = Color3.fromRGB(190, 110, 255), position = Vector3.new(50000, 200, 10000) }),
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
