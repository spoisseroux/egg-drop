"""New Pet 1 "Mix" (v2): low-poly retro blend of Spencer's newPet1 and the v1 mockup.
Run inside Blender. Rebuilds only the EggDrop_NewPet1Mix collection. Uses COPIES of Spencer's materials."""
import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PFX = "NewPet1Mix"
COL = "EggDrop_NewPet1Mix"
ROOT_WORLD = Vector((-5.4, 0.0, 0.0))
MAT_SRC = {
    "body": "bodyMat",
    "face": "PetEye",
    "mouth": "attach_0001D590_material_1",
    "wing": "attach_0001CD08_material_0",
    "secondary": "charmMat",
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
for name in [m.name for m in bpy.data.materials if m.name.startswith("newPet1Mix__")]:
    m = bpy.data.materials[name]
    if m.users - (1 if m.use_fake_user else 0) <= 0:
        bpy.data.materials.remove(m)

MATS = {}
for key, src in MAT_SRC.items():
    m = bpy.data.materials.get("newPet1Mix__" + key)
    if m is None:
        m = bpy.data.materials[src].copy()      # copy only; the source material is never edited
        m.name = "newPet1Mix__" + key
        m.use_fake_user = False
    MATS[key] = m


# ---------- helpers (pet-local space) ----------
def new_bm():
    bm = bmesh.new()
    bm.verts.layers.float.new("t")
    return bm


def ellipsoid(bm, fn, useg, vseg):
    r = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in r["verts"]:
        v.co = fn(v.co.normalized())
    return r["verts"]


def sweep(bm, pts, radii, baxis, sides, ts=None):
    lay = bm.verts.layers.float["t"]
    n = len(pts)
    ts = ts or [i / (n - 1) for i in range(n)]
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
            a = 2 * math.pi * (k + 0.5) / sides
            v = bm.verts.new(p + bb * (math.cos(a) * ra) + nn * (math.sin(a) * rb))
            v[lay] = ts[i]
            ring.append(v)
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    c0 = bm.verts.new(pts[0] - (pts[1] - pts[0]).normalized() * min(radii[0]) * 0.7)
    c0[lay] = ts[0]
    c1 = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * min(radii[-1]) * 0.7)
    c1[lay] = ts[-1]
    for k in range(sides):
        k2 = (k + 1) % sides
        bm.faces.new((c0, rings[0][k2], rings[0][k]))
        bm.faces.new((c1, rings[-1][k], rings[-1][k2]))


def bez(p0, p1, p2, t):
    return p0 * (1 - t) ** 2 + p1 * (2 * t * (1 - t)) + p2 * t ** 2


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def surf(bvh, x, z):
    loc, nor, _, _ = bvh.ray_cast(Vector((x, -5.0, z)), Vector((0, 1, 0)))
    return loc, nor


def ang_u(co, c):
    return 0.5 + math.atan2(co.x - c.x, -(co.y - c.y)) / (2 * math.pi) * 0.9


A = {
    "Body": Vector((0, -0.05, 0.455)),
    "Head": Vector((0, -0.02, 0.70)),
    "HandL": Vector((-0.215, -0.08, 0.65)),
    "HandR": Vector((0.215, -0.08, 0.65)),
    "FootL": Vector((-0.165, -0.09, 0.105)),
    "FootR": Vector((0.165, -0.09, 0.105)),
    "WingL": Vector((-0.11, 0.17, 0.54)),
    "WingR": Vector((0.11, 0.17, 0.54)),
    "Tail": Vector((0, 0.22, 0.33)),
    "CharmAnchor": Vector((0.60, -0.12, 1.47)),
}
pieces = []


def piece(role, channel, anchor, bm, matkey, uvfn, **extra):
    pieces.append((role, channel, anchor, bm, matkey, uvfn, extra))


# bodyTex is a vertical gradient: v = 1 yellow ... v = 0 pink; u does not matter.

# ---------- Body (his proportions: 0.54 wide, y -0.41..0.24, z 0.17..0.74) ----------
def body_fn(u):
    k = 1.0 - 0.15 * u.z
    return Vector((0.272 * u.x * k, -0.085 + 0.325 * u.y * k, 0.455 + 0.29 * u.z))


bm = new_bm()
ellipsoid(bm, body_fn, 12, 8)
body_bvh = BVHTree.FromBMesh(bm)
BELLY = Vector((0, -0.41, 0.42))
piece("Body", "Body", "Body", bm, "body",
      lambda co, t: (ang_u(co, Vector((0, -0.085, 0))), clamp(0.22 + 1.9 * max(0.0, (co - BELLY).length - 0.06))))

# ---------- Head: wide mochi, faceted, soft cheek corners, flat loaf top (no point) ----------
HC = Vector((0, -0.04, 1.0))
HEAD_BOT, HEAD_TOP = 0.62, 1.40


def head_fn(u):
    cheek = 1.0 + 0.30 * max(0.0, -u.z + 0.15) * (1 - max(0.0, -u.z))
    zr = 0.40 if u.z > 0 else 0.38
    flat = 1.0 - 0.10 * max(0.0, u.z) ** 3
    corner = 1.0 + 0.08 * abs(u.x) ** 6 * max(0.0, 1 - abs(u.z + 0.25) * 2)
    return Vector((0.49 * u.x * cheek * corner, HC.y + 0.44 * u.y * (1 + 0.5 * (cheek - 1)), HC.z + zr * u.z * flat))


bm = new_bm()
ellipsoid(bm, head_fn, 12, 9)
head_bvh = BVHTree.FromBMesh(bm)
piece("Head", "Head", "Head", bm, "body",
      lambda co, t: (ang_u(co, HC), 1.0 - 0.72 * clamp((co.z - HEAD_BOT) / (HEAD_TOP - HEAD_BOT)) ** 1.6))

# ---------- Ears: droopy petal flaps, pink tips ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = new_bm()
    p0, p1, p2 = Vector((sx * 0.34, 0.03, 1.19)), Vector((sx * 0.72, 0.04, 1.28)), Vector((sx * 0.68, 0.02, 0.74))
    ts = [0.0, 0.2, 0.42, 0.62, 0.8, 0.93, 1.0]
    pts = [bez(p0, p1, p2, t) for t in ts]
    w = [0.07, 0.085, 0.11, 0.14, 0.15, 0.11, 0.05]
    th = [0.055, 0.06, 0.065, 0.07, 0.07, 0.055, 0.03]
    sweep(bm, pts, list(zip(w, th)), Vector((0, 1, 0)), 8, ts)
    piece("Ear" + side, "Head", "Head", bm, "body", lambda co, t: (0.5 + co.y, clamp(0.95 - 0.95 * t)))

# ---------- Eyes: his eye texture (black disc, white ring), tall ovals ----------
EYE_X, EYE_Z, EYE_RX, EYE_RZ = 0.215, 0.95, 0.088, 0.122
for side, sx in (("L", -1), ("R", 1)):
    bm = new_bm()
    c, nrm = surf(head_bvh, sx * EYE_X, EYE_Z)
    rgt = Vector((1, 0, 0))
    rgt = (rgt - nrm * rgt.dot(nrm)).normalized()
    upv = nrm.cross(rgt)
    if upv.z < 0:
        upv = -upv
    N = 10
    uvmap = {}
    cv = bm.verts.new(c + nrm * 0.03)
    uvmap[cv] = (0.5, 0.5)
    ring = []
    for k in range(N):
        a = 2 * math.pi * k / N
        p = c + rgt * (math.cos(a) * EYE_RX) + upv * (math.sin(a) * EYE_RZ)
        hit, hn, _, _ = head_bvh.ray_cast(p + nrm * 0.6, -nrm)
        v = bm.verts.new((hit if hit is not None else p) + nrm * 0.012)
        uvmap[v] = (0.5 + 0.43 * math.cos(a), 0.5 + 0.43 * math.sin(a))
        ring.append(v)
    for k in range(N):
        bm.faces.new((cv, ring[k], ring[(k + 1) % N]))
    bm.verts.ensure_lookup_table()
    table = {v.index: uv for v, uv in uvmap.items()}
    bm.verts.index_update()
    table = {v.index: uv for v, uv in uvmap.items()}
    piece("Eye" + side, "Head", "Head", bm, "face", ("index", table))

# ---------- Mouth: alpha-cutout patch using his mouthTex ("v" smile) ----------
bm = new_bm()
MZ, MW = 0.82, 0.07
grid, table = [], {}
for j in range(3):
    row = []
    for i in range(3):
        x = (i - 1) * MW
        z = MZ + (1 - j) * MW
        loc, nor = surf(head_bvh, x, z)
        v = bm.verts.new(loc + nor * 0.012)
        row.append(v)
    grid.append(row)
bm.verts.index_update()
for j in range(3):
    for i in range(3):
        # his mapping: top of the patch = v 0, so the texture's "^" reads as a "v" on the face
        table[grid[j][i].index] = (0.25 + 0.25 * i, 0.03 + 0.25 * j)
for j in range(2):
    for i in range(2):
        bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
piece("Mouth", "Head", "Head", bm, "mouth", ("index", table))

# ---------- Hands: his long stubby arms, pink mitten tips ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = new_bm()
    p0, p1, p2 = Vector((sx * 0.20, -0.08, 0.67)), Vector((sx * 0.34, -0.08, 0.52)), Vector((sx * 0.335, -0.14, 0.255))
    ts = [0.0, 0.25, 0.55, 0.82, 1.0]
    pts = [bez(p0, p1, p2, t) for t in ts]
    r = [0.05, 0.068, 0.088, 0.095, 0.055]
    sweep(bm, pts, [(x * 1.1, x) for x in r], Vector((0, 1, 0)), 8, ts)
    piece("Hand" + side, "Hand" + side, "Hand" + side, bm, "body", lambda co, t: (0.5 + co.y, clamp(0.92 - 0.95 * t)))

# ---------- Feet: his slippers (0.31 x 0.60 x 0.24), flat soles, pink toes ----------
for side, sx in (("L", -1), ("R", 1)):
    bm = new_bm()
    c0 = Vector((sx * 0.165, -0.09, 0.0))

    def foot_fn(u, c0=c0):
        hi = 0.15 * (1.0 - 0.45 * max(0.0, -u.y)) * (1.0 - 0.2 * max(0.0, u.y))
        z = max(0.0, 0.09 + (hi if u.z > 0 else 0.09) * u.z)
        if u.z < -0.3:
            z = 0.0
        return c0 + Vector((0.155 * u.x * (1 - 0.15 * max(0.0, u.y)), 0.30 * u.y, z))

    ellipsoid(bm, foot_fn, 10, 6)
    piece("Foot" + side, "Foot" + side, "Foot" + side, bm, "body",
          lambda co, t: (0.5 + co.x, clamp((co.y + 0.39) / 0.60)))

# ---------- Wings: his small three-feather wing silhouette, modelled fresh ----------
# outline in the wing plane: (s = distance out from the root, z = height)
OUT = [(0.00, 0.50), (0.00, 0.58), (0.15, 0.70), (0.34, 0.765), (0.54, 0.745), (0.55, 0.67), (0.36, 0.56),
       (0.42, 0.485), (0.35, 0.44), (0.27, 0.455), (0.25, 0.37), (0.15, 0.385), (0.07, 0.43)]
SPINE = [((0.12, 0.555), 0.045), ((0.32, 0.655), 0.04)]
for side, sx in (("L", -1), ("R", 1)):
    bm = new_bm()
    d = Vector((sx * 0.7071, 0.7071, 0))
    nrm = Vector((-sx * 0.7071, 0.7071, 0))
    base = Vector((sx * 0.11, 0.17, 0))
    P = lambda s, z, off=0.0: base + d * s + Vector((0, 0, z)) + nrm * off
    table = {}
    ov = [bm.verts.new(P(s, z)) for s, z in OUT]
    for face_sign in (1, -1):
        a_v = bm.verts.new(P(*SPINE[0][0], face_sign * SPINE[0][1]))
        b_v = bm.verts.new(P(*SPINE[1][0], face_sign * SPINE[1][1]))
        tris = [(ov[0], ov[1], a_v), (ov[1], ov[2], a_v), (ov[2], b_v, a_v), (ov[2], ov[3], b_v), (ov[3], ov[4], b_v),
                (ov[4], ov[5], b_v), (ov[5], ov[6], b_v), (ov[6], a_v, b_v)]
        for i in range(6, 12):
            tris.append((ov[i], ov[i + 1], a_v))
        tris.append((ov[12], ov[0], a_v))
        for t3 in tris:
            bm.faces.new(t3 if face_sign > 0 else t3[::-1])
    piece("Wing" + side, "Body", "Wing" + side, bm, "wing",
          lambda co, t, base=base, d=d: (clamp(0.05 + (co - base).dot(d) / 0.6), clamp((co.z - 0.35) / 0.45)))

# ---------- Tail: v1 fiddlehead curl, low-poly ----------
bm = new_bm()
C = Vector((0, 0.43, 0.49))
n = 18
pts, rad, ts = [Vector((0, 0.17, 0.36))], [(0.07, 0.07)], [0.0]
th0, th1 = math.radians(-125), math.radians(-125 + 410)
for i in range(n):
    s = i / (n - 1)
    th = th0 + (th1 - th0) * s
    r = 0.16 * (1 - s) ** 1.1 + 0.03
    pts.append(C + Vector((0, math.cos(th) * r, math.sin(th) * r)))
    tr = 0.07 * (1 - 0.55 * s)
    rad.append((tr * 1.15, tr))
    ts.append(0.08 + 0.92 * s)
sweep(bm, pts, rad, Vector((1, 0, 0)), 6, ts)
piece("Tail", "Body", "Tail", bm, "body", lambda co, t: (0.5 + co.x, clamp(0.95 - 0.9 * t)))

# ---------- Charm: low-poly five-petal bloom, off to the side (his charmMat copy) ----------
bm = new_bm()
cc = A["CharmAnchor"]
fn_ = Vector((0.22, -0.92, 0.30)).normalized()
ax = fn_.cross(Vector((0, 0, 1))).normalized()
ay = ax.cross(fn_).normalized()


def octa(bm, ctr, e1, e2, e3):
    vs = [bm.verts.new(ctr + e) for e in (e1, -e1, e2, -e2, e3, -e3)]
    for a, b, c in ((0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)):
        bm.faces.new((vs[a], vs[b], vs[c]))


for k in range(5):
    a = math.radians(90 + 72 * k)
    rd = ax * math.cos(a) + ay * math.sin(a)
    tg = fn_.cross(rd)
    octa(bm, cc + rd * 0.078, rd * 0.062, tg * 0.05, fn_ * 0.028)
octa(bm, cc + fn_ * 0.012, ax * 0.042, ay * 0.042, fn_ * 0.04)
piece("CharmDot", "CharmAnchor", "CharmAnchor", bm, "secondary",
      lambda co, t: (clamp(0.5 + (co - cc).dot(ax) / 0.3), clamp(0.5 + (co - cc).dot(ay) / 0.3)), optional=True)

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

tot = 0
for role, channel, anchor, bm, matkey, uvfn, extra in pieces:
    off = A[anchor]
    lay = bm.verts.layers.float["t"]
    if not (isinstance(uvfn, tuple) and uvfn[0] == "index"):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if role in ("EyeL", "EyeR", "Mouth"):
        # make sure the decals face the front (-Y)
        if sum((f.normal.y for f in bm.faces)) > 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for l in f.loops:
            if isinstance(uvfn, tuple):
                l[uvl].uv = uvfn[1][l.vert.index]
            else:
                l[uvl].uv = uvfn(l.vert.co, l.vert[lay])
    bm.verts.layers.float.remove(lay)
    for v in bm.verts:
        v.co -= off
    me = bpy.data.meshes.new(f"{PFX}__{role}")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(MATS[matkey])
    ob = bpy.data.objects.new(f"{PFX}__{role}", me)
    ob.parent = anchors[anchor]
    ob["role"] = role
    ob["channel"] = channel
    for k, v in extra.items():
        ob[k] = v
    col.objects.link(ob)
    me.calc_loop_triangles()
    tot += len(me.loop_triangles)
    print(ob.name, len(me.loop_triangles), matkey)
bpy.context.view_layer.update()
print("TOTAL tris", tot)
for k, v in A.items():
    print("ANCHOR", k, tuple(round(c, 3) for c in v))
