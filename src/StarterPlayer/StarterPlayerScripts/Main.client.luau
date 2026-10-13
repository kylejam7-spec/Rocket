local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
    local headline = "ROCKET  •  " .. state.phase
    if state.deadline > 0 then headline ..= "  •  " .. remaining .. "s" end
    local instructions = "Train at the gym. Gather Metal or Fuel, then deliver at the blue pad."
    if state.phase == "Boarding" then
        instructions = state.boarded and "ABOARD — stay on the green pad until departure." or "BOARD NOW — stand on the green pad before the timer ends."
    elseif state.phase == "Launching" then
        instructions = state.passenger and "You made it! Launching to Meadow…" or "You missed this launch. The next build starts shortly."
    elseif state.phase == "Rewarding" then
        instructions = state.passenger and "Meadow reward: +1 strength, +1 speed. Check save status below." or "Passengers are visiting Meadow. Next build shortly."
    elseif state.phase == "Resetting" then instructions = "Returning home. A fresh shared build starts next." end
    local cargo = state.cargo and (state.cargo.count .. " " .. state.cargo.material) or "empty"
    local lines = { headline, "", "Metal: " .. state.totals.Metal .. "/" .. state.required.Metal .. "     Fuel: " .. state.totals.Fuel .. "/" .. state.required.Fuel,
        "Carrying: " .. cargo .. "   •   Your deliveries this cycle: " .. state.contribution }
    if state.profile then
        local p = state.profile
        table.insert(lines, "Strength " .. p.strength .. "   Speed " .. p.speed .. "   Carry " .. p.capacity .. "   Walk " .. string.format("%.1f", p.walkSpeed))
        table.insert(lines, "Launches " .. p.completedLaunches .. "   Lifetime deliveries " .. p.lifetimeDeliveries)
        table.insert(lines, p.completedLaunches >= 1 and "Advanced gym: UNLOCKED" or "Advanced gym: locked until your first launch")
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
