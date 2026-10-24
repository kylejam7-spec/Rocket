-- The UFO SHOP panel: one row per Shared.Pets UFO tier with its landing time, pet odds
-- and price. Any UFO Shop counter's "Open UFO Shop" prompt opens it; walking away or ✖
-- closes it. Buying sends BuyUfo with a fresh request ID (the server charges once per
-- ID); when the UFO shows up in the state the panel closes so you can watch it arrive.
-- Rare, Epic and Legendary UFOs also sell for Robux (Config.Shop UfoRare/UfoEpic/
-- UfoLegendary; Epic and Legendary only for Robux): the purple button sends BuyShop and
-- the server opens the prompt. One UFO flies at a time; the SHOP's Triple Hatch pass lets
-- 3 (state.shop.maxUfos), each at its own price.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pets = require(ReplicatedStorage.Shared.Pets)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local Sfx = require(UI.Sfx)
local StrokedText = require(UI.StrokedText)
local Icon = require(UI.Icon)
local Tween = require(UI.Tween)
local UfoShopController = {}

local ROW = 70
local TOP = 104
local WIDTH, HEIGHT = 700, TOP + #Pets.Ufos * ROW + 18
local CLOSE_DISTANCE = 22
local CANT_AFFORD = Color3.fromRGB(120, 112, 140)

local function hex(color)
    return ("#%02X%02X%02X"):format(color.R * 255, color.G * 255, color.B * 255)
end
-- "5 min · 80% Common · 20% Uncommon", each rarity in its colour. With Fast Hatch
-- (`rate` > 1) the landing time shows divided and marked ⚡.
local function odds(ufo, rate)
    local minutes = ufo.Minutes / (rate or 1)
    local parts = { (rate or 1) > 1 and ("⚡ " .. (minutes % 1 == 0 and minutes or ("%.1f"):format(minutes)) .. " min") or (minutes .. " min") }
    for _, rarity in Pets.Rarities do
        local percent = ufo.Odds[rarity]
        if percent then table.insert(parts, ('<font color="%s">%d%% %s</font>'):format(hex(Theme.rarity[rarity]), percent, rarity)) end
    end
    return table.concat(parts, "  ·  ")
end

function UfoShopController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("RocketUfoShop")
    gui.DisplayOrder = 10
    local panel = Panel.new({
        Name = "UfoShopPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundTransparency = 0.05, radius = 18,
        stroke = 4, strokeColor = Theme.color.Ready, Visible = false, Parent = gui,
    })
    -- Same phone fit as the upgrades panel: readable, and left of the touch buttons.
    local screenScale = gui:FindFirstChildOfClass("UIScale")
    local panelScale = Create.new("UIScale", { Name = "ReadableScale", Parent = panel })
    local function fit()
        local s = screenScale and screenScale.Scale or 1
        local want = math.max(s, math.min(0.75, 0.9 * gui.AbsoluteSize.Y / HEIGHT))
        panelScale.Scale = want / s
        local shift = 0
        if Actions.touch then
            local cluster = Actions.cluster()
            local right = gui.AbsoluteSize.X / 2 + WIDTH * want / 2
            shift = math.min(0, cluster.AbsolutePosition.X - 8 - right)
        end
        panel.Position = UDim2.new(0.5, shift / s, 0.5, 0)
    end
    if screenScale then screenScale:GetPropertyChangedSignal("Scale"):Connect(fit) end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()

    StrokedText.new({
        Text = "🛸 UFO SHOP", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(320, 44), Font = Theme.font.Display, TextSize = 38, stroke = 3, Parent = panel,
    })
    local coinsLabel = StrokedText.new({
        Name = "Coins", Position = UDim2.fromOffset(22, 18), Size = UDim2.fromOffset(150, 34), Text = Theme.icon.Coin .. " 0",
        Font = Theme.font.Display, TextSize = 26, TextColor3 = Theme.color.Gold, TextXAlignment = Enum.TextXAlignment.Left,
        stroke = 2, Parent = panel,
    })
    local status = StrokedText.new({
        Name = "Status", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.new(1, -40, 0, 28),
        Font = Theme.font.Display, TextSize = 20, TextColor3 = Theme.color.Muted, stroke = 1.5, Parent = panel,
    })
    local openShop
    local function close()
        if panel.Visible then Sfx.play("close") end
        panel.Visible, openShop = false, nil
    end
    Button.new({
        Name = "Close", shape = "circle", icon = Theme.icon.Leave, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 46),
        sound = false, onActivated = close, Parent = panel,
    })

    local current, render
    local rows, pending = {}, {}
    -- UFOs that can fly at once (Triple Hatch: 3).
    local function room(state)
        local profile = state and state.profile
        local max = state and state.shop and state.shop.maxUfos or 1
        return profile ~= nil and #(profile.ufos or {}) < max, max
    end
    for tier, ufo in Pets.Ufos do
        local color = Theme.rarity[ufo.Rarity]
        local row = Create.new("Frame", {
            Name = "Tier" .. tier, Position = UDim2.fromOffset(16, TOP + (tier - 1) * ROW), Size = UDim2.new(1, -32, 0, ROW - 8),
            BackgroundColor3 = Theme.color.Track, BackgroundTransparency = 0.35, Parent = panel,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = row })
        Create.new("UIStroke", { Thickness = 2, Color = color, Transparency = 0.3, Parent = row })
        Icon.new(Shop.ufoKey(tier), Theme.icon.Ufo, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(50, 50), TextSize = 36, Parent = row })
        StrokedText.new({
            Name = "Title", Position = UDim2.fromOffset(66, 6), Size = UDim2.fromOffset(330, 28), Text = ufo.Name:upper(),
            Font = Theme.font.Display, TextSize = 24, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = row,
        })
        local oddsLabel = StrokedText.new({
            Name = "Odds", Position = UDim2.fromOffset(66, 34), Size = UDim2.fromOffset(330, 22), Text = odds(ufo), RichText = true,
            Font = Theme.font.Display, TextSize = 17, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
            stroke = 1.5, Parent = row,
        })
        -- Robux: its own purple button (left of the coin price), or the only one.
        local key = Shop.ufoKey(tier)
        local robux
        if Shop.entry(Config, key) then
            robux = Button.new({
                Name = "Robux", Text = "R$ " .. Shop.entry(Config, key).price, TextSize = 20, color = Theme.color.Purple,
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, ufo.Price and -156 or -8, 0.5, 0),
                Size = UDim2.fromOffset(ufo.Price and 110 or 140, 44), Parent = row, sound = false,
                onActivated = function()
                    if not current or not room(current) or not Shop.enabled(Config, key) then return Sfx.play("error") end
                    Sfx.play("click")
                    State.remote("BuyShop"):FireServer(key)
                end,
            })
        end
        local buy = ufo.Price and Button.new({
            Name = "Buy", Text = Theme.icon.Coin .. " " .. Theme.short(ufo.Price), TextSize = 22,
            color = Theme.color.Go,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 44),
            Parent = row, sound = false,
            onActivated = function()
                local profile = current and current.profile
                if not profile or pending[tier] then return end
                if not ufo.Price or not room(current) or profile.coins < ufo.Price then return Sfx.play("error") end
                Sfx.play("click")
                pending[tier] = true
                State.remote("BuyUfo"):FireServer(tier, HttpService:GenerateGUID(false))
                task.delay(1, function() pending[tier] = nil end)
            end,
        })
        rows[tier] = { buy = buy, robux = robux, key = key, odds = oddsLabel }
    end

    function render(state)
        local profile = state.profile
        if not profile then return end
        coinsLabel.Text = Theme.icon.Coin .. " " .. Theme.number(profile.coins)
        local ufos = profile.ufos or {}
        local free, max = room(state)
        -- The one landing soonest.
        local soonest
        for _, ufo in ufos do if not soonest or ufo.hatchAt < soonest.hatchAt then soonest = ufo end end
        if soonest then
            local landing = Pets.Ufos[soonest.tier].Name .. " lands in " .. Pets.clock(soonest.hatchAt - workspace:GetServerTimeNow())
            status.Text = (max > 1 and (#ufos .. "/" .. max .. " UFOs flying · next: ") or "Your ") .. landing
                .. (free and "" or (max > 1 and ". All slots busy!" or ". One UFO at a time!"))
        else
            status.Text = "Each UFO follows you while you play, then lands as a random pet!"
        end
        local owned = state.shop and state.shop.owned or {}
        local rate = owned.FastHatch and Config.Shop.FastHatchRate or 1
        for tier, row in rows do
            row.odds.Text = odds(Pets.Ufos[tier], rate)
            local price = Pets.Ufos[tier].Price
            if price then
                row.buy.BackgroundColor3 = (free and profile.coins >= price) and Theme.color.Go or CANT_AFFORD
            end
            if row.robux then
                row.robux.BackgroundColor3 = (free and Shop.enabled(Config, row.key)) and Theme.color.Purple or CANT_AFFORD
            end
        end
    end
    State.subscribe(function(state, previous)
        current = state
        local had = previous and previous.profile and #(previous.profile.ufos or {}) or 0
        if state.profile and #(state.profile.ufos or {}) > had and previous then
            table.clear(pending)
            Sfx.play("confirm")
            -- Close so the player sees their UFO swoop in.
            if panel.Visible then panel.Visible, openShop = false, nil end
        end
        render(state)
    end)

    ProximityPromptService.PromptTriggered:Connect(function(prompt)
        local part = prompt.Parent
        if part and CollectionService:HasTag(part, "UfoShop") then
            fit()
            if not panel.Visible then Sfx.play("open") end
            panel.Visible, openShop = true, part
            if current then render(current) end
            Tween.bounce(panel, 1.08, 0.3)
        end
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        if not panel.Visible then return end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not openShop or not root or (root.Position - openShop.Position).Magnitude > CLOSE_DISTANCE then return close() end
        -- Keep the countdown ticking.
        elapsed += dt
        if elapsed >= 0.5 and current then
            elapsed = 0
            render(current)
        end
    end)
end

return UfoShopController
