# Latest session: 2026-10-14, Phase 0 client half + reference-style HUD

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
