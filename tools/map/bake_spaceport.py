"""Bakes the spaceport picks (2026-10-20) into one FBX per kit for a three-file import.

Each picked model is joined into a single mesh named <Kit>_<name>, and every kit's models
go into one binary FBX with the kit's palette embedded, so Studio's importer uploads one
image per kit and brings each model in as one MeshPart of that file's model
(tools/map/prepare_spaceport.luau splits them out).

- Space kit: flat material colours, which the importer drops, are baked into a palette of
  every colour in the kit (so any pick, old or new, fits it). All Space picks, the ones
  already in SiteModels included, are rebaked onto it.
- Modular space kit and space station kit: already textured from their colormap.png.

    blender -b --factory-startup -P tools/map/bake_spaceport.py -- <kits folder> <out folder>

<kits folder> holds kenney_space-kit, kenney_modular-space-kit_1.0 and
kenney_space-station-kit as downloaded. Output: Spaceport_Space.fbx,
Spaceport_Modular.fbx and Spaceport_Station.fbx (+ Space_colormap.png).
"""
import importlib.util
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ARGS = sys.argv[sys.argv.index("--") + 1:]
KITS, OUT = ARGS[0], ARGS[1]

SPACE_DIR = os.path.join(KITS, "kenney_space-kit", "Models", "GLTF format")
FOLDERS = {
    "Modular": os.path.join(KITS, "kenney_modular-space-kit_1.0", "Models", "GLB format"),
    "Station": os.path.join(KITS, "kenney_space-station-kit", "Models", "GLB format"),
}

PICKS = {
    "Space": [
        "monorail_trackStraight", "monorail_trackSupport", "monorail_trackCornerLarge", "monorail_trackSlope",
        "monorail_trainFront", "monorail_trainPassenger", "monorail_trainCargo", "monorail_trainBox",
        "monorail_trainEnd", "corridor", "corridor_window", "corridor_cornerRound", "corridor_cross",
        "corridor_split", "corridor_end", "corridor_detailed", "hangar_roundB", "hangar_smallA", "hangar_smallB",
        "craft_speederA", "craft_speederD", "craft_racer", "craft_miner", "rocket_baseB", "rocket_fuelB",
        "rocket_sidesA", "rocket_sidesB", "rocket_topB", "rocket_finsA", "rocket_finsB", "platform_long",
        "platform_high", "platform_low", "platform_small", "satelliteDish", "pipe_ringHigh", "pipe_straight",
        "pipe_supportLow", "structure", "structure_closed", "structure_diagonal", "supports_low",
        "machine_generator", "machine_barrel", "machine_wirelessCable", "rock_largeB", "rocks_smallA",
        "meteor_half", "craterLarge", "gate_simple",
    ],
    "Modular": [
        "room-large", "room-large-variation", "room-wide", "room-wide-variation", "room-small",
        "room-small-variation", "room-corner", "corridor", "corridor-corner", "corridor-junction",
        "corridor-intersection", "corridor-end", "corridor-wide", "corridor-wide-junction", "corridor-wide-corner",
        "corridor-wide-end", "corridor-wide-intersection", "corridor-transition", "gate", "gate-door",
        "gate-door-window", "gate-lasers", "stairs", "stairs-wide", "cables", "template-floor-layer-raised",
        "template-detail",
    ],
    "Station": [
        "container-flat", "container-flat-open", "structure", "structure-panel", "pipe", "pipe-bend", "rocks",
        "display-wall", "rail", "balcony-floor", "balcony-rail",
    ],
}

# Swatch grid: CELLS x CELLS swatches of CELL pixels each.
CELLS, CELL = 4, 8


def stage_space_picks():
    spec = importlib.util.spec_from_file_location("stage", os.path.join(HERE, "stage.py"))
    stage = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(stage)
    return stage.PICKS[("Space", "kenney_space-kit")]


def base_color(material):
    bsdf = material.node_tree and material.node_tree.nodes.get("Principled BSDF")
    return tuple(bsdf.inputs["Base Color"].default_value[:3]) if bsdf else (1.0, 1.0, 1.0)


def import_glb(path):
    """Imports a GLB into the current scene and returns its objects joined as one mesh."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before]
    others = [o.name for o in new if o.type != "MESH"]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    for name in others:
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name])
    return joined


def export(kit):
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, f"Spaceport_{kit}.fbx"),
        use_selection=False,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )


def space_palette():
    """Every material in the whole space kit (glTF colours are linear), and its swatch."""
    colors = {}
    for file in sorted(os.listdir(SPACE_DIR)):
        if not file.endswith(".glb"):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(SPACE_DIR, file))
        for material in bpy.data.materials:
            colors.setdefault(material.name.split(".")[0], base_color(material))
    order = sorted(colors)
    assert len(order) <= CELLS * CELLS, "palette full"
    return {key: (i, colors[key]) for i, key in enumerate(order)}


def write_palette(swatches, path):
    size = CELLS * CELL
    image = bpy.data.images.new("Space_colormap", size, size, alpha=False)
    pixels = [0.0] * (size * size * 4)
    for index, color in swatches.values():
        cx, cy = index % CELLS, index // CELLS
        for y in range(cy * CELL, (cy + 1) * CELL):
            for x in range(cx * CELL, (cx + 1) * CELL):
                at = (y * size + x) * 4
                pixels[at:at + 4] = [*color, 1.0]
    image.pixels = pixels  # float pixels are linear; the PNG is written as sRGB
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return image


def bake_space():
    swatches = space_palette()
    names = list(dict.fromkeys(stage_space_picks() + PICKS["Space"]))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    image = write_palette(swatches, os.path.join(OUT, "Space_colormap.png"))
    colormap = bpy.data.materials.new("colormap")
    colormap.use_nodes = True
    texture = colormap.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    bsdf = colormap.node_tree.nodes["Principled BSDF"]
    colormap.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    for name in names:
        obj = import_glb(os.path.join(SPACE_DIR, name + ".glb"))
        obj.name = obj.data.name = "Space_" + name
        mesh = obj.data
        layer = mesh.uv_layers.active or mesh.uv_layers.new()
        for poly in mesh.polygons:
            material = mesh.materials[poly.material_index]
            index = swatches[material.name.split(".")[0]][0]
            point = ((index % CELLS + 0.5) / CELLS, (index // CELLS + 0.5) / CELLS)
            for loop in poly.loop_indices:
                layer.data[loop].uv = point
        mesh.materials.clear()
        mesh.materials.append(colormap)
        for poly in mesh.polygons:
            poly.material_index = 0
    export("Space")
    print(f"Space: {len(names)} models")


def bake_textured(kit):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shared = None
    for name in PICKS[kit]:
        obj = import_glb(os.path.join(FOLDERS[kit], name + ".glb"))
        obj.name = obj.data.name = f"{kit}_{name}"
        # One material for the kit, so the palette is embedded once.
        shared = shared or obj.data.materials[0]
        obj.data.materials.clear()
        obj.data.materials.append(shared)
    for material in list(bpy.data.materials):
        if material != shared and material.users == 0:
            bpy.data.materials.remove(material)
    export(kit)
    print(f"{kit}: {len(PICKS[kit])} models")


def main():
    os.makedirs(OUT, exist_ok=True)
    bake_space()
    bake_textured("Modular")
    bake_textured("Station")


main()
