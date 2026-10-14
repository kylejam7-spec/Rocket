-- Server-owned mounting and timed gains. Clients can only request an exit.
local Training = {}
function Training.new(context)
    local sessions, lastExit = {}, {}
    local function stop(player)
        local session = sessions[player.UserId]
        if not session then return end
        sessions[player.UserId] = nil
        lastExit[player.UserId] = os.clock()
        session.station.occupant = nil
        if session.root.Parent then
            session.root.Anchored = session.anchored
            session.humanoid.AutoRotate = session.autoRotate
            session.humanoid.Sit = false
            if player.Character == session.character then
                context.relocate(player, session.station.part.Position + Vector3.new(5, 4, 0))
            end
        end
        context.changed(player)
    end
    local exit = Instance.new("RemoteEvent")
    exit.Name = "ExitTraining"
    exit.Parent = context.remotes
    exit.OnServerEvent:Connect(function(player) stop(player) end)
    local stations = context.stations
    for _, station in stations do
        station.part:SetAttribute("TrainingStation", true)
        station.part:SetAttribute("RequiredCycles", station.required or 0)
        station.part:SetAttribute("TrainingGain", station.gain)
        context.prompt(station.part, "Train " .. station.name).Triggered:Connect(function(player)
            if os.clock() - (lastExit[player.UserId] or -math.huge) < 1 then return end
            if sessions[player.UserId] or not context.allowed(player, "train") or not context.near(player, station.part) then return end
            if not context.phaseAllowed() then return end
            if station.occupant then context.feedback(player, "Station occupied."); return end
            local profile = context.profiles.records[player.UserId].profile
            if profile.completedLaunches < (station.required or 0) then
                context.feedback(player, "Complete " .. station.required .. " rocket cycles to unlock " .. station.name .. ".")
                return
            end
            if profile[station.stat] >= context.config.MaxLevel then context.feedback(player, "Playtest level cap reached."); return end
            local root, humanoid = context.body(player)
            if not root then return end
            station.occupant = player
            sessions[player.UserId] = { station = station, root = root, humanoid = humanoid, character = player.Character,
                anchored = root.Anchored, autoRotate = humanoid.AutoRotate, nextTick = os.clock() + context.config.TrainingSeconds }
            context.relocate(player, station.part.Position + Vector3.new(0, station.stat == "speedLevel" and 4 or 3, 0))
            root.Anchored = true
            humanoid.AutoRotate = false
            humanoid.Sit = station.stat == "strengthLevel"
            context.feedback(player, station.name .. ": training! Press E or Leave station to exit.")
            context.changed(player)
        end)
    end
    local service = { sessions = sessions, stop = stop }
    function service.tick(now)
        for userId, session in sessions do
            local player = context.players:GetPlayerByUserId(userId)
            if player then
                if player.Character ~= session.character or session.humanoid.Health <= 0 or not session.root.Parent
                    or not context.profiles:ready(userId) or not context.phaseAllowed()
                    or (session.root.Position - session.station.part.Position).Magnitude > 7 then
                    stop(player)
                elseif now >= session.nextTick then
                    session.nextTick = now + context.config.TrainingSeconds
                    local profile = context.profiles.records[userId].profile
                    local stat = session.station.stat
                    local gain = math.min(session.station.gain, context.config.MaxLevel - profile[stat])
                    profile[stat] += gain
                    context.profiles:dirty(userId)
                    context.feedback(player, "+" .. gain .. " " .. (stat == "strengthLevel" and "Strength" or "Speed") .. "!")
                    context.changed(player)
                    if profile[stat] >= context.config.MaxLevel then
                        stop(player)
                        context.feedback(player, "Level cap reached! Try your upgraded stats.")
                    end
                end
            end
        end
    end
    return service
end
return Training

