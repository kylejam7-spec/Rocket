-- Map space grows every three cycles; rocket construction remains separate.
local Map = {}
function Map.build(part, label)
    local grass = Color3.fromRGB(62, 103, 72)
    local concrete = Color3.fromRGB(81, 91, 107)
    local paint = Color3.fromRGB(245, 182, 71)
    part("Ground", Vector3.new(0, -1, -45), Vector3.new(240, 2, 230), grass)
    part("LaunchApron", Vector3.new(0, -0.17, -110), Vector3.new(160, 0.5, 100), concrete)
    local sign = part("ExpansionSign", Vector3.new(0, 0.1, 60), Vector3.new(12, 0.2, 4), paint)
    label(sign, "SPACEPORT • New construction bays every 3 cycles")
    -- Flat markings leave the cabin entrance and future boosters unobstructed.
    for _, z in {-160, -60} do
        part("ApronMarking", Vector3.new(0, 0.10, z), Vector3.new(160, 0.04, 1), paint).CanCollide = false
    end
    local stage = 0
    return function(cycle)
        local target = math.floor((cycle - 1) / 3)
        for index = stage + 1, target do
            for _, side in {-1, 1} do
                part("ExpansionGround" .. index .. "_" .. side,
                    Vector3.new(side * (80 + index * 80), -1, -45), Vector3.new(80, 2, 230), grass)
                local bay = part("ConstructionBay" .. index .. "_" .. side,
                    Vector3.new(side * (40 + index * 80), -0.17, -110), Vector3.new(80, 0.5, 100), concrete)
                label(bay, "EXPANSION " .. index .. " • Booster / rocket space")
                for _, z in {-160, -60} do
                    part("BayMarking", Vector3.new(bay.Position.X, 0.10, z),
                        Vector3.new(80, 0.04, 1), paint).CanCollide = false
                end
            end
            if index % 10 == 0 then task.wait() end
        end
        stage = math.max(stage, target)
    end
end
return Map
