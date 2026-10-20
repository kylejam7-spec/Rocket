-- Builds the cabin and destinations into a scratch folder and checks them by raycast:
-- every rocket design has a destination, each arrival lands on that destination's
-- ground inside its fence, and the cabin is closed in on every side.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Missions = require(ReplicatedStorage.Shared.Missions)
    local Destinations = require(script.Parent.DestinationService)
    local scratch = Instance.new("Folder")
    scratch.Name = "DestinationCheckScratch"
    scratch.Parent = workspace
    local ok, failure = pcall(function()
        local built, cabin = Destinations.build(scratch, config)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { scratch }
        for index = 1, Missions.Count do
            local mission = Missions.get(index)
            assert(built[mission.ModelTier], "mission " .. mission.Id .. " has no destination")
            assert(config.Destinations[mission.ModelTier].id == mission.Id, "mission " .. mission.Id .. " flies to the wrong destination")
        end
        -- Rarer destinations pay more per tick, in even steps from 6 a tick (4 a second) on the Moon.
        local destinations = config.Destinations
        assert(config.Planet.StrengthBonus * destinations[1].reward == 6 and config.Planet.SpeedBonus * destinations[1].reward == 6, "Moon pays 6 of each stat per tick")
        assert(config.Planet.TicksPerSecond == 4, "stay rewards tick 4 times a second")
        -- Stays last about two minutes everywhere.
        for index = 1, Missions.Count do
            local seconds = Missions.get(index).RewardSeconds or config.RewardSeconds
            assert(seconds >= 90 and seconds <= 150, "destination stays last about two minutes")
        end
        local step = destinations[2].reward - destinations[1].reward
        for tier = 2, #destinations do
            assert(step > 0 and destinations[tier].reward - destinations[tier - 1].reward == step, "destination rewards must grow evenly with rarity")
        end
        local ids = {}
        for tier, place in built do
            local spec = config.Destinations[tier]
            assert(not ids[spec.id], "duplicate destination " .. spec.id)
            ids[spec.id] = true
            assert(type(place.name) == "string" and place.gravity > 0, spec.id .. " name/gravity")
            -- Far from the main map (±520 x, -340..160 z) and from each other.
            assert(math.abs(place.center.X) > 1000 or math.abs(place.center.Z) > 1000, spec.id .. " is on the main map")
            -- Both gym spots stand on this destination's ground, clear of the arrival.
            for kind, spot in place.gym do
                local floor = workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params)
                assert(floor and floor.Instance:IsDescendantOf(scratch:FindFirstChild(spec.id)), spec.id .. ": no ground under the " .. kind)
                assert(math.abs(floor.Position.Y - (spot.Y - 1)) < 0.6, spec.id .. ": " .. kind .. " spot is not on the ground (hit " .. floor.Instance.Name .. ")")
                assert((Vector3.new(spot.X, 0, spot.Z) - Vector3.new(place.arrival.X, 0, place.arrival.Z)).Magnitude > 15, spec.id .. ": " .. kind .. " too close to the arrival")
            end
            local hit = workspace:Raycast(place.arrival, Vector3.new(0, -12, 0), params)
            assert(hit and hit.Instance:IsDescendantOf(scratch:FindFirstChild(spec.id)), spec.id .. ": arrival has no ground under it")
            -- Walking straight out from the arrival hits a fence before the edge.
            for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
                local wall = workspace:Raycast(place.arrival, direction * 200, params)
                assert(wall, spec.id .. ": no wall toward " .. tostring(direction))
                local below = workspace:Raycast(wall.Position - direction * 2 + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
                assert(below, spec.id .. ": floor ends before the wall toward " .. tostring(direction))
            end
        end
        for other, a in built do
            for tier, b in built do
                if other ~= tier then assert((a.center - b.center).Magnitude >= 8000, "destinations close enough to see each other's backdrops") end
            end
        end
        -- Cabin: floor under the arrival, and walls or ceiling in every direction.
        local offset = cabin.arrival - cabin.center
        assert(math.abs(offset.X) < cabin.size.X / 2 and math.abs(offset.Z) < cabin.size.Z / 2, "cabin arrival outside the cabin")
        assert(workspace:Raycast(cabin.arrival, Vector3.new(0, -10, 0), params), "cabin has no floor")
        for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis, Vector3.yAxis } do
            assert(workspace:Raycast(cabin.arrival + Vector3.new(0, 4, 0), direction * 60, params), "cabin open toward " .. tostring(direction))
        end
        assert(cabin.exit and cabin.screen, "cabin needs an exit hatch and a screen")
        -- Seats leave an aisle: a straight walk at hip height reaches the exit hatch.
        local hip = Vector3.new(0, -1.5, 0)
        local toExit = workspace:Raycast(cabin.arrival + hip, (cabin.exit.Position - cabin.arrival) * Vector3.new(1, 0, 1) * 1.1, params)
        assert(toExit and toExit.Instance == cabin.exit, "something blocks the walk to the exit hatch: " .. (toExit and toExit.Instance.Name or "nothing hit"))
    end)
    scratch:Destroy()
    if not ok then error(failure, 0) end
end
