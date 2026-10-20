-- Late-game walk speed reaches 400 (Config.MaxSpeed). At that speed Roblox's humanoid
-- trips over every kerb and seam (FallingDown, then Ragdoll), flinging the character
-- and tripping the server's anti-teleport snap-back. Your own character's states are
-- yours to set, so this turns tripping off on every spawn.
local Players = game:GetService("Players")
local SpeedController = {}

local function noTripping(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end

function SpeedController.start()
    local player = Players.LocalPlayer
    player.CharacterAdded:Connect(noTripping)
    if player.Character then task.spawn(noTripping, player.Character) end
end

return SpeedController
