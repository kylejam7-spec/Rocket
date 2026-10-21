-- Player settings shared by every controller: music and SFX volume (0..1) and
-- reduced effects. Settings.get(key), Settings.set(key, value), and
-- Settings.subscribe(fn(settings)), which replays the current values right away.
-- Volumes drive the "Music" and "SFX" SoundGroups; any future sound joins one of
-- them with Settings.group(name). Session-only for now (persistence is off).
-- Joining is silent: both groups stay muted until the loading screen is done (it sets
-- the LoadingDone attribute on the local player) and the player's saved profile has
-- arrived (State.loaded), then WAKE_HOLD seconds more; then they fade up over WAKE_FADE. Settings.awake() is false until the fade
-- starts, and Sfx drops cues until then rather than playing them silently.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Settings = {}
local values = { music = 0.5, sfx = 0.8, reducedEffects = false }
local listeners = {}
local WAKE_HOLD, WAKE_FADE, WAKE_LIMIT = 1.5, 2.5, 45
local wake, awake = 0, false

function Settings.group(name)
    local group = SoundService:FindFirstChild(name)
    if not group then
        group = Instance.new("SoundGroup")
        group.Name = name
        group.Parent = SoundService
    end
    return group
end

local function apply()
    Settings.group("Music").Volume = values.music * wake
    Settings.group("SFX").Volume = values.sfx * wake
end

function Settings.awake()
    return awake
end

function Settings.get(key)
    return values[key]
end

function Settings.set(key, value)
    if values[key] == value then return end
    values[key] = value
    apply()
    for _, fn in listeners do task.spawn(fn, values) end
end

function Settings.subscribe(fn)
    table.insert(listeners, fn)
    task.spawn(fn, values)
end

apply()
task.spawn(function()
    local player = Players.LocalPlayer
    local giveUp = os.clock() + WAKE_LIMIT
    local State = require(script.Parent.State)
    while not (player:GetAttribute("LoadingDone") and State.loaded(State.get())) and os.clock() < giveUp do task.wait(0.1) end
    task.wait(WAKE_HOLD)
    awake = true
    local started = os.clock()
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local t = math.min(1, (os.clock() - started) / WAKE_FADE)
        wake = t * t
        apply()
        if t >= 1 then connection:Disconnect() end
    end)
end)
return Settings
