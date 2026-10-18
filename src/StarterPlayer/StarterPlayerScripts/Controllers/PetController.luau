-- Draws every nearby player's UFO and pets on this client (local models, nothing
-- replicates but PetService's player attributes: UfoTier, UfoHatchAt, Pets).
-- The UFO hovers over its owner's shoulder with a rarity-coloured countdown; pets
-- trail behind in up to three slots: blobs hop, large pets waddle, flyers hover and
-- flap. On PetHatched the UFO stops, beams its pet down, and flies off; the pet then
-- joins its owner (or vanishes into the inventory if no slot is free). The owner gets
-- a reveal banner. The UFO Shop saucers spin here too.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pets = require(ReplicatedStorage.Shared.Pets)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local PetAnimator = require(ReplicatedStorage.Shared.PetAnimator)
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local StrokedText = require(UI.StrokedText)
local Popup = require(UI.Popup)
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
local HATCH = { beam = 0.7, grow = 1.6, leave = 2.6 }

local function lerpFactor(rate, dt) return 1 - math.exp(-rate * dt) end
local function yawOf(cframe)
    local look = cframe.LookVector
    return math.atan2(-look.X, -look.Z)
end

function PetController.start()
    local localPlayer = Players.LocalPlayer
    -- Fetch the pet meshes up front, so followers and backpack previews (which stay
    -- blank if built before their mesh arrives) show at once.
    local imported = ReplicatedStorage:FindFirstChild("PetModels")
    if imported then task.spawn(ContentProvider.PreloadAsync, ContentProvider, { imported }) end
    local folder = Instance.new("Folder")
    folder.Name = "PetFollowers"
    folder.Parent = workspace
    local gui = Create.screen("RocketPets")
    gui.DisplayOrder = 5
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    local ignoreRefresh = 0

    local entries = {} -- userId -> { pets = { slot }, petsKey, ufo, reveal }

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
    local function newUfo(tier, at)
        local model = PetModels.ufo(tier)
        model:ScaleTo(UFO_SCALE)
        model:PivotTo(CFrame.new(at))
        model.Parent = folder
        return { model = model, tier = tier, position = at, spin = 0, time = ufoLabel(model, tier) }
    end
    local function newPet(id, at)
        local model = PetModels.pet(id)
        local entry = Pets.get(id)
        local slot = { id = id, model = model, form = entry.Form, position = at, yaw = 0, phase = math.random() * 10,
            animator = PetAnimator.new(model) }
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
    local function clear(entry)
        if entry.ufo then entry.ufo.model:Destroy() end
        for _, slot in entry.pets do if slot.model then slot.model:Destroy() end end
        if entry.reveal then
            entry.reveal.ufo.model:Destroy()
            if entry.reveal.model then entry.reveal.model:Destroy() end
        end
        entry.ufo, entry.pets, entry.petsKey, entry.reveal = nil, {}, nil, nil
    end

    -- Matches the drawn followers to the owner's attributes, keeping models it can.
    local function sync(player, entry, root)
        local tier = player:GetAttribute("UfoTier")
        local landing = entry.reveal and entry.reveal.ufo
        if not landing and entry.ufo and entry.ufo.tier ~= tier then
            entry.ufo.model:Destroy()
            entry.ufo = nil
        end
        if tier and not entry.ufo and not landing then entry.ufo = newUfo(tier, root.Position + UFO_PERCH) end
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
            -- The pet being beamed down joins once the reveal ends.
            if not reuse and entry.reveal and entry.reveal.id == id and not entry.reveal.claimed then
                entry.reveal.claimed = true
                reuse = { id = id, pending = true }
            end
            table.insert(entry.pets, reuse or newPet(id, root.Position + root.CFrame:VectorToWorldSpace(SLOTS[index])))
        end
        for _, slot in old do if slot.model then slot.model:Destroy() end end
    end

    -- Ground height under `position` (pets stand on it), or nil.
    local function ground(position)
        local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
        return hit and hit.Position.Y
    end

    local function updatePet(slot, target, facing, dt, now, animate)
        local snapped = (slot.position - target).Magnitude > SNAP
        local before = slot.position
        slot.position = snapped and target or slot.position:Lerp(target, lerpFactor(7, dt))
        local moved = (slot.position - before) * Vector3.new(1, 0, 1)
        local speed = dt > 0 and moved.Magnitude / dt or 0
        local moving = math.clamp(speed / 10, 0, 1)
        if moved.Magnitude > 0.02 then slot.yaw = math.atan2(-moved.X, -moved.Z) else
            -- Settle facing the owner's way.
            local diff = (facing - slot.yaw + math.pi) % (2 * math.pi) - math.pi
            slot.yaw += diff * lerpFactor(4, dt)
        end
        local t = now + slot.phase
        local lift, tilt, roll = 0, 0, 0
        -- Imported pets walk and fly with their own clips; stand-ins hop and waddle.
        if slot.animator then
            if animate then slot.animator:step(dt, moving) end
            if slot.form == "Flying" then lift = FLY_HEIGHT + math.sin(t * 2.4) * 0.25 end
        elseif slot.form == "Blob" then
            lift = math.abs(math.sin(t * 9)) * 0.9 * moving + math.sin(t * 2) * 0.05
        elseif slot.form == "Large" then
            lift = math.abs(math.sin(t * 7)) * 0.3 * moving
            roll = math.sin(t * 7) * 0.09 * moving
        else
            lift = FLY_HEIGHT + math.sin(t * 2.4) * 0.35
            tilt = -0.3 * moving
        end
        local pivot = CFrame.new(slot.position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, slot.yaw, 0) * CFrame.Angles(tilt, 0, roll)
        slot.model:PivotTo(pivot)
        if slot.wings then
            local flap = math.sin(t * (12 + 6 * moving)) * 0.55
            for _, wing in slot.wings do
                local hinge = pivot * wing.hinge * CFrame.Angles(0, 0, -wing.side * flap)
                wing.part.CFrame = hinge * CFrame.new(wing.side * wing.half, 0, 0)
            end
        end
    end

    -- PetHatched: the UFO stops where it is and beams the pet down.
    State.remote("PetHatched").OnClientEvent:Connect(function(player, id)
        local entry = entries[player.UserId]
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local spec = Pets.get(id)
        if player == localPlayer and spec then
            -- The owner's reveal banner and fanfare.
            Sfx.play(spec.Rank >= 3 and "jingle" or "confirm")
            local color = Theme.rarity[spec.Rarity]
            Popup.banner({ Name = "PetReveal", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
                Text = "🛸 UFO LANDED!\n" .. spec.Rarity:upper() .. ": " .. spec.Name, TextColor3 = color, TextSize = 46,
                Size = UDim2.new(1, -40, 0, 120), seconds = 4 })
        end
        if not entry or not root or not spec then return end
        local ufo = entry.ufo
        if not ufo then ufo = newUfo(player:GetAttribute("UfoTier") or 1, root.Position + UFO_PERCH) end
        entry.ufo = nil
        if entry.reveal then
            entry.reveal.ufo.model:Destroy()
            if entry.reveal.model then entry.reveal.model:Destroy() end
        end
        local floor = ground(ufo.position - Vector3.new(0, 4, 0)) or (root.Position.Y - 3)
        local model = PetModels.pet(id)
        model.Parent = folder
        -- PetService fires this before it updates the attributes, so the new pet's slot
        -- (sync) finds the reveal and waits for it.
        entry.reveal = { id = id, ufo = ufo, model = model, scale = model:GetScale(), animator = PetAnimator.new(model), start = os.clock(), floor = floor,
            at = Vector3.new(ufo.position.X, floor, ufo.position.Z), claimed = false }
        ufo.time.Text = "LANDING!"
    end)

    local function updateReveal(entry, now, dt)
        local reveal = entry.reveal
        local t = now - reveal.start
        local ufo = reveal.ufo
        local beam = ufo.model:FindFirstChild("Beam")
        local height = ufo.position.Y - reveal.floor
        if t < HATCH.grow then
            -- Hover in place, beam reaching the ground.
            local reach = math.clamp(t / HATCH.beam, 0, 1) * height
            if beam then
                beam.Transparency = 0.74
                beam.Size = Vector3.new(math.max(0.1, reach), 1 + reach * 0.12, 1 + reach * 0.12)
                beam.CFrame = CFrame.new(ufo.position - Vector3.new(0, reach / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
            end
            ufo.spin += 0.2
            ufo.model:PivotTo(CFrame.new(ufo.position) * CFrame.Angles(0, ufo.spin, 0))
        else
            -- Fly off up and away.
            if beam then beam.Transparency = 1 end
            local up = (t - HATCH.grow) ^ 2 * 40
            ufo.model:PivotTo(CFrame.new(ufo.position + Vector3.new(up * 0.4, up, 0)) * CFrame.Angles(0, ufo.spin + t * 3, 0))
        end
        -- The pet grows in the beam, spinning.
        local grow = math.clamp((t - HATCH.beam * 0.6) / (HATCH.grow - HATCH.beam * 0.6), 0, 1)
        local model = reveal.model
        if model then
            local scale = reveal.scale * math.max(0.05, 1 - (1 - grow) ^ 3)
            if math.abs(model:GetScale() - scale) > 0.01 * reveal.scale then model:ScaleTo(scale) end
            if reveal.animator then reveal.animator:step(dt, 0) end
            model:PivotTo(CFrame.new(reveal.at + Vector3.new(0, (1 - grow) * height * 0.5, 0)) * CFrame.Angles(0, t * 6 * (1 - grow) + math.pi, 0))
        end
        if t < HATCH.leave then return end
        ufo.model:Destroy()
        -- Hand the model to its waiting slot, or shrink it away into the inventory.
        for _, slot in entry.pets do
            if slot.pending and slot.id == reveal.id and model then
                local fresh = newPet(reveal.id, reveal.at)
                model:Destroy()
                for key, value in fresh do slot[key] = value end
                slot.pending, model = nil, nil
            end
        end
        if model then model:Destroy() end
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
                    ufo.time.Text = hatchAt and Pets.clock(hatchAt - serverNow) or ""
                end
            end
            if entry.reveal then updateReveal(entry, now, dt) end
            local animate = (root.Position - camera.CFrame.Position).Magnitude <= ANIMATE_DISTANCE
            for index, slot in entry.pets do
                if slot.model then
                    local spot = base * SLOTS[index]
                    local floor = slot.form == "Flying" and feet or ground(spot) or feet
                    -- Never sink far below the owner's feet (holes, ramps' edges).
                    if floor < feet - 6 then floor = feet end
                    updatePet(slot, Vector3.new(spot.X, floor, spot.Z), yawOf(root.CFrame), dt, now, animate)
                end
            end
        end
        for model, base in displays do
            if model.Parent then model:PivotTo(base * CFrame.new(0, math.sin(now * 1.5) * 0.6, 0) * CFrame.Angles(0, now * 0.8, 0)) end
        end
    end)
end

return PetController
