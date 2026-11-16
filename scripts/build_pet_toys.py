"""Personal pet toys, v2 (QA v760: "this does not look like a bone"). Procedural meshes, no
AI art. Builds the six toys as real meshes, one mesh per colour part, and writes:

  assets/art-source/toys/toys-v2.blend           the source scene (one Empty per toy)
  assets/art-source/toys/pet-toys.fbx            upload this (Open Cloud, assetType Model)
  assets/art-source/toys/pet-toys-manifest.json  each part's centre, size and colour

Everything is authored in the game's own frame and units: one unit is one pet body height,
+Y up, +Z facing (PetToyGeometry). A part's manifest `centre` and `size` are what the Luau
builder passes to Prop:mesh, so the mesh lands exactly where it was modelled.

Usage (from the repo root):
  blender -b --factory-startup --python scripts/build_pet_toys.py [-- preview DIR]
`preview DIR` also renders one PNG per toy into DIR (a quick look before uploading).
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "art-source", "toys")
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # game (x, y, z) -> (x, -z, y)
I4 = Matrix.Identity(4)


def rz(a):
    """CFrame.Angles(0, 0, a): a turn about the facing axis."""
    return Matrix.Rotation(a, 4, "Z")


def tr(x, y, z):
    return Matrix.Translation((x, y, z))


def sc(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


# ── mesh helpers (game frame; `m` places the shape) ─────────────────────────────────────
def lathe(bm, profile, seg=24, m=I4, closed=False):
    """Revolve (radius, y) points about +Y. A zero radius is a pole. `closed` joins the last
    ring back to the first (a band with thickness)."""
    rings = []
    for r, y in profile:
        if r < 1e-9:
            rings.append([bm.verts.new(m @ Vector((0, y, 0)))])
        else:
            rings.append([bm.verts.new(m @ Vector((r * math.cos(2 * math.pi * i / seg), y, r * math.sin(2 * math.pi * i / seg))))
                          for i in range(seg)])
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for a, b in pairs:
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))


def ball(bm, m, seg=20, rings=12):
    """A unit-radius sphere placed (and squashed) by `m`."""
    lathe(bm, [(math.sin(math.pi * k / rings), -math.cos(math.pi * k / rings)) for k in range(rings + 1)], seg, m)


def slab(bm, hx, hy, corner, depth, fillet, m=I4, arc=6):
    """A rounded rectangle (half extents hx, hy; corner radius) of `depth` along +Z, its rim
    filleted. hy == corner gives a pill."""
    layers = [(fillet, -depth / 2)]
    for k in range(1, 4):
        a = k / 3 * math.pi / 2
        layers.append((fillet * (1 - math.sin(a)), -depth / 2 + fillet * (1 - math.cos(a))))
    for k in range(4):
        a = k / 3 * math.pi / 2
        layers.append((fillet * (1 - math.cos(a)), depth / 2 - fillet * (1 - math.sin(a))))
    rings = []
    for inset, z in layers:
        ring = []
        r = max(corner - inset, 1e-5)
        for cx, cy, start in ((1, 1, 0), (-1, 1, 1), (-1, -1, 2), (1, -1, 3)):
            for k in range(arc + 1):
                a = (start + k / arc) * math.pi / 2
                ring.append(bm.verts.new(m @ Vector((cx * (hx - corner) + r * math.cos(a), cy * (hy - corner) + r * math.sin(a), z))))
        rings.append(ring)
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def ribbon(bm, points, normals, half_wide, half_thick, sides=8):
    """A closed tube with an oval section along `points`; `normals` is the section's thin axis."""
    count = len(points)
    rings = []
    for i in range(count):
        tangent = (points[(i + 1) % count] - points[i - 1]).normalized()
        n = normals[i].normalized()
        side = tangent.cross(n).normalized()
        rings.append([bm.verts.new(points[i] + side * (half_wide * math.cos(2 * math.pi * k / sides))
                                   + n * (half_thick * math.sin(2 * math.pi * k / sides))) for k in range(sides)])
    for i in range(count):
        a, b = rings[i], rings[(i + 1) % count]
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((a[k], a[j], b[j], b[k]))


# ── scene plumbing ──────────────────────────────────────────────────────────────────────
def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


def material(colour, glow=False):
    name = "toy_" + colour.lstrip("#") + ("_glow" if glow else "")
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = lin(colour)
    bsdf.inputs["Roughness"].default_value = 0.5
    if glow:
        for key in ("Emission Color", "Emission"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = lin(colour)
                break
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 1.6
    return mat


TOYS = {}      # toy id -> Empty
PARTS = []     # manifest rows, in build order
EXPORT = []


def toy_root(toy):
    if toy not in TOYS:
        # Book cells are named after the Empty (render_book_icons.py): Bone, Wobble_Top, ...
        root = bpy.data.objects.new("_".join(w.capitalize() for w in toy.split("_")), None)
        root.location = (len(TOYS) * 0.6, 0, 0)
        bpy.context.scene.collection.objects.link(root)
        TOYS[toy] = root
    return TOYS[toy]


def finish(bm, toy, part, colour, glow=False, export=True, sharp=45):
    """Bake a game-frame bmesh into an object under the toy's Empty and record its manifest row."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    tris = len(bm.faces)
    bm.transform(TO_BLENDER)
    for f in bm.faces:
        f.smooth = True
    mesh = bpy.data.meshes.new(toy + "__" + part)
    bm.to_mesh(mesh)
    bm.free()
    if hasattr(mesh, "set_sharp_from_angle"):
        mesh.set_sharp_from_angle(angle=math.radians(sharp))
    mesh.materials.append(material(colour, glow))
    ob = bpy.data.objects.new(toy + "__" + part, mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = toy_root(toy)
    if export:
        EXPORT.append(ob)
        PARTS.append({"toy": toy, "part": part, "mesh": ob.name, "colour": colour, "tris": tris,
                      "centre": [round(v, 5) for v in (lo + hi) / 2], "size": [round(v, 5) for v in hi - lo]})
    return ob


def remeshed(bm, voxel, smooth, tris):
    """Fuse overlapping shapes into one soft skin: voxel remesh, relax, then thin to `tris`."""
    mesh = bpy.data.meshes.new("fuse")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.transform(sc(10, 10, 10))   # the voxel remesher wants metres, not centimetres
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new("fuse", mesh)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel * 10
    mod.use_smooth_shade = True
    mod = ob.modifiers.new("relax", "SMOOTH")
    mod.factor = 1.0
    mod.iterations = smooth
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    fused = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = bmesh.new()
    out.from_mesh(fused)
    bmesh.ops.triangulate(out, faces=out.faces)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(mesh)
    bpy.data.meshes.remove(fused)
    # Decimate on a temporary object (the collapse decimator is a modifier).
    tmp_mesh = bpy.data.meshes.new("thin")
    out.to_mesh(tmp_mesh)
    count = len(out.faces)
    out.free()
    tmp = bpy.data.objects.new("thin", tmp_mesh)
    bpy.context.scene.collection.objects.link(tmp)
    mod = tmp.modifiers.new("thin", "DECIMATE")
    mod.ratio = min(1.0, tris / max(1, count))
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    thin = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    result = bmesh.new()
    result.from_mesh(thin)
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(tmp_mesh)
    bpy.data.meshes.remove(thin)
    return result


# ── the toys ────────────────────────────────────────────────────────────────────────────
def bone():
    """The classic cartoon dog bone: a straight shaft and two round knobs on each end, one
    soft cream skin. 0.31 long, like the old one, so the hold and chew offsets still fit."""
    bm = bmesh.new()
    along_x = Matrix.Rotation(-math.pi / 2, 4, "Z")      # the lathe's +Y laid along +X
    lathe(bm, [(0, -.125), (.031, -.118), (.029, -.06), (.027, 0), (.029, .06), (.031, .118), (0, .125)], 20, along_x)
    for side in (-1, 1):
        for lobe in (-1, 1):
            ball(bm, tr(side * .113, lobe * .034, 0) @ sc(.043, .043, .039))
    bm = remeshed(bm, .0045, 10, 1100)
    # Remeshing leaves the skin 10x; bring it back to body heights.
    bm.transform(sc(.1, .1, .1))
    finish(bm, "bone", "BoneBody", "#FFF1D6")


def tennis_ball():
    """Optic yellow felt and the real one-piece seam: the closed curve that wraps the ball,
    seen from the front as two white arcs bowing toward each other."""
    radius = .12
    bm = bmesh.new()
    ball(bm, sc(radius, radius, radius), 28, 16)
    finish(bm, "ball", "FeltBall", "#D0E83A")
    # (a cos t + b cos 3t, a sin t - b sin 3t, 2 sqrt(ab) sin 2t) lies on the unit sphere.
    a, b = .76, .24
    c = 2 * math.sqrt(a * b)
    turn = rz(.2) @ Matrix.Rotation(-math.pi / 4, 4, "Z")
    points, normals = [], []
    for i in range(72):
        t = 2 * math.pi * i / 72
        p = turn @ Vector((a * math.cos(t) + b * math.cos(3 * t), a * math.sin(t) - b * math.sin(3 * t), c * math.sin(2 * t)))
        p.normalize()
        points.append(p * (radius * 1.004))
        normals.append(p)
    bm = bmesh.new()
    ribbon(bm, points, normals, .0105, .0042, 6)
    finish(bm, "ball", "Seam", "#FCFBEF")


def sparkler():
    """A party sparkler: an indigo grip with a pommel, a brass ferrule and wire, and a spiky
    citrine spark burst round the glowing tip (the tip itself stays a Neon sphere in game)."""
    lean = rz(-.12)
    bm = bmesh.new()
    lathe(bm, [(0, -.158), (.017, -.154), (.024, -.143), (.024, -.133), (.019, -.124), (.0205, -.11), (.0235, -.05),
               (.0225, -.012), (.016, -.002), (0, 0)], 16, lean)
    finish(bm, "sparkler", "IndigoGrip", "#333C78")
    bm = bmesh.new()
    lathe(bm, [(0, -.012), (.027, -.012), (.029, -.004), (.027, .004), (.012, .01), (.0075, .02), (.0065, .17), (0, .172)], 12, lean)
    finish(bm, "sparkler", "BrassWire", "#C69A45")
    tip = lean @ Vector((0, .19, 0))
    bm = bmesh.new()
    spikes = []
    for i in range(8):
        a = math.pi / 2 + i * math.pi / 4
        spikes.append((Vector((math.cos(a), math.sin(a), 0)), .092 if i % 2 == 0 else .058))
    for z in (-1, 1):
        spikes.append((Vector((0, 0, z)), .06))
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            spikes.append((Vector((math.cos(a) * .7, math.sin(a) * .7, z * .72)), .05))
    for direction, length in spikes:
        m = tr(*tip) @ Vector((0, 1, 0)).rotation_difference(direction.normalized()).to_matrix().to_4x4()
        lathe(bm, [(0, .004), (.019, .01), (.0155, length * .45), (.0085, length * .8), (.0035, length * .96), (0, length)], 8, m)
    finish(bm, "sparkler", "SparkBurst", "#F6D759")
    bm = bmesh.new()
    ball(bm, tr(*tip) @ sc(.024, .024, .024), 16, 10)
    finish(bm, "sparkler", "GlowTip", "#FFF1B8", glow=True, export=False)
    return [round(v, 5) for v in tip]


def wobble_top():
    """A spinning top: a fat teal body that tapers to a coral point, a cream belly band, a
    brass stem and a citrine knob. Tilted 0.18 rad, mid-wobble."""
    tilt = rz(.18)
    bm = bmesh.new()
    lathe(bm, [(0, -.094), (.02, -.09), (.046, -.071), (.075, -.042), (.093, -.014), (.1, .008), (.097, .026), (.086, .044),
               (.064, .059), (.036, .069), (0, .073)], 24, tilt)
    finish(bm, "wobble_top", "TealBody", "#3FB7B0")
    bm = bmesh.new()
    lathe(bm, [(.084, -.02), (.0965, -.014), (.104, .008), (.101, .026), (.09, .036), (.08, .03), (.08, -.014)], 24, tilt, closed=True)
    finish(bm, "wobble_top", "CreamEquator", "#FFF0C9")
    bm = bmesh.new()
    lathe(bm, [(0, -.13), (.009, -.127), (.016, -.116), (.019, -.1), (.017, -.086), (0, -.08)], 14, tilt)
    finish(bm, "wobble_top", "CoralFoot", "#EF786B")
    bm = bmesh.new()
    lathe(bm, [(0, .06), (.024, .068), (.015, .078), (.0125, .09), (.0125, .15), (0, .152)], 12, tilt)
    finish(bm, "wobble_top", "BrassStem", "#C69A45")
    bm = bmesh.new()
    ball(bm, tilt @ tr(0, .168, 0) @ sc(.031, .027, .031), 16, 10)
    finish(bm, "wobble_top", "CitrineKnob", "#F6D759")


def squeaky_carrot():
    """A plump carrot on the diagonal: one tapered orange body with three shallow rings, a
    tuft of three leaves at the fat end and a cream squeaker button on its side."""
    axis = rz(-.62)

    def girth(y):
        return .0155 + (.048 - .0155) * (y + .11) / .19

    profile = [(0, -.132), (.008, -.129), (.013, -.121), (girth(-.11), -.11)]
    for groove in (-.062, -.012, .038):
        profile += [(girth(groove - .008), groove - .008), (girth(groove) - .0045, groove), (girth(groove + .008), groove + .008)]
    profile += [(.048, .08), (.046, .097), (.037, .109), (.02, .116), (0, .118)]
    bm = bmesh.new()
    lathe(bm, profile, 20, axis)
    finish(bm, "squeaky_carrot", "CarrotBody", "#FF8A3C", sharp=60)
    bm = bmesh.new()
    for turn, length, wide in ((0, .115, .026), (.55, .095, .023), (-.55, .095, .023)):
        leaf = [(0, 0)] + [(wide * math.sin(math.pi * (k / 8) ** .8) ** .9, length * k / 8) for k in range(1, 8)] + [(0, length)]
        lathe(bm, leaf, 10, axis @ tr(turn * -.02, .108, 0) @ rz(-turn) @ sc(1, 1, .6))
    finish(bm, "squeaky_carrot", "CarrotLeaves", "#58B368")
    bm = bmesh.new()
    ball(bm, axis @ tr(0, .045, .042) @ sc(.0125, .0125, .007), 14, 8)
    finish(bm, "squeaky_carrot", "SqueakerDot", "#FFF0C9")


def pocket_deck():
    """The Pocket Deck handheld: a cream pill shell, an ink bezel, a mint screen, a plus
    d-pad and two round buttons. Same layout as the primitive one, with real edges."""
    bm = bmesh.new()
    slab(bm, .1275, .0525, .0525, .036, .012, arc=8)
    finish(bm, "pocket_deck", "DeckShell", "#F3E9D2")
    bm = bmesh.new()
    slab(bm, .055, .038, .011, .008, .003, tr(0, .004, .0175), arc=4)
    finish(bm, "pocket_deck", "DeckBezel", "#1B2330")
    bm = bmesh.new()
    slab(bm, .046, .029, .006, .006, .0015, tr(0, .004, .0215), arc=3)
    finish(bm, "pocket_deck", "DeckScreen", "#76F6B0", glow=True)
    bm = bmesh.new()
    slab(bm, .0185, .0065, .003, .01, .0025, tr(-.088, -.004, .02), arc=2)
    slab(bm, .0065, .0185, .003, .01, .0025, tr(-.088, -.004, .02), arc=2)
    finish(bm, "pocket_deck", "DeckPad", "#333C78")
    for name, x, y, colour in (("DeckButtonA", .098, .008, "#EF786B"), ("DeckButtonB", .078, -.016, "#F6D759")):
        bm = bmesh.new()
        slab(bm, .0115, .0115, .0115, .011, .004, tr(x, y, .02), arc=4)
        finish(bm, "pocket_deck", name, colour)


# ── preview renders ─────────────────────────────────────────────────────────────────────
def preview(folder):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            pass
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = scene.world or bpy.data.worlds.new("ToyWorld")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = lin("#3FA9A3")
    bg.inputs[1].default_value = 1.0
    cam_data = bpy.data.cameras.new("ToyCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("ToyCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, energy, rot in (("Key", 3.2, (52, 0, -32)), ("Fill", 1.0, (70, 0, 40)), ("Rim", 1.8, (-60, 0, 160))):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        light = bpy.data.objects.new(name, data)
        light.rotation_euler = [math.radians(v) for v in rot]
        scene.collection.objects.link(light)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    os.makedirs(folder, exist_ok=True)
    for toy, root in TOYS.items():
        for o in meshes:
            o.hide_render = o.parent is not root
        pts = [o.matrix_world @ Vector(c) for o in root.children for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        yaw, pitch = math.radians(-20), math.radians(14)
        d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        cam.location = (lo + hi) / 2 + d * 4
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam_data.ortho_scale = max(hi - lo) * 1.35
        scene.render.filepath = os.path.join(folder, "blender-" + toy + ".png")
        bpy.ops.render.render(write_still=True)


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bone()
    tennis_ball()
    tip = sparkler()
    wobble_top()
    squeaky_carrot()
    pocket_deck()
    bpy.context.view_layer.update()
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in EXPORT:
        o.select_set(True)
    bpy.context.view_layer.objects.active = EXPORT[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "pet-toys.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="AUTO", mesh_smooth_type="OFF")
    manifest = {"schema": 1, "units": "pet body heights; +Y up, +Z facing", "sparklerTip": tip, "parts": PARTS,
                "tris": {toy: sum(p["tris"] for p in PARTS if p["toy"] == toy) for toy in TOYS}}
    with open(os.path.join(OUT, "pet-toys-manifest.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=1)
        handle.write("\n")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "toys-v2.blend"))
    print("TOY TRIS", manifest["tris"])
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args[:1] == ["preview"]:
        preview(args[1])


if __name__ == "__main__":
    main()
