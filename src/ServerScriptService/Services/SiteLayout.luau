--[[
    Where everything on the Earth launch site (the main map) stands, in one place.
    -Z is toward the launch site; the spawn lane runs along x = 0.

        z -480 .. -90   launch apron, the pad at its near end (rockets tilt toward -Z)
        z  -90 ..  -10  forecourt: Upgrades hut (west) and UFO Shop (east) either side
                        of the lane; site offices and stores off to the sides
        z  -45 ..   75  Salvage Yard (Metal, west) and Fuel Depot (Fuel, east), flanking
                        spawn a short walk out from the lane
        z  40           spawn
        z  112 ..       Gym District, behind spawn

    A round trip from either station to the foot of a ramp and back is ~300-350 studs,
    about what it was on the old, tighter map (UpgradeCheck's pacing model uses 460 with
    the climb), while the site itself is far roomier.
]]
local Layout = {}

-- The rocket's upright build frame on the pad top (RocketBuildService origin).
Layout.PadOrigin = CFrame.new(0, 0.58, -150)
-- The permanent pad under every tier (scaled Tier 5 complex: |x| <= 80, |z| <= 60).
Layout.Pad = { center = Vector3.new(0, 0.33, -150), size = Vector3.new(164, 0.5, 124) }
-- Concrete apron under the tilted rockets (Tier 5's farthest part reaches z = -385).
Layout.Apron = { x = 115, z0 = -480, z1 = -88 }
-- The base ground; map expansion adds strips outside |x| = Ground.x.
Layout.Ground = { x = 200, z0 = -500, z1 = 112 }

Layout.Spawn = Vector3.new(0, 1, 40)
Layout.Lane = { width = 20, z0 = -92, z1 = 112 }

-- Material stations: centre and footprint (x by z); each faces the lane.
Layout.StationFootprint = Vector2.new(90, 110)
Layout.Metal = Vector3.new(-125, 0, 15)
Layout.Fuel = Vector3.new(125, 0, 15)

Layout.Upgrades = Vector3.new(-42, 0, -42)
Layout.UfoShop = Vector3.new(42, 0, -42)

-- Gym District: first bay centre on z, bay step and bay offset from the walkway.
Layout.Gym = { z0 = 132, step = 16, x = 27, entrance = 114 }

-- Footprints map expansion must not pave over (the material stations).
Layout.Reserved = {}
for _, center in { Layout.Metal, Layout.Fuel } do
    table.insert(Layout.Reserved, {
        x0 = center.X - Layout.StationFootprint.X / 2, x1 = center.X + Layout.StationFootprint.X / 2,
        z0 = center.Z - Layout.StationFootprint.Y / 2, z1 = center.Z + Layout.StationFootprint.Y / 2,
    })
end

return table.freeze(Layout)
