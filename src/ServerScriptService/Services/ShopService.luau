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
--   * A server effect: units are marked in the ledger BEFORE this server uses them, and
--     only marked units are ever used, so two live servers never use the same units. The
--     claim's own write marks what's used at once (the boost, recorded used outright;
--     time on a running stay, the fill the rocket can take now), and PurchaseGranted
--     follows. The rest is banked by PurchaseId (fill for the next delivery phase, time
--     for the next stay, a mission for the next spin) and marked as it's needed. Marked
--     units stay pending in the ledger until this server confirms it used them. Offer
--     limits hold for receipts too: a stay takes at most ExtraStayMax extra (the rest
--     banks), one locked mission a spin (the rest queue). Shutdown hands marked-but-unused
--     units back. When this server closes or crashes, the buyer's next join anywhere
--     takes over what's still owed once the claim's lease runs out, and what was marked
--     but never confirmed PendingGraceSeconds after that (so nothing paid for is lost),
--     and tries again, while they stay, when a claim not yet free becomes free.
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
-- with entry = { key, productId, amount (owed: not yet marked), pending (marked for use by
-- the owner, not yet confirmed used), claimed (marked by the owner's claim), owner (server),
-- leaseUntil, at }.
-- A server marks units BEFORE it uses them (moving them from `amount` to `pending`) and
-- confirms them once used (taking them off `pending`); it only ever uses units it marked,
-- and marking needs the claim, so two live servers never use the same units. When a
-- server is gone, the next takes over what's owed once its lease runs out, and what it
-- had marked but never confirmed (pending) PendingGraceSeconds after that: long enough
-- that a server merely unable to write meanwhile has long stopped, so nothing paid for is
-- lost and nothing is used twice. A boost is used in the same instant as its claim, so
-- the claim records it used outright.
ShopService.LeaseSeconds = 300
ShopService.PendingGraceSeconds = 900
ShopService.DoneLimit = 100
function ShopService.ledger(raw)
    local ledger = type(raw) == "table" and raw or {}
    if type(ledger.open) ~= "table" then ledger.open = {} end
    if type(ledger.done) ~= "table" then ledger.done = {} end
    return ledger
end

-- When a claim whose lease has run out may be taken by another server: at once, unless
-- units its server marked are still unconfirmed (then PendingGraceSeconds later).
function ShopService.freeAt(entry)
    local leaseUntil = entry.leaseUntil or 0
    return (entry.pending or 0) > 0 and leaseUntil + ShopService.PendingGraceSeconds or leaseUntil
end
-- Takes `entry` for `owner`: what its last server marked but never confirmed is owed again.
local function adopt(entry, owner, now)
    if entry.owner ~= owner then
        entry.amount = (entry.amount or 0) + (entry.pending or 0)
        entry.pending, entry.claimed = 0, 0
    end
    entry.owner, entry.leaseUntil = owner, now + ShopService.LeaseSeconds
end

-- Claims `id` for server `owner` (changes `ledger`): "done" (granted before), "busy"
-- (another server's claim, not yet free: ShopService.freeAt), or "mine", the entry (new,
-- ours already, or taken over) and how many units are marked for this server to apply
-- now: use(owed) says how much of the owed amount it uses at once (a boost, time on a
-- running stay, fill the rocket can take now). `instant` (a boost, applied in the same
-- instant) records them used outright; anything else is marked pending until settle
-- confirms it. The entry keeps them (`claimed`) so the same server, retrying after a write
-- whose answer was lost, applies the units it marked rather than marking more.
function ShopService.claim(ledger, id, fields, owner, now, use, instant)
    if table.find(ledger.done, id) then return "done" end
    local entry = ledger.open[id]
    if entry and entry.owner ~= owner and ShopService.freeAt(entry) > now then return "busy", entry end
    if not entry then
        entry = { key = fields.key, productId = fields.productId, amount = fields.amount, pending = 0, at = now }
        ledger.open[id] = entry
    end
    adopt(entry, owner, now)
    local previous = entry.claimed or 0
    local used = math.clamp(use and use(entry.amount) or 0, 0, entry.amount)
    entry.amount -= used
    if not instant then entry.pending = (entry.pending or 0) + used end
    entry.claimed = previous + used
    return "mine", entry, previous + used
end

local function trimDone(ledger)
    while #ledger.done > ShopService.DoneLimit do table.remove(ledger.done, 1) end
end

-- This server's writes to its claims, by id: { use = n (mark n more of the owed amount,
-- before using them), deliver = n (confirm n marked units used), close = true (nothing of
-- it left here: move it to done), give = n (hand back n marked but unused: shutdown) }.
-- Every claim written has its lease renewed, or let go with `release` (shutdown, or a
-- claim that couldn't be applied) so the next server takes it at once. Returns
-- { [id] = { status, used, delivered } }: status "held", "done", or "gone" (no longer
-- ours: another server took it over), the units marked and the units confirmed.
function ShopService.settle(ledger, owner, changes, now, release)
    local results = {}
    for id, change in changes do
        local entry = ledger.open[id]
        if not entry or entry.owner ~= owner then
            results[id] = { status = table.find(ledger.done, id) and "done" or "gone", used = 0, delivered = 0 }
        else
            entry.pending = entry.pending or 0
            local used = math.clamp(change.use or 0, 0, entry.amount)
            entry.amount -= used
            entry.pending += used
            local delivered = math.clamp(change.deliver or 0, 0, entry.pending)
            entry.pending -= delivered
            local give = math.clamp(change.give or 0, 0, entry.pending)
            entry.pending -= give
            entry.amount += give
            entry.claimed = 0
            if change.close and entry.amount <= 0 and entry.pending <= 0 then
                ledger.open[id] = nil
                table.insert(ledger.done, id)
                results[id] = { status = "done", used = used, delivered = delivered }
            else
                -- Let go: free now (anything still pending waits out its grace from now).
                entry.leaseUntil = release and now or now + ShopService.LeaseSeconds
                results[id] = { status = "held", used = used, delivered = delivered }
            end
        end
    end
    trimDone(ledger)
    return results
end

-- Takes over the buyer's claims that are free (ShopService.freeAt: the lease has run out,
-- and any unconfirmed units' grace too), except those `skip(id, entry)` leaves (UFOs:
-- Roblox's own receipt retry finishes those; claims this server still holds). Units its
-- last server marked but never confirmed are owed again; a claim with nothing owed is
-- closed. Returns { [id] = entry } and when the soonest claim not yet free will be (nil
-- if none), for a retry.
function ShopService.takeover(ledger, owner, now, skip)
    local taken, retryAt = {}, nil
    for id, entry in ledger.open do
        if not skip(id, entry) then
            local free = ShopService.freeAt(entry)
            if free > now then
                retryAt = math.min(retryAt or math.huge, free)
            else
                adopt(entry, owner, now)
                if (entry.amount or 0) <= 0 then
                    ledger.open[id] = nil
                    table.insert(ledger.done, id)
                else
                    taken[id] = entry
                end
            end
        end
    end
    trimDone(ledger)
    return taken, retryAt
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
--   plan(key, owed)           -> how much of `owed` this server uses at once (no side effects)
--   instant(key)              -> true when that use happens in the same instant (a boost):
--                                recorded used in the claim itself, never pending
--   update(userId, transform) -> ok (UpdateAsync on the buyer's ledger; may yield);
--                                transform(ledger, now) returns true to write
--   apply(key, receipt, value, used) -> true, or false: can't yet (a UFO for a buyer who
--                                isn't here, or whose save failed). `value` is the part of
--                                the purchase in play here, `used` of it already marked.
--   hold(userId, id, key, owed, leaseUntil) -> tracks the claim until it's used up
-- Returns GRANTED or RETRY.
function ShopService.process(state, receipt, deps)
    local key = deps.key(receipt.ProductId)
    local id = receipt.PurchaseId
    if not key or type(id) ~= "string" or id == "" or type(receipt.PlayerId) ~= "number" then return ShopService.RETRY end
    if state.busy[id] then return ShopService.RETRY end
    -- Applied here already (and held): nothing to mark or apply again.
    if state.applied[id] then return ShopService.GRANTED end
    state.busy[id] = true
    local result = (function()
        local outcome, entry, used
        local ok = deps.update(receipt.PlayerId, function(ledger, now)
            outcome, entry, used = ShopService.claim(ledger, id, { key = key, productId = receipt.ProductId, amount = deps.amount(key) },
                state.owner, now, function(owed) return deps.plan(key, owed) end, deps.instant and deps.instant(key))
            return outcome == "mine"
        end)
        if not ok then return ShopService.RETRY end
        if outcome == "done" then return ShopService.GRANTED end
        if outcome ~= "mine" then return ShopService.RETRY end
        if not deps.apply(key, receipt, entry.amount + used, used) then
            -- Let go, so the server the buyer is on next can claim it at once.
            deps.update(receipt.PlayerId, function(ledger, now)
                ShopService.settle(ledger, state.owner, { [id] = {} }, now, true)
                return true
            end)
            return ShopService.RETRY
        end
        -- A UFO's apply is safe to repeat (the profile ledger); a server effect's isn't.
        if not ShopService.isUfo(key) then state.applied[id] = true end
        deps.hold(receipt.PlayerId, id, key, entry.amount, entry.leaseUntil)
        return ShopService.GRANTED
    end)()
    state.busy[id] = nil
    return result
end

-- Server-wide effects bought with products. The banks remember which purchase each part
-- came from (`id`) and how much of it is marked used in the ledger (`reserved`): only
-- reserved units are ever used. Fills and stays are { id, units / seconds, reserved }
-- oldest first, guarantees { mission, id, reserved = bool }. `delivered[id]` counts units
-- used since the service last collected them (takeDelivered), to confirm in the ledger.
function ShopService.newEffects()
    return { boostUntil = 0, fillBank = 0, fills = {}, stayBank = 0, stays = {}, guarantees = {}, delivered = {} }
end
local function deliver(effects, id, n)
    if id ~= nil and n > 0 then effects.delivered[id] = (effects.delivered[id] or 0) + n end
end
-- The units used per purchase since the last call (and clears the count).
function ShopService.takeDelivered(effects)
    local delivered = effects.delivered
    effects.delivered = {}
    return delivered
end
-- Uses `amount` reserved units off the front of a bank list (oldest purchase first).
local function consume(effects, list, field, amount)
    for index = 1, #list do
        if amount <= 0 then break end
        local item = list[index]
        local take = math.min(amount, item.reserved)
        item[field] -= take
        item.reserved -= take
        amount -= take
        deliver(effects, item.id, take)
    end
    for index = #list, 1, -1 do
        if list[index][field] <= 0 then table.remove(list, index) end
    end
end
local function reservedIn(list)
    local total = 0
    for _, item in list do total += item.reserved end
    return total
end
-- What's still banked of purchase `id` here, and how much of that is reserved.
function ShopService.owed(effects, id)
    local left, reserved = 0, 0
    for _, item in effects.fills do if item.id == id then left += item.units; reserved += item.reserved end end
    for _, item in effects.stays do if item.id == id then left += item.seconds; reserved += item.reserved end end
    for _, item in effects.guarantees do if item.id == id then left += 1; reserved += item.reserved and 1 or 0 end end
    return left, reserved
end
-- Marks `n` more units of purchase `id` reserved (the ledger has them marked used).
function ShopService.reserve(effects, id, n)
    for _, list in { effects.fills, effects.stays } do
        for _, item in list do
            if n <= 0 then return end
            if item.id == id then
                local size = item.units or item.seconds
                local add = math.min(n, size - item.reserved)
                item.reserved += add
                n -= add
            end
        end
    end
    for _, item in effects.guarantees do
        if n <= 0 then return end
        if item.id == id and not item.reserved then item.reserved, n = true, n - 1 end
    end
end
-- Drops whatever of purchase `id` isn't reserved (another server took its claim over;
-- reserved units were marked used before that, so they stay usable here).
function ShopService.forfeit(effects, id)
    for _, entry in { { effects.fills, "units", "fillBank" }, { effects.stays, "seconds", "stayBank" } } do
        local list, field, total = entry[1], entry[2], entry[3]
        for index = #list, 1, -1 do
            local item = list[index]
            if item.id == id then
                effects[total] -= item[field] - item.reserved
                item[field] = item.reserved
                if item[field] <= 0 then table.remove(list, index) end
            end
        end
    end
    for index = #effects.guarantees, 1, -1 do
        local item = effects.guarantees[index]
        if item.id == id and not item.reserved then table.remove(effects.guarantees, index) end
    end
end
-- Training boost: each purchase adds `seconds` after whatever is left.
function ShopService.boost(effects, now, seconds)
    effects.boostUntil = math.max(now, effects.boostUntil) + seconds
end
function ShopService.trainingMultiplier(config, effects, now)
    return now < effects.boostUntil and config.Shop.ServerTrainingMultiplier or 1
end
-- Banks `units` of fill bought by purchase `id`, `reserved` of them usable now.
function ShopService.bankFill(effects, units, id, reserved)
    effects.fillBank += units
    table.insert(effects.fills, { id = id, units = units, reserved = math.min(reserved or 0, units) })
end
-- Units the rocket can take now: what's left of the current delivery phase and, while
-- building, the fuel after it (fill overflows from Metal into Fuel).
function ShopService.room(rocket)
    local material = Rocket.PhaseMaterial[rocket.phase]
    if not material then return 0 end
    local room = rocket.required[material] - rocket.totals[material]
    if material == "Metal" then room += rocket.required.Fuel - rocket.totals.Fuel end
    return math.max(0, room)
end
-- Reserved fill units waiting here.
function ShopService.reservedFill(effects) return reservedIn(effects.fills) end
-- Pours reserved banked fill into the rocket's current phase, Metal or Fuel. What the
-- phase doesn't need stays banked: Metal overflow goes into Fuel, Fuel overflow into the
-- next rocket. Returns the units added and whether the phase advanced.
function ShopService.fill(rocket, effects)
    local ready = reservedIn(effects.fills)
    if not Rocket.PhaseMaterial[rocket.phase] or ready <= 0 then return 0, false end
    local added, advanced = rocket:fill(ready)
    effects.fillBank -= added
    consume(effects, effects.fills, "units", added)
    return added, advanced
end
-- Extra time bought by purchase `id`: `reserved` seconds of it go into the running stay
-- (up to `max` extra per stay); the rest is banked for a later stay. Returns the seconds
-- added to this stay.
function ShopService.extendStay(effects, stay, seconds, id, max, reserved)
    reserved = math.min(reserved or 0, seconds)
    local add = stay and math.max(0, math.min(reserved, max - stay.extra)) or 0
    if add > 0 then
        stay.total += add
        stay.extra += add
        deliver(effects, id, add)
    end
    if seconds - add > 0 then
        effects.stayBank += seconds - add
        table.insert(effects.stays, { id = id, seconds = seconds - add, reserved = reserved - add })
    end
    return add
end
-- Reserved banked seconds a stay may start with (up to `max`).
function ShopService.stayReady(effects, max)
    return math.min(reservedIn(effects.stays), max)
end
-- A new stay of `seconds` plus `banked` reserved banked seconds (at most stayReady).
function ShopService.beginStay(effects, seconds, banked)
    banked = math.min(banked or 0, reservedIn(effects.stays))
    effects.stayBank -= banked
    consume(effects, effects.stays, "seconds", banked)
    return { total = seconds + banked, extra = banked }
end
-- Banks a guaranteed next mission bought by purchase `id` (`reserved`: usable at once).
function ShopService.guarantee(effects, mission, id, reserved)
    table.insert(effects.guarantees, { mission = mission, id = id, reserved = reserved == true })
end
-- The next reserved guaranteed mission index, or nil (taken by the spin). One a spin:
-- any others wait for the following spins.
function ShopService.takeGuarantee(effects)
    for index, item in effects.guarantees do
        if item.reserved then
            table.remove(effects.guarantees, index)
            deliver(effects, item.id, 1)
            return item.mission
        end
    end
    return nil
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
    -- This server's claims, per buyer: held[userId][purchaseId] = { key, ufo, owed (still
    -- owed in the ledger), want (units to mark at the next write), deliver (units used, to
    -- confirm at the next write), leaseUntil };
    -- holder[purchaseId] = userId. Written whenever there's something to mark or close,
    -- and every RENEW_SECONDS anyway (renewing the leases).
    local held, holder, settling = {}, {}, false
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

    -- Asks for `n` more units of purchase `id` to be marked used at the next write (never
    -- more than it still owes).
    local function want(id, n)
        local h = holder[id] and held[holder[id]] and held[holder[id]][id]
        if not h or n <= 0 then return 0 end
        local take = math.min(n, h.owed - h.want)
        h.want += take
        return take
    end
    -- Asks for `n` more units of the oldest unreserved purchases in a bank list.
    local function wantFrom(list, field, n)
        for _, item in list do
            if n <= 0 then return end
            local h = holder[item.id] and held[holder[item.id]][item.id]
            local free = item[field] - item.reserved - (h and h.want or 0)
            if free > 0 then n -= want(item.id, math.min(n, free)) end
        end
    end
    local function wanting()
        for _, mine in held do
            for _, h in mine do if h.want > 0 then return true end end
        end
        return false
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
    local function hold(userId, id, key, owed, leaseUntil)
        held[userId] = held[userId] or {}
        held[userId][id] = { key = key, ufo = ShopService.isUfo(key), owed = owed, want = 0, deliver = 0, leaseUntil = leaseUntil }
        holder[id] = userId
    end
    -- Collects what the banks used into the held claims, to confirm at the next write.
    local function collect()
        for id, n in ShopService.takeDelivered(effects) do
            local h = holder[id] and held[holder[id]] and held[holder[id]][id]
            if h then h.deliver += n end
        end
    end
    -- Whether a held claim has something to write now: units to mark or confirm, or
    -- nothing left here.
    local function due(id, h)
        return h.ufo or h.want > 0 or h.deliver > 0 or ShopService.owed(effects, id) == 0
    end
    -- Writes every buyer's held claims: marks what's wanted (then those units are usable
    -- here), closes the used up, renews leases; `release` (shutdown) hands back what's
    -- marked but unused and lets every claim go. True when every write went through.
    local function settle(release, renew)
        if settling then return false end
        settling = true
        collect()
        local all = true
        for userId, mine in held do
            local needed = release or renew
            for id, h in mine do if due(id, h) then needed = true end end
            if not needed then continue end
            local changes = {}
            for id, h in mine do
                local _, reserved = ShopService.owed(effects, id)
                if release then
                    changes[id] = { deliver = h.deliver, give = not h.ufo and reserved or 0 }
                elseif h.ufo then
                    changes[id] = { use = h.owed, deliver = h.owed, close = true }
                else
                    changes[id] = { use = h.want, deliver = h.deliver, close = ShopService.owed(effects, id) == 0 and h.owed - h.want <= 0 }
                end
            end
            local results, at
            local written = update(userId, function(ledger, now)
                results, at = ShopService.settle(ledger, receipts.owner, changes, now, release), now
                return true
            end)
            if not written then
                all = false
            elseif not release then
                for id, outcome in results do
                    local h = mine[id]
                    if h then
                        if outcome.used > 0 and not h.ufo then ShopService.reserve(effects, id, outcome.used) end
                        h.owed -= outcome.used
                        h.want = math.max(0, h.want - outcome.used)
                        h.deliver = math.max(0, h.deliver - outcome.delivered)
                        h.leaseUntil = at + ShopService.LeaseSeconds
                        if outcome.status ~= "held" then
                            -- Taken over elsewhere (this server stopped renewing): what isn't
                            -- reserved here is theirs now.
                            if outcome.status == "gone" then ShopService.forfeit(effects, id) end
                            mine[id], holder[id] = nil, nil
                        end
                    end
                end
                if not next(mine) then held[userId] = nil end
            end
        end
        settling = false
        return all
    end
    -- Writes now if anything is waiting (`wait`: until it's done or `timeout` passes).
    local function settleNow(timeout)
        local deadline = os.clock() + (timeout or 3)
        repeat
            if not settling then
                if settle(false, false) and not wanting() then return true end
            end
            task.wait(0.1)
        until os.clock() >= deadline
        return not wanting()
    end

    -- Launch calls these around the reward stay; the stay's length can grow while it runs.
    -- prepareStay marks banked time (up to ExtraStayMax) and the next guaranteed mission
    -- used, waiting up to `timeout` seconds, and returns the banked seconds ready to add.
    function service.prepareStay(timeout)
        local max = config.Shop.ExtraStayMax
        local short = math.min(effects.stayBank, max) - ShopService.stayReady(effects, math.huge)
        if short > 0 then wantFrom(effects.stays, "seconds", short) end
        local ready = false
        for _, item in effects.guarantees do if item.reserved then ready = true end end
        if not ready and effects.guarantees[1] then want(effects.guarantees[1].id, 1) end
        if wanting() then settleNow(timeout) end
        return ShopService.stayReady(effects, max)
    end
    -- A new stay of `seconds` plus `banked` ready banked seconds.
    function service.beginStay(seconds, banked)
        stay = ShopService.beginStay(effects, seconds, banked)
        return stay
    end
    function service.endStay() stay = nil end
    function service.takeGuarantee() return ShopService.takeGuarantee(effects) end

    -- Pours reserved fill in; when the rocket could take more than is reserved, asks for
    -- more to be marked (it pours on a later tick).
    local function drainFill()
        local rocket = ctx.Cycle.rocket
        local added, advanced = ShopService.fill(rocket, effects)
        while added > 0 do
            ctx.Cargo.delivered(advanced)
            if ctx.Cycle.rocket ~= rocket or not advanced then break end
            added, advanced = ShopService.fill(rocket, effects)
        end
        local short = math.min(ShopService.room(ctx.Cycle.rocket), effects.fillBank) - ShopService.reservedFill(effects)
        if short > 0 then wantFrom(effects.fills, "units", short) end
    end

    -- What a purchase of `key` is worth.
    local function amount(key)
        local units = tonumber(key:match("^Fill(%d+)$"))
        if units then return units end
        if key == "ServerTraining" then return config.Shop.ServerTrainingSeconds end
        if key == "ExtraStay" then return config.Shop.ExtraStaySeconds end
        return 1
    end
    -- How much of `owed` units of `key` this server uses the moment the receipt is claimed
    -- (marked used in that same write): the whole boost; time on a running stay up to its
    -- ExtraStayMax; the fill the rocket can take now; a mission while this stay's spin is
    -- still to come and none is locked in yet. The rest banks.
    local function plan(key, owed)
        if key == "ServerTraining" then return owed end
        if key:match("^Fill%d+$") then return math.min(owed, math.max(0, ShopService.room(ctx.Cycle.rocket) - ShopService.reservedFill(effects))) end
        if key == "ExtraStay" then return stay and math.max(0, math.min(owed, config.Shop.ExtraStayMax - stay.extra)) or 0 end
        if key:match("^Next") then
            local coming = stay ~= nil and ctx.Cycle.rocket.phase == "Rewarding" and ctx.Cycle.wheel == nil
            for _, item in effects.guarantees do if item.reserved then coming = false end end
            return coming and math.min(owed, 1) or 0
        end
        return 0
    end

    -- Applies purchase `receipt` (of `key`): `value` units of it in play here, `used` of
    -- them marked used already. False when it can't be applied yet (a UFO: buyer not here
    -- or not saved). `restored`: taken over from a server that closed (the buyer is told,
    -- nobody else).
    local function apply(key, receipt, value, used, restored)
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
                    return ctx.profiles:saveNow(player.UserId)
                end
            end
            return false
        end
        if key == "ServerTraining" then
            ShopService.boost(effects, workspace:GetServerTimeNow(), used)
            announce(name .. " boosted training " .. config.Shop.ServerTrainingMultiplier .. "x for everyone for " .. used // 60 .. " minutes!",
                "your training boost is running here.")
        elseif key:match("^Fill%d+$") then
            local material = Rocket.PhaseMaterial[ctx.Cycle.rocket.phase]
            local text = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            ShopService.bankFill(effects, value, id, used)
            announce(name .. " added " .. text .. (material and " " .. material .. " to the rocket!" or " units to the next rocket!"),
                text .. " units of fill went into this rocket.")
            drainFill()
        elseif key == "ExtraStay" then
            -- Time on this stay only once every passenger's longer trip is saved
            -- (LaunchService.growTrips); otherwise it waits for the next stay.
            local max = config.Shop.ExtraStayMax
            local room = stay and math.max(0, math.min(used, max - stay.extra)) or 0
            local grown = room > 0 and ctx.Launch and ctx.Launch.growTrips(room)
            local add = ShopService.extendStay(effects, grown and stay or nil, value, id, max, used)
            if add > 0 then
                ctx.Cycle.deadline += add
                announce(name .. " added " .. add .. " seconds to this stay!", add .. " more seconds on this stay.")
            end
            if value - add > 0 then
                announce(name .. " added " .. value - add .. " seconds to the next stay!", value - add .. " more seconds on the next stay.")
            end
        else
            local mission = Missions.index(key:match("^Next(.+)$") or "")
            if mission then
                ShopService.guarantee(effects, mission, id, used >= 1)
                announce(name .. " locked in the next mission: " .. config.Destinations[mission].name .. "!",
                    "the next mission here is " .. config.Destinations[mission].name .. ".")
            end
        end
        ctx.Cycle.broadcast()
        return true
    end

    -- On join: what a closed server still owed this buyer is banked here. A claim still
    -- leased elsewhere (that server just crashed) is tried again when its lease runs out,
    -- for as long as the buyer stays.
    local retrying = {}
    function service.recover(player)
        local userId = player.UserId
        local taken, retryAt
        local written = update(userId, function(ledger, now)
            taken, retryAt = ShopService.takeover(ledger, receipts.owner, now, function(id, entry)
                return ShopService.isUfo(entry.key) or holder[id] ~= nil
            end)
            return true
        end)
        if not player.Parent then return end
        for id, entry in written and taken or {} do
            if not receipts.applied[id] then
                receipts.applied[id] = true
                apply(entry.key, { PlayerId = userId, PurchaseId = id, ProductId = entry.productId }, entry.amount, 0, true)
                hold(userId, id, entry.key, entry.amount, entry.leaseUntil)
            end
        end
        -- Again when the soonest outstanding lease runs out (or in a minute after a failed write).
        local wait = not written and 60 or retryAt and math.max(1, retryAt - os.time() + 1)
        if wait and not retrying[userId] then
            retrying[userId] = true
            task.delay(wait, function()
                retrying[userId] = nil
                if player.Parent then service.recover(player) end
            end)
        end
    end

    local deps = { key = function(productId) return productIds[productId] end, amount = amount, plan = plan, update = update, hold = hold,
        instant = function(key) return key == "ServerTraining" end,
        apply = function(key, receipt, value, used) return apply(key, receipt, value, used, false) end }
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
    -- Studio checks: what this server holds for `userId`, and a write now.
    function service.debugHeld(userId) return held[userId] end
    function service.debugSettle(release) return settle(release, true) end
    game:BindToClose(function() settle(true, true) end)

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
    -- Claims are written as soon as there's something to mark or close, and every
    -- RENEW_SECONDS anyway (renewing their leases).
    local RENEW_SECONDS = 60
    local elapsed, boosted, sinceRenew, retryAfter = 0, false, 0, 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 1 then return end
        sinceRenew += elapsed
        elapsed = 0
        if effects.fillBank > 0 then drainFill() end
        collect()
        if next(held) and not settling then
            local renew = sinceRenew >= RENEW_SECONDS
            local pending = renew
            for _, mine in held do
                for id, h in mine do if due(id, h) then pending = true end end
            end
            if renew then sinceRenew = 0 end
            -- After a failed write, wait a little before the next (a DataStore outage).
            if pending and os.clock() >= retryAfter then
                task.spawn(function()
                    if not settle(false, renew) then retryAfter = os.clock() + 10 end
                end)
            end
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
