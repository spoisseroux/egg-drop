"""Blip v2 CONCEPTS: make Blip read as his own species, not a green Bear (TODO.md, Spencer 2026-11-14).

Concept only. Reads Blip v1 (scripts/build_blip.py output) and never saves over it:
  blender -b assets/art-source/pets/pet-blip.blend --python scripts/build_blip_v2.py -- <A|B|C> [--render DIR] [--save]
  blender -b assets/art-source/pets/pet-blip.blend --python scripts/build_blip_v2.py -- REF --render DIR          (v1 as is)
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/build_blip_v2.py -- REF --render DIR  (Bear)
--save writes assets/art-source/pets/pet-blip-v2.blend (root `PetBlip`, same 46 anchor names, same pieces).
--render writes DIR/raw/<tag>-{front,q,side,phone}.png; scripts/blip_v2_sheets.py lays the sheets out.

Variants (all keep the family face kit: the Bear's eye mesh at v1 size, the mouth, the pale snout spot):
  A "Bean"    thick capsule body with no neck, lower flatter head, nub arms, chunky feet, big wide antennae
  B "Saucer"  wide low flat head, wide-set eyes, small pear body, long V antennae out at the head's edges
  C "Sprout"  egg: body wider than the head, head tapers to the top, drooping feelers, flipper arms, big feet
Every piece keeps its topology (vertices are moved, never added), except the antennae and tail, which are
rebuilt as in v1. Not done here: wearable refits, alt-eye checks, FBX export, Studio import, rig data.
"""
import bpy, bmesh, math, sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
VARIANT = args[0] if args else "A"
RENDER = args[args.index("--render") + 1] if "--render" in args else None
SAVE = "--save" in args
SRC = Path(bpy.data.filepath).resolve()
IS_BEAR = SRC.name == "pet-bear-attachments.blend"
assert IS_BEAR or SRC.name == "pet-blip.blend", "run on pet-blip.blend (or the Bear blend with REF)"
assert VARIANT in ("A", "B", "C", "REF") and not (IS_BEAR and VARIANT != "REF")
OUT = SRC.with_name("pet-blip-v2.blend")
ROOT_NAME = "PetBear" if IS_BEAR else "PetBlip"
PRE = ROOT_NAME + "__"
PRIMARY, SECONDARY = "#7BD88F", "#D6F5E3"
NECK = Vector((0.0, -0.02, 0.70))
BODY_C0, BODY_R0 = Vector((0.0, -0.085, 0.455)), Vector((0.30, 0.325, 0.295))   # v1 body as an ellipsoid

SPEC = {
    "A": dict(
        head=dict(drop=0.03, s=(1.03, 1.0, 0.86), broad=0.10),
        body=dict(c=(0.0, -0.07, 0.47), r=(0.42, 0.30, 0.31), k=2.8, pear=0.0),
        arm=dict(length=0.60, thick=1.0, shoulder=(0.37, -0.07, 0.60), swing=16),
        foot=dict(s=(1.2, 1.08, 1.15), out=0.05),
        eye_z=0.975, eye_x=1.0, patch_z=0.80, tail=1.15,
        ant=dict(base=(0.34, 0.05), path=[(0.42, 0.05, 1.40)], radii=[0.076, 0.070, 0.064, 0.060],
                 tip=(0.435, 0.05, 1.44), tip_r=0.12)),
    "B": dict(
        head=dict(drop=0.0, s=(1.16, 1.02, 0.76), broad=0.14),
        body=dict(c=(0.0, -0.085, 0.45), r=(0.30, 0.32, 0.29), k=2.0, pear=0.22),
        arm=dict(length=0.70, thick=0.95, shoulder=(0.21, -0.06, 0.63), swing=10),
        foot=dict(s=(1.0, 1.0, 1.0), out=0.0),
        eye_z=0.95, eye_x=1.2, patch_z=0.775, tail=1.0,
        ant=dict(base=(0.42, 0.05), path=[(0.52, 0.05, 1.40)], radii=[0.060, 0.054, 0.050, 0.047],
                 tip=(0.54, 0.05, 1.435), tip_r=0.125)),
    "C": dict(
        head=dict(drop=0.05, s=(0.93, 0.95, 1.02), broad=-0.28),
        body=dict(c=(0.0, -0.07, 0.47), r=(0.49, 0.34, 0.32), k=2.5, pear=0.10),
        arm=dict(length=0.55, thick=1.0, shoulder=(0.42, -0.07, 0.57), swing=22),
        foot=dict(s=(1.25, 1.1, 1.1), out=0.07),
        eye_z=0.97, eye_x=1.0, patch_z=0.795, tail=1.1,
        ant=dict(base=(0.20, 0.04), path=[(0.235, 0.04, 1.39), (0.295, 0.04, 1.47), (0.375, 0.04, 1.505), (0.455, 0.04, 1.48), (0.505, 0.04, 1.42)],
                 radii=[0.062, 0.057, 0.054, 0.052, 0.050, 0.048], tip=(0.53, 0.04, 1.35), tip_r=0.11)),
}

D = bpy.data.objects
root = D[ROOT_NAME]


def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


ROOT_INV = world(root).inverted()


def local(o):
    return ROOT_INV @ world(o)


def bvh_of(*names):
    vs, ts = [], []
    for n in names:
        o = D[PRE + n]
        m = local(o)
        base = len(vs)
        vs += [m @ v.co for v in o.data.vertices]
        o.data.calc_loop_triangles()
        ts += [tuple(base + i for i in t.vertices) for t in o.data.loop_triangles]
    return BVHTree.FromPolygons(vs, ts)


def tris(name):
    me = D[PRE + name].data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def front(tree, x, z):
    hit = tree.ray_cast(Vector((x, -3.0, z)), Vector((0, 1, 0)))
    return hit[0].y if hit[0] else None


def back(tree, x, z):
    return tree.ray_cast(Vector((x, 3.0, z)), Vector((0, -1, 0)))[0]


# ---------------------------------------------------------------- mesh helpers (as build_blip.py)
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
    ob = D[PRE + name]
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
    me = bpy.data.meshes.new(PRE + name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    old = ob.data
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def anchor_pos(name):
    return local(D[PRE + "Anchor_" + name]).translation.copy()


def move_anchor(name, p):
    a = D[PRE + "Anchor_" + name]
    assert a.parent == root
    m = a.matrix_basis.copy()
    m.translation = Vector(p)
    a.matrix_basis = m


def write(ob, pts):
    """Set a mesh's vertices from pet-local points (after any anchor moves)."""
    mi = local(ob).inverted()
    for v, p in zip(ob.data.vertices, pts):
        v.co = mi @ p
    ob.data.update()
    for poly in ob.data.polygons:
        poly.use_smooth = True


def build(S):
    BODY_MAT, SECOND_MAT = bpy.data.materials["petBlip__body"], bpy.data.materials["petBlip__secondary"]
    before = {n: tris(n) for n in ("Body", "Head", "HandL", "HandR", "FootL", "FootR")}
    SNAP = {o.name[len(PRE):]: [local(o) @ v.co for v in o.data.vertices]
            for o in D if o.type == "MESH" and o.name.startswith(PRE)}
    OLD_HEAD, OLD_FACE = bvh_of("Head"), bvh_of("Head", "Muzzle")
    old_top = max(p.z for n in ("EarInnerL", "EarInnerR") for p in SNAP[n])

    # ------------------------------------------------------------ head: one smooth map, so surface anchors ride along
    H = S["head"]

    def f_head(p):
        r = p - NECK
        h = min(max(r.z / 0.66, 0.0), 1.0)
        f = 1.0 + H["broad"] * h * h
        return NECK + Vector((r.x * H["s"][0] * f, r.y * H["s"][1] * f, r.z * H["s"][2] - H["drop"]))

    head_anchors = ("Head", "Forehead", "FaceBridge", "CheekL", "CheekR", "HelixL", "HelixR", "LobeL", "LobeR",
                    "HornL", "HornR", "HatCrown", "EyeLine")
    moved = {n: f_head(anchor_pos(n)) for n in head_anchors}
    for n, p in moved.items():
        move_anchor(n, p)
    write(D[PRE + "Head"], [f_head(p) for p in SNAP["Head"]])
    HEAD = bvh_of("Head")

    def head_top(x, y):
        return HEAD.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))[0]

    # ------------------------------------------------------------ body: superellipsoid (k > 2 squares the profile)
    B = S["body"]
    c, r, k = Vector(B["c"]), Vector(B["r"]), B["k"]

    def f_body(p):
        q = Vector(((p.x - BODY_C0.x) / BODY_R0.x, (p.y - BODY_C0.y) / BODY_R0.y, (p.z - BODY_C0.z) / BODY_R0.z))
        rh = math.hypot(q.x, q.y)
        n = (rh ** k + abs(q.z) ** k) ** (1.0 / k)
        if n > 1e-6:
            q = q * (q.length / n)
        w = 1.0 - B["pear"] * q.z                         # pear: wider below, narrower above
        return Vector((c.x + q.x * r.x * w, c.y + q.y * r.y * w, c.z + q.z * r.z))

    write(D[PRE + "Body"], [f_body(p) for p in SNAP["Body"]])
    BODY = bvh_of("Body")
    chest_y = front(BODY, 0.0, 0.50)
    move_anchor("Chest", (0.0, chest_y, 0.50))
    move_anchor("HandCatch", (0.0, chest_y - 0.07, 0.45))
    move_anchor("Back", back(BODY, 0.0, 0.52))
    for side, sx in (("L", -1.0), ("R", 1.0)):
        move_anchor("Wing" + side, back(BODY, sx * 0.11, 0.54))

    # ------------------------------------------------------------ arms: shorter, out on the flank, swung outward
    A = S["arm"]
    for side in ("L", "R"):
        s_old = anchor_pos("Hand" + side)
        sx = 1.0 if s_old.x > 0 else -1.0
        s_new = Vector((sx * A["shoulder"][0], A["shoulder"][1], A["shoulder"][2]))
        rot = Matrix.Rotation(math.radians(-sx * A["swing"]), 3, "Y")

        axis = (anchor_pos("Wrist" + side) - s_old).normalized()

        def f_arm(p, s_old=s_old, s_new=s_new, rot=rot, axis=axis):
            d = p - s_old                                  # shorter along the arm, nearly as thick: a nub, not a twig
            along = axis * d.dot(axis)
            return s_new + rot @ (along * A["length"] + (d - along) * A["thick"])

        for n in ("Hand", "Wrist", "Claw"):
            move_anchor(n + side, f_arm(anchor_pos(n + side)))
        write(D[PRE + "Hand" + side], [f_arm(p) for p in SNAP["Hand" + side]])

    # ------------------------------------------------------------ feet: chunkier, still on the ground
    F = S["foot"]
    for side in ("L", "R"):
        a = anchor_pos("Foot" + side)
        sx = 1.0 if a.x > 0 else -1.0
        o = Vector((a.x, a.y, 0.0))

        def f_foot(p, o=o, sx=sx):
            d = p - o
            return o + Vector((d.x * F["s"][0] + sx * F["out"], d.y * F["s"][1], d.z * F["s"][2]))

        for n in ("Foot", "Ankle", "Toe"):
            move_anchor(n + side, f_foot(anchor_pos(n + side)))
        write(D[PRE + "Foot" + side], [f_foot(p) for p in SNAP["Foot" + side]])

    # ------------------------------------------------------------ antennae (the ear-flick channel wiggles them)
    N = S["ant"]
    top_z, STALK_INNER = 0.0, 9.0
    for side, sx in (("L", -1.0), ("R", 1.0)):
        base = head_top(sx * N["base"][0], N["base"][1])
        move_anchor("Ear" + side, base)
        start = base - Vector((sx * 0.01, 0, 0.03))
        path = [Vector((sx * x, y, z)) for x, y, z in N["path"]]
        if len(path) == 1:
            pts = [start.lerp(path[0], t) + Vector((sx * 0.012 * math.sin(math.pi * t), 0, 0)) for t in (0.0, 0.34, 0.68, 1.0)]
        else:
            pts = [start] + path
        bm = bmesh.new()
        tube(bm, pts, N["radii"], sides=6)
        stalk = set_mesh("Ear" + side, bm, BODY_MAT, uv=(0.5, 0.9))
        STALK_INNER = min(STALK_INNER, min(abs((local(stalk) @ v.co).x) for v in stalk.data.vertices))
        bm = bmesh.new()
        tip = Vector((sx * N["tip"][0], N["tip"][1], N["tip"][2]))
        ball(bm, tip, N["tip_r"], segs=8, rings=4)
        set_mesh("EarInner" + side, bm, SECOND_MAT)
        top_z = max(top_z, tip.z + N["tip_r"], max(p.z for p in pts) + 0.05)

    # ------------------------------------------------------------ face kit: snout spot, the Bear's eyes and mouth
    PATCH = dict(cz=S["patch_z"], rx=0.135, rz=0.088, rise=0.024, rim=0.010, sink=0.012)
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

    def reseat(short, old_tree, new_tree, to_z=None, dz=0.0, x_mul=1.0):
        ob, pts = D[PRE + short], SNAP[short]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        mid = (lo + hi) / 2
        target = Vector((mid.x * x_mul, mid.y, (mid.z if to_z is None else to_z) + dz))
        out, fallback = [], None
        for p in pts:
            was = front(old_tree, p.x, p.z)
            q = target + (p - mid)
            now = front(new_tree, q.x, q.z)
            if was is not None and now is not None:
                fallback = now + (p.y - was) - q.y
                q.y = now + (p.y - was)
            elif fallback is not None:
                q.y += fallback
            out.append(q)
        write(ob, out)

    for o in list(D):
        if o.type != "MESH" or not o.name.startswith(PRE) or o.parent != D[PRE + "Anchor_Head"]:
            continue
        short = o.name[len(PRE):]
        if short.startswith("Eye"):
            reseat(short, OLD_HEAD, HEAD, to_z=S["eye_z"], x_mul=S["eye_x"])
        elif short.startswith("Mouth"):
            reseat(short, OLD_FACE, FACE, dz=S["patch_z"] - 0.805)
    for side in ("L", "R"):
        p = anchor_pos("Eye" + side)
        x = p.x * S["eye_x"]
        move_anchor("Eye" + side, (x, front(HEAD, x, S["eye_z"]), S["eye_z"]))
    move_anchor("Nose", (0.0, front(FACE, 0.0, S["patch_z"] + 0.095), S["patch_z"] + 0.095))
    move_anchor("Mouth", (0.0, front(FACE, 0.0, S["patch_z"] - 0.005), S["patch_z"] - 0.005))

    # ------------------------------------------------------------ curl tail on the new back
    t = back(BODY, 0.0, 0.36)
    move_anchor("Tail", t)
    curl = [Vector(p) * S["tail"] for p in ((0.0, -0.040, 0.000), (0.0, 0.055, 0.000), (0.008, 0.130, 0.040), (0.018, 0.150, 0.115),
                                            (0.028, 0.105, 0.170), (0.034, 0.050, 0.150), (0.036, 0.045, 0.100))]
    bm = bmesh.new()
    tube(bm, [t + p for p in curl], [v * S["tail"] for v in (0.036, 0.036, 0.034, 0.031, 0.028, 0.026, 0.024)], sides=6)
    ball(bm, t + curl[-1], 0.028 * S["tail"], segs=6, rings=2)
    set_mesh("Tail", bm, SECOND_MAT)

    # ------------------------------------------------------------ charm headroom follows the new top
    for name in ("CharmAnchor", "CharmFloat"):
        p = anchor_pos(name)
        move_anchor(name, (p.x, p.y, p.z + (top_z - old_top)))

    # ------------------------------------------------------------ checks and report
    anchors = [o for o in D if o.type == "EMPTY" and "__Anchor_" in o.name]
    assert len(anchors) == 46, len(anchors)
    for a in anchors:
        assert all(abs(s - 1.0) < 1e-6 for s in a.matrix_basis.to_scale()), a.name
    assert {n: tris(n) for n in before} == before
    root["variant"] = "v2-" + VARIANT
    shown = [o for o in D if o.type == "MESH" and o.name.startswith(PRE) and not o.hide_render and "Charm" not in o.name]
    total, lo, hi = 0, Vector((9, 9, 9)), Vector((-9, -9, -9))
    for o in shown:
        total += tris(o.name[len(PRE):])
        for v in o.data.vertices:
            p = local(o) @ v.co
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    print(f"V2 {VARIANT} TRIS {total}  height {hi.z:.3f} (v1 {old_top:.3f}, Bear 1.48)  width {hi.x - lo.x:.3f}  depth {hi.y - lo.y:.3f}")
    print(f"V2 {VARIANT} HAT stalk inner half-width {STALK_INNER:.3f} (hat limit 0.19)  crown z {anchor_pos('HatCrown').z:.3f}")
    for z in (S["patch_z"] - 0.088, S["patch_z"], S["eye_z"] - 0.13):
        fb, ff = front(BODY, 0.0, z), front(FACE, 0.0, z)
        print(f"V2 {VARIANT} FACE CLEAR z {z:.3f}: face y {ff:.3f}, body y {fb if fb is None else round(fb, 3)}"
              + ("  <-- BODY IN FRONT" if fb is not None and fb < ff else ""))
    for n in ("EyeL", "Mouth", "Chest", "Back", "Tail", "HandL", "WristL", "FootL", "EarL", "HornL", "HelixL", "CharmFloat"):
        print(f"V2 {VARIANT} ANCHOR {n:10s}", [round(v, 3) for v in anchor_pos(n)])


if VARIANT != "REF":
    build(SPEC[VARIANT])
    bpy.context.view_layer.update()
    if SAVE:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT), copy=True)
        print("SAVED", OUT)

# ---------------------------------------------------------------- review renders (flat review materials, v1's rig)
if RENDER:
    sys.path.insert(0, str(Path(__file__).resolve().parent / "deck_art"))
    import render_book_icons as R  # noqa: E402

    tag = ("bear" if IS_BEAR else "v1") if VARIANT == "REF" else VARIANT
    raw = Path(RENDER).resolve() / "raw"       # absolute: Blender resolves a relative path against the drive root
    raw.mkdir(parents=True, exist_ok=True)
    scene, cam = R.setup_scene()
    mat = "petBear" if IS_BEAR else "petBlip"
    bmat = R.flat("review_body", "#FBF3EA" if IS_BEAR else PRIMARY, rough=0.62, spec=0.35)
    smat = R.flat("review_secondary", "#F5A6C6" if IS_BEAR else SECONDARY, rough=0.55)
    for o in D:
        if o.type != "MESH":
            continue
        if not o.name.startswith(PRE) or "Charm" in o.name:
            o.hide_render = True
        for slot in o.material_slots:
            if slot.material and slot.material.name == mat + "__body":
                slot.material = bmat
            elif slot.material and slot.material.name in (mat + "__secondary", mat + "__wing"):
                slot.material = smat
    scene.render.film_transparent = True
    X = world(root).translation.x
    for view, yaw, pitch, size in (("front", 0, 8, 512), ("q", -35, 10, 512), ("side", -90, 6, 512), ("phone", 0, 8, 96)):
        scene.render.resolution_x = scene.render.resolution_y = size
        R.frame(cam, (X, -0.05, 0.80), 2.05, yaw, pitch)
        R.render(scene, str(raw / f"{tag}-{view}.png"))
    print("RENDERED", tag)
