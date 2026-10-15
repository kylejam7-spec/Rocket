-- Instance construction shared by the components. Component props tables mix
-- Instance properties (Capitalized keys, applied as-is) with component options
-- (lowercase keys, read by the component and skipped here).
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Create = {}

-- Applies defaults, then props, then Parent last so the instance appears fully built.
function Create.new(className, defaults, props)
    local item = Instance.new(className)
    local parent
    for _, source in { defaults or {}, props or {} } do
        for key, value in source do
            if key == "Parent" then
                parent = value
            elseif type(key) == "string" and key:match("^%u") then
                item[key] = value
            end
        end
    end
    item.Parent = parent
    return item
end

-- A copy of defaults with props layered on top; lets one component pass its own
-- defaults to another without losing the caller's overrides.
function Create.merge(defaults, props)
    local merged = table.clone(defaults)
    for key, value in props or {} do merged[key] = value end
    return merged
end

-- One ScreenGui per name in PlayerGui, shared by every controller that asks for it.
-- Its UIScale keeps offset layouts (authored for Theme.designHeight) the same
-- relative size on phones and big monitors.
function Create.screen(name)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(name)
    if existing and existing:IsA("ScreenGui") then return existing end
    -- CoreUISafeInsets keeps everything clear of the notch and the Roblox top bar.
    local screen = Create.new("ScreenGui", { Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets })
    local scale = Create.new("UIScale", { Name = "ScreenScale", Parent = screen })
    -- Fit the usable (inset) height, which tracks resizes and rotation. Floor 0.45 so a
    -- ~375 px landscape phone still fits the whole 720 px layout.
    local function fit()
        local height = screen.AbsoluteSize.Y
        if height <= 0 then height = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or Theme.designHeight end
        scale.Scale = math.clamp(height / Theme.designHeight, 0.45, 1.6)
    end
    screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()
    screen.Parent = playerGui
    fit()
    return screen
end

return Create
