-- The Robux SHOP (Shared.Shop; IDs and prices in Config.Shop). Three places sell:
-- * the 🛒 SHOP button under the stat stack opens the panel: Game Passes, gym access
--   for each Gym District tier, and the server training boost (with a chip by the
--   button while it runs);
-- * the rocket-fill row right above the progress pill while building or fueling:
--   +2,000 / 4,000 / 7,000 / 11,000 / 27,500 of whatever the rocket needs now (Metal or Fuel);
-- * at a destination, passengers get a side panel: more time there and the next mission.
-- Every button sends BuyShop(key); the server checks it and opens the Roblox prompt.
-- Offers without a dashboard ID show their price greyed out; prices are always on the button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Missions = require(ReplicatedStorage.Shared.Missions)
local State = require(script.Parent.State)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local Sfx = require(UI.Sfx)
local StrokedText = require(UI.StrokedText)
local Tween = require(UI.Tween)
local ShopController = {}

local WIDTH, HEIGHT = 760, 520
local ROBUX = Theme.color.Purple
local OFF = Color3.fromRGB(120, 112, 140)
local OWNED = Theme.color.Go

local function clock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- The view Shared.Shop.available reads, from a state snapshot.
local function view(state)
    local shop = state.shop or {}
    return { phase = state.phase, passenger = state.passenger, wheelSpun = state.wheel ~= nil,
        guaranteed = shop.guaranteed ~= nil, stayExtra = shop.stayExtra or 0 }
end

function ShopController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("RocketShop")
    gui.DisplayOrder = 10
    local current, render
    -- Price buttons, redrawn on every state: key -> { button, prefix, available? }.
    local offers = {}

    local function buy(key)
        local state = current
        if not state then return end
        local owned = state.shop and state.shop.owned or {}
        if owned[key] then return Sfx.play("error") end
        -- Not on sale yet: the server says "coming soon".
        if not Shop.enabled(Config, key) then Sfx.play("error"); return State.remote("BuyShop"):FireServer(key) end
        if not Shop.isPass(Config, key) and not Shop.available(Config, key, view(state)) then return Sfx.play("error") end
        Sfx.play("click")
        State.remote("BuyShop"):FireServer(key)
    end
    local function offerButton(key, props, prefix)
        local button = Button.new(Create.merge({ Text = "", TextSize = 20, color = ROBUX, sound = false,
            onActivated = function() buy(key) end }, props))
        offers[key] = { button = button, prefix = prefix or "" }
        return button
    end
    local function renderOffer(key, offer, state)
        local entry = Shop.entry(Config, key)
        local owned = state.shop and state.shop.owned or {}
        local text, color
        if owned[key] then
            text, color = "OWNED ✔", OWNED
        elseif not Shop.enabled(Config, key) then
            -- No dashboard ID yet: the price shows, greyed.
            text, color = offer.prefix .. "R$ " .. entry.price, OFF
        else
            text = offer.prefix .. "R$ " .. entry.price
            local ok = Shop.isPass(Config, key) or Shop.available(Config, key, view(state))
            color = ok and ROBUX or OFF
        end
        offer.button.Label.Text = text
        offer.button.BackgroundColor3 = color
    end

    ------------------------------------------------------------------ the panel
    local panel = Panel.new({
        Name = "ShopPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundTransparency = 0.05, radius = 18,
        stroke = 4, strokeColor = ROBUX, Visible = false, Parent = gui,
    })
    -- Same phone fit as the other panels: readable, and left of the touch buttons. It
    -- never grows wider than the screen, and the touch shift stops at the left edge, so
    -- the first column of offers always shows whole.
    local screenScale = gui:FindFirstChildOfClass("UIScale")
    local panelScale = Create.new("UIScale", { Name = "ReadableScale", Parent = panel })
    local function fit()
        local s = screenScale and screenScale.Scale or 1
        local screen = gui.AbsoluteSize
        local want = math.max(s, math.min(0.75, 0.9 * screen.Y / HEIGHT))
        want = math.min(want, (screen.X - 2 * Theme.gutter) / WIDTH)
        panelScale.Scale = want / s
        local shift = 0
        if Actions.touch then
            local cluster = Actions.cluster()
            local right = screen.X / 2 + WIDTH * want / 2
            shift = math.min(0, cluster.AbsolutePosition.X - 8 - right)
        end
        shift = math.max(shift, Theme.gutter + WIDTH * want / 2 - screen.X / 2)
        panel.Position = UDim2.new(0.5, shift / s, 0.5, 0)
    end
    if screenScale then screenScale:GetPropertyChangedSignal("Scale"):Connect(fit) end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()
    StrokedText.new({
        Text = "🛒 SHOP", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(300, 44), Font = Theme.font.Display, TextSize = 38, stroke = 3, Parent = panel,
    })
    local fillRow
    local function close()
        if panel.Visible then Sfx.play("close") end
        panel.Visible = false
        if current then render(current) end
    end
    Button.new({
        Name = "Close", shape = "circle", icon = Theme.icon.Leave, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 46),
        sound = false, onActivated = close, Parent = panel,
    })
    local list = Create.new("ScrollingFrame", {
        Name = "List", Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 1, -80), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel,
    })
    Create.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    -- The cards' outlines draw outside their frames; this keeps the list from clipping them.
    Create.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), Parent = list })
    local order = 0
    local function section(title)
        order += 1
        StrokedText.new({
            Name = "Header", Size = UDim2.new(1, -12, 0, 30), Text = title, Font = Theme.font.Display, TextSize = 24,
            TextColor3 = Theme.color.Gold, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, LayoutOrder = order, Parent = list,
        })
        order += 1
        local grid = Create.new("Frame", { Name = "Grid", Size = UDim2.new(1, -14, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
        return grid
    end
    local function card(parent, size, accent)
        local frame = Create.new("Frame", { Size = size, BackgroundColor3 = Theme.color.Track, BackgroundTransparency = 0.3, Parent = parent })
        Create.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = frame })
        Create.new("UIStroke", { Thickness = 2, Color = accent or ROBUX, Transparency = 0.3, Parent = frame })
        return frame
    end
    local function gridLayout(grid, cell)
        Create.new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
    end

    -- Game Passes: one card each.
    local passes = section("GAME PASSES  ·  yours for good")
    gridLayout(passes, UDim2.fromOffset(228, 128))
    for index, pass in Shop.Passes do
        local frame = card(passes, UDim2.new(), ROBUX)
        frame.LayoutOrder = index
        StrokedText.new({ Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(40, 40), Text = pass.icon,
            Font = Theme.font.Display, TextSize = 30, stroke = 2, Parent = frame })
        StrokedText.new({ Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -60, 0, 26), Text = pass.name:upper(),
            Font = Theme.font.Display, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = frame })
        StrokedText.new({ Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 32), Text = pass.text, TextWrapped = true,
            Font = Theme.font.Display, TextSize = 16, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, stroke = 1.5, Parent = frame })
        offerButton(pass.key, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
            Size = UDim2.new(1, -20, 0, 38), Parent = frame })
    end

    -- Gym access: every District tier, unlocked without its launches.
    local gyms = section("GYM ACCESS  ·  train there before you've unlocked it")
    gridLayout(gyms, UDim2.fromOffset(170, 96))
    local gymCards = {}
    for tier, spec in Config.TrainingTiers do
        local frame = card(gyms, UDim2.new(), Theme.color.Strength)
        frame.LayoutOrder = tier
        StrokedText.new({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), Text = "🏋 " .. spec.multiplier .. "X GYM",
            Font = Theme.font.Display, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = frame })
        local note = StrokedText.new({ Name = "Note", Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 18),
            Font = Theme.font.Display, TextSize = 15, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
            stroke = 1.5, Parent = frame })
        local button = offerButton(Shop.gymKey(tier), { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 36), TextSize = 18, Parent = frame })
        gymCards[tier] = { note = note, button = button, cycles = spec.cycles }
    end

    -- Server boosts.
    local boosts = section("SERVER BOOSTS  ·  for everyone here")
    gridLayout(boosts, UDim2.fromOffset(350, 96))
    local boostCard = card(boosts, UDim2.new(), Theme.color.Ready)
    StrokedText.new({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -150, 0, 26),
        Text = "⚡ " .. Config.Shop.ServerTrainingMultiplier .. "X TRAINING", Font = Theme.font.Display, TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = boostCard })
    local boostNote = StrokedText.new({ Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -150, 0, 48), TextWrapped = true,
        Text = "Every gym gives " .. Config.Shop.ServerTrainingMultiplier .. "x to the whole server for "
            .. Config.Shop.ServerTrainingSeconds // 60 .. " minutes. Stacks!",
        Font = Theme.font.Display, TextSize = 15, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, stroke = 1.5, Parent = boostCard })
    offerButton("ServerTraining", { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(124, 44), Parent = boostCard })
    local fillCard = card(boosts, UDim2.new(), Theme.color.Build)
    StrokedText.new({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), Text = Theme.icon.Launch .. " FILL THE ROCKET",
        Font = Theme.font.Display, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = fillCard })
    StrokedText.new({ Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 48), TextWrapped = true,
        Text = "Add 2,000 to 27,500 Metal or Fuel to the rocket: the buttons above the progress bar. At a destination: more time and the next mission.",
        Font = Theme.font.Display, TextSize = 15, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, stroke = 1.5, Parent = fillCard })

    ------------------------------------------------------------------ HUD button
    -- Under the stat stack (HudController): 150 + its 276 on desktop; on phones the
    -- stack sits at the top, enlarged 1.25x.
    local holder = Create.new("Frame", { Name = "ShopHolder", BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 52),
        Position = UDim2.fromOffset(Theme.gutter, Actions.touch and 8 + 276 * 1.25 + 8 or 150 + 276 + 6), Parent = gui })
    local shopButton = Button.new({
        Name = "ShopButton", Text = "🛒 SHOP", TextSize = 26, color = ROBUX, Size = UDim2.fromOffset(150, 50), sound = false,
        onActivated = function()
            if panel.Visible then return close() end
            fit()
            panel.Visible = true
            if current then render(current) end
            Sfx.play("open")
            Tween.bounce(panel, 1.08, 0.3)
        end,
        Parent = holder,
    })
    local boostChip = StrokedText.new({
        Name = "BoostChip", Position = UDim2.fromOffset(160, 9), Size = UDim2.fromOffset(170, 32), BackgroundTransparency = 0.2,
        BackgroundColor3 = Theme.color.Panel, Font = Theme.font.Display, TextSize = 18, TextColor3 = Theme.color.Ready,
        stroke = 2, Visible = false, Parent = holder,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = boostChip })

    ------------------------------------------------------------------ fill row
    -- Right above the progress pill group (ProgressController: 14 from the bottom, 70
    -- tall, 1.35x on touch).
    fillRow = Create.new("Frame", {
        Name = "FillRow", AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Size = UDim2.fromOffset(700, 36),
        Position = UDim2.new(0.5, 0, 1, Actions.touch and -(14 + 70 * 1.35 + 4) or -(14 + 70 + 4)), Visible = false, Parent = gui,
    })
    -- Five buttons: 700 wide, so phones keep it at 1x to stay on screen.
    Create.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = fillRow })
    for index, units in Shop.Fills do
        offerButton(Shop.fillKey(units), { Name = "Fill" .. units, Size = UDim2.fromOffset(134, 34), TextSize = 16,
            LayoutOrder = index, radius = 10, Parent = fillRow }, "+" .. Theme.number(units) .. " · ")
    end

    ------------------------------------------------------------------ destination
    local DEST_W = 270
    local dest = Panel.new({
        Name = "DestinationShop", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -Theme.gutter, 0.45, 0),
        Size = UDim2.fromOffset(DEST_W, 104 + Missions.Count * 42 + 40), BackgroundTransparency = 0.12, radius = 16,
        stroke = 3, strokeColor = ROBUX, Visible = false, Parent = gui,
    })
    if Actions.touch then Create.new("UIScale", { Name = "TouchScale", Scale = 0.9, Parent = dest }) end
    local destTitle = StrokedText.new({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 26), Font = Theme.font.Display,
        TextSize = 22, stroke = 2, Parent = dest })
    offerButton("ExtraStay", { Name = "ExtraStay", Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 40), Parent = dest },
        "+" .. Config.Shop.ExtraStaySeconds .. "s HERE · ")
    StrokedText.new({ Position = UDim2.fromOffset(12, 86), Size = UDim2.new(1, -24, 0, 20), Text = "PICK THE NEXT MISSION",
        Font = Theme.font.Display, TextSize = 17, TextColor3 = Theme.color.Gold, stroke = 1.5, Parent = dest })
    for mission = 1, Missions.Count do
        local definition = Missions.get(mission)
        local button = offerButton(Shop.nextKey(mission), { Name = "Next" .. definition.Id, Position = UDim2.fromOffset(12, 108 + (mission - 1) * 42),
            Size = UDim2.new(1, -24, 0, 36), TextSize = 17, Parent = dest }, Config.Destinations[mission].name:gsub("^THE ", "") .. " · ")
        Create.new("UIStroke", { Thickness = 3, Color = Theme.rarity[definition.Rarity], ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
    end
    local destStatus = StrokedText.new({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -8), Size = UDim2.new(1, -24, 0, 22),
        Font = Theme.font.Display, TextSize = 16, TextColor3 = Theme.color.Muted, stroke = 1.5, Parent = dest })

    ------------------------------------------------------------------ render
    function render(state)
        local shop = state.shop or {}
        -- The fill buttons name the material the rocket needs right now.
        local material = state.phase == "Fueling" and Theme.icon.Fuel or Theme.icon.Metal
        for _, units in Shop.Fills do offers[Shop.fillKey(units)].prefix = "+" .. Theme.number(units) .. " " .. material .. " · " end
        local owned = shop.owned or {}
        for key, offer in offers do renderOffer(key, offer, state) end
        local launches = state.profile and state.profile.completedLaunches or 0
        for tier, gym in gymCards do
            local unlocked = launches >= gym.cycles
            gym.note.Text = unlocked and "✔ Unlocked by launches" or ("🔒 " .. launches .. "/" .. gym.cycles .. (gym.cycles == 1 and " launch" or " launches"))
            if unlocked and not owned[Shop.gymKey(tier)] then
                gym.button.Label.Text, gym.button.BackgroundColor3 = "UNLOCKED", OWNED
            end
        end
        -- Hidden under the open panel.
        fillRow.Visible = (state.phase == "Building" or state.phase == "Fueling") and not panel.Visible
        local atDestination = state.phase == "Rewarding" and state.passenger == true
        dest.Visible = atDestination
        if atDestination then
            destTitle.Text = "🪐 " .. (state.destination or "SPACE")
            if shop.guaranteed then
                local index = Missions.index(shop.guaranteed)
                destStatus.Text = "🔒 NEXT: " .. (index and Config.Destinations[index].name or shop.guaranteed)
            elseif state.wheel then
                destStatus.Text = "The wheel has spun!"
            else
                destStatus.Text = (shop.stayExtra or 0) > 0 and ("+" .. shop.stayExtra .. "s added this stay") or "Or let the wheel decide!"
            end
        end
    end
    State.subscribe(function(state, previous)
        current = state
        local owned = state.shop and state.shop.owned or {}
        local before = previous and previous.shop and previous.shop.owned or {}
        for key in owned do
            if not before[key] and previous then Sfx.play("confirm"); Tween.bounce(shopButton.Label, 1.4, 0.4) end
        end
        render(state)
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.25 or not current then return end
        elapsed = 0
        local left = (current.shop and current.shop.boostUntil or 0) - workspace:GetServerTimeNow()
        boostChip.Visible = left > 0
        if left > 0 then
            boostChip.Text = "⚡ " .. Config.Shop.ServerTrainingMultiplier .. "X TRAINING " .. clock(left)
            boostNote.Text = "Active: " .. clock(left) .. " left. Buy again to add " .. Config.Shop.ServerTrainingSeconds // 60 .. " more minutes!"
        end
    end)
end

return ShopController
