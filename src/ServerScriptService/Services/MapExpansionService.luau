-- Map space grows every three cycles; rocket construction remains separate.
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
function Map.build(part, label, reserved)
    local grass = Color3.fromRGB(62, 103, 72)
    local concrete = Color3.fromRGB(81, 91, 107)
    local paint = Color3.fromRGB(245, 182, 71)
    -- Builds a centre/size slab as carved pieces; returns the largest.
    local function slab(name, center, size, color)
        local largest, area = nil, 0
        local rect = { x0 = center.X - size.X / 2, x1 = center.X + size.X / 2, z0 = center.Z - size.Z / 2, z1 = center.Z + size.Z / 2 }
        for _, r in carve(rect, reserved or {}) do
            local piece = part(name, Vector3.new((r.x0 + r.x1) / 2, center.Y, (r.z0 + r.z1) / 2),
                Vector3.new(r.x1 - r.x0, size.Y, r.z1 - r.z0), color)
            if (r.x1 - r.x0) * (r.z1 - r.z0) > area then largest, area = piece, (r.x1 - r.x0) * (r.z1 - r.z0) end
        end
        return largest
    end
    -- Ground and apron run out to z = -340 under the tilted rockets, which lean toward -Z
    -- (the scaled Tier 5 nose reaches about z = -290). Behind spawn the ground reaches
    -- z = 160 to hold the material stations, which are carved out of it.
    slab("Ground", Vector3.new(0, -1, -90), Vector3.new(240, 2, 500), grass)
    part("LaunchApron", Vector3.new(0, -0.17, -195), Vector3.new(160, 0.5, 270), concrete)
    -- Permanent pad sized for the scaled Tier 5 rocket (mount 83x57 + climbing ramps out to
    -- x = +/-53 on both flanks); its top surface (y = 0.58) is the origin every tier is built from.
    part("LaunchPad", Vector3.new(0, 0.33, -112), Vector3.new(112, 0.5, 88), Color3.fromRGB(96, 104, 118))
    -- Sits between spawn and the apron, clear of the gym rows on either side.
    local sign = part("ExpansionSign", Vector3.new(0, 0.1, -54), Vector3.new(12, 0.2, 4), paint)
    label(sign, "SPACEPORT")
    -- Flat markings leave the cabin entrance and future boosters unobstructed.
    for _, z in {-330, -60} do
        part("ApronMarking", Vector3.new(0, 0.10, z), Vector3.new(160, 0.04, 1), paint).CanCollide = false
    end
    local stage = 0
    return function(cycle)
        local target = math.floor((cycle - 1) / 3)
        for index = stage + 1, target do
            for _, side in {-1, 1} do
                slab("ExpansionGround" .. index .. "_" .. side,
                    Vector3.new(side * (80 + index * 80), -1, -90), Vector3.new(80, 2, 500), grass)
                local x = side * (40 + index * 80)
                local bay = slab("ConstructionBay" .. index .. "_" .. side,
                    Vector3.new(x, -0.17, -195), Vector3.new(80, 0.5, 270), concrete)
                if bay then label(bay, "EXPANSION " .. index) end
                for _, z in {-330, -60} do
                    local marking = slab("BayMarking", Vector3.new(x, 0.10, z), Vector3.new(80, 0.04, 1), paint)
                    if marking then marking.CanCollide = false end
                end
            end
            if index % 10 == 0 then task.wait() end
        end
        stage = math.max(stage, target)
    end
end
Map.carve = carve
return Map
