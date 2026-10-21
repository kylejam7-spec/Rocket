-- Sound effects: Sfx.play(cue, options?) starts a cue on the frame it's called.
-- Every cue's Sounds are made at startup in SoundService (routed to the SFX group,
-- so the settings slider sets their volume) and preloaded, so Play() has nothing to
-- fetch; tools/sounds/build.py trims each file so it's audible from its first sample.
-- A cue keeps a few voices so quick repeats overlap instead of cutting each other
-- off, and `gap` drops repeats closer together than that (hover, ticks); play()
-- returns whether it played.
-- Options: pitch (PlaybackSpeed multiplier), volume (multiplier).
-- `world` cues sound from a place in the world instead: Sfx.attach(cue, parent) gives
-- a new Sound under a part or attachment (Looped if the cue loops) for the caller to
-- play, fade and destroy; Sfx.playAt(cue, parent) plays one there once.
-- Files come from Shared/SoundIds once uploaded; until then Studio plays the copies
-- `build.py --studio` puts in its content folder, and live servers stay silent.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SoundIds = require(ReplicatedStorage.Shared.SoundIds)
local Settings = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("Settings"))
local Sfx = {}

-- vary: random pitch spread (±) so repeats don't sound machine-made.
local CUES = {
    click = { file = "ui/click", volume = 0.44, voices = 3, vary = 0.04 },
    hover = { file = "ui/hover", volume = 0.16, gap = 0.06, vary = 0.04 },
    open = { file = "ui/open", volume = 0.36 },
    close = { file = "ui/close", volume = 0.36 },
    toggle = { file = "ui/toggle", volume = 0.48 },
    tick = { file = "ui/tick", volume = 0.28, voices = 4, gap = 0.03 },
    error = { file = "ui/error", volume = 0.4, gap = 0.15 },
    confirm = { file = "ui/confirm", volume = 0.44 },
    notify = { file = "ui/notify", volume = 0.32, gap = 0.1 },
    jingle = { file = "ui/jingle", volume = 0.48 },
    -- Material pickup and place pop: CargoController pitches it up a step at a time as
    -- a load fills and back down as it empties. Cargo streams up to 20 transfers a
    -- second, so it's short and quiet, with no random spread to blur the steps.
    pop = { file = "game/pop", volume = 0.45, voices = 4 },
    full = { file = "game/full", volume = 0.45, gap = 0.3 },
    drop = { file = "game/drop", volume = 0.5 },
    -- Up to 5 coins land 60 ms apart and the jingle runs 0.3 s, so they overlap: quiet.
    coin = { file = "game/coin", volume = 0.14, voices = 6, gap = 0.03 },
    gain = { file = "game/gain", volume = 0.4 },
    -- Destination rewards can level a stat every few seconds: kept light.
    levelup = { file = "game/levelup", volume = 0.2, gap = 1 },
    countdown = { file = "game/countdown", volume = 0.45 },
    -- near/far: the roll-off distances in studs.
    engine = { file = "game/engine", volume = 1.2, world = true, loop = true, near = 60, far = 2500 },
    ignition = { file = "game/ignition", volume = 0.9, world = true, near = 80, far = 2500 },
    liftoff = { file = "game/liftoff", volume = 1, world = true, near = 80, far = 2500 },
    -- UFO pet deliveries, heard from the UFO (PetController); fanfares are the owner's.
    petArrive = { file = "pet/arrive", volume = 0.5, world = true, near = 12, far = 160 },
    petBeam = { file = "pet/beam", volume = 0.55, world = true, near = 12, far = 160 },
    petPop = { file = "pet/pop", volume = 0.6, world = true, near = 12, far = 160 },
    petZip = { file = "pet/zip", volume = 0.45, world = true, near = 12, far = 200 },
    fanfare2 = { file = "pet/fanfare2", volume = 0.3 },
    fanfare3 = { file = "pet/fanfare3", volume = 0.33 },
    fanfare4 = { file = "pet/fanfare4", volume = 0.36 },
    fanfare5 = { file = "pet/fanfare5", volume = 0.42 },
    -- Europa's oarfish (OarfishController): the quake is everywhere at once (a rumble from
    -- below; listed only so it's preloaded: the controller plays its own copy to fade it);
    -- the ice breaking and the roar come from out on the plain, 300+ studs off, so they
    -- keep their volume that far and only pan.
    oarfishQuake = { file = "europa/quake", volume = 0.9, voices = 1 },
    oarfishBreakOut = { file = "europa/break-out", volume = 1.1, world = true, near = 450, far = 3000 },
    oarfishBreakIn = { file = "europa/break-in", volume = 1.1, world = true, near = 450, far = 3000 },
    oarfishRoar = { file = "europa/roar", volume = 1.2, world = true, near = 450, far = 3000 },
}

-- The content id for a built file (its upload, else Studio's local copy), or nil.
local function source(file)
    if SoundIds[file] then return SoundIds[file] end
    if RunService:IsStudio() then return "rbxasset://sounds/rocket/" .. file .. ".ogg" end
    return nil
end
Sfx.source = source

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService
local group = Settings.group("SFX")
local voices, nextVoice, lastPlayed, templates = {}, {}, {}, {}
local preload = {}
for name, cue in CUES do
    local id = source(cue.file)
    if id and cue.world then
        -- Never played itself: preloads the file and is cloned by attach().
        local sound = Instance.new("Sound")
        sound.Name = name
        sound.SoundId = id
        sound.Volume = cue.volume
        sound.Looped = cue.loop == true
        sound.SoundGroup = group
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.RollOffMinDistance = cue.near or 10
        sound.RollOffMaxDistance = cue.far or 1000
        sound.Parent = folder
        templates[name] = sound
        table.insert(preload, sound)
    elseif id then
        voices[name] = {}
        for index = 1, cue.voices or 2 do
            local sound = Instance.new("Sound")
            sound.Name = name .. index
            sound.SoundId = id
            sound.Volume = cue.volume
            sound.SoundGroup = group
            sound.Parent = folder
            table.insert(voices[name], sound)
            table.insert(preload, sound)
        end
        nextVoice[name] = 1
    end
end
task.spawn(ContentProvider.PreloadAsync, ContentProvider, preload)

function Sfx.play(name, options)
    local cue, pool = CUES[name], voices[name]
    if not pool then return false end
    local now = os.clock()
    if cue.gap and lastPlayed[name] and now - lastPlayed[name] < cue.gap then return false end
    lastPlayed[name] = now
    local sound = pool[nextVoice[name]]
    nextVoice[name] = nextVoice[name] % #pool + 1
    local vary = cue.vary and (math.random() * 2 - 1) * cue.vary or 0
    sound.PlaybackSpeed = (options and options.pitch or 1) * (1 + vary)
    sound.Volume = cue.volume * (options and options.volume or 1)
    sound.TimePosition = 0
    sound:Play()
    return true
end

function Sfx.attach(name, parent)
    local template = templates[name]
    if not template then return nil end
    local sound = template:Clone()
    sound.Parent = parent
    return sound
end

function Sfx.playAt(name, parent, options)
    local sound = Sfx.attach(name, parent)
    if not sound then return end
    sound.PlaybackSpeed = options and options.pitch or 1
    sound.Volume *= options and options.volume or 1
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
end

return Sfx
