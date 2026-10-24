-- Walk-in offers: stepping onto a gym bay you can't use yet (a District tier short of its
-- launches, or the paid-only SpaceX Gym) or up to a suit stand whose suit you don't own
-- opens Roblox's own purchase prompt for it (user, 2026-10-24: the official buy screen,
-- like the fill buttons'). It sends BuyShop(key) like the SHOP: the server checks it and
-- opens the prompt. Once per walk-in: closing the prompt and standing there doesn't
-- reopen it; walking off and back does.
-- Gym bays are WorldService's GymBay parts; suit stands SkinService's SuitStand prompts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Skins = require(ReplicatedStorage.Shared.Skins)
local State = require(script.Parent.State)
local PurchaseOfferController = {}

local STAND_RANGE = 9 -- studs from a suit stand's centre (its plinth is 6 across)
local CHECK_SECONDS = 0.15
-- A new offer waits this long after the last prompt, so walking across two bays doesn't
-- stack prompts.
local PROMPT_GAP = 1

function PurchaseOfferController.start()
    local player = Players.LocalPlayer
    local launches, owned = 0, {}

    -- The pass key for the spot the player stands on, if they don't own it yet.
    local function gymOffer(bay, position)
        local tier = bay:GetAttribute("GymTier")
        if tier == nil then return nil end
        local key = Shop.gymKey(tier)
        local paid = bay:GetAttribute("PaidOnly") == true
        local required = bay:GetAttribute("RequiredCycles") or 0
        if owned[key] or (not paid and launches >= required) then return nil end
        local local_ = bay.CFrame:PointToObjectSpace(position)
        if math.abs(local_.X) > bay.Size.X / 2 or math.abs(local_.Z) > bay.Size.Z / 2 or local_.Y < -2 or local_.Y > 12 then return nil end
        return key
    end
    local function suitOffer(prompt, position)
        local key = prompt:GetAttribute("Suit")
        local holder = prompt.Parent
        if not key or not Skins.get(key) or owned[key] or not holder or not holder:IsA("BasePart") then return nil end
        local offset = holder.Position - position
        if Vector3.new(offset.X, 0, offset.Z).Magnitude > STAND_RANGE or math.abs(offset.Y) > 12 then return nil end
        return key
    end
    local function find(position)
        for _, bay in CollectionService:GetTagged("GymBay") do
            local key = gymOffer(bay, position)
            if key then return key end
        end
        for _, prompt in CollectionService:GetTagged("SuitStand") do
            local key = suitOffer(prompt, position)
            if key then return key end
        end
        return nil
    end

    State.subscribe(function(state)
        launches = state.profile and state.profile.completedLaunches or 0
        owned = state.shop and state.shop.owned or {}
    end)
    -- The offer already prompted for this walk-in, and when the last prompt opened.
    local prompted, lastPrompt = nil, -math.huge
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < CHECK_SECONDS then return end
        elapsed = 0
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local key = root and find(root.Position) or nil
        if key ~= prompted and key and Shop.enabled(Config, key) and os.clock() - lastPrompt >= PROMPT_GAP then
            prompted, lastPrompt = key, os.clock()
            State.remote("BuyShop"):FireServer(key)
        elseif not key then
            prompted = nil
        end
    end)
end

return PurchaseOfferController
