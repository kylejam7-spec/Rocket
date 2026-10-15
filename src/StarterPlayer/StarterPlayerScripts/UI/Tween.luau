-- Animation helpers shared by every component: play, bounce, count-up and fly-to.
local TweenService = game:GetService("TweenService")
local Tween = {}

function Tween.info(seconds, style, direction)
    return TweenInfo.new(seconds or 0.25, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
end

-- info may be a TweenInfo or a duration in seconds.
function Tween.play(instance, info, goals)
    if type(info) == "number" then info = Tween.info(info) end
    local tween = TweenService:Create(instance, info, goals)
    tween:Play()
    return tween
end

-- Punch a GuiObject up to `amount` and spring back. Uses a UIScale child, so the
-- object's layout (Size, Position, list order) never changes.
function Tween.bounce(gui, amount, seconds)
    local scale = gui:FindFirstChild("BounceScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Name = "BounceScale"
        scale.Parent = gui
    end
    scale.Scale = amount or 1.15
    return Tween.play(scale, Tween.info(seconds or 0.35, Enum.EasingStyle.Back), { Scale = 1 })
end

-- Roll a label's number from `from` to `to`. A newer count on the same label
-- cancels the older one, so rapid updates never fight over the text.
local counting = setmetatable({}, { __mode = "k" })
function Tween.countUp(label, from, to, seconds, format)
    format = format or function(value) return tostring(math.round(value)) end
    if counting[label] then counting[label]:Cancel() end
    local value = Instance.new("NumberValue")
    value.Value = from
    value.Changed:Connect(function(current) label.Text = format(current) end)
    label.Text = format(from)
    local tween = Tween.play(value, seconds or 0.4, { Value = to })
    counting[label] = tween
    tween.Completed:Connect(function(state)
        if counting[label] == tween then counting[label] = nil end
        if state == Enum.PlaybackState.Completed then label.Text = format(to) end
        value:Destroy()
    end)
    return tween
end

-- Move `gui` (a direct child of a ScreenGui) onto the centre of `target`, e.g. a
-- coin flying to the coin counter, then call onArrive.
function Tween.flyTo(gui, target, seconds, onArrive)
    local screen = gui:FindFirstAncestorWhichIsA("LayerCollector")
    local origin = screen and screen.AbsolutePosition or Vector2.zero
    -- Offsets are multiplied by the screen's UIScale, so divide pixels back out.
    local scale = screen and screen:FindFirstChildOfClass("UIScale")
    local goal = (target.AbsolutePosition + target.AbsoluteSize / 2 - origin) / (scale and scale.Scale or 1)
    gui.AnchorPoint = Vector2.new(0.5, 0.5)
    local tween = Tween.play(gui, Tween.info(seconds or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.fromOffset(goal.X, goal.Y) })
    tween.Completed:Connect(function(state)
        if state == Enum.PlaybackState.Completed and onArrive then onArrive() end
    end)
    return tween
end

return Tween
