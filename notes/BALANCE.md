# Balance numbers

Source: `ServerScriptService/ProgressionReport` (reads the live Config, Shared.Missions and
Upgrades; simulates a seeded mission wheel). Re-run after any tuning:

```lua
print(require(game.ServerScriptService.ProgressionReport)({ players = { 1, 4, 8, 16 }, launches = 30 }))
```

Model: identical players who stay for the whole run; trip = 230 studs each way to the ramp
foot plus the climb along the tilted rocket to the fill line, at walk speed, plus pickup,
place ticks and 2 s; `train` (default 15%) of time on the best unlocked Gym District tier;
cheapest-first upgrades; at each destination the passive bonus plus two thirds of the stay
on its 2× gym. Fixed overhead per mission (boarding + launch + stay + reset) is ~1.1 min
(Moon) to ~1.6 min (Black Hole).

## 2026-10-16 slower training, 2-minute stays, planets 3/s by rarity (current)

User: gym leveling was too fast and should be a boost, not game-breaking. Planet stays
should last about 2 minutes, with the Moon around +3/s, rising steadily by rarity.
(An intermediate 5/s step was never merged.)

- Gym District: TrainingBaseGain 2 → **1**, tiers 2/4/6/10/15/20/30× → **2/3/4/6/8/10/12×**.
  Free gym 1/s (level 1 in 10 s, level 10 in ~4 min); top gym 12/s (37.5 s per capped
  level, was 7.5 s).
- Stays: **120 s** everywhere (were 30 s, Black Hole 45 s).
- Destinations, each stat per second: **3 / 6 / 9 / 12 / 15** (Moon → Black Hole), was
  10 / 20 / 30 / 50 / 100. Standing through a stay gives 360 / 720 / 1,080 / 1,440 / 1,800;
  each destination's own bench/treadmill gives 6–30/s, the best training anywhere.

Report, 30 launches (before → after; "before" is the merged levels pass):

| Players | First Moon | Late Moon | 30 launches | Level @ 30 | Carry @ 30 | Stats from destinations |
|---|---|---|---|---|---|---|
| 1 | 296 → 349 min | 56 → 75 min (#10) | 2,540 → 3,288 min | 373 → 218 | 1,000 → 664 | 19% → 39% |
| 4 | 106 → 129 min | 23 → 29 min (#10) | 991 → 1,217 min | 197 → 138 | 601 → 424 | 38% → 64% |
| 8 | — → 81 min | — → 18 min (#10) | — → 727 min | — → 119 | — → 367 | — → 76% |
| 16 | 41 → 52 min | 9 → 11 min (#10) | 368 → 440 min | 124 → 108 | 382 → 334 | 63% → 85% |

About 45 of the added minutes over 30 launches are the longer stays (1.5 min × 30); the
rest is slower carry growth. The first Moon is ~22% longer because the gym is slower.

## 2026-10-16 strength and speed levels

Points (training + destination rewards) now turn into **levels** (`Shared/StatLevels`).
Level 1 costs 10 points, each level after ×1.2 (rounded to 5), capped at **450** from
level 22 (~2,700 points in); every later level costs 450. Free gym (2/s): level 1 in
5 s, level 10 in ~2 min, level 20 in ~15 min.

| Level | 1 | 2 | 3 | 5 | 8 | 10 | 12 | 15 | 18 | 20 | 22+ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 10 | 10 | 15 | 20 | 35 | 50 | 75 | 130 | 220 | 320 | 450 |

- Strength: carry = 10 + **3 per level** (cap 1,000, level 330).
- Speed: walk = 24 + 46 · L / (L + 8), so MaxSpeed is now **70** (was 60): +5 at level 1,
  47 at level 8, 59 at level 30, 66 at level 100. The first speed level is worth about
  two thirds of the first strength level in delivery rate. After that the gap grows,
  because walk speed has a ceiling and carry does not (see the open question below).
- Gym District multipliers 2/5/10/25/50/75/100 → **2/4/6/10/15/20/30** (top gym 60/s,
  7.5 s per capped level, which was 2.25 s at the old 200/s).
- Destination reward 3 → **10 per second** per stat × destination reward.

Report (same seed as below, 30 launches):

| Players | First Moon | Level after first Moon | Late Moon | Level @ 30 | Carry @ 30 | Walk @ 30 | Stats from destinations | 30 launches |
|---|---|---|---|---|---|---|---|---|
| 1 | 296 min (was 287) | 23 | 29 min | 373 | 1,000 | 69 | 16–20% (was 3%) | 42 h |
| 4 | 106 min (was 112) | 18 | 12 min | 197 | 601 | 68 | 35–39% (was 9%) | 16.5 h |
| 16 | 41 min (was 45) | 15 | 5 min | 124 | 382 | 67 | 58–66% (was 21%) | 6.1 h |

Mission pacing stays close to the agreed build-size pass. Planets now give a real share
of stats.

**Known gap, kept for now (user, 2026-10-16):** walk speed caps out and carry doesn't,
so past the first few levels a strength level is worth more than a speed level (3× by
level 10, 10× by level 30, in the trip model). If it's revisited, the suggested fix is
for speed to also make pickup and place faster.

## 2026-10-16 upgrades: 10 levels, ×3 coins, Robux per level

Three tracks (Bulk Pickup, Bulk Place, Placement Range), 10 levels each, set by the user.
Pickup and place move 1 + level units per 0.05 s tick; reach is 12 studs +10% per level
(level 10: 11 units per tick, 2× reach). Coins: 50, then ×3 per level (3 significant
figures). Each level is also a Robux Game Pass (owning the level-N pass keeps the track at
level N or higher).

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Coins | 50 | 150 | 450 | 1,350 | 4,050 | 12.2K | 36.5K | 109K | 328K | 984K |
| R$ | 53 | 63 | 73 | 83 | 93 | 103 | 113 | 123 | 133 | 143 |

One track 0 → 10 on Robux: 980 R$; all three: 2,940 R$. A new player (~27 coins/min)
gets level 1 after ~2 min; levels 2 and 3 stay inside UpgradeCheck's 3–7 and 7–18 min
windows. Report, 30 launches, total levels across the three tracks (max 30):

| Players | After the first Moon | After 10 launches | After 30 launches (per track) | First Moon |
|---|---|---|---|---|
| 1 | 18 | 25 | 28 (10/9/9) | 287 min |
| 4 | 15 | 21 | 24 (8/8/8) | 112 min |
| 8 | 12 | 19 | 23 (8/8/7) | 70 min |
| 16 | 10 | 18 | 21 (7/7/7) | 45 min |

Coins reach levels 7–9; level 10 (984K) is in practice for Robux. 

## History: 2026-10-16 coin upgrade prices, 100 levels (replaced the same day)

Three tracks (Bulk Pickup, Bulk Place, Placement Range), 100 levels each, one curve set by
the user: level 1 costs 50, then ×2.5 per level to 25, ×1.5 per level to 50, ×1.1 per
level to 100 (3 significant figures; under 1,000 rounded to 5). Pickup and place move
1 + level units per 0.05 s tick; reach is 12 studs +10% per level.

| Level | 1 | 2 | 3 | 4 | 5 | 8 | 10 | 12 | 15 | 20 | 25 | 30 | 50 | 75 | 100 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Coins | 50 | 125 | 315 | 780 | 1,950 | 30.5K | 191K | 1.19M | 18.6M | 1.82B | 178B | 1.35T | 4.49Qa | 48.6Qa | 527Qa |

A brand-new player (carry 10, ~22 s trips) earns ~27 coins/min: level 1 after ~2 min,
level 2 ~5 min later, level 3 ~12 min after that (UpgradeCheck holds these). Levels per
track reached on coins in the report's 30 launches (Pickup/Place/Range):

| Players | After the first Moon | After 10 launches | After 30 launches | First Moon |
|---|---|---|---|---|
| 1 | 7/7/7 | 10/10/9 | 11/11/11 | 285 min |
| 4 | 6/5/5 | 9/8/8 | 10/10/9 | 111 min |
| 8 | 5/5/4 | 8/7/7 | 9/9/9 | 70 min |
| 16 | 4/4/4 | 7/7/6 | 8/8/8 | 44 min |

Coins stop at about level 10; everything above is for Robux (separate session). With fewer
upgrades, missions run a little longer than in the build-size table below.

Previous curve (merged f6f2481, same day): 10 / 30 / 120 then ×1.2; coins reached 28–43.

## 2026-10-16 mission build sizes

Agreed with the user: totals 73k / 98k / 137k / 182k / 215k units (Moon → Black Hole),
Metal:Fuel at the old ratios (48.5k/24.5k, 64k/34k, 85k/52k, 108k/74k, 122.5k/92.5k). No
lobby-size scaling (the whole server has to cooperate), missions may shrink as players get
stronger, and walk curve, destination rewards, Gym District, upgrade prices and rank
thresholds are unchanged (strength and walk get their own pass later).

Default seed, 30 launches (12 Moon, 10 Mars, 5 Europa, 3 Saturn, no Black Hole).
Minutes per mission, mean of launches 1–10 → 21–30:

| Players | First Moon (new server) | Moon | Mars | Europa | Saturn (12–30) | 30 launches | Carry @ 30 | Upgrades @ 30 | Stats from destinations |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 225 min | 91 → 29 | 107 → 39 | 176 → 61 | 69–126 | 36 h | 853 | 38 (all) | 3% |
| 4 | 91 min | 35 → 11 | 40 → 15 | 66 → 22 | 26–46 | 13.7 h | 550 | 38 (all) | 9% |
| 8 | 59 min | 22 → 7 | 24 → 9 | 41 → 14 | 16–28 | 8.5 h | 446 | 36 | 14% |
| 16 | 39 min | 14 → 5 | 15 → 6 | 25 → 9 | 10–18 | 5.4 h | 367 | 34 | 21% |

Black Hole (fixed 30-launch sequence at long-run odds, same sim): ~31 min late with 4
players, ~12 min with 16, ~83 min solo.

First hour of upgrades (UpgradeCheck, unchanged): first buy at 23 s; mean gap 195 s with
gym time, 301 s without.

## Findings

- **The opening Moon is the longest mission.** Every server starts on the Moon with
  everyone at carry 10: ~1.5 h for 4 players, ~3.7 h solo. Kept on purpose (2026-10-16).
- **Missions shrink 3× over 30 launches** as carry grows (√strength, Gym District tiers
  up to 100/s). Kept on purpose: getting stronger is the reward.
- **Walk speed saturates early** (half-point 120: ~59 of 60 by launch 5). Deferred to the
  strength/walk pass.
- **Gym District now dominates stats** (destinations give 3–21%): longer missions mean much
  more gym time between stays. Deferred to the strength/walk pass.
- **Coin upgrades all maxed out** (38 levels) within the first few missions solo. Replaced
  by the 100-level curve above.
- **Ranks:** COMMANDER (20k deliveries, 8 launches) is gated by launches only now. Kept.

## History

- 2026-10-15 first pass (linear 15-rocket program, since replaced by the wheel): MaxSpeed
  44 → 60, destination rewards softened, upgrades ×2.2 growth (Carry Capacity base 120).
  8 players cleared all 15 rockets in ~41 min; that drove this pass.
- 2026-10-16 before this pass (wheel, builds 600–6,100 units): 4 players took 2.5 → 1.5 min
  per Moon and 30 launches in 71 min; groups of 8+ spent most of each mission in the fixed
  ~1.5 min overhead.
