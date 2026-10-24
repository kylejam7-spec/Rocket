-- The suit stands' prompts (SkinService), worded for this player: "Buy R$ 1,199" until
-- they own the suit, then "Wear", or "Take off" while they wear it (back to the basic
-- suit). The server decides what a press does; this only changes the words, locally.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Skins = require(ReplicatedStorage.Shared.Skins)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local SuitStandController = {}

local TAG = "SuitStand" -- SkinService.StandTag

function SuitStandController.start()
    local player = Players.LocalPlayer
    local owned = {}
    local function word(prompt)
        local key = prompt:GetAttribute("Suit")
        local skin = key and Skins.get(key)
        if not skin then return end
        prompt.ObjectText = skin.name .. " · " .. skin.multiplier .. "x boost"
        if player:GetAttribute("Suit") == key then
            prompt.ActionText = "Take off"
        elseif owned[key] then
            prompt.ActionText = "Wear"
        else
            prompt.ActionText = "Buy R$ " .. Theme.number(Shop.entry(Config, key).price)
        end
    end
    local function all()
        for _, prompt in CollectionService:GetTagged(TAG) do word(prompt) end
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(word)
    State.subscribe(function(state)
        owned = state.shop and state.shop.owned or {}
        all()
    end)
    player:GetAttributeChangedSignal("Suit"):Connect(all)
    all()
end

return SuitStandController
