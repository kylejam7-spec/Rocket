-- Per-delivery juice on the rocket, for anyone's delivery: a glowing shell pulses out
-- of the segment being filled and the BUILD HERE ring flashes wide. Driven by the
-- shared totals in State snapshots (already batched to <=4 a second by the server).
-- Effects are local parts; the server's rocket and ring are never touched.
local CollectionService = game:GetService("CollectionService")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Tween = require(UI.Tween)
local DeliveryFeedbackController = {}
local PULSE = { Metal = Color3.fromRGB(255, 220, 120), Fuel = Color3.fromRGB(255, 120, 190) }

-- A neon copy of `source` that grows to `size` and fades out.
local function flash(source, size, color, seconds)
    local shell = source:Clone()
    shell:ClearAllChildren()
    shell.Name = "DeliveryFlash"
    shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow = true, false, false, false, false
    shell.Material, shell.Color, shell.Transparency = Enum.Material.Neon, color, 0.2
    shell.Size = source.Size * 1.04
    shell.Parent = workspace.CurrentCamera
    Tween.play(shell, seconds, { Size = size, Transparency = 1 })
    task.delay(seconds, shell.Destroy, shell)
end

function DeliveryFeedbackController.start()
    local lastPulse = 0
    State.subscribe(function(state, previous)
        if not previous or state.cycle ~= previous.cycle or state.phase ~= previous.phase then return end
        local material = state.phase == "Building" and "Metal" or state.phase == "Fueling" and "Fuel" or nil
        if not material or state.totals[material] <= previous.totals[material] then return end
        local now = os.clock()
        if now - lastPulse < 0.2 then return end
        lastPulse = now
        local vehicle = workspace:FindFirstChild("RocketVehicle", true)
        local filling = vehicle and vehicle:FindFirstChild("Filling")
        if filling and filling:IsA("BasePart") then flash(filling, filling.Size * 1.25, PULSE[material], 0.45) end
        local ring = CollectionService:GetTagged("BuildFrontier")[1]
        -- The ring is a cylinder along X: widen Y/Z, keep it thin.
        if ring and ring.Transparency < 1 then flash(ring, ring.Size * Vector3.new(1, 1.6, 1.6), Color3.new(1, 1, 1), 0.4) end
    end)
end

return DeliveryFeedbackController
