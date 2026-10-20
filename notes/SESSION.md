# Latest session: 2026-10-20 (15), global leaderboards

- `claude/leaderboards` from master 590b77b. New LeaderboardService (categories, stands,
  merge/format, push/refresh/render loops, SurfaceGui panels) and LeaderboardCheck;
  SiteDressingService `leaderboardStand` replaces `siteOffices` at x = +/-50, z = 80
  (three 14x18 panels, faces tagged `Leaderboard`); Config.Leaderboards; Main wires
  start and leave. ProfileService `blackHolesVisited` + queueReward's `blackHole` flag
  (LaunchService passes it); PersistenceCheck covers one visit per Black Hole launch and
  legacy profiles.
- Studio: RunChecks 16/16; no SiteOffices left; panels west Strength/Speed/Coins, east
  Launches/Delivered/BlackHoles, left to right from the lane. Debug Black Hole launch:
  the board showed "fruitsalad6d9 = 1" ~33 s in, launches 5 -> 6. After the 2-minute push
  all six RocketTop_studio stores held the player (strength 98,864, coins 12,805, ...);
  the client sees all six 560x720 panels. No errors. Not eyeballed (MCP capture can't
  show runtime SurfaceGuis in Play); one player only, so no cross-server ranking seen.

# Earlier session: 2026-10-20 (13), planet stays x2 a tick at 4 ticks a second

- `claude/planet-ticks` from master 590b77b (#46 merged). Config.Planet: StrengthBonus /
  SpeedBonus 6, TicksPerSecond 4, GymGain 6 (destination gyms unchanged);
  RewardSaveSeconds 1. LaunchService's stay loop ticks at 1/rate, feedback and broadcasts
  once a second. ProfileService: `Profiles:preview(record)` adds pending ticks to
  planetBonuses (record.preview), saves subtract it from the snapshot and recompute after;
  queueReward schedules one save per RewardSaveSeconds. PersistenceCheck covers preview,
  throttle and no double count; DestinationCheck 6 a tick / 4 a second; ProgressionReport
  uses the tick rate.
- Studio: RunChecks 15/15. Debug Moon launch (stay 12): client strength rose +6 every
  ~0.26 s, 48 steps = 288 (24/s); feedback "+24 strength / +24 speed (n/12)" once a
  second; stored DataStore total (98,654) matched live, launches 4 → 5. No new warnings
  (PersistenceCheck's own negative cases only). Two test Moon launches went to the
  Studio store (launches 3 → 5).

# Earlier session: 2026-10-20 (12), launches-only ranks

- `claude/happy-poitras-d42432` from master 0e64806. `Config.Ranks` is ten launch-only
  tiers (Intern 0 .. NASA CEO 100); `Upgrades.rank(config, launches)`; RankTag 280 wide.
  UpgradeCheck walks the ladder. `notes/RANKS.md` documents the system.
- Studio (scripts matched master before Rojo on 34873): RunChecks 15/15; debug launches
  4/5/10/64/65/99/100/250 gave INTERN, ROCKET TRAINEE, MECHANIC, MISSION COMMANDER,
  LAUNCH DIRECTOR, NASA DIRECTOR, NASA CEO, NASA CEO on attribute and tag; client draws
  "MISSION COMMANDER" 211 px wide. Test profile put back to 1 launch. No server errors.
- Nameplate: RankTag is now "🚀 N" pill + rank title, display name below, and the
  Humanoid's own name is hidden. Studio: RunChecks 15/15; at launches 1/42/100:
  "🚀 1 | INTERN", "🚀 42 | LAUNCH SPECIALIST", "🚀 100 | NASA CEO", name row
  "fruitsalad6d9"; client layout badge x82-121, title x127-198, name y30-54 in a 280x54
  tag; no client/server errors. Not eyeballed: MCP screen_capture skips BillboardGuis.
- Pets: removed the rarity GlowRing under Rare+ pets (PetController). Studio Play with
  Uncommon/Rare/Legendary out: 0 GlowRing parts, no client errors.

# Earlier session: 2026-10-20 (11), gyms tick 3x a second, scattered popups

- `claude/gym-ticks` from master 86227c3. `TrainingSeconds = 1/3`; GymSignController
  shows gain / TrainingSeconds; Main's training `changed` uses Cycle.sendSoon; HudController
  scatters gain popups (MIN_GAP 45). TrainingCheck: 3 ticks a second, top gym 300/s.
- Studio: RunChecks 15/15; on the 100x bench 1,000 strength in 3.4 s (~297/s), tag
  "+300 STRENGTH / SEC", signs "+150/s" (50x) and "+15/s" (5x); popups landed at
  (-37,56), (-127,-18), (-13,73), (-84,52). No errors.

# Earlier session: 2026-10-20 (10), walk speed to 400

- `claude/walk-speed-400` from master 85e658e. Config `SpeedEarly`/`SpeedPerLevel`/
  `MaxSpeed = 400`, `StatLevels.walk` capped; MovementService limit per player
  (`MoveLimitFactor` 1.5, `MinMoveLimit` 70); new `SpeedController` turns tripping off.
  TrainingCheck pins the curve (29 / 121 / 243, 400 at ~560, never more).
- Studio: RunChecks 15/15. At 400, before the fix the run tripped (FallingDown) and was
  snapped back 21 times in 3 s; after, 465 studs in ~1.2 s, no snap-backs, Running.
- Not checked: carrying up the rocket ramps at 400 (players may overshoot the ring).

# Earlier session: 2026-10-20 (9), Robux SHOP (merged with the spaceport / Black Hole / parkland work)

- Merged `claude/partner-latest-f117d18` (10 unpushed commits: spaceport, launch anywhere,
  Black Hole singularity and audio, Gym District parkland) into this branch. Audit first:
  nothing in them deletes, clears or rewrites existing work (ParklandService and
  SpaceportService only add non-colliding scenery; SiteModels.rbxm grows 198 KB → 720 KB).
  Conflicts: Main.client controller list (both kept), DebugService header (both), the
  reward loop in LaunchService: the singularity now fires once when the possibly
  extended stay has SingularitySeconds left, and closes the shop's stay so time bought
  during it goes to the next stay. Studio: 108 scripts identical to the branch,
  RunChecks 15/15, no errors, ~10.9K parts; a Black Hole trip with +60 s bought on
  arrival ran the extended stay, the singularity, the reset and the next build.

- `claude/frosty-goldstine-93fa70` (from master f117d18). `Config.Shop` (IDs nil until the
  user sends them; recommended prices), `Shared/Shop.luau` (catalog, `available`, pet
  slots), `ShopService` (BuyShop remote, pass sync on join + PromptGamePassPurchaseFinished,
  ProcessReceipt with the `RocketReceipts` journal, server effects), `ShopCheck`.
- Hooks: TrainingService (`unlocked` for gym passes, `multiplier` for the boost; stations
  and signs carry `GymTier`), CargoService (2x coins via `Profiles.credit` multiplier),
  LaunchService (stay is a growing `while` loop; a guaranteed mission replaces the spin),
  PetService (slots, hatch rate, up to 3 UFOs at once), `Rocket:fill`, Cycle snapshot `shop`.
- Client: ShopController (🛒 SHOP under the stat stack, 2x TRAINING chip, panel with
  passes / gym access / boosts; fill row above the pill; destination side panel), UFO shop
  status shows UFOs flying (no price switch), backpack slots from `state.shop.petSlots`, gym signs unlock by pass. Toasts
  moved up (-132 / -168) to clear the fill row.
- Studio debug: `RocketDebug:Invoke("own", key, on)`, `("receipt", key, purchaseId)` and `("board")`.
- Studio (synced on 34875, all 102 scripts identical to the branch): RunChecks 13/13 (PetCheck's
  "too many equipped" case is now 7). Play: Fill10 receipt added 4,850/48,500 once (same PurchaseId
  again: granted, no second fill); boost chip counts down; owned passes show OWNED, gym 5X
  unlocked by pass; banked ExtraStay made the next stay 180 s. Second play (after Studio
  dropped once): as a passenger (`RocketDebug:Invoke("board")`) the destination panel shows
  +60s and the five missions with prices and "🔒 NEXT: SATURN'S RINGS"; an ExtraStay receipt
  mid-stay took the countdown 104 → 163 s; the wheel then landed on Saturn and the next
  rocket was Saturn. No script errors; the journal fell back to memory (Studio API access off).
  Not tested: real Roblox prompts (no IDs yet).
- Saving on (user): live `RocketProfiles_v1`, Studio `RocketProfiles_studio` with a no-access
  fallback; lease released on leave, locked loads wait and retry; user IDs on keys; Robux
  UFOs saved (PurchaseId in the ledger) before PurchaseGranted. New PersistenceCheck (fake
  store). Studio: RunChecks 14/14; with API access off the player loads unsaved and the HUD
  says so. Real round trip (user enabled Studio API access): 4,321 coins, all 50 pets and two
  UFOs (one from a Rare UFO receipt, saved before PurchaseGranted) were saved, Play stopped,
  and the next Play loaded them straight back (HUD "Progress: Saved"; the shutdown save had
  released the lease, so no wait). Not tested yet: a published server hop with two accounts.
  The Studio store (`RocketProfiles_studio`) keeps this test data for the user's account.
- Robux UFOs (user IDs): Rare 349 (plus 50K coins), Epic 549, Legendary 649. GetProductInfo
  matches. UFO shop rows show purple R$ buttons. A Legendary receipt via the debug hook gave
  one UFO (repeat PurchaseId: no second). RunChecks 13/13. Persistence is still off, so a
  bought UFO's pet is lost on rejoin (see DECISIONS).
- Triple Hatch reworked (user): up to 3 UFOs at once at normal prices (was 3 pets per UFO
  for 3x coins). `profile.ufos`, `Ufos` attribute, PetController draws one saucer per UFO
  (three perches) and 6 follower slots. Studio: three debug UFOs drawn together, landed one
  by one, three pets followed; RunChecks 13/13; no errors.
- Pass IDs in (user): all 12 shop Game Passes. GetProductInfo in Studio: each is a Game Pass,
  for sale, name and price matching Config (Triple Hatch 249). In Play the creator's account
  owns every pass (Roblox gives the creator their own passes), so all show OWNED: the join sync
  works with real IDs; a real purchase needs a non-owner account. RunChecks 13/13.
  Product IDs in (user): all 11 Developer Products; GetProductInfo matches every name and price.
  Real flow: the user clicked +2,000 in Play and bought it (Studio test purchase): ProcessReceipt
  ran through the journal (memory fallback, Studio API access off) and Metal went 0 → 2,000, once.
- Fills are flat (user): +2,000/4,000/7,000/11,000 (R$ 25/45/75/109) of Metal or Fuel. Studio:
  Fill2000 → Metal 2,000; Fill11000 near full finished Metal and put 8,150 into Fuel; Fill7000
  → Fuel 15,150; repeat PurchaseIds not regranted; a fill while boarding banked 4,000; fresh
  round Fill4000 while fueling → Fuel 4,000; buttons show ⛽ while fueling. RunChecks 13/13.
- Gyms re-tiered (user): free 1x, then 2/5/10/25/50/75/100x; passes 49/129/249/449/699/899/1099.
  Studio: signs read FREE..100X, shop cards show the new prices, RunChecks 13/13.
- Offers without IDs show their price greyed (was "SOON"); the fill row hides under the open panel.

# Earlier session: 2026-10-20 (3), parkland round the Gym District

- `ParklandService` (built by SiteSurroundsService into Land, so it shows to 7,000):
  the land round the Gym District (z > 112, never covered by expansion). East: running
  track with pitch, goals, stands, floodlights; a farm (crop strips, barn, silo, fence).
  West: a centrifuge whose arm turns (WindTurbineRotor tag, SpaceportController) with a
  booth; a training pool with a mock capsule and gantry; a pine wood with a campsite
  (fire, tents, logs). Behind: a lake of overlapping glass discs on a sand shore, jetty,
  boats, reeds, rocks, benches; 14 rolling grass hills (a near row and a bigger far row
  toward the mountains and out to the sides), an observatory on the highest, a broadleaf
  band and big trees in clumps over the hills (big enough to still draw from the gyms).
  `Parkland.Clear` keeps the plain's random trees and clutter off it. About 2,260 parts.
- Seen from the gyms at player-camera height (26 up): back (lake, hills, observatory,
  mountains), east (track, farm, turbines, water tower) and west (pool, centrifuge,
  pines, comms dishes). At eye height the 10-stud hoarding still hides the near ground.
  RunChecks 13/13, no errors. Studio was reopened mid-session (new studio id).

# Earlier session: 2026-10-20 (2), launch anywhere and the Black Hole's singularity

- `RocketDebug` "launch" (DebugService, Studio only): from Building/Fueling, swaps in the
  chosen mission, fills both phases, moves every player into the cabin and launches
  after a short countdown; `stay` shortens the reward stay. Studio chat `/launch
  blackhole [countdown] [stay]` (TextChatCommand) or `tools/debug/launch.luau` in the
  command bar. LaunchService reads `service.debug` (cleared when that flight resets).
- Black Hole: red warning beacons blink round the shard's rim and three more streams
  tear off its edge (DestinationService). `BlackHoleController` (client): while on the
  shard the hole swells 25% over the stay, the light drains violet, a drone (the engine
  cue pitched down) rises, tremors shake the camera more often and harder toward the
  end, and lightning cracks off the horizon (reducedEffects skips shake and bolts).
- Singularity: LaunchService stamps `SingularityAt` on the BlackHole folder 4 s before
  the stay ends (just after the wheel stops) and anchors passengers; each client hides
  the characters, spirals stand-in copies into the hole shrinking, drags the camera in
  (FOV 70 -> 120, blur, desaturation) as the hole balloons, flashes white then black;
  the server's usual reset moves everyone to spawn (and unanchors them) and the black
  fades. The camera is marked Cinematic so CameraController steps aside.
- Revised singularity (7.5 s, LaunchService.SingularityLength; the reset waits it out):
  every ScreenGui (HUD, wheel, toasts) is off while it runs; the landed rocket is dragged
  in first, tumbling (0-2.6 s), then the whole shard and every character on it (all
  anchored RocketWorld parts within 320 studs, BulkMoveTo; characters PivotTo, their
  roots held by the server) spiral into the swelling hole (1.8-6.4 s) with the camera
  riding the shard, then white flash, black, home. The client puts the shard back once
  the server has moved the player > 5,000 studs (the ride itself carries them ~2,000,
  which first tripped the "still there" test and ended it early). No stand-in copies.
- Black Hole audio: the user's Pixabay downloads (freesound_community "space hole test"
  23665 and "earth rumble" 6953). `ambience/black-hole` replaces the space music there
  (MusicController's AMBIENCE mood "blackhole", for passengers bound for or at the Black
  Hole); `game/rumble` is the hole's looped voice, the tremor swells and the
  singularity's groan (BlackHoleController, SFX group). Built here with Blender's `aud`
  (no ffmpeg on this machine) as 48 kHz mono looped OGG, and registered in build.py's
  MANIFEST (sources expected in Sounds/freesound/<name>.mp3). NOT UPLOADED: no
  ROBLOX_API_KEY here, so they play in Studio only (copied to Studio's
  content/sounds/rocket) until `tools/sounds/upload.py` runs with the key.
- Studio: two full Black Hole runs via the debug launch (arrival, singularity, home,
  rewards credited), sampled the pull numerically; RunChecks 13/13, no errors.
  Rojo sometimes lands edits a moment after Play starts: restart Play if the server
  still runs old code.

# Earlier session: 2026-10-20, spaceport round the launch site

- Branch `claude/partner-latest-f117d18` from master f117d18 (#42). User: the apron
  behind the rocket was empty and the land round the site was just meadow; fill it from
  Kenney's space, modular space and space station kits with Blender, own direction.
- Measured: every tier's 45-degree rocket clears the apron behind the pad (z < -440) by
  230+ studs (raycasts up from a grid, all five tiers), so props there are capped at 150.
- `SpaceportService` (built after SiteDressing): on the apron, a walk-in Mission Control
  of modular rooms (4 studs per metre, walls 17 high, rooms meet door to door) on the
  centre line, five landing pads with parked craft to the east, hangars and rovers to the
  west, frames and spare stages at the far end, and a monorail down the west edge over
  the back fence. Beyond: a campus slab past the back fence (a 270-stud display rocket,
  hangars joined by corridor tubes, dish array, tank farm, the monorail's train), a comms
  array west and assembly hangars east (|x| > 690, outside the widest site). Trees keep
  off the slabs (the tree placement changed as a result).
- Import: `tools/map/bake_spaceport.py` (Blender 5.2, CLI; the Blender MCP extension
  wasn't loaded) baked three FBX files; the user imported them; `prepare_spaceport.luau`
  merged 115 models into SiteModels (155 now). New palettes: Space 71738999329000,
  Modular 126762679417470.
- Studio: RunChecks 13/13 with the new SpaceportCheck; no errors. Seen from above, the
  apron at an angle and the campus from the fence.
- Round two: `SpaceportController` runs the monorail train (its own MonorailTrain
  model) from the campus station to the apron end and back on the server clock (28 s
  each way, 10 s waits), so every client sees it in the same place. Mission Control is
  furnished from parts: a holo table with four consoles (ops room), two rows of desks and
  two wall screens (launch room, screens between the wall's pillars), bunks, lockers and
  a mess table (crew quarters), a console in each front wing. Signs (SignService boards):
  MISSION CONTROL over the gate, LANDING PADS (pads painted 1-5), HANGARS, MONORAIL,
  SPACEPORT CAMPUS and CAMPUS STATION, COMMS ARRAY, ASSEMBLY.
- Gotchas: Box collision made each solid room one block, so Modular_* models are stored
  with PreciseConvexDecomposition (SiteModels re-saved); the modular corridor runs along X
  (it walled off the doors until turned 90); gate-lasers blocks the door (plain gate now).
  Walked spawn -> gate -> every room in Play (Humanoid:MoveTo; anti-teleport snaps
  PivotTo moves back).
- Round three: Mission Control roofed (flat roofs on every room and corridor at y 18,
  parapets, glass skylights over the bigger rooms, two ceiling lamps each; the two
  `-variation` rooms swapped for plain ones so every footprint is a rounded rectangle,
  listed in `Spaceport.Rooms`), with dishes, generators and vents on the roofs. Fields:
  a solar farm west and a tank farm, container store, hangars, parked craft and water
  tower east, on the meadow the site grows into (`Spaceport.build` returns `fit(edge)`,
  called with the perimeter on every expansion, which clears filler the ground reaches);
  16 wind turbines beyond everything (rotors turned by SpaceportController).
- Render distance: nothing in the game hides the spaceport (DestinationController only
  culls destinations and the cabin; Earth has no haze). Graphics quality is Automatic,
  and a captured frame right after a camera jump showed only nearby geometry, filling in
  a few seconds later; at ~2,000 studs medium meshes stayed culled while the mountains
  drew. That's Roblox's quality-based draw distance; scripts can't set it (needs
  RobloxScript). Studio measured 15 FPS throughout, unchanged by hiding whole areas, so
  likely background-window throttling, not the scene. Indoor furniture no longer casts
  shadows.

# Earlier session: 2026-10-19 (8), visual tidy pass

- `claude/visual-tidy`. Earth: `tools/site/textures.py` builds dirt, asphalt, concrete,
  grass and gym-floor overlays (uploaded, ids in Planets TEXTURES; need experience
  access), laid on the ground, roads, apron, pad, plain and Gym District, each with a big
  tinted maria blotch layer so the tiling doesn't show from afar. `UpgradeShop` replaces
  the green box: a garage (brick and plank walls, pitched roof with the sign on the
  gable, open roll-up door, awning, lit interior; the tagged UpgradesHut part is now the
  counter, and the prompt and panel still work: checked). `SiteDetails` adds puddles,
  gravel, ruts, weeds, kerbs, manholes, crosswalks, road patches, pad hazard lines and
  stains (none collide; scatter keeps off roads, stations, huts, spawn, apron, District).
  The Gym District has brick walls with caps, trimmed rubber bays, a textured walkway,
  chevrons, lamps, planters and benches. UFO shops (all six) got blinking pad lights, a
  rounded kiosk and pet eggs. The plain got broadleaf trees, bushes, rocks and flowers.
- Destinations: the arrival spot is a dark landing pad with a ring, chevrons and a
  beacon in the destination colour (was a glaring neon disc); the bonus gyms sit on
  gold-trimmed outpost mats with lamp posts, on dark plates. The cabin got panelled,
  ribbed walls, sloped ceiling corners, padded seats with headrests and harnesses,
  framed starry portholes, an aisle runner with lights, consoles, a bezel, pipes and
  vents, and a striped exit hatch with a wheel and EXIT light.
- Gotcha: `Enum.Material.CorrugatedSteel` doesn't exist; the error stopped the build
  half way (the workshop came out with no roof). WedgeParts rise toward +Z.
- Uploads needing access: dirt 84661666848501, asphalt 93816747599509, concrete
  90203920386352, grass 95172590517271, gym floor 100327531950364.
- Studio: RunChecks 12/12 (DestinationCheck covers the cabin aisle and walls).
- Second round: the Salvage Yard floor is textured, with oil slicks, floodlights in the
  back corners, hazard sleeves on the gate posts and warning plates on the fence; the
  Fuel Depot pad is textured, with a hazard kerb, painted bays round the dispenser
  islands, fuel stains and bollards. Standing signs (`Signs.board` with ground: the
  welcome signs and the COMING SOON boards) got concrete footings, back braces and a
  lamp bar. The gravel patches are Slate (Pebble rendered bright beige). The user
  granted the five site textures; merged as #42.

# Earlier session: 2026-10-19 (7), loading screen

- `claude/loading-screen`. `src/ReplicatedFirst/LoadingScreen.client.luau` (the project's
  ReplicatedFirst now maps to `src/ReplicatedFirst`; the empty world/ReplicatedFirst.rbxm
  is gone). It removes Roblox's screen and shows the user's title art (uploaded
  133247550435220; needs experience access, Studio falls back to
  content/textures/rocket-loading/loading.png; the source is assets/loading/loading.png)
  with a slow zoom, a shuffled tip card (20 tips and jokes, every third badged FUN FACT),
  a status line, and a gradient progress bar with a rocket riding its tip.
- Steps: game loaded, then RocketWorld's Built attribute (the bar creeps meanwhile: in
  Studio the server takes ~10 s to build the destinations), then PreloadAsync of every
  textured, meshed or sounded instance in the world and PetModels plus the SFX (by
  instance, one per file: bare id strings get fetched as images and spam "asset type
  does not match"), capped at 25 s, then ClientReady and holding the root anchored until
  a ray finds ground. At least 5 s on screen, then a 0.6 s fade.
- Server (Main): `Players.CharacterAutoLoads = false`; ClientReady spawns the character
  (LoadCharacter, guarded); a 45 s fallback spawn; respawn after death (RespawnTime),
  since auto-respawn went with auto-loading. World sets `RocketWorld.Built` once every
  service is built. RemoteService adds ClientReady.
- Verified in Play: no character until ClientReady (11.5 s in Studio), spawned 0.4 s
  after, standing on the spawn (never below y = 4); respawn 5.5 s after death; RunChecks
  12/12; no asset-type spam.
- The user granted the art access; merged as #41. The art's load check goes through the
  ImageLabel: `PreloadAsync` on the bare id string reported Failure even with access.

# Earlier session: 2026-10-19 (6), music

- Planet PRs #34-#38 squash-merged into master. Music on `claude/music`.
- The user's MP3s (HoliznaCC0 lofi, CC0) sit in `assets/sounds/Earth Music` and
  `assets/sounds/Space Music` (not committed). `tools/sounds/music.py` loudness-matches
  them (two-pass loudnorm, -20 LUFS, linear; the sources ranged -9.8 to -17.3) into
  `assets/sounds/music/<earth|space>/<slug>.ogg` (stereo Vorbis q3, 12 MB) and writes
  `Shared/MusicTracks.luau`. `--studio` copies them for local play. build.py now leaves
  music/ alone and skips the MP3s when copying to Studio; upload.py labels music.
- Uploaded by the user with `tools/sounds/upload.py` (ids in Shared/SoundIds; checked
  playing from the asset in Play). Merged as #39.
- `MusicController` (client): shuffle bags per mood (each song once before repeats, no
  song twice running), 6 s crossfade into the next song, 3.5 s fade out and 5 s fade in
  on mood changes. Mood from the state snapshot plus the LandedRocket's DescentAt:
  passengers get silence from liftoff, space music from the start of the descent through
  the stay, Earth music again on return; players left on Earth hear it dip to 30% while
  the rocket climbs. Song volume 0.4 under the Music SoundGroup; the default Music
  setting is now 0.5 (was 0.6). The player folder is `SoundService.MusicPlayer` (a
  folder named "Music" would shadow the SoundGroup in Settings.group).
- Studio Play verified: crossfade (Ode To Forgetting into Tokyo Sunset over 6 s),
  boarding, then silence at liftoff, then Dreamshifter fading in at the descent, the
  crossfade back to Earth music on return, and the dip for a non-passenger. RunChecks
  12/12.

# Earlier session: 2026-10-19 (5), Saturn rework, then the Black Hole

- Black Hole on `claude/planet-blackhole` (stacked on Saturn). Builder 5: a glossy black
  glass shard (Basalt went sandy under warm light) with violet fissures cut in and
  breathing, faint violet veins (Europa's lineae texture, tinted), a rim of obsidian
  blades and an underside of hanging blades round a lumpy core, crystal clusters, an
  observatory scope and dish aimed at the hole, floating turning shards, violet motes.
  The hole at (700, 330, -1100), horizon radius 210: a black Neon ball; the accretion disk
  (tipped 12 degrees off edge on) and the lensed halo (square to the player) are nested
  flattened sphere-mesh discs, each smaller one thicker so it bulges through the next
  (white-hot to deep red). 26 hot clumps orbit the disk faster further in, twin jets with
  a faint sheath, four Beam streams spiralling in (one from the shard's edge), and 140
  debris shards wheeling about the hole (those passing near the platform only spin).
  The sun stands exactly behind the hole (ClockTime 7.7, latitude -32, found by search),
  so the disk is the light; Skies "BlackHole" uses the band sky with violet fill below.
- **Server-made CSG rings drew unreliably on clients here**: the disk's MeshPart bands
  (from `Planets.rings`) were invisible in Play, with or without anything in front, while
  a client clone of the same part drew, and re-parenting one made it draw. Saturn's
  identical rings drew every time. The Black Hole now uses no CSG for its disk; if
  Saturn's rings ever go missing, that's the cause (a client-side re-parent on show, or
  nested discs with an opaque dark Cassini band, would fix it).
- Concurrent CSG cuts gave no speed-up, so `Planets.rings` cuts one at a time.
- `scatter` (only the old Black Hole used it) is gone. Full destinations build: ~3.4 s.
- Studio: RunChecks 12/12; in Play the disk, clumps (77 studs/s), debris orbits and the
  return home all verified. No new image uploads for the Black Hole.

- Saturn rework on `claude/planet-saturn` (PR #37), after the user's feedback: the ring
  plane is no longer an opaque banded floor. Three see-through layers of ring particles
  (`ring_speckle`, alpha) lie at 46, 60 and 76 below the platform, each a 4 x 4 grid of
  invisible 2048-stud tiles (out to the horizon), scaled 256/512/1024, their textures
  drifting at different speeds (tag TextureDrift, PlanetController). The sky shows the
  rings edge on as a glowing horizon line with stars below.
- Saturn now hangs fully above the horizon at (-1500, 400, -1700), 41 degrees left of the
  arrival so a landed Tier 4-5 rocket doesn't hide it, its pole tipped 28 degrees toward
  the player so `Planets.rings` (six annuli cut by CSG from the flattened sphere mesh:
  smooth, unlike CSG cylinders) open into a wide ellipse. The rings are dark Neon, since
  the low sun left SmoothPlastic rings a dull grey-brown. The ring shadow is painted onto
  the Saturn texture. Each ring band costs about 0.45 s of CSG, so Saturn builds in
  about 2 s.
- Tried and dropped: one annulus wearing a radial ringlet texture (the cut keeps the
  sphere's UVs, latitude = radius) came out stair-stepped: too few latitude rows.
- `Planets.mound` is now a sunk ellipsoid of the sphere mesh: big sunk Ball parts showed
  as flat polygons (Saturn's frost drifts looked like white squares). This smooths the
  crater walls, talus and drifts on every destination.
- New uploads needing access: Saturn 72973342803379, ring speckle 118246725794362, sky Bk
  96836179595217, Dn 70901967949717, Ft 111141752494092, Lf 94514358915591, Rt
  117806823065119 (Up unchanged). `ring_sheet` is gone.

# Earlier session: 2026-10-19 (4), Saturn's Rings

- `claude/planet-saturn`, stacked on Europa (PR #36). Europa's images have access.
- Saturn (`DestinationService` builder 4): the platform is one big ring particle:
  frosted rock (ring_rock overlay) over a lumpy underside of ellipsoids (`Planets.blob`)
  that bulges past the edge, with a lip of frosted boulders. On it: crystal clusters with
  breathing cores, frost drifts, ice lumps, a lighthouse whose beam sweeps two ways
  (spinning neon bar with spotlights), an ice harvester with a sled of glowing blocks,
  and a crew pod tethered to pegs. No plain or mountains: the ring plane is four
  2048-stud tiles 60 below the top (`RING_PLANE`), a dark field crowded with ice
  particles in bands, and the sky (`saturn_sky`) carries the same bands on past their
  edge (its plane is darker than the sheet's texture, since the sky is never shaded). 150
  ice chunks of every size float all round, sliding along X faster the further they
  are from z = 0 (tag RingDrift, wrapping within 1400 of the centre) and tumbling; ones
  near the landing line stay below the platform. Saturn (1700 across) rises out of the
  ring plane beyond the landing site, Enceladus (tiger stripes) orbits across the sky,
  and hazy Titan hangs far off. Glitter drifts over the platform.
- `orbitingMoon` (shared by Mars and Saturn) and `isClear`'s edge argument moved to
  module level; the unused `band` helper is gone.
- Uploads needing experience access: Saturn 92757706712119, Enceladus 84183449209134,
  Titan 95534044250868, ring sheet 79775712039680, ring rock 97315882149044; sky Bk
  128681954064565, Dn 121094191642894, Ft 114895300719628, Lf 117925321081193, Rt
  73948970098985, Up 125914376227514. (Earlier uploads of the sheet and sky, 875545...
  and 940106.../126629.../839926.../816123.../815170..., are unused.)
- Studio: RunChecks 12/12. In Play: chunks drift at their set speed, the beam sweeps,
  Saturn behind the landed rocket, and Earth's lighting restored on the way home.

# Earlier session: 2026-10-19 (3), Europa

- Moon and Mars pushed as PRs #34 (to master) and #35 (to `claude/planet-moon`). Europa
  is `claude/planet-europa`, stacked on Mars. The imported sphere model was removed
  from Workspace (the planets load the mesh by id).
- Europa (`DestinationService` builder 3): crevasses cut into the ice (CSG, 2 deep,
  walkable) with pulsing glowing water at the bottom; five geyser vents on little ice
  cones (carved bowls with rims), still tagged GeyserVent for the planned mechanic; a
  drilling rig over a hole to the glowing ocean (railing plus an invisible guard; the
  probe and cable bob, tag Hover), a crew pod with crates, and ice chunks and frost
  drifts. Beyond: a snow berm, double ridges, four fields of jumbled ice rafts, three big
  geysers on cones out on the plain (Scale 4), pointed ice blades (two mirrored wedges)
  in front of a ring of icy peaks, a giant Jupiter (1100 across, Great Red Spot painted
  into the SBS texture, turning) rising behind them, and Io orbiting Jupiter, crossing
  its face on the near side. Ice crystals sparkle down over the platform.
- PlanetController: geysers erupt every 7-15 s (a crystal jet and a vapour column, sized
  by Scale, with a wisp between), and Pulse glows breathe.
- Sky: `Skies` "Europa" uses Kenney's "dark" skybox (cut with cubemap.py `dark`) with a
  small cold sun from +X (Jupiter half lit), glossy ice, and an orange ColorShift_Bottom
  for Jupiter-shine. ColorShift_Bottom joins the managed lighting keys (Earth's is black).
- Uploads needing experience access: Jupiter 138703120001562, Io 92758180219133,
  ice 124873466873497, dark sky Bk 135698275869633, Dn 89429151521851,
  Ft 112325889790250, Lf 134675348379561, Rt 116080667193829, Up 104136192848757.
- Rojo dropped the last of four quick edits to PlanetController once (Studio kept the old
  source and Play ran without geysers). Touching the file didn't resync; a real edit did.
  Compare sources (serve `src/` and diff from the Edit datamodel) before a Play test.
- Studio: RunChecks 12/12. Seen in Play: Jupiter half lit, Io crossing it, the glowing
  drill hole, crystals, crevasse glow and geysers erupting.

# Earlier session: 2026-10-19 (2), Mars

- One branch per planet, stacked: `claude/planet-moon` (8219051), then
  `claude/planet-mars` on top of it (Mars uses Moon's Planets module). The user imported
  the sphere: `Planets.SphereMesh` = 101153315842104.
- Mars (`DestinationService` builder 2): a base on the rim of a canyon. The canyon runs
  along X beyond the landing site (`CANYON`: near rim 95 toward -Z, three terraces down to
  114 below the plain; the plain is 130 thick), cut by `Planets.subtract`, with the
  strata texture on the plain's four side faces. Layered, lobed mesas and buttes close the
  horizon (ones in the canyon rise from its floor). Also: buttes, dunes and fallen rock in
  the canyon, dune fields on the plain, a sand berm round the platform (left open on the
  canyon side, `keep`), white habitat domes with an airlock, a greenhouse with pink grow
  lights, a solar array, a mast with a beacon, a six-wheeled rover with tracks, and a
  hovering helicopter with counter-turning rotors.
- Moving parts (PlanetController): Phobos and Deimos orbit (tag PlanetOrbit) on tilted
  circles round a point below the ground, peaking at 37 and 28 degrees over the canyon;
  dust devils wander the plain (tag DustDevil); the helicopter bobs (tag Hover). Wind dust
  blows across the platform.
- Sky: `Skies` set "Mars" uses a procedural sky (textures.py `mars_sky`, cut with
  `tools/sky/cubemap.py`), warm afternoon light (sun in the west) and a thin Atmosphere.
  The first Atmosphere settings (Density 0.3, Haze 1.4, a dark Decay) turned the far mesas
  blue-grey; Density 0.22, Haze 0.6, Glare 0 with tan colours keep their colour. Earth's
  lighting comes back, with no haze (checked in Play). `surroundings` gained `keep`, `cut`,
  `horizon` and a coloured `ridge`; the other destinations keep their random sequence.
- Uploads (k_b4nd0) that need experience access: Mars sky Bk 116733246444349,
  Dn 112767906081295, Ft 96691941054366, Lf 134366695000385, Rt 77374313685282,
  Up 139021632660213; ground 112067650457008, strata 97408578392069, Phobos
  104118206737090.
- Studio caches rbxasset:// textures by path: after regenerating a file, preview it under
  a new name (I used `*_v2` copies) or it shows the old image.
- Studio: RunChecks 12/12. Flown to Mars in Play: rotors, hover, dust devils, Phobos's
  orbit and the return home verified. Mars builds in about 0.3 s, 786 parts.

# Earlier session: 2026-10-19, planet overhaul starts with the Moon

- Working tree on master (84319bc), not committed yet. Goal from the user: destinations
  that look less flat and feel alive, using the SBS planet texture pack (CC0, uploaded to
  `assets/models-textures/sbs_-_planet_texture_pack_*`). Moon first.
- `Services/Planets.luau` (new, shared by future planets): textured globes (UV sphere
  MeshPart + ForceField atmosphere rim, spun by the client), CSG crater bowls with
  continuous raised rims (`carve`), sunk-ball mounds and rounded boulders, texture
  overlays. Intermediate CSG steps use Box collision: precise decomposition on each step
  took 12 s; the whole Moon now builds in about 0.3 s.
- Moon (`DestinationService` builder 1): carved, rimmed craters you can walk into, regolith
  overlay, rounded rocks, Apollo-style lander (blinking beacon), flag on a rod, science
  station, boot prints, drifting dust motes. Beyond: a low crater wall, a plain with 12
  carved craters and maria/regolith overlays, two rows of rounded highlands
  (`Mountains` `dome` option), and a textured cloudy Earth (earthrise over the hills,
  half lit). `surroundings` gained ridge/round/craters/overlays/farRing options; the other
  destinations are unchanged (same random sequence).
- Lighting: `Skies` sets may carry `lighting` and `moon = false`; the Moon set is a low hard
  sun (ClockTime 7.3, ShadowSoftness 0.04, dark ambient) for long shadows. Earth's own
  values come back on the way home (checked in Play).
- `PlanetController` (new, client): spins PlanetSpin parts, flashes Blinker lights,
  meteors over destinations with a Meteors attribute, and low-gravity foot dust on
  destinations with a Dust colour.
- Textures: `tools/planets/textures.py` (Earth with baked clouds, moon regolith and maria
  overlays; `--studio` copies for `Planets.LocalPreview`). Uploaded to k_b4nd0: Earth
  98936869274892, regolith 95330664069444, maria 131900343409098. **They need experience
  access** like the skies did; until then Play shows the Moon untextured.
- Sphere mesh: `tools/planets/sphere.py` writes a clean 96x48 UV sphere
  (`assets/planets/planet_sphere.fbx`); the user imported it: `Planets.SphereMesh` =
  101153315842104. (Free Creator Store spheres shaded a dark seam and pinched poles.)
- Found: SpecialMesh `Sphere` renders as a cube in this Studio build, and MeshPart
  TextureID ignores alpha (a cloud shell rendered as an opaque white ball).
- Studio: RunChecks all pass (12/12, MaterialInteractionCheck included). Flown to the Moon
  in Play: lighting, spin, blink, meteors, foot dust and the return home all verified.

# Earlier session: 2026-10-18 (6), Kenney props on the Earth site

- Branch `claude/earth-props` from master (bfce87f). The user imported the staged
  factory and station FBX files and uploaded their palettes: Factory 96315897677106,
  Station 109349449591065.
- Space kit: its FBX files are ASCII with flat material colours, and Studio dropped the
  colours, so everything came in grey. `tools/map/bake_space.py` runs Blender headless
  (`F:\blender.exe`; the MCP isn't needed). It reads the GLB files, bakes the 9
  colours into a palette and writes binary FBX files with the palette embedded.
  Studio's importer uploaded the palette once per model; `prepare.luau` points every
  copy at one id (`SiteProps.Palettes.Space`).
- `tools/map/prepare.luau` builds `ServerStorage.SiteModels`: pivot at the base, 10
  studs per kit metre, box collision. It's saved to
  `src/ServerScriptService/SiteModels.rbxm`.
- `SiteProps.place` stands a model at a given studs-per-metre scale.
  `SiteDressingService.Props` lists the placements. `SitePropsCheck` keeps them on
  the site and off the lane, spawn, huts, stations and Tier 5's footprint (|x| <= 245
  on the apron).
- Studio: RunChecks all pass except MaterialInteractionCheck, which already failed on
  master. #28 put Tier 5's FloodPole at x = 234, outside the 380-wide pad. Left for
  whoever owns the 3x rockets.

## Same session, part 2: sky, perimeter, surroundings, liftoff

- Skies: `tools/sky/cubemap.py` cuts the Kenney equirectangular skyboxes into Roblox's
  six faces. Face orientation was checked in Studio with `--test`: Rt covers -X, and Up
  and Dn are turned a quarter. Earth uses "day" (purple dusk) with a matching
  Atmosphere haze. Destinations and the cabin use "galaxy"; the Black Hole uses "band".
  `Shared/Skies` holds the ids, and DestinationController picks one each frame.
  - The 18 faces were uploaded with the Studio MCP `upload_image` to k_b4nd0. They're
    approved, but the experience (universe 10770732428, owner user 1502038929) still
    can't load them. Studio reports "User is not authorized", so the experience needs
    permission to use them. Until then the default sky shows.
- Earth perimeter (`SiteSurroundsService`): hoarding (10 tall, hazard rail, posts,
  notices) on a closed loop round the ground and the Gym District, with a 120-stud
  invisible barrier. `fit(edge)` rebuilds it whenever map expansion widens the ground
  (`expandMap` now returns the half-width).
- Land beyond: a grass plain to +-5120, 0.35 under the site, so expansion strips cover
  it; 70 low-poly trees; and 22 faceted mountains at 2600-4200 (snow caps on the big
  ones). DestinationController hides this land more than 7000 from Earth.
- Destinations: a rim of faceted crags just outside each fence, and a plain 3 below the
  platform with boulders, reaching 1000 on the Moon and Mars, 650 on Europa and Saturn,
  and 800 on the Black Hole. The Black Hole backdrop moved up 70 so its disk clears the
  plain. Each reach clears its giant planet and covers the arrival camera's spot.
- Liftoff: the tilted ramps stayed up when the rocket swung upright, so the hull seemed
  to cut through them. `Build:erect` now fades the ramps, rails, posts and beacons
  (no collision), and `beginBoarding` lifts anyone on a ramp down beside the hatch
  (`Build:isOnRamps`). Shot 1 starts 0.1h higher, to see the pad over the hoarding. A
  numeric check over all 5 tiers: the whole rocket stays in frame in both shots.
- PerimeterCheck added. RunChecks: all pass except the pre-existing
  MaterialInteractionCheck (Tier 5 FloodPole off the pad).

## Same session, part 5: launch and landing animations (2026-10-19)

- Missing flames: particle-only exhaust was too small to see on the 3x rockets and
  disappears on lower graphics. Each engine now gets a flame plume made of parts: an
  outer orange flame and a pale core, each three tapering Neon segments that flicker.
  Plumes are sized to the nozzle (capped at a quarter of the rocket's height), plus the
  particles. `burn(power, reach)` drives them; landing flames never reach past the
  ground. Engine lights got smaller (they washed the boosters white with bloom).
- Rockets disappearing: the cinematics never set `Camera.Focus`, so it stayed on the
  passenger far away in the cabin. Roblox draws and loads the world around Focus, so
  the launch pad and landing site drew late or dropped out. Focus now follows the shot.
  Both launch shots are closer (about one rocket height off), and the wide shot rises at
  0.82 of the climb. Simulated for every tier: nose at 12% and flame tips at 86% of the
  screen, never off it.
- Landing shot: drop 80 + 0.9h, camera 1.1h + 40 back (at most 220, inside every
  destination's mountain ring), riding down at 0.6 of the descent and aimed at 0.35h.
  For Tiers 4-5 the lens widens to as much as 88 degrees, restored after the cutscene.
  Measured live on Tier 5: the whole rocket and its flames stay between 18% and 91% of
  the screen. Rays from the camera to the rocket hit nothing on any destination.

## Same session, part 4: closed horizons, accurate gym badges, signs, launch fixes

- Horizons: `Mountains.ring` builds continuous rings of faceted peaks (neighbours'
  bases overlap). Earth has two rows (2350 and 2850 studs out, 34 + 32 peaks). Every
  destination has one inside its plain, low enough to keep its backdrop planet in view.
  PerimeterCheck asserts the rows have no gaps and clear the site.
- Gym badges: a station's badge is now its live `TrainingGain / TrainingBaseGain`
  (destination gyms said x2 while paying +12 to +30). The fixed `Multiplier` attribute
  on destination stations is gone.
- Cabin: it sat at (-3000, 200, 0), inside Earth's mountain ring, and a peak came
  through its back wall. It moved to (-12000, 200, 0) (PerimeterCheck keeps the cabin and
  destinations outside Earth's land). Its walls now overlap at the corners.
- Launch camera: the wide shot used to hold still, so the Tier 4-5 rockets climbed to
  ~5000 studs away, past the draw distance Roblox drops to under the launch's load, and
  vanished. It now rises at 0.75 x the rocket's climb, so the rocket stays within ~1800.
- Big-rocket sound: ignition and liftoff pitched down with size, roar bass up to +10 dB,
  plus a sub-rumble layer (the engine an octave down, highs cut). The rest is on the
  roadmap (Phase 5, Audio).
- Signs: SignService (server) and WorldSignController (client) draw every world sign in
  the gym-sign style: dark rounded panel, accent border and sheen, a pulsing icon badge,
  outlined title and subtitle. Converted: destination welcome signs (now on posts at
  SignOffset, left of the arrival and kept clear of scatter, so they no longer cut
  through landed rockets), the spaceport arch (both faces), the Gym District arch, the
  Upgrades hut, UFO shops, site offices, the building-site hoardings and the perimeter
  notices.
- Studio MCP tip: a Scriptable debug camera far from the character should also set
  `Camera.Focus`. Otherwise Roblox takes 20-40 s to draw that area, which looks like
  missing geometry.

## Same session, part 3: skies load, launch background fixed

- After the Studio restart the 18 sky faces load: the user granted the experience access.
- What flickered during the launch:
  - The grass plain lay 0.35 under the whole site, so from a climbing camera the two
    z-fought. It now has a hole for the site and the District (`Surrounds.plainPieces`,
    refitted on expansion; PerimeterCheck covers it).
  - The snow caps were flush with their peaks' faces. They now stand 1.2% proud.
  - The Atmosphere haze thickened with camera height and swallowed the ground during the
    shots, so Earth has no haze now.
- Mountains: 24 at 2200-3100, all well clear of the fully expanded site (checked).
- The Earth sky is cut with `--land`: ground matching the plain below the horizon and a
  low faceted far range. Where Roblox drops distant geometry (lower draw distance when
  the frame rate dips), the sky behind still reads as land.
  - The 5 changed Earth faces are new uploads (k_b4nd0) and need experience access like
    the first set. Until then the Earth sky falls back to the default.
  - Painting a tall range into the sky was tried and dropped: it was stair-stepped on
    the cube faces and washed out by the haze.
- Studio MCP screen captures right after a big camera move often return a stale frame;
  a second capture after a wait is reliable.

# Earlier session: 2026-10-18 (5), touches on the Earth site

- Built on the partner's `claude/earth-map` (6d9623f) and kept all of his work. The
  first attempt (PR #27, on master) would have undone it and was closed.
- Carried scrap: the plain ball with cubes is now a salvage heap (22 parts: rusty core
  and lumps, pipe, tyre, brass gear, I-beam, bent sheet, copper coil, bolts, and an
  antenna with a red bulb). It grows like the jerry can (CargoVisualService).
- Rockets 3x: `Models.SiteScale` = 1.35 * 3, about 428, 568, 708, 845 and 1019 studs
  tall. Landed copies still shrink back by SiteScale (the partner's design), so
  destinations are unchanged. SiteLayout changes:
  - PadOrigin z -265; Tier 5's hatch ends at -97, short of the forecourt.
  - Pad 380 x 350; ramps reach |x| = 182.
  - Apron |x| 270, z -1000..-88. Ground |x| 290, z0 -1020.
  - SiteDressing's back floodlights sit at the apron's mid z.
- Ramps: arms every 40 studs, with posts on the outer edges only, so the fill stays
  visible.
- Removed: the SPACEPORT floor sign, the apron and bay marking lines, and the visible
  spawn pad and SPAWN label. The SpawnLocation stays, invisible and non-colliding.
- Spawn fix: the anti-teleport check snapped new characters back to (0, 3, 0), because
  CharacterAdded fires before the character moves onto its spawn. `Movement.track`
  takes a settle time (1 s on spawn), so players now spawn at z = 40.
- Studio: RunChecks 10/10. Seen:
  - Tier 1 at 35% fill and Tier 5 at 45% fill
  - no overlap between the site dressing, hut or UFO shop and the rocket complex,
    tilted or upright (Tiers 1, 3, 5)
  - a Moon landing at the original size
  - no game errors in LogService
  Not seen: a passenger's launch camera at the new heights.

# Earlier session: 2026-10-18 (4), Earth site first pass

- PR #26 merged. Branch `claude/earth-map` from master. The user asked for a ground-zero
  spaceport construction site: things spaced out (not extremely), the scrap pit and fuel
  station remodelled, the rocket, build site and side ramps notably bigger, and no
  planets visible from Earth.
- `SiteLayout` holds every position. The pad (164 x 124) is at z = -150, the apron
  reaches -480, and the ground is dirt (|x| <= 200, z -500..112). Spawn is at z 40.
  Salvage Yard (x -125) and Fuel Depot (x +125) flank the lane at z 15. The Upgrades hut
  and UFO Shop sit either side of the forecourt (+-42, -42). The Gym District starts
  behind spawn (z 132). Map expansion strips start at the new ground edge.
- Rocket: `Models.SiteScale` 1.35 (143..340 studs tall). Ramps are at least 20 wide
  (was 14), with RAMP_PAST_MOUNT 14 and arms 5 wide every 16. `landedCopy` shrinks the
  copy back by SiteScale. Moon check: base on the ground, ~102 tall, within 58 of the
  centre on its 75 radius. RampCheck and MaterialInteractionCheck now read the pad
  from SiteLayout.
- Stations remodelled: the Salvage Yard (fenced gravel yard, three climbable scrap
  mountains, magnet crane, conveyor and compactor, skips, crushed cubes; the whole yard
  is the pickup) and the Fuel Depot (two cryo spheres on legs, bullet tanks, pipe rack,
  vent stack with vapour, tanker; the fuelling gantry is the pickup). HUD and tutorial
  text renamed to match.
- `SiteDressingService`: roads, two tower cranes with jibs over the pad, floodlights,
  container stacks, girder piles, site offices, Mission Control and hangar skeletons in
  scaffolding, cones and barriers, and a SPACEPORT EARTH / GROUND ZERO arch over the lane.
  It adds about 2,240 parts to RocketWorld.
- DestinationController hides far destinations and the cabin per client (2,500 / 700
  studs from the camera or character, checked every physics step). LaunchEffects
  lands each LandedRocket once despite the reparenting.
- `tools/map/stage.py` stages 67 Kenney models (factory, space and station kits) plus
  two palettes. Not imported yet. The Blender MCP isn't connected to Claude Code here.
- Studio: RunChecks 10/10. Seen: overview, spawn, Salvage Yard and pad views; the sky
  with no planets; a full load of scrap picked up in the yard; boarding into the cabin
  and the Moon landing measured. The MCP character_navigation tool silently did nothing
  on this map, so Humanoid:MoveTo was used instead.

# Earlier session: 2026-10-18 (3), pet polish and the launch camera

- PR #25 merged by the user. Branch `claude/pets-polish` from master.
- Launch camera: the second passenger shot sat 6 studs up beside the pad, right where
  the UFO Shop stands, and players could walk into it. It now looks up from high on the
  other side (`-0.7h, 40 + 0.5h, 1.3h` from the pad). A posed check at the Moon
  rocket's height showed open sky, and a raycast from the camera hits only the rocket.
- Names: bland pets renamed to alien names. A creature's forms share a root: Glorple /
  Glorpwing, Gloopling / Gloopzilla, Mushnub / Mushnubbus / King Mushnubulon, Grunkle /
  Grunklor / Skullgrunklor, Drakko / Drakkothar... Already-alien names (Hywirl, Squidle,
  Alpaking...) stay. Ids are unchanged, so saves are fine. PetCheck requires unique names.
- Clips: every model now carries 5-8 clips from the importer's saves (Blob: Idle, Move,
  Jump, Yes, Dance, Bite, No; Large: + Run, Wave, Punch, Swing; Flying: Idle, Move, Yes,
  Headbutt, Punch, No). Finger and leaf-bone poses are dropped and long clips halved, so
  the file is 2.8 MB.
- PetAnimator: Idle -> Walk -> Run blending with the step rate matched to ground speed.
  Measured at pet size, Walk keeps pace at ~2 studs/s and Run at ~3, so at player speed
  (24-70) Large pets bound in leaps timed to each step and blobs hop per Walk cycle.
  One-shot clips play over the base with fades (play/busy/phase).
- PetController rewrite. Rarity flair: Rare+ glow ring, Epic+ sparkles, Legendary light
  and a short trail. Idle shows (clips and tricks: hop, spin, roll, backflip, loop,
  barrel roll) grow in variety and frequency with rank, and Epic+ trick on the move.
  Pets hop when their owner jumps. Name and rarity tags are sized in studs to each pet
  (3 x 0.75 at full size, fading by 45 studs), and Legendary tags shimmer. The UFO swoops
  in on purchase, and its lights race in the last 10 s.
- Landing: the UFO swoops in front of the owner, wobbles and spins up, its beam powers on
  with rising sparkles, and the pet spins up from a speck inside it. At the pop come a
  shockwave ring, a flash and a burst (confetti for Epic+, a gold light pillar and a
  camera kick for Legendary). The UFO zips off and the pet drops, bounces and celebrates
  (Dance/Wave/Yes/Headbutt), then joins its owner. It's longer for rarer pets.
- `PetRevealCard` replaces the banner and the server toast: a live 3D pet, name, star
  rarity pill and "now following you" / "sent to your backpack". Epic+ get rays,
  Legendary a gold shimmer. Fixed: a UIGradient on the CanvasGroup dimmed everything,
  so the wash is its own frame now.
- Sounds (Kenney sci-fi): pet/arrive, beam (forceField_002 + warble), pop (retro zap +
  thump + slime), zip (reversed falling laser), and fanfare2-5 (rising 8-bit arpeggios;
  Legendary adds a phrase and a boom). Built and copied to Studio. **Not uploaded** (no
  API key here); the user runs tools/sounds/upload.py. Until then they're silent live.
- Round 2 (user):
  - Legged pets stepped too fast (Run at 3.5x). Gaits are now owner-speed based (Run
    ~1.1x at 24, 1.8x max), driven by the owner's smoothed ground speed instead of the
    pet's jittery catch-up speed, with lower leaps.
  - Fanfares rebuilt from the user's nomagician pickup notification (freesound 833635,
    moved to Sounds/), climbing per rarity: as is / +2 semitones with a fifth / +4 with
    a fifth / three rising entries over a boom.
  - Stars removed from tags and the card.
  - Rare+ get confetti, card rays, a camera kick and a rarity-tinted screen blink, all
    growing with rank.
  - Your own landings happen ahead of the camera and off to the side, so your character
    no longer hides them.
- Studio: RunChecks 10/10. Seen: a Legendary landing (rays, trail, tag), the Epic card,
  Legendary idle tricks, the Large run stride, the posed launch shot. Trails and rings
  were toned down after a look. Not seen: a full passenger launch (the character didn't
  board), and a second player.

# Earlier session: 2026-10-18 (2), real pet models, animation, sizes, backpack

- PR #25 (`claude/pets`) opened with the first round. The user imported all 50 FBX into
  Studio and asked for: fixed animations, pet-sized pets (the Large ones were far too
  big), pets purely cosmetic, and a small backpack button to equip or unequip.
- Import: models came in at FBX scale (200-465 studs) with a pivot turned 90° about X.
  Multi-mesh models (14) keep their bones under an invisible RootPart that is their
  PrimaryPart. My first re-pivot turned single-mesh models over; that was caught by
  bone heights and corrected. All 50 are now upright, face -Z, have their pivot at the
  feet, and keep `Clips/Idle` and `Clips/Move` (from the importer's AnimSaves). They are
  saved as `src/ReplicatedStorage/PetModels.rbxm` (3 MB, SerializationService, written out
  over a local HTTP receiver).
- `Shared/PetAnimator`: compiles a KeyframeSequence into per-bone key lists (cached per
  clip), samples them linearly, and blends Idle into Move by speed. It writes
  Bone.Transform with translations times the copy's scale. No animation uploads.
  PetController animates pets within 110 studs. Stand-ins keep the procedural hop.
- Sizes (`PetModels.Fit`): Blob span 2.2, Large height 3 (their T bind pose would make
  width-fitting tiny), Flying wingspan 3. The following UFO is 0.55 scale, slots are
  tighter, and the beam is slimmer and more transparent.
- Backpack: a 🎒 top-bar button opens PET BACKPACK. Cards have posed previews (WorldModel)
  and an EQUIP / UNEQUIP button (greyed when full), plus UNEQUIP ALL
  (`EquipPet("*", false)`). Pet meshes are preloaded; viewports built before a mesh
  loaded stayed blank.
- **Textures blocked:** the atlas is not in the downloads. Copies of the CC0 Quaternius
  atlases (one per pack) found in public Godot repos are in `tools/pets/atlas/`;
  textured previews of all 50 rendered correctly with them. Uploading them from
  Claude was denied by the auto-mode classifier, so the user uploaded them (Blob
  82233115260905, Large 127491665071338, Flying 119141981005054), now in
  `PetModels.Atlases`. All three load, and all three packs show fully coloured in
  Studio.
- Studio: RunChecks 10/10 (PetCheck now checks sizes, pivots and clips for all 50 imports,
  and unequip-all). Seen: Yeti, Cat and Dragon following and animating, facing their
  travel, a Hywirl landing from an Uncommon UFO, the backpack round-trip, and immediate
  previews.

# Earlier session: 2026-10-18, alien pets and UFOs

- Branch `claude/pets` from master. The user added 50 Quaternius *Ultimate Monsters*
  FBX files in three downloads. Their previews and rigs show they are Blob (17), Big
  (16, T-posed humanoids) and Flying (17).
- `Shared/Pets`: the catalog (id = `<Form>_<Model>`), tiered 14/12/10/8/6 Common to
  Legendary. Plain animals and base blobs are Common; armour, weapons, crowns and evolved
  forms climb the tiers. UFO tiers: 500 / 5K / 50K coins, 5-25 minutes, odds 80/20,
  90/10, 95/5. Epic (95/5) and Legendary (100) aren't on sale; they will be Robux. The
  roll is uniform within a rarity.
- `PetService`: BuyUfo(tier, requestId) runs only near a UFO Shop, once per ID, with one
  UFO at a time. The pet is rolled at purchase and never sent to the client until it
  lands. The countdown runs on play time only (profile.ufo.remaining, ticked each second
  while in game). On landing, the pet is added and equipped if a slot (max 3) is free,
  and PetHatched fires before the attributes change. EquipPet(id, on). Player attributes
  UfoTier, UfoHatchAt and Pets drive every client.
- Profile v7: pets (id -> count), equippedPets and ufo. Retired ids and equips of pets
  not owned are dropped on load; other bad data is refused. The countdown alone doesn't
  mark a save dirty.
- World: UFO Shops (a pad, counter, sign and a spinning saucer beaming down) opposite the
  upgrades hut at (26, -32), and on every destination at (38, -4), facing the arrival.
  The scatter keeps 14 studs clear around them.
- Client: `PetController` draws everyone's UFO (rarity lights, countdown billboard) and
  pets. Blobs hop, large pets waddle, flyers hover and flap. On landing, the UFO beams
  the pet down, flies off, and shows a reveal banner. `UfoShopController` (panel opened
  by the shop prompt) and `PetsController` (🐾 top-bar button, card grid with 3D
  previews, tap to equip). Skip Tutorial moved one slot left to make room.
- `Shared/PetModels`: a primitive UFO and per-form stand-in pets, used until
  ReplicatedStorage.PetModels holds the imported meshes. `tools/pets/stage.py` copies the
  FBX files to `import/<Id>.fbx`. **Blocked:** `Atlas_Monsters.png` isn't in the
  downloads, so the meshes would import untextured.
- Studio: RunChecks 10/10 (PetCheck is new). Tested: bought a Common UFO (panel closed,
  UFO followed, 4:58 countdown), a Rare UFO landed (beam, growth, banner, toast,
  auto-equip), the 4th equip was refused, and all 5 destination shops are clear of
  scenery. Not tested: a second player, persistence (off in Studio), phone layout.

# Earlier session: 2026-10-17, prompt, toast and hint polish

- Branch `claude/prompt-and-hint-polish` from master.
- Gym station prompts read just "[E] Use": no ObjectText (it was the part name, e.g.
  FREEGYMTreadmill) and no station name in the action. PromptController draws a narrower
  card with the action centred when a prompt has no object name.
- Toasts wrap: a message wider than the card (TextService measure) takes the full 520 width
  and grows down, so text no longer spills past the pill ("...to exit." did). The mount
  message is now "Training! Press E or LEAVE to get off."
- Objective-line how-to hints hide once the player has done the thing, persistently:
  first pickup / place of Metal and of Fuel, leaving a station. The client
  notices from state changes and fires `HintLearned`; TutorialService whitelists the name
  and stores "Hint:<name>" in `seenCallouts` (already saved and sent). With nothing to
  say the banner hides. Phase news (liftoff, arrival, "You're aboard!") still shows, and
  "BOARD NOW!" shows to everyone every time a rocket is finished (user: keep it server
  wide), and
  the training mount toast is skipped once LeaveStation is learned. The tutorial's own
  steps are unchanged.
- Studio: pickup stored Hint:PickupMetal and hid "Grab scrap metal..."; after leaving
  the treadmill a remount showed no banner or toast; toasts fit at one and two lines.
  Cross-session persistence not testable in Studio (profiles aren't saved there).
  RunChecks 9/9.

# Earlier session: 2026-10-17, longer launch cutscene with a landing

- Branch `claude/launch-landing` from master (separate from the gym PR #22).
- Flights are longer: `LaunchSeconds` (ignition and ascent) 7/8/9/10/12 -> 11/12/13/14/16
  and a new `LandingSeconds` 8/8/9/9/10 per tier (Shared.Missions), so the Moon trip is
  19 s instead of 7. The ascent has a second shot: from the pad looking up as the rocket
  shrinks into the sky.
- At liftoff the server stands a finished copy of the rocket (`Build:landedCopy`,
  "LandedRocket", engine bells on the ground) on the destination's landing spot, 42 studs
  behind its centre past the welcome sign. It carries DescentAt, DescentSeconds,
  CutsceneEnd, Ground, Height, ExhaustScale; it stays for the reward stay and is removed
  at reset (and any older one at the next launch).
- Each client hides that copy until DescentAt, then drops it from 120 + 1.2 x height
  studs, slowing to a stop ((1 - t)^2.2) with big braking flames, landing dust and the
  engine roar, then a touchdown boom. Passengers fade to black at the end of the ascent,
  watch from far enough back to keep the ground and the rocket in frame, hold 1.5 s on
  the landed rocket, and fade out as the server moves them to the arrival pad.
- DestinationService: scatter keeps a 30-stud radius clear around the landing spot;
  Mars' habitat dome moved to (-38, -20) to clear the Mars rocket. Every tier's rocket
  bounds fit its own destination's ground at that spot (checked numerically, only the
  Moon seen in Studio).
- Studio: full passenger run on the Moon: ascent shots, fade, descent 437 -> 196 (bells
  exactly on the ground at y 200), fade, arrival beside the rocket; the copy was gone
  after reset. RunChecks 9/9.

# Earlier session: 2026-10-17, gym animations (treadmill and bench)

- Branch `claude/gym-animations` from master.
- Server (TrainingService): poses the anchored body with a full CFrame (`relocate` now
  takes one). Treadmill: upright on the belt facing the console. Bench: flat on the
  cushion, face up, head under the rack, `PlatformStand` instead of `Sit` (Animate
  stops its idle). The station carries `OccupantId` and `TrainingSince` while in use.
  Gain ticks now keep to the mount's beat (`nextTick += TrainingSeconds`) so the client
  can time reps to them.
- World: gym pieces are now children of the station base. The treadmill belt has 7
  slats and an end roller each side; the barbell is a cylinder with the plates as its
  children, moved outside the rack posts.
- Client `GymAnimationController` (every client, every occupied station, PreSimulation
  so it wins over the Animator): slats scroll back at 5 x HipHeight studs/s (the run's
  measured stance-foot speed); the runner's own client plays its avatar's run (Action
  priority, replicates). Bench: the bar lifts off the rack in 0.35 s, then one rep per
  gain tick (hold, lower slowly, press, locking out as the gain pays), feet up on the
  bench. Arms use a two-bone IK written to the joint Transforms (works for Motor6D and
  AnimationConstraint rigs; the test avatar uses AnimationConstraints). IKControl was
  tried first and left the hands 0.2-0.4 studs off the bar.
- Studio (Rojo not connected, pushed over HTTP again; all scripts matched the repo):
  grips measured 0.000 off the bar axis through the rep, bar travel ~1 stud, bar back
  on the rack and body upright after LEAVE. RunChecks 9/9. Not tested with a second
  player (no multi-client run through MCP).
- Shared benches (user): any number of users can train on one bench at once, each
  seeing only themselves on it. The station carries `Occupant_<UserId>` = mount time per
  user (replacing OccupantId/TrainingSince). Each client shows one occupant per bench
  (itself if on it, else the earliest) and hides the rest locally (LocalTransparency-
  Modifier, their BillboardGuis such as RankTag, Humanoid name). Treadmills now work the
  same way (user asked; "Station occupied." is gone). Each runner's own client plays its
  run animation, so whichever runner a client shows is running. TrainingCheck covers two
  users on each. Verified solo plus the hide/restore on a cloned dummy; no real second
  player tested.

# Earlier session: 2026-10-17, gameplay sounds

- Branch `claude/gameplay-sounds` from `claude/ui-sounds` (PR #19, not merged yet).
  Uploads deferred by the user; Studio plays the `--studio` copies meanwhile.
- 12 new files in `assets/sounds/game/`. `build.py` can now mix files and build
  seamless loops (end crossfaded into start), and encodes bitexact (fixed Ogg serial),
  so unchanged sounds rebuild byte for byte and never re-upload. That changed the
  bytes of the 10 UI files once.
- Cargo: the server stamps `Count` on CarriedMaterials with each resize, and the
  owner's client plays pickup and place sounds off it: metal clink or can clank going
  up in pitch as the load fills, "full" at capacity, metal clunk or soft thud as it
  empties, a drop thud after Q/DROP, and silence when a phase change clears it.
- Coins clink as each flying coin lands, each a step higher. Stat gains pop (strength
  lower, speed higher); level-ups play powerUp1 instead. Boarding countdown beeps at
  10..1 (1.5x pitch from 3). Launch: a looped engine roar on the nozzle swells with
  ignition (deeper for bigger exhaust) and a low boom on the pad as it lifts.
- Review round 1 (user): cargo too twangy, wanted a ka-ching, a sweeter shorter
  level-up and a truer launch. Now: pickup/place are Kenney wood knocks (~20 ms decay,
  200-450 Hz, low-passed), one pair for both materials with fuel at 0.85 pitch. The
  first coin of a burst plays a ka-ching built in `build.py` (chip clack, two synth
  bells, handleCoins2), at most every 0.5 s (Sfx.play now returns whether it played),
  and later coins clink. Level-up is the steel-drum STEEL10 (D E F# G) at 1.12x. The
  launch roar is synthesised (rumble, 90-900 Hz roar, crackle pops, slow sway, tanh),
  balanced for small speakers (~75% above 100 Hz). An ignition burst plays on the pad
  at t=0, and an EqualizerSoundEffect cuts the roar's highs with camera distance.
  `build.py` manifest entries can now be layered dicts (file or synth, gain, delay,
  pitch, lowpass/highpass), and stale built files are deleted. Seeded, so rebuilds
  stay byte-identical. Offered the user: a real (e.g. NASA public-domain) launch
  recording would beat the synth.
- Review round 2 (user): ka-ching's bell dropped. `game/cash` is now the chip clack plus
  handleCoins2 only. Level-up is now a light two-note pluck (PIZZI16 at 1.19x:
  F#4 -> C#5, 0.38 s, volume 0.35, gap 1 s), since destination rewards level stats often.
  The user added NASA's launch recording (`Sounds/590189main_ringtone_131_launchNats.mp3`,
  19 s of steady post-ignition roar, ~90% under 400 Hz, effectively mono). The engine
  loop is its 5-15 s (high-passed at 30 Hz) plus a 700 Hz high-passed copy at 0.35 for
  crackle on small speakers, 9.7 s. Ignition is its first 2.4 s swelling in over
  lowFrequency_explosion_001. The synthesised roar and bells were removed from build.py.
- Review round 3 (user-supplied files in `Sounds/`): coins use
  `mixkit-coins-sound-2003.wav`, clipped from 85 ms (it swells for ~200 ms) to a
  0.33 s jingle, volume 0.14. Every landing coin plays it, each a step higher (+4%,
  up to +40%) across bursts, and the climb resets after 1 s without coins.
  `game/cash` is gone. Level-up is `609335__kenneth_cooney__levelup.wav` (0.31 s chiptune
  A-D-E-A that stops dead, given a 30 ms fade), volume 0.3. A level-up no longer
  silences the stat-gain pops: both play on the same frame.
- Final tweaks (user): level-up volume 0.2. Place pitch is 1.5-1.65x (falling only
  slightly as the load empties; with big loads the old 0.9-1.2x sank too deep). Fuel
  is x0.85 on both.
- Studio (Rojo wasn't connected to this Studio session, so the scripts were pushed
  with HttpService from a local file server; all 70 scripts then matched the repo):
  every sound played on the frame its count, coin, digit or lift change showed. The
  `Played` event drops some rapid replays, so timing was measured by polling
  IsPlaying and TimePosition. RunChecks 9/9.

# Earlier session: 2026-10-17, UI sounds (Kenney packs)

- Branch `claude/ui-sounds` from master.
- User: use the Kenney packs in `Sounds/` (untracked, ~650 files), UI first; sounds must
  start the moment they're triggered.
- `tools/sounds/build.py` turns the 10 picked files into `assets/sounds/ui/*.ogg`: cut
  to the first audible sample, tail trimmed, -1 dBFS peak, mono Vorbis (not MP3, which
  pads the start). Many Kenney files open with silence (digital pack ~100 ms, ui-audio
  switches 35-140 ms); the UI picks mostly start at 0 already. `--studio` copies them
  into Studio's content folder so Studio plays them before upload.
- `tools/sounds/upload.py` (Open Cloud, ROBLOX_API_KEY) uploads and writes
  `Shared/SoundIds.luau`. Not run yet: needs a key for the experience owner.
- `UI/Sfx`: preloaded pooled Sounds in the SFX group, cue table with volume, voices,
  gap and pitch spread. Hooked into Button (click and hover; `sound` prop), Toggle,
  Slider ticks, Toast, settings and upgrades open/close, buy (error / click, then
  confirm on the server's level-up), wheel ticks on slice edges, wheel result and
  tutorial-complete jingle. JUMP and GRAB mute the click.
- Studio Play: all 26 voices load; Play() is at position 0 on the same frame. Clicks
  logged on the same frame as the visual change; buy confirm 66 ms after the click
  (round trip). Wheel simulation: every tick within one frame of its edge. RunChecks 9/9.
- User review: all picks kept except close (was minimize_001, heard as a laser). Close
  is now the open sweep reversed (1.78 -> 1.19 kHz) with the open's loudness curve, so
  it still hits at once; Kenney's own reverse (minimize_009) fades in over ~60 ms.
  Every cue's volume down ~20%.

# Earlier session: 2026-10-16, HUD on a phone (iPhone 14 emulator)

- PR #17 rebase-merged. Branch `claude/hud-phone-fixes`.
- iPhone 14 landscape (749x388, HUD scale 0.46): the objective and mission-tag backings
  were sized from TextBounds (screen pixels) as if they were layout units, so they came
  out tiny on phones and oversized on desktop. Now divided by the label's scale.
- Touch: stat stack and the progress group (pill + mission tag, now one frame) get a
  1.35 UIScale; toasts sit higher to clear it. The desktop camera hint showed in the
  emulator only before the touch thumbstick appeared (PreferredInput); not changed.
- Follow-up (user OK'd 1-3): `UI/WorldScale` shrinks pixel-sized world billboards by
  viewport height / 720 (floor 0.5, never above 1, follows resizes): rank tags (watched
  on every character), gym equipment tags, Popup.world pops. Tutorial edge arrow is
  pushed right of the stat stack when it would overlap. Touch: objective text 34
  (desktop 26); stat stack 1.25x, vertically centred on the left edge (-30), clear of the
  thumbstick.
- Phone layout (user): stat stack at the top left under the Roblox button (y 8, 1.25x).
- ⚙ and SKIP TUTORIAL sit in the free right side of the Roblox top bar row on every
  platform (user asked for PC too): `Create.inTopBar` centres a holder on
  GuiService.TopbarInset and scales it to 0.66 of the row (~38 px on both), following
  scale and inset changes. Checked in the desktop view (1849x949) and the iPhone 14.
- Studio iPhone 14 emulator: RunChecks 9/9; screenshots before/after; rank tag
  200x28 → 108x15, equipment tag 280x72 → 140x36. The rank tag appears only after the
  first stats update after spawning (existing behaviour).

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
