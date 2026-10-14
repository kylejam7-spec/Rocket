return function()
    local visual = require(script.Parent.CargoVisualService)
    local character = Instance.new("Model")
    local root = Instance.new("Part")
    root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, character
    local colors = {Metal = Color3.fromRGB(139, 166, 185), Fuel = Color3.fromRGB(245, 182, 71)}
    local previousRadius = -1
    for _, count in {1, 2, 5, 10, 25, 100} do
        visual.update(character, {Metal = math.ceil(count / 2), Fuel = math.floor(count / 2)}, colors)
        local model = assert(character:FindFirstChild("CarriedMaterials"))
        assert(#model:GetChildren() == count, "Every held item must be visible")
        local radius = 0.85 * (count - 1) ^ (1 / 3)
        local center = Vector3.new(0, 0.3 + radius * 0.2, -2 - radius)
        local outer = 0
        for _, block in model:GetChildren() do
            local position = root.CFrame:PointToObjectSpace(block.Position)
            outer = math.max(outer, (position - center).Magnitude)
            assert(position.Z <= -1.99, "Cargo must stay in front")
            assert(not block.CanCollide and not block.CanTouch and not block.CanQuery and block.Massless)
            local weld = assert(block:FindFirstChildOfClass("WeldConstraint"))
            assert(weld.Part0 == root and weld.Part1 == block)
        end
        assert(outer > previousRadius, "Mass must expand with more cargo")
        previousRadius = outer
    end
    visual.update(character, {Metal = 1}, colors)
    assert(#character.CarriedMaterials:GetChildren() == 1, "Delivery must shrink the mass")
    visual.update(character, nil, colors)
    assert(not character:FindFirstChild("CarriedMaterials"), "Clearing must remove the mass")
    visual.update(character, {Metal = 0, Fuel = 0}, colors)
    assert(not character:FindFirstChild("CarriedMaterials"))
    character:Destroy()
    return "Cargo checks passed: mixed materials, growth 1–100, shrinking, clearing, welds, and collisions"
end