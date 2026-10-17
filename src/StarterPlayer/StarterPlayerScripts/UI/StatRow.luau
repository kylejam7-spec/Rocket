-- One entry of the reference's left stat stack: a dark rounded card edged in the
-- stat's colour, the icon in a coloured disc over its left end, a big outlined
-- number and a small sub-label ("Walk Speed: 32").
-- Options: icon (asset id "rbxassetid://…" or a glyph), value, sub, badge, color
-- (the stat's colour: card edge, disc, badge, bar and "+N" pops), progress (true: a
-- level bar under the sub-label).
-- row:set(value, sub?) counts the number up, bounces the icon and pops "+N" past the
-- card's right edge when it grows; row:setBadge(text?) shows or hides the "LV 10"
-- chip under the disc; row:setProgress(fraction, text) fills the bar and labels it.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Popup = require(script.Parent.Popup)
local StatRow = {}
StatRow.__index = StatRow

local WIDTH, DISC, CARD_X = 250, 60, 30

function StatRow.new(props)
    local color = props.color or Theme.color.Gold
    local height = props.progress and 82 or 64
    local row = Create.new("Frame", { Size = UDim2.fromOffset(WIDTH, height), BackgroundTransparency = 1 }, props)
    -- The card starts under the disc's middle so the disc overlaps its rounded end.
    local card = Create.new("Frame", {
        Name = "Card", Position = UDim2.fromOffset(CARD_X, 4), Size = UDim2.fromOffset(WIDTH - CARD_X, height - 8),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.18, Parent = row,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = card })
    Create.new("UIStroke", { Thickness = 2.5, Color = color, Transparency = 0.15, Parent = card })
    Create.new("UIGradient", {
        Rotation = 90, Parent = card,
        Color = ColorSequence.new(Theme.lighten(Theme.color.Panel, 0.12), Theme.color.Panel),
    })
    local disc = Create.new("Frame", {
        Name = "Disc", Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(DISC, DISC),
        BackgroundColor3 = color, ZIndex = 2, Parent = row,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = disc })
    Create.new("UIStroke", { Thickness = 3, Color = Theme.color.Stroke, Parent = disc })
    Theme.shine(disc)
    local iconProps = {
        Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 3, Parent = disc,
    }
    local icon = props.icon or ""
    if icon:match("^rbx") then
        iconProps.Image = icon
        icon = Create.new("ImageLabel", iconProps)
    else
        icon = StrokedText.new(Create.merge(iconProps, { Text = icon, Font = Theme.font.Display, TextSize = 38, stroke = 2 }))
    end
    local value = StrokedText.new({
        Name = "Value", Size = UDim2.new(1, -DISC - 14, 0, 38), Position = UDim2.fromOffset(DISC + 10, 4),
        Font = Theme.font.Display, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3, ZIndex = 2, Parent = row,
    })
    local sub = StrokedText.new({
        Name = "Sub", Size = UDim2.new(1, -DISC - 14, 0, 18), Position = UDim2.fromOffset(DISC + 11, 39),
        Font = Theme.font.Display, TextSize = 17, TextColor3 = Theme.color.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.5, ZIndex = 2, Parent = row,
    })
    -- "LV 10" chip in the stat's colour, hanging off the bottom of the disc.
    local badge = Create.new("Frame", {
        Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(DISC / 2, DISC - 6),
        Size = UDim2.fromOffset(54, 20), BackgroundColor3 = Theme.lighten(color, 0.1), Visible = false, ZIndex = 4, Parent = row,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = badge })
    Create.new("UIStroke", { Thickness = 2, Color = Theme.color.Stroke, Parent = badge })
    local badgeText = StrokedText.new({
        Name = "Text", Size = UDim2.fromScale(1, 1), Font = Theme.font.Display, TextSize = 15, stroke = 1.5, ZIndex = 5, Parent = badge,
    })
    local fill, barText
    if props.progress then
        local bar = Create.new("Frame", {
            Name = "LevelBar", Position = UDim2.fromOffset(DISC + 10, 60), Size = UDim2.new(1, -DISC - 22, 0, 14),
            BackgroundColor3 = Theme.color.Track, ZIndex = 2, Parent = row,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = bar })
        Create.new("UIStroke", { Color = Theme.color.Stroke, Thickness = 2, Parent = bar })
        fill = Create.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, ZIndex = 2, Parent = bar })
        Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = fill })
        Theme.shine(fill)
        barText = StrokedText.new({
            Name = "LevelText", Size = UDim2.fromScale(1, 1), Font = Theme.font.Display, TextSize = 12,
            stroke = 1.5, ZIndex = 3, Parent = bar,
        })
    end
    local self = setmetatable({ instance = row, icon = icon, disc = disc, value = value, sub = sub, badge = badge,
        badgeText = badgeText, fill = fill, barText = barText, color = color, current = props.value or 0 }, StatRow)
    value.Text = Theme.number(self.current)
    sub.Text = props.sub or ""
    self:setBadge(props.badge)
    return self
end

function StatRow:set(amount, sub)
    if amount ~= self.current then
        local gain = amount - self.current
        if gain > 0 then
            Tween.bounce(self.disc, 1.2, 0.35)
            Popup.show({
                Text = "+" .. Theme.number(gain), TextColor3 = self.color, TextSize = 28,
                Position = UDim2.fromOffset(WIDTH + 44, 22),
                Size = UDim2.fromOffset(90, 30), rise = 26, seconds = 0.7, Parent = self.instance,
            })
        end
        Tween.countUp(self.value, self.current, amount, 0.4, Theme.number)
        self.current = amount
    end
    if sub and sub ~= self.sub.Text then
        self.sub.Text = sub
    end
end

function StatRow:setProgress(fraction, text)
    if not self.fill then return end
    local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
    -- A level-up wraps to an emptier bar: snap instead of sliding backwards.
    if size.X.Scale < self.fill.Size.X.Scale then self.fill.Size = size else Tween.play(self.fill, Tween.info(0.25), { Size = size }) end
    self.barText.Text = text
end

function StatRow:setBadge(text)
    self.badge.Visible = text ~= nil
    if text then self.badgeText.Text = text end
end

return StatRow
