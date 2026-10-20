--[[
    Splits the three spaceport imports (Spaceport_Space / _Modular / _Station, from
    bake_spaceport.py via File > Import 3D into Workspace) into one model per MeshPart and
    merges them into ServerScriptService.SiteModels, replacing any model of the same name.
    Run it in Studio's command bar (Edit mode), then save SiteModels.rbxm (README step 6).
    With Rojo connected, Rojo re-adds the saved file's models on top of these: keep one
    copy of each name afterwards.

    Models match prepare.luau's: anchored decor, box collision (Modular: precise, as its
    rooms are walked into), pivot at the middle of the base, stored at 10 studs per kit
    metre (the importer brings them in at 100), on their kit's palette (SiteProps.Palettes; the importer's upload ids for Space and
    Modular went there, Station keeps its earlier id).
]]
local PER_METRE, STORED = 100, 10
local Palettes = require(game.ServerScriptService.Services.SiteProps).Palettes
local site = game.ServerScriptService.SiteModels

local count = 0
for _, fileName in { "Spaceport_Space", "Spaceport_Modular", "Spaceport_Station" } do
    local file = workspace:FindFirstChild(fileName)
    for _, raw in file and file:GetChildren() or {} do
        if raw:IsA("MeshPart") then
            local kit = raw.Name:match("^(%a+)_")
            local part = raw:Clone()
            part.Anchored = true
            part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
            -- Modular rooms are walked into: their hulls follow the walls, not a box.
            part.CollisionFidelity = kit == "Modular" and Enum.CollisionFidelity.PreciseConvexDecomposition or Enum.CollisionFidelity.Box
            part.Color = Color3.new(1, 1, 1)
            part.TextureID = Palettes[kit]
            for _, child in part:GetChildren() do
                if not child:IsA("Attachment") then child:Destroy() end
            end
            local model = Instance.new("Model")
            model.Name = raw.Name
            part.Parent = model
            model:ScaleTo(STORED / PER_METRE)
            local box, size = model:GetBoundingBox()
            model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
            model:PivotTo(CFrame.new())
            local prior = site:FindFirstChild(raw.Name)
            if prior then prior:Destroy() end
            model.Parent = site
            count += 1
        end
    end
end
print(("SiteModels: %d spaceport models merged, %d in all"):format(count, #site:GetChildren()))
