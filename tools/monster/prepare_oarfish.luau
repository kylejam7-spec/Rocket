--[[
    After File > Import 3D of assets/models-textures/Monster/import/Europa_Oarfish_Rig.fbx
    (tools/monster/rig_oarfish.py), run this in the command bar (Edit mode). It turns the
    import into ReplicatedStorage.EuropaOarfish for OarfishController:
    - the six MeshParts (OarfishIce .. OarfishEye) and the RootPart holding bones B00-B16;
    - anchored decor, coloured from the GLB's materials (Studio's importer drops flat
      material colours), the photophores Neon, the fin membrane a little see-through;
    - upright: the dorsal fin above the body, nose toward -X.
    Then save it as src/ReplicatedStorage/EuropaOarfish.rbxm (SerializationService,
    written out over a local HTTP receiver, as PetModels.rbxm was).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The GLB's base colours (linear) in sRGB, and how each part draws.
local LOOKS = {
    OarfishIce = { color = Color3.fromRGB(183, 217, 224), material = Enum.Material.SmoothPlastic, reflectance = 0.08 },
    OarfishMembrane = { color = Color3.fromRGB(120, 97, 170), material = Enum.Material.SmoothPlastic, transparency = 0.12 },
    OarfishCrest = { color = Color3.fromRGB(71, 174, 183), material = Enum.Material.SmoothPlastic },
    OarfishTeal = { color = Color3.fromRGB(38, 90, 104), material = Enum.Material.SmoothPlastic },
    OarfishPhoto = { color = Color3.fromRGB(59, 237, 255), material = Enum.Material.Neon },
    OarfishEye = { color = Color3.fromRGB(15, 28, 38), material = Enum.Material.SmoothPlastic, reflectance = 0.3 },
}

local import
for _, item in workspace:GetDescendants() do
    if item:IsA("MeshPart") and item.Name == "OarfishIce" then
        import = item:FindFirstAncestorOfClass("Model")
        while import and import.Parent ~= workspace and import.Parent:IsA("Model") do import = import.Parent end
        break
    end
end
assert(import, "Import Europa_Oarfish_Rig.fbx first (File > Import 3D)")

local model = Instance.new("Model")
model.Name = "EuropaOarfish"
local bones, root = 0, nil
for _, item in import:GetDescendants() do
    if item:IsA("Bone") then bones += 1 end
    if item:IsA("BasePart") and item:FindFirstChildWhichIsA("Bone", true) and not item:IsA("MeshPart") then root = item end
end
assert(bones >= 17, "expected bones B00-B16, found " .. bones)
for _, part in import:GetDescendants() do
    if part:IsA("BasePart") then
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = true, false, false, false, true
        local look = LOOKS[part.Name]
        if look then
            part.Color, part.Material = look.color, look.material
            part.Reflectance, part.Transparency = look.reflectance or 0, look.transparency or 0
            part.CastShadow = true
            for _, child in part:GetChildren() do
                if child:IsA("SurfaceAppearance") then child:Destroy() end
            end
        elseif part == root then
            part.Transparency, part.CastShadow = 1, false
        end
    end
end
for _, child in import:GetChildren() do
    -- The importer's bind poses and animation controller: nothing plays clips here.
    if child.Name == "InitialPoses" or child:IsA("AnimationController") then child:Destroy() else child.Parent = model end
end
import:Destroy()

-- The importer reads the FBX at 100 studs a metre and shrinks any mesh past the
-- 2048-stud part limit without its bones, which scatters the skinned mesh. The rig is
-- exported small enough (1,280 studs) that this doesn't happen: check it didn't.
do
    local first, last = model:FindFirstChild("B00", true), model:FindFirstChild("B16", true)
    local ratio = model:FindFirstChild("OarfishIce", true).Size.X / math.abs(first.WorldPosition.X - last.WorldPosition.X)
    assert(ratio > 0.97 and ratio < 1.03, ("meshes and bones disagree in size (x%.3f): re-export smaller (rig_oarfish.py SCALE)"):format(ratio))
end

-- The pivot: at the nose, looking where the nose points, up through the dorsal fin.
-- OarfishController takes "up" from it; the stored copy sits nose -Z, fin +Y.
local head = model:FindFirstChild("B00", true).WorldPosition
local tail = model:FindFirstChild("B16", true).WorldPosition
local along = (tail - head).Unit
local dorsal = model:FindFirstChild("OarfishMembrane", true).Position - model:FindFirstChild("OarfishIce", true).Position
dorsal = (dorsal - along * dorsal:Dot(along)).Unit
model.WorldPivot = CFrame.lookAt(head, head - along, dorsal)
model:PivotTo(CFrame.new(0, 100, 0))
model.Parent = ReplicatedStorage
print(("EuropaOarfish ready: %d bones, %.1f studs nose to tail, root %s"):format(bones, (tail - head).Magnitude, root and root.Name or "none"))
