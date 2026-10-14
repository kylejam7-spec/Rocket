-- This module never yields: validation, spending and phase transition are atomic.
-- Phases: Building (Metal) -> Fueling (Fuel) -> Boarding -> Launching -> Rewarding -> Resetting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cycles = require(ReplicatedStorage.Shared.RocketCycles)
local Rocket = {}
Rocket.__index = Rocket
-- The single material each delivery phase accepts.
Rocket.PhaseMaterial = table.freeze({ Building = "Metal", Fueling = "Fuel" })

-- `id` is a unique launch id (reward ledger key); `cycleNumber` is the 1..15 server cycle.
function Rocket.new(config, id, cycleNumber, programRuns)
    local definition = Cycles.get(cycleNumber or 1)
    return setmetatable({
        config = config, cycle = id, cycleNumber = definition.Number, definition = definition,
        programRuns = programRuns or 0, phase = "Building",
        totals = { Metal = 0, Fuel = 0 },
        required = { Metal = definition.ConstructionRequired, Fuel = definition.FuelRequired },
        cargo = {}, contributions = {}, passengers = {},
    }, Rocket)
end

function Rocket:progress(material)
    return math.clamp(self.totals[material] / self.required[material], 0, 1)
end

-- Fills cargo toward capacity, at most `limit` units (default: all); returns the amount picked up.
function Rocket:pickup(userId, material, capacity, limit)
    if Rocket.PhaseMaterial[self.phase] ~= material then return 0 end
    local cargo = self.cargo[userId] or { count = 0, materials = {} }
    local amount = math.max(0, math.min(capacity - cargo.count, self.required[material] - self.totals[material], limit or math.huge))
    if amount == 0 then return 0 end
    cargo.count += amount
    cargo.materials[material] = (cargo.materials[material] or 0) + amount
    self.cargo[userId] = cargo
    return amount
end

-- Deposits matching cargo, at most `limit` units (default: all).
-- Returns accepted units and whether the phase advanced.
function Rocket:deliver(userId, limit)
    local material = Rocket.PhaseMaterial[self.phase]
    local cargo = self.cargo[userId]
    if not material or not cargo then return 0, false end
    local amount = math.min(cargo.materials[material] or 0, self.required[material] - self.totals[material], limit or math.huge)
    if amount <= 0 then return 0, false end
    self.totals[material] += amount
    cargo.materials[material] -= amount
    cargo.count -= amount
    if cargo.count == 0 then self.cargo[userId] = nil end
    self.contributions[userId] = (self.contributions[userId] or 0) + amount
    if self.totals[material] < self.required[material] then return amount, false end
    -- Leftover cargo of the finished material is useless now; drop it.
    for id, held in self.cargo do
        held.count -= held.materials[material] or 0
        held.materials[material] = nil
        if held.count <= 0 then self.cargo[id] = nil end
    end
    self.phase = self.phase == "Building" and "Fueling" or "Boarding"
    return amount, true
end

function Rocket:lockPassengers(eligible)
    if self.phase ~= "Boarding" then return false end
    self.passengers = table.clone(eligible)
    self.phase = "Launching"
    return true
end

-- Only a locked, nonempty passenger list counts as a successful blast off and
-- advances the server cycle; after the final cycle the program restarts at 1.
function Rocket:nextCycle(id)
    assert(self.phase == "Resetting", "Reset only after the launch sequence")
    if not next(self.passengers) then return Rocket.new(self.config, id, self.cycleNumber, self.programRuns) end
    local final = self.definition.IsFinalCycle
    return Rocket.new(self.config, id, Cycles.next(self.cycleNumber), self.programRuns + (final and 1 or 0))
end

function Rocket:forget(userId)
    self.cargo[userId] = nil
    -- Keep a locked passenger's entitlement even after disconnect.
    if self.phase == "Boarding" then self.passengers[userId] = nil end
end

return Rocket
