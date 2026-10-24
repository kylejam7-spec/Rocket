-- Ramps and placement reach on every tier and variant, built in a detached folder.
-- Ramps hug the rocket without covering any segment, stay wide enough for a full
-- server, stay inside the launch complex, have no ledge at the mount, and anyone
-- standing on a ramp or the hull beside the fill line can place, at every fill level.
return function()
    local Build = require(script.Parent.RocketBuildService)
    local config = require(game.ReplicatedStorage.Shared.Config)
    local Layout = require(script.Parent.SiteLayout)
    local padHalf = Layout.Pad.size / 2
    local holder = Instance.new("Folder")
    local ok, failure = pcall(function()
        for tier = 1, 5 do
            for variant = 1, 3 do
                local build = Build.new(holder, CFrame.new())
                build:load(tier, variant)
                local name = "T" .. tier .. "v" .. variant
                local widest = 0
                for _, item in build.lists.Metal.items do widest = math.max(widest, item.high.X, -item.low.X) end
                assert(build.rampInner >= widest + 1 and build.rampInner <= widest + 1.5, name .. " ramp hugs the widest segment")
                assert(build.rampOuter - build.rampInner >= 40, name .. " ramp wide enough for a full server")
                assert(build.rampOuter <= padHalf.X - 1, ("%s ramp reaches x = %.1f, past the pad (%.1f)"):format(name, build.rampOuter, padHalf.X))
                -- The launch complex (mount, ramps' feet, tower) stands on the pad.
                for _, item in build.site.LaunchComplex:GetDescendants() do
                    if item:IsA("BasePart") and item.Name ~= "RampBeacon" then
                        local p = item.Position
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
    return "All 15 rocket variants: ramps hug the rocket, >=40 wide, on the pad; no ledge; placing in reach from ramps and hull at every fill level"
end
