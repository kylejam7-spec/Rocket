-- Shared look for every UI component: the loud reference style (chunky rounded
-- font, white text with a heavy dark outline, saturated buttons with a shine).
-- Icons are emoji for now; Phase 5 swaps them for "rbxassetid://" art here.
local Theme = {}

Theme.color = {
    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(225, 225, 240),
    Stroke = Color3.fromRGB(22, 14, 32),
    Shadow = Color3.fromRGB(20, 16, 30),
    Track = Color3.fromRGB(30, 24, 44),
    Panel = Color3.fromRGB(34, 26, 52),
    Gold = Color3.fromRGB(255, 204, 40),
    Strength = Color3.fromRGB(255, 160, 30),
    Speed = Color3.fromRGB(70, 170, 255),
    Launch = Color3.fromRGB(180, 95, 255),
    Build = Color3.fromRGB(255, 185, 35),
    Fuel = Color3.fromRGB(255, 80, 150),
    Ready = Color3.fromRGB(70, 225, 90),
    Go = Color3.fromRGB(70, 210, 70),
    Danger = Color3.fromRGB(255, 75, 70),
    Action = Color3.fromRGB(255, 140, 30),
    Purple = Color3.fromRGB(140, 80, 255),
    Unlocked = Color3.fromRGB(120, 255, 140),
    Locked = Color3.fromRGB(255, 190, 190),
    White = Color3.new(1, 1, 1),
}

Theme.icon = {
    Coin = "💰",
    Strength = "💪",
    Speed = "👟",
    Launch = "🚀",
    Metal = "🔩",
    Fuel = "⛽",
    Drop = "⬇",
    Leave = "✖",
    Star = "⭐",
    Settings = "⚙️",
    Hand = "✋",
    Jump = "⬆",
    Pets = "🐾",
    Ufo = "🛸",
}

-- Mission wheel rarities (Shared.Missions); WheelController and the progress tag.
Theme.rarity = {
    Common = Color3.fromRGB(170, 180, 200),
    Uncommon = Color3.fromRGB(80, 210, 90),
    Rare = Color3.fromRGB(60, 150, 255),
    Epic = Color3.fromRGB(175, 80, 255),
    Legendary = Color3.fromRGB(255, 170, 30),
}

Theme.font = {
    Body = Enum.Font.GothamBold,
    Bold = Enum.Font.GothamBlack,
    Display = Enum.Font.FredokaOne,
}

Theme.panelTransparency = 0.25
Theme.radius = 12
Theme.gutter = 16
-- Layout sizes are authored for a 720 px tall screen; UI.Create.screen scales from there.
Theme.designHeight = 720

-- 171700 -> "171,700"
function Theme.number(value)
    local text = tostring(math.round(value))
    local sign, digits = text:match("^(-?)(%d+)$")
    if not digits then return text end
    return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Compact counts for tight buttons: 9,999 as is, then 12.3K, 4.56M, 7.8B, 1.2T, 527Qa, 5.7Qi.
function Theme.short(value)
    if value < 10000 then return Theme.number(value) end
    for _, unit in { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if value >= unit[1] then
            -- Three significant digits, truncated (5,999,999 reads 5.99M, not 6M).
            local scaled = value / unit[1]
            local decimals = scaled >= 100 and 0 or scaled >= 10 and 1 or 2
            local text = ("%." .. decimals .. "f"):format(math.floor(scaled * 10 ^ decimals) / 10 ^ decimals)
            if decimals > 0 then text = text:gsub("0+$", ""):gsub("%.$", "") end
            return text .. unit[2]
        end
    end
    return Theme.number(value)
end

-- A lighter top edge on any filled GuiObject, so flat colours read as glossy candy.
function Theme.shine(gui)
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 175, 175)),
    })
    gradient.Parent = gui
    return gradient
end

function Theme.lighten(color, amount)
    return color:Lerp(Color3.new(1, 1, 1), amount or 0.3)
end

return Theme
