-- Carried materials: the round DROP button and the hold/E input that streams
-- pickups and placements while a material prompt is held.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Tween = require(UI.Tween)
local CargoController = {}

function CargoController.start()
    local discardCargo = State.remote("DiscardCargo")
    -- Round action button in the bottom-right cluster, like the reference's drop button.
    local discardButton = Button.new({
        Name = "DiscardCargo",
        shape = "circle",
        icon = Theme.icon.Drop,
        caption = "DROP",
        color = Theme.color.Purple,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -28, 1, -70),
        Size = UDim2.fromOffset(72, 72),
        Visible = false,
        onActivated = function() discardCargo:FireServer() end,
        Parent = Create.screen("RocketHUD"),
    })
    State.subscribe(function(state)
        local show = state.cargo ~= nil
        if show and not discardButton.Visible then Tween.bounce(discardButton, 1.3, 0.4) end
        discardButton.Visible = show
    end)

    -- PromptButtonHoldEnded fires at completion, so use physical input release instead.
    local materialHold = State.remote("MaterialHold")
    local activeMaterialPrompt
    local function stopMaterialHold()
        if not activeMaterialPrompt then return end
        materialHold:FireServer(activeMaterialPrompt, false)
        activeMaterialPrompt = nil
    end
    local function startMaterialHold(item)
        local world = workspace:FindFirstChild("RocketWorld")
        if not world or not item:IsDescendantOf(world) or not item.Enabled then return end
        if not (item.ActionText:match("^Pick up ") or item.ActionText:match("^Place ")) then return end
        if activeMaterialPrompt == item then return end
        stopMaterialHold()
        activeMaterialPrompt = item
        materialHold:FireServer(item, true)
    end
    ProximityPromptService.PromptButtonHoldBegan:Connect(startMaterialHold)
    -- Holding the key while walking up starts the transfer as soon as the prompt appears.
    ProximityPromptService.PromptShown:Connect(function(item)
        if UserInputService:GetFocusedTextBox() then return end
        if UserInputService:IsKeyDown(item.KeyboardKeyCode)
            or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, item.GamepadKeyCode) then
            startMaterialHold(item)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        local item = activeMaterialPrompt
        if item and (input.KeyCode == item.KeyboardKeyCode or input.KeyCode == item.GamepadKeyCode
            or input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1) then
            stopMaterialHold()
        end
    end)
    UserInputService.WindowFocusReleased:Connect(stopMaterialHold)
    ProximityPromptService.PromptHidden:Connect(function(item)
        if activeMaterialPrompt == item then stopMaterialHold() end
    end)
    Players.LocalPlayer.CharacterRemoving:Connect(stopMaterialHold)
end

return CargoController
