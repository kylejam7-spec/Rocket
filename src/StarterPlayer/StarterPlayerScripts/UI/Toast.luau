-- Short-lived message cards in a stack: each pops in, holds, then fades; the oldest
-- goes when the stack is full, and a repeat of the newest message just re-bounces it.
-- Toast.stack(props) makes the stack (a Frame; Capitalized props apply, `max` caps
-- the count); stack:push(text, color?, seconds?) adds a card at the bottom.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Toast = {}
Toast.__index = Toast

function Toast.stack(props)
    local frame = Create.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 200) }, props)
    Create.new("UIListLayout", {
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Parent = frame,
    })
    return setmetatable({ instance = frame, max = props.max or 3, cards = {}, order = 0 }, Toast)
end

local function fade(card, seconds)
    local info = Tween.info(seconds)
    Tween.play(card, info, { BackgroundTransparency = 1 })
    for _, item in card:GetDescendants() do
        if item:IsA("TextLabel") then Tween.play(item, info, { TextTransparency = 1 }) end
        if item:IsA("UIStroke") then Tween.play(item, info, { Transparency = 1 }) end
    end
end

function Toast:push(text, color, seconds)
    local newest = self.cards[#self.cards]
    if newest and newest.text == text then
        newest.expires = os.clock() + (seconds or 3)
        Tween.bounce(newest.card, 1.1, 0.25)
        return newest.card
    end
    self.order += 1
    local card = Create.new("Frame", {
        Name = "Toast", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 36),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.15, LayoutOrder = self.order,
        Parent = self.instance,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = card })
    Create.new("UIStroke", { Thickness = 2.5, Color = color or Theme.color.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
    Create.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = card })
    Create.new("UISizeConstraint", { MaxSize = Vector2.new(520, 120), Parent = card })
    StrokedText.new({
        Name = "Text", Text = text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36),
        Font = Theme.font.Display, TextSize = 22, TextWrapped = false, stroke = 2, Parent = card,
    })
    Tween.bounce(card, 1.15, 0.3)
    local entry = { card = card, text = text, expires = os.clock() + (seconds or 3) }
    table.insert(self.cards, entry)
    if #self.cards > self.max then table.remove(self.cards, 1).card:Destroy() end
    task.spawn(function()
        while os.clock() < entry.expires do task.wait(entry.expires - os.clock()) end
        local index = table.find(self.cards, entry)
        if not index then return end
        table.remove(self.cards, index)
        fade(card, 0.3)
        task.delay(0.3, card.Destroy, card)
    end)
    return card
end

return Toast
