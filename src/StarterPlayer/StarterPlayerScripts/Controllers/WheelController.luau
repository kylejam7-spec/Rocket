-- The mission wheel everyone sees near the end of each reward stay. The server picks
-- the result (state.wheel: result, weights, offset, startAt, seconds, pity); every
-- client draws the same pie from the weights and eases it to the same stopping
-- angle from the shared server clock, then shows the result in its rarity colour.
-- Sound follows the drawn wheel: a tick each time a slice edge passes the pointer
-- (slowing with the wheel), then a chime as it stops, a jingle for Rare or better.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Missions = require(ReplicatedStorage.Shared.Missions)
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Sfx = require(UI.Sfx)
local StrokedText = require(UI.StrokedText)
local Tween = require(UI.Tween)
local WheelController = {}

local SIZE, SPOKES, TURNS, LINGER = 380, 144, 5, 3.5

local function shortName(index)
    return (Config.Destinations[index].name:gsub("^THE ", ""))
end

function WheelController.start()
    local gui = Create.screen("MissionWheel")
    gui.DisplayOrder = 5
    local root = Create.new("Frame", {
        Name = "WheelRoot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1, Visible = false, Parent = gui,
    })
    local title = StrokedText.new({
        Name = "Title", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -26), Size = UDim2.fromOffset(600, 44),
        Font = Theme.font.Display, TextSize = 40, stroke = 3, Text = "NEXT MISSION", Parent = root,
    })
    local result = StrokedText.new({
        Name = "Result", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 12), Size = UDim2.fromOffset(640, 56),
        Font = Theme.font.Display, TextSize = 48, stroke = 4, Text = "", Parent = root,
    })
    -- Rim and pointer stay still; only `wheel` rotates.
    local rim = Create.new("Frame", {
        Name = "Rim", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 16, 1, 16),
        BackgroundColor3 = Theme.color.Gold, Parent = root,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rim })
    Create.new("UIStroke", { Thickness = 4, Color = Theme.color.Stroke, Parent = rim })
    local wheel = Create.new("Frame", {
        Name = "Wheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.color.Panel, ClipsDescendants = false, Parent = root,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = wheel })
    local hub = Create.new("Frame", {
        Name = "Hub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64),
        BackgroundColor3 = Theme.color.Gold, ZIndex = 5, Parent = root,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hub })
    Create.new("UIStroke", { Thickness = 3, Color = Theme.color.Stroke, Parent = hub })
    StrokedText.new({
        Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(60, 60),
        Text = "▼", Font = Theme.font.Display, TextSize = 56, TextColor3 = Theme.color.White, stroke = 4, ZIndex = 6, Parent = root,
    })

    -- Builds the pie for a weight table: thin spokes from the centre (a solid fill once
    -- there are enough of them) coloured by slice, plus a radial label per slice.
    -- Returns each slice's start and size in degrees, clockwise from the top.
    local function build(weights)
        for _, child in wheel:GetChildren() do
            if not child:IsA("UICorner") then child:Destroy() end
        end
        local total, slices, angle = 0, {}, 0
        for _, weight in weights do total += weight end
        for index, weight in weights do
            if weight > 0 then
                slices[index] = { from = angle, size = weight / total * 360 }
                angle += slices[index].size
            end
        end
        local width = math.pi * SIZE / SPOKES * 1.6
        for spoke = 0, SPOKES - 1 do
            local at = (spoke + 0.5) / SPOKES * 360
            local colour = Theme.color.Panel
            for index, slice in slices do
                if at >= slice.from and at < slice.from + slice.size then colour = Theme.rarity[Missions.get(index).Rarity] end
            end
            -- GUI rotation turns about an object's centre, so each spoke is a full
            -- diameter strip centred on the wheel with only its outer half painted.
            local strip = Create.new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, width, 1, -4),
                Rotation = at, BackgroundTransparency = 1, Parent = wheel,
            })
            Create.new("Frame", { Size = UDim2.fromScale(1, 0.5), BorderSizePixel = 0, BackgroundColor3 = colour, Parent = strip })
        end
        for index, slice in slices do
            local degrees = slice.from + slice.size / 2
            local middle = math.rad(degrees)
            local radius = SIZE * 0.31
            StrokedText.new({
                AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(SIZE * 0.42, 20), ZIndex = 3,
                Position = UDim2.new(0.5, math.sin(middle) * radius, 0.5, -math.cos(middle) * radius),
                -- Along the radius; flipped on the left half so it never starts upside down.
                Rotation = degrees <= 180 and degrees - 90 or degrees + 90, Font = Theme.font.Display, TextSize = slice.size < 20 and 14 or 18, stroke = 2,
                Text = shortName(index) .. " " .. math.round(slice.size / 3.6) .. "%", Parent = wheel,
            })
        end
        return slices
    end

    -- The objective line sits where the wheel's title goes; hide it while spinning.
    local hud = Create.screen("RocketHUD")
    local spin, slices, shownFor, revealed, underPointer
    -- The slice under the pointer at a wheel rotation (slices run clockwise from the top).
    local function sliceAt(rotation)
        local at = -rotation % 360
        for index, slice in slices do
            if at >= slice.from and at < slice.from + slice.size then return index end
        end
        return nil
    end
    State.subscribe(function(state)
        spin = state.wheel
        if not spin then return end
        if shownFor ~= spin.startAt then
            shownFor, revealed, underPointer = spin.startAt, false, nil
            slices = build(spin.weights)
            title.Text = spin.pity and "PITY SPIN! RARE OR BETTER!" or "SPINNING FOR THE NEXT MISSION"
            title.TextColor3 = spin.pity and Theme.rarity.Rare or Theme.color.White
            result.Text = ""
        end
    end)

    RunService.RenderStepped:Connect(function()
        local now = workspace:GetServerTimeNow()
        local active = spin and slices and now < spin.startAt + spin.seconds + LINGER
        root.Visible = active == true
        local objective = hud:FindFirstChild("Objective")
        if objective then objective.Visible = not active end
        if not active then return end
        local slice = slices[spin.result]
        local final = TURNS * 360 - (slice.from + slice.size * spin.offset)
        local progress = math.clamp((now - spin.startAt) / spin.seconds, 0, 1)
        local eased = 1 - (1 - progress) ^ 3
        wheel.Rotation = final * eased
        local under = sliceAt(wheel.Rotation)
        if progress < 1 and underPointer and under ~= underPointer then Sfx.play("tick") end
        underPointer = under
        if progress >= 1 and not revealed then
            revealed = true
            local mission = Missions.get(spin.result)
            result.Text = Config.Destinations[spin.result].name .. "!  " .. mission.Rarity:upper()
            result.TextColor3 = Theme.rarity[mission.Rarity]
            Tween.bounce(result, mission.Rank >= 4 and 1.8 or 1.4, 0.5)
            Tween.bounce(root, 1.06, 0.3)
            Sfx.play(mission.Rank >= Missions.PityRank and "jingle" or "confirm")
        end
    end)
end

return WheelController
