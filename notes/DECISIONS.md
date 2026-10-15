# Decisions

## 2026-10-14: Roadmap toward Build a Pyramid parity

- The plan lives in `ROADMAP.md`; *Build a Pyramid* is the reference for feel and UI.
  `master` (the restored project) is the real codebase; `feat/first-playable`
  is an older, unrelated history and is not built on.
- Builds stay per-server and grow through `Shared/RocketCycles`, like the
  reference's growing pyramids.
- Monetization is built last (Phase 7), after a durable entitlement journal.
  HUD purchase slots stay hidden until they work.
- UI uses plain Luau component modules plus an animation helper, with no framework.
- Imported meshes are allowed: uploaded to Roblox and referenced by ID from a
  source-owned manifest, with every asset's license logged in `assets/LICENSES.md`
  (CC0 preferred).

## 2026-10-14: Phase 0 server structure

- `Main.server.luau` only wires services. Each `Services/*Service` is built with
  `X.new(ctx)`, matching `TrainingService`. Services reach each other through `ctx` at
  call time (`ctx.Cycle.rocket`, `ctx.Launch.beginBoarding()`), so circular calls
  between Cargo, Cycle and Launch never become require cycles. Construction order in
  `Main` still matters: World before Cycle (it loads the rocket), Cycle before Cargo
  (it refreshes prompts).
- `ctx.Cycle.rocket` is replaced every cycle via `Cycle.replace`. Always read it
  through `ctx.Cycle` and never cache it.
- One 0.2 s server tick lives in `CycleService.start`, in the original order:
  training tick, then movement sample and boarding check per player, then the
  batched broadcasts.
- Tags on generated anchors: SpawnPoint, MaterialSource (attribute Material),
  BuildFrontier, BoardingZone, TrainingStation, GymSign, PlanetDestination
  (attribute PlanetId). New code finds anchors via `WorldService.anchors(tag)` or
  CollectionService, so imported art can replace the parts later.
- `RunChecks` runs every `Services/*Check` module:
  `print(require(game.ServerScriptService.RunChecks)())`.
- The `updateFrontier` fix that was uncommitted in the main checkout (set the place
  points after moving the ring) is included in `CargoService`.
