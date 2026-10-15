-- Carried materials: the round DROP button and the held E / ButtonX / prompt-card input
-- that streams pickups and placements while in range.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local State = require(script.Parent.State)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local Tween = require(UI.Tween)
local CargoController = {}

function CargoController.start()
    local discardCargo = State.remote("DiscardCargo")
    -- Round action button in the bottom-right cluster, like the reference's drop button.
    local discardButton = Button.new({
        Name = "DiscardCargo",
        shape = "circle",
        icon = Theme.icon.Drop,
        caption = "DROP",
        color = Theme.color.Purple,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -28, 1, -70),
        Size = UDim2.fromOffset(72, 72),
        Visible = false,
        onActivated = function() discardCargo:FireServer() end,
        Parent = Create.screen("RocketHUD"),
    })
    State.subscribe(function(state)
        local show = state.cargo ~= nil
        if show and not discardButton.Visible then Tween.bounce(discardButton, 1.3, 0.4) end
        discardButton.Visible = show
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
    UserInputService.WindowFocusReleased:Connect(function() setHolding(false) end)
    Players.LocalPlayer.CharacterRemoving:Connect(function() setHolding(false) end)

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
