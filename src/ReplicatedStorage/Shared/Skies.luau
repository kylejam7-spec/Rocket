--[[
    Skyboxes (Kenney Skyboxes Space, CC0), cut into Roblox's six faces by
    tools/sky/cubemap.py, and the haze that goes with each. Earth wears the dusk sky with
    a purple haze that melts the far ground into the horizon; space destinations get the
    galaxy (the Black Hole the bright band) with no haze, so their giant planets stay crisp.
    Skies.apply(name) swaps the local Lighting (DestinationController picks the name).
]]
local Lighting = game:GetService("Lighting")
local Skies = {}

local function faces(bk, dn, ft, lf, rt, up)
    return { Bk = bk, Dn = dn, Ft = ft, Lf = lf, Rt = rt, Up = up }
end

Skies.Sets = table.freeze({
    Earth = {
        faces = faces(71940586335526, 111587257160763, 83331280995710, 115758681144593, 134531220958872, 83836347376752),
        sun = true,
        atmosphere = { Density = 0.24, Offset = 0.15, Color = Color3.fromRGB(150, 120, 225), Decay = Color3.fromRGB(96, 70, 170), Glare = 0, Haze = 1.6 },
    },
    Space = {
        faces = faces(134664654153944, 128519848611002, 122380106257368, 111516135636938, 88118147567612, 131930288039490),
    },
    Band = {
        faces = faces(87670783189823, 84277202571331, 136923449858016, 100857173953889, 106596975936954, 96253202128209),
    },
})
-- Which set each destination (Config.Destinations id) and the cabin use.
Skies.ByPlace = table.freeze({ Moon = "Space", Mars = "Space", Europa = "Space", Saturn = "Space", BlackHole = "Band", RocketCabin = "Space" })

local sky, atmosphere, current
function Skies.apply(name)
    if name == current then return end
    local set = Skies.Sets[name]
    if not set then return end
    current = name
    if not sky then
        for _, item in Lighting:GetChildren() do
            if item:IsA("Sky") or item:IsA("Atmosphere") then item:Destroy() end
        end
        sky = Instance.new("Sky")
        sky.Name = "RocketSky"
        sky.StarCount = 0
        sky.Parent = Lighting
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "RocketHaze"
    end
    for face, id in set.faces do
        sky["Skybox" .. face] = "rbxassetid://" .. id
    end
    sky.CelestialBodiesShown = set.sun == true
    if set.atmosphere then
        for key, value in set.atmosphere do atmosphere[key] = value end
        atmosphere.Parent = Lighting
    else
        atmosphere.Parent = nil
    end
end

return Skies
