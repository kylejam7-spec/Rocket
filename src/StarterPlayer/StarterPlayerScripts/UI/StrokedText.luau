-- TextLabel with an optional UIStroke outline: the reference's heavy white text
-- with a dark edge. Options: stroke (thickness; omit for no outline), strokeColor.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = {}

function StrokedText.new(props)
    local label = Create.new("TextLabel", {
        BackgroundTransparency = 1,
        Font = Theme.font.Bold,
        TextColor3 = Theme.color.Text,
        TextSize = 14,
    }, props)
    if props.stroke then
        Create.new("UIStroke", {
            Thickness = props.stroke,
            Color = props.strokeColor or Theme.color.Stroke,
            LineJoinMode = Enum.LineJoinMode.Round,
            Parent = label,
        })
    end
    return label
end

return StrokedText
