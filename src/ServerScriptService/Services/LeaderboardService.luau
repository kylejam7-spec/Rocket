--[[
    Global top-ten leaderboards on the two stands beside spawn (SiteDressingService builds
    them; each panel's face carries a `Leaderboard` attribute naming its category).
    Display only: nothing on them can be clicked.

    Categories (whole numbers from the saved profile):
        Strength, Speed   trained points plus destination bonuses (not levels)
        Coins             coins held now: spending them drops you down the board
        Launches          lifetime completed launches
        Delivered         lifetime units delivered
        BlackHoles        lifetime Black Hole visits

    Each category is an OrderedDataStore keyed by user ID. Every PushSeconds, and when a
    player leaves, a player's changed values are written; every RefreshSeconds each board
    reads its top ten. Panels redraw every RenderSeconds from that top ten with the live
    values of everyone in this server laid over it, so players here move at once (and a
    player here who spends their coins drops at once). Writes and reads wait for their
    own DataStore budgets (sorted requests don't share the profile saves' budget).
    Without DataStores (Studio without API access) the boards rank this server's players.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UserService = game:GetService("UserService")
local CollectionService = game:GetService("CollectionService")
local Images = require(game:GetService("ReplicatedStorage").Shared.ProductImages)
local Leaderboards = {}

Leaderboards.Categories = table.freeze({
    table.freeze({ key = "Strength", title = "STRENGTH", icon = "💪", accent = Color3.fromRGB(255, 110, 80),
        value = function(p) return p.strengthLevel + p.planetBonuses.strength end }),
    table.freeze({ key = "Speed", title = "SPEED", icon = "👟", accent = Color3.fromRGB(90, 200, 255),
        value = function(p) return p.speedLevel + p.planetBonuses.speed end }),
    table.freeze({ key = "Coins", title = "COINS", icon = "💰", accent = Color3.fromRGB(255, 204, 40),
        value = function(p) return p.coins end }),
    table.freeze({ key = "Launches", title = "ROCKETS DELIVERED", icon = "🚀", accent = Color3.fromRGB(255, 150, 60),
        value = function(p) return p.completedLaunches end }),
    table.freeze({ key = "Delivered", title = "MATERIALS DELIVERED", icon = "🔩", accent = Color3.fromRGB(150, 220, 120),
        value = function(p) return p.lifetimeDeliveries end }),
    table.freeze({ key = "BlackHoles", title = "BLACK HOLES VISITED", icon = "🕳️", image = "BlackHole", accent = Color3.fromRGB(190, 120, 255),
        value = function(p) return p.blackHolesVisited or 0 end }),
})
-- Which categories each stand shows, left to right as you face it (west stand first).
Leaderboards.Stands = table.freeze({ { "Strength", "Speed", "Coins" }, { "Launches", "Delivered", "BlackHoles" } })

local byKey = {}
for _, category in Leaderboards.Categories do byKey[category.key] = category end
Leaderboards.byKey = byKey

-- A profile's whole-number value in a category.
function Leaderboards.value(key, profile)
    return math.max(0, math.floor(byKey[key].value(profile)))
end

-- The board's rows: `stored` ({ userId, value } from the DataStore) with `live`
-- ({ [userId] = value } for players in this server) replacing their stored entries;
-- zeros dropped, highest first, ties by user ID, at most `size`.
function Leaderboards.merge(stored, live, size)
    local values = {}
    for _, entry in stored do values[entry.userId] = entry.value end
    for userId, value in live do values[userId] = value end
    local rows = {}
    for userId, value in values do
        if value > 0 then table.insert(rows, { userId = userId, value = value }) end
    end
    table.sort(rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.userId < b.userId
    end)
    while #rows > size do table.remove(rows) end
    return rows
end

-- 1,234,567 with commas; from ten million up, 12.3M / 4.56B / 7.8T (three significant
-- digits, truncated) so the value column stays narrow.
function Leaderboards.format(value)
    if value >= 1e7 then
        for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" } } do
            if value >= unit[1] then
                local scaled = value / unit[1]
                local decimals = scaled >= 100 and 0 or scaled >= 10 and 1 or 2
                local factor = 10 ^ decimals
                return string.format("%." .. decimals .. "f", math.floor(scaled * factor) / factor) .. unit[2]
            end
        end
    end
    local digits = tostring(math.floor(value))
    return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local RANK_COLORS = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(215, 225, 235), Color3.fromRGB(225, 150, 90) }
local WHITE, MUTED = Color3.new(1, 1, 1), Color3.fromRGB(170, 175, 200)

local function label(parent, name, props)
    local text = Instance.new("TextLabel")
    text.Name = name
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.FredokaOne
    text.TextColor3 = WHITE
    text.TextScaled = true
    text.TextStrokeTransparency = 0.4
    for key, value in props do text[key] = value end
    text.Parent = parent
    return text
end

-- The panel's SurfaceGui: a title bar, "TOP 10 · ALL SERVERS", and `size` rows.
local function buildPanel(face, category, size)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Leaderboard"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.LightInfluence = 0
    gui.Brightness = 1.4
    gui.Active = false
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.fromScale(1, 0.16)
    header.BackgroundColor3 = category.accent
    header.BorderSizePixel = 0
    header.Parent = gui
    -- A picture before the title where there is one (InlineIconController), else the emoji.
    local picture = category.image and Images[category.image]
    local title = label(header, "Title", { Size = UDim2.new(1, -24, 0.9, 0), Position = UDim2.new(0, 12, 0.05, 0),
        Text = (picture and "" or category.icon .. " ") .. category.title, TextColor3 = WHITE, TextStrokeTransparency = 0 })
    if picture then
        title:SetAttribute("Image", category.image)
        CollectionService:AddTag(title, "InlineIcon")
    end
    label(gui, "Subtitle", { Size = UDim2.new(1, -24, 0.06, 0), Position = UDim2.new(0, 12, 0.175, 0),
        Text = "TOP " .. size .. " · ALL SERVERS", TextColor3 = MUTED })
    local rows = {}
    local top, height = 0.25, 0.74 / size
    for index = 1, size do
        local row = Instance.new("Frame")
        row.Name = "Row" .. index
        row.Position = UDim2.new(0, 10, top + (index - 1) * height, 0)
        row.Size = UDim2.new(1, -20, height * 0.9, 0)
        row.BackgroundColor3 = Color3.new(1, 1, 1)
        row.BackgroundTransparency = index % 2 == 1 and 0.92 or 1
        row.BorderSizePixel = 0
        row.Parent = gui
        local color = RANK_COLORS[index] or WHITE
        rows[index] = {
            rank = label(row, "Rank", { Size = UDim2.fromScale(0.13, 0.8), Position = UDim2.fromScale(0.01, 0.1),
                Text = "#" .. index, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }),
            name = label(row, "PlayerName", { Size = UDim2.fromScale(0.55, 0.7), Position = UDim2.fromScale(0.15, 0.15),
                Text = "", TextXAlignment = Enum.TextXAlignment.Left }),
            value = label(row, "Value", { Size = UDim2.fromScale(0.29, 0.7), Position = UDim2.fromScale(0.7, 0.15),
                Text = "", TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right }),
        }
    end
    gui.Parent = face
    return rows
end

function Leaderboards.new(ctx)
    local config = ctx.config
    local settings = config.Leaderboards
    local service = { top = {}, panels = {}, names = {} }
    local stores, pushed = {}, {}
    local function persistent() return config.PersistenceEnabled and ctx.profiles:persistent() end

    local function budget(kind)
        return DataStoreService:GetRequestBudgetForRequestType(kind) > 0
    end
    local function store(key)
        stores[key] = stores[key] or DataStoreService:GetOrderedDataStore(settings.Store .. "_" .. key)
        return stores[key]
    end

    -- Live values of every loaded player here, per category.
    local function live()
        local values = {}
        for _, category in Leaderboards.Categories do values[category.key] = {} end
        for _, player in Players:GetPlayers() do
            local record = ctx.profiles.records[player.UserId]
            if record and ctx.profiles:ready(player.UserId) then
                for _, category in Leaderboards.Categories do
                    values[category.key][player.UserId] = Leaderboards.value(category.key, record.profile)
                end
            end
        end
        return values
    end

    -- Writes `profile`'s changed values for `userId` (yields).
    local function push(userId, profile)
        if not persistent() then return end
        pushed[userId] = pushed[userId] or {}
        for _, category in Leaderboards.Categories do
            local value = Leaderboards.value(category.key, profile)
            if pushed[userId][category.key] ~= value then
                while not budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) do task.wait(1) end
                local ok, err = pcall(function() store(category.key):SetAsync(tostring(userId), value) end)
                if ok then pushed[userId][category.key] = value else warn("Rocket leaderboard write failed", category.key, userId, err) end
            end
        end
    end

    -- Reads every board's top ten (yields).
    local function refresh()
        if not persistent() then return end
        for _, category in Leaderboards.Categories do
            while not budget(Enum.DataStoreRequestType.GetSortedAsync) do task.wait(1) end
            local ok, result = pcall(function()
                local entries = {}
                for _, entry in store(category.key):GetSortedAsync(false, settings.Size):GetCurrentPage() do
                    local userId = tonumber(entry.key)
                    if userId then table.insert(entries, { userId = userId, value = entry.value }) end
                end
                return entries
            end)
            if ok then service.top[category.key] = result else warn("Rocket leaderboard read failed", category.key, result) end
        end
    end

    -- Display names for user IDs not seen yet (players here are read off their Player).
    local function resolveNames(userIds)
        local missing = {}
        for userId in userIds do
            local player = Players:GetPlayerByUserId(userId)
            if player then service.names[userId] = player.DisplayName
            elseif not service.names[userId] then table.insert(missing, userId) end
        end
        if #missing == 0 then return end
        local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
        if ok then
            for _, info in infos do service.names[info.Id] = info.DisplayName end
        end
        for _, userId in missing do
            if not service.names[userId] then
                local found, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
                service.names[userId] = found and name or ("Player " .. userId)
            end
        end
    end

    function service.render()
        local values = live()
        local boards, seen = {}, {}
        for key in service.panels do
            boards[key] = Leaderboards.merge(service.top[key] or {}, values[key], settings.Size)
            for _, row in boards[key] do seen[row.userId] = true end
        end
        resolveNames(seen)
        for key, panels in service.panels do
            for _, rows in panels do
                for index, slot in rows do
                    local row = boards[key][index]
                    slot.name.Text = row and (service.names[row.userId] or "…") or "—"
                    slot.name.TextColor3 = row and WHITE or MUTED
                    slot.value.Text = row and Leaderboards.format(row.value) or ""
                end
            end
        end
    end

    -- A leaving player's last values go out before their record is let go.
    function service.leave(player)
        local record = ctx.profiles.records[player.UserId]
        if not record or not ctx.profiles:ready(player.UserId) then return end
        local snapshot = table.clone(record.profile)
        snapshot.planetBonuses = table.clone(record.profile.planetBonuses)
        task.spawn(function()
            push(player.UserId, snapshot)
            pushed[player.UserId] = nil
        end)
    end

    function service.start()
        for _, face in ctx.World.world:GetDescendants() do
            local key = face:IsA("BasePart") and face:GetAttribute("Leaderboard")
            if key and byKey[key] then
                service.panels[key] = service.panels[key] or {}
                table.insert(service.panels[key], buildPanel(face, byKey[key], settings.Size))
            end
        end
        service.render()
        task.spawn(function()
            while true do
                refresh()
                service.render()
                task.wait(settings.RefreshSeconds)
            end
        end)
        task.spawn(function()
            while true do
                task.wait(settings.PushSeconds)
                for _, player in Players:GetPlayers() do
                    local record = ctx.profiles.records[player.UserId]
                    if record and ctx.profiles:ready(player.UserId) then push(player.UserId, record.profile) end
                end
            end
        end)
        task.spawn(function()
            while true do
                task.wait(settings.RenderSeconds)
                service.render()
            end
        end)
    end
    return service
end

return Leaderboards
