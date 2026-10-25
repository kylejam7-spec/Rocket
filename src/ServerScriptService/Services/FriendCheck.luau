-- Friend boost math (FriendService.boost): 2x with any friend present, never more however
-- many, friends only, the player never counting themselves, and a friend who left no longer counting.
local Friends = require(script.Parent.FriendService)

return function()
    local friendships = { [1] = { [2] = true, [3] = true }, [2] = { [1] = true, [3] = true }, [3] = { [1] = true, [2] = true }, [4] = {} }
    assert(Friends.boost(friendships, 1, { 1 }) == 1, "alone")
    assert(Friends.boost(friendships, 1, { 1, 4 }) == 1, "a stranger isn't a friend")
    assert(Friends.boost(friendships, 1, { 1, 2 }) == 2, "one friend: 2x")
    assert(Friends.boost(friendships, 1, { 1, 2, 3, 4 }) == 2, "three friends together: still 2x each")
    assert(Friends.boost(friendships, 2, { 1, 2, 3 }) == 2 and Friends.boost(friendships, 3, { 1, 2, 3 }) == 2)
    assert(Friends.boost(friendships, 4, { 1, 2, 3, 4 }) == 1, "the stranger gets no boost")
    assert(Friends.boost(friendships, 9, { 1, 9 }) == 1, "unknown player")
    assert(Friends.boost(friendships, 1, { 1, 3 }) == 2, "one left: back to 2x")
    return "Friend boost math passed"
end
