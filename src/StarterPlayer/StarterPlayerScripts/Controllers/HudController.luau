-- The reference-style HUD: left stat stack (Coins, Strength, Speed, Launches), the
-- top-centre objective line, Feedback toasts above the pill, the save-status tag,
-- and stat-gain juice ("+2 💪" over your head, "Strength Level 5!" on each new
-- level, coins that fly from your head to the Coins row on delivery).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local StatLevels = require(ReplicatedStorage.Shared.StatLevels)
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local Tutorial = require(script.Parent.TutorialController)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local StatRow = require(UI.StatRow)
local WorldScale = require(UI.WorldScale)
local Popup = require(UI.Popup)
local Tween = require(UI.Tween)
local Toast = require(UI.Toast)
local Sfx = require(UI.Sfx)
local HudController = {}
local icon = Theme.icon

local function carrying(state)
    local cargo = state.cargo
    if not cargo or cargo.count <= 0 then return nil end
    return (cargo.materials.Fuel or 0) > 0 and "Fuel" or "Metal", cargo.count
end

-- One short, punchy instruction for what to do right now (the tutorial's, while on).
-- How-to lines go once the player has done that thing (`learned`, see HintLearned);
-- an empty line hides the banner. Phase news (liftoff, arrival) and the call to board,
-- which goes to the whole server every time a rocket is finished, always show.
local function objective(state, learned)
    local tip = Tutorial.objective(state)
    if tip then return tip end
    if state.training then return learned.LeaveStation and "" or "Training on the " .. state.training .. "! Press E to leave." end
    local material, count = carrying(state)
    local full = material and state.profile and count >= state.profile.capacity
    if state.phase == "Building" then
        if material == "Metal" then
            if learned.PlaceMetal then return "" end
            return full and "Full! Carry the scrap up the ramp to the glowing ring!" or "Grab more, or carry it up the ramp to the glowing ring!"
        end
        return learned.PickupMetal and "" or "Grab scrap metal at the SALVAGE YARD to build the rocket!"
    elseif state.phase == "Fueling" then
        if material == "Fuel" then return learned.PlaceFuel and "" or "Pour the fuel into the rocket at the glowing ring!" end
        return learned.PickupFuel and "" or "Rocket built! Fill your jerry can at the FUEL DEPOT!"
    elseif state.phase == "Boarding" then
        return state.boarded and "You're aboard! Next stop: " .. state.destination .. "!" or "BOARD NOW! Run up the ramp and through the glowing BOARD door!"
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

    -- Desktop: just under the objective line (64 + 84 design px). Phones shrink the whole
    -- HUD to fit, so there the stack is enlarged and sits at the top left, under the
    -- Roblox button and well clear of the thumbstick.
    local stack = Create.new("Frame", {
        Name = "StatStack", BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 276),
        Position = UDim2.fromOffset(Theme.gutter, Actions.touch and 8 or 150), Parent = gui,
    })
    Create.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
    if Actions.touch then Create.new("UIScale", { Name = "TouchScale", Scale = 1.25, Parent = stack }) end
    local coins = StatRow.new({ Name = "Coins", icon = icon.Coin, color = Theme.color.Gold, sub = "Earn by building", LayoutOrder = 0, Parent = stack })
    coins.value.TextColor3 = Theme.color.Gold
    local strength = StatRow.new({ Name = "Strength", icon = icon.Strength, color = Theme.color.Strength, sub = "Capacity: 0/10", badge = "LV 0", progress = true, LayoutOrder = 1, Parent = stack })
    local speed = StatRow.new({ Name = "Speed", icon = icon.Speed, color = Theme.color.Speed, sub = "Walk Speed: 24", badge = "LV 0", progress = true, LayoutOrder = 2, Parent = stack })
    local launches = StatRow.new({ Name = "Launches", icon = icon.Launch, color = Theme.color.Launch, sub = "Delivered: 0", LayoutOrder = 3, Parent = stack })

    local goal = StrokedText.new({
        Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
        Size = UDim2.new(1, -360, 0, 84), Font = Theme.font.Display, TextSize = Actions.touch and 34 or 26, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, stroke = 3, Text = "Connecting…", ZIndex = 2, Parent = gui,
    })
    -- A dark gold-rimmed banner hugging the objective text; it bounces on each new line.
    local goalBack = Create.new("Frame", {
        Name = "ObjectiveBack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.2, Parent = gui,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = goalBack })
    Create.new("UIStroke", { Thickness = 2.5, Color = Theme.color.Gold, Parent = goalBack })
    Create.new("UIGradient", {
        Rotation = 90, Color = ColorSequence.new(Theme.lighten(Theme.color.Panel, 0.15), Theme.color.Panel), Parent = goalBack,
    })
    -- TextBounds is in screen pixels; divide by the screen scale to get layout units.
    local function fitGoal()
        local bounds = goal.TextBounds
        local scale = goal.AbsoluteSize.Y / goal.Size.Y.Offset
        goalBack.Visible = goal.Text ~= "" and bounds.X > 0 and scale > 0
        if scale > 0 then goalBack.Size = UDim2.fromOffset(bounds.X / scale + 36, bounds.Y / scale + 12) end
    end
    goal:GetPropertyChangedSignal("TextBounds"):Connect(fitGoal)
    goal:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGoal)
    goal:GetPropertyChangedSignal("Text"):Connect(function()
        Tween.bounce(goalBack, 1.06, 0.3)
        Tween.bounce(goal, 1.06, 0.3)
    end)
    fitGoal()

    local save = StrokedText.new({
        Name = "SaveStatus", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, Theme.gutter, 1, -12),
        Size = UDim2.fromOffset(320, 18), Font = Theme.font.Display, TextSize = 14, TextColor3 = Theme.color.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.5, Parent = gui,
    })

    local function head()
        local character = player.Character
        return character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
    end
    -- Strength and Speed often rise together (gyms tick 3 times a second, destinations
    -- once), so gains scatter: each lands somewhere new in its own half round your head
    -- (strength left, speed right), never within MIN_GAP px of the last one. Level-ups stay
    -- put at two heights in the middle.
    local lanes = {
        strengthGain = { x = { -140, 10 }, y = { -40, 90 } }, speedGain = { x = { -10, 140 }, y = { -40, 90 } },
        strengthLevel = { jitter = 0, shift = 50 }, speedLevel = { jitter = 0, shift = 100 },
    }
    local MIN_GAP = 45
    local function spot(lane)
        local x, y
        for _ = 1, 6 do
            x, y = math.random(lane.x[1], lane.x[2]), math.random(lane.y[1], lane.y[2])
            if not lane.last or (Vector2.new(x, y) - lane.last).Magnitude >= MIN_GAP then break end
        end
        lane.last = Vector2.new(x, y)
        return x, y
    end
    local function worldPop(text, color, lane, size)
        local adornee = head()
        if adornee then
            lane = lanes[lane]
            local jitter, shift = lane.jitter, lane.shift
            if lane.x then jitter, shift = spot(lane) end
            Popup.world(adornee, { Text = text, TextColor3 = color, TextSize = size or (lane.x and math.random(26, 34)) or 30,
                jitter = jitter, shift = shift })
        end
    end

    -- Coin bursts: a few coins pop out over your head and fly to the Coins row; the
    -- row counts up when the first lands. Bursts overlap freely while you hold E, but
    -- the row always ends on the newest server total.
    local coinTarget, inFlight = 0, 0
    -- Each coin that lands clinks a step higher than the last, so a run of deliveries
    -- climbs (up to +40%); the climb starts over after a second without coins.
    local streak, lastClink = 0, 0
    local function clink()
        local now = os.clock()
        if now - lastClink > 1 then streak = 0 end
        lastClink = now
        Sfx.play("coin", { pitch = 1 + 0.04 * math.min(streak, 10) })
        streak += 1
    end
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
                    clink()
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
        if spawned == 0 then
            coins:set(coinTarget)
            clink()
        end
    end

    -- Hints already acted on, from the profile ("Hint:<name>" in seenCallouts, kept by
    -- TutorialService) plus any reported this session.
    local hintLearned = State.remote("HintLearned")
    local reported, learned = {}, {}
    local function learn(name)
        if reported[name] then return end
        reported[name] = true
        learned[name] = true
        hintLearned:FireServer(name)
    end
    local function noticeLearning(state, previous)
        for _, name in state.profile and state.profile.seenCallouts or {} do
            local hint = name:match("^Hint:(.+)$")
            if hint then learned[hint] = true end
        end
        if not previous then return end
        local material, count = carrying(state)
        local _, before = carrying(previous)
        if material and count > (before or 0) then learn("Pickup" .. material) end
        if state.cycle == previous.cycle and state.contribution > previous.contribution then
            learn(previous.phase == "Fueling" and "PlaceFuel" or "PlaceMetal")
        end
        if previous.training and not state.training then learn("LeaveStation") end
    end

    State.subscribe(function(state, previous)
        noticeLearning(state, previous)
        local p = state.profile
        if p then
            local before = previous and previous.profile
            coinTarget = p.coins or 0
            local gain = before and coinTarget - (before.coins or 0) or 0
            if gain > 0 and not Settings.get("reducedEffects") then
                burst(gain)
            elseif coinTarget ~= coins.current then
                coins:set(coinTarget)
                if gain > 0 then clink() end
            end
            local material, count = carrying(state)
            strength:set(p.strength, "Capacity: " .. (material and count or 0) .. "/" .. p.capacity)
            speed:set(p.speed, "Walk Speed: " .. math.floor(p.walkSpeed))
            launches:set(p.completedLaunches, "Delivered: " .. Theme.number(p.lifetimeDeliveries))
            -- Level badge and the bar toward the next level (points into it / its cost).
            local strengthLevel, strengthInto, strengthNeed = StatLevels.level(Config, p.strength)
            local speedLevel, speedInto, speedNeed = StatLevels.level(Config, p.speed)
            strength:setBadge("LV " .. strengthLevel)
            strength:setProgress(strengthInto / strengthNeed, Theme.number(strengthInto) .. "/" .. Theme.number(strengthNeed))
            speed:setBadge("LV " .. speedLevel)
            speed:setProgress(speedInto / speedNeed, Theme.number(speedInto) .. "/" .. Theme.number(speedNeed))
            if before then
                -- A pop with each gain popup (strength lower, speed higher), and the
                -- level-up sound on top of it when a stat levels (once if both do).
                local levelled = false
                if p.strength > before.strength then
                    worldPop("+" .. p.strength - before.strength .. " " .. icon.Strength, Theme.color.Strength, "strengthGain")
                    Sfx.play("gain", { pitch = 0.9 })
                end
                if p.speed > before.speed then
                    worldPop("+" .. p.speed - before.speed .. " " .. icon.Speed, Theme.color.Speed, "speedGain")
                    Sfx.play("gain", { pitch = 1.25 })
                end
                if strengthLevel > StatLevels.level(Config, before.strength) then
                    worldPop("Strength Level " .. strengthLevel .. "!", Theme.color.Go, "strengthLevel", 34)
                    Tween.bounce(strength.badge, 1.6, 0.5)
                    levelled = true
                end
                if speedLevel > StatLevels.level(Config, before.speed) then
                    worldPop("Speed Level " .. speedLevel .. "!", Theme.color.Speed, "speedLevel", 34)
                    Tween.bounce(speed.badge, 1.6, 0.5)
                    levelled = true
                end
                if levelled then Sfx.play("levelup") end
            end
        end
        goal.Text = objective(state, learned)
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
        Name = "Toasts", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, Actions.touch and -168 or -132),
        Size = UDim2.fromOffset(520, 130), max = 3, Parent = gui,
    })
    -- Rank tags over every player's head are server-made pixel billboards; shrink them
    -- with the screen like the rest of the world labels.
    local function watchCharacter(character)
        local function check(item)
            if item:IsA("BillboardGui") and item.Name == "RankTag" then WorldScale.apply(item) end
        end
        for _, item in character:GetDescendants() do check(item) end
        character.DescendantAdded:Connect(check)
    end
    local function watchPlayer(other)
        if other.Character then watchCharacter(other.Character) end
        other.CharacterAdded:Connect(watchCharacter)
    end
    for _, other in Players:GetPlayers() do watchPlayer(other) end
    Players.PlayerAdded:Connect(watchPlayer)

    State.onFeedback(function(message)
        if message:match("^%+%d+ %a+!$") or message:match("%+%d+ strength / %+%d+ speed %(") then return end
        if message:match("^Training!") and learned.LeaveStation then return end
        local hint = materialHint(message)
        if hint then
            if hinted[hint] then return end
            hinted[hint] = true
        end
        toasts:push(message)
    end)
end

return HudController
