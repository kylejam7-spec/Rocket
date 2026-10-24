-- Instantiates one rocket tier on the pad, tilted between two climbing ramps, and fills
-- it lowest-point-first as material arrives. Material totals stay numeric in
-- RocketService; this maps fractions to anchored segments plus one growing "Filling"
-- part, so an 8,250-unit rocket is still ~100-200 parts.
-- Erecting and the ascent are animated by each client (LaunchEffects) from attributes.
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Models = require(script.Parent.RocketModels)
local BoardingStation = require(script.Parent.BoardingStation)
local GHOST_COLOR, GHOST_TRANSPARENCY = Color3.fromRGB(150, 200, 255), 0.86
local FUEL_LIT = Color3.fromRGB(255, 150, 40)
local SCRAP = Color3.fromRGB(125, 118, 108)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- Each ramp is at least RAMP_MIN_WIDTH wide, so a full 50-player server can climb, pass
-- and stand along the fill line at once. The outer edge stays RAMP_PAST_MOUNT beyond the
-- launch mount, inside the floodlights.
local RAMP_MIN_WIDTH, RAMP_PAST_MOUNT, POST_SPACING = 40, 28, 80
-- The ramp-top bar: its height over the surface (under a jump) and how far down from the
-- ramp's top end it stands.
local END_RAIL, END_RAIL_BACK = 3.5, 4
-- Bridges between the ramps: one every BRIDGE_SPACING up the rocket, BRIDGE_WIDTH wide
-- with BRIDGE_RAIL-high rails, lifted BRIDGE_CLEAR over the hull below; approaches at least
-- BRIDGE_APPROACH long, aiming for BRIDGE_SLOPE and never steeper than BRIDGE_MAX_SLOPE.
local BRIDGE_SPACING, BRIDGE_WIDTH, BRIDGE_RAIL, BRIDGE_CLEAR = 70, 10, 3, 0.5
local BRIDGE_APPROACH, BRIDGE_SLOPE, BRIDGE_MAX_SLOPE = 5, 15, 35
local reveal = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Build = {}
Build.__index = Build

function Build.new(parent, origin)
    local site = Instance.new("Folder")
    site.Name = "RocketSite"
    site.Parent = parent
    return setmetatable({ site = site, origin = origin, pivot = origin }, Build)
end

local function shaped(spec, cframe, parent)
    local className = spec.shape == "Wedge" and "WedgePart" or "Part"
    local part = Instance.new(className)
    if className == "Part" then part.Shape = Enum.PartType[spec.shape] end
    part.Name = spec.name
    part.Anchored = true
    part.Size = spec.size
    part.CFrame = cframe
    part.Color = spec.color
    part.Material = Enum.Material[spec.material or "SmoothPlastic"]
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function create(spec, cframe, parent)
    local part = shaped(spec, cframe, parent)
    if spec.engine then part:SetAttribute("Engine", true) end
    if spec.light then
        local light = Instance.new("PointLight")
        light.Color, light.Range, light.Brightness = spec.light.color, spec.light.range, spec.light.brightness
        light.Parent = part
    end
    return part
end

local function setGhost(item, ghost)
    local part = item.part
    part.CanCollide, part.CanQuery, part.CastShadow = not ghost, not ghost, not ghost
    if ghost then
        part.Color, part.Material, part.Transparency = GHOST_COLOR, Enum.Material.SmoothPlastic, GHOST_TRANSPARENCY
    else
        part.Color, part.Material = item.spec.color, Enum.Material[item.spec.material or "SmoothPlastic"]
        TweenService:Create(part, reveal, { Transparency = 0 }):Play()
    end
end

local function lightCell(item)
    item.part.Color, item.part.Material = FUEL_LIT, Enum.Material.Neon
end

-- Axis-aligned bounds of a spec in the upright rocket frame.
local function bounds(spec)
    local half = spec.size / 2
    local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
    for _, sx in { -1, 1 } do
        for _, sy in { -1, 1 } do
            for _, sz in { -1, 1 } do
                local point = spec.cframe * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
                low, high = low:Min(point), high:Max(point)
            end
        end
    end
    return low, high
end

-- The spec's local axis that points up the rocket; segments grow along it (balls scale).
local function growAxis(spec)
    if spec.shape == "Ball" then return nil end
    local up = spec.cframe:VectorToObjectSpace(Vector3.yAxis)
    local x, y, z = math.abs(up.X), math.abs(up.Y), math.abs(up.Z)
    if x >= y and x >= z then return Vector3.xAxis * math.sign(up.X) end
    if y >= z then return Vector3.yAxis * math.sign(up.Y) end
    return Vector3.zAxis * math.sign(up.Z)
end

local function entry(spec, order)
    local low, high = bounds(spec)
    return { spec = spec, order = order, low = low, high = high, axis = growAxis(spec),
        weight = math.max(1, spec.size.X * spec.size.Y * spec.size.Z) }
end

-- Size and upright-frame CFrame of the bottom `fraction` of a segment. The filled
-- piece is a hair wider than the segment so it never z-fights the ghost/empty cell.
local function partial(item, fraction)
    local spec, axis = item.spec, item.axis
    fraction = math.max(fraction, 0.04)
    if not axis then return spec.size * fraction + Vector3.one * 0.04, spec.cframe end
    local mask = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
    local length = spec.size:Dot(mask)
    local size = spec.size - mask * length * (1 - fraction) + (Vector3.one - mask) * 0.04
    return size, spec.cframe * CFrame.new(axis * length * (fraction - 1) / 2)
end

-- Marks items finished up to `fraction` of the list's weight and returns the first
-- unfinished item with how much of it is filled (nil once everything is done).
local function advance(list, fraction, complete)
    local target, sum = fraction * list.total, 0
    local current, amount, finished = nil, 0, #list.items
    for index, item in list.items do
        if sum + item.weight > target + 1e-6 then
            current, amount, finished = item, (target - sum) / item.weight, index - 1
            break
        end
        sum += item.weight
    end
    for index = list.done + 1, finished do complete(list.items[index]) end
    list.done = math.max(list.done, finished)
    return current, amount
end

local function makeList(items)
    local total = 0
    for _, item in items do total += item.weight end
    return { items = items, total = total, done = 0 }
end

-- Replace whatever is on the pad with `tier` (variant = 1st/2nd/3rd cycle of that tier).
function Build:load(tier, variant)
    self.site:ClearAllChildren()
    self.filling, self.frontierItem, self.ramps = nil, nil, {}
    local data = Models[tier]()
    local complex = Instance.new("Model")
    complex.Name = "LaunchComplex"
    local mountHalf, mountTop, mountFront = 0, 0, 0
    for _, spec in data.infra do
        create(spec, self.origin * spec.cframe, complex)
        if spec.name == "LaunchMount" then
            mountHalf, mountTop, mountFront = spec.size.X / 2, spec.cframe.Y + spec.size.Y / 2, spec.cframe.Z + spec.size.Z / 2
        end
    end

    -- Bounds of this variant's rocket decide the hinge and the ramps.
    local items, low, high, coreRadius = {}, Vector3.one * math.huge, -Vector3.one * math.huge, 2
    for order, spec in data.build do
        if (spec.minVariant or 1) <= variant then
            local item = entry(spec, order)
            low, high = low:Min(item.low), high:Max(item.high)
            if spec.shape == "Cylinder" and math.abs(spec.cframe.X) < 0.5 and math.abs(spec.cframe.Z) < 0.5 then
                coreRadius = math.max(coreRadius, spec.size.Z / 2)
            end
            table.insert(items, item)
        end
    end
    -- The boarding station on the mount's front (BoardingStation): its hatch module stops
    -- just under the lowest full-width core segment.
    local hullBottom = math.huge
    for _, item in items do
        local spec = item.spec
        if spec.shape == "Cylinder" and math.abs(spec.cframe.X) < 0.5 and math.abs(spec.cframe.Z) < 0.5 and spec.size.Z / 2 >= coreRadius * 0.9 then
            hullBottom = math.min(hullBottom, item.low.Y)
        end
    end
    -- How far forward (+Z, upright) anything of the finished rocket stands within |x| <= halfWidth
    -- between heights y0 and y1: the station goes in front of it (engine pods, skirts).
    local fuelItems = {}
    for order, spec in data.fuel do table.insert(fuelItems, entry(spec, order)) end
    local function front(halfWidth, y0, y1)
        local z = -math.huge
        for _, list in { items, fuelItems } do
            for _, item in list do
                if item.low.X < halfWidth and item.high.X > -halfWidth and item.low.Y < y1 and item.high.Y > y0 then
                    z = math.max(z, item.high.Z)
                end
            end
        end
        return z
    end
    self.boarding = BoardingStation.build(complex, self.origin,
        { mountTop = mountTop, mountFront = mountFront, coreRadius = coreRadius, hullBottom = hullBottom, front = front })
    -- "Lowest uncompleted point" first; list order breaks ties.
    table.sort(items, function(a, b)
        if a.low.Y ~= b.low.Y then return a.low.Y < b.low.Y end
        return a.order < b.order
    end)

    -- Hinge on the rocket's bottom -Z edge, so the tilted rocket never dips into the pad
    -- and erecting it swings it back to exactly the upright build position.
    local tilt = math.rad(Config.RocketTiltDegrees)
    local hinge = CFrame.new(0, low.Y, low.Z)
    local tilted = self.origin * hinge * CFrame.Angles(-tilt, 0, 0) * hinge:Inverse()
    self.pivot, self.bounds = tilted, { low = low, high = high }

    -- A ramp runs parallel to the rocket on each flank (-X and +X). Its inner edge is just
    -- outside the widest segment (boosters, fins), so players stand right beside the fill
    -- line and nothing being built hides under it; it rides over the low mount slab. Its
    -- surface is level with the core's top ridge (raised just enough to clear the mount
    -- where needed, see below) and its foot sinks into the pad in front.
    local c, s = math.cos(tilt), math.sin(tilt)
    local inner = math.max(high.X, -low.X, coreRadius) + 1
    local outer = math.max(inner + RAMP_MIN_WIDTH, math.max(high.X, -low.X, mountHalf) + RAMP_PAST_MOUNT)
    local rampX, rampWidth = (inner + outer) / 2, outer - inner
    -- Where the ramp crosses the mount's front edge its surface must clear the mount top,
    -- or the inner strip meets a ledge. Lifting the ramp plane by d raises it there by d / s.
    local surface = coreRadius
    if mountHalf > inner then
        local depth = surface - low.Z
        local atFront = low.Y + (depth * c - (mountFront - low.Z)) / s * c + depth * s
        surface += math.max(0, (mountTop + 0.3 - atFront) * s)
    end
    self.rampInner, self.rampOuter, self.rampSurface = inner, outer, surface
    local y0 = low.Y - (low.Y + (surface - low.Z) * s) / c - 2
    local y1 = high.Y - 8
    local steel, dark = Models.Colors.tower, Models.Colors.dark
    self.rampTop = y1
    for _, side in { -1, 1 } do
        local ramp = create({ name = "LaunchRamp", shape = "Block", size = Vector3.new(rampWidth, y1 - y0, 1), color = steel, material = "DiamondPlate" },
            tilted * CFrame.new(side * rampX, (y0 + y1) / 2, surface - 0.5), complex)
        -- How far up the ramp (its own Y) a runner's ramp slide carries them: just short
        -- of the end rail (SpeedController).
        ramp:SetAttribute("StopAt", (y1 - END_RAIL_BACK) - (y0 + y1) / 2 - 4)
        -- ...and how far across (its own X, signed toward the outer edge): just inside the
        -- guard wall, which a runner held against it at full speed could climb.
        ramp:SetAttribute("EdgeAt", side * (rampWidth / 2 - 2.6))
        table.insert(self.ramps, ramp)
        -- A guard wall 4 studs high on the outer edge: a fast runner drifting into it slides
        -- along it (a low lip there launched them off the side).
        table.insert(self.ramps, create({ name = "RampRail", shape = "Block", size = Vector3.new(0.6, y1 - y0, 4.5), color = dark, material = "Metal" },
            tilted * CFrame.new(side * (outer - 0.3), (y0 + y1) / 2, surface + 1.75), complex))
        table.insert(self.ramps, create({ name = "RampBeacon", shape = "Block", size = Vector3.new(1.5, 1, 1.5), color = Color3.fromRGB(255, 70, 60), material = "Neon",
            light = { color = Color3.fromRGB(255, 80, 60), range = 24, brightness = 2 } },
            tilted * CFrame.new(side * rampX, y1, surface + 0.75), complex))
        -- An upright bar across the top end, END_RAIL studs over the surface: low enough to
        -- jump, while the ramp slide stops a runner holding W just short of it (at full
        -- speed they'd sail over anything jumpable). Thick, so nobody tunnels through it.
        local foot = tilted * Vector3.new(side * rampX, y1 - END_RAIL_BACK, surface)
        table.insert(self.ramps, create({ name = "RampEndRail", shape = "Block", size = Vector3.new(rampWidth, END_RAIL + 2, 3), color = dark, material = "Metal" },
            CFrame.new(foot + Vector3.new(0, END_RAIL / 2 - 1, 0)) * self.origin.Rotation, complex))
    end
    local up = self.origin.Rotation
    -- Bridges across the hull join the two ramps every BRIDGE_SPACING, so players can walk
    -- straight over from one to the other. Each lies in the ramps' plane, lifted over the
    -- hull where anything on it (the core's ridge, fuel gauges, windows, boosters, fins)
    -- would meet it, with gentle approaches down to both ramps' inner edges. A bridge whose
    -- approaches would still touch the hull moves up or down the ramp a little, or is left
    -- out. Rails along both sides; the open ends meet the ramps.
    local solids = table.clone(items)
    for order, spec in data.fuel do table.insert(solids, entry(spec, order)) end
    local function clearance(y0b, y1b, x0, x1)
        -- The highest hull top (local Z) under the band y0b..y1b and |x| in x0..x1.
        local top = -math.huge
        for _, item in solids do
            local near = math.max(0, item.low.X, -item.high.X) -- the item's |x| nearest the axis
            local far = math.max(math.abs(item.low.X), math.abs(item.high.X))
            if item.high.Y > y0b and item.low.Y < y1b and far >= x0 and near <= x1 then top = math.max(top, item.high.Z) end
        end
        return top
    end
    local function slab(a, b, y)
        -- A deck piece from a to b (local X, Z at local height y; a.X < b.X), its top face
        -- on that line, BRIDGE_WIDTH along the rocket, a rail along each side.
        local x = (b - a).Unit
        local axisX, axisY = Vector3.new(x.X, 0, x.Y), Vector3.yAxis
        local normal = axisX:Cross(axisY)
        local mid = Vector3.new((a.X + b.X) / 2, y, (a.Y + b.Y) / 2) - normal * 0.5
        local cframe = tilted * CFrame.fromMatrix(mid, axisX, axisY, normal)
        table.insert(self.ramps, create({ name = "RampBridge", shape = "Block", size = Vector3.new((b - a).Magnitude + 0.3, BRIDGE_WIDTH, 1), color = Models.Colors.grey, material = "DiamondPlate" },
            cframe, complex))
        for _, edge in { -1, 1 } do
            table.insert(self.ramps, create({ name = "RampBridgeRail", shape = "Block", size = Vector3.new((b - a).Magnitude + 0.3, 0.6, BRIDGE_RAIL), color = dark, material = "Metal" },
                cframe * CFrame.new(0, edge * (BRIDGE_WIDTH / 2 - 0.3), 0.5 + BRIDGE_RAIL / 2), complex))
        end
    end
    self.bridges = {}
    for y = low.Y + BRIDGE_SPACING / 2, y1 - BRIDGE_WIDTH, BRIDGE_SPACING do
        for _, shift in { 0, 8, -8, 16, -16 } do
            local at = y + shift
            local y0b, y1b = at - BRIDGE_WIDTH / 2 - 1, at + BRIDGE_WIDTH / 2 + 1
            local top = math.max(surface, clearance(y0b, y1b, 0, inner) + 1 + BRIDGE_CLEAR)
            local lift = top - surface
            local run = math.min(inner - 1, math.max(BRIDGE_APPROACH, lift / math.tan(math.rad(BRIDGE_SLOPE))))
            -- The approach from the ramp edge (x = inner, surface) up to (inner - run, top):
            -- each eighth of it clears the hull under it at its low (outer) end.
            local fits = lift < 0.05 or math.atan2(lift, run) <= math.rad(BRIDGE_MAX_SLOPE)
            for step = 0, 7 do
                if not fits or lift < 0.05 then break end
                local x = inner - run * step / 8
                fits = clearance(y0b, y1b, x - run / 8, x) <= surface + lift * step / 8 - 1 - BRIDGE_CLEAR
            end
            if fits then
                if lift < 0.05 then
                    slab(Vector2.new(-inner, surface), Vector2.new(inner, surface), at)
                else
                    local inside = inner - run
                    slab(Vector2.new(-inside, top), Vector2.new(inside, top), at)
                    slab(Vector2.new(-inner, surface), Vector2.new(-inside, top), at)
                    slab(Vector2.new(inside, top), Vector2.new(inner, surface), at)
                end
                table.insert(self.bridges, { y = at, top = top })
                break
            end
        end
    end
    -- Posts under the ramps' outer edges only, so they never meet the rocket being built
    -- and tall ramps don't look like a fence.
    for y = low.Y + 10, y1, POST_SPACING do
        for _, x in { -outer + 0.5, outer - 0.5 } do
            local top = tilted * Vector3.new(x, y, surface - 1)
            local height = top.Y - self.origin.Y
            if height > 2 then
                table.insert(self.ramps, create({ name = "RampPost", shape = "Block", size = Vector3.new(1, height, 1), color = steel, material = "Metal" },
                    CFrame.new(top.X, self.origin.Y + height / 2, top.Z) * up, complex))
            end
        end
    end

    local vehicle = Instance.new("Model")
    vehicle.Name = "RocketVehicle"
    for _, item in items do
        item.part = create(item.spec, tilted * item.spec.cframe, vehicle)
        setGhost(item, true)
    end
    local cells = {}
    for order, spec in data.fuel do
        local cell = entry(spec, order)
        cell.weight = 1
        cell.part = create(spec, tilted * spec.cframe, vehicle)
        cell.part.Transparency, cell.part.CanCollide, cell.part.CastShadow = 1, false, false
        table.insert(cells, cell)
    end
    self.lists = { Metal = makeList(items), Fuel = makeList(cells) }
    vehicle.WorldPivot = tilted
    vehicle:SetAttribute("Tier", tier)
    vehicle:SetAttribute("Variant", variant)
    vehicle:SetAttribute("Height", data.height)
    vehicle:SetAttribute("Upright", self.origin)
    vehicle:SetAttribute("Hinge", self.origin * hinge)
    vehicle:SetAttribute("Tilt", Config.RocketTiltDegrees)
    complex.Parent, vehicle.Parent = self.site, self.site
    self.vehicle, self.data = vehicle, data
    return self.boarding.trigger.cframe, self.boarding.trigger.size
end

-- The boarding station follows the rocket's phase (CycleService.broadcast): the door
-- lights for boarding and its sign says what's needed first.
function Build:setBoardingPhase(phase)
    if self.boarding then self.boarding.setPhase(phase) end
end

-- buildFraction and fuelFraction are 0..1. Finished segments turn solid; the first
-- unfinished one grows a scrap (or glowing fuel) piece from its base.
function Build:setProgress(buildFraction, fuelFraction)
    local kind = "Metal"
    local item, amount = advance(self.lists.Metal, buildFraction, function(done) setGhost(done, false) end)
    if not item then
        kind = "Fuel"
        for _, cell in self.lists.Fuel.items do
            if cell.part.Transparency == 1 then cell.part.Transparency = 0 end
        end
        item, amount = advance(self.lists.Fuel, fuelFraction, lightCell)
    end
    if self.filling and self.filling.item ~= item then
        self.filling.part:Destroy()
        self.filling = nil
    end
    self.frontierItem, self.frontierAmount = item, amount
    if not item or amount <= 0 then return end
    if not self.filling then
        local part = shaped(item.spec, self.pivot * item.spec.cframe, self.vehicle)
        part.Name = "Filling"
        if kind == "Fuel" then
            part.Color, part.Material, part.CanCollide = FUEL_LIT, Enum.Material.Neon, false
        else
            part.Color, part.Material = SCRAP, Enum.Material.CorrodedMetal
        end
        self.filling = { item = item, part = part }
    end
    local size, cframe = partial(item, amount)
    self.filling.part.Size, self.filling.part.CFrame = size, self.pivot * cframe
end

-- Where material goes next: a ring around the whole rocket (on its axis) at the lowest
-- unfilled level, wide enough to clear every part at that height, and its diameter.
-- Material can be placed from any point around the ring, whichever part it fills.
function Build:frontier()
    local item = self.frontierItem
    if not item then return nil end
    local y = item.low.Y + (item.high.Y - item.low.Y) * self.frontierAmount
    local radius = 1.5
    for _, list in self.lists do
        for _, other in list.items do
            if other.low.Y <= y and other.high.Y >= y then
                radius = math.max(radius, -other.low.X, other.high.X, -other.low.Z, other.high.Z)
            end
        end
    end
    return self.pivot * CFrame.new(0, y, 0) * UPRIGHT, 2 * radius + 1.5
end

-- Whether a player at `position` can place: within `reach` of the frontier ring, or
-- standing on either ramp within `reach` of the fill line along the rocket. The wide
-- ramps sit beside the widest segment, which can be far outside the ring where the
-- rocket is narrow, so the ring alone would leave most of a ramp out of reach.
function Build:inPlaceReach(position, reach)
    local cframe, diameter = self:frontier()
    if not cframe then return false end
    local ring = cframe:PointToObjectSpace(position)
    local half = Vector3.new(0.2, diameter / 2, diameter / 2)
    local closest = Vector3.new(math.clamp(ring.X, -half.X, half.X), math.clamp(ring.Y, -half.Y, half.Y), math.clamp(ring.Z, -half.Z, half.Z))
    if (ring - closest).Magnitude <= reach then return true end
    -- In the ring frame X runs along the rocket, -Y is the rocket's X and Z its Z.
    local across, height = math.abs(ring.Y), ring.Z
    return math.abs(ring.X) <= reach and across >= self.rampInner - 1 and across <= self.rampOuter + 1
        and height >= self.rampSurface - 1 and height <= self.rampSurface + 8
end

-- True for points on the tilted rocket (the ramps are outside).
function Build:isAboard(position)
    local point, b = self.pivot:PointToObjectSpace(position), self.bounds
    return point.Y > b.low.Y - 2 and point.Y < b.high.Y + 4 and math.abs(point.X) < self.rampInner
        and point.Z > b.low.Z - 2 and point.Z < b.high.Z + 6
end

-- True for points on (or just over) either ramp or a bridge between them. On tall mounts
-- the ramps' plane (and the bridges in it) stands above the hull, out of isAboard's reach.
function Build:isOnRamps(position)
    local point = self.pivot:PointToObjectSpace(position)
    if math.abs(point.X) >= self.rampInner - 1 and math.abs(point.X) <= self.rampOuter + 1
        and point.Y < (self.rampTop or 0) + 4 and point.Z > self.rampSurface - 2 and point.Z < self.rampSurface + 9 then
        return true
    end
    for _, bridge in self.bridges or {} do
        if math.abs(point.X) < self.rampInner and math.abs(point.Y - bridge.y) <= BRIDGE_WIDTH / 2 + 1
            and point.Z > self.rampSurface - 2 and point.Z < bridge.top + 9 then
            return true
        end
    end
    return false
end

-- Swing the finished rocket upright about its hinge. Clients animate it; the server
-- snaps to the upright pose afterwards. The ramps (which lean at the build angle, so the
-- upright hull would seem to cut through them) retract first: they fade out and stop
-- colliding. The next load builds fresh ones.
function Build:erect(serverTime, seconds)
    local vehicle = self.vehicle
    if self.filling then self.filling.part:Destroy() end
    self.filling, self.frontierItem = nil, nil
    local fold = TweenInfo.new(math.min(seconds, 1.5), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    for _, piece in self.ramps do
        piece.CanCollide, piece.CanQuery = false, false
        for _, light in piece:GetChildren() do
            if light:IsA("Light") then light.Enabled = false end
        end
        TweenService:Create(piece, fold, { Transparency = 1 }):Play()
    end
    vehicle:SetAttribute("ErectSeconds", seconds)
    vehicle:SetAttribute("ErectAt", serverTime)
    task.delay(seconds, function()
        if self.vehicle ~= vehicle or not vehicle.Parent then return end
        vehicle:PivotTo(self.origin)
        self.pivot = self.origin
        -- The rocket stands complete: the boarding station appears in front of it.
        if self.boarding then self.boarding.reveal() end
    end)
end

-- Clients play ignition + ascent; the server rocket stays put until the next load.
-- `isFinal` (legendary missions) makes the launch bigger and louder.
function Build:launch(serverTime, tierDefinition, isFinal)
    local vehicle = self.vehicle
    vehicle:SetAttribute("LaunchSeconds", tierDefinition.LaunchSeconds)
    vehicle:SetAttribute("IgnitionSeconds", tierDefinition.IgnitionSeconds)
    vehicle:SetAttribute("ExhaustScale", tierDefinition.ExhaustScale * (isFinal and 1.3 or 1))
    vehicle:SetAttribute("SmokeScale", tierDefinition.SmokeScale * (isFinal and 1.5 or 1))
    vehicle:SetAttribute("Shake", tierDefinition.Shake * (isFinal and 1.5 or 1))
    vehicle:SetAttribute("Final", isFinal)
    vehicle:SetAttribute("LaunchAt", serverTime)
end

-- A finished copy of the launched rocket standing upright with its base on `ground`
-- (no launch mount under it there). Clients fly it down from the sky (LaunchEffects)
-- from the attributes given. It is shrunk back by Models.SiteScale: the Earth site's
-- rockets are built bigger than the destinations' grounds were laid out for.
function Build:landedCopy(ground, parent, attributes)
    local copy = self.vehicle:Clone()
    for name in copy:GetAttributes() do copy:SetAttribute(name, nil) end
    copy.Name = "LandedRocket"
    local shrink = 1 / Models.SiteScale
    copy:PivotTo(self.origin.Rotation)
    copy:ScaleTo(copy:GetScale() * shrink)
    copy:PivotTo(self.origin.Rotation + ground - Vector3.new(0, self.bounds.low.Y * shrink, 0))
    copy:SetAttribute("Height", (self.data.height - self.bounds.low.Y) * shrink)
    copy:SetAttribute("Ground", ground)
    for name, value in attributes do copy:SetAttribute(name, value) end
    copy.Parent = parent
    return copy
end

return Build
