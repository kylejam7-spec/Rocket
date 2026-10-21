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
