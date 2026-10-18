-- Pets and UFOs (Shared.Pets has the catalog and odds). BuyUfo(tier, requestId) at a UFO
-- Shop charges coins once per request ID and rolls the pet then; the UFO follows its
-- owner while they play (profile.ufo.remaining counts down only in game) and then
-- turns into that pet, equipped at once if a slot is free. EquipPet(id, on) changes
-- which pets follow you. Every client draws everyone's UFO and pets (PetController)
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

-- Pure purchase rule. Returns the coins paid (0 for a repeated request ID), or nil and
-- a reason. `random` rolls the pet.
function PetService.buy(profile, tier, requestId, random)
    local ufo = type(tier) == "number" and Pets.Ufos[tier]
    if not ufo then return nil, "unknown tier" end
    if type(requestId) ~= "string" or #requestId == 0 or #requestId > 64 then return nil, "bad request id" end
    if table.find(profile.purchaseIds, requestId) then return 0 end
    if not ufo.Price then return nil, "robux only" end
    if profile.ufo then return nil, "busy" end
    if profile.coins < ufo.Price then return nil, "not enough coins" end
    profile.coins -= ufo.Price
    profile.ufo = { tier = tier, pet = Pets.roll(random, tier), remaining = ufo.Seconds }
    table.insert(profile.purchaseIds, requestId)
    while #profile.purchaseIds > UpgradeService.LedgerSize do table.remove(profile.purchaseIds, 1) end
    return ufo.Price
end

-- Adds a pet (capped at Pets.MaxCount copies) and equips it if a slot is free.
-- Returns whether it was equipped.
function PetService.grant(profile, id)
    profile.pets[id] = math.min((profile.pets[id] or 0) + 1, Pets.MaxCount)
    if #profile.equippedPets < Pets.MaxEquipped then
        table.insert(profile.equippedPets, id)
        return true
    end
    return false
end

-- Counts the UFO down by `seconds` of play. Returns the pet id when it lands, and
-- whether that pet was equipped.
function PetService.advance(profile, seconds)
    local ufo = profile.ufo
    if not ufo then return nil end
    ufo.remaining = math.max(0, ufo.remaining - seconds)
    if ufo.remaining > 0 then return nil end
    profile.ufo = nil
    return ufo.pet, PetService.grant(profile, ufo.pet)
end

-- Equips (on) or unequips one copy of `id`. Returns true, or nil and a reason.
function PetService.equip(profile, id, on)
    if type(id) ~= "string" or not Pets.get(id) then return nil, "unknown pet" end
    local equipped = 0
    for _, other in profile.equippedPets do if other == id then equipped += 1 end end
    if on then
        if equipped >= (profile.pets[id] or 0) then return nil, "not owned" end
        if #profile.equippedPets >= Pets.MaxEquipped then return nil, "full" end
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
        local hatchAt = ufo and workspace:GetServerTimeNow() + ufo.remaining or nil
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

    buyRemote.OnServerEvent:Connect(function(player, tier, requestId)
        local profile = profileOf(player)
        if not profile or not ctx.Interaction.allowed(player, "ufo") then return end
        if not nearShop(player) then return ctx.Remote.feedback(player, "Buy UFOs at a UFO Shop!") end
        local paid, reason = PetService.buy(profile, tier, requestId, random)
        if not paid then
            if reason == "not enough coins" then ctx.Remote.feedback(player, "Not enough coins for that UFO yet!")
            elseif reason == "busy" then ctx.Remote.feedback(player, "Your UFO is still on its way. Wait for it to land!")
            elseif reason == "robux only" then ctx.Remote.feedback(player, "That UFO is coming soon!") end
            ctx.Cycle.send(player)
            return
        end
        if paid > 0 then
            local ufo = Pets.Ufos[tier]
            ctx.Remote.feedback(player, ufo.Name .. " summoned! It lands in " .. ufo.Minutes .. " minutes of play.")
            changed(player)
        end
    end)
    equipRemote.OnServerEvent:Connect(function(player, id, on)
        local profile = profileOf(player)
        if not profile or not ctx.Interaction.allowed(player, "pet") then return end
        local ok, reason = PetService.equip(profile, id, on == true)
        if ok then return changed(player) end
        if reason == "full" then ctx.Remote.feedback(player, "Only " .. Pets.MaxEquipped .. " pets can follow you. Unequip one first.") end
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
                local id, equipped = PetService.advance(profile, step)
                if id then
                    local entry = Pets.get(id)
                    ctx.Remote.feedback(player, "Your UFO landed! You got " .. entry.Name .. " (" .. entry.Rarity:upper() .. ")"
                        .. (equipped and "!" or ". Equip it from PETS."))
                    -- The landing cue goes first so clients hold the UFO for it.
                    hatched:FireAllClients(player, id)
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
