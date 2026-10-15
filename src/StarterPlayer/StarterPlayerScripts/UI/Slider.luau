-- Chunky horizontal slider: dark track with a gold rim, glossy fill and a round
-- knob. Drag or click anywhere on it (mouse or touch).
-- Options: value (0..1), color (fill), onChanged(value). slider:set(value).
local UserInputService = game:GetService("UserInputService")
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Slider = {}
Slider.__index = Slider

function Slider.new(props)
    local track = Create.new("TextButton", {
        Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(200, 22),
        BackgroundColor3 = Theme.color.Track,
    }, props)
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    Create.new("UIStroke", { Thickness = 2.5, Color = Theme.color.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = track })
    local fill = Create.new("Frame", { Name = "Fill", BackgroundColor3 = props.color or Theme.color.Gold, Parent = track })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    Theme.shine(fill)
    local knob = Create.new("Frame", {
        Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Theme.color.White, ZIndex = 2, Parent = track,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    Create.new("UIStroke", { Thickness = 3, Color = Theme.color.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = knob })
    local self = setmetatable({ instance = track, fill = fill, knob = knob, onChanged = props.onChanged }, Slider)
    self:set(props.value or 0)

    local dragging
    local function moveTo(x)
        local value = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        value = math.round(value * 20) / 20
        if value ~= self.value then
            self:set(value)
            if self.onChanged then self.onChanged(value) end
        end
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = input
            moveTo(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement then moveTo(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
    end)
    return self
end

function Slider:set(value)
    self.value = math.clamp(value, 0, 1)
    self.fill.Size = UDim2.fromScale(self.value, 1)
    self.fill.Visible = self.value > 0
    self.knob.Position = UDim2.fromScale(self.value, 0.5)
end

return Slider
