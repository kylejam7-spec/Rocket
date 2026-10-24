-- A purchasable item's icon: its product image (Shared.ProductImages) when it has one,
-- else the emoji as stroked text. Every image is preloaded once; one that fails to
-- download (e.g. the experience has no access to it) turns back into its emoji.
-- Icon.new(key, emoji, props): props are GuiObject properties (Size, Position, Parent…);
-- TextSize only applies to the emoji.
-- Icon.attach(label, key, side): an image just "before" (default) or "after" a TextLabel's
-- text, sized to the text, following it as the text, size or fade change; pass key nil
-- to take it off again. A UIPadding makes room for it, so text and picture stay centred
-- (or clear of the edge) together.
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

-- The emoji (and a space) to write in a label's text when `key` has no picture to
-- attach, else "".
function Icon.text(key, emoji)
    return Icon.image(key) and "" or (emoji .. " ")
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

-- Positions are worked out in screen pixels (TextBounds is in screen pixels, UIScale and
-- billboards included) and set as fractions of the label's padded content box.
function Icon.attach(label, key, side)
    side = side or "before"
    local name = "InlineIcon_" .. side
    local image = label:FindFirstChild(name)
    local id = Icon.image(key)
    if not id then
        if image then image:Destroy() end
        local padding = label:FindFirstChild("InlineIconPadding")
        if padding then padding[side == "before" and "PaddingLeft" or "PaddingRight"] = UDim.new() end
        return nil
    end
    if image then
        image.Image = id
        return image
    end
    image = Create.new("ImageLabel", { Name = name, Image = id, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
        ZIndex = label.ZIndex, ImageTransparency = label.TextTransparency, Parent = label })
    local padding = label:FindFirstChild("InlineIconPadding")
        or Create.new("UIPadding", { Name = "InlineIconPadding", Parent = label })
    local function place()
        -- The padding makes room for the picture (text scaled to fit shrinks a little and
        -- settles in a step or two).
        local align = label.TextXAlignment
        local box, text = label.AbsoluteSize, label.TextBounds
        if box.X <= 0 or box.Y <= 0 or text.Y <= 0 then return end
        local size, gap = text.Y * 1.1, text.Y * 0.2
        -- Fixed-size text pads in its own units (TextSize per screen pixel of text), so a
        -- label that sizes itself to its text grows to fit the picture too; scaled text
        -- pads as a share of its width.
        local units = not label.TextScaled and label.TextSize / text.Y or nil
        local function screen(udim) return udim.Scale * box.X + (units and udim.Offset / units or 0) end
        local key = side == "before" and "PaddingLeft" or "PaddingRight"
        local want = units and UDim.new(0, math.round((size + gap) * units)) or UDim.new((size + gap) / box.X, 0)
        if math.abs(screen(padding[key]) - screen(want)) > 0.5 then padding[key] = want end
        local left, right = screen(padding.PaddingLeft), screen(padding.PaddingRight)
        local start
        if align == Enum.TextXAlignment.Left then
            start = left
        elseif align == Enum.TextXAlignment.Right then
            start = box.X - right - text.X
        else
            start = left + (box.X - left - right - text.X) / 2
        end
        local x = side == "before" and start - gap - size or start + text.X + gap
        local y = box.Y / 2
        if label.TextYAlignment == Enum.TextYAlignment.Top then y = text.Y / 2
        elseif label.TextYAlignment == Enum.TextYAlignment.Bottom then y = box.Y - text.Y / 2 end
        -- The padding moves children too: place the picture in the padded content box.
        local inner = box.X - left - right
        image.AnchorPoint = Vector2.new(0, 0.5)
        image.Position = UDim2.fromScale((x - left) / inner, y / box.Y)
        image.Size = UDim2.fromScale(size / inner, size / box.Y)
    end
    local links = {
        label:GetPropertyChangedSignal("TextBounds"):Connect(place),
        label:GetPropertyChangedSignal("AbsoluteSize"):Connect(place),
        label:GetPropertyChangedSignal("TextTransparency"):Connect(function() image.ImageTransparency = label.TextTransparency end),
    }
    place()
    -- Taken off (or failed to load): stop following and give the space back.
    shown[id] = shown[id] or {}
    table.insert(shown[id], { image, nil, {} })
    image.Destroying:Connect(function()
        for _, link in links do link:Disconnect() end
        if padding.Parent then padding[side == "before" and "PaddingLeft" or "PaddingRight"] = UDim.new() end
    end)
    return image
end

return Icon
