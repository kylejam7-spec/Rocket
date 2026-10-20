-- Pets and UFOs (Shared.Pets has the catalog and odds). BuyUfo(tier, requestId) at a UFO
-- Shop charges coins once per request ID and rolls the pet then; the UFO follows its
-- owner while they play (each of profile.ufos counts down only in game) and then
-- turns into that pet, equipped at once if a slot is free. Pets are only for show:
-- they follow you and grant nothing. EquipPet(id, on) changes which pets follow you
-- (the backpack); EquipPet("*", false) puts them all away. Every client draws everyone's UFO and pets (PetController)
-- from player attributes: Ufos ("id:tier:hatchAt" per UFO, `;` between, hatchAt in
-- server time) and Pets (equipped ids,
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
-- Seconds between landings that fall on the same tick (Triple Hatch): one reveal at a time.
local EXTRA_LANDING_GAP = 6

-- Pure purchase rule. Returns the coins paid (0 for a repeated request ID), or nil and
-- a reason. `random` rolls the pet. Up to `maxUfos` UFOs fly at once (1; Triple Hatch 3),
-- each bought at its own price and counting down together.
function PetService.buy(profile, tier, requestId, random, maxUfos)
    local ufo = type(tier) == "number" and Pets.Ufos[tier]
    if not ufo then return nil, "unknown tier" end
    if type(requestId) ~= "string" or #requestId == 0 or #requestId > 64 then return nil, "bad request id" end
    if table.find(profile.purchaseIds, requestId) then return 0 end
    if not ufo.Price then return nil, "robux only" end
    if #profile.ufos >= (maxUfos or 1) then return nil, "busy" end
    if profile.coins < ufo.Price then return nil, "not enough coins" end
    profile.coins -= ufo.Price
    PetService.add(profile, tier, requestId, random)
    table.insert(profile.purchaseIds, requestId)
    while #profile.purchaseIds > UpgradeService.LedgerSize do table.remove(profile.purchaseIds, 1) end
    return ufo.Price
end

-- Puts a UFO of `tier` on its way (the pet rolled now). `id` (request or purchase ID) names
-- it for clients. False when all 3 UFO slots any profile can hold are taken.
function PetService.add(profile, tier, id, random)
    if #profile.ufos >= 3 then return false end
    table.insert(profile.ufos, { id = id:sub(1, 8), tier = tier, pet = Pets.roll(random, tier), remaining = Pets.Ufos[tier].Seconds })
    return true
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

-- Counts every UFO down by `seconds` of play. Returns the pet id of the first to land,
-- whether it was equipped, and the pets of any others landing on the same tick (all granted).
function PetService.advance(profile, seconds, slots)
    local landed = {}
    for index = 1, #profile.ufos do
        local ufo = profile.ufos[index]
        ufo.remaining = math.max(0, ufo.remaining - seconds)
        if ufo.remaining <= 0 then table.insert(landed, ufo) end
    end
    if #landed == 0 then return nil end
    for _, ufo in landed do table.remove(profile.ufos, table.find(profile.ufos, ufo)) end
    local equipped = PetService.grant(profile, landed[1].pet, slots)
    local others = {}
    for index = 2, #landed do
        PetService.grant(profile, landed[index].pet, slots)
        table.insert(others, landed[index].pet)
    end
    return landed[1].pet, equipped, others
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
    -- Shop passes (ShopService): pet slots, hatch speed, UFOs at once.
    function service.slots(player) return ctx.Shop and ctx.Shop.petSlots(player) or Pets.MaxEquipped end
    function service.hatchRate(player) return ctx.Shop and ctx.Shop.hatchRate(player) or 1 end
    function service.maxUfos(player) return ctx.Shop and ctx.Shop.maxUfos(player) or 1 end
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
        -- Rewritten only when the set of UFOs changes or a landing time drifts by 0.5 s.
        local now, rate = workspace:GetServerTimeNow(), service.hatchRate(player)
        local shown, count = {}, 0
        for item in (player:GetAttribute("Ufos") or ""):gmatch("[^;]+") do
            local id, at = item:match("^([^:]+):%d+:([%d%.]+)$")
            if id then shown[id], count = tonumber(at), count + 1 end
        end
        local parts, stale = {}, count ~= #profile.ufos
        for _, ufo in profile.ufos do
            local at = now + ufo.remaining / rate
            if not shown[ufo.id] or math.abs(shown[ufo.id] - at) > 0.5 then stale = true else at = shown[ufo.id] end
            table.insert(parts, ("%s:%d:%.1f"):format(ufo.id, ufo.tier, at))
        end
        if stale then player:SetAttribute("Ufos", #parts > 0 and table.concat(parts, ";") or nil) end
        local pets = table.concat(profile.equippedPets, ",")
        if player:GetAttribute("Pets") ~= pets then player:SetAttribute("Pets", pets) end
    end
    local function changed(player)
        ctx.profiles:dirty(player.UserId)
        task.spawn(function() ctx.profiles:save(player.UserId) end)
        service.refresh(player)
        ctx.Cycle.send(player)
    end
    -- A Robux UFO (ShopService receipt). The prompt only opens with a free slot; a receipt
    -- that races past it still flies (up to the 3 a profile holds). False (retried on a
    -- later join) only with no loaded profile or 3 UFOs already up.
    function service.grantUfo(player, tier, purchaseId)
        local profile = profileOf(player)
        if not profile then return false end
        -- The PurchaseId goes in the profile's purchase ledger with the UFO, so a retry
        -- after a failed save never adds a second one.
        if table.find(profile.purchaseIds, purchaseId) then return true end
        if not PetService.add(profile, tier, purchaseId, random) then return false end
        table.insert(profile.purchaseIds, purchaseId)
        while #profile.purchaseIds > UpgradeService.LedgerSize do table.remove(profile.purchaseIds, 1) end
        local ufo = Pets.Ufos[tier]
        local minutes = ufo.Minutes / service.hatchRate(player)
        ctx.Remote.feedback(player, ufo.Name .. " summoned! It lands in " .. (minutes % 1 == 0 and minutes or ("%.1f"):format(minutes)) .. " minutes of play.")
        changed(player)
        return true
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
        local paid, reason = PetService.buy(profile, tier, requestId, random, service.maxUfos(player))
        if not paid then
            if reason == "not enough coins" then ctx.Remote.feedback(player, "Not enough coins for that UFO yet!")
            elseif reason == "busy" then
                ctx.Remote.feedback(player, service.maxUfos(player) > 1 and "You already have " .. service.maxUfos(player) .. " UFOs on the way!"
                    or "Your UFO is still on its way. Triple Hatch in the SHOP lets 3 fly at once!")
            elseif reason == "robux only" then ctx.Remote.feedback(player, "That UFO is bought with Robux!") end
            ctx.Cycle.send(player)
            return
        end
        if paid > 0 then
            local ufo = Pets.Ufos[tier]
            local minutes = ufo.Minutes / service.hatchRate(player)
            ctx.Remote.feedback(player, ufo.Name .. " summoned! It lands in "
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
            if profile and #profile.ufos > 0 then
                local id, _, extra = PetService.advance(profile, step * service.hatchRate(player), service.slots(player))
                if id then
                    -- The landing cue goes first so clients hold the UFO for it; the owner's
                    -- client shows the reveal card (no toast). UFOs landing on the same tick
                    -- (already granted) each get their own landing a few seconds apart.
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
        for _, name in { "Ufos", "Pets" } do player:SetAttribute(name, nil) end
    end)
    return service
end

return PetService
