-- Plays an imported pet's own animations by writing its Bones' Transform, so nothing
-- has to be uploaded as an animation asset. Each model in ReplicatedStorage.PetModels
-- carries Clips (KeyframeSequences from its FBX): Idle and Move for every form, Run
-- for Large pets, and one-shot moves (Jump, Yes, Dance, Wave, Headbutt...; see
-- PetAnimator.Moves). Clips compile once into per-bone key lists shared by every copy.
--   local animator = PetAnimator.new(model, form)  -- nil for stand-ins (no Clips)
--   animator:step(dt, speed)    -- speed in studs/s: Idle -> Move -> Run, with the
--                               -- step rate matched to the ground speed
--   animator:play("Dance")      -- a one-shot over the base; returns its seconds
local PetAnimator = {}
PetAnimator.__index = PetAnimator

-- Ground speed (studs/s, at pet size) at which each clip's feet keep pace when
-- played at normal speed, and the fastest it may play. Large: measured from the foot
-- travel of the Walk and Run clips at 3 studs tall (~2 and ~3 studs/s). Players run
-- 24-70 studs/s, far past any clip, so above maxRate the pets bound along instead:
-- PetController lifts them in leaps timed to phase(), one per step, and the feet are
-- off the ground while they cover the distance. Blob and flyer gaits are by eye.
PetAnimator.Gaits = table.freeze({
    Blob = table.freeze({ move = 3, maxRate = 2.6 }),
    Large = table.freeze({ move = 2, run = 3, maxRate = 3.5 }),
    Flying = table.freeze({ move = 9, maxRate = 2.2 }),
})
-- One-shots each form has (the rarer the pet, the more of them it uses; PetController).
PetAnimator.Moves = table.freeze({
    Blob = table.freeze({ "Jump", "Yes", "Dance", "Bite", "No" }),
    Large = table.freeze({ "Jump", "Yes", "Wave", "Punch", "Swing" }),
    Flying = table.freeze({ "Yes", "Headbutt", "Punch", "No" }),
})

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

local function approach(value, target, rate, dt)
    return value + (target - value) * (1 - math.exp(-rate * dt))
end

function PetAnimator.new(model, form)
    local clips = model:FindFirstChild("Clips")
    local idle = clips and clips:FindFirstChild("Idle")
    if not idle then return nil end
    local bones = {}
    for _, bone in model:GetDescendants() do
        if bone:IsA("Bone") then bones[bone.Name] = bone end
    end
    local move, run = clips:FindFirstChild("Move"), clips:FindFirstChild("Run")
    return setmetatable({
        model = model, clips = clips, bones = bones, gait = PetAnimator.Gaits[form] or PetAnimator.Gaits.Blob,
        idle = compile(idle), move = compile(move or idle), run = run and compile(run),
        idleTime = math.random() * 2, moveTime = 0, runTime = 0, moving = 0, running = 0,
        action = nil,
    }, PetAnimator)
end

function PetAnimator:has(name)
    return self.clips:FindFirstChild(name) ~= nil
end

-- Plays the one-shot `name` over the base (rate: playback speed). Returns its length
-- in seconds, or nil when this pet doesn't have it.
function PetAnimator:play(name, rate)
    local sequence = self.clips:FindFirstChild(name)
    if not sequence then return nil end
    local clip = compile(sequence)
    rate = rate or 1
    self.action = { clip = clip, time = 0, rate = rate, weight = self.action and self.action.weight or 0 }
    return clip.length / rate
end

function PetAnimator:busy()
    return self.action ~= nil
end

-- How far through its current step the gait is, 0..1 (the Run cycle once running,
-- else the Move cycle), and how much it is running (0..1).
function PetAnimator:phase()
    if self.run and self.running > 0.5 then return self.runTime / self.run.length, self.running end
    return self.moveTime / self.move.length, self.running
end

function PetAnimator:step(dt, speed)
    local gait = self.gait
    -- Idle -> Move from a stroll; Move -> Run (Large) once well past a walk.
    self.moving = approach(self.moving, math.clamp((speed - 0.4) / 2.5, 0, 1), 10, dt)
    local wantRun = self.run and math.clamp((speed - gait.move * 1.6) / (gait.move * 1.4), 0, 1) or 0
    self.running = approach(self.running, wantRun, 8, dt)
    -- Steps keep pace with the ground: the clip speeds up with the pet.
    self.idleTime = (self.idleTime + dt) % self.idle.length
    local moveRate = math.clamp(speed / gait.move, 0.7, gait.maxRate)
    self.moveTime = (self.moveTime + dt * moveRate) % self.move.length
    if self.run then
        local runRate = math.clamp(speed / gait.run, 0.7, gait.maxRate)
        self.runTime = (self.runTime + dt * runRate) % self.run.length
    end
    local action = self.action
    if action then
        action.time += dt * action.rate
        local left = action.clip.length - action.time
        action.weight = left < 0.15 and math.max(0, left / 0.15) or approach(action.weight, 1, 18, dt)
        if left <= 0 then
            self.action, action = nil, nil
        end
    end
    -- Keys are in the imported model's units; copies are scaled down (and grow in
    -- while a UFO lands them).
    local scale = self.model:GetScale()
    local moving, running = self.moving, self.running
    for name, bone in self.bones do
        local idleTrack = self.idle.tracks[name]
        local pose = idleTrack and sample(idleTrack, self.idleTime) or CFrame.identity
        if moving > 0.01 then
            local track = self.move.tracks[name]
            if track then pose = pose:Lerp(sample(track, self.moveTime), moving) end
            if running > 0.01 then
                local runTrack = self.run.tracks[name]
                if runTrack then pose = pose:Lerp(sample(runTrack, self.runTime), moving * running) end
            end
        end
        if action and action.weight > 0.01 then
            local track = action.clip.tracks[name]
            if track then pose = pose:Lerp(sample(track, action.time), action.weight) end
        end
        bone.Transform = pose.Rotation + pose.Position * scale
    end
end

return PetAnimator
