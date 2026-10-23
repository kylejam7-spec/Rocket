--[[
    After File > Import 3D of assets/models-textures/Suits/import/SuitArmor.fbx
    (tools/suits/build_suits.py --fbx), run this in the command bar (Edit mode). It turns
    the import into ReplicatedStorage.SuitModels for SkinService: one MeshPart per piece,
    named after it, with attributes BodyPart (the R15 part it's welded to), Role (what
    colours it: Shared/Skins) and Offset (its CFrame relative to that body part at rest).

    The importer's scale and axes are read from the four markers the FBX carries
    (Mark_Origin at the HumanoidRootPart, Mark_Up 10 studs up, Mark_Right 10 studs right,
    Mark_Front 10 studs forward), so they don't have to be guessed; a mirrored import is
    refused. Then save it as src/ReplicatedStorage/SuitModels.rbxm (SerializationService).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The default R15 blocky body's rest positions (HumanoidRootPart space), as in build_suits.py.
local REST = {
    Head = Vector3.new(0, 1.674, 0), UpperTorso = Vector3.new(0, 0.249, 0), LowerTorso = Vector3.new(0, -0.8, 0),
    LeftUpperArm = Vector3.new(-1.472, 0.428, 0), RightUpperArm = Vector3.new(1.472, 0.428, 0),
    LeftLowerArm = Vector3.new(-1.472, -0.202, 0), RightLowerArm = Vector3.new(1.472, -0.202, 0),
    LeftHand = Vector3.new(-1.472, -0.866, 0), RightHand = Vector3.new(1.472, -0.866, 0),
    LeftUpperLeg = Vector3.new(-0.5, -1.471, 0), RightUpperLeg = Vector3.new(0.5, -1.471, 0),
    LeftLowerLeg = Vector3.new(-0.5, -2.334, 0), RightLowerLeg = Vector3.new(0.5, -2.334, 0),
    LeftFoot = Vector3.new(-0.5, -3.036, 0), RightFoot = Vector3.new(0.5, -3.036, 0),
}

local marks, pieces, import = {}, {}, nil
for _, item in workspace:GetDescendants() do
    if item:IsA("MeshPart") then
        local mark = item.Name:match("^Mark_(%a+)")
        if mark then
            marks[mark] = item.Position
            import = import or item:FindFirstAncestorOfClass("Model")
        elseif item.Name:match("^[%w_]+__%a+__%a+$") then
            table.insert(pieces, item)
        end
    end
end
assert(marks.Origin and marks.Up and marks.Right and marks.Front, "Import SuitArmor.fbx first (no markers found)")
local scale = (marks.Up - marks.Origin).Magnitude / 10
local x = (marks.Right - marks.Origin).Unit
local y = (marks.Up - marks.Origin).Unit
local z = (marks.Origin - marks.Front).Unit
assert(x:Cross(y):Dot(z) > 0.99, "The import is mirrored or skewed: check the FBX axes")
local frame = CFrame.fromMatrix(marks.Origin, x, y, z)

local out = ReplicatedStorage:FindFirstChild("SuitModels")
if out then out:Destroy() end
out = Instance.new("Folder")
out.Name = "SuitModels"
for _, part in pieces do
    local name, body, role = part.Name:match("^([%w_]+)__(%a+)__(%a+)$")
    assert(REST[body], part.Name .. ": unknown body part")
    local here = frame:ToObjectSpace(part.CFrame)
    local at = CFrame.new(here.Position / scale) * here.Rotation
    local copy = part:Clone()
    for _, child in copy:GetChildren() do child:Destroy() end
    copy.Name = name
    copy.Size = part.Size / scale
    copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.Massless = true, false, false, false, true
    copy.CFrame = at
    copy:SetAttribute("BodyPart", body)
    copy:SetAttribute("Role", role)
    copy:SetAttribute("Offset", CFrame.new(REST[body]):ToObjectSpace(at))
    copy.Parent = out
end
out.Parent = ReplicatedStorage
if import then import:Destroy() end
print(("SuitModels: %d pieces, import scale %.3f"):format(#out:GetChildren(), scale))
