--[[
    Turns the raw Kenney imports into ServerStorage.SiteModels, ready to save as
    src/ServerScriptService/SiteModels.rbxm. Run it in Studio's command bar (Edit mode) after
    importing into Workspace or ServerStorage.KenneyImport (see tools/map/README.md).

    Each model is anchored decor (SiteProps.place decides collision per placement, so
    hulls are boxes), has its pivot at the middle of its base and is stored at 10 studs
    per kit metre (Studio's importer brings every kit in at 100). The importer uploads the
    space kit's embedded palette once per model; every copy is pointed at
    SiteProps.Palettes.Space instead, so the game loads one image.
]]
local PER_METRE = 100
local STORED = 10
local Palettes = require(game.ServerScriptService.Services.SiteProps).Palettes

local source = game.ServerStorage:FindFirstChild("KenneyImport") or Instance.new("Folder")
for _, item in workspace:GetChildren() do
    if item:IsA("Model") and (item.Name:match("^Factory_") or item.Name:match("^Station_") or item.Name:match("^Space_")) then
        if source:FindFirstChild(item.Name) then item:Destroy() else item.Parent = source end
    end
end
source.Name = "KenneyImport"
source.Parent = game.ServerStorage

local out = game.ServerStorage:FindFirstChild("SiteModels")
if out then out:Destroy() end
out = Instance.new("Folder")
out.Name = "SiteModels"

local report = {}
for _, raw in source:GetChildren() do
    local kit = raw.Name:match("^(%a+)_")
    local model = raw:Clone()
    model.PrimaryPart = nil
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
            if part:IsA("MeshPart") then
                part.CollisionFidelity = Enum.CollisionFidelity.Box
                -- Palette textures carry the colour; the importer's grey would tint them.
                part.Color = Color3.new(1, 1, 1)
                part.TextureID = Palettes[kit]
            end
        elseif not part:IsA("Attachment") then
            part:Destroy()
        end
    end
    model:ScaleTo(model:GetScale() * STORED / PER_METRE)
    local box, size = model:GetBoundingBox()
    model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
    model:PivotTo(CFrame.new())
    model.Parent = out
    table.insert(report, ("%s %.1f x %.1f x %.1f"):format(model.Name, size.X, size.Y, size.Z))
end
out.Parent = game.ServerStorage
table.sort(report)
print(("SiteModels: %d models"):format(#report))
print(table.concat(report, "\n"))
