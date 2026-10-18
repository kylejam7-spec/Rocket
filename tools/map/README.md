# Earth site models: Kenney kits to Roblox

The Earth launch site is built in code (`SiteLayout`, `MapExpansionService`,
`MaterialStationService`, `SiteDressingService`), from primitives for now. Kenney meshes
(CC0) can replace or add to the props once they are in Studio.

## Steps

1. **Stage.** Run `python tools/map/stage.py`. It copies 67 picked models from the factory,
   space and space-station kits to `assets/models-textures/Map/import/<Kit>_<name>.fbx`.
   It also copies each palette kit's texture as `Factory_colormap.png` and
   `Station_colormap.png`. Edit `PICKS` in the script to change the set.
2. **Import.** In Studio, open *File > Import 3D*, select every FBX in `import/`, and
   import them.
3. **Textures.** The factory and station models take their colours from those two
   palettes, which the FBX files don't embed. Upload the two PNGs as Images (Asset
   Manager > Bulk Import), then give Claude the ids. The space-kit models use plain
   material colours.
4. **Collect.** Claude gathers the imports into a site props folder and applies the
   palettes. It then saves them as an `.rbxm` that Rojo serves, the same way as the pets
   (see `tools/pets/README.md`).
