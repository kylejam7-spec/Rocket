-- Each player sees their own lock status on the gym signs (local-only text change).
local CollectionService = game:GetService("CollectionService")
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent:WaitForChild("UI").Theme)
local GymSignController = {}

function GymSignController.start()
    State.subscribe(function(state)
        if not state.profile then return end
        local launches = state.profile.completedLaunches
        for _, sign in CollectionService:GetTagged("GymSign") do
            local required = sign:GetAttribute("RequiredCycles")
            local status = required and sign:FindFirstChild("SignText") and sign.SignText:FindFirstChild("Status")
            if status then
                if launches >= required then
                    status.Text = "UNLOCKED"
                    status.TextColor3 = Theme.color.Unlocked
                else
                    status.Text = "LOCKED • " .. launches .. "/" .. required .. (required == 1 and " launch" or " launches")
                    status.TextColor3 = Theme.color.Locked
                end
            end
        end
    end)
end

return GymSignController
