-- Instance construction shared by the components. Component props tables mix
-- Instance properties (Capitalized keys, applied as-is) with component options
-- (lowercase keys, read by the component and skipped here).
local Players = game:GetService("Players")
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
function Create.screen(name)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(name)
    if existing and existing:IsA("ScreenGui") then return existing end
    return Create.new("ScreenGui", { Name = name, ResetOnSpawn = false, Parent = playerGui })
end

return Create
