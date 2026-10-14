local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Profiles = {}
Profiles.__index = Profiles

local function defaults()
    return { schemaVersion = 1, strengthLevel = 0, speedLevel = 0, planetBonuses = { strength = 0, speed = 0 }, completedLaunches = 0, lifetimeDeliveries = 0, rewardedLaunchIds = {} }
end

local function copy(profile)
    local result = table.clone(profile)
    result.planetBonuses = table.clone(profile.planetBonuses)
    result.rewardedLaunchIds = table.clone(profile.rewardedLaunchIds)
    return result
end

local function validate(raw, config)
    if raw == nil then return defaults() end
    if type(raw) ~= "table" or raw.schemaVersion ~= 1 then error("Unsupported profile schema; refusing overwrite") end
    for _, key in { "strengthLevel", "speedLevel", "completedLaunches", "lifetimeDeliveries" } do
        local value = raw[key]
        if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0 then error("Invalid profile " .. key) end
    end
    if type(raw.planetBonuses) ~= "table" or type(raw.rewardedLaunchIds) ~= "table" then error("Invalid profile collections") end
    for _, key in { "strength", "speed" } do
        local value = raw.planetBonuses[key]
        if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0 then error("Invalid bonus") end
    end
    if raw.strengthLevel > config.MaxLevel or raw.speedLevel > config.MaxLevel then error("Invalid stat cap") end
    for _, id in raw.rewardedLaunchIds do if type(id) ~= "string" then error("Invalid reward ledger") end end
    return copy(raw)
end

function Profiles.new(config, changed)
    return setmetatable({ config = config, changed = changed, records = {}, owner = HttpService:GenerateGUID(false), store = config.PersistenceEnabled and DataStoreService:GetDataStore(config.DataStoreName) or nil }, Profiles)
end

function Profiles:load(userId)
    local previous = self.records[userId]
    if previous and not string.find(previous.status, "Load failed", 1, true) then
        while previous.busy do task.wait(0.1) end
        previous.leaving = false
        self.changed(userId)
        return not previous.blocked
    end
    local record = { profile = defaults(), pending = {}, status = "Loading", busy = true, leaving = false }
    self.records[userId] = record
    local ok, profile = pcall(function()
        if not self.store then return defaults() end
        local now = os.time()
        return self.store:UpdateAsync("Player_" .. userId, function(raw)
            local current = validate(raw, self.config)
            if current.session and current.session.owner ~= self.owner and current.session.expires > now then return nil end
            current.session = { owner = self.owner, expires = now + self.config.LeaseSeconds }
            return current
        end)
    end)
    record.busy = false
    if not ok or not profile then
        record.status = "Load failed — rejoin; progress disabled"
        warn("Rocket profile load failed", userId, ok and "Profile in use" or tostring(profile))
        self.changed(userId)
        return false
    end
    record.profile = profile
    record.status = self.store and "Saved" or "Studio only — progress is not permanent"
    self.changed(userId)
    return true
end

function Profiles:ready(userId)
    local record = self.records[userId]
    return record and not record.blocked and not record.leaving and record.status ~= "Loading" and not string.find(record.status, "Load failed", 1, true)
end

function Profiles:dirty(userId)
    local record = self.records[userId]
    record.dirty = true
    if self.store and not next(record.pending) then record.status = "Unsaved changes — autosave pending" end
end

function Profiles:queueReward(userId, launchId)
    local record = self.records[userId]
    if not record or record.status == "Loading" or string.find(record.status, "Load failed", 1, true) then return end
    record.pending[launchId] = true
    record.status = "Reward pending — saving"
    self.changed(userId)
    task.spawn(function() self:save(userId) end)
end

function Profiles:save(userId)
    local record = self.records[userId]
    if not record or record.busy or record.status == "Loading" or string.find(record.status, "Load failed", 1, true) then return false end
    record.busy = true
    local snapshot = copy(record.profile)
    local batch = {}
    local batchCount = 0
    for id in record.pending do
        if batchCount >= self.config.RecentRewardLimit then break end
        batch[id] = true
        batchCount += 1
    end
    local function applyRewards(profile)
        for id in batch do
            if not table.find(profile.rewardedLaunchIds, id) then
                profile.completedLaunches += 1
                profile.planetBonuses.strength = math.min(self.config.MaxLevel, profile.planetBonuses.strength + self.config.Planet.StrengthBonus)
                profile.planetBonuses.speed = math.min(self.config.MaxLevel, profile.planetBonuses.speed + self.config.Planet.SpeedBonus)
                table.insert(profile.rewardedLaunchIds, id)
            end
        end
        while #profile.rewardedLaunchIds > self.config.RecentRewardLimit do
            -- Never evict an ID in this transaction's retry batch.
            for index, id in profile.rewardedLaunchIds do
                if not batch[id] then table.remove(profile.rewardedLaunchIds, index); break end
            end
        end
        return profile
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
                applyRewards(current)
                current.session = { owner = self.owner, expires = os.time() + self.config.LeaseSeconds }
                return current
            end)
        end)
        if ok and saved then break end
        if attempt < 3 then task.wait(2 ^ attempt) end
    end
    record.busy = false
    if ok and saved then
        -- Preserve training/deliveries earned while UpdateAsync was yielding.
        record.profile.completedLaunches = saved.completedLaunches
        record.profile.planetBonuses = saved.planetBonuses
        record.profile.rewardedLaunchIds = saved.rewardedLaunchIds
        for id in batch do record.pending[id] = nil end
        record.dirty = record.profile.strengthLevel ~= snapshot.strengthLevel or record.profile.speedLevel ~= snapshot.speedLevel or record.profile.lifetimeDeliveries ~= snapshot.lifetimeDeliveries
        record.status = next(record.pending) and "Reward pending — saving" or (self.store and (record.dirty and "Unsaved changes — autosave pending" or "Saved") or "Studio only — progress is not permanent")
        if record.leaving and not next(record.pending) and not record.dirty then
            -- Keep lease until expiry: protects a disconnected locked passenger.
            -- Rejoining another server may wait up to LeaseSeconds.
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

function Profiles:remove(userId)
    local record = self.records[userId]
    if not record then return end
    record.leaving = true
    record.dirty = true
    task.spawn(function() self:save(userId) end)
end

function Profiles:start()
    -- ponytail: retain disconnected records for late locked rewards; prune after
    -- cycle completion if long-lived servers make historical player count large.
    task.spawn(function()
        while true do
            task.wait(self.config.AutosaveSeconds)
            for userId, record in self.records do
                if not record.leaving or record.dirty or next(record.pending) then task.spawn(function() self:save(userId) end) end
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
                self:save(userId)
                left -= 1
            end)
        end
        local deadline = os.clock() + 25
        while left > 0 and os.clock() < deadline do task.wait(0.1) end
    end)
end

return Profiles
