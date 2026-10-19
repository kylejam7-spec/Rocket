-- Kenney site props: every model in SiteModels has its pivot at its base and its kit's
-- palette; every placement names one of them and, placed, stands on the site clear of
-- the lane, the stations' footprints, spawn, the forecourt huts and the ground Tier 5's
-- launch complex covers.
return function()
    local Dressing = require(script.Parent.SiteDressingService)
    local Props = require(script.Parent.SiteProps)
    local Layout = require(script.Parent.SiteLayout)
    local models = script.Parent.Parent:FindFirstChild("SiteModels")
    assert(models, "ServerScriptService.SiteModels is missing (src/ServerScriptService/SiteModels.rbxm)")
    for _, model in models:GetChildren() do
        local kit = model.Name:match("^(%a+)_")
        assert(kit == "Factory" or kit == "Station" or kit == "Space", model.Name .. " has no kit prefix")
        assert(model:GetPivot().Position.Magnitude < 0.01, model.Name .. " is not stored at the origin")
        local box, size = model:GetBoundingBox()
        assert(math.abs(box.Position.Y - size.Y / 2) < 0.05, model.Name .. "'s pivot is not at its base")
        for _, part in model:GetDescendants() do
            if part:IsA("MeshPart") then
                assert(part.TextureID == Props.Palettes[kit], model.Name .. " is not on its kit's palette")
            end
        end
    end

    local keepOut = {
        { "lane", -Layout.Lane.width / 2 - 2, Layout.Lane.width / 2 + 2, Layout.Lane.z0, Layout.Lane.z1 },
        { "spawn", Layout.Spawn.X - 14, Layout.Spawn.X + 14, Layout.Spawn.Z - 14, Layout.Spawn.Z + 14 },
        { "launch complex", -245, 245, Layout.Apron.z0, Layout.Apron.z1 },
    }
    for _, hut in { Layout.Upgrades, Layout.UfoShop } do
        table.insert(keepOut, { "forecourt hut", hut.X - 16, hut.X + 16, hut.Z - 16, hut.Z + 16 })
    end
    for _, r in Layout.Reserved do
        table.insert(keepOut, { "station", r.x0, r.x1, r.z0, r.z1 })
    end

    local holder = Instance.new("Folder")
    local ok, failure = pcall(function()
        for index, spot in Dressing.Props do
            local name, x, z, yaw, scale, solid = table.unpack(spot)
            local label = ("Props[%d] %s"):format(index, tostring(name))
            assert(type(scale) == "number" and scale > 0 and type(solid) == "boolean", label .. " is malformed")
            local model = Props.place(holder, name, CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0), scale, solid)
            assert(model, label .. " is not in SiteModels")
            local box, size = model:GetBoundingBox()
            local low, high = box.Position - size / 2, box.Position + size / 2
            assert(math.abs(low.Y) < 0.1, label .. " does not stand on the ground")
            assert(math.abs(low.X) <= Layout.Ground.x and math.abs(high.X) <= Layout.Ground.x
                and low.Z >= Layout.Ground.z0 and high.Z <= Layout.Ground.z1, label .. " hangs off the site")
            for _, zone in keepOut do
                local overlaps = high.X > zone[2] and low.X < zone[3] and high.Z > zone[4] and low.Z < zone[5]
                assert(not overlaps, ("%s overlaps the %s (x %.0f..%.0f, z %.0f..%.0f)"):format(label, zone[1], low.X, high.X, low.Z, high.Z))
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
end
