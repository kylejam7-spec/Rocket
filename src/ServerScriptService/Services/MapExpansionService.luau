-- The Earth site's ground, apron and pad, and the space that grows every three cycles;
-- rocket construction remains separate.
local Map = {}

-- Splits an x/z rectangle into the pieces left after cutting out each hole.
local function carve(rect, holes)
    local pieces = { rect }
    for _, hole in holes do
        local remaining = {}
        for _, r in pieces do
            if hole.x0 >= r.x1 or hole.x1 <= r.x0 or hole.z0 >= r.z1 or hole.z1 <= r.z0 then
                table.insert(remaining, r)
            else
                local mx0, mx1 = math.max(r.x0, hole.x0), math.min(r.x1, hole.x1)
                for _, piece in {
                    { x0 = r.x0, x1 = mx0, z0 = r.z0, z1 = r.z1 },
                    { x0 = mx1, x1 = r.x1, z0 = r.z0, z1 = r.z1 },
                    { x0 = mx0, x1 = mx1, z0 = r.z0, z1 = math.max(r.z0, hole.z0) },
                    { x0 = mx0, x1 = mx1, z0 = math.min(r.z1, hole.z1), z1 = r.z1 },
                } do
                    if piece.x1 - piece.x0 > 0.01 and piece.z1 - piece.z0 > 0.01 then table.insert(remaining, piece) end
                end
            end
        end
        pieces = remaining
    end
    return pieces
end

-- `reserved` lists x/z footprints (the material stations) that expansion must not cover.
-- Sizes and positions come from SiteLayout.
-- Surfaces: a tiling overlay for the close-up detail and a big tinted blotch layer
-- (the Moon's maria texture) so the tiling never reads as a grid from afar.
local Planets = require(script.Parent.Planets)
local function dirt(piece)
    Planets.overlay(piece, Enum.NormalId.Top, "SiteDirt", 36, 0.1)
    Planets.overlay(piece, Enum.NormalId.Top, "MoonMaria", 420, 0.35, Color3.fromRGB(110, 78, 52))
end
local function concrete(piece, studs)
    Planets.overlay(piece, Enum.NormalId.Top, "Concrete", studs or 24, 0.15)
    Planets.overlay(piece, Enum.NormalId.Top, "MoonMaria", 360, 0.55, Color3.fromRGB(70, 66, 60))
end
Map.dirt, Map.concrete = dirt, concrete

function Map.build(part, label, reserved)
    local Layout = require(script.Parent.SiteLayout)
    local dirt = Color3.fromRGB(150, 122, 92)
    local concrete = Color3.fromRGB(118, 120, 124)
    -- Builds a centre/size slab as carved pieces; returns the largest.
    local function slab(name, center, size, color, material)
        local largest, area = nil, 0
        local rect = { x0 = center.X - size.X / 2, x1 = center.X + size.X / 2, z0 = center.Z - size.Z / 2, z1 = center.Z + size.Z / 2 }
        for _, r in carve(rect, reserved or {}) do
            local piece = part(name, Vector3.new((r.x0 + r.x1) / 2, center.Y, (r.z0 + r.z1) / 2),
                Vector3.new(r.x1 - r.x0, size.Y, r.z1 - r.z0), color)
            if material then piece.Material = material end
            if material == Enum.Material.Ground then Map.dirt(piece) elseif material == Enum.Material.Concrete then Map.concrete(piece) end
            if (r.x1 - r.x0) * (r.z1 - r.z0) > area then largest, area = piece, (r.x1 - r.x0) * (r.z1 - r.z0) end
        end
        return largest
    end
    -- Packed construction dirt from the far end of the apron to the Gym District, with
    -- the material stations carved out of it (they bring their own floors).
    local ground = Layout.Ground
    local length = ground.z1 - ground.z0
    slab("Ground", Vector3.new(0, -1, (ground.z0 + ground.z1) / 2), Vector3.new(ground.x * 2, 2, length), dirt, Enum.Material.Ground)
    local apron = Layout.Apron
    local apronPart = part("LaunchApron", Vector3.new(0, -0.17, (apron.z0 + apron.z1) / 2), Vector3.new(apron.x * 2, 0.5, apron.z1 - apron.z0), concrete)
    apronPart.Material = Enum.Material.Concrete
    Map.concrete(apronPart, 30)
    -- Permanent pad sized for the scaled Tier 5 complex (mount and both ramps); its top
    -- surface (y = 0.58) is the origin every tier is built from.
    local pad = part("LaunchPad", Layout.Pad.center, Layout.Pad.size, Color3.fromRGB(96, 104, 118))
    pad.Material = Enum.Material.Concrete
    Map.concrete(pad, 20)
    -- Each expansion adds a strip of ground outside the base on both sides, and a
    -- concrete construction bay alongside the apron. Returns the ground's half-width.
    local stage = 0
    return function(cycle)
        local target = math.floor((cycle - 1) / 3)
        for index = stage + 1, target do
            for _, side in {-1, 1} do
                slab("ExpansionGround" .. index .. "_" .. side,
                    Vector3.new(side * (ground.x + 40 + (index - 1) * 80), -1, (ground.z0 + ground.z1) / 2), Vector3.new(80, 2, length), dirt, Enum.Material.Ground)
                local x = side * (apron.x + 40 + (index - 1) * 80)
                local bay = slab("ConstructionBay" .. index .. "_" .. side,
                    Vector3.new(x, -0.17, (apron.z0 + apron.z1) / 2), Vector3.new(80, 0.5, apron.z1 - apron.z0), concrete, Enum.Material.Concrete)
                if bay then label(bay, "EXPANSION " .. index) end
            end
            if index % 10 == 0 then task.wait() end
        end
        stage = math.max(stage, target)
        return ground.x + stage * 80
    end
end
Map.carve = carve
return Map
