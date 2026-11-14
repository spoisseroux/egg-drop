"""Build Blip, the green toy alien, from the Bear (VISUAL-BRIEF.md section 4, recipe steps 1-9).

Run (background Blender only). It reads the Bear's attachment blend and writes a NEW file; the Bear's
blend is never saved:
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/build_blip.py
Output: assets/art-source/pets/pet-blip.blend (root `PetBlip`, every object/anchor/material renamed).

Blip is the Bear's exact body, hands and feet (untouched) with a wider, slightly flat-topped head, two
short thick antennae with fat ball tips where the ears were, a shallow pale face patch instead of a
muzzle, no nose, the Bear's eyes (scaled 1.10) and mouth re-seated on the new surface, and a curl tail.
Originality guard: two upright oval eyes, no point on the head, green and mint, short thick antennae.

Not done here (LATER): FBX export, Studio import, rig data. Fit check and review renders:
scripts/build_bear_wearables.py and scripts/render_wearable_review.py both run on pet-blip.blend.
"""
import bpy, bmesh, math
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

SRC = Path(bpy.data.filepath).resolve()
assert SRC.name == "pet-bear-attachments.blend", "run on the Bear's attachment blend"
OUT = SRC.with_name("pet-blip.blend")
PRIMARY, SECONDARY = "#7BD88F", "#D6F5E3"
NECK = Vector((0.0, -0.02, 0.70))                    # the head scales about the neck joint
HEAD_SCALE = Vector((1.07, 0.98, 0.95))

# ---------------------------------------------------------------- 1. copy and rename
col = bpy.data.collections.get("PetBear_Wearables")   # rebuilt per pet by build_bear_wearables.py
if col:
    for o in list(col.objects):
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if me.users == 0:
            bpy.data.meshes.remove(me)
for o in bpy.data.objects:
    if o.name.startswith("PetBear"):
        o.name = "PetBlip" + o.name[7:]
        if o.type == "MESH" and o.data.name.startswith("PetBear"):
            o.data.name = "PetBlip" + o.data.name[7:]
for m in bpy.data.materials:
    if m.name.startswith("petBear__"):
        m.name = "petBlip__" + m.name[9:]
for c in bpy.data.collections:
    c.name = c.name.replace("PetBear", "PetBlip")
D = bpy.data.objects
root = D["PetBlip"]
root["animal"] = "Blip"
BODY_MAT, SECOND_MAT = bpy.data.materials["petBlip__body"], bpy.data.materials["petBlip__secondary"]


def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


ROOT_INV = world(root).inverted()


def local(o):
    return ROOT_INV @ world(o)


def bvh_of(*names):
    vs, ts = [], []
    for n in names:
        o = D["PetBlip__" + n]
        m = local(o)
        base = len(vs)
        vs += [m @ v.co for v in o.data.vertices]
        o.data.calc_loop_triangles()
        ts += [tuple(base + i for i in t.vertices) for t in o.data.loop_triangles]
    return BVHTree.FromPolygons(vs, ts)


def tris(name):
    me = D["PetBlip__" + name].data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


SHARED = {n: tris(n) for n in ("Body", "HandL", "HandR", "FootL", "FootR")}
assert SHARED == {"Body": 148, "HandL": 72, "HandR": 72, "FootL": 84, "FootR": 84}, SHARED
OLD_HEAD = bvh_of("Head")
OLD_FACE = bvh_of("Head", "Muzzle")


def front(tree, x, z):
    hit = tree.ray_cast(Vector((x, -3.0, z)), Vector((0, 1, 0)))
    return hit[0].y if hit[0] else None


# ---------------------------------------------------------------- mesh helpers (as build_bear_wearables.py)
def ring_faces(bm, a, b, closed=True):
    n = len(a)
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def fan(bm, pole, ring):
    n = len(ring)
    for i in range(n):
        bm.faces.new((pole, ring[i], ring[(i + 1) % n]))


def ball(bm, centre, radius, segs=8, rings=4):
    prev = bm.verts.new(centre + Vector((0, 0, -radius)))
    for k in range(1, rings + 1):
        a = math.pi * k / (rings + 1)
        cur = [bm.verts.new(centre + Vector((radius * math.sin(a) * math.cos(2 * math.pi * i / segs),
                                             radius * math.sin(a) * math.sin(2 * math.pi * i / segs),
                                             -radius * math.cos(a)))) for i in range(segs)]
        if isinstance(prev, list):
            ring_faces(bm, prev, cur)
        else:
            fan(bm, prev, cur)
        prev = cur
    fan(bm, bm.verts.new(centre + Vector((0, 0, radius))), prev)


def tube(bm, pts, radii, sides=6):
    """Open tube with the frame carried along, rounded caps."""
    rings, carried, last_t = [], None, None
    for i, p in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        t = (b - a).normalized()
        if carried is None:
            side = t.cross(Vector((0, 1, 0)))
            side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
        else:
            side = (last_t.rotation_difference(t) @ carried).normalized()
        carried, last_t = side, t
        u = side.cross(t).normalized()
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * k / sides) + u * math.sin(2 * math.pi * k / sides)) * radii[i])
                      for k in range(sides)])
    for i in range(len(pts) - 1):
        ring_faces(bm, rings[i], rings[i + 1])
    for ring, p, q, r in ((rings[0], pts[0], pts[1], radii[0]), (rings[-1], pts[-1], pts[-2], radii[-1])):
        fan(bm, bm.verts.new(p + (p - q).normalized() * r * 0.5), ring)


def set_mesh(name, bm, material, uv=(0.5, 0.5)):
    """Replace an existing piece's mesh (bm is pet-local): keeps the object, its anchor and its role."""
    ob = D["PetBlip__" + name]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    centre = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    if sum(f.normal.dot(f.calc_center_median() - centre) * f.calc_area() for f in bm.faces) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = True
    layer = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for l in f.loops:
            l[layer].uv = uv
    bmesh.ops.transform(bm, matrix=local(ob).inverted(), verts=bm.verts[:])
    me = bpy.data.meshes.new("PetBlip__" + name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    old = ob.data
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def move_anchor(name, p):
    a = D["PetBlip__Anchor_" + name]
    assert a.parent == root
    m = a.matrix_basis.copy()
    m.translation = Vector(p)
    a.matrix_basis = m


# ---------------------------------------------------------------- 3. head: wider, a little flatter on top
head = D["PetBlip__Head"]
m, mi = local(head), local(head).inverted()
for v in head.data.vertices:
    p = m @ v.co - NECK
    v.co = mi @ (NECK + Vector((p.x * HEAD_SCALE.x, p.y * HEAD_SCALE.y, p.z * HEAD_SCALE.z)))
head.data.update()
for poly in head.data.polygons:
    poly.use_smooth = True
HEAD = bvh_of("Head")


def head_top(x, y):
    return HEAD.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))[0]


# ---------------------------------------------------------------- 5. antennae where the ears were
STALKS = {}
TIP_X, TIP_R = 0.330, 0.098
for side, sx in (("L", -1.0), ("R", 1.0)):
    base = head_top(sx * 0.27, 0.05)
    move_anchor("Ear" + side, base)                      # the ear-flick channel becomes the antenna wiggle
    start = base - Vector((sx * 0.01, 0, 0.03))          # sunk 0.03
    top = Vector((sx * 0.318, 0.05, 1.425))
    pts = [start.lerp(top, t) + Vector((sx * 0.012 * math.sin(math.pi * t), 0, 0)) for t in (0.0, 0.34, 0.68, 1.0)]
    bm = bmesh.new()
    tube(bm, pts, [0.066, 0.061, 0.056, 0.052], sides=6)     # short and thick: a toy's antenna, not a wire
    stalk = set_mesh("Ear" + side, bm, BODY_MAT, uv=(0.5, 0.9))          # v = 0.9: fully primary
    bm = bmesh.new()
    ball(bm, Vector((sx * TIP_X, 0.05, 1.475)), TIP_R, segs=8, rings=4)
    set_mesh("EarInner" + side, bm, SECOND_MAT)
    STALKS[side] = (base, [local(stalk) @ v.co for v in stalk.data.vertices])

# ---------------------------------------------------------------- 6. face patch, eyes, mouth
# A small round snout spot under the eyes. The brief's 0.20 x 0.125 patch ran into the eyes and read as a
# mask; and flush with the head (rim 0.004) the low-poly facets cut its edge.
PATCH = dict(cz=0.805, rx=0.135, rz=0.088, rise=0.024, rim=0.010, sink=0.012)
bm = bmesh.new()
outline = [(PATCH["rx"] * math.cos(2 * math.pi * i / 12), PATCH["rz"] * math.sin(2 * math.pi * i / 12)) for i in range(12)]


def patch_at(dx, dz, h):
    return bm.verts.new(Vector((dx, front(HEAD, dx, PATCH["cz"] + dz) - h, PATCH["cz"] + dz)))


top = patch_at(0, 0, PATCH["rise"])
ring = [patch_at(dx, dz, PATCH["rim"]) for dx, dz in outline]
inner = [patch_at(dx * 0.6, dz * 0.6, PATCH["rim"] + (PATCH["rise"] - PATCH["rim"]) * 0.75) for dx, dz in outline]
fan(bm, top, inner)
ring_faces(bm, inner, ring)
ring_faces(bm, ring, [patch_at(dx * 0.92, dz * 0.92, -PATCH["sink"]) for dx, dz in outline])
set_mesh("Muzzle", bm, SECOND_MAT)
FACE = bvh_of("Head", "Muzzle")

# Eyes: the Bear's mesh and texture, scaled 1.10 about its own middle, at the Bear's x spacing (every eye
# item still lines up) and z 1.01. Each vertex keeps its height above the surface it was modelled on.
EYE_Z, EYE_SCALE = 1.01, 1.10


def reseat(ob, old_tree, new_tree, scale=1.0, to_z=None):
    m, mi = local(ob), local(ob).inverted()
    pts = [m @ v.co for v in ob.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    mid = (lo + hi) / 2
    target = Vector((mid.x, mid.y, mid.z if to_z is None else to_z))
    fallback = None
    for v, p in zip(ob.data.vertices, pts):
        was = front(old_tree, p.x, p.z)
        q = target + (p - mid) * scale
        now = front(new_tree, q.x, q.z)
        if was is not None and now is not None:
            q.y = now + (p.y - was)
            fallback = q.y - (target.y + (p.y - mid.y) * scale)
        elif fallback is not None:
            q.y += fallback
        v.co = mi @ q
    ob.data.update()


for o in list(D):
    if o.type != "MESH" or not o.name.startswith("PetBlip__") or o.parent != D["PetBlip__Anchor_Head"]:
        continue
    short = o.name.split("__", 1)[1]
    if short.startswith("Eye"):
        reseat(o, OLD_HEAD, HEAD, EYE_SCALE, EYE_Z + (0.0 if "Alt" not in short else 0.0))
    elif short.startswith("Mouth"):
        reseat(o, OLD_FACE, FACE)
# No nose: the piece goes, the anchor stays (the slot is marked unavailable in rig data later).
nose = D["PetBlip__Nose"]
bpy.data.objects.remove(nose, do_unlink=True)

# ---------------------------------------------------------------- 7. curl tail
t = local(D["PetBlip__Anchor_Tail"]).translation
curl = [Vector(p) for p in ((0.0, -0.040, 0.000), (0.0, 0.055, 0.000), (0.008, 0.130, 0.040), (0.018, 0.150, 0.115),
                            (0.028, 0.105, 0.170), (0.034, 0.050, 0.150), (0.036, 0.045, 0.100))]
bm = bmesh.new()
tube(bm, [t + p for p in curl], [0.036, 0.036, 0.034, 0.031, 0.028, 0.026, 0.024], sides=6)
ball(bm, t + curl[-1], 0.028, segs=6, rings=2)
set_mesh("Tail", bm, SECOND_MAT)

# ---------------------------------------------------------------- 8. anchors onto the new surface
move_anchor("HatCrown", head_top(0.0, -0.03))
for name, z in (("Forehead", None), ("EyeL", EYE_Z), ("EyeR", EYE_Z), ("FaceBridge", None), ("CheekL", None), ("CheekR", None)):
    p = local(D["PetBlip__Anchor_" + name]).translation
    z = p.z if z is None else z
    move_anchor(name, (p.x, front(HEAD, p.x, z), z))
move_anchor("Nose", (0.0, front(FACE, 0.0, 0.90), 0.90))
move_anchor("Mouth", (0.0, front(FACE, 0.0, 0.80), 0.80))
for side, sx in (("L", -1.0), ("R", 1.0)):
    move_anchor("Horn" + side, head_top(sx * 0.14, -0.12))             # in front of the stalks, clear of the tips
    for name, z in (("Helix", 1.20), ("Lobe", 1.05)):                    # no outer ear: the side of the head
        hit = HEAD.ray_cast(Vector((sx * 3.0, 0.0, z)), Vector((-sx, 0, 0)))[0]
        a = D["PetBlip__Anchor_" + name + side]
        a.matrix_basis = Matrix.Translation(hit) @ Matrix.Rotation(math.radians(90 * sx), 4, "Y")   # local +Z leaves the surface
for name in ("CharmAnchor", "CharmFloat"):                              # tips reach 1.58 (Bear ears 1.48): +0.10 headroom
    p = local(D["PetBlip__Anchor_" + name]).translation
    move_anchor(name, (p.x, p.y, p.z + 0.10))
anchors = [o for o in D if o.type == "EMPTY" and "__Anchor_" in o.name]
assert len(anchors) == 46, len(anchors)
for a in anchors:
    assert all(abs(s - 1.0) < 1e-6 for s in a.matrix_basis.to_scale()), a.name

# ---------------------------------------------------------------- 9. palette
root["primaryColor"], root["secondaryColor"] = PRIMARY, SECONDARY


def lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


for mat in (BODY_MAT, SECOND_MAT):
    for node in mat.node_tree.nodes:
        if node.type == "GROUP" and node.node_tree:
            for inp in node.inputs:
                key = inp.name.lower()
                if inp.type == "RGBA" and ("primary" in key or "secondary" in key):
                    inp.default_value = lin(PRIMARY if "primary" in key else SECONDARY)
            print("PALETTE GROUP", mat.name, node.node_tree.name, [(i.name, i.type) for i in node.inputs])
    mat.diffuse_color = lin(PRIMARY if mat is BODY_MAT else SECONDARY)

# ---------------------------------------------------------------- report and save
bpy.context.view_layer.update()
assert {n: tris(n) for n in SHARED} == SHARED
shown = [o for o in D if o.type == "MESH" and o.name.startswith("PetBlip__") and not o.hide_render and "Charm" not in o.name]
total = 0
for o in sorted(shown, key=lambda o: o.name):
    n = tris(o.name.split("__", 1)[1])
    total += n
    pts = [local(o) @ v.co for v in o.data.vertices]
    print(f"BLIP {o.name:24s} tris {n:4d}  x {min(p.x for p in pts):+.3f}..{max(p.x for p in pts):+.3f}"
          f"  y {min(p.y for p in pts):+.3f}..{max(p.y for p in pts):+.3f}  z {min(p.z for p in pts):.3f}..{max(p.z for p in pts):.3f}")
print("BLIP TOTAL TRIS", total)
crown_z = local(D["PetBlip__Anchor_HatCrown"]).translation.z
inner = min(abs(p.x) for side in STALKS for p in STALKS[side][1])
tip_inner = TIP_X - TIP_R
print(f"BLIP HAT GAP half-width between stalks {inner:.3f} (hat limit 0.19), between tips {tip_inner:.3f}; crown z {crown_z:.3f}")
for a in sorted(anchors, key=lambda a: a.name):
    if a.get("channel") == "Head" or a.name.endswith(("EarL", "EarR", "CharmFloat")):
        print("BLIP ANCHOR", a.name.split("Anchor_")[1], [round(v, 3) for v in local(a).translation])
bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
print("SAVED", OUT)
