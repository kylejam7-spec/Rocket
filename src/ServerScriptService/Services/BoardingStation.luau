-- The boarding station on the front of each tier's launch mount (user, 2026-10-24): a
-- railed ramp from the apron up onto the mount, and a crew hatch module tucked under the
-- hull with a glowing door. Walking into the door boards you (LaunchService.onHatch
-- tests the trigger box in front of it); it's a picture of a door, not a moving one.
-- The ramp and door are human-sized on every tier; the module sizes with the rocket.
--
-- BoardingStation.build(parent, origin, site) builds it in `origin`'s frame (the upright
-- rocket on the pad, +Z toward the forecourt, y = 0 the apron) from site = { mountTop,
-- mountFront, coreRadius, hullBottom, front } (studs; front(halfWidth, y0, y1) is how far
-- forward the finished rocket stands in that column, so the hatch module goes in front
-- of engine pods and skirts and nothing stands before its door). Returns
-- { trigger = { cframe, size }, setPhase = function(phase), reveal = function() }.
-- The station is hidden while the rocket is built and fuelled: reveal() (the rocket
-- stands upright and complete) fades it in for boarding, and any other phase hides it
-- again. The door and its strips light for "Boarding".
local TweenService = game:GetService("TweenService")
local Signs = require(script.Parent.SignService)
local BoardingStation = {}

local SLOPE = math.rad(30)
local RAMP_WIDTH, RAIL_HEIGHT = 30, 3.5
local DOOR_WIDTH, DOOR_HEIGHT = 12, 16
local OPEN, CLOSED = Color3.fromRGB(80, 255, 140), Color3.fromRGB(70, 76, 92)
local STEEL, DARK = Color3.fromRGB(150, 156, 166), Color3.fromRGB(46, 50, 62)
local HULL, HAZARD = Color3.fromRGB(226, 230, 238), Color3.fromRGB(255, 196, 40)
-- The BOARD sign's subtitle and colour per rocket phase (anything else: after liftoff).
local STATUS = {
    Building = { "FILL THE ROCKET TO BOARD", Color3.fromRGB(255, 185, 35) },
    Fueling = { "FUEL THE ROCKET TO BOARD", Color3.fromRGB(255, 80, 150) },
    Boarding = { "BOARD NOW!", OPEN },
}
local AFTER = { "NEXT ROCKET SOON", Color3.fromRGB(150, 120, 255) }

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
    -- A trim strip along the mount's front edge (Tier 5's stands a stud proud of the top)
    -- parts round the ramp, so its top has no lip and its rails don't cut through it.
    local gap = RAMP_WIDTH / 2 + 1
    for _, trim in parent:GetChildren() do
        local at = trim:IsA("BasePart") and trim.Name == "MountTrim" and origin:ToObjectSpace(trim.CFrame)
        if at and math.abs(at.Z - front) < trim.Size.Z and trim.Size.X > 2 * gap then
            for _, side in { -1, 1 } do
                local piece = trim:Clone()
                local width = trim.Size.X / 2 - gap
                piece.Size = Vector3.new(width, trim.Size.Y, trim.Size.Z)
                piece.CFrame = trim.CFrame * CFrame.new(side * (gap + width / 2), 0, 0)
                piece.Parent = parent
            end
            trim:Destroy()
        end
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
    local width = math.clamp(site.coreRadius * 0.75, DOOR_WIDTH + 10, 48)
    -- At least the door plus a band for the sign (on low-slung tiers it tucks into the hull).
    local height = math.clamp(site.hullBottom - top - 0.3, DOOR_HEIGHT + 11, 80)
    -- Its back meets the front of whatever of the rocket stands at its height (engine
    -- pods, a thrust skirt), or tucks under the hull where nothing does.
    local standing = site.front and site.front(width / 2 + 2.5, top, top + height) or -math.huge
    local back = math.max(site.coreRadius * 0.8, standing)
    local face = math.max(site.coreRadius + 5, back + 6)
    block("HatchModule", Vector3.new(width, height, face - back), CFrame.new(0, top + height / 2, (back + face) / 2), HULL, Enum.Material.Metal)
    -- Dark corner posts up its front edges, and a light band round it that glows for boarding.
    for _, side in { -1, 1 } do
        block("HatchPost", Vector3.new(2, height, 2), CFrame.new(side * (width / 2 + 0.4), top + height / 2, face - 0.6), DARK, Enum.Material.Metal)
    end
    table.insert(glow, block("HatchBand", Vector3.new(width + 0.4, 0.8, 0.4), CFrame.new(0, top + height - 0.8, face + 0.2), CLOSED, Enum.Material.Neon,
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
    -- Between the door's lintel and the light band.
    local signHeight = math.min(height - DOOR_HEIGHT - 4, 8)
    local sign = Signs.decorate(block("BoardSign", Vector3.new(math.min(width - 4, signHeight * 4.5), signHeight, 0.4),
        CFrame.new(0, top + DOOR_HEIGHT + 1.8 + signHeight / 2, face + 0.3) * outward, Signs.Backing),
        Enum.NormalId.Front, { title = "BOARD", subtitle = STATUS.Building[1], icon = "🚀", accent = STATUS.Building[2] })
    model.Parent = parent

    local station = {
        -- Just in front of the door, so walking into it boards you.
        trigger = { cframe = origin * CFrame.new(0, top + DOOR_HEIGHT / 2, face + 2.4), size = Vector3.new(DOOR_WIDTH + 2, DOOR_HEIGHT, 4) },
        model = model,
    }
    -- Hidden until reveal(): every part's look and collision, remembered (the BOARD sign
    -- is drawn by each client, WorldSignController, which hides it while it's Hidden).
    local looks = {}
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then looks[part] = { part.Transparency, part.CanCollide, part.CanQuery } end
    end
    local shown = true
    local function show(visible, seconds)
        if visible == shown then return end
        shown = visible
        sign:SetAttribute("Hidden", not visible)
        for part, look in looks do
            part.CanCollide, part.CanQuery = visible and look[2], visible and look[3]
            local goal = visible and look[1] or 1
            if seconds then
                part.Transparency = 1
                TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Transparency = goal }):Play()
            else
                part.Transparency = goal
            end
        end
    end
    local current
    function station.reveal()
        if current == "Boarding" then show(true, 0.8) end
    end
    function station.setPhase(phase)
        if phase == current then return end
        current = phase
        if phase ~= "Boarding" then show(false) end
        local open = phase == "Boarding"
        for _, part in glow do
            if part.Parent then part.Color = open and OPEN or CLOSED end
        end
        looks[door][1] = open and 0.1 or 0
        if shown then door.Transparency = looks[door][1] end
        local status = STATUS[phase] or AFTER
        sign:SetAttribute("Subtitle", status[1])
        sign:SetAttribute("Accent", status[2])
    end
    station.setPhase("Building")
    return station
end

return BoardingStation
