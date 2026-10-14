local Hold = {}
Hold.__index = Hold
function Hold.new(duration)
    return setmetatable({ duration = duration, active = {} }, Hold)
end
function Hold:begin(id, target, cycle, now)
    self.active[id] = { target = target, cycle = cycle, started = now }
end
function Hold:ended(id, target)
    local entry = self.active[id]
    if entry and entry.target == target then self.active[id] = nil end
end
function Hold:cancel(id) self.active[id] = nil end
return Hold
