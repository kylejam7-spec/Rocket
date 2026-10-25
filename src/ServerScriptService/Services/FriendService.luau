-- Friend boost: everyone playing with Roblox friends in the same server trains and earns
-- coins 2x, however many of those friends are here (one boost, never stacking). It
-- multiplies with the Shop's boosts (TrainingService's multiplier, Profiles.credit).
-- Friendships are looked up once per pair as players join (Player:IsFriendsWith is a web
-- call; each join runs on its own thread) and each player's boost is published as the
-- FriendBoost attribute, which the client's INVITE chip shows.
local Friends = {}

local BOOST = 2

-- The boost for `userId` from `friendships` (friendships[a][b] = true when a and b are
-- friends) among the user ids in `present`: 2 with any friend here, otherwise 1.
function Friends.boost(friendships, userId, present)
    local mine = friendships[userId]
    if mine then
        for _, other in present do
            if other ~= userId and mine[other] then return BOOST end
        end
    end
    return 1
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
                player:SetAttribute("FriendBoost", fake and (fake > 0 and BOOST or 1) or Friends.boost(friendships, player.UserId, ids))
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
