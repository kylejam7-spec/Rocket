# Roadmap: getting Rocket to "Build a Pyramid" quality

Reference: eight gameplay frames from *Build a Pyramid* (2026-10-14). Rocket keeps
its own identity: a shared rocket instead of a pyramid, a Metal-then-Fuel build, and
a board/launch/planet payoff the pyramid game doesn't have. It should match the
reference for feel, UI layout, onboarding and progression.

This roadmap describes `master` (the restored project, at 26ffae5). Rojo serves it
on port 34873 into the *Build a Rocket* place.

## 1. What the reference does (from the frames)

| Frame | Observation | What it means for Rocket |
|---|---|---|
| 1 | Top-center objective banner ("Grab a block from the quarry to begin.") plus green 3D arrows in the world. **Skip tutorial** button top right. | A step-based tutorial with world waypoints, skippable, remembered per player. |
| 2 | Proximity prompt **Block / Pick Up** at the quarry. Everything except the prompt is dimmed. | One-word prompts and focus dimming during the tutorial. |
| 3 | A large stone block is carried **over the player's head**; "Carry the block to the pyramid." Capacity readout `0/1`. | Cargo visible on the character. **Done:** the scrap ball and jerry can. |
| 4 | On delivery: gold coins burst out and fly to the coin counter, and a **green wireframe ghost** shows where the next block goes. Bottom bar reads `8 / 171,700`. | Coins are the soft currency. **Done:** the ghost/fill line and growing goals. **Missing:** coins and the bottom progress pill. |
| 5 | Bench press: floating `+1` strength icons and a **Strength Level Up!** billboard. Strength 13 gives Capacity `0/2`. | **Done:** seated training. **Missing:** per-tick popups and level-up billboards. |
| 6 | Treadmill: `+1` speed icons and **Speed Level Up!** Speed 12 gives Walk Speed 33; base is 32. | Same pattern. Base walk speed is fast, so the first minute never feels sluggish. |
| 7 | **UPGRADES** panel with Bulk Pickup, Bulk Place ("1 Blocks Per Place") and Placement Range. Each row has a level, a coin price (green) and a Robux price (purple). | A coin sink with three upgrade tracks, opened in a physical upgrades area. |
| 8 | "Train some more and work with everyone to complete the pyramid." A sign advertises *2x Pyramids · Quick Pickup · Quick Place*, and there's a Pharaoh NPC. | The tutorial hands off to the open loop. Upsells live in the world as well as in the HUD. |

**Persistent HUD layout (every frame):**

- **Left stack:** Coins, Speed and Strength. Each has a large icon, a big number, an `x1` multiplier badge and a small sub-label (`Walk Speed: 32`, `Capacity: 0/1`).
- **Top right:** PETS and SHOP buttons, with boost badges (`1.5x Speed`, `2x Strength`) below them.
- **Bottom center:** A wide progress pill (`9 / 171,700`), with four purchase chips above it.
- **Bottom left:** `Friend Boost: +0%`.
- **Bottom right (mobile):** Jump, drop-cargo and place buttons.
- **Above players:** A rank title such as **APPRENTICE** above the display name.
- **Art direction:** Warm desert palette, chunky outlined cartoon icons and heavy white text with a dark stroke. Panels use saturated green and purple buttons.

## 2. Where Rocket is today (`master` @ 26ffae5)

| Area | Current state | Gap to the reference |
|---|---|---|
| Shared goal | 15 server cycles across 5 rocket tiers (600 → 8,250 units). Metal builds the rocket, then Fuel fills it. The program wraps to Cycle 1. Data lives in `Shared/RocketCycles`. | Matches decision 1 already. Only presentation is missing (bottom progress pill). |
| Building | Hold E for 20 transfers/s. The rocket fills lowest-point-first with ghost cells, a glowing "BUILD HERE" ring and 7 placement points. It's built tilted, then erected. | Missing: coin bursts and per-delivery juice. |
| Carrying | The scrap ball grows with load; Fuel is carried as a jerry can. Capacity is 10 + strength/15. A "Clear carried materials" button exists. | Missing: a mobile action cluster in the reference style. |
| Training | Seated bench/treadmill at +2/s, with a starter gym and five gym tiers unlocked by launches. A playtest level cap of 50. | Missing: `+N` popups and level-up billboards. Remove the 50 cap and add a soft curve. Base walk speed is 16 (reference: 32). |
| Launch | Boarding pad, erect animation, client-side launch effects and camera, a Meadow reward ticking for 30 s, and the map expanding every 3 cycles. | Unique to Rocket. Keep it and polish it. |
| Currency/upgrades | None. | Coins, an Upgrades panel and three tracks. |
| HUD | A text panel at left (`Main.client`), a progress panel top right (`RocketProgress.client`) and gym sign lock text. | Rebuild in the reference layout. |
| Tutorial | None, beyond feedback lines and big station banners. | A full step machine. |
| Art/audio | All primitives, but rich ones: scrap pit, oil refinery, 5 rocket models of ~160 parts each. No sound. | Imported meshes, VFX and SFX. |
| Code shape | `Main.server.luau` is 697 lines covering map, remotes, gyms, cargo/hold loop, launch sequence and debug hook. There are 7 focused service modules. | Split into services before features pile in. |
| Tests | `*Check.luau` modules run inside Studio. No CLI tests, no notes folder. | Add a single check runner. |
| Persistence | Off. `ProfileService` has a reward ledger keyed by tick. | Real data store test and a durable entitlement journal before release. |

## 3. Decisions (confirmed 2026-10-14)

1. **Builds are per-server and grow.** This is already true on master through `RocketCycles`. Each launch moves the server to a bigger cycle, as the reference's pyramids grow after 171,700. A global "fleet" counter can come later.
2. **Monetization comes near the end.** Build the HUD slots now and hide them until they work. Wire purchases only in Phase 7, after the durable entitlement journal.
3. **UI tech: plain Luau component modules.** Use a small `UI/` library (Theme, StrokedText, StatRow, Pill, Button, Panel, Popup) plus a tween helper for bounce, count-up and fly-to effects. This adds no new toolchain. The effort goes into animation and art, which is what makes the reference grab attention.
4. **Asset pipeline: imported meshes.** Meshes are uploaded to Roblox and referenced by ID from a source-owned manifest, and every asset's license is recorded (details in Phase 5). Master already stores the world as `.rbxm` under `world/`.

## 4. Phases

Each phase ends with a Studio play test (two clients where it matters) and passing `*Check` modules.

### Phase 0: Foundation (no behavior change)

- **Split `Main.server.luau`** into services in the existing context style (`X.new(context)`, like `TrainingService`). The server half was done 2026-10-14; see `notes/DECISIONS.md`.
- **Tag the anchors** with `CollectionService`: spawn, material zones, build frontier, boarding pad, gyms, gym signs and planet. Services and clients can then find them by tag instead of by name or captured local variables.
- **Add a check runner:** one `RunChecks` entry that runs every `*Check` module in Studio and reports pass/fail. It's used by every phase.
- **Client half:** add a `Controllers/` folder and a `UI/` component library. The existing HUD keeps working on top of them until Phase 2 replaces it. Done 2026-10-14; see `notes/DECISIONS.md`.
- **Accept:** the README play test behaves as before and every check passes.

### Phase 1: Economy and feedback

- **Coins:** each accepted delivery tick grants coins, credited by the server and stored in the profile (schema bump). The client plays a coin burst that flies to the counter.
- **Stat curve:** strength and speed become uncapped point totals with soft curves. Raise base walk speed toward ~24–32. Retune `BaseCarryCapacity`/`StrengthPerCarry` so capacity growth stays visible early.
- **Training feedback:** `+N` icon popups per training tick, plus a "Strength/Speed Level Up!" billboard at thresholds. The existing `TrainingService` tick fires an event the client renders.
- **Delivery feedback:** a pulse on the filled segment, a ring flash, and a small coin pop per transfer batch (batched with `sendSoon`).
- **Accept:** in a 10-minute solo session, coins, stats and walk speed all visibly climb, and no duplicated cargo or coins appear (extend `MaterialInteractionCheck`).

### Phase 2: HUD parity

Build these with the `UI/` library. Use stroked heavy fonts, and scale for phone with `UIScale` and safe areas.

- **Left stat stack:** Coins, Speed and Strength, each with a multiplier badge and sub-label. Numbers count up on change.
- **Bottom progress pill:** `Metal 312 / 400`, then `Fuel 80 / 200`, then the boarding/launch countdown. The current `RocketProgress` panel moves here; tier name and cycle `n/15` become a small tag above it.
- **Top-center objective banner,** driven by the tutorial and phase. This replaces the text panel's instructions.
- **Right column:** SHOP and (later) PETS buttons and boost badges. Hide them until those features exist.
- **Mobile action cluster:** Drop (the existing discard), Place/Interact (the existing hold) and Jump. Restyle the Leave-station button to match.
- **Feedback:** route the `Feedback` remote into toasts, and use big center banners for announcements (new rocket design, final mission).
- **Settings panel:** music and SFX volume, plus a reduced-effects toggle.
- **Accept:** side-by-side screenshots against reference frames 4 and 5 at 1920×1080 and on a phone emulator, with no overlaps.

### Phase 3: Tutorial and onboarding

- A `TutorialController` step machine. The server confirms each step, so a client can't skip ahead to rewards.
  1. Pick up Metal at the SCRAP PIT.
  2. Carry it to the glowing ring.
  3. Place it, and see coins and the rocket grow.
  4. Buy a first upgrade (the tutorial guarantees enough coins).
  5. Use the bench.
  6. Use the treadmill.
  7. "Work with everyone to finish the rocket, then fuel it and board!"
- Beam/chevron waypoints along the road, plus dimming outside the current target.
- A **Skip tutorial** button, with completion stored in the profile.
- First Fuel phase and first boarding get one-time callouts, since those are Rocket's unique beats.
- **Accept:** a fresh account finishes in under 2 minutes, and skip and rejoin behave correctly.

### Phase 4: Upgrades and ranks

- An **Upgrades** hut on the road, with a prompt that opens the panel. Each track maps onto existing tunables:
  - **Bulk Pickup:** more units per pickup tick (today: 1 per `MaterialHoldSeconds`).
  - **Bulk Place:** faster pour (`PourSeconds`).
  - **Placement Range:** `FrontierReach`.
  - Possible extras: Training Power and Carry Capacity.
- Price curves live in `Config.Upgrades`. Purchases are server-validated and idempotent per request ID.
- **Rank titles** (Apprentice → Mechanic → Engineer → Flight Director → Commander) come from lifetime deliveries and launches, shown above the name.
- **Accept:** a simulated first hour stays within the targets (first upgrade under 1 minute, then one every 3–5 minutes), and purchases survive rejoin with persistence on.

### Phase 5: Art, world and audio (your assets and Blender)

**Pipeline:**

1. Prefer CC0 sources (Kenney, Quaternius, Poly Haven, ambientCG). Log each asset in `assets/LICENSES.md` with URL, author, license and date.
2. Edit in Blender, keeping `.blend` sources in `assets/src/` (Git LFS if large). Use 1 unit = 1 stud and low poly counts: under ~10k tris for hero pieces and under ~2k for props.
3. Export FBX, import in Studio, and upload. Asset IDs go in `Shared/Assets.luau`; reusable models go in `.rbxm` under `world/` or `assets/models/`.
4. Gameplay keeps finding anchors by tag, so swapping art never touches logic.

**Content, in priority order:**

1. **Rocket kits:** replace the `RocketModels` primitive specs tier by tier with mesh segments (engines, body rings, fins, noses, tanks). Keep the per-segment fill behavior and the ~160-part budget.
2. **Scrap ball and jerry can** carry meshes.
3. **Scrap pit and oil refinery** hero pieces. They are already elaborate primitives, so mesh them last.
4. **Gyms:** bench and treadmill meshes, with tier colors as material variants.
5. **Environment:** desert or launch-site terrain, skybox, Atmosphere/Lighting presets, upgrades hut, and a Mission Control NPC.
6. **Animations:** carry, bench rep and treadmill run.
7. **VFX:** coin burst, `+N` icons, place sparkle. Launch smoke and fire already exist.
8. **Audio:** pickup, place, coin, training rep, level-up, countdown and launch roar, plus an ambient track.
9. **UI icons** for coin, speed, strength, shop, pets and upgrades in the chunky outlined style.

- **Accept:** side-by-side screenshots with the reference, and 60 FPS on a mid-range phone emulator with 8 players at Tier 5.

### Phase 6: Meta and social

- **Friend Boost:** +X% coins or training for each friend in the server.
- **Leaderboards:** in-world boards for top builders and launches using OrderedDataStore.
- **Destinations:** give each tier its own planet (Meadow → Moon → Mars…) with its own reward, in place of one Meadow.
- **Pets** (optional, only if retention data supports it).
- **Daily rewards and playtime gifts.**

### Phase 7: Monetization (after the journal in Phase 8 exists)

- **Gamepasses:** 2x Strength, 1.5x Speed, Quick Pickup, Quick Place and VIP.
- **Developer products:** "+N units" instant contributions and Robux upgrade prices.
- `ProcessReceipt` writes to the durable entitlement journal first, then grants the item, idempotently per `PurchaseId`.
- In-world signs plus HUD chips. Never sell another player's launch eligibility.

### Phase 8: Release hardening

- A durable pending-entitlement journal and fault tests.
- A published private persistence test with real accounts.
- Anti-cheat beyond the current horizontal-jump heuristic: rate caps on transfers and training.
- Performance: StreamingEnabled, part budget at Tier 5 with map expansion, and pooled VFX.
- Funnel analytics: tutorial steps, first delivery, first upgrade, first launch, D1 return.
- Closed playtest with 8+ people, then fixes, then public launch.

## 5. Suggested order

| Milestone | Phases | Playable result |
|---|---|---|
| M1 "Rewarding" | 0 + 1 | Coins, juicy training and delivery feedback |
| M2 "Looks like it" | 2 + 3 | Reference-style HUD and tutorial |
| M3 "Has depth" | 4 | Upgrades, ranks and a balanced first hour |
| M4 "Beautiful" | 5 (parallel, ongoing) | Art, audio and VFX |
| M5 "Sticky" | 6 | Friend boost, leaderboards and destinations |
| M6 "Ship" | 7 + 8 | Safe monetization and public release |
