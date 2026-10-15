-- Rounded background frame. Options: radius (px), maxSize (Vector2 for a
-- UISizeConstraint), stroke (border thickness), strokeColor, padding (px).
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Panel = {}

function Panel.new(props)
    local frame = Create.new("Frame", {
        BackgroundColor3 = Theme.color.Panel,
        BackgroundTransparency = Theme.panelTransparency,
    }, props)
    if props.maxSize then Create.new("UISizeConstraint", { MaxSize = props.maxSize, Parent = frame }) end
    Create.new("UICorner", { CornerRadius = UDim.new(0, props.radius or Theme.radius), Parent = frame })
    if props.stroke then
        Create.new("UIStroke", {
            Thickness = props.stroke,
            Color = props.strokeColor or Theme.color.Stroke,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = frame,
        })
    end
    if props.padding then
        local inset = UDim.new(0, props.padding)
        Create.new("UIPadding", { PaddingTop = inset, PaddingBottom = inset, PaddingLeft = inset, PaddingRight = inset, Parent = frame })
    end
    return frame
end

return Panel
