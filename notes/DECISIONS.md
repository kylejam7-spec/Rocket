# Decisions

## 2026-10-13 — First playable defaults

- Fixed build: 6 Metal per server. Fuel removed by the gameplay decision below.
- One material type per cargo stack; capacity 1 + floor(effective strength / 5),
  capped at 5. Pickups cannot exceed remaining unreserved need; deliveries
  credit actual accepted pieces.
- Boarding lasts 20 seconds. Players must remain on the pad until lock;
  the server recomputes eligibility at departure. Pickup/delivery stop at boarding.
- Meadow grants +1 strength bonus, +1 speed bonus and one completion, only after
  the profile transaction succeeds (or explicitly temporary memory-mode grant).
- WalkSpeed = min(32, 16 + effective speed * 0.3). Training/bonus caps are 50.
- Advanced gym needs one confirmed launch and grants two strength levels.
- Generated anchored primitives are source-owned; no binary art edits.
- Persistence defaults off; test store `RocketProfiles_v1_test`, schema 1,
  serialized UpdateAsync, 120-second session lease, 64 recent reward IDs.
- Pending rewards survive disconnect within the live server. Durable entitlement
  recovery across server shutdown is a public-release blocker, not claimed solved.
- Empty upstream has no main/PR base; keep the first implementation on a feature
  branch and agree on initial main before opening the review PR.

## 2026-10-13 — Local Studio sync

- Rocket uses port 34873; CityGang already uses 34872. Pin `servePort` in the
  project so both can run without disconnecting the other project.
- Use the existing Build a Rocket experience in Studio. In Team Create, hand
  off the Rojo session by disconnecting the current owner before connecting
  another developer. Do not clear another developer's active session lock.

## 2026-10-13 — One material and no excess cargo

- User requested one material type for simplicity: keep Metal and remove Fuel
  from the map, requirement and HUD. Keep the existing six-Metal requirement.
- Pickups count both delivered material and every player's carried material
  against the fixed requirement. This prevents extra pieces from stranding cargo,
  including when two players try to take the last needed piece.
- Disconnecting releases carried reservations. Inventory is still per-cycle
  server memory; no persistence schema changes.
