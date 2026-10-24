--[[
    The Upgrades workshop on the forecourt: a little garage that fixes up your gear.
    Brick base and painted plank walls under a pitched metal roof with a gable sign, an
    open roll-up door (hazard-striped frame, striped awning) onto a lit workshop: a
    service counter with a glowing upgrade core spinning on it, pegboard with tools,
    shelves of parts, a tool chest and a workbench. Warm windows down the sides, a roof
    vent and antenna, and crates, barrels, plants and a lamp outside.

    UpgradeShop.build(parent, base, part) -> the counter: the part tagged UpgradesHut,
    carrying the prompt (WorldService), which the panel measures its closing distance
    from and the tutorial points at. `base` is the ground under the shop's centre; the
    door faces +X (the lane). It all fits the forecourt hut's 32 x 32 clear square
    (SitePropsCheck): 16 x 20, the awning and props within 12 of the centre.
]]
local CollectionService = game:GetService("CollectionService")
local Signs = require(script.Parent.SignService)
local Planets = require(script.Parent.Planets)
local UpgradeShop = {}

local BRICK = Color3.fromRGB(150, 74, 60)
local SIDING = Color3.fromRGB(70, 160, 120)
local TRIM = Color3.fromRGB(245, 240, 225)
local ROOF = Color3.fromRGB(56, 64, 84)
local YELLOW = Color3.fromRGB(255, 204, 40)
local DARK = Color3.fromRGB(38, 40, 48)
local STEEL = Color3.fromRGB(165, 172, 184)
-- Lit windows and lamps (Neon blooms toward white, so a deep warm orange).
local WARM = Color3.fromRGB(255, 176, 90)
local CORE = Color3.fromRGB(110, 230, 255)
-- Walls: the room is 16 (x) by 20 (z), walls 10 tall on a 0.5 slab.
local W, D, H, FLOOR = 16, 20, 10, 0.5
local DOOR_W, DOOR_H = 9, 7

function UpgradeShop.build(parent, base)
    local model = Instance.new("Model")
    model.Name = "UpgradesWorkshop"
    model.Parent = parent
    local frame = CFrame.new(base)
    local function piece(name, size, at, color, material, solid, class)
        local item = Instance.new(class or "Part")
        item.Name, item.Size, item.CFrame, item.Color = name, size, frame * at, color
        item.Material = material or Enum.Material.SmoothPlastic
        item.Anchored = true
        item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        if not solid then item.CanCollide, item.CanQuery, item.CanTouch = false, false, false end
        item.Parent = model
        return item
    end
    local function at(x, y, z) return CFrame.new(x, y, z) end

    -- Slab and floor (a step up of half a stud).
    local slab = piece("Foundation", Vector3.new(W + 1, FLOOR, D + 1), at(0, FLOOR / 2, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete, true)
    Planets.overlay(slab, Enum.NormalId.Top, "Concrete", 8, 0.3)
    -- Walls: a brick band to 3.5, plank siding above, a trim board between.
    local function wall(name, size, center)
        local brickH = 3
        piece(name .. "Brick", Vector3.new(size.X, brickH, size.Z), at(center.X, FLOOR + brickH / 2, center.Z), BRICK, Enum.Material.Brick, true)
        piece(name .. "Siding", Vector3.new(size.X, H - brickH, size.Z), at(center.X, FLOOR + brickH + (H - brickH) / 2, center.Z), SIDING, Enum.Material.WoodPlanks, true)
        piece(name .. "Trim", Vector3.new(size.X + 0.2, 0.35, size.Z + 0.2), at(center.X, FLOOR + brickH, center.Z), TRIM, Enum.Material.SmoothPlastic)
    end
    wall("BackWall", Vector3.new(1, 0, D), Vector3.new(-W / 2 + 0.5, 0, 0))
    for _, side in { -1, 1 } do
        wall("SideWall", Vector3.new(W, 0, 1), Vector3.new(0, 0, side * (D / 2 - 0.5)))
        -- Front piers either side of the door.
        local pier = (D - DOOR_W) / 2
        wall("FrontPier", Vector3.new(1, 0, pier), Vector3.new(W / 2 - 0.5, 0, side * (DOOR_W / 2 + pier / 2)))
        -- Corner posts.
        piece("CornerPost", Vector3.new(1.2, H + 0.4, 1.2), at(W / 2 - 0.4, FLOOR + H / 2, side * (D / 2 - 0.4)), TRIM, Enum.Material.SmoothPlastic, true)
        piece("CornerPost", Vector3.new(1.2, H + 0.4, 1.2), at(-W / 2 + 0.4, FLOOR + H / 2, side * (D / 2 - 0.4)), TRIM, Enum.Material.SmoothPlastic, true)
    end
    piece("Lintel", Vector3.new(1, H - DOOR_H, DOOR_W), at(W / 2 - 0.5, FLOOR + DOOR_H + (H - DOOR_H) / 2, 0), SIDING, Enum.Material.WoodPlanks, true)
    -- The door frame: hazard stripes up both sides and across the top.
    for _, side in { -1, 1 } do
        for index = 0, 6 do
            piece("HazardStripe", Vector3.new(0.3, 1, 0.5), at(W / 2 + 0.05, FLOOR + 0.5 + index, side * (DOOR_W / 2 + 0.25)), index % 2 == 0 and YELLOW or DARK)
        end
    end
    for index = 0, 8 do
        piece("HazardStripe", Vector3.new(0.3, 0.5, 1), at(W / 2 + 0.05, FLOOR + DOOR_H + 0.25, -DOOR_W / 2 + 0.5 + index), index % 2 == 0 and YELLOW or DARK)
    end
    -- The roll-up shutter, rolled up into its drum behind the lintel, its bottom slat
    -- just showing under it (clear of the counter's glowing core).
    piece("ShutterDrum", Vector3.new(DOOR_W, 1.4, 1.4), at(W / 2 - 1.8, FLOOR + DOOR_H + 0.8, 0) * CFrame.Angles(0, math.rad(90), 0), STEEL, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
    piece("ShutterSlat", Vector3.new(0.2, 0.35, DOOR_W - 0.4), at(W / 2 - 1.1, FLOOR + DOOR_H - 0.17, 0), Color3.fromRGB(190, 196, 206), Enum.Material.Metal)
    -- Striped awning over the door, sloping out and down.
    local awning = CFrame.new(W / 2 + 1.7, FLOOR + DOOR_H + 1.2, 0) * CFrame.Angles(0, 0, math.rad(-18))
    for index = 0, 9 do
        local z = -5.4 + index * 1.2
        piece("Awning", Vector3.new(3.8, 0.15, 1.2), awning * CFrame.new(0, 0, z), index % 2 == 0 and Color3.fromRGB(235, 70, 60) or Color3.fromRGB(250, 245, 235), Enum.Material.Fabric)
    end
    for _, side in { -1, 1 } do
        piece("AwningArm", Vector3.new(3.6, 0.15, 0.15), awning * CFrame.new(-0.1, -0.15, side * 5.9), DARK, Enum.Material.Metal)
    end

    -- Pitched metal roof: the ridge runs front to back, eaves overhanging the walls.
    local pitch = math.rad(28)
    local half = D / 2 + 1.2
    local ridgeY = FLOOR + H - 0.3 + half * math.tan(pitch)
    for _, side in { -1, 1 } do
        local roof = piece("Roof", Vector3.new(W + 2.4, 0.5, half / math.cos(pitch)), at(0, ridgeY - half * math.tan(pitch) / 2, side * half / 2) * CFrame.Angles(side * pitch, 0, 0), ROOF, Enum.Material.Metal, true)
        roof.CastShadow = true
        -- Gable ends: two wedges per end (tall toward the ridge) fill the triangle.
        for _, x in { W / 2 - 0.5, -W / 2 + 0.5 } do
            local wedge = piece("Gable", Vector3.new(1, ridgeY - FLOOR - H, D / 2), at(x, FLOOR + H + (ridgeY - FLOOR - H) / 2, side * D / 4) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), SIDING, Enum.Material.WoodPlanks, true, "WedgePart")
            wedge.CastShadow = true
        end
    end
    piece("RidgeCap", Vector3.new(W + 2.6, 0.5, 0.9), at(0, ridgeY + 0.05, 0), DARK, Enum.Material.Metal)
    -- The sign on the front gable, a vent and an antenna on the roof. The sign stays under
    -- the eaves (the roof's underside falls ~0.53 a stud out from the ridge): 10 wide and
    -- low on the gable, its foot over the wall top and clear of the awning.
    Signs.decorate(piece("UpgradesSign", Vector3.new(0.4, 3.2, 10), at(W / 2 + 0.2, FLOOR + H + 0.9, 0), Signs.Backing), Enum.NormalId.Right,
        { title = "UPGRADES", subtitle = "SPEND YOUR COINS", icon = "⚡", accent = YELLOW })
    local vent = piece("RoofVent", Vector3.new(1.6, 1.6, 1.6), at(-3, ridgeY - 1.6, 3.5), STEEL, Enum.Material.Metal)
    vent.Shape = Enum.PartType.Cylinder
    vent.CFrame = frame * at(-3, ridgeY - 1.2, 3.5) * CFrame.Angles(0, 0, math.rad(90))
    local fan = piece("VentFan", Vector3.new(1.4, 0.2, 0.3), at(-3, ridgeY - 0.3, 3.5), DARK, Enum.Material.Metal)
    fan:SetAttribute("SpinRate", 4)
    CollectionService:AddTag(fan, Planets.SpinTag)
    piece("Antenna", Vector3.new(0.2, 5, 0.2), at(-5, ridgeY + 2.2, -1), STEEL, Enum.Material.Metal)
    local blink = piece("AntennaLight", Vector3.new(0.5, 0.5, 0.5), at(-5, ridgeY + 4.9, -1), Color3.fromRGB(255, 70, 50), Enum.Material.Neon)
    blink.Shape = Enum.PartType.Ball
    blink:SetAttribute("Period", 1.6)
    CollectionService:AddTag(blink, "Blinker")

    -- Side windows: framed, glowing warm.
    for _, side in { -1, 1 } do
        for _, x in { -3.5, 2.5 } do
            local z = side * (D / 2 + 0.02)
            piece("WindowFrame", Vector3.new(3.2, 2.6, 0.2), at(x, FLOOR + 6, z), TRIM)
            piece("Window", Vector3.new(2.6, 2, 0.24), at(x, FLOOR + 6, z), WARM, Enum.Material.Neon)
            piece("WindowBar", Vector3.new(0.15, 2, 0.28), at(x, FLOOR + 6, z), TRIM)
            piece("WindowSill", Vector3.new(3.6, 0.25, 0.6), at(x, FLOOR + 4.6, side * (D / 2 + 0.25)), TRIM)
        end
    end

    -- Inside: ceiling lights, pegboard with tools, shelves, a tool chest, a workbench.
    for _, z in { -5, 0, 5 } do
        local strip = piece("CeilingLight", Vector3.new(6, 0.2, 0.6), at(-1, FLOOR + H - 0.5, z), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
        if z == 0 then
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = WARM, 22, 1.4
            light.Parent = strip
        end
    end
    piece("Pegboard", Vector3.new(0.2, 4.5, 12), at(-W / 2 + 1.1, FLOOR + 5, 0), Color3.fromRGB(196, 160, 112), Enum.Material.Wood)
    local tools = { { -4.5, 6, Color3.fromRGB(220, 60, 50) }, { -2.5, 5.5, STEEL }, { -0.5, 6.4, Color3.fromRGB(240, 190, 40) }, { 1.5, 5.2, STEEL }, { 3.5, 6, Color3.fromRGB(60, 120, 220) } }
    for _, tool in tools do
        piece("Tool", Vector3.new(0.25, 2.2, 0.5), at(-W / 2 + 1.3, FLOOR + tool[2], tool[1]) * CFrame.Angles(math.rad(tool[1] * 8), 0, 0), tool[3], Enum.Material.Metal)
    end
    for _, side in { -1, 1 } do
        -- Shelves of parts along the side walls at the back.
        for level = 0, 2 do
            piece("Shelf", Vector3.new(5, 0.25, 1.6), at(-4, FLOOR + 1.5 + level * 2, side * (D / 2 - 1.8)), STEEL, Enum.Material.Metal)
            for item = 0, 2 do
                local colors = { Color3.fromRGB(220, 160, 60), Color3.fromRGB(90, 150, 220), Color3.fromRGB(200, 80, 70) }
                piece("Part", Vector3.new(1, 0.9, 1), at(-5.6 + item * 1.6, FLOOR + 2.1 + level * 2, side * (D / 2 - 1.8)), colors[(item + level) % 3 + 1], Enum.Material.SmoothPlastic)
            end
        end
    end
    piece("ToolChest", Vector3.new(2, 3.4, 3), at(-5.8, FLOOR + 1.7, -5.5), Color3.fromRGB(210, 50, 45), Enum.Material.Metal, true)
    for row = 0, 3 do
        piece("Drawer", Vector3.new(0.1, 0.6, 2.6), at(-4.75, FLOOR + 0.6 + row * 0.75, -5.5), STEEL, Enum.Material.Metal)
    end
    piece("Workbench", Vector3.new(2.4, 0.4, 6), at(-5.6, FLOOR + 3, 4), Color3.fromRGB(140, 100, 64), Enum.Material.Wood, true)
    for _, z in { 1.4, 6.6 } do piece("BenchLeg", Vector3.new(2, 3, 0.3), at(-5.6, FLOOR + 1.4, z), DARK, Enum.Material.Metal) end
    piece("Vice", Vector3.new(1, 0.8, 0.8), at(-5.2, FLOOR + 3.6, 2.2), STEEL, Enum.Material.Metal)
    -- Floor markings: a hazard border round the service bay.
    for _, z in { -3.6, 3.6 } do piece("FloorLine", Vector3.new(7, 0.04, 0.3), at(2.5, FLOOR + 0.03, z), YELLOW) end

    -- The service counter just inside the door, with the upgrade core spinning on it.
    local counter = piece("UpgradesHut", Vector3.new(2.4, 3.2, 7), at(3.6, FLOOR + 1.6, 0), Color3.fromRGB(60, 66, 82), Enum.Material.Metal, true)
    piece("CounterTop", Vector3.new(2.8, 0.3, 7.4), at(3.6, FLOOR + 3.35, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
    piece("CounterStripe", Vector3.new(0.1, 0.5, 7), at(4.82, FLOOR + 2.4, 0), YELLOW, Enum.Material.SmoothPlastic)
    local pedestal = piece("CorePedestal", Vector3.new(0.5, 1.4, 1.4), at(3.6, FLOOR + 3.75, 0) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Metal)
    pedestal.Shape = Enum.PartType.Cylinder
    local core = piece("UpgradeCore", Vector3.new(1.3, 1.3, 1.3), at(3.6, FLOOR + 4.8, 0), CORE, Enum.Material.Neon)
    core.Shape = Enum.PartType.Ball
    core:SetAttribute("Period", 2.2)
    CollectionService:AddTag(core, "Pulse")
    local glow = Instance.new("PointLight")
    glow.Color, glow.Range, glow.Brightness = CORE, 12, 2
    glow.Parent = core
    for index, tilt in { 0, 60, -60 } do
        local ring = piece("CoreRing", Vector3.new(0.12, 2.2, 2.2), at(3.6, FLOOR + 4.8, 0) * CFrame.Angles(math.rad(tilt), 0, math.rad(90)), YELLOW, Enum.Material.Neon)
        ring.Shape = Enum.PartType.Cylinder
        ring.Transparency = 0.3
        ring:SetAttribute("SpinRate", index % 2 == 0 and 1.6 or -1.2)
        CollectionService:AddTag(ring, Planets.SpinTag)
    end
    piece("Register", Vector3.new(1, 0.8, 1.2), at(3.4, FLOOR + 3.9, -2.4), DARK, Enum.Material.SmoothPlastic)
    piece("RegisterScreen", Vector3.new(0.1, 0.5, 0.9), at(3.95, FLOOR + 4.1, -2.4), Color3.fromRGB(120, 255, 150), Enum.Material.Neon)

    -- Outside: plants by the door, crates and barrels round the side, a street lamp.
    for _, side in { -1, 1 } do
        local pot = piece("Planter", Vector3.new(1.6, 1.4, 1.6), at(W / 2 + 1.4, 0.7, side * 6.2), Color3.fromRGB(180, 110, 70), Enum.Material.Slate, true)
        pot.Shape = Enum.PartType.Cylinder
        pot.CFrame = frame * at(W / 2 + 1.4, 0.7, side * 6.2) * CFrame.Angles(0, 0, math.rad(90))
        Planets.blob(model, "Shrub", frame * at(W / 2 + 1.4, 2.2, side * 6.2), Vector3.new(2.4, 2.2, 2.4), Color3.fromRGB(70, 140, 60), Enum.Material.Grass).CastShadow = true
    end
    for index, spot in { { -3, -12.2, 0 }, { -0.8, -12.4, 20 }, { -2, -12.3, -10, true } } do
        local size = spot[4] and 1.6 or 2.4
        piece("Crate", Vector3.new(size, size, size), at(spot[1], (spot[4] and 2.4 or 0) + size / 2, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0),
            Color3.fromRGB(176, 128, 76), Enum.Material.WoodPlanks, index < 3)
    end
    for index, z in { -2, 0.2 } do
        local barrel = piece("Barrel", Vector3.new(2.6, 1.8, 1.8), at(-6.5 + index * 2, 1.3, -12.3) * CFrame.Angles(0, 0, math.rad(90)), index == 1 and Color3.fromRGB(40, 110, 200) or Color3.fromRGB(220, 70, 50), Enum.Material.Metal, true)
        barrel.Shape = Enum.PartType.Cylinder
    end
    local lampAt = Vector3.new(W / 2 + 3, 0, -10.5)
    piece("LampPost", Vector3.new(0.4, 9, 0.4), at(lampAt.X, 4.5, lampAt.Z), DARK, Enum.Material.Metal, true)
    piece("LampArm", Vector3.new(0.25, 0.25, 2), at(lampAt.X, 8.9, lampAt.Z + 0.9), DARK, Enum.Material.Metal)
    local lamp = piece("Lamp", Vector3.new(1, 0.5, 1), at(lampAt.X, 8.6, lampAt.Z + 1.8), WARM, Enum.Material.Neon)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = WARM, 16, 1.2
    light.Parent = lamp
    return counter
end

return UpgradeShop
