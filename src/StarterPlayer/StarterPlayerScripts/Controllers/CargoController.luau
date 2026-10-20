-- Carried materials: Q drops them (touch: the round DROP and GRAB/PLACE buttons in the
-- action cluster), and the held E / ButtonX / prompt-card input streams pickups and
-- placements while in range.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local State = require(script.Parent.State)
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Tween = require(UI.Tween)
local Sfx = require(UI.Sfx)
local CargoController = {}

function CargoController.start()
    local discardCargo = State.remote("DiscardCargo")
    local carrying, discardedAt = false, -math.huge
    local function discard()
        discardedAt = os.clock()
        discardCargo:FireServer()
    end
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and carrying and input.KeyCode == Enum.KeyCode.Q then discard() end
    end)
    -- Touch has no Q: a round DROP button in the action cluster instead.
    local discardButton = Actions.touch and Button.new({
        Name = "DiscardCargo",
        shape = "circle",
        icon = Theme.icon.Drop,
        caption = "DROP",
        color = Theme.color.Purple,
        Size = UDim2.fromOffset(72, 72),
        LayoutOrder = 2,
        Visible = false,
        onActivated = discard,
        Parent = Actions.cluster(),
    })
    State.subscribe(function(state)
        carrying = state.cargo ~= nil
        if discardButton then
            if carrying and not discardButton.Visible then Tween.bounce(discardButton, 1.3, 0.4) end
            discardButton.Visible = carrying
        end
        -- The place prompt shows from this player's (upgraded) reach, like the server's check.
        local ring = CollectionService:GetTagged("BuildFrontier")[1]
        local prompt = ring and ring:FindFirstChild("PlacePoint") and ring.PlacePoint:FindFirstChildOfClass("ProximityPrompt")
        if prompt and state.profile then prompt.MaxActivationDistance = Upgrades.reach(Config, state.profile) end
    end)

    -- The server streams pickups/placements while the material button is down, at
    -- whatever pit or ring the player is in range of, so E can be held before reaching
    -- a prompt and kept down for a whole grab, place, grab, place loop.
    local materialHold = State.remote("MaterialHold")
    local KEYS = { [Enum.KeyCode.E] = true, [Enum.KeyCode.ButtonX] = true }
    local holding, holdInput, lastTouch = false, nil, nil
    local function setHolding(down, input)
        if holding == down then return end
        holding, holdInput = down, down and input or nil
        materialHold:FireServer(down)
    end
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            lastTouch = input
        elseif KEYS[input.KeyCode] and not UserInputService:GetFocusedTextBox() then
            setHolding(true, input)
        end
    end)
    -- Touch/click: holding a material prompt card counts until that finger lifts.
    ProximityPromptService.PromptButtonHoldBegan:Connect(function(item, inputType)
        if inputType ~= Enum.ProximityPromptInputType.Touch and inputType ~= Enum.ProximityPromptInputType.Keyboard then return end
        local world = workspace:FindFirstChild("RocketWorld")
        if not world or not item:IsDescendantOf(world) then return end
        if not (item.ActionText:match("^Pick up ") or item.ActionText:match("^Place ")) then return end
        if not holding and lastTouch and lastTouch.UserInputState == Enum.UserInputState.Begin then
            setHolding(true, lastTouch)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if holding and (KEYS[input.KeyCode] or input == holdInput) then setHolding(false) end
    end)
    -- Touch: a big GRAB/PLACE button in the action cluster is the material button.
    if Actions.touch then
        local material = Button.new({
            Name = "MaterialButton", shape = "circle", icon = Theme.icon.Hand, caption = "GRAB",
            color = Theme.color.Go, Size = UDim2.fromOffset(84, 84), LayoutOrder = 3, Visible = false, sound = false,
            Parent = Actions.cluster(),
        })
        material.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                setHolding(true, input)
            end
        end)
        State.subscribe(function(state)
            local phase = state.phase == "Building" or state.phase == "Fueling"
            material.Visible = phase and not state.training
            material.Caption.Text = state.cargo and "PLACE" or "GRAB"
            material.BackgroundColor3 = state.cargo and Theme.color.Build or Theme.color.Go
        end)
    end
    UserInputService.WindowFocusReleased:Connect(function() setHolding(false) end)
    Players.LocalPlayer.CharacterRemoving:Connect(function() setHolding(false) end)

    -- Sounds for this player's own load, on the frame each transfer shows: the server
    -- stamps the unit count on CarriedMaterials together with its new size. Both play
    -- the three pops by how full the load is: the deepest (pop1) in its first third,
    -- pop3 in its last, each bending up a little across its third. So pickups climb
    -- as the load fills and placements range back down as it empties. Placements sit a
    -- touch lower than pickups, and Fuel's pops lower than scrap's. Losing the load is
    -- a placement while the button is held, a drop right after Q/DROP, and silent
    -- otherwise (a phase change clears it).
    local function pop(fill, kind, pitch)
        local band = math.clamp(fill * 3, 0, 2.999)
        local index = math.floor(band) + 1
        Sfx.play("pop" .. index, { pitch = pitch * (kind == "Fuel" and 0.85 or 1) * (1 + 0.08 * (band - index + 1)) })
    end
    local function watchLoad(character)
        local count, kind = 0, nil
        local function update(new, newKind)
            local state = State.get()
            local capacity = math.max(1, state and state.profile and state.profile.capacity or new)
            local fill = math.min(1, new / capacity)
            if new > count then
                if new >= capacity then
                    Sfx.play("full")
                else
                    pop(fill, newKind, 1)
                end
            elseif new < count then
                if new == 0 and os.clock() - discardedAt < 1 then
                    Sfx.play("drop")
                elseif new > 0 or holding then
                    pop(fill, kind, 0.94)
                end
            end
            count, kind = new, newKind or kind
        end
        local function track(model, quiet)
            if model.Name ~= "CarriedMaterials" then return end
            local function read() update(model:GetAttribute("Count") or 0, model:GetAttribute("Kind")) end
            model:GetAttributeChangedSignal("Count"):Connect(read)
            if quiet then
                count, kind = model:GetAttribute("Count") or 0, model:GetAttribute("Kind")
            else
                read()
            end
        end
        character.ChildAdded:Connect(track)
        character.ChildRemoved:Connect(function(child)
            if child.Name == "CarriedMaterials" then update(0, nil) end
        end)
        local existing = character:FindFirstChild("CarriedMaterials")
        if existing then track(existing, true) end
    end
    if Players.LocalPlayer.Character then watchLoad(Players.LocalPlayer.Character) end
    Players.LocalPlayer.CharacterAdded:Connect(watchLoad)

    -- The rocket has one place prompt; keep it (locally) at the ring point nearest this
    -- character, so material can be dropped from anywhere around the lowest level.
    RunService.RenderStepped:Connect(function()
        local ring = CollectionService:GetTagged("BuildFrontier")[1]
        local point = ring and ring:FindFirstChild("PlacePoint")
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not point or not root or ring.Transparency >= 1 then return end
        -- The ring is a cylinder along its X axis: its circle lies in the local YZ plane.
        local offset = ring.CFrame:PointToObjectSpace(root.Position)
        -- On a ramp beside the fill line (outside the ring): show it on the ramp right
        -- beside you, matching the server's reach rule (Build:inPlaceReach).
        local inner, outer, surface = ring:GetAttribute("RampInner"), ring:GetAttribute("RampOuter"), ring:GetAttribute("RampSurface")
        local across = math.abs(offset.Y)
        if inner and across >= inner - 1 and across <= outer + 1 and offset.Z >= surface - 1 and offset.Z <= surface + 8 then
            point.Position = Vector3.new(0, offset.Y, surface + 1.5)
            return
        end
        local radial = Vector3.new(0, offset.Y, offset.Z)
        radial = radial.Magnitude > 0.01 and radial.Unit or Vector3.yAxis
        point.Position = radial * (ring.Size.Y / 2 + 0.5)
    end)
end

return CargoController
