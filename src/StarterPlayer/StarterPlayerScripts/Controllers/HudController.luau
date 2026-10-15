-- The reference-style HUD: left stat stack (Coins, Strength, Speed, Launches), the
-- top-centre objective line, Feedback toasts above the pill, the save-status tag,
-- and stat-gain juice ("+2 💪" over your head, "Strength Level Up!" when capacity
-- grows, coins that fly from your head to the Coins row on delivery).
local Players = game:GetService("Players")
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local Tutorial = require(script.Parent.TutorialController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local StatRow = require(UI.StatRow)
local Popup = require(UI.Popup)
local Tween = require(UI.Tween)
local Toast = require(UI.Toast)
local HudController = {}
local icon = Theme.icon

local function carrying(state)
    local cargo = state.cargo
    if not cargo or cargo.count <= 0 then return nil end
    return (cargo.materials.Fuel or 0) > 0 and "Fuel" or "Metal", cargo.count
end

-- One short, punchy instruction for what to do right now (the tutorial's, while on).
local function objective(state)
    local tip = Tutorial.objective(state)
    if tip then return tip end
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
        return state.boarded and "You're aboard! Next stop: " .. state.destination .. "!" or "BOARD NOW! Walk into the rocket at the green BOARD hatch!"
    elseif state.phase == "Launching" then
        return state.passenger and "LIFTOFF! Off to " .. state.destination .. "!" or "You missed this one. Next build starts soon!"
    elseif state.phase == "Rewarding" then
        return state.passenger and "Welcome to " .. state.destination .. "! Free strength & speed!" or "The crew is on " .. state.destination .. ". Next build soon!"
    end
    return "Returning home. A bigger rocket is next!"
end

function HudController.start()
    local gui = Create.screen("RocketHUD")
    local player = Players.LocalPlayer

    local stack = Create.new("Frame", {
        Name = "StatStack", BackgroundTransparency = 1,
        -- Just under the objective line (64 + 84 design px), whatever the aspect ratio.
        Position = UDim2.fromOffset(Theme.gutter, 160), Size = UDim2.fromOffset(260, 290), Parent = gui,
    })
    Create.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
    local coins = StatRow.new({ Name = "Coins", icon = icon.Coin, color = Theme.color.Gold, sub = "Earn by building", LayoutOrder = 0, Parent = stack })
    coins.value.TextColor3 = Theme.color.Gold
    local strength = StatRow.new({ Name = "Strength", icon = icon.Strength, color = Theme.color.Strength, sub = "Capacity: 0/10", LayoutOrder = 1, Parent = stack })
    local speed = StatRow.new({ Name = "Speed", icon = icon.Speed, color = Theme.color.Speed, sub = "Walk Speed: 24", LayoutOrder = 2, Parent = stack })
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

    local function head()
        local character = player.Character
        return character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
    end
    -- Strength and Speed often rise together (destination ticks), so each popup kind has its
    -- own lane: gains sit left/right, level-ups stack at two heights.
    local lanes = {
        strengthGain = { jitter = -55, shift = 0 }, speedGain = { jitter = 55, shift = 0 },
        strengthLevel = { jitter = 0, shift = 50 }, speedLevel = { jitter = 0, shift = 100 },
    }
    local function worldPop(text, color, lane, size)
        local adornee = head()
        if adornee then
            lane = lanes[lane]
            Popup.world(adornee, { Text = text, TextColor3 = color, TextSize = size or 30,
                jitter = lane.jitter + math.random(-8, 8), shift = lane.shift })
        end
    end

    -- Coin bursts: a few coins pop out over your head and fly to the Coins row; the
    -- row counts up when the first lands. Bursts overlap freely while you hold E, but
    -- the row always ends on the newest server total.
    local coinTarget, inFlight = 0, 0
    local function burst(gain)
        local camera = workspace.CurrentCamera
        local adornee = head()
        local scale = gui:FindFirstChildOfClass("UIScale")
        local origin = camera.ViewportSize / 2
        if adornee then
            local point, visible = camera:WorldToScreenPoint(adornee.Position + Vector3.new(0, 2, 0))
            if visible then origin = Vector2.new(point.X, point.Y) - gui.AbsolutePosition end
        end
        origin /= scale and scale.Scale or 1
        local landed, spawned = false, 0
        for index = 1, math.min(gain, 5) do
            if inFlight >= 15 then break end
            inFlight += 1
            spawned += 1
            local coin = StrokedText.new({
                Name = "FlyingCoin", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
                Position = UDim2.fromOffset(origin.X, origin.Y), Text = icon.Coin, Font = Theme.font.Display,
                TextSize = 34, stroke = 2, ZIndex = 5, Parent = gui,
            })
            -- Pop outward first, then fly to the counter, staggered.
            local spread = Vector2.new(math.random(-70, 70), math.random(-60, -10))
            Tween.play(coin, Tween.info(0.18, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(origin.X + spread.X, origin.Y + spread.Y) })
            task.delay(0.18 + index * 0.06, function()
                Tween.flyTo(coin, coins.icon, 0.45, function()
                    if not landed then
                        landed = true
                        coins:set(coinTarget)
                    else
                        Tween.bounce(coins.icon, 1.2, 0.2)
                    end
                end).Completed:Connect(function()
                    inFlight -= 1
                    coin:Destroy()
                end)
            end)
        end
        -- Too many coins in the air already: just count the row up.
        if spawned == 0 then coins:set(coinTarget) end
    end

    State.subscribe(function(state, previous)
        local p = state.profile
        if p then
            local before = previous and previous.profile
            coinTarget = p.coins or 0
            local gain = before and coinTarget - (before.coins or 0) or 0
            if gain > 0 and not Settings.get("reducedEffects") then burst(gain) elseif coinTarget ~= coins.current then coins:set(coinTarget) end
            local material, count = carrying(state)
            strength:set(p.strength, "Capacity: " .. (material and count or 0) .. "/" .. p.capacity)
            speed:set(p.speed, "Walk Speed: " .. math.floor(p.walkSpeed))
            launches:set(p.completedLaunches, "Delivered: " .. Theme.number(p.lifetimeDeliveries))
            if before then
                if p.strength > before.strength then worldPop("+" .. p.strength - before.strength .. " " .. icon.Strength, Theme.color.Strength, "strengthGain") end
                if p.speed > before.speed then worldPop("+" .. p.speed - before.speed .. " " .. icon.Speed, Theme.color.Speed, "speedGain") end
                if p.capacity > before.capacity then
                    worldPop("Strength Level Up!", Theme.color.Go, "strengthLevel", 34)
                    Tween.bounce(strength.sub, 1.6, 0.5)
                end
                if math.floor(p.walkSpeed) > math.floor(before.walkSpeed) then
                    worldPop("Speed Level Up!", Theme.color.Speed, "speedLevel", 34)
                    Tween.bounce(speed.sub, 1.6, 0.5)
                end
            end
        end
        goal.Text = objective(state)
        save.Text = state.persistent and ("Progress: " .. state.saveStatus) or "Studio test: progress isn't saved"
    end)

    -- Material how-to hints ("Cargo full…", "Metal placed!…", "Pick up Metal…") show
    -- once each per session; the objective line keeps saying what to do next.
    local hinted = {}
    local function materialHint(message)
        for _, pattern in { "^Cargo full", "^%a+ placed!", "^Pick up %a+ at", "^Fill up on Fuel", "^Cargo cleared" } do
            if message:match(pattern) then return pattern end
        end
        return nil
    end

    -- Training ticks and destination rewards already show as stat popups; everything else
    -- is a toast above the progress pill, so the objective line always stays up.
    local toasts = Toast.stack({
        Name = "Toasts", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
        Size = UDim2.fromOffset(520, 130), max = 3, Parent = gui,
    })
    State.onFeedback(function(message)
        if message:match("^%+%d+ %a+!$") or message:match("%+%d+ strength / %+%d+ speed %(") then return end
        local hint = materialHint(message)
        if hint then
            if hinted[hint] then return end
            hinted[hint] = true
        end
        toasts:push(message)
    end)
end

return HudController
