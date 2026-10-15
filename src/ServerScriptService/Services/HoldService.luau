-- Server-side "material button held" state. While held, the player transfers at
-- whichever material target they are in range of, so E can stay down for a whole
-- grab, place, grab, place loop. A target that refuses (cargo full, nothing left to
-- place) is skipped until the player leaves its range.
local Hold = {}
Hold.__index = Hold
function Hold.new(duration)
    return setmetatable({ duration = duration, active = {} }, Hold)
end
-- `ready` is the earliest next transfer; returns false if already held.
function Hold:press(id, cycle, ready)
    if self.active[id] then return false end
    self.active[id] = { cycle = cycle, nextAt = ready, spent = {} }
    return true
end
function Hold:release(id) self.active[id] = nil end
-- One tick: `near(target)` says whether the player is in range of a target. Returns
-- the first usable target if a transfer is due now (booking the next one), else nil.
function Hold:pick(entry, now, targets, near)
    local current
    for _, target in targets do
        if not near(target) then
            entry.spent[target] = nil
        elseif not current and not entry.spent[target] then
            current = target
        end
    end
    if not current or now < entry.nextAt then return nil end
    -- Catch up at most one missed tick so a stalled frame can't burst transfers.
    entry.nextAt = math.max(entry.nextAt + self.duration, now)
    return current
end
function Hold:refused(entry, target) entry.spent[target] = true end
return Hold
