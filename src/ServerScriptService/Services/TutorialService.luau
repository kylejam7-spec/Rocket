-- Server-confirmed onboarding. A player's step lives in their profile
-- (tutorialStep) and only server observations advance it: cargo picked up, standing
-- in place reach with it, an accepted delivery, a training tick on the starter bench
-- and treadmill. The client can only ask to skip, which grants nothing.
-- One-time callouts (first Fuel phase, first boarding) are shown by the client and
-- marked seen here, only while that phase is on.
local Tutorial = {}
-- Phase 4 adds "Upgrade" after "Place" (buy a first upgrade) once the shop exists.
-- Steps are stored by name, so inserting one later keeps saved progress valid.
Tutorial.Steps = table.freeze({ "Pickup", "Carry", "Place", "Bench", "Treadmill", "Together" })
Tutorial.Done = "Done"
Tutorial.Callouts = table.freeze({ Fuel = "Fueling", Boarding = "Boarding" })

function Tutorial.valid(step)
    return step == Tutorial.Done or table.find(Tutorial.Steps, step) ~= nil
end

-- Events are named after the step they finish. Returns the step after `step` when
-- `event` finishes it, else nil (out-of-order events never skip ahead).
function Tutorial.advance(step, event)
    if step ~= event then return nil end
    local index = table.find(Tutorial.Steps, step)
    return index and (Tutorial.Steps[index + 1] or Tutorial.Done)
end

function Tutorial.new(ctx)
    local config = ctx.config
    local service = {}
    local function profileOf(player)
        if not ctx.profiles:ready(player.UserId) then return nil end
        return ctx.profiles.records[player.UserId].profile
    end
    local function set(player, profile, step)
        profile.tutorialStep = step
        ctx.profiles:dirty(player.UserId)
        ctx.Cycle.sendSoon(player)
        if step == "Together" then
            -- The last step is a message; it finishes on its own.
            task.delay(config.TutorialFinalSeconds, function()
                if player.Parent then service.observe(player, "Together") end
            end)
        end
    end
    function service.observe(player, event)
        local profile = profileOf(player)
        local step = profile and Tutorial.advance(profile.tutorialStep, event)
        if step then set(player, profile, step) end
    end
    -- From the 5 Hz movement sample: "Carry" finishes in place reach, and goes back
    -- to "Pickup" if the cargo is gone (dropped, or the phase moved on).
    function service.sample(player)
        local profile = profileOf(player)
        if not profile or profile.tutorialStep ~= "Carry" then return end
        if not ctx.Cycle.rocket.cargo[player.UserId] then set(player, profile, "Pickup"); return end
        local root = ctx.Movement.observed(player)
        if root and ctx.World.rocketBuild:inPlaceReach(root.Position, config.FrontierReach) then
            service.observe(player, "Carry")
        end
    end

    local remotes = ctx.Remote.folder
    local skip = Instance.new("RemoteEvent")
    skip.Name = "TutorialSkip"
    skip.Parent = remotes
    skip.OnServerEvent:Connect(function(player)
        local profile = profileOf(player)
        if not profile or profile.tutorialStep == Tutorial.Done or not ctx.Interaction.allowed(player, "tutorial") then return end
        set(player, profile, Tutorial.Done)
    end)
    local seen = Instance.new("RemoteEvent")
    seen.Name = "TutorialSeen"
    seen.Parent = remotes
    seen.OnServerEvent:Connect(function(player, name)
        local profile = profileOf(player)
        if not profile or type(name) ~= "string" or Tutorial.Callouts[name] ~= ctx.Cycle.rocket.phase then return end
        if table.find(profile.seenCallouts, name) or not ctx.Interaction.allowed(player, "callout") then return end
        table.insert(profile.seenCallouts, name)
        ctx.profiles:dirty(player.UserId)
        ctx.Cycle.sendSoon(player)
    end)
    return service
end

return Tutorial
