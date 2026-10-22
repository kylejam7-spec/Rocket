--[[
    After File > Import 3D of assets/models-textures/Monster/import/SaturnUFO_Rig.fbx
    (tools/monster/rig_ufo.py), run this in the command bar (Edit mode). It turns the
    import into ReplicatedStorage.SaturnUFO for UfoController:
    - the nine MeshParts (UFOTitanium .. UFOCoral) and the part holding the 18 bones
      (Root > Hull > Pilot1_Torso / Pilot2_Torso > heads, arms, forearms, hands);
    - anchored decor, coloured from SaturnUFO_Color.png's swatches (as flat colours, with
      no texture): the running lights, ion ring and buttons Neon, the canopy glass;
    - the canopy and the pilots drawn at full detail at any distance, the hull and trim
      double-sided;
    - the pivot at the saucer's centre (the Root bone), looking the way the pilots face, up
      through the canopy.
    Then save it as src/ReplicatedStorage/SaturnUFO.rbxm (SerializationService, written out
    over a local HTTP receiver, as EuropaOarfish.rbxm was).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- SaturnUFO_Color.png's swatches (the texture every material samples), and how each part draws.
local LOOKS = {
    UFOTitanium = { color = Color3.fromRGB(107, 125, 153), material = Enum.Material.Metal, reflectance = 0.1 },
    UFOGraphite = { color = Color3.fromRGB(24, 30, 38), material = Enum.Material.Metal },
    UFOIon = { color = Color3.fromRGB(8, 204, 255), material = Enum.Material.Neon },
    UFOAmber = { color = Color3.fromRGB(255, 140, 10), material = Enum.Material.Neon },
    UFOCoral = { color = Color3.fromRGB(242, 18, 6), material = Enum.Material.Neon },
    UFOJade = { color = Color3.fromRGB(20, 166, 41), material = Enum.Material.SmoothPlastic },
    UFOHighlight = { color = Color3.fromRGB(56, 204, 66), material = Enum.Material.SmoothPlastic },
    UFOEyes = { color = Color3.fromRGB(4, 6, 10), material = Enum.Material.SmoothPlastic, reflectance = 0.4 },
    UFOGlass = { color = Color3.fromRGB(190, 235, 255), material = Enum.Material.Glass, transparency = 0.6 },
}

local PRECISE = { UFOGlass = true, UFOJade = true, UFOEyes = true, UFOHighlight = true }

local import
for _, item in workspace:GetDescendants() do
    if item:IsA("MeshPart") and item.Name == "UFOTitanium" then
        import = item:FindFirstAncestorOfClass("Model")
        while import and import.Parent ~= workspace and import.Parent:IsA("Model") do import = import.Parent end
        break
    end
end
assert(import, "Import SaturnUFO_Rig.fbx first (File > Import 3D)")

local model = Instance.new("Model")
model.Name = "SaturnUFO"
local bones, root, missing = {}, nil, {}
for _, item in import:GetDescendants() do
    if item:IsA("Bone") then bones[item.Name] = item end
    if item:IsA("BasePart") and item:FindFirstChildWhichIsA("Bone", true) and not item:IsA("MeshPart") then root = item end
end
for _, name in { "Root", "Hull", "Pilot1_Torso", "Pilot1_Head", "Pilot1_1Hand", "Pilot2_Torso", "Pilot2_Head", "Pilot2_-1Hand" } do
    if not bones[name] then table.insert(missing, name) end
end
assert(#missing == 0, "missing bones: " .. table.concat(missing, ", "))
for name in LOOKS do
    assert(import:FindFirstChild(name, true), "missing mesh " .. name)
end
for _, part in import:GetDescendants() do
    if part:IsA("BasePart") then
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = true, false, false, false, true
        local look = LOOKS[part.Name]
        if look then
            part.Color, part.Material = look.color, look.material
            part.Reflectance, part.Transparency = look.reflectance or 0, look.transparency or 0
            part.CastShadow = part.Name ~= "UFOGlass"
            -- The palette texture holds only these flat colours: drop it, so there's one
            -- upload fewer that the experience needs access to.
            part.TextureID = ""
            for _, child in part:GetChildren() do
                if child:IsA("SurfaceAppearance") then child:Destroy() end
            end
            -- The pilots' heads sit ~6 cm (model metres) under the canopy: drawn simplified
            -- at a distance, the two would cut through each other.
            if PRECISE[part.Name] then part.RenderFidelity = Enum.RenderFidelity.Precise end
            -- The hull and its dark trim are single shells (no thickness): drawn from both
            -- sides, the body reads solid from outside and from inside the canopy.
            if part.Name == "UFOTitanium" or part.Name == "UFOGraphite" then part.DoubleSided = true end
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

-- Meshes and bones must agree in size (the importer shrinks meshes past 2048 studs but
-- not their bones): the hull is 8.24 wide for every 0.85 from the centre to a pilot.
do
    local hull = model:FindFirstChild("UFOTitanium", true).Size
    local spread = (bones.Pilot1_Torso.WorldPosition - bones.Pilot2_Torso.WorldPosition).Magnitude
    local ratio = math.max(hull.X, hull.Z) / spread / (8.24 / 1.7)
    assert(ratio > 0.97 and ratio < 1.03, ("meshes and bones disagree in size (x%.3f)"):format(ratio))
end

-- The pivot: the Root bone, looking where the pilots face (from their torsos toward their
-- hands), up from torso to head. The stored copy sits level, facing -Z.
local torso = (bones.Pilot1_Torso.WorldPosition + bones.Pilot2_Torso.WorldPosition) / 2
local head = (bones.Pilot1_Head.WorldPosition + bones.Pilot2_Head.WorldPosition) / 2
local hands = (bones.Pilot1_1Hand.WorldPosition + bones["Pilot2_-1Hand"].WorldPosition) / 2
local up = (head - torso).Unit
local forward = hands - torso
forward = (forward - up * forward:Dot(up)).Unit
local centre = bones.Root.WorldPosition
model.WorldPivot = CFrame.lookAt(centre, centre + forward, up)
model:PivotTo(CFrame.new(0, 100, 0))
model.Parent = ReplicatedStorage
local count = 0
for _ in bones do count += 1 end
local size = model:GetExtentsSize()
print(("SaturnUFO ready: %d bones, %.0f x %.0f studs, root %s"):format(count, size.X, size.Y, root and root.Name or "none"))
