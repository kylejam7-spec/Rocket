-- Late-game walk speed reaches 400 (Config.MaxSpeed). At that speed Roblox's humanoid
-- trips over every kerb and seam (FallingDown, then Ragdoll), flinging the character
-- and tripping the server's anti-teleport snap-back. Your own character's states are
-- yours to set, so this turns tripping off on every spawn.
-- Clipping a ledge (a treadmill, a kerb) at full speed also threw the character high into
-- the air: the step-up and collision push came out as a huge upward velocity. Your own
-- character's physics are yours too, so after each physics step, while airborne (no floor
-- under it: the state lags, staying Running for several steps of a fling, but
-- FloorMaterial turns Air within two), its rise is held to a jump's (MAX_RISE x the jump
-- speed in this gravity) and its sideways speed to its walk speed (MAX_RUN x). Nothing in
-- the game launches characters with velocity: flights move them by CFrame, anchored.
-- The rocket ramps are a smooth slide at any speed: a humanoid only lifts itself onto
-- rising ground at ~45 studs/s, so at a late-game walk speed it sank into the 40-degree
-- ramp, dragged along it at ~75 studs/s and bounced off its foot. While running on a
-- LaunchRamp, before each physics step the character is held at standing height over
-- the surface and moves along the ramp's plane at its full walk speed. That stays within
-- the server's move limit, which only counts horizontal movement.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SpeedController = {}

local MAX_RISE, MAX_RUN = 1.15, 1.3
local RAMP = "LaunchRamp" -- RocketBuildService's climbing ramps

local function noTripping(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end

-- A jump's launch speed for `humanoid` in this gravity.
local function jumpSpeed(humanoid)
    if humanoid.UseJumpPower then return humanoid.JumpPower end
    return math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
end

local rampParams = RaycastParams.new()
rampParams.FilterType = Enum.RaycastFilterType.Exclude

-- Runs the character along the ramp under it: no sinking in, no drag, no launch off a seam.
local function rampSlide(character, humanoid, root, dt)
    local move = humanoid.MoveDirection
    if move.Magnitude < 0.1 then return end
    local state = humanoid:GetState()
    if state ~= Enum.HumanoidStateType.Running and state ~= Enum.HumanoidStateType.RunningNoPhysics then return end
    -- Cast from a standing height above the root, so a root already sunk into the ramp
    -- still finds its surface.
    local stand = humanoid.HipHeight + root.Size.Y / 2
    rampParams.FilterDescendantsInstances = { character }
    local hit = workspace:Raycast(root.Position + Vector3.new(0, stand, 0), Vector3.new(0, -(2 * stand + 3), 0), rampParams)
    if not hit or hit.Instance.Name ~= RAMP then return end
    local normal = hit.Normal
    local along = move - normal * move:Dot(normal)
    if along.Magnitude < 0.05 then return end
    local sunk = hit.Position.Y + stand - root.Position.Y
    if sunk > 0 then root.CFrame += Vector3.new(0, sunk, 0) end
    local velocity = along.Unit * humanoid.WalkSpeed * math.min(1, move.Magnitude)
    -- Uphill, never past the ramp's StopAt (just short of its end rail) this step: holding
    -- W stops at the rail instead of launching over it. A jump still clears it.
    local stopAt = hit.Instance:GetAttribute("StopAt")
    if stopAt then
        local up = hit.Instance.CFrame.UpVector
        local climb = velocity:Dot(up)
        local room = math.max(0, stopAt - hit.Instance.CFrame:PointToObjectSpace(hit.Position).Y)
        if climb > room / dt then velocity -= up * (climb - room / dt) end
    end
    root.AssemblyLinearVelocity = velocity
end

function SpeedController.start()
    local player = Players.LocalPlayer
    player.CharacterAdded:Connect(noTripping)
    if player.Character then task.spawn(noTripping, player.Character) end
    RunService.PreSimulation:Connect(function(dt)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
        if not root or root.Anchored or humanoid.SeatPart then return end
        rampSlide(character, humanoid, root, dt)
    end)
    RunService.PostSimulation:Connect(function()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
        if not root or root.Anchored or humanoid.SeatPart or humanoid.FloorMaterial ~= Enum.Material.Air then return end
        local velocity = root.AssemblyLinearVelocity
        local rise, run = jumpSpeed(humanoid) * MAX_RISE, humanoid.WalkSpeed * MAX_RUN
        local flat = Vector3.new(velocity.X, 0, velocity.Z)
        if velocity.Y <= rise and flat.Magnitude <= run then return end
        if flat.Magnitude > run then flat = flat.Unit * run end
        root.AssemblyLinearVelocity = Vector3.new(flat.X, math.min(velocity.Y, rise), flat.Z)
    end)
end

return SpeedController
