# Europa oarfish: GLB to Roblox

The oarfish that breaches at Europa (`Controllers/OarfishController`) is the user's
`assets/models-textures/Monster/Europa_Oarfish.glb`: one static mesh, 12.8 m long, with six
flat-colour materials. In game it is `src/ReplicatedStorage/EuropaOarfish.rbxm` (Rojo
serves it). That model has six MeshParts (`OarfishIce`, `OarfishMembrane`, `OarfishCrest`,
`OarfishTeal`, `OarfishPhoto` in Neon, `OarfishEye`) skinned to 17 bones, `B00` (nose) to
`B16` (tail tip), on its centre line under an invisible `RootPart`. The model's pivot sits
at the nose: it looks where the nose points, and its up vector goes through the dorsal fin.
The controller scales a copy to 360 studs and moves each bone onto the flight path.

## Rebuilding it

1. **Rig.** Run `blender -b --factory-startup -P tools/monster/rig_oarfish.py`. It also runs
   inside an open Blender, in a scene of its own that it removes afterwards. It writes
   `Monster/import/Europa_Oarfish_Rig.fbx`.
2. **Import.** In Studio, open *File > Import 3D* and import that FBX with the default
   settings.
3. **Prepare.** Paste `tools/monster/prepare_oarfish.luau` into the command bar (Edit mode).
   It builds `ReplicatedStorage.EuropaOarfish`: anchored decor, coloured from the GLB's
   materials, with the pivot as above.
4. **Save.** Serialize it (SerializationService) to `src/ReplicatedStorage/EuropaOarfish.rbxm`,
   written out over a local HTTP receiver, the same way as `PetModels.rbxm`. With Rojo
   connected, keep one copy.

**Keep the export small.** The importer reads 1 m as 100 studs. Any mesh longer than the
2048-stud part limit gets shrunk to fit, but its bones don't. The skinned mesh then draws
stretched and in pieces, and moving the bones afterwards doesn't fix it. At 12.8 m the fish
imports at 1,280 studs, under the limit. `prepare_oarfish.luau` stops with an error if the
meshes and bones disagree in size.


# Saturn UFO: FBX to Roblox

The UFO that crashes at Saturn (`Controllers/SaturnUfoController`) is the user's
`assets/models-textures/Monster/SaturnUFO.fbx`: a flying saucer with two alien pilots under a
glass canopy, 192 small meshes (~105,000 triangles) rigidly skinned to 18 bones (Root > Hull >
each pilot's Torso > Head and both arms > forearms > hands). In game it is
`src/ReplicatedStorage/SaturnUFO.rbxm`: nine MeshParts, one per material (`UFOTitanium`,
`UFOGraphite`, `UFOIon`, `UFOAmber`, `UFOCoral`, `UFOJade`, `UFOHighlight`, `UFOEyes`,
`UFOGlass`; 32,000 triangles), still skinned, so the controller poses the pilots through
`Bone.Transform`. Its pivot is the saucer's centre, looking where the pilots face, up through
the canopy. The colours are `SaturnUFO_Color.png`'s swatches set as flat part colours (no
texture).

1. **Reduce.** Run `F:/blender.exe -b --factory-startup -P tools/monster/rig_ufo.py`. It drops
   the stray default Cube, flips the hull's two shells (they face inward in the source),
   decimates each part to ~250 triangles per metre of its size and joins the parts by material. It writes `Monster/import/SaturnUFO_Rig.fbx`.
2. **Import.** In Studio, open *File > Import 3D* and import that FBX with the default
   settings. At 8.24 m it comes in 824 studs across, under the 2048-stud part limit.
3. **Prepare.** Paste `tools/monster/prepare_ufo.luau` into the command bar (Edit mode). It
   builds `ReplicatedStorage.SaturnUFO` (canopy and pilots at Precise render fidelity, hull
   double-sided) and stops with an error if bones are missing or the meshes and bones
   disagree in size. The saved model predates the flip: its hull is inward-facing but
   double-sided, which draws the same.
4. **Save.** Serialize it to `src/ReplicatedStorage/SaturnUFO.rbxm` as above. With Rojo
   connected, keep one copy.
5. **Access.** The importer uploads the meshes to whoever runs the import. Until the
   experience is given access to them, the parts don't draw in game ("User is not authorized
   to access Asset" in Output; click "share access" there).
