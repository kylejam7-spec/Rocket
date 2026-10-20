--[[
    Shop — the Robux SHOP catalog and the rules both sides share. IDs and prices live
    in Config.Shop; this module adds names, icons and when each offer can be bought.
    The server (ShopService) owns every grant; the client (ShopController) only draws.

    Passes (Game Passes, owned for good): 2x Coins, Fast Hatch, Triple Hatch, +1 and +2
    Pet Slots, and access to each Gym District tier without its launches.
    Products (Developer Products, repeatable):
        ServerTraining  2x training for the whole server, 10 minutes, stacks
        Fill<n>         n units (2,000 / 4,000 / 7,000 / 11,000 / 27,500) of whatever the shared rocket
                        needs now: Metal while building, Fuel while fueling
        ExtraStay       +60 s at the destination for everyone there
        Next<Id>        the next mission wheel lands on that destination
        Ufo<Rarity>     a Rare, Epic or Legendary UFO (one of your UFO slots: 1, Triple Hatch 3)
    Paying never decides who flies: boarding stays open to everyone.
]]
local Pets = require(script.Parent.Pets)
local Missions = require(script.Parent.Missions)
local Shop = {}

Shop.Passes = table.freeze({
    table.freeze({ key = "DoubleCoins", name = "2x Coins", icon = "💰", text = "Double coins from every delivery" }),
    table.freeze({ key = "FastHatch", name = "Fast Hatch", icon = "⚡", text = "Your UFOs land 2x faster" }),
    table.freeze({ key = "MultiHatch", name = "Triple Hatch", icon = "🛸", text = "Hatch 3 UFOs at once" }),
    table.freeze({ key = "PetSlot1", name = "+1 Pet Slot", icon = "🐾", text = "One more pet follows you" }),
    table.freeze({ key = "PetSlot2", name = "+2 Pet Slots", icon = "🐾", text = "Two more pets follow you" }),
})
Shop.Fills = table.freeze({ 2000, 4000, 7000, 11000, 27500 })
Shop.MaxPetSlots = Pets.MaxEquipped + 3

function Shop.gymKey(tier) return "Gym" .. tier end
function Shop.nextKey(mission) return "Next" .. Missions.get(mission).Id end
function Shop.fillKey(units) return "Fill" .. units end
function Shop.ufoKey(tier) return Pets.Ufos[tier] and "Ufo" .. Pets.Ufos[tier].Rarity end

-- The {id, price} entry for a pass or product key, or nil.
function Shop.entry(config, key)
    return config.Shop.passes[key] or config.Shop.products[key]
end
function Shop.isPass(config, key) return config.Shop.passes[key] ~= nil end
-- On sale: the key exists and has a dashboard ID.
function Shop.enabled(config, key)
    local entry = Shop.entry(config, key)
    return entry ~= nil and type(entry.id) == "number"
end

-- Pets that can follow you with these passes owned (`owned[key] = true`).
function Shop.petSlots(owned)
    return Pets.MaxEquipped + (owned.PetSlot1 and 1 or 0) + (owned.PetSlot2 and 2 or 0)
end

-- Whether a product can be offered right now. `view`: phase, passenger, wheelSpun,
-- guaranteed (a mission is already locked), stayExtra (seconds added this stay), ufos
-- (UFOs flying) and maxUfos.
-- A receipt that lands after its moment has passed is still honoured (ShopService
-- banks it); this only decides whether the button and the prompt open.
function Shop.available(config, key, view)
    if key == "ServerTraining" then return true end
    if key:match("^Ufo%a+$") then return (view.ufos or 0) < (view.maxUfos or 1) end
    if key:match("^Fill%d+$") then return view.phase == "Building" or view.phase == "Fueling" end
    local atDestination = view.phase == "Rewarding" and view.passenger == true
    if key == "ExtraStay" then return atDestination and (view.stayExtra or 0) < config.Shop.ExtraStayMax end
    if key:match("^Next") then return atDestination and not view.wheelSpun and not view.guaranteed end
    return false
end

return Shop
