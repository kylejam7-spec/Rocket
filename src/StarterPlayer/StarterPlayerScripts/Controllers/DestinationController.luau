-- Destination presentation on this client: the cabin's countdown screen, the
-- destination's gravity while this player is there as a passenger (characters are
-- client-simulated, so local Gravity is enough; it resets on the way home), and which
-- destinations are drawn at all: only one near this player's camera or character.
-- Their backdrops are huge (Jupiter is 900 studs across) and would otherwise hang in
-- the Earth site's sky and every other destination's. Hidden ones wait in a local
-- folder; the check runs before each physics step, so a teleport always lands on ground.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local DestinationController = {}

-- Destinations (and the cabin) this close to the camera or character are drawn.
local SHOW_DISTANCE, CABIN_DISTANCE = 2500, 700

function DestinationController.start()
    local normalGravity = workspace.Gravity
    local root = workspace:WaitForChild("RocketWorld"):WaitForChild("Destinations")
    local hidden = Instance.new("Folder")
    hidden.Name = "HiddenDestinations"
    hidden.Parent = ReplicatedStorage
    local places = {}
    for _, spec in Config.Destinations do
        table.insert(places, { folder = root:WaitForChild(spec.id), center = spec.position, reach = SHOW_DISTANCE })
    end
    table.insert(places, { folder = root:WaitForChild("RocketCabin"), center = Config.CabinPosition, reach = CABIN_DISTANCE })
    RunService.PreSimulation:Connect(function()
        local camera = workspace.CurrentCamera
        local character = Players.LocalPlayer.Character
        local body = character and character:FindFirstChild("HumanoidRootPart")
        for _, place in places do
            local near = (camera and (camera.CFrame.Position - place.center).Magnitude <= place.reach)
                or (body and (body.Position - place.center).Magnitude <= place.reach)
            local parent = near and root or hidden
            if place.folder.Parent ~= parent then place.folder.Parent = parent end
        end
    end)
    local current
    State.subscribe(function(state)
        current = state
        local place = state.passenger and state.phase == "Rewarding" and Config.Destinations[state.destinationTier]
        workspace.Gravity = place and place.gravity or normalGravity
    end)
    local cabin = places[#places].folder
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
