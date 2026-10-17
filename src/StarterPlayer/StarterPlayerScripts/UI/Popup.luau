-- Short-lived juice text.
-- Popup.show(props): pops in, rises and fades, then destroys itself ("+1" ticks).
-- Popup.world(adornee, props): the same, floating in 3D above a part or model
--   (training "+2 💪" icons, "Strength Level Up!"); `shift` raises it that many
--   screen pixels, so stacked popups stay apart at any camera distance.
-- Popup.banner(props): pops in with a bounce, holds `seconds`, then fades; a newer
--   banner with the same Name replaces it (announcements, toasts).
-- Options: rise (px), seconds, plus any StrokedText option or TextLabel property.
local Players = game:GetService("Players")
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Tween = require(script.Parent.Tween)
local WorldScale = require(script.Parent.WorldScale)
local Popup = {}

local function label(props)
    return StrokedText.new(Create.merge({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(260, 48),
        Font = Theme.font.Display,
        TextSize = 30,
        TextColor3 = Theme.color.White,
        stroke = 3,
    }, props))
end

local function fadeOut(item, seconds)
    local fade = Tween.info(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Tween.play(item, fade, { TextTransparency = 1 })
    local stroke = item:FindFirstChildOfClass("UIStroke")
    if stroke then Tween.play(stroke, fade, { Transparency = 1 }) end
end

function Popup.show(props)
    local item = label(props)
    local seconds, rise = props.seconds or 0.9, props.rise or 48
    Tween.bounce(item, 1.5, 0.3)
    Tween.play(item, Tween.info(seconds), { Position = item.Position - UDim2.fromOffset(0, rise) })
    fadeOut(item, seconds)
    task.delay(seconds, item.Destroy, item)
    return item
end

function Popup.world(adornee, props)
    local seconds = props.seconds or 1.1
    local billboard = Create.new("BillboardGui", {
        Name = "WorldPopup",
        Adornee = adornee,
        AlwaysOnTop = true,
        LightInfluence = 0,
        Size = UDim2.fromOffset(240, 140),
        StudsOffsetWorldSpace = props.offset or Vector3.new(0, 3, 0),
        SizeOffset = Vector2.new(0, (props.shift or 0) / 140),
        MaxDistance = 120,
        Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
    })
    WorldScale.apply(billboard)
    Popup.show(Create.merge({ Position = UDim2.new(0.5, props.jitter or 0, 1, -24), rise = 90, seconds = seconds, Parent = billboard }, props))
    task.delay(seconds + 0.1, billboard.Destroy, billboard)
    return billboard
end

function Popup.banner(props)
    local parent = props.Parent
    local old = props.Name and parent and parent:FindFirstChild(props.Name)
    if old then old:Destroy() end
    local item = label(Create.merge({ TextSize = 44, Size = UDim2.new(1, -40, 0, 70), TextWrapped = true }, props))
    Tween.bounce(item, 1.6, 0.45)
    task.delay(props.seconds or 3, function()
        if not item.Parent then return end
        fadeOut(item, 0.4)
        task.delay(0.4, item.Destroy, item)
    end)
    return item
end

return Popup
