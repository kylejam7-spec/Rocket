-- Background music (Shared/MusicTracks, built by tools/sounds/music.py): Earth music
-- on Earth, space music out on a mission, each playlist shuffled (every song once
-- before any repeats, never the same song twice running), crossfading from one song
-- into the next. Plays through the "Music" SoundGroup, so the settings slider sets it.
-- Following the mission (from the state snapshot and the landed rocket's DescentAt):
-- - passengers: Earth music fades out at liftoff, space music fades in as the landing
--   begins, and on the way home space music fades out and Earth music fades back in;
-- - everyone left on Earth: the music dips while the rocket climbs, then comes back.
-- At the Black Hole, its ambience (the space hole recording) plays instead of space music.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local MusicTracks = require(ReplicatedStorage.Shared.MusicTracks)
local Settings = require(script.Parent.Settings)
local State = require(script.Parent.State)
local Sfx = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Sfx"))
local MusicController = {}

-- Each song's own volume, under the slider (tracks are loudness-matched at build).
local VOLUME = 0.4
-- Seconds: song-to-song crossfade, fading out when the mood changes, fading in.
local CROSSFADE, FADE_OUT, FADE_IN = 6, 3.5, 5
-- How far the music dips for players watching a launch from Earth.
local LAUNCH_DUCK = 0.3

-- Moods with their own sound instead of a MusicTracks playlist; `volume` multiplies VOLUME.
local AMBIENCE = {
    blackhole = { { cue = "ambience/black-hole", title = "Black Hole", seconds = 109.7, volume = 1.6 } },
}
local BLACK_HOLE = 5 -- Config.Destinations index

local random = Random.new()
local folder, group
local bags, last = {}, {}
-- Playing songs: { sound, track, mood, level, target, speed, handedOff }.
local voices = {}
local mood, duck, duckTarget = nil, 1, 1

-- The next song for `mood`: a shuffled bag, refilled when empty, never repeating the
-- song that just played.
local function nextTrack(name)
    local tracks = MusicTracks[name] or AMBIENCE[name]
    if not tracks or #tracks == 0 then return nil end
    local bag = bags[name]
    if not bag or #bag == 0 then
        bag = table.clone(tracks)
        for index = #bag, 2, -1 do
            local other = random:NextInteger(1, index)
            bag[index], bag[other] = bag[other], bag[index]
        end
        if #bag > 1 and bag[#bag] == last[name] then bag[1], bag[#bag] = bag[#bag], bag[1] end
        bags[name] = bag
    end
    local track = table.remove(bag)
    last[name] = track
    return track
end

local function start(name, fadeSeconds)
    local track = nextTrack(name)
    local id = track and Sfx.source(track.cue)
    if not id then return end
    local sound = Instance.new("Sound")
    sound.Name = track.title
    sound.SoundId = id
    sound.Volume = 0
    sound.SoundGroup = group
    sound.Parent = folder
    sound:Play()
    table.insert(voices, { sound = sound, track = track, mood = name, level = 0, target = 1, speed = 1 / fadeSeconds })
end

local function fadeOut(voice, seconds)
    voice.target, voice.speed = 0, 1 / seconds
end

-- Where the landed rocket's descent begins (server time), if a mission is under way.
local function descentAt()
    for _, root in { workspace:FindFirstChild("RocketWorld") and workspace.RocketWorld:FindFirstChild("Destinations"), ReplicatedStorage:FindFirstChild("HiddenDestinations") } do
        local landed = root and root:FindFirstChild("LandedRocket", true)
        if landed and landed:GetAttribute("DescentAt") then return landed:GetAttribute("DescentAt") end
    end
    return nil
end

-- The music this player should hear now ("earth", "space" or nil for silence), and
-- how far to dip it.
local function wanted()
    local state = State.get()
    if not state then return nil, 1 end
    local launching = state.phase == "Launching"
    local descent = launching and descentAt()
    local climbing = launching and (not descent or workspace:GetServerTimeNow() < descent)
    local away = state.destinationTier == BLACK_HOLE and "blackhole" or "space"
    if state.passenger and launching then
        return (not climbing) and away or nil, 1
    elseif state.passenger and state.phase == "Rewarding" then
        return away, 1
    end
    return "earth", climbing and LAUNCH_DUCK or 1
end

local function step(dt)
    local want
    want, duckTarget = wanted()
    if want ~= mood then
        mood = want
        for _, voice in voices do fadeOut(voice, FADE_OUT) end
        if mood then start(mood, FADE_IN) end
    end
    -- The dip eases in and out over about two seconds.
    duck += (duckTarget - duck) * math.min(1, dt * 1.5)
    for index = #voices, 1, -1 do
        local voice = voices[index]
        local sound = voice.sound
        voice.level = voice.target > voice.level and math.min(voice.target, voice.level + voice.speed * dt) or math.max(voice.target, voice.level - voice.speed * dt)
        sound.Volume = VOLUME * (voice.track.volume or 1) * voice.level * duck
        if voice.target == 0 and voice.level <= 0 then
            sound:Stop()
            sound:Destroy()
            table.remove(voices, index)
        elseif voice.target > 0 and not voice.handedOff then
            -- Near the end, the next song fades in over this one.
            local length = sound.TimeLength > 0 and sound.TimeLength or voice.track.seconds
            if sound.IsLoaded and length - sound.TimePosition <= CROSSFADE then
                voice.handedOff = true
                fadeOut(voice, CROSSFADE)
                start(voice.mood, CROSSFADE)
            end
        end
    end
end

function MusicController.start()
    Players.LocalPlayer:WaitForChild("PlayerGui")
    group = Settings.group("Music")
    folder = Instance.new("Folder")
    folder.Name = "MusicPlayer"
    folder.Parent = SoundService
    RunService.Heartbeat:Connect(step)
end

-- For playtests: what's playing, and at what level.
function MusicController.debug()
    local out = { "mood " .. tostring(mood) .. string.format(" duck %.2f", duck) }
    for _, voice in voices do
        table.insert(out, string.format("%s %s level %.2f -> %d at %.0f/%.0fs", voice.mood, voice.track.title, voice.level, voice.target, voice.sound.TimePosition, voice.track.seconds))
    end
    return table.concat(out, "\n")
end

return MusicController
