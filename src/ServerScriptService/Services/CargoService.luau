-- Material pickup at the stations, placement at the build frontier, the
-- server-driven hold loop and carried-material visuals. Rocket rules live in RocketService.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Rocket = require(script.Parent.RocketService)
local CargoVisual = require(script.Parent.CargoVisualService)
local Hold = require(script.Parent.HoldService)
local Cargo = {}

function Cargo.new(ctx)
    local config, World, Remote = ctx.config, ctx.World, ctx.Remote
    local frontier, frontierSign = World.frontier, World.frontierSign
    local colors = World.materialColors
    local holds = Hold.new(config.MaterialHoldSeconds)
    local depotPrompts, placePrompt = {}, nil
    local materialTargets, materialCallbacks = {}, {}
    local lastTransfer = {}
    local service = { holds = holds }

    function service.visual(player)
        local cargo = ctx.Cycle.rocket.cargo[player.UserId]
        CargoVisual.update(player.Character, cargo and cargo.materials, colors)
    end
    function service.refreshVisuals()
        for _, player in Players:GetPlayers() do service.visual(player) end
    end
    -- Moves the ring to the current fill point; hidden outside delivery phases. Each
    -- client slides the place prompt to the ring point nearest its own character.
    function service.updateFrontier()
        local material = Rocket.PhaseMaterial[ctx.Cycle.rocket.phase]
        local cframe, diameter = World.rocketBuild:frontier()
        local active = material ~= nil and cframe ~= nil
        frontierSign.Enabled = active
        frontier.Transparency = active and 0.55 or 1
        placePrompt.Enabled = active
        if not active then return end
        frontier.CFrame, frontier.Size = cframe, Vector3.new(0.4, diameter, diameter)
        frontier.Color = colors[material]
    end
    -- Only the material the current phase needs can be picked up or placed.
    function service.refreshPrompts()
        local material = Rocket.PhaseMaterial[ctx.Cycle.rocket.phase]
        for kind, items in depotPrompts do
            for _, item in items do item.Enabled = material == kind end
        end
        placePrompt.ActionText = "Place " .. (material or "materials")
        service.updateFrontier()
    end

    local function materialNear(player, object)
        local root = ctx.Movement.observed(player)
        if not root or not ctx.profiles:ready(player.UserId) or ctx.Interaction.training(player) then return false end
        if not Rocket.PhaseMaterial[ctx.Cycle.rocket.phase] then return false end
        local point = object.CFrame:PointToObjectSpace(root.Position)
        local half = object.Size / 2
        local closest = Vector3.new(math.clamp(point.X, -half.X, half.X), math.clamp(point.Y, -half.Y, half.Y), math.clamp(point.Z, -half.Z, half.Z))
        return (point - closest).Magnitude <= (object == frontier and config.FrontierReach or config.InteractionDistance)
    end
    -- `point` (an attachment) places the prompt somewhere on a large object; range is
    -- still checked against the whole object.
    local function holdPrompt(object, action, callback, point)
        local item = World.prompt(object, action, config.MaterialHoldSeconds)
        if point then
            item.Parent = point
            -- A station has many prompt points; show only the nearest one.
            item.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
        end
        materialTargets[item], materialCallbacks[item] = object, callback
        return item
    end
    -- One unit moves per MaterialHoldSeconds. Each callback returns false to end the hold.
    local function stepHold(player, entry, now)
        if now - entry.started < config.MaterialHoldSeconds then return end
        -- Catch up at most one missed tick so a stalled frame can't burst transfers.
        entry.started = math.max(entry.started + config.MaterialHoldSeconds, now - config.MaterialHoldSeconds)
        lastTransfer[player.UserId] = now
        if not materialCallbacks[entry.target](player) then holds:cancel(player.UserId) end
    end
    Remote.MaterialHold.OnServerEvent:Connect(function(player, item, holding)
        if holding == false then
            holds:cancel(player.UserId)
            return
        end
        local object = materialTargets[item]
        if holding ~= true or not object or not item.Enabled or not materialNear(player, object) then return end
        local rocket = ctx.Cycle.rocket
        local entry = holds.active[player.UserId]
        if entry and entry.target == item and entry.cycle == rocket.cycle then return end
        -- A press moves a unit right away so taps count; spacing from the last transfer
        -- keeps spam-tapping at the same rate as holding.
        local now = os.clock()
        holds:begin(player.UserId, item, rocket.cycle, math.max(lastTransfer[player.UserId] or -math.huge, now - config.MaterialHoldSeconds))
        stepHold(player, holds.active[player.UserId], now)
    end)

    for material, station in World.materialStations do
        local function pickup(player)
            local amount = ctx.Cycle.rocket:pickup(player.UserId, material, ctx.Stats.capacity(ctx.profiles.records[player.UserId].profile), 1)
            if amount == 0 then
                Remote.feedback(player, "Cargo full: carry it up to the glowing ring on the rocket.")
                return false
            end
            service.visual(player)
            ctx.Cycle.sendSoon(player)
            return true
        end
        depotPrompts[material] = {}
        for _, point in station.points do
            table.insert(depotPrompts[material], holdPrompt(station.zone, "Pick up " .. material, pickup, point))
        end
    end

    -- Shared by player deliveries and the Studio debug hook.
    function service.delivered(advanced)
        local rocket = ctx.Cycle.rocket
        World.rocketBuild:setProgress(rocket:progress("Metal"), rocket:progress("Fuel"))
        service.updateFrontier()
        if not advanced then ctx.Cycle.broadcastSoon(); return end
        if rocket.phase == "Fueling" then
            service.refreshVisuals()
            service.refreshPrompts()
            Remote.announce("ROCKET BUILT! Carry Fuel up and pour it into the tanks.")
            ctx.Cycle.broadcast()
        else
            ctx.Launch.beginBoarding()
        end
    end
    -- Pouring scales with carry capacity so any full ball empties in ~PourSeconds;
    -- a base 10-unit ball still moves one unit per tick.
    local function place(player)
        local rocket = ctx.Cycle.rocket
        local material = Rocket.PhaseMaterial[rocket.phase]
        local pour = math.ceil(ctx.Stats.capacity(ctx.profiles.records[player.UserId].profile) * config.MaterialHoldSeconds / config.PourSeconds)
        local amount, advanced = rocket:deliver(player.UserId, math.max(1, pour))
        if amount == 0 then
            Remote.feedback(player, material == "Fuel" and "Fill up on Fuel at the OIL REFINERY first."
                or "Pick up Metal at the SCRAP PIT first.")
            return false
        end
        service.visual(player)
        ctx.profiles.credit(ctx.profiles.records[player.UserId].profile, amount, config)
        ctx.profiles:dirty(player.UserId)
        ctx.Stats.update(player)
        local emptied = rocket.cargo[player.UserId] == nil
        if emptied then Remote.feedback(player, material .. " placed! Your deliveries this cycle: " .. (rocket.contributions[player.UserId] or 0)) end
        service.delivered(advanced)
        return not (emptied or advanced)
    end
    -- One prompt for the whole ring (CargoController keeps it at the nearest ring point),
    -- so walking around the rocket never swaps prompts and a held E keeps pouring.
    -- The server checks range against the whole ring.
    local point = Instance.new("Attachment")
    point.Name = "PlacePoint"
    point.Parent = frontier
    placePrompt = holdPrompt(frontier, "Place Metal", place, point)
    placePrompt.ObjectText = "Rocket"
    placePrompt.MaxActivationDistance = config.FrontierReach
    service.refreshPrompts()

    -- Repeat on the server while the prompt button remains held.
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for userId, entry in holds.active do
            local player = Players:GetPlayerByUserId(userId)
            local target = materialTargets[entry.target]
            if not player or not target or not entry.target.Enabled or entry.cycle ~= ctx.Cycle.rocket.cycle
                or not materialNear(player, target) then
                holds:cancel(userId)
            else
                stepHold(player, entry, now)
            end
        end
    end)
    Remote.DiscardCargo.OnServerEvent:Connect(function(player)
        local rocket = ctx.Cycle.rocket
        if not ctx.Interaction.allowed(player, "discard") or not rocket.cargo[player.UserId] then return end
        rocket.cargo[player.UserId] = nil
        service.visual(player)
        Remote.feedback(player, "Cargo cleared. Pick up another material.")
        ctx.Cycle.send(player)
    end)

    function service.forget(player)
        holds:cancel(player.UserId)
        lastTransfer[player.UserId] = nil
    end
    return service
end
return Cargo
