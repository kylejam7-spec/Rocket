# Pet models: FBX to Roblox

The pets are the 50 Quaternius *Ultimate Monsters* models (CC0) in
`assets/models-textures/Pets`: Blob (17), Big/Large (16) and Flying (17).

## State (2026-10-18)

- **Imported:** `src/ReplicatedStorage/PetModels.rbxm` (Rojo serves it). It has one Model
  per catalog id. Each model is upright, faces -Z, has its pivot at its feet, and is
  anchored decor. Each also has `Clips/Idle` and `Clips/Move` (KeyframeSequences from
  its FBX: Idle and Walk, or Flying_Idle and Fast_Flying for flyers).
  `Shared/PetAnimator` plays these by writing the Bones' `Transform`, so no animation
  assets are uploaded. `Shared/PetModels` sizes each copy as a pet:
  `PetModels.Fit` gives Blob span 2.2, Large height 3 and Flying wingspan 3 studs.
- **Textures, still to do:** the FBX files reference an atlas they don't embed. There
  is one per pack, and all three are in `tools/pets/atlas/`. They're copies of the CC0
  Quaternius atlases taken from public Godot projects that use the same pack
  (galensoft/learning-godot, Godot-Dojo/Godot-XR-Avatar). The two 32 px palettes are
  upscaled to 512 px, nearest neighbour, so filtering can't blur the colour cells.
  Previews of all 50 rendered with them came out right.
  1. Upload the three PNGs as Images: Studio's Asset Manager > Bulk Import, or Creator
     Dashboard. Use the account that owns the experience.
  2. Paste the ids into `PetModels.Atlases` (`Blob`, `Large`, `Flying`) as
     `"rbxassetid://..."`. Every copy gets its pack's atlas as its MeshParts' `TextureID`.

## Re-importing (if the models ever change)

1. Run `python tools/pets/stage.py`. It copies each FBX to
   `assets/models-textures/Pets/import/<Id>.fbx`, so the duplicate file names (Alien is in
   both Blob and Big) don't collide and imports carry the catalog id.
2. Bulk import them in Studio (*File > Import 3D*), with animations.
3. For each model, take `CharacterArmature|Idle` and the move clip from
   `ServerStorage.RBX_ANIMSAVES.<Id>` into a `Clips` folder as `Idle` / `Move`. Drop
   `InitialPoses`, `AnimSaves` and the `AnimationController`, make the parts anchored decor,
   and put the pivot at the feet.
4. **Watch the orientation:** the importer gives each model a pivot turned 90° about X.
   Re-pivot without turning the parts (single-mesh models have no PrimaryPart;
   multi-mesh ones have an invisible `RootPart` holding the bones, which is their
   PrimaryPart). Then check the skeleton stands up: the head bone should be well above the
   feet.
5. Serialize `ReplicatedStorage.PetModels` (SerializationService) to
   `src/ReplicatedStorage/PetModels.rbxm`, then rerun RunChecks. PetCheck checks every
   pet's size, pivot and clips.
