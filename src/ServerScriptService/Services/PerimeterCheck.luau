-- Earth site perimeter (SiteSurroundsService): at every expansion stage the hoarding's
-- lines close into one loop round the ground and the Gym District, the barrier is far
-- taller than a jump, and the plain beyond meets the site's edge without running under it.
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
    assert(Surrounds.PlainDepth > 0 and Surrounds.PlainDepth < 1, "the plain's top must sit just under the site's ground")
    -- No mountain reaches the fully expanded site or the District, none stands past the
    -- plain, and each row is continuous: neighbours' bases overlap, so the horizon is
    -- closed (Mountains: base radius 0.6 x size, second cube up to 0.35 x size off).
    local Mountains = require(script.Parent.Mountains)
    local centerZ = (Layout.Ground.z0 + Layout.Ground.z1) / 2
    local widest = Layout.Ground.x + 4 * 80
    local corner = math.max(Vector2.new(widest, Layout.Ground.z0 - centerZ).Magnitude, Vector2.new(widest, district.z1 - centerZ).Magnitude)
    -- The rocket cabin and every destination stand well outside Earth's land and mountains.
    local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
    local earth = Vector3.new(0, 0, centerZ)
    local places = { Config.CabinPosition }
    for _, spec in Config.Destinations do table.insert(places, spec.position) end
    for _, at in places do
        local flat = Vector3.new(at.X, 0, at.Z)
        assert((flat - earth).Magnitude > Surrounds.PlainReach * math.sqrt(2) + 500, ("%s is inside Earth's land"):format(tostring(at)))
    end
    for _, row in Surrounds.Mountains do
        local inner, outer = row.radius - row.spread / 2, row.radius + row.spread / 2
        assert(inner - row.size[2] * (Mountains.Base + 0.5) > corner, "mountains too close to the site")
        assert(outer + row.size[2] * (Mountains.Base + 0.5) < Surrounds.PlainReach, "mountains past the plain")
        local gap = 2 * math.pi * outer / row.count * 1.3
        assert(2 * Mountains.Base * row.size[1] > gap, "a mountain row leaves gaps in the horizon")
    end
    -- The plain never lies under the site or the District (the two would flicker through
    -- each other from a distance), its pieces fit in a part, and together with the holes
    -- they cover the whole square.
    for stage = 0, 4 do
        local edge = Layout.Ground.x + stage * 80
        local area = 0
        for _, r in Surrounds.plainPieces(edge, district) do
            assert(r.x1 - r.x0 <= Surrounds.Tile and r.z1 - r.z0 <= Surrounds.Tile, "plain piece too big for a part")
            for _, hole in { { -edge, edge, Layout.Ground.z0, Layout.Ground.z1 }, { -district.x, district.x, Layout.Ground.z1, district.z1 } } do
                assert(r.x1 <= hole[1] or r.x0 >= hole[2] or r.z1 <= hole[3] or r.z0 >= hole[4], ("stage %d: the plain runs under the site"):format(stage))
            end
            area += (r.x1 - r.x0) * (r.z1 - r.z0)
        end
        local site = 2 * edge * (Layout.Ground.z1 - Layout.Ground.z0) + 2 * district.x * (district.z1 - Layout.Ground.z1)
        assert(math.abs(area + site - (2 * Surrounds.PlainReach) ^ 2) < 1, ("stage %d: the plain has gaps"):format(stage))
    end
end
