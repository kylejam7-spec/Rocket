-- Studio-only playtest hook, parented to the Main script as RocketDebug:
-- Invoke("fill", fraction) adds that share of the current phase's requirement;
-- Invoke("mission", n or id) swaps in that mission while building; Invoke("misses", n) sets
-- the wheel's pity counter; Invoke("tutorial", step?)
-- restarts every player's tutorial (at Pickup by default) and clears seen callouts;
-- Invoke("coins", n) sets everyone's coins; Invoke("upgrades") clears everyone's upgrades;
-- Invoke("stats", strength, speed) sets everyone's trained points (destination bonuses kept);
-- Invoke("launches", n) sets everyone's completed launches (gym tier unlocks);
-- Invoke("ufo", tier, seconds) gives everyone another UFO of that tier (rolled as bought)
-- landing in `seconds` (10 by default); Invoke("pets", count) gives everyone `count`
-- (1) of every pet; Invoke("nopets") clears everyone's pets and UFO.
-- Shop (before the dashboard IDs exist): Invoke("own", key, on) gives (or with false
-- takes) everyone that Game Pass; Invoke("receipt", key, purchaseId) runs a product
-- receipt for the first player through the real journal path and returns its outcome.
-- Invoke("board") puts everyone in the rocket's cabin (during boarding, they fly).
local RunService = game:GetService("RunService")
local Rocket = require(script.Parent.RocketService)
local Missions = require(game:GetService("ReplicatedStorage").Shared.Missions)
local Pets = require(game:GetService("ReplicatedStorage").Shared.Pets)
local Debug = {}

function Debug.new(ctx, parent)
    if not RunService:IsStudio() then return end
    local Cycle = ctx.Cycle
    local debugHook = Instance.new("BindableFunction")
    debugHook.Name = "RocketDebug"
    debugHook.OnInvoke = function(action, value, extra)
        local rocket = Cycle.rocket
        local material = Rocket.PhaseMaterial[rocket.phase]
        if action == "fill" and material then
            local amount = math.max(1, math.ceil(rocket.required[material] * (value or 1)))
            rocket.cargo[0] = { count = amount, materials = { [material] = amount } }
            local _, advanced = rocket:deliver(0)
            rocket.cargo[0] = nil
            ctx.Cargo.delivered(advanced)
        elseif action == "mission" and material then
            -- value: mission index (1 Moon .. 5 Black Hole) or id ("Europa").
            local index = Missions.index(value) or value
            Cycle.replace(Rocket.new(ctx.config, Cycle.newId(), index, rocket.launches))
            Cycle.broadcast()
        elseif action == "misses" then
            Cycle.misses = value or 0 -- pity counter, e.g. 4 makes the next spin Rare or better
            Cycle.broadcast()
        elseif action == "tutorial" then
            for _, record in ctx.profiles.records do
                record.profile.tutorialStep, record.profile.seenCallouts = value or "Pickup", {}
            end
            Cycle.broadcast()
        elseif action == "coins" or action == "upgrades" or action == "stats" or action == "launches" then
            for _, record in ctx.profiles.records do
                local profile = record.profile
                if action == "coins" then profile.coins = value or 0
                elseif action == "stats" then profile.strengthLevel, profile.speedLevel = value or 0, extra or value or 0
                elseif action == "launches" then profile.completedLaunches = value or 0
                else profile.upgrades = {} end
            end
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Stats.update(player) end
            Cycle.broadcast()
        elseif action == "ufo" or action == "pets" or action == "nopets" then
            local random = Random.new()
            for _, record in ctx.profiles.records do
                local profile = record.profile
                if action == "ufo" then
                    local tier = value or 1
                    table.insert(profile.ufos, { id = "d" .. math.random(1e6), tier = tier, pet = Pets.roll(random, tier), remaining = extra or 10 })
                elseif action == "pets" then
                    for _, entry in Pets.Catalog do profile.pets[entry.Id] = value or 1 end
                else
                    profile.pets, profile.equippedPets, profile.ufos = {}, {}, {}
                end
            end
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Pets.refresh(player) end
            Cycle.broadcast()
        end
        if action == "board" then
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Movement.relocate(player, ctx.World.cabin.arrival) end
        elseif action == "own" then
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Shop.debugOwn(player, value, extra) end
        elseif action == "receipt" then
            local player = game:GetService("Players"):GetPlayers()[1]
            return player and ctx.Shop.debugReceipt(player, value, extra or Cycle.newId())
        end
        rocket = Cycle.rocket
        return rocket.definition.Id, rocket.phase, rocket.totals.Metal, rocket.totals.Fuel
    end
    debugHook.Parent = parent
end
return Debug
