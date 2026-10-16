-- Robux upgrade levels: developer products from Config.RobuxUpgrades, one per track per
-- 10-level tier, each +1 level. The client asks the server to open the prompt (BuyUpgradeRobux),
-- so a maxed track or a missing product never prompts, and only one purchase per player is in
-- flight. ProcessReceipt writes the receipt journal first, then grants once per PurchaseId
-- (the ID is saved in the profile's receipt ledger in the same write as the level), and says
-- PurchaseGranted only after that write lands. A level bought past max (a race) pays the top
-- level's coin price instead. RobuxCheck runs `process` against fakes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local RobuxUpgradeService = {}
-- Granted PurchaseIds kept per profile. Roblox stops retrying a receipt once it is granted,
-- so the ledger only has to cover retries of receipts still in flight.
RobuxUpgradeService.LedgerSize = 64
-- How long a prompt (or a bought-but-unreceipted purchase) blocks the next prompt.
RobuxUpgradeService.PromptSeconds = 60

local Decision = Enum.ProductPurchaseDecision

-- ProductId -> { track, tier } from the config.
function RobuxUpgradeService.products(config)
    local map = {}
    for track, ids in config.RobuxUpgrades.products do
        for tier, id in ids do map[id] = { track = track, tier = tier } end
    end
    return map
end

-- Pure grant (no yields). Returns "duplicate", "level", or "coins" plus the coins paid back.
function RobuxUpgradeService.grant(config, profile, track, purchaseId)
    if table.find(profile.receiptIds, purchaseId) then return "duplicate", 0 end
    local spec = config.Upgrades[track]
    local level = Upgrades.level(profile, track)
    local outcome, coins = "level", 0
    if level < spec.max then
        profile.upgrades[track] = level + 1
    else
        outcome, coins = "coins", Upgrades.price(config, track, spec.max - 1)
        profile.coins += coins
    end
    table.insert(profile.receiptIds, purchaseId)
    while #profile.receiptIds > RobuxUpgradeService.LedgerSize do table.remove(profile.receiptIds, 1) end
    return outcome, coins
end

-- Receipt journal: one record per PurchaseId, written before anything is granted. A
-- DataStore when persistence is on, else a table (Studio).
function RobuxUpgradeService.journal(config)
    local store, memory = nil, {}
    if config.PersistenceEnabled then store = game:GetService("DataStoreService"):GetDataStore(config.ReceiptJournalName) end
    local function write(id, change)
        if not store then memory[id] = change(memory[id]); return end
        store:UpdateAsync("Receipt_" .. id, change)
    end
    return {
        entries = memory,
        open = function(info)
            write(info.PurchaseId, function(old)
                return old or { userId = info.PlayerId, productId = info.ProductId, at = os.time(), state = "pending" }
            end)
        end,
        close = function(purchaseId, outcome)
            write(purchaseId, function(old)
                old = old or {}
                old.state, old.outcome = "granted", old.outcome or outcome
                return old
            end)
        end,
    }
end

-- The ProcessReceipt body. deps: config, products, profiles, journal, present(userId),
-- granted(userId, track, outcome, coins).
function RobuxUpgradeService.process(deps, info)
    local product = deps.products[info.ProductId]
    if not product then
        warn("Rocket receipt for unknown product", info.ProductId, info.PurchaseId)
        return Decision.NotProcessedYet
    end
    local userId = info.PlayerId
    -- Not here (or still loading): Roblox retries when they next join a server.
    if not deps.present(userId) or not deps.profiles:ready(userId) then return Decision.NotProcessedYet end
    if not pcall(deps.journal.open, info) then return Decision.NotProcessedYet end
    -- The record outlives a player who left during the journal write, so the grant still saves.
    local record = deps.profiles.records[userId]
    if not record or record.blocked then return Decision.NotProcessedYet end
    local outcome, coins = RobuxUpgradeService.grant(deps.config, record.profile, product.track, info.PurchaseId)
    if outcome ~= "duplicate" then
        deps.profiles:dirty(userId)
        deps.granted(userId, product.track, outcome, coins)
    end
    -- A duplicate still saves: its first attempt may have failed after the grant.
    if not deps.profiles:commit(userId) then return Decision.NotProcessedYet end
    pcall(deps.journal.close, info.PurchaseId, outcome)
    return Decision.PurchaseGranted
end

function RobuxUpgradeService.new(ctx)
    local config = ctx.config
    local MarketplaceService = game:GetService("MarketplaceService")
    local Players = ctx.players
    local products = RobuxUpgradeService.products(config)
    local busy = {} -- userId -> os.clock() until which no new prompt opens
    local service = {}

    local deps = {
        config = config, products = products, profiles = ctx.profiles,
        journal = RobuxUpgradeService.journal(config),
        present = function(userId) return Players:GetPlayerByUserId(userId) ~= nil end,
        granted = function(userId, track, outcome, coins)
            busy[userId] = nil
            local player = Players:GetPlayerByUserId(userId)
            if not player then return end
            local profile = ctx.profiles.records[userId].profile
            local name = config.Upgrades[track].name
            if outcome == "level" then
                ctx.Remote.feedback(player, name .. " upgraded to level " .. profile.upgrades[track] .. "!")
            else
                ctx.Remote.feedback(player, name .. " was already maxed: you got " .. coins .. " coins instead.")
            end
            ctx.Stats.update(player)
            ctx.Cycle.send(player)
        end,
    }
    service.deps = deps
    MarketplaceService.ProcessReceipt = function(info) return RobuxUpgradeService.process(deps, info) end

    local remote = Instance.new("RemoteEvent")
    remote.Name = "BuyUpgradeRobux"
    remote.Parent = ctx.Remote.folder
    remote.OnServerEvent:Connect(function(player, track)
        if type(track) ~= "string" or not config.Upgrades[track] then return end
        if not ctx.profiles:ready(player.UserId) or not ctx.Interaction.allowed(player, "robux") then return end
        if (busy[player.UserId] or 0) > os.clock() then
            ctx.Remote.feedback(player, "Finishing your last purchase...")
            return
        end
        local profile = ctx.profiles.records[player.UserId].profile
        local id = Upgrades.robux(config, track, Upgrades.level(profile, track))
        if not id then return end
        busy[player.UserId] = os.clock() + RobuxUpgradeService.PromptSeconds
        MarketplaceService:PromptProductPurchase(player, id)
    end)
    -- Cancelled: free the prompt now. Bought: stay busy until the receipt grants.
    MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
        if products[productId] and not purchased then busy[userId] = nil end
    end)
    Players.PlayerRemoving:Connect(function(player) busy[player.UserId] = nil end)
    return service
end

return RobuxUpgradeService
