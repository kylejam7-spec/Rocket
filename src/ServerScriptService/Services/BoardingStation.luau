-- The boarding station on the front of each tier's launch mount (user, 2026-10-24): a
-- railed ramp from the apron up onto the mount, and a crew hatch module tucked under the
-- hull with a glowing door. Walking into the door boards you (LaunchService.onHatch
-- tests the trigger box in front of it); it's a picture of a door, not a moving one.
-- The ramp and door are human-sized on every tier; the module sizes with the rocket.
--
-- BoardingStation.build(parent, origin, site) builds it in `origin`'s frame (the upright
-- rocket on the pad, +Z toward the forecourt, y = 0 the apron) from site = { mountTop,
-- mountFront, coreRadius, hullBottom } (studs). Returns { trigger = { cframe, size },
-- setOpen = function(open) } — open lights the door and its strips for boarding.
local Signs = require(script.Parent.SignService)
local BoardingStation = {}

local SLOPE = math.rad(30)
local RAMP_WIDTH, RAIL_HEIGHT = 30, 3.5
local DOOR_WIDTH, DOOR_HEIGHT = 12, 16
local OPEN, CLOSED = Color3.fromRGB(80, 255, 140), Color3.fromRGB(70, 76, 92)
local STEEL, DARK = Color3.fromRGB(150, 156, 166), Color3.fromRGB(46, 50, 62)
local HULL, HAZARD = Color3.fromRGB(226, 230, 238), Color3.fromRGB(255, 196, 40)

function BoardingStation.build(parent, origin, site)
    local model = Instance.new("Model")
    model.Name = "BoardingStation"
    local glow = {}
    local function block(name, size, cframe, color, material, props)
        local part = Instance.new("Part")
        part.Name, part.Size, part.CFrame, part.Color = name, size, origin * cframe, color
        part.Material = material or Enum.Material.SmoothPlastic
        part.Anchored = true
        part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        for key, value in props or {} do part[key] = value end
        part.Parent = model
        return part
    end
    local top, front = site.mountTop, site.mountFront

    -- The ramp: a slab rising toward the rocket, its top surface from the apron to the
    -- mount's front edge, a little into each so there's no lip.
    local run = top / math.tan(SLOPE)
    local length = top / math.sin(SLOPE) + 2
    local tilt = CFrame.Angles(SLOPE, 0, 0)
    local normal = Vector3.new(0, math.cos(SLOPE), math.sin(SLOPE))
    local mid = Vector3.new(0, top / 2, front + run / 2)
    local surface = CFrame.new(mid) * tilt
    block("BoardingRamp", Vector3.new(RAMP_WIDTH, 1, length), CFrame.new(mid - normal * 0.5) * tilt, STEEL, Enum.Material.DiamondPlate)
    for _, side in { -1, 1 } do
        local x = side * (RAMP_WIDTH / 2 + 0.3)
        block("RampRail", Vector3.new(0.6, RAIL_HEIGHT, length), surface * CFrame.new(x, RAIL_HEIGHT / 2, 0), DARK, Enum.Material.Metal)
        table.insert(glow, block("RampGuide", Vector3.new(0.3, 0.25, length - 2), surface * CFrame.new(x - side * 0.6, 0.15, 0), CLOSED,
            Enum.Material.Neon, { CanCollide = false, CanQuery = false }))
    end
    -- Posts under the ramp's high end.
    for _, fraction in { 0.35, 0.7 } do
        local height = top * fraction
        local z = front + run * (1 - fraction)
        for _, side in { -1, 1 } do
            block("RampPost", Vector3.new(1.2, height, 1.2), CFrame.new(side * (RAMP_WIDTH / 2 - 1.5), height / 2, z), STEEL, Enum.Material.Metal)
        end
    end

    -- The crew hatch module: from under the hull out past its front, mount top up to the
    -- hull's underside. The door is on its front face.
    local back = site.coreRadius * 0.8
    local face = site.coreRadius + 5
    local width = math.clamp(site.coreRadius * 0.75, DOOR_WIDTH + 10, 48)
    local height = math.clamp(site.hullBottom - top - 0.3, DOOR_HEIGHT + 6, 80)
    block("HatchModule", Vector3.new(width, height, face - back), CFrame.new(0, top + height / 2, (back + face) / 2), HULL, Enum.Material.Metal)
    -- Dark corner posts up its front edges, and a light band round it that glows for boarding.
    for _, side in { -1, 1 } do
        block("HatchPost", Vector3.new(2, height, 2), CFrame.new(side * (width / 2 + 0.4), top + height / 2, face - 0.6), DARK, Enum.Material.Metal)
    end
    table.insert(glow, block("HatchBand", Vector3.new(width + 0.4, 0.8, 0.4), CFrame.new(0, top + DOOR_HEIGHT + 3, face + 0.2), CLOSED, Enum.Material.Neon,
        { CanCollide = false, CanQuery = false }))
    -- Facing +Z: a part's front face is -Z, so the door and sign are turned round.
    local outward = CFrame.Angles(0, math.pi, 0)
    local door = block("BoardingDoor", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.4), CFrame.new(0, top + DOOR_HEIGHT / 2, face + 0.2) * outward,
        CLOSED, Enum.Material.Neon)
    table.insert(glow, door)
    -- A hazard-striped frame round the door.
    for index = 0, math.floor(DOOR_HEIGHT / 1.4) do
        for _, side in { -1, 1 } do
            block("DoorStripe", Vector3.new(1.2, 1.4, 0.6), CFrame.new(side * (DOOR_WIDTH / 2 + 0.6), top + 0.7 + index * 1.4, face + 0.3),
                index % 2 == 0 and HAZARD or DARK, Enum.Material.SmoothPlastic, { CanCollide = false })
        end
    end
    block("DoorLintel", Vector3.new(DOOR_WIDTH + 2.4, 1.2, 0.6), CFrame.new(0, top + DOOR_HEIGHT + 0.6, face + 0.3), HAZARD)
    local signHeight = math.min(height - DOOR_HEIGHT - 6, 8)
    if signHeight >= 3 then
        Signs.decorate(block("BoardSign", Vector3.new(math.min(width - 4, signHeight * 4), signHeight, 0.4),
            CFrame.new(0, top + DOOR_HEIGHT + 4.5 + signHeight / 2, face + 0.3) * outward, Signs.Backing),
            Enum.NormalId.Front, { title = "BOARD", subtitle = "LIFTOFF THIS WAY", icon = "🚀", accent = OPEN })
    end
    -- An arch over the foot of the ramp, so the way in reads from the forecourt (its
    -- posts stand just outside the ramp's edges: Signs.board puts them at 0.32 of its width).
    local archWidth = (RAMP_WIDTH / 2 + 2) / 0.32
    local archAt = (origin * CFrame.new(0, 16, front + run + 3)).Position
    Signs.board(model, "BoardingArch", CFrame.lookAt(archAt, archAt + origin.Rotation * Vector3.zAxis), Vector2.new(archWidth, 7),
        { title = "BOARDING", subtitle = "UP THE RAMP • THROUGH THE DOOR", icon = "🚀", accent = OPEN, ground = origin.Y })
    model.Parent = parent

    local station = {
        -- Just in front of the door, so walking into it boards you.
        trigger = { cframe = origin * CFrame.new(0, top + DOOR_HEIGHT / 2, face + 2.4), size = Vector3.new(DOOR_WIDTH + 2, DOOR_HEIGHT, 4) },
        model = model,
    }
    function station.setOpen(open)
        for _, part in glow do
            if part.Parent then part.Color = open and OPEN or CLOSED end
        end
        door.Transparency = open and 0.1 or 0
    end
    station.setOpen(false)
    return station
end

return BoardingStation
