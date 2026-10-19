-- Earth site perimeter (SiteSurroundsService): at every expansion stage the hoarding's
-- lines close into one loop round the ground and the Gym District, the barrier is far
-- taller than a jump, and the land beyond sits under the site's ground so expansion
-- strips cover it.
return function()
    local Surrounds = require(script.Parent.SiteSurroundsService)
    local Layout = require(script.Parent.SiteLayout)
    local district = { x = 56, z1 = Layout.Ground.z1 + 300 }
    for stage = 0, 4 do
        local edge = Layout.Ground.x + stage * 80
        local ends = {}
        local west, east = false, false
        for _, line in Surrounds.lines(edge, district) do
            for _, point in line do
                local key = ("%.1f,%.1f"):format(point.X, point.Y)
                ends[key] = (ends[key] or 0) + 1
            end
            local a, b = line[1], line[2]
            if a.X == b.X and math.abs(a.X) == edge and math.min(a.Y, b.Y) <= Layout.Ground.z0 and math.max(a.Y, b.Y) >= Layout.Ground.z1 then
                if a.X < 0 then west = true else east = true end
            end
        end
        for key, count in ends do
            assert(count == 2, ("stage %d: the perimeter is open at %s"):format(stage, key))
        end
        assert(west and east, ("stage %d: the perimeter does not run the length of the ground's sides"):format(stage))
    end
    assert(Surrounds.BarrierHeight >= 60 and Surrounds.BarrierHeight > Surrounds.WallHeight, "barrier too low")
    assert(Surrounds.PlainDepth > 0 and Surrounds.PlainDepth < 1, "the plain must sit just under the site's ground")
    assert(Surrounds.PlainReach >= Surrounds.Mountains.far + 500, "mountains stand off the plain")
end
