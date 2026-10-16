# Balance numbers

Source: `ServerScriptService/ProgressionReport` (reads the live Config, Shared.Missions and
Upgrades; simulates a seeded mission wheel). Re-run after any tuning:

```lua
print(require(game.ServerScriptService.ProgressionReport)({ players = { 1, 4, 8, 16 }, launches = 30 }))
```

Model: identical players who stay for the whole run; trip = 230 studs each way to the ramp
foot plus the climb along the tilted rocket to the fill line, at walk speed, plus pickup,
pour and 2 s; `train` (default 15%) of time on the best unlocked Gym District tier;
cheapest-first upgrades; at each destination the passive bonus plus two thirds of the stay
on its 2× gym. Fixed overhead per mission (boarding + launch + stay + reset) is ~1.1 min
(Moon) to ~1.6 min (Black Hole).

## 2026-10-16 mission build sizes (current)

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
- **Coin upgrades all max out** (38 levels) within the first few missions solo; coins per
  hour don't depend on build size, so the first hour is unchanged. Kept for now.
- **Ranks:** COMMANDER (20k deliveries, 8 launches) is gated by launches only now. Kept.

## History

- 2026-10-15 first pass (linear 15-rocket program, since replaced by the wheel): MaxSpeed
  44 → 60, destination rewards softened, upgrades ×2.2 growth (Carry Capacity base 120).
  8 players cleared all 15 rockets in ~41 min; that drove this pass.
- 2026-10-16 before this pass (wheel, builds 600–6,100 units): 4 players took 2.5 → 1.5 min
  per Moon and 30 launches in 71 min; groups of 8+ spent most of each mission in the fixed
  ~1.5 min overhead.
