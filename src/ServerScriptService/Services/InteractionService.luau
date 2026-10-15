-- Shared server checks for player interactions: per-action rate limits and proximity.
local Interaction = {}

function Interaction.new(ctx)
    local config = ctx.config
    local lastAction = {}
    local service = {}
    function service.allowed(player, action)
        local now = os.clock()
        local history = lastAction[player.UserId] or {}
        lastAction[player.UserId] = history
        if now - (history[action] or -math.huge) < config.ActionCooldown then return false end
        history[action] = now
        return true
    end
    function service.training(player)
        return ctx.Training and ctx.Training.sessions[player.UserId] ~= nil
    end
    function service.near(player, object)
        local root = ctx.Movement.observed(player)
        return not service.training(player) and ctx.profiles:ready(player.UserId) and root and object:IsA("BasePart") and object.Anchored and object:IsDescendantOf(ctx.World.world) and (root.Position - object.Position).Magnitude <= config.InteractionDistance
    end
    function service.forget(player)
        lastAction[player.UserId] = nil
    end
    return service
end
return Interaction
