-- Robux upgrade levels: one Game Pass per track per level (Config.RobuxUpgrades). Owning the
-- pass for level N means that track is at least level N while Roblox says it's owned: the
-- pass levels (profile.passLevels) are worked out again on every join from Roblox's
-- ownership and never saved, so a refunded pass stops counting. Coin levels are saved
-- apart (profile.upgrades) and continue from whichever is higher (Shared.Upgrades.level).
-- A pass bought here is also saved on the profile as a key in `passes` ("Robux:<track>:<level>"):
-- used when Roblox's check fails, and in Studio, whose test purchases never show up in
-- UserOwnsGamePassAsync. The client asks the server to open the prompt (BuyUpgradeRobux),
-- which offers only the next level's pass; a finished purchase raises the level at once.
-- RobuxCheck runs the pure parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

-- The profile `passes` key recording a level pass bought here.
function RobuxUpgradeService.savedKey(track, level)
    return "Robux:" .. track .. ":" .. level
end

-- The highest level of `track` among the saved keys (0 for none).
local function savedLevel(saved, track)
    local best = 0
    for _, key in saved or {} do
        local name, level = key:match("^Robux:(%a+):(%d+)$")
        if name == track then best = math.max(best, tonumber(level)) end
    end
    return best
end

-- Raises `track`'s pass level to `level` (capped at max; never lowers it). True when the
-- level in effect changed.
function RobuxUpgradeService.apply(config, profile, track, level)
    local spec = config.Upgrades[track]
    if not spec or type(level) ~= "number" then return false end
    level = math.min(level, spec.max)
    local before = Upgrades.level(profile, track)
    profile.passLevels = profile.passLevels or {}
    if (profile.passLevels[track] or 0) >= level then return false end
    profile.passLevels[track] = level
    return Upgrades.level(profile, track) ~= before
end

-- Works out every track's pass level from owns(passId) (may yield or error), checking
-- from the top level down to just above the coin level (passes at or below it change
-- nothing). A failed check falls back to the saved keys (`saved`, the profile's passes);
-- `trustSaved` (Studio) counts saved keys even when Roblox says no. Returns the tracks
-- whose level in effect changed, up or down.
function RobuxUpgradeService.sync(config, profile, owns, saved, trustSaved)
    local changed = {}
    local levels = {}
    for _, track in config.UpgradeOrder do
        local before = Upgrades.level(profile, track)
        local coins = profile.upgrades[track] or 0
        local ids = config.RobuxUpgrades.passes[track]
        local level = 0
        for candidate = config.Upgrades[track].max, coins + 1, -1 do
            local id = ids and ids[candidate]
            if id then
                local ok, owned = pcall(owns, id)
                if not ok then
                    level = savedLevel(saved, track)
                    break
                end
                if owned or (trustSaved and savedLevel(saved, track) >= candidate) then
                    level = candidate
                    break
                end
            end
        end
        if trustSaved then level = math.max(level, savedLevel(saved, track)) end
        levels[track] = math.min(level, config.Upgrades[track].max)
        local after = math.max(coins, levels[track])
        if after ~= before then table.insert(changed, track) end
    end
    profile.passLevels = levels
    return changed
end

-- Puts sync's freshly worked-out pass levels (`computed`) on the profile, plus only the
-- passes bought while the ownership checks ran (`boughtDuring`, track -> level). Levels
-- the profile held before the checks are not kept: a refunded pass must drop.
function RobuxUpgradeService.install(profile, computed, boughtDuring)
    local levels = table.clone(computed)
    for track, level in boughtDuring or {} do levels[track] = math.max(levels[track] or 0, level) end
    profile.passLevels = levels
end

function RobuxUpgradeService.new(ctx)
    local config = ctx.config
    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = ctx.players
    local passes = RobuxUpgradeService.passes(config)
    local prompting = {} -- userId -> os.clock() until which no new prompt opens
    local syncing = {} -- userId -> { track = level } bought while their ownership checks run
    local service = {}

    local function changed(player, track)
        ctx.profiles:dirty(player.UserId)
        task.spawn(function() ctx.profiles:save(player.UserId) end)
        local profile = ctx.profiles.records[player.UserId].profile
        ctx.Remote.feedback(player, config.Upgrades[track].name .. " upgraded to level " .. Upgrades.level(profile, track) .. "!")
        ctx.Stats.update(player)
        ctx.Cycle.send(player)
    end

    -- On join, after the profile loads: the pass levels from what the player owns now.
    function service.sync(player)
        if not ctx.profiles:ready(player.UserId) then return end
        local profile = ctx.profiles.records[player.UserId].profile
        -- Worked out on a copy (the checks yield), then put on the live profile.
        local probe = { upgrades = table.clone(profile.upgrades) }
        syncing[player.UserId] = {}
        RobuxUpgradeService.sync(config, probe, function(id)
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
        end, profile.passes, RunService:IsStudio())
        local boughtDuring = syncing[player.UserId]
        syncing[player.UserId] = nil
        if not player.Parent or not ctx.profiles:ready(player.UserId) then return end
        local before = {}
        for _, track in config.UpgradeOrder do before[track] = Upgrades.level(profile, track) end
        RobuxUpgradeService.install(profile, probe.passLevels, boughtDuring)
        for _, track in config.UpgradeOrder do
            local level = Upgrades.level(profile, track)
            if level > before[track] then changed(player, track)
            elseif level < before[track] then ctx.Stats.update(player); ctx.Cycle.send(player) end
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
        local during = syncing[player.UserId]
        if during then during[pass.track] = math.max(during[pass.track] or 0, pass.level) end
        -- Saved too (see the header): kept when a later ownership check fails, and in Studio.
        local key = RobuxUpgradeService.savedKey(pass.track, pass.level)
        if not table.find(profile.passes, key) then
            table.insert(profile.passes, key)
            ctx.profiles:dirty(player.UserId)
        end
        if RobuxUpgradeService.apply(config, profile, pass.track, pass.level) then changed(player, pass.track)
        else task.spawn(function() ctx.profiles:save(player.UserId) end) end
    end)
    Players.PlayerRemoving:Connect(function(player) prompting[player.UserId], syncing[player.UserId] = nil, nil end)
    return service
end

return RobuxUpgradeService
