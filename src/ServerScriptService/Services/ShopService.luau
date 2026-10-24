-- The Robux SHOP (Shared.Shop has the catalog, Config.Shop the IDs and prices).
-- The client asks with BuyShop(key); the server opens the prompt only for an offer
-- that's on sale (has an ID), not owned and available right now.
--
-- Game Passes: ownership comes from Roblox (UserOwnsGamePassAsync on join, and
-- PromptGamePassPurchaseFinished, which fires on the server, for a purchase made here), so
-- a refunded pass stops counting on the next join. A purchase made here is also saved on
-- the buyer's profile (`passes`): it counts when Roblox's check fails (an outage can't
-- take a pass away), and in Studio, whose test purchases never show up in
-- UserOwnsGamePassAsync at all.
--
-- Developer Products: nearly all are server-wide effects (training boost, rocket fill,
-- longer stay, the next mission). Robux UFOs go onto the buyer's profile.
-- Every receipt is first claimed in the buyer's receipt ledger (ReceiptStore, key
-- "Buyer_<userId>", changed only in UpdateAsync, so one server at a time holds a
-- PurchaseId). A claim has a lease this server renews, and records what is still owed.
--   * A UFO goes onto the profile with the PurchaseId in its ledger (so a retry never
--     adds a second), and PurchaseGranted only once the profile is saved. Otherwise the
--     claim is let go and NotProcessedYet, so Roblox retries wherever the buyer is.
--   * A server effect is applied here at once and PurchaseGranted follows (the claim,
--     with the amount owed, is durable). What can't be used yet is banked by PurchaseId:
--     fill waits for the next delivery phase, time for the next stay, a mission for the
--     next spin. The ledger follows the banks down, and a purchase used up moves to its
--     done list. If this server closes or crashes first, the buyer's next join anywhere
--     takes over every claim whose lease has run out and banks what's owed there.
-- A PurchaseId on the done list is granted with nothing applied. ShopCheck runs the
-- pure parts and the receipt path against an in-memory store.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
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

-- The buyer's receipt ledger, as stored: { open = { [purchaseId] = entry }, done = { purchaseId, ... } }
-- with entry = { key, productId, amount (still owed), owner (server), leaseUntil, at }.
ShopService.LeaseSeconds = 300
ShopService.DoneLimit = 100
function ShopService.ledger(raw)
    local ledger = type(raw) == "table" and raw or {}
    if type(ledger.open) ~= "table" then ledger.open = {} end
    if type(ledger.done) ~= "table" then ledger.done = {} end
    return ledger
end

-- Claims `id` for server `owner` (changes `ledger`): "done" (granted before), "busy"
-- (another server's live claim), or "mine" and the entry (new, ours already, or taken
-- from a server whose lease ran out).
function ShopService.claim(ledger, id, fields, owner, now)
    if table.find(ledger.done, id) then return "done" end
    local entry = ledger.open[id]
    if entry and entry.owner ~= owner and (entry.leaseUntil or 0) > now then return "busy", entry end
    if not entry then
        entry = { key = fields.key, productId = fields.productId, amount = fields.amount, at = now }
        ledger.open[id] = entry
    end
    entry.owner, entry.leaseUntil = owner, now + ShopService.LeaseSeconds
    return "mine", entry
end

-- Writes what this server still owes on its claims (`held[id]` = amount left; 0 = used
-- up, so done) and renews their leases; `release` lets go of them instead (shutdown, or a
-- claim that couldn't be applied) so the next server takes them at once. Claims no longer
-- ours are left alone. Returns { [id] = "done" or "gone" (no longer ours) }: nothing
-- more to write for those.
function ShopService.settle(ledger, owner, held, now, release)
    local finished = {}
    for id, left in held do
        local entry = ledger.open[id]
        if not entry or entry.owner ~= owner then
            finished[id] = "gone"
        elseif left <= 0 then
            ledger.open[id] = nil
            table.insert(ledger.done, id)
            finished[id] = "done"
        else
            entry.amount = left
            entry.leaseUntil = release and 0 or now + ShopService.LeaseSeconds
        end
    end
    while #ledger.done > ShopService.DoneLimit do table.remove(ledger.done, 1) end
    return finished
end

-- Takes over the buyer's claims whose server let go or stopped renewing (it closed),
-- except those `skip(key)` leaves (UFOs: Roblox's own receipt retry finishes those).
-- Returns { [id] = entry }.
function ShopService.takeover(ledger, owner, now, skip)
    local taken = {}
    for id, entry in ledger.open do
        if entry.owner ~= owner and (entry.leaseUntil or 0) <= now and not skip(entry.key) then
            entry.owner, entry.leaseUntil = owner, now + ShopService.LeaseSeconds
            taken[id] = entry
        end
    end
    return taken
end

-- An in-memory stand-in for the ledger store (Studio without DataStores; ShopCheck):
-- UpdateAsync on copies, as the real store hands out.
function ShopService.memoryStore()
    local function deep(value)
        if type(value) ~= "table" then return value end
        local out = {}
        for k, v in value do out[k] = deep(v) end
        return out
    end
    local store = { data = {}, writes = 0 }
    function store:UpdateAsync(key, transform)
        local value = transform(deep(self.data[key]))
        if value == nil then return nil end
        self.data[key] = deep(value)
        self.writes += 1
        return deep(value)
    end
    return store
end

function ShopService.isUfo(key) return key:match("^Ufo%a+$") ~= nil end

-- One receipt; `state.owner` is this server, `state.applied[purchaseId]` marks server
-- effects applied here. deps:
--   key(productId)            -> shop key or nil
--   amount(key)               -> what the purchase is worth (units, seconds or 1)
--   update(userId, transform) -> ok (UpdateAsync on the buyer's ledger; may yield);
--                                transform(ledger, now) returns true to write
--   apply(key, receipt, amount) -> amount still owed (0 = all used), or false: can't yet
--                                (a UFO for a buyer who isn't here, or whose save failed)
--   hold(userId, id, key, left) -> tracks what's owed until it's used up (and written)
-- Returns GRANTED or RETRY.
function ShopService.process(state, receipt, deps)
    local key = deps.key(receipt.ProductId)
    local id = receipt.PurchaseId
    if not key or type(id) ~= "string" or id == "" or type(receipt.PlayerId) ~= "number" then return ShopService.RETRY end
    if state.busy[id] then return ShopService.RETRY end
    state.busy[id] = true
    local result = (function()
        local outcome, entry
        local ok = deps.update(receipt.PlayerId, function(ledger, now)
            outcome, entry = ShopService.claim(ledger, id, { key = key, productId = receipt.ProductId, amount = deps.amount(key) }, state.owner, now)
            return outcome == "mine"
        end)
        if not ok then return ShopService.RETRY end
        if outcome == "done" then return ShopService.GRANTED end
        if outcome ~= "mine" then return ShopService.RETRY end
        if state.applied[id] then return ShopService.GRANTED end
        local left = deps.apply(key, receipt, entry.amount)
        if left == false then
            -- Let go, so the server the buyer is on next can claim it at once.
            deps.update(receipt.PlayerId, function(ledger, now)
                ShopService.settle(ledger, state.owner, { [id] = entry.amount }, now, true)
                return true
            end)
            return ShopService.RETRY
        end
        -- A UFO's apply is safe to repeat (the profile ledger); a server effect's isn't.
        if not ShopService.isUfo(key) then state.applied[id] = true end
        deps.hold(receipt.PlayerId, id, key, left)
        return ShopService.GRANTED
    end)()
    state.busy[id] = nil
    return result
end

-- Server-wide effects bought with products. The banks remember which purchase each part
-- came from (`id`): fills and stays are { id, units / seconds } oldest first, guarantees
-- { mission, id }.
function ShopService.newEffects()
    return { boostUntil = 0, fillBank = 0, fills = {}, stayBank = 0, stays = {}, guarantees = {} }
end
-- Takes `amount` off the front of a bank list (oldest purchase first).
local function consume(list, field, amount)
    while amount > 0 and list[1] do
        local take = math.min(amount, list[1][field])
        list[1][field] -= take
        amount -= take
        if list[1][field] <= 0 then table.remove(list, 1) end
    end
end
-- What's still banked of purchase `id`.
function ShopService.owed(effects, id)
    local left = 0
    for _, item in effects.fills do if item.id == id then left += item.units end end
    for _, item in effects.stays do if item.id == id then left += item.seconds end end
    for _, item in effects.guarantees do if item.id == id then left += 1 end end
    return left
end
-- Drops whatever is banked of purchase `id` (another server took its claim over).
function ShopService.forfeit(effects, id)
    for index = #effects.fills, 1, -1 do
        local item = effects.fills[index]
        if item.id == id then effects.fillBank -= item.units; table.remove(effects.fills, index) end
    end
    for index = #effects.stays, 1, -1 do
        local item = effects.stays[index]
        if item.id == id then effects.stayBank -= item.seconds; table.remove(effects.stays, index) end
    end
    for index = #effects.guarantees, 1, -1 do
        if effects.guarantees[index].id == id then table.remove(effects.guarantees, index) end
    end
end
-- Training boost: each purchase adds `seconds` after whatever is left.
function ShopService.boost(effects, now, seconds)
    effects.boostUntil = math.max(now, effects.boostUntil) + seconds
end
function ShopService.trainingMultiplier(config, effects, now)
    return now < effects.boostUntil and config.Shop.ServerTrainingMultiplier or 1
end
-- Banks `units` of fill bought by purchase `id`.
function ShopService.bankFill(effects, units, id)
    effects.fillBank += units
    table.insert(effects.fills, { id = id, units = units })
end
-- Pours banked fill (units) into the rocket's current phase, Metal or Fuel. What the
-- phase doesn't need stays banked: Metal overflow goes into Fuel, Fuel overflow into
-- the next rocket. Returns the units added and whether the phase advanced.
function ShopService.fill(rocket, effects)
    if not Rocket.PhaseMaterial[rocket.phase] or effects.fillBank <= 0 then return 0, false end
    local added, advanced = rocket:fill(effects.fillBank)
    effects.fillBank -= added
    consume(effects.fills, "units", added)
    return added, advanced
end
-- Extra time: into the running stay if there is one (true), else banked for the next.
function ShopService.extendStay(effects, stay, seconds, id)
    if stay then
        stay.total += seconds
        stay.extra += seconds
        return true
    end
    effects.stayBank += seconds
    table.insert(effects.stays, { id = id, seconds = seconds })
    return false
end
-- A new stay of `seconds`, plus any banked time.
function ShopService.beginStay(effects, seconds)
    local stay = { total = seconds + effects.stayBank, extra = effects.stayBank }
    effects.stayBank = 0
    table.clear(effects.stays)
    return stay
end
-- Banks a guaranteed next mission bought by purchase `id`.
function ShopService.guarantee(effects, mission, id)
    table.insert(effects.guarantees, { mission = mission, id = id })
end
-- The next guaranteed mission index, or nil (taken by the spin).
function ShopService.takeGuarantee(effects)
    local item = table.remove(effects.guarantees, 1)
    return item and item.mission
end

-- Pass ownership via owns(passId) (may yield or error): Roblox's answer decides. `saved`
-- (pass keys on the profile, bought here before) stands in when the check fails or the
-- pass has no ID to check; `trustSaved` (Studio, where test purchases never show up in
-- the check) counts them even when Roblox says no. Returns owned and checked (key -> true
-- for every pass whose ownership is known).
function ShopService.sync(config, owns, saved, trustSaved)
    local owned, checked = {}, {}
    for key, entry in config.Shop.passes do
        local wasBought = saved ~= nil and table.find(saved, key) ~= nil
        local ok, has = false, nil
        if type(entry.id) == "number" then ok, has = pcall(owns, entry.id) end
        if ok then
            checked[key] = true
            if has or (trustSaved and wasBought) then owned[key] = true end
        elseif wasBought then
            owned[key], checked[key] = true, true
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
    local receipts = { owner = HttpService:GenerateGUID(false), applied = {}, busy = {} }
    -- What this server still owes on its claims, per buyer: held[userId][purchaseId] =
    -- { key, left }. Written to their ledger soon after it changes, and every RenewSeconds
    -- (which renews the leases).
    local held, heldChanged, settling = {}, false, false
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
            guaranteed = guaranteed and Missions.get(guaranteed.mission).Id or nil, stayExtra = stay and stay.extra or 0,
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

    -- What a purchase of `key` is worth.
    local function amount(key)
        local units = tonumber(key:match("^Fill(%d+)$"))
        if units then return units end
        if key == "ServerTraining" then return config.Shop.ServerTrainingSeconds end
        if key == "ExtraStay" then return config.Shop.ExtraStaySeconds end
        return 1
    end

    -- Applies `amount` of purchase `receipt` (of `key`). Returns what's still owed (banked
    -- here), or false when it can't be applied yet (a UFO: buyer not here or not saved).
    -- `restored`: taken over from a server that closed (the buyer is told, nobody else).
    local function apply(key, receipt, value, restored)
        local player = Players:GetPlayerByUserId(receipt.PlayerId)
        local name = player and player.DisplayName or "A player"
        local id = receipt.PurchaseId
        local function announce(text, mine)
            if restored then
                if player then ctx.Remote.feedback(player, "From your last server: " .. mine) end
            else
                ctx.Remote.announce(text)
            end
        end
        -- A UFO goes onto the buyer's profile, so they must be here.
        local rarity = key:match("^Ufo(%a+)$")
        if rarity then
            if not player then return false end
            for tier, ufo in Pets.Ufos do
                if ufo.Rarity == rarity then
                    -- Saved (with its PurchaseId) before Roblox hears it was granted.
                    if not ctx.Pets.grantUfo(player, tier, id) then return false end
                    return ctx.profiles:saveNow(player.UserId) and 0 or false
                end
            end
            return false
        end
        local left = 0
        if key == "ServerTraining" then
            ShopService.boost(effects, workspace:GetServerTimeNow(), value)
            announce(name .. " boosted training " .. config.Shop.ServerTrainingMultiplier .. "x for everyone for " .. value // 60 .. " minutes!",
                "your training boost is running here.")
        elseif key:match("^Fill%d+$") then
            local material = Rocket.PhaseMaterial[ctx.Cycle.rocket.phase]
            local text = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            ShopService.bankFill(effects, value, id)
            announce(name .. " added " .. text .. (material and " " .. material .. " to the rocket!" or " units to the next rocket!"),
                text .. " units of fill went into this rocket.")
            drainFill()
            left = ShopService.owed(effects, id)
        elseif key == "ExtraStay" then
            if ShopService.extendStay(effects, stay, value, id) then
                ctx.Cycle.deadline += value
                announce(name .. " added " .. value .. " seconds to this stay!", value .. " more seconds on this stay.")
            else
                left = value
                announce(name .. " added " .. value .. " seconds to the next stay!", value .. " more seconds on the next stay.")
            end
        else
            local mission = Missions.index(key:match("^Next(.+)$") or "")
            if mission then
                ShopService.guarantee(effects, mission, id)
                left = 1
                announce(name .. " locked in the next mission: " .. config.Destinations[mission].name .. "!",
                    "the next mission here is " .. config.Destinations[mission].name .. ".")
            end
        end
        ctx.Cycle.broadcast()
        return left
    end

    -- The receipt ledgers (ReceiptStore, "Buyer_<userId>"). Studio test servers may have no
    -- DataStore access: there they fall back to this server's memory.
    local store, inMemory
    local ok, result = pcall(function() return game:GetService("DataStoreService"):GetDataStore(config.Shop.ReceiptStore) end)
    if ok then store = result elseif RunService:IsStudio() then store, inMemory = ShopService.memoryStore(), true end
    local function update(userId, transform)
        if not store then return false end
        local function attempt()
            return pcall(function()
                store:UpdateAsync("Buyer_" .. userId, function(raw)
                    local ledger = ShopService.ledger(raw)
                    if not transform(ledger, os.time()) then return nil end
                    return ledger, { userId }
                end)
            end)
        end
        local okUpdate, err = attempt()
        if not okUpdate and RunService:IsStudio() and not inMemory then
            warn("Rocket shop: receipt ledgers in memory (Studio, no DataStore):", err)
            store, inMemory = ShopService.memoryStore(), true
            okUpdate, err = attempt()
        end
        if not okUpdate then warn("Rocket shop: receipt ledger write failed", userId, err) end
        return okUpdate
    end
    local function hold(userId, id, key, left)
        held[userId] = held[userId] or {}
        held[userId][id] = { key = key, left = left }
        heldChanged = true
    end
    -- Follows the banks down as they're used.
    local function track()
        for _, mine in held do
            for id, item in mine do
                if not ShopService.isUfo(item.key) then
                    local left = ShopService.owed(effects, id)
                    if left ~= item.left then item.left, heldChanged = left, true end
                end
            end
        end
    end
    -- Writes every buyer's held claims (`release`: lets go of them, at shutdown).
    local function settle(release)
        if settling then return end
        settling, heldChanged = true, false
        for userId, mine in held do
            local amounts = {}
            for id, item in mine do amounts[id] = item.left end
            local finished
            local written = update(userId, function(ledger, now)
                finished = ShopService.settle(ledger, receipts.owner, amounts, now, release)
                return true
            end)
            if not written then
                heldChanged = true
            elseif finished then
                for id, why in finished do
                    -- Taken over elsewhere (this server stopped renewing): it's theirs now.
                    if why == "gone" then ShopService.forfeit(effects, id) end
                    mine[id] = nil
                end
                if not next(mine) then held[userId] = nil end
            end
        end
        settling = false
    end
    -- On join: what a closed server still owed this buyer is banked here.
    function service.recover(player)
        local taken
        local written = update(player.UserId, function(ledger, now)
            taken = ShopService.takeover(ledger, receipts.owner, now, ShopService.isUfo)
            return next(taken) ~= nil
        end)
        if not written or not taken or not player.Parent then return end
        for id, entry in taken do
            if not receipts.applied[id] then
                receipts.applied[id] = true
                local left = apply(entry.key, { PlayerId = player.UserId, PurchaseId = id, ProductId = entry.productId }, entry.amount, true)
                hold(player.UserId, id, entry.key, left == false and entry.amount or left)
            end
        end
    end

    local deps = { key = function(productId) return productIds[productId] end, amount = amount, update = update, hold = hold,
        apply = function(key, receipt, value) return apply(key, receipt, value, false) end }
    function service.processReceipt(receipt)
        local outcome = ShopService.process(receipts, receipt, deps)
        if outcome == ShopService.GRANTED then return Enum.ProductPurchaseDecision.PurchaseGranted end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    MarketplaceService.ProcessReceipt = service.processReceipt
    -- Studio playtests (DebugService) before the dashboard IDs exist: a receipt for `key`
    -- through the same ledger path, and owning a pass.
    function service.debugReceipt(player, key, purchaseId)
        local debugDeps = table.clone(deps)
        debugDeps.key = function() return Shop.entry(config, key) and not Shop.isPass(config, key) and key or nil end
        return ShopService.process(receipts, { PurchaseId = purchaseId, ProductId = 0, PlayerId = player.UserId }, debugDeps)
    end
    -- Studio checks: what this server holds for `userId`, and a settle now.
    function service.debugHeld(userId) track(); return held[userId] end
    function service.debugSettle(release) track(); settle(release) end
    game:BindToClose(function()
        track()
        settle(true)
    end)

    local function refresh(player)
        if ctx.Pets then ctx.Pets.refresh(player) end
        if ctx.Skins then ctx.Skins.refresh(player) end
        ctx.Cycle.send(player)
    end
    -- On join, after the profile loads: which passes they own (Roblox decides; see the
    -- header). A slot pass that's gone (refunded) puts the extra pets away. Purchases a
    -- closed server still owed them come here too.
    function service.sync(player)
        task.spawn(service.recover, player)
        local record = ctx.profiles.records[player.UserId]
        local has, ok = ShopService.sync(config, function(id) return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) end,
            record and record.profile.passes, RunService:IsStudio())
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

    -- Opens the Roblox prompt for `key` if `player` may buy it now (BuyShop, and the suit
    -- stands' prompts: SkinService).
    function service.buy(player, key)
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
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = "BuyShop"
    remote.Parent = ctx.Remote.folder
    remote.OnServerEvent:Connect(service.buy)
    -- Tells the buyer's client a pass was just bought here, so it celebrates
    -- (PurchaseCelebrationController); ownership loading on join doesn't fire it.
    local bought = Instance.new("RemoteEvent")
    bought.Name = "PassBought"
    bought.Parent = ctx.Remote.folder
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
        local name = key
        local tier = tonumber(key:match("^Gym(%d+)$"))
        if tier and config.TrainingTiers[tier] then name = "The " .. config.TrainingTiers[tier].multiplier .. "x Gym" end
        if key == config.SpaceXGym.key then name = "The SpaceX Gym" end
        for _, pass in Shop.Passes do if pass.key == key then name = pass.name end end
        local skin = Skins.get(key)
        if skin then name = "The " .. skin.name end
        ctx.Remote.feedback(player, "Thanks! " .. name .. " is yours.")
        refresh(player)
        bought:FireClient(player, key)
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
    -- What's owed is written within a couple of seconds of changing, and every
    -- RENEW_SECONDS anyway (renewing the claims' leases).
    local RENEW_SECONDS = 60
    local elapsed, boosted, sinceSettle = 0, false, 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 1 then return end
        sinceSettle += elapsed
        elapsed = 0
        if effects.fillBank > 0 then drainFill() end
        track()
        if next(held) and (sinceSettle >= RENEW_SECONDS or (heldChanged and sinceSettle >= 2)) then
            sinceSettle = 0
            task.spawn(settle, false)
        end
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
