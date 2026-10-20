# Rank titles

Ranks count **completed rocket launches only** (user, 2026-10-20). Lifetime deliveries no
longer count.

## The ladder

`Config.Ranks` (`src/ReplicatedStorage/Shared/Config.luau:126-139`). You hold the highest
rank whose launch count you have (`Shared/Upgrades.luau:67-74`).

| # | Title | Completed launches |
|---|---|---|
| 1 | INTERN | 0 |
| 2 | ROCKET TRAINEE | 5 |
| 3 | MECHANIC | 10 |
| 4 | ROCKET ENGINEER | 20 |
| 5 | FLIGHT DIRECTOR | 30 |
| 6 | LAUNCH SPECIALIST | 40 |
| 7 | MISSION COMMANDER | 50 |
| 8 | LAUNCH DIRECTOR | 65 |
| 9 | NASA DIRECTOR | 80 |
| 10 | NASA CEO | 100 |

- Perks: none. A rank is only a title. Every rank looks the same: gold (255, 204, 40)
  FredokaOne text, with no icon and no per-rank color.
- Rough pace (estimate from `notes/BALANCE.md`, 2026-10-16, before the faster gyms of
  #43 and #45): after the first Moon, a launch takes ~11 min (16 players) to ~30 min
  (4 players). That puts NASA CEO roughly 20 to 50 hours of play in. Re-run
  ProgressionReport to get current numbers.

## Tracking and saving

- `profile.completedLaunches` goes up by +1 per launch, only for **passengers** who are
  aboard at the destination. It's counted once per launch id on the first reward tick
  (`Services/ProfileService.luau:278-283`, queued from `LaunchService.luau:180-182`).
- The field is saved in the DataStore profile (schema 7, `ProfileService.luau:11`) and
  validated as a non-negative integer (`ProfileService.luau:82-85`). The rank itself is never
  stored: it's recomputed from the launch count each time.
- It never goes down, apart from the Studio-only debug hook
  (`Invoke("launches", n)`, `DebugService.luau:84`).

## Where it shows

- **Overhead nameplate** `RankTag` on the Head (280x54, `Services/UpgradeService.luau`
  `showRank`). The top row is a dark pill with "🚀 N" (lifetime completed launches, the
  saved counter) next to the gold rank title. Below that is the player's DisplayName in
  white, just above the head. Roblox's own name label is turned off
  (`Humanoid.DisplayDistanceType = None`). With `SizeOffset (0, 0.5)` and a 1.6 stud
  offset, the bottom edge stays about a stud above the head at any distance. It's made
  on the server and visible to everyone within 90 studs. The client scales it
  with the screen (`Controllers/HudController.luau:302-306`). It refreshes on every
  `Stats.update`: on join, on respawn, after deliveries, purchases and profile changes.
- **Player attribute** `Rank`, also sent to the client as `profile.rank`
  (`CycleService.luau:54`). No client code reads it yet.
- **Leaderboard** shows CompletedLaunches and LifetimeDeliveries, but not the rank.
  The HUD shows the launch count, but not the rank.
- There's no next-rank display, progress bar, rank list or rank-up celebration.

## Checks

`UpgradeCheck.luau:60-68` asserts that the ladder rises, and checks INTERN at 0 and 4,
ROCKET TRAINEE at 5, MISSION COMMANDER at 64, and NASA CEO at 100 and 1e6.
