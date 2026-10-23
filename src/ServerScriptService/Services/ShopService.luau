-- The Robux SHOP (Shared.Shop has the catalog, Config.Shop the IDs and prices).
-- The client asks with BuyShop(key); the server opens the prompt only for an offer
-- that's on sale (has an ID), not owned and available right now.
--
-- Game Passes: ownership comes from Roblox (UserOwnsGamePassAsync on join, and
-- PromptGamePassPurchaseFinished, which fires on the server, for a purchase made here).
-- A purchase made here is also saved on the buyer's profile (`passes`) and counts as
-- owned on every later join, so it can't be lost to a failed or stale ownership check
-- (Studio test purchases never show up in UserOwnsGamePassAsync at all). The flip side:
-- a pass refunded after buying here stays owned.
--
-- Developer Products: nearly all are server-wide effects (training boost, rocket fill,
-- longer stay, the next mission), so a grant needs no saved profile and never fails.
-- Robux UFOs go onto the buyer's profile: granted only while they're here, and the
-- profile (with the PurchaseId in its ledger) is saved before PurchaseGranted. Else
-- NotProcessedYet, and Roblox retries on their next join.
-- ProcessReceipt checks the receipt journal (a DataStore keyed by PurchaseId), grants,
-- records the PurchaseId and only then returns PurchaseGranted; a failed record returns
-- NotProcessedYet and the retry finds the in-memory mark, so nothing is granted twice
-- on this server. (If the server dies between the grant and the record, the retry
-- grants again on the next server: the buyer's favour, never a lost purchase.) A
-- receipt that arrives after its moment is banked: fill waits for the next delivery
-- phase, time for the next stay, a mission for the next spin.
-- ShopCheck runs the pure parts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shop = require(ReplicatedStorage.Shared.Shop)
local Missions = require(ReplicatedStorage.Shared.Missions)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Rocket = require(script.Parent.RocketService)
local ShopService = {}
ShopService.GRANTED, ShopService.RETRY = "granted", "retry"

-- Dashboard ID -> key for `kind` ("passes" or "products"); offers without IDs are left out.
function ShopService.ids(config, kind)
    local map = {}
    for key, entry in config.Shop[kind] do
        if type(entry.id) == "number" then map[entry.id] = key end
    end
    return map
end

-- One receipt. `state.granted[purchaseId]` marks grants made on this server; deps:
--   key(productId)        -> shop key or nil
--   seen(purchaseId)      -> ok, alreadyRecorded (the journal; may yield)
--   record(purchaseId, receipt, key) -> ok
--   grant(key, receipt)   -> applies the effect (never yields); false = can't yet (a UFO
--                            for a buyer who isn't here or has no free slot): retry later
-- Returns GRANTED or RETRY.
function ShopService.process(state, receipt, deps)
    local key = deps.key(receipt.ProductId)
    local id = receipt.PurchaseId
    if not key or type(id) ~= "string" or id == "" then return ShopService.RETRY end
    if state.busy[id] then return ShopService.RETRY end
    state.busy[id] = true
    local result = (function()
        if not state.granted[id] then
            local ok, seen = deps.seen(id)
            if not ok then return ShopService.RETRY end
            if seen then
                state.granted[id] = true
                return ShopService.GRANTED
            end
            if deps.grant(key, receipt) == false then return ShopService.RETRY end
            state.granted[id] = true
        end
        return deps.record(id, receipt, key) and ShopService.GRANTED or ShopService.RETRY
    end)()
    state.busy[id] = nil
    return result
end

-- Server-wide effects bought with products.
function ShopService.newEffects()
    return { boostUntil = 0, fillBank = 0, stayBank = 0, guarantees = {} }
end
-- Training boost: each purchase adds `seconds` after whatever is left.
function ShopService.boost(effects, now, seconds)
    effects.boostUntil = math.max(now, effects.boostUntil) + seconds
end
function ShopService.trainingMultiplier(config, effects, now)
    return now < effects.boostUntil and config.Shop.ServerTrainingMultiplier or 1
end
-- Pours banked fill (units) into the rocket's current phase, Metal or Fuel. What the
-- phase doesn't need stays banked: Metal overflow goes into Fuel, Fuel overflow into
-- the next rocket. Returns the units added and whether the phase advanced.
function ShopService.fill(rocket, effects)
    if not Rocket.PhaseMaterial[rocket.phase] or effects.fillBank <= 0 then return 0, false end
    local added, advanced = rocket:fill(effects.fillBank)
    effects.fillBank -= added
    return added, advanced
end
-- Extra time: into the running stay if there is one (true), else banked for the next.
function ShopService.extendStay(effects, stay, seconds)
    if stay then
        stay.total += seconds
        stay.extra += seconds
        return true
    end
    effects.stayBank += seconds
    return false
end
-- A new stay of `seconds`, plus any banked time.
function ShopService.beginStay(effects, seconds)
    local stay = { total = seconds + effects.stayBank, extra = effects.stayBank }
    effects.stayBank = 0
    return stay
end
-- The next guaranteed mission index, or nil (taken by the spin).
function ShopService.takeGuarantee(effects)
    return table.remove(effects.guarantees, 1)
end

-- Pass ownership via owns(passId) (may yield or error), plus `saved` (pass keys on
-- the profile, bought here before: owned and known without asking). Returns owned and
-- checked (key -> true for every pass whose ownership is known).
function ShopService.sync(config, owns, saved)
    local owned, checked = {}, {}
    for key, entry in config.Shop.passes do
        if saved and table.find(saved, key) then
            owned[key], checked[key] = true, true
        elseif type(entry.id) == "number" then
            local ok, has = pcall(owns, entry.id)
            if ok then
                checked[key] = true
                if has then owned[key] = true end
            end
        end
    end
    return owned, checked
end
-- Unequips pets past `slots` (a slot pass no longer owned). True when it changed.
function ShopService.trim(profile, slots)
    if #profile.equippedPets <= slots then return false end
    while #profile.equippedPets > slots do table.remove(profile.equippedPets) end
    return true
end

function ShopService.new(ctx)
    local config = ctx.config
    local MarketplaceService = game:GetService("MarketplaceService")
    local passIds, productIds = ShopService.ids(config, "passes"), ShopService.ids(config, "products")
    local effects = ShopService.newEffects()
    local receipts = { granted = {}, busy = {} }
    local owned, checked, prompting = {}, {}, {}
    local stay = nil
    local service = { effects = effects }

    function service.owns(player, key) return owned[player.UserId] ~= nil and owned[player.UserId][key] == true end
    function service.petSlots(player) return Shop.petSlots(owned[player.UserId] or {}) end
    function service.hatchRate(player) return service.owns(player, "FastHatch") and config.Shop.FastHatchRate or 1 end
    function service.maxUfos(player) return service.owns(player, "MultiHatch") and config.Shop.MultiHatchCount or 1 end
    function service.coinMultiplier(player) return service.owns(player, "DoubleCoins") and config.Shop.DoubleCoinsMultiplier or 1 end
    function service.trainingMultiplier() return ShopService.trainingMultiplier(config, effects, workspace:GetServerTimeNow()) end
    function service.gymUnlocked(player, tier) return tier ~= nil and service.owns(player, Shop.gymKey(tier)) end

    local function view(player)
        local rocket = ctx.Cycle.rocket
        return { phase = rocket.phase, passenger = rocket.passengers[player.UserId] == true,
            wheelSpun = ctx.Cycle.wheel ~= nil, guaranteed = #effects.guarantees > 0, stayExtra = stay and stay.extra or 0,
            ufos = #ctx.profiles.records[player.UserId].profile.ufos, maxUfos = service.maxUfos(player) }
    end
    function service.snapshot(player)
        local mine = owned[player.UserId] or {}
        local guaranteed = effects.guarantees[1]
        return { owned = table.clone(mine), petSlots = Shop.petSlots(mine), maxUfos = service.maxUfos(player), boostUntil = effects.boostUntil,
            guaranteed = guaranteed and Missions.get(guaranteed).Id or nil, stayExtra = stay and stay.extra or 0,
            fillBank = effects.fillBank }
    end

    -- Launch calls these around the reward stay; the stay's length can grow while it runs.
    function service.beginStay(seconds)
        stay = ShopService.beginStay(effects, seconds)
        return stay
    end
    function service.endStay() stay = nil end
    function service.takeGuarantee() return ShopService.takeGuarantee(effects) end

    local function drainFill()
        local rocket = ctx.Cycle.rocket
        local added, advanced = ShopService.fill(rocket, effects)
        while added > 0 do
            ctx.Cargo.delivered(advanced)
            if ctx.Cycle.rocket ~= rocket or not advanced then break end
            added, advanced = ShopService.fill(rocket, effects)
        end
    end

    local function grant(key, receipt)
        local player = Players:GetPlayerByUserId(receipt.PlayerId)
        local name = player and player.DisplayName or "A player"
        -- A UFO goes onto the buyer's profile, so they must be here.
        local rarity = key:match("^Ufo(%a+)$")
        if rarity then
            if not player then return false end
            for tier, ufo in Pets.Ufos do
                if ufo.Rarity == rarity then
                    -- Saved (with its PurchaseId) before Roblox hears it was granted.
                    if not ctx.Pets.grantUfo(player, tier, receipt.PurchaseId) then return false end
                    return ctx.profiles:saveNow(player.UserId)
                end
            end
            return false
        end
        local units = tonumber(key:match("^Fill(%d+)$"))
        if key == "ServerTraining" then
            ShopService.boost(effects, workspace:GetServerTimeNow(), config.Shop.ServerTrainingSeconds)
            ctx.Remote.announce(name .. " boosted training " .. config.Shop.ServerTrainingMultiplier .. "x for everyone for " .. config.Shop.ServerTrainingSeconds // 60 .. " minutes!")
        elseif units then
            local material = Rocket.PhaseMaterial[ctx.Cycle.rocket.phase]
            local amount = tostring(units):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            effects.fillBank += units
            ctx.Remote.announce(name .. " added " .. amount .. (material and " " .. material .. " to the rocket!" or " units to the next rocket!"))
            drainFill()
        elseif key == "ExtraStay" then
            local seconds = config.Shop.ExtraStaySeconds
            if ShopService.extendStay(effects, stay, seconds) then
                ctx.Cycle.deadline += seconds
                ctx.Remote.announce(name .. " added " .. seconds .. " seconds to this stay!")
            else
                ctx.Remote.announce(name .. " added " .. seconds .. " seconds to the next stay!")
            end
        else
            local mission = Missions.index(key:match("^Next(.+)$"))
            if mission then
                table.insert(effects.guarantees, mission)
                ctx.Remote.announce(name .. " locked in the next mission: " .. config.Destinations[mission].name .. "!")
            end
        end
        ctx.Cycle.broadcast()
    end

    -- The journal: one DataStore entry per PurchaseId. Studio test servers may have no
    -- DataStore access, so there it falls back to this server's memory.
    local store
    local ok, result = pcall(function() return game:GetService("DataStoreService"):GetDataStore(config.Shop.ReceiptStore) end)
    if ok then store = result end
    local memory = {}
    local warned = false
    local function studioFallback(err)
        if not RunService:IsStudio() then return false end
        if not warned then warned = true; warn("Rocket shop: receipt journal in memory (Studio, no DataStore):", err) end
        return true
    end
    local function seen(id)
        if memory[id] then return true, true end
        if not store then return studioFallback("no store"), false end
        local okGet, value = pcall(store.GetAsync, store, "Receipt_" .. id)
        if okGet then return true, value ~= nil end
        return studioFallback(value), false
    end
    local function record(id, receipt, key)
        memory[id] = true
        if not store then return studioFallback("no store") end
        local okSet, err = pcall(store.SetAsync, store, "Receipt_" .. id,
            { userId = receipt.PlayerId, productId = receipt.ProductId, key = key, at = os.time() }, { receipt.PlayerId })
        if okSet then return true end
        memory[id] = nil
        if studioFallback(err) then memory[id] = true; return true end
        warn("Rocket shop: couldn't record receipt", id, err)
        return false
    end
    local deps = { key = function(productId) return productIds[productId] end, seen = seen, record = record, grant = grant }
    function service.processReceipt(receipt)
        local outcome = ShopService.process(receipts, receipt, deps)
        if outcome == ShopService.GRANTED then return Enum.ProductPurchaseDecision.PurchaseGranted end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    MarketplaceService.ProcessReceipt = service.processReceipt
    -- Studio playtests (DebugService) before the dashboard IDs exist: a receipt for `key`
    -- through the same journal path, and owning a pass.
    function service.debugReceipt(player, key, purchaseId)
        local debugDeps = table.clone(deps)
        debugDeps.key = function() return Shop.entry(config, key) and not Shop.isPass(config, key) and key or nil end
        return ShopService.process(receipts, { PurchaseId = purchaseId, ProductId = 0, PlayerId = player.UserId }, debugDeps)
    end

    local function refresh(player)
        if ctx.Pets then ctx.Pets.refresh(player) end
        if ctx.Skins then ctx.Skins.refresh(player) end
        ctx.Cycle.send(player)
    end
    -- On join, after the profile loads: which passes they own. A slot pass that's gone
    -- (refunded) puts the extra pets away; a failed check changes nothing.
    function service.sync(player)
        local record = ctx.profiles.records[player.UserId]
        local has, ok = ShopService.sync(config, function(id) return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) end,
            record and record.profile.passes)
        if not player.Parent then return end
        -- A pass bought while the checks ran stays owned.
        for key in owned[player.UserId] or {} do has[key], ok[key] = true, true end
        owned[player.UserId], checked[player.UserId] = has, ok
        local slotsKnown = (ok.PetSlot1 or not Shop.enabled(config, "PetSlot1")) and (ok.PetSlot2 or not Shop.enabled(config, "PetSlot2"))
        if record and slotsKnown and ShopService.trim(record.profile, service.petSlots(player)) then ctx.profiles:dirty(player.UserId) end
        refresh(player)
    end

    function service.debugOwn(player, key, on)
        owned[player.UserId] = owned[player.UserId] or {}
        owned[player.UserId][key] = on ~= false or nil
        local record = ctx.profiles.records[player.UserId]
        if record and ShopService.trim(record.profile, service.petSlots(player)) then ctx.profiles:dirty(player.UserId) end
        refresh(player)
    end

    local remote = Instance.new("RemoteEvent")
    remote.Name = "BuyShop"
    remote.Parent = ctx.Remote.folder
    remote.OnServerEvent:Connect(function(player, key)
        if type(key) ~= "string" or not Shop.entry(config, key) then return end
        if not ctx.profiles:ready(player.UserId) or not ctx.Interaction.allowed(player, "shop") then return end
        if not Shop.enabled(config, key) then return ctx.Remote.feedback(player, "That's coming soon!") end
        if (prompting[player.UserId] or 0) > os.clock() then return end
        local entry = Shop.entry(config, key)
        if Shop.isPass(config, key) then
            if service.owns(player, key) then return ctx.Remote.feedback(player, "You already own that!") end
            local tier = tonumber(key:match("^Gym(%d+)$"))
            local spec = tier and config.TrainingTiers[tier]
            if spec and ctx.profiles.records[player.UserId].profile.completedLaunches >= spec.cycles then
                return ctx.Remote.feedback(player, "You've already unlocked that gym!")
            end
            prompting[player.UserId] = os.clock() + 30
            MarketplaceService:PromptGamePassPurchase(player, entry.id)
        else
            if not Shop.available(config, key, view(player)) then return ctx.Remote.feedback(player, "That isn't available right now.") end
            prompting[player.UserId] = os.clock() + 30
            MarketplaceService:PromptProductPurchase(player, entry.id)
        end
    end)
    -- A pass bought here (PromptGamePassPurchaseFinished; DebugService "bought").
    function service.passBought(player, key)
        owned[player.UserId] = owned[player.UserId] or {}
        owned[player.UserId][key] = true
        -- Saved on their profile too, so it's theirs on every join (see the header).
        local record = ctx.profiles.records[player.UserId]
        if record and ctx.profiles:ready(player.UserId) and not table.find(record.profile.passes, key) then
            table.insert(record.profile.passes, key)
            ctx.profiles:dirty(player.UserId)
            task.spawn(ctx.profiles.saveNow, ctx.profiles, player.UserId)
        end
        local name = key:match("^Gym") and "gym access" or key
        for _, pass in Shop.Passes do if pass.key == key then name = pass.name end end
        local skin = Skins.get(key)
        if skin then name = "The " .. skin.name end
        ctx.Remote.feedback(player, "Thanks! " .. name .. " is yours.")
        refresh(player)
    end
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        prompting[player.UserId] = nil
        local key = passIds[passId]
        if purchased and key then service.passBought(player, key) end
    end)
    MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
        prompting[userId] = nil
    end)

    -- Banked fill pours in as soon as a delivery phase opens; the boost's end updates HUDs.
    local elapsed, boosted = 0, false
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 1 then return end
        elapsed = 0
        if effects.fillBank > 0 then drainFill() end
        local now = service.trainingMultiplier() > 1
        if boosted and not now then ctx.Remote.announce("The server training boost has ended."); ctx.Cycle.broadcast() end
        boosted = now
    end)
    Players.PlayerRemoving:Connect(function(player)
        owned[player.UserId], checked[player.UserId], prompting[player.UserId] = nil, nil, nil
    end)
    return service
end

return ShopService
