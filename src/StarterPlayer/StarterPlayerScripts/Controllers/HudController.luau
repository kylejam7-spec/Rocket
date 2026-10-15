-- The reference-style HUD: left stat stack (Strength, Speed, Launches), the
-- top-centre objective line, Feedback toasts, the save-status tag, and stat-gain
-- juice ("+2 💪" over your head, "Strength Level Up!" when capacity grows).
local Players = game:GetService("Players")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local StatRow = require(UI.StatRow)
local Popup = require(UI.Popup)
local Tween = require(UI.Tween)
local HudController = {}
local icon = Theme.icon

local function carrying(state)
    local cargo = state.cargo
    if not cargo or cargo.count <= 0 then return nil end
    return (cargo.materials.Fuel or 0) > 0 and "Fuel" or "Metal", cargo.count
end

-- One short, punchy instruction for what to do right now.
local function objective(state)
    if state.training then return "Training on the " .. state.training .. "! Press E to leave." end
    local material, count = carrying(state)
    local full = material and state.profile and count >= state.profile.capacity
    if state.phase == "Building" then
        if material == "Metal" then
            return full and "Full! Carry the scrap up the ramp to the glowing ring!" or "Grab more, or carry it up the ramp to the glowing ring!"
        end
        return "Grab scrap metal at the SCRAP PIT to build the rocket!"
    elseif state.phase == "Fueling" then
        if material == "Fuel" then return "Pour the fuel into the rocket at the glowing ring!" end
        return "Rocket built! Fill your jerry can at the OIL REFINERY!"
    elseif state.phase == "Boarding" then
        return state.boarded and "You're aboard! Stay on the green pad!" or "BOARD NOW! Stand on the green BOARD pad!"
    elseif state.phase == "Launching" then
        return state.passenger and "LIFTOFF! Off to Meadow!" or "You missed this one. Next build starts soon!"
    elseif state.phase == "Rewarding" then
        return state.passenger and "Meadow bonus: free strength & speed!" or "Passengers are on Meadow. Next build soon!"
    end
    return "Returning home. A bigger rocket is next!"
end

function HudController.start()
    local gui = Create.screen("RocketHUD")
    local player = Players.LocalPlayer

    local stack = Create.new("Frame", {
        Name = "StatStack", BackgroundTransparency = 1,
        Position = UDim2.new(0, Theme.gutter, 0.24, 0), Size = UDim2.fromOffset(260, 220), Parent = gui,
    })
    Create.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
    local strength = StatRow.new({ Name = "Strength", icon = icon.Strength, color = Theme.color.Strength, sub = "Capacity: 0/10", LayoutOrder = 1, Parent = stack })
    local speed = StatRow.new({ Name = "Speed", icon = icon.Speed, color = Theme.color.Speed, sub = "Walk Speed: 16", LayoutOrder = 2, Parent = stack })
    local launches = StatRow.new({ Name = "Launches", icon = icon.Launch, color = Theme.color.Launch, sub = "Delivered: 0", LayoutOrder = 3, Parent = stack })

    local goal = StrokedText.new({
        Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
        Size = UDim2.new(1, -360, 0, 84), Font = Theme.font.Display, TextSize = 34, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, stroke = 3, Text = "Connecting…", Parent = gui,
    })

    local save = StrokedText.new({
        Name = "SaveStatus", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, Theme.gutter, 1, -12),
        Size = UDim2.fromOffset(320, 18), Font = Theme.font.Display, TextSize = 14, TextColor3 = Theme.color.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.5, Parent = gui,
    })

    local feedbackUntil = 0
    local function head()
        local character = player.Character
        return character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
    end
    local function worldPop(text, color, size)
        local adornee = head()
        if adornee then
            Popup.world(adornee, { Text = text, TextColor3 = color, TextSize = size or 30, jitter = math.random(-60, 60) })
        end
    end

    State.subscribe(function(state, previous)
        local p = state.profile
        if p then
            local material, count = carrying(state)
            strength:set(p.strength, "Capacity: " .. (material and count or 0) .. "/" .. p.capacity)
            speed:set(p.speed, "Walk Speed: " .. math.floor(p.walkSpeed))
            launches:set(p.completedLaunches, "Delivered: " .. Theme.number(p.lifetimeDeliveries))
            local before = previous and previous.profile
            if before then
                if p.strength > before.strength then worldPop("+" .. p.strength - before.strength .. " " .. icon.Strength, Theme.color.Strength) end
                if p.speed > before.speed then worldPop("+" .. p.speed - before.speed .. " " .. icon.Speed, Theme.color.Speed) end
                if p.capacity > before.capacity then
                    worldPop("Strength Level Up!", Theme.color.Go, 34)
                    Tween.bounce(strength.sub, 1.6, 0.5)
                end
                if math.floor(p.walkSpeed) > math.floor(before.walkSpeed) then
                    worldPop("Speed Level Up!", Theme.color.Speed, 34)
                    Tween.bounce(speed.sub, 1.6, 0.5)
                end
            end
        end
        if os.clock() >= feedbackUntil then goal.Text = objective(state) end
        save.Text = state.persistent and ("Progress: " .. state.saveStatus) or "Studio test: progress isn't saved"
    end)

    -- Training ticks and Meadow rewards already show as stat popups.
    State.onFeedback(function(message)
        if message:match("^%+%d+ %a+!$") or message:match("^Meadows %+") then return end
        feedbackUntil = os.clock() + 3
        goal.Text = message
        Tween.bounce(goal, 1.2, 0.35)
        task.delay(3.05, function()
            local state = State.get()
            if state and os.clock() >= feedbackUntil then goal.Text = objective(state) end
        end)
    end)
end

return HudController
