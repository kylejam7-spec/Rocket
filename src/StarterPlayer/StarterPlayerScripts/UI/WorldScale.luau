-- World billboards (rank tags, gym equipment tags, "+2" stat pops) are sized in screen
-- pixels, so on a short phone screen they cover far more of the view than on a
-- monitor. WorldScale.apply(gui) shrinks a BillboardGui and its contents by
-- viewport height / ReferenceHeight (never above 1, so desktops are unchanged) and
-- follows window resizes. Call it once per billboard after setting its Size.
local Create = require(script.Parent.Create)
local WorldScale = {}

local ReferenceHeight, Floor = 720, 0.5
local tracked = setmetatable({}, { __mode = "k" })

function WorldScale.factor()
    local camera = workspace.CurrentCamera
    local height = camera and camera.ViewportSize.Y or ReferenceHeight
    return math.clamp(height / ReferenceHeight, Floor, 1)
end

local function fit(gui, base)
    local factor = WorldScale.factor()
    gui.Size = UDim2.fromOffset(base.X * factor, base.Y * factor)
    local scale = gui:FindFirstChild("WorldScale") or Create.new("UIScale", { Name = "WorldScale", Parent = gui })
    scale.Scale = factor
end

function WorldScale.apply(gui)
    if tracked[gui] then return end
    local base = Vector2.new(gui.Size.X.Offset, gui.Size.Y.Offset)
    tracked[gui] = base
    fit(gui, base)
end

local function watch(camera)
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        for gui, base in tracked do
            if gui.Parent then fit(gui, base) end
        end
    end)
end
if workspace.CurrentCamera then watch(workspace.CurrentCamera) end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then watch(workspace.CurrentCamera) end
end)

return WorldScale
