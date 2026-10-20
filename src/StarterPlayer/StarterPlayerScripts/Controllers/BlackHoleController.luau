--[[
    The Black Hole, made threatening, for whoever stands on its shard:
    - While there: the hole swells through the stay (horizon, disk and lensed halo grow
      about its centre), the light drains and tints violet, a low drone rises, the
      ground trembles every few seconds (harder and more often as the stay runs out)
      and lightning cracks off the horizon.
    - The singularity: when the server stamps SingularityAt on the destination folder
      (LaunchService, just after the wheel stops), the HUD and wheel go, the hole
      balloons and drags in the landed rocket, tumbling, then the whole shard with
      everyone on it, the camera riding it down with the view stretching, then a white
      flash and black. The server moves everyone to spawn as it ends; the black lifts
      once this player is home and the shard is put back.
    All local: the server holds the passengers' roots still, and only this client moves
    the shard, the rocket and the characters (so no anti-teleport snap).
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local SoundIds = require(ReplicatedStorage.Shared.SoundIds)
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local BlackHoleController = {}

local SPEC = Config.Destinations[5]
local NEAR = 900 -- studs from the shard's centre that count as "there"
-- The singularity's timeline, seconds from SingularityAt (LaunchService holds the reset
-- for SingularityLength = LENGTH): the rocket falls in first, then the shard.
local ROCKET_END, ISLAND_START, ISLAND_END, LENGTH = 2.6, 1.8, 6.4, 7.5
local ISLAND_RADIUS = 320 -- the shard and everything on it
local GROWTH = 0.25 -- how much the hole swells over a whole stay
local VIOLET = Color3.fromRGB(205, 150, 255)

local player = Players.LocalPlayer
local hole, holeParts, folder = nil, {}, nil
local grade, blur, screen, drone, scale = nil, nil, nil, nil, 1
local shakeUntil, shakePower, nextTremor, nextBolt = 0, 0, 0, 0
local inSingularity = false

local function sound(file, speed, volume, looped)
    local s = Instance.new("Sound")
    s.SoundId = SoundIds[file] or ""
    s.PlaybackSpeed, s.Volume, s.Looped = speed, volume, looped == true
    s.Parent = SoundService
    return s
end

local function rootPosition()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

local function there()
    local at = rootPosition()
    return at ~= nil and (at - SPEC.position).Magnitude < NEAR
end

-- Finds the hole's parts (once the destination has replicated) and remembers their
-- unscaled frames, so any scale is applied from the original.
local function findHole()
    if hole then return true end
    local destinations = Workspace:FindFirstChild("RocketWorld") and Workspace.RocketWorld:FindFirstChild("Destinations")
    folder = destinations and destinations:FindFirstChild(SPEC.id)
    local horizon = folder and folder:FindFirstChild("EventHorizon")
    if not horizon then return false end
    hole = horizon.Position
    table.insert(holeParts, { part = horizon, size = horizon.Size, cframe = horizon.CFrame })
    for _, name in { "AccretionDisk", "Lensing" } do
        local model = folder:FindFirstChild(name)
        for _, part in model and model:GetChildren() or {} do
            if part:IsA("BasePart") then table.insert(holeParts, { part = part, size = part.Size, cframe = part.CFrame }) end
        end
    end
    folder:GetAttributeChangedSignal("SingularityAt"):Connect(function()
        local at = folder:GetAttribute("SingularityAt")
        if at and not inSingularity and there() then task.spawn(BlackHoleController.singularity, at) end
    end)
    return true
end

local function setScale(k)
    if math.abs(k - scale) < 0.002 then return end
    scale = k
    for _, entry in holeParts do
        entry.part.Size = entry.size * k
        entry.part.CFrame = CFrame.new(hole + (entry.cframe.Position - hole) * k) * entry.cframe.Rotation
    end
end

local function ensureGrade()
    if grade then return end
    grade = Instance.new("ColorCorrectionEffect")
    grade.Name = "BlackHoleGrade"
    grade.Parent = Lighting
    blur = Instance.new("BlurEffect")
    blur.Name, blur.Size = "BlackHoleBlur", 0
    blur.Parent = Lighting
    drone = sound("game/engine", 0.22, 0, true)
    drone:Play()
end

local function clearGrade()
    if grade then grade:Destroy() blur:Destroy() drone:Destroy() end
    grade, blur, drone = nil, nil, nil
    setScale(1)
end

-- A crack of lightning off the horizon toward a random point: jagged neon segments
-- that flicker out.
local function bolt()
    local camera = Workspace.CurrentCamera
    local towards = (camera.CFrame.Position - hole).Unit
    local direction = (towards + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6).Unit
    local from = hole + direction * 210 * scale
    local to = from + direction * math.random(250, 600) + Vector3.new(math.random(-120, 120), math.random(-120, 120), math.random(-120, 120))
    local model = Instance.new("Model")
    local previous = from
    for step = 1, 7 do
        local point = from:Lerp(to, step / 7) + (step < 7 and Vector3.new(math.random(-40, 40), math.random(-40, 40), math.random(-40, 40)) or Vector3.zero)
        local segment = Instance.new("Part")
        segment.Anchored, segment.CanCollide, segment.CanQuery, segment.CanTouch, segment.CastShadow = true, false, false, false, false
        segment.Material, segment.Color = Enum.Material.Neon, Color3.fromRGB(225, 200, 255)
        segment.Size = Vector3.new(3, 3, (point - previous).Magnitude)
        segment.CFrame = CFrame.lookAt((previous + point) / 2, point)
        segment.Parent = model
        previous = point
    end
    model.Parent = camera
    task.delay(0.07, function() model.Parent = nil end)
    task.delay(0.13, function() model.Parent = camera end)
    task.delay(0.22, function() model:Destroy() end)
end

local function shakeCamera()
    if inSingularity or os.clock() > shakeUntil or Settings.get("reducedEffects") then return end
    local camera = Workspace.CurrentCamera
    local fade = (shakeUntil - os.clock())
    local amount = shakePower * math.clamp(fade, 0, 1)
    camera.CFrame *= CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
        * CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * amount * 2))
end

-- Every frame while this player is on the shard and no singularity is running.
local function ambient(dt)
    if inSingularity then return end
    if not there() then
        if grade then clearGrade() end
        return
    end
    ensureGrade()
    local state = State.get()
    local progress = 0
    if state and state.destinationTier == 5 and state.phase == "Rewarding" and state.deadline > 0 then
        progress = math.clamp(1 - (state.deadline - Workspace:GetServerTimeNow()) / Config.RewardSeconds, 0, 1)
    end
    setScale(1 + GROWTH * progress)
    grade.Saturation, grade.Contrast = -0.2 - 0.25 * progress, 0.1 + 0.15 * progress
    grade.TintColor = Color3.new(1, 1, 1):Lerp(VIOLET, 0.12 + 0.18 * progress)
    drone.Volume = 0.25 + 0.35 * progress
    local now = os.clock()
    if now > nextTremor then
        shakePower = 0.25 + 0.9 * progress
        shakeUntil = now + 0.6 + progress
        nextTremor = now + math.random(30, 70) / 10 * (1 - 0.55 * progress)
        local rumble = sound("game/engine", 0.3 + math.random() * 0.1, 0.5 + progress, false)
        rumble:Play()
        task.delay(2, rumble.Destroy, rumble)
    end
    if now > nextBolt and not Settings.get("reducedEffects") then
        nextBolt = now + math.random(15, 40) / 10 * (1 - 0.5 * progress)
        bolt()
    end
end

-- Everything that falls in, gathered at the start: the landed rocket's parts, and the
-- shard's (every anchored part of RocketWorld within ISLAND_RADIUS of the centre:
-- the shard, its kit, gyms, shop, signs), each with its frame now.
local function gather()
    local rocket, island = { parts = {}, frames = {} }, { parts = {}, frames = {} }
    local landed = folder:FindFirstChild("LandedRocket")
    local function add(group, part)
        table.insert(group.parts, part)
        table.insert(group.frames, part.CFrame)
    end
    for _, part in landed and landed:GetDescendants() or {} do
        if part:IsA("BasePart") then add(rocket, part) end
    end
    for _, part in Workspace.RocketWorld:GetDescendants() do
        if part:IsA("BasePart") and part.Anchored and not (landed and part:IsDescendantOf(landed))
            and (part.Position - SPEC.position).Magnitude < ISLAND_RADIUS then
            add(island, part)
        end
    end
    return rocket, island, landed and landed:GetPivot().Position or SPEC.position
end

-- Where something at `frame` is once a fall `e` (0..1) has carried it toward the hole:
-- its group's pivot spirals in (about the hole, shrinking in radius) and tumbles.
local function falling(pivot, e, tumble)
    local offset = CFrame.fromAxisAngle(Vector3.yAxis, e * math.pi * 1.2) * (pivot - hole) * (1 - e)
    return CFrame.new(hole + offset) * CFrame.Angles(e * tumble.X, e * tumble.Y, e * tumble.Z) * CFrame.new(-pivot)
end

local function move(group, motion)
    local frames = table.create(#group.parts)
    for index, frame in group.frames do frames[index] = motion * frame end
    Workspace:BulkMoveTo(group.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Every ScreenGui but the singularity's own stays off while it runs (the wheel, the
-- HUD, toasts); the ones that were on come back after.
local function hideScreens(hidden)
    for _, gui in player.PlayerGui:GetChildren() do
        if gui:IsA("ScreenGui") and gui.Name ~= "Singularity" and gui.Enabled then
            hidden[gui] = true
            gui.Enabled = false
        end
    end
end

function BlackHoleController.singularity(at)
    if not findHole() then return end
    inSingularity = true
    ensureGrade()
    local camera = Workspace.CurrentCamera
    local cameraStart, fieldOfView = camera.CFrame, camera.FieldOfView
    -- CameraController steps aside while the camera is Cinematic (as for the launch ride).
    camera:SetAttribute("Cinematic", true)
    camera.CameraType = Enum.CameraType.Scriptable
    local hidden = {}
    screen = Instance.new("ScreenGui")
    screen.Name, screen.IgnoreGuiInset, screen.DisplayOrder, screen.ResetOnSpawn = "Singularity", true, 50, false
    local cover = Instance.new("Frame")
    cover.Size, cover.BackgroundColor3, cover.BackgroundTransparency, cover.BorderSizePixel = UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1, 0
    cover.Parent = screen
    screen.Parent = player.PlayerGui
    local rocket, island, rocketPivot = gather()
    local center = SPEC.position
    -- The characters ride the shard: their roots are held still by the server, so moving
    -- them here is only what this player sees (no anti-teleport snap).
    local riders = {}
    for _, other in Players:GetPlayers() do
        local character = other.Character
        if character and character.PrimaryPart and (character:GetPivot().Position - center).Magnitude < ISLAND_RADIUS then
            table.insert(riders, { model = character, frame = character:GetPivot() })
        end
    end
    local startScale = scale
    local whoosh = sound("game/liftoff", 0.45, 1.4)
    whoosh:Play()
    local groan = sound("game/engine", 0.15, 1.2)
    local boomed, groaned = false, false
    local connection
    connection = RunService.RenderStepped:Connect(function()
        hideScreens(hidden)
        local elapsed = Workspace:GetServerTimeNow() - at
        local total = math.clamp(elapsed / ISLAND_END, 0, 1)
        setScale(startScale + 1.4 * total ^ 1.5)
        -- The rocket goes first, tumbling end over end.
        local r = math.clamp(elapsed / ROCKET_END, 0, 1) ^ 2.4
        if r > 0 and #rocket.parts > 0 then move(rocket, falling(rocketPivot, r, Vector3.new(7, 2, 4))) end
        -- Then the shard, everyone on it, and the camera with them.
        local i = math.clamp((elapsed - ISLAND_START) / (ISLAND_END - ISLAND_START), 0, 1) ^ 2.2
        local shardMotion = falling(center, i, Vector3.new(0.9, 0.5, 1.4))
        if i > 0 then
            if not groaned then
                groaned = true
                groan:Play()
            end
            move(island, shardMotion)
            for _, rider in riders do
                if rider.model.Parent then rider.model:PivotTo(shardMotion * rider.frame) end
            end
        end
        -- Camera: watches the rocket go, then rides the shard down looking into the hole.
        local ride = shardMotion * cameraStart
        local gaze = shardMotion * (cameraStart.Position + cameraStart.LookVector * 60)
        local turn = math.min(1, elapsed / 1.5) * 0.7 + 0.3 * i
        local shake = (0.3 + 4 * i + 1.2 * r * (1 - i)) * (Settings.get("reducedEffects") and 0.2 or 1)
        camera.CFrame = CFrame.lookAt(ride.Position, gaze:Lerp(hole, turn))
            * CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
        camera.FieldOfView = fieldOfView + 50 * i
        local e = math.max(total ^ 1.5, i)
        grade.Saturation, grade.Contrast = -0.45 - 0.55 * e, 0.25 + 0.6 * e
        grade.TintColor = Color3.new(1, 1, 1):Lerp(VIOLET, 0.3 + 0.5 * e)
        blur.Size = 20 * i
        drone.Volume, drone.PlaybackSpeed = 0.6 + e, 0.22 + 0.5 * e
        -- The flash as the shard crosses the horizon, then black.
        if elapsed > ISLAND_END - 0.4 then
            local f = math.clamp((elapsed - ISLAND_END + 0.4) / 0.35, 0, 1)
            cover.BackgroundTransparency = 1 - f
            cover.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), math.clamp((elapsed - ISLAND_END) / 0.4, 0, 1))
            if not boomed then
                boomed = true
                local boom = sound("game/ignition", 0.35, 1.6)
                boom:Play()
                task.delay(4, boom.Destroy, boom)
            end
        end
    end)
    -- Hold black until the server has moved this player home, far from the shard (the ride
    -- itself only carries them ~2,000 studs here), or a moment past the end.
    local deadline = os.clock() + LENGTH + 3
    local function home()
        local position = rootPosition()
        return position ~= nil and (position - SPEC.position).Magnitude > 5000
    end
    repeat task.wait(0.1) until os.clock() > deadline or (Workspace:GetServerTimeNow() - at > ISLAND_END and home())
    connection:Disconnect()
    whoosh:Destroy()
    groan:Destroy()
    -- Put the shard and rocket back where they were (the server rebuilt nothing).
    for _, group in { rocket, island } do
        local parts, frames = {}, {}
        for index, part in group.parts do
            if part.Parent then
                table.insert(parts, part)
                table.insert(frames, group.frames[index])
            end
        end
        Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
    end
    clearGrade()
    camera.FieldOfView = fieldOfView
    camera:SetAttribute("Cinematic", nil)
    camera.CameraType = Enum.CameraType.Custom
    for gui in hidden do
        if gui.Parent then gui.Enabled = true end
    end
    cover.BackgroundColor3, cover.BackgroundTransparency = Color3.new(0, 0, 0), 0
    for step = 1, 20 do
        cover.BackgroundTransparency = step / 20
        task.wait(0.05)
    end
    screen:Destroy()
    inSingularity = false
end

function BlackHoleController.start()
    RunService.Heartbeat:Connect(function(dt)
        if not findHole() then return end
        ambient(dt)
    end)
    RunService:BindToRenderStep("BlackHoleTremor", Enum.RenderPriority.Camera.Value + 3, shakeCamera)
end

return BlackHoleController
