-- Suits (Shared.Skins): every character is built from the suit's HumanoidDescription
-- (Main's spawnCharacter) and dressed here: the suit's armour pieces from
-- ReplicatedStorage.SuitModels (tools/suits) welded to their body parts, each coloured by
-- its Role, the star field on the galaxy suit, and the suit's particles (`fx`).
-- SuitFxController (client) animates the halo, the pulsing glows and the stars. A pass
-- bought or found on join re-dresses the character in place (ShopService's refresh calls
-- `refresh`). Players may wear any suit they own, or the basic one (WearSuit; saved as
-- the profile's `suit`): the look only, as the boost (`multiplier`) is always their best
-- suit's. The worn suit is the player's Suit attribute.
-- The suits sell on stands on the forecourt (SiteLayout.SuitStands): a mannequin wearing
-- each one on a plinth, whose prompt buys it (ShopService.buy), puts it on once owned, or
-- takes it off again for the basic suit (SuitStandController words it per player).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skins = require(ReplicatedStorage.Shared.Skins)
local Signs = require(script.Parent.SignService)
local Skin = {}

Skin.StandTag = "SuitStand" -- each stand's prompt, its Suit attribute the suit's key
local MANNEQUIN_SCALE = 1.3
local PLINTH_HEIGHT, PLINTH_SIZE = 1.2, 6

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

-- A suit stand at `base` (on the ground) facing `facing`: a round plinth with a rim lit in
-- the suit's trim, a mannequin wearing the suit on it, and a plaque in front naming the
-- suit and its boost. Returns the stand's prompt. Yields (the mannequin's body loads).
function Skin.stand(parent, base, facing, skin)
    local frame = CFrame.lookAt(base, base + facing)
    local model = Instance.new("Model")
    model.Name = skin.key .. "Stand"
    local function block(name, size, cframe, color, material, shape)
        local part = Instance.new("Part")
        part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
        part.Material = material or Enum.Material.SmoothPlastic
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
        part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        if shape then part.Shape = shape end
        part.Parent = model
        return part
    end
    local upright = CFrame.Angles(0, 0, math.rad(90))
    local accent = Skins.accent(skin)
    local plinth = block("Plinth", Vector3.new(PLINTH_HEIGHT, PLINTH_SIZE, PLINTH_SIZE), frame * CFrame.new(0, PLINTH_HEIGHT / 2, 0) * upright,
        Color3.fromRGB(40, 42, 52), Enum.Material.Metal, Enum.PartType.Cylinder)
    plinth.CanCollide = true
    local rim = block("PlinthRim", Vector3.new(0.3, PLINTH_SIZE + 0.3, PLINTH_SIZE + 0.3), frame * CFrame.new(0, PLINTH_HEIGHT - 0.2, 0) * upright,
        accent, Enum.Material.Neon, Enum.PartType.Cylinder)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = accent, 12, 1.5
    light.Parent = rim
    -- The plaque leans back in front of the plinth, its face toward the lane.
    Signs.decorate(block("Plaque", Vector3.new(5.5, 1.8, 0.3), frame * CFrame.new(0, 1, -PLINTH_SIZE / 2 - 0.9) * CFrame.Angles(math.rad(20), 0, 0),
        Signs.Backing, Enum.Material.Metal), Enum.NormalId.Front,
        { title = skin.name:upper(), subtitle = skin.multiplier .. "X TRAINING · COINS · LAUNCHES", icon = skin.icon, accent = accent })
    model.Parent = parent

    -- The mannequin: a plain R15 body in the suit, standing on the plinth. Anchored and
    -- out of the way of every query; an invisible box round it keeps players out of it.
    local top = base.Y + PLINTH_HEIGHT
    local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, Skins.description(skin), Enum.HumanoidRigType.R15)
    local holder = plinth
    if ok and rig then
        rig.Name = "Mannequin"
        local humanoid = rig:FindFirstChildOfClass("Humanoid")
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        Skin.dress(rig, skin)
        rig:ScaleTo(MANNEQUIN_SCALE)
        for _, part in rig:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
                if part.Parent == rig then part.Anchored = true end
            end
        end
        rig:PivotTo(frame * CFrame.new(0, top - base.Y + 5, 0))
        local box, size = rig:GetBoundingBox()
        rig:PivotTo(rig:GetPivot() + Vector3.new(0, top - (box.Position.Y - size.Y / 2), 0))
        rig.Parent = model
        box, size = rig:GetBoundingBox()
        holder = block("Collider", Vector3.new(size.X * 0.7, size.Y, size.Z * 0.7), box, Color3.new(), nil)
        holder.Transparency, holder.CanCollide = 1, true
    else
        warn("SkinService: no mannequin for " .. skin.key .. ": " .. tostring(rig))
    end
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText, prompt.ActionText = skin.name, "Buy"
    prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = 12, 0, false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt:SetAttribute("Suit", skin.key)
    prompt.Parent = holder
    CollectionService:AddTag(prompt, Skin.StandTag)
    return prompt
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
    -- Puts on a suit they own, or the basic one ("Astronaut").
    function service.wear(player, key)
        local skin = type(key) == "string" and Skins.get(key)
        if not skin or not ctx.profiles:ready(player.UserId) then return end
        if skin ~= Skins.Default and not owns(player, key) then return end
        ctx.profiles.records[player.UserId].profile.suit = key
        ctx.profiles:dirty(player.UserId)
        service.refresh(player)
    end
    local wear = Instance.new("RemoteEvent")
    wear.Name = "WearSuit"
    wear.Parent = ctx.Remote.folder
    wear.OnServerEvent:Connect(service.wear)

    -- The stands: buy the suit, then wear it, or take it off for the basic one.
    local Layout = require(script.Parent.SiteLayout)
    for _, spot in Layout.SuitStands do
        task.spawn(function()
            local skin = Skins.get(spot.key)
            local prompt = Skin.stand(workspace:FindFirstChild("RocketWorld") or workspace, spot.at, spot.facing, skin)
            prompt.Triggered:Connect(function(player)
                if not owns(player, skin.key) then
                    if ctx.Shop then ctx.Shop.buy(player, skin.key) end
                elseif player:GetAttribute("Suit") == skin.key then
                    service.wear(player, Skins.Default.key)
                else
                    service.wear(player, skin.key)
                end
            end)
        end)
    end
    return service
end

return Skin
