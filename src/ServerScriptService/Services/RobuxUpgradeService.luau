-- Robux upgrade levels: one Game Pass per track per level (Config.RobuxUpgrades). Owning the
-- passes up to level N means that track is at least level N while Roblox says so: the
-- pass levels (profile.passLevels) are worked out again on every join from Roblox's
-- ownership, each pass counting only on top of every level below it (owned or bought with
-- coins), and never saved, so a refunded pass stops counting. Coin levels are saved
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

-- Whether level `level` of `track` was saved as bought here.
local function wasBought(saved, track, level)
    return saved ~= nil and table.find(saved, RobuxUpgradeService.savedKey(track, level)) ~= nil
end

-- A pass counts only on top of every level below it: the level in effect climbs from the
-- coin level one owned pass at a time, so a pass bought out of order (Roblox sells any
-- pass directly, not just the next one the game offers) waits until the levels under it
-- are owned or bought with coins.

-- Puts the pass for `level` of `track` (just bought) on the profile if it's the next
-- level up. True when the level in effect changed; false for one out of order (the next
-- sync counts it once the levels below it are there).
function RobuxUpgradeService.apply(config, profile, track, level)
    local spec = config.Upgrades[track]
    if not spec or type(level) ~= "number" or level > spec.max then return false end
    if level ~= Upgrades.level(profile, track) + 1 then return false end
    profile.passLevels = profile.passLevels or {}
    profile.passLevels[track] = level
    return true
end

-- Works out every track's pass level from owns(passId) (may yield or error), climbing from
-- the coin level while the next level's pass is owned. A failed check falls back to the
-- saved keys (`saved`, the profile's passes); `trustSaved` (Studio) counts saved keys even
-- when Roblox says no. Returns the tracks whose level in effect changed, up or down.
function RobuxUpgradeService.sync(config, profile, owns, saved, trustSaved)
    local changed = {}
    local levels = {}
    for _, track in config.UpgradeOrder do
        local before = Upgrades.level(profile, track)
        local coins = profile.upgrades[track] or 0
        local ids = config.RobuxUpgrades.passes[track]
        local level = coins
        for candidate = coins + 1, config.Upgrades[track].max do
            local id = ids and ids[candidate]
            if not id then break end
            local ok, owned = pcall(owns, id)
            local has = (ok and owned) or ((not ok or trustSaved) and wasBought(saved, track, candidate))
            if not has then break end
            level = candidate
        end
        levels[track] = level > coins and level or nil
        if math.max(coins, level) ~= before then table.insert(changed, track) end
    end
    profile.passLevels = levels
    return changed
end

-- Puts sync's freshly worked-out pass levels (`computed`) on the profile, plus the passes
-- bought while the ownership checks ran (`boughtDuring`, track -> { [level] = true }) that
-- continue them. Levels the profile held before the checks are not kept: a refunded pass
-- must drop.
function RobuxUpgradeService.install(profile, computed, boughtDuring)
    local levels = table.clone(computed)
    for track, bought in boughtDuring or {} do
        local level = math.max(profile.upgrades[track] or 0, levels[track] or 0)
        while bought[level + 1] do level += 1 end
        if level > (levels[track] or 0) and level > (profile.upgrades[track] or 0) then levels[track] = level end
    end
    profile.passLevels = levels
end

function RobuxUpgradeService.new(ctx)
    local config = ctx.config
    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = ctx.players
    local passes = RobuxUpgradeService.passes(config)
    local prompting = {} -- userId -> os.clock() until which no new prompt opens
    local syncing = {} -- userId -> { track = { [level] = true } } bought while their ownership checks run
    local service = {}

    local function changed(player, track)
        ctx.profiles:dirty(player.UserId)
        ctx.profiles:saveSoon(player.UserId)
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
        if during then
            during[pass.track] = during[pass.track] or {}
            during[pass.track][pass.level] = true
        end
        -- Saved too (see the header): kept when a later ownership check fails, and in Studio.
        local key = RobuxUpgradeService.savedKey(pass.track, pass.level)
        if not table.find(profile.passes, key) then
            table.insert(profile.passes, key)
            ctx.profiles:dirty(player.UserId)
        end
        if RobuxUpgradeService.apply(config, profile, pass.track, pass.level) then changed(player, pass.track)
        else
            ctx.profiles:saveSoon(player.UserId)
            -- Out of order (bought outside the game's prompt): counted once the levels
            -- below it are owned, which a fresh sync works out.
            if not during and pass.level > Upgrades.level(profile, pass.track) + 1 then
                ctx.Remote.feedback(player, config.Upgrades[pass.track].name .. " level " .. pass.level .. " counts once you have every level below it.")
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player) prompting[player.UserId], syncing[player.UserId] = nil, nil end)
    return service
end

return RobuxUpgradeService
