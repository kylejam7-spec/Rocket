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
-- the surface and moves along the ramp's plane at its full walk speed; the same on the
-- bridges across the hull between the ramps. That stays within the server's move limit,
-- which only counts horizontal movement.
-- Inside the rocket's cabin (the floor tagged RocketCabin, its CabinSize attribute) a
-- late-game runner covers more than a wall's thickness in one physics step and slipped
-- out through the walls. After each step, anyone who was inside is kept inside: back
-- within the walls, their speed outward dropped. Only the exit hatch (a server teleport
-- far out of the room) or the flight takes them out.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SpeedController = {}

local MAX_RISE, MAX_RUN = 1.15, 1.3
-- RocketBuildService's climbing ramps and the bridges across the hull between them.
local RAMPS = { LaunchRamp = true, RampBridge = true }

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
    if not hit or not RAMPS[hit.Instance.Name] then return end
    local normal = hit.Normal
    -- Only from on top: a runner under a ramp (its underside within a standing height
    -- over their head) found its top surface with this cast and was lifted up through it.
    if (root.Position - hit.Position):Dot(normal) < 0 then return end
    local along = move - normal * move:Dot(normal)
    if along.Magnitude < 0.05 then return end
    local sunk = hit.Position.Y + stand - root.Position.Y
    if sunk > 0 then root.CFrame += Vector3.new(0, sunk, 0) end
    local velocity = along.Unit * humanoid.WalkSpeed * math.min(1, move.Magnitude)
    -- Uphill, never past the ramp's StopAt (just short of its end rail) this step: holding
    -- W stops at the rail instead of launching over it. A jump still clears it.
    local ramp = hit.Instance
    local at = ramp.CFrame:PointToObjectSpace(hit.Position)
    local stopAt = ramp:GetAttribute("StopAt")
    if stopAt then
        local up = ramp.CFrame.UpVector
        local climb = velocity:Dot(up)
        local room = math.max(0, stopAt - at.Y)
        if climb > room / dt then velocity -= up * (climb - room / dt) end
    end
    -- Across, never past EdgeAt (just inside the outer guard wall): a runner held against
    -- the wall at full speed climbed over it. Crossing a bridge heads straight for it.
    local edgeAt = ramp:GetAttribute("EdgeAt")
    if edgeAt then
        local out = ramp.CFrame.RightVector * math.sign(edgeAt)
        local across = velocity:Dot(out)
        local room = math.max(0, (edgeAt - at.X) * math.sign(edgeAt))
        if across > room / dt then velocity -= out * (across - room / dt) end
    end
    root.AssemblyLinearVelocity = velocity
end

-- The cabin's inside as a box: its centre (floor top) and half size, or nil.
local function cabinBox()
    local floor = CollectionService:GetTagged("RocketCabin")[1]
    local size = floor and floor:GetAttribute("CabinSize")
    if not size then return nil end
    return floor.Position + Vector3.new(0, floor.Size.Y / 2, 0), size / 2
end

local CABIN_MARGIN = 1.4 -- studs the root stays off each wall
local wasInside = false
local function keepInCabin(root)
    local center, half = cabinBox()
    if not center then return end
    local offset = root.Position - center
    local inside = math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and offset.Y >= -2 and offset.Y <= half.Y * 2 + 2
    -- Just out after being in (not teleported away): put back within the walls.
    local near = math.abs(offset.X) <= half.X + 40 and math.abs(offset.Z) <= half.Z + 40 and offset.Y > -40 and offset.Y < half.Y * 2 + 40
    if not inside and wasInside and near then
        local x = math.clamp(offset.X, -half.X + CABIN_MARGIN, half.X - CABIN_MARGIN)
        local z = math.clamp(offset.Z, -half.Z + CABIN_MARGIN, half.Z - CABIN_MARGIN)
        local y = math.clamp(offset.Y, 3, half.Y * 2 - 3)
        root.CFrame = root.CFrame.Rotation + center + Vector3.new(x, y, z)
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(0, math.min(velocity.Y, 0), 0)
        return
    end
    wasInside = inside
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
        if not root or root.Anchored then wasInside = false return end
        keepInCabin(root)
        if humanoid.SeatPart or humanoid.FloorMaterial ~= Enum.Material.Air then return end
        local velocity = root.AssemblyLinearVelocity
        local rise, run = jumpSpeed(humanoid) * MAX_RISE, humanoid.WalkSpeed * MAX_RUN
        local flat = Vector3.new(velocity.X, 0, velocity.Z)
        if velocity.Y <= rise and flat.Magnitude <= run then return end
        if flat.Magnitude > run then flat = flat.Unit * run end
        root.AssemblyLinearVelocity = Vector3.new(flat.X, math.min(velocity.Y, rise), flat.Z)
    end)
end

return SpeedController
