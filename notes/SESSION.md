# Latest session — 2026-10-13: material pickup fix

- Branch: `feat/first-playable`; no main/PR base yet, no PR opened.
  First playable implementation: `56d8cbc`; setup details in README.
- Fixed excess pickup: delivered plus all carried pieces reserve the fixed
  requirement. Capacity cannot grant more than the remaining unreserved need;
  disconnect releases carried reservations. Delivery finishes without leftovers.
- User requested one material: keep 6 Metal; remove Fuel pickup, requirement,
  HUD text and onboarding. No profile schema changes.
- Synced through Rojo 7.7.1 at `127.0.0.1:34873` to Build a Rocket.
- Verification: all Luau files compile; delivery and profile checks pass.
  New assertions cover 3/4 with capacity 3, competing final pickups, disconnect
  release and empty cargo at completion. Same regression passes in Studio.
  Play smoke check confirms one Metal source, no Fuel, HUD Metal 0/6, no console
  output errors. Studio is left in Edit mode ready to play.
- Updated README, defaults and notes. Two-client live interactions, real saves,
  rejoin and shutdown recovery remain unverified. Persistence remains off.
- Public-release blocker: pending rewards in memory can be lost on server death;
  implement and fault-test durable pending entitlements before release.
- Next task: run README's two-player Studio scenario in the connected experience.
  Second developer independently reproduces it; agree initial main/PR base.
