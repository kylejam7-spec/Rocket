"""Readies the Saturn UFO (assets/models-textures/Monster/SaturnUFO.fbx) for Roblox.

The user's FBX is a flying saucer with two alien pilots under a glass canopy: 192 small
meshes (~105,000 triangles) rigidly skinned to an 18-bone rig (Root > Hull > each
pilot's Torso > Head and both arms > forearms > hands). Studio would make a MeshPart of
every one of them, so this decimates the small parts (rivets, vents, buttons and fingers
came in at 240-288 triangles each) by their size and joins everything into one mesh per
material (UFOTitanium, UFOGraphite, ...), keeping each vertex on its bone, so the pilots
can still be posed. The leftover default Cube is dropped.

    F:/blender.exe -b --factory-startup -P tools/monster/rig_ufo.py

writes assets/models-textures/Monster/import/SaturnUFO_Rig.fbx. Import it in Studio
(File > Import 3D, default settings), then run tools/monster/prepare_ufo.luau in the
command bar and save as it says.
"""
import os

import bmesh
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MONSTER = os.path.join(ROOT, "assets", "models-textures", "Monster")
SOURCE = os.path.join(MONSTER, "SaturnUFO.fbx")
OUT = os.path.join(MONSTER, "import", "SaturnUFO_Rig.fbx")
# Material -> mesh name. Studio's importer reads 1 m as 100 studs: the 8.24 m saucer comes
# in 824 studs across, under the 2048-stud part limit (prepare_ufo.luau scales it down).
SHORT = {
    "Titanium": "Titanium", "Graphite": "Graphite", "Ion": "Ion", "Amber": "Amber",
    "Canopy glass": "Glass", "Jade": "Jade", "Alien highlights": "Highlight", "Eyes": "Eyes",
    "Coral indicators": "Coral",
}


FLIP = {"Upper hull", "Lower shell"}


def budget(obj):
    """Triangles to keep for one part: about 250 per metre of its longest side."""
    return 24 + 250 * max(obj.dimensions)


def triangles(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=SOURCE)
    scene = bpy.context.scene
    rig = next(o for o in scene.objects if o.type == "ARMATURE")
    for obj in list(scene.objects):
        if obj.type not in ("MESH", "ARMATURE") or (obj.type == "MESH" and not obj.vertex_groups):
            print("dropped", obj.name)
            bpy.data.objects.remove(obj)
    parts = [o for o in scene.objects if o.type == "MESH"]
    before = sum(triangles(o.data) for o in parts)

    # The saucer's two big shells face inward in the source (Blender draws both sides, so
    # it doesn't show; Roblox culls back faces and the body turned see-through): flip them.
    for obj in parts:
        if obj.name.split(".")[0] in FLIP:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
            bm.to_mesh(obj.data)
            bm.free()
            if obj.data.has_custom_normals:
                obj.data.normals_split_custom_set([(0, 0, 0)] * len(obj.data.loops))
            print("flipped", obj.name)

    # Decimate each part to its budget (weights are kept: each part is on one bone).
    for obj in parts:
        count = triangles(obj.data)
        ratio = budget(obj) / count
        if ratio < 0.9:
            bpy.context.view_layer.objects.active = obj
            modifier = obj.modifiers.new("Decimate", "DECIMATE")
            modifier.ratio = max(ratio, 0.05)
            modifier.use_collapse_triangulate = True
            # Above the Armature modifier, so it applies to the rest shape.
            bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
            bpy.ops.object.modifier_apply(modifier="Decimate")

    # One mesh per material.
    groups = {}
    for obj in parts:
        names = {slot.material.name for slot in obj.material_slots if slot.material}
        assert len(names) == 1, f"{obj.name} has materials {names}"
        groups.setdefault(names.pop(), []).append(obj)
    for material, objs in groups.items():
        short = SHORT.get(material.split(".")[0], material.replace(" ", ""))
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = joined.data.name = "UFO" + short
        print(f"{joined.name:14s} {len(objs):3d} parts, {triangles(joined.data):6d} triangles")
    after = sum(triangles(o.data) for o in scene.objects if o.type == "MESH")
    print(f"{before} -> {after} triangles")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in scene.objects:
        obj.select_set(obj.type in ("MESH", "ARMATURE"))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=OUT,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        use_armature_deform_only=True,
    )
    print("Wrote", OUT, "rig", rig.name, len(rig.data.bones), "bones")


main()
