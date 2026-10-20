-- Character lookup, relocation and the horizontal-jump check behind every interaction.
local Movement = {}

local function finite(vector)
    return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z and vector.Magnitude < 1e7
end

function Movement.new(ctx)
    local config = ctx.config
    local motion = {}
    local service = {}
    function service.body(player)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or not finite(root.Position) then return nil end
        return root, humanoid
    end
    -- The fastest horizontal move allowed: a margin over this player's own walk speed.
    local function limit(player)
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local walk = humanoid and humanoid.WalkSpeed or 0
        return math.max(config.MinMoveLimit, walk * config.MoveLimitFactor)
    end
    function service.observed(player)
        local root = service.body(player)
        if not root then return nil end
        local sample = motion[player.UserId]
        if not sample or sample.root ~= root or os.clock() < sample.blockedUntil then return nil end
        -- Check again in the interaction handler, covering the gap between samples.
        local delta = root.Position - sample.position
        local elapsed = math.max(0, os.clock() - sample.time)
        if Vector3.new(delta.X, 0, delta.Z).Magnitude > limit(player) * elapsed + 3 then return nil end
        return root
    end
    -- `settle` seconds of free movement before the jump check applies: CharacterAdded fires
    -- before Roblox moves the new character onto its SpawnLocation, so without it the
    -- spawn move looks like a teleport and snaps players back to the map centre.
    function service.track(player, root, grace, settle)
        motion[player.UserId] = { root = root, position = root.Position, safe = root.CFrame, time = os.clock(),
            blockedUntil = os.clock() + grace, settledAt = os.clock() + (settle or 0) }
    end
    -- Takes a position (stands upright) or a full CFrame (gym poses).
    function service.relocate(player, position)
        local root = service.body(player)
        if not root then return end
        player.Character:PivotTo(typeof(position) == "CFrame" and position or CFrame.new(position))
        root.AssemblyLinearVelocity = Vector3.zero
        service.track(player, root, 0.5)
    end
    -- Called from the server tick: snap back jumps faster than the player's limit allows.
    function service.sample(player, now)
        local root = service.body(player)
        local sample = motion[player.UserId]
        if not root or not sample or sample.root ~= root then return end
        local delta = root.Position - sample.position
        if now >= sample.settledAt and Vector3.new(delta.X, 0, delta.Z).Magnitude > limit(player) * (now - sample.time) + 3 then
            root.CFrame = sample.safe
            root.AssemblyLinearVelocity = Vector3.zero
            sample.blockedUntil = now + 2
        end
        sample.position, sample.safe, sample.time = root.Position, root.CFrame, now
    end
    function service.forget(player)
        motion[player.UserId] = nil
    end
    return service
end
return Movement
