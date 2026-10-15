-- This module never yields: validation, spending and phase transition are atomic.
-- Phases: Building (Metal) -> Fueling (Fuel) -> Boarding -> Launching -> Rewarding -> Resetting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Missions = require(ReplicatedStorage.Shared.Missions)
local Rocket = {}
Rocket.__index = Rocket
-- The single material each delivery phase accepts.
Rocket.PhaseMaterial = table.freeze({ Building = "Metal", Fueling = "Fuel" })

-- `id` is a unique launch id (reward ledger key); `mission` is the Missions index;
-- `launches` counts this server's launches before this rocket.
function Rocket.new(config, id, mission, launches)
    local definition = Missions.get(mission or Missions.First)
    return setmetatable({
        config = config, cycle = id, mission = definition.Number, definition = definition,
        launches = launches or 0, phase = "Building",
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

-- The next rocket is the mission the wheel picked during the reward stay (the same
-- mission again if no spin happened).
function Rocket:nextCycle(id, mission)
    assert(self.phase == "Resetting", "Reset only after the launch sequence")
    return Rocket.new(self.config, id, mission or self.mission, self.launches + 1)
end

function Rocket:forget(userId)
    self.cargo[userId] = nil
    -- Keep a locked passenger's entitlement even after disconnect.
    if self.phase == "Boarding" then self.passengers[userId] = nil end
end

return Rocket
