-- Chunky candy button: saturated fill with a shine, thick dark outline, stroked
-- label, grows on hover and bounces on press.
-- Options: onActivated, color, shape ("pill" default, or "circle"), icon (big
-- glyph for circle buttons), caption (small stroked label under a circle),
-- radius (px), stroke (outline thickness), sound (the Sfx cue on press, "click"
-- by default; false for none, when the handler plays its own).
local UserInputService = game:GetService("UserInputService")
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Sfx = require(script.Parent.Sfx)
local Button = {}

function Button.new(props)
    local color = props.color or Theme.color.Action
    local circle = props.shape == "circle"
    local button = Create.new("TextButton", {
        Font = Theme.font.Display,
        TextSize = 24,
        TextColor3 = Theme.color.White,
        BackgroundColor3 = color,
        AutoButtonColor = false,
        Size = circle and UDim2.fromOffset(64, 64) or UDim2.fromOffset(180, 52),
    }, props)
    Theme.shine(button)
    Create.new("UICorner", {
        CornerRadius = circle and UDim.new(1, 0) or UDim.new(0, props.radius or Theme.radius),
        Parent = button,
    })
    Create.new("UIStroke", {
        Thickness = props.stroke or 3,
        Color = Theme.color.Stroke,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = button,
    })
    -- Button text gets its own outline via a stroked overlay (one UIStroke per
    -- object); change it later through button.Label.Text.
    local text = button.Text
    button.Text = ""
    local label = StrokedText.new({
        Name = "Label",
        Size = UDim2.fromScale(1, 1),
        Text = props.icon or text,
        Font = Theme.font.Display,
        TextSize = props.icon and 34 or button.TextSize,
        TextColor3 = button.TextColor3,
        stroke = 2.5,
        Parent = button,
    })
    if circle and props.caption then
        StrokedText.new({
            Name = "Caption",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 1, 2),
            Size = UDim2.fromOffset(120, 18),
            Text = props.caption,
            Font = Theme.font.Display,
            TextSize = 16,
            stroke = 2,
            Parent = button,
        })
    end
    local scale = Create.new("UIScale", { Name = "HoverScale", Parent = button })
    button.MouseEnter:Connect(function()
        Tween.play(scale, 0.12, { Scale = 1.08 })
        -- Taps fire MouseEnter too; only a real pointer hovers.
        if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then Sfx.play("hover") end
    end)
    button.MouseLeave:Connect(function() Tween.play(scale, 0.12, { Scale = 1 }) end)
    button.Activated:Connect(function(...)
        Tween.bounce(label, 1.3, 0.3)
        if props.sound ~= false then Sfx.play(props.sound or "click") end
        if props.onActivated then props.onActivated(...) end
    end)
    return button
end

return Button
