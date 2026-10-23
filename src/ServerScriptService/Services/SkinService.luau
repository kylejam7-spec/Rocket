-- Suits (Shared.Skins): every character is built from the suit's HumanoidDescription
-- (Main's spawnCharacter) and dressed here: the suit's armour pieces from
-- ReplicatedStorage.SuitModels (tools/suits) welded to their body parts, each coloured by
-- its Role, the star field on the galaxy suit, and the suit's particles (`fx`).
-- SuitFxController (client) animates the halo, the pulsing glows and the stars. A pass
-- bought or found on join re-dresses the character in place (ShopService's refresh calls
-- `refresh`). Players may wear any suit they own, or the basic one (WearSuit; saved as
-- the profile's `suit`): the look only, as the boost (`multiplier`) is always their best
-- suit's. The worn suit is the player's Suit attribute.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skins = require(ReplicatedStorage.Shared.Skins)
local Skin = {}

local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
-- Particles the dressing adds to the body itself (taken off again on a re-dress).
local BODY_FX = { Energy = true, StarDust = true, Nebula = true }

-- The star field on every face of `part` (SuitFxController scrolls the GalaxyStars).
local function stars(part)
    for _, face in FACES do
        local texture = Instance.new("Texture")
        texture.Name = "GalaxyStars"
        texture.Texture, texture.Face = Skins.GalaxyTexture, face
        texture.StudsPerTileU, texture.StudsPerTileV = 4, 4
        texture.Parent = part
        CollectionService:AddTag(texture, "GalaxyStars")
    end
end

local function emitter(parent, props)
    local item = Instance.new("ParticleEmitter")
    for key, value in props do item[key] = value end
    item.Parent = parent
    return item
end

local function fade(from, to)
    return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, from), NumberSequenceKeypoint.new(1, to) })
end
local function blink(size)
    return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, size), NumberSequenceKeypoint.new(1, 0) })
end

-- The suit's particles on the dressed pieces (`byName[name]` = the piece).
local function effects(skin, byName, character)
    local fx = skin.fx
    local glow = skin.roles.Glow.color
    local torso = character:FindFirstChild("UpperTorso")
    if fx.thrusters and byName.ThrusterGlow then
        emitter(byName.ThrusterGlow, { Name = "Flame", Texture = FIRE, Color = ColorSequence.new(Color3.new(1, 1, 1), fx.thrusters),
            Size = NumberSequence.new(0.35, 0), Transparency = NumberSequence.new(0.2, 1), Lifetime = NumberRange.new(0.15, 0.3),
            Rate = 40, Speed = NumberRange.new(5, 8), SpreadAngle = Vector2.new(6, 6), EmissionDirection = Enum.NormalId.Bottom,
            LightEmission = 1, LightInfluence = 0 })
    end
    if fx.glints and byName.ChestPlate then
        emitter(byName.ChestPlate, { Name = "Glints", Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 230, 140)),
            Size = blink(0.35), Lifetime = NumberRange.new(0.4, 0.7), Rate = 5, Speed = NumberRange.new(0),
            LightEmission = 1, LightInfluence = 0, Rotation = NumberRange.new(0, 90) })
    end
    if fx.energy and torso then
        emitter(torso, { Name = "Energy", Texture = SPARKLE, Color = ColorSequence.new(fx.energy),
            Size = NumberSequence.new(0.18, 0), Transparency = NumberSequence.new(0.1, 1), Lifetime = NumberRange.new(0.8, 1.4),
            Rate = 10, Speed = NumberRange.new(0.6, 1.4), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0),
            LightEmission = 1, LightInfluence = 0 })
    end
    if fx.stars and torso then
        emitter(torso, { Name = "StarDust", Texture = SPARKLE, Color = ColorSequence.new(Color3.new(1, 1, 1), glow),
            Size = blink(0.3), Lifetime = NumberRange.new(1, 1.8), Rate = 16, Speed = NumberRange.new(0.4, 1.2),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 1, LightInfluence = 0,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) })
        emitter(torso, { Name = "Nebula", Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(150, 70, 255), Color3.fromRGB(60, 120, 255)),
            Size = NumberSequence.new(1.2, 3), Transparency = fade(0.8, 1), Lifetime = NumberRange.new(1.5, 2.5), Rate = 3,
            Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.6, LightInfluence = 0,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) })
    end
    local pack = byName.Backpack
    if fx.trail and pack then
        local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
        top.Position, bottom.Position = Vector3.new(0, pack.Size.Y / 2, 0), Vector3.new(0, -pack.Size.Y / 2, 0)
        top.Parent, bottom.Parent = pack, pack
        local trail = Instance.new("Trail")
        trail.Attachment0, trail.Attachment1 = top, bottom
        trail.Color = ColorSequence.new(glow, skin.roles.Trim.color)
        trail.Transparency = NumberSequence.new(0.4, 1)
        trail.Lifetime, trail.LightEmission = 0.45, 1
        trail.Parent = pack
    end
    if fx.halo and byName.Halo then CollectionService:AddTag(byName.Halo, "SuitHalo") end
    if fx.pulse then
        for name, part in byName do
            if part:GetAttribute("Role") == "Glow" and name ~= "Halo" then CollectionService:AddTag(part, "SuitPulse") end
        end
    end
    -- The paid suits' chest screens light the suit a little.
    if byName.ChestScreen and skin ~= Skins.Default then
        local light = Instance.new("PointLight")
        light.Color, light.Range, light.Brightness = glow, 7, 1.2
        light.Parent = byName.ChestScreen
    end
end

-- Puts `skin`'s armour on `character` (replacing any it had).
function Skin.dress(character, skin)
    local old = character:FindFirstChild("SuitGear")
    if old then old:Destroy() end
    for _, item in character:GetDescendants() do
        if (item:IsA("Texture") and item.Name == "GalaxyStars") or (item:IsA("ParticleEmitter") and BODY_FX[item.Name]) then item:Destroy() end
    end
    local models = ReplicatedStorage:FindFirstChild("SuitModels")
    if not models then return warn("SkinService: ReplicatedStorage.SuitModels is missing (tools/suits)") end
    local folder = Instance.new("Folder")
    folder.Name = "SuitGear"
    local byName = {}
    for _, template in models:GetChildren() do
        local body = character:FindFirstChild(template:GetAttribute("BodyPart") or "")
        if body and Skins.wears(skin, template.Name) then
            local role = template:GetAttribute("Role")
            local look = skin.roles[role]
            local part = template:Clone()
            part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, false, true
            part.Color, part.Material = look.color, look.material
            part.Reflectance, part.Transparency = look.reflectance or 0, look.transparency or 0
            part.CastShadow = role ~= "Glass" and role ~= "Glow"
            local offset = template:GetAttribute("Offset")
            part.CFrame = body.CFrame * offset
            local weld = Instance.new("Weld")
            weld.Name = "SuitWeld"
            weld.Part0, weld.Part1, weld.C0 = body, part, offset
            weld.Parent = part
            if skin.galaxy and Skins.GalaxyTexture and role == "Base" then stars(part) end
            part.Parent = folder
            byName[template.Name] = part
        end
    end
    if skin.galaxy and Skins.GalaxyTexture then
        for _, body in character:GetChildren() do
            if body:IsA("BasePart") and body.Name ~= "Head" and body.Name ~= "HumanoidRootPart" then stars(body) end
        end
    end
    folder.Parent = character
    effects(skin, byName, character)
end

function Skin.new(ctx)
    local service = {}
    local function owns(player, key) return ctx.Shop ~= nil and ctx.Shop.owns(player, key) end
    -- Each player's own avatar (a web call, once per join), for their head.
    local avatars = {}
    local function avatar(player)
        if avatars[player] == nil then
            local ok, description = pcall(game:GetService("Players").GetHumanoidDescriptionFromUserId, game:GetService("Players"), math.max(1, player.UserId))
            avatars[player] = ok and description or false
        end
        return avatars[player] or nil
    end
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        if avatars[player] then avatars[player]:Destroy() end
        avatars[player] = nil
    end)
    -- The best suit `player` owns: its boost is theirs whatever they wear.
    function service.best(player)
        return Skins.best(function(key) return owns(player, key) end)
    end
    -- The suit `player` wears: their saved choice while they own it, else their best.
    function service.skin(player)
        local record = ctx.profiles.records[player.UserId]
        local chosen = record and record.profile.suit and Skins.get(record.profile.suit)
        if chosen and (chosen == Skins.Default or owns(player, chosen.key)) then return chosen end
        return service.best(player)
    end
    function service.multiplier(player)
        return player and service.best(player).multiplier or 1
    end
    function service.description(player)
        return Skins.description(service.skin(player), avatar(player))
    end
    -- Dresses a new character in the player's suit.
    function service.characterAdded(player, character)
        local skin = service.skin(player)
        player:SetAttribute("Suit", skin.key)
        character:WaitForChild("UpperTorso", 10)
        character:WaitForChild("Head", 10)
        Skin.dress(character, skin)
    end
    -- After passes change: a new suit goes on the current character in place.
    function service.refresh(player)
        local skin = service.skin(player)
        if player:GetAttribute("Suit") == skin.key then return end
        player:SetAttribute("Suit", skin.key)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        pcall(humanoid.ApplyDescription, humanoid, Skins.description(skin, avatar(player)))
        Skin.dress(character, skin)
    end
    -- WearSuit(key): put on a suit they own, or the basic one ("Astronaut").
    local wear = Instance.new("RemoteEvent")
    wear.Name = "WearSuit"
    wear.Parent = ctx.Remote.folder
    wear.OnServerEvent:Connect(function(player, key)
        local skin = type(key) == "string" and Skins.get(key)
        if not skin or not ctx.profiles:ready(player.UserId) then return end
        if skin ~= Skins.Default and not owns(player, key) then return end
        ctx.profiles.records[player.UserId].profile.suit = key
        ctx.profiles:dirty(player.UserId)
        service.refresh(player)
    end)
    return service
end

return Skin
