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
    Coin = "🪙",
    Strength = "💪",
    Speed = "⚡",
    Launch = "🚀",
    Metal = "🔩",
    Fuel = "⛽",
    Drop = "⬇",
    Leave = "✖",
    Star = "⭐",
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
