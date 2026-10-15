-- The reference's bottom-right action cluster: one row of round buttons (LEAVE,
-- DROP, GRAB/PLACE, JUMP from left to right). ActionController.cluster() is the
-- shared row other controllers parent their buttons to (LayoutOrder sets the
-- place); ActionController.touch says whether touch-only buttons show.
-- On touch devices this also replaces Roblox's jump button with a matching JUMP.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local ActionController = {}
ActionController.touch = UserInputService.TouchEnabled

function ActionController.cluster()
    local gui = Create.screen("RocketHUD")
    local row = gui:FindFirstChild("ActionCluster")
    if row then return row end
    row = Create.new("Frame", {
        Name = "ActionCluster", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -Theme.gutter, 1, -30),
        Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Parent = gui,
    })
    Create.new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = row,
    })
    return row
end

function ActionController.start()
    local row = ActionController.cluster()
    if not ActionController.touch then return end
    local player = Players.LocalPlayer
    local held
    local jump = Button.new({
        Name = "Jump", shape = "circle", icon = Theme.icon.Jump, caption = "JUMP", color = Theme.color.Speed,
        Size = UDim2.fromOffset(84, 84), LayoutOrder = 4, Parent = row,
    })
    jump.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then held = input end
    end)
    UserInputService.InputEnded:Connect(function(input) if input == held then held = nil end end)
    -- Holding JUMP keeps jumping, like Roblox's own button.
    RunService.RenderStepped:Connect(function()
        local humanoid = held and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Jump = true end
    end)
    -- Hide Roblox's jump button (it would sit under the cluster); its script may
    -- re-show it on respawn, so keep it hidden.
    task.spawn(function()
        local touchGui = player:WaitForChild("PlayerGui"):WaitForChild("TouchGui", 30)
        local frame = touchGui and touchGui:WaitForChild("TouchControlFrame", 10)
        local default = frame and frame:WaitForChild("JumpButton", 10)
        if not default then return end
        default.Visible = false
        default:GetPropertyChangedSignal("Visible"):Connect(function() default.Visible = false end)
    end)
end

return ActionController
