local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local CargoVisual = {}

-- Lumps on the ball's surface (direction, size as a fraction of the diameter) so a
-- Metal load reads as a ball of scrap rather than a smooth sphere.
local CHUNKS = {
    { Vector3.new(0.9, 0.35, 0.2), Vector3.new(0.42, 0.3, 0.34) },
    { Vector3.new(-0.7, 0.6, -0.4), Vector3.new(0.36, 0.36, 0.28) },
    { Vector3.new(0.1, 0.95, 0.5), Vector3.new(0.3, 0.22, 0.4) },
    { Vector3.new(-0.3, -0.2, 0.95), Vector3.new(0.38, 0.32, 0.24) },
    { Vector3.new(0.4, -0.5, -0.8), Vector3.new(0.3, 0.4, 0.3) },
    { Vector3.new(-0.95, -0.4, 0.3), Vector3.new(0.26, 0.3, 0.36) },
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
    for index in CHUNKS do
        local chunk = piece("Chunk", Enum.PartType.Block, color:Lerp(Color3.new(0.3, 0.28, 0.25), index % 2 * 0.4),
            Enum.Material.DiamondPlate, model)
        chunk:SetAttribute("Index", index)
        weld(ball, chunk)
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
    local specs = kind == "Fuel" and CAN or CHUNKS
    for _, part in model:GetChildren() do
        local index = part:GetAttribute("Index")
        local spec = index and specs[index]
        if spec then
            part.Size = spec[2] * size
            part.Weld.C0 = kind == "Fuel" and scaled(spec[3], size)
                or CFrame.new(spec[1].Unit * size * 0.42) * CFrame.Angles(index, index * 2.4, index * 0.7)
        end
    end
    if fresh then model.Parent = character end
end

return CargoVisual
