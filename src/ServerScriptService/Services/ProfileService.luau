local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.Pets)
local Tutorial = require(script.Parent.TutorialService)
local Profiles = {}
Profiles.__index = Profiles

local function defaults()
    return { schemaVersion = 7, strengthLevel = 0, speedLevel = 0, planetBonuses = { strength = 0, speed = 0 }, completedLaunches = 0, lifetimeDeliveries = 0, coins = 0, rewardedLaunchIds = {},
        blackHolesVisited = 0, tutorialStep = Tutorial.Steps[1], seenCallouts = {}, upgrades = {}, purchaseIds = {},
        pets = {}, equippedPets = {}, ufos = {}, passes = {}, openLaunches = {} }
end

local function copy(profile)
    local result = table.clone(profile)
    result.planetBonuses = table.clone(profile.planetBonuses)
    result.rewardedLaunchIds = table.clone(profile.rewardedLaunchIds)
    result.rewardedLaunchTicks = table.clone(profile.rewardedLaunchTicks or {})
    result.seenCallouts = table.clone(profile.seenCallouts)
    result.upgrades = table.clone(profile.upgrades)
    result.purchaseIds = table.clone(profile.purchaseIds)
    result.pets = table.clone(profile.pets)
    result.equippedPets = table.clone(profile.equippedPets)
    result.passes = table.clone(profile.passes or {})
    result.ufos = {}
    for index, ufo in profile.ufos or {} do result.ufos[index] = table.clone(ufo) end
    result.openLaunches = {}
    for id, entry in profile.openLaunches or {} do result.openLaunches[id] = table.clone(entry) end
    return result
end

-- A UFO id clients can parse out of the Ufos attribute ("id:tier:hatchAt;…").
local function ufoIdOk(id)
    return type(id) == "string" and #id >= 1 and #id <= 16 and id:match("^[%w%-_]+$") ~= nil
end

local function validate(raw, config)
    if raw == nil then return defaults() end
    if type(raw) ~= "table" or (type(raw.schemaVersion) ~= "number" or raw.schemaVersion < 1 or raw.schemaVersion > 7) then error("Unsupported profile schema; refusing overwrite") end
    -- v1 -> v2 adds coins.
    if raw.schemaVersion == 1 then raw = table.clone(raw); raw.schemaVersion, raw.coins = 2, 0 end
    -- v2 -> v3 adds the tutorial; anyone who already delivered has played, so skip it.
    if raw.schemaVersion == 2 then
        raw = table.clone(raw)
        raw.schemaVersion, raw.seenCallouts = 3, {}
        raw.tutorialStep = (type(raw.lifetimeDeliveries) == "number" and raw.lifetimeDeliveries > 0) and Tutorial.Done or Tutorial.Steps[1]
    end
    -- v3 -> v4 adds coin upgrades and the purchase request ledger.
    if raw.schemaVersion == 3 then
        raw = table.clone(raw)
        raw.schemaVersion, raw.upgrades, raw.purchaseIds = 4, {}, {}
    end
    -- v4 -> v5 drops the retired Carry Capacity upgrade (no refund: persistence was never on).
    if raw.schemaVersion == 4 then
        raw = table.clone(raw)
        raw.schemaVersion = 5
        if type(raw.upgrades) == "table" then
            raw.upgrades = table.clone(raw.upgrades)
            raw.upgrades.CarryCapacity = nil
        end
    end
    -- v5 -> v6 caps levels at the new 10-level max (no refund: persistence was never on).
    if raw.schemaVersion == 5 then
        raw = table.clone(raw)
        raw.schemaVersion = 6
        if type(raw.upgrades) == "table" then
            raw.upgrades = table.clone(raw.upgrades)
            for track, level in raw.upgrades do
                local spec = config.Upgrades[track]
                if spec and type(level) == "number" and level > spec.max then raw.upgrades[track] = spec.max end
            end
        end
    end
    -- v6 -> v7 adds pets: owned counts, the equipped list and the UFO on its way.
    if raw.schemaVersion == 6 then
        raw = table.clone(raw)
        raw.schemaVersion, raw.pets, raw.equippedPets = 7, {}, {}
    end
    if not Tutorial.valid(raw.tutorialStep) then error("Invalid tutorial step") end
    if type(raw.upgrades) ~= "table" or type(raw.purchaseIds) ~= "table" then error("Invalid upgrades") end
    for track, level in raw.upgrades do
        local spec = config.Upgrades[track]
        if not spec or type(level) ~= "number" or level < 0 or level % 1 ~= 0 or level > spec.max then error("Invalid upgrade " .. tostring(track)) end
    end
    for _, id in raw.purchaseIds do if type(id) ~= "string" then error("Invalid purchase ledger") end end
    -- An ID that isn't valid UTF-8 would make every DataStore write fail: dropped.
    for _, id in raw.purchaseIds do
        if not utf8.len(id) then
            raw = table.clone(raw)
            local kept = {}
            for _, other in raw.purchaseIds do if utf8.len(other) then table.insert(kept, other) end end
            raw.purchaseIds = kept
            break
        end
    end
    if type(raw.seenCallouts) ~= "table" then error("Invalid callouts") end
    for _, name in raw.seenCallouts do if type(name) ~= "string" then error("Invalid callouts") end end
    -- blackHolesVisited came later without a schema bump (older servers keep it untouched).
    if raw.blackHolesVisited == nil then
        raw = table.clone(raw)
        raw.blackHolesVisited = 0
    end
    -- SHOP Game Passes bought in game (ShopService), by key: also owned when Roblox's
    -- ownership check says no (Studio test purchases never show up there). Came later
    -- without a schema bump, like blackHolesVisited.
    if raw.passes == nil then
        raw = table.clone(raw)
        raw.passes = {}
    end
    if type(raw.passes) ~= "table" then error("Invalid passes") end
    for _, key in raw.passes do if type(key) ~= "string" then error("Invalid passes") end end
    for _, key in { "strengthLevel", "speedLevel", "completedLaunches", "lifetimeDeliveries", "coins", "blackHolesVisited" } do
        local value = raw[key]
        if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0 then error("Invalid profile " .. key) end
    end
    if type(raw.planetBonuses) ~= "table" or type(raw.rewardedLaunchIds) ~= "table" then error("Invalid profile collections") end
    for _, key in { "strength", "speed" } do
        local value = raw.planetBonuses[key]
        if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0 then error("Invalid bonus") end
    end
    for _, id in raw.rewardedLaunchIds do if type(id) ~= "string" then error("Invalid reward ledger") end end
    if raw.rewardedLaunchTicks ~= nil then
        if type(raw.rewardedLaunchTicks) ~= "table" then error("Invalid reward ticks") end
        for id, ticks in raw.rewardedLaunchTicks do
            if type(id) ~= "string" or type(ticks) ~= "number" or ticks ~= ticks or ticks < 0 or ticks % 1 ~= 0 or ticks == math.huge then error("Invalid reward ticks") end
        end
    end
    if type(raw.pets) ~= "table" or type(raw.equippedPets) ~= "table" then error("Invalid pets") end
    for id, count in raw.pets do
        if type(id) ~= "string" or type(count) ~= "number" or count < 1 or count % 1 ~= 0 or count > Pets.MaxCount then error("Invalid pets") end
    end
    -- Slot passes (Shared.Shop) raise the limit; ShopService trims if a pass is gone.
    if #raw.equippedPets > Pets.MaxEquipped + 3 then error("Invalid equipped pets") end
    for _, id in raw.equippedPets do if type(id) ~= "string" then error("Invalid equipped pets") end end
    -- UFOs on their way: a list (up to 3 with Triple Hatch). Older saves held one `ufo`.
    if raw.ufo ~= nil then
        raw = table.clone(raw)
        raw.ufos, raw.ufo = { raw.ufo }, nil
    end
    if raw.ufos ~= nil and (type(raw.ufos) ~= "table" or #raw.ufos > 3) then error("Invalid UFO") end
    for _, ufo in raw.ufos or {} do
        if type(ufo) ~= "table" or not Pets.Ufos[ufo.tier] or type(ufo.pet) ~= "string"
            or type(ufo.remaining) ~= "number" or ufo.remaining ~= ufo.remaining or ufo.remaining < 0 or ufo.remaining > 86400
            or (ufo.id ~= nil and type(ufo.id) ~= "string") then
            error("Invalid UFO")
        end
    end
    -- Launches a passenger was locked into but whose stay hadn't finished saving
    -- (LaunchService; Profiles:lockLaunch). Came later without a schema bump.
    if raw.openLaunches ~= nil then
        if type(raw.openLaunches) ~= "table" then error("Invalid open launches") end
        for id, entry in raw.openLaunches do
            if type(id) ~= "string" or type(entry) ~= "table" or type(entry.ticks) ~= "number" or entry.ticks ~= entry.ticks or entry.ticks < 0
                or entry.ticks % 1 ~= 0 or entry.ticks == math.huge or type(entry.launches) ~= "number" or entry.launches < 1 or entry.launches % 1 ~= 0
                or entry.launches > 100 or (entry.blackHole ~= nil and type(entry.blackHole) ~= "boolean") then
                error("Invalid open launches")
            end
        end
    end
    local result = copy(raw)
    -- Pets that left the catalog are dropped, not refused; so is an equip of a pet not owned.
    for id in raw.pets do if not Pets.get(id) then result.pets[id] = nil end end
    local equipped, used = {}, {}
    for _, id in raw.equippedPets do
        used[id] = (used[id] or 0) + 1
        if used[id] <= (result.pets[id] or 0) then table.insert(equipped, id) end
    end
    result.equippedPets = equipped
    for index, ufo in result.ufos do
        if not Pets.get(ufo.pet) then ufo.pet = Pets.ByRarity[Pets.Ufos[ufo.tier].Rarity][1] end
        -- A stable id per UFO lets clients keep drawing the same saucer.
        if not ufoIdOk(ufo.id) then ufo.id = "u" .. index end
    end
    for _, id in result.rewardedLaunchIds do
        if result.rewardedLaunchTicks[id] == nil then result.rewardedLaunchTicks[id] = 1 end
    end
    -- The suit chosen to wear (SkinService), by key; nil wears the best owned. Came later
    -- without a schema bump; anything but a short string is dropped, not refused.
    if type(result.suit) ~= "string" or #result.suit > 40 then result.suit = nil end
    return result
end
Profiles.validate = validate

-- Same pets, equipped list and UFOs (to tell whether a save left pet changes unsaved).
-- A UFO's countdown alone doesn't count: it ticks every second.
function Profiles.samePets(a, b)
    if #a.ufos ~= #b.ufos then return false end
    for index, ufo in a.ufos do
        local other = b.ufos[index]
        if ufo.tier ~= other.tier or ufo.pet ~= other.pet then return false end
    end
    if #a.equippedPets ~= #b.equippedPets then return false end
    for index, id in a.equippedPets do if b.equippedPets[index] ~= id then return false end end
    for id, count in a.pets do if b.pets[id] ~= count then return false end end
    for id in b.pets do if not a.pets[id] then return false end end
    return true
end

-- The pass keys in either list, `a`'s order first.
function Profiles.mergePasses(a, b)
    local result = table.clone(a or {})
    for _, key in b or {} do
        if not table.find(result, key) then table.insert(result, key) end
    end
    return result
end

-- Credits accepted delivery units: lifetime deliveries plus CoinsPerUnit coins each.
-- Callers pass only what Rocket:deliver accepted, so coins can't outnumber carried units.
function Profiles.credit(profile, delivered, config, multiplier)
    if type(delivered) ~= "number" or delivered <= 0 or delivered % 1 ~= 0 then return 0 end
    -- `multiplier`: 2x Coins (ShopService) times the friend boost (FriendService) and suit (SkinService).
    local coins = delivered * config.CoinsPerUnit * (multiplier or 1)
    profile.lifetimeDeliveries += delivered
    profile.coins += coins
    return coins
end

-- Commits stay rewards: `batch[launchId]` = cumulative ticks earned. Idempotent per launch
-- ID (the ledger keeps the ticks already paid), so a retried or recovered batch never pays
-- twice. `launches[id]` (default 1) and `blackHoles[id]` count on a launch's first reward.
function Profiles.applyBatch(profile, batch, config, launches, blackHoles)
    profile.rewardedLaunchTicks = profile.rewardedLaunchTicks or {}
    for id, ticks in batch do
        local previous = profile.rewardedLaunchTicks[id] or (table.find(profile.rewardedLaunchIds, id) and 1 or 0)
        local delta = math.max(0, ticks - previous)
        if not table.find(profile.rewardedLaunchIds, id) then
            profile.completedLaunches += launches and launches[id] or 1
            if blackHoles and blackHoles[id] then profile.blackHolesVisited = (profile.blackHolesVisited or 0) + 1 end
            table.insert(profile.rewardedLaunchIds, id)
        end
        local cap = config.MaxPlanetBonus
        profile.planetBonuses.strength = math.min(cap, profile.planetBonuses.strength + delta * config.Planet.StrengthBonus)
        profile.planetBonuses.speed = math.min(cap, profile.planetBonuses.speed + delta * config.Planet.SpeedBonus)
        profile.rewardedLaunchTicks[id] = math.max(previous, ticks)
    end
    while #profile.rewardedLaunchIds > config.RecentRewardLimit do
        -- Never evict an ID in this transaction's batch.
        local evicted = false
        for index, id in profile.rewardedLaunchIds do
            if not batch[id] then profile.rewardedLaunchTicks[id] = nil; table.remove(profile.rewardedLaunchIds, index); evicted = true; break end
        end
        if not evicted then break end
    end
    return profile
end

-- A launch left open by a server that closed or crashed during the flight or stay: the
-- whole trip is paid (its stay's ticks, less any already saved) and closed. Runs inside
-- the load's UpdateAsync, so only the server taking the session does it. True if any.
function Profiles.recoverLaunches(profile, config)
    if not next(profile.openLaunches or {}) then return false end
    local batch, launches, blackHoles = {}, {}, {}
    for id, entry in profile.openLaunches do
        batch[id], launches[id], blackHoles[id] = entry.ticks, entry.launches, entry.blackHole
    end
    Profiles.applyBatch(profile, batch, config, launches, blackHoles)
    profile.openLaunches = {}
    return true
end

local function sameKeys(a, b)
    for key in a do if b[key] == nil then return false end end
    for key in b do if a[key] == nil then return false end end
    return true
end

function Profiles.new(config, changed)
    return setmetatable({ config = config, changed = changed, records = {}, owner = HttpService:GenerateGUID(false), store = config.PersistenceEnabled and DataStoreService:GetDataStore(config.DataStoreName) or nil,
        -- A load finding another server's lock retries every `retrySeconds` for up to
        -- `waitSeconds` (default: the lease plus 10 s). PersistenceCheck shortens both.
        retrySeconds = 5, waitSeconds = nil }, Profiles)
end

-- Whether progress is really saved (false in Studio without API access).
function Profiles:persistent()
    return self.store ~= nil
end

-- Studio without "Enable Studio Access to API Services" can't reach DataStores: drop to
-- unsaved progress instead of failing every load. True when it did.
function Profiles:studioFallback(err)
    if not self.store or not RunService:IsStudio() then return false end
    local text = tostring(err)
    if not (text:find("Studio", 1, true) or text:find("API", 1, true) or text:find("403", 1, true)) then return false end
    warn("Rocket profiles: no DataStore access in Studio, progress won't save:", text)
    self.store = nil
    return true
end

function Profiles:load(userId)
    local previous = self.records[userId]
    if previous and previous.released then
        while previous.busy do task.wait(0.1) end
        previous = nil
    end
    if previous and not string.find(previous.status, "Load failed", 1, true) then
        while previous.busy do task.wait(0.1) end
        previous.leaving = false
        self.changed(userId)
        return not previous.blocked
    end
    local record = { profile = defaults(), pending = {}, status = "Loading", busy = true, leaving = false }
    self.records[userId] = record
    local function attempt()
        return pcall(function()
            if not self.store then return defaults() end
            local now = os.time()
            return self.store:UpdateAsync("Player_" .. userId, function(raw)
                local current = validate(raw, self.config)
                if current.session and current.session.owner ~= self.owner and current.session.expires > now then return nil end
                -- A record still held here (rejoining this server) never reaches this
                -- load, so open launches found now belong to a server that's gone.
                Profiles.recoverLaunches(current, self.config)
                current.session = { owner = self.owner, expires = now + self.config.LeaseSeconds }
                -- The user ID tags the key for Roblox's data-erasure requests.
                return current, { userId }
            end)
        end)
    end
    local ok, profile = attempt()
    if not ok and self:studioFallback(profile) then ok, profile = attempt() end
    -- Locked by the server they just left (it saves and lets go, or the lease runs out):
    -- wait and try again rather than fail.
    local deadline = os.clock() + (self.waitSeconds or self.config.LeaseSeconds + 10)
    while ok and profile == nil and os.clock() < deadline do
        record.status = "Loading — finishing your last server's save"
        self.changed(userId)
        task.wait(self.retrySeconds)
        ok, profile = attempt()
    end
    record.busy = false
    if not ok or not profile then
        record.status = "Load failed — rejoin; progress disabled"
        warn("Rocket profile load failed", userId, ok and "Profile in use" or tostring(profile))
        self.changed(userId)
        return false
    end
    record.profile = profile
    -- `loaded`: the real profile is in. Until then the record holds placeholder defaults
    -- that nothing may change or save (a grant made to them would be lost).
    record.loaded = true
    -- The last profile known to be in the DataStore (leaderboards publish only this).
    record.committed = copy(profile)
    record.status = self.store and "Saved" or "Studio only — progress is not permanent"
    self.changed(userId)
    return true
end

function Profiles:ready(userId)
    local record = self.records[userId]
    return record ~= nil and record.loaded == true and not record.blocked and not record.leaving
end

function Profiles:dirty(userId)
    local record = self.records[userId]
    record.dirty = true
    if self.store and not next(record.pending) then record.status = "Unsaved changes — autosave pending" end
end

-- Unsaved stay ticks show in planetBonuses at once (record.preview holds what was
-- added) so stats climb every tick; saves stay at most one per RewardSaveSeconds.
function Profiles:preview(record)
    local profile, added = record.profile, record.preview or { strength = 0, speed = 0 }
    local ticks = 0
    for id, pending in record.pending do
        local saved = (profile.rewardedLaunchTicks or {})[id] or (table.find(profile.rewardedLaunchIds, id) and 1 or 0)
        ticks += math.max(0, pending - saved)
    end
    local cap, bonuses, preview = self.config.MaxPlanetBonus, profile.planetBonuses, {}
    for stat, unit in { strength = self.config.Planet.StrengthBonus, speed = self.config.Planet.SpeedBonus } do
        local base = bonuses[stat] - added[stat]
        bonuses[stat] = math.min(cap, base + ticks * unit)
        preview[stat] = bonuses[stat] - base
    end
    record.preview = preview
end

-- `blackHole`: this launch went to the Black Hole (its first reward counts a visit).
-- `launches`: how many launches it counts for (a suit's boost; 1 by default).
function Profiles:queueReward(userId, launchId, ticks, blackHole, launches)
    local record = self.records[userId]
    if not record or not record.loaded then return end
    record.pending[launchId] = math.max(record.pending[launchId] or 0, ticks or 1)
    if launches and launches > 1 then
        record.launchCounts = record.launchCounts or {}
        record.launchCounts[launchId] = math.max(record.launchCounts[launchId] or 1, launches)
    end
    if blackHole then
        record.blackHoles = record.blackHoles or {}
        record.blackHoles[launchId] = true
    end
    record.status = "Reward pending — saving"
    self:preview(record)
    self.changed(userId)
    self:saveSoon(userId)
end

-- A save within RewardSaveSeconds (at most one per that long).
function Profiles:saveSoon(userId)
    local record = self.records[userId]
    if not record or record.saveQueued then return end
    record.saveQueued = true
    task.delay(math.max(0, (record.rewardSavedAt or -math.huge) + self.config.RewardSaveSeconds - os.clock()), function()
        record.saveQueued = false
        record.rewardSavedAt = os.clock()
        -- A save still running (its snapshot predates this change) is waited out.
        self:saveNow(userId)
    end)
end

-- A passenger locked into launch `launchId`: the trip is saved on their profile at once
-- (`entry`: ticks = the stay's full reward ticks, launches = how many launches it counts
-- for, blackHole), so a server that closes or crashes before the stay is saved still
-- pays it on their next load (Profiles.recoverLaunches). False without a loaded profile.
function Profiles:lockLaunch(userId, launchId, entry)
    local record = self.records[userId]
    if not record or not record.loaded then return false end
    record.profile.openLaunches[launchId] = { ticks = entry.ticks, launches = entry.launches or 1, blackHole = entry.blackHole == true }
    if (entry.launches or 1) > 1 then
        record.launchCounts = record.launchCounts or {}
        record.launchCounts[launchId] = math.max(record.launchCounts[launchId] or 1, entry.launches)
    end
    if entry.blackHole then
        record.blackHoles = record.blackHoles or {}
        record.blackHoles[launchId] = true
    end
    self:dirty(userId)
    self:saveSoon(userId)
    return true
end

-- The stay of `launchId` is over: its rewards are all queued, so the open launch closes
-- in the same save that commits them. A passenger who left can now let go of the session.
function Profiles:finishLaunch(userId, launchId)
    local record = self.records[userId]
    if not record or not record.loaded or not record.profile.openLaunches[launchId] then return end
    record.profile.openLaunches[launchId] = nil
    if record.leaving then record.keepLease = false end
    self:dirty(userId)
    self:saveSoon(userId)
end

function Profiles:save(userId)
    local record = self.records[userId]
    if not record or record.busy or not record.loaded or record.released then return false end
    record.busy = true
    local snapshot = copy(record.profile)
    -- Saves start from the stored bonuses; the preview of pending ticks isn't real yet.
    local added = record.preview or { strength = 0, speed = 0 }
    snapshot.planetBonuses.strength -= added.strength
    snapshot.planetBonuses.speed -= added.speed
    local batch = {}
    local batchCount, pendingCount = 0, 0
    for id, ticks in record.pending do
        pendingCount += 1
        if batchCount >= self.config.RecentRewardLimit then continue end
        batch[id] = ticks
        batchCount += 1
    end
    -- Leaving with nothing left to save: let go of the session so another server can
    -- load them at once (kept for a locked passenger whose rewards may still come).
    local release = record.leaving and not record.keepLease and batchCount == pendingCount and not next(snapshot.openLaunches)
    local function applyRewards(profile)
        return Profiles.applyBatch(profile, batch, self.config, record.launchCounts, record.blackHoles)
    end
    local ok, saved
    for attempt = 1, 3 do
        ok, saved = pcall(function()
            if not self.store then return applyRewards(copy(snapshot)) end
            return self.store:UpdateAsync("Player_" .. userId, function(raw)
                local current = validate(raw, self.config)
                if not current.session or current.session.owner ~= self.owner then return nil end
                -- Retain the stored reward ledger after an ambiguous previous write.
                current.strengthLevel = snapshot.strengthLevel
                current.speedLevel = snapshot.speedLevel
                current.lifetimeDeliveries = snapshot.lifetimeDeliveries
                current.coins = snapshot.coins
                current.tutorialStep = snapshot.tutorialStep
                current.seenCallouts = snapshot.seenCallouts
                current.upgrades = snapshot.upgrades
                current.purchaseIds = snapshot.purchaseIds
                current.pets = snapshot.pets
                current.equippedPets = snapshot.equippedPets
                current.ufos = snapshot.ufos
                current.suit = snapshot.suit
                -- Closed in the same write that commits the stay's last rewards.
                current.openLaunches = snapshot.openLaunches
                -- Passes only ever add up: one recorded by any server stays.
                current.passes = Profiles.mergePasses(current.passes, snapshot.passes)
                applyRewards(current)
                current.session = not release and { owner = self.owner, expires = os.time() + self.config.LeaseSeconds } or nil
                return current, { userId }
            end)
        end)
        if ok and saved then break end
        if attempt < 3 then task.wait(2 ^ attempt) end
    end
    record.busy = false
    if ok and saved then
        record.committed = saved
        -- Preserve training/deliveries earned while UpdateAsync was yielding.
        record.profile.completedLaunches = saved.completedLaunches
        record.profile.blackHolesVisited = saved.blackHolesVisited or 0
        record.profile.planetBonuses = saved.planetBonuses
        record.profile.rewardedLaunchIds = saved.rewardedLaunchIds
        record.profile.rewardedLaunchTicks = saved.rewardedLaunchTicks
        for id, ticks in batch do
            if record.pending[id] <= ticks then
                record.pending[id] = nil
                if record.blackHoles then record.blackHoles[id] = nil end
            end
        end
        record.preview = nil
        self:preview(record)
        record.dirty = record.profile.strengthLevel ~= snapshot.strengthLevel or record.profile.speedLevel ~= snapshot.speedLevel or record.profile.lifetimeDeliveries ~= snapshot.lifetimeDeliveries or record.profile.coins ~= snapshot.coins
            or record.profile.tutorialStep ~= snapshot.tutorialStep or #record.profile.seenCallouts ~= #snapshot.seenCallouts
            or #record.profile.purchaseIds ~= #snapshot.purchaseIds or not Profiles.samePets(record.profile, snapshot)
            or #record.profile.passes ~= #snapshot.passes or not sameKeys(record.profile.openLaunches, snapshot.openLaunches)
        record.status = next(record.pending) and "Reward pending — saving" or (self.store and (record.dirty and "Unsaved changes — autosave pending" or "Saved") or "Studio only — progress is not permanent")
        if release and self.store then
            -- Nothing more may be written for them here; a rejoin loads afresh.
            record.released = true
            record.status = "Saved — session released"
        elseif record.leaving and not next(record.pending) and not record.dirty then
            -- A locked passenger keeps the lease until it expires; rejoining another
            -- server waits for it (Profiles:load).
            record.status = self.store and "Saved — session expires shortly" or record.status
        end
    else
        record.dirty = true
        if ok and saved == nil then record.blocked = true end
        record.status = next(record.pending) and "Reward pending — save failed; retrying" or "Save failed — retrying"
        if record.blocked then record.status = "Save blocked — session ownership lost; progress disabled" end
        warn("Rocket save failed", userId, ok and "Session ownership lost" or tostring(saved))
    end
    self.changed(userId)
    return ok and saved ~= nil
end

-- `keepLease`: a locked passenger whose rewards may still be queued after they leave.
function Profiles:remove(userId, keepLease)
    local record = self.records[userId]
    if not record then return end
    record.leaving = true
    -- Only while a launch they're locked into is still open (finishLaunch lets go).
    record.keepLease = keepLease == true and next(record.profile.openLaunches or {}) ~= nil
    record.dirty = true
    task.spawn(function() self:save(userId) end)
end

-- Saves now, waiting out a save in progress (up to 30 s). True when it saved.
function Profiles:saveNow(userId)
    local record = self.records[userId]
    local deadline = os.clock() + 30
    while record and record.busy and os.clock() < deadline do task.wait(0.1) end
    return self:save(userId)
end

-- Lets go of departed players' records once nothing more can be written for them: the
-- session released (or never loaded, or Studio-only and saved), no save running or
-- queued, no rewards pending and no launch still open. Returns how many went.
function Profiles:prune()
    local pruned = 0
    for userId, record in self.records do
        local settled = not record.busy and not record.saveQueued and not next(record.pending) and not next(record.profile.openLaunches or {})
        if record.leaving and settled and (record.released or not record.loaded or (not self.store and not record.dirty)) then
            self.records[userId] = nil
            pruned += 1
        end
    end
    return pruned
end

function Profiles:start()
    task.spawn(function()
        while true do
            task.wait(self.config.AutosaveSeconds)
            -- Disconnected records stay while a locked passenger's rewards may still come.
            self:prune()
            for userId, record in self.records do
                if not record.released and (not record.leaving or record.dirty or next(record.pending)) then task.spawn(function() self:save(userId) end) end
            end
        end
    end)
    game:BindToClose(function()
        local left = 0
        for userId in self.records do
            left += 1
            task.spawn(function()
                local record = self.records[userId]
                while record.busy do task.wait(0.1) end
                -- Shutting down: no rewards can follow, so every lease is released.
                record.leaving, record.keepLease = true, false
                if not record.released then self:save(userId) end
                left -= 1
            end)
        end
        local deadline = os.clock() + 25
        while left > 0 and os.clock() < deadline do task.wait(0.1) end
    end)
end

return Profiles
