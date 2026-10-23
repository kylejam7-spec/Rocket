--[[
    Suits: everyone wears the same basic astronaut suit instead of their own avatar
    (SkinService builds the character from Skins.description and dresses it). Three suits
    sell as Game Passes (Config.Shop.passes: SuitGold, SuitCommander, SuitGalaxy); a
    player wears the best one they own and gets its boost, which multiplies their gym
    training, their delivery coins and the launches each ride counts for (ranks, gym
    unlocks, the launches leaderboard). Suits don't stack with each other; the boost
    multiplies with the other boosts (2x Coins, the server training boost, friends).
    Colours: suit (torso, arms, legs), trim (collar, badge, helmet ring), pack (backpack),
    visor (the glass helmet, if any). `glow` makes the trim Neon and lights the badge;
    `trail` and `sparkles` are the Galaxy Suit's extras.
]]
local Skins = {}

Skins.Default = table.freeze({
    key = "Astronaut", name = "Astronaut", multiplier = 1,
    suit = Color3.fromRGB(236, 238, 242), trim = Color3.fromRGB(150, 154, 164), pack = Color3.fromRGB(176, 180, 190),
})
-- Cheapest first; the last one owned wins.
Skins.List = table.freeze({
    table.freeze({ key = "SuitGold", name = "Gold Astronaut", icon = "🥇", multiplier = 2,
        suit = Color3.fromRGB(240, 186, 40), trim = Color3.fromRGB(120, 76, 20), pack = Color3.fromRGB(200, 150, 40),
        visor = Color3.fromRGB(255, 220, 120), helmet = true }),
    table.freeze({ key = "SuitCommander", name = "Commander Astronaut", icon = "🎖", multiplier = 4,
        suit = Color3.fromRGB(34, 52, 112), trim = Color3.fromRGB(230, 50, 50), pack = Color3.fromRGB(60, 70, 96),
        visor = Color3.fromRGB(255, 120, 60), helmet = true, glow = true }),
    table.freeze({ key = "SuitGalaxy", name = "Galaxy Astronaut", icon = "🌌", multiplier = 8,
        suit = Color3.fromRGB(58, 24, 110), trim = Color3.fromRGB(60, 240, 255), pack = Color3.fromRGB(30, 14, 60),
        visor = Color3.fromRGB(120, 200, 255), helmet = true, glow = true, trail = true, sparkles = true }),
})
-- The skin tone under every suit (the head; gloves are the suit colour).
Skins.Skin = Color3.fromRGB(234, 184, 146)

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

-- One line for the shop card.
function Skins.blurb(skin)
    return skin.multiplier .. "x training, coins & launches"
end

-- The HumanoidDescription every character is built from: no accessories, clothing or
-- animations of their own, the suit's colours on the body.
function Skins.description(skin)
    local description = Instance.new("HumanoidDescription")
    description.HeadColor = Skins.Skin
    description.TorsoColor = skin.suit
    description.LeftArmColor, description.RightArmColor = skin.suit, skin.suit
    description.LeftLegColor, description.RightLegColor = skin.suit, skin.suit
    return description
end

return Skins
