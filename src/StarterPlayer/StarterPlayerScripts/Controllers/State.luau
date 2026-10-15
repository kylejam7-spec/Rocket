-- The one StateUpdated subscription every controller shares.
-- State.subscribe(fn) calls fn(state, previous) on every server snapshot (and
-- replays the current one to late subscribers); State.onFeedback(fn) gets Feedback
-- messages. Main calls State.start() once every controller has started.
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
        snapshot = state
        for _, fn in listeners do task.spawn(fn, state, previous) end
    end)
    State.remote("Feedback").OnClientEvent:Connect(function(message)
        for _, fn in feedbackListeners do task.spawn(fn, message) end
    end)
    State.remote("RequestState"):FireServer()
end

return State
