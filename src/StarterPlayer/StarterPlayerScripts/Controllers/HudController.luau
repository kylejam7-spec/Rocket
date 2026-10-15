-- Left text panel: cycle and phase, build totals, cargo, stats, instructions,
-- Feedback messages and save status. Phase 2 replaces it with the stat stack.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Panel = require(UI.Panel)
local StrokedText = require(UI.StrokedText)
local HudController = {}

local function instructionsFor(state)
    if state.training then return state.training .. " — auto-training! Press E or Leave station to stop." end
    if state.phase == "Fueling" then
        return "Rocket built! Fill your jerry can at the OIL REFINERY, then climb to the glowing ring on the fuel gauge and hold E to pour it in."
    elseif state.phase == "Boarding" then
        return state.boarded and "ABOARD — stay on the green BOARD pad until liftoff." or "BOARD NOW — stand on the green BOARD pad in front of the rocket."
    elseif state.phase == "Launching" then
        return state.passenger and "You made it! Launching to Meadow…" or "You missed this launch. The next build starts shortly."
    elseif state.phase == "Rewarding" then
        return state.passenger and "Meadows: bonus strength and speed every second. Check save status below." or "Passengers are visiting Meadow. Next build shortly."
    elseif state.phase == "Resetting" then
        return "Returning home. A fresh shared build starts next."
    end
    return "Hold or tap E at the SCRAP PIT to grow a scrap ball, then climb the ramp to the glowing ring on the rocket and hold E to place it."
end

function HudController.start()
    local gui = Create.screen("RocketHUD")
    local frame = Panel.new({
        Position = UDim2.fromOffset(Theme.gutter, Theme.gutter),
        -- Half width leaves the top-right corner for the rocket progress panel.
        Size = UDim2.new(0.5, -24, 0, 360),
        maxSize = Vector2.new(440, 360),
        Parent = gui,
    })
    local text = StrokedText.new({
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -32, 1, -24),
        Font = Theme.font.Body,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "ROCKET\nConnecting to the server…",
        Parent = frame,
    })

    local feedbackText, feedbackUntil = "", 0
    local function render()
        local state = State.get()
        if not state then return end
        local remaining = math.max(0, math.ceil(state.deadline - workspace:GetServerTimeNow()))
        local headline = "CYCLE " .. state.cycle .. "/" .. state.cycleCount .. "  •  " .. state.phase
        if state.deadline > 0 then headline ..= "  •  " .. remaining .. "s" end
        local carried = {}
        if state.cargo then
            for _, material in { "Metal", "Fuel" } do
                local count = state.cargo.materials[material] or 0
                if count > 0 then table.insert(carried, count .. " " .. material) end
            end
        end
        local cargo = #carried > 0 and table.concat(carried, " + ") or "empty"
        local lines = { headline, "", state.tierName .. "  •  Build " .. state.totals.Metal .. "/" .. state.required.Metal .. "   Fuel " .. state.totals.Fuel .. "/" .. state.required.Fuel,
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
                .. (nextTier and " • Next at " .. nextTier .. (nextTier == 1 and " launch" or " launches") or " • All unlocked"))
        end
        table.insert(lines, "")
        table.insert(lines, os.clock() < feedbackUntil and feedbackText or instructionsFor(state))
        table.insert(lines, "")
        table.insert(lines, state.saveStatus)
        text.Text = table.concat(lines, "\n")
    end

    State.subscribe(render)
    State.onFeedback(function(message)
        feedbackText, feedbackUntil = message, os.clock() + 3
        render()
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 0.25 then elapsed = 0; render() end
    end)
end

return HudController
