"""Stages the Kenney models picked for the Earth site for one bulk import into Studio.

Copies each chosen FBX to assets/models-textures/Map/import/<Kit>_<name>.fbx (so names
from different kits can't collide and imports say where they came from), plus each
kit's palette texture as <Kit>_colormap.png. The factory and space-station kits colour
their models from that palette (like the pets' atlases): upload the two PNGs as Images
and their ids go in SiteProps.Palettes. The space kit uses flat material colours that
Studio drops, so its picks are baked by bake_space.py instead of staged here.

    python tools/map/stage.py
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KITS = os.path.join(ROOT, "assets", "models-textures")
OUT = os.path.join(KITS, "Map", "import")

PICKS = {
    ("Factory", "kenney_factory-kit_3.0"): [
        "crane", "crane-lift", "crane-magnet", "structure-tall", "structure-high", "structure-yellow-tall",
        "structure-yellow-high", "catwalk-straight", "catwalk-stairs", "catwalk-corner", "conveyor-long",
        "conveyor-long-sides", "hopper-high-square", "hopper-round", "machine", "machine-fortified", "pipe-large",
        "pipe-large-long", "pipe-large-bend", "pipe-large-valve", "box-large", "box-long", "box-wide", "cone",
        "warning-orange", "warning-traffic", "robot-arm-a", "robot-arm-b", "screen-wide", "floor-large",
        "indicator-special-lines",
    ],
    ("Space", "kenney_space-kit"): [
        "hangar_largeA", "hangar_largeB", "hangar_roundA", "hangar_roundGlass", "machine_generatorLarge",
        "machine_barrelLarge", "machine_wireless", "satelliteDish_large", "satelliteDish_detailed", "supports_high",
        "structure_detailed", "platform_large", "barrels", "barrels_rail", "craft_cargoA", "craft_cargoB", "rover",
        "gate_complex", "pipe_supportHigh", "chimney_detailed", "rocket_baseA", "rocket_fuelA", "rocket_topA",
        "astronautA", "astronautB", "rock_largeA", "crater",
    ],
    ("Station", "kenney_space-station-kit"): [
        "container-tall", "container-wide", "container", "skip-rocks", "skip", "structure-barrier-high",
        "structure-barrier", "stairs", "display-wall-wide",
    ],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    staged, missing = 0, []
    for (kit, folder), names in PICKS.items():
        if kit == "Space":
            continue
        models = os.path.join(KITS, folder, "Models", "FBX format")
        for name in names:
            source = os.path.join(models, name + ".fbx")
            if not os.path.exists(source):
                missing.append(f"{folder}/{name}")
                continue
            shutil.copyfile(source, os.path.join(OUT, f"{kit}_{name}.fbx"))
            staged += 1
        palette = os.path.join(models, "Textures", "colormap.png")
        if os.path.exists(palette):
            shutil.copyfile(palette, os.path.join(OUT, f"{kit}_colormap.png"))
    print(f"staged {staged} models in {os.path.relpath(OUT, ROOT)}")
    for name in missing:
        print("  missing", name)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
