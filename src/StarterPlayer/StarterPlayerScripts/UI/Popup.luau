-- Short-lived floating text: "+1" training ticks, coin pops, "Level Up!".
-- It pops in, rises and fades, then destroys itself. Options: rise (px),
-- seconds, plus any StrokedText option or TextLabel property (Parent, Position…).
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Popup = {}

function Popup.show(props)
    local label = StrokedText.new(Create.merge({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(240, 48),
        Font = Theme.font.Display,
        TextSize = 30,
        TextColor3 = Theme.color.White,
        stroke = 2.5,
    }, props))
    local seconds, rise = props.seconds or 0.9, props.rise or 48
    Tween.bounce(label, 1.4, 0.25)
    local fade = Tween.info(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Tween.play(label, Tween.info(seconds), { Position = label.Position - UDim2.fromOffset(0, rise) })
    Tween.play(label, fade, { TextTransparency = 1 })
    local stroke = label:FindFirstChildOfClass("UIStroke")
    if stroke then Tween.play(stroke, fade, { Transparency = 1 }) end
    task.delay(seconds, label.Destroy, label)
    return label
end

return Popup
