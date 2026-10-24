-- A purchasable item's icon: its product image (Shared.ProductImages) when it has one,
-- else the emoji as stroked text. Every image is preloaded once; one that fails to
-- download (e.g. the experience has no access to it) turns back into its emoji.
-- Icon.new(key, emoji, props): props are GuiObject properties (Size, Position, Parent…);
-- TextSize only applies to the emoji.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Images = require(ReplicatedStorage.Shared.ProductImages)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local StrokedText = require(script.Parent.StrokedText)
local Icon = {}

local failed, shown = {}, {} -- shown[id] = { {image, emoji, props} ... }

local function emoji(text, props)
    return StrokedText.new(Create.merge({ Name = "Icon", Text = text or "", Font = Theme.font.Display, TextSize = 30, stroke = 2 }, props))
end

local function fallBack(entry)
    local image, text, props = entry[1], entry[2], entry[3]
    if not image.Parent then return end
    if text then
        emoji(text, Create.merge(props, { Size = image.Size, Position = image.Position, AnchorPoint = image.AnchorPoint,
            TextSize = props.TextSize or math.max(16, math.floor(image.Size.Y.Offset * 0.7)), Parent = image.Parent }))
    end
    image:Destroy()
end

task.spawn(function()
    -- Preload through ImageLabels: a bare "rbxassetid://" string reports Failure for
    -- Image assets that load fine.
    local probes = {}
    for _, id in Images do
        local probe = Instance.new("ImageLabel")
        probe.Image = id
        table.insert(probes, probe)
    end
    ContentProvider:PreloadAsync(probes, function(id, status)
        if status == Enum.AssetFetchStatus.Failure then
            failed[id] = true
            for _, entry in shown[id] or {} do fallBack(entry) end
            shown[id] = nil
        end
    end)
end)

-- The image id for `key`, or nil when it has none (or it failed to load).
function Icon.image(key)
    local id = key and Images[key]
    return id and not failed[id] and id or nil
end

function Icon.new(key, text, props)
    local id = Icon.image(key)
    if not id then return emoji(text, props) end
    local imageProps = table.clone(props)
    imageProps.TextSize = nil
    local image = Create.new("ImageLabel", { Name = "Icon", Image = id, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit }, imageProps)
    Create.new("UICorner", { CornerRadius = UDim.new(0.22, 0), Parent = image })
    shown[id] = shown[id] or {}
    table.insert(shown[id], { image, text, props })
    return image
end

return Icon
