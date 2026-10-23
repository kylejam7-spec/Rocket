-- Strength and speed level math shared by the server (walk speed, carry) and the client
-- (HUD level, progress bar). Profiles store uncapped point totals; a level costs
-- Config.StatLevels points: base for level 1, x growth per level after, never more
-- than max (rounded to 5), so early levels come fast and every later one costs the same.
local StatLevels = {}

-- Unrounded costs pass max after a few dozen levels; past that every level costs max.
local cumulative, capFrom, built
local function build(curve)
    if built == curve then return end
    built, cumulative = curve, { [0] = 0 }
    local level = 0
    while true do
        level += 1
        local cost = math.min(curve.max, math.max(5, math.round(curve.base * curve.growth ^ (level - 1) / 5) * 5))
        cumulative[level] = cumulative[level - 1] + cost
        if cost >= curve.max then capFrom = level; break end
    end
end

-- Points needed to go from level - 1 to `level`.
function StatLevels.cost(config, level)
    local curve = config.StatLevels
    build(curve)
    if level >= capFrom then return curve.max end
    return cumulative[level] - cumulative[level - 1]
end

-- Total points that reach `level`.
function StatLevels.total(config, level)
    build(config.StatLevels)
    if level <= capFrom then return cumulative[level] end
    return cumulative[capFrom] + (level - capFrom) * config.StatLevels.max
end

-- Level for `points`, plus the points into the next level and that level's cost.
function StatLevels.level(config, points)
    local curve = config.StatLevels
    build(curve)
    local level
    if points >= cumulative[capFrom] then
        level = capFrom + math.floor((points - cumulative[capFrom]) / curve.max)
    else
        level = 0
        while cumulative[level + 1] <= points do level += 1 end
    end
    return level, points - StatLevels.total(config, level), StatLevels.cost(config, level + 1)
end

-- Carry capacity at a strength level: a flat amount per level, uncapped.
function StatLevels.capacity(config, level)
    return config.BaseCarryCapacity + config.CarryPerLevel * level
end

-- Walk speed at a speed level: big early steps, then a steady climb to MaxSpeed.
function StatLevels.walk(config, level)
    local walk = config.BaseSpeed + config.SpeedEarly * level / (level + config.SpeedHalfLevel) + config.SpeedPerLevel * level
    return math.min(config.MaxSpeed, walk)
end

return StatLevels
