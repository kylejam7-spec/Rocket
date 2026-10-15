-- Shared look for every UI component. The Panel/Text/Track values reproduce the
-- current HUD; Display, Stroke and the button colours are the loud reference style
-- Phase 2 builds on.
local Theme = {}

Theme.color = {
    Panel = Color3.fromRGB(20, 29, 43),
    Text = Color3.fromRGB(234, 241, 250),
    Muted = Color3.fromRGB(170, 185, 205),
    Subtle = Color3.fromRGB(190, 200, 215),
    Track = Color3.fromRGB(45, 55, 72),
    Build = Color3.fromRGB(150, 190, 225),
    Fuel = Color3.fromRGB(255, 165, 55),
    Ready = Color3.fromRGB(95, 220, 150),
    Gold = Color3.fromRGB(255, 220, 110),
    Danger = Color3.fromRGB(255, 120, 90),
    Unlocked = Color3.fromRGB(150, 255, 170),
    Locked = Color3.fromRGB(255, 200, 200),
    Action = Color3.fromRGB(235, 160, 65),
    Secondary = Color3.fromRGB(80, 110, 140),
    Stroke = Color3.fromRGB(28, 22, 34),
    White = Color3.new(1, 1, 1),
}

Theme.font = {
    Body = Enum.Font.GothamMedium,
    Bold = Enum.Font.GothamBold,
    Display = Enum.Font.FredokaOne,
}

Theme.panelTransparency = 0.08
Theme.radius = 12
Theme.gutter = 16

-- 171700 -> "171,700"
function Theme.number(value)
    local text = tostring(math.round(value))
    local sign, digits = text:match("^(-?)(%d+)$")
    if not digits then return text end
    return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

return Theme
