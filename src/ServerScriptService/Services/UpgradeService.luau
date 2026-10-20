-- Coin upgrades and rank titles. BuyUpgrade(track, requestId) is validated here and
-- idempotent per request ID (a retried click never charges twice); effects are read
-- through Shared.Upgrades by Cargo (pickup, place, reach) and the
-- tutorial. The rank tag over each character comes from completed launches.
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

    -- Rank title over the head, visible to everyone.
    function service.showRank(player, profile)
        local _, name = Upgrades.rank(config, profile.completedLaunches)
        player:SetAttribute("Rank", name)
        local head = player.Character and player.Character:FindFirstChild("Head")
        if not head then return end
        local tag = head:FindFirstChild("RankTag")
        if not tag then
            tag = Instance.new("BillboardGui")
            tag.Name = "RankTag"
            tag.Size = UDim2.fromOffset(280, 28)
            tag.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
            tag.MaxDistance = 90
            tag.LightInfluence = 0
            local label = Instance.new("TextLabel")
            label.Name = "Title"
            label.Size = UDim2.fromScale(1, 1)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.FredokaOne
            label.TextSize = 22
            label.TextColor3 = Color3.fromRGB(255, 204, 40)
            label.TextStrokeTransparency = 0.1
            label.Parent = tag
            tag.Parent = head
        end
        if tag.Title.Text ~= name then tag.Title.Text = name end
    end
    return service
end

return UpgradeService
