-- Pets and UFOs: the catalog's tiers (14/12/10/8/6, every rarity mixing all three
-- forms), UFO times and odds, the roll's long-run shares, the purchase rule, the
-- play-time countdown and hatch, equipping, the v7 profile, and the models.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local config = require(ReplicatedStorage.Shared.Config)
    local Pets = require(ReplicatedStorage.Shared.Pets)
    local PetModels = require(ReplicatedStorage.Shared.PetModels)
    local Service = require(script.Parent.PetService)
    local Profiles = require(script.Parent.ProfileService)

    -- Catalog: 50 unique pets, one per FBX (form + model), tiered 14/12/10/8/6, each
    -- with its own name.
    assert(#Pets.Catalog == 50, "catalog has " .. #Pets.Catalog)
    local perRarity, perForm, models, names = {}, {}, {}, {}
    for _, entry in Pets.Catalog do
        assert(not names[entry.Name], "two pets are called " .. entry.Name)
        names[entry.Name] = true
        assert(Pets.get(entry.Id) == entry and entry.Id == entry.Form .. "_" .. entry.Model)
        assert(not models[entry.Id], "two pets share " .. entry.Id)
        models[entry.Id] = true
        perRarity[entry.Rarity] = perRarity[entry.Rarity] or {}
        perRarity[entry.Rarity][entry.Form] = (perRarity[entry.Rarity][entry.Form] or 0) + 1
        perForm[entry.Form] = (perForm[entry.Form] or 0) + 1
    end
    assert(perForm.Blob == 17 and perForm.Large == 16 and perForm.Flying == 17, "forms don't match the three FBX folders")
    for rank, count in { 14, 12, 10, 8, 6 } do
        local rarity = Pets.Rarities[rank]
        assert(#Pets.ByRarity[rarity] == count, rarity .. " has " .. #Pets.ByRarity[rarity])
        for _, form in Pets.Forms do assert((perRarity[rarity][form] or 0) > 0, rarity .. " has no " .. form .. " pet") end
    end

    -- UFOs: 5 to 25 minutes in 5-minute steps; the agreed odds; Epic and Legendary
    -- aren't sold for coins.
    for tier, ufo in Pets.Ufos do
        assert(ufo.Minutes == tier * 5 and ufo.Seconds == ufo.Minutes * 60)
        assert((ufo.Price ~= nil) == (tier <= 3), ufo.Name .. " price")
    end
    local function same(odds, want)
        for rarity, percent in want do if odds[rarity] ~= percent then return false end end
        for rarity in odds do if not want[rarity] then return false end end
        return true
    end
    assert(same(Pets.Ufos[1].Odds, { Common = 80, Uncommon = 20 }))
    assert(same(Pets.Ufos[2].Odds, { Uncommon = 90, Rare = 10 }))
    assert(same(Pets.Ufos[3].Odds, { Rare = 95, Epic = 5 }))

    -- Rolls: only the tier's rarities, at its odds (±1.5 points over 20,000 rolls), and
    -- every pet of a rarity turns up.
    local random = Random.new(7)
    for tier, ufo in Pets.Ufos do
        local shares, seen, rolls = {}, {}, 20000
        for _ = 1, rolls do
            local entry = Pets.get(Pets.roll(random, tier))
            assert(ufo.Odds[entry.Rarity], ufo.Name .. " rolled a " .. entry.Rarity)
            shares[entry.Rarity] = (shares[entry.Rarity] or 0) + 1
            seen[entry.Id] = true
        end
        for rarity, percent in ufo.Odds do
            local got = 100 * (shares[rarity] or 0) / rolls
            assert(math.abs(got - percent) <= 1.5, ("%s: %s %.1f%% (want %d%%)"):format(ufo.Name, rarity, got, percent))
            for _, id in Pets.ByRarity[rarity] do assert(seen[id], ufo.Name .. " never rolled " .. id) end
        end
    end

    -- Purchases: coins only, one UFO at a time, once per request ID; the pet is rolled
    -- then and kept on the profile.
    local profile = Profiles.validate(nil, config)
    assert(profile.schemaVersion == 7 and next(profile.pets) == nil and #profile.equippedPets == 0 and profile.ufo == nil)
    assert(select(2, Service.buy(profile, 1, "a", random)) == "not enough coins")
    profile.coins = 600
    assert(Service.buy(profile, 0, "a", random) == nil and Service.buy(profile, "1", "a", random) == nil)
    assert(Service.buy(profile, 1, "", random) == nil and Service.buy(profile, 1, string.rep("x", 65), random) == nil)
    assert(select(2, Service.buy(profile, 4, "a", random)) == "robux only" and select(2, Service.buy(profile, 5, "a", random)) == "robux only")
    assert(Service.buy(profile, 1, "a", random) == 500 and profile.coins == 100)
    assert(profile.ufo and profile.ufo.tier == 1 and profile.ufo.remaining == 300 and Pets.get(profile.ufo.pet))
    assert(Service.buy(profile, 1, "a", random) == 0 and profile.coins == 100, "retry charged twice")
    profile.coins = 1e6
    assert(select(2, Service.buy(profile, 2, "b", random)) == "busy" and profile.coins == 1e6)

    -- Countdown and landing: the rolled pet is added and equipped.
    local rolled = profile.ufo.pet
    assert(Service.advance(profile, 299) == nil and profile.ufo.remaining == 1)
    local id, equipped = Service.advance(profile, 5)
    assert(id == rolled and equipped and profile.ufo == nil and profile.pets[rolled] == 1 and profile.equippedPets[1] == rolled)
    assert(Service.advance(profile, 5) == nil)
    -- Slots fill to Pets.MaxEquipped; later pets go to the inventory only.
    for index = 1, 3 do
        assert(Service.buy(profile, 3, "c" .. index, random) == 50000)
        local _, put = Service.advance(profile, 900)
        assert(put == (index <= Pets.MaxEquipped - 1), "equip slot " .. index)
    end
    assert(#profile.equippedPets == Pets.MaxEquipped)

    -- Equipping: owned copies only, at most MaxEquipped.
    local fresh = Profiles.validate(nil, config)
    assert(select(2, Service.equip(fresh, "Nope", true)) == "unknown pet")
    assert(select(2, Service.equip(fresh, "Blob_Cat", true)) == "not owned")
    fresh.pets = { Blob_Cat = 2, Flying_Dragon = 1, Large_Yeti = 1 }
    assert(Service.equip(fresh, "Blob_Cat", true) and Service.equip(fresh, "Blob_Cat", true))
    assert(select(2, Service.equip(fresh, "Blob_Cat", true)) == "not owned", "equipped a third copy of two")
    assert(Service.equip(fresh, "Flying_Dragon", true))
    assert(select(2, Service.equip(fresh, "Large_Yeti", true)) == "full")
    assert(Service.equip(fresh, "Blob_Cat", false) and #fresh.equippedPets == 2)
    assert(select(2, Service.equip(fresh, "Large_Yeti", false)) == "not equipped")
    assert(select(2, Service.equip(fresh, "*", true)) == "unknown pet", "\"*\" only unequips")
    assert(Service.equip(fresh, "*", false) and #fresh.equippedPets == 0 and fresh.pets.Blob_Cat == 2)
    assert(select(2, Service.equip(fresh, "*", false)) == "not equipped")
    fresh.pets.Blob_Cat = Pets.MaxCount
    Service.grant(fresh, "Blob_Cat")
    assert(fresh.pets.Blob_Cat == Pets.MaxCount)

    -- Profiles: v6 gains empty pets; pets round-trip; bad data is refused, retired pets
    -- and equips of pets not owned are dropped.
    local v6 = Profiles.validate(nil, config)
    v6.schemaVersion, v6.pets, v6.equippedPets = 6, nil, nil
    local migrated = Profiles.validate(v6, config)
    assert(migrated.schemaVersion == 7 and next(migrated.pets) == nil and #migrated.equippedPets == 0 and migrated.ufo == nil)
    local saved = Profiles.validate(profile, config)
    assert(Profiles.samePets(saved, profile) and saved.pets ~= profile.pets, "pets didn't round-trip as a copy")
    local function bad(change)
        local raw = Profiles.validate(nil, config)
        change(raw)
        return not pcall(Profiles.validate, raw, config)
    end
    assert(bad(function(raw) raw.pets = { Blob_Cat = 0 } end) and bad(function(raw) raw.pets = { Blob_Cat = 1.5 } end))
    assert(bad(function(raw) raw.pets = { [1] = 1 } end) and bad(function(raw) raw.equippedPets = { 1 } end))
    assert(bad(function(raw) raw.equippedPets = { "a", "b", "c", "d" } end))
    assert(bad(function(raw) raw.ufo = { tier = 9, pet = "Blob_Cat", remaining = 1 } end))
    assert(bad(function(raw) raw.ufo = { tier = 1, pet = "Blob_Cat", remaining = -1 } end))
    local odd = Profiles.validate(nil, config)
    odd.pets = { Blob_Cat = 1, Retired_Pet = 2 }
    odd.equippedPets = { "Blob_Cat", "Blob_Cat", "Retired_Pet" }
    odd = Profiles.validate(odd, config)
    assert(odd.pets.Retired_Pet == nil and #odd.equippedPets == 1 and odd.equippedPets[1] == "Blob_Cat")
    local a, b = Profiles.validate(saved, config), Profiles.validate(saved, config)
    b.ufo = { tier = 1, pet = "Blob_Cat", remaining = 10 }
    a.ufo = { tier = 1, pet = "Blob_Cat", remaining = 5 }
    assert(Profiles.samePets(a, b), "countdown alone counted as a pet change")
    b.pets.Blob_Cat = (b.pets.Blob_Cat or 0) + 1
    assert(not Profiles.samePets(a, b))

    -- Models: every pet is pet-sized for its form (Blob span, Large height, Flying
    -- wingspan) with its pivot at its feet, and only decor parts. Imported pets (all 50
    -- once ReplicatedStorage.PetModels is in) carry Idle and Move clips that pose them.
    local PetAnimator = require(ReplicatedStorage.Shared.PetAnimator)
    local imported = ReplicatedStorage:FindFirstChild("PetModels")
    for _, entry in Pets.Catalog do
        local model = PetModels.pet(entry.Id)
        local box, size = PetModels.bounds(model)
        local fit = PetModels.Fit[entry.Form]
        local measure = fit.measure == "height" and size.Y or math.max(size.X, size.Y, size.Z)
        assert(math.abs(measure - fit.size) <= fit.size * 0.03, ("%s measures %.2f, want %.2f"):format(entry.Id, measure, fit.size))
        assert(size.Y <= 3.2 and math.max(size.X, size.Z) <= 6, entry.Id .. " isn't pet-sized: " .. tostring(size))
        assert(math.abs(box.Position.Y - size.Y / 2 - model:GetPivot().Position.Y) <= 0.05, entry.Id .. " pivot isn't at its feet")
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then assert(part.Anchored and not part.CanCollide and not part.CanQuery, entry.Id .. " has a solid part") end
        end
        if imported then
            assert(model:GetAttribute("Imported"), entry.Id .. " has no imported model")
            local animator = assert(PetAnimator.new(model, entry.Form), entry.Id .. " has no Idle clip")
            assert(model.Clips:FindFirstChild("Move"), entry.Id .. " has no Move clip")
            assert(entry.Form ~= "Large" or model.Clips:FindFirstChild("Run"), entry.Id .. " has no Run clip")
            for _, move in PetAnimator.Moves[entry.Form] do assert(animator:has(move), entry.Id .. " has no " .. move .. " clip") end
            -- A one-shot plays out and hands back to the base layer.
            local seconds = assert(animator:play(PetAnimator.Moves[entry.Form][1]), entry.Id .. " won't play a move")
            for _ = 1, math.ceil(seconds * 30) + 2 do animator:step(1 / 30, 12) end
            assert(not animator:busy(), entry.Id .. " move never ends")
            assert(next(animator.bones) and next(animator.idle.tracks), entry.Id .. " clips don't reach its bones")
            local posed = 0
            for name in animator.idle.tracks do if animator.bones[name] then posed += 1 end end
            assert(posed >= 1, entry.Id .. " Idle poses no bone")
            animator:step(1 / 30, 1)
        end
        model:Destroy()
    end
    for tier in Pets.Ufos do
        local ufo = PetModels.ufo(tier)
        assert(ufo.PrimaryPart and ufo:FindFirstChild("Beam") and #ufo:GetChildren() >= 12)
        ufo:Destroy()
    end
end
