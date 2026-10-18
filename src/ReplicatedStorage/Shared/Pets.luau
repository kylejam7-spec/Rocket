--[[
    Pets — the alien pet catalog and the UFOs that deliver them. Shared by the server
    (purchases, rolls, hatching) and the client (shop, inventory, followers).

    A UFO is bought at any UFO Shop (the spaceport and every destination). It follows
    its owner for `Minutes` of play time, then lands and turns into one pet, rolled at
    purchase from the UFO's `Odds` (rarity -> percent), uniformly within that rarity.
    One UFO at a time. Epic and Legendary UFOs will sell for Robux; until then they
    show in the shop but can't be bought (`Price` nil).

    Catalog[n]
        Id      unique key; also the model's name in ReplicatedStorage.PetModels
                (assets/models-textures/Pets/import/<Id>.fbx, see tools/pets)
        Name    display name
        Form    "Blob" (small, hops), "Large" (walks) or "Flying" (hovers)
        Model   the Quaternius Ultimate Monsters model it comes from
        Rarity  Common .. Legendary; the plainer models sit in the lower tiers
]]

local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RarityRank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

-- 14 / 12 / 10 / 8 / 6 pets, each rarity mixing all three forms. Plain animals and
-- base blobs are Common; armour, weapons, crowns and evolved forms climb the tiers.
local List = {
    -- Common (14)
    { "Blob", "PinkBlob", "Pink Blob", "Common" },
    { "Blob", "GreenBlob", "Green Blob", "Common" },
    { "Blob", "Dog", "Blob Dog", "Common" },
    { "Blob", "Cat", "Blob Cat", "Common" },
    { "Blob", "Pigeon", "Blob Pigeon", "Common" },
    { "Blob", "Chicken", "Blob Chicken", "Common" },
    { "Blob", "Yeti", "Blob Yeti", "Common" },
    { "Large", "Frog", "Big Frog", "Common" },
    { "Large", "Monkroose", "Big Monkroose", "Common" },
    { "Large", "Yeti", "Big Yeti", "Common" },
    { "Flying", "Pigeon", "Pigeon", "Common" },
    { "Flying", "Glub", "Glub", "Common" },
    { "Flying", "Armabee", "Armabee", "Common" },
    { "Flying", "Goleling", "Goleling", "Common" },
    -- Uncommon (12)
    { "Blob", "Orc", "Blob Orc", "Uncommon" },
    { "Blob", "Birb", "Blob Birb", "Uncommon" },
    { "Blob", "Fish", "Blob Fish", "Uncommon" },
    { "Blob", "Mushnub", "Mushnub", "Uncommon" },
    { "Large", "Dino", "Big Dino", "Uncommon" },
    { "Large", "Bunny", "Big Bunny", "Uncommon" },
    { "Large", "Birb", "Big Birb", "Uncommon" },
    { "Large", "Fish", "Big Fish", "Uncommon" },
    { "Flying", "Squidle", "Squidle", "Uncommon" },
    { "Flying", "Ghost", "Ghost", "Uncommon" },
    { "Flying", "Hywirl", "Hywirl", "Uncommon" },
    { "Flying", "Alpaking", "Alpaking", "Uncommon" },
    -- Rare (10)
    { "Blob", "Cactoro", "Blob Cactoro", "Rare" },
    { "Blob", "Alien", "Blob Alien", "Rare" },
    { "Blob", "Ninja", "Blob Ninja", "Rare" },
    { "Large", "Orc", "Big Orc", "Rare" },
    { "Large", "Alien", "Big Alien", "Rare" },
    { "Large", "Ninja", "Big Ninja", "Rare" },
    { "Flying", "Dragon", "Dragon", "Rare" },
    { "Flying", "Armabee_Evolved", "Evolved Armabee", "Rare" },
    { "Flying", "Glub_Evolved", "Evolved Glub", "Rare" },
    { "Flying", "Goleling_Evolved", "Evolved Goleling", "Rare" },
    -- Epic (8)
    { "Blob", "Wizard", "Blob Wizard", "Epic" },
    { "Blob", "Mushnub_Evolved", "Evolved Mushnub", "Epic" },
    { "Large", "BlueDemon", "Big Blue Demon", "Epic" },
    { "Large", "Orc_Skull", "Skull Orc", "Epic" },
    { "Large", "Cactoro", "Big Cactoro", "Epic" },
    { "Flying", "Demon", "Winged Demon", "Epic" },
    { "Flying", "Ghost_Skull", "Skull Ghost", "Epic" },
    { "Flying", "Tribal", "Winged Tribal", "Epic" },
    -- Legendary (6)
    { "Blob", "GreenSpikyBlob", "Spiky Blob", "Legendary" },
    { "Large", "Tribal", "Tribal Chief", "Legendary" },
    { "Large", "Demon", "Big Demon", "Legendary" },
    { "Large", "MushroomKing", "Mushroom King", "Legendary" },
    { "Flying", "Alpaking_Evolved", "Evolved Alpaking", "Legendary" },
    { "Flying", "Dragon_Evolved", "Elder Dragon", "Legendary" },
}

-- UFO tiers (index = tier). Price in coins (nil = Robux only, not on sale yet);
-- Minutes it follows you before landing; Odds of the pet's rarity, in percent.
local Ufos = {
    { Name = "Common UFO", Rarity = "Common", Price = 500, Minutes = 5, Odds = { Common = 80, Uncommon = 20 } },
    { Name = "Uncommon UFO", Rarity = "Uncommon", Price = 5000, Minutes = 10, Odds = { Uncommon = 90, Rare = 10 } },
    { Name = "Rare UFO", Rarity = "Rare", Price = 50000, Minutes = 15, Odds = { Rare = 95, Epic = 5 } },
    { Name = "Epic UFO", Rarity = "Epic", Price = nil, Minutes = 20, Odds = { Epic = 95, Legendary = 5 } },
    { Name = "Legendary UFO", Rarity = "Legendary", Price = nil, Minutes = 25, Odds = { Legendary = 100 } },
}

local Pets = {
    Rarities = table.freeze(Rarities),
    RarityRank = table.freeze(RarityRank),
    Forms = table.freeze({ "Blob", "Large", "Flying" }),
    -- Pets following you at once; more stay in the inventory.
    MaxEquipped = 3,
    -- Copies of one pet a profile keeps (more just aren't added).
    MaxCount = 999,
}

local catalog, byId, byRarity = {}, {}, {}
for _, rarity in Rarities do byRarity[rarity] = {} end
for index, row in List do
    local form, model, name, rarity = row[1], row[2], row[3], row[4]
    local entry = table.freeze({ Id = form .. "_" .. model, Name = name, Form = form, Model = model, Rarity = rarity,
        Rank = RarityRank[rarity], Index = index })
    assert(not byId[entry.Id], "Pets: duplicate id " .. entry.Id)
    assert(byRarity[rarity], "Pets: unknown rarity " .. rarity)
    catalog[index], byId[entry.Id] = entry, entry
    table.insert(byRarity[rarity], entry.Id)
end
for _, ufo in Ufos do
    local total = 0
    for rarity, percent in ufo.Odds do
        assert(byRarity[rarity] and #byRarity[rarity] > 0, "Pets: UFO odds name an empty rarity " .. rarity)
        total += percent
    end
    assert(total == 100, "Pets: " .. ufo.Name .. " odds must add up to 100")
    ufo.Seconds = ufo.Minutes * 60
    table.freeze(ufo.Odds)
    table.freeze(ufo)
end
for _, ids in byRarity do table.freeze(ids) end
Pets.Catalog = table.freeze(catalog)
Pets.ByRarity = table.freeze(byRarity)
Pets.Ufos = table.freeze(Ufos)

function Pets.get(id)
    return byId[id]
end

-- Rolls the pet a UFO of `tier` turns into. `random` is a Random (seeded in checks).
function Pets.roll(random, tier)
    local ufo = assert(Ufos[tier], "Pets: no UFO tier " .. tostring(tier))
    local roll = random:NextNumber(0, 100)
    local picked
    for _, rarity in Rarities do
        local percent = ufo.Odds[rarity]
        if percent then
            picked = rarity
            if roll < percent then break end
            roll -= percent
        end
    end
    local ids = byRarity[picked]
    return ids[random:NextInteger(1, #ids)]
end

-- "4:05" from seconds.
function Pets.clock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

return table.freeze(Pets)
