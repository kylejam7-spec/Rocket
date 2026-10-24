return table.freeze({
    -- Mission build sizes, wheel odds, countdown and launch timings live in Shared.Missions.
    MaterialHoldSeconds = 0.05,
    -- Every destination stay lasts two minutes.
    RewardSeconds = 120,
    InteractionDistance = 10,
    ActionCooldown = 0.5,
    -- Gyms and treadmills tick 3 times a second, each tick paying the gym's multiplier
    -- (the 100x gym: 300 a second). Signs and tags show the per-second total.
    TrainingSeconds = 1 / 3,
    -- Strength and speed are uncapped point totals turned into levels (Shared.StatLevels):
    -- level 1 costs 10 points, each level after x1.2, never more than 450 (from level 22,
    -- ~2,700 points in). Free gym (2/s): level 1 in 5 s, level 10 in ~2 min.
    StatLevels = table.freeze({ base = 10, growth = 1.2, max = 450 }),
    MaxPlanetBonus = 1000000,
    -- Carry = BaseCarryCapacity + CarryPerLevel * strength level, uncapped: enough
    -- strength carries a whole rocket's Metal or Fuel in one trip.
    BaseCarryCapacity = 10,
    CarryPerLevel = 1,
    -- Walk = BaseSpeed + SpeedEarly * level / (level + SpeedHalfLevel) + SpeedPerLevel * level,
    -- capped at MaxSpeed: the early levels give big steps (29 at level 1, ~49 at level 8),
    -- then every level adds 0.6 (121 at 100, 243 at 300) up to 400 around level 560.
    -- MovementService's anti-teleport limit follows each player's own walk speed.
    BaseSpeed = 24,
    MaxSpeed = 400,
    SpeedEarly = 40,
    SpeedHalfLevel = 8,
    SpeedPerLevel = 0.6,
    -- The anti-teleport check allows this times a player's walk speed (never below 70).
    MoveLimitFactor = 1.5,
    MinMoveLimit = 70,
    -- Carried cargo is one scrap ball overhead: diameter = Base * (count / BaseCarryCapacity) ^ Growth,
    -- with no cap (only Roblox's largest part size).
    ScrapBallBaseDiameter = 2,
    ScrapBallGrowth = 0.55,
    -- The rocket is built tilted against its ramp, then erected upright for boarding. The
    -- tilt is from upright: 50 lays the hull and its ramps at 40 degrees to the ground.
    RocketTiltDegrees = 50,
    ErectSeconds = 5,
    -- Place reach: from the glowing frontier ring, or along the rocket from the fill line
    -- while standing on a ramp (Build:inPlaceReach); also the place prompt's range.
    -- Each Placement Range level adds a stud more than the last: 11 at level 1, 12 at
    -- level 2 ... 20 at level 10 (167 studs of reach in all).
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
        BulkPickup = table.freeze({ name = "Bulk Pickup", icon = "✋", max = 10, step = 1 }), -- units per pickup tick: see BulkFactor
        BulkPlace = table.freeze({ name = "Bulk Place", icon = "⚡", max = 10, step = 1 }), -- units per place tick: see BulkFactor
        PlacementRange = table.freeze({ name = "Placement Range", icon = "📏", max = 10, first = 11 }), -- studs level 1 adds
    }),
    UpgradePrices = table.freeze({
        base = 50,
        segments = table.freeze({
            table.freeze({ upTo = 10, factor = 3 }),
        }),
    }),
    -- Bulk Pickup / Bulk Place: 1 unit per tick unbought, then BulkFactor x (1 + level):
    -- 6, 9, 12 ... 33 a tick at level 10 (660 a second). User, 2026-10-23: x3 per level.
    BulkFactor = 3,
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
    -- The Robux SHOP (ShopService; names, icons and rules in Shared.Shop). `id` is the
    -- Creator Dashboard Game Pass / Developer Product ID: nil means not set up yet, and
    -- that offer shows its price greyed and can't be bought. `price` mirrors the dashboard's R$
    -- (the UI shows it). Never invent IDs: copy them from the dashboard.
    Shop = table.freeze({
        -- Game Passes: bought once, ownership re-checked on every join.
        passes = table.freeze({
            DoubleCoins = table.freeze({ id = 2042720701, price = 199 }),
            FastHatch = table.freeze({ id = 2037395515, price = 149 }),
            MultiHatch = table.freeze({ id = 2039573122, price = 249 }),
            PetSlot1 = table.freeze({ id = 2037017405, price = 99 }),
            PetSlot2 = table.freeze({ id = 2039741160, price = 179 }),
            -- Suits (Shared.Skins): 2x / 4x / 8x training, coins and launches (dashboard:
            -- "Gold / Commander / Galaxy Astronaut Skin").
            SuitGold = table.freeze({ id = 2053295062, price = 1199 }),
            SuitCommander = table.freeze({ id = 2052479099, price = 1499 }),
            SuitGalaxy = table.freeze({ id = 2055359009, price = 1999 }),
            -- Gym<n> unlocks TrainingTiers[n] without its launches.
            -- 2x / 5x / 10x / 25x / 50x / 75x / 100x (user set 50x-100x).
            Gym1 = table.freeze({ id = 2042480753, price = 49 }),
            Gym2 = table.freeze({ id = 2040347000, price = 129 }),
            Gym3 = table.freeze({ id = 2039867258, price = 249 }),
            Gym4 = table.freeze({ id = 2041586828, price = 449 }),
            Gym5 = table.freeze({ id = 2040706913, price = 699 }),
            Gym6 = table.freeze({ id = 2036915437, price = 899 }),
            Gym7 = table.freeze({ id = 2042348700, price = 1099 }),
            -- The SpaceX Gym at the back of the District: paid only (SpaceXGym below).
            GymSpaceX = table.freeze({ id = 2052845580, price = 1499 }),
        }),
        -- Developer Products: repeatable; each receipt is granted once (receipt journal).
        products = table.freeze({
            ServerTraining = table.freeze({ id = 3720386542, price = 79 }),
            -- Flat units into whichever material the rocket needs now (Metal or Fuel).
            Fill2000 = table.freeze({ id = 3720386733, price = 25 }),
            Fill4000 = table.freeze({ id = 3720386845, price = 45 }),
            Fill7000 = table.freeze({ id = 3720386948, price = 75 }),
            Fill11000 = table.freeze({ id = 3720387035, price = 109 }),
            Fill27500 = table.freeze({ id = 3720426887, price = 239 }),
            ExtraStay = table.freeze({ id = 3720387123, price = 39 }),
            NextMoon = table.freeze({ id = 3720387259, price = 19 }),
            NextMars = table.freeze({ id = 3720387367, price = 39 }),
            NextEuropa = table.freeze({ id = 3720387434, price = 69 }),
            NextSaturn = table.freeze({ id = 3720387492, price = 119 }),
            NextBlackHole = table.freeze({ id = 3720387554, price = 179 }),
            -- UFOs for Robux (Shared.Shop.ufoKey): Rare also sells for coins.
            UfoRare = table.freeze({ id = 3720390200, price = 349 }),
            UfoEpic = table.freeze({ id = 3720390071, price = 549 }),
            UfoLegendary = table.freeze({ id = 3720390015, price = 649 }),
        }),
        DoubleCoinsMultiplier = 2,
        FastHatchRate = 2, -- UFOs count down this many times faster
        MultiHatchCount = 3, -- UFOs that can fly at once with Triple Hatch (1 without)
        ServerTrainingMultiplier = 2,
        ServerTrainingSeconds = 600, -- each purchase adds this much (stacks)
        ExtraStaySeconds = 60,
        ExtraStayMax = 300, -- per stay; prompts stop opening past it
        ReceiptStore = "RocketReceipts",
    }),
    -- Rank titles above names: the highest rank whose completed launches you have
    -- (user, 2026-10-20: launches only, Intern to NASA CEO at 100).
    Ranks = table.freeze({
        table.freeze({ name = "INTERN", launches = 0 }),
        table.freeze({ name = "ROCKET TRAINEE", launches = 5 }),
        table.freeze({ name = "MECHANIC", launches = 10 }),
        table.freeze({ name = "ROCKET ENGINEER", launches = 20 }),
        table.freeze({ name = "FLIGHT DIRECTOR", launches = 30 }),
        table.freeze({ name = "LAUNCH SPECIALIST", launches = 40 }),
        table.freeze({ name = "MISSION COMMANDER", launches = 50 }),
        table.freeze({ name = "LAUNCH DIRECTOR", launches = 65 }),
        table.freeze({ name = "NASA DIRECTOR", launches = 80 }),
        table.freeze({ name = "NASA CEO", launches = 100 }),
    }),
    -- Gym District tiers, in walking order after the free gym. Each station gains
    -- TrainingBaseGain * multiplier strength or speed per TrainingSeconds tick, 3 ticks a
    -- second (the free gym uses FreeGymMultiplier), and its sign's "xN" badge is that multiplier: a boost,
    -- and the top gyms are the fast lane (user, 2026-10-20: free, 2x, 5x, 10x, 25x, 50x,
    -- 75x, 100x; each also sells as a SHOP gym access pass).
    TrainingBaseGain = 1,
    FreeGymMultiplier = 1,
    TrainingTiers = table.freeze({
        table.freeze({ cycles = 1, multiplier = 2 }),
        table.freeze({ cycles = 3, multiplier = 5 }),
        table.freeze({ cycles = 8, multiplier = 10 }),
        table.freeze({ cycles = 15, multiplier = 25 }),
        table.freeze({ cycles = 25, multiplier = 50 }),
        table.freeze({ cycles = 50, multiplier = 75 }),
        table.freeze({ cycles = 100, multiplier = 100 }),
    }),
    -- The SpaceX Gym, centred at the very back of the Gym District: no launches unlock
    -- it, only its Game Pass (Shop.passes.GymSpaceX).
    SpaceXGym = table.freeze({ key = "GymSpaceX", multiplier = 150, title = "SPACEX GYM" }),
    -- Per-tick stat reward unit for passengers at a destination, TicksPerSecond ticks a
    -- second: x the destination's reward (rarer missions pay more) x the mission's
    -- RewardMultiplier (Shared.Missions). User, 2026-10-20: double per tick (3 → 6) at 4
    -- ticks a second, so 24 / 48 / 72 / 96 / 120 of each stat per second (Moon → Black
    -- Hole, reward 1-5); a Moon stay gives 2,880 of each, the Black Hole 14,400.
    -- Each destination's bench and treadmill pay GymGain x reward per training tick
    -- (unchanged by the stay rewards: 6-30 per tick, 3 ticks a second).
    Planet = table.freeze({ StrengthBonus = 6, SpeedBonus = 6, TicksPerSecond = 4, GymGain = 6 }),
    -- Stay rewards save to the DataStore at most this often; ticks in between show at once
    -- (Profiles:queueReward previews them) and go out with the next save.
    RewardSaveSeconds = 1,
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
    -- Far from Earth, past its mountains and land (SiteSurroundsService, drawn within
    -- 7000): at -3000 a mountain pushed through the cabin's back wall.
    CabinPosition = Vector3.new(-12000, 200, 0),
    -- Player saves (ProfileService). Studio uses its own store so tests never touch live
    -- saves; without Studio API access it falls back to unsaved progress.
    PersistenceEnabled = true,
    DataStoreName = game:GetService("RunService"):IsStudio() and "RocketProfiles_studio" or "RocketProfiles_v1",
    AutosaveSeconds = 30,
    LeaseSeconds = 120,
    RecentRewardLimit = 64,
    -- Global top-ten boards beside spawn (LeaderboardService): one OrderedDataStore per
    -- category, `Store .. "_" .. key`; Studio writes its own.
    Leaderboards = table.freeze({
        Store = game:GetService("RunService"):IsStudio() and "RocketTop_studio" or "RocketTop_v1",
        Size = 10,
        PushSeconds = 120, -- each player's changed values go out this often (and on leaving)
        RefreshSeconds = 120, -- each board reads its top ten this often
        RenderSeconds = 5, -- boards redraw with this server's live values this often
    }),
})
