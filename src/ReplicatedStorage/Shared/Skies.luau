--[[
    Skyboxes (Kenney Skyboxes Space, CC0), cut into Roblox's six faces by
    tools/sky/cubemap.py. Earth wears the dusk sky with land and a far mountain range
    painted below and on its horizon (--land), matching the grass plain: when Roblox
    shortens the draw distance (it does when the frame rate dips, as in a launch) the
    distant world gives way to more of the same land, not purple sky. No haze: it thickened
    with the camera's height and swallowed the ground during the launch shots. Space
    destinations get the galaxy, the Black Hole the bright band.
    Skies.apply(name) swaps the local Lighting (DestinationController picks the name). A set
    may give `atmosphere` (Atmosphere properties), `lighting` (Lighting properties, from
    LIGHTING_KEYS; any it leaves out go back to the place's own) and `moon = false` to hide
    Roblox's moon (standing on the Moon, there shouldn't be another in the sky).
    The Moon's set is the galaxy under a low, hard sun: dark fill and sharp shadows, so
    every crater rim and rock throws a long shadow and the Earth shows a terminator.
]]
local Lighting = game:GetService("Lighting")
local Skies = {}

local function faces(bk, dn, ft, lf, rt, up)
    return { Bk = bk, Dn = dn, Ft = ft, Lf = lf, Rt = rt, Up = up }
end

local GALAXY = faces(134664654153944, 128519848611002, 122380106257368, 111516135636938, 88118147567612, 131930288039490)
Skies.Sets = table.freeze({
    Earth = {
        faces = faces(114916478202084, 78986771335343, 119047115779431, 128101403518562, 96105877986502, 83836347376752),
        sun = true,
    },
    Space = {
        faces = GALAXY,
    },
    Moon = {
        faces = GALAXY,
        sun = true,
        moon = false,
        -- Sun low from +X (behind the right shoulder of anyone facing the landing site).
        lighting = { ClockTime = 7.3, GeographicLatitude = 42, Brightness = 3.2, Ambient = Color3.fromRGB(26, 28, 36),
            OutdoorAmbient = Color3.fromRGB(62, 66, 82), EnvironmentDiffuseScale = 0.2, EnvironmentSpecularScale = 0.4, ShadowSoftness = 0.04 },
    },
    Band = {
        faces = faces(87670783189823, 84277202571331, 136923449858016, 100857173953889, 106596975936954, 96253202128209),
    },
})
-- Which set each destination (Config.Destinations id) and the cabin use.
Skies.ByPlace = table.freeze({ Moon = "Moon", Mars = "Space", Europa = "Space", Saturn = "Space", BlackHole = "Band", RocketCabin = "Space" })

local LIGHTING_KEYS = { "ClockTime", "GeographicLatitude", "Brightness", "Ambient", "OutdoorAmbient",
    "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness" }
local sky, atmosphere, current, defaults
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
        defaults = { MoonAngularSize = sky.MoonAngularSize }
        for _, key in LIGHTING_KEYS do defaults[key] = Lighting[key] end
    end
    local lighting = set.lighting or {}
    for _, key in LIGHTING_KEYS do
        if lighting[key] ~= nil then Lighting[key] = lighting[key] else Lighting[key] = defaults[key] end
    end
    sky.MoonAngularSize = set.moon == false and 0 or defaults.MoonAngularSize
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
