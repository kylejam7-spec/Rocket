-- Server-owned mounting and timed gains. Clients can only request an exit.
-- The station carries an Occupant_<UserId> attribute (the mount's server time) per
-- user; each client animates from those (GymAnimationController), reps in step with
-- the gain ticks. A bench takes any number of users at once and each sees only
-- themselves on it; a treadmill takes one.
local Training = {}

-- Where the anchored body goes: upright on the belt facing the console, or flat on
-- the bench with the head under the rack (both pieces are -Z of the base).
local function pose(station, root, humanoid)
    local base = station.part
    local forward = base.CFrame.LookVector
    if station.stat == "speedLevel" then
        local belt = base:FindFirstChild("TreadmillBelt")
        local top = belt and belt.Position.Y + belt.Size.Y / 2 or base.Position.Y + 1
        local position = Vector3.new(base.Position.X, top + humanoid.HipHeight + root.Size.Y / 2, base.Position.Z)
        return CFrame.lookAt(position, position + forward)
    end
    local cushion = base:FindFirstChild("BenchCushion")
    local top = cushion and cushion.Position.Y + cushion.Size.Y / 2 or base.Position.Y + 1.5
    local position = Vector3.new(base.Position.X, top + root.Size.Z / 2, base.Position.Z) + forward * 0.3
    -- Face up, head toward the rack.
    return CFrame.fromMatrix(position, Vector3.yAxis:Cross(forward), forward)
end

function Training.new(context)
    local sessions, lastExit = {}, {}
    local function stop(player)
        local session = sessions[player.UserId]
        if not session then return end
        sessions[player.UserId] = nil
        lastExit[player.UserId] = os.clock()
        session.station.occupants[player.UserId] = nil
        session.station.part:SetAttribute("Occupant_" .. player.UserId, nil)
        if session.root.Parent then
            session.root.Anchored = session.anchored
            session.humanoid.AutoRotate = session.autoRotate
            session.humanoid.Sit = false
            session.humanoid.PlatformStand = session.platformStand
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
        station.occupants = {}
        station.part:SetAttribute("TrainingStation", true)
        station.part:SetAttribute("RequiredCycles", station.required or 0)
        station.part:SetAttribute("TrainingGain", station.gain)
        station.part:SetAttribute("TrainingStat", station.stat)
        context.prompt(station.part, "Train " .. station.name).Triggered:Connect(function(player)
            if os.clock() - (lastExit[player.UserId] or -math.huge) < 1 then return end
            if sessions[player.UserId] or not context.allowed(player, "train") or not context.near(player, station.part) then return end
            if not context.phaseAllowed(station) then return end
            if station.stat == "speedLevel" and next(station.occupants) then context.feedback(player, "Station occupied."); return end
            local profile = context.profiles.records[player.UserId].profile
            if profile.completedLaunches < (station.required or 0) then
                context.feedback(player, "Complete " .. station.required .. " rocket cycles to unlock " .. station.name .. ".")
                return
            end
            local root, humanoid = context.body(player)
            if not root then return end
            station.occupants[player.UserId] = true
            sessions[player.UserId] = { station = station, root = root, humanoid = humanoid, character = player.Character,
                anchored = root.Anchored, autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand,
                nextTick = os.clock() + context.config.TrainingSeconds }
            context.relocate(player, pose(station, root, humanoid))
            root.Anchored = true
            humanoid.AutoRotate = false
            humanoid.Sit = false
            -- Lying on the bench: no standing up, and Animate stops its idle.
            humanoid.PlatformStand = station.stat == "strengthLevel"
            station.part:SetAttribute("Occupant_" .. player.UserId, workspace:GetServerTimeNow())
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
                    or not context.profiles:ready(userId) or not context.phaseAllowed(session.station)
                    or (session.root.Position - session.station.part.Position).Magnitude > 7 then
                    stop(player)
                elseif now >= session.nextTick then
                    -- Keep to the mount's beat (the client times reps to it), but don't
                    -- pay out a backlog after a stall.
                    session.nextTick += context.config.TrainingSeconds
                    if session.nextTick <= now then session.nextTick = now + context.config.TrainingSeconds end
                    local profile = context.profiles.records[userId].profile
                    local stat = session.station.stat
                    local gain = session.station.gain
                    profile[stat] += gain
                    context.profiles:dirty(userId)
                    context.feedback(player, "+" .. gain .. " " .. (stat == "strengthLevel" and "Strength" or "Speed") .. "!")
                    if context.trained then context.trained(player, session.station) end
                    context.changed(player)
                end
            end
        end
    end
    return service
end
return Training

