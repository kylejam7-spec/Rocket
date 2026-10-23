-- Suits (Shared.Skins): every character is built from the suit's HumanoidDescription
-- (Main's spawnCharacter) and dressed here with its gear, welded on: a backpack with two
-- tanks, a collar ring and a chest badge, and for the paid suits a glass helmet (Neon
-- trim, a lit badge, a trail and sparkles on the better ones). A pass bought or found
-- on join re-dresses the character in place (ShopService's refresh calls `refresh`).
-- Players may wear any suit they own, or the basic one (WearSuit; saved as the profile's
-- `suit`): the look only, as the boost (`multiplier`) is always their best suit's. The
-- worn suit is the player's Suit attribute.
local Skins = require(game:GetService("ReplicatedStorage").Shared.Skins)
local Skin = {}

local function gear(parent, name, props)
    local part = Instance.new("Part")
    part.Name = name
    part.CanCollide, part.CanQuery, part.CanTouch, part.Massless, part.CastShadow = false, false, false, true, false
    part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    part.Material = Enum.Material.SmoothPlastic
    for key, value in props do part[key] = value end
    part.Parent = parent
    return part
end
local function weld(part, to, offset)
    part.CFrame = to.CFrame * offset
    local joint = Instance.new("WeldConstraint")
    joint.Part0, joint.Part1 = to, part
    joint.Parent = part
end

-- Puts `skin`'s gear on `character` (replacing any it had).
function Skin.dress(character, skin)
    local old = character:FindFirstChild("SuitGear")
    if old then old:Destroy() end
    local torso, head = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"), character:FindFirstChild("Head")
    if not torso or not head then return end
    local folder = Instance.new("Folder")
    folder.Name = "SuitGear"
    local trim = skin.glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
    -- Backpack (R15's UpperTorso faces -Z, so its back is +Z) with two tanks.
    local pack = gear(folder, "Backpack", { Size = Vector3.new(1.5, 1.7, 0.6), Color = skin.pack, Material = Enum.Material.Metal })
    weld(pack, torso, CFrame.new(0, 0.05, torso.Size.Z / 2 + 0.3))
    for _, side in { -0.4, 0.4 } do
        local tank = gear(folder, "Tank", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.55, 0.55), Color = skin.trim, Material = trim })
        weld(tank, pack, CFrame.new(side, 0, 0.35) * CFrame.Angles(0, 0, math.rad(90)))
    end
    -- Collar ring where the helmet seals, and a badge on the chest.
    local collar = gear(folder, "Collar", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.5, 1.5), Color = skin.trim, Material = trim })
    weld(collar, torso, CFrame.new(0, torso.Size.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(90)))
    local badge = gear(folder, "Badge", { Size = Vector3.new(0.5, 0.35, 0.1), Color = skin.trim, Material = trim })
    weld(badge, torso, CFrame.new(-0.35, 0.3, -torso.Size.Z / 2 - 0.05))
    if skin.glow then
        local light = Instance.new("PointLight")
        light.Color, light.Range, light.Brightness = skin.trim, 8, 1.5
        light.Parent = badge
    end
    if skin.helmet then
        local helmet = gear(folder, "Helmet", { Shape = Enum.PartType.Ball, Size = Vector3.one * (head.Size.Y * 1.75),
            Color = skin.visor, Material = Enum.Material.Glass, Transparency = 0.55 })
        weld(helmet, head, CFrame.new(0, 0.1, 0))
    end
    if skin.trail then
        local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
        top.Position, bottom.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
        top.Parent, bottom.Parent = pack, pack
        local trail = Instance.new("Trail")
        trail.Attachment0, trail.Attachment1 = top, bottom
        trail.Color = ColorSequence.new(skin.trim, skin.suit)
        trail.Transparency = NumberSequence.new(0.3, 1)
        trail.Lifetime, trail.LightEmission = 0.5, 1
        trail.Parent = pack
    end
    if skin.sparkles then
        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparkles.Color = ColorSequence.new(skin.trim)
        sparkles.Size = NumberSequence.new(0.25, 0)
        sparkles.Lifetime, sparkles.Rate = NumberRange.new(0.6, 1), 8
        sparkles.Speed, sparkles.SpreadAngle = NumberRange.new(1, 2), Vector2.new(180, 180)
        sparkles.LightEmission = 1
        sparkles.Parent = pack
    end
    folder.Parent = character
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
