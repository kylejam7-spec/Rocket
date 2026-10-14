local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateEvent = remotes:WaitForChild("StateUpdated")
local requestState = remotes:WaitForChild("RequestState")
local feedbackEvent = remotes:WaitForChild("Feedback")

local gui = Instance.new("ScreenGui")
gui.Name = "RocketHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.Position = UDim2.fromOffset(16, 16)
frame.Size = UDim2.new(0.9, 0, 0, 360)
frame.BackgroundColor3 = Color3.fromRGB(20, 29, 43)
frame.BackgroundTransparency = 0.08
frame.Parent = gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(440, 360)
constraint.Parent = frame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame
local text = Instance.new("TextLabel")
text.Position = UDim2.fromOffset(16, 12)
text.Size = UDim2.new(1, -32, 1, -24)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.fromRGB(234, 241, 250)
text.Font = Enum.Font.GothamMedium
text.TextSize = 14
text.TextWrapped = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Text = "ROCKET\nConnecting to the server…"
text.Parent = frame

local snapshot
local feedbackText, feedbackUntil = "", 0
local function render()
    if not snapshot then return end
    local state = snapshot
    local remaining = math.max(0, math.ceil(state.deadline - workspace:GetServerTimeNow()))
    local headline = "ROCKET " .. ((state.successfulLaunches or 0) + 1) .. "  •  " .. state.phase
    if state.deadline > 0 then headline ..= "  •  " .. remaining .. "s" end
    local instructions = "Hold E to collect Metal / Fuel. Hold E at a matching rocket section to place."
    if state.phase == "Boarding" then
        instructions = state.boarded and "ABOARD — stay INSIDE the rocket until departure." or "BOARD NOW — enter the open end of the rocket before the timer ends."
    elseif state.phase == "Launching" then
        instructions = state.passenger and "You made it! Launching to Meadow…" or "You missed this launch. The next build starts shortly."
    elseif state.phase == "Rewarding" then
        instructions = state.passenger and "Meadows: +3 strength and +3 speed each second for 30 seconds. Check save status below." or "Passengers are visiting Meadow. Next build shortly."
    elseif state.phase == "Resetting" then instructions = "Returning home. A fresh shared build starts next." end
    if state.training then instructions = state.training .. " — auto-training! Press E or Leave station to stop." end
    local carried = {}
    if state.cargo then
        for _, material in {"Metal", "Fuel"} do
            local count = state.cargo.materials[material] or 0
            if count > 0 then table.insert(carried, count .. " " .. material) end
        end
    end
    local cargo = #carried > 0 and table.concat(carried, " + ") or "empty"
    local lines = { headline, "", "Metal: " .. state.totals.Metal .. "/" .. state.required.Metal .. "     Fuel: " .. state.totals.Fuel .. "/" .. state.required.Fuel,
        "Carrying: " .. cargo .. "   •   Your deliveries this cycle: " .. state.contribution }
    if state.profile then
        local p = state.profile
        table.insert(lines, "Strength " .. p.strength .. "   Speed " .. p.speed .. "   Carry " .. p.capacity .. "   Walk " .. string.format("%.1f", p.walkSpeed))
        table.insert(lines, "Launches " .. p.completedLaunches .. "   Lifetime deliveries " .. p.lifetimeDeliveries)
        local unlocked, nextTier = 0, nil
        for _, tier in Config.TrainingTiers do
            if p.completedLaunches >= tier.cycles then unlocked += 1
            elseif not nextTier then nextTier = tier.cycles end
        end
        table.insert(lines, "Advanced gyms: " .. unlocked .. "/" .. #Config.TrainingTiers .. " unlocked"
            .. (nextTier and " • Next: " .. nextTier .. " cycles" or " • All unlocked"))
    end
    table.insert(lines, "")
    table.insert(lines, os.clock() < feedbackUntil and feedbackText or instructions)
    table.insert(lines, "")
    table.insert(lines, state.saveStatus)
    text.Text = table.concat(lines, "\n")
end
stateEvent.OnClientEvent:Connect(function(state) snapshot = state; render() end)
feedbackEvent.OnClientEvent:Connect(function(message)
    feedbackText, feedbackUntil = message, os.clock() + 3
    render()
end)
requestState:FireServer()
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed >= 0.25 then elapsed = 0; render() end
end)

-- One explicit exit action works on keyboard, controller and touch.
local ContextActionService = game:GetService("ContextActionService")
local exitTraining = remotes:WaitForChild("ExitTraining")
local exitButton = Instance.new("TextButton")
exitButton.Name = "LeaveStation"
exitButton.Size = UDim2.fromOffset(220, 48)
exitButton.Position = UDim2.new(0.5, -110, 1, -72)
exitButton.BackgroundColor3 = Color3.fromRGB(235, 160, 65)
exitButton.Text = "Leave station [E]"
exitButton.TextSize = 20
exitButton.Visible = false
exitButton.Parent = gui
exitButton.Activated:Connect(function() exitTraining:FireServer() end)
local bound = false
stateEvent.OnClientEvent:Connect(function(state)
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
end)

local UserInputService = game:GetService("UserInputService")
local mountedAt = 0
stateEvent.OnClientEvent:Connect(function(state)
    if state.training and mountedAt == 0 then mountedAt = os.clock() end
    if not state.training then mountedAt = 0 end
    local world = workspace:FindFirstChild("RocketWorld")
    if world then
        for _, station in world:GetChildren() do
            local prompt = station:GetAttribute("TrainingStation") and station:FindFirstChildOfClass("ProximityPrompt")
            if prompt then prompt.Enabled = not state.training end
        end
    end
end)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E and mountedAt > 0 and os.clock() - mountedAt > 0.3 then
        exitTraining:FireServer()
    end
end)

local discardCargo = remotes:WaitForChild("DiscardCargo")
local discardButton = Instance.new("TextButton")
discardButton.Name = "DiscardCargo"
discardButton.Size = UDim2.fromOffset(220, 42)
discardButton.Position = UDim2.new(0.5, -110, 1, -122)
discardButton.BackgroundColor3 = Color3.fromRGB(80, 110, 140)
discardButton.TextColor3 = Color3.new(1, 1, 1)
discardButton.Text = "Clear carried materials"
discardButton.TextSize = 16
discardButton.Visible = false
discardButton.Parent = gui
discardButton.Activated:Connect(function() discardCargo:FireServer() end)
stateEvent.OnClientEvent:Connect(function(state) discardButton.Visible = state.cargo ~= nil end)

-- PromptButtonHoldEnded fires at completion, so use physical input release instead.
local ProximityPromptService = game:GetService("ProximityPromptService")
local materialHold = remotes:WaitForChild("MaterialHold")
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
ProximityPromptService.PromptShown:Connect(function(item)
    if UserInputService:GetFocusedTextBox() then return end
    if UserInputService:IsKeyDown(item.KeyboardKeyCode) then
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
player.CharacterRemoving:Connect(stopMaterialHold)
