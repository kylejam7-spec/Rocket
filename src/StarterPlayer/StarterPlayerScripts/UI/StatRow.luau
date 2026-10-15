-- One entry of the reference's left stat stack: a big icon, a big number, an
-- "x1" multiplier badge and a small sub-label ("Walk Speed: 32").
-- Options: icon (asset id "rbxassetid://…" or a short glyph), value, sub, badge,
-- color (number colour). row:set(value, sub?) counts the number up and bounces
-- the icon when it grows; row:setBadge(text?) shows or hides the badge.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local StatRow = {}
StatRow.__index = StatRow

function StatRow.new(props)
    local row = Create.new("Frame", { Size = UDim2.fromOffset(240, 64), BackgroundTransparency = 1 }, props)
    local iconProps = { Name = "Icon", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(0, 4), BackgroundTransparency = 1, Parent = row }
    local icon = props.icon or ""
    if icon:match("^rbx") then
        iconProps.Image = icon
        icon = Create.new("ImageLabel", iconProps)
    else
        icon = StrokedText.new(Create.merge(iconProps, { Text = icon, Font = Theme.font.Display, TextSize = 40, TextColor3 = Theme.color.White, stroke = 2.5 }))
    end
    local value = StrokedText.new({
        Name = "Value", Size = UDim2.new(1, -66, 0, 38), Position = UDim2.fromOffset(64, 0),
        Font = Theme.font.Display, TextSize = 34, TextColor3 = props.color or Theme.color.White,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 2.5, Parent = row,
    })
    local sub = StrokedText.new({
        Name = "Sub", Size = UDim2.new(1, -66, 0, 20), Position = UDim2.fromOffset(64, 40),
        Font = Theme.font.Bold, TextSize = 14, TextColor3 = Theme.color.White,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.5, Parent = row,
    })
    local badge = Create.new("TextLabel", {
        Name = "Badge", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(34, 20),
        AutomaticSize = Enum.AutomaticSize.X, Font = Theme.font.Display, TextSize = 14,
        TextColor3 = Theme.color.White, BackgroundColor3 = Theme.color.Ready, Visible = false, Parent = row,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = badge })
    Create.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = badge })
    local self = setmetatable({ instance = row, icon = icon, value = value, sub = sub, badge = badge, current = props.value or 0 }, StatRow)
    -- The badge sits just right of the number's rendered width as it counts.
    value:GetPropertyChangedSignal("TextBounds"):Connect(function()
        badge.Position = UDim2.fromOffset(70 + value.TextBounds.X, 19)
    end)
    value.Text = Theme.number(self.current)
    sub.Text = props.sub or ""
    self:setBadge(props.badge)
    return self
end

function StatRow:set(amount, sub)
    if amount ~= self.current then
        if amount > self.current then Tween.bounce(self.icon, 1.25, 0.35) end
        Tween.countUp(self.value, self.current, amount, 0.4, Theme.number)
        self.current = amount
    end
    if sub then self.sub.Text = sub end
end

function StatRow:setBadge(text)
    self.badge.Visible = text ~= nil
    if text then self.badge.Text = text end
end

return StatRow
