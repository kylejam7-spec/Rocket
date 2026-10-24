-- Walk-in offers: stepping onto a gym bay you can't use yet (a District tier short of its
-- launches, or the paid-only SpaceX Gym) or up to a suit stand whose suit you don't own
-- pops a card with the item's picture, what it gives and a Robux button. BUY sends
-- BuyShop(key) like the SHOP (the server checks it and opens the Roblox prompt); NO
-- THANKS or walking away closes it, and it shows again the next time you walk in.
-- Gym bays are WorldService's GymBay parts; suit stands SkinService's SuitStand prompts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Skins = require(ReplicatedStorage.Shared.Skins)
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local Sfx = require(UI.Sfx)
local StrokedText = require(UI.StrokedText)
local Icon = require(UI.Icon)
local Tween = require(UI.Tween)
local PurchaseOfferController = {}

local WIDTH, HEIGHT = 330, 400
local ROBUX = Theme.color.Purple
local STAND_RANGE = 9 -- studs from a suit stand's centre (its plinth is 6 across)
local CHECK_SECONDS = 0.15

function PurchaseOfferController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("PurchaseOffer")
    gui.DisplayOrder = 12
    local launches, owned = 0, {}
    -- The offer showing (its key), and the one the player last closed while still there.
    local showing, dismissed

    local card = Panel.new({
        Name = "OfferCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundTransparency = 0.04, radius = 20, stroke = 4, strokeColor = ROBUX,
        Visible = false, Parent = gui,
    })
    local title = StrokedText.new({ Name = "Title", Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 32),
        Font = Theme.font.Display, TextScaled = true, stroke = 2.5, Parent = card })
    local picture = Create.new("Frame", { Name = "Picture", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
        Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 1, Parent = card })
    local blurb = StrokedText.new({ Name = "Blurb", Position = UDim2.fromOffset(18, 230), Size = UDim2.new(1, -36, 0, 56),
        Font = Theme.font.Display, TextSize = 19, TextWrapped = true, TextColor3 = Theme.color.Muted, stroke = 1.5, Parent = card })
    local current
    local buy = Button.new({ Name = "Buy", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 292),
        Size = UDim2.new(1, -36, 0, 54), Text = "", TextSize = 26, color = ROBUX, sound = false, Parent = card,
        onActivated = function()
            if not current then return end
            Sfx.play("click")
            State.remote("BuyShop"):FireServer(current.key)
        end,
    })
    local function close()
        if not card.Visible then return end
        Sfx.play("close")
        dismissed, showing = showing, nil
        card.Visible = false
    end
    Button.new({ Name = "NoThanks", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.fromOffset(150, 36), Text = "NO THANKS", TextSize = 18, color = Theme.color.Track, sound = false,
        onActivated = close, Parent = card })
    Button.new({ Name = "Close", shape = "circle", icon = Theme.icon.Leave, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(42, 42),
        sound = false, onActivated = close, Parent = card })

    local function show(offer)
        current = offer
        showing = offer.key
        for _, child in picture:GetChildren() do child:Destroy() end
        Icon.new(offer.key, offer.emoji, { Size = UDim2.fromScale(1, 1), TextSize = 110, Parent = picture })
        title.Text = offer.title
        blurb.Text = offer.blurb
        local entry = Shop.entry(Config, offer.key)
        buy.Label.Text = "BUY  R$ " .. Theme.number(entry and entry.price or 0)
        buy.BackgroundColor3 = Shop.enabled(Config, offer.key) and ROBUX or Color3.fromRGB(120, 112, 140)
        if not card.Visible then
            card.Visible = true
            Sfx.play("open")
            Tween.bounce(card, 1.08, 0.3)
        end
    end
    local function hide()
        showing, current = nil, nil
        card.Visible = false
    end

    -- The offer for the spot the player stands on, if any.
    local function gymOffer(bay, position)
        local tier = bay:GetAttribute("GymTier")
        if tier == nil then return nil end
        local key = Shop.gymKey(tier)
        local paid = bay:GetAttribute("PaidOnly") == true
        local required = bay:GetAttribute("RequiredCycles") or 0
        if owned[key] or (not paid and launches >= required) then return nil end
        local local_ = bay.CFrame:PointToObjectSpace(position)
        if math.abs(local_.X) > bay.Size.X / 2 or math.abs(local_.Z) > bay.Size.Z / 2 or local_.Y < -2 or local_.Y > 12 then return nil end
        local multiplier = bay:GetAttribute("Multiplier") or 1
        return {
            key = key, emoji = paid and "🚀" or "🏋", title = (bay:GetAttribute("Title") or "GYM") .. (paid and " ACCESS" or " PASS"),
            blurb = paid and ("x" .. multiplier .. " strength & speed on every bench and treadmill here. Game Pass only!")
                or ("Train here now at x" .. multiplier .. " without the " .. required .. " launches."),
        }
    end
    local function suitOffer(prompt, position)
        local key = prompt:GetAttribute("Suit")
        local skin = key and Skins.get(key)
        local holder = prompt.Parent
        if not skin or owned[key] or not holder or not holder:IsA("BasePart") then return nil end
        local offset = holder.Position - position
        if Vector3.new(offset.X, 0, offset.Z).Magnitude > STAND_RANGE or math.abs(offset.Y) > 12 then return nil end
        return { key = key, emoji = skin.icon, title = skin.name:upper(), blurb = "Wear it for " .. Skins.blurb(skin) .. "!" }
    end
    local function find(position)
        for _, bay in CollectionService:GetTagged("GymBay") do
            local offer = gymOffer(bay, position)
            if offer then return offer end
        end
        for _, prompt in CollectionService:GetTagged("SuitStand") do
            local offer = suitOffer(prompt, position)
            if offer then return offer end
        end
        return nil
    end

    State.subscribe(function(state)
        launches = state.profile and state.profile.completedLaunches or 0
        owned = state.shop and state.shop.owned or {}
        -- Bought it: the card goes (the SHOP plays the confirm sound).
        if showing and owned[showing] then hide() end
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < CHECK_SECONDS then return end
        elapsed = 0
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local offer = root and find(root.Position) or nil
        local key = offer and offer.key
        -- Walked off what was closed: it may show again next time.
        if dismissed and dismissed ~= key then dismissed = nil end
        if not offer then
            if showing then hide() end
        elseif key ~= showing and key ~= dismissed then
            show(offer)
        end
    end)
end

return PurchaseOfferController
