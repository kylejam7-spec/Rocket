--[[
    Suits: everyone wears the same basic astronaut suit instead of their own avatar,
    keeping only their own head (SkinService builds the character from Skins.description
    and dresses it). Three suits sell as Game Passes (Config.Shop.passes: SuitGold,
    SuitCommander, SuitGalaxy). A player gets the boost of the best one they own, which
    multiplies their gym training, their delivery coins and the launches each ride counts
    for (ranks, gym unlocks, the launches leaderboard); they wear that one unless they
    pick another they own (or the basic one) in the SHOP. Suits don't stack with each
    other; the boost multiplies with the other boosts (2x Coins, the server training
    boost, friends).

    The armour is ReplicatedStorage.SuitModels (tools/suits): one MeshPart per piece,
    shared by every suit. A suit lists the pieces it wears and how each Role draws:
      suit    the undersuit (the body colours) and the shop card's backdrop
      roles   Base (main plates), Trim (rims, straps, tanks), Dark (gloves, belt, soles),
              Glow (screens, lamps, gems, strips: Neon), Glass (the helmet bubble)
      galaxy  the undersuit and Base plates wear the scrolling star field (GalaxyTexture)
      fx      SkinService's particles: "thrusters" (backpack flames), "glints" (gold
              sparkle), "energy" (blue motes), "stars" (star dust and nebula wisps),
              "trail"; SuitFxController animates "halo" spin, "pulse" glows and the stars.
]]
local Skins = {}

-- The Galaxy Astronaut's star field (assets/models-textures/Suits/Galaxy.png), uploaded
-- as an Image; nil leaves the galaxy suit in its flat colours.
Skins.GalaxyTexture = "rbxassetid://75317861591571"

local function look(color, material, extra)
    local entry = { color = color, material = material or Enum.Material.SmoothPlastic }
    for key, value in extra or {} do entry[key] = value end
    return table.freeze(entry)
end
local rgb = Color3.fromRGB
local METAL, NEON, GLASS, PLASTIC = Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Glass, Enum.Material.SmoothPlastic

-- Pieces every suit wears, then the armour the paid ones add.
local BASIC = { "HelmetGlass", "HelmetFrame", "HelmetPods", "HelmetLamps", "Antenna", "AntennaTip", "Collar", "ChestConsole",
    "ChestScreen", "NamePlate", "Backpack", "BackpackTanks", "BackpackLights", "Belt", "Buckle", "Pouches", "Glove",
    "Knuckles", "ElbowPad", "KneePad", "Boot", "BootSole", "BootToe", "AnkleRing", "PatchRim", "PatchFace", "PatchStar" }
local ARMOUR = { "ChestPlate", "ChestVents", "Thrusters", "ThrusterGlow", "ShoulderPad", "ShoulderRim", "Bracer", "BracerTrim",
    "BracerLight", "ThighPlate", "ShinGuard" }
local function pieces(...)
    local list = table.clone(BASIC)
    for _, extra in { ... } do
        for _, name in extra do table.insert(list, name) end
    end
    return table.freeze(list)
end

Skins.Default = table.freeze({
    key = "Astronaut", name = "Basic Astronaut", multiplier = 1,
    suit = rgb(236, 238, 242),
    roles = table.freeze({
        Base = look(rgb(236, 238, 242)), Trim = look(rgb(240, 120, 30)), Dark = look(rgb(90, 94, 104)),
        Glow = look(rgb(255, 170, 60), NEON), Glass = look(rgb(200, 210, 225), GLASS, { transparency = 0.7 }),
    }),
    pieces = pieces({ "ChestStraps", "ArmBand", "Flag", "FlagStripes", "ThighPocket", "PocketFlap" }),
    fx = table.freeze({}),
})
-- Cheapest first; the last one owned wins.
Skins.List = table.freeze({
    table.freeze({ key = "SuitGold", name = "Gold Astronaut", icon = "🥇", multiplier = 2,
        suit = rgb(34, 30, 28),
        roles = table.freeze({
            Base = look(rgb(232, 162, 18), PLASTIC, { reflectance = 0.06 }), Trim = look(rgb(36, 32, 30), METAL),
            Dark = look(rgb(28, 24, 22)), Glow = look(rgb(255, 160, 40), NEON),
            Glass = look(rgb(255, 196, 80), GLASS, { transparency = 0.55 }),
        }),
        pieces = pieces(ARMOUR),
        fx = table.freeze({ thrusters = rgb(255, 170, 60), glints = true }) }),
    table.freeze({ key = "SuitCommander", name = "Commander Astronaut", icon = "🎖", multiplier = 4,
        suit = rgb(26, 34, 80),
        roles = table.freeze({
            Base = look(rgb(238, 240, 246), PLASTIC, { reflectance = 0.05 }), Trim = look(rgb(226, 176, 40), METAL, { reflectance = 0.15 }),
            Dark = look(rgb(26, 34, 80)), Glow = look(rgb(60, 140, 255), NEON),
            Glass = look(rgb(110, 150, 255), GLASS, { transparency = 0.62 }),
        }),
        pieces = pieces(ARMOUR, { "KneeGem", "Emblem", "ArmStrip", "LegStrip" }),
        fx = table.freeze({ thrusters = rgb(80, 160, 255), energy = rgb(90, 170, 255), pulse = true, trail = true }) }),
    table.freeze({ key = "SuitGalaxy", name = "Galaxy Astronaut", icon = "🌌", multiplier = 8,
        suit = rgb(30, 14, 66), galaxy = true,
        roles = table.freeze({
            Base = look(rgb(70, 34, 150), PLASTIC, { reflectance = 0.1 }), Trim = look(rgb(190, 120, 255), METAL, { reflectance = 0.2 }),
            Dark = look(rgb(18, 10, 40)), Glow = look(rgb(80, 220, 255), NEON),
            Glass = look(rgb(150, 80, 255), GLASS, { transparency = 0.5 }),
        }),
        pieces = pieces(ARMOUR, { "KneeGem", "ArmStrip", "LegStrip", "ShinStrip", "Halo" }),
        fx = table.freeze({ thrusters = rgb(150, 110, 255), stars = true, pulse = true, halo = true, trail = true }) }),
})
-- The skin tone for a head when the player's own avatar can't be read.
Skins.Skin = rgb(234, 184, 146)

function Skins.get(key)
    for _, skin in Skins.List do
        if skin.key == key then return skin end
    end
    return key == Skins.Default.key and Skins.Default or nil
end

-- The suit a player wears: the best one `owns(key)` says they have, else the default.
function Skins.best(owns)
    local best = Skins.Default
    for _, skin in Skins.List do
        if owns(skin.key) then best = skin end
    end
    return best
end

-- Whether `skin` wears the piece called `name` (pieces with sides are `<Name>_<Side>`).
function Skins.wears(skin, name)
    local base = name:match("^(%a+)_%a+$") or name
    return table.find(skin.pieces, base) ~= nil
end

-- The shop card's accent: the suit's trim.
function Skins.accent(skin)
    return skin.roles.Trim.color
end

-- One line for the shop card.
function Skins.blurb(skin)
    return skin.multiplier .. "x training, coins & launches"
end

-- The HumanoidDescription every character is built from: the suit's colours on the
-- body, no clothing, accessories or animations of their own, but their own head from
-- `avatar` (their HumanoidDescription, if it could be read): head shape, face, skin tone
-- and hair (rigid or layered).
function Skins.description(skin, avatar)
    local description = Instance.new("HumanoidDescription")
    description.HeadColor = Skins.Skin
    if avatar then
        description.Head, description.Face, description.HeadColor = avatar.Head, avatar.Face, avatar.HeadColor
        local hair = {}
        for _, accessory in avatar:GetAccessories(true) do
            if accessory.AccessoryType == Enum.AccessoryType.Hair then table.insert(hair, accessory) end
        end
        description:SetAccessories(hair, true)
    end
    description.TorsoColor = skin.suit
    description.LeftArmColor, description.RightArmColor = skin.suit, skin.suit
    description.LeftLegColor, description.RightLegColor = skin.suit, skin.suit
    return description
end

return Skins
