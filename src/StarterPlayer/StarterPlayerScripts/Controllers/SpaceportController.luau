-- Runs the spaceport's monorail train (SpaceportService's MonorailTrain) up the track to
-- the apron and back to the campus station, easing in and out with a wait at each end,
-- and turns the wind farm's rotors. Local only: the server never moves either, so every
-- client just plays the same schedule from the server clock.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SpaceportController = {}

local RUN, WAIT = 28, 10 -- seconds travelling each way, seconds waiting at each end
local CYCLE = 2 * (RUN + WAIT)
local FAR = 2200 -- skip updates while the camera is this far from the train
local ROTOR_SPEED, ROTOR_FAR = 0.6, 3500 -- radians a second; skip rotors this far away

-- 0 at the campus station, 1 at the apron end, for a time in the cycle.
local function along(t)
    t %= CYCLE
    if t < WAIT then return 0 end
    t -= WAIT
    if t < RUN then return (1 - math.cos(math.pi * t / RUN)) / 2 end
    t -= RUN
    if t < WAIT then return 1 end
    t -= WAIT
    return (1 + math.cos(math.pi * t / RUN)) / 2
end

local function spinRotors()
    local rotors = {}
    local function add(rotor)
        if rotor:IsA("Model") and rotor.PrimaryPart then
            table.insert(rotors, { model = rotor, home = rotor:GetPivot(), phase = #rotors * 0.7 })
        end
    end
    CollectionService:GetInstanceAddedSignal("WindTurbineRotor"):Connect(add)
    for _, rotor in CollectionService:GetTagged("WindTurbineRotor") do add(rotor) end
    RunService.Heartbeat:Connect(function()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local now = Workspace:GetServerTimeNow()
        for _, rotor in rotors do
            if (camera.CFrame.Position - rotor.home.Position).Magnitude < ROTOR_FAR and rotor.model.Parent then
                rotor.model:PivotTo(rotor.home * CFrame.Angles(0, 0, now * ROTOR_SPEED + rotor.phase))
            end
        end
    end)
end

function SpaceportController.start()
    spinRotors()
    local spaceport = Workspace:WaitForChild("RocketWorld"):WaitForChild("Spaceport", 120)
    local train = spaceport and spaceport:WaitForChild("MonorailTrain", 30)
    if not train then return end
    local travel = train:GetAttribute("Travel") or 0
    local cars = {}
    for _, car in train:GetChildren() do
        if car:IsA("Model") then table.insert(cars, { model = car, home = car:GetPivot() }) end
    end
    local last
    RunService.Heartbeat:Connect(function()
        local offset = along(Workspace:GetServerTimeNow()) * travel
        if offset == last then return end
        local camera = Workspace.CurrentCamera
        local head = cars[1] and cars[1].home.Position + Vector3.new(0, 0, offset)
        if camera and head and (camera.CFrame.Position - head).Magnitude > FAR then return end
        last = offset
        for _, car in cars do
            car.model:PivotTo(car.home + Vector3.new(0, 0, offset))
        end
    end)
end

return SpaceportController
