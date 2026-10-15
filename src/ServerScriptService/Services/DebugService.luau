-- Studio-only playtest hook, parented to the Main script as RocketDebug:
-- Invoke("fill", fraction) adds that share of the current phase's requirement;
-- Invoke("cycle", n) jumps to cycle n while building; Invoke("tutorial", step?)
-- restarts every player's tutorial (at Pickup by default) and clears seen callouts;
-- Invoke("coins", n) sets everyone's coins; Invoke("upgrades") clears everyone's upgrades.
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
        elseif action == "tutorial" then
            for _, record in ctx.profiles.records do
                record.profile.tutorialStep, record.profile.seenCallouts = value or "Pickup", {}
            end
            Cycle.broadcast()
        elseif action == "coins" or action == "upgrades" then
            for _, record in ctx.profiles.records do
                if action == "coins" then record.profile.coins = value or 0 else record.profile.upgrades = {} end
            end
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Stats.update(player) end
            Cycle.broadcast()
        end
        rocket = Cycle.rocket
        return rocket.cycleNumber, rocket.phase, rocket.totals.Metal, rocket.totals.Fuel
    end
    debugHook.Parent = parent
end
return Debug
