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
-- takes) everyone that Game Pass for this session; Invoke("bought", key) runs a finished
-- Game Pass purchase for everyone (saved on their profiles, as a real one is);
-- Invoke("receipt", key, purchaseId) runs a product receipt for the first player
-- through the real journal path and returns its outcome.
-- Invoke("board") puts everyone in the rocket's cabin (during boarding, they fly).
-- Invoke("tp", position or cframe) puts everyone there.
-- Invoke("oarfish") starts Europa's oarfish breach now (seen by anyone at Europa).
-- Invoke("crash") starts Saturn's UFO crash now (seen by anyone at Saturn; it stays down
-- until the stay ends). Not "ufo": that one gives everyone a pet UFO.
-- Invoke("storm") starts Mars's dust storm now (seen by anyone at Mars).
-- Invoke("friends", n) gives everyone a friend boost as if n friends were here (nil: real).
-- Invoke("launch", destination, { countdown = s, stay = s }) flies everyone to a
-- destination now: from Building or Fueling it swaps in that mission (index 1..5 or id:
-- "Moon", "Mars", "Europa", "Saturn", "BlackHole"), finishes the build and fuel, puts
-- every player in the cabin and launches after `countdown` (5 s); `stay` shortens the
-- reward stay (at least 12 s, so the wheel still spins). In Studio chat:
-- /launch blackhole [countdown] [stay].
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
        local function fill(fraction)
            local amount = math.max(1, math.ceil(rocket.required[material] * fraction))
            rocket.cargo[0] = { count = amount, materials = { [material] = amount } }
            local _, advanced = rocket:deliver(0)
            rocket.cargo[0] = nil
            ctx.Cargo.delivered(advanced)
        end
        if action == "fill" and material then
            fill(value or 1)
        elseif action == "launch" and material then
            local index = Missions.index(value) or tonumber(value) or rocket.definition.Number
            for number = 1, Missions.Count do
                if type(value) == "string" and Missions.get(number).Id:lower() == (value:lower():gsub("%s", "")) then index = number end
            end
            Missions.get(index) -- errors on an unknown destination
            if index ~= rocket.definition.Number or rocket.phase ~= "Building" then
                Cycle.replace(Rocket.new(ctx.config, Cycle.newId(), index, rocket.launches))
                rocket = Cycle.rocket
            end
            local options = type(extra) == "table" and extra or {}
            ctx.Launch.debug = { countdown = options.countdown or 5, stay = options.stay and math.max(12, options.stay) }
            for _ = 1, 2 do
                material = Rocket.PhaseMaterial[rocket.phase]
                if material then fill(1) end
            end
            local cabin = ctx.World.cabin
            for slot, player in game:GetService("Players"):GetPlayers() do
                ctx.Movement.relocate(player, cabin.arrival + Vector3.new((slot % 4) * 2 - 3, 0, (slot // 4) * 2))
            end
            Cycle.broadcast()
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
        elseif action == "tp" then
            -- Place everyone at a Vector3 or CFrame (the move check accepts it).
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Movement.relocate(player, value) end
        elseif action == "own" then
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Shop.debugOwn(player, value, extra) end
        elseif action == "oarfish" then
            ctx.World.destinations[3].folder:SetAttribute("OarfishAt", workspace:GetServerTimeNow())
        elseif action == "crash" then
            ctx.World.destinations[4].folder:SetAttribute("UfoAt", workspace:GetServerTimeNow())
        elseif action == "friends" then
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Friends.setDebug(player, value) end
        elseif action == "storm" then
            ctx.World.destinations[2].folder:SetAttribute("StormAt", workspace:GetServerTimeNow())
        elseif action == "bought" then
            for _, player in game:GetService("Players"):GetPlayers() do ctx.Shop.passBought(player, value) end
        elseif action == "receipt" then
            local player = game:GetService("Players"):GetPlayers()[1]
            return player and ctx.Shop.debugReceipt(player, value, extra or Cycle.newId())
        end
        rocket = Cycle.rocket
        return rocket.definition.Id, rocket.phase, rocket.totals.Metal, rocket.totals.Fuel
    end
    debugHook.Parent = parent
    -- /launch <destination> [countdown] [stay] in Studio chat.
    local command = Instance.new("TextChatCommand")
    command.Name, command.PrimaryAlias = "RocketLaunchCommand", "/launch"
    command.Triggered:Connect(function(_, text)
        local words = string.split(text, " ")
        local ok, result = pcall(debugHook.Invoke, debugHook, "launch", words[2] or "Moon",
            { countdown = tonumber(words[3]), stay = tonumber(words[4]) })
        if not ok then warn("/launch: " .. tostring(result)) end
    end)
    command.Parent = game:GetService("TextChatService")
end
return Debug
