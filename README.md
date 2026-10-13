# Rocket

A cooperative Roblox prototype: train strength/speed, gather Metal,
build one shared rocket, board together, visit Meadow, and unlock an advanced gym.
The server owns inventory, contributions, boarding eligibility, stats and rewards.

## Run the generated test place

1. Install Roblox Studio and [Rokit](https://github.com/rojo-rbx/rokit).
2. Clone this repository and check out `feat/first-playable`.
3. Run `rokit install` (Rojo 7.7.1 is pinned in `rokit.toml`).
4. Run `rojo build default.project.json -o build/Rocket.rbxlx`.
   Create `build` first if necessary.
5. Open `build/Rocket.rbxlx` in Studio. Start a **Server & Clients** test with
   **2 clients**. The server creates the test map when the game starts.

For live editing, install the matching Rojo Studio plugin, run `rojo serve`,
and connect the plugin to **127.0.0.1:34873**. The project pins this port so
Rocket can run alongside CityGang on 34872. Confirm the plugin shows **Rocket**
and **Disconnect** after connecting. For Team Create, the developer currently
syncing must disconnect Rojo before another developer connects.

Source files and generated geometry
are owned by Git. No hand-edited place or binary assets are required.
Rebuild the place after source changes when using the file workflow.

## First two-player scenario

- Hold a gym prompt for two seconds. Strength raises carry capacity by one
  per five levels (maximum five); speed adds 0.3 studs/sec per effective level
  (maximum 32). Training levels and planet bonuses each cap at 50.
- Each player picks up material at its source and delivers at the blue pad.
  The shared requirement is **6 Metal**, regardless of player count.
  Metal is the only material. Pickups reserve the remaining requirement across
  every player's cargo: delivered plus carried Metal can never exceed six.
  If all needed pieces are being carried, deliver them first. Leaving the server
  releases that player's carried pieces for pickup again. Each credited piece
  belongs to one player; completing the build leaves no excess cargo.
- When full, pickup and delivery stop. Stand on the green pad during the
  **20-second** countdown. The HUD confirms boarding; remain until departure.
- Leave one player outside the pad. Only the passenger visits Meadow and
  receives one completion and +1 strength/+1 speed bonus. The other player
  sees that they missed this launch. With no passengers, the cycle still resets.
- Return after six seconds, build again, and confirm a second cycle works.
  After one confirmed completion the advanced strength gym grants two levels
  per approved interaction instead of one.
- Use Roblox's player list for the server completion/delivery leaderboard.

## Persistence test setup

Persistence is **off by default**. Every HUD says progress is not permanent.
Memory-mode rewards still exercise the gameplay loop; they disappear on server
restart. Never interpret those checks as a production data-store test.

For actual saves, publish a separate private test experience, enable Studio API
access there, set `PersistenceEnabled = true` in `Config.luau`, and choose a
test-only `DataStoreName`. Never enable Studio API access against live player data.
Test with real accounts as well as simulated Studio players. After a confirmed
save, leave, allow up to 120 seconds for the session lease to expire, and rejoin.
Confirm training, bonuses, completions, lifetime deliveries and gate eligibility.
An active profile on another server is rejected rather than overwritten.

Each server serializes profile writes. Reward IDs and bonuses/completions commit
in the same `UpdateAsync`. Transient/ambiguous failures retry three times with
backoff, then retry at the 30-second checkpoint. Pending rewards remain in memory
for disconnected locked passengers. The HUD confirms a reward only after the
write succeeds. Unsaved training/deliveries remain visible as unsaved.

## Focused checks

Download the official Windows tools from [Luau 0.742](https://github.com/luau-lang/luau/releases/tag/0.742)
and extract them to `build/luau`, or install `luau` and `luau-compile` on your PATH.

```powershell
./tools/Test.ps1 -LuauDirectory ./build/luau
rojo build default.project.json -o build/Rocket.rbxlx
```

The script compiles every Luau file and runs real delivery/profile code with
assertions. A fake data store covers an outage, commit with lost response,
duplicate launch ID, changes during a write, disconnect/rejoin, corrupt data,
session ownership loss and bounded reward history. This verifies application
logic, not Roblox API behavior or multi-client networking.

In Studio also test: repeated prompts, triggering without a valid hold, cancelling
training/moving away, respawn, teleport attempts, pickup beyond capacity, delivery
after boarding begins, simultaneous final deliveries, joining during launch,
disconnect before/after passenger lock and a second launch. Validate UI at desktop
and phone sizes. The movement check rejects large horizontal jumps and invalid
positions; it is a first-pass heuristic, not complete movement anti-cheat.

## Private-playtest and release gates

- Two-client Studio and real published data-store tests are still required.
- If a server dies before a reward save is confirmed, its in-memory pending
  reward can be lost. An ambiguous write may already have committed; the next
  profile load shows the stored result. There is no durable pending-entitlement
  recovery yet. Before public release, implement a durable entitlement journal
  and fault-test termination before, during and after reward commit.
- Session leases intentionally remain for up to 120 seconds on disconnect;
  rapid moves between servers may see a load-in-use error. Same-server rejoin
  retains the existing record and pending rewards.
- Global boards, sounds/art and monetization are deferred. The server board
  works without an OrderedDataStore.

## Review workflow

The upstream repository was empty at startup: no `main` commit exists to use
as a PR base. Initial work is isolated on `feat/first-playable`; do not merge
without the second developer's review. Establish an agreed initial `main`
baseline, then open a draft PR. Subsequent changes use short feature branches.

The handoff and durable defaults are in `notes/`. The intended Obsidian mirror
is `C:\Users\Kyle7\Documents\gpt\Rocket`, a separate notes folder rather than
the source repository. Keep `TODO.md` and `SESSION.md` current after each session.

Security review baseline: [Roblox client/server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).
