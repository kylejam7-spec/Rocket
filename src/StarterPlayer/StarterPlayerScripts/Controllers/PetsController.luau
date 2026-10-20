-- The small round 🎒 button (top bar, left of ⚙) and the PET BACKPACK: every pet you
-- own as a card (posed 3D preview, rarity rim, copies owned), rarest first, each with
-- an EQUIP / UNEQUIP button, plus UNEQUIP ALL. Pets are only for show: they follow
-- you, up to Pets.MaxEquipped at once, more with the SHOP's slot passes (state.shop.petSlots;
-- EquipPet: the server checks ownership and the limit). The header shows how many follow you, your collection and the UFO on its way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pets = require(ReplicatedStorage.Shared.Pets)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local PetAnimator = require(ReplicatedStorage.Shared.PetAnimator)
local State = require(script.Parent.State)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Panel = require(UI.Panel)
local Sfx = require(UI.Sfx)
local StrokedText = require(UI.StrokedText)
local Tween = require(UI.Tween)
local PetsController = {}

local WIDTH, HEIGHT = 720, 480
local CARD = Vector2.new(124, 178)
local FULL = Color3.fromRGB(120, 112, 140)

local function preview(parent, id)
    local viewport = Create.new("ViewportFrame", {
        Name = "Preview", Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 6),
        BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 170, 190), LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-0.5, -1, -0.8), Parent = parent,
    })
    -- Skinned meshes deform inside a WorldModel; pose it at the start of its Idle.
    local world = Create.new("WorldModel", { Parent = viewport })
    local model = PetModels.pet(id)
    model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
    model.Parent = world
    local animator = PetAnimator.new(model, Pets.get(id).Form)
    if animator then animator.idleTime = 0; animator:step(0, 0) end
    local camera = Instance.new("Camera")
    -- Frame the widest side, so winged pets fit as well as tall ones.
    -- (Large pets by their height: the T of their bind pose is much wider than they stand.)
    local box, size = PetModels.bounds(model)
    local reach = Pets.get(id).Form == "Large" and size.Y * 1.1 or math.max(size.X, size.Y, size.Z)
    local focus = box.Position
    camera.FieldOfView = 30
    camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, reach * 0.3, reach * 2.6), focus)
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    return viewport
end

function PetsController.start()
    local gui = Create.screen("RocketPetsPanel")
    gui.DisplayOrder = 10
    local panel = Panel.new({
        Name = "PetsPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundTransparency = 0.05, radius = 18,
        stroke = 4, strokeColor = Theme.color.Gold, Visible = false, Parent = gui,
    })
    local screenScale = gui:FindFirstChildOfClass("UIScale")
    local panelScale = Create.new("UIScale", { Name = "ReadableScale", Parent = panel })
    local function fit()
        local s = screenScale and screenScale.Scale or 1
        local want = math.max(s, math.min(0.75, 0.9 * gui.AbsoluteSize.Y / HEIGHT))
        panelScale.Scale = want / s
        local shift = 0
        if Actions.touch then
            local cluster = Actions.cluster()
            local right = gui.AbsoluteSize.X / 2 + WIDTH * want / 2
            shift = math.min(0, cluster.AbsolutePosition.X - 8 - right)
        end
        panel.Position = UDim2.new(0.5, shift / s, 0.5, 0)
    end
    if screenScale then screenScale:GetPropertyChangedSignal("Scale"):Connect(fit) end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()

    StrokedText.new({
        Text = Theme.icon.Backpack .. " PET BACKPACK", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(360, 44), Font = Theme.font.Display, TextSize = 38, stroke = 3, Parent = panel,
    })
    local following = StrokedText.new({
        Name = "Following", Position = UDim2.fromOffset(22, 18), Size = UDim2.fromOffset(200, 34), Text = "",
        Font = Theme.font.Display, TextSize = 24, TextColor3 = Theme.color.Ready, TextXAlignment = Enum.TextXAlignment.Left,
        stroke = 2, Parent = panel,
    })
    local status = StrokedText.new({
        Name = "Status", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.new(1, -40, 0, 26),
        Font = Theme.font.Display, TextSize = 19, TextColor3 = Theme.color.Muted, stroke = 1.5, Parent = panel,
    })
    local function close()
        if panel.Visible then Sfx.play("close") end
        panel.Visible = false
    end
    Button.new({
        Name = "Close", shape = "circle", icon = Theme.icon.Leave, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 46),
        sound = false, onActivated = close, Parent = panel,
    })
    local current
    local unequipAll = Button.new({
        Name = "UnequipAll", Text = "UNEQUIP ALL", TextSize = 16, color = Theme.color.Danger,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 18), Size = UDim2.fromOffset(130, 32),
        sound = false, Parent = panel,
        onActivated = function()
            local profile = current and current.profile
            if not profile or #(profile.equippedPets or {}) == 0 then return Sfx.play("error") end
            Sfx.play("click")
            State.remote("EquipPet"):FireServer("*", false)
        end,
    })
    local grid = Create.new("ScrollingFrame", {
        Name = "Grid", Position = UDim2.fromOffset(16, 96), Size = UDim2.new(1, -32, 1, -112), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel,
    })
    Create.new("UIGridLayout", { CellSize = UDim2.fromOffset(CARD.X, CARD.Y), CellPadding = UDim2.fromOffset(10, 10),
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
    Create.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = grid })
    local empty = StrokedText.new({
        Name = "Empty", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(1, -80, 0, 90),
        Text = "No pets yet!\nBuy a UFO at any " .. Theme.icon.Ufo .. " UFO SHOP: it follows you, then lands as a pet.",
        Font = Theme.font.Display, TextSize = 24, TextWrapped = true, stroke = 2, Parent = panel,
    })

    -- Pets that can follow you: 3, more with the SHOP's slot passes.
    local slots = Pets.MaxEquipped
    local cards = {} -- id -> { frame, count, badge, action }
    local function equippedCount(profile, id)
        local count = 0
        for _, other in profile.equippedPets or {} do if other == id then count += 1 end end
        return count
    end
    local function card(id)
        local entry = Pets.get(id)
        local color = Theme.rarity[entry.Rarity]
        local frame = Create.new("Frame", {
            Name = id, BackgroundColor3 = Theme.color.Track, BackgroundTransparency = 0.2,
            LayoutOrder = (6 - entry.Rank) * 100 + entry.Index, Parent = grid,
        })
        Create.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = frame })
        local rim = Create.new("UIStroke", { Thickness = 3, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
        preview(frame, id)
        StrokedText.new({ Name = "PetName", Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, -8, 0, 22), Text = entry.Name,
            Font = Theme.font.Display, TextScaled = true, stroke = 1.5, Parent = frame })
        StrokedText.new({ Name = "Rarity", Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 18), Text = entry.Rarity:upper() .. " · " .. entry.Form:upper(),
            Font = Theme.font.Display, TextSize = 13, TextColor3 = color, stroke = 1.5, Parent = frame })
        local count = StrokedText.new({ Name = "Count", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(50, 20),
            Font = Theme.font.Display, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, stroke = 1.5, Parent = frame })
        local badge = StrokedText.new({ Name = "Equipped", Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(80, 18), Text = "",
            Font = Theme.font.Display, TextSize = 14, TextColor3 = Theme.color.Ready, TextXAlignment = Enum.TextXAlignment.Left,
            stroke = 1.5, Parent = frame })
        -- UNEQUIP while any copy follows you, else EQUIP (greyed when every slot is taken).
        local action = Button.new({
            Name = "Action", Text = "EQUIP", TextSize = 15, color = Theme.color.Go, radius = 10, stroke = 2,
            AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(104, 28),
            sound = false, Parent = frame,
            onActivated = function()
                local profile = current and current.profile
                if not profile then return end
                local equipped = equippedCount(profile, id)
                local room = #(profile.equippedPets or {}) < slots
                if equipped == 0 and not room then return Sfx.play("error") end
                Sfx.play(equipped == 0 and "confirm" or "click")
                Tween.bounce(frame, 1.06, 0.25)
                State.remote("EquipPet"):FireServer(id, equipped == 0)
            end,
        })
        cards[id] = { frame = frame, count = count, badge = badge, rim = rim, action = action }
        return cards[id]
    end

    local function render(state)
        local profile = state.profile
        if not profile or not profile.pets then return end
        slots = state.shop and state.shop.petSlots or Pets.MaxEquipped
        local equippedTotal = #(profile.equippedPets or {})
        following.Text = "Following " .. equippedTotal .. "/" .. slots
        unequipAll.BackgroundColor3 = equippedTotal > 0 and Theme.color.Danger or FULL
        local found = 0
        for _, entry in Pets.Catalog do
            local owned = profile.pets[entry.Id] or 0
            local view = cards[entry.Id]
            if owned > 0 then
                found += 1
                view = view or card(entry.Id)
                local equipped = equippedCount(profile, entry.Id)
                view.count.Text = owned > 1 and "x" .. owned or ""
                view.badge.Text = equipped > 1 and "EQUIPPED x" .. equipped or (equipped == 1 and "EQUIPPED" or "")
                view.frame.BackgroundColor3 = equipped > 0 and Theme.lighten(Theme.color.Track, 0.18) or Theme.color.Track
                view.action.Label.Text = equipped > 0 and "UNEQUIP" or "EQUIP"
                view.action.BackgroundColor3 = equipped > 0 and Theme.color.Danger
                    or (equippedTotal < slots and Theme.color.Go or FULL)
            elseif view then
                view.frame:Destroy()
                cards[entry.Id] = nil
            end
        end
        empty.Visible = found == 0
        -- The UFO landing soonest (and how many more are on the way).
        local ufo
        for _, other in profile.ufos or {} do if not ufo or other.hatchAt < ufo.hatchAt then ufo = other end end
        local more = #(profile.ufos or {}) - 1
        status.Text = ("Collected %d/%d"):format(found, #Pets.Catalog)
            .. (ufo and ("   ·   %s %s lands in %s%s"):format(Theme.icon.Ufo, Pets.Ufos[ufo.tier].Name,
                Pets.clock(ufo.hatchAt - workspace:GetServerTimeNow()), more > 0 and (" (+" .. more .. " more)") or "") or "")
            .. "   ·   Pets follow you just for fun"
    end
    State.subscribe(function(state)
        current = state
        if panel.Visible then render(state) end
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if panel.Visible and current and elapsed >= 0.5 then
            elapsed = 0
            render(current)
        end
    end)

    -- Top bar, left of the settings button.
    local holder = Create.new("Frame", { Name = "BackpackHolder", Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, Parent = gui })
    Create.inTopBar(holder, gui, 0.66, function(rowHeight) return Theme.gutter + rowHeight + 10 end)
    local button = Button.new({
        Name = "BackpackButton", shape = "circle", icon = Theme.icon.Backpack, color = Theme.color.Ready,
        Size = UDim2.fromScale(1, 1), sound = false,
        onActivated = function()
            if panel.Visible then return close() end
            fit()
            panel.Visible = true
            if current then render(current) end
            Sfx.play("open")
            Tween.bounce(panel, 1.08, 0.3)
        end,
        Parent = holder,
    })
    -- A new pet bounces the button.
    State.subscribe(function(state, previous)
        local now, before = state.profile, previous and previous.profile
        if not now or not before or not now.pets or not before.pets then return end
        for id, count in now.pets do
            if count > (before.pets[id] or 0) then Tween.bounce(button.Label, 1.5, 0.5); break end
        end
    end)
end

return PetsController
