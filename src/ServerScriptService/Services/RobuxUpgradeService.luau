-- Robux upgrade levels: one Game Pass per track per level (Config.RobuxUpgrades). Owning the
-- pass for level N means that track is at least level N, so a level bought with Robux can
-- never be lost: Roblox keeps the ownership and `sync` re-applies it on every join. The
-- client asks the server to open the prompt (BuyUpgradeRobux), which offers only the next
-- level's pass; a finished purchase raises the level at once. Coin levels continue from
-- there. RobuxCheck runs the pure parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local RobuxUpgradeService = {}

-- PassId -> { track, level } from the config.
function RobuxUpgradeService.passes(config)
    local map = {}
    for track, ids in config.RobuxUpgrades.passes do
        for level, id in ids do map[id] = { track = track, level = level } end
    end
    return map
end

-- Raises `track` to `level` (never lowers it). True when the level changed.
function RobuxUpgradeService.apply(config, profile, track, level)
    local spec = config.Upgrades[track]
    if not spec or type(level) ~= "number" then return false end
    level = math.min(level, spec.max)
    if Upgrades.level(profile, track) >= level then return false end
    profile.upgrades[track] = level
    return true
end

-- Applies the highest owned pass per track. owns(passId) may yield or error; a failed
-- check leaves that track alone (the next join retries). Returns the tracks raised.
function RobuxUpgradeService.sync(config, profile, owns)
    local raised = {}
    for _, track in config.UpgradeOrder do
        local ids = config.RobuxUpgrades.passes[track]
        for level = config.Upgrades[track].max, Upgrades.level(profile, track) + 1, -1 do
            local id = ids and ids[level]
            if id then
                local ok, owned = pcall(owns, id)
                if not ok then break end
                if owned then
                    if RobuxUpgradeService.apply(config, profile, track, level) then table.insert(raised, track) end
                    break
                end
            end
        end
    end
    return raised
end

function RobuxUpgradeService.new(ctx)
    local config = ctx.config
    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = ctx.players
    local passes = RobuxUpgradeService.passes(config)
    local prompting = {} -- userId -> os.clock() until which no new prompt opens
    local service = {}

    local function changed(player, track)
        ctx.profiles:dirty(player.UserId)
        task.spawn(function() ctx.profiles:save(player.UserId) end)
        local profile = ctx.profiles.records[player.UserId].profile
        ctx.Remote.feedback(player, config.Upgrades[track].name .. " upgraded to level " .. profile.upgrades[track] .. "!")
        ctx.Stats.update(player)
        ctx.Cycle.send(player)
    end

    -- On join, after the profile loads: re-apply every pass the player owns.
    function service.sync(player)
        if not ctx.profiles:ready(player.UserId) then return end
        local profile = ctx.profiles.records[player.UserId].profile
        local raised = RobuxUpgradeService.sync(config, profile, function(id)
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
        end)
        if player.Parent and ctx.profiles:ready(player.UserId) then
            for _, track in raised do changed(player, track) end
        end
    end

    local remote = Instance.new("RemoteEvent")
    remote.Name = "BuyUpgradeRobux"
    remote.Parent = ctx.Remote.folder
    remote.OnServerEvent:Connect(function(player, track)
        if type(track) ~= "string" or not config.Upgrades[track] then return end
        if not ctx.profiles:ready(player.UserId) or not ctx.Interaction.allowed(player, "robux") then return end
        if (prompting[player.UserId] or 0) > os.clock() then return end
        local profile = ctx.profiles.records[player.UserId].profile
        local id = Upgrades.robux(config, track, Upgrades.level(profile, track))
        if not id then return end
        prompting[player.UserId] = os.clock() + 30
        MarketplaceService:PromptGamePassPurchase(player, id)
    end)
    -- Fires on the server, so `purchased` can be trusted. A pass bought outside the game
    -- is picked up by the next join's sync.
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        prompting[player.UserId] = nil
        local pass = passes[passId]
        if not purchased or not pass or not ctx.profiles:ready(player.UserId) then return end
        local profile = ctx.profiles.records[player.UserId].profile
        if RobuxUpgradeService.apply(config, profile, pass.track, pass.level) then changed(player, pass.track) end
    end)
    Players.PlayerRemoving:Connect(function(player) prompting[player.UserId] = nil end)
    return service
end

return RobuxUpgradeService
