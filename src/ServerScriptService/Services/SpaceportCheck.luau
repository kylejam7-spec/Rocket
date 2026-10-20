-- Spaceport props: every placement names a SiteModels model and stands where it was put.
-- Inside the fence it is on the apron behind the pad, under Spaceport.ApronCap (clear of
-- every tier's leaning rocket); outside, it sits on one of the spaceport's slabs (the
-- monorail's track may cross the ground between them).
return function()
    local Spaceport = require(script.Parent.SpaceportService)
    local Props = require(script.Parent.SiteProps)
    local Layout = require(script.Parent.SiteLayout)
    local holder = Instance.new("Folder")
    local ok, failure = pcall(function()
        for index, spot in Spaceport.Props do
            local name, x, z, yaw, scale, solid, y = table.unpack(spot)
            local label = ("Spaceport.Props[%d] %s"):format(index, tostring(name))
            assert(type(scale) == "number" and scale > 0 and type(solid) == "boolean", label .. " is malformed")
            local model = Props.place(holder, name, CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0), scale, solid)
            assert(model, label .. " is not in SiteModels")
            local box, size = model:GetBoundingBox()
            local low, high = box.Position - size / 2, box.Position + size / 2
            assert(math.abs(low.Y - (y or 0)) < 0.1, label .. " does not stand where placed")
            local monorail = name:match("^Space_monorail_") ~= nil
            if high.Z > Layout.Ground.z0 and math.abs(box.Position.X) < Layout.Ground.x then
                -- On the site: the apron behind the pad.
                assert(high.Z <= Spaceport.ApronFront, ("%s is in front of the apron line (z %.0f)"):format(label, high.Z))
                assert(math.abs(low.X) <= Layout.Apron.x and math.abs(high.X) <= Layout.Apron.x, label .. " is off the apron")
                assert(high.Y <= Spaceport.ApronCap, ("%s stands %.0f high, over the apron cap"):format(label, high.Y))
                assert(low.Z >= Layout.Ground.z0 or monorail, label .. " straddles the back fence")
            elseif not monorail then
                local onSlab = false
                for _, r in Spaceport.Slabs do
                    if low.X >= r[1] and high.X <= r[2] and low.Z >= r[3] and high.Z <= r[4] then onSlab = true end
                end
                assert(onSlab, ("%s is off every slab (x %.0f..%.0f, z %.0f..%.0f)"):format(label, low.X, high.X, low.Z, high.Z))
            end
            for _, part in model:GetDescendants() do
                if part:IsA("BasePart") then
                    assert(part.Anchored and part.CanCollide == solid, label .. " collision is not as placed")
                end
            end
        end
    end)
    holder:Destroy()
    assert(ok, failure)
    -- Slabs lie outside the widest site (4 expansions of 80) and off the Gym District.
    local widest = Layout.Ground.x + 4 * 80
    for name, r in Spaceport.Slabs do
        assert(r[1] > widest or r[2] < -widest or r[4] < Layout.Ground.z0 - 40, name .. " slab overlaps where the site grows")
    end
    return "Spaceport checks passed: " .. #Spaceport.Props .. " props placed, apron under the rockets' clearance, the rest on slabs"
end
