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
    Europa wears the dark navy sky under a small cold sun, with Jupiter's orange glow as
    fill from below (ColorShift_Bottom), and glossy ice.
    Saturn's rings have their own sky (textures.py `saturn_sky`): stars all round and the
    rings edge on as a glowing line along the horizon; they light things from below.
    Mars has its own daytime sky (tools/planets/textures.py: dusty rose overhead to a pale
    butterscotch horizon), warm afternoon light and a thin dust haze that fades the far
    mesas into the sky.
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
    Mars = {
        faces = faces(116733246444349, 112767906081295, 96691941054366, 134366695000385, 77374313685282, 139021632660213),
        sun = true,
        moon = false,
        -- Afternoon: the sun in the west (-X), left of anyone facing the canyon.
        lighting = { ClockTime = 15.6, GeographicLatitude = 42, Brightness = 2.6, Ambient = Color3.fromRGB(74, 48, 38),
            OutdoorAmbient = Color3.fromRGB(150, 104, 80), EnvironmentDiffuseScale = 0.35, EnvironmentSpecularScale = 0.3,
            ShadowSoftness = 0.2, ColorShift_Top = Color3.fromRGB(255, 214, 170) },
        atmosphere = { Density = 0.22, Offset = 0, Color = Color3.fromRGB(205, 150, 110), Decay = Color3.fromRGB(190, 120, 84), Glare = 0, Haze = 0.6 },
    },
    Europa = {
        faces = faces(135698275869633, 89429151521851, 112325889790250, 134675348379561, 116080667193829, 104136192848757),
        sun = true,
        moon = false,
        -- Sun low from +X, so Jupiter (beyond the landing site) is half lit.
        lighting = { ClockTime = 7.8, GeographicLatitude = 42, Brightness = 1.6, Ambient = Color3.fromRGB(30, 40, 60),
            OutdoorAmbient = Color3.fromRGB(72, 92, 124), EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 0.7,
            ShadowSoftness = 0.08, ColorShift_Top = Color3.fromRGB(205, 228, 255), ColorShift_Bottom = Color3.fromRGB(120, 76, 44) },
    },
    Saturn = {
        faces = faces(96836179595217, 70901967949717, 111141752494092, 94514358915591, 117806823065119, 125914376227514),
        sun = true,
        moon = false,
        -- Sun low from -X: Saturn (beyond the landing site) is half lit from the left.
        lighting = { ClockTime = 16.6, GeographicLatitude = 42, Brightness = 1.9, Ambient = Color3.fromRGB(34, 34, 46),
            OutdoorAmbient = Color3.fromRGB(82, 82, 98), EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 0.5,
            ShadowSoftness = 0.1, ColorShift_Top = Color3.fromRGB(255, 238, 206), ColorShift_Bottom = Color3.fromRGB(86, 80, 66) },
    },
    Band = {
        faces = faces(87670783189823, 84277202571331, 136923449858016, 100857173953889, 106596975936954, 96253202128209),
    },
})
-- Which set each destination (Config.Destinations id) and the cabin use.
Skies.ByPlace = table.freeze({ Moon = "Moon", Mars = "Mars", Europa = "Europa", Saturn = "Saturn", BlackHole = "Band", RocketCabin = "Space" })

local LIGHTING_KEYS = { "ClockTime", "GeographicLatitude", "Brightness", "Ambient", "OutdoorAmbient",
    "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness", "ColorShift_Top", "ColorShift_Bottom" }
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
