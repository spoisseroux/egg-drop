"""Collection book thumbnails, 3D part (Blender, background). Renders the Bear wearing one
wardrobe item at a time, the Bear in each body finish, and the three personal toys, as
transparent 256 px PNGs. build_book_atlas.py turns them into the 128 px atlas.

Each wardrobe render also writes a `-mask` PNG: the same view with everything except the
item held out, so the atlas can draw "not owned" as the item's own silhouette over a faint
Bear.

Usage (from the repo root):
  blender -b --factory-startup assets/art-source/pets/pet-bear-attachments.blend --python scripts/deck_art/render_book_icons.py -- bear
  blender -b --factory-startup assets/art-source/toys/toys.blend --python scripts/deck_art/render_book_icons.py -- toys
  (after `bear`, optional ids limit the run: item ids from the manifest and/or `finishes`)
Outputs: assets/ui/book/raw/<slot>.png (and <slot>-mask.png for wardrobe items)
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "assets", "ui", "book", "raw")
MANIFEST = os.path.join(ROOT, "assets", "garden-babies", "attachments", "attachments-manifest.json")
SIZE = 256

# Book thumbnails show the Bear undyed but warm, with one friendly secondary (the in-game
# Bear is player-dyed; the book shows the item, not anyone's colours).
BODY = "#EEDFCD"
# Finishes are shown on a coloured Bear so the highlight (or its absence) reads at 48 px.
FINISH_BODY = "#B7A2F2"
SECONDARY = "#F28DAA"


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


def flat(name, hexcol, rough=0.55, metal=0.0, coat=0.0, spec=0.5):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = lin(hexcol)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    for key in ("Coat Weight", "Clearcoat"):
        if key in b.inputs:
            b.inputs[key].default_value = coat
            break
    for key in ("Specular IOR Level", "Specular"):
        if key in b.inputs:
            b.inputs[key].default_value = spec
            break
    nt.links.new(b.outputs[0], out.inputs[0])
    return m


def setup_scene():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            pass
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.view_settings.look = "None"
    for o in list(bpy.data.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)
    world = scene.world or bpy.data.worlds.new("BookWorld")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.62, 0.66, 0.74, 1)
    bg.inputs[1].default_value = 0.9
    cam_data = bpy.data.cameras.new("BookCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("BookCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def light(name, kind, energy, rot, color=(1, 1, 1), size=None):
        d = bpy.data.lights.new(name, kind)
        d.energy = energy
        d.color = color
        if size is not None and hasattr(d, "angle"):
            d.angle = size
        o = bpy.data.objects.new(name, d)
        o.rotation_euler = [math.radians(v) for v in rot]
        scene.collection.objects.link(o)

    light("Key", "SUN", 3.4, (52, 0, -32), (1.0, 0.97, 0.92), math.radians(8))
    light("Fill", "SUN", 1.0, (70, 0, 40), (0.85, 0.92, 1.0), math.radians(30))
    light("Rim", "SUN", 2.2, (-60, 0, 160), (1.0, 1.0, 1.0), math.radians(10))
    return scene, cam


def frame(cam, target, scale, yaw=0.0, pitch=12.0, roll=0.0):
    """Ortho camera on `target`, looking from the front (-Y) turned `yaw` degrees around Z.
    The key, fill and rim lights turn with it, so a back view (the tail) is lit like a front one."""
    for name, base in (("Key", -32), ("Fill", 40), ("Rim", 160)):
        light = bpy.data.objects.get(name)
        if light:
            light.rotation_euler[2] = math.radians(base + yaw)
    t = Vector(target)
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = t + d * 6
    q = (-d).to_track_quat("-Z", "Y")
    if roll:
        from mathutils import Quaternion
        q = Quaternion(-d, math.radians(roll)) @ q
    cam.rotation_euler = q.to_euler()
    cam.data.ortho_scale = scale
    cam.data.clip_start, cam.data.clip_end = 0.01, 50


def render(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def shoot(scene, others, name):
    """Colour render, then the item-only mask (everything else held out)."""
    render(scene, os.path.join(RAW, name + ".png"))
    for o in others:
        o.is_holdout = True
    render(scene, os.path.join(RAW, name + "-mask.png"))
    for o in others:
        o.is_holdout = False


# Per-item overrides of the slot view (the flower crown is wider than the other hats).
ITEM_VIEWS = {"flowercrown": ((1.04, -0.05, 1.10), 1.36, 0, 22), "starstud": ((0.64, -0.02, 1.36), 0.46, -38, 10),
              "acorn": ((1.04, -0.2, 0.555), 0.34, 0, 10), "bowtail": ((1.04, 0.2, 0.50), 0.92, 168, 16)}
# Per-slot camera: target (Blender world), ortho scale, yaw (degrees; negative turns the
# camera toward the Bear's left ear), pitch.
HEAD = (1.04, -0.05, 1.08)
VIEWS = {
    "Hat": ((1.04, -0.05, 1.10), 1.34, 0, 16),
    "Shirt": ((1.04, -0.1, 0.74), 1.86, 0, 10),
    "Neck": ((1.04, -0.2, 0.68), 0.66, 0, 16),
    "EarPiercing": ((0.62, -0.02, 1.26), 0.46, -38, 6),
    "Eyes": ((1.04, -0.3, 1.04), 1.24, 0, 6),
    "Mouth": ((1.04, -0.42, 0.93), 0.80, -10, 2),
    "Tail": ((1.04, 0.2, 0.52), 1.0, 160, 14),
    # Slice B slots (overnight 2026-11-14): cheeks and eyewear use the face view, wrists the left arm.
    "Cheek": ((1.04, -0.3, 0.98), 1.10, 0, 4),
    "Eyewear": ((1.04, -0.3, 1.04), 1.24, 0, 6),
    "Wrist": ((0.66, -0.14, 0.47), 0.56, -32, 10),
}
# Small pieces read better on their own, filling the cell: (yaw, pitch, side filter).
ALONE = {"beads": (0, 22, None), "bellcollar": (0, 16, None), "ring": (-72, 6, "L"), "starstud": (-15, 6, "L"),
         "heart": (160, 10, None)}
# Icon exaggeration: pieces too small to read at 48 px are drawn bigger (thumbnail only).
ITEM_SCALE = {"blep": 2.2}
# Toys built from the game's sphere primitives (PetToyGeometry builders, slice D toy pool 2). They are
# mirrored here in memory for their book cell, not saved in toys.blend: (name, size, steps, colour) with
# steps a chain of ("r", radians about the toy's facing axis) and ("t", x, y, z) in the game's axes
# (Y up, +Z facing), exactly as the Luau CFrame chain reads.
PRIMITIVE_TOYS = {
    "Wobble_Top": [
        ("TealBody", (.20, .15, .20), [("r", .18)], "#3FB7B0"),
        ("CreamEquator", (.205, .04, .205), [("r", .18), ("t", 0, .01, 0)], "#FFF0C9"),
        ("CoralFoot", (.05, .07, .05), [("r", .18), ("t", 0, -.09, 0)], "#EF786B"),
        ("BrassStem", (.04, .10, .04), [("r", .18), ("t", 0, .11, 0)], "#C69A45"),
        ("CitrineKnob", (.06, .06, .06), [("r", .18), ("t", 0, .17, 0)], "#F6D759"),
    ],
    "Squeaky_Carrot": [
        ("CarrotTop", (.085, .11, .085), [("r", -.62), ("t", 0, .075, 0)], "#FF8A3C"),
        ("CarrotMiddle", (.07, .10, .07), [("r", -.62)], "#FF8A3C"),
        ("CarrotTip", (.05, .09, .05), [("r", -.62), ("t", 0, -.075, 0)], "#FF8A3C"),
        ("LeafProng-1", (.03, .08, .03), [("r", -.62), ("t", -.018, .128, 0), ("r", .5), ("t", 0, .03, 0)], "#58B368"),
        ("LeafProng0", (.03, .08, .03), [("r", -.62), ("t", 0, .128, 0), ("t", 0, .03, 0)], "#58B368"),
        ("LeafProng1", (.03, .08, .03), [("r", -.62), ("t", .018, .128, 0), ("r", -.5), ("t", 0, .03, 0)], "#58B368"),
        ("SqueakerDot", (.03, .03, .03), [("r", -.62), ("t", 0, .02, .034)], "#FFF0C9"),
    ],
}
REPLACES = {"Eyes": ["PetBear__EyeL", "PetBear__EyeR"], "Mouth": ["PetBear__Mouth"], "Tail": ["PetBear__Tail"]}


def bear():
    scene, cam = setup_scene()
    defaults = [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render and o.name.startswith("PetBear__")]
    defaults = [o for o in defaults if "Charm" not in o.name]
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = True
    body = flat("book_body", BODY, rough=0.62, spec=0.35)
    second = flat("book_secondary", SECONDARY, rough=0.55)
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for slot in o.material_slots:
            if slot.material and slot.material.name == "petBear__body":
                slot.material = body
            elif slot.material and slot.material.name in ("petBear__secondary", "petBear__wing"):
                slot.material = second
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    only = set(sys.argv[sys.argv.index("--") + 2:]) if "--" in sys.argv else set()
    for item in manifest["items"]:
        if only and item["id"] not in only:
            continue
        slot = item["slot"]
        pieces = [bpy.data.objects["Pet" + p["mesh"]] for p in item["pieces"]]
        if item["id"] in ALONE:
            yaw, pitch, side = ALONE[item["id"]]
            if side:
                pieces = [o for o in pieces if ("Helix" + side) in o.name or (side == "L" and "L_" in o.name)]
            for o in pieces:
                o.hide_render = False
            pts = [o.matrix_world @ Vector(c) for o in pieces for c in o.bound_box]
            mn = Vector([min(p[i] for p in pts) for i in range(3)])
            mx = Vector([max(p[i] for p in pts) for i in range(3)])
            frame(cam, (mn + mx) / 2, max(mx - mn) * 1.3, yaw, pitch)
            render(scene, os.path.join(RAW, "wear-" + item["id"] + ".png"))
            render(scene, os.path.join(RAW, "wear-" + item["id"] + "-mask.png"))
            for o in pieces:
                o.hide_render = True
            continue
        hidden = set(REPLACES.get(slot, []))
        shown = [o for o in defaults if o.name not in hidden]
        for o in shown + pieces:
            o.hide_render = False
        grow = ITEM_SCALE.get(item["id"], 1.0)
        for o in pieces:
            o.scale = [v * grow for v in o.scale]
        target, scale, yaw, pitch = ITEM_VIEWS.get(item["id"], VIEWS[slot])
        frame(cam, target, scale, yaw, pitch)
        shoot(scene, shown, "wear-" + item["id"])
        for o in pieces:
            o.scale = [v / grow for v in o.scale]
        for o in shown + pieces:
            o.hide_render = True
    if only and "finishes" not in only:
        return
    # Body finishes: the Bear front-on, body in the finish (standard is not a book item).
    finishes = {
        "gloss": dict(rough=0.08, coat=1.0, spec=0.9),
        "matte": dict(rough=1.0, spec=0.0),
        "metal": dict(rough=0.22, metal=1.0),
    }
    for o in defaults:
        o.hide_render = False
    frame(cam, (1.04, -0.08, 1.0), 1.30, -16, 8)
    # A big soft box up and to the left: a glossy body shows it as a window highlight.
    box = bpy.data.lights.new("SoftBox", "AREA")
    box.energy, box.size = 70, 0.9
    # A coloured body needs less light than the cream Bear, or the lilac washes out to white.
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    for name, energy in (("Key", 1.9), ("Fill", 0.45), ("Rim", 1.4)):
        bpy.data.objects[name].data.energy = energy
    box_obj = bpy.data.objects.new("SoftBox", box)
    box_obj.location = (0.2, -2.2, 2.2)
    box_obj.rotation_euler = (-(Vector((1.04, -0.08, 1.0)) - box_obj.location)).to_track_quat("Z", "Y").to_euler()
    scene.collection.objects.link(box_obj)
    for fid, kw in finishes.items():
        mat = flat("book_finish_" + fid, FINISH_BODY, **kw)
        swapped = []
        for o in defaults:
            for s in o.material_slots:
                if s.material == body:
                    s.material = mat
                    swapped.append(s)
        render(scene, os.path.join(RAW, "finish-" + fid + ".png"))
        for s in swapped:
            s.material = body


def build_primitive_toys():
    """Create the sphere-primitive toys under an Empty each, like the modelled ones in toys.blend."""
    from mathutils import Matrix
    to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # game (x, y, z) -> (x, -z, y)
    sphere = bpy.data.meshes.new("ToyUnitSphere")
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=0.5)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(sphere)
    bm.free()
    for index, (gid, parts) in enumerate(PRIMITIVE_TOYS.items()):
        root = bpy.data.objects.new(gid, None)
        root.location = (4.0 + index, 0.0, 0.2)
        bpy.context.scene.collection.objects.link(root)
        for name, size, steps, colour in parts:
            m = Matrix.Identity(4)
            for step in steps:
                m = m @ (Matrix.Rotation(step[1], 4, "Z") if step[0] == "r" else Matrix.Translation(step[1:]))
            ob = bpy.data.objects.new(gid + "_" + name, sphere.copy())
            ob.data.materials.append(flat("toyprim_" + colour.lstrip("#"), colour, rough=0.5))
            bpy.context.scene.collection.objects.link(ob)
            ob.parent = root
            ob.matrix_parent_inverse = Matrix.Identity(4)
            ob.matrix_basis = to_blender @ m @ Matrix.Diagonal((*size, 1.0))
    bpy.context.view_layer.update()


def toys():
    scene, cam = setup_scene()
    build_primitive_toys()
    groups = {}
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = True
            if o.parent and o.parent.type == "EMPTY":
                groups.setdefault(o.parent.name, []).append(o)
    for gid, objs in groups.items():
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        mn = Vector([min(p[i] for p in pts) for i in range(3)])
        mx = Vector([max(p[i] for p in pts) for i in range(3)])
        centre = (mn + mx) / 2
        extent = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        for o in objs:
            o.hide_render = False
        yaw = {"Bone": -28, "Ball": -24, "Sparkler": -30, "Wobble_Top": -12, "Squeaky_Carrot": -10}.get(gid, -25)
        roll = {"Sparkler": -38, "Bone": 20}.get(gid, 0)        # long toys lie on the diagonal
        fit = {"Sparkler": 1.0, "Bone": 1.05, "Wobble_Top": 1.12, "Squeaky_Carrot": 1.08}.get(gid, 1.28)
        frame(cam, centre, extent * fit, yaw, 18, roll)
        render(scene, os.path.join(RAW, "toy-" + gid.lower() + ".png"))
        for o in objs:
            o.hide_render = True


if __name__ == "__main__":
    os.makedirs(RAW, exist_ok=True)
    mode = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "bear"
    {"bear": bear, "toys": toys}[mode]()
