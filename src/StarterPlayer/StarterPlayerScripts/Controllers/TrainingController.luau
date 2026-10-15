-- Gym stations: the round LEAVE button in the action cluster, E/ButtonB to exit,
-- and hiding the station prompts while this player trains. Stat popups live in
-- HudController.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local State = require(script.Parent.State)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Tween = require(UI.Tween)
local TrainingController = {}

function TrainingController.start()
    local exitTraining = State.remote("ExitTraining")
    -- One explicit exit action works on keyboard, controller and touch.
    local exitButton = Button.new({
        Name = "LeaveStation",
        shape = "circle",
        icon = Theme.icon.Leave,
        caption = Actions.touch and "LEAVE" or "LEAVE [E]",
        color = Theme.color.Danger,
        Size = UDim2.fromOffset(72, 72),
        LayoutOrder = 1,
        Visible = false,
        onActivated = function() exitTraining:FireServer() end,
        Parent = Actions.cluster(),
    })

    local bound, mountedAt = false, 0
    State.subscribe(function(state)
        local active = state.training ~= nil
        if active and not exitButton.Visible then Tween.bounce(exitButton, 1.25, 0.4) end
        exitButton.Visible = active
        if active and not bound then
            ContextActionService:BindActionAtPriority("ExitGym", function(_, inputState)
                if inputState == Enum.UserInputState.Begin then exitTraining:FireServer() end
                return Enum.ContextActionResult.Sink
            end, false, 3000, Enum.KeyCode.E, Enum.KeyCode.ButtonB)
        elseif not active and bound then
            ContextActionService:UnbindAction("ExitGym")
        end
        bound = active

        if active and mountedAt == 0 then mountedAt = os.clock() end
        if not active then mountedAt = 0 end
        for _, station in CollectionService:GetTagged("TrainingStation") do
            local prompt = station:FindFirstChildOfClass("ProximityPrompt")
            if prompt then prompt.Enabled = not active end
        end
    end)
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E and mountedAt > 0 and os.clock() - mountedAt > 0.3 then
            exitTraining:FireServer()
        end
    end)
end

return TrainingController
