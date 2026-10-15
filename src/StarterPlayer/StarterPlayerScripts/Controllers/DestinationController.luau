-- Destination presentation on this client: the cabin's countdown screen, and the
-- destination's gravity while this player is there as a passenger (characters are
-- client-simulated, so local Gravity is enough; it resets on the way home).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local DestinationController = {}

function DestinationController.start()
    local normalGravity = workspace.Gravity
    local current
    State.subscribe(function(state)
        current = state
        local place = state.passenger and state.phase == "Rewarding" and Config.Destinations[state.destinationTier]
        workspace.Gravity = place and place.gravity or normalGravity
    end)
    local cabin = workspace:WaitForChild("RocketWorld"):WaitForChild("Destinations"):WaitForChild("RocketCabin")
    local display = cabin:WaitForChild("CountdownScreen"):WaitForChild("Display"):WaitForChild("Text")
    while true do
        local state = current
        if state and state.phase == "Boarding" then
            local left = math.max(0, math.ceil(state.deadline - workspace:GetServerTimeNow()))
            display.Text = "LIFTOFF IN " .. left .. "\n→ " .. state.destination
        elseif state and state.phase == "Launching" then
            display.Text = "LIFTOFF!"
        else
            display.Text = "PREPARE FOR LIFTOFF"
        end
        task.wait(0.25)
    end
end

return DestinationController
