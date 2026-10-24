-- The reference's bottom progress pill: a dark rounded track with a gold rim, a
-- glossy fill and a big stroked "9 / 171,700" label on top.
-- Options: fillColor, rimColor, rim (thickness, 0 for none), label (true to add
-- text), textSize, animate (tween fill changes).
-- pill:set(progress, color?, text?, image?) updates it (image: a Shared.ProductImages key
-- shown after the text, nil for none); call it as often as you like.
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local Icon = require(script.Parent.Icon)
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
    -- The fill sits in a rounded inset clip so it never pokes past the rim. It is
    -- always at least a full round cap wide and slides in from the left, so the
    -- first few units grow a smooth sliver instead of a squashed blob.
    local inset = Create.new("CanvasGroup", {
        Name = "Inset", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), Parent = track,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = inset })
    local cap = track.Size.Y.Offset - 6
    local fill = Create.new("Frame", {
        Name = "Fill",
        Position = UDim2.fromOffset(-cap, 0),
        Size = UDim2.new(0, cap, 1, 0),
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
    return setmetatable({ instance = track, fill = fill, label = label, animate = props.animate, cap = cap, target = -1 }, Pill)
end

function Pill:set(progress, color, text, image)
    local alpha = math.clamp(progress, 0, 1)
    if alpha ~= self.target then
        local grew = self.target >= 0 and alpha > self.target
        self.target = alpha
        -- Visible width is exactly alpha of the track; the rest of the cap hides off the left.
        local hidden = self.cap * (1 - alpha)
        local goal = { Size = UDim2.new(alpha, hidden, 1, 0), Position = UDim2.fromOffset(-hidden, 0) }
        if self.animate and grew then
            Tween.play(self.fill, Tween.info(0.35, Enum.EasingStyle.Quad), goal)
        else
            self.fill.Size, self.fill.Position = goal.Size, goal.Position
        end
        if grew and self.label then Tween.bounce(self.label, 1.15, 0.3) end
    end
    if color then self.fill.BackgroundColor3 = color end
    if text and self.label then self.label.Text = text end
    if self.label and image ~= self.image then
        self.image = image
        Icon.attach(self.label, image, "after")
    end
end

return Pill
