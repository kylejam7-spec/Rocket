# Latest session: 2026-10-16, HUD on a phone (iPhone 14 emulator)

- PR #17 rebase-merged. Branch `claude/hud-phone-fixes`.
- iPhone 14 landscape (749x388, HUD scale 0.46): the objective and mission-tag backings
  were sized from TextBounds (screen pixels) as if they were layout units, so they came
  out tiny on phones and oversized on desktop. Now divided by the label's scale.
- Touch: stat stack and the progress group (pill + mission tag, now one frame) get a
  1.35 UIScale; toasts sit higher to clear it. The desktop camera hint showed in the
  emulator only before the touch thumbstick appeared (PreferredInput); not changed.
- Studio emulator: RunChecks 9/9; screenshots before/after.

# Earlier session: 2026-10-16, sign panels only, gyms +1

- PR #16 (HUD) rebase-merged with the user's OK. Branch `claude/gym-sign-oval-and-gains`.
- Gym sign parts are invisible (Transparency 1, no shadow); only the rounded panel the
  client draws shows.
- Gyms +1 each (user): FreeGymMultiplier 2, tiers 3/4/5/7/9/11/13. Tutorial gym steps now
  ~5 s. Numbers in BALANCE.md.
- Studio Play: RunChecks 9/9; screenshot of the district at 10 launches; report run.

# Earlier session: 2026-10-16, HUD polish

- PRs #14 and #15 rebase-merged with the user's OK. Branch `claude/hud-polish` from master.
- User: make the HUD pop like the gym signs.
- StatRow: a dark rounded card edged in the stat's colour, the icon in a glossy coloured
  disc over its left end, an "LV n" chip in the stat colour under the disc, a thicker
  glossy level bar with "into/cost" inside it; "+N" pops land past the card's right
  edge instead of over the digits.
- Objective line on a dark gold-rimmed banner sized to its text (bounces on a new line);
  mission tag on a dark chip with the rarity word in its rarity colour (RichText);
  progress pill 400x48 with a 4 px rim.
- User follow-up: HUD too large and in the way; remove the coloured card outlines
  around the stats, keep the rest. Cards removed; stat rows 220 wide (disc 52, value 34,
  rows 58/74 tall), objective text 26 on a slimmer banner, progress pill 340x40, mission
  tag 17.
- Studio: RunChecks 9/9; screenshots before and after shrinking. Not checked on a
  phone-sized screen. Note: Play started right after an edit can miss Rojo's sync;
  check the Edit copy before starting Play.

# Earlier session: 2026-10-16, gym sign and map label polish

- Branch `claude/gym-sign-polish` stacked on `claude/planet-rewards` (PR #14, not merged).
- User: make the gym/map GUI pop, less flat text, eye-catching "x5" tier multipliers;
  real art comes later, so no reskin.
- GymSignController now draws every gym sign and bench/treadmill tag on the client from
  attributes WorldService sets (Title, Multiplier, Gain, TierColor, Face; stations also
  TrainingStat, TrainingGain, RequiredCycles). Signs: framed panel in the tier colour, a
  pulsing, swaying gold "x3" badge, "💪 +3/s 👟 +3/s", green "✔ UNLOCKED" / red
  "🔒 3/8 LAUNCHES" pill. Equipment: "💪 BENCH" / "+3 STRENGTH / SEC" pill plus a small x3
  badge; locked ones grey out. Destination gyms show "x2" and follow their live gain.
- Server labels (SPAWN, BOARD, SPACEPORT, EXPANSION, BUILD HERE, station banners,
  arch/hut signs): FredokaOne with a UIStroke outline; generic labels sit on a dark pill.
- Debug hook: `RocketDebug:Invoke("launches", n)`.
- Studio: RunChecks 9/9; screenshots of the district at 0 and 10 launches. Note: the MCP
  screen capture leaves out AlwaysOnTop billboards (they render in game); turn
  AlwaysOnTop off locally to preview them.

# Earlier session: 2026-10-16, planet rewards

- PR #13 (levels, tutorial) rebase-merged with the user's OK. Branch
  `claude/planet-rewards` from `master` @ 88b0369.
- User: training too fast, stays ~2 min, Moon ~+3/s rising by rarity → TrainingBaseGain 1,
  tiers 2/3/4/6/8/10/12×, RewardSeconds 120 (Black Hole override gone), Planet bonus 3 ×
  reward 1–5. DestinationCheck: Moon = 3/s, even steps, stays 90–150 s; TrainingCheck:
  top gym ≥ 30 s per capped level. Numbers in BALANCE.md.
- Studio Play: RunChecks 9/9; ProgressionReport run (Edit-mode report reused a cached
  Config; run it in Play). Not flown to a destination live (the feedback text and gym
  gains read the same Config values).

# Earlier session: 2026-10-16, tutorial dim off, strength/speed levels

- Branch `claude/tutorial-and-stat-levels` from `master` @ 4e144cf.
- Tutorial: the darkened screen with a hole around ground targets is gone (no
  `TutorialDim`); the beam, bouncing arrow and off-screen edge arrow stay (`TutorialGuide`).
- Stats: points become levels via `Shared/StatLevels` (cost 10 ×1.2, cap 450). Strength
  +3 carry per level; speed 24 → 70 on a level curve; gym tiers 2–30×; destinations
  10/s. HUD: badge "LV n" under the icon, a bar and "into/cost" toward the next level,
  "Strength Level n!" pops on real level-ups. Numbers in BALANCE.md.
- Tutorial Bench/Treadmill steps now finish at LV 1 of that stat (5 starter-gym ticks)
  and say "Lift to Strength LV 1!" / "Run to Speed LV 1!" while on it. Fixed: the
  on-station line never showed on map gyms (station names are lowercase "Free gym bench").
  Verified in Play: bench 0 → LV 1 advanced to Treadmill, treadmill LV 1 → Together.
- User (2026-10-16): keep the speed vs strength late-game gap as is for now.
- Debug hook: `RocketDebug:Invoke("stats", strength, speed)`.
- Studio (Rojo on 34873 synced the branch): RunChecks 9/9 in Play (TrainingCheck now
  covers level costs, cap 400–500, carry/walk curves); 300/75 points showed LV 10
  (45/60, capacity 40) and LV 5 (5/25, walk 41.7 on the server); tutorial shows no dim.
  Only engine warnings.

# Earlier session: 2026-10-16, free mouse and Q to drop

- Branch `claude/mouse-and-q-drop` from `master` @ 4a267a9 (Robux passes merged).
- Desktop camera: the cursor is free by default; holding right-click turns the camera
  (MouseBehavior LockCurrentPosition while held). The V toggle and centre dot are gone.
  Hint: "Hold right-click: look • Scroll: zoom • Q: drop".
- Q drops carried material on desktop; the round DROP button now shows on touch only
  (phones have no Q). Controllers have no drop input (none before either, beyond GUI
  selection).
- Studio (user OK'd stopping their Play session): mouse Default with icon on, no DROP button
  on desktop; a simulated right-drag locked the cursor, turned the camera 27° and released
  it after; picked up 10 Metal at the Scrap Pit with E, Q dropped it (Capacity 10/10 → 0/10).
  No script errors.

# Earlier session: 2026-10-16, Robux upgrade levels

- PR #8 (100-level upgrades) rebase-merged with the user's OK; branch `claude/robux-upgrades`
  from `master` @ f6f2481, rebased onto 26c1683. The user then set **10 levels per track,
  coins ×3 (50 … 984K), Robux 53 … 143 R$ per level**, and moved Robux to **Game Passes**
  (30, created by the user; IDs in `Config.RobuxUpgrades.passes[track][level]`, checked in
  Studio: names and prices match). Notes in BALANCE/DECISIONS.
- `RobuxUpgradeService`: `sync` on join raises each track to its highest owned pass;
  `BuyUpgradeRobux(track)` → server prompts the next level's pass; a purchase raises the
  level at once. Profile v6 caps saved levels at 10. Panel: blue "R$ 53" button, hidden
  at max.
- Studio: all 67 scripts loaded over HTTP, RunChecks 9/9 (RobuxCheck: pass map, next-level
  lookup, apply never lowers, sync highest-wins / failed check / maxed, coin buys continue,
  v5 cap). Live: the creator owns all 30 passes, so sync raised every track to 10 and the
  Robux buttons hid; after clearing upgrades the button showed R$ 53 and the prompt opened
  for Pickup Level 1 (finished "not purchased", since the creator already owns it).
- Not verified: a real purchase by a non-owner (needs another account, or a Studio local
  server test player), persistence with real saves (off).

# Earlier session: 2026-10-16, upgrade price curve

- Branch `claude/upgrade-price-curve` from `master` @ f6f2481. User's curve: level 1 = 50
  coins, ×2.5 per level to 25, ×1.5 to 50, ×1.1 to 100 (`Config.UpgradePrices.base` +
  `segments`), prices to 3 significant figures; `Theme.short` gains Qa/Qi. UpgradeCheck
  asserts the segment factors and the new pacing (level 1 1–3 min, level 2 3–7 min,
  level 3 7–18 min of a new player's work). Coins reach ~level 10 (notes/BALANCE.md).
- Studio was shared with the Robux session (its scripts loaded). I overwrote its Studio
  copies of Config/Upgrades/UpgradeCheck/Theme before noticing and told it to reload;
  then verified without touching the place: unparented module copies in Edit mode ran
  UpgradeCheck (PASS) and ProgressionReport. Full RunChecks in Play not run on this branch.

# Earlier session: 2026-10-16, 100-level coin upgrades

- Branch `claude/upgrade-levels` from `master` @ 4d18877 (build sizes merged).
- User's spec: 100 levels per upgrade; Carry Capacity removed; Bulk Pickup and Bulk Place
  +1 unit per tick per level; Placement Range +10% per level; level 1 cheap, level 2 a
  minute of work, level 3 a few minutes, then very expensive, so Robux can sell levels.
- Prices 10 / 30 / 120 then ×1.2 (`Config.UpgradePrices`, shared by all tracks): level
  100 costs 5.75B. Placing is tick-based like pickup (`Upgrades.placeUnits`;
  `PourSeconds` gone). Profile schema v5 drops `CarryCapacity`. Panel: three rows, prices
  in short form (`Theme.short`: 16.4K, 3.91M, 5.75B), "Place N per tick", "Reach +N%".
- UpgradeCheck's first-hour pacing replaced by the user's targets (new player, one track:
  level 1 < 60 s, level 2 30–120 s of work, level 3 2–8 min; ≥ 10% per level after; top
  ≥ 1e9). ProgressionReport prints per-track levels; numbers in `notes/BALANCE.md`.
- Studio (with the user's OK, stopped their Play session): all 65 scripts match;
  RunChecks 8/8. Live: bought Bulk Pickup 10 then 30, panel "Grab 3 → 4 per tick, 💰 120";
  Placement Range Lv 2 = place prompt 14.4 studs; a CarryCapacity buy is refused;
  short prices checked. Only UIBlox warnings.
- Not verified live: a pour at Bulk Place > 0 (one-line change, covered by the effect
  check). Not built: Robux purchases (Phase 7 needs the receipt journal and product IDs).

# Earlier session: 2026-10-16, mission build-size balance

- Branch `claude/mechanic-balancing` from `master` @ 51bc175 (mission wheel merged).
- Ran ProgressionReport (1/4/8/16 players, 30 launches) and walked the user through mission
  time, scaling, walk curve, rewards vs Gym District and upgrades. Their choices: build
  totals 73k / 98k / 137k / 182k / 215k (Moon → Black Hole, ~120× before), old Metal:Fuel
  ratios, no lobby scaling, let missions shrink as players grow, keep the 73k opening Moon,
  keep upgrades and ranks; strength and walk get their own pass later.
- Only `Shared/Missions` build sizes changed (plus a stale Config comment). New numbers
  and findings in `notes/BALANCE.md`: first Moon ~91 min for 4 players (3.7 h solo),
  later Moons ~11 min; everyone maxes all upgrades; Gym District now gives most stats.
- Studio: scripts loaded over a local HTTP server (Edit mode), all 65 lengths match the
  worktree; RunChecks 8/8 in Play; HUD pill shows "🔩 0 / 48,500" on the Moon.
- Not done: strength/walk balance (half-point 120 saturates by launch 5), destination vs
  Gym District stat share, rank thresholds, upgrade sinks for late game.

# Earlier session: 2026-10-16, mission wheel (Phase 4.6)

- Branch `claude/mission-wheel` from `master` @ 77826d8 (Gym District + UI polish merged).
- The linear 15-cycle program is gone. `Shared/Missions` (replaces RocketCycles): five
  missions, one rocket design and destination each — Moon (Common 40%), Mars (Uncommon
  28%), Europa (Rare 19%), Saturn's Rings (Epic 10%), Black Hole (Legendary 3%). New
  servers start on the Moon; WheelLeadSeconds (10) before each stay ends the server
  spins (`LaunchService` spinWheel → `Cycle.wheel`, sent in state) and the next rocket is
  the result. Pity: after 4 spins in a row below Rare the next spin uses Europa 34 /
  Saturn 33 / Black Hole 33. Long-run share: 36.8 / 25.8 / 20.2 / 11.8 / 5.4%.
- Rarer = bigger build and reward: 600 / 1,150 / 2,100 / 3,700 / 6,100 units;
  destination reward 1/2/3/5/10 (3, 6, 9, 15, 30 per second, gyms 2×); Black Hole stays
  45 s and launches with bigger exhaust and shake. Rocket names: Lunar Rocket, Mars
  Rocket, Europa Heavy-Lift, Saturn Super Heavy, Event Horizon Explorer.
- Destinations: Moon, Mars, Saturn moved; Europa (ice shell, cyan fissures, ridges,
  GeyserVent-tagged vents, banded Jupiter with the Great Red Spot) and Black Hole
  (obsidian disc, purple fissures, debris, neon-black horizon, tilted accretion disk,
  lensed halo) new; Space Station and Pluto removed. Planet bands are thin discs:
  Ball parts are always round, so squashed balls don't work.
- `WheelController`: pie of 144 spokes coloured by rarity (Theme.rarity), radial labels,
  eased 6 s spin to the server's slice + offset on the shared clock, result in rarity
  colour; hides the objective line while up. Progress tag: "EUROPA MISSION • RARE",
  "Rare+ in N spins" / "NEXT SPIN: RARE+ GUARANTEED". New-mission banner in rarity colour.
- Checks: `MissionCheck` (odds, pity after 4, pity pool Rare+, sampled shares, ≤4 misses
  in a row, exact long-run chain); MaterialInteraction/Destination checks moved to
  missions. `ProgressionReport` simulates N launches of a seeded wheel. Debug:
  `Invoke("mission", id or index)`, `Invoke("misses", n)`.
- Studio: RunChecks 8/8. Pity spin (misses 4) on the Moon → "PITY SPIN!" Rare+ wheel →
  EUROPA, then home on the Europa mission (0 / 1,300, blue banner). Normal wheel checked
  by screenshot (40/28/19/10/3). Europa and Black Hole by Edit preview.
- Sync gotcha: Rojo (34874, even after a restart) delivered new files but no edits to
  existing scripts; scripts were written into Studio from the worktree over a local
  HTTP server (Source set directly) and all 66 lengths matched before testing.
- Not done: destination mechanics (Mars dust storm, Europa geysers, drifting Saturn
  chunks, Black Hole slow motion + exit cutscene) — next PR; a real Black Hole launch
  (its hatch sits elsewhere for the big rocket); two clients; phone layout of the wheel.

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
