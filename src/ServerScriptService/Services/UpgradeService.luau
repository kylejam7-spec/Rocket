-- Coin upgrades and rank titles. BuyUpgrade(track, requestId) is validated here and
-- idempotent per request ID (a retried click never charges twice); effects are read
-- through Shared.Upgrades by Cargo (pickup, place, reach) and the
-- tutorial. The nameplate over each character (launch count, rank title from completed
-- launches, display name) is made here too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local UpgradeService = {}
-- Recent request IDs kept per profile; a retry arrives within seconds, not 32 buys later.
UpgradeService.LedgerSize = 32

-- Pure purchase rule (UpgradeCheck runs it offline). Returns the price paid, or nil
-- and a reason; a repeated request ID returns 0 ("already done").
function UpgradeService.buy(config, profile, track, requestId)
    if type(track) ~= "string" or not config.Upgrades[track] then return nil, "unknown track" end
    if type(requestId) ~= "string" or #requestId == 0 or #requestId > 64 then return nil, "bad request id" end
    if table.find(profile.purchaseIds, requestId) then return 0 end
    local level = Upgrades.level(profile, track)
    local price = Upgrades.price(config, track, level)
    if not price then return nil, "maxed" end
    if profile.coins < price then return nil, "not enough coins" end
    profile.coins -= price
    profile.upgrades[track] = level + 1
    table.insert(profile.purchaseIds, requestId)
    while #profile.purchaseIds > UpgradeService.LedgerSize do table.remove(profile.purchaseIds, 1) end
    return price
end

function UpgradeService.new(ctx)
    local config = ctx.config
    local service = {}
    local buy = Instance.new("RemoteEvent")
    buy.Name = "BuyUpgrade"
    buy.Parent = ctx.Remote.folder
    buy.OnServerEvent:Connect(function(player, track, requestId)
        if not ctx.profiles:ready(player.UserId) or not ctx.Interaction.allowed(player, "upgrade") then return end
        local profile = ctx.profiles.records[player.UserId].profile
        local paid, reason = UpgradeService.buy(config, profile, track, requestId)
        if not paid then
            if reason == "not enough coins" then ctx.Remote.feedback(player, "Not enough coins yet. Build more of the rocket!") end
            ctx.Cycle.send(player)
            return
        end
        if paid > 0 then
            ctx.profiles:dirty(player.UserId)
            -- Save soon so a purchase survives a quick rejoin.
            task.spawn(function() ctx.profiles:save(player.UserId) end)
            ctx.Remote.feedback(player, config.Upgrades[track].name .. " upgraded to level " .. profile.upgrades[track] .. "!")
            ctx.Tutorial.observe(player, "Upgrade")
            ctx.Stats.update(player)
        end
        ctx.Cycle.send(player)
    end)

    local function text(name, size, color, parent)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.FredokaOne
        label.TextSize = size
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.1
        label.Parent = parent
        return label
    end

    -- Nameplate over the head, visible to everyone: a 🚀 lifetime launch count and the
    -- rank title on top, the display name just above the head (it replaces Roblox's own).
    function service.showRank(player, profile)
        local _, name = Upgrades.rank(config, profile.completedLaunches)
        player:SetAttribute("Rank", name)
        local head = player.Character and player.Character:FindFirstChild("Head")
        if not head then return end
        local tag = head:FindFirstChild("RankTag")
        if not tag then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
            tag = Instance.new("BillboardGui")
            tag.Name = "RankTag"
            tag.Size = UDim2.fromOffset(280, 54)
            -- Bottom edge sits a stud above the head however far the camera is.
            tag.SizeOffset = Vector2.new(0, 0.5)
            tag.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
            tag.MaxDistance = 90
            tag.LightInfluence = 0
            local row = Instance.new("Frame")
            row.Name = "RankRow"
            row.Size = UDim2.new(1, 0, 0, 28)
            row.BackgroundTransparency = 1
            row.Parent = tag
            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.VerticalAlignment = Enum.VerticalAlignment.Center
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 6)
            layout.Parent = row
            local badge = Instance.new("Frame")
            badge.Name = "Launches"
            badge.Size = UDim2.fromOffset(0, 22)
            badge.AutomaticSize = Enum.AutomaticSize.X
            badge.BackgroundColor3 = Color3.fromRGB(24, 28, 48)
            badge.BackgroundTransparency = 0.25
            badge.LayoutOrder = 1
            badge.Parent = row
            Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)
            local padding = Instance.new("UIPadding")
            padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
            padding.Parent = badge
            local count = text("Count", 16, Color3.new(1, 1, 1), badge)
            count.Size = UDim2.fromScale(0, 1)
            count.AutomaticSize = Enum.AutomaticSize.X
            local title = text("Title", 22, Color3.fromRGB(255, 204, 40), row)
            title.Size = UDim2.fromScale(0, 1)
            title.AutomaticSize = Enum.AutomaticSize.X
            title.LayoutOrder = 2
            local display = text("PlayerName", 20, Color3.new(1, 1, 1), tag)
            display.Position = UDim2.fromOffset(0, 30)
            display.Size = UDim2.new(1, 0, 0, 24)
            display.Text = player.DisplayName
            tag.Parent = head
        end
        local title, count = tag.RankRow.Title, tag.RankRow.Launches.Count
        local launches = "🚀 " .. profile.completedLaunches
        if title.Text ~= name then title.Text = name end
        if count.Text ~= launches then count.Text = launches end
    end
    return service
end

return UpgradeService
