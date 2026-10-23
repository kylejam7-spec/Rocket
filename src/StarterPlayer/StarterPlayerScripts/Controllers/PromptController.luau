-- Reference-style proximity prompts: a dark gold-rimmed card with the object
-- name, a big action word and a key chip, popping in with a bounce. Prompts are
-- switched to Custom style locally; Roblox still handles key/gamepad input, and
-- tapping or clicking the card drives InputHoldBegin/End for touch.
-- PromptController.onPress(fn) calls fn(prompt, input) when a finger or click lands
-- on a card (CargoController starts the material hold from it).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local Tween = require(UI.Tween)
local PromptController = {}
local pressListeners = {}

function PromptController.onPress(fn)
    table.insert(pressListeners, fn)
end

local GAMEPAD = { ButtonX = "X", ButtonY = "Y", ButtonA = "A", ButtonB = "B" }

local function keyText(prompt, inputType)
    if inputType == Enum.ProximityPromptInputType.Touch then return "TAP" end
    if inputType == Enum.ProximityPromptInputType.Gamepad then
        return GAMEPAD[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
    end
    return prompt.KeyboardKeyCode.Name
end

local function build(prompt, inputType)
    -- No object name (gym stations): a narrower card, the action word centred beside the key.
    local named = prompt.ObjectText ~= ""
    local billboard = Create.new("BillboardGui", {
        Name = "Prompt", Adornee = prompt.Parent, AlwaysOnTop = true, Active = true,
        LightInfluence = 0, Size = UDim2.fromOffset(named and 250 or 170, 76), StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0), Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
    })
    local card = Create.new("TextButton", {
        Name = "Card", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.1, Parent = billboard,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = card })
    Create.new("UIStroke", { Thickness = 3, Color = Theme.color.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
    local chip = Create.new("Frame", {
        Name = "Key", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Theme.color.Gold, Parent = card,
    })
    Theme.shine(chip)
    Create.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = chip })
    Create.new("UIStroke", { Thickness = 2.5, Color = Theme.color.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip })
    local key = keyText(prompt, inputType)
    StrokedText.new({
        Size = UDim2.fromScale(1, 1), Text = key, Font = Theme.font.Display,
        TextSize = #key > 1 and 16 or 28, stroke = 2, Parent = chip,
    })
    -- Hold progress for prompts with a HoldDuration.
    local hold = Create.new("Frame", {
        Name = "Hold", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 0), BackgroundColor3 = Theme.color.White, BackgroundTransparency = 0.4, Parent = chip,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = hold })
    if named then
        StrokedText.new({
            Name = "Object", Position = UDim2.fromOffset(68, 8), Size = UDim2.new(1, -78, 0, 20),
            Text = prompt.ObjectText, Font = Theme.font.Display, TextSize = 16, TextColor3 = Theme.color.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.5, Parent = card,
        })
    end
    local action = StrokedText.new({
        Name = "Action", Position = UDim2.fromOffset(68, named and 28 or 20), Size = UDim2.new(1, -78, 0, 36),
        Text = prompt.ActionText, Font = Theme.font.Display, TextSize = 28, TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 2.5, Parent = card,
    })
    Create.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = action })

    local connections = {
        card.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                for _, fn in pressListeners do task.spawn(fn, prompt, input) end
                prompt:InputHoldBegin()
            end
        end),
        card.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                prompt:InputHoldEnd()
            end
        end),
        prompt.PromptButtonHoldBegan:Connect(function()
            if prompt.HoldDuration > 0 then Tween.play(hold, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }) end
        end),
        prompt.PromptButtonHoldEnded:Connect(function() hold.Size = UDim2.fromScale(1, 0) end),
        prompt.Triggered:Connect(function() Tween.bounce(card, 1.12, 0.25) end),
        prompt:GetPropertyChangedSignal("ActionText"):Connect(function() action.Text = prompt.ActionText end),
    }
    Tween.bounce(card, 0.6, 0.3)
    return function()
        for _, connection in connections do connection:Disconnect() end
        billboard:Destroy()
    end
end

function PromptController.start()
    local function adopt(item)
        if item:IsA("ProximityPrompt") then item.Style = Enum.ProximityPromptStyle.Custom end
    end
    workspace.DescendantAdded:Connect(adopt)
    for _, item in workspace:GetDescendants() do adopt(item) end

    local open = {}
    ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
        if open[prompt] then open[prompt]() end
        open[prompt] = build(prompt, inputType)
    end)
    ProximityPromptService.PromptHidden:Connect(function(prompt)
        if open[prompt] then open[prompt]() end
        open[prompt] = nil
    end)
end

return PromptController
