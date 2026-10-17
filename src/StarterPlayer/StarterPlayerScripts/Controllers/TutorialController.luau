-- First-session tutorial, shown from the server's step (state.profile.tutorialStep;
-- TutorialService advances it): the objective line (HudController asks
-- TutorialController.objective first), a glowing beam and bouncing arrow to the
-- target (an edge arrow when it's off screen), a SKIP TUTORIAL button, and
-- one-time callouts for the first Fuel phase and the first boarding.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local State = require(script.Parent.State)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local StrokedText = require(UI.StrokedText)
local Popup = require(UI.Popup)
local Tween = require(UI.Tween)
local TutorialController = {}

local MATERIAL = { Building = "Metal", Fueling = "Fuel" }
local CALLOUTS = {
    Fuel = { phase = "Fueling", text = "FIRST FUEL RUN! Fill a jerry can at the OIL REFINERY, then pour it in at the ring!", color = Theme.color.Fuel },
    Boarding = { phase = "Boarding", text = "Walk into the rocket at the green BOARD hatch to fly to space for free stats!", color = Theme.color.Ready },
}

local function step(state)
    local profile = state.profile
    local current = profile and profile.tutorialStep
    return current ~= "Done" and current or nil
end

-- The tutorial's line for the objective banner, or nil to show the normal one.
-- Cargo steps only make sense while there's cargo to move.
function TutorialController.objective(state)
    local current = step(state)
    if not current then return nil end
    local material = MATERIAL[state.phase]
    local hold = Actions.touch and "Hold GRAB" or "Hold E"
    if current == "Pickup" and material and not state.training then
        return material == "Fuel" and hold .. " at the OIL REFINERY to fill a jerry can!" or hold .. " at the SCRAP PIT to grab scrap metal!"
    elseif current == "Carry" and material and not state.training then
        return "Carry it up the ramp to the glowing ring!"
    elseif current == "Place" and material and not state.training then
        return (Actions.touch and "Hold PLACE" or "Hold E") .. " by the ring to build the rocket and earn coins!"
    elseif current == "Upgrade" and not state.training then
        return "Spend your coins! Buy an upgrade at the UPGRADES hut."
    elseif current == "Bench" or current == "Treadmill" then
        -- state.training is the station name ("Free gym bench", "2x gym treadmill", "Bench press"…).
        local bench = current == "Bench"
        local onIt = state.training and state.training:lower():find(bench and "bench" or "treadmill") ~= nil
        if onIt then
            return bench and "Lift to Strength LV 1! More strength = more carried per trip."
                or "Run to Speed LV 1! More speed = faster trips."
        end
        if state.training then return "Nice! Press E to leave, then hop on the " .. (bench and "BENCH PRESS!" or "TREADMILL!") end
        return bench and "Get stronger! Use the bench press at the FREE GYM in the GYM DISTRICT!" or "Now the TREADMILL: more speed = faster trips!"
    elseif current == "Together" then
        return "Work with everyone to finish the rocket, then fuel it and board!"
    end
    return nil
end

-- Where the current step wants you: a world position, plus the target part when
-- it's on the ground (its edge, not its centre, counts as arrived).
local function target(state)
    local current = step(state)
    if not current or state.training then return nil end
    local material = MATERIAL[state.phase]
    if current == "Pickup" and material then
        for _, source in CollectionService:GetTagged("MaterialSource") do
            if source:GetAttribute("Material") == material and source:IsA("BasePart") then return source.Position, source end
        end
    elseif (current == "Carry" or current == "Place") and material then
        local ring = CollectionService:GetTagged("BuildFrontier")[1]
        local point = ring and ring:FindFirstChild("PlacePoint")
        if point then return point.WorldPosition, false end
    elseif current == "Upgrade" then
        local hut = CollectionService:GetTagged("UpgradesHut")[1]
        if hut then return hut.Position, hut end
    elseif current == "Bench" or current == "Treadmill" then
        local stat = current == "Bench" and "strengthLevel" or "speedLevel"
        for _, station in CollectionService:GetTagged("TrainingStation") do
            if station:GetAttribute("TrainingStat") == stat and (station:GetAttribute("RequiredCycles") or 0) == 0
                and not station:GetAttribute("Destination") then
                return station.Position, station
            end
        end
    end
    return nil
end

function TutorialController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("RocketHUD")
    local function statStack() return gui:FindFirstChild("StatStack") end
    -- The holder carries the touch scale (the button's own UIScale is its hover grow).
    local holder = Create.new("Frame", {
        Name = "SkipTutorialHolder", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -Theme.gutter, 0, 160),
        Size = UDim2.fromOffset(170, 44), BackgroundTransparency = 1, Parent = gui,
    })
    local skip = Button.new({
        Name = "SkipTutorial", Text = "SKIP TUTORIAL", TextSize = 18, color = Theme.color.Purple,
        Size = UDim2.fromScale(1, 1), Visible = false, Parent = holder,
        onActivated = function() State.remote("TutorialSkip"):FireServer() end,
    })
    -- On a phone the HUD scales to ~0.45; keep SKIP a thumb-sized target (≥ 36 px tall).
    if Actions.touch then
        local screenScale = gui:FindFirstChildOfClass("UIScale")
        local scale = Create.new("UIScale", { Name = "TouchScale", Parent = holder })
        local function fit() scale.Scale = math.max(1, 36 / (44 * (screenScale and screenScale.Scale or 1))) end
        if screenScale then screenScale:GetPropertyChangedSignal("Scale"):Connect(fit) end
        fit()
    end

    -- Waypoint: a local anchor at the target with a bouncing arrow, and a beam to it.
    local anchor = Create.new("Part", {
        Name = "TutorialTarget", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        Transparency = 1, Size = Vector3.one, Parent = workspace.CurrentCamera,
    })
    local toAttachment = Create.new("Attachment", { Parent = anchor })
    local arrow = Create.new("BillboardGui", {
        Name = "TutorialArrow", AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromOffset(90, 90),
        StudsOffsetWorldSpace = Vector3.new(0, 7, 0), Enabled = false, Parent = anchor,
    })
    local arrowLabel = StrokedText.new({
        Size = UDim2.fromScale(1, 1), Text = "⬇", Font = Theme.font.Display, TextSize = 72,
        TextColor3 = Theme.color.Ready, stroke = 4, Parent = arrow,
    })
    local beam = Create.new("Beam", {
        Attachment1 = toAttachment, FaceCamera = true, Width0 = 0.6, Width1 = 1.4, LightEmission = 1,
        Color = ColorSequence.new(Theme.color.Ready),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0.15) }),
        Segments = 24, CurveSize0 = 0, CurveSize1 = -6, Enabled = false, Parent = anchor,
    })

    -- Under the HUD; no dimming, the world stays fully visible.
    local guide = Create.new("ScreenGui", {
        Name = "TutorialGuide", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -1, Parent = player:WaitForChild("PlayerGui"),
    })
    -- Off-screen targets (the Scrap Pit is behind you at spawn): an arrow on a ring
    -- around your character pointing the way, clear of the HUD at the edges.
    local edgeArrow = StrokedText.new({
        Name = "EdgeArrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(110, 110), Text = "⬆",
        Font = Theme.font.Display, TextScaled = true, TextColor3 = Theme.color.Ready, stroke = 4, Visible = false, Parent = guide,
    })
    local current
    State.subscribe(function(state)
        current = state
        skip.Visible = step(state) ~= nil
        -- One-time callouts, after the phase's own banner has had its moment.
        local profile = state.profile
        for name, callout in CALLOUTS do
            if profile and state.phase == callout.phase and not table.find(profile.seenCallouts, name) and not callout.shown then
                callout.shown = true
                task.delay(4.2, function()
                    Popup.banner({
                        Name = "Banner", Text = callout.text, TextColor3 = callout.color, TextSize = 34, seconds = 7,
                        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Parent = Create.screen("RocketProgress"),
                    })
                    State.remote("TutorialSeen"):FireServer(name)
                end)
            end
        end
    end)

    local bob = 0
    RunService.RenderStepped:Connect(function(dt)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local position, focus
        if current and root then position, focus = target(current) end
        -- Distance to the target's nearest edge: the Scrap Pit alone is 52 x 66 studs.
        local distance = position and (position - root.Position).Magnitude or math.huge
        if focus then
            local offset = focus.CFrame:PointToObjectSpace(root.Position)
            local half = focus.Size / 2
            distance = (offset - offset:Max(-half):Min(half)).Magnitude
        end
        local show = position ~= nil and distance > 6
        arrow.Enabled = position ~= nil
        beam.Enabled = show
        if position then
            anchor.Position = position
            bob += dt
            arrowLabel.Position = UDim2.fromOffset(0, math.sin(bob * 5) * 8)
            local from = root:FindFirstChild("TutorialFrom") or Create.new("Attachment", { Name = "TutorialFrom", Position = Vector3.new(0, -2, 0), Parent = root })
            beam.Attachment0 = from
        end
        local camera = workspace.CurrentCamera
        local size = camera.ViewportSize
        local onScreen = false
        if position then
            local point, visible = camera:WorldToViewportPoint(position + Vector3.new(0, 7, 0))
            onScreen = visible and point.X > 0 and point.X < size.X and point.Y > 0 and point.Y < size.Y
        end
        edgeArrow.Visible = position ~= nil and not onScreen
        if edgeArrow.Visible then
            -- Direction in screen terms (x right, y down); straight behind points down.
            local relative = camera.CFrame:PointToObjectSpace(position)
            local direction = Vector2.new(relative.X, -relative.Y)
            if relative.Z > 0 then direction = Vector2.new(relative.X, math.abs(relative.Y) + 1) end
            direction = direction.Magnitude > 1e-3 and direction.Unit or Vector2.new(0, 1)
            local at = size / 2 + direction * size * 0.3
            -- Sized to the screen; pushed right of the stat stack if it would land on it.
            local arrowSize = math.clamp(size.Y * 0.12, 48, 110)
            local stack = statStack()
            if stack then
                -- The HUD sits inside the safe-area inset; this guide ignores it.
                local inset = gui.AbsolutePosition
                local min, max = stack.AbsolutePosition + inset, stack.AbsolutePosition + inset + stack.AbsoluteSize
                local half = arrowSize / 2
                if at.X - half < max.X and at.X + half > min.X and at.Y - half < max.Y and at.Y + half > min.Y then
                    at = Vector2.new(max.X + half + 8, at.Y)
                end
            end
            edgeArrow.Size = UDim2.fromOffset(arrowSize, arrowSize)
            edgeArrow.Position = UDim2.fromOffset(at.X, at.Y)
            edgeArrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
        end
    end)

    -- A short cheer when a step finishes.
    local last
    State.subscribe(function(state)
        local now = state.profile and state.profile.tutorialStep
        if last and now and now ~= last and now == "Done" and last == "Together" then
            Popup.banner({
                Name = "Banner", Text = "TUTORIAL COMPLETE! " .. Theme.icon.Star, TextColor3 = Theme.color.Gold, seconds = 4,
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Parent = Create.screen("RocketProgress"),
            })
        elseif last and now and now ~= last and now ~= "Done" and table.find({ "Carry", "Place", "Upgrade", "Bench", "Treadmill", "Together" }, now) then
            Tween.bounce(gui:FindFirstChild("Objective") or skip, 1.25, 0.35)
        end
        last = now
    end)
end

return TutorialController
