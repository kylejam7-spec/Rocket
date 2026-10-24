-- The SpaceX Gym's show (WorldService builds it; all local to this client, and only
-- while the camera is near the District):
-- - chase lights (tag SpaceXChase, by Index) run round the hall's edge;
-- - two searchlights (SpaceXSearchlight: Base, Side) sweep the sky;
-- - the display vehicles test-fire their engines in turn (SpaceXEngine: Flame and Smoke
--   emitters and a FireLight that flickers while they burn);
-- - the hologram rocket (SpaceXHologram: Center) turns and bobs over the hall;
-- - a glint runs across the ★ EXCLUSIVE ★ banner (SpaceXShine).
-- An owner walking into the hall gets a burst of sparkles round their feet and a chime.
-- Floor glows and pillar feet pulse through PlanetController (tag Pulse).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Sfx = require(UI.Sfx)
local SpaceXGymController = {}

-- Studs from the hall's centre the camera must be within: the searchlights and engine
-- fires show across the site; the chase lights, hologram and banner only up close.
local FAR, NEAR = 700, 300
local CHASE_SPEED, CHASE_GAP, CHASE_LIT = 14, 7, 3 -- lights a second, cycle length, lit per cycle
local FIRE_EVERY, FIRE_FOR = 6, 2.6

function SpaceXGymController.start()
    local player = Players.LocalPlayer
    local owned = false
    State.subscribe(function(state)
        owned = state.shop and state.shop.owned and state.shop.owned[Config.SpaceXGym.key] == true or false
    end)
    local holoBase = {}
    local inside = false
    local function hall()
        for _, bay in CollectionService:GetTagged("GymBay") do
            if bay:GetAttribute("PaidOnly") then return bay end
        end
        return nil
    end
    -- Sparkles bursting round the owner's feet as they step in.
    local function welcome(root)
        local spot = Instance.new("Part")
        spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch, spot.Transparency = true, false, false, false, 1
        spot.Size = Vector3.new(4, 0.2, 4)
        spot.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0))
        local burst = Instance.new("ParticleEmitter")
        burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        burst.Color = ColorSequence.new(Color3.fromRGB(70, 160, 255), Color3.fromRGB(255, 210, 90))
        burst.LightEmission, burst.LightInfluence = 1, 0
        burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
        burst.Lifetime = NumberRange.new(0.8, 1.3)
        burst.Speed = NumberRange.new(10, 16)
        burst.SpreadAngle = Vector2.new(80, 80)
        burst.EmissionDirection = Enum.NormalId.Top
        burst.Acceleration = Vector3.new(0, -14, 0)
        burst.Drag = 1.5
        burst.Enabled = false
        burst.Parent = spot
        spot.Parent = workspace
        burst:Emit(60)
        Sfx.play("levelup", { volume = 2.5 })
        task.delay(2, function() spot:Destroy() end)
    end

    local fireStarted, fireIndex = -math.huge, 0
    RunService.RenderStepped:Connect(function()
        local bay = hall()
        local camera = workspace.CurrentCamera
        local away = bay and camera and (camera.CFrame.Position - bay.Position).Magnitude or math.huge
        if away > FAR then return end
        local now = os.clock()
        local close = away <= NEAR
        if close then
            for _, light in CollectionService:GetTagged("SpaceXChase") do
                local phase = ((light:GetAttribute("Index") or 0) - now * CHASE_SPEED) % CHASE_GAP
                local transparency = phase < CHASE_LIT and 0 or 0.75
                if light.Transparency ~= transparency then light.Transparency = transparency end
            end
        end
        for _, lamp in CollectionService:GetTagged("SpaceXSearchlight") do
            local base, side = lamp:GetAttribute("Base"), lamp:GetAttribute("Side") or 1
            local sweep = now * 0.55 + (side > 0 and math.pi or 0)
            local direction = Vector3.new(math.sin(sweep) * 0.75 + side * 0.25, 1, math.cos(sweep * 0.8) * 0.6 + 0.3)
            lamp.CFrame = CFrame.lookAt(base, base + direction)
        end
        for _, model in close and CollectionService:GetTagged("SpaceXHologram") or {} do
            local center = model:GetAttribute("Center")
            holoBase[model] = holoBase[model] or CFrame.new(center):Inverse() * model:GetPivot()
            model:PivotTo(CFrame.new(center + Vector3.new(0, math.sin(now * 1.3) * 0.9, 0)) * CFrame.Angles(0, now * 0.9, 0) * holoBase[model])
        end
        for _, shine in close and CollectionService:GetTagged("SpaceXShine") or {} do
            shine.Offset = Vector2.new((now * 0.6) % 2.6 - 1.3, 0)
        end
        -- Engine test fires, one vehicle at a time.
        local engines = CollectionService:GetTagged("SpaceXEngine")
        -- In a fixed order (west first): GetTagged's order isn't promised.
        table.sort(engines, function(a, b) return a.Position.X < b.Position.X end)
        if #engines > 0 then
            if now - fireStarted > FIRE_EVERY then
                fireStarted, fireIndex = now, fireIndex % #engines + 1
            end
            for index, engine in engines do
                local burning = index == fireIndex and now - fireStarted < FIRE_FOR
                local flame, smoke, light = engine:FindFirstChild("Flame"), engine:FindFirstChild("Smoke"), engine:FindFirstChild("FireLight")
                if flame then flame.Enabled = burning end
                if smoke then smoke.Enabled = burning end
                if light then light.Brightness = burning and 3 + math.random() * 3 or 0 end
            end
        end
        -- The owner's welcome, once per visit.
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local here = false
        if root then
            local at = bay.CFrame:PointToObjectSpace(root.Position)
            here = math.abs(at.X) <= bay.Size.X / 2 and math.abs(at.Z) <= bay.Size.Z / 2 and at.Y > -2 and at.Y < 12
        end
        if here and not inside and owned then welcome(root) end
        inside = here
    end)
end

return SpaceXGymController
