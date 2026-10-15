# Latest session: 2026-10-14, roadmap and Phase 0 on master

- Branch: `claude/phase0-on-master` (from `master` @ 26ffae5). Rojo for this branch
  was served from the worktree on 127.0.0.1:34873. To go back, run `rojo serve` from
  the main checkout again.
- `ROADMAP.md` is rewritten against master, and decisions are recorded in `DECISIONS.md`.
- Phase 0 server half: Main went from 697 to 63 lines, with nine services (World,
  Remote, Movement, Interaction, Stats, Cycle, Cargo, Launch, Debug), tagged anchors
  and a `RunChecks` runner.
- Studio verification (Build a Rocket place, Rojo-synced):
  - all three checks pass
  - world fingerprint matches master: 116 children, 97 prompts, 6 remotes; the
    one-part difference is build progress (a 1% fill reproduces it)
  - real-client play: starter bench +2/s and exit; Scrap Pit hold pickup to
    capacity 10 with the scrap ball; discard; placing at the ring (Metal 0→10,
    contribution and lifetime updated)
  - debug fill to Fueling and then Boarding: hull riders moved to the pad, passenger
    locked, launch to Meadow, 30 reward ticks, reset to Cycle 2 (500 Metal, variant 2),
    GYM 1 sign unlocked
  - no game warnings or errors on the server or client
- Not covered: two-client play, persistence (still off).
- Next: the Phase 0 client half (`Controllers/` + `UI/` library), then Phase 1 (coins
  and feedback).
