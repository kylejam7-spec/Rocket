-- Owns the Remotes folder. ExitTraining is added by TrainingService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Remote = {}

function Remote.new()
    local folder = Instance.new("Folder")
    folder.Name = "Remotes"
    local service = { folder = folder }
    for _, name in { "StateUpdated", "RequestState", "Feedback", "MaterialHold", "DiscardCargo" } do
        local event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = folder
        service[name] = event
    end
    folder.Parent = ReplicatedStorage

    local lastReject = {}
    function service.feedback(player, message, rejection)
        service.Feedback:FireClient(player, message)
        if rejection and os.clock() - (lastReject[player.UserId] or -math.huge) >= 5 then
            lastReject[player.UserId] = os.clock()
            warn("Rocket rejected interaction", player.UserId, rejection)
        end
    end
    function service.announce(message)
        for _, player in Players:GetPlayers() do service.feedback(player, message) end
    end
    function service.forget(player)
        lastReject[player.UserId] = nil
    end
    return service
end
return Remote
