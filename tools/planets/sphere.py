"""Writes the UV sphere the planets wear their textures on: smooth-shaded, 96 x 48
segments, UVs laid out equirectangular (u round the equator, v pole to pole), +Y up for
Roblox. Runs in Blender, headless:

    F:/blender.exe -b --python tools/planets/sphere.py     # -> assets/planets/planet_sphere.fbx

Import the FBX in Studio (3D Importer) and put its MeshId in Planets.SphereMesh. Free
Creator Store spheres were tried first: their seams shade dark and their poles pinch.
"""
import os

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "planets", "planet_sphere.fbx")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1, calc_uvs=True)
sphere = bpy.context.active_object
sphere.name = "PlanetSphere"
bpy.ops.object.shade_smooth()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, axis_forward="-Z", axis_up="Y",
                         apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", use_mesh_modifiers=True)
print("wrote", OUT)
