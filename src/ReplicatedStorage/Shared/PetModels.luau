-- Builds the UFO and pet models (server: shop displays; client: followers, previews).
-- PetModels.ufo(tier) is a small primitive saucer lit in its rarity's colour.
-- PetModels.pet(id) clones ReplicatedStorage.PetModels[id] (the imported Quaternius
-- mesh with its Idle/Move clips, see tools/pets; PetAnimator plays them) fitted to
-- its form's pet size, or builds a primitive stand-in of that form if it's missing.
-- Every model is anchored decor (no collisions, queries or touches) with its pivot
-- at the bottom centre, facing -Z; attribute Height is its height in studs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(script.Parent.Pets)
local PetModels = {}

-- Pet size per form, in studs (a character is ~5 tall): Blob's widest side, Large's
-- height (their bind pose is a T, so width would shrink them), Flying's wingspan.
-- Flyers hover (PetController lifts them).
PetModels.Fit = table.freeze({
    Blob = table.freeze({ measure = "span", size = 2.2 }),
    Large = table.freeze({ measure = "height", size = 3 }),
    Flying = table.freeze({ measure = "span", size = 3 }),
})
-- The pets' shared colour atlases (the FBX files reference them but don't embed
-- them), one per Quaternius pack, as uploaded image ids ("rbxassetid://..."); empty
-- until uploaded (tools/pets/README.md), and the meshes stay untextured grey.
PetModels.Atlases = table.freeze({ Blob = "", Large = "", Flying = "" })
-- Rarity colours (match UI Theme.rarity).
PetModels.RarityColors = table.freeze({
    Common = Color3.fromRGB(170, 180, 200),
    Uncommon = Color3.fromRGB(80, 210, 90),
    Rare = Color3.fromRGB(60, 150, 255),
    Epic = Color3.fromRGB(175, 80, 255),
    Legendary = Color3.fromRGB(255, 170, 30),
})

local function decor(part)
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    return part
end
local function new(model, name, props)
    local part = decor(Instance.new("Part"))
    part.Name = name
    for key, value in props do part[key] = value end
    part.Parent = model
    return part
end
-- A squashable sphere (Ball parts always stay round).
local function blob(model, name, size, cframe, color, material)
    local part = new(model, name, { Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic })
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = part
    return part
end
local function disc(model, name, diameter, thickness, cframe, color, material)
    return new(model, name, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, diameter, diameter),
        CFrame = cframe * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material or Enum.Material.SmoothPlastic })
end

function PetModels.ufo(tier)
    local spec = Pets.Ufos[tier]
    local glow = PetModels.RarityColors[spec.Rarity]
    local model = Instance.new("Model")
    model.Name = "UFO"
    local c = CFrame.new()
    local saucer = disc(model, "Saucer", 4.6, 0.7, c, Color3.fromRGB(190, 198, 212), Enum.Material.Metal)
    disc(model, "Rim", 5.3, 0.3, c, Color3.fromRGB(110, 118, 135), Enum.Material.Metal)
    blob(model, "Belly", Vector3.new(3.4, 1, 3.4), c * CFrame.new(0, -0.35, 0), Color3.fromRGB(150, 158, 175), Enum.Material.Metal)
    blob(model, "Dome", Vector3.new(2.5, 1.9, 2.5), c * CFrame.new(0, 0.45, 0), Color3.fromRGB(150, 235, 255), Enum.Material.Glass).Transparency = 0.45
    -- The pilot: a little green alien with big black eyes.
    local pilot = blob(model, "Pilot", Vector3.new(0.9, 1.1, 0.9), c * CFrame.new(0, 0.75, 0), Color3.fromRGB(120, 230, 110))
    for _, x in { -0.18, 0.18 } do
        blob(model, "PilotEye", Vector3.new(0.25, 0.35, 0.12), pilot.CFrame * CFrame.new(x, 0.12, -0.42), Color3.new(0, 0, 0))
    end
    for index = 1, 8 do
        local angle = index / 8 * math.pi * 2
        new(model, "Light", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42, Material = Enum.Material.Neon, Color = glow,
            CFrame = c * CFrame.new(math.cos(angle) * 2.55, 0, math.sin(angle) * 2.55) })
    end
    local under = disc(model, "Underglow", 2.2, 0.1, c * CFrame.new(0, -0.82, 0), glow, Enum.Material.Neon)
    under.Transparency = 0.2
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = glow, 10, 1.5
    light.Parent = under
    -- The tractor beam, shown while it lands (PetController grows it to the ground).
    local beam = disc(model, "Beam", 2.4, 1, c * CFrame.new(0, -1.3, 0), glow, Enum.Material.Neon)
    beam.Transparency = 1
    -- The model's pivot follows its PrimaryPart's, so undo the saucer's lying-cylinder turn.
    saucer.PivotOffset = saucer.CFrame:Inverse() * c
    model.PrimaryPart = saucer
    model:SetAttribute("Height", 2.4)
    model:SetAttribute("Tier", tier)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then part.CastShadow = false end
    end
    return model
end

-- Stand-in palette: each pet gets a stable colour from its id.
local PALETTE = {
    Color3.fromRGB(120, 230, 110), Color3.fromRGB(255, 130, 190), Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 200, 70),
    Color3.fromRGB(185, 130, 255), Color3.fromRGB(255, 140, 80), Color3.fromRGB(90, 225, 200), Color3.fromRGB(240, 240, 250),
}
local function hash(text)
    local value = 0
    for index = 1, #text do value = (value * 31 + text:byte(index)) % 2147483647 end
    return value
end
local function eyes(model, head, size, spacing, forward)
    for _, side in { -1, 1 } do
        local eye = blob(model, "Eye", Vector3.new(size, size * 1.2, size * 0.5), head * CFrame.new(side * spacing, 0, -forward), Color3.new(1, 1, 1))
        blob(model, "Pupil", Vector3.new(size * 0.55, size * 0.7, size * 0.3), eye.CFrame * CFrame.new(0, -size * 0.05, -size * 0.18), Color3.fromRGB(20, 16, 30))
    end
end
local function antennae(model, top, color, glow)
    for _, side in { -1, 1 } do
        local stalk = new(model, "Antenna", { Size = Vector3.new(0.12, 0.9, 0.12), Color = color,
            CFrame = top * CFrame.Angles(0, 0, side * -0.35) * CFrame.new(0, 0.45, 0) })
        new(model, "AntennaTip", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.32, Color = glow, Material = Enum.Material.Neon,
            CFrame = stalk.CFrame * CFrame.new(0, 0.5, 0) })
    end
end

local function standIn(entry)
    local model = Instance.new("Model")
    local seed = hash(entry.Id)
    local color = PALETTE[seed % #PALETTE + 1]
    local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
    local glow = PetModels.RarityColors[entry.Rarity]
    if entry.Form == "Blob" then
        local body = blob(model, "Body", Vector3.new(2.6, 2.2, 2.4), CFrame.new(0, 1.1, 0), color)
        eyes(model, body.CFrame * CFrame.new(0, 0.25, 0), 0.55, 0.45, 1.05)
        antennae(model, body.CFrame * CFrame.new(0, 1, 0), dark, glow)
    elseif entry.Form == "Large" then
        for _, side in { -1, 1 } do
            blob(model, "Foot", Vector3.new(0.9, 0.6, 1.2), CFrame.new(side * 0.6, 0.3, -0.1), dark)
            blob(model, "Arm", Vector3.new(0.6, 1.4, 0.6), CFrame.new(side * 1.25, 1.7, 0) * CFrame.Angles(0, 0, side * 0.35), dark)
        end
        local body = blob(model, "Body", Vector3.new(2.3, 2.4, 2), CFrame.new(0, 1.7, 0), color)
        local head = blob(model, "Head", Vector3.new(2.1, 1.8, 1.9), CFrame.new(0, 3.05, -0.05), color)
        blob(model, "Belly", Vector3.new(1.5, 1.6, 0.4), body.CFrame * CFrame.new(0, -0.1, -0.85), color:Lerp(Color3.new(1, 1, 1), 0.45))
        eyes(model, head.CFrame * CFrame.new(0, 0.1, 0), 0.5, 0.42, 0.85)
        antennae(model, head.CFrame * CFrame.new(0, 0.8, 0), dark, glow)
    else
        local body = blob(model, "Body", Vector3.new(2, 1.9, 2.1), CFrame.new(0, 1.3, 0), color)
        eyes(model, body.CFrame * CFrame.new(0, 0.2, 0), 0.5, 0.4, 0.92)
        blob(model, "Tail", Vector3.new(0.6, 0.6, 1.2), body.CFrame * CFrame.new(0, -0.3, 1.1), dark)
        -- WingL / WingR flap around their inner edge (PetController).
        for _, side in { -1, 1 } do
            new(model, side < 0 and "WingL" or "WingR", { Size = Vector3.new(2, 0.15, 1.3), Color = dark,
                CFrame = body.CFrame * CFrame.new(side * 1.85, 0.3, 0.1) })
        end
    end
    -- Epic and Legendary stand-ins sparkle in their rarity's colour.
    if entry.Rank >= 4 then
        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Color = ColorSequence.new(glow)
        sparkles.LightEmission, sparkles.Rate, sparkles.Lifetime = 1, 6, NumberRange.new(0.6, 1.1)
        sparkles.Size = NumberSequence.new(0.25, 0)
        sparkles.Speed, sparkles.SpreadAngle = NumberRange.new(1, 2), Vector2.new(180, 180)
        sparkles.Parent = model:FindFirstChild("Body")
    end
    return model
end

-- World-aligned bounds of the visible parts (imported multi-mesh rigs carry an
-- invisible RootPart that holds the bones).
function PetModels.bounds(model)
    local low, high
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") and part.Transparency < 1 then
            -- Half extents of the (possibly turned) part along the world axes.
            local extent = Vector3.zero
            for _, axis in { part.CFrame.RightVector * part.Size.X, part.CFrame.UpVector * part.Size.Y, part.CFrame.LookVector * part.Size.Z } do
                extent += Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) / 2
            end
            local a, b = part.Position - extent, part.Position + extent
            low = low and low:Min(a) or a
            high = high and high:Max(b) or b
        end
    end
    if not low then return CFrame.new(), Vector3.zero end
    return CFrame.new((low + high) / 2), high - low
end

-- Scales `model` to its form's pet size and puts its pivot at its feet, upright.
local function fit(model, form)
    local spec = PetModels.Fit[form]
    model.WorldPivot = CFrame.new(model:GetPivot().Position)
    local box, size = PetModels.bounds(model)
    local measure = spec.measure == "height" and size.Y or math.max(size.X, size.Y, size.Z)
    if measure <= 0 then return false end
    model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
    model:ScaleTo(model:GetScale() * spec.size / measure)
    return true
end

-- The imported mesh as anchored decor, textured with its pack's atlas.
local function imported(source, form)
    if not source:IsA("Model") then return nil end
    local model = source:Clone()
    local atlas = PetModels.Atlases[form]
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then decor(part); part.Massless = true end
        if part:IsA("MeshPart") and atlas ~= "" then part.TextureID = atlas end
        if part:IsA("Humanoid") or part:IsA("AnimationController") or part:IsA("LuaSourceContainer") then part:Destroy() end
    end
    return fit(model, form) and model or nil
end

function PetModels.pet(id)
    local entry = assert(Pets.get(id), "PetModels: unknown pet " .. tostring(id))
    local folder = ReplicatedStorage:FindFirstChild("PetModels")
    local source = folder and folder:FindFirstChild(id)
    local model = source and imported(source, entry.Form)
    local real = model ~= nil
    if not model then
        model = standIn(entry)
        model.WorldPivot = CFrame.new()
        fit(model, entry.Form)
    end
    model.Name = id
    local _, size = PetModels.bounds(model)
    model:SetAttribute("Height", size.Y)
    model:SetAttribute("Imported", real)
    return model
end

return PetModels
