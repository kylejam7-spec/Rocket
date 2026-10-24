-- Character lookup, relocation and the horizontal-move check behind every interaction.
-- The check is a budget (Config.MoveLimitFactor / MoveBurstSeconds / MoveSlackStuds): each
-- player earns studs of horizontal movement at a margin over the walk speed their profile
-- gives them (server-derived, never the client's), banked up to a short burst, and each
-- server sample spends what they moved. Moves that arrive bunched up after lag fit in the
-- bank; going faster than the limit for longer drains it and snaps them back. Vertical
-- movement (falls, jumps) isn't counted. Server teleports (relocate) start a fresh budget.
-- MovementCheck runs the budget.
local Movement = {}

local function finite(vector)
    return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z and vector.Magnitude < 1e7
end

-- The most a budget holds at `rate` studs a second.
function Movement.cap(config, rate)
    return rate * config.MoveBurstSeconds + config.MoveSlackStuds
end
-- One sample: `budget` left after moving `moved` studs in `dt` seconds at `rate`. Below
-- zero means the move was too fast.
function Movement.spend(config, budget, rate, dt, moved)
    return math.min(Movement.cap(config, rate), budget + rate * math.max(0, dt)) - moved
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
    -- Studs a second this player may cover: a margin over their profile's walk speed (the
    -- same speed StatsService gives their Humanoid).
    local function limit(player)
        local record = ctx.profiles and ctx.profiles.records[player.UserId]
        local walk = record and ctx.Stats.speed(record.profile) or config.BaseSpeed
        return math.max(config.BaseSpeed, walk) * config.MoveLimitFactor
    end
    local function horizontal(delta) return Vector3.new(delta.X, 0, delta.Z).Magnitude end
    function service.observed(player)
        local root = service.body(player)
        if not root then return nil end
        local sample = motion[player.UserId]
        if not sample or sample.root ~= root or os.clock() < sample.blockedUntil then return nil end
        -- Check again in the interaction handler, covering the gap between samples.
        local moved = horizontal(root.Position - sample.position)
        if Movement.spend(config, sample.budget, limit(player), os.clock() - sample.time, moved) < 0 then return nil end
        return root
    end
    -- `settle` seconds of free movement before the check applies: CharacterAdded fires
    -- before Roblox moves the new character onto its SpawnLocation, so without it the
    -- spawn move looks like a teleport and snaps players back to the map centre.
    function service.track(player, root, grace, settle)
        motion[player.UserId] = { root = root, position = root.Position, safe = root.CFrame, time = os.clock(),
            blockedUntil = os.clock() + grace, settledAt = os.clock() + (settle or 0), from = nil,
            budget = Movement.cap(config, limit(player)) }
    end
    -- Takes a position (stands upright) or a full CFrame (gym poses).
    function service.relocate(player, position)
        local root = service.body(player)
        if not root then return end
        player.Character:PivotTo(typeof(position) == "CFrame" and position or CFrame.new(position))
        root.AssemblyLinearVelocity = Vector3.zero
        service.track(player, root, 0.5)
    end
    -- Called from the server tick: snap back a player who overspends their budget.
    function service.sample(player, now)
        local root = service.body(player)
        local sample = motion[player.UserId]
        if not root or not sample or sample.root ~= root then return end
        local rate = limit(player)
        if now < sample.settledAt then
            sample.budget = Movement.cap(config, rate)
        else
            sample.budget = Movement.spend(config, sample.budget, rate, now - sample.time, horizontal(root.Position - sample.position))
            if sample.budget < 0 then
                root.CFrame = sample.safe
                root.AssemblyLinearVelocity = Vector3.zero
                sample.blockedUntil = now + 2
                -- Earned again from nothing: snapping back can't refill a burst.
                sample.budget = 0
                sample.from = nil
                sample.time = now
                return
            end
        end
        sample.from = sample.position
        sample.position, sample.safe, sample.time = root.Position, root.CFrame, now
    end
    -- The last sampled step (from, to), for checks a fast runner could cross between
    -- samples (the BOARD door): nil just after a spawn or relocation.
    function service.lastStep(player)
        local root = service.body(player)
        local sample = motion[player.UserId]
        if not root or not sample or sample.root ~= root or not sample.from then return nil end
        return sample.from, sample.position
    end
    function service.forget(player)
        motion[player.UserId] = nil
    end
    return service
end
return Movement
