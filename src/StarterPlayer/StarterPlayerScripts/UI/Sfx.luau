-- Sound effects: Sfx.play(cue, options?) starts a cue on the frame it's called.
-- Every cue's Sounds are made at startup in SoundService (routed to the SFX group,
-- so the settings slider sets their volume) and preloaded, so Play() has nothing to
-- fetch; tools/sounds/build.py trims each file so it's audible from its first sample.
-- A cue keeps a few voices so quick repeats overlap instead of cutting each other
-- off, and `gap` drops repeats closer together than that (hover, ticks).
-- Options: pitch (PlaybackSpeed multiplier), volume (multiplier).
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
}

local function source(file)
    if SoundIds[file] then return SoundIds[file] end
    if RunService:IsStudio() then return "rbxasset://sounds/rocket/" .. file .. ".ogg" end
    return nil
end

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService
local group = Settings.group("SFX")
local voices, nextVoice, lastPlayed = {}, {}, {}
local preload = {}
for name, cue in CUES do
    local id = source(cue.file)
    if id then
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
    if not pool then return end
    local now = os.clock()
    if cue.gap and lastPlayed[name] and now - lastPlayed[name] < cue.gap then return end
    lastPlayed[name] = now
    local sound = pool[nextVoice[name]]
    nextVoice[name] = nextVoice[name] % #pool + 1
    local vary = cue.vary and (math.random() * 2 - 1) * cue.vary or 0
    sound.PlaybackSpeed = (options and options.pitch or 1) * (1 + vary)
    sound.Volume = cue.volume * (options and options.volume or 1)
    sound.TimePosition = 0
    sound:Play()
end

return Sfx
