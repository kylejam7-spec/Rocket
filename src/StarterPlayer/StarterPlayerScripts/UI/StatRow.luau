-- One entry of the reference's left stat stack: a big icon with an "x1" badge
-- under it, a big outlined number and a small sub-label ("Walk Speed: 32").
-- Options: icon (asset id "rbxassetid://…" or a glyph), value, sub, badge, color
-- (colour of "+N" pops). row:set(value, sub?) counts the number up, bounces the
-- icon and pops "+N" when it grows; row:setBadge(text?) shows or hides the badge.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Popup = require(script.Parent.Popup)
local StatRow = {}
StatRow.__index = StatRow

function StatRow.new(props)
    local row = Create.new("Frame", { Size = UDim2.fromOffset(260, 66), BackgroundTransparency = 1 }, props)
    local iconProps = { Name = "Icon", Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Parent = row }
    local icon = props.icon or ""
    if icon:match("^rbx") then
        iconProps.Image = icon
        icon = Create.new("ImageLabel", iconProps)
    else
        icon = StrokedText.new(Create.merge(iconProps, { Text = icon, Font = Theme.font.Display, TextSize = 48, stroke = 2 }))
    end
    local value = StrokedText.new({
        Name = "Value", Size = UDim2.new(1, -66, 0, 44), Position = UDim2.fromOffset(66, -2),
        Font = Theme.font.Display, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3, Parent = row,
    })
    local sub = StrokedText.new({
        Name = "Sub", Size = UDim2.new(1, -66, 0, 18), Position = UDim2.fromOffset(68, 42),
        Font = Theme.font.Display, TextSize = 14, TextColor3 = Theme.color.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.5, Parent = row,
    })
    local badge = StrokedText.new({
        Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(14, 48),
        Size = UDim2.fromOffset(24, 14), Font = Theme.font.Display, TextSize = 13, stroke = 1.5,
        Visible = false, ZIndex = 2, Parent = row,
    })
    local self = setmetatable({ instance = row, icon = icon, value = value, sub = sub, badge = badge,
        color = props.color or Theme.color.Gold, current = props.value or 0 }, StatRow)
    value.Text = Theme.number(self.current)
    sub.Text = props.sub or ""
    self:setBadge(props.badge)
    return self
end

function StatRow:set(amount, sub)
    if amount ~= self.current then
        local gain = amount - self.current
        if gain > 0 then
            Tween.bounce(self.icon, 1.35, 0.35)
            Popup.show({
                Text = "+" .. Theme.number(gain), TextColor3 = self.color, TextSize = 26,
                Position = UDim2.fromOffset(66 + self.value.TextBounds.X + 36, 20),
                Size = UDim2.fromOffset(80, 30), rise = 26, seconds = 0.7, Parent = self.instance,
            })
        end
        Tween.countUp(self.value, self.current, amount, 0.4, Theme.number)
        self.current = amount
    end
    if sub and sub ~= self.sub.Text then
        self.sub.Text = sub
    end
end

function StatRow:setBadge(text)
    self.badge.Visible = text ~= nil
    if text then self.badge.Text = text end
end

return StatRow
