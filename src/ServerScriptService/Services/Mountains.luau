--[[
    Low-poly mountain rings that close off a playable area's horizon (Earth's site, every
    destination), so nobody sees where its ground ends, even from the top of a jump.

    A mountain is one or two cubes stood on a corner and sunk into the ground, so their
    faces read as a faceted peak; the biggest can carry a snow cap (a smaller cube at the
    top corner, standing a little proud: flush, the two flicker through each other from
    afar). A peak rises about 0.48 x its size; its base at ground level is about 0.6 x its
    size in radius.

    Mountains.ring(parent, center, spec, make) builds one: spec = { radius, spread, count,
    size = { min, max }, rock = Color3, rockAlt = Color3?, material?, snow = size above
    which peaks get caps (nil: none), seed }. It places `count` mountains evenly round the
    circle (jittered) at radius +- spread/2. `make(parent, name, size, cframe, color,
    material)` creates one part (each caller's own builder, so collision etc. match).
]]
local Mountains = {}

-- Turns a cube's (1, 1, 1) corner straight up.
local CORNER = CFrame.fromAxisAngle(Vector3.new(-1, 0, 1).Unit, math.acos(1 / math.sqrt(3)))
Mountains.Rise = 0.476
Mountains.Base = 0.6

function Mountains.peak(parent, at, size, random, spec, make)
    local rock = spec.rock:Lerp(spec.rockAlt or spec.rock, random:NextNumber())
    for index = 1, random:NextInteger(1, 2) do
        local s = size * (index == 1 and 1 or random:NextNumber(0.5, 0.75))
        local offset = index == 1 and Vector3.zero or Vector3.new(random:NextNumber(-0.35, 0.35) * size, 0, random:NextNumber(-0.35, 0.35) * size)
        local peak = CFrame.new(at + offset + Vector3.new(0, -s * math.sqrt(3) / 2 * 0.45, 0)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0) * CORNER
        make(parent, "Mountain", Vector3.one * s, peak, rock, spec.material or Enum.Material.Rock)
        if index == 1 and spec.snow and size > spec.snow then
            local cap = s * 0.3
            make(parent, "SnowCap", Vector3.one * cap, peak * CFrame.new(Vector3.one * ((s - cap) / 2 + s * 0.012)), Color3.fromRGB(236, 236, 248), Enum.Material.Snow)
        end
    end
end

function Mountains.ring(parent, center, spec, make)
    local random = Random.new(spec.seed or 1)
    local folder = Instance.new("Folder")
    folder.Name = "Mountains"
    folder.Parent = parent
    for index = 1, spec.count do
        local angle = (index + random:NextNumber(-0.3, 0.3)) / spec.count * math.pi * 2
        local distance = spec.radius + random:NextNumber(-0.5, 0.5) * (spec.spread or 0)
        Mountains.peak(folder, center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
            random:NextNumber(spec.size[1], spec.size[2]), random, spec, make)
    end
    return folder
end

return Mountains
