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

## 2026-10-14: Phase 0 client structure

- One LocalScript, `StarterPlayerScripts/Main.client.luau`, starts every
  `Controllers/*Controller` (`X.start()`, each in its own thread) and then
  `State.start()`. New client features are new controllers, not new LocalScripts.
- `Controllers/State` owns the only `StateUpdated` and `Feedback` connections and
  fires `RequestState`. Controllers use `State.subscribe(fn(state, previous))`,
  `State.get()`, `State.onFeedback(fn)` and `State.remote(name)`. Late subscribers
  get the current snapshot replayed, so a controller that yields on a remote can't
  miss the first state. Each listener runs in its own thread, so one error doesn't
  stop the others.
- Controllers find world anchors by tag (`GymSign`, `TrainingStation`) instead of
  scanning `RocketWorld` by name.
- `UI/` components take one props table: Capitalized keys are Instance properties
  applied as-is, lowercase keys are component options (`stroke`, `maxSize`,
  `onActivated`, …). `UI.Create.screen(name)` shares one ScreenGui per name, so
  Hud, Training and Cargo all draw into `RocketHUD` as before.
- `Theme` holds today's HUD colours plus the reference style (FredokaOne display
  font, dark stroke). `Button` is themed by default; `themed = false` keeps the
  plain Roblox button the current Leave-station and Clear-cargo buttons use, until
  Phase 2 restyles them.
- Animation goes through `UI.Tween` (`play`, `bounce` via a UIScale child so
  layout never moves, `countUp` with cancel-on-retarget, `flyTo` in ScreenGui space).

## 2026-10-14: Reference-style HUD

- The HUD follows the eight *Build a Pyramid* frames: left stat stack, top-centre
  objective line, bottom-centre progress pill, round action buttons bottom right,
  world-space "+N" popups and level-up text. No dark panels behind HUD text:
  white text with a heavy dark UIStroke (FredokaOne) carries it.
- Icons are emoji in `Theme.icon` until Phase 5 art; swapping a value to
  "rbxassetid://…" makes StatRow use an ImageLabel.
- Stat feedback is derived on the client by diffing `state.profile` against the
  previous snapshot, so training, Meadow rewards and any future source get the same
  popups without new remotes. "Level Up" thresholds: capacity +1 (strength) and
  each whole walk-speed point (speed).
- Proximity prompts use Custom style, set locally by `PromptController`; Roblox
  still handles key and gamepad input, and the card drives InputHoldBegin/End for
  touch. Material-hold logic in `CargoController` is unchanged.
- Each ScreenGui from `UI.Create.screen` carries a UIScale from a 720 px design
  height (clamped 0.6–1.6); `Tween.flyTo` divides that scale back out.
- Shop, Pets, boost badges, purchase chips and coins stay out until they work
  (monetization decision).

## 2026-10-14: Coins (Phase 1)

- Coins are the soft currency for Phase 4 upgrades. The server credits them, one
  per accepted delivery unit (`Config.CoinsPerUnit`), through `Profiles.credit`.
  The amount always comes from `Rocket:deliver`'s return, so coins can never
  exceed units carried and then accepted.
- Profile schema v2 adds `coins`; v1 profiles migrate to 0 on load. Persistence
  stays off.
- The client gets no coin remote: like other stat juice, the HUD diffs
  `state.profile.coins` against the previous snapshot and plays the burst. The row
  shows the server total once the first coin lands, so batched updates can't drift.

## 2026-10-14: Stat curve and delivery feedback (Phase 1)

- Strength and speed are uncapped point totals. Stats come from soft curves in
  `StatsService`: walk speed is hyperbolic toward `MaxSpeed` (base 24, half at 120
  points), so the anti-teleport limit stays valid. Capacity is square-root
  (10 + 1.5√s), so the first training seconds visibly add capacity and later gains
  slow without a hard wall. `MaxCapacity` stays as a safety cap.
- Delivery juice is client-only and keyed on the shared totals, so every player
  sees everyone's deliveries land. Effects are local clones under the camera;
  server parts are never edited from the client.
