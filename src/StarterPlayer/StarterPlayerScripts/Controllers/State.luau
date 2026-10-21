-- The one StateUpdated subscription every controller shares.
-- State.subscribe(fn) calls fn(state, previous) on every server snapshot (and
-- replays the current one to late subscribers); State.onFeedback(fn) gets Feedback
-- messages. Main calls State.start() once every controller has started.
-- While a profile loads, the server sends a blank placeholder (saveStatus "Loading...").
-- The first real profile isn't a change from that: listeners get previous = nil for it,
-- as for a first snapshot, so joining doesn't set off coin bursts, level-ups, pass and
-- upgrade fanfares for everything the player already had. State.loaded(state) tells
-- whether a snapshot carries the real profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = {}
local snapshot
local listeners, feedbackListeners = {}, {}

function State.remote(name)
    return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

function State.get()
    return snapshot
end

function State.loaded(state)
    return state ~= nil and state.profile ~= nil and not string.find(state.saveStatus or "Loading", "^Loading")
end

function State.subscribe(fn)
    table.insert(listeners, fn)
    if snapshot then task.spawn(fn, snapshot, nil) end
end

function State.onFeedback(fn)
    table.insert(feedbackListeners, fn)
end

function State.start()
    -- Each listener gets its own thread, so one controller's error can't stop the rest.
    State.remote("StateUpdated").OnClientEvent:Connect(function(state)
        local previous = snapshot
        if previous and not State.loaded(previous) then previous = nil end
        snapshot = state
        for _, fn in listeners do task.spawn(fn, state, previous) end
    end)
    State.remote("Feedback").OnClientEvent:Connect(function(message)
        for _, fn in feedbackListeners do task.spawn(fn, message) end
    end)
    State.remote("RequestState"):FireServer()
end

return State
