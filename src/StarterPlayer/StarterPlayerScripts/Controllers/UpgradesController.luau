-- The UPGRADES panel (reference frame 7): one row per Config.Upgrades track with its
-- level, what the next level does, a coin price button and, when that level's tier has a
-- developer product, a Robux +1 level button. The hut's "Open Upgrades"
-- prompt opens it; walking away or ✖ closes it. Buying sends BuyUpgrade with a fresh
-- request ID; the server validates, charges once per ID and replies with state. The
-- press clicks (or buzzes when you can't afford it); the cha-ching waits for that
-- reply, so it lands with the new level.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
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
local UpgradesController = {}

local ROW = 66
local WIDTH, HEIGHT = 680, 70 + #Config.UpgradeOrder * ROW + 26
local CLOSE_DISTANCE = 22
local CANT_AFFORD = Color3.fromRGB(120, 112, 140)

-- The cha-ching for reaching `level` (coins or Robux), bigger every tier: the chime
-- climbs a major scale to the octave, more coins clink in, then a sparkle (tier 4+)
-- and the level-up arpeggio (tier 7+) join, and the last tier lands the hit jingle
-- and a fanfare.
local SCALE = { 0, 2, 4, 5, 7, 9, 11, 12 }
local function celebrate(level, max)
    local loud = 1 + 0.04 * (level - 1)
    Sfx.play("confirm", { pitch = 0.9 * 2 ^ (SCALE[math.min(level, #SCALE)] / 12), volume = loud })
    for clink = 1, math.min(1 + level // 3, 4) do
        task.delay(0.05 + 0.06 * clink, Sfx.play, "coin", { pitch = 1 + 0.04 * clink, volume = 1.6 * loud })
    end
    if level >= 4 then task.delay(0.1, Sfx.play, "gain", { pitch = 1 + 0.03 * (level - 4), volume = 0.8 * loud }) end
    if level >= 7 then task.delay(0.16, Sfx.play, "levelup", { pitch = 1 + 0.04 * (level - 7), volume = 2 * loud }) end
    if level >= max then
        task.delay(0.3, Sfx.play, "jingle", { volume = 1.1 })
        task.delay(0.3, Sfx.play, "fanfare4")
    end
end

-- "now → next" for each track's effect.
local function effect(track, level)
    local spec = Config.Upgrades[track]
    local function at(n)
        local bonus = n * spec.step
        if track == "BulkPickup" then return "Grab " .. Upgrades.bulkUnits(Config, track, n) .. " per tick" end
        if track == "BulkPlace" then return "Place " .. Upgrades.bulkUnits(Config, track, n) .. " per tick" end
        return "Reach +" .. math.round(bonus * 100) .. "%"
    end
    if level >= spec.max then return at(level) .. "  (MAX)" end
    return at(level) .. "  →  " .. at(level + 1)
end

function UpgradesController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("RocketUpgrades")
    gui.DisplayOrder = 10
    local panel = Panel.new({
        Name = "UpgradesPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundTransparency = 0.05, radius = 18,
        stroke = 4, strokeColor = Theme.color.Gold, Visible = false, Parent = gui,
    })
    -- Phones shrink the HUD to ~0.45; keep the panel readable (≥ 0.75) while it fits,
    -- and on touch slide it left of the action buttons so GRAB/JUMP stay usable.
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
        Text = "UPGRADES", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(300, 44), Font = Theme.font.Display, TextSize = 38, stroke = 3, Parent = panel,
    })
    local coinsLabel = StrokedText.new({
        Name = "Coins", Position = UDim2.fromOffset(22, 18), Size = UDim2.fromOffset(150, 34), Text = Theme.icon.Coin .. " 0",
        Font = Theme.font.Display, TextSize = 26, TextColor3 = Theme.color.Gold, TextXAlignment = Enum.TextXAlignment.Left,
        stroke = 2, Parent = panel,
    })
    local function close()
        if panel.Visible then Sfx.play("close") end
        panel.Visible = false
    end
    Button.new({
        Name = "Close", shape = "circle", icon = Theme.icon.Leave, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 46),
        sound = false, onActivated = close, Parent = panel,
    })

    local current
    local rows = {}
    local pending = {}
    for index, track in Config.UpgradeOrder do
        local spec = Config.Upgrades[track]
        local y = 70 + (index - 1) * ROW
        local row = Create.new("Frame", {
            Name = track, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, ROW - 8),
            BackgroundColor3 = Theme.color.Track, BackgroundTransparency = 0.35, Parent = panel,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = row })
        StrokedText.new({
            Name = "Icon", Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(50, 50), Text = spec.icon,
            Font = Theme.font.Display, TextSize = 36, stroke = 2, Parent = row,
        })
        local title = StrokedText.new({
            Name = "Title", Position = UDim2.fromOffset(66, 4), Size = UDim2.fromOffset(300, 28), Text = spec.name,
            Font = Theme.font.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = row,
        })
        local detail = StrokedText.new({
            Name = "Detail", Position = UDim2.fromOffset(66, 30), Size = UDim2.fromOffset(310, 22),
            Font = Theme.font.Display, TextSize = 17, TextColor3 = Theme.color.Muted, TextXAlignment = Enum.TextXAlignment.Left,
            stroke = 1.5, Parent = row,
        })
        local buy = Button.new({
            Name = "Buy", Text = "", TextSize = 22, color = Theme.color.Go,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 44),
            Parent = row, sound = false,
            onActivated = function()
                local state = current and current.profile
                if not state or pending[track] then return end
                local level = state.upgrades and state.upgrades[track] or 0
                local price = Upgrades.price(Config, track, level)
                if not price or state.coins < price then return Sfx.play("error") end
                Sfx.play("click")
                pending[track] = true
                State.remote("BuyUpgrade"):FireServer(track, HttpService:GenerateGUID(false))
                -- The reply is a state update; give up waiting after a second.
                task.delay(1, function() pending[track] = nil end)
            end,
        })
        -- Robux: the server opens the purchase prompt (and refuses at max or mid-purchase).
        local robux = Button.new({
            Name = "Robux", Text = "", TextSize = 22, color = Theme.color.Speed,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -156, 0.5, 0), Size = UDim2.fromOffset(100, 44),
            Visible = false, Parent = row,
            onActivated = function() State.remote("BuyUpgradeRobux"):FireServer(track) end,
        })
        rows[track] = { title = title, detail = detail, buy = buy, robux = robux }
    end

    local function render(state)
        local profile = state.profile
        if not profile then return end
        coinsLabel.Text = Theme.icon.Coin .. " " .. Theme.number(profile.coins)
        for track, row in rows do
            local level = profile.upgrades and profile.upgrades[track] or 0
            local price = Upgrades.price(Config, track, level)
            row.title.Text = Config.Upgrades[track].name .. "  Lv " .. level
            row.detail.Text = effect(track, level)
            row.buy.Label.Text = price and (Theme.icon.Coin .. " " .. Theme.short(price)) or "MAX"
            row.buy.BackgroundColor3 = (price and profile.coins >= price) and Theme.color.Go or CANT_AFFORD
            local product, robux = Upgrades.robux(Config, track, level)
            row.robux.Visible = product ~= nil
            if robux then row.robux.Label.Text = "R$ " .. robux end
        end
    end
    State.subscribe(function(state, previous)
        current = state
        local before = previous and previous.profile and previous.profile.upgrades
        if before and state.profile then
            for track, row in rows do
                local level = state.profile.upgrades[track] or 0
                if level > (before[track] or 0) then
                    pending[track] = nil
                    Tween.bounce(row.title, 1.25 + 0.3 * level / Config.Upgrades[track].max, 0.35 + 0.02 * level)
                    celebrate(level, Config.Upgrades[track].max)
                end
            end
        end
        render(state)
    end)

    local function hut() return CollectionService:GetTagged("UpgradesHut")[1] end
    ProximityPromptService.PromptTriggered:Connect(function(prompt)
        local part = hut()
        if part and prompt.Parent == part then
            fit()
            if not panel.Visible then Sfx.play("open") end
            panel.Visible = true
            if current then render(current) end
            Tween.bounce(panel, 1.08, 0.3)
        end
    end)
    RunService.Heartbeat:Connect(function()
        if not panel.Visible then return end
        local part = hut()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not part or not root or (root.Position - part.Position).Magnitude > CLOSE_DISTANCE then close() end
    end)
end

return UpgradesController
