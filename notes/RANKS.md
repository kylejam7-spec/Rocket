# Rank titles

Current code as of origin/master 0e64806 (#45). No open branch changes ranks.

## The ladder

`Config.Ranks` (`src/ReplicatedStorage/Shared/Config.luau:126-133`). You hold the highest rank
whose deliveries **and** launches you both have (`Shared/Upgrades.luau:67-74`).

| # | Title | Lifetime deliveries | Completed launches | Rough time (estimate) |
|---|---|---|---|---|
| 1 | APPRENTICE | 0 | 0 | on join |
| 2 | MECHANIC | 250 | 0 | a few minutes of hauling |
| 3 | ENGINEER | 1,500 | 1 | first launch: ~40 min (16 players) to ~5 h (solo) |
| 4 | FLIGHT DIRECTOR | 6,000 | 3 | ~1 h (16p) to ~8 h (solo) |
| 5 | COMMANDER | 20,000 | 8 | ~2 h (16p) to ~15+ h (solo) |

- Perks: none. A rank is only a title. Every rank looks the same: gold (255, 204, 40)
  FredokaOne text, with no icon and no per-rank color.
- The launch counts (1/3/8) match the Gym District unlocks for 2x/5x/10x
  (`Config.luau:142-144`), so each rank-up happens alongside a new gym, but the gym unlock
  doesn't depend on the rank.
- In practice, launches decide the rank. A Moon rocket takes 73,000 units, so anyone
  who helps fill one passes 20,000 deliveries long before 8 launches. Deliveries only
  hold back a player who rides along without hauling.

Time estimates come from `notes/BALANCE.md` (ProgressionReport, 2026-10-16: first Moon
42–297 min, later Moons ~11–75 min, by player count). Gyms have been much faster since
#43 and #45, so real times today are likely shorter. Re-run ProgressionReport to get real
numbers.

## Tracking and saving

- `profile.lifetimeDeliveries` goes up by +1 per accepted unit in `Profiles.credit`
  (`Services/ProfileService.luau:155-163`). 2x Coins doubles the coins but not the deliveries.
- `profile.completedLaunches` goes up by +1 per launch, only for **passengers** who are
  aboard at the destination. It's counted once per launch id on the first reward tick
  (`ProfileService.luau:278-283`, queued from `LaunchService.luau:180-182`).
- Both fields are saved in the DataStore profile (schema 7, `ProfileService.luau:11`) and
  validated as non-negative integers (`ProfileService.luau:82-85`). The rank itself is never
  stored: it's recomputed from these two fields each time.
- It never goes down. Neither counter decreases, apart from the Studio-only debug hook
  (`DebugService.luau:84`).

## Where it shows

- **Overhead billboard** `RankTag` on the Head, made on the server and visible to everyone
  within 90 studs (`Services/UpgradeService.luau:55-84`). The client scales it with the
  screen (`Controllers/HudController.luau:302-306`). It refreshes on every
  `Stats.update`: on join, on respawn, after deliveries, purchases and profile changes
  (`Main.server.luau:25,43,99`, `CargoService.luau:147`).
- **Player attribute** `Rank` (`UpgradeService.luau:58`), also sent to the client in the
  cycle profile payload as `rank` (`CycleService.luau:54`). No client code reads it yet.
- **Leaderboard** (`leaderstats`) shows CompletedLaunches and LifetimeDeliveries, but not
  the rank (`StatsService.luau:23-31`).
- **HUD** shows the launch count with "Delivered: N" beneath it (`HudController.luau:249`),
  but not the rank.
- There's no next-rank display, progress bar, rank list or rank-up celebration. The
  index that `Upgrades.rank` returns goes unused.

## Checks

`UpgradeCheck.luau:60-64` asserts APPRENTICE at 0/0, MECHANIC at 250/0, MECHANIC at 1e6/0
(launches gate the higher ranks) and COMMANDER at 1e6/100.
