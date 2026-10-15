-- Wiring only. Each service is built with the shared context `ctx` and reaches the
-- others through it at call time, so order matters for construction, not for calls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    if player then ctx.Stats.update(player); ctx.Cycle.send(player) end
end)
ctx.Launch = require(Services.LaunchService).new(ctx)
ctx.Cargo = require(Services.CargoService).new(ctx)
require(Services.DebugService).new(ctx, script)
ctx.Training = require(Services.TrainingService).new({
    players = Players, config = Config, profiles = ctx.profiles, remotes = ctx.Remote.folder,
    prompt = ctx.World.prompt, allowed = ctx.Interaction.allowed, near = ctx.Interaction.near,
    body = ctx.Movement.body, relocate = ctx.Movement.relocate, feedback = ctx.Remote.feedback,
    changed = function(player) ctx.Stats.update(player); ctx.Cycle.send(player) end,
    phaseAllowed = function()
        local phase = ctx.Cycle.rocket.phase
        return phase == "Building" or phase == "Fueling" or phase == "Boarding"
    end,
    stations = ctx.World.stations,
})

local function joined(player)
    ctx.Stats.attach(player)
    local function characterAdded(character)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or player.Character ~= character then return end
        ctx.Movement.track(player, root, 1)
        ctx.Stats.update(player)
        ctx.Cargo.visual(player)
        ctx.Launch.characterAdded(player)
    end
    player.CharacterAdded:Connect(characterAdded)
    if player.Character then task.spawn(characterAdded, player.Character) end
    ctx.profiles:load(player.UserId)
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
