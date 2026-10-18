local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local CargoVisual = {}

-- Junk welded onto the ball, in units of its diameter (the core's radius is 0.5): shape,
-- size, offset, colour, material. A Metal load reads as a heap of salvage: rusty lumps,
-- a pipe, a tyre, a brass gear, a girder, a bent sheet, a copper coil, bolts and an
-- antenna with a red bulb.
local V = Vector3.new
-- Centred `dist` out along `dir`, with the part's X axis pointing outward.
local function radial(dir, dist, spin)
    local position = dir.Unit * dist
    return CFrame.lookAt(position, position + dir.Unit) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(spin or 0, 0, 0)
end
local RUST, DARK, STEEL = Color3.fromRGB(150, 78, 42), Color3.fromRGB(70, 72, 78), Color3.fromRGB(168, 174, 182)
local BRASS, COPPER, RUBBER, PAINT = Color3.fromRGB(206, 164, 72), Color3.fromRGB(190, 112, 60), Color3.fromRGB(32, 32, 36), Color3.fromRGB(226, 120, 40)
local PIPE, TYRE, GEAR = V(0.5, 0.8, 0.35), V(-0.85, 0.25, 0.45), V(0.2, -0.3, 0.95)
local GIRDER, SHEET, COIL, ANTENNA = V(-0.75, 0.45, -0.5), V(0.95, -0.1, -0.35), V(0.35, 0.35, -0.9), V(-0.15, 1, 0.1)
local SCRAP = {
    { "Ball", V(0.72, 0.72, 0.72), CFrame.new(0.2, 0.12, -0.12), RUST, "CorrodedMetal" },
    { "Ball", V(0.6, 0.6, 0.6), CFrame.new(-0.22, -0.1, 0.16), DARK, "CorrodedMetal" },
    { "Cylinder", V(0.62, 0.13, 0.13), radial(PIPE, 0.5), STEEL, "Metal" },
    { "Cylinder", V(0.06, 0.19, 0.19), radial(PIPE, 0.8), DARK, "Metal" },
    { "Cylinder", V(0.16, 0.5, 0.5), radial(TYRE, 0.48), RUBBER, "SmoothPlastic" },
    { "Cylinder", V(0.2, 0.2, 0.2), radial(TYRE, 0.5), STEEL, "Metal" },
    { "Cylinder", V(0.07, 0.4, 0.4), radial(GEAR, 0.49), BRASS, "Metal" },
    { "Block", V(0.06, 0.5, 0.08), radial(GEAR, 0.49), BRASS, "Metal" },
    { "Block", V(0.06, 0.5, 0.08), radial(GEAR, 0.49, math.pi / 3), BRASS, "Metal" },
    { "Block", V(0.06, 0.5, 0.08), radial(GEAR, 0.49, -math.pi / 3), BRASS, "Metal" },
    { "Cylinder", V(0.09, 0.12, 0.12), radial(GEAR, 0.52), DARK, "Metal" },
    { "Block", V(1, 0.14, 0.03), radial(GIRDER, 0.6, 0.4), PAINT, "Metal" },
    { "Block", V(1, 0.03, 0.13), radial(GIRDER, 0.6, 0.4) * CFrame.new(0, 0.07, 0), PAINT, "Metal" },
    { "Block", V(1, 0.03, 0.13), radial(GIRDER, 0.6, 0.4) * CFrame.new(0, -0.07, 0), PAINT, "Metal" },
    { "Wedge", V(0.04, 0.42, 0.5), radial(SHEET, 0.5) * CFrame.Angles(0.5, 0.3, 0), STEEL, "DiamondPlate" },
    { "Cylinder", V(0.22, 0.27, 0.27), radial(COIL, 0.5), COPPER, "Metal" },
    { "Cylinder", V(0.05, 0.29, 0.29), radial(COIL, 0.56), Color3.fromRGB(120, 66, 34), "Metal" },
    { "Cylinder", V(0.36, 0.03, 0.03), radial(ANTENNA, 0.6), STEEL, "Metal" },
    { "Ball", V(0.09, 0.09, 0.09), radial(ANTENNA, 0.79), Color3.fromRGB(255, 60, 50), "Neon" },
    { "Cylinder", V(0.06, 0.09, 0.09), radial(V(0.9, 0.4, -0.2), 0.5), DARK, "Metal" },
    { "Cylinder", V(0.06, 0.09, 0.09), radial(V(-0.5, 0.3, 0.85), 0.5), DARK, "Metal" },
    { "Cylinder", V(0.06, 0.09, 0.09), radial(V(0.3, -0.95, -0.1), 0.5), DARK, "Metal" },
}

-- Jerry can details relative to its body, in units of the can's height: size, offset,
-- tone (Handle/Trim/Cap). The wide faces point front/back so the X shows from behind.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local X_ANGLE = math.atan(0.74 / 0.62)
local CAN = {
    { "Block", Vector3.new(0.72, 0.04, 0.36), CFrame.new(0, 0, 0), "Trim" },
    { "Block", Vector3.new(0.44, 0.07, 0.1), CFrame.new(-0.08, 0.55, 0), "Handle" },
    { "Block", Vector3.new(0.06, 0.13, 0.1), CFrame.new(-0.27, 0.48, 0), "Handle" },
    { "Block", Vector3.new(0.06, 0.13, 0.1), CFrame.new(-0.08, 0.48, 0), "Handle" },
    { "Block", Vector3.new(0.06, 0.13, 0.1), CFrame.new(0.11, 0.48, 0), "Handle" },
    { "Cylinder", Vector3.new(0.1, 0.13, 0.13), CFrame.new(0.24, 0.47, 0) * UPRIGHT, "Trim" },
    { "Cylinder", Vector3.new(0.06, 0.17, 0.17), CFrame.new(0.24, 0.54, 0) * UPRIGHT, "Cap" },
    { "Block", Vector3.new(0.9, 0.05, 0.02), CFrame.new(0, 0, 0.175) * CFrame.Angles(0, 0, X_ANGLE), "Trim" },
    { "Block", Vector3.new(0.9, 0.05, 0.02), CFrame.new(0, 0, 0.175) * CFrame.Angles(0, 0, -X_ANGLE), "Trim" },
    { "Block", Vector3.new(0.9, 0.05, 0.02), CFrame.new(0, 0, -0.175) * CFrame.Angles(0, 0, X_ANGLE), "Trim" },
    { "Block", Vector3.new(0.9, 0.05, 0.02), CFrame.new(0, 0, -0.175) * CFrame.Angles(0, 0, -X_ANGLE), "Trim" },
}
local CAN_BODY = Vector3.new(0.7, 0.84, 0.34)
local CAN_COLORS = { Body = Color3.fromRGB(190, 38, 32), Trim = Color3.fromRGB(140, 26, 22), Handle = Color3.fromRGB(58, 58, 62) }

-- Grows with the load (volume-ish), capped at a deliberately absurd size.
-- Also the jerry can's height, so both loads grow at the same rate.
function CargoVisual.diameter(count)
    return math.clamp(Config.ScrapBallBaseDiameter * (count / Config.BaseCarryCapacity) ^ Config.ScrapBallGrowth,
        0.8, Config.ScrapBallMaxDiameter)
end

local function piece(name, shape, color, material, parent)
    local part = Instance.new("Part")
    part.Name, part.Shape, part.Color, part.Material = name, shape, color, material
    part.CanCollide, part.CanTouch, part.CanQuery, part.Massless, part.CastShadow = false, false, false, true, false
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function weld(part0, part1)
    local joint = Instance.new("Weld")
    joint.Part0, joint.Part1, joint.Parent = part0, part1, part1
    return joint
end

local function build(root, kind, color)
    local model = Instance.new("Model")
    model.Name = "CarriedMaterials"
    model:SetAttribute("Kind", kind)
    if kind == "Fuel" then
        local body = piece("JerryCan", Enum.PartType.Block, CAN_COLORS.Body, Enum.Material.Metal, model)
        weld(root, body)
        for index, spec in CAN do
            local detail = piece("CanDetail", Enum.PartType[spec[1]], spec[4] == "Cap" and color or CAN_COLORS[spec[4]],
                spec[4] == "Cap" and Enum.Material.Neon or Enum.Material.Metal, model)
            detail:SetAttribute("Index", index)
            weld(body, detail)
        end
        return model
    end
    local ball = piece("ScrapBall", Enum.PartType.Ball, color, Enum.Material.CorrodedMetal, model)
    weld(root, ball)
    for index, spec in SCRAP do
        local junk = piece("Scrap", Enum.PartType[spec[1]], spec[4], Enum.Material[spec[5]], model)
        junk:SetAttribute("Index", index)
        weld(ball, junk)
    end
    return model
end

-- Scales a unit-height offset, keeping its rotation.
local function scaled(cframe, size)
    return CFrame.new(cframe.Position * size) * cframe.Rotation
end

-- One load held overhead, resized in place (holds update cargo 20x per second):
-- a scrap ball for Metal, a jerry can for Fuel.
function CargoVisual.update(character, materials, colors)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    local model = character:FindFirstChild("CarriedMaterials")
    local metal, fuel = materials and materials.Metal or 0, materials and materials.Fuel or 0
    if metal + fuel == 0 or not root then
        if model then model:Destroy() end
        return
    end
    local kind = fuel > metal and "Fuel" or "Metal"
    if model and model:GetAttribute("Kind") ~= kind then
        model:Destroy()
        model = nil
    end
    local fresh = not model
    if fresh then model = build(root, kind, colors[kind]) end
    -- The owner's client plays its pickup and place sounds off this count, which
    -- arrives with the size change (CargoController).
    model:SetAttribute("Count", metal + fuel)
    local size = CargoVisual.diameter(metal + fuel)
    local main = model:FindFirstChild("JerryCan") or model.ScrapBall
    main.Size = kind == "Fuel" and CAN_BODY * size or Vector3.one * size
    -- Only C0 moves the load. Writing a welded part's CFrame on the server drags the
    -- whole character back to the server's lagged position (players froze mid-walk).
    main.Weld.C0 = CFrame.new(0, 2.4 + size / 2, -0.3)
    local specs = kind == "Fuel" and CAN or SCRAP
    for _, part in model:GetChildren() do
        local index = part:GetAttribute("Index")
        local spec = index and specs[index]
        if spec then
            part.Size = spec[2] * size
            part.Weld.C0 = scaled(spec[3], size)
        end
    end
    if fresh then model.Parent = character end
end

return CargoVisual
