# Latest session — 2026-10-13

- Branch: `feat/first-playable`; upstream was empty with no main or PR base.
  Initial implementation is isolated for review; no PR opened.
- Built: Rojo mapping/tool pin, source-generated test world, shared fixed build,
  cargo/capped atomic delivery, training, timed boarding/passenger lock,
  Meadow/reward/reset, completion gym gate, HUD and server leaderboard.
- Persistence: opt-in test store, validated schema, exclusive session lease,
  serialized saves, atomic reward-ID de-duplication, retries and honest status.
  Default Studio mode is temporary; no permanent progress claim.
- Verification: Luau compilation and focused real-code delivery/profile checks
  pass; Rojo builds `build/Rocket.rbxlx`. Mock tests cover outage/ambiguous commit,
  concurrent changes, replay, disconnect/rejoin and schema/session failures.
- Not verified: Studio two-client behavior/UI, actual published DataStore calls,
  real rejoin and shutdown recovery. Studio connection reported no place open.
- Public-release blocker: pending rewards in memory can be lost on server death;
  implement and fault-test durable pending entitlements before release.
- Next task: open generated place and run README two-player scenario; second
  developer independently reproduces it. Agree initial main/PR base for review.
