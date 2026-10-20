-- Runs the spaceport's monorail train (SpaceportService's MonorailTrain) up the track to
-- the apron and back to the campus station, easing in and out with a wait at each end.
-- Local only: the server never moves the train, so every client just plays the same
-- schedule from the server clock (players see it in the same place).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SpaceportController = {}

local RUN, WAIT = 28, 10 -- seconds travelling each way, seconds waiting at each end
local CYCLE = 2 * (RUN + WAIT)
local FAR = 2200 -- skip updates while the camera is this far from the train

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

function SpaceportController.start()
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
