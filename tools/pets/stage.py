"""Stages the pet FBX files for import into Roblox Studio.

The three Quaternius "Ultimate Monsters" downloads in assets/models-textures/Pets share
file names (Alien.fbx is in both Blob and Big), so this copies each one to
assets/models-textures/Pets/import/<Id>.fbx, where <Id> is the pet's catalog id in
src/ReplicatedStorage/Shared/Pets.luau (e.g. Large_Alien). Studio names an imported
model after its file, so the imports already carry the names PetModels looks up.

    python tools/pets/stage.py            (stage and check)
    python tools/pets/stage.py --check    (only report what's missing)

It also reports whether Atlas_Monsters.png is present: the FBX files reference it but
don't embed it. The game textures the meshes itself from tools/pets/atlas (see README).
"""
import argparse
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PETS = os.path.join(ROOT, "assets", "models-textures", "Pets")
OUT = os.path.join(PETS, "import")
CATALOG = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Pets.luau")
# Which download holds which form (checked against the models' rigs and silhouettes).
FOLDERS = {
    "drive-download-20261018T163850Z-1-001": "Blob",
    "drive-download-20261018T163915Z-1-001": "Large",
    "drive-download-20261018T163936Z-1-001": "Flying",
}
ATLAS = "Atlas_Monsters.png"


def catalog():
    rows = re.findall(r'\{ "(Blob|Large|Flying)", "(\w+)", "[^"]+", "\w+" \}', open(CATALOG, encoding="utf-8").read())
    return {(form, model) for form, model in rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="report only, copy nothing")
    args = parser.parse_args()
    wanted = catalog()
    found = {}
    for folder, form in FOLDERS.items():
        path = os.path.join(PETS, folder)
        if not os.path.isdir(path):
            continue
        for name in sorted(os.listdir(path)):
            if name.lower().endswith(".fbx"):
                found[(form, name[:-4])] = os.path.join(path, name)
    missing = sorted(wanted - found.keys())
    extra = sorted(found.keys() - wanted)
    print(f"catalog {len(wanted)} pets, found {len(found)} FBX files")
    for form, model in missing:
        print(f"  missing FBX for {form}_{model}")
    for form, model in extra:
        print(f"  FBX not in the catalog: {form}/{model}.fbx")
    atlas = [os.path.join(dirpath, ATLAS) for dirpath, _, files in os.walk(PETS) if ATLAS in files]
    print(f"{ATLAS}: " + (atlas[0] if atlas else "not found (fine: the game uses tools/pets/atlas)"))
    if args.check:
        return 1 if missing else 0
    os.makedirs(OUT, exist_ok=True)
    for key in sorted(wanted & found.keys()):
        shutil.copyfile(found[key], os.path.join(OUT, f"{key[0]}_{key[1]}.fbx"))
    if atlas:
        shutil.copyfile(atlas[0], os.path.join(OUT, ATLAS))
    print(f"staged {len(wanted & found.keys())} files in {os.path.relpath(OUT, ROOT)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
