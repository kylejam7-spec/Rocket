-- Ramps and placement reach on every tier and variant, each built in a folder of its own.
-- Ramps hug the rocket without covering any segment, stay wide enough for a full
-- server, stay inside the launch complex, have no ledge at the mount, and anyone
-- standing on a ramp or the hull beside the fill line can place, at every fill level.
-- Nothing of the ramps (bridges, rails, posts) touches the rocket, bridges join them all
-- the way up, the boarding walkway's top is clear of the mount's trim, the rocket being
-- built and its ramps leave the boarding station (standing in every phase) clear, and the
-- upright rocket leaves the station, its door and the walk from the ramp to it clear.
-- An unupgraded player (Upgrades.reachAt 0) can place every Metal segment and Fuel cell
-- from where the ramp's slide stops them.
return function()
    local Build = require(script.Parent.RocketBuildService)
    local config = require(game.ReplicatedStorage.Shared.Config)
    local Layout = require(script.Parent.SiteLayout)
    local Upgrades = require(game.ReplicatedStorage.Shared.Upgrades)
    local reach0 = Upgrades.reachAt(config, 0)
    local padHalf = Layout.Pad.size / 2
    local ORIGIN = CFrame.new(0, 0, 30000)
    local holder = Instance.new("Folder")
    -- In workspace for the overlap queries (they only test this build's own parts), far
    -- off the map so nothing there meets a player.
    holder.Name = "RampCheck"
    holder.Parent = workspace
    local ok, failure = pcall(function()
        for tier = 1, 5 do
            for variant = 1, 3 do
                local build = Build.new(holder, ORIGIN)
                local triggerCFrame, triggerSize = build:load(tier, variant)
                local name = "T" .. tier .. "v" .. variant
                local widest = 0
                for _, item in build.lists.Metal.items do widest = math.max(widest, item.high.X, -item.low.X) end
                assert(build.rampInner >= widest + 1 and build.rampInner <= widest + 1.5, name .. " ramp hugs the widest segment")
                assert(build.rampOuter - build.rampInner >= 40, name .. " ramp wide enough for a full server")
                assert(build.rampOuter <= padHalf.X - 1, ("%s ramp reaches x = %.1f, past the pad (%.1f)"):format(name, build.rampOuter, padHalf.X))
                -- The launch complex (mount, ramps' feet, tower) stands on the pad.
                for _, item in build.site.LaunchComplex:GetDescendants() do
                    if item:IsA("BasePart") and item.Name ~= "RampBeacon" then
                        local p = ORIGIN:PointToObjectSpace(item.Position)
                        if p.Y < 3 then
                            assert(math.abs(p.X) <= padHalf.X + 1 and math.abs(p.Z) <= padHalf.Z + 1,
                                ("%s %s at (%.0f, %.0f) is off the pad"):format(name, item.Name, p.X, p.Z))
                        end
                    end
                end
                -- No ledge: where a ramp's inner edge crosses the mount's front face, its
                -- surface is above the mount top.
                local mount = build.site.LaunchComplex.LaunchMount
                local front, top = mount.Position.Z + mount.Size.Z / 2, mount.Position.Y + mount.Size.Y / 2
                for _, ramp in build.site.LaunchComplex:GetChildren() do
                    if ramp.Name == "LaunchRamp" and mount.Size.X / 2 > build.rampInner then
                        local edge = -math.sign(ramp.Position.X) * ramp.Size.X / 2
                        local closest
                        for t = -ramp.Size.Y / 2, ramp.Size.Y / 2, 0.2 do
                            local p = (ramp.CFrame * CFrame.new(edge, t, ramp.Size.Z / 2)).Position
                            if not closest or math.abs(p.Z - front) < math.abs(closest.Z - front) then closest = p end
                        end
                        assert(closest.Y >= top, string.format("%s ramp meets a %.1f-stud ledge at the mount", name, top - closest.Y))
                    end
                end
                -- Nothing of the ramps (bridges, rails, posts) cuts the rocket being built,
                -- and bridges join the ramps all the way up: none more than 110 studs apart
                -- (the first can wait above fins that stand out to the ramps' inner edge).
                -- (The unbuilt rocket is a ghost that ignores queries: made queryable here.)
                local hull = {}
                for _, part in build.vehicle:GetDescendants() do
                    if part:IsA("BasePart") then part.CanQuery = true; table.insert(hull, part) end
                end
                local overlap = OverlapParams.new()
                overlap.FilterType = Enum.RaycastFilterType.Include
                overlap.FilterDescendantsInstances = hull
                for _, part in build.ramps do
                    local hit = workspace:GetPartsInPart(part, overlap)[1]
                    assert(not hit, ("%s %s cuts the rocket's %s"):format(name, part.Name, hit and hit.Name or ""))
                end
                assert(#build.bridges >= 3, name .. " has bridges between its ramps")
                local last = build.bounds.low.Y
                for _, bridge in build.bridges do
                    assert(bridge.y - last <= 110, ("%s: %.0f studs of ramp with no bridge"):format(name, bridge.y - last))
                    last = bridge.y
                end
                assert(build.rampTop - last <= 110, name .. " has no bridge near the top")
                -- Anyone standing on a bridge is moved off before the ramps retract.
                for _, bridge in build.bridges do
                    for _, x in { 0, build.rampInner * 0.5, -build.rampInner * 0.9 } do
                        local spot = build.pivot * Vector3.new(x, bridge.y, bridge.top + 3)
                        assert(build:isAboard(spot) or build:isOnRamps(spot), ("%s: someone on the bridge at %.0f isn't moved off"):format(name, bridge.y))
                    end
                end
                -- The boarding walkway's top is clear of the mount's trim strips.
                local trims = {}
                for _, part in build.site.LaunchComplex:GetChildren() do
                    if part.Name == "MountTrim" then table.insert(trims, part) end
                end
                overlap.FilterDescendantsInstances = trims
                local station = build.site.LaunchComplex.BoardingStation
                assert(#workspace:GetPartsInPart(station.BoardingRamp, overlap) == 0, name .. " mount trim stands up through the boarding walkway")
                -- The station stands in every phase: the rocket lying at its build angle and
                -- the build ramps, bridges, rails and posts don't cut through any of it either.
                local building = table.clone(hull)
                for _, part in build.ramps do
                    if part:IsA("BasePart") then part.CanQuery = true; table.insert(building, part) end
                end
                overlap.FilterDescendantsInstances = building
                for _, part in station:GetDescendants() do
                    local hit = part:IsA("BasePart") and workspace:GetPartsInPart(part, overlap)[1]
                    assert(not hit, ("%s rocket being built (its %s) cuts the boarding station's %s"):format(name, hit and hit.Name or "", part.Name))
                end
                -- With the rocket upright for boarding, nothing of it touches the station or
                -- stands in front of the door; the door is on the mount.
                build.vehicle:PivotTo(ORIGIN)
                overlap.FilterDescendantsInstances = hull
                for _, part in station:GetDescendants() do
                    local hit = part:IsA("BasePart") and workspace:GetPartsInPart(part, overlap)[1]
                    assert(not hit, ("%s upright rocket's %s cuts the boarding station's %s"):format(name, hit and hit.Name or "", part.Name))
                end
                local zone = Instance.new("Part")
                zone.Anchored, zone.CanCollide = true, false
                zone.CFrame, zone.Size = triggerCFrame * CFrame.new(0, 0, 3), triggerSize + Vector3.new(0, 0, 6)
                zone.Parent = holder
                assert(#workspace:GetPartsInPart(zone, overlap) == 0, name .. " rocket stands in front of the BOARD door")
                -- ...nor anywhere on the walk from the top of the boarding ramp to the door.
                local doorAt = ORIGIN:PointToObjectSpace(station.BoardingDoor.Position)
                local mountFront = ORIGIN:PointToObjectSpace(mount.Position).Z + mount.Size.Z / 2
                local mountTop = ORIGIN:PointToObjectSpace(mount.Position).Y + mount.Size.Y / 2
                zone.Size = Vector3.new(station.BoardingRamp.Size.X, 10, mountFront - doorAt.Z)
                zone.CFrame = ORIGIN * CFrame.new(0, mountTop + 5.5, (mountFront + doorAt.Z) / 2)
                assert(#workspace:GetPartsInPart(zone, overlap) == 0, name .. " rocket stands on the walk from the boarding ramp to the door")
                zone:Destroy()
                local door = ORIGIN:PointToObjectSpace(station.BoardingDoor.Position)
                local mount = build.site.LaunchComplex.LaunchMount
                assert(door.Z + 4.4 <= ORIGIN:PointToObjectSpace(mount.Position).Z + mount.Size.Z / 2, name .. " BOARD door's doorstep runs off the mount")
                build.vehicle:PivotTo(build.pivot)
                -- Every segment and fuel cell is within an unupgraded player's reach of where
                -- the ramp's slide stops them (a stud to spare); the ramps' feet are under
                -- the rocket's bottom.
                local ramp = build.site.LaunchComplex.LaunchRamp
                local stop = build.pivot:PointToObjectSpace(ramp.Position).Y + ramp:GetAttribute("StopAt")
                for _, list in build.lists do
                    for _, item in list.items do
                        assert(item.high.Y - stop <= reach0 - 1, ("%s %s's top is %.1f studs above the ramp stop (reach %d)"):format(name, item.spec.name, item.high.Y - stop, reach0))
                    end
                end
                assert(build.pivot:PointToObjectSpace(ramp.Position).Y - ramp.Size.Y / 2 <= build.bounds.low.Y, name .. " ramps start above the rocket's bottom")
                for _, fraction in { 0, 0.1, 0.3, 0.5, 0.7, 0.9, 0.99 } do
                    build:setProgress(fraction, 0)
                    local item = build.frontierItem
                    local y = item.low.Y + (item.high.Y - item.low.Y) * build.frontierAmount
                    local function reach(x, along, z)
                        return build:inPlaceReach(build.pivot * Vector3.new(x, y + along, z), config.FrontierReach)
                    end
                    -- Standing spots (root height) across both ramps and the hull ridge, a
                    -- few studs either side of the fill line along the rocket.
                    for _, along in { -6, 0, 6 } do
                        for x = -build.rampOuter + 0.5, build.rampOuter - 0.5, 1 do
                            local onRamp = math.abs(x) >= build.rampInner
                            if onRamp or math.abs(x) <= 2 then
                                local z = onRamp and build.rampSurface + 3 or item.high.Z + 3
                                assert(reach(x, along, z), string.format("%s %.0f%%: x=%.1f out of reach", name, fraction * 100, x))
                            end
                        end
                    end
                    -- ...but not far up or down the ramp, or high above it.
                    assert(not reach(build.rampOuter - 1, config.FrontierReach + 30, build.rampSurface + 3), name .. " far up the ramp")
                    assert(not reach(build.rampOuter - 1, 0, build.rampSurface + 40), name .. " far above the ramp")
                end
                build.site:Destroy()
            end
        end
    end)
    holder:Destroy()
    assert(ok, failure)
    return "All 15 rocket variants: ramps hug the rocket, >=40 wide, on the pad; no ledge; bridges and posts clear of the rocket, never more than 110 apart; boarding walkway clear; placing in reach from ramps and hull at every fill level"
end
