-- The reference's bottom-right action cluster: one row of round buttons (LEAVE,
-- DROP, GRAB/PLACE, JUMP from left to right; a 2×2 grid on touch).
-- ActionController.cluster() is the shared frame other controllers parent their
-- buttons to (LayoutOrder sets the place); ActionController.touch says whether
-- touch-only buttons show.
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
-- Phones: touch on a short screen (Roblox's own small-screen test: the shorter side at
-- most 500), unlike tablets and touch laptops. The whole HUD is already shrunk to fit a
-- phone, so there the touch enlargements below are trimmed to keep the view clear.
-- The camera reports a 1×1 viewport for the first seconds of a session, so touch devices
-- wait (up to 5 s; then they keep the full touch layout) for the real one.
local viewport = Vector2.zero
if ActionController.touch then
    local deadline = os.clock() + 5
    while (not workspace.CurrentCamera or workspace.CurrentCamera.ViewportSize.Y <= 1) and os.clock() < deadline do task.wait() end
    viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or viewport
end
ActionController.phone = ActionController.touch and viewport.Y > 1 and math.min(viewport.X, viewport.Y) <= 500
-- How much touch screens enlarge the left stat stack (HudController; SHOP and INVITE sit
-- under it) and the bottom progress group (ProgressController; the fill row and toasts
-- sit above it).
ActionController.stackScale = ActionController.phone and 1 or ActionController.touch and 1.25 or 1
ActionController.progressScale = ActionController.phone and 1.1 or ActionController.touch and 1.35 or 1

-- Touch layout: a fixed 2×2 grid so a button never shifts when another appears.
-- Slots by LayoutOrder (cell centres in design px): LEAVE top right, DROP top left,
-- GRAB/PLACE bottom left, JUMP bottom right.
local CELL, GAP, CAPTION = 84, 16, 24
local SLOTS = {
    [1] = Vector2.new(CELL * 1.5 + GAP, CELL / 2),
    [2] = Vector2.new(CELL / 2, CELL / 2),
    [3] = Vector2.new(CELL / 2, CELL * 1.5 + CAPTION),
    [4] = Vector2.new(CELL * 1.5 + GAP, CELL * 1.5 + CAPTION),
}
-- Smallest on-screen button, in real pixels (Roblox's own phone jump button is 70).
local MIN_TOUCH_PX = 70

local function touchGrid(gui)
    local grid = Create.new("Frame", {
        Name = "ActionCluster", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -Theme.gutter, 1, -30),
        Size = UDim2.fromOffset(CELL * 2 + GAP, (CELL + CAPTION) * 2), BackgroundTransparency = 1, Parent = gui,
    })
    -- The whole HUD shrinks to fit a phone; the buttons you thumb must not.
    local screenScale = gui:FindFirstChildOfClass("UIScale")
    local scale = Create.new("UIScale", { Name = "TouchScale", Parent = grid })
    local function fit()
        local s = screenScale and screenScale.Scale or 1
        scale.Scale = math.max(1, MIN_TOUCH_PX / (CELL * s))
    end
    if screenScale then screenScale:GetPropertyChangedSignal("Scale"):Connect(fit) end
    fit()
    local function place(child)
        local slot = child:IsA("GuiObject") and SLOTS[child.LayoutOrder]
        if not slot then return end
        child.AnchorPoint = Vector2.new(0.5, 0.5)
        child.Position = UDim2.fromOffset(slot.X, slot.Y)
    end
    grid.ChildAdded:Connect(place)
    return grid
end

function ActionController.cluster()
    local gui = Create.screen("RocketHUD")
    local row = gui:FindFirstChild("ActionCluster")
    if row then return row end
    if ActionController.touch then return touchGrid(gui) end
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
        Size = UDim2.fromOffset(84, 84), LayoutOrder = 4, sound = false, Parent = row,
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
