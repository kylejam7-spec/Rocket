-- Draws every nearby player's UFO and pets on this client (local models, nothing
-- replicates but PetService's player attributes: UfoTier, UfoHatchAt, Pets).
-- * The UFO swoops in from the sky and hovers over its owner's shoulder with a
--   rarity-coloured countdown; its lights race in the last seconds.
-- * Pets trail behind in up to three slots with their own Idle / Walk / Run clips
--   (PetAnimator), stepping in time with the ground and bounding along at running
--   speed. Each wears a small name and rarity tag sized to it. Rarer pets show off more:
--   idle emotes and tricks (hop, spin, roll, backflip, loop...) grow in variety and
--   frequency with rank (FLAIR), and Rare+ glow underfoot, Epic+ sparkle, and
--   Legendaries carry a light and a trail. Everyone's pets jump when they jump.
-- * On PetHatched the UFO swoops in front of its owner, beams down with rising
--   sparkles, the pet spins into being inside the beam and pops out (shockwave, burst,
--   fanfare; Rare+ get confetti, a camera kick and a screen blink, growing with rank;
--   Legendaries also a light pillar), the UFO zips away and the pet
--   celebrates before joining its owner (or poofing into the backpack). The owner gets a
--   reveal card (PetRevealCard).
-- The UFO Shop saucers spin here too.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Pets = require(ReplicatedStorage.Shared.Pets)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local PetAnimator = require(ReplicatedStorage.Shared.PetAnimator)
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local RevealCard = require(script.Parent.PetRevealCard)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local Sfx = require(UI.Sfx)
local WorldScale = require(UI.WorldScale)
local PetController = {}

-- Followers of players farther than this from the camera aren't drawn, and past
-- ANIMATE_DISTANCE their pets hold still.
local DRAW_DISTANCE = 220
local ANIMATE_DISTANCE = 110
-- Pet slots behind the owner (owner space: +X right, +Z behind) and the UFO's perch.
local SLOTS = { Vector3.new(-3, 0, 3), Vector3.new(3, 0, 3), Vector3.new(0, 0, 5) }
local UFO_PERCH = Vector3.new(2.2, 5.6, 1.8)
-- The following UFO is a small copy of the shop saucer.
local UFO_SCALE = 0.55
local FLY_HEIGHT = 2.2
-- Farther than this from its target, a follower jumps there (teleports, launches).
local SNAP = 60
-- Name tags show within this distance.
local TAG_DISTANCE = 45

-- What each rank does when its owner stands still: seconds between shows, one-shot
-- clips it may play (if its model has them) and tricks it may pull. Epic+ also
-- trick while on the move now and then.
local FLAIR = {
    { every = { 9, 15 }, moves = { "Yes" }, tricks = {} },
    { every = { 7, 12 }, moves = { "Yes", "No" }, tricks = { "hop" } },
    { every = { 5.5, 10 }, moves = { "Yes", "Dance", "Wave", "Headbutt" }, tricks = { "hop", "spin" } },
    { every = { 4.5, 8 }, moves = { "Yes", "Dance", "Wave", "Headbutt", "Punch", "Bite", "Swing" },
        tricks = { "hop", "spin", "roll" }, moving = { 7, 12 } },
    { every = { 3.5, 6.5 }, moves = { "Yes", "Dance", "Wave", "Headbutt", "Punch", "Bite", "Swing" },
        tricks = { "hop", "spin", "roll", "flip" }, moving = { 5, 9 } },
}
-- The move a pet celebrates its landing with (the first it has).
local CELEBRATE = { "Dance", "Wave", "Yes", "Headbutt" }

local function lerpFactor(rate, dt) return 1 - math.exp(-rate * dt) end
local function yawOf(cframe)
    local look = cframe.LookVector
    return math.atan2(-look.X, -look.Z)
end
local function easeOutBack(x)
    local c = 1.9
    return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end
local function pick(list) return list[math.random(1, #list)] end

-- Tricks: procedural motion layered over the pet (seconds, and the offset at 0..1
-- through it: lift in studs and a turn about the pet's middle). Flyers loop and
-- barrel-roll instead of rolling and flipping.
local TRICKS = {
    hop = { seconds = 0.55, clip = "Jump", fn = function(t, h) return 4 * t * (1 - t) * h * 0.45, CFrame.identity end },
    spin = { seconds = 0.75, clip = "Jump", fn = function(t, h)
        return 4 * t * (1 - t) * h * 0.55, CFrame.Angles(0, t * math.pi * 2, 0)
    end },
    roll = { seconds = 0.8, fn = function(t, h)
        return 4 * t * (1 - t) * h * 0.25, CFrame.Angles(-t * math.pi * 2, 0, 0)
    end },
    flip = { seconds = 0.85, clip = "Jump", fn = function(t, h)
        return 4 * t * (1 - t) * h * 0.95, CFrame.Angles(t * math.pi * 2, 0, 0)
    end },
    loop = { seconds = 1, fn = function(t, h)
        return math.sin(t * math.pi) * h * 0.8, CFrame.Angles(-t * math.pi * 2, 0, 0)
    end },
    barrel = { seconds = 0.7, fn = function(t, h) return math.sin(t * math.pi) * h * 0.3, CFrame.Angles(0, 0, t * math.pi * 2) end },
}
local function trickFor(name, form)
    if form == "Flying" then
        if name == "roll" then return "barrel" end
        if name == "flip" then return "loop" end
    elseif form == "Large" and name == "roll" then
        return "spin"
    end
    return name
end

function PetController.start()
    local localPlayer = Players.LocalPlayer
    -- Fetch the pet meshes up front, so followers and previews (which stay blank if
    -- built before their mesh arrives) show at once.
    local imported = ReplicatedStorage:FindFirstChild("PetModels")
    if imported then task.spawn(ContentProvider.PreloadAsync, ContentProvider, { imported }) end
    local folder = Instance.new("Folder")
    folder.Name = "PetFollowers"
    folder.Parent = workspace
    -- Full-screen blink for rare landings (under the reveal card).
    -- (A plain ScreenGui: Create.screen's UIScale would shrink it off the edges.)
    local flashGui = Create.new("ScreenGui", { Name = "RocketPetFlash", DisplayOrder = 15, ResetOnSpawn = false,
        IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, Parent = localPlayer:WaitForChild("PlayerGui") })
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    local ignoreRefresh = 0

    local entries = {} -- userId -> { pets = { slot }, petsKey, ufo, reveal, airborne }

    local function decor(part)
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
        part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        part.Parent = folder
        return part
    end
    local function ringPart(color, diameter, transparency)
        local ring = Instance.new("Part")
        ring.Name = "GlowRing"
        ring.Shape = Enum.PartType.Cylinder
        ring.Material = Enum.Material.Neon
        ring.Color = color
        ring.Size = Vector3.new(0.06, diameter, diameter)
        ring.Transparency = transparency
        return decor(ring)
    end
    local function emitter(parent, props)
        local item = Instance.new("ParticleEmitter")
        item.LightEmission = 1
        item.LightInfluence = 0
        for key, value in props do item[key] = value end
        item.Parent = parent
        return item
    end

    -- Rarity flair carried by the model (moves with it): Epic+ sparkles, Legendary also a
    -- light and a trail. An invisible AuraCore part at its middle holds them.
    local function decorate(model, spec)
        if spec.Rank < 4 or model:FindFirstChild("AuraCore") then return end
        local height = model:GetAttribute("Height") or 2.5
        local color = Theme.rarity[spec.Rarity]
        local core = Instance.new("Part")
        core.Name = "AuraCore"
        core.Size = Vector3.one * 0.2
        core.Transparency = 1
        core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch = true, false, false, false
        core.CFrame = model:GetPivot() * CFrame.new(0, height * 0.5, 0)
        core.Parent = model
        emitter(core, {
            Color = ColorSequence.new(color, Color3.new(1, 1, 1)), Rate = spec.Rank == 5 and 10 or 5,
            Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0.4, 1.2), SpreadAngle = Vector2.new(180, 180),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18 * height / 2.5), NumberSequenceKeypoint.new(1, 0) }),
            Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
        })
        if spec.Rank == 5 then
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = color, 7, 1.2
            light.Parent = core
            local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
            -- A short, thin streak that tapers off behind it.
            top.Position, bottom.Position = Vector3.new(0, height * 0.12, 0), Vector3.new(0, -height * 0.12, 0)
            top.Parent, bottom.Parent = core, core
            local trail = Instance.new("Trail")
            trail.Attachment0, trail.Attachment1 = top, bottom
            trail.Lifetime, trail.MinLength, trail.LightEmission, trail.FaceCamera = 0.16, 0.05, 1, true
            trail.WidthScale = NumberSequence.new(1, 0)
            trail.Color = ColorSequence.new(color, Color3.fromRGB(255, 245, 200))
            trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
            trail.Parent = core
        end
    end

    -- Name and rarity over a pet, in studs (so it shrinks with distance like the pet),
    -- sized to the pet. It hangs off an attachment in Terrain that follows the pet.
    local function nameTag(spec, height)
        local anchor = Instance.new("Attachment")
        anchor.Name = "PetTag"
        anchor.Parent = workspace.Terrain
        local k = math.clamp(height / 3, 0.6, 1)
        local billboard = Create.new("BillboardGui", {
            Name = "PetTag", Adornee = anchor, Size = UDim2.new(3 * k, 0, 0.75 * k, 0), LightInfluence = 0,
            MaxDistance = TAG_DISTANCE, Parent = anchor,
        })
        local color = Theme.rarity[spec.Rarity]
        local name = StrokedText.new({ Name = "PetName", Size = UDim2.fromScale(1, 0.6), Text = spec.Name, Font = Theme.font.Display,
            TextScaled = true, TextColor3 = spec.Rank == 5 and Color3.fromRGB(255, 225, 120) or Theme.color.White, stroke = 1.5, Parent = billboard })
        local rank = StrokedText.new({ Name = "Rarity", Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4),
            Text = spec.Rarity:upper(),
            Font = Theme.font.Display, TextScaled = true, TextColor3 = color, stroke = 1.2, Parent = billboard })
        -- Legendary tags shimmer.
        if spec.Rank == 5 then
            for _, label in { name, rank } do
                local gradient = Create.new("UIGradient", { Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 60)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 60)) }), Parent = label })
                gradient.Offset = Vector2.new(-1, 0)
                TweenService:Create(gradient, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()
            end
        end
        return anchor
    end

    -- The countdown over a UFO.
    local function ufoLabel(model, tier)
        local spec = Pets.Ufos[tier]
        local billboard = Create.new("BillboardGui", {
            Name = "UfoCountdown", Size = UDim2.fromOffset(150, 46), StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0),
            LightInfluence = 0, MaxDistance = 80, Adornee = model.PrimaryPart, Parent = model,
        })
        WorldScale.apply(billboard)
        StrokedText.new({ Name = "Title", Size = UDim2.fromScale(1, 0.48), Text = spec.Name:upper(), Font = Theme.font.Display,
            TextScaled = true, TextColor3 = Theme.rarity[spec.Rarity], stroke = 2, Parent = billboard })
        return StrokedText.new({ Name = "Time", Position = UDim2.fromScale(0, 0.48), Size = UDim2.fromScale(1, 0.52), Text = "",
            Font = Theme.font.Display, TextScaled = true, stroke = 2, Parent = billboard })
    end
    local function newUfo(tier, at, swoop)
        local model = PetModels.ufo(tier)
        model:ScaleTo(UFO_SCALE)
        -- Arrivals drop in from high above with a whoosh.
        local start = swoop and at + Vector3.new(-14, 46, 10) or at
        model:PivotTo(CFrame.new(start))
        model.Parent = folder
        local lights = {}
        for _, part in model:GetChildren() do
            if part.Name == "Light" then table.insert(lights, part) end
        end
        if swoop then Sfx.playAt("petArrive", model.PrimaryPart) end
        return { model = model, tier = tier, position = start, spin = 0, time = ufoLabel(model, tier), lights = lights,
            color = Theme.rarity[Pets.Ufos[tier].Rarity] }
    end

    -- A follower slot around a pet model (an existing one when a landing hands over).
    local function makeSlot(id, at, model, animator)
        local spec = Pets.get(id)
        model = model or PetModels.pet(id)
        local height = model:GetAttribute("Height") or 2.5
        decorate(model, spec)
        local slot = { id = id, spec = spec, model = model, form = spec.Form, rank = spec.Rank, height = height,
            position = at, yaw = 0, phase = math.random() * 10, speed = 0,
            animator = animator or PetAnimator.new(model, spec.Form), tag = nameTag(spec, height),
            nextShow = os.clock() + math.random(2, 6), nextMovingTrick = os.clock() + math.random(4, 8) }
        if spec.Rank >= 3 then
            local _, size = PetModels.bounds(model)
            slot.ring = ringPart(Theme.rarity[spec.Rarity], math.max(size.X, size.Z) * 0.9, spec.Rank == 3 and 0.78 or 0.68)
        end
        -- Stand-in flyers flap their wings around the inner edge.
        local pivot = model:GetPivot()
        for _, name in { "WingL", "WingR" } do
            local wing = model:FindFirstChild(name)
            if wing then
                slot.wings = slot.wings or {}
                local side = name == "WingL" and -1 or 1
                table.insert(slot.wings, { part = wing, side = side, hinge = pivot:ToObjectSpace(wing.CFrame * CFrame.new(-side * wing.Size.X / 2, 0, 0)), half = wing.Size.X / 2 })
            end
        end
        model:PivotTo(CFrame.new(at))
        model.Parent = folder
        return slot
    end
    local function dropSlot(slot)
        if slot.model then slot.model:Destroy() end
        if slot.ring then slot.ring:Destroy() end
        if slot.tag then slot.tag:Destroy() end
    end
    local function clearReveal(reveal)
        reveal.ufo.model:Destroy()
        if reveal.model then reveal.model:Destroy() end
        for _, part in reveal.parts do part:Destroy() end
    end
    local function clear(entry)
        if entry.ufo then entry.ufo.model:Destroy() end
        for _, slot in entry.pets do dropSlot(slot) end
        if entry.reveal then clearReveal(entry.reveal) end
        entry.ufo, entry.pets, entry.petsKey, entry.reveal = nil, {}, nil, nil
    end

    -- Matches the drawn followers to the owner's attributes, keeping models it can.
    local function sync(player, entry, root)
        local tier = player:GetAttribute("UfoTier")
        local landing = entry.reveal ~= nil
        if not landing and entry.ufo and entry.ufo.tier ~= tier then
            entry.ufo.model:Destroy()
            entry.ufo = nil
        end
        if tier and not entry.ufo and not landing then entry.ufo = newUfo(tier, root.Position + UFO_PERCH, true) end
        local key = player:GetAttribute("Pets") or ""
        if key == entry.petsKey then return end
        entry.petsKey = key
        local old = entry.pets
        entry.pets = {}
        for index, id in (key == "" and {} or key:split(",")) do
            if index > #SLOTS or not Pets.get(id) then continue end
            local reuse
            for i, slot in old do
                if slot.id == id then reuse = table.remove(old, i); break end
            end
            -- The pet being beamed down joins once its landing ends.
            if not reuse and entry.reveal and entry.reveal.id == id and not entry.reveal.claimed then
                entry.reveal.claimed = true
                reuse = { id = id, pending = true }
            end
            table.insert(entry.pets, reuse or makeSlot(id, root.Position + root.CFrame:VectorToWorldSpace(SLOTS[index])))
        end
        for _, slot in old do dropSlot(slot) end
    end

    -- Ground height under `position` (pets stand on it), or nil.
    local function ground(position)
        local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
        return hit and hit.Position.Y
    end

    local function startTrick(slot, name, now)
        name = trickFor(name, slot.form)
        local trick = TRICKS[name]
        if not trick then return end
        slot.trick = { kind = trick, start = now }
        if trick.clip and slot.animator then slot.animator:play(trick.clip, 1.2) end
    end
    -- Idle shows: a clip or a trick from the pet's rank's list (only what it has).
    local function show(slot, now)
        local flair = FLAIR[slot.rank]
        local options = {}
        for _, move in flair.moves do
            if slot.animator and slot.animator:has(move) then table.insert(options, { move = move }) end
        end
        for _, name in flair.tricks do table.insert(options, { trick = name }) end
        if #options == 0 then return end
        local choice = pick(options)
        if choice.move then slot.animator:play(choice.move) else startTrick(slot, choice.trick, now) end
    end

    -- `pace` is the owner's smoothed speed: legs step with the player, not with the
    -- pet's own catch-up speed (which jitters).
    local function updatePet(slot, target, facing, dt, now, animate, pace)
        local snapped = (slot.position - target).Magnitude > SNAP
        local before = slot.position
        slot.position = snapped and target or slot.position:Lerp(target, lerpFactor(7, dt))
        local moved = (slot.position - before) * Vector3.new(1, 0, 1)
        local speed = (dt > 0 and not snapped) and moved.Magnitude / dt or 0
        slot.speed += (speed - slot.speed) * lerpFactor(10, dt)
        speed = slot.speed
        local moving = math.clamp(speed / 10, 0, 1)
        if moved.Magnitude > 0.02 then slot.yaw = math.atan2(-moved.X, -moved.Z) else
            -- Settle facing the owner's way.
            local diff = (facing - slot.yaw + math.pi) % (2 * math.pi) - math.pi
            slot.yaw += diff * lerpFactor(4, dt)
        end
        local t = now + slot.phase
        local lift, tilt, roll = 0, 0, 0
        local height = slot.height
        -- While the owner stands still a lagging pet still walks the last steps in.
        pace = pace > 1 and pace or speed
        if slot.animator then
            if animate then slot.animator:step(dt, pace) end
            local step = slot.animator:phase()
            if slot.form == "Flying" then
                lift = FLY_HEIGHT + math.sin(t * 2.4) * 0.25
                tilt = -0.35 * moving
            elseif slot.form == "Large" then
                -- At running pace it bounds: a low leap per step, feet off the ground.
                local bound = math.clamp((pace - 14) / 30, 0, 1)
                lift = math.abs(math.sin(step * math.pi * 2)) * height * 0.22 * bound
                tilt = -0.1 * bound
            else
                -- Blobs hop a little higher the faster they go, one hop per Walk cycle.
                local bound = math.clamp(pace / 30, 0, 1)
                lift = math.sin(step * math.pi) * height * 0.3 * bound
            end
            -- Shows when the owner stands still; Epic+ show off on the move too.
            local flair = FLAIR[slot.rank]
            if animate and not slot.trick and not slot.animator:busy() then
                if pace < 1 and now >= slot.nextShow then
                    show(slot, now)
                    slot.nextShow = now + math.random() * (flair.every[2] - flair.every[1]) + flair.every[1]
                elseif flair.moving and pace > 6 and now >= slot.nextMovingTrick then
                    startTrick(slot, slot.form == "Large" and "spin" or "roll", now)
                    slot.nextMovingTrick = now + math.random() * (flair.moving[2] - flair.moving[1]) + flair.moving[1]
                end
            end
            if pace >= 1 then slot.nextShow = math.max(slot.nextShow, now + 1.5) end
        elseif slot.form == "Blob" then
            lift = math.abs(math.sin(t * 9)) * 0.9 * moving + math.sin(t * 2) * 0.05
        elseif slot.form == "Large" then
            lift = math.abs(math.sin(t * 7)) * 0.3 * moving
            roll = math.sin(t * 7) * 0.09 * moving
        else
            lift = FLY_HEIGHT + math.sin(t * 2.4) * 0.35
            tilt = -0.3 * moving
        end
        -- A trick in progress turns the pet about its middle and lifts it.
        local turn = CFrame.identity
        if slot.trick then
            local trick = slot.trick
            local progress = (now - trick.start) / trick.kind.seconds
            if progress >= 1 then
                slot.trick = nil
            else
                local up, rotation = trick.kind.fn(progress, height)
                lift += up
                turn = CFrame.new(0, height * 0.5, 0) * rotation * CFrame.new(0, -height * 0.5, 0)
            end
        end
        local pivot = CFrame.new(slot.position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, slot.yaw, 0) * CFrame.Angles(tilt, 0, roll) * turn
        slot.model:PivotTo(pivot)
        if slot.ring then
            slot.ring.CFrame = CFrame.new(slot.position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
            if slot.rank == 5 then slot.ring.Transparency = 0.68 + math.sin(now * 3) * 0.08 end
        end
        if slot.tag then slot.tag.WorldPosition = slot.position + Vector3.new(0, lift + height + 0.45, 0) end
        if slot.wings then
            local flap = math.sin(t * (12 + 6 * moving)) * 0.55
            for _, wing in slot.wings do
                local hinge = pivot * wing.hinge * CFrame.Angles(0, 0, -wing.side * flap)
                wing.part.CFrame = hinge * CFrame.new(wing.side * wing.half, 0, 0)
            end
        end
    end

    -- Landing timeline (seconds from PetHatched), longer for rarer pets.
    local function timeline(rank)
        local extra = (rank - 1) * 0.3
        local pop = 2.3 + extra
        return { fly = 0.7, beam = 1.05, pop = pop, leave = pop + 0.3, done = pop + 1.9 }
    end

    -- PetHatched: the UFO swoops in front of its owner and beams the pet down.
    State.remote("PetHatched").OnClientEvent:Connect(function(player, id)
        local entry = entries[player.UserId]
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local spec = Pets.get(id)
        if not entry or not root or not spec then
            if player == localPlayer and spec then RevealCard.show(id, nil) end
            return
        end
        local ufo = entry.ufo or newUfo(player:GetAttribute("UfoTier") or math.min(spec.Rank, #Pets.Ufos), root.Position + UFO_PERCH, false)
        entry.ufo = nil
        if entry.reveal then clearReveal(entry.reveal) end
        -- It lands a few studs in front of its owner: for your own, ahead of your camera
        -- and off to one side so your character doesn't hide it; it faces the viewer.
        local mine = player == localPlayer
        local view = mine and workspace.CurrentCamera.CFrame or root.CFrame
        local look = view.LookVector * Vector3.new(1, 0, 1)
        look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
        local right = Vector3.new(-look.Z, 0, look.X)
        local spot = root.Position + look * (mine and 6 or 7) + right * (mine and 4 or 0)
        local floor = ground(spot) or (root.Position.Y - 3)
        local model = PetModels.pet(id)
        decorate(model, spec)
        model:ScaleTo(model:GetScale() * 0.05)
        model:PivotTo(CFrame.new(spot.X, floor + 1.5, spot.Z))
        model.Parent = folder
        local color = Theme.rarity[spec.Rarity]
        local reveal = { id = id, spec = spec, ufo = ufo, model = model, scale = model:GetScale() * 20, start = os.clock(),
            animator = PetAnimator.new(model, spec.Form), times = timeline(spec.Rank), from = ufo.position,
            hover = Vector3.new(spot.X, floor + 7.5, spot.Z), floor = floor, at = Vector3.new(spot.X, floor, spot.Z),
            facing = math.atan2(look.X, look.Z), claimed = false, owner = player == localPlayer, color = color, parts = {} }
        -- Rising sparkles inside the beam, and a glow on the ground under it.
        local base = decor(Instance.new("Part"))
        base.Name = "BeamBase"
        base.Size = Vector3.new(1.6, 0.2, 1.6)
        base.Transparency = 1
        base.CFrame = CFrame.new(reveal.at)
        reveal.sparkles = emitter(base, {
            Color = ColorSequence.new(color, Color3.new(1, 1, 1)), Rate = 0, Lifetime = NumberRange.new(0.8, 1.3),
            Speed = NumberRange.new(4, 8), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
        })
        reveal.burst = emitter(base, {
            Color = ColorSequence.new(color, Color3.new(1, 1, 1)), Rate = 0, Lifetime = NumberRange.new(0.5, 1),
            Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(180, 180), Drag = 4,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }),
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
        })
        if spec.Rank >= 3 then
            reveal.confetti = emitter(base, {
                Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 90)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 220, 255)) }),
                Rate = 0, Lifetime = NumberRange.new(1.5, 2.4), Speed = NumberRange.new(18, 30), SpreadAngle = Vector2.new(35, 35),
                EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -30, 0), Drag = 1.5,
                RotSpeed = NumberRange.new(-300, 300), Rotation = NumberRange.new(0, 360), LightEmission = 0.3,
                Size = NumberSequence.new(0.25), Texture = "rbxasset://textures/particles/sparkles_main.dds",
            })
        end
        local glow = ringPart(color, 3, 1)
        glow.CFrame = CFrame.new(reveal.at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
        reveal.glow = glow
        table.insert(reveal.parts, base)
        table.insert(reveal.parts, glow)
        if spec.Rank == 5 then
            -- Legendaries arrive in a golden pillar of light.
            local pillar = decor(Instance.new("Part"))
            pillar.Name = "LightPillar"
            pillar.Shape = Enum.PartType.Cylinder
            pillar.Material = Enum.Material.Neon
            pillar.Color = Color3.fromRGB(255, 220, 120)
            pillar.Transparency = 1
            pillar.Size = Vector3.new(80, 5, 5)
            pillar.CFrame = CFrame.new(reveal.at + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
            reveal.pillar = pillar
            table.insert(reveal.parts, pillar)
        end
        entry.reveal = reveal
        ufo.time.Text = "LANDING!"
    end)

    local function popEffects(reveal)
        local spec = reveal.spec
        Sfx.playAt("petPop", reveal.parts[1])
        reveal.sparkles.Rate = 0
        reveal.burst:Emit(24 + spec.Rank * 14)
        if reveal.confetti then reveal.confetti:Emit(({ 40, 80, 140 })[spec.Rank - 2]) end
        -- A shockwave ring across the ground and a flash.
        local wave = ringPart(reveal.color, 1, 0.2)
        wave.CFrame = CFrame.new(reveal.at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
        local reach = 10 + spec.Rank * 3
        TweenService:Create(wave, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = Vector3.new(0.06, reach, reach), Transparency = 1 }):Play()
        local flash = decor(Instance.new("Part"))
        flash.Shape = Enum.PartType.Ball
        flash.Material = Enum.Material.Neon
        flash.Color = Color3.new(1, 1, 1):Lerp(reveal.color, 0.4)
        flash.Size = Vector3.one * 1
        flash.Transparency = 0.1
        flash.CFrame = CFrame.new(reveal.at + Vector3.new(0, 1.2, 0))
        TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = Vector3.one * (4 + spec.Rank), Transparency = 1 }):Play()
        table.insert(reveal.parts, wave)
        table.insert(reveal.parts, flash)
        if reveal.owner then
            if spec.Rank >= 2 then Sfx.play("fanfare" .. spec.Rank) end
            RevealCard.show(reveal.id, localPlayer)
            -- Rare and up kick the camera (harder for rarer) and wash the screen in the
            -- rarity's colour for a blink.
            if spec.Rank >= 3 and not Settings.get("reducedEffects") then
                local camera = workspace.CurrentCamera
                local seconds = ({ 0.3, 0.38, 0.5 })[spec.Rank - 2]
                local strength = ({ 0.14, 0.24, 0.38 })[spec.Rank - 2]
                local until_ = os.clock() + seconds
                RunService:BindToRenderStep("PetRevealShake", Enum.RenderPriority.Camera.Value + 3, function()
                    local left = until_ - os.clock()
                    if left <= 0 then return RunService:UnbindFromRenderStep("PetRevealShake") end
                    local amount = strength * left / seconds
                    camera.CFrame *= CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
                        * CFrame.Angles(0, 0, (math.random() - 0.5) * amount * 0.04)
                end)
                local wash = Create.new("Frame", { Name = "RevealFlash", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
                    BackgroundColor3 = reveal.color:Lerp(Color3.new(1, 1, 1), 0.35), BackgroundTransparency = 1 - (0.12 + spec.Rank * 0.04),
                    ZIndex = 50, Parent = flashGui })
                TweenService:Create(wash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
                task.delay(0.5, wash.Destroy, wash)
            end
        end
    end

    local function updateReveal(entry, now, dt)
        local reveal = entry.reveal
        local times = reveal.times
        local t = now - reveal.start
        local ufo = reveal.ufo
        local beam = ufo.model:FindFirstChild("Beam")
        -- The UFO: swoop to its hover point, hang there wobbling and spinning ever faster,
        -- then zip up and away.
        if t < times.fly then
            local x = t / times.fly
            local eased = 1 - (1 - x) ^ 3
            ufo.position = reveal.from:Lerp(reveal.hover, eased) + Vector3.new(0, math.sin(x * math.pi) * 3, 0)
        elseif t < times.leave then
            ufo.position = reveal.hover + Vector3.new(0, math.sin(t * 5) * 0.25, 0)
        else
            local away = t - times.leave
            if not reveal.zipped then
                reveal.zipped = true
                Sfx.playAt("petZip", ufo.model.PrimaryPart)
            end
            ufo.position = reveal.hover + Vector3.new(away * away * 25, away * away * 70, -away * away * 15)
        end
        ufo.spin += dt * (2 + math.clamp(t / times.pop, 0, 1) * 10)
        local wobble = t < times.leave and CFrame.Angles(math.sin(t * 7) * 0.12, 0, math.cos(t * 6) * 0.12) or CFrame.identity
        ufo.model:PivotTo(CFrame.new(ufo.position) * CFrame.Angles(0, ufo.spin, 0) * wobble)
        -- Lights race through the rarity colour and white.
        for index, light in ufo.lights do
            light.Color = ((index + math.floor(t * 14)) % 2 == 0) and ufo.color or Color3.new(1, 1, 1)
        end
        -- The beam powers up to the ground, sparkles rising in it, and shuts off as it leaves.
        local height = ufo.position.Y - reveal.floor
        if beam then
            if t >= times.fly and t < times.leave then
                if not reveal.beamOn then
                    reveal.beamOn = true
                    Sfx.playAt("petBeam", ufo.model.PrimaryPart)
                    reveal.sparkles.Rate = 18 + reveal.spec.Rank * 6
                end
                local reach = math.clamp((t - times.fly) / 0.35, 0, 1) * height
                beam.Transparency = 0.7 + math.sin(t * 20) * 0.05
                beam.Size = Vector3.new(math.max(0.1, reach), 1.2 + reach * 0.15, 1.2 + reach * 0.15)
                beam.CFrame = CFrame.new(ufo.position - Vector3.new(0, reach / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
                reveal.glow.Transparency = 0.45
            else
                beam.Transparency = 1
                reveal.glow.Transparency = math.min(1, reveal.glow.Transparency + dt * 2)
            end
        end
        if reveal.pillar then
            local on = t >= times.beam and t < times.done - 0.6
            reveal.pillar.Transparency = on and (0.55 + math.sin(t * 9) * 0.1) or math.min(1, reveal.pillar.Transparency + dt * 2)
        end
        -- The pet: grows from a speck, spinning, floating in the beam; at the pop it lands
        -- with a bounce and celebrates.
        local model = reveal.model
        if model then
            local spin, y, scale
            if t < times.pop then
                local grow = math.clamp((t - times.beam) / (times.pop - times.beam), 0, 1)
                scale = math.max(0.05, easeOutBack(grow))
                y = reveal.floor + 1.4 + math.sin(t * 4) * 0.2
                spin = reveal.facing + t * (12 - grow * 6)
            else
                if not reveal.popped then
                    reveal.popped = true
                    popEffects(reveal)
                end
                local after = t - times.pop
                local drop = math.clamp(after / 0.3, 0, 1)
                -- Falls from its float, then a small bounce.
                local bounce = after > 0.3 and math.max(0, math.sin((after - 0.3) / 0.35 * math.pi)) * 0.5 * math.max(0, 1 - (after - 0.3) / 0.35) or 0
                y = reveal.floor + (1 - drop * drop) * 1.4 + bounce
                scale = 1
                spin = reveal.facing
                if after > 0.4 and not reveal.celebrated then
                    reveal.celebrated = true
                    for _, move in CELEBRATE do
                        if reveal.animator and reveal.animator:play(move) then break end
                    end
                end
            end
            local target = reveal.scale * scale
            if math.abs(model:GetScale() - target) > 0.002 * reveal.scale then model:ScaleTo(target) end
            local fly = reveal.spec.Form == "Flying" and t >= times.pop and FLY_HEIGHT * math.clamp((t - times.pop) / 0.5, 0, 1) or 0
            -- Facing its owner (yaw `facing` points the pet's front back along their look).
            model:PivotTo(CFrame.new(reveal.at.X, y + fly, reveal.at.Z) * CFrame.Angles(0, spin, 0))
            if reveal.animator then reveal.animator:step(dt, 0) end
        end
        if t < times.done then return end
        ufo.model:Destroy()
        -- Hand the pet to its waiting slot, or poof it into the backpack.
        local handed = false
        for _, slot in entry.pets do
            if slot.pending and slot.id == reveal.id and model then
                local fresh = makeSlot(reveal.id, reveal.at, model, reveal.animator)
                fresh.yaw = reveal.facing
                for key, value in fresh do slot[key] = value end
                slot.pending, handed = nil, true
                reveal.model = nil
            end
        end
        if not handed and model then
            reveal.burst:Emit(20)
            reveal.model = nil
            model:Destroy()
        end
        for _, part in reveal.parts do
            -- Let the last particles fade before the emitters go.
            task.delay(2.5, part.Destroy, part)
        end
        entry.reveal = nil
    end

    -- UFO Shop saucers turn slowly and bob.
    local displays = {}
    local function addDisplay(model)
        if model:IsA("Model") then displays[model] = model:GetPivot() end
    end
    for _, model in CollectionService:GetTagged("UfoShopDisplay") do addDisplay(model) end
    CollectionService:GetInstanceAddedSignal("UfoShopDisplay"):Connect(addDisplay)
    CollectionService:GetInstanceRemovedSignal("UfoShopDisplay"):Connect(function(model) displays[model] = nil end)

    Players.PlayerRemoving:Connect(function(player)
        local entry = entries[player.UserId]
        if entry then clear(entry) end
        entries[player.UserId] = nil
    end)

    local lastLabel = 0
    RunService:BindToRenderStep("PetFollowers", Enum.RenderPriority.Camera.Value + 2, function(dt)
        local now = os.clock()
        local camera = workspace.CurrentCamera
        if now - ignoreRefresh > 1 then
            ignoreRefresh = now
            local ignore = { folder }
            for _, player in Players:GetPlayers() do
                if player.Character then table.insert(ignore, player.Character) end
            end
            rayParams.FilterDescendantsInstances = ignore
        end
        local labels = now - lastLabel > 0.2
        if labels then lastLabel = now end
        local serverNow = workspace:GetServerTimeNow()
        for _, player in Players:GetPlayers() do
            local entry = entries[player.UserId]
            if not entry then
                entry = { pets = {} }
                entries[player.UserId] = entry
            end
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local near = root and humanoid and camera and (root.Position - camera.CFrame.Position).Magnitude <= DRAW_DISTANCE
            if not near then
                if entry.ufo or #entry.pets > 0 or entry.reveal then clear(entry) end
                continue
            end
            sync(player, entry, root)
            local base = CFrame.new(root.Position) * CFrame.Angles(0, yawOf(root.CFrame), 0)
            local feet = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
            if entry.ufo then
                local ufo = entry.ufo
                local target = base * UFO_PERCH + Vector3.new(0, math.sin(now * 2) * 0.4, 0)
                ufo.position = (ufo.position - target).Magnitude > SNAP and target or ufo.position:Lerp(target, lerpFactor(4, dt))
                ufo.spin += dt * 1.6
                ufo.model:PivotTo(CFrame.new(ufo.position) * CFrame.Angles(0, ufo.spin, 0))
                if labels then
                    local hatchAt = player:GetAttribute("UfoHatchAt")
                    local left = hatchAt and hatchAt - serverNow
                    ufo.time.Text = left and ((left <= 10 and "LANDING " or "") .. Pets.clock(left)) or ""
                    -- The last seconds: lights race.
                    local racing = left and left <= 10
                    for index, light in ufo.lights do
                        light.Color = (racing and (index + math.floor(now * 8)) % 2 == 0) and Color3.new(1, 1, 1) or ufo.color
                    end
                end
            end
            if entry.reveal then updateReveal(entry, now, dt) end
            local animate = (root.Position - camera.CFrame.Position).Magnitude <= ANIMATE_DISTANCE
            -- Everyone's pets jump when they do (each a beat after the last).
            -- The owner's ground speed, smoothed; their pets' legs keep to it.
            local velocity = root.AssemblyLinearVelocity
            local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
            entry.pace = (entry.pace or 0) + (flat - (entry.pace or 0)) * lerpFactor(6, dt)
            local jumping = velocity.Y > 12
            if jumping and not entry.airborne and animate then
                for index, slot in entry.pets do
                    if slot.model and not slot.trick then
                        task.delay((index - 1) * 0.08, function()
                            if slot.model and not slot.trick then startTrick(slot, "hop", os.clock()) end
                        end)
                    end
                end
            end
            entry.airborne = jumping
            for index, slot in entry.pets do
                if slot.model then
                    local spot = base * SLOTS[index]
                    local floor = slot.form == "Flying" and feet or ground(spot) or feet
                    -- Never sink far below the owner's feet (holes, ramps' edges).
                    if floor < feet - 6 then floor = feet end
                    updatePet(slot, Vector3.new(spot.X, floor, spot.Z), yawOf(root.CFrame), dt, now, animate, entry.pace)
                end
            end
        end
        for model, base in displays do
            if model.Parent then model:PivotTo(base * CFrame.new(0, math.sin(now * 1.5) * 0.6, 0) * CFrame.Angles(0, now * 0.8, 0)) end
        end
    end)
end

return PetController
