-- tools/Test.ps1 wraps the actual ProfileService in loadProfiles(game, task).
-- These mocks exercise confirmed/ambiguous writes and failure recovery.
local stored, failures, ambiguous, loads, duringWrite = {}, 0, false, 0, nil
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in value do result[key] = deepCopy(item) end
    return result
end
local store = {}
function store:UpdateAsync(key, transform)
    loads += 1
    if failures > 0 then failures -= 1; error("Injected outage") end
    local nextValue = transform(deepCopy(stored[key]))
    if nextValue == nil then return nil end
    stored[key] = deepCopy(nextValue)
    if duringWrite then local action = duringWrite; duringWrite = nil; action() end
    if ambiguous then ambiguous = false; error("Committed, but response lost") end
    return deepCopy(nextValue)
end
local fakeGame = { GetService = function(_, name)
    if name == "HttpService" then return { GenerateGUID = function() return "test-server" end } end
    return { GetDataStore = function() return store end }
end }
local fakeTask = { wait = function() end, spawn = function(callback) callback() end }
local Profiles = loadProfiles(fakeGame, fakeTask)
local config = { PersistenceEnabled = true, DataStoreName = "fake", LeaseSeconds = 120, MaxLevel = 50, RecentRewardLimit = 4, Planet = { StrengthBonus = 1, SpeedBonus = 1 } }
local profiles = Profiles.new(config, function() end)
assert(profiles:load(1))
assert(profiles:ready(1))
profiles.records[1].profile.strengthLevel = 3
profiles.records[1].profile.lifetimeDeliveries = 4
ambiguous = true
profiles:queueReward(1, "launch-a")
assert(profiles.records[1].profile.completedLaunches == 1, "Ambiguous retry grants once")
assert(stored.Player_1.completedLaunches == 1)
assert(stored.Player_1.strengthLevel == 3 and stored.Player_1.lifetimeDeliveries == 4)
profiles:queueReward(1, "launch-a")
assert(stored.Player_1.completedLaunches == 1, "Replay cannot duplicate reward")
failures = 3
profiles:queueReward(1, "launch-b")
assert(profiles.records[1].pending["launch-b"])
assert(profiles.records[1].profile.completedLaunches == 1, "Failed reward never shown as confirmed")
assert(string.find(profiles.records[1].status, "pending", 1, true))
assert(profiles:save(1))
assert(stored.Player_1.completedLaunches == 2 and not next(profiles.records[1].pending))
duringWrite = function()
    profiles.records[1].profile.speedLevel += 1
    profiles.records[1].profile.lifetimeDeliveries += 1
    profiles.records[1].pending["launch-c"] = true
end
assert(profiles:save(1))
assert(profiles.records[1].profile.speedLevel == 1 and profiles.records[1].profile.lifetimeDeliveries == 5, "Changes during write preserved")
assert(profiles.records[1].dirty, "Concurrent changes must be saved again")
assert(profiles.records[1].pending["launch-c"], "New pending reward survives older write")
assert(profiles:save(1))
assert(not profiles.records[1].dirty, "Follow-up write clears dirty state")
profiles:remove(1)
assert(not profiles:ready(1))
profiles:queueReward(1, "launch-d")
assert(stored.Player_1.completedLaunches == 4, "Disconnect after lock still saves")
assert(profiles:load(1))
assert(profiles:ready(1) and profiles.records[1].profile.completedLaunches == 4, "Same-server rejoin keeps pending/confirmed state")
for index = 1, 8 do profiles:queueReward(1, "later-" .. index) end
assert(#stored.Player_1.rewardedLaunchIds == config.RecentRewardLimit, "Ledger bounded")
stored.Player_2 = { schemaVersion = 99 }
assert(not profiles:load(2), "Unknown schema refuses overwrite")
assert(stored.Player_2.schemaVersion == 99 and not profiles:ready(2))
failures = 1
assert(not profiles:load(3), "Load failure disables progression")
assert(not profiles:ready(3) and stored.Player_3 == nil)
stored.Player_1.session.owner = "another-server"
assert(not profiles:save(1))
assert(not profiles:ready(1), "Lost ownership disables progress")
print("PASS: ambiguous/replayed rewards, outage/retry, concurrent mutation, disconnect/rejoin, bounded ledger, schema/load/ownership failures")
