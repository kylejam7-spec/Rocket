-- Rounded progress track with a fill and an optional centred label (the
-- reference's bottom "9 / 171,700" pill). Options: radius (UDim), fillColor,
-- label (true to add text), textSize, stroke, animate (tween fill changes).
-- pill:set(progress, color?, text?) updates it; call it as often as you like.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Pill = {}
Pill.__index = Pill

function Pill.new(props)
    local track = Create.new("Frame", { BackgroundColor3 = Theme.color.Track }, props)
    local radius = props.radius or UDim.new(0.5, 0)
    Create.new("UICorner", { CornerRadius = radius, Parent = track })
    local fill = Create.new("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = props.fillColor or Theme.color.Build,
        Parent = track,
    })
    Create.new("UICorner", { CornerRadius = radius, Parent = fill })
    local label = props.label and StrokedText.new({
        Name = "Label",
        Size = UDim2.fromScale(1, 1),
        Font = Theme.font.Display,
        TextSize = props.textSize or 18,
        TextColor3 = Theme.color.White,
        stroke = props.stroke or 2,
        ZIndex = fill.ZIndex + 1,
        Parent = track,
    })
    return setmetatable({ instance = track, fill = fill, label = label, animate = props.animate, target = 0 }, Pill)
end

function Pill:set(progress, color, text)
    local alpha = math.clamp(progress, 0, 1)
    if alpha ~= self.target then
        self.target = alpha
        local size = UDim2.fromScale(alpha, 1)
        if self.animate then Tween.play(self.fill, 0.25, { Size = size }) else self.fill.Size = size end
    end
    if color then self.fill.BackgroundColor3 = color end
    if text and self.label then self.label.Text = text end
end

return Pill
