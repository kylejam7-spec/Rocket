-- Gym District signs and the tags over every bench and treadmill, drawn per player
-- from the attributes WorldService sets (Title, Multiplier, Gain, TierColor,
-- RequiredCycles; stations add TrainingStat and TrainingGain). Each shows its tier's
-- "x3" multiplier as a pulsing badge; locked ones grey out with the launches still
-- needed for this player. A station's badge is its live gain over the base gain, so it
-- always matches its "+N / SEC" (destination gyms change gain per mission).
-- Placeholder styling until real sign art arrives.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local State = require(script.Parent.State)
local Config = require(ReplicatedStorage.Shared.Config)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local WorldScale = require(UI.WorldScale)
local GymSignController = {}

local LOCKED = Color3.fromRGB(110, 110, 125)
local GOLD = ColorSequence.new(Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 165, 30))
local GREY = ColorSequence.new(Color3.fromRGB(215, 215, 225), Color3.fromRGB(150, 150, 165))
local STAT = {
    strengthLevel = { icon = Theme.icon.Strength, name = "STRENGTH", color = Theme.color.Strength, equipment = "BENCH" },
    speedLevel = { icon = Theme.icon.Speed, name = "SPEED", color = Theme.color.Speed, equipment = "TREADMILL" },
}

local function multiplierText(multiplier)
    return ("x%g"):format(multiplier)
end

-- A round tier-coloured badge with a big gold "x3" that gently pulses and sways.
local function badge(parent, props)
    local circle = Create.new("Frame", {
        Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = props.color, Parent = parent,
    }, props)
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = circle })
    local ring = Create.new("UIStroke", { Thickness = props.ring, Color = Theme.color.Stroke, Parent = circle })
    local text = StrokedText.new({
        Name = "Multiplier", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.84, 0.62), Text = props.text, Font = Theme.font.Display, TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1), stroke = props.stroke, Rotation = -10, Parent = circle,
    })
    local gradient = Create.new("UIGradient", { Color = GOLD, Rotation = 90, Parent = text })
    local scale = Create.new("UIScale", { Parent = circle })
    local pulse = TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 })
    local sway = TweenService:Create(text, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 6 })
    return {
        set = function(locked, tierColor, label)
            text.Text = label
            circle.BackgroundColor3 = locked and LOCKED or tierColor
            gradient.Color = locked and GREY or GOLD
            ring.Color = Theme.color.Stroke
            if locked then
                pulse:Cancel(); sway:Cancel()
                scale.Scale, text.Rotation = 1, -10
            else
                pulse:Play(); sway:Play()
            end
        end,
    }
end

-- Status pill: green when open, red-grey with the launches still needed when locked.
local function statusPill(parent, props)
    local pill = Create.new("Frame", { Name = "StatusPill", BackgroundColor3 = Theme.color.Go, Parent = parent }, props)
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pill })
    Create.new("UIStroke", { Thickness = props.ring, Color = Theme.color.Stroke, Parent = pill })
    local text = StrokedText.new({
        Name = "Status", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.9, 0.72), Font = Theme.font.Display, TextScaled = true, stroke = props.stroke, Parent = pill,
    })
    return function(locked, label)
        pill.BackgroundColor3 = locked and Color3.fromRGB(150, 60, 70) or Theme.color.Go
        text.Text = label
    end
end

local function lockLabel(required, launches)
    return "🔒 " .. launches .. "/" .. required .. (required == 1 and " LAUNCH" or " LAUNCHES")
end

-- The big sign on each gym bay's outer edge (22 x 7 studs).
local function buildSign(sign, playerGui)
    local surface = Create.new("SurfaceGui", {
        Name = "GymSign_" .. sign.Name, Adornee = sign, Face = Enum.NormalId[sign:GetAttribute("Face") or "Right"],
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0,
        ResetOnSpawn = false, Parent = playerGui,
    })
    local tierColor = sign:GetAttribute("TierColor") or Theme.color.Gold
    local panel = Create.new("Frame", {
        Name = "Panel", Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.color.Panel, Parent = surface,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 36), Parent = panel })
    local border = Create.new("UIStroke", { Thickness = 12, Color = tierColor, Parent = panel })
    local multiplier = sign:GetAttribute("Multiplier") or 1
    local required = sign:GetAttribute("RequiredCycles")
    local gymTier = sign:GetAttribute("GymTier")
    local mark = badge(panel, {
        Position = UDim2.new(0, 128, 0.5, 0), Size = UDim2.fromOffset(220, 220), color = tierColor, ring = 8, stroke = 8,
        text = multiplierText(multiplier),
    })
    StrokedText.new({
        Name = "Title", Position = UDim2.fromOffset(262, 14), Size = UDim2.new(1, -282, 0, 96),
        Text = sign:GetAttribute("Title") or "GYM", Font = Theme.font.Display, TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left, stroke = 6, Parent = panel,
    })
    -- "💪 +3/s   👟 +3/s" in the stat colours.
    local gain = sign:GetAttribute("Gain") or 0
    for index, stat in { STAT.strengthLevel, STAT.speedLevel } do
        StrokedText.new({
            Name = stat.name .. "Gain", Position = UDim2.new(0, 262 + (index - 1) * 270, 0, 112), Size = UDim2.fromOffset(260, 64),
            Text = stat.icon .. " +" .. gain .. "/s", Font = Theme.font.Display, TextScaled = true, TextColor3 = stat.color,
            TextXAlignment = Enum.TextXAlignment.Left, stroke = 5, Parent = panel,
        })
    end
    local setStatus = statusPill(panel, { Position = UDim2.fromOffset(262, 186), Size = UDim2.fromOffset(330, 52), ring = 4, stroke = 4 })
    return function(launches, passes)
        local locked = required ~= nil and launches < required and not (gymTier and passes["Gym" .. gymTier])
        mark.set(locked, tierColor, multiplierText(multiplier))
        border.Color = locked and LOCKED or tierColor
        setStatus(locked, locked and lockLabel(required, launches) or (required and "✔ UNLOCKED" or "✔ OPEN TO ALL"))
    end
end

-- The tag over a bench or treadmill: "💪 BENCH", "+3 STRENGTH / SEC" and an "x3" badge.
local function buildStation(station, playerGui)
    local gui = Create.new("BillboardGui", {
        Name = "StationTag_" .. station.Name, Adornee = station, Size = UDim2.fromOffset(280, 72),
        StudsOffset = Vector3.new(0, 6, 0), LightInfluence = 0, MaxDistance = 45, ResetOnSpawn = false, Parent = playerGui,
    })
    WorldScale.apply(gui)
    local pill = Create.new("Frame", {
        Name = "Pill", Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(214, 56),
        BackgroundColor3 = Theme.color.Panel, BackgroundTransparency = 0.1, Parent = gui,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = pill })
    local border = Create.new("UIStroke", { Thickness = 3, Parent = pill })
    local name = StrokedText.new({
        Name = "Name", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 28), Font = Theme.font.Display,
        TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2.5, Parent = pill,
    })
    local rate = StrokedText.new({
        Name = "Rate", Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -20, 0, 20), Font = Theme.font.Display,
        TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2, Parent = pill,
    })
    local mark = badge(gui, { Position = UDim2.fromOffset(246, 36), Size = UDim2.fromOffset(64, 64), color = Theme.color.Gold, ring = 3, stroke = 3, text = "" })
    return function(launches, passes)
        local stat = STAT[station:GetAttribute("TrainingStat")] or STAT.strengthLevel
        local tierColor = station:GetAttribute("TierColor") or Theme.color.Gold
        local required = station:GetAttribute("RequiredCycles") or 0
        local gymTier = station:GetAttribute("GymTier")
        local locked = launches < required and not (gymTier and passes["Gym" .. gymTier])
        name.Text = stat.icon .. " " .. stat.equipment .. (station:GetAttribute("Destination") and " • BONUS" or "")
        rate.Text = locked and lockLabel(required, launches) or ("+" .. (station:GetAttribute("TrainingGain") or 0) .. " " .. stat.name .. " / SEC")
        rate.TextColor3 = locked and Theme.color.Locked or stat.color
        border.Color = locked and LOCKED or tierColor
        local gain = station:GetAttribute("TrainingGain") or 0
        mark.set(locked, tierColor, multiplierText(gain / Config.TrainingBaseGain))
    end
end

function GymSignController.start()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    -- Launches and owned gym access passes (state.shop.owned).
    local refreshers, launches, passes = {}, 0, {}
    local function add(object, build)
        if refreshers[object] then return end
        local refresh = build(object, playerGui)
        refreshers[object] = refresh
        refresh(launches, passes)
        -- Destination gyms change their gain per mission; TrainingService sets the rest late.
        object.AttributeChanged:Connect(function() refresh(launches, passes) end)
    end
    for tagName, build in { GymSign = buildSign, TrainingStation = buildStation } do
        for _, object in CollectionService:GetTagged(tagName) do add(object, build) end
        CollectionService:GetInstanceAddedSignal(tagName):Connect(function(object) add(object, build) end)
    end
    local function key(owned)
        local list = {}
        for name in owned do if name:match("^Gym") then table.insert(list, name) end end
        table.sort(list)
        return table.concat(list, ",")
    end
    State.subscribe(function(state)
        local owned = state.shop and state.shop.owned or {}
        if not state.profile or (state.profile.completedLaunches == launches and key(owned) == key(passes)) then return end
        launches, passes = state.profile.completedLaunches, owned
        for _, refresh in refreshers do refresh(launches, passes) end
    end)
end

return GymSignController
