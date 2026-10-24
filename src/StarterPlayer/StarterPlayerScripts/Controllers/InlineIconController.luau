-- Pictures in server-built text (leaderboard headers, the launch count on nameplates):
-- the server tags a TextLabel "InlineIcon" with an Image attribute (a Shared.ProductImages
-- key) and optionally ImageSide ("before" by default, or "after"); this attaches it with
-- UI.Icon, which needs the text's on-screen size and so only works here on the client.
local CollectionService = game:GetService("CollectionService")
local UI = script.Parent.Parent:WaitForChild("UI")
local Icon = require(UI.Icon)
local InlineIconController = {}

local TAG = "InlineIcon"

function InlineIconController.start()
    local function add(label)
        if not label:IsA("TextLabel") then return end
        local function attach() Icon.attach(label, label:GetAttribute("Image"), label:GetAttribute("ImageSide") or "before") end
        label:GetAttributeChangedSignal("Image"):Connect(attach)
        attach()
    end
    for _, label in CollectionService:GetTagged(TAG) do add(label) end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
end

return InlineIconController
