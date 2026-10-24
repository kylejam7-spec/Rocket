-- The friend boost on screen (FriendService): an INVITE button under the SHOP button
-- opens Roblox's invite-friends prompt, and a chip beneath it shows this player's boost
-- (the FriendBoost attribute): "FRIEND BOOST x3" in green with friends here, otherwise
-- a nudge that friends double training and coins.
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local Actions = require(script.Parent.ActionController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Button = require(UI.Button)
local StrokedText = require(UI.StrokedText)
local Icon = require(UI.Icon)
local Tween = require(UI.Tween)
local FriendController = {}

local FRIEND = Theme.color.Speed

function FriendController.start()
    local player = Players.LocalPlayer
    local gui = Create.screen("RocketFriends")
    gui.DisplayOrder = 10
    -- Right under ShopController's SHOP row (52 tall at the same left edge).
    local holder = Create.new("Frame", { Name = "InviteHolder", BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 92),
        Position = UDim2.fromOffset(Theme.gutter, (Actions.touch and 8 + 276 * 1.25 + 8 or 150 + 276 + 6) + 58), Parent = gui })
    local invite = Button.new({
        Name = "InviteButton", Text = Icon.text("Invite", "👋") .. "INVITE", TextSize = 26, color = FRIEND, Size = UDim2.fromOffset(150, 50),
        onActivated = function()
            local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
            if ok and can then pcall(SocialService.PromptGameInvite, SocialService, player) end
        end,
        Parent = holder,
    })
    Icon.attach(invite.Label, "Invite")
    local chip = StrokedText.new({
        Name = "FriendChip", Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(150, 38), BackgroundTransparency = 0.2,
        BackgroundColor3 = Theme.color.Panel, Font = Theme.font.Display, TextSize = 16, TextColor3 = Theme.color.Muted,
        TextWrapped = true, stroke = 2, Parent = holder,
    })
    Create.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = chip })
    local last = 1
    local function show()
        local boost = player:GetAttribute("FriendBoost") or 1
        if boost > 1 then
            chip.Text, chip.TextColor3, chip.TextSize = "👥 FRIEND BOOST x" .. boost, Theme.color.Ready, 16
        else
            chip.Text, chip.TextColor3, chip.TextSize = "Friends = 2x\ntraining & coins!", Theme.color.Muted, 14
        end
        if boost > last then Tween.bounce(chip, 1.15, 0.3) end
        last = boost
    end
    player:GetAttributeChangedSignal("FriendBoost"):Connect(show)
    show()
end

return FriendController
