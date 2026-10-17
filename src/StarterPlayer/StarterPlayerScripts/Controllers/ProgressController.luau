-- Shared rocket progress as the reference's bottom pill ("🔩 312 / 400"), a
-- cycle/tier tag above it, the boarding countdown, delivery pops and the big
-- milestone banners (new rocket design, final mission, program complete).
local RunService = game:GetService("RunService")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Pill = require(UI.Pill)
local Popup = require(UI.Popup)
local StrokedText = require(UI.StrokedText)
local Tween = require(UI.Tween)
local ProgressController = {}
local color, icon = Theme.color, Theme.icon
-- Rarity colours shared with the mission wheel (WheelController).
local function rarityColor(rarity) return Theme.rarity[rarity] or color.Ready end

function ProgressController.start()
    local gui = Create.screen("RocketProgress")
    local bar = Pill.new({
        Name = "ProgressPill", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
        Size = UDim2.fromOffset(340, 40), label = true, animate = true, textSize = 25, rim = 3, Parent = gui,
    })
    local tag = StrokedText.new({
        Name = "CycleTag", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -59),
        Size = UDim2.fromOffset(520, 22), Font = Theme.font.Display, TextSize = 17, stroke = 2, RichText = true,
        ZIndex = 2, Parent = gui,
    })
    -- A dark chip behind the tag, sized to its text.
    local tagBack = Create.new("Frame", {
        Name = "CycleTagBack", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -57),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.25, Parent = gui,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = tagBack })
    tag:GetPropertyChangedSignal("TextBounds"):Connect(function()
        tagBack.Size = UDim2.fromOffset(tag.TextBounds.X + 24, 26)
    end)
    local countdown = StrokedText.new({
        Name = "Countdown", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
        Size = UDim2.fromOffset(300, 120), Font = Theme.font.Display, TextSize = 110, stroke = 5,
        Visible = false, Parent = gui,
    })
    local function banner(message, tint, seconds)
        Popup.banner({
            Name = "Banner", Text = message, TextColor3 = tint, seconds = seconds,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Parent = gui,
        })
    end

    State.subscribe(function(state, previous)
        if not previous then return end
        local phaseChanged = state.phase ~= previous.phase
        if state.cycle ~= previous.cycle then
            banner("NEW MISSION: " .. state.destination .. "!", rarityColor(state.rarity), 6)
        elseif phaseChanged and state.phase == "Fueling" then
            banner("ROCKET BUILT! FUEL IT UP! " .. icon.Fuel, color.Fuel, 4)
        elseif phaseChanged and state.phase == "Boarding" then
            banner(state.legendary and "LEGENDARY MISSION! BOARD THE ROCKET!" or "ROCKET READY! BOARD NOW! " .. icon.Launch, color.Ready, 4)
        elseif phaseChanged and state.phase == "Launching" and state.passenger then
            banner("LIFTOFF! " .. icon.Launch, color.Gold, 4)
        end
        -- Your own delivery: pop the amount over the pill.
        if state.cycle == previous.cycle and state.contribution > previous.contribution then
            local material = previous.phase == "Fueling" and icon.Fuel or icon.Metal
            Popup.show({
                Text = "+" .. Theme.number(state.contribution - previous.contribution) .. " " .. material,
                TextColor3 = color.Gold, TextSize = 34, AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, math.random(-120, 120), 1, -70), rise = 70, Parent = gui,
            })
        end
    end)

    local lastCount
    RunService.Heartbeat:Connect(function()
        local state = State.get()
        if not state then return end
        local remaining = math.max(0, state.deadline - workspace:GetServerTimeNow())
        local metal, fuel = state.totals.Metal, state.totals.Fuel
        local needMetal, needFuel = state.required.Metal, state.required.Fuel
        if state.phase == "Building" then
            bar:set(metal / needMetal, color.Build, icon.Metal .. " " .. Theme.number(metal) .. " / " .. Theme.number(needMetal))
        elseif state.phase == "Fueling" then
            bar:set(fuel / needFuel, color.Fuel, icon.Fuel .. " " .. Theme.number(fuel) .. " / " .. Theme.number(needFuel))
        elseif state.phase == "Boarding" then
            bar:set(1, color.Ready, "BOARD NOW! T-" .. math.ceil(remaining))
        elseif state.phase == "Launching" then
            bar:set(1, color.Gold, "LIFTOFF! " .. icon.Launch)
        elseif state.phase == "Rewarding" then
            bar:set(1, color.Launch, (state.destination or "SPACE"):gsub("^THE ", "") .. " " .. math.ceil(remaining) .. "s")
        else
            bar:set(1, color.Purple, "NEXT ROCKET…")
        end
        local rarity = state.rarity or ""
        tag.Text = (state.destination or "?"):gsub("^THE ", "") .. " MISSION  •  "
            .. ('<font color="#%s">%s</font>'):format(rarityColor(rarity):ToHex(), rarity:upper())
            .. "  •  You: " .. Theme.number(state.contribution)
            .. (state.pityIn == 0 and "  •  NEXT SPIN: RARE+ GUARANTEED"
                or state.pityIn and state.pityIn <= 2 and ("  •  Rare+ in " .. state.pityIn .. (state.pityIn == 1 and " spin" or " spins")) or "")
        local showCountdown = state.phase == "Boarding" and remaining <= 10
        countdown.Visible = showCountdown
        if showCountdown then
            local count = math.ceil(remaining)
            countdown.Text = tostring(count)
            countdown.TextColor3 = remaining <= 3 and color.Danger or color.White
            if count ~= lastCount then Tween.bounce(countdown, 1.5, 0.4) end
            lastCount = count
        end
    end)
end

return ProgressController
