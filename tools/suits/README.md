# Astronaut suits: Blender to Roblox

The suit armour (`Shared/Skins`, `SkinService`, `SuitFxController`) is modelled in code by
`build_suits.py`, around the default R15 blocky body the game spawns (sizes measured in
Studio). In game it is `src/ReplicatedStorage/SuitModels.rbxm`: 72 MeshParts, one per piece,
each with attributes `BodyPart`, `Role` (Base, Trim, Dark, Glow, Glass) and `Offset` (its
CFrame relative to that body part at rest). Every suit shares the pieces; `Shared/Skins`
lists which ones each suit wears and how each role draws in it.

The Galaxy Astronaut's star field is `assets/models-textures/Suits/Galaxy.png`
(`galaxy_texture.py`, seamless 512 px), uploaded as image 75317861591571
(`Skins.GalaxyTexture`).

## Rebuilding

1. **Model.** Run `blender -b --factory-startup -P tools/suits/build_suits.py -- --preview --fbx`
   (Blender 5.2). `--preview` renders the four suits to `tools/suits/preview.png` and
   `preview_back.png`; `--fbx` writes `assets/models-textures/Suits/import/SuitArmor.fbx`
   with four markers for the import's scale and axes.
2. **Import.** In Studio (Edit), *File > Import 3D* that FBX with the default settings. The
   meshes upload to whoever imports, so use the account that owns the experience.
3. **Prepare.** Run `tools/suits/prepare_suits.luau` in the command bar. It builds
   `ReplicatedStorage.SuitModels` from the import (reading the markers, refusing a mirrored
   import) and deletes the import.
4. **Save.** Serialize `ReplicatedStorage.SuitModels` (SerializationService) to
   `src/ReplicatedStorage/SuitModels.rbxm`, written out over a local HTTP receiver, then
   rerun RunChecks: SkinCheck checks every listed piece exists and dresses a stand-in body.

A new piece needs a name in `build_suits.py` (`<Piece>__<BodyPart>__<Role>`) and a place in
a suit's list in `Shared/Skins`; its colours come from the suit's roles.
