import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PFX = "NewPet1Mockup"
COL = "EggDrop_NewPet1Mockup"
ROOT_WORLD = Vector((-3.2, 0.0, 0.0))

PALETTE = {
    "body": "#D3C9E2",
    "secondary": "#E2AE8C",
    "face": "#3B3348",
    "mouth": "#7C5468",
    "ivory": "#FFF6E9",
    "blush": "#E3A7AE",
}

# ---------- cleanup of OUR datablocks only ----------
col = bpy.data.collections.get(COL)
if col:
    for name in [o.name for o in col.objects]:
        ob = bpy.data.objects.get(name)
        if ob is not None:
            bpy.data.objects.remove(ob, do_unlink=True)
else:
    col = bpy.data.collections.new(COL)
    bpy.context.scene.collection.children.link(col)
for name in [m.name for m in bpy.data.meshes if m.name.startswith(PFX + "__") and m.users == 0]:
    bpy.data.meshes.remove(bpy.data.meshes[name])
for name in [m.name for m in bpy.data.materials if m.name.startswith("newPet1Mockup__") and m.users == 0]:
    bpy.data.materials.remove(bpy.data.materials[name])


def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_mat(key):
    h = PALETTE[key].lstrip("#")
    rgb = [srgb2lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    m = bpy.data.materials.new("newPet1Mockup__" + key)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.32 if key in ("face", "ivory") else 0.48
    m.diffuse_color = (*rgb, 1.0)
    return m


MATS = {k: make_mat(k) for k in PALETTE}


# ---------- geometry helpers (all in pet-local space) ----------
def ellipsoid(bm, fn, useg=24, vseg=12):
    """fn(unit Vector) -> Vector position."""
    r = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in r["verts"]:
        v.co = fn(v.co.normalized())
    return r["verts"]


def sweep(bm, pts, radii, baxis, sides=10):
    """Tube along pts. radii[i] = (ra along binormal-ish axis, rb along normal)."""
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        nn = t.cross(baxis)
        if nn.length < 1e-6:
            nn = t.orthogonal()
        nn.normalize()
        bb = nn.cross(t).normalized()
        ra, rb = radii[i]
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + bb * (math.cos(a) * ra) + nn * (math.sin(a) * rb)))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    c0 = bm.verts.new(pts[0] - (pts[1] - pts[0]).normalized() * min(radii[0]) * 0.6)
    c1 = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * min(radii[-1]) * 0.6)
    for k in range(sides):
        k2 = (k + 1) % sides
        bm.faces.new((c0, rings[0][k2], rings[0][k]))
        bm.faces.new((c1, rings[-1][k], rings[-1][k2]))


def bez(p0, p1, p2, t):
    return p0 * (1 - t) ** 2 + p1 * (2 * t * (1 - t)) + p2 * t ** 2


def cos_samples(n):
    return [(1 - math.cos(math.pi * i / (n - 1))) / 2 for i in range(n)]


def cap(i, n, p=0.5, lo=0.12):
    return lo + (1 - lo) * max(0.0, math.sin(math.pi * i / (n - 1))) ** p


def decal(bm, bvh, x0, z0, rx, rz, th, tilt=0.0, useg=14, vseg=8, lift=0.003):
    """Lens-shaped blob that hugs the surface hit by a +Y ray (i.e. on the pet's face)."""
    r = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    ct, st = math.cos(tilt), math.sin(tilt)
    for v in r["verts"]:
        # sphere pole axis is Z by default; rotate so pole axis is Y (front/back)
        u, w, d = v.co.x, v.co.y, v.co.z      # d = depth (+ = outward)
        uu, ww = u * ct - w * st, u * st + w * ct
        loc, nor, _, _ = bvh.ray_cast(Vector((x0 + uu * rx, -5.0, z0 + ww * rz)), Vector((0, 1, 0)))
        v.co = loc + nor * (d * th + lift)


def surf(bvh, x, z):
    loc, nor, _, _ = bvh.ray_cast(Vector((x, -5.0, z)), Vector((0, 1, 0)))
    return loc, nor


# ---------- anchors (pet-local) ----------
A = {
    "Body": Vector((0, -0.05, 0.455)),
    "Head": Vector((0, -0.02, 0.70)),
    "HandL": Vector((-0.235, -0.04, 0.635)),
    "HandR": Vector((0.235, -0.04, 0.635)),
    "FootL": Vector((-0.168, -0.09, 0.105)),
    "FootR": Vector((0.168, -0.09, 0.105)),
    "WingL": Vector((-0.11, 0.20, 0.585)),
    "WingR": Vector((0.11, 0.20, 0.585)),
    "Tail": Vector((0, 0.22, 0.33)),
    "CharmAnchor": Vector((0.60, -0.12, 1.47)),
}

pieces = []  # (role, channel, anchor, bm, matkey, extra)


def piece(role, channel, anchor, bm, matkey, **extra):
    pieces.append((role, channel, anchor, bm, matkey, extra))


# ---------- Body: chubby pear ----------
def body_fn(u):
    k = 1.0 - 0.16 * u.z            # wider low, narrower at the neck
    return Vector((0.285 * u.x * k, -0.085 + 0.325 * u.y * k - 0.03 * max(0, -u.y) * (1 - abs(u.z)),
                   0.455 + 0.295 * u.z))


bm_body = bmesh.new()
ellipsoid(bm_body, body_fn, 20, 12)
body_bvh = BVHTree.FromBMesh(bm_body)
piece("Body", "Body", "Body", bm_body, "body")

# ---------- Head: wide mochi / bean, cheeks low, no point ----------
HC = Vector((0, -0.04, 1.005))


def head_fn(u):
    cheek = 1.0 + 0.11 * max(0.0, -u.z + 0.15) * (1 - max(0.0, -u.z)) * 2.2   # puff below the equator
    zr = 0.405 if u.z > 0 else 0.385
    top_flat = 1.0 - 0.06 * max(0.0, u.z) ** 3                               # soft loaf top
    return Vector((HC.x + 0.50 * u.x * cheek, HC.y + 0.455 * u.y * (1 + 0.5 * (cheek - 1)),
                   HC.z + zr * u.z * top_flat))


bm_head = bmesh.new()
ellipsoid(bm_head, head_fn, 32, 18)
head_bvh = BVHTree.FromBMesh(bm_head)
piece("Head", "Head", "Head", bm_head, "body")

# ---------- Ears: droopy petal flaps ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = bmesh.new()
    p0, p1, p2 = Vector((sx * 0.33, 0.03, 1.20)), Vector((sx * 0.74, 0.04, 1.30)), Vector((sx * 0.70, 0.02, 0.72))
    n = 13
    ts = cos_samples(n)
    pts = [bez(p0, p1, p2, t) for t in ts]
    rad = []
    for i, t in enumerate(ts):
        c = cap(i, n, 0.55, 0.10)
        rad.append(((0.062 + 0.088 * t) * c, (0.048 + 0.018 * t) * c))
    sweep(bm, pts, rad, Vector((0, 1, 0)), 10)
    piece("Ear" + side, "Head", "Head", bm, "secondary")

# ---------- Face ----------
EYE_X, EYE_Z = 0.245, 0.955
for side, sx in (("L", -1), ("R", 1)):
    bm = bmesh.new()
    decal(bm, head_bvh, sx * EYE_X, EYE_Z, 0.074, 0.066, 0.022, tilt=-sx * math.radians(8))
    piece("Eye" + side, "Head", "Head", bm, "face")
    bm = bmesh.new()
    decal(bm, head_bvh, sx * EYE_X - 0.022, EYE_Z + 0.022, 0.021, 0.021, 0.006, useg=8, vseg=4, lift=0.026)
    piece("Glint" + side, "Head", "Head", bm, "ivory")
    bm = bmesh.new()
    decal(bm, head_bvh, sx * 0.375, 0.845, 0.066, 0.040, 0.006, useg=12, vseg=6, lift=0.002)
    piece("Cheek" + side, "Head", "Head", bm, "blush")

# mouth: small soft "w"
bm = bmesh.new()
n = 17
pts, rad = [], []
for i in range(n):
    s = i / (n - 1)
    x = (s - 0.5) * 0.125
    z = 0.888 - 0.024 * abs(math.sin(2 * math.pi * s)) ** 0.8
    loc, nor = surf(head_bvh, x, z)
    pts.append(loc + nor * 0.006)
    c = cap(i, n, 0.5, 0.35)
    rad.append((0.0125 * c, 0.0125 * c))
sweep(bm, pts, rad, Vector((0, 1, 0)), 6)
piece("Mouth", "Head", "Head", bm, "mouth")

# ---------- Hands: stubby mitten arms ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = bmesh.new()
    p0 = Vector((sx * 0.215, -0.04, 0.655))
    p1 = Vector((sx * 0.34, -0.07, 0.56))
    p2 = Vector((sx * 0.375, -0.115, 0.37))
    n = 12
    ts = cos_samples(n)
    pts = [bez(p0, p1, p2, t) for t in ts]
    rad = []
    for i, t in enumerate(ts):
        c = cap(i, n, 0.5, 0.15)
        r = (0.068 + 0.040 * t) * c
        rad.append((r * 1.08, r))
    sweep(bm, pts, rad, Vector((0, 1, 0)), 10)
    piece("Hand" + side, "Hand" + side, "Hand" + side, bm, "body")

# ---------- Feet: long flat-bottomed slippers, slight toe-out ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = bmesh.new()
    rot = Matrix.Rotation(sx * math.radians(7), 3, "Z")
    c0 = Vector((sx * 0.168, -0.09, 0.0))

    def foot_fn(u, c0=c0, rot=rot):
        toe = 1.0 + 0.12 * max(0.0, -u.y)           # rounder, wider toe
        z = max(0.0, 0.095 + (0.145 if u.z > 0 else 0.095) * u.z)
        return c0 + rot @ Vector((0.148 * u.x * toe, 0.295 * u.y, 0.0)) + Vector((0, 0, z))

    vs = ellipsoid(bm, foot_fn, 18, 10)
    # flatten the sole: anything in the lowest band sits on z = 0
    for v in vs:
        if v.co.z < 0.022:
            v.co.z = 0.0
    piece("Foot" + side, "Foot" + side, "Foot" + side, bm, "secondary")

# ---------- Wings: two soft petal paddles per side (no feathers) ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = bmesh.new()
    root = A["Wing" + side]
    d_up = Vector((sx * 0.66, 0.56, 0.48)).normalized()
    d_lo = Vector((sx * 0.78, 0.55, -0.34)).normalized()
    nrm = d_up.cross(d_lo).normalized()
    if nrm.y < 0:
        nrm = -nrm
    for d, length, width, thick in ((d_up, 0.48, 0.165, 0.034), (d_lo, 0.32, 0.120, 0.030)):
        wax = nrm.cross(d).normalized()
        n = 11
        ts = cos_samples(n)
        start = root - d * 0.06
        pts = [start + d * (length * t) for t in ts]
        rad = []
        for i, t in enumerate(ts):
            prof = max(0.0, math.sin(math.pi * min(1.0, t ** 0.85))) ** 0.42
            prof = max(prof, 0.16)
            rad.append((width * prof, thick * max(prof, 0.5) * (1 - 0.3 * t)))
        sweep(bm, pts, rad, wax, 8)
    piece("Wing" + side, "Body", "Wing" + side, bm, "secondary")

# ---------- Tail: fiddlehead curl ----------
bm = bmesh.new()
C = Vector((0, 0.435, 0.50))
n = 24
pts, rad = [], []
th0, th1 = math.radians(-125), math.radians(-125 + 430)
pts.append(Vector((0, 0.17, 0.36)))
rad.append((0.075, 0.075))
for i in range(n):
    s = i / (n - 1)
    th = th0 + (th1 - th0) * s
    r = 0.165 * (1 - s) ** 1.15 + 0.022
    pts.append(C + Vector((0, math.cos(th) * r, math.sin(th) * r)))
    tr = 0.072 * (1 - 0.55 * s)
    rad.append((tr * 1.15, tr))
sweep(bm, pts, rad, Vector((1, 0, 0)), 8)
piece("Tail", "Body", "Tail", bm, "body")

# ---------- Charm: a little five-petal bloom drifting beside the ear ----------
bm = bmesh.new()
cc = A["CharmAnchor"]
fn_ = Vector((0.22, -0.92, 0.30)).normalized()
ax = fn_.cross(Vector((0, 0, 1))).normalized()
ay = ax.cross(fn_).normalized()
for k in range(5):
    a = math.radians(90 + 72 * k)
    rd = ax * math.cos(a) + ay * math.sin(a)
    tg = fn_.cross(rd)
    ctr = cc + rd * 0.074 - fn_ * 0.008
    ellipsoid(bm, lambda u, ctr=ctr, rd=rd, tg=tg: ctr + rd * (0.060 * u.x) + tg * (0.050 * u.y) + fn_ * (0.030 * u.z), 8, 5)
ellipsoid(bm, lambda u: cc + ax * (0.046 * u.x) + ay * (0.046 * u.y) + fn_ * (0.012 + 0.040 * u.z), 8, 5)
piece("CharmDot", "CharmAnchor", "CharmAnchor", bm, "secondary", optional=True)

# ---------- Alternates (hidden) ----------
bm = bmesh.new()
ellipsoid(bm, head_fn, 32, 18)
for sx in (-1, 1):
    ctr = Vector((sx * 0.265, -0.03, 1.375))
    ellipsoid(bm, lambda u, ctr=ctr: ctr + Vector((0.135 * u.x, 0.115 * u.y, 0.125 * u.z)), 14, 8)
piece("AltHeadNubs", "Head", "Head", bm, "body", alternate=True, replaces="Head (hide EarL/EarR)")

bm = bmesh.new()
top = Vector((0, -0.03, 1.385))
n = 8
pts = [top + Vector((0.02 * math.sin(i / (n - 1) * 2.0), 0, 0.15 * i / (n - 1))) for i in range(n)]
sweep(bm, pts, [(0.028, 0.028)] * n, Vector((0, 1, 0)), 8)
tip = pts[-1]
for sx, ln, up in ((-1, 0.27, 0.10), (1, 0.21, 0.14)):
    n = 11
    ts = cos_samples(n)
    p0, p1, p2 = tip - Vector((0, 0, 0.02)), tip + Vector((sx * ln * 0.5, 0, up)), tip + Vector((sx * ln, -0.02, -0.02))
    lp = [bez(p0, p1, p2, t) for t in ts]
    rd = [((0.02 + 0.085 * math.sin(math.pi * t) ** 0.7), 0.022 * (0.5 + 0.5 * math.sin(math.pi * t))) for t in ts]
    sweep(bm, lp, rd, Vector((0, 1, 0)), 10)
piece("AltSproutTuft", "Head", "Head", bm, "secondary", alternate=True, replaces="EarL/EarR (add-on to Head)")

# ---------- derived anchors ----------
eloc, _ = surf(head_bvh, 0.0, EYE_Z)
A["EyeLine"] = Vector((0, round(eloc.y, 3), EYE_Z))
bloc, _, _, _ = body_bvh.ray_cast(Vector((0, -5, 0.45)), Vector((0, 1, 0)))
A["HandCatch"] = Vector((0, round(bloc.y - 0.06, 3), 0.45))

# ---------- objects ----------
root = bpy.data.objects.new(PFX, None)
root.empty_display_type = "PLAIN_AXES"
root.empty_display_size = 0.12
root.location = ROOT_WORLD
col.objects.link(root)

anchors = {}
for name in ["Body", "Head", "EyeLine", "HandCatch", "HandL", "HandR", "FootL", "FootR", "WingL", "WingR", "Tail", "CharmAnchor"]:
    e = bpy.data.objects.new(f"{PFX}__Anchor_{name}", None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.045
    e.parent = root
    e.location = A[name]
    col.objects.link(e)
    anchors[name] = e

report = []
for role, channel, anchor, bm, matkey, extra in pieces:
    off = A[anchor]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for v in bm.verts:
        v.co -= off
    me = bpy.data.meshes.new(f"{PFX}__{role}")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(MATS[matkey])
    ob = bpy.data.objects.new(f"{PFX}__{role}", me)
    ob.parent = anchors[anchor]
    ob["role"] = role
    ob["channel"] = channel
    for k, v in extra.items():
        ob[k] = v
    col.objects.link(ob)
    if extra.get("alternate"):
        ob.hide_viewport = True
        ob.hide_render = True
    report.append(ob.name)

bpy.context.view_layer.update()

# ---------- UVs ----------
view_layer = bpy.context.view_layer
prev_active = view_layer.objects.active
prev_sel = [o.name for o in bpy.context.selected_objects]
for o in bpy.context.selected_objects:
    o.select_set(False)
for name in report:
    ob = bpy.data.objects[name]
    was_hidden = ob.hide_viewport
    ob.hide_viewport = False
    ob.data.uv_layers.new(name="UVMap")
    ob.select_set(True)
    view_layer.objects.active = ob
    try:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception as ex:
        print("UV fail", name, ex)
    ob.select_set(False)
    ob.hide_viewport = was_hidden
for nme in prev_sel:
    o = bpy.data.objects.get(nme)
    if o:
        o.select_set(True)
view_layer.objects.active = prev_active

tot = 0
for name in report:
    me = bpy.data.objects[name].data
    me.calc_loop_triangles()
    t = len(me.loop_triangles)
    alt = bool(bpy.data.objects[name].get("alternate"))
    if not alt:
        tot += t
    print(name, t, "ALT" if alt else "")
print("TOTAL primary tris", tot)
for k, v in A.items():
    print("ANCHOR", k, tuple(round(c, 3) for c in v))
