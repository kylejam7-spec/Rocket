# Earth site models: Kenney kits to Roblox

The Earth launch site is built in code (`SiteLayout`, `MapExpansionService`,
`MaterialStationService`, `SiteDressingService`). Kenney meshes (CC0) from the factory,
space and space-station kits dress it: `SiteDressingService.Props` lists each placement
(model, x, z, yaw, studs per kit metre, solid) and `SiteProps.place` stands a copy there.
The models are in `src/ServerScriptService/SiteModels.rbxm`, which Rojo serves.
`SitePropsCheck` checks the models and keeps every placement off the lane, stations,
spawn, forecourt huts and Tier 5's launch footprint.

## State (2026-10-18)

- **Factory and station kits:** imported. Their palettes are uploaded, and the ids are in
  `SiteProps.Palettes`.
- **Space kit:** its FBX files are ASCII with flat material colours, and Studio's importer
  drops those colours, so every mesh came in grey. `bake_space.py` re-exports them with
  the colours baked into a palette that's embedded in each FBX, so the importer uploads it
  itself.

## Rebuilding the models

1. **Stage.** Run `python tools/map/stage.py`. It copies the picked factory and station
   FBX files to `assets/models-textures/Map/import/<Kit>_<name>.fbx`, with each kit's
   `<Kit>_colormap.png`. Edit `PICKS` to change the set.
2. **Bake the space kit.** Run `blender -b --factory-startup -P tools/map/bake_space.py`.
   It reads the kit's GLB files and writes `Map/import-space/Space_<name>.fbx`.
3. **Import.** In Studio, open *File > Import 3D* and import every FBX from `import/`
   (skip the `Space_*` ones there) and from `import-space/`.
4. **Palettes.** Upload `Factory_colormap.png` and `Station_colormap.png` as Images,
   only if they changed, and put the ids in `SiteProps.Palettes`.
5. **Prepare.** Paste `tools/map/prepare.luau` into the command bar (Edit mode). It
   gathers the imports into `ServerStorage.KenneyImport` and builds
   `ServerStorage.SiteModels`: anchored, box collision, pivot at the base, 10 studs per
   kit metre.
6. **Save.** Serialize `ServerStorage.SiteModels` (SerializationService) to
   `src/ServerScriptService/SiteModels.rbxm`, the same way as `PetModels.rbxm`
   (`tools/pets/README.md`). Then rerun RunChecks.
