-- The reference's bottom progress pill: a dark rounded track with a gold rim, a
-- glossy fill and a big stroked "9 / 171,700" label on top.
-- Options: fillColor, rimColor, rim (thickness, 0 for none), label (true to add
-- text), textSize, animate (tween fill changes).
-- pill:set(progress, color?, text?) updates it; call it as often as you like.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Pill = {}
Pill.__index = Pill

function Pill.new(props)
    local track = Create.new("Frame", { BackgroundColor3 = Theme.color.Track, BackgroundTransparency = 0.15 }, props)
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    if (props.rim or 3) > 0 then
        Create.new("UIStroke", {
            Thickness = props.rim or 3,
            Color = props.rimColor or Theme.color.Gold,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = track,
        })
    end
    -- The fill sits in an inset clip so its rounded ends never poke past the rim.
    local inset = Create.new("Frame", {
        Name = "Inset", BackgroundTransparency = 1, ClipsDescendants = true,
        Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), Parent = track,
    })
    local fill = Create.new("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = props.fillColor or Theme.color.Build,
        Parent = inset,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    Theme.shine(fill)
    local label = props.label and StrokedText.new({
        Name = "Label",
        Size = UDim2.fromScale(1, 1),
        Font = Theme.font.Display,
        TextSize = props.textSize or 30,
        TextColor3 = Theme.color.White,
        stroke = 3,
        ZIndex = 2,
        Parent = track,
    })
    return setmetatable({ instance = track, fill = fill, label = label, animate = props.animate, target = -1 }, Pill)
end

function Pill:set(progress, color, text)
    local alpha = math.clamp(progress, 0, 1)
    if alpha ~= self.target then
        local grew = self.target >= 0 and alpha > self.target
        self.target = alpha
        local size = UDim2.fromScale(alpha, 1)
        -- A zero-width rounded frame still draws a sliver of its corners.
        self.fill.Visible = alpha > 0
        if self.animate and grew then Tween.play(self.fill, 0.3, { Size = size }) else self.fill.Size = size end
        if grew and self.label then Tween.bounce(self.label, 1.15, 0.3) end
    end
    if color then self.fill.BackgroundColor3 = color end
    if text and self.label then self.label.Text = text end
end

return Pill
