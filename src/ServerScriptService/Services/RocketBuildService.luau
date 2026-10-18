-- Instantiates one rocket tier on the pad, tilted between two climbing ramps, and fills
-- it lowest-point-first as material arrives. Material totals stay numeric in
-- RocketService; this maps fractions to anchored segments plus one growing "Filling"
-- part, so an 8,250-unit rocket is still ~100-200 parts.
-- Erecting and the ascent are animated by each client (LaunchEffects) from attributes.
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Models = require(script.Parent.RocketModels)
local GHOST_COLOR, GHOST_TRANSPARENCY = Color3.fromRGB(150, 200, 255), 0.86
local FUEL_LIT = Color3.fromRGB(255, 150, 40)
local SCRAP = Color3.fromRGB(125, 118, 108)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- Each ramp is at least RAMP_MIN_WIDTH wide, so a full 50-player server can climb, pass
-- and stand along the fill line at once. The outer edge stays RAMP_PAST_MOUNT beyond the
-- launch mount, inside the floodlights.
local RAMP_MIN_WIDTH, RAMP_PAST_MOUNT, ARM_WIDTH, ARM_SPACING = 14, 11, 4, 30
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
    self.filling, self.frontierItem, self.arms = nil, nil, {}
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

    -- Bounds of this variant's rocket decide the hinge, ramp and arms.
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
    for _, side in { -1, 1 } do
        create({ name = "LaunchRamp", shape = "Block", size = Vector3.new(rampWidth, y1 - y0, 1), color = steel, material = "DiamondPlate" },
            tilted * CFrame.new(side * rampX, (y0 + y1) / 2, surface - 0.5), complex)
        create({ name = "RampRail", shape = "Block", size = Vector3.new(0.6, y1 - y0, 1.4), color = dark, material = "Metal" },
            tilted * CFrame.new(side * (outer - 0.3), (y0 + y1) / 2, surface + 0.2), complex)
        create({ name = "RampBeacon", shape = "Block", size = Vector3.new(1.5, 1, 1.5), color = Color3.fromRGB(255, 70, 60), material = "Neon",
            light = { color = Color3.fromRGB(255, 80, 60), range = 24, brightness = 2 } },
            tilted * CFrame.new(side * rampX, y1, surface + 0.75), complex)
    end
    local up = self.origin.Rotation
    for y = low.Y + 10, y1, ARM_SPACING do
        -- Level bridges over the core's top ridge at ramp height, joining both ramps' inner edges.
        local center = tilted * Vector3.new(0, y, surface)
        local arm = create({ name = "RampArm", shape = "Block", size = Vector3.new(2 * inner + 2, 1, ARM_WIDTH), color = Models.Colors.grey, material = "Metal" },
            CFrame.new(center.X, center.Y - 0.5, center.Z) * up, complex)
        table.insert(self.arms, arm)
        -- Posts under every other arm, on the outer edges only, so they never hide the
        -- rocket being built and tall ramps don't look like a fence.
        for _, x in (#self.arms % 2 == 1 and { -outer + 0.5, outer - 0.5 } or {}) do
            local top = tilted * Vector3.new(x, y, surface - 1)
            local height = top.Y - self.origin.Y
            if height > 2 then
                create({ name = "RampPost", shape = "Block", size = Vector3.new(1, height, 1), color = steel, material = "Metal" },
                    CFrame.new(top.X, self.origin.Y + height / 2, top.Z) * up, complex)
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
    return self.origin * data.boarding.cframe, data.boarding.size
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

-- True for points on the tilted rocket or the arms over it (the ramps are outside).
function Build:isAboard(position)
    local point, b = self.pivot:PointToObjectSpace(position), self.bounds
    return point.Y > b.low.Y - 2 and point.Y < b.high.Y + 4 and math.abs(point.X) < self.rampInner
        and point.Z > b.low.Z - 2 and point.Z < b.high.Z + 6
end

-- Swing the finished rocket upright about its hinge. Clients animate it; the server
-- snaps to the upright pose afterwards. The arms retract so the hull clears them.
function Build:erect(serverTime, seconds)
    local vehicle = self.vehicle
    if self.filling then self.filling.part:Destroy() end
    self.filling, self.frontierItem = nil, nil
    for _, arm in self.arms do
        arm.CanCollide, arm.CanQuery = false, false
        TweenService:Create(arm, reveal, { Transparency = 1 }):Play()
    end
    vehicle:SetAttribute("ErectSeconds", seconds)
    vehicle:SetAttribute("ErectAt", serverTime)
    task.delay(seconds, function()
        if self.vehicle ~= vehicle or not vehicle.Parent then return end
        vehicle:PivotTo(self.origin)
        self.pivot = self.origin
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
-- from the attributes given.
function Build:landedCopy(ground, parent, attributes)
    local copy = self.vehicle:Clone()
    for name in copy:GetAttributes() do copy:SetAttribute(name, nil) end
    copy.Name = "LandedRocket"
    copy:PivotTo(self.origin.Rotation + ground - Vector3.new(0, self.bounds.low.Y, 0))
    copy:SetAttribute("Height", self.data.height - self.bounds.low.Y)
    copy:SetAttribute("Ground", ground)
    for name, value in attributes do copy:SetAttribute(name, value) end
    copy.Parent = parent
    return copy
end

return Build
