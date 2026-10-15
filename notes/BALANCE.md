# Balance numbers

Source: `ServerScriptService/ProgressionReport` (reads the live Config, RocketCycles and
Upgrades). Re-run after any tuning:

```lua
print(require(game.ServerScriptService.ProgressionReport)({ players = { 1, 4, 8, 16 }, train = 0.15 }))
```

Model: identical players; trip = 230 studs each way to the ramp foot plus the climb
along the tilted rocket to the fill line, at walk speed, plus pickup, pour and 2 s;
`train` share of time on the best unlocked map gym; cheapest-first upgrades; at each
destination the passive bonus plus two thirds of the stay on its 2× gym.

## 2026-10-15 first pass (after: MaxSpeed 60, destination rewards 3/6/9/12/18 per second, upgrade growth ×2.2)

| Players | Train | Full program | Rocket 1 | Mid rockets (4–12) | Walk @ rocket 4 → 15 | Carry @ 15 | Strength @ 15 | Upgrades @ 15 | Stats from destinations |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 15% | 132 min | 12.4 min | 5.7–10.2 min | 56.6 → 59.7 | 212 | 13,286 | 27 | 59–67% |
| 1 | 30% | 138 min | 11.6 min | 6.1–11.0 min | 57.5 → 59.8 | 242 | 18,157 | 27 | 43–49% |
| 4 | 15% | 56 min | 5.3 min | 2.6–4.0 min | 55.7 → 59.6 | 182 | 10,374 | 20 | 80–86% |
| 8 | 15% | 41 min | 3.7 min | 2.4–3.0 min | 55.5 → 59.6 | 173 | 9,813 | 17 | 86–91% |
| 8 | 30% | 44 min | 4.0 min | 2.3–3.5 min | 56.0 → 59.6 | 181 | 10,906 | 17 | 73–82% |
| 16 | 15% | 32 min | 2.9 min | 1.8–2.2 min | 55.4 → 59.5 | 166 | 9,475 | 14 | 90–95% |

First hour of upgrades (UpgradeCheck): first buy at 23 s; mean gap 195 s with gym
time (20 buys), 301 s without (12 buys).

## Findings for the full overhaul

- **Group size isn't scaled.** Rocket requirements are fixed, so 8 players clear all
  15 rockets in ~40 min (a launch every ~2.5 min, ~1 of which is boarding, launch and
  the stay). Decided 2026-10-15: leave as is; the overhaul will lengthen the stages.
  The sim tried +60% material per extra player: ~7 min rockets and a ~2 h program
  at any lobby size.
- **Walk speed saturates early.** With half-point 120, walk is ~94% of max by
  rocket 4 whatever MaxSpeed is; speed training stops being visible after the first
  half hour. (Kept on purpose 2026-10-15; MaxSpeed raised 44 → 60 instead.) A half
  point of ~800 spreads it across the whole program.
- **Destinations dominate stats in groups** (80–95%): launches come fast and each
  stay pays more than minutes of map-gym training (map gyms give 2–12 per second).
  More training time or slower launches lower the share.
- **Capacity grows steadily** (sqrt strength + Carry Capacity upgrade): 38 → ~210 solo.
- **Coin upgrades run out of reach late:** at ×2.2 growth the 8th+ levels cost tens
  of thousands of coins; solo players buy ~27 in a full program.
