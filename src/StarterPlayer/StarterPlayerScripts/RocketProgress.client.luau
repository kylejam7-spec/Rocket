-- Shared rocket progress: BUILD -> FUEL -> READY bar, launch countdown and
-- milestone banners (new rocket design, final mission, program complete).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local stateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StateUpdated")
local BUILD, FUEL, READY = Color3.fromRGB(150, 190, 225), Color3.fromRGB(255, 165, 55), Color3.fromRGB(95, 220, 150)

local gui = Instance.new("ScreenGui")
gui.Name = "RocketProgress"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local function text(parent, name, size, position, textSize, alignment)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size, label.Position = size, position
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(234, 241, 250)
    label.Font = Enum.Font.GothamBold
    label.TextSize = textSize
    label.TextXAlignment = alignment or Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 16)
panel.Size = UDim2.new(0.5, -24, 0, 104)
panel.BackgroundColor3 = Color3.fromRGB(20, 29, 43)
panel.BackgroundTransparency = 0.08
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(400, 104)
limit.Parent = panel
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local header = text(panel, "Header", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 8), 12)
header.TextColor3 = Color3.fromRGB(170, 185, 205)
local title = text(panel, "Title", UDim2.new(0.6, -12, 0, 24), UDim2.fromOffset(12, 26), 20)
local count = text(panel, "Count", UDim2.new(0.4, -12, 0, 24), UDim2.new(0.6, 0, 0, 26), 18, Enum.TextXAlignment.Right)
local track = Instance.new("Frame")
track.Size, track.Position = UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, 54)
track.BackgroundColor3 = Color3.fromRGB(45, 55, 72)
track.Parent = panel
Instance.new("UICorner", track).CornerRadius = UDim.new(0, 7)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 7)
local footer = text(panel, "Footer", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 78), 12)
footer.Font = Enum.Font.GothamMedium
footer.TextColor3 = Color3.fromRGB(190, 200, 215)

local countdown = text(gui, "Countdown", UDim2.fromOffset(400, 90), UDim2.new(0.5, -200, 0.3, -45), 72, Enum.TextXAlignment.Center)
countdown.TextStrokeTransparency = 0.4
countdown.Visible = false
local banner = text(gui, "Banner", UDim2.new(1, -40, 0, 64), UDim2.new(0, 20, 0.18, 0), 30, Enum.TextXAlignment.Center)
banner.TextWrapped = true
banner.TextStrokeTransparency = 0.3
banner.Visible = false
local bannerUntil = 0
local function showBanner(message, color, seconds)
    banner.Text, banner.TextColor3 = message, color
    banner.Visible, bannerUntil = true, os.clock() + seconds
end

local snapshot, lastTier, lastPhase
stateEvent.OnClientEvent:Connect(function(state)
    local tierChanged = lastTier and state.modelTier ~= lastTier
    local phaseChanged = lastPhase and state.phase ~= lastPhase
    if tierChanged then
        showBanner("NEW ROCKET UNLOCKED: " .. state.tierName:upper(), READY, 6)
    elseif phaseChanged and state.phase == "Fueling" then
        showBanner("ROCKET BUILT — FUEL IT UP!", FUEL, 4)
    elseif phaseChanged and state.phase == "Boarding" then
        showBanner(state.isFinal and "FINAL MISSION — BOARD THE ROCKET!" or "ROCKET READY — BOARD NOW!", READY, 4)
    elseif phaseChanged and state.phase == "Rewarding" and state.isFinal then
        showBanner("SPACE PROGRAM COMPLETE!\nAll " .. state.cycleCount .. " rockets launched.", Color3.fromRGB(255, 220, 110), 12)
    elseif phaseChanged and state.phase == "Building" and state.cycle == 1 and state.programRuns > 0 then
        showBanner("A NEW SPACE PROGRAM BEGINS", READY, 6)
    end
    lastTier, lastPhase, snapshot = state.modelTier, state.phase, state
end)

RunService.Heartbeat:Connect(function()
    local state = snapshot
    if banner.Visible and os.clock() > bannerUntil then banner.Visible = false end
    if not state then return end
    header.Text = "CYCLE " .. state.cycle .. "/" .. state.cycleCount .. "  •  " .. state.tierName:upper()
        .. (state.isFinal and "  •  FINAL MISSION" or "")
    local remaining = math.max(0, state.deadline - workspace:GetServerTimeNow())
    local progress, color
    if state.phase == "Building" then
        title.Text, count.Text = "BUILD ROCKET", state.totals.Metal .. " / " .. state.required.Metal
        progress, color = state.totals.Metal / state.required.Metal, BUILD
    elseif state.phase == "Fueling" then
        title.Text, count.Text = "FUEL ROCKET", state.totals.Fuel .. " / " .. state.required.Fuel
        progress, color = state.totals.Fuel / state.required.Fuel, FUEL
    elseif state.phase == "Boarding" then
        title.Text, count.Text = "ROCKET READY", "T-" .. math.ceil(remaining)
        progress, color = 1, READY
    else
        title.Text, count.Text = state.phase == "Launching" and "LIFTOFF!" or state.phase:upper(), ""
        progress, color = 1, READY
    end
    fill.Size, fill.BackgroundColor3 = UDim2.fromScale(math.clamp(progress, 0, 1), 1), color
    local buildMark = state.totals.Metal >= state.required.Metal and "Build ✓" or "Build " .. math.floor(state.totals.Metal / state.required.Metal * 100) .. "%"
    local fuelMark = state.totals.Fuel >= state.required.Fuel and "Fuel ✓" or "Fuel " .. math.floor(state.totals.Fuel / state.required.Fuel * 100) .. "%"
    local nextTier = state.nextTierIn and ("Next rocket design in " .. state.nextTierIn .. (state.nextTierIn == 1 and " launch" or " launches"))
        or (state.isFinal and "Final rocket" or "Final rocket tier")
    footer.Text = buildMark .. "   •   " .. fuelMark .. "   •   " .. nextTier
    local showCountdown = state.phase == "Boarding" and remaining <= 10
    countdown.Visible = showCountdown
    if showCountdown then
        countdown.Text = tostring(math.ceil(remaining))
        countdown.TextColor3 = remaining <= 3 and Color3.fromRGB(255, 120, 90) or Color3.new(1, 1, 1)
    end
end)
