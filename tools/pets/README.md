# Pet models: FBX to Roblox

The pets are the 50 Quaternius *Ultimate Monsters* models (CC0) in
`assets/models-textures/Pets`: Blob (17), Big/Large (16) and Flying (17). Until they are
imported, the game draws each pet as a primitive stand-in of the same form
(`Shared/PetModels.luau`), so everything works without them.

## Steps

1. **Texture.** The FBX files use one shared texture, `Atlas_Monsters.png`, but don't embed
   it. Copy it from the Quaternius download (its `Textures` folder) anywhere under
   `assets/models-textures/Pets`.
2. **Stage.** Run `python tools/pets/stage.py`. It copies each model to
   `assets/models-textures/Pets/import/<Id>.fbx`, named by its catalog id (`Blob_Alien`,
   `Large_Alien` and so on), so the duplicate file names stop colliding. It also copies the
   atlas in and reports anything missing.
3. **Import.** In Studio, open *File > Import 3D*, select all 50 files in `import/`, and
   import them with the atlas as the texture. Studio uploads the meshes and the texture to
   the experience owner's account. Leave *Add to Workspace* on.
4. **Collect.** Claude (or the snippet below) moves the imported models into
   `ReplicatedStorage.PetModels`, one Model per id. It points every MeshPart at the
   uploaded atlas and removes the rigs' Humanoid and AnimationController. The models are
   then saved to `src/ReplicatedStorage/PetModels.rbxm`, which Rojo serves.
5. **Check.** Rerun `RunChecks`. `PetModels.pet(id)` now clones the real mesh, turns it
   to face -Z (`PetModels.ImportedYaw`), and scales it to the form's height. PetCheck
   asserts every pet's height and that its pivot is at its feet.

```lua
-- Command bar, after the import: gather the models into ReplicatedStorage.PetModels.
local Pets = require(game.ReplicatedStorage.Shared.Pets)
local folder = game.ReplicatedStorage:FindFirstChild("PetModels") or Instance.new("Folder")
folder.Name, folder.Parent = "PetModels", game.ReplicatedStorage
for _, entry in Pets.Catalog do
    local model = workspace:FindFirstChild(entry.Id)
    if model then model.Parent = folder else warn("not imported: " .. entry.Id) end
end
```

## Known follow-ups

- The Large models import in their T-pose bind pose. Pose them at rest, and later play
  Idle, Walk and Fly, by driving the rig's Bones (`UpperArm.L/R`, `UpperLeg.L/R`,
  `Wing1-4.L/R`). One way is to bake each FBX's Idle and Flying_Idle curves into a Luau
  keyframe table offline, so no animation assets need uploading.
- `PetModels.ImportedYaw` (π) assumes the imports face +Z. Check one pet in Studio and
  flip it if they walk backwards.
