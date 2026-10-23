"""Builds the astronaut suit armor (Shared/Skins, SkinService) in Blender.

    blender -b --factory-startup -P tools/suits/build_suits.py -- [--preview] [--fbx]

Every piece is modelled in studs, around the default R15 blocky body the game spawns
(part sizes and rest positions measured in Studio, relative to the HumanoidRootPart), in
Roblox axes turned into Blender's: Roblox (x, y, z) -> Blender (x, -z, y), a rotation, so
Roblox's front (-z) is Blender's +Y (see R()). A piece is one object named <Piece>__<BodyPart>__<Role>:
  BodyPart  the R15 part it's welded to (SkinService),
  Role      what colours it in each suit (Shared/Skins: Base, Trim, Dark, Glow, Glass).
Which suit wears which piece is Shared/Skins's business, not this file's.

--fbx writes assets/models-textures/Suits/import/SuitArmor.fbx with every piece plus four
markers (Mark_Origin at the root, Mark_Up 10 studs up, Mark_Right 10 studs right,
Mark_Front 10 studs forward), from which tools/suits/prepare_suits.luau works out the
importer's scale and axes.
--preview renders the four suits on a stand-in body to tools/suits/preview.png.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

# The default R15 blocky body (studs, HumanoidRootPart space): centre and size.
BODY = {
    "Head": ((0, 1.674, 0), (1.159, 1.182, 1.161)),
    "UpperTorso": ((0, 0.249, 0), (1.943, 1.698, 1.004)),
    "LowerTorso": ((0, -0.8, 0), (1.991, 0.401, 1.004)),
    "LeftUpperArm": ((-1.472, 0.428, 0), (1.001, 1.242, 1.002)),
    "RightUpperArm": ((1.472, 0.428, 0), (1.001, 1.242, 1.002)),
    "LeftLowerArm": ((-1.472, -0.202, 0), (1.001, 1.118, 1.002)),
    "RightLowerArm": ((1.472, -0.202, 0), (1.001, 1.118, 1.002)),
    "LeftHand": ((-1.472, -0.866, 0), (0.984, 0.316, 1.028)),
    "RightHand": ((1.472, -0.866, 0), (0.984, 0.316, 1.028)),
    "LeftUpperLeg": ((-0.5, -1.471, 0), (0.993, 1.363, 0.973)),
    "RightUpperLeg": ((0.5, -1.471, 0), (0.993, 1.363, 0.973)),
    "LeftLowerLeg": ((-0.5, -2.334, 0), (0.993, 1.301, 0.973)),
    "RightLowerLeg": ((0.5, -2.334, 0), (0.993, 1.301, 0.973)),
    "LeftFoot": ((-0.5, -3.036, 0), (1.009, 0.312, 1.001)),
    "RightFoot": ((0.5, -3.036, 0), (1.009, 0.312, 1.001)),
}
SIDES = (("Left", -1), ("Right", 1))


def R(x, y, z):
    """A Roblox position (studs) in Blender space: Roblox's front (-z) is Blender's +Y."""
    return Vector((x, -z, y))


# ---------------------------------------------------------------- mesh helpers
def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def finish(obj, bevel=0.0, segments=3, subsurf=0, smooth=True):
    """Bevels / subdivides `obj` and applies it, shaded smooth by angle."""
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width, mod.segments, mod.limit_method = bevel, segments, "ANGLE"
    if subsurf:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = mod.render_levels = subsurf
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
        if hasattr(obj.data, "set_sharp_from_angle"):
            obj.data.set_sharp_from_angle(angle=math.radians(40))
    return obj


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(name, center, size, bevel=0.06, rotation=(0, 0, 0)):
    """A rounded box: `center` and `size` in Roblox studs (x, y, z), rotation in degrees
    about Roblox's x, y, z."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    obj.scale = (size[0], size[2], size[1])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    obj.select_set(False)
    finish(obj, bevel=min(bevel, min(size) * 0.45))
    place(obj, center, rotation)
    return obj


def place(obj, center, rotation=(0, 0, 0)):
    rx, ry, rz = (math.radians(a) for a in rotation)
    # Roblox rotations about x, y (up), z (back) -> Blender x, z, y (y flipped).
    obj.matrix_world = Matrix.Translation(R(*center)) @ (
        Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Z") @ Matrix.Rotation(-rz, 4, "Y"))
    apply(obj)


def apply(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def sphere(name, center, radius, scale=(1, 1, 1), cut=None, segments=32, rings=16):
    """A UV sphere (Roblox scale x, y, z). `cut`: keep only the part above this Roblox-y
    fraction of the radius (-1..1), e.g. 0 for a dome."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    if cut is not None:
        verts = [v for v in bm.verts if v.co.z < cut * radius - 1e-6]
        bmesh.ops.delete(bm, geom=verts, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    obj.scale = (scale[0], scale[2], scale[1])
    obj.location = R(*center)
    apply(obj)
    obj.location = (0, 0, 0)
    obj.data.transform(Matrix.Translation(R(*center)))
    finish(obj)
    return obj


def torus(name, center, major, minor, rotation=(0, 0, 0), arc=None, segments=48, minor_segments=12, scale=(1, 1, 1)):
    """A ring lying flat (in Roblox's x-z plane) before `rotation`. `arc`: keep only that
    many degrees of it, centred on Roblox's front (-z); turned (90, 0, 0) that's the top."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for i in range(segments):
        a = i / segments * math.tau
        for j in range(minor_segments):
            b = j / minor_segments * math.tau
            r = major + minor * math.cos(b)
            bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b)))
    bm.verts.ensure_lookup_table()
    for i in range(segments):
        for j in range(minor_segments):
            a = i * minor_segments + j
            b = ((i + 1) % segments) * minor_segments + j
            c = ((i + 1) % segments) * minor_segments + (j + 1) % minor_segments
            d = i * minor_segments + (j + 1) % minor_segments
            bm.faces.new((bm.verts[a], bm.verts[b], bm.verts[c], bm.verts[d]))
    if arc is not None:
        # The ring is in Blender's XY plane; keep the angles within the arc around +Y.
        keep = math.radians(arc) / 2
        gone = [v for v in bm.verts if abs(math.atan2(v.co.x, v.co.y)) > keep + 1e-6]
        bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    # Blender XY plane is Roblox's x-z plane (flat); scale in Roblox axes.
    obj.scale = (scale[0], scale[2], scale[1])
    apply(obj)
    finish(obj)
    place(obj, center, rotation)
    return obj


def cylinder(name, center, radius, depth, rotation=(0, 0, 0), vertices=24, bevel=0.03):
    """A cylinder along Roblox's y before `rotation`."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices, radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    finish(obj, bevel=bevel)
    place(obj, center, rotation)
    return obj


def star(name, center, outer, inner, depth, rotation=(0, 0, 0), points=5):
    """A five-point star facing Roblox's -z before `rotation`, `depth` thick."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    ring_front, ring_back = [], []
    for i in range(points * 2):
        a = math.pi / 2 + i * math.pi / points
        r = outer if i % 2 == 0 else inner
        x, y = r * math.cos(a), r * math.sin(a)
        ring_front.append(bm.verts.new((x, -depth / 2, y)))
        ring_back.append(bm.verts.new((x, depth / 2, y)))
    bm.faces.new(ring_front[::-1])
    bm.faces.new(ring_back)
    n = len(ring_front)
    for i in range(n):
        bm.faces.new((ring_front[i], ring_front[(i + 1) % n], ring_back[(i + 1) % n], ring_back[i]))
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object(name, mesh)
    finish(obj, bevel=depth * 0.3, segments=2, smooth=False)
    place(obj, center, rotation)
    return obj


def join(name, parts):
    """Joins `parts` into one object called `name`."""
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = obj.data.name = name
    obj.select_set(False)
    return obj


PIECES = []


def piece(name, body, role, parts):
    obj = join(name + "__" + body + "__" + role, parts if isinstance(parts, list) else [parts])
    PIECES.append(obj)
    return obj


# ---------------------------------------------------------------- the armour
def build():
    head_c, head_s = BODY["Head"]
    hx, hy, hz = head_c
    neck = hy - head_s[1] / 2

    # Helmet: a glass bubble round the head (big enough for dynamic heads and hair), a
    # metal neck ring, ear pods each side with a lamp, and a ridge arching over the top.
    piece("HelmetGlass", "Head", "Glass", sphere("g", (hx, hy + 0.08, hz), 1.12, segments=48, rings=24))
    # Ear to ear over the top: an arc stood up across the head.
    ridge = torus("r", (hx, hy + 0.08, hz), 1.16, 0.075, rotation=(90, 0, 0), arc=150)
    neck_ring = torus("n", (hx, neck + 0.06, hz), 0.84, 0.13)
    piece("HelmetFrame", "Head", "Base", [ridge, neck_ring])
    pods = [cylinder("p" + side, (sign * 1.1, hy + 0.05, hz), 0.34, 0.22, rotation=(0, 0, 90)) for side, sign in SIDES]
    piece("HelmetPods", "Head", "Trim", pods)
    lamps = [cylinder("l" + side, (sign * 1.23, hy + 0.05, hz), 0.17, 0.06, rotation=(0, 0, 90), bevel=0.02) for side, sign in SIDES]
    piece("HelmetLamps", "Head", "Glow", lamps)

    # Torso: collar, a chest console with a glowing screen, straps, and a backpack with
    # two tanks and running lights. The plate goes behind the console on the better suits.
    piece("Collar", "UpperTorso", "Trim", torus("c", (0, 1.06, 0), 0.82, 0.16, scale=(1.15, 1, 0.75)))
    piece("ChestConsole", "UpperTorso", "Dark", box("cc", (0, 0.42, -0.67), (0.86, 0.6, 0.36), bevel=0.06))
    piece("ChestScreen", "UpperTorso", "Glow", [box("cs", (-0.08, 0.45, -0.86), (0.5, 0.34, 0.04), bevel=0.015),
                                                 box("cb1", (0.28, 0.55, -0.86), (0.1, 0.1, 0.04), bevel=0.015),
                                                 box("cb2", (0.28, 0.35, -0.86), (0.1, 0.1, 0.04), bevel=0.015)])
    # A name plate under the console, and vents either side on the chest plate.
    piece("NamePlate", "UpperTorso", "Trim", box("np", (0, 0.02, -0.62), (0.9, 0.16, 0.26), bevel=0.04))
    vents = []
    for side, sign in SIDES:
        for i, y in enumerate((0.84, 0.76, 0.68)):
            vents.append(box("v%s%d" % (side, i), (sign * 0.62, y, -0.71), (0.36, 0.045, 0.04), bevel=0.012))
    piece("ChestVents", "UpperTorso", "Dark", vents)
    piece("ChestPlate", "UpperTorso", "Base", [box("cp", (0, 0.6, -0.6), (1.98, 0.98, 0.2), bevel=0.08),
                                                box("cpl", (-0.62, 0.0, -0.58), (0.62, 0.5, 0.16), bevel=0.06),
                                                box("cpr", (0.62, 0.0, -0.58), (0.62, 0.5, 0.16), bevel=0.06)])
    piece("ChestStraps", "UpperTorso", "Trim", [box("s" + side, (sign * 0.6, 0.2, -0.53), (0.2, 1.62, 0.07), bevel=0.02) for side, sign in SIDES])
    piece("Backpack", "UpperTorso", "Base", box("bp", (0, 0.38, 0.86), (1.62, 1.6, 0.66), bevel=0.14))
    tanks = []
    for side, sign in SIDES:
        tanks.append(cylinder("t" + side, (sign * 0.48, 0.38, 1.28), 0.22, 1.36, bevel=0.08))
    tanks.append(box("bar", (0, 1.05, 1.25), (1.3, 0.14, 0.2), bevel=0.04))
    piece("BackpackTanks", "UpperTorso", "Trim", tanks)
    piece("BackpackLights", "UpperTorso", "Glow", [box("bl" + side, (sign * 0.48, -0.25, 1.52), (0.16, 0.16, 0.04), bevel=0.015) for side, sign in SIDES])
    # Thrusters under the backpack: nozzles with a glowing ring inside (flames: SkinService).
    nozzles, rings = [], []
    for side, sign in SIDES:
        mesh = bpy.data.meshes.new("nz")
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=20, radius1=0.2, radius2=0.13, depth=0.3)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.03)
        bm.to_mesh(mesh)
        bm.free()
        nozzle = new_object("nz" + side, mesh)
        finish(nozzle)
        place(nozzle, (sign * 0.45, -0.55, 0.95))
        nozzles.append(nozzle)
        rings.append(cylinder("ng" + side, (sign * 0.45, -0.62, 0.95), 0.15, 0.04, bevel=0.01))
    piece("Thrusters", "UpperTorso", "Dark", nozzles)
    piece("ThrusterGlow", "UpperTorso", "Glow", rings)

    # Waist: belt and buckle.
    piece("Belt", "LowerTorso", "Dark", box("b", (0, -0.78, 0), (2.1, 0.34, 1.14), bevel=0.08))
    piece("Buckle", "LowerTorso", "Trim", box("bk", (0, -0.78, -0.6), (0.52, 0.3, 0.08), bevel=0.03))
    piece("Pouches", "LowerTorso", "Base", [box("pu" + side, (sign * 0.72, -0.84, -0.52), (0.38, 0.34, 0.2), bevel=0.06) for side, sign in SIDES])
    # Antenna on the left ear pod.
    piece("Antenna", "Head", "Trim", cylinder("an", (-1.12, hy + 0.55, hz + 0.12), 0.03, 0.75, vertices=10, bevel=0.0))
    piece("AntennaTip", "Head", "Glow", sphere("at", (-1.12, hy + 0.95, hz + 0.12), 0.07, segments=12, rings=6))
    # Mission patch on the left upper arm (rim, face, star) and a flag on the right.
    lax, rax = BODY["LeftUpperArm"][0][0], BODY["RightUpperArm"][0][0]
    piece("PatchRim", "LeftUpperArm", "Trim", cylinder("pr", (lax - 0.52, 0.42, 0), 0.3, 0.05, rotation=(0, 0, 90), vertices=32, bevel=0.015))
    piece("PatchFace", "LeftUpperArm", "Dark", cylinder("pf", (lax - 0.545, 0.42, 0), 0.24, 0.03, rotation=(0, 0, 90), vertices=32, bevel=0.008))
    piece("PatchStar", "LeftUpperArm", "Glow", star("ps", (lax - 0.565, 0.42, 0), 0.15, 0.065, 0.02, rotation=(0, -90, 0)))
    piece("Flag", "RightUpperArm", "Dark", box("fl", (rax + 0.515, 0.42, 0), (0.04, 0.36, 0.56), bevel=0.01))
    piece("FlagStripes", "RightUpperArm", "Trim", [box("fs%d" % i, (rax + 0.54, 0.42 + dy, 0), (0.03, 0.06, 0.52), bevel=0.0) for i, dy in enumerate((-0.1, 0.0, 0.1))])

    for side, sign in SIDES:
        ax = BODY[side + "UpperArm"][0][0]
        lx = BODY[side + "UpperLeg"][0][0]
        # Shoulder pads: a domed pauldron with a trim rim (better suits).
        pad = sphere("sp", (ax + sign * 0.08, 0.98, 0), 0.72, scale=(1.05, 0.62, 1.1), cut=-0.15)
        piece("ShoulderPad_" + side, side + "UpperArm", "Base", pad)
        rim = torus("sr", (ax + sign * 0.08, 0.98 - 0.72 * 0.62 * 0.15, 0), 0.74, 0.07, scale=(1.05, 1, 1.1))
        piece("ShoulderRim_" + side, side + "UpperArm", "Trim", rim)
        # Arm stripe (the basic suit's orange band) and bracer.
        piece("ArmBand_" + side, side + "UpperArm", "Trim", box("ab", (ax, 0.2, 0), (1.08, 0.2, 1.08), bevel=0.05))
        piece("Bracer_" + side, side + "LowerArm", "Base", box("br", (ax, -0.42, 0), (1.14, 0.62, 1.14), bevel=0.1))
        piece("BracerTrim_" + side, side + "LowerArm", "Trim", box("bt", (ax, -0.08, 0), (1.18, 0.14, 1.18), bevel=0.05))
        piece("BracerLight_" + side, side + "LowerArm", "Glow", box("bg", (ax + sign * 0.58, -0.42, -0.1), (0.04, 0.22, 0.34), bevel=0.015))
        piece("Glove_" + side, side + "Hand", "Dark", box("gl", (ax, -0.87, -0.02), (1.08, 0.44, 1.12), bevel=0.12))
        piece("Knuckles_" + side, side + "Hand", "Base", box("kn", (ax, -0.82, -0.58), (0.74, 0.18, 0.12), bevel=0.04))
        piece("ElbowPad_" + side, side + "LowerArm", "Trim", box("ep", (ax, 0.22, 0.53), (0.62, 0.36, 0.12), bevel=0.05))
        piece("AnkleRing_" + side, side + "Foot", "Trim", torus("ar", (lx, -2.5, -0.04), 0.58, 0.06, scale=(1, 1, 1.08)))
        piece("ThighPocket_" + side, side + "UpperLeg", "Base", box("tk", (lx + sign * 0.55, -1.5, 0), (0.18, 0.44, 0.52), bevel=0.05))
        piece("PocketFlap_" + side, side + "UpperLeg", "Trim", box("tf", (lx + sign * 0.6, -1.3, 0), (0.1, 0.1, 0.54), bevel=0.02))
        # Legs: thigh plate, knee pad with a gem, shin guard, boot with sole and toe cap.
        piece("ThighPlate_" + side, side + "UpperLeg", "Base", box("tp", (lx, -1.36, -0.53), (0.8, 0.78, 0.14), bevel=0.06))
        piece("KneePad_" + side, side + "LowerLeg", "Base", box("kp", (lx, -1.86, -0.55), (0.74, 0.62, 0.22), bevel=0.09))
        piece("KneeGem_" + side, side + "LowerLeg", "Glow", cylinder("kg", (lx, -1.86, -0.68), 0.13, 0.06, rotation=(90, 0, 0), vertices=6, bevel=0.015))
        piece("ShinGuard_" + side, side + "LowerLeg", "Trim", box("sg", (lx, -2.42, -0.52), (0.66, 0.74, 0.1), bevel=0.04))
        piece("Boot_" + side, side + "Foot", "Base", box("bo", (lx, -2.82, -0.06), (1.14, 0.62, 1.24), bevel=0.14))
        piece("BootSole_" + side, side + "Foot", "Dark", box("bs", (lx, -3.13, -0.1), (1.2, 0.18, 1.36), bevel=0.06))
        piece("BootToe_" + side, side + "Foot", "Trim", box("bto", (lx, -2.98, -0.66), (1.0, 0.24, 0.14), bevel=0.05))
        # Glowing strips down the outside of each limb (the better suits).
        out = sign * 0.53
        # (Down the front of the arm: its outside has the patch and the flag.)
        piece("ArmStrip_" + side, side + "UpperArm", "Glow", box("as", (ax, 0.35, -0.525), (0.14, 0.9, 0.05), bevel=0.02))
        piece("LegStrip_" + side, side + "UpperLeg", "Glow", box("ls", (lx + out, -1.5, 0), (0.05, 0.9, 0.14), bevel=0.02))
        piece("ShinStrip_" + side, side + "LowerLeg", "Glow", box("ss", (lx + out, -2.35, 0), (0.05, 0.8, 0.14), bevel=0.02))

    # Commander: a star on the left shoulder pad.
    piece("Emblem", "LeftUpperArm", "Glow", star("em", (lax - 0.66, 0.86, 0), 0.26, 0.11, 0.05, rotation=(0, -90, 0)))
    # Galaxy: a halo ring tilted round the helmet with three orbs on it, built flat at the
    # origin and then tilted and moved into place.
    parts = [torus("ha", (0, 0, 0), 1.65, 0.035, segments=64, minor_segments=8)]
    for i in range(3):
        a = i / 3 * math.tau + 0.4
        parts.append(sphere("o%d" % i, (1.65 * math.cos(a), 0, 1.65 * math.sin(a)), 0.13, segments=16, rings=8))
    halo = join("halo", parts)
    place(halo, (hx, hy + 0.15, hz), (14, 0, 10))
    piece("Halo", "Head", "Glow", halo)


# ---------------------------------------------------------------- preview / export
SUITS = {
    # role colours (r, g, b 0-255), body colour, and how Base draws (metal 0-1).
    "Default": {"Base": (236, 238, 242), "Trim": (240, 120, 30), "Dark": (90, 94, 104), "Glow": (255, 170, 60),
                "Glass": (40, 44, 56), "Body": (236, 238, 242), "metal": 0.0,
                "pieces": ["HelmetGlass", "HelmetFrame", "HelmetPods", "HelmetLamps", "Collar", "ChestConsole", "ChestScreen", "ChestStraps",
                           "Backpack", "BackpackTanks", "BackpackLights", "Belt", "Buckle", "ArmBand", "Glove", "KneePad", "Boot", "BootSole", "BootToe",
                           "Antenna", "AntennaTip", "NamePlate", "PatchRim", "PatchFace", "PatchStar", "Pouches", "ElbowPad", "Knuckles", "AnkleRing", "Flag", "FlagStripes", "ThighPocket", "PocketFlap"]},
    "Gold": {"Base": (240, 178, 36), "Trim": (30, 26, 24), "Dark": (36, 30, 26), "Glow": (255, 160, 40),
             "Glass": (255, 190, 70), "Body": (34, 30, 28), "metal": 1.0,
             "pieces": ["HelmetGlass", "HelmetFrame", "HelmetPods", "HelmetLamps", "Collar", "ChestPlate", "ChestConsole", "ChestScreen",
                        "Backpack", "BackpackTanks", "BackpackLights", "Belt", "Buckle", "ShoulderPad", "ShoulderRim", "Bracer", "BracerTrim",
                        "BracerLight", "Glove", "ThighPlate", "KneePad", "ShinGuard", "Boot", "BootSole", "BootToe",
                        "Antenna", "AntennaTip", "NamePlate", "PatchRim", "PatchFace", "PatchStar", "Pouches", "ElbowPad", "Knuckles", "AnkleRing", "ChestVents", "Thrusters", "ThrusterGlow"]},
    "Commander": {"Base": (238, 240, 246), "Trim": (226, 176, 40), "Dark": (26, 34, 80), "Glow": (60, 140, 255),
                  "Glass": (40, 70, 200), "Body": (26, 34, 80), "metal": 0.3,
                  "pieces": ["HelmetGlass", "HelmetFrame", "HelmetPods", "HelmetLamps", "Collar", "ChestPlate", "ChestConsole", "ChestScreen",
                             "Backpack", "BackpackTanks", "BackpackLights", "Belt", "Buckle", "ShoulderPad", "ShoulderRim", "Bracer", "BracerTrim",
                             "BracerLight", "Glove", "ThighPlate", "KneePad", "KneeGem", "ShinGuard", "Boot", "BootSole", "BootToe", "Emblem",
                             "ArmStrip", "LegStrip", "Antenna", "AntennaTip", "NamePlate", "PatchRim", "PatchFace", "PatchStar", "Pouches", "ElbowPad", "Knuckles", "AnkleRing", "ChestVents", "Thrusters", "ThrusterGlow"]},
    "Galaxy": {"Base": (70, 34, 150), "Trim": (190, 120, 255), "Dark": (18, 10, 40), "Glow": (80, 220, 255),
               "Glass": (150, 80, 255), "Body": (30, 14, 66), "metal": 0.6,
               "pieces": ["HelmetGlass", "HelmetFrame", "HelmetPods", "HelmetLamps", "Collar", "ChestPlate", "ChestConsole", "ChestScreen",
                          "Backpack", "BackpackTanks", "BackpackLights", "Belt", "Buckle", "ShoulderPad", "ShoulderRim", "Bracer", "BracerTrim",
                          "BracerLight", "Glove", "ThighPlate", "KneePad", "KneeGem", "ShinGuard", "Boot", "BootSole", "BootToe", "Halo",
                          "ArmStrip", "LegStrip", "ShinStrip", "Antenna", "AntennaTip", "NamePlate", "PatchRim", "PatchFace", "PatchStar", "Pouches", "ElbowPad", "Knuckles", "AnkleRing", "ChestVents", "Thrusters", "ThrusterGlow"]},
}


def material(name, rgb, metal=0.0, rough=0.35, emit=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    color = tuple((c / 255) ** 2.2 for c in rgb) + (1,)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
    return mat


def galaxy_material(name, path, scale=0.5, emit=0.6):
    """The star field box-projected in studs (SkinService tiles it on every face)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    coords = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale, scale, scale)
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(path)
    image.projection, image.projection_blend = "BOX", 0.2
    links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], image.inputs["Vector"])
    links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(image.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = emit
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.2
    return mat


GALAXY = os.path.join(ROOT, "assets", "models-textures", "Suits", "Galaxy.png")


def preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 900
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.03, 0.05, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    spacing = 5.0
    order = ["Default", "Gold", "Commander", "Galaxy"]
    by_name = {}
    for obj in PIECES:
        base = obj.name.split("__")[0].split("_")[0]
        by_name.setdefault(base, []).append(obj)
    skin = material("Skin", (234, 184, 146), rough=0.6)
    for index, suit_name in enumerate(order):
        suit = SUITS[suit_name]
        # The camera looks from Blender's +Y, so +X is on the left: Default ends up leftmost.
        offset = Vector(((1.5 - index) * spacing, 0, 0))
        mats = {role: material(suit_name + role, suit[role], metal=(suit["metal"] if role == "Base" else 0.2),
                               rough=0.25 if role == "Base" else 0.45, emit=4.0 if role == "Glow" else 0.0,
                               alpha=0.35 if role == "Glass" else 1.0)
                for role in ("Base", "Trim", "Dark", "Glow", "Glass")}
        body_mat = material(suit_name + "Body", suit["Body"], rough=0.7)
        if suit_name == "Galaxy" and os.path.exists(GALAXY):
            body_mat = mats["Base"] = galaxy_material("GalaxyStars", GALAXY)
        # Stand-in body.
        for part, (center, size) in BODY.items():
            b = box(suit_name + part, center, size, bevel=0.04)
            b.location += offset
            b.data.materials.append(skin if part == "Head" else body_mat)
        for name in suit["pieces"]:
            for obj in by_name.get(name, []):
                copy = obj.copy()
                copy.data = obj.data.copy()
                bpy.context.scene.collection.objects.link(copy)
                copy.location += offset
                role = obj.name.split("__")[2]
                copy.data.materials.clear()
                copy.data.materials.append(mats[role])
    for obj in PIECES:
        obj.hide_render = True
    # Lights and camera: three-quarter front, slightly above.
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy, key.data.size = 3000, 8
    key.location = (-6, 10, 9)
    key.rotation_euler = (math.radians(-55), 0, math.radians(30))
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy, fill.data.size = 1200, 10
    fill.location = (10, 6, 3)
    fill.rotation_euler = (math.radians(-75), 0, math.radians(-55))
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "AREA"))
    rim.data.energy, rim.data.size = 2000, 6
    rim.location = (0, -10, 7)
    rim.rotation_euler = (math.radians(50), 0, 0)
    for light in (key, fill, rim):
        bpy.context.scene.collection.objects.link(light)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.lens = 50
    bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((0, 0, -0.5))
    for suffix, at in (("", (0, 30, 2.5)), ("_back", (-14, -27, 5))):
        cam.location = at
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = path.replace(".png", suffix + ".png")
        bpy.ops.render.render(write_still=True)


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    marks = {"Mark_Origin": (0, 0, 0), "Mark_Up": (0, 10, 0), "Mark_Right": (10, 0, 0), "Mark_Front": (0, 0, -10)}
    for name, at in marks.items():
        PIECES.append(box(name, at, (0.2, 0.2, 0.2), bevel=0))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PIECES:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             global_scale=0.01, axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE")


clear()
build()
print("pieces:", len(PIECES), "tris:", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in PIECES))
for obj in PIECES:
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > 10000:
        print("WARNING big piece", obj.name, tris)
if "--fbx" in ARGS:
    export(os.path.join(ROOT, "assets", "models-textures", "Suits", "import", "SuitArmor.fbx"))
if "--preview" in ARGS:
    preview(os.path.join(ROOT, "tools", "suits", "preview.png"))
