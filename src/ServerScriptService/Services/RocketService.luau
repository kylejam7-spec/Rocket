-- This module never yields: validation, spending and phase transition are atomic.
local Rocket = {}
Rocket.__index = Rocket

function Rocket.new(config, id, successfulLaunches)
    local self = setmetatable({ config = config, cycle = id, phase = "Building", totals = {}, cargo = {}, contributions = {}, passengers = {}, placedSlots = {} }, Rocket)
    self.successfulLaunches = successfulLaunches or 0
    self.slotCost = 1 + self.successfulLaunches * (config.MaterialsPerSlotPerLaunch or 1)
    self.required, self.slotProgress = {}, {}
    for material, base in config.Materials do
        self.totals[material] = 0
        self.required[material] = base * self.slotCost
    end
    return self
end

function Rocket:pickup(userId, material, capacity)
    if self.phase ~= "Building" or type(material) ~= "string" or not self.required[material] then return false end
    if self.totals[material] >= self.required[material] then return false end
    local cargo = self.cargo[userId]
    if cargo and cargo.count >= capacity then return false end
    cargo = cargo or { count = 0, materials = {} }
    cargo.count += 1
    cargo.materials[material] = (cargo.materials[material] or 0) + 1
    self.cargo[userId] = cargo
    return true
end

function Rocket:deliver(userId)
    if self.phase ~= "Building" then return 0 end
    local cargo = self.cargo[userId]
    if not cargo then return 0 end
    local accepted = 0
    for material, count in cargo.materials do
        local amount = math.min(count, self.required[material] - self.totals[material])
        self.totals[material] += amount
        cargo.materials[material] -= amount
        cargo.count -= amount
        accepted += amount
    end
    if cargo.count == 0 then self.cargo[userId] = nil end
    self.contributions[userId] = (self.contributions[userId] or 0) + accepted
    for material, required in self.required do
        if self.totals[material] < required then return accepted end
    end
    self.phase = "Boarding"
    return accepted
end

-- A slot is spent once, in the same non-yielding transaction as its cargo.
function Rocket:place(userId, slotId, material)
    if self.phase ~= "Building" or self.placedSlots[slotId] or not self.required[material] then return 0 end
    local cargo = self.cargo[userId]
    if not cargo or (cargo.materials[material] or 0) < 1 or self.totals[material] >= self.required[material] then return 0 end
    self.slotProgress[slotId] = (self.slotProgress[slotId] or 0) + 1
    self.placedSlots[slotId] = self.slotProgress[slotId] >= self.slotCost
    self.totals[material] += 1
    cargo.materials[material] -= 1
    cargo.count -= 1
    if cargo.count == 0 then self.cargo[userId] = nil end
    self.contributions[userId] = (self.contributions[userId] or 0) + 1
    for key, required in self.required do
        if self.totals[key] < required then return 1 end
    end
    self.phase = "Boarding"
    return 1
end
function Rocket:lockPassengers(eligible)
    if self.phase ~= "Boarding" then return false end
    self.passengers = table.clone(eligible)
    self.phase = "Launching"
    return true
end

-- Only a locked, nonempty passenger list counts as a successful blast off.
function Rocket:nextCycle(id)
    assert(self.phase == "Resetting", "Reset only after the launch sequence")
    local successes = self.successfulLaunches + (next(self.passengers) and 1 or 0)
    return Rocket.new(self.config, id, successes)
end
function Rocket:forget(userId)
    self.cargo[userId] = nil
    -- Keep a locked passenger's entitlement even after disconnect.
    if self.phase == "Boarding" then self.passengers[userId] = nil end
end

return Rocket
