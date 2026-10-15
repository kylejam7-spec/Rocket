-- Gym stations: the Leave-station button, E/ButtonB to exit, and hiding the
-- station prompts while this player trains.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local TrainingController = {}

function TrainingController.start()
    local exitTraining = State.remote("ExitTraining")
    -- One explicit exit action works on keyboard, controller and touch.
    local exitButton = Button.new({
        themed = false,
        Name = "LeaveStation",
        Size = UDim2.fromOffset(220, 48),
        Position = UDim2.new(0.5, -110, 1, -72),
        BackgroundColor3 = Theme.color.Action,
        Text = "Leave station [E]",
        TextSize = 20,
        Visible = false,
        onActivated = function() exitTraining:FireServer() end,
        Parent = Create.screen("RocketHUD"),
    })

    local bound, mountedAt = false, 0
    State.subscribe(function(state)
        local active = state.training ~= nil
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
