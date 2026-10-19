-- Player settings shared by every controller: music and SFX volume (0..1) and
-- reduced effects. Settings.get(key), Settings.set(key, value), and
-- Settings.subscribe(fn(settings)), which replays the current values right away.
-- Volumes drive the "Music" and "SFX" SoundGroups; any future sound joins one of
-- them with Settings.group(name). Session-only for now (persistence is off).
local SoundService = game:GetService("SoundService")
local Settings = {}
local values = { music = 0.5, sfx = 0.8, reducedEffects = false }
local listeners = {}

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
    Settings.group("Music").Volume = values.music
    Settings.group("SFX").Volume = values.sfx
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
return Settings
