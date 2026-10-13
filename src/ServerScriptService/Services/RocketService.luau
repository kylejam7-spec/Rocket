-- This module never yields: validation, spending and phase transition are atomic.
local Rocket = {}
Rocket.__index = Rocket

function Rocket.new(config, id)
    local self = setmetatable({ config = config, cycle = id, phase = "Building", totals = {}, cargo = {}, contributions = {}, passengers = {} }, Rocket)
    for material in config.Materials do self.totals[material] = 0 end
    return self
end

function Rocket:pickup(userId, material, capacity)
    if self.phase ~= "Building" or type(material) ~= "string" or not self.config.Materials[material] then return false end
    if self.totals[material] >= self.config.Materials[material] then return false end
    local cargo = self.cargo[userId]
    if cargo and (cargo.material ~= material or cargo.count >= capacity) then return false end
    self.cargo[userId] = { material = material, count = (cargo and cargo.count or 0) + 1 }
    return true
end

function Rocket:deliver(userId)
    if self.phase ~= "Building" then return 0 end
    local cargo = self.cargo[userId]
    if not cargo then return 0 end
    local accepted = math.min(cargo.count, self.config.Materials[cargo.material] - self.totals[cargo.material])
    if accepted <= 0 then return 0 end
    self.totals[cargo.material] += accepted
    cargo.count -= accepted
    if cargo.count == 0 then self.cargo[userId] = nil end
    self.contributions[userId] = (self.contributions[userId] or 0) + accepted
    local complete = true
    for material, required in self.config.Materials do
        if self.totals[material] < required then complete = false end
    end
    if complete then self.phase = "Boarding" end
    return accepted
end

function Rocket:lockPassengers(eligible)
    if self.phase ~= "Boarding" then return false end
    self.passengers = table.clone(eligible)
    self.phase = "Launching"
    return true
end

function Rocket:forget(userId)
    self.cargo[userId] = nil
    -- Keep a locked passenger's entitlement even after disconnect.
    if self.phase == "Boarding" then self.passengers[userId] = nil end
end

return Rocket
