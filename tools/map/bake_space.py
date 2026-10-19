"""Re-exports the picked Kenney space-kit models with their colours baked into a palette.

The space kit colours its models with flat materials (dark, metal, metalRed, ...), which
Roblox's importer drops: every mesh comes in grey. This bakes those colours into a small
palette, Space_colormap.png, the way the factory and station kits already work. Each
model's meshes are joined into one, every face's UVs are pointed at its material's swatch,
and the model is written as a binary FBX with the palette embedded. Studio's importer
then uploads the palette by itself.

Run it with Blender (reads the kit's GLB files, since its FBX files are ASCII):

    blender -b --factory-startup -P tools/map/bake_space.py

Output: assets/models-textures/Map/import-space/Space_<name>.fbx (+ Space_colormap.png).
"""
import importlib.util
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
KIT = os.path.join(ROOT, "assets", "models-textures", "kenney_space-kit", "Models", "GLTF format")
OUT = os.path.join(ROOT, "assets", "models-textures", "Map", "import-space")

# Swatch grid: CELLS x CELLS swatches of CELL pixels each.
CELLS, CELL = 4, 8


def picks():
    spec = importlib.util.spec_from_file_location("stage", os.path.join(HERE, "stage.py"))
    stage = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(stage)
    return stage.PICKS[("Space", "kenney_space-kit")]


def base_color(material):
    bsdf = material.node_tree and material.node_tree.nodes.get("Principled BSDF")
    return tuple(bsdf.inputs["Base Color"].default_value[:3]) if bsdf else (1.0, 1.0, 1.0)


def load(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, name + ".glb"))


def palette(names):
    """Every material the picks use, by name (glTF colours are linear), plus its swatch."""
    colors = {}
    for name in names:
        load(name)
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


def uv(index):
    return ((index % CELLS + 0.5) / CELLS, (index // CELLS + 0.5) / CELLS)


def bake(name, swatches, path):
    load(name)
    image = write_palette(swatches, path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)

    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new()
    for poly in mesh.polygons:
        material = mesh.materials[poly.material_index]
        point = uv(swatches[material.name.split(".")[0]][0])
        for loop in poly.loop_indices:
            layer.data[loop].uv = point

    colormap = bpy.data.materials.new("colormap")
    colormap.use_nodes = True
    texture = colormap.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Closest"
    bsdf = colormap.node_tree.nodes["Principled BSDF"]
    colormap.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    mesh.materials.clear()
    mesh.materials.append(colormap)
    for poly in mesh.polygons:
        poly.material_index = 0

    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, f"Space_{name}.fbx"),
        use_selection=False,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )


def main():
    os.makedirs(OUT, exist_ok=True)
    names = picks()
    swatches = palette(names)
    path = os.path.join(OUT, "Space_colormap.png")
    for name in names:
        bake(name, swatches, path)
        print("baked", name)
    print(f"baked {len(names)} models in {os.path.relpath(OUT, ROOT)}")


main()
