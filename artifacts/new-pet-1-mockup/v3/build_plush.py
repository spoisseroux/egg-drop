"""New Pet 1 v3: four plush baby animals (Bear, Dog, Cat, Bunny) on one shared base.
Run inside Blender with garden-babies.blend open. Rebuilds only the EggDrop_NewPet1Plush* collections.
Uses COPIES of Spencer's materials and of the v2 wing / flower meshes; never edits the originals."""
import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

BASE = "NewPet1Plush"
ANIMALS = {
    "Bear": dict(x=-7.8, body="#D8A45C", sec="#F2E2C2", nose="nose"),
    "Dog": dict(x=-10.2, body="#EEDFC4", sec="#B88A5E", nose="nose"),
    "Cat": dict(x=-12.6, body="#A7ABB8", sec="#ECEAF1", nose="nosePink"),
    "Bunny": dict(x=-15.0, body="#F1B8C7", sec="#FCEFF1", nose="nosePink"),
}


def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexlin(h):
    h = h.lstrip("#")
    return [srgb2lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)] + [1.0]


# ---------- cleanup of OUR datablocks only ----------
for cname in [c.name for c in bpy.data.collections if c.name.startswith("EggDrop_" + BASE)]:
    c = bpy.data.collections[cname]
    for name in [o.name for o in c.objects]:
        ob = bpy.data.objects.get(name)
        if ob is not None:
            bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.collections.remove(c)
for name in [m.name for m in bpy.data.meshes if m.name.startswith(BASE) and m.users == 0]:
    bpy.data.meshes.remove(bpy.data.meshes[name])
for name in [m.name for m in bpy.data.materials if m.name.startswith("newPet1Plush__")]:
    bpy.data.materials.remove(bpy.data.materials[name])

# ---------- grayscale gradient texture (same layout as his bodyTex_Gradient) ----------
src_img = bpy.data.materials["bodyMat"].node_tree.nodes
src_img = next(n.image for n in src_img if n.type == "TEX_IMAGE")
_old = bpy.data.images.get("plushBodyTex_Gray")
if _old is not None:
    bpy.data.images.remove(_old)
gray = None
if gray is None:
    w, h = src_img.size
    px = list(src_img.pixels)                       # read only
    mb = max(px[2::4]) or 1.0
    out = []
    for i in range(0, len(px), 4):
        g = 0.72 + 0.28 * (px[i + 2] / mb)          # his pink end -> white, his yellow end -> light gray
        out += [g, g, g, 1.0]
    gray = bpy.data.images.new("plushBodyTex_Gray", w, h, alpha=False)
    gray.pixels = out
    gray.pack()


def bsdf(m):
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def tinted(name, hexcol):
    m = bpy.data.materials["bodyMat"].copy()
    m.name = "newPet1Plush__" + name
    nt = m.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    tex.image = gray
    b = bsdf(m)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.label = "Plush tint"
    mix.location = (tex.location.x + 280, tex.location.y)
    ins = {s.identifier: s for s in mix.inputs}
    outs = {s.identifier: s for s in mix.outputs}
    ins["Factor_Float"].default_value = 1.0
    ins["B_Color"].default_value = hexlin(hexcol)
    for l in [l for l in nt.links if l.to_socket == b.inputs["Base Color"]]:
        nt.links.remove(l)
    nt.links.new(tex.outputs["Color"], ins["A_Color"])
    nt.links.new(outs["Result_Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    return m


def flat(name, src, hexcol=None, rough=None):
    m = bpy.data.materials[src].copy()
    m.name = "newPet1Plush__" + name
    if hexcol:
        bsdf(m).inputs["Base Color"].default_value = hexlin(hexcol)
        m.diffuse_color = hexlin(hexcol)
    if rough is not None:
        bsdf(m).inputs["Roughness"].default_value = rough
    return m


SHARED = {
    "face": flat("face", "PetEye"),
    "mouth": flat("mouth", "attach_0001D590_material_1"),
    "wing": flat("wing", "attach_0001CD08_material_0"),
    "charm": flat("charm", "charmMat"),
    "nose": flat("nose", "charmMat", "#3A2A2E", 0.45),
    "nosePink": flat("nosePink", "charmMat", "#D98A9A", 0.45),
}


# ---------- geometry helpers (pet-local) ----------
def new_bm():
    bm = bmesh.new()
    for n in ("t", "uu", "vv"):
        bm.verts.layers.float.new(n)
    return bm


def ellipsoid(bm, fn, useg, vseg):
    r = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in r["verts"]:
        v.co = fn(v.co.normalized())
    return r["verts"]


def ball(bm, c, rx, ry, rz, useg=12, vseg=7):
    return ellipsoid(bm, lambda u: Vector((c.x + rx * u.x, c.y + ry * u.y, c.z + rz * u.z)), useg, vseg)


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


def cos_ts(n):
    return [(1 - math.cos(math.pi * i / (n - 1))) / 2 for i in range(n)]


def blob_path(bm, p0, p1, p2, n, wfn, thfn, baxis, sides):
    """Rounded-end sweep along a quadratic bezier; wfn/thfn(t) give the half width / half thickness."""
    ts = cos_ts(n)
    rad = []
    for i, t in enumerate(ts):
        c = 0.14 + 0.86 * max(0.0, math.sin(math.pi * i / (n - 1))) ** 0.5
        rad.append((wfn(t) * c, thfn(t) * c))
    sweep(bm, [bez(p0, p1, p2, t) for t in ts], rad, baxis, sides, ts)


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ray(bvh, x, z):
    loc, nor, _, _ = bvh.ray_cast(Vector((x, -5.0, z)), Vector((0, 1, 0)))
    return loc, nor


def set_uv(bm, v, u, vv):
    v[bm.verts.layers.float["uu"]] = u
    v[bm.verts.layers.float["vv"]] = vv


X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
HC = Vector((0, -0.03, 1.0))
BELLY = Vector((0, -0.41, 0.42))
CHARM = Vector((0.60, -0.12, 1.47))

# gray gradient: V = 0 lightest (paws, tips, belly) ... V >= 0.5 base plush colour
UV_BASE = lambda co, t: (0.5 + co.x * 0.5, 0.9)
UV_LIGHT = lambda co, t: (0.5 + co.x * 0.5, 0.05)
UV_TIP = lambda co, t: (0.5 + co.y, clamp(0.95 - 0.95 * t))


def build_head(bm):
    def fn(u):
        cheek = 1.0 + 0.22 * max(0.0, -u.z + 0.1) * (1 - max(0.0, -u.z))
        zr = 0.39 if u.z > 0 else 0.37
        return Vector((0.485 * u.x * cheek, HC.y + 0.44 * u.y * (1 + 0.4 * (cheek - 1)), HC.z + zr * u.z))
    ellipsoid(bm, fn, 24, 14)


def build_muzzle(bm, animal):
    if animal == "Bear":
        ball(bm, Vector((0, -0.395, 0.85)), 0.17, 0.135, 0.12, 14, 8)
    elif animal == "Dog":
        ellipsoid(bm, lambda u: Vector((0.19 * u.x * (1 - 0.12 * max(0, -u.y)), -0.41 + 0.19 * u.y,
                                         0.845 + 0.125 * u.z * (1 - 0.1 * max(0, -u.y)))), 14, 8)
    elif animal == "Cat":
        for sx in (-1, 1):
            ball(bm, Vector((sx * 0.07, -0.415, 0.855)), 0.095, 0.08, 0.072, 12, 7)
    else:
        for sx in (-1, 1):
            ball(bm, Vector((sx * 0.06, -0.42, 0.86)), 0.082, 0.072, 0.066, 12, 7)


FACE = {  # nose z, nose radii, mouth z
    "Bear": (0.905, (0.05, 0.03, 0.036), 0.80),
    "Dog": (0.905, (0.058, 0.036, 0.042), 0.785),
    "Cat": (0.895, (0.032, 0.02, 0.024), 0.815),
    "Bunny": (0.895, (0.03, 0.02, 0.022), 0.82),
}
EYES = {"": (0.215, 1.03, 0.075, 0.105), "Round": (0.215, 1.03, 0.086, 0.086), "SmallWide": (0.25, 1.025, 0.06, 0.082)}


def build_eye(head_bvh, sx, spec):
    ex, ez, rx, rz = spec
    bm = new_bm()
    c, nrm = ray(head_bvh, sx * ex, ez)
    rgt = (X - nrm * X.dot(nrm)).normalized()
    upv = nrm.cross(rgt)
    if upv.z < 0:
        upv = -upv
    N = 14
    cv = bm.verts.new(c + nrm * 0.03)
    set_uv(bm, cv, 0.5, 0.5)
    rings = []
    for frac, lift in ((0.62, 0.024), (1.0, 0.006)):
        ring = []
        for k in range(N):
            a = 2 * math.pi * k / N
            p = c + rgt * (math.cos(a) * rx * frac) + upv * (math.sin(a) * rz * frac)
            hit, _, _, _ = head_bvh.ray_cast(p + nrm * 0.6, -nrm)
            v = bm.verts.new((hit if hit is not None else p) + nrm * lift)
            set_uv(bm, v, 0.5 + 0.43 * frac * math.cos(a), 0.5 + 0.43 * frac * math.sin(a))
            ring.append(v)
        rings.append(ring)
    for k in range(N):
        k2 = (k + 1) % N
        bm.faces.new((cv, rings[0][k], rings[0][k2]))
        bm.faces.new((rings[0][k], rings[1][k], rings[1][k2], rings[0][k2]))
    return bm


def puffy(bm, outline, depth, ax, ay, fn_, mid=0.58, centre=1.0):
    """Faceted two-sided charm from a 2D outline (list of (x, y)) around the origin."""
    n = len(outline)
    rim = []
    for x, y in outline:
        v = bm.verts.new(CHARM + ax * x + ay * y)
        set_uv(bm, v, clamp(0.5 + x / 0.3), clamp(0.5 + y / 0.3))
        rim.append(v)
    for sgn in (1, -1):
        cv = bm.verts.new(CHARM + fn_ * (sgn * depth * centre))
        set_uv(bm, cv, 0.5, 0.5)
        ring = []
        for x, y in outline:
            v = bm.verts.new(CHARM + ax * (x * mid) + ay * (y * mid) + fn_ * (sgn * depth * 0.85))
            set_uv(bm, v, clamp(0.5 + x * mid / 0.3), clamp(0.5 + y * mid / 0.3))
            ring.append(v)
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((cv, ring[k], ring[k2]))
            bm.faces.new((ring[k], rim[k], rim[k2], ring[k2]))


def build_animal(animal, cfg):
    PFX = BASE + animal
    col = bpy.data.collections.new("EggDrop_" + PFX)
    bpy.context.scene.collection.children.link(col)
    low = animal.lower()
    M = dict(SHARED)
    M["body"] = tinted(low + "_body", cfg["body"])
    M["sec"] = tinted(low + "_secondary", cfg["sec"])
    M["nose"] = SHARED[cfg["nose"]]

    A = {
        "Body": Vector((0, -0.05, 0.455)), "Head": Vector((0, -0.02, 0.70)),
        "HandL": Vector((-0.225, -0.06, 0.655)), "HandR": Vector((0.225, -0.06, 0.655)),
        "FootL": Vector((-0.165, -0.08, 0.10)), "FootR": Vector((0.165, -0.08, 0.10)),
        "WingL": Vector((-0.11, 0.17, 0.54)), "WingR": Vector((0.11, 0.17, 0.54)),
        "Tail": Vector((0, 0.24, 0.33)), "CharmAnchor": CHARM.copy(),
        # charm position roll: Right = default side spot, Left = its mirror, Center = rare pin nestled on the crown
        "CharmRight": CHARM.copy(), "CharmLeft": Vector((-CHARM.x, CHARM.y, CHARM.z)), "CharmCenter": Vector((0, -0.16, 1.40)),
    }
    ear_root = {"Bear": (0.33, 0.0, 1.27), "Dog": (0.32, 0.02, 1.27), "Cat": (0.27, 0.0, 1.27), "Bunny": (0.17, 0.02, 1.33)}[animal]
    A["EarL"] = Vector((-ear_root[0], ear_root[1], ear_root[2]))
    A["EarR"] = Vector(ear_root)
    P = []  # (role, channel, anchor, bm_or_mesh, matkey, uvfn, extra, smooth)

    def piece(role, channel, anchor, data, matkey, uvfn=None, smooth=True, name=None, **extra):
        P.append((name or role, role, channel, anchor, data, matkey, uvfn, extra, smooth))

    # ----- shared base -----
    bm = new_bm()
    ellipsoid(bm, lambda u: Vector((0.295 * u.x * (1 - 0.15 * u.z), -0.085 + 0.325 * u.y * (1 - 0.15 * u.z), 0.455 + 0.29 * u.z)), 20, 12)
    body_bvh = BVHTree.FromBMesh(bm)
    piece("Body", "Body", "Body", bm, "body",
          lambda co, t: (0.5 + co.x * 0.5, clamp(0.12 + 2.2 * max(0.0, (co - BELLY).length - 0.10))))

    bm = new_bm()
    build_head(bm)
    head_bvh = BVHTree.FromBMesh(bm)
    piece("Head", "Head", "Head", bm, "body", UV_BASE)
    tmp = bmesh.new()
    build_head(tmp)
    build_muzzle(tmp, animal)
    face_bvh = BVHTree.FromBMesh(tmp)
    tmp.free()
    mouth_bvh = face_bvh
    if animal in ("Cat", "Bunny"):      # bridge the cleft between the two pads so the mouth sits on a clean surface
        tmp = bmesh.new()
        build_head(tmp)
        ball(tmp, Vector((0, -0.415, 0.855)), 0.14, 0.085, 0.07, 14, 8)
        mouth_bvh = BVHTree.FromBMesh(tmp)
        tmp.free()

    for side, sx in (("L", -1), ("R", 1)):
        bm = new_bm()
        blob_path(bm, Vector((sx * 0.21, -0.06, 0.675)), Vector((sx * 0.37, -0.08, 0.58)), Vector((sx * 0.405, -0.16, 0.37)),
                  9, lambda t: 0.072 + 0.04 * t, lambda t: 0.066 + 0.036 * t, Y, 10)
        piece("Hand" + side, "Hand" + side, "Hand" + side, bm, "body", UV_TIP)
        bm = new_bm()
        c0 = Vector((sx * 0.165, -0.08, 0.0))

        def foot_fn(u, c0=c0):
            hi = 0.125 * (1.0 - 0.35 * max(0.0, -u.y))
            z = max(0.0, 0.09 + (hi if u.z > 0 else 0.09) * u.z)
            if u.z < -0.35:
                z = 0.0
            return c0 + Vector((0.152 * u.x, 0.265 * u.y, z))
        ellipsoid(bm, foot_fn, 16, 8)
        piece("Foot" + side, "Foot" + side, "Foot" + side, bm, "body", lambda co, t: (0.5 + co.x, clamp((co.y + 0.345) / 0.5)))
        # wings: exact copies of the v2 wing meshes
        wm = bpy.data.objects["NewPet1Mix__Wing" + side].data.copy()
        wm.materials[0] = M["wing"]
        piece("Wing" + side, "Body", "Wing" + side, wm, "wing", smooth=False)

    # ----- ears -----
    for side, sx in (("L", -1), ("R", 1)):
        an = "Ear" + side
        if animal == "Bear":
            bm = new_bm()
            ball(bm, Vector((sx * 0.345, 0.0, 1.33)), 0.155, 0.075, 0.15, 14, 8)
            piece(an, "Head", an, bm, "body", UV_BASE)
            bm = new_bm()
            ball(bm, Vector((sx * 0.345, -0.05, 1.335)), 0.09, 0.035, 0.088, 12, 6)
            piece("EarInner" + side, "Head", an, bm, "sec", UV_LIGHT)
        elif animal == "Dog":
            bm = new_bm()
            blob_path(bm, Vector((sx * 0.30, 0.02, 1.25)), Vector((sx * 0.66, 0.03, 1.34)), Vector((sx * 0.62, 0.0, 0.80)),
                      12, lambda t: 0.08 + 0.085 * t, lambda t: 0.055 + 0.012 * t, Y, 10)
            piece(an, "Head", an, bm, "sec", UV_BASE)
        elif animal == "Cat":
            bm = new_bm()
            p0, p2 = Vector((sx * 0.245, 0.0, 1.22)), Vector((sx * 0.40, 0.0, 1.60))
            ts = [0, 0.2, 0.45, 0.7, 0.88, 1.0]
            w = [0.17, 0.165, 0.13, 0.085, 0.045, 0.02]
            th = [0.10, 0.095, 0.075, 0.05, 0.032, 0.016]
            sweep(bm, [p0.lerp(p2, t) for t in ts], list(zip(w, th)), X, 12, ts)
            piece(an, "Head", an, bm, "body", UV_BASE)
            bm = new_bm()
            q0, q2 = Vector((sx * 0.275, -0.06, 1.27)), Vector((sx * 0.385, -0.03, 1.535))
            sweep(bm, [q0.lerp(q2, t) for t in ts], [(a * 0.55, 0.022) for a in w], X, 8, ts)
            piece("EarInner" + side, "Head", an, bm, "sec", UV_LIGHT)
        else:
            bm = new_bm()
            blob_path(bm, Vector((sx * 0.16, 0.02, 1.28)), Vector((sx * 0.22, 0.05, 1.66)), Vector((sx * 0.34, 0.02, 1.98)),
                      12, lambda t: 0.085 + 0.03 * math.sin(math.pi * t), lambda t: 0.05, X, 10)
            piece(an, "Head", an, bm, "body", UV_BASE)
            bm = new_bm()
            blob_path(bm, Vector((sx * 0.185, -0.035, 1.42)), Vector((sx * 0.235, -0.01, 1.68)), Vector((sx * 0.325, -0.03, 1.92)),
                      9, lambda t: 0.05 + 0.02 * math.sin(math.pi * t), lambda t: 0.022, X, 8)
            piece("EarInner" + side, "Head", an, bm, "sec", UV_LIGHT)

    # ----- muzzle, nose, optional details -----
    bm = new_bm()
    build_muzzle(bm, animal)
    piece("Muzzle", "Head", "Head", bm, "sec", UV_LIGHT)
    nz, nr, mz = FACE[animal]
    nloc, nnor = ray(face_bvh, 0.0, nz)
    bm = new_bm()
    ball(bm, nloc + nnor * 0.004, nr[0], nr[1], nr[2], 10, 6)
    piece("Nose", "Head", "Head", bm, "nose", UV_LIGHT)
    if animal == "Cat":
        for side, sx in (("L", -1), ("R", 1)):
            bm = new_bm()
            pts = [Vector((sx * 0.43, -0.10, 0.90)), Vector((sx * 0.51, -0.115, 0.86)), Vector((sx * 0.565, -0.12, 0.825))]
            sweep(bm, pts, [(0.095, 0.065), (0.07, 0.05), (0.03, 0.024)], Y, 8)
            piece("CheekTuft" + side, "Head", "Head", bm, "body", UV_BASE, optional=True)

    # ----- eyes (his texture) + hidden variants -----
    for vname, spec in EYES.items():
        for side, sx in (("L", -1), ("R", 1)):
            bm = build_eye(head_bvh, sx, spec)
            if vname:
                piece("Eye" + side, "Head", "Head", bm, "face", name=f"Eye{side}_Alt{vname}", alternate=True, variant=vname)
            else:
                piece("Eye" + side, "Head", "Head", bm, "face")

    # ----- mouth: his alpha "v" patch + hidden "w" -----
    bm = new_bm()
    MW = 0.062
    grid = []
    for j in range(3):
        row = []
        for i in range(3):
            loc, nor = ray(mouth_bvh, (i - 1) * MW, mz + (1 - j) * MW)
            v = bm.verts.new(loc + nor * 0.01)
            set_uv(bm, v, 0.25 + 0.25 * i, 0.03 + 0.25 * j)   # his orientation: top of patch = V 0
            row.append(v)
        grid.append(row)
    for j in range(2):
        for i in range(2):
            bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
    piece("Mouth", "Head", "Head", bm, "mouth")
    bm = new_bm()
    n = 13
    pts, rad = [], []
    for i in range(n):
        s = i / (n - 1)
        loc, nor = ray(mouth_bvh, (s - 0.5) * 0.12, mz + 0.012 - 0.024 * abs(math.sin(2 * math.pi * s)) ** 0.8)
        pts.append(loc + nor * 0.007)
        c = 0.4 + 0.6 * math.sin(math.pi * s) ** 0.5
        rad.append((0.0115 * c, 0.0115 * c))
    sweep(bm, pts, rad, Y, 6)
    piece("Mouth", "Head", "Head", bm, "nose", UV_LIGHT, name="Mouth_AltW", alternate=True, variant="W")

    # ----- tail -----
    bm = new_bm()
    if animal == "Bear":
        ball(bm, Vector((0, 0.305, 0.37)), 0.09, 0.085, 0.085, 12, 8)
        piece("Tail", "Body", "Tail", bm, "body", UV_BASE)
    elif animal == "Bunny":
        ball(bm, Vector((0, 0.32, 0.39)), 0.115, 0.105, 0.11, 12, 8)
        piece("Tail", "Body", "Tail", bm, "sec", UV_LIGHT)
    elif animal == "Dog":
        blob_path(bm, Vector((0, 0.18, 0.35)), Vector((0, 0.44, 0.40)), Vector((0, 0.50, 0.70)),
                  10, lambda t: 0.068 - 0.03 * t, lambda t: 0.068 - 0.03 * t, X, 8)
        piece("Tail", "Body", "Tail", bm, "body", UV_TIP)
    else:
        blob_path(bm, Vector((0, 0.18, 0.33)), Vector((0, 0.72, 0.22)), Vector((0, 0.60, 0.92)),
                  14, lambda t: 0.05, lambda t: 0.05, X, 8)
        piece("Tail", "Body", "Tail", bm, "body", UV_TIP)

    # ----- charms: v2 flower (default) + hidden ideas, all side-offset on CharmAnchor -----
    fm = bpy.data.objects["NewPet1Mix__CharmDot"].data.copy()
    fm.materials[0] = M["charm"]
    piece("CharmDot", "CharmAnchor", "CharmAnchor", fm, "charm", smooth=False, optional=True, variant="Flower")
    fn_ = Vector((0.22, -0.92, 0.30)).normalized()
    ax = fn_.cross(Z).normalized()
    ay = ax.cross(fn_).normalized()
    star = [(math.cos(math.radians(90 + 36 * k)) * (0.125 if k % 2 == 0 else 0.058),
             math.sin(math.radians(90 + 36 * k)) * (0.125 if k % 2 == 0 else 0.058)) for k in range(10)]
    heart = []
    for k in range(16):
        tt = 2 * math.pi * k / 16
        heart.append((16 * math.sin(tt) ** 3 / 17 * 0.115,
                      (13 * math.cos(tt) - 5 * math.cos(2 * tt) - 2 * math.cos(3 * tt) - math.cos(4 * tt) + 2.5) / 17 * 0.115))
    button = [(math.cos(2 * math.pi * k / 12) * 0.11, math.sin(2 * math.pi * k / 12) * 0.11) for k in range(12)]
    for vname, outline, depth, mid, centre in (("Star", star, 0.045, 0.5, 1.0), ("Heart", heart, 0.05, 0.6, 1.0),
                                               ("Button", button, 0.035, 0.74, 0.45)):
        bm = new_bm()
        puffy(bm, outline, depth, ax, ay, fn_, mid, centre)
        piece("CharmDot", "CharmAnchor", "CharmAnchor", bm, "charm", smooth=False, name="CharmDot_Alt" + vname,
              optional=True, alternate=True, variant=vname)

    # ----- derived anchors -----
    eloc, _ = ray(head_bvh, 0.0, EYES[""][1])
    A["EyeLine"] = Vector((0, round(eloc.y, 3), EYES[""][1]))
    bloc, _ = ray(body_bvh, 0.0, 0.45)
    A["HandCatch"] = Vector((0, round(bloc.y - 0.06, 3), 0.45))

    # ----- objects -----
    root = bpy.data.objects.new(PFX, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.12
    root.location = (cfg["x"], 0, 0)
    root["animal"] = animal
    col.objects.link(root)
    anchors = {}
    for name in ["Body", "Head", "EyeLine", "HandCatch", "HandL", "HandR", "FootL", "FootR", "WingL", "WingR", "Tail",
                 "CharmAnchor", "CharmLeft", "CharmRight", "CharmCenter", "EarL", "EarR"]:
        e = bpy.data.objects.new(f"{PFX}__Anchor_{name}", None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.045
        e.parent = root
        e.location = A[name]
        col.objects.link(e)
        anchors[name] = e

    tot = alt = 0
    rows = []
    for name, role, channel, anchor, data, matkey, uvfn, extra, smooth in P:
        if isinstance(data, bpy.types.Mesh):
            me = data
            me.name = f"{PFX}__{name}"
        else:
            bm = data
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            if role in ("EyeL", "EyeR") or name == "Mouth":
                if sum(f.normal.y for f in bm.faces) > 0:
                    bmesh.ops.reverse_faces(bm, faces=bm.faces)
            lt, lu, lv = (bm.verts.layers.float[k] for k in ("t", "uu", "vv"))
            uvl = bm.loops.layers.uv.new("UVMap")
            for f in bm.faces:
                for l in f.loops:
                    l[uvl].uv = uvfn(l.vert.co, l.vert[lt]) if uvfn else (l.vert[lu], l.vert[lv])
            for lay in (lt, lu, lv):
                bm.verts.layers.float.remove(lay)
            off = A[anchor]
            for v in bm.verts:
                v.co -= off
            me = bpy.data.meshes.new(f"{PFX}__{name}")
            bm.to_mesh(me)
            bm.free()
            for p in me.polygons:
                p.use_smooth = smooth
            me.materials.append(M[matkey])
        ob = bpy.data.objects.new(f"{PFX}__{name}", me)
        ob.parent = anchors[anchor]
        ob["role"] = role
        ob["channel"] = channel
        for k, v in extra.items():
            ob[k] = v
        col.objects.link(ob)
        if extra.get("alternate"):
            ALT_OBJS.append(ob.name)
        me.calc_loop_triangles()
        nt = len(me.loop_triangles)
        if extra.get("alternate"):
            alt += nt
        else:
            tot += nt
        rows.append((name, channel, anchor, me.materials[0].name, nt, "alt" if extra.get("alternate") else ""))
    print("==", animal, "default tris", tot, "| hidden alternates", alt)
    for r in rows:
        print("  ", *r)
    for k, v in A.items():
        print("   ANCHOR", k, tuple(round(c, 3) for c in v))


ALT_OBJS = []
for animal, cfg in ANIMALS.items():
    build_animal(animal, cfg)
bpy.context.view_layer.update()          # evaluate world matrices before hiding the alternates
for name in ALT_OBJS:
    ob = bpy.data.objects[name]
    ob.hide_viewport = True
    ob.hide_render = True
