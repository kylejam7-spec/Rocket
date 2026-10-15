-- Desktop mouse-look; Roblox retains its native touch/controller camera.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local CameraController = {}
local MIN_ZOOM, MAX_ZOOM, DEFAULT_ZOOM = 8, 24, 12
local SENSITIVITY = 0.003

function CameraController.start()
    local player = Players.LocalPlayer
    player.CameraMinZoomDistance = MIN_ZOOM
    player.CameraMaxZoomDistance = MAX_ZOOM
    local zoom, distance = DEFAULT_ZOOM, DEFAULT_ZOOM
    local yaw, pitch = 0, math.rad(-15)
    local active, cursorFree, focused = false, false, true
    local previousType
    local gui = Create.screen("CameraControls")
    local hint = StrokedText.new({
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -Theme.gutter, 1, -Theme.gutter),
        Size = UDim2.fromOffset(300, 30),
        BackgroundColor3 = Theme.color.Panel,
        BackgroundTransparency = 0.2,
        TextColor3 = Theme.color.White,
        Font = Theme.font.Body,
        TextSize = 13,
        Parent = gui,
    })
    local dot = Create.new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Theme.color.White,
        BorderSizePixel = 0,
        Parent = gui,
    })
    local function desktop()
        return Input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
    end
    local function released()
        return cursorFree or not focused or GuiService.MenuIsOpen or Input:GetFocusedTextBox() ~= nil
    end
    Input.InputBegan:Connect(function(input, processed)
        if not processed and desktop() and input.KeyCode == Enum.KeyCode.V then cursorFree = not cursorFree end
    end)
    Input.InputChanged:Connect(function(input, processed)
        if active and not released() and not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
            zoom = math.clamp(zoom - input.Position.Z * 2, MIN_ZOOM, MAX_ZOOM)
        end
    end)
    Input.WindowFocusReleased:Connect(function() focused = false end)
    Input.WindowFocused:Connect(function() focused = true end)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    local function restore(camera)
        if active then
            camera.CameraType = previousType or Enum.CameraType.Custom
            Input.MouseBehavior = Enum.MouseBehavior.Default
            Input.MouseIconEnabled = true
            active = false
        end
    end
    RunService:BindToRenderStep("RocketMouseCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
        local camera = workspace.CurrentCamera
        if not camera then return end
        -- LaunchEffectsController owns the camera while a passenger rides the rocket.
        if camera:GetAttribute("Cinematic") then return end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not desktop() or not root or not humanoid or humanoid.Health <= 0 then
            restore(camera)
            hint.Visible, dot.Visible = false, false
            return
        end
        if not active then
            previousType = camera.CameraType
            local look = camera.CFrame.LookVector
            yaw = math.atan2(-look.X, -look.Z)
            pitch = math.clamp(math.asin(look.Y), math.rad(-65), math.rad(80))
            active = true
        end
        camera.CameraType = Enum.CameraType.Scriptable
        local free = released()
        Input.MouseBehavior = free and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
        Input.MouseIconEnabled = free
        hint.Visible, dot.Visible = true, not free
        hint.Text = cursorFree and "V: resume mouse-look" or "Mouse: look  •  Scroll: zoom  •  V: cursor"
        if not free then
            local delta = Input:GetMouseDelta()
            yaw -= delta.X * SENSITIVITY
            pitch = math.clamp(pitch - delta.Y * SENSITIVITY, math.rad(-65), math.rad(80))
        end
        distance += (zoom - distance) * (1 - math.exp(-14 * dt))
        local focus = root.Position + Vector3.new(0, 2, 0)
        local direction = CFrame.fromOrientation(pitch, yaw, 0).LookVector
        params.FilterDescendantsInstances = { character }
        local offset = -direction * distance
        -- Ghost template panels don't obstruct the camera; completed hulls do.
        local hit = workspace:Spherecast(focus, 0.4, offset, params)
        if hit then offset = -direction * math.max(0.5, hit.Distance - 0.3) end
        camera.CFrame = CFrame.lookAt(focus + offset, focus)
        camera.Focus = CFrame.new(focus)
        script:SetAttribute("RequestedZoom", zoom)
    end)
    script.Destroying:Connect(function()
        RunService:UnbindFromRenderStep("RocketMouseCamera")
        if workspace.CurrentCamera then restore(workspace.CurrentCamera) end
        gui:Destroy()
    end)
end

return CameraController
