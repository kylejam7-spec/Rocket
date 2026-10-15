-- Studio-only playtest hook, parented to the Main script as RocketDebug:
-- Invoke("fill", fraction) adds that share of the current phase's requirement;
-- Invoke("cycle", n) jumps to cycle n while building.
local RunService = game:GetService("RunService")
local Rocket = require(script.Parent.RocketService)
local Debug = {}

function Debug.new(ctx, parent)
    if not RunService:IsStudio() then return end
    local Cycle = ctx.Cycle
    local debugHook = Instance.new("BindableFunction")
    debugHook.Name = "RocketDebug"
    debugHook.OnInvoke = function(action, value)
        local rocket = Cycle.rocket
        local material = Rocket.PhaseMaterial[rocket.phase]
        if action == "fill" and material then
            local amount = math.max(1, math.ceil(rocket.required[material] * (value or 1)))
            rocket.cargo[0] = { count = amount, materials = { [material] = amount } }
            local _, advanced = rocket:deliver(0)
            rocket.cargo[0] = nil
            ctx.Cargo.delivered(advanced)
        elseif action == "cycle" and material then
            Cycle.replace(Rocket.new(ctx.config, Cycle.newId(), value, rocket.programRuns))
            Cycle.broadcast()
        end
        rocket = Cycle.rocket
        return rocket.cycleNumber, rocket.phase, rocket.totals.Metal, rocket.totals.Fuel
    end
    debugHook.Parent = parent
end
return Debug
