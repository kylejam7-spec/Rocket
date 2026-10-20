-- Pets and UFOs (Shared.Pets has the catalog and odds). BuyUfo(tier, requestId) at a UFO
-- Shop charges coins once per request ID and rolls the pet then; the UFO follows its
-- owner while they play (profile.ufo.remaining counts down only in game) and then
-- turns into that pet, equipped at once if a slot is free. Pets are only for show:
-- they follow you and grant nothing. EquipPet(id, on) changes which pets follow you
-- (the backpack); EquipPet("*", false) puts them all away. Every client draws everyone's UFO and pets (PetController)
-- from player attributes: UfoTier, UfoHatchAt (server time) and Pets (equipped ids,
-- comma separated); PetHatched(player, id) cues the landing. The rolled pet stays on
-- the server until it lands. PetCheck runs the pure parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pets = require(ReplicatedStorage.Shared.Pets)
local UpgradeService = require(script.Parent.UpgradeService)
local PetService = {}
PetService.ShopTag = "UfoShop"
-- How close to a UFO Shop a purchase must be made (its prompt reaches 14).
PetService.ShopReach = 30
-- Seconds between the landings of one UFO's pets (Triple Hatch): one reveal at a time.
local EXTRA_LANDING_GAP = 6

-- Pure purchase rule. Returns the coins paid (0 for a repeated request ID), or nil and
-- a reason. `random` rolls the pet. `count` pets come in the one UFO (Triple Hatch: 3,
-- at `count` times the price).
function PetService.buy(profile, tier, requestId, random, count)
    count = count or 1
    local ufo = type(tier) == "number" and Pets.Ufos[tier]
    if not ufo then return nil, "unknown tier" end
    if type(count) ~= "number" or count < 1 or count > 3 or count % 1 ~= 0 then return nil, "bad count" end
    if type(requestId) ~= "string" or #requestId == 0 or #requestId > 64 then return nil, "bad request id" end
    if table.find(profile.purchaseIds, requestId) then return 0 end
    if not ufo.Price then return nil, "robux only" end
    if profile.ufo then return nil, "busy" end
    local price = ufo.Price * count
    if profile.coins < price then return nil, "not enough coins" end
    profile.coins -= price
    profile.ufo = { tier = tier, pet = Pets.roll(random, tier), remaining = ufo.Seconds }
    if count > 1 then
        profile.ufo.extra = {}
        for _ = 2, count do table.insert(profile.ufo.extra, Pets.roll(random, tier)) end
    end
    table.insert(profile.purchaseIds, requestId)
    while #profile.purchaseIds > UpgradeService.LedgerSize do table.remove(profile.purchaseIds, 1) end
    return price
end

-- Adds a pet (capped at Pets.MaxCount copies) and equips it if one of `slots`
-- (Pets.MaxEquipped by default; slot passes add more) is free. Returns whether it was equipped.
function PetService.grant(profile, id, slots)
    profile.pets[id] = math.min((profile.pets[id] or 0) + 1, Pets.MaxCount)
    if #profile.equippedPets < (slots or Pets.MaxEquipped) then
        table.insert(profile.equippedPets, id)
        return true
    end
    return false
end

-- Counts the UFO down by `seconds` of play. Returns the pet id when it lands, whether
-- that pet was equipped, and the extra pets it brought (Triple Hatch; granted too).
function PetService.advance(profile, seconds, slots)
    local ufo = profile.ufo
    if not ufo then return nil end
    ufo.remaining = math.max(0, ufo.remaining - seconds)
    if ufo.remaining > 0 then return nil end
    profile.ufo = nil
    local equipped = PetService.grant(profile, ufo.pet, slots)
    for _, id in ufo.extra or {} do PetService.grant(profile, id, slots) end
    return ufo.pet, equipped, ufo.extra or {}
end

-- Equips (on) or unequips one copy of `id`; "*" unequips them all. Returns true, or
-- nil and a reason.
function PetService.equip(profile, id, on, slots)
    slots = slots or Pets.MaxEquipped
    if id == "*" and not on then
        if #profile.equippedPets == 0 then return nil, "not equipped" end
        table.clear(profile.equippedPets)
        return true
    end
    if type(id) ~= "string" or not Pets.get(id) then return nil, "unknown pet" end
    local equipped = 0
    for _, other in profile.equippedPets do if other == id then equipped += 1 end end
    if on then
        if equipped >= (profile.pets[id] or 0) then return nil, "not owned" end
        if #profile.equippedPets >= slots then return nil, "full" end
        table.insert(profile.equippedPets, id)
        return true
    end
    for index = #profile.equippedPets, 1, -1 do
        if profile.equippedPets[index] == id then
            table.remove(profile.equippedPets, index)
            return true
        end
    end
    return nil, "not equipped"
end

function PetService.new(ctx)
    local Players = ctx.players
    local random = Random.new()
    local service = {}
    -- Shop passes (ShopService): pet slots, hatch speed, pets per UFO.
    function service.slots(player) return ctx.Shop and ctx.Shop.petSlots(player) or Pets.MaxEquipped end
    function service.hatchRate(player) return ctx.Shop and ctx.Shop.hatchRate(player) or 1 end
    local function remote(name)
        local event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = ctx.Remote.folder
        return event
    end
    local buyRemote, equipRemote, hatched = remote("BuyUfo"), remote("EquipPet"), remote("PetHatched")

    local function profileOf(player)
        if not ctx.profiles:ready(player.UserId) then return nil end
        return ctx.profiles.records[player.UserId].profile
    end
    -- Mirrors the profile onto the attributes every client draws from.
    function service.refresh(player)
        local record = ctx.profiles.records[player.UserId]
        local profile = record and record.profile
        if not profile then return end
        local ufo = profile.ufo
        player:SetAttribute("UfoTier", ufo and ufo.tier or nil)
        local hatchAt = ufo and workspace:GetServerTimeNow() + ufo.remaining / service.hatchRate(player) or nil
        local shown = player:GetAttribute("UfoHatchAt")
        if not hatchAt or not shown or math.abs(shown - hatchAt) > 0.5 then player:SetAttribute("UfoHatchAt", hatchAt) end
        local pets = table.concat(profile.equippedPets, ",")
        if player:GetAttribute("Pets") ~= pets then player:SetAttribute("Pets", pets) end
    end
    local function changed(player)
        ctx.profiles:dirty(player.UserId)
        task.spawn(function() ctx.profiles:save(player.UserId) end)
        service.refresh(player)
        ctx.Cycle.send(player)
    end
    local function nearShop(player)
        local root = ctx.Movement.observed(player)
        if not root then return false end
        for _, shop in ctx.World.anchors(PetService.ShopTag) do
            if (root.Position - shop.Position).Magnitude <= PetService.ShopReach then return true end
        end
        return false
    end

    buyRemote.OnServerEvent:Connect(function(player, tier, requestId, count)
        local profile = profileOf(player)
        if not profile or not ctx.Interaction.allowed(player, "ufo") then return end
        if not nearShop(player) then return ctx.Remote.feedback(player, "Buy UFOs at a UFO Shop!") end
        -- More than one pet per UFO needs Triple Hatch.
        count = count == nil and 1 or count
        if count ~= 1 and count ~= (ctx.Shop and ctx.Shop.multiHatch(player) or 1) then return end
        local paid, reason = PetService.buy(profile, tier, requestId, random, count)
        if not paid then
            if reason == "not enough coins" then ctx.Remote.feedback(player, "Not enough coins for that UFO yet!")
            elseif reason == "busy" then ctx.Remote.feedback(player, "Your UFO is still on its way. Wait for it to land!")
            elseif reason == "robux only" then ctx.Remote.feedback(player, "That UFO is coming soon!") end
            ctx.Cycle.send(player)
            return
        end
        if paid > 0 then
            local ufo = Pets.Ufos[tier]
            local minutes = ufo.Minutes / service.hatchRate(player)
            ctx.Remote.feedback(player, ufo.Name .. (count > 1 and " with " .. count .. " pets" or "") .. " summoned! It lands in "
                .. (minutes % 1 == 0 and minutes or ("%.1f"):format(minutes)) .. " minutes of play.")
            changed(player)
        end
    end)
    equipRemote.OnServerEvent:Connect(function(player, id, on)
        local profile = profileOf(player)
        if not profile or not ctx.Interaction.allowed(player, "pet") then return end
        local ok, reason = PetService.equip(profile, id, on == true, service.slots(player))
        if ok then return changed(player) end
        if reason == "full" then ctx.Remote.feedback(player, "Only " .. service.slots(player) .. " pets can follow you. Unequip one first.") end
        ctx.Cycle.send(player)
    end)

    -- Play-time countdown, once a second.
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 1 then return end
        local step = math.min(elapsed, 5)
        elapsed = 0
        for _, player in Players:GetPlayers() do
            local profile = profileOf(player)
            if profile and profile.ufo then
                local id, _, extra = PetService.advance(profile, step * service.hatchRate(player), service.slots(player))
                if id then
                    -- The landing cue goes first so clients hold the UFO for it; the owner's
                    -- client shows the reveal card (no toast). Extra pets (Triple Hatch) are
                    -- already granted; each gets its own landing a few seconds apart.
                    hatched:FireAllClients(player, id)
                    for index, other in extra do
                        task.delay(index * EXTRA_LANDING_GAP, function()
                            if player.Parent then hatched:FireAllClients(player, other) end
                        end)
                    end
                    changed(player)
                else
                    -- Not marked dirty: autosave and leaving save the countdown anyway.
                    service.refresh(player)
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        for _, name in { "UfoTier", "UfoHatchAt", "Pets" } do player:SetAttribute(name, nil) end
    end)
    return service
end

return PetService
