--[[
    Skyboxes (Kenney Skyboxes Space, CC0), cut into Roblox's six faces by
    tools/sky/cubemap.py. Earth wears the dusk sky with land and a far mountain range
    painted below and on its horizon (--land), matching the grass plain: when Roblox
    shortens the draw distance (it does when the frame rate dips, as in a launch) the
    distant world gives way to more of the same land, not purple sky. No haze: it thickened
    with the camera's height and swallowed the ground during the launch shots. Space
    destinations get the galaxy, the Black Hole the bright band.
    Skies.apply(name) swaps the local Lighting (DestinationController picks the name). A set
    may give `atmosphere` (Atmosphere properties).
]]
local Lighting = game:GetService("Lighting")
local Skies = {}

local function faces(bk, dn, ft, lf, rt, up)
    return { Bk = bk, Dn = dn, Ft = ft, Lf = lf, Rt = rt, Up = up }
end

Skies.Sets = table.freeze({
    Earth = {
        faces = faces(114916478202084, 78986771335343, 119047115779431, 128101403518562, 96105877986502, 83836347376752),
        sun = true,
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
