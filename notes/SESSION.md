# Latest session: 2026-10-15, planet destination UI polish

- Merged `claude/gym-area-tiered-ordering-2997f1` (Gym District + Phases 2–4,
  destinations, balance). Material hints now filter before the toast stack.
- Merged build in Studio (34873): all 63 scripts match by length; RunChecks 7/7 in a
  Play server. Edit-mode require returned a stale cached Config (TrainingCheck and
  UpgradeCheck failed there), so run RunChecks in Play after a big sync.
- Head popups have lanes (`HudController` `lanes`): +Strength left, +Speed right,
  "Strength Level Up!" / "Speed Level Up!" raised 50 / 100 px via `Popup.world`'s new
  `shift` (BillboardGui.SizeOffset, pixel-stable). Meadow ticks no longer stack them.
- Speed icon is 👟 (`Theme.icon.Speed`).
- Progress pill: the inset is a rounded CanvasGroup and the fill is always ≥ one cap
  wide, sliding in from the left, so early fill grows as a smooth sliver (0.35 s tween).
- Material how-to toasts (cargo full, X placed!, pick up first, cargo cleared) show
  once per session, filtered client-side in `HudController`.
- Studio (this worktree served on 34873; all five changed scripts match by length):
  1% fill = 5.5 of 552 px, 6% = small rounded sliver; Meadow trip logged 33 head
  popups: gains at x ≈ −55 / +55, both level-ups on one tick at shift 50 / 100 px.
  Material hints sent twice each showed once. Only UIBlox warnings. Screen capture
  does not show BillboardGuis, so popup lanes are checked by log, not by eye.
- Studio gotcha: a teleport via PivotTo is snapped back by the anti-teleport; walk to
  the BOARD pad with Humanoid:MoveTo (-40,3,-10) → (-40,3,-87) → (0,3,-87).
# Earlier session: 2026-10-15, first balance pass

- Branch `claude/balance` from `master` @ 83364c4 (destinations merged).
- New `ServerScriptService/ProgressionReport`: simulates all 15 rockets for N players
  from the live Config/RocketCycles/Upgrades and prints per-rocket time, carry, walk,
  stats, upgrades and the destination share of stat gains. Numbers and findings are
  in `notes/BALANCE.md`.
- User decisions: no player-count scaling yet (the overhaul will lengthen stages);
  keep the speed curve shape but raise MaxSpeed 44 → 60 (also the anti-teleport
  limit); soften destination rewards to 1/2/3/4/6 (3, 6, 9, 12, 18 per second).
- Faster walking broke UpgradeCheck's first-hour pacing (gap 174 s). Retuned upgrades
  with the check's own sim in Studio: growth ×2.2 on all tracks, Carry Capacity base
  150 → 120 (others 10/90/120): first buy 23 s, mean gap 195 s training / 301 s not.
- Studio (synced): RunChecks 7/7; report run for 1/4/8/16 players at 15% and 30%.
- Not done: the balance overhaul itself (stage length, group scaling, speed spread).

# Earlier session: 2026-10-15, rocket cabin and destinations (Phase 4.5, merged)

- Branch `claude/destinations` from `master` @ e156ee3 (Phase 4 merged). Rojo on
  127.0.0.1:34874 from the `phase2-hud-ea13bf` worktree.
- User's change: no more Meadow slab. Players get inside the rocket, countdown, the
  liftoff cutscene, then an isolated destination per design (1 Space Station, 2 Moon,
  3 Mars, 4 Saturn, 5 Pluto) with the same passive per-second bonus, then spawn.
  Done before Phase 5 assets so the art list follows the gameplay.
- `Services/DestinationService` builds the cabin (Config.CabinPosition, -3000/200/0:
  seats with a centre aisle, portholes, CountdownScreen, ExitHatch) and the five
  areas (Config.Destinations: id, name, gravity, color, position; 10,000 studs apart
  on x, z 10000, because Saturn's rings are visible ~4,000 away). Each: walled play
  area (invisible fence ring), themed primitives, ArrivalPad tagged
  DestinationArrival, welcome sign ahead of the arrival.
- `LaunchService`: on the BOARD hatch during Boarding → relocated into the cabin;
  boarded = in the cabin box (raw body, so a just-teleported player counts); cabin
  "Leave rocket" prompt puts you beside the hatch (away from the rocket). Lock = in
  cabin at the deadline; stragglers without a lock go to spawn. Rewarding: spread
  arrival at the design's destination; reward toasts name it. Hull standers at
  boarding start go beside the hatch, not onto it.
- Client: `DestinationController` (cabin screen "LIFTOFF IN n → THE MOON", local
  Gravity while a passenger at the destination, reset after). HUD/pill/tutorial text
  name the destination (`state.destination`, `state.destinationTier`).
- `DestinationCheck`: builds into a scratch folder; every cycle's design has a
  destination; arrivals on their ground; fence before every edge; ≥ 8,000 studs
  apart; cabin closed on all sides; clear aisle from arrival to the exit hatch.
- Studio (single sync verified, desktop): RunChecks 7/7. Cycle 1: hatch → cabin
  (screen counting down) → liftoff → Space Station, +3/s ticks, back to spawn.
  Cycle 4: in, out through the exit hatch (beside the BOARD hatch, objective back to
  "BOARD NOW!"), in again → Moon (gravity 60, jump +23.5 studs, sign, "MOON 26s"
  pill) → spawn with gravity 196.2, Cycle 5. Mars, Saturn, Pluto checked by Edit
  preview screenshots. Fixed on the way: seats blocked the aisle (exit unreachable);
  neighbouring destinations' giant planets were visible (spacing 1,000 → 10,000).
  Only UIBlox warnings.
- Not verified: Saturn/Pluto via a real launch (layout via preview + check),
  two clients boarding together, the cabin and destinations on the phone emulator.
- Edit-mode screen captures don't render SurfaceGui text; Play captures do.
- Follow-up (user): rewards grow with the destination and each destination has its
  own gym. `Config.Destinations[n].reward` = 1, 2, 4, 6, 10 (× Planet 3/s → 3, 6, 12,
  18, 30 per second); RocketCycles RewardMultiplier is now 1 except the final
  mission (2). Each destination has a bench and treadmill (gold, "2× BONUS", at
  ±28/24 from its centre, scatter keeps those and the arrival clear) giving double
  the destination's per-second reward; usable only during that destination's stay
  (`phaseAllowed(station)`); training stops before the trip home. Tutorial ignores
  destination gyms. `DestinationCheck` adds growing rewards and gym spots on ground.
- Studio: RunChecks 7/7. Cycle 7 → Mars by a real launch: passive +12/s strength and
  speed; on the Mars bench +36/s strength (24 bench + 12 passive), "+24" popups; home
  unanchored, walking, gravity 196.2.

# Earlier session: 2026-10-15, Phase 4 upgrades and ranks (merged)

- Branch `claude/phase4-upgrades` from `master` @ 2ea6f97 (Phase 3 merged). Rojo on
  127.0.0.1:34874 from the `phase2-hud-ea13bf` worktree.
- Tracks (`Config.Upgrades`, math in `Shared/Upgrades`): Bulk Pickup (+1 unit per
  pickup tick, from 10 coins), Bulk Place (+25% pour speed, 90), Placement Range
  (+2 studs reach, 120), Carry Capacity (+5, 150). Each level doubles, rounded to 5.
  Effects: Stats.capacity, Cargo pickup/pour/reach, Tutorial reach, and the client
  place prompt's distance.
- `Services/UpgradeService`: `BuyUpgrade(track, requestId)` validates and charges once
  per request ID (ledger of the last 32 IDs in the profile), saves right away, toasts,
  and finishes the tutorial's new "Upgrade" step. Rank tag (APPRENTICE → MECHANIC 250
  deliveries → ENGINEER 1500 + 1 launch → FLIGHT DIRECTOR 6000 + 3 → COMMANDER 20000 +
  8) over every head, refreshed on Stats.update.
- Profile schema v4: `upgrades`, `purchaseIds` (v3 migrates empty; bad levels refused).
- Upgrades hut (green, gold roof, UPGRADES sign) at (-26, 4, -32) beside the lane;
  its prompt opens `Controllers/UpgradesController` (rows: icon, name + level,
  now → next, coin button; grey when unaffordable, MAX at the cap; closes past 22
  studs). The panel keeps ≥ 0.75 scale on phones while it fits.
- Tutorial: "Upgrade" after "Place" (target: the hut). Entering it tops coins up to the
  cheapest upgrade, counting the ball still being poured (exactly 10 in Studio).
- `UpgradeCheck`: prices, purchase validation and idempotency, effects, ranks, v4
  migration, and a first-hour sim (trip model from Studio timings): first buy at 23 s;
  mean gap after the second buy 189 s with gym time, 285 s without.
- Debug: `RocketDebug:Invoke("coins", n)` and `Invoke("upgrades")` (clear).
- Studio (single sync verified, desktop): RunChecks 6/6. Fresh run pit → ring →
  "Spend your coins!" with 10 coins; prompt opened the panel; a real click bought Bulk
  Pickup (19 → 9 coins, price 10 → 20) and moved the tutorial to the bench. With 1000
  coins: Carry Capacity (capacity /15), retry of the same ID not charged, Placement
  Range (prompt distance 14), unknown track ignored → 730 coins. Rank tag APPRENTICE.
  Only UIBlox warnings.
- Phone emulator (750×323 inset): panel at 0.75 scale (18 px titles, 12 px details,
  33 px buy buttons); its right edge clipped GRAB, so on touch it now slides left of
  the action cluster (8 px clear; stat stack clear). A real emulated tap bought Bulk
  Pickup (100 → 90 coins).
- Not verified: purchases across rejoin with persistence on (published test place),
  two clients.

# Earlier session: 2026-10-15, Phase 3 tutorial (merged)

- Branch `claude/phase3-tutorial` from `master` @ bbb24d4 (Phase 2 merged). Rojo on
  127.0.0.1:34874 from the `phase2-hud-ea13bf` worktree.
- `Services/TutorialService`: steps Pickup → Carry → Place → Bench → Treadmill →
  Together → Done, stored by name in the profile (`tutorialStep`). Only server events
  advance it: a pickup, standing in place reach with cargo (5 Hz sample; Carry falls
  back to Pickup if the cargo is gone), an accepted delivery, a training tick at the
  starter bench / treadmill (TrainingService `trained` hook). Together ends after
  `TutorialFinalSeconds` (8). `TutorialSkip` sets Done; `TutorialSeen` marks a
  one-time callout only while its phase is on. "Upgrade" slots in after Place in
  Phase 4.
- Profile schema v3: `tutorialStep`, `seenCallouts`. v1/v2 migrate; anyone with
  deliveries skips the tutorial. Saves copy both fields. Debug: `RocketDebug:Invoke(
  "tutorial", step?)` restarts everyone's tutorial.
- `Controllers/TutorialController`: objective line (HudController asks it first), a
  green beam + bouncing arrow at the target, a ring arrow toward off-screen targets
  (the pit is behind you at spawn), the world dimmed around a ground target within
  40 studs of its edge, SKIP TUTORIAL (right, under the settings), callouts for the
  first Fuel phase and first boarding, "TUTORIAL COMPLETE!" banner.
- `TutorialCheck`: step order (no skipping ahead, Done final) and v1/v2/v3 profile
  migration and validation.
- Studio (single sync verified): RunChecks 5/5. Fresh run: every step advanced on its
  server event; real play time ≈ 40 s (≈6 s to the pit, 10 s pit → ring, ≈15 s gym,
  8 s closing line). SKIP by real click cleared line, arrow and beam. Debug fills:
  both callouts showed after the phase banner, server recorded `Fuel,Boarding`.
  Dimming and the ring arrow checked by screenshot. Only UIBlox warnings.
- Phone pass (landscape phone emulator): SKIP was 19 px tall and the ring arrow
  (fixed 110 px) covered the stat stack. SKIP now sits in a holder with a touch
  UIScale (≥ 36 px tall, 14 px text; the button's own UIScale is its hover grow, and
  only one UIScale applies per object); the arrow is 12% of the screen height
  (48–110 px). No HUD overlaps; a real emulated tap on SKIP ended the tutorial.
- Not verified: rejoin with persistence on (needs the published test place; the
  v3 round trip is covered by TutorialCheck), two clients.
- Pit exit for MoveTo: (-42,-4,78) → (-20,0,78) → (-10,0,40), then the ramp.

# Earlier session: 2026-10-15, Phase 2 HUD parity (merged)

- Branch `claude/phase2-hud` from `master` @ aa8ddde (Phases 0–1 merged). Rojo for it on
  127.0.0.1:34874 from this worktree.
- Toasts: `UI/Toast` stack above the progress pill (max 3, 3 s, repeats re-bounce).
  Feedback goes there; the objective line never gets overwritten now.
- Action cluster (`Controllers/ActionController`): one bottom-right row of round
  buttons, LEAVE (red, was a pill) · DROP · GRAB/PLACE · JUMP. GRAB/PLACE (hold = the
  material button, caption by cargo) and JUMP show on touch only; Roblox's own jump
  button is hidden on touch.
- Settings (`Controllers/Settings` store + `SettingsController`): gold ⚙️ button top
  right opens a panel with Music and Sounds sliders (`UI/Slider`, driving the "Music"
  and "SFX" SoundGroups for future audio) and a Reduced effects switch (`UI/Toggle`)
  that drops launch camera shake, delivery flashes and flying coins. Session-only.
- Phone fit: UIScale now follows the ScreenGui's inset height, floor 0.45 (was 0.6
  of the viewport, which overflowed ~375 px landscape phones); `CoreUISafeInsets` set
  explicitly. Stat stack pinned under the objective (fixed 160 design px) instead of
  20% of the height, which clipped it on wide screens. Camera hint moved bottom-left.
- 🪙 doesn't render in Roblox (blank coin icon); Coin is 💰 now.
- Studio (1920×1080-class viewport, single sync verified): RunChecks 4/4; no HUD
  rectangle overlaps; toasts, settings panel, slider (Music 0.6 → 0.5 on the group) and
  toggle by real mouse clicks; with Reduced effects on, a 10-unit delivery gave coins
  0 → 10 with no flashes or flying coins; no game errors or warnings.
- Phone pass (Studio Device Emulator, landscape phone, 750×323 inset, UIScale 0.45):
  the action buttons were 37 px and the stat sub-labels 6 px. Fixed: on touch the cluster
  is a fixed 2×2 grid (JUMP bottom right, GRAB/PLACE left of it, DROP and LEAVE above;
  slots by LayoutOrder, so nothing shifts) with its own UIScale keeping buttons ≥ 70 px
  (Roblox's own phone jump size); sub-labels 14 → 20 and cycle tag 18 → 22 design px
  (9 px on the phone). Verified by real emulated touches: JUMP held 1.5 s = 4 jumps, then
  stops; Roblox's jump button hidden; GRAB held at the pit filled 10/10, caption → PLACE,
  DROP appeared above it. No HUD rectangle overlaps with all four buttons shown.
  RunChecks 4/4; only Roblox UIBlox warnings.
- 1920×1080 capture matches the reference frames 4/5 layout (left stack, top objective,
  bottom pill + tag, bottom-right round buttons); no overlaps.
- Studio MCP: in the Device Emulator `user_mouse_input` instance_path clicks miss (they
  ignore the letterbox and inset). Calibrate by logging InputBegan positions; here GUI
  (x, y) = screen (x − 62, y − 20).
- Left out on purpose: SHOP/PETS column and boost badges (hidden until those exist).

# Earlier session: 2026-10-14, wide ramps + ramp place reach

- Branch `claude/great-ellis-195d97` is now rebased onto `claude/place-pickup-anywhere`
  (6101de9: hold E anywhere, one place prompt that slides around a ring encircling the
  whole rocket). One commit on top.
- Ramps: inner edge 1 stud outside the widest segment (it used to clear the launch
  mount), outer edge unchanged (inside the floodlights), each ramp ≥ 14 wide (T3–T5
  16–19). Where the inner strip crosses the mount front it would meet a 1.6–2.9 stud
  ledge (T3/T4), so the ramp plane and its arms lift just enough (T3 +2.3, T4 +1.3).
- Reach: `Build:inPlaceReach(position, reach)` = within reach of the ring, or on a ramp
  (across rampInner−1…rampOuter+1, up to 8 above its surface) within reach of the fill
  line along the rocket. CargoService uses it; the ring carries `RampInner`/`RampOuter`/
  `RampSurface` attributes so CargoController slides the prompt onto the ramp beside you.
- New `RampCheck`: all 15 variants: hug, width, inside complex, no mount ledge, reach
  from every ramp/hull spot ±6 studs of the fill line at 7 fill levels, and no reach far
  up the ramp or far above it.
- Studio (single sync verified: every script length matches the worktree): RunChecks
  4/4 pass. Cycle 7 (T3) at 45%: walked the inner edge past the mount (no ledge), then
  stood at x = 39 on the outer ramp, 12.6 studs outside the 52.7-stud ring: prompt slid
  to 1.1 studs away, Delivered 0 → 10, coins 0 → 10. No game errors or warnings.
- Studio gotchas: a Rojo patch that lands during Play is dropped and Rojo then thinks
  it's in sync (make a real content change to resend). Two sessions syncing at once
  mixed branches in Studio; check script lengths against the worktree before testing.
- Not done: the 10-minute solo acceptance run, two clients, phone layout.

# Earlier session: 2026-10-14, Phase 1 stat curve + delivery feedback

- Same branch and Rojo port (34874) as the coins work below.
- Stat curve: no level cap. Walk speed = 24 + 20 · p / (p + 120), so it never
  passes `MaxSpeed` 44 (also the anti-teleport limit). Carry = 10 + ⌊1.5 · √strength⌋,
  capped at 1,000. `MaxLevel`, `SpeedPerLevel` and `StrengthPerCarry` are gone, and
  so are the training cap stop and the profile stat-cap check.
- `TrainingCheck`: training past 10,000 keeps going; the curves start at base, the
  first starter-bench tick raises capacity, five treadmill ticks raise whole walk
  speed, both rise monotonically to 1e6 within limits, and speed gains diminish.
- New `Controllers/DeliveryFeedbackController`: when the current phase's shared
  total rises (anyone's delivery), it flashes a local neon shell out of the
  `Filling` segment (gold for Metal, pink for Fuel) and a white ring off the
  `BuildFrontier`, at most once every 0.2 s. Coin bursts cover the coin pop.
- Studio verification (real client): `RunChecks` all pass. Starter bench, 10 s:
  Capacity 10 → 16. Treadmill, 12 s: Walk Speed 24 → 27, Humanoid 27.1. Delivered
  Metal from the ramp: coins 0 → 15 = Delivered 15; both flash parts (segment
  and ring) appeared per batch; only Roblox UIBlox warnings.
- Reach: as the fill line rose, the ramp fell out of `FrontierReach` (fixed in the
  session above).
- Pit exit for MoveTo: (-72, 0, 73) → (-64, 0, 75) → (-64, 3, 90), then the ramp.
- Not done: the 10-minute solo acceptance run, two clients, phone layout.
- Next: that 10-minute run, then Phase 2 leftovers (settings, mobile Place/Jump,
  safe areas, toasts, screenshot comparison).

# Earlier session: 2026-10-14, Phase 1 coins

- Branch: `claude/great-ellis-195d97`, on top of `claude/brave-turing-b9188d` @ 2f203c7.
  Rojo for this branch was served from its worktree on **127.0.0.1:34874** (another
  checkout still held 34873). Point the plugin back at 34873 to return.
- Server: `Profiles.credit(profile, delivered, config)` adds lifetime deliveries and
  `CoinsPerUnit` (1) coins per unit `Rocket:deliver` accepted. `CargoService.place`
  calls it. Profile schema is v2 (`coins`); v1 migrates to 0 coins on load and
  `save` writes coins back. `StateUpdated.profile.coins` carries the total.
  Persistence is still off.
- Client: a gold 🪙 Coins row tops the left stat stack. On a coin gain up to 5
  coins pop from over your head and `Tween.flyTo` the row (max 15 in the air). The
  first to land counts the row up to the latest total with the usual bounce and
  "+N"; later ones just bump the icon.
- `MaterialInteractionCheck` now covers coins: they match delivered units, and
  empty, discarded, leftover and invalid (negative, fractional, NaN, inf) deliveries
  pay nothing.
- Studio verification (real client): `RunChecks` all pass. Picked up 10 Metal at
  the Scrap Pit, placed from the ramp at about (18, 23, -107): Coins 0 → 4 → 9 with
  up to 4 coins in flight, matching Delivered 9; no stray coins left; only Roblox
  core UIBlox warnings, no game errors.
- Studio MCP tips: firing `Remotes.MaterialHold` (prompt, true/false) from the
  Client drives pickup/place reliably; `prompt:InputHoldBegin()` does not. Path to
  the ramp: MoveTo (22, 3, -78), then (21, 23, -107). From (18, 23, -107) the ring
  is ~12.3 studs away, right at `FrontierReach` 12 + slack, so holds can end early.
- Not covered: two clients, phone layout of the taller stack, persistence.
- Next: the rest of Phase 1 (stat curve, delivery pulse/ring flash).

# Previous session: 2026-10-14, Phase 0 client half + reference-style HUD

- Branch: `claude/brave-turing-b9188d`, on top of `claude/phase0-on-master` @ 4f4e4c7.
  Rojo for this branch was served from its worktree on 127.0.0.1:34873. To go back,
  run `rojo serve` from the other checkout again and reconnect the plugin.
- Commit 1 (Phase 0 client half): one `Main.client.luau` entry, `Controllers/` and a
  `UI/` library; the old HUD unchanged.
- Commit 2 (HUD overhaul, most of Phase 2 plus Phase 1 training feedback), styled
  after the eight *Build a Pyramid* reference frames:
  - left stat stack (💪 Strength / Capacity, ⚡ Speed / Walk Speed, 🚀 Launches /
    Delivered) with count-up, icon bounce and "+N" pops
  - top-centre objective line by phase and cargo ("Full! Carry the scrap…");
    Feedback messages replace it for 3 s (training and Meadow ticks are skipped,
    they show as popups)
  - bottom-centre gold-rimmed progress pill (`🔩 8 / 400`, `⛽ 0 / 200`,
    `BOARD NOW! T-7`, `LIFTOFF!`, `MEADOW 30s`) with a cycle/tier/"You: N" tag
  - big bouncing centre banners and boarding countdown
  - gym juice: `+2 💪` / `+2 ⚡` world popups over your head each tick, "Strength
    Level Up!" when capacity grows, "Speed Level Up!" per whole walk speed
  - round purple DROP button (bottom right), red LEAVE STATION [E] button
  - custom proximity prompts (`PromptController`): gold-rimmed card with object,
    action and key chip; tap/click drives InputHoldBegin/End for touch
  - every ScreenGui has a UIScale from a 720 px design height
- Studio verification (Build a Rocket place, Rojo-synced, real client):
  - `RunChecks`: all three pass
  - bench: 14 popups incl. Strength Level Up, HUD 0→26 with count-up; treadmill:
    `+2 ⚡` and Speed Level Up; exit with E
  - Scrap Pit hold-E pickup through the custom prompt to 12/12 ("Full!" objective),
    DROP click clears, re-pickup, place from the ramp (8/400, You: 8, Delivered: 8)
  - debug fill: Fueling banner, boarding countdown and green pill, liftoff, 30
    Meadow ticks (79 popups), Launches 0→1, reset to 0 / 500
  - no game warnings or errors on client or server
- Caveat: the MCP `screen_capture` does not render BillboardGuis, so world popups
  and prompt cards were verified through the instance tree, not by eye.
- Studio MCP tip: walk with `Humanoid:MoveTo` from Client `execute_luau`;
  `character_navigation` stalls and client teleports get snapped back. Place
  prompts are reachable from the ramp edge at about (17.3, 23, -107).
- Not covered: touch tap on the prompt card, phone layout in the Device Emulator,
  two clients, persistence (still off).
- Next: eyeball popups/prompt cards in a real play session, phone layout pass,
  then Phase 1 coins (coin row in the stat stack, `Tween.flyTo` bursts).
