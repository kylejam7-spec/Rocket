-- Wiring only. Each service is built with the shared context `ctx` and reaches the
-- others through it at call time, so order matters for construction, not for calls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Characters spawn once the client's loading screen (ReplicatedFirst) reports the world
-- and its assets are in (ClientReady), so nobody drops through ground that hasn't
-- reached them yet. Set before anything yields, so the first player waits too.
Players.CharacterAutoLoads = false
-- A client that never reports (it errored, say) spawns after this many seconds anyway.
local LOAD_TIMEOUT = 45
local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent.Services
local Profiles = require(Services.ProfileService)

local ctx = { config = Config, players = Players }
ctx.Remote = require(Services.RemoteService).new(ctx)
ctx.World = require(Services.WorldService).new(ctx)
ctx.Movement = require(Services.MovementService).new(ctx)
ctx.Interaction = require(Services.InteractionService).new(ctx)
ctx.Stats = require(Services.StatsService).new(ctx)
ctx.Cycle = require(Services.CycleService).new(ctx)
ctx.profiles = Profiles.new(Config, function(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        ctx.Stats.update(player)
        if ctx.Pets then ctx.Pets.refresh(player) end
        ctx.Cycle.send(player)
    end
end)
ctx.Launch = require(Services.LaunchService).new(ctx)
ctx.Cargo = require(Services.CargoService).new(ctx)
ctx.Tutorial = require(Services.TutorialService).new(ctx)
ctx.Upgrades = require(Services.UpgradeService).new(ctx)
ctx.Robux = require(Services.RobuxUpgradeService).new(ctx)
ctx.Pets = require(Services.PetService).new(ctx)
ctx.Shop = require(Services.ShopService).new(ctx)
require(Services.DebugService).new(ctx, script)
ctx.Training = require(Services.TrainingService).new({
    players = Players, config = Config, profiles = ctx.profiles, remotes = ctx.Remote.folder,
    prompt = ctx.World.prompt, allowed = ctx.Interaction.allowed, near = ctx.Interaction.near,
    body = ctx.Movement.body, relocate = ctx.Movement.relocate, feedback = ctx.Remote.feedback,
    changed = function(player) ctx.Stats.update(player); ctx.Cycle.send(player) end,
    -- Reaching level 1 of that stat on a starter gym finishes the tutorial's bench and
    -- treadmill steps (5 s for a new player).
    -- Gym access passes unlock a District tier; a server boost multiplies every gain.
    unlocked = function(player, station) return ctx.Shop.gymUnlocked(player, station.tier) end,
    multiplier = function() return ctx.Shop.trainingMultiplier() end,
    trained = function(player, station)
        if (station.required or 0) > 0 then return end
        local strength, speed = ctx.Stats.levels(ctx.profiles.records[player.UserId].profile)
        local bench = station.stat == "strengthLevel"
        if (bench and strength or speed) >= 1 then ctx.Tutorial.observe(player, bench and "Bench" or "Treadmill") end
    end,
    -- Map gyms work while building, fueling and boarding; a destination's gym only
    -- while passengers are there.
    phaseAllowed = function(station)
        local rocket = ctx.Cycle.rocket
        if station and station.destination then
            return rocket.phase == "Rewarding" and rocket.definition.ModelTier == station.destination
        end
        return rocket.phase == "Building" or rocket.phase == "Fueling" or rocket.phase == "Boarding"
    end,
    stations = ctx.World.stations,
})

-- Spawns `player` if they have no character (ready, timeout and respawn all land here).
local spawning = {}
local function spawnCharacter(player)
    if spawning[player] or player.Character or player.Parent ~= Players then return end
    spawning[player] = true
    local ok, err = pcall(player.LoadCharacter, player)
    spawning[player] = nil
    if not ok then warn("Rocket: couldn't spawn", player.UserId, err) end
end
ctx.Remote.ClientReady.OnServerEvent:Connect(spawnCharacter)
-- The world is built: loading screens wait for this before preloading.
ctx.World.world:SetAttribute("Built", true)

local function joined(player)
    ctx.Stats.attach(player)
    task.delay(LOAD_TIMEOUT, spawnCharacter, player)
    local function characterAdded(character)
        -- Without CharacterAutoLoads there's no automatic respawn either.
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.Died:Once(function()
                task.delay(Players.RespawnTime, function()
                    if player.Character == character then
                        player.Character = nil
                        spawnCharacter(player)
                    end
                end)
            end)
        end
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or player.Character ~= character then return end
        ctx.Movement.track(player, root, 1, 1)
        ctx.Stats.update(player)
        ctx.Cargo.visual(player)
        ctx.Launch.characterAdded(player)
    end
    player.CharacterAdded:Connect(characterAdded)
    if player.Character then task.spawn(characterAdded, player.Character) end
    -- Robux upgrade passes live with Roblox; re-apply them once the profile is loaded.
    -- Shop passes too (gym access, pet slots, hatching, coins).
    if ctx.profiles:load(player.UserId) then
        task.spawn(ctx.Shop.sync, player)
        ctx.Robux.sync(player)
    end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    ctx.Cargo.forget(player)
    ctx.Training.stop(player)
    ctx.Cycle.rocket:forget(player.UserId)
    ctx.Launch.forget(player)
    ctx.Movement.forget(player)
    ctx.Interaction.forget(player)
    ctx.Remote.forget(player)
    ctx.Cycle.forget(player)
    ctx.profiles:remove(player.UserId)
end)
for _, player in Players:GetPlayers() do task.spawn(joined, player) end
ctx.Cycle.start()
ctx.profiles:start()
