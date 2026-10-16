# Decisions

## 2026-10-16: Strength and speed are levels

- Profiles still store point totals (`strengthLevel`/`speedLevel` are points despite the
  names; renaming them would need a schema migration). `Shared/StatLevels` turns points
  into levels on both server and client, so no schema change.
- Each level costs at most `Config.StatLevels.max` (user: 400–500 per level).
- The tutorial doesn't dim the screen (user request).

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
  height (clamped 0.6–1.6; Phase 2 made it 0.45–1.6 of the inset height); `Tween.flyTo`
  divides that scale back out.
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

## 2026-10-14: Wide ramps and ramp place reach

- Ramps hug the rocket: the inner edge sits just outside the widest segment, so
  nothing being built is hidden under a ramp, and ramps ride over the low mount slab
  (lifted where needed so there is no ledge). Minimum width 14 per ramp keeps room for
  a full 50-player server climbing and standing along the fill line.
- Placement keeps the hold-anywhere and sliding-ring-prompt model from
  `claude/place-pickup-anywhere`. Reach adds one rule on top: standing on a ramp
  within `FrontierReach` of the fill line along the rocket counts, because where the
  rocket is narrow the ramps can be far outside the ring. Server and client share the
  rule through the ring's ramp attributes.

## 2026-10-15: Phase 2 HUD

- Feedback is toasts, not a takeover of the objective line: the "what to do now"
  line must always be readable.
- All round action buttons share one bottom-right row (`ActionController.cluster()`),
  so new actions slot in by LayoutOrder instead of fighting for corners. Touch gets a
  GRAB/PLACE hold button and our own JUMP; Roblox's jump button is hidden there.
- Settings are client-side and session-only until persistence is on. Audio volume
  goes through "Music"/"SFX" SoundGroups so future sounds just join a group.
- Reduced effects removes motion (shake, flashes, flying coins) but keeps
  information (numbers, popups, banners).

- On touch the action cluster is a fixed 2×2 grid with a minimum on-screen size
  (70 px), not the desktop row scaled down: thumbs need big targets, and a button
  must not move when another (DROP, LEAVE) appears.

## 2026-10-15: Tutorial (Phase 3)

- The server owns the step and moves it only on what it saw (pickup, reach, accepted
  delivery, starter-gym tick). The client renders and can only skip, which grants
  nothing, so no tutorial step can be used to farm rewards.
- Steps are stored by name, not index, so Phase 4 can insert "Upgrade" without
  shifting saved progress.
- Existing profiles with deliveries skip the tutorial on migration; new ones get it.
- The upgrade step is deferred to Phase 4 rather than faked with a placeholder shop.

## 2026-10-15: Upgrades and ranks (Phase 4)

- Four coin tracks: the reference's three plus Carry Capacity, the one that visibly
  raises income. Training Power is left out (training already scales well).
- Prices double per level from small bases (10/90/120/150). A deterministic
  first-hour sim in UpgradeCheck holds the targets, so retuning a price or a trip
  time fails a check instead of drifting.
- Purchases are idempotent by client request ID kept in the profile, so a retried
  click or a resent remote never charges twice; the profile saves right after a buy.
- The hut prompt only opens the panel; buying doesn't need you at the hut (it's a
  coin spend with nothing to exploit).
- Ranks are server-set billboards from lifetime deliveries and launches; higher ranks
  need launches so deliveries alone can't reach Commander.

## 2026-10-15: Rocket cabin and destinations

- Boarding means getting inside: the hatch teleports you into a shared cabin interior
  (an isolated room, not geometry inside each rocket model), so it works for every
  design and the launch stays client-animated.
- One destination per rocket design, not per cycle: Space Station, Moon, Mars, Saturn,
  Pluto. Rewards stay passive and per-second (RewardMultiplier still scales them).
- Destinations are far-off walled areas 10,000 studs apart, so giant backdrop planets
  never show in another destination's sky. Gravity is set on the passenger's client.
- The reward size lives on the destination (Config.Destinations reward 1/2/4/6/10),
  not the cycle; RocketCycles keeps a multiplier only for the final mission. Each
  destination's gym pays double its passive rate and works only during its stay.
- Built before Phase 5 art so the asset list (five destinations, cabin) follows the
  gameplay.

## 2026-10-15: First balance pass

- Pacing is measured by `ProgressionReport` from the live tunables; numbers live in
  `notes/BALANCE.md`, refreshed after tuning.
- Rocket requirements don't scale with player count for now; a later overhaul makes
  stages much longer.
- MaxSpeed 60 (speed curve unchanged); destination rewards 3/6/9/12/18 per second;
  upgrades grow ×2.2 per level so the first-hour pacing still holds with faster walking.

## 2026-10-16: Mission wheel instead of a linear program

- Each launch's stay ends with a server-wide wheel spin that picks the next mission;
  one mission = one rocket design + one destination. Odds 40/28/19/10/3 by rarity
  (Moon, Mars, Europa, Saturn's Rings, Black Hole). New servers start on the Moon.
- Pity: after 4 spins in a row below Rare, the next spin is Rare+ only, split 34/33/33.
  Long-run Black Hole share is 5.4% (about 1 launch in 18).
- Rarer missions are bigger builds and pay more (reward 1/2/3/5/10 × 3/s).
- The server picks the result and a landing offset; clients only animate it, from the
  shared clock, so everyone sees the same wheel stop.
- Destination mechanics come in a follow-up so the wheel can ship first.

## 2026-10-16: Mission build sizes

- Missions are long co-op builds: 73k / 98k / 137k / 182k / 215k units in all (Moon →
  Black Hole), split Metal:Fuel at the old ratios (fuel share 34% → 43% with rarity).
- No scaling by player count: a full server finishes faster, a small one grinds; the
  point is that everyone has to work together.
- Missions are allowed to get shorter as players grow stronger (~3× over 30 launches);
  that's the payoff for training. A new server's first Moon is the full 73k too.
- Walk curve, destination rewards, Gym District gains, upgrade prices and rank
  thresholds stay as they were; strength and walk get a separate balance pass.

## 2026-10-16: 100-level coin upgrades

- Three tracks with 100 levels each (Bulk Pickup, Bulk Place, Placement Range); Carry
  Capacity is gone, so carry comes only from strength.
- Pickup and place are symmetric: 1 unit per tick, +1 per level. Reach grows 10% of the
  base per level.
- One price curve for every track, set by the user the same day: 50 coins for level 1,
  ×2.5 per level to 25, ×1.5 to 50, ×1.1 to 100. Coins realistically reach about level
  10; the rest is priced for Robux sales, which is the point. (First version: 10/30/120
  then ×1.2, replaced.)

## 2026-10-16: Robux upgrade levels, 10-level tracks

- Upgrades have 10 levels per track (100 made the coin prices absurd): coins 50, then ×3
  per level (984K for level 10); per-level effects unchanged (+1 unit per tick, +10% reach).
- Robux levels are **Game Passes**, one per track per level: 53, 63, … 143 R$ (30 passes).
  Each is bought once, and Roblox keeps the ownership, so a Robux level survives any loss
  of our save data. The track's level is at least the highest owned pass, re-applied on
  every join; coin levels continue from there.
- The server opens the prompt and offers only the next level's pass; the level is raised
  when PromptGamePassPurchaseFinished says purchased (it fires on the server). A pass
  bought out of order (prompted directly) just gives that level.
- The developer-product version (receipt journal, per-PurchaseId ledger, coin payback at
  max) was built first and dropped the same day; repeatable products (Phase 7 "+N units")
  still need that pattern (see the playbook's Persistence Patterns).
- Profile v6 caps saved levels above 10 at 10 (no refund: persistence was never on).

## 2026-10-16: Free mouse, right-click look, Q to drop

- Desktop players keep a normal cursor and hold right-click to look around (the usual
  Roblox feel), instead of a locked mouse-look with a V toggle.
- Dropping cargo is the Q key on desktop; touch keeps the round DROP button.
