-- The UFO SHOP panel: one row per Shared.Pets UFO tier with its landing time, pet odds
-- and price. Any UFO Shop counter's "Open UFO Shop" prompt opens it; walking away or ✖
-- closes it. Buying sends BuyUfo with a fresh request ID (the server charges once per
-- ID); when the UFO shows up in the state the panel closes so you can watch it arrive.
-- Epic and Legendary UFOs are Robux-only and not on sale yet ("SOON"). With the SHOP's
-- Triple Hatch pass a x3 switch appears: one UFO brings 3 pets, for 3x the coins.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pets = require(ReplicatedStorage.Shared.Pets)
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
local UfoShopController = {}

local ROW = 70
local TOP = 104
local WIDTH, HEIGHT = 700, TOP + #Pets.Ufos * ROW + 18
local CLOSE_DISTANCE = 22
local CANT_AFFORD = Color3.fromRGB(120, 112, 140)

local function hex(color)
    return ("#%02X%02X%02X"):format(color.R * 255, color.G * 255, color.B * 255)
end
-- "5 min · 80% Common · 20% Uncommon", each rarity in its colour.
local function odds(ufo)
    local parts = { ufo.Minutes .. " min" }
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
    -- Triple Hatch (state.shop.owned.MultiHatch): pets per UFO while the switch is on.
    local triple = false
    local function count()
        local owned = current and current.shop and current.shop.owned or {}
        return (triple and owned.MultiHatch) and 3 or 1
    end
    local tripleButton = Button.new({
        Name = "Triple", Text = "🛸 x3: OFF", TextSize = 16, color = Theme.color.Purple, radius = 10, stroke = 2,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 18), Size = UDim2.fromOffset(120, 32),
        Visible = false, Parent = panel,
        onActivated = function() triple = not triple; if current then render(current) end end,
    })
    for tier, ufo in Pets.Ufos do
        local color = Theme.rarity[ufo.Rarity]
        local row = Create.new("Frame", {
            Name = "Tier" .. tier, Position = UDim2.fromOffset(16, TOP + (tier - 1) * ROW), Size = UDim2.new(1, -32, 0, ROW - 8),
            BackgroundColor3 = Theme.color.Track, BackgroundTransparency = 0.35, Parent = panel,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = row })
        Create.new("UIStroke", { Thickness = 2, Color = color, Transparency = 0.3, Parent = row })
        StrokedText.new({
            Name = "Icon", Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(50, 50), Text = Theme.icon.Ufo,
            Font = Theme.font.Display, TextSize = 36, stroke = 2, Parent = row,
        })
        StrokedText.new({
            Name = "Title", Position = UDim2.fromOffset(66, 6), Size = UDim2.fromOffset(330, 28), Text = ufo.Name:upper(),
            Font = Theme.font.Display, TextSize = 24, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = row,
        })
        StrokedText.new({
            Name = "Odds", Position = UDim2.fromOffset(66, 34), Size = UDim2.fromOffset(420, 22), Text = odds(ufo), RichText = true,
            Font = Theme.font.Display, TextSize = 17, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
            stroke = 1.5, Parent = row,
        })
        local buy = Button.new({
            Name = "Buy", Text = ufo.Price and Theme.icon.Coin .. " " .. Theme.short(ufo.Price) or "R$ SOON", TextSize = 22,
            color = ufo.Price and Theme.color.Go or Theme.color.Purple,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 44),
            Parent = row, sound = false,
            onActivated = function()
                local profile = current and current.profile
                if not profile or pending[tier] then return end
                local n = count()
                if not ufo.Price or profile.ufo or profile.coins < ufo.Price * n then return Sfx.play("error") end
                Sfx.play("click")
                pending[tier] = true
                State.remote("BuyUfo"):FireServer(tier, HttpService:GenerateGUID(false), n)
                task.delay(1, function() pending[tier] = nil end)
            end,
        })
        rows[tier] = { buy = buy }
    end

    function render(state)
        local profile = state.profile
        if not profile then return end
        coinsLabel.Text = Theme.icon.Coin .. " " .. Theme.number(profile.coins)
        local active = profile.ufo
        if active then
            local ufo = Pets.Ufos[active.tier]
            status.Text = "Your " .. ufo.Name .. " lands in " .. Pets.clock(active.hatchAt - workspace:GetServerTimeNow()) .. ". One UFO at a time!"
        else
            status.Text = "Each UFO follows you while you play, then lands as a random pet!"
        end
        local owned = state.shop and state.shop.owned or {}
        tripleButton.Visible = owned.MultiHatch == true
        local n = count()
        tripleButton.Label.Text = "🛸 x3: " .. (n == 3 and "ON" or "OFF")
        tripleButton.BackgroundColor3 = n == 3 and Theme.color.Go or Theme.color.Purple
        for tier, row in rows do
            local price = Pets.Ufos[tier].Price
            if price then
                row.buy.Label.Text = Theme.icon.Coin .. " " .. Theme.short(price * n) .. (n > 1 and " x" .. n or "")
                row.buy.BackgroundColor3 = (not active and profile.coins >= price * n) and Theme.color.Go or CANT_AFFORD
            end
        end
    end
    State.subscribe(function(state, previous)
        current = state
        local had = previous and previous.profile and previous.profile.ufo
        if state.profile and state.profile.ufo and not had and previous then
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
