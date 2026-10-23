-- Friend boost: everyone playing with Roblox friends in the same server trains and earns
-- coins faster, 1x more for each friend here (one friend 2x, two 3x, and so on). It
-- multiplies with the Shop's boosts (TrainingService's multiplier, Profiles.credit).
-- Friendships are looked up once per pair as players join (Player:IsFriendsWith is a web
-- call; each join runs on its own thread) and each player's boost is published as the
-- FriendBoost attribute, which the client's INVITE chip shows.
local Friends = {}

-- The boost for `userId` from `friendships` (friendships[a][b] = true when a and b are
-- friends) among the user ids in `present`.
function Friends.boost(friendships, userId, present)
    local count = 0
    local mine = friendships[userId]
    if mine then
        for _, other in present do
            if other ~= userId and mine[other] then count += 1 end
        end
    end
    return 1 + count
end

function Friends.new(ctx)
    local Players = ctx.players
    local friendships = {}
    -- Studio playtests (DebugService "friends") may set a player's friend count directly.
    local service = { friendships = friendships, debug = {} }

    -- Everyone's boost, from who's here (less `leaving`, still in the list as it goes).
    local function publish(leaving)
        local ids = {}
        for _, player in Players:GetPlayers() do
            if player ~= leaving then table.insert(ids, player.UserId) end
        end
        for _, player in Players:GetPlayers() do
            if player ~= leaving then
                local fake = service.debug[player.UserId]
                player:SetAttribute("FriendBoost", fake and 1 + fake or Friends.boost(friendships, player.UserId, ids))
            end
        end
    end
    local function link(a, b)
        friendships[a] = friendships[a] or {}
        friendships[b] = friendships[b] or {}
        friendships[a][b], friendships[b][a] = true, true
    end

    function service.multiplier(player)
        return player and player:GetAttribute("FriendBoost") or 1
    end
    function service.setDebug(player, count)
        service.debug[player.UserId] = count
        publish()
    end

    local function joined(player)
        publish()
        for _, other in Players:GetPlayers() do
            local known = friendships[player.UserId]
            if other ~= player and not (known and known[other.UserId]) then
                local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
                if ok and friends then link(player.UserId, other.UserId) end
            end
        end
        publish()
    end
    Players.PlayerAdded:Connect(joined)
    for _, player in Players:GetPlayers() do task.spawn(joined, player) end
    Players.PlayerRemoving:Connect(function(player)
        service.debug[player.UserId] = nil
        friendships[player.UserId] = nil
        for _, mine in friendships do mine[player.UserId] = nil end
        publish(player)
    end)
    return service
end

return Friends
