return function()
    local visual = require(script.Parent.CargoVisualService)
    local config = require(game.ReplicatedStorage.Shared.Config)
    local character = Instance.new("Model")
    local root = Instance.new("Part")
    root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, character
    local colors = {Metal = Color3.fromRGB(139, 166, 185), Fuel = Color3.fromRGB(245, 182, 71)}
    local previous = 0
    for _, count in {1, 2, 5, 10, 25, 100, 250, 1000} do
        visual.update(character, {Metal = count}, colors)
        local model = assert(character:FindFirstChild("CarriedMaterials"))
        local ball = assert(model:FindFirstChild("ScrapBall"))
        assert(ball.Shape == Enum.PartType.Ball and ball.Size.X == ball.Size.Y)
        assert(ball.Size.X > previous and ball.Size.X <= config.ScrapBallMaxDiameter, "Ball grows with cargo, up to the cap")
        previous = ball.Size.X
        local weld = assert(ball:FindFirstChild("Weld"))
        assert(weld.Part0 == root and weld.C0.Y - ball.Size.Y / 2 >= 2.39, "Ball sits overhead")
        for _, part in model:GetChildren() do
            assert(not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Massless)
        end
    end
    assert(visual.diameter(10) == config.ScrapBallBaseDiameter, "Base carry gives the base diameter")
    assert(visual.diameter(1e6) == config.ScrapBallMaxDiameter, "Huge loads hit the cap")
    local ball = character.CarriedMaterials.ScrapBall
    visual.update(character, {Metal = 3}, colors)
    assert(character.CarriedMaterials.ScrapBall == ball and ball.Size.X < previous, "Pouring shrinks the same ball")
    visual.update(character, {Fuel = 5}, colors)
    assert(character.CarriedMaterials:GetAttribute("Kind") == "Fuel", "Fuel swaps to a jerry can")
    local can = assert(character.CarriedMaterials:FindFirstChild("JerryCan"), "Fuel is carried as a jerry can")
    assert(not character.CarriedMaterials:FindFirstChild("ScrapBall"))
    local small = can.Size.Y
    visual.update(character, {Fuel = 200}, colors)
    assert(character.CarriedMaterials.JerryCan == can and can.Size.Y > small, "The jerry can grows with the load")
    assert(can.Weld.C0.Y - can.Size.Y / 2 >= 2.39, "Jerry can sits overhead")
    for _, part in character.CarriedMaterials:GetChildren() do
        assert(not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Massless)
    end
    visual.update(character, nil, colors)
    assert(not character:FindFirstChild("CarriedMaterials"), "Clearing must remove the ball")
    visual.update(character, {Metal = 0, Fuel = 0}, colors)
    assert(not character:FindFirstChild("CarriedMaterials"))
    character:Destroy()
    -- Stations: right behind spawn (z = 32..40), short of the Gym District (z >= 160) and the
    -- road between them (x = -8..8), on the ground, and never paved over.
    local stations = require(script.Parent.MaterialStationService)
    local map = require(script.Parent.MapExpansionService)
    for _, rect in stations.Reserved do
        assert(rect.x1 - rect.x0 >= 60 and rect.z1 - rect.z0 >= 60, "Stations are big enough for a full server")
        assert(rect.z0 >= 44 and rect.z0 <= 60, "Stations sit right behind spawn")
        assert(rect.x0 >= 8 or rect.x1 <= -8, "Stations leave the road between them clear")
        assert(rect.x0 >= -120 and rect.x1 <= 120 and rect.z1 <= 160, "Stations sit on the ground")
        for _, piece in map.carve({ x0 = -500, x1 = 500, z0 = -400, z1 = 200 }, stations.Reserved) do
            assert(piece.x0 >= rect.x1 or piece.x1 <= rect.x0 or piece.z0 >= rect.z1 or piece.z1 <= rect.z0,
                "Map expansion must not cover a station")
        end
    end
    local area = 0
    for _, piece in map.carve({ x0 = 0, x1 = 100, z0 = 0, z1 = 100 }, { { x0 = 20, x1 = 40, z0 = 30, z1 = 60 } }) do
        area += (piece.x1 - piece.x0) * (piece.z1 - piece.z0)
    end
    assert(area == 100 * 100 - 20 * 30, "Carving removes exactly the hole")
    return "Cargo checks passed: overhead scrap ball and jerry can grow to a cap, shrink in place, swap, clear, never collide; stations are clear of gyms and expansion"
end
