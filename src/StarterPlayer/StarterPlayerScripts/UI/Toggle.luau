-- Candy on/off switch: a pill that turns green with the knob sliding right.
-- Options: value (bool), onChanged(value). toggle:set(value).
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Tween = require(script.Parent.Tween)
local Sfx = require(script.Parent.Sfx)
local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(props)
    local pill = Create.new("TextButton", {
        Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(72, 34),
    }, props)
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
    Create.new("UIStroke", { Thickness = 3, Color = Theme.color.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = pill })
    Theme.shine(pill)
    local knob = Create.new("Frame", {
        Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = Theme.color.White, Parent = pill,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    local self = setmetatable({ instance = pill, knob = knob, onChanged = props.onChanged }, Toggle)
    self:set(props.value == true, true)
    pill.Activated:Connect(function()
        self:set(not self.value)
        Sfx.play("toggle", { pitch = self.value and 1.12 or 0.9 })
        if self.onChanged then self.onChanged(self.value) end
    end)
    return self
end

function Toggle:set(value, instant)
    self.value = value
    local goal = { Position = UDim2.new(value and 1 or 0, value and -19 or 19, 0.5, 0) }
    self.instance.BackgroundColor3 = value and Theme.color.Go or Theme.color.Track
    if instant then self.knob.Position = goal.Position else Tween.play(self.knob, 0.15, goal) end
end

return Toggle
