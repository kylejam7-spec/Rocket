--[[
    The Black Hole, made threatening, for whoever stands on its shard:
    - While there: the hole swells through the stay (horizon, disk and lensed halo grow
      about its centre), the light drains and tints violet, a low drone rises, the
      ground trembles every few seconds (harder and more often as the stay runs out)
      and lightning cracks off the horizon.
    - The singularity: when the server stamps SingularityAt on the destination folder
      (LaunchService, just after the wheel stops), everyone is pulled in: the hole
      balloons, every character spirals into it shrinking, the camera is dragged after
      them with the view stretching, then a white flash and black. The server moves
      everyone to spawn as it ends; the black lifts once this player is home.
    All local: characters are hidden and stand-in copies fall in; the server's parts are
    only rescaled on this client.
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
local SINGULARITY = 4 -- LaunchService.SingularitySeconds
local PULL = 3 -- seconds of the pull before the flash
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

-- Stand-in copies of every character on the shard, the originals hidden.
local function standIns()
    local copies = {}
    for _, other in Players:GetPlayers() do
        local character = other.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position - SPEC.position).Magnitude < NEAR then
            character.Archivable = true
            local copy = character:Clone()
            for _, item in copy:GetDescendants() do
                if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Sound") or item:IsA("ModuleScript") then
                    item:Destroy()
                elseif item:IsA("BasePart") then
                    item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false
                end
            end
            local humanoid = copy:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
            copy.Parent = Workspace.CurrentCamera
            table.insert(copies, { model = copy, original = character, start = copy:GetPivot(), spin = math.random() * 6 })
        end
    end
    return copies
end

local function hide(character, hidden)
    for _, item in character:GetDescendants() do
        if item:IsA("BasePart") or item:IsA("Decal") then item.LocalTransparencyModifier = hidden and 1 or 0 end
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
    screen = Instance.new("ScreenGui")
    screen.Name, screen.IgnoreGuiInset, screen.DisplayOrder, screen.ResetOnSpawn = "Singularity", true, 50, false
    local cover = Instance.new("Frame")
    cover.Size, cover.BackgroundColor3, cover.BackgroundTransparency, cover.BorderSizePixel = UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1, 0
    cover.Parent = screen
    screen.Parent = player:WaitForChild("PlayerGui")
    local copies = standIns()
    local startScale = scale
    local whoosh = sound("game/liftoff", 0.45, 1.4)
    whoosh:Play()
    local boomed = false
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = Workspace:GetServerTimeNow() - at
        local p = math.clamp(elapsed / PULL, 0, 1)
        local e = p ^ 2.2
        setScale(startScale + 1.6 * e)
        for _, copy in copies do
            hide(copy.original, true)
            local offset = copy.start.Position - hole
            local turned = CFrame.fromAxisAngle(Vector3.yAxis, e * math.pi * 3) * offset * (1 - 0.97 * e)
            copy.model:PivotTo(CFrame.new(hole + turned) * copy.start.Rotation * CFrame.Angles(e * 9 + copy.spin, e * 5, e * 7))
            copy.model:ScaleTo(math.max(0.05, 1 - 0.95 * e))
        end
        local camOffset = CFrame.fromAxisAngle(Vector3.yAxis, e * math.pi * 1.5) * (cameraStart.Position - hole) * (1 - 0.85 * e)
        local shake = (0.4 + 6 * e) * (Settings.get("reducedEffects") and 0.2 or 1)
        camera.CFrame = CFrame.lookAt(hole + camOffset, hole) * CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
        camera.FieldOfView = fieldOfView + 50 * e
        grade.Saturation, grade.Contrast = -0.45 - 0.55 * e, 0.25 + 0.6 * e
        grade.TintColor = Color3.new(1, 1, 1):Lerp(VIOLET, 0.3 + 0.5 * e)
        blur.Size = 24 * e
        drone.Volume, drone.PlaybackSpeed = 0.6 + e, 0.22 + 0.5 * e
        -- The flash, then black.
        if elapsed > PULL then
            local f = math.clamp((elapsed - PULL) / 0.35, 0, 1)
            cover.BackgroundTransparency = 1 - f
            cover.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), math.clamp((elapsed - PULL - 0.4) / 0.4, 0, 1))
            if not boomed then
                boomed = true
                local boom = sound("game/ignition", 0.35, 1.6)
                boom:Play()
                task.delay(4, boom.Destroy, boom)
            end
        end
    end)
    -- Hold black until the server has moved this player home (or a moment past the end).
    local deadline = os.clock() + SINGULARITY + 3
    repeat task.wait(0.1) until (os.clock() > deadline) or (Workspace:GetServerTimeNow() - at > SINGULARITY and not there())
    connection:Disconnect()
    whoosh:Destroy()
    for _, copy in copies do
        copy.model:Destroy()
        if copy.original.Parent then hide(copy.original, false) end
    end
    clearGrade()
    camera.FieldOfView = fieldOfView
    camera:SetAttribute("Cinematic", nil)
    camera.CameraType = Enum.CameraType.Custom
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
