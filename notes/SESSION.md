# Latest session: 2026-10-15, planet destination UI polish

- Head popups have lanes (`HudController` `lanes`): +Strength left, +Speed right,
  "Strength Level Up!" / "Speed Level Up!" raised 50 / 100 px via `Popup.world`'s new
  `shift` (BillboardGui.SizeOffset, pixel-stable). Meadow ticks no longer stack them.
- Speed icon is 👟 (`Theme.icon.Speed`).
- Progress pill: the inset is a rounded CanvasGroup and the fill is always ≥ one cap
  wide, sliding in from the left, so early fill grows as a smooth sliver (0.35 s tween).
- Material how-to toasts (cargo full, X placed!, pick up first, cargo cleared) show
  once per session, filtered client-side in `HudController`.
- Not verified in Studio (it was mid-playtest on another branch; no local compiler).

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
