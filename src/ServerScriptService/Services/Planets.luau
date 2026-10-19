--[[
    Planet dressing for the destinations: textured globes for their skies, and the relief
    that keeps a destination's ground from reading as a flat disc.

    Textures come from tools/planets/textures.py (the SBS planet pack, CC0, plus overlays
    made there). Planets.texture(key) gives one's content id; with LocalPreview on it gives
    the copy that `textures.py --studio` puts in Studio's content folder instead, to look at
    changes before an upload is allowed to load.

    Planets.globe(parent, name, spec) -> Model: a UV sphere MeshPart (SphereMesh, its UVs
    equirectangular, the pole on +Y; tools/planets/sphere.py) wearing spec.texture, and an
    optional atmosphere: a ForceField ball a little bigger, which Roblox draws as a glowing
    fresnel rim, so the planet's limb shines like air. Clouds are baked into a texture
    (MeshPart textures ignore alpha, so a cloud shell would be an opaque ball). The surface
    is tagged PlanetSpin with a SpinRate (radians a second); PlanetController turns it on
    each client. Without the mesh (it failed to load) the planet is a plain ball of
    spec.color.

    Relief, all deterministic from the caller's Random so every server builds the same:
    - Planets.carve(ground, bowls, walkable) cuts real bowl craters, each with an optional
      raised rim, into a ground part (CSG), so players walk down into them (walkable:
      precise collision; otherwise a box, for scenery). Returns the carved part (or the
      ground, unchanged, if CSG fails).
    - Planets.mound(...) is a ball sunk until only a low cap shows: a smooth hill.
      Planets.boulder heaps a few balls into a rounded rock.
    - Planets.overlay(part, face, key, studs) lays a tiling texture over one face.
]]
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local GeometryService = game:GetService("GeometryService")
local Planets = {}

Planets.SpinTag = "PlanetSpin"
Planets.LocalPreview = false
Planets.SphereMesh = "rbxassetid://101153315842104"
local TEXTURES = {
    Earth = { id = 98936869274892, file = "earth" },
    MoonRegolith = { id = 95330664069444, file = "moon_regolith" },
    MoonMaria = { id = 131900343409098, file = "moon_maria" },
}

function Planets.texture(key)
    local texture = TEXTURES[key]
    if Planets.LocalPreview then return "rbxasset://textures/rocket-planets/" .. texture.file .. ".png" end
    return "rbxassetid://" .. texture.id
end

local function part(parent, name, props)
    local item = Instance.new(props.ClassName or "Part")
    item.Name = name
    item.Anchored = true
    item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for key, value in props do
        if key ~= "ClassName" then item[key] = value end
    end
    item.Parent = parent
    return item
end
local function decor(item)
    item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = false, false, false, false
    return item
end

-- One sphere MeshPart, made once and cloned (MeshId can't be set from a script).
local sphere
local function sphereTemplate()
    if sphere == nil then
        local ok, made = pcall(function()
            return AssetService:CreateMeshPartAsync(Content.fromUri(Planets.SphereMesh))
        end)
        if not ok then warn("Planets: sphere mesh failed to load, globes fall back to balls: " .. tostring(made)) end
        sphere = ok and made or false
    end
    return sphere or nil
end

local function shell(parent, name, center, diameter, props)
    local template = sphereTemplate()
    local item
    if template then
        item = template:Clone()
        item.Name = name
        item.Anchored = true
        item.Size = Vector3.one * diameter
        item.CFrame = center
        for key, value in props do item[key] = value end
        item.Parent = parent
    else
        props = table.clone(props)
        props.TextureID = nil
        props.Shape, props.Size, props.CFrame = Enum.PartType.Ball, Vector3.one * diameter, center
        item = part(parent, name, props)
    end
    return decor(item)
end

-- spec = { center = Vector3, diameter, texture = key, color = Color3 (tint, and the
-- fallback), tilt = degrees (axial tilt), spin = rad/s, atmosphere = Color3?,
-- glow = 0..1 (atmosphere transparency) }
function Planets.globe(parent, name, spec)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent
    local frame = CFrame.new(spec.center) * CFrame.Angles(0, 0, math.rad(spec.tilt or 0))
    local surface = shell(model, "Surface", frame, spec.diameter, { Color = spec.color or Color3.new(1, 1, 1), TextureID = Planets.texture(spec.texture) })
    surface:SetAttribute("SpinRate", spec.spin or 0.02)
    CollectionService:AddTag(surface, Planets.SpinTag)
    if spec.atmosphere then
        part(model, "Atmosphere", { Shape = Enum.PartType.Ball, Size = Vector3.one * spec.diameter * 1.06, CFrame = frame,
            Color = spec.atmosphere, Material = Enum.Material.ForceField, Transparency = spec.glow or 0 })
        decor(model.Atmosphere)
    end
    model.PrimaryPart = surface
    return model
end

-- Bowls: { { at = Vector3 (on the ground's top), radius, depth, rim = height? } }. Each is a ball whose
-- cap below the surface is the bowl. With `rim` (a height) the bowl first gets a raised
-- lip: a low mound half again as wide is merged into the ground, and the bowl is cut
-- through it, so the crest is one continuous ring.
local function ball(center, diameter)
    local item = Instance.new("Part")
    item.Shape = Enum.PartType.Ball
    item.Size = Vector3.one * diameter
    item.CFrame = CFrame.new(center)
    item.Anchored = true
    return item
end
function Planets.carve(ground, bowls, walkable)
    local options = {
        CollisionFidelity = walkable and Enum.CollisionFidelity.PreciseConvexDecomposition or Enum.CollisionFidelity.Box,
        RenderFidelity = Enum.RenderFidelity.Precise,
        SplitApart = false,
    }
    local lips, cutters, tallest = {}, {}, 0
    for _, bowl in bowls do
        if bowl.rim then
            local reach = bowl.radius * 1.5
            local diameter = reach * reach / bowl.rim + bowl.rim
            table.insert(lips, ball(bowl.at + Vector3.new(0, bowl.rim - diameter / 2, 0), diameter))
            tallest = math.max(tallest, bowl.rim)
        end
        local r = (bowl.radius * bowl.radius + bowl.depth * bowl.depth) / (2 * bowl.depth)
        table.insert(cutters, ball(bowl.at + Vector3.new(0, r - bowl.depth, 0), r * 2))
    end
    -- The lips are big sunk balls; clip them to the disc (taller by the highest rim) so
    -- nothing of them shows under or beside it. The ground is a disc as disc() lays it:
    -- a cylinder on its side, its X axis up.
    local envelope = ground:Clone()
    envelope.Size += Vector3.new(tallest * 2 + 1, 0, 0)
    envelope.CFrame += Vector3.new(0, tallest + 0.5, 0)
    local temporary = {}
    local ok, result = pcall(function()
        local base = ground
        if #lips > 0 then
            -- Box collision until the last cut: decomposing every intermediate step for
            -- precise collision took 12 s on the Moon's platform.
            local rough = table.clone(options)
            rough.CollisionFidelity = Enum.CollisionFidelity.Box
            local merged = GeometryService:UnionAsync(ground, lips, rough)[1]
            base = GeometryService:IntersectAsync(merged, { envelope }, rough)[1]
            table.insert(temporary, merged)
            table.insert(temporary, base)
        end
        return GeometryService:SubtractAsync(base, cutters, options)
    end)
    for _, list in { lips, cutters, temporary, { envelope } } do
        for _, item in list do item:Destroy() end
    end
    if not ok or not result or not result[1] then
        warn("Planets: carving craters failed, ground stays flat: " .. tostring(result))
        return ground
    end
    local carved = result[1]
    carved.Name = ground.Name
    carved.Anchored = true
    carved.UsePartColor = true
    carved.Color, carved.Material = ground.Color, ground.Material
    carved.CanCollide, carved.CanQuery, carved.CanTouch = ground.CanCollide, ground.CanQuery, ground.CanTouch
    for key, value in ground:GetAttributes() do carved:SetAttribute(key, value) end
    carved.Parent = ground.Parent
    ground:Destroy()
    return carved
end

-- A ball sunk so a cap `height` tall and `radius` wide at its base shows above `at.Y`.
function Planets.mound(parent, name, at, radius, height, color, material, collide)
    local diameter = radius * radius / height + height
    local item = part(parent, name, { Shape = Enum.PartType.Ball, Size = Vector3.one * diameter,
        CFrame = CFrame.new(at + Vector3.new(0, height - diameter / 2, 0)), Color = color, Material = material or Enum.Material.Slate })
    if not collide then decor(item) item.CastShadow = true end
    return item
end

-- A rounded rock: two to four balls heaped together, half buried.
function Planets.boulder(parent, at, size, color, material, random, collide)
    for index = 1, random:NextInteger(2, 4) do
        local s = size * (index == 1 and 1 or random:NextNumber(0.45, 0.75))
        local offset = index == 1 and Vector3.zero or Vector3.new(random:NextNumber(-0.45, 0.45), 0, random:NextNumber(-0.45, 0.45)) * size
        local item = part(parent, "Boulder", { Shape = Enum.PartType.Ball, Size = Vector3.one * s,
            CFrame = CFrame.new(at + offset + Vector3.new(0, s * random:NextNumber(0.1, 0.25), 0)),
            Color = color:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.15)), Material = material or Enum.Material.Slate })
        if not collide then decor(item) item.CastShadow = true end
    end
end

function Planets.overlay(target, face, key, studs, transparency)
    local texture = Instance.new("Texture")
    texture.Name = key
    texture.Face = face
    texture.Texture = Planets.texture(key)
    texture.StudsPerTileU, texture.StudsPerTileV = studs, studs
    texture.Transparency = transparency or 0
    texture.Parent = target
    return texture
end

return Planets
