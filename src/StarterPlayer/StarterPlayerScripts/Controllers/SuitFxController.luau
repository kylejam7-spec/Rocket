--[[
    Animates the suits SkinService dresses, on this client only (every client runs its
    own copy, for everyone's suit):
      GalaxyStars  the galaxy suit's star field drifts slowly across the body and armour,
      SuitHalo     the galaxy halo and its orbs turn round the helmet (the weld's C0),
      SuitPulse    Neon glows (screens, lamps, gems, strips) breathe brighter and dimmer.
    Reduced effects stops the motion and leaves everything at rest.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Settings = require(script.Parent.Settings)
local SuitFxController = {}

local DRIFT_U, DRIFT_V = 0.35, 0.15 -- studs a second the star field slides
local HALO_SPIN = 0.6 -- radians a second
local PULSE_SPEED, PULSE_DEPTH = 2.2, 0.35 -- radians a second; how far it dims

function SuitFxController.start()
    -- Each halo's resting C0 and each glow's own colour, kept as they appear.
    local halos, pulses = {}, {}
    local function addHalo(part)
        local weld = part:WaitForChild("SuitWeld", 5)
        if weld then halos[part] = { weld = weld, rest = weld.C0 } end
    end
    local function addPulse(part)
        pulses[part] = { color = part.Color, phase = math.random() * math.pi * 2 }
    end
    for _, part in CollectionService:GetTagged("SuitHalo") do task.spawn(addHalo, part) end
    for _, part in CollectionService:GetTagged("SuitPulse") do addPulse(part) end
    CollectionService:GetInstanceAddedSignal("SuitHalo"):Connect(addHalo)
    CollectionService:GetInstanceAddedSignal("SuitPulse"):Connect(addPulse)
    CollectionService:GetInstanceRemovedSignal("SuitHalo"):Connect(function(part) halos[part] = nil end)
    CollectionService:GetInstanceRemovedSignal("SuitPulse"):Connect(function(part) pulses[part] = nil end)

    local clock = 0
    RunService.RenderStepped:Connect(function(dt)
        if Settings.get("reducedEffects") then return end
        clock += dt
        local u, v = (clock * DRIFT_U) % 4, (clock * DRIFT_V) % 4
        for _, texture in CollectionService:GetTagged("GalaxyStars") do
            texture.OffsetStudsU, texture.OffsetStudsV = u, v
        end
        for part, halo in halos do
            if part.Parent then
                -- Turn about the halo's own centre, tilted as built (its C0 already
                -- holds the tilt and the place over the head).
                halo.weld.C0 = halo.rest * CFrame.Angles(0, clock * HALO_SPIN, 0)
            end
        end
        for part, pulse in pulses do
            if part.Parent then
                local k = 1 - PULSE_DEPTH * (0.5 + 0.5 * math.sin(clock * PULSE_SPEED + pulse.phase))
                part.Color = Color3.new(pulse.color.R * k, pulse.color.G * k, pulse.color.B * k)
            end
        end
    end)
end

return SuitFxController
