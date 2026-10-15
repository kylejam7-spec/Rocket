-- TextButton with the reference's chunky style and a press bounce.
-- Options: onActivated, themed (default true; false keeps Roblox's plain button
-- look), bounce (defaults to themed), radius (px), stroke (border thickness).
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Tween = require(script.Parent.Tween)
local Button = {}

function Button.new(props)
    local themed = props.themed ~= false
    local button = Create.new("TextButton", themed and {
        Font = Theme.font.Display,
        TextSize = 22,
        TextColor3 = Theme.color.White,
        BackgroundColor3 = Theme.color.Action,
    } or nil, props)
    if props.radius or themed then
        Create.new("UICorner", { CornerRadius = UDim.new(0, props.radius or Theme.radius), Parent = button })
    end
    if props.stroke or themed then
        Create.new("UIStroke", {
            Thickness = props.stroke or 3,
            Color = Theme.color.Stroke,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = button,
        })
    end
    local bounce = if props.bounce == nil then themed else props.bounce
    button.Activated:Connect(function(...)
        if bounce then Tween.bounce(button, 1.12, 0.3) end
        if props.onActivated then props.onActivated(...) end
    end)
    return button
end

return Button
