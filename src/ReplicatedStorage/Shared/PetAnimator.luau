-- Plays an imported pet's own animations by writing its Bones' Transform, so nothing
-- has to be uploaded as an animation asset. Each model in ReplicatedStorage.PetModels
-- carries Clips/Idle and Clips/Move (KeyframeSequences from its FBX: Idle and Walk,
-- or Flying_Idle and Fast_Flying for flyers). Clips are compiled once per pet into
-- per-bone key lists and shared by every copy.
--   local animator = PetAnimator.new(model)   -- nil for stand-ins (no Clips)
--   animator:step(dt, moving)                 -- moving 0..1 blends Idle into Move
local PetAnimator = {}
PetAnimator.__index = PetAnimator

local compiled = {} -- KeyframeSequence -> clip

-- { length, tracks = { [bone name] = { times = {...}, frames = { CFrame... } } } }
local function compile(sequence)
    local clip = compiled[sequence]
    if clip then return clip end
    local keyframes = sequence:GetKeyframes()
    table.sort(keyframes, function(a, b) return a.Time < b.Time end)
    local tracks, length = {}, 0
    for _, keyframe in keyframes do
        length = math.max(length, keyframe.Time)
        for _, pose in keyframe:GetDescendants() do
            if pose:IsA("Pose") then
                local track = tracks[pose.Name]
                if not track then
                    track = { times = {}, frames = {} }
                    tracks[pose.Name] = track
                end
                table.insert(track.times, keyframe.Time)
                table.insert(track.frames, pose.CFrame)
            end
        end
    end
    clip = { length = math.max(length, 1 / 30), tracks = tracks }
    compiled[sequence] = clip
    return clip
end

-- The track's pose at time t (linear between keys, held past the ends).
local function sample(track, t)
    local times, frames = track.times, track.frames
    local count = #times
    if count == 1 or t <= times[1] then return frames[1] end
    if t >= times[count] then return frames[count] end
    local low, high = 1, count
    while high - low > 1 do
        local mid = (low + high) // 2
        if times[mid] <= t then low = mid else high = mid end
    end
    local span = times[high] - times[low]
    return frames[low]:Lerp(frames[high], span > 0 and (t - times[low]) / span or 0)
end

function PetAnimator.new(model)
    local clips = model:FindFirstChild("Clips")
    local idle = clips and clips:FindFirstChild("Idle")
    if not idle then return nil end
    local move = clips:FindFirstChild("Move") or idle
    local bones = {}
    for _, bone in model:GetDescendants() do
        if bone:IsA("Bone") then bones[bone.Name] = bone end
    end
    return setmetatable({
        bones = bones, idle = compile(idle), move = compile(move),
        idleTime = math.random() * 2, moveTime = 0, blend = 0, model = model,
    }, PetAnimator)
end

function PetAnimator:step(dt, moving)
    self.blend += (moving - self.blend) * (1 - math.exp(-8 * dt))
    self.idleTime = (self.idleTime + dt) % self.idle.length
    self.moveTime = (self.moveTime + dt) % self.move.length
    -- Keys are in the imported model's units; copies are scaled down (and grow in
    -- while a UFO lands them).
    local blend, scale = self.blend, self.model:GetScale()
    for name, bone in self.bones do
        local idleTrack, moveTrack = self.idle.tracks[name], self.move.tracks[name]
        if idleTrack or moveTrack then
            local pose = idleTrack and sample(idleTrack, self.idleTime) or CFrame.identity
            if moveTrack and blend > 0.01 then pose = pose:Lerp(sample(moveTrack, self.moveTime), blend) end
            bone.Transform = pose.Rotation + pose.Position * scale
        end
    end
end

return PetAnimator
