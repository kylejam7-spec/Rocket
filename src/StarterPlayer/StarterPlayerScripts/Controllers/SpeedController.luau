-- Late-game walk speed reaches 400 (Config.MaxSpeed). At that speed Roblox's humanoid
-- trips over every kerb and seam (FallingDown, then Ragdoll), flinging the character
-- and tripping the server's anti-teleport snap-back. Your own character's states are
-- yours to set, so this turns tripping off on every spawn.
-- Clipping a ledge (a treadmill, a kerb) at full speed also threw the character high into
-- the air: the step-up and collision push came out as a huge upward velocity. Your own
-- character's physics are yours too, so after each physics step, while airborne (no floor
-- under it: the state lags, staying Running for several steps of a fling, but
-- FloorMaterial turns Air within two), its rise is held to a jump's (MAX_RISE x the jump
-- speed in this gravity) and its sideways speed to its walk speed (MAX_RUN x). Grounded
-- movement (running up the rocket ramp) is never touched, and nothing in the game
-- launches characters with velocity: flights move them by CFrame, anchored.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SpeedController = {}

local MAX_RISE, MAX_RUN = 1.15, 1.3

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

function SpeedController.start()
    local player = Players.LocalPlayer
    player.CharacterAdded:Connect(noTripping)
    if player.Character then task.spawn(noTripping, player.Character) end
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
