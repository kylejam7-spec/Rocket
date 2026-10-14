local CargoVisual = {}

function CargoVisual.update(character, materials, colors)
    if not character then return end
    local previous = character:FindFirstChild("CarriedMaterials")
    if previous then previous:Destroy() end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not materials or not root then return end
    local count = (materials.Metal or 0) + (materials.Fuel or 0)
    if count == 0 then return end
    local radius = 0.85 * (count - 1) ^ (1 / 3)
    local center = Vector3.new(0, 0.3 + radius * 0.2, -2 - radius)
    local model = Instance.new("Model")
    model.Name = "CarriedMaterials"
    local index = 0
    for _, material in {"Metal", "Fuel"} do
        for _ = 1, materials[material] or 0 do
            index += 1
            local offset = Vector3.zero
            if index > 1 then
                local distance = 0.85 * (index - 1) ^ (1 / 3)
                local y = 1 - 2 * ((index * 0.61803398875) % 1)
                local angle = index * 2.39996322973
                local ring = math.sqrt(1 - y * y)
                offset = Vector3.new(math.cos(angle) * ring, y, math.sin(angle) * ring) * distance
            end
            local block = Instance.new("Part")
            block.Name = material
            block.Size = Vector3.new(1.5, 1.2, 1.5)
            block.Color = colors[material]
            block.CanCollide, block.CanTouch, block.CanQuery, block.Massless = false, false, false, true
            block.CFrame = root.CFrame * CFrame.new(center + offset)
                * CFrame.Angles(math.sin(index * 2) * 0.25, index * 2.39996322973, math.cos(index * 3) * 0.25)
            block.Parent = model
            local weld = Instance.new("WeldConstraint")
            weld.Part0, weld.Part1, weld.Parent = root, block, block
        end
    end
    model.Parent = character
end

return CargoVisual
