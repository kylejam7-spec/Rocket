-- Suits (Shared.Skins, SkinService): the best owned suit is worn, 2x / 4x / 8x, the
-- default is 1x; every suit has a Config.Shop pass entry; the description carries the
-- suit's colours and nothing of the player's own; dressing welds the gear on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skins = require(ReplicatedStorage.Shared.Skins)
local Config = require(ReplicatedStorage.Shared.Config)
local SkinService = require(script.Parent.SkinService)

return function()
    local function owning(keys)
        return function(key) return table.find(keys, key) ~= nil end
    end
    assert(Skins.best(owning({})) == Skins.Default and Skins.Default.multiplier == 1, "default suit")
    assert(Skins.best(owning({ "SuitGold" })).multiplier == 2)
    assert(Skins.best(owning({ "SuitCommander" })).multiplier == 4)
    assert(Skins.best(owning({ "SuitGold", "SuitGalaxy" })).multiplier == 8, "best owned wins")
    assert(Skins.best(owning({ "SuitGold", "SuitCommander" })).key == "SuitCommander", "no stacking")
    for _, skin in Skins.List do
        assert(Config.Shop.passes[skin.key], skin.key .. " has no pass entry")
        assert(Skins.get(skin.key) == skin)
    end
    local description = Skins.description(Skins.List[3])
    assert(description.TorsoColor == Skins.List[3].suit and description.Shirt == 0 and description.HatAccessory == "", "description")
    description:Destroy()
    -- Their own head: shape, face, skin tone and hair, but no hat or clothes.
    local avatar = Instance.new("HumanoidDescription")
    avatar.Head, avatar.Face, avatar.HeadColor, avatar.Shirt = 123, 456, Color3.fromRGB(90, 60, 40), 789
    avatar.HairAccessory, avatar.HatAccessory = "111", "222"
    local mine = Skins.description(Skins.Default, avatar)
    assert(mine.Head == 123 and mine.Face == 456 and mine.HeadColor == avatar.HeadColor and mine.TorsoColor == Skins.Default.suit, "own head")
    assert(mine.HairAccessory == "111" and mine.HatAccessory == "" and mine.Shirt == 0, "hair kept, hat and shirt dropped")
    mine:Destroy()
    avatar:Destroy()
    -- Dressing a stand-in R15 body: gear welded, helmet only on the paid suits.
    local body = Instance.new("Model")
    for name, size in { UpperTorso = Vector3.new(2, 1.6, 1), Head = Vector3.new(1.2, 1.2, 1.2) } do
        local part = Instance.new("Part")
        part.Name, part.Size, part.Anchored = name, size, true
        part.Parent = body
    end
    SkinService.dress(body, Skins.Default)
    assert(body.SuitGear:FindFirstChild("Backpack") and not body.SuitGear:FindFirstChild("Helmet"), "default gear")
    SkinService.dress(body, Skins.List[3])
    assert(#body:GetChildren() == 3 and body.SuitGear:FindFirstChild("Helmet"), "redress replaces the gear")
    assert(body.SuitGear.Backpack:FindFirstChildOfClass("Trail"), "galaxy trail")
    body:Destroy()
    return "Suit checks passed"
end
