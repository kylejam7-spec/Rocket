"""Rigs the Europa Oarfish (assets/models-textures/Monster/Europa_Oarfish.glb) for Roblox.

The GLB is one static mesh, 12.8 m long along X (head at -X), with six flat-colour
materials. This splits it by material into six meshes (OarfishIce, OarfishMembrane,
OarfishCrest, OarfishTeal, OarfishPhoto, OarfishEye; Roblox gives each MeshPart one
colour, and Photo becomes Neon), keeps it at 12.8 m, and skins all six to an armature of 17
unparented bones (B00 at the head .. B16 at the tail tip) on the body's centre line,
each vertex weighted between the two bones either side of it along X. The client
(Controllers/OarfishController) bends the body along its flight path by moving the bones.

    blender -b --factory-startup -P tools/monster/rig_oarfish.py

writes assets/models-textures/Monster/import/Europa_Oarfish_Rig.fbx. Import it in Studio
(File > Import 3D, defaults; it comes in with a RootPart holding the bones), then run
tools/monster/prepare_oarfish.luau in the command bar and save as it says.
Also runs inside an open Blender (it works in a scene of its own and removes it).
"""
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MONSTER = os.path.join(ROOT, "assets", "models-textures", "Monster")
SOURCE = os.path.join(MONSTER, "Europa_Oarfish.glb")
OUT = os.path.join(MONSTER, "import", "Europa_Oarfish_Rig.fbx")
BONES = 16  # spans; BONES + 1 bones
# Studio's importer reads 1 m as 100 studs and shrinks any mesh past the 2048-stud part
# limit without shrinking its bones, which breaks the skinning: at 12.8 m the fish comes
# in 1,280 studs long, under the limit (the client scales it to size).
SCALE = 1.0
SHORT = {0: "Ice", 1: "Membrane", 2: "Crest", 3: "Teal", 4: "Photo", 5: "Eye"}


def centreline(mesh, x0, x1):
    """Points on the body's centre line at each bone: the mean of the body material's
    vertices in a thin slice there (wider where the slice is sparse)."""
    body = {v.co.copy().freeze() for f in mesh.polygons if f.material_index == 0 for v in (mesh.vertices[i] for i in f.vertices)}
    body = list(body)
    points = []
    for i in range(BONES + 1):
        x = x0 + (x1 - x0) * i / BONES
        probe, width = min(max(x, x0 + 0.15), x1 - 0.15), 0.06
        near = [v for v in body if abs(v.x - probe) < width]
        while len(near) < 6:
            width *= 1.6
            near = [v for v in body if abs(v.x - probe) < width]
        centre = sum(near, Vector()) / len(near)
        if i in (0, BONES):
            centre.x = x
        points.append(centre)
    return points


def main():
    window = getattr(bpy.context, "window", None)
    previous = window.scene if window else None
    scene = bpy.data.scenes.new("OarfishRig_build")
    if window:
        window.scene = scene
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    src = next(o for o in scene.objects if o.type == "MESH")
    xs = [v.co.x for v in src.data.vertices]
    x0, x1 = min(xs), max(xs)
    points = centreline(src.data, x0, x1)

    armature = bpy.data.armatures.new("OarfishArmature")
    rig = bpy.data.objects.new("Oarfish", armature)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for i, point in enumerate(points):
        along = (points[min(i + 1, BONES)] - points[max(i - 1, 0)]).normalized()
        bone = armature.edit_bones.new(f"B{i:02d}")
        bone.head, bone.tail, bone.roll = point * SCALE, (point + along * 0.3) * SCALE, 0
    bpy.ops.object.mode_set(mode="OBJECT")

    def weights(x):
        t = min(max((x - x0) / (x1 - x0), 0), 1) * BONES
        i = min(int(t), BONES - 1)
        return ((i, 1 - (t - i)), (i + 1, t - i))

    for index, short in SHORT.items():
        bm = bmesh.new()
        bm.from_mesh(src.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != index], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        along = [v.co.x for v in bm.verts]
        for v in bm.verts:
            v.co *= SCALE
        mesh = bpy.data.meshes.new("Oarfish" + short)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(src.data.materials[index])
        part = bpy.data.objects.new("Oarfish" + short, mesh)
        scene.collection.objects.link(part)
        groups = [part.vertex_groups.new(name=f"B{i:02d}") for i in range(BONES + 1)]
        for vertex, x in enumerate(along):
            for bone, weight in weights(x):
                if weight > 0:
                    groups[bone].add([vertex], weight, "REPLACE")
        part.modifiers.new("Armature", "ARMATURE").object = rig
        part.parent = rig
        print(part.name, len(mesh.polygons), "triangles")

    bpy.data.objects.remove(src)
    for obj in scene.objects:
        obj.select_set(obj.type in ("MESH", "ARMATURE"))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=OUT,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        use_armature_deform_only=True,
    )
    print("Wrote", OUT)

    if window:
        window.scene = previous
        for obj in list(scene.objects):
            data = obj.data
            bpy.data.objects.remove(obj)
            if data is not None and data.users == 0:
                (bpy.data.meshes if isinstance(data, bpy.types.Mesh) else bpy.data.armatures).remove(data)
        bpy.data.scenes.remove(scene)


main()
