-- Shared rocket progress: BUILD -> FUEL -> READY bar, launch countdown and
-- milestone banners (new rocket design, final mission, program complete).
local RunService = game:GetService("RunService")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Panel = require(UI.Panel)
local Pill = require(UI.Pill)
local StrokedText = require(UI.StrokedText)
local ProgressController = {}
local BUILD, FUEL, READY = Theme.color.Build, Theme.color.Fuel, Theme.color.Ready

local function text(parent, name, size, position, textSize, alignment)
    return StrokedText.new({
        Name = name, Size = size, Position = position, TextSize = textSize,
        TextXAlignment = alignment or Enum.TextXAlignment.Left, Parent = parent,
    })
end

function ProgressController.start()
    local gui = Create.screen("RocketProgress")
    local panel = Panel.new({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -Theme.gutter, 0, Theme.gutter),
        Size = UDim2.new(0.5, -24, 0, 104),
        maxSize = Vector2.new(400, 104),
        Parent = gui,
    })
    local header = text(panel, "Header", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 8), 12)
    header.TextColor3 = Theme.color.Muted
    local title = text(panel, "Title", UDim2.new(0.6, -12, 0, 24), UDim2.fromOffset(12, 26), 20)
    local count = text(panel, "Count", UDim2.new(0.4, -12, 0, 24), UDim2.new(0.6, 0, 0, 26), 18, Enum.TextXAlignment.Right)
    local bar = Pill.new({
        Size = UDim2.new(1, -24, 0, 14),
        Position = UDim2.fromOffset(12, 54),
        radius = UDim.new(0, 7),
        Parent = panel,
    })
    local footer = text(panel, "Footer", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 78), 12)
    footer.Font = Theme.font.Body
    footer.TextColor3 = Theme.color.Subtle

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

    State.subscribe(function(state, previous)
        if not previous then return end
        local phaseChanged = state.phase ~= previous.phase
        if state.modelTier ~= previous.modelTier then
            showBanner("NEW ROCKET UNLOCKED: " .. state.tierName:upper(), READY, 6)
        elseif phaseChanged and state.phase == "Fueling" then
            showBanner("ROCKET BUILT — FUEL IT UP!", FUEL, 4)
        elseif phaseChanged and state.phase == "Boarding" then
            showBanner(state.isFinal and "FINAL MISSION — BOARD THE ROCKET!" or "ROCKET READY — BOARD NOW!", READY, 4)
        elseif phaseChanged and state.phase == "Rewarding" and state.isFinal then
            showBanner("SPACE PROGRAM COMPLETE!\nAll " .. state.cycleCount .. " rockets launched.", Theme.color.Gold, 12)
        elseif phaseChanged and state.phase == "Building" and state.cycle == 1 and state.programRuns > 0 then
            showBanner("A NEW SPACE PROGRAM BEGINS", READY, 6)
        end
    end)

    RunService.Heartbeat:Connect(function()
        local state = State.get()
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
        bar:set(progress, color)
        local buildMark = state.totals.Metal >= state.required.Metal and "Build ✓" or "Build " .. math.floor(state.totals.Metal / state.required.Metal * 100) .. "%"
        local fuelMark = state.totals.Fuel >= state.required.Fuel and "Fuel ✓" or "Fuel " .. math.floor(state.totals.Fuel / state.required.Fuel * 100) .. "%"
        local nextTier = state.nextTierIn and ("Next rocket design in " .. state.nextTierIn .. (state.nextTierIn == 1 and " launch" or " launches"))
            or (state.isFinal and "Final rocket" or "Final rocket tier")
        footer.Text = buildMark .. "   •   " .. fuelMark .. "   •   " .. nextTier
        local showCountdown = state.phase == "Boarding" and remaining <= 10
        countdown.Visible = showCountdown
        if showCountdown then
            countdown.Text = tostring(math.ceil(remaining))
            countdown.TextColor3 = remaining <= 3 and Theme.color.Danger or Theme.color.White
        end
    end)
end

return ProgressController
