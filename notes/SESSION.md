# Latest session: 2026-10-14, Phase 0 client half

- Branch: `claude/brave-turing-b9188d`, on top of `claude/phase0-on-master` @ 4f4e4c7.
  Rojo for this branch was served from its worktree on 127.0.0.1:34873. To go back,
  run `rojo serve` from the other checkout again and reconnect the plugin.
- Client is now one `Main.client.luau` entry, plus `Controllers/` (State, Camera,
  LaunchEffects, Hud, Progress, GymSign, Training, Cargo) and a `UI/` library
  (Theme, Create, Tween, StrokedText, Panel, Pill, Button, Popup, StatRow). The old
  `Camera`, `RocketProgress` and `LaunchEffects` LocalScripts are gone. The HUD looks
  the same as before.
- Studio verification (Build a Rocket place, Rojo-synced):
  - `RunChecks`: all three checks pass
  - real-client play: left panel and top-right panel text and layout unchanged
    (screenshot); starter bench mount with E (Leave-station shown, station prompts
    hidden, strength +2/s), exit with E; Scrap Pit hold pickup to capacity 11;
    Clear-cargo button click; re-pickup and hold-E placing from the launch ramp
    (Metal 0→9, contribution and lifetime updated, progress bar filled)
  - RocketDebug fill: Fueling banner and feedback; first boarding missed (player
    off the pad) so "You missed this launch" path; second run on the pad: ABOARD,
    countdown, cinematic camera, LIFTOFF, 30 Meadow ticks, reset to Cycle 2
    (500/250), GYM 1 sign UNLOCKED, GYM 2 `LOCKED • 1/3 launches`
  - UI library smoke test on the client (StatRow count-up and badge, themed Button,
    Pill label, Panel, Popup, flyTo, `Theme.number`)
  - LogService: no game warnings or errors on client or server (only Roblox
    CorePackages UIBlox warnings)
- Studio MCP tip: `character_navigation` stalls on this map; walking with
  `Humanoid:MoveTo` from a Client `execute_luau` works. Client `PivotTo` teleports
  are snapped back by the server's movement check. Place prompts are reachable
  from the ramp edge at about (17.3, 23, -107).
- Not covered: two-client play, touch/mobile layout, persistence (still off).
- Next: Phase 1 (coins and feedback) using `UI/Popup`, `Tween.flyTo` and `StatRow`.
