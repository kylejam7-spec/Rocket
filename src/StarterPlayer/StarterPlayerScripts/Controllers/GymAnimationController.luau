-- Treadmill runs and bench presses. The server poses the anchored body and stamps
-- OccupantId and TrainingSince on the station (TrainingService); every client then
-- animates its own copy of the equipment: the belt's slats scroll, and the barbell
-- leaves the rack and goes up and down in the lifter's hands (two-bone IK), feet up
-- on the bench. One rep per gain tick, locking out as it pays.
-- On the treadmill the runner's own client also plays its avatar's run, which the
-- Animator replicates to everyone else.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local GymAnimationController = {}

local LIFT_SECONDS = 0.35 -- rack to lockout on mount
local DEFAULT_RUN = "rbxassetid://913376220"

local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

-- 1 at lockout, 0 with the bar at the chest. Lockout lands on each gain tick:
-- hold briefly, lower slowly, press quickly.
local function press(phase)
    if phase < 0.15 then return 1 end
    if phase < 0.65 then return 1 - smooth((phase - 0.15) / 0.5) end
    local t = (phase - 0.65) / 0.35
    return 1 - (1 - t) ^ 2
end

local function treadmill(station, character, player)
    local belt = station:FindFirstChild("TreadmillBelt")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not belt or not humanoid then return nil end
    local slats = {}
    for _, slat in belt:GetChildren() do
        if slat.Name == "TreadmillSlat" then table.insert(slats, { part = slat, rest = slat.CFrame }) end
    end
    -- Belt speed to match the run cycle's stride, which grows with the avatar.
    local speed = 5 * humanoid.HipHeight
    local track
    if player == Players.LocalPlayer then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        local animate = character:FindFirstChild("Animate")
        local run = animate and animate:FindFirstChild("run")
        local animation = run and run:FindFirstChildOfClass("Animation")
        if not animation then
            animation = Instance.new("Animation")
            animation.AnimationId = DEFAULT_RUN
        end
        if animator then
            track = animator:LoadAnimation(animation)
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            track:Play(0.2)
        end
    end
    local span, shift = belt.Size.Z, 0
    return {
        animate = function(dt)
            -- Slats run back toward +Z under the runner, wrapping round the rollers.
            shift = (shift + speed * dt) % span
            for _, slat in slats do
                local z = slat.rest.Position.Z - belt.Position.Z
                slat.part.CFrame = slat.rest + Vector3.new(0, 0, (z + span / 2 + shift) % span - span / 2 - z)
            end
        end,
        finish = function()
            for _, slat in slats do slat.part.CFrame = slat.rest end
            if track then track:Stop(0.2) end
        end,
    }
end

-- A joint's frames in its two parts, for Motor6D and AnimationConstraint rigs alike:
-- Part1 = Part0 * c0 * Transform * c1:Inverse().
local function frames(joint)
    if joint:IsA("Motor6D") then return joint.C0, joint.C1 end
    return joint.Attachment0.CFrame, joint.Attachment1.CFrame
end

local function joint(character, name)
    local found = character:FindFirstChild(name, true)
    return found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) and found or nil
end

-- Two-bone arm IK: bends the elbow until the grip is as far from the shoulder as
-- the target, then turns the shoulder so the grip lands on it with the elbow
-- toward the pole. Returns a function(target, pole) that writes the Transforms.
local function armSolver(character, side, torso)
    local shoulder, elbow, wrist = joint(character, side .. "Shoulder"), joint(character, side .. "Elbow"), joint(character, side .. "Wrist")
    local hand = character:FindFirstChild(side .. "Hand")
    if not shoulder or not elbow or not wrist or not hand then return nil end
    local s0, s1 = frames(shoulder)
    local e0, e1 = frames(elbow)
    local w0, w1 = frames(wrist)
    local grip = hand:FindFirstChild(side .. "GripAttachment")
    -- Everything in the shoulder's child frame: the elbow's frame, and the grip as
    -- the elbow sees it (wrist held straight).
    local elbowFrame = s1:Inverse() * e0
    local gripPoint = e1:Inverse() * (w0 * w1:Inverse() * (grip and grip.Position or Vector3.zero))
    local function reach(angle)
        return elbowFrame * (CFrame.Angles(angle, 0, 0) * gripPoint)
    end
    local function basis(forward, side)
        local x = forward.Unit
        local y = (side - x * side:Dot(x)).Unit
        return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
    end
    local longest = reach(0).Magnitude
    return function(target, pole)
        local frame = torso.CFrame * s0
        local goal, toward = frame:PointToObjectSpace(target), frame:PointToObjectSpace(pole)
        local distance = goal.Magnitude
        -- Reach shrinks as the elbow folds (positive X bends the forearm forward).
        local low, high = 0, math.rad(165)
        if distance >= longest then
            high = 0
        else
            for _ = 1, 14 do
                local mid = (low + high) / 2
                if reach(mid).Magnitude > distance then low = mid else high = mid end
            end
        end
        local bend = CFrame.Angles(high, 0, 0)
        shoulder.Transform = basis(goal, toward) * basis(reach(high), elbowFrame.Position):Inverse()
        elbow.Transform = bend
        wrist.Transform = CFrame.identity
    end, longest
end

local function bench(station, character)
    local bar = station:FindFirstChild("Barbell")
    local torso = character:FindFirstChild("UpperTorso")
    local rightShoulder = torso and torso:FindFirstChild("RightShoulderRigAttachment")
    local leftShoulder = torso and torso:FindFirstChild("LeftShoulderRigAttachment")
    if not bar or not rightShoulder or not leftShoulder then return nil end
    local rest, plates = bar.CFrame, {}
    for _, plate in bar:GetChildren() do
        if plate:IsA("BasePart") then plates[plate] = rest:ToObjectSpace(plate.CFrame) end
    end
    local function place(cframe)
        bar.CFrame = cframe
        for plate, offset in plates do plate.CFrame = cframe * offset end
    end
    local arms, legs, reach = {}, {}, math.huge
    for _, side in { "Right", "Left" } do
        local solve, longest = armSolver(character, side, torso)
        if not solve then return nil end
        arms[side] = solve
        reach = math.min(reach, longest)
        -- Feet up on the bench: thighs raised and a little apart, knees folded back,
        -- soles flat. Angles(x, 0, z) abducts (z) first, then flexes (x).
        local out = side == "Right" and 1 or -1
        for name, angle in { Hip = CFrame.Angles(math.rad(60), 0, math.rad(14) * out),
            Knee = CFrame.Angles(math.rad(-115), 0, 0), Ankle = CFrame.Angles(math.rad(-35), 0, 0) } do
            local found = joint(character, side .. name)
            if found then legs[found] = angle end
        end
    end
    local grip = (rightShoulder.Position - leftShoulder.Position).Magnitude / 2 + 0.35

    local since = station:GetAttribute("TrainingSince") or workspace:GetServerTimeNow()
    local beat = math.max(0.5, Config.TrainingSeconds)
    return {
        animate = function()
            local elapsed = workspace:GetServerTimeNow() - since
            local body = torso.CFrame
            local up, toFeet, right = body.LookVector, -body.UpVector, body.RightVector
            local chest = (rightShoulder.WorldPosition + leftShoulder.WorldPosition) / 2
            -- The bar touches low on the chest and locks out over the shoulders.
            local low = chest + up * (torso.Size.Z / 2 + 0.35) + toFeet * 0.45
            local high = chest + up * math.sqrt(math.max(0, (reach * 0.96) ^ 2 - 0.35 ^ 2))
            local center = low:Lerp(high, press(elapsed % beat / beat))
            local lift = smooth(elapsed / LIFT_SECONDS)
            local cframe = rest:Lerp(CFrame.fromMatrix(center, rest.RightVector, rest.UpVector), lift)
            place(cframe)
            -- Elbows flare out and drop toward the floor.
            for side, solve in arms do
                local out = side == "Right" and right or -right
                local hold = cframe.Position + out * grip
                solve(hold, hold + out * 2 - up * 1.5 + toFeet * 0.8)
            end
            for found, angle in legs do found.Transform = angle end
        end,
        finish = function()
            for found in legs do found.Transform = CFrame.identity end
            for _, name in { "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist" } do
                local found = joint(character, name)
                if found then found.Transform = CFrame.identity end
            end
            place(rest)
        end,
    }
end

function GymAnimationController.start()
    local active = {}
    local function sync()
        for station, session in active do
            local id = station:GetAttribute("OccupantId")
            local player = id and Players:GetPlayerByUserId(id)
            if not station.Parent or not player or player.Character ~= session.character then
                session.finish()
                active[station] = nil
            end
        end
        for _, station in CollectionService:GetTagged("TrainingStation") do
            local id = station:GetAttribute("OccupantId")
            local player = id and Players:GetPlayerByUserId(id)
            local character = player and player.Character
            if character and not active[station] then
                local build = station:GetAttribute("TrainingStat") == "speedLevel" and treadmill or bench
                local session = build(station, character, player)
                if session then
                    session.character = character
                    active[station] = session
                end
            end
        end
    end
    -- After the Animator has stepped, so these poses win over anything it wrote.
    RunService.PreSimulation:Connect(function(dt)
        sync()
        for _, session in active do session.animate(dt) end
    end)
end

return GymAnimationController
