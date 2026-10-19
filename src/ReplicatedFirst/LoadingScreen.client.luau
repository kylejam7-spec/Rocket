-- The loading screen: the first thing a joining player sees, until they can play.
-- It covers Roblox's own screen with the title art, a progress bar (a rocket riding
-- its tip) and rotating tips and jokes about the game, while it:
--   1. waits for the game to load and the server's world to be built (RocketWorld's
--      Built attribute);
--   2. preloads the textures, meshes and sounds in the world, the pets and the sound
--      effects (the bar follows each file), up to PRELOAD_LIMIT seconds;
--   3. asks the server to spawn the character (Remotes.ClientReady: characters don't
--      auto-load, Main) and holds it still until there's ground under it;
-- then fills the bar and fades away. It stays up at least MIN_SECONDS so a tip can be
-- read. Runs from ReplicatedFirst, so it can't use the UI modules (not here yet).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local ART = "rbxassetid://133247550435220"
-- Studio plays before an upload is allowed to load; it has a local copy (of
-- assets/loading/loading.png).
local ART_STUDIO = "rbxasset://textures/rocket-loading/loading.png"
local MIN_SECONDS, PRELOAD_LIMIT, TIP_SECONDS = 5, 25, 4.2
local DISPLAY, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold
local YELLOW, ORANGE, INK = Color3.fromRGB(255, 214, 64), Color3.fromRGB(255, 140, 40), Color3.fromRGB(24, 22, 48)

local TIPS = {
    "Hold E at the SALVAGE YARD to grab scrap metal, then carry it up the ramp to the glowing ring.",
    "Strength = more scrap per trip. The bench press in the GYM DISTRICT is free!",
    "Treadmills make you faster. Faster legs, more trips, bigger rocket.",
    "Fill a jerry can at the FUEL DEPOT and pour it into the rocket. Rockets are thirsty.",
    "Walk in through the green BOARD hatch before the countdown ends to fly along!",
    "Every destination pays free strength and speed for every second you're there.",
    "Gyms on other worlds pay double. Do your reps on the Moon!",
    "Gravity on the Moon is low. Your jumps will be legendary.",
    "Mars has dust devils. They're harmless. Probably.",
    "Europa's geysers go off every few seconds. Stand back... or don't.",
    "On Saturn's Rings, the ice drifts by in two directions. Don't try to count it.",
    "The mission wheel only lands on the Black Hole 3% of the time. Lucky you?",
    "Spend your coins at the UPGRADES hut. Coins can't fly you to space on their own.",
    "The UFO shop hatches alien pets that follow you around. They're very loyal.",
    "Carrying too much? Press Q to drop it.",
    "Everyone builds the same rocket. Teamwork makes the rocket work!",
    "No rockets were harmed in the making of this game. A few were launched very hard.",
    "Engineers recommend at least one (1) helmet.",
    "On the Moon, look up: that blue marble rising over the hills is home.",
    "Astronaut tip: space is big. Like, really big.",
}
-- What the status line says as the bar fills (from this fraction on).
local STATUS = {
    { 0, "Waking up the launch crew..." },
    { 0.15, "Building the launch site..." },
    { 0.3, "Gathering scrap metal..." },
    { 0.55, "Fueling the boosters..." },
    { 0.75, "Calibrating gravity..." },
    { 0.88, "Strapping you in..." },
    { 1, "Ready for liftoff!" },
}

local player = Players.LocalPlayer
local started = os.clock()

local function make(class, props, children)
    local item = Instance.new(class)
    for key, value in props do item[key] = value end
    for _, child in children or {} do child.Parent = item end
    return item
end
local function corner(radius) return make("UICorner", { CornerRadius = UDim.new(0, radius) }) end
local function stroke(thickness, color) return make("UIStroke", { Thickness = thickness, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function outline(thickness) return make("UIStroke", { Thickness = thickness, Color = INK }) end

local gui = make("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local backdrop = make("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 16, 44), BorderSizePixel = 0, Parent = gui })
-- The art fills the screen (cropped to fit) and drifts slowly closer.
local art = make("ImageLabel", { Name = "Art", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = ART, ImageTransparency = 1, Parent = backdrop })
local zoom = make("UIScale", { Scale = 1, Parent = art })
-- A shade up from the bottom so the bar and tips read over the art.
make("Frame", { Name = "Shade", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.42), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = backdrop },
    { make("UIGradient", { Rotation = 270, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }) }) })

local panel = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.new(0.62, 0, 0, 150), BackgroundTransparency = 1, Parent = backdrop },
    { make("UISizeConstraint", { MinSize = Vector2.new(300, 150), MaxSize = Vector2.new(820, 150) }) })
-- Tip card.
local card = make("Frame", { Name = "Tip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = INK, BackgroundTransparency = 0.25, Parent = panel },
    { corner(16), stroke(3, Color3.fromRGB(90, 80, 170)) })
local cardScale = make("UIScale", { Scale = 1, Parent = card })
local badge = make("TextLabel", { Name = "Badge", Position = UDim2.fromOffset(12, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(84, 26), BackgroundColor3 = YELLOW,
    Font = DISPLAY, Text = "TIP", TextSize = 18, TextColor3 = INK, Parent = card }, { corner(13), stroke(2) })
local tipText = make("TextLabel", { Name = "Text", Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 1, -20), BackgroundTransparency = 1, Font = BODY,
    TextSize = 18, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), Text = "", Parent = card })
-- Status line and percentage over the bar.
local status = make("TextLabel", { Name = "Status", Position = UDim2.fromOffset(4, 80), Size = UDim2.new(1, -70, 0, 26), BackgroundTransparency = 1, Font = DISPLAY, TextSize = 22,
    TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), Text = STATUS[1][2], Parent = panel }, { outline(2) })
local percent = make("TextLabel", { Name = "Percent", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 80), Size = UDim2.fromOffset(70, 26), BackgroundTransparency = 1,
    Font = DISPLAY, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = YELLOW, Text = "0%", Parent = panel }, { outline(2) })
-- The bar: a dark track, a yellow-to-orange fill with a moving shine, and a rocket on its tip.
local track = make("Frame", { Name = "Bar", Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = INK, Parent = panel }, { corner(13), stroke(3) })
local fill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = track },
    { corner(13), make("UIGradient", { Color = ColorSequence.new(YELLOW, ORANGE) }) })
local shine = make("Frame", { Name = "Shine", Size = UDim2.new(0, 60, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = fill },
    { make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
local rocket = make("TextLabel", { Name = "Rocket", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1,
    Text = "🚀", TextSize = 34, Rotation = 45, ZIndex = 3, Parent = track })

gui.Parent = player:WaitForChild("PlayerGui")

-- The art appears as soon as it has loaded (Studio falls back to its local copy).
task.spawn(function()
    -- Through the label, not the bare id (a bare id's fetch reports failure here).
    local result
    ContentProvider:PreloadAsync({ art }, function(_, fetched) result = fetched end)
    if result ~= Enum.AssetFetchStatus.Success and RunService:IsStudio() then
        art.Image = ART_STUDIO
        ContentProvider:PreloadAsync({ art })
    end
    TweenService:Create(art, TweenInfo.new(0.5), { ImageTransparency = 0 }):Play()
    TweenService:Create(zoom, TweenInfo.new(40, Enum.EasingStyle.Linear), { Scale = 1.12 }):Play()
end)

-- Tips: shuffled, each popping in for TIP_SECONDS; every third is badged FUN FACT.
task.spawn(function()
    local order = table.clone(TIPS)
    for index = #order, 2, -1 do
        local other = math.random(1, index)
        order[index], order[other] = order[other], order[index]
    end
    local index = 0
    while gui.Parent do
        index = index % #order + 1
        badge.Text = index % 3 == 0 and "FUN FACT" or "TIP"
        badge.Size = UDim2.fromOffset(index % 3 == 0 and 104 or 64, 26)
        tipText.Text = order[index]
        cardScale.Scale = 0.94
        TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        task.wait(TIP_SECONDS)
    end
end)

-- Progress: `target` is where loading has got to; the bar eases toward it.
local target, shown = 0, 0
local function reach(value) target = math.max(target, math.min(1, value)) end
local animation = RunService.RenderStepped:Connect(function(dt)
    shown += (target - shown) * math.min(1, dt * 5)
    fill.Size = UDim2.fromScale(shown, 1)
    rocket.Position = UDim2.new(shown, 0, 0.5, math.sin(os.clock() * 9) * 2)
    shine.Position = UDim2.new((os.clock() * 0.6) % 1.6 - 0.3, 0, 0, 0)
    percent.Text = math.floor(shown * 100 + 0.5) .. "%"
    for index = #STATUS, 1, -1 do
        if shown >= STATUS[index][1] - 0.001 then status.Text = STATUS[index][2] break end
    end
end)

-- 1. The game, then the server's world. The world can take a while when the server
-- has only just started (it builds every destination), so the bar creeps toward 0.2
-- meanwhile instead of sitting still.
if not game:IsLoaded() then game.Loaded:Wait() end
reach(0.1)
local waitStart = os.clock()
local world
local worldDeadline = os.clock() + 45
repeat
    world = workspace:FindFirstChild("RocketWorld")
    reach(0.1 + 0.095 * (1 - math.exp(-(os.clock() - waitStart) / 5)))
    task.wait(0.1)
until (world and world:GetAttribute("Built")) or os.clock() > worldDeadline
reach(0.2)

-- 2. Preload what the world, the pets and the sound effects use (0.2 -> 0.85). By the
-- instances that use each file (one per file), not bare ids: Roblox then knows each
-- file's type (bare ids are fetched as images, and sounds and meshes fail).
local PROPERTIES = { "Texture", "TextureID", "TextureId", "MeshId", "Image", "SoundId", "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local seen, content = {}, {}
local function collect(root)
    if not root then return end
    for _, item in root:GetDescendants() do
        local new = false
        for _, property in PROPERTIES do
            local ok, value = pcall(function() return item[property] end)
            if ok and typeof(value) == "string" and value ~= "" and not seen[value] then
                seen[value] = true
                new = true
            end
        end
        if new then table.insert(content, item) end
    end
end
collect(world)
collect(ReplicatedStorage:FindFirstChild("PetModels"))
local ok, soundIds = pcall(require, ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundIds"))
if ok then
    for file, id in soundIds do
        -- Not the music: it streams in as it plays.
        if not file:find("^music/") and not seen[id] then
            seen[id] = true
            table.insert(content, make("Sound", { SoundId = id }))
        end
    end
end
local files = 0
for _ in seen do files += 1 end
local loaded, finished = 0, false
task.spawn(function()
    ContentProvider:PreloadAsync(content, function()
        loaded += 1
        reach(0.2 + 0.65 * loaded / math.max(1, files))
    end)
    finished = true
end)
local deadline = os.clock() + PRELOAD_LIMIT
while not finished and os.clock() < deadline do task.wait(0.1) end
reach(0.85)

-- 3. The character: ask for it, then hold it still until there's ground beneath it.
local ready = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClientReady")
ready:FireServer()
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart", 15)
reach(0.92)
if root then
    root.Anchored = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local groundBy = os.clock() + 10
    while os.clock() < groundBy and not workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params) do task.wait(0.1) end
    root.Anchored = false
end

-- Done: fill up, give the last tip a moment, fade out.
reach(1)
while os.clock() - started < MIN_SECONDS or shown < 0.995 do task.wait(0.05) end
task.wait(0.4)
local fade = TweenInfo.new(0.6)
for _, item in gui:GetDescendants() do
    if item:IsA("GuiObject") then
        TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
        if item:IsA("TextLabel") then TweenService:Create(item, fade, { TextTransparency = 1 }):Play() end
        if item:IsA("ImageLabel") then TweenService:Create(item, fade, { ImageTransparency = 1 }):Play() end
    elseif item:IsA("UIStroke") then
        TweenService:Create(item, fade, { Transparency = 1 }):Play()
    end
end
task.wait(0.65)
animation:Disconnect()
gui:Destroy()
