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
    -- Every piece a suit lists exists in SuitModels, with a body part, role and offset.
    local models = ReplicatedStorage:FindFirstChild("SuitModels")
    assert(models, "ReplicatedStorage.SuitModels is missing (tools/suits)")
    local bases = {}
    for _, template in models:GetChildren() do
        assert(template:IsA("MeshPart") and template:GetAttribute("BodyPart") and typeof(template:GetAttribute("Offset")) == "CFrame", template.Name)
        assert(Skins.Default.roles[template:GetAttribute("Role")], template.Name .. " has no role")
        bases[template.Name:match("^(%a+)_%a+$") or template.Name] = true
    end
    for _, skin in { Skins.Default, table.unpack(Skins.List) } do
        for _, name in skin.pieces do assert(bases[name], skin.key .. " wears missing piece " .. name) end
    end
    -- Dressing a stand-in R15 body: the pieces welded on, coloured by role, paid armour
    -- only on paid suits, and a re-dress replacing the old gear.
    local body = Instance.new("Model")
    for _, name in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand",
        "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" } do
        local part = Instance.new("Part")
        part.Name, part.Anchored = name, true
        part.Parent = body
    end
    SkinService.dress(body, Skins.Default)
    local gear = body.SuitGear
    assert(gear:FindFirstChild("Backpack") and gear:FindFirstChild("HelmetGlass") and not gear:FindFirstChild("ShoulderPad_Left"), "basic gear")
    assert(gear.Backpack.SuitWeld.Part0 == body.UpperTorso and gear.Backpack.Color == Skins.Default.roles.Base.color, "welded, coloured")
    SkinService.dress(body, Skins.List[3])
    assert(#body:GetChildren() == 16, "redress replaces the gear")
    gear = body.SuitGear
    assert(gear:FindFirstChild("Halo") and gear:FindFirstChild("ShoulderPad_Left") and gear.HelmetLamps.Material == Enum.Material.Neon, "galaxy gear")
    assert(gear.ThrusterGlow:FindFirstChild("Flame") and gear.Backpack:FindFirstChildOfClass("Trail"), "galaxy effects")
    body:Destroy()
    return "Suit checks passed"
end
