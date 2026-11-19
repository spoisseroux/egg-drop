"""Production Bunny (2026-11-19, Fable as Astra). Built to the Bear's piece and anchor structure.

Run headless from the repo root. It opens the Bear v2 candidate, edits it in memory and saves a NEW file;
no Bear file is ever written:
  blender -b assets/art-source/pets/pet-bear-v2-cute.blend --python assets/art-source/pets/build_bunny.py

Writes, next to this file:
  pet-bunny.blend                     the Bunny, with every Bear anchor and the Bear's wearables for fit checks
  bunny-rig-proposal.lua              rig data in BearRigDefinition's shape (a proposal; not wired into src/)
  bunny-export/bunny.fbx              one mesh per piece, named Bunny__<Role>, same FBX settings as bear.fbx
  bunny-export/bunny-export-manifest.json, bunny-export/bunny-textures/*.png
and artifacts/v2-bunny-production/bunny-report.json (triangles, cute-rule measures, wearable fit).

Original geometry only, built or edited by this script. No generated or imported models, no AI images.

Shared with the Bear (unchanged meshes): Body, HandL, HandR, FootL, FootR.
The Bunny's own: Head (re-meshed rounder, through the Bear v2 head's vertices, so hats keep their fit), EarL, EarR,
EarInnerL, EarInnerR (long round paddles; the right one flops), Muzzle (a low snout pad), Nose (pink),
Mouth (a "w" texture), EyeL, EyeR (sparkle eye, 41% up the head), BlushL, BlushR, Tail (a cotton ball, secondary).
Blender pet-local axes: front -Y, up +Z, L = -X, paws at z = 0, 1 unit = 1 stud at garden size.
"""
import bpy, bmesh, math, os, json, re
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_BLEND = os.path.join(HERE, "pet-bunny.blend")
EXPORT = os.path.join(HERE, "bunny-export"); TEX = os.path.join(EXPORT, "bunny-textures")
REPORT_DIR = os.path.join(REPO, "artifacts", "v2-bunny-production")
for d in (EXPORT, TEX, REPORT_DIR): os.makedirs(d, exist_ok=True)
assert os.path.basename(bpy.data.filepath) == "pet-bear-v2-cute.blend", "open pet-bear-v2-cute.blend"
D = bpy.data.objects

# ---------- tunables (CUTE-DESIGN-RULES.md; the approved blockout's numbers) ----------
HEAD_SEG, HEAD_RINGS = 24, 12                      # 15 degree corners round the head (rule S1 wants under 25)
EYE_X, EYE_Z, EYE_W, EYE_H = .232, .945, .158, .200  # eye line 41% up the head, centres 47% of head width apart
BLUSH_X, BLUSH_Z, BLUSH_RX, BLUSH_RZ = .335, .845, .087, .051
PAD_Z, PAD_RX, PAD_RZ, PAD_OUT = .842, .105, .068, .028   # snout pad: a fifth of the head wide, sticks out under 0.05
NOSE_Z, NOSE_R = .872, (.030, .018, .021)
MOUTH_TOP, MOUTH_HALF_W, MOUTH_DIP, MOUTH_INK_R = NOSE_Z - .026, .038, .020, .0045
MOUTH_MX, MOUTH_Z0, MOUTH_Z1 = .05, .806, .856      # the mouth patch (a 32 x 16 px texture)
EAR_L, EAR_W, EAR_T, EAR_TILT, EAR_SEG = .62, .15, .062, 13, 12
EAR_BASE = (.25, .03, 1.24)                         # the ear joint, inside the skull: EarL/EarR anchors sit here
EAR_HAT_TILT = 27                                   # extra tip-out when a hat is on (13 -> 40 degrees)
EAR_ROWS = (0, .13, .26, .36, .43, .49, .55)
HELIX_T, LOBE_T = .36, .20                          # piercing anchors, as a share of the ear's length
TAIL_C, TAIL_R = (0, .30, .34), (.135, .125, .13)   # 50% bigger than the Bear's tail
PRIMARY, SECONDARY, EYE_HEX, NOSE_HEX, BLUSH_HEX, INK_HEX = "#FFFFFF", "#A8A5AE", "#2B1A20", "#F58CA5", "#FFB0BC", "#5A2F33"
ROUGH = .5

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)
def srgb(h): h = h.lstrip("#"); return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]

# ---------- the file becomes the Bunny: same structure, new prefix ----------
root = D["PetBear"]; ROOT_HOME = root.location.copy(); root.location = (0, 0, 0)
for o in D:
    if o.name.startswith("PetBear"): o.name = "PetBunny" + o.name[7:]
for c in bpy.data.collections: c.name = c.name.replace("PetBear", "PetBunny")
for m in bpy.data.materials:
    if m.name in ("petBear__body", "petBear__secondary"): m.name = m.name.replace("petBear", "petBunny")
bpy.context.view_layer.update()
P = "PetBunny__"
obj = lambda n: D[P + n]
anchor = lambda n: D[P + "Anchor_" + n]
COLL = bpy.data.collections["EggDrop_PetBunny"]
M_BODY, M_SEC = bpy.data.materials["petBunny__body"], bpy.data.materials["petBunny__secondary"]

def world(o):
    """Explicit parent chain, so hidden objects (never evaluated) are right too."""
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()
def wverts(o): mw = world(o); return [mw @ v.co for v in o.data.vertices]
def world_bvh(o): return BVHTree.FromPolygons(wverts(o), [tuple(p.vertices) for p in o.data.polygons])
def signed(bvhs, p):
    """Signed distance to the union of surfaces: negative = inside."""
    best = 1e9
    for b in bvhs:
        loc, nrm, _, dist = b.find_nearest(p)
        best = min(best, dist if (p - loc).dot(nrm) >= 0 or (b in OPEN and dist > .06) else -dist)
    return best
OPEN = []                                          # open patches (the snout pad): only points just behind them count as inside
def front_hit(bvhs, x, z):
    """First surface met looking at the face from the front (camera at -Y)."""
    best = None
    for b in bvhs:
        loc, nrm, _, _ = b.ray_cast(Vector((x, -5, z)), Vector((0, 1, 0)))
        if loc is not None and (best is None or loc.y < best[0].y): best = (loc, nrm)
    return best
def apos(n): return world(anchor(n)).translation.copy()

# ---------- record the Bear v2 fit before anything moves ----------
SURFACES = ("Head", "Body", "EarL", "EarR", "HandL", "HandR", "FootL", "FootR", "Muzzle", "Tail")
WEAR = [o for c in ("PetBunny_Wearables", "PetBunny_FeatureHorns", "PetBunny_FeatureWings") for o in bpy.data.collections[c].objects if o.type == "MESH"]
def slot_of(o): return o.get("slot") or {"horns": "Horns", "wings": "Back"}.get(o.get("feature"), "")
def surfaces_for(o):
    s = slot_of(o)
    if s in ("EarPiercing", "Earring"): return ("EarL", "EarR")
    if s in ("Mouth", "Nose"): return ("Head", "Muzzle")
    if s == "Tail": return ("Body",)
    return ("Head", "Body", "HandL", "HandR", "FootL", "FootR", "Muzzle", "Tail")
def fit_now(open_pad=False):
    bv = {n: world_bvh(obj(n)) for n in SURFACES}
    if open_pad: OPEN.append(bv["Muzzle"])
    return {o.name: [signed([bv[n] for n in surfaces_for(o)], p) for p in wverts(o)] for o in WEAR}
old_fit = fit_now()
old_head, old_muzzle = world_bvh(obj("Head")), world_bvh(obj("Muzzle"))
old_head_verts = wverts(obj("Head"))
old_anchor = {a.name[len(P) + 7:]: world(a).translation.copy() for a in D if a.name.startswith(P + "Anchor_")}
old_rot = {a.name[len(P) + 7:]: a.rotation_euler.copy() for a in D if a.name.startswith(P + "Anchor_")}

# ---------- helpers ----------
def new_piece(name, bm, mat, parent, props, uv_fn=None, v=.05):
    """A mesh named PetBunny__<name>, parented to an anchor with an identity transform (bm is in pet space)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l in f.loops: l[layer].uv = uv_fn(l.vert.co) if uv_fn else (.5, v)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=world(parent).inverted())
    me = bpy.data.meshes.new(P + name); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    o = D.get(P + name)
    if o: o.data = me
    else:
        o = D.new(P + name, me); COLL.objects.link(o)
    o.parent = parent; o.matrix_parent_inverse = Matrix.Identity(4); o.matrix_basis = Matrix.Identity(4)
    for k, val in props.items(): o[k] = val
    o.hide_render = False
    return o

def oval_patch(bvhs, x0, z0, rx, rz, lift, rings, seg):
    """An oval that hugs the face like a sewn-on felt piece. lift(k) = height above the surface at radius k (0 centre, 1 rim)."""
    bm = bmesh.new()
    def vert(x, z, k):
        p, n = front_hit(bvhs, x, z); out = Vector((0, -1, 0)).lerp(n, .6).normalized()
        return bm.verts.new(p + out * lift(k))
    centre = vert(x0, z0, 0); loops = []
    for i in range(1, rings + 1):
        k = i / rings
        loops.append([vert(x0 + rx * k * math.cos(2 * math.pi * j / seg), z0 + rz * k * math.sin(2 * math.pi * j / seg), k) for j in range(seg)])
    for j in range(seg): bm.faces.new((centre, loops[0][j], loops[0][(j + 1) % seg]))
    for a, b in zip(loops, loops[1:]):
        for j in range(seg): bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
    return bm

def ball(seg, rings, vert_fn):
    """A closed seg x rings ball; vert_fn(unit direction) -> position. Poles on local Z."""
    bm = bmesh.new()
    top = bm.verts.new(vert_fn(Vector((0, 0, 1)))); bot = bm.verts.new(vert_fn(Vector((0, 0, -1)))); loops = []
    for i in range(1, rings):
        phi = math.pi * i / rings
        loops.append([bm.verts.new(vert_fn(Vector((math.sin(phi) * math.cos(2 * math.pi * j / seg), math.sin(phi) * math.sin(2 * math.pi * j / seg), math.cos(phi))))) for j in range(seg)])
    for j in range(seg):
        bm.faces.new((top, loops[0][j], loops[0][(j + 1) % seg])); bm.faces.new((bot, loops[-1][(j + 1) % seg], loops[-1][j]))
    for a, b in zip(loops, loops[1:]):
        for j in range(seg): bm.faces.new((a[j], b[j], b[(j + 1) % seg], a[(j + 1) % seg]))
    return bm

def image(name, px, filename):
    """px: float array (h, w, 4), sRGB values 0..1, row 0 at the bottom (Blender's order)."""
    h, w, _ = px.shape
    im = bpy.data.images.new(name, w, h, alpha=True)
    im.pixels.foreach_set(px.astype(np.float32).ravel()); im.filepath_raw = os.path.join(TEX, filename); im.file_format = "PNG"; im.save(); im.pack()
    return im

def textured(name, img, base_hex=None, rough=.6, emit=0.0, alpha=False, closest=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = next(nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED")
    tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = img; tx.extension = "EXTEND"
    if closest: tx.interpolation = "Closest"
    if base_hex: bsdf.inputs["Base Color"].default_value = lin(base_hex)
    else: nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    if emit:
        nt.links.new(tx.outputs["Color"], bsdf.inputs["Emission Color"]); bsdf.inputs["Emission Strength"].default_value = emit
    if alpha:
        nt.links.new(tx.outputs["Alpha"], bsdf.inputs["Alpha"])
        try: m.surface_render_method = "BLENDED"
        except Exception: pass
    bsdf.inputs["Roughness"].default_value = rough
    return m

def plain(name, hexcol, rough):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(nd for nd in m.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hexcol); b.inputs["Roughness"].default_value = rough
    return m

# ---------- 1. head: the Bunny's own mesh, cast onto the Bear head's surface so every hat still fits ----------
def smooth_target(o, levels=2, passes=4):
    """A smooth surface THROUGH o's vertices: a subdivision cage is pushed out until its smoothed surface meets them again."""
    tmp = D.new("tmp_target", o.data.copy()); bpy.context.scene.collection.objects.link(tmp)
    tmp.matrix_world = world(o)
    md = tmp.modifiers.new("s", "SUBSURF"); md.levels = md.render_levels = levels
    want = [v.co.copy() for v in tmp.data.vertices]
    def smoothed():
        bpy.context.view_layer.update()
        ev = tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = ev.to_mesh()
        out = [v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons]; ev.to_mesh_clear(); return out
    for _ in range(passes):
        pts, _polys = smoothed()                                  # subdivision keeps the cage's vertices first, in order
        for v, w, got in zip(tmp.data.vertices, want, pts): v.co += w - got
        tmp.data.update()
    pts, polys = smoothed(); mw = tmp.matrix_world.copy()
    miss = max((w - got).length for w, got in zip(want, pts)); assert miss < .002, miss
    D.remove(tmp)
    return BVHTree.FromPolygons([mw @ q for q in pts], polys)
lo = Vector([min(p[i] for p in old_head_verts) for i in range(3)]); hi = Vector([max(p[i] for p in old_head_verts) for i in range(3)])
HC, HE = (lo + hi) / 2, (hi - lo) / 2
target = smooth_target(obj("Head"))
def head_vert(grow):
    def f(d):
        d = Vector((HE.x * d.x, HE.y * d.y, HE.z * d.z)).normalized()
        loc, _, _, _ = target.ray_cast(HC, d)
        return HC + (loc - HC) * grow
    return f
HEAD_GROW = 1.0
new_piece("Head", ball(HEAD_SEG, HEAD_RINGS, head_vert(HEAD_GROW)), M_BODY, anchor("Head"), {"role": "Head", "channel": "Head"}, v=.9)
head = world_bvh(obj("Head"))

# ---------- 2. eyes: one dark shape, two catchlights, no white ring ----------
S = 4; n_px = 128 * S
yy, xx = np.mgrid[0:n_px, 0:n_px]; u = (xx + .5) / n_px - .5; v = (yy + .5) / n_px - .5
tex = np.zeros((n_px, n_px, 4)); tex[..., :3] = srgb(EYE_HEX); tex[..., 3] = 1
for cu, cv, r in ((-.14, .19, .19), (.15, -.21, .085)):               # big upper-left, small lower-right; same side on both eyes
    tex[((u - cu) / r) ** 2 + ((v - cv) / (r * 1.08 * EYE_W / EYE_H)) ** 2 <= 1, :3] = 1
M_EYE = textured("petBunny__eye", image("petBunnyEyeTex", tex.reshape(128, S, 128, S, 4).mean(axis=(1, 3)), "bunny-eye.png"), rough=.6, emit=.35)
for sx, tag in ((-1, "L"), (1, "R")):
    x0 = sx * EYE_X
    bm = oval_patch([head], x0, EYE_Z, EYE_W / 2, EYE_H / 2, lambda k: .006 + .018 * (1 - k * k), 2, 24)
    new_piece("Eye" + tag, bm, M_EYE, anchor("Head"), {"role": "Eye" + tag, "channel": "Head"}, lambda co, x0=x0: (.5 + (co.x - x0) / EYE_W, .5 + (co.z - EYE_Z) / EYE_H))

# ---------- 3. blush ----------
n_px = 64 * S; yy, xx = np.mgrid[0:n_px, 0:n_px]; r = np.hypot((xx + .5) / n_px - .5, (yy + .5) / n_px - .5) * 2
t = np.clip((1 - r) / .45, 0, 1); a = t * t * (3 - 2 * t)
tex = np.zeros((n_px, n_px, 4)); tex[..., :3] = srgb(BLUSH_HEX); tex[..., 3] = a * .95
M_BLUSH = textured("petBunny__blush", image("petBunnyBlushTex", tex.reshape(64, S, 64, S, 4).mean(axis=(1, 3)), "bunny-blush.png"), BLUSH_HEX, .8, alpha=True)
for sx, tag in ((-1, "L"), (1, "R")):
    x0 = sx * BLUSH_X
    bm = oval_patch([head], x0, BLUSH_Z, BLUSH_RX, BLUSH_RZ, lambda k: .004, 2, 12)
    new_piece("Blush" + tag, bm, M_BLUSH, anchor("Head"), {"role": "Blush" + tag, "channel": "Head"},
              lambda co, x0=x0: (.5 + (co.x - x0) / (2 * BLUSH_RX), .5 + (co.z - BLUSH_Z) / (2 * BLUSH_RZ)))

# ---------- 4. snout pad (piece name Muzzle, like the Bear), pink nose, "w" mouth ----------
bm = oval_patch([head], 0, PAD_Z, PAD_RX, PAD_RZ, lambda k: -.004 + (PAD_OUT + .004) * (1 - k * k) ** .6, 4, 16)
new_piece("Muzzle", bm, M_SEC, anchor("Head"), {"role": "Muzzle", "channel": "Head"}, v=.05)
pad = world_bvh(obj("Muzzle")); face = [head, pad]

M_NOSE = plain("petBunny__nose", NOSE_HEX, .4)
p, n = front_hit([pad], 0, NOSE_Z)
bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=4, radius=1)
bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))   # poles front and back: a round outline
for vv in bm.verts:
    if vv.co.z < 0: vv.co.z *= .8                                   # a rounded bean: a touch flatter underneath
bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(p + Vector((0, .005, 0))) @ Matrix.Diagonal((NOSE_R[0], NOSE_R[1], NOSE_R[2], 1)))
new_piece("Nose", bm, M_NOSE, anchor("Head"), {"role": "Nose", "channel": "Head"})

MW, MH = 32, 16
curve = [(tt * MOUTH_HALF_W, MOUTH_TOP - MOUTH_DIP * math.sin(math.pi * abs(tt))) for tt in np.linspace(-1, 1, 241)]
tex = np.zeros((MH, MW, 4)); tex[..., :3] = srgb(INK_HEX)             # transparent pixels keep the ink colour: no light fringe
for py in range(MH):
    for px in range(MW):
        x = -MOUTH_MX + (px + .5) / MW * 2 * MOUTH_MX; z = MOUTH_Z0 + (py + .5) / MH * (MOUTH_Z1 - MOUTH_Z0)
        tex[py, px, 3] = 1.0 if min(math.hypot(x - cx, z - cz) for cx, cz in curve) <= MOUTH_INK_R else 0.0
M_MOUTH = textured("petBunny__mouth", image("petBunnyMouthTex", tex, "bunny-mouth.png"), INK_HEX, .5, alpha=True, closest=True)
bm = bmesh.new(); NX, NZ = 4, 2; grid = []
for i in range(NZ + 1):
    row = []
    for j in range(NX + 1):
        x = -MOUTH_MX + 2 * MOUTH_MX * j / NX; z = MOUTH_Z1 - (MOUTH_Z1 - MOUTH_Z0) * i / NZ
        q, nn = front_hit(face, x, z); row.append(bm.verts.new(q + Vector((0, -1, 0)).lerp(nn, .6).normalized() * .006))
    grid.append(row)
for i in range(NZ):
    for j in range(NX): bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
new_piece("Mouth", bm, M_MOUTH, anchor("Head"), {"role": "Mouth", "channel": "Head", "variant": "W"},
          lambda co: ((co.x + MOUTH_MX) / (2 * MOUTH_MX), (co.z - MOUTH_Z0) / (MOUTH_Z1 - MOUTH_Z0)))

# ---------- 5. ears: long round paddles on the EarL/EarR swap anchors; the right one flops ----------
DT = 1 / 80
def ear_spine(sx, flop):
    tilt = math.radians(EAR_TILT)
    side = Vector((math.cos(tilt), 0, -sx * math.sin(tilt)))                 # across the ear
    up = Vector((sx * math.sin(tilt), .10, math.cos(tilt))).normalized()     # along the ear, leaning back a touch
    front = side.cross(up).normalized()
    if front.y > 0: front = -front
    target = (Vector((sx, 0, 0)) * .9 + front * .45).normalized()            # a flopped ear droops out to the side and a little forward
    axis = up.cross(target).normalized()
    pos, dirv, sidev, frontv, tt = Vector((sx * EAR_BASE[0], EAR_BASE[1], EAR_BASE[2])), up.copy(), side.copy(), front.copy(), 0.0
    samples = [(pos.copy(), dirv.copy(), sidev.copy(), frontv.copy())]
    while tt < 1 - 1e-9:
        tt += DT
        if flop and .36 < tt < .92:
            rot = Matrix.Rotation(flop * math.radians(105) * DT / .56, 3, axis)
            dirv, sidev, frontv = (rot @ dirv).normalized(), (rot @ sidev).normalized(), (rot @ frontv).normalized()
        pos = pos + dirv * EAR_L * DT; samples.append((pos.copy(), dirv.copy(), sidev.copy(), frontv.copy()))
    return samples
def at(samples, t): return samples[min(len(samples) - 1, round(t / DT))]
def half_width(t):
    if t < .55: return EAR_W * (.56 + .44 * math.sin(math.pi / 2 * t / .55))
    return EAR_W * math.sqrt(max(0.0, 1 - ((t - .55) / .45) ** 2))               # a half-ellipse tip: its tightest radius is 0.08, no point
def thick(t): return EAR_T * half_width(t) / EAR_W

def ear_mesh(samples):
    TIP = 8; ts = list(EAR_ROWS) + [.55 + .45 * math.sin(math.pi / 2 * k / TIP) for k in range(1, TIP)]
    bm = bmesh.new(); rings = []
    for t in ts:
        c, dv, sv, fv = at(samples, t)
        rings.append([bm.verts.new(c + sv * half_width(t) * math.cos(2 * math.pi * k / EAR_SEG) + fv * thick(t) * math.sin(2 * math.pi * k / EAR_SEG)) for k in range(EAR_SEG)])
    c0, d0, _, _ = samples[0]; base = bm.verts.new(c0 - d0 * .03); tip = bm.verts.new(samples[-1][0])
    for k in range(EAR_SEG):
        bm.faces.new((base, rings[0][(k + 1) % EAR_SEG], rings[0][k])); bm.faces.new((tip, rings[-1][k], rings[-1][(k + 1) % EAR_SEG]))
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(EAR_SEG): bm.faces.new((r0[k], r0[(k + 1) % EAR_SEG], r1[(k + 1) % EAR_SEG], r1[k]))
    return bm
def inner_mesh(samples, t0, t1, rows=11, k_w=.58):
    """The grey inside: a low dome sewn onto the front of the ear, round at both ends, its rim tucked under the surface."""
    bm = bmesh.new(); lines = []
    for i in range(rows):
        s = -1 + 2 * i / (rows - 1); t = t0 + (t1 - t0) * i / (rows - 1); c, dv, sv, fv = at(samples, t)
        hw, th = half_width(t), thick(t); wi = k_w * hw * math.sqrt(max(0.0, 1 - abs(s) ** 2.6)); end = math.sqrt(max(0.0, 1 - s * s))
        def vert(a):
            x = a * wi; return bm.verts.new(c + sv * x + fv * (th * math.sqrt(max(0.0, 1 - (x / hw) ** 2)) - .003 + .013 * math.sqrt(max(0.0, 1 - a * a)) * end))
        lines.append([vert(0)] if i in (0, rows - 1) else [vert(a) for a in (-1, -.5, 0, .5, 1)])
    for a, b in zip(lines, lines[1:]):
        if len(a) == 1:
            for j in range(4): bm.faces.new((a[0], b[j], b[j + 1]))
        elif len(b) == 1:
            for j in range(4): bm.faces.new((b[0], a[j + 1], a[j]))
        else:
            for j in range(4): bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    return bm

spines = {"L": ear_spine(-1, 0.0), "R": ear_spine(1, 1.0)}
for sx, tag in ((-1, "L"), (1, "R")):
    a = anchor("Ear" + tag); a.location = Vector((sx * EAR_BASE[0], EAR_BASE[1], EAR_BASE[2]))
    a["restTiltDeg"] = EAR_TILT; a["hatTiltDeg"] = EAR_HAT_TILT; a["note"] = "Ear joint. With a hat on, turn the ear %d more degrees outward about the front-back axis." % EAR_HAT_TILT
bpy.context.view_layer.update()
for tag in "LR":
    new_piece("Ear" + tag, ear_mesh(spines[tag]), M_BODY, anchor("Ear" + tag), {"role": "Ear" + tag, "channel": "Head"}, v=.9)
    new_piece("EarInner" + tag, inner_mesh(spines[tag], .14, .90 if tag == "L" else .54), M_SEC, anchor("Ear" + tag), {"role": "EarInner" + tag, "channel": "Head"}, v=.05)

# ---------- 6. cotton tail ----------
bm = ball(16, 8, lambda d: Vector((TAIL_C[0] + TAIL_R[0] * d.x, TAIL_C[1] + TAIL_R[1] * d.z, TAIL_C[2] - TAIL_R[2] * d.y)))   # poles front and back: round from behind
new_piece("Tail", bm, M_SEC, anchor("Tail"), {"role": "Tail", "channel": "Body"}, v=.05)

# ---------- 7. anchors: all 46 kept; the species ones move with the Bunny's features ----------
def keep_depth(name, x, z, old=None, new=None):
    """Move a face anchor to (x, z), keeping its distance from the surface under it."""
    was = old_anchor[name]; off = was.y - front_hit(old or [old_head], was.x, was.z)[0].y
    anchor(name).location = Vector((x, front_hit(new or [head], x, z)[0].y + off, z))
keep_depth("EyeL", -EYE_X, EYE_Z); keep_depth("EyeR", EYE_X, EYE_Z); keep_depth("EyeLine", 0, EYE_Z)
keep_depth("FaceBridge", 0, old_anchor["FaceBridge"].z + EYE_Z - old_anchor["EyeLine"].z)
for tag in "LR": keep_depth("Cheek" + tag, old_anchor["Cheek" + tag].x, old_anchor["Cheek" + tag].z + EYE_Z - old_anchor["EyeLine"].z)
keep_depth("Mouth", 0, (MOUTH_TOP + MOUTH_TOP - MOUTH_DIP) / 2, [old_muzzle], face)
keep_depth("Nose", 0, NOSE_Z, [old_muzzle], [pad])
for sx, tag in ((-1, "L"), (1, "R")):
    for name, t in (("Helix", HELIX_T), ("Lobe", LOBE_T)):
        c, dv, sv, fv = at(spines[tag], t); out = sv * sx                      # the ear's outer rim; local +Z leaves it
        a = anchor(name + tag); a.location = c + out * half_width(t); a.rotation_euler = (0, math.atan2(out.x, out.z), 0)
bpy.context.view_layer.update()
ears = [world_bvh(obj("EarL")), world_bvh(obj("EarR"))]
charm = obj("CharmDot"); charm_home = apos("CharmAnchor"); charm_pts = wverts(charm)
def charm_gap(p): return min(ears[i].find_nearest(q + p - charm_home)[3] for q in charm_pts for i in (0, 1))
CLEAR = .05; charm_report = {}
for name, step in (("CharmFloat", Vector((0, 0, .02))), ("CharmLeft", Vector((-.02, 0, 0))), ("CharmRight", Vector((.02, 0, 0))), ("CharmCenter", Vector((0, -.01, 0)))):
    p = apos(name); before = charm_gap(p); n_steps = 0
    while charm_gap(p) < CLEAR and n_steps < 40: p += step; n_steps += 1
    anchor(name).location = p; charm_report[name] = {"gap_before": round(before, 3), "gap": round(charm_gap(p), 3), "moved": [round(c, 3) for c in (p - old_anchor[name])]}
anchor("CharmAnchor").location = apos("CharmFloat")
bpy.context.view_layer.update()

# ---------- 8. finish and identity ----------
for m in (M_BODY, M_SEC): next(nd for nd in m.node_tree.nodes if nd.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = ROUGH
for nd in bpy.data.node_groups["PetPalette"].nodes:
    if nd.type == "RGB": nd.outputs[0].default_value = lin(PRIMARY if nd.name == "Primary" else SECONDARY)
for k in list(root.keys()): del root[k]
root["animal"] = "Bunny"; root["favouriteStat"] = "Jump"; root["status"] = "production model 2026-11-19; exported, not uploaded, not wired"

# ---------- numbers ----------
def bounds(o):
    pts = wverts(o); return Vector([min(q[i] for q in pts) for i in range(3)]), Vector([max(q[i] for q in pts) for i in range(3)])
def tri(o): o.data.calc_loop_triangles(); return len(o.data.loop_triangles)
VISIBLE = ("Body", "Head", "EarL", "EarR", "EarInnerL", "EarInnerR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR", "Tail", "HandL", "HandR", "FootL", "FootR")
tris = {n: tri(obj(n)) for n in VISIBLE}; TOTAL = sum(tris.values())
assert TOTAL <= 3000, TOTAL
(hlo, hhi), (blo, bhi), (plo, phi_), (nlo, nhi) = bounds(obj("Head")), bounds(obj("Body")), bounds(obj("Muzzle")), bounds(obj("Nose"))
HW, HH = hhi.x - hlo.x, hhi.z - hlo.z
top = max(bounds(obj("EarL"))[1].z, bounds(obj("EarR"))[1].z)
new_head_verts = wverts(obj("Head"))
new_fit = fit_now(True)
fit = []
for o in WEAR:
    a, b = old_fit[o.name], new_fit[o.name]
    row = {"mesh": o.name[len(P):], "item": o.get("item") or o.get("feature") or "", "slot": slot_of(o), "anchor": o.parent.name[len(P) + 7:],
           "bear_deepest": round(min(a), 4), "bunny_deepest": round(min(b), 4), "bear_mean": round(sum(a) / len(a), 4), "bunny_mean": round(sum(b) / len(b), 4)}
    row["mean_shift"] = round(row["bunny_mean"] - row["bear_mean"], 4); row["deepest_shift"] = round(row["bunny_deepest"] - row["bear_deepest"], 4)
    row["ok"] = abs(row["mean_shift"]) <= .03 and row["deepest_shift"] >= -.03
    if slot_of(o) not in ("EarPiercing", "Earring"):
        row["into_ears"] = round(min(0.0, min(signed(ears, q) for q in wverts(o))), 4)     # how far it cuts into a resting ear (0 = clear)
    fit.append(row)
moved = {}
for a in D:
    if a.name.startswith(P + "Anchor_"):
        k = a.name[len(P) + 7:]; d = world(a).translation - old_anchor[k]
        if d.length > 1e-6 or (Vector(a.rotation_euler) - Vector(old_rot[k])).length > 1e-6:
            moved[k] = {"from": [round(c, 4) for c in old_anchor[k]], "to": [round(c, 4) for c in world(a).translation]}
pad_front = front_hit([pad], 0, PAD_Z)[0].y; head_there = front_hit([head], 0, PAD_Z)[0].y
ink_cols = [px for px in range(MW) if tex[:, px, 3].any()]
report = {
    "file": "assets/art-source/pets/pet-bunny.blend", "favouriteStat": "Jump",
    "tris": {"total": TOTAL, "budget": 3000, "by_piece": tris, "shared_with_bear": ["Body", "HandL", "HandR", "FootL", "FootR"]},
    "measures": {
        "head_width": round(HW, 3), "head_height": round(HH, 3), "body_width": round(bhi.x - blo.x, 3), "height_to_ear_tip": round(top, 3),
        "P1_head_over_height_to_crown": round(HH / hhi.z, 3), "P2_head_width_over_body_width": round(HW / (bhi.x - blo.x), 2), "P3_head_width_over_height": round(HW / HH, 2),
        "P5_ear_width_over_length": round(2 * EAR_W / EAR_L, 2),
        "E1_eye_width_over_head_width": round(EYE_W / HW, 3), "E1_eye_height_over_width": round(EYE_H / EYE_W, 2),
        "E2_eye_line_up_the_head": round((EYE_Z - hlo.z) / HH, 3), "E3_eye_centres_over_head_width": round(2 * EYE_X / HW, 3),
        "F1_highest_feature_up_the_head": round((EYE_Z + EYE_H / 2 - hlo.z) / HH, 3),
        "F2_nose_width_over_head_width": round((nhi.x - nlo.x) / HW, 3),
        "F3_mouth_glyph_width_over_head_width": round((ink_cols[-1] - ink_cols[0] + 1) / MW * 2 * MOUTH_MX / HW, 3),
        "F4_pad_width_over_head_width": round((phi_.x - plo.x) / HW, 3), "F4_pad_sticks_out": round(head_there - pad_front, 3),
        "F5_blush_width_over_head_width": round(2 * BLUSH_RX * .9 / HW, 3),
        "S1_head_outline_corner_degrees": round(360 / HEAD_SEG, 1), "S1_body_outline_corner_degrees": 22.5,
        "S2_ear_tip_radius": round(EAR_W ** 2 / (.45 * EAR_L), 3),
    },
    "head_vs_bear_v2_head": {                             "bunny_outside_bear_max": round(max(signed([old_head], q) for q in new_head_verts), 4),
                             "bear_corner_above_bunny_max": round(max(signed([head], q) for q in old_head_verts), 4)},
    "anchors": {"total": len(old_anchor), "moved_from_bear_v2": moved, "charm_clearance_to_ears": charm_report},
    "wearable_fit": {"meshes": len(fit), "ok": sum(r["ok"] for r in fit), "not_ok": [r for r in fit if not r["ok"]],
                     "cuts_into_resting_ears": [{"mesh": r["mesh"], "depth": r["into_ears"]} for r in fit if r.get("into_ears", 0) < -.01], "rows": fit},
    "palette": {"primary": PRIMARY, "secondary": SECONDARY, "eye": EYE_HEX, "nose": NOSE_HEX, "blush": BLUSH_HEX, "mouth": INK_HEX},
}
with open(os.path.join(REPORT_DIR, "bunny-report.json"), "w") as f: json.dump(report, f, indent=1)
short = dict(report); short["wearable_fit"] = {k: val for k, val in report["wearable_fit"].items() if k not in ("rows", "not_ok")}
print("REPORT", json.dumps(short))
for r_ in report["wearable_fit"]["not_ok"]: print("NOT_OK", r_)

# ---------- export: one FBX, a mesh per piece, the same settings as bear.fbx and the attachment set ----------
def r5(vec, n=5): return [round(float(x), n) + 0.0 for x in vec]
EXPORT_NAME = {"Mouth": "MouthSmile"}                              # the Bear's exported mouth piece is MouthSmile; the rig looks for that name
PIECES = VISIBLE + ("CharmDot",)
export_scene = bpy.data.scenes.new("BunnyExport"); made = []; objects = []
for name in PIECES:
    src = obj(name); me = src.data.copy(); me.transform(world(src)); me.update()
    ob = D.new("Bunny__" + EXPORT_NAME.get(name, name), me); export_scene.collection.objects.link(ob); made.append(ob)
    me.calc_loop_triangles(); lo_, hi_ = bounds(ob)
    objects.append({"name": ob.name, "source": src.name, "centerBlender": r5((lo_ + hi_) / 2), "sizeBlender": r5(hi_ - lo_), "triangles": len(me.loop_triangles),
                    "channel": "Charm" if name == "CharmDot" else src.get("channel"), "material": src.data.materials[0].name, "parentAnchor": src.parent.name[len(P) + 7:]})
bpy.context.window.scene = export_scene
for o in made: o.select_set(True)
bpy.context.view_layer.objects.active = made[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "bunny.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True,
                         use_mesh_modifiers=False, object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO", mesh_smooth_type="FACE")
bpy.context.window.scene = bpy.data.scenes[0]
for o in made:
    me = o.data; D.remove(o, do_unlink=True); bpy.data.meshes.remove(me)
bpy.data.scenes.remove(export_scene)

KIND = {n: "surface" for n in "HatCrown HornL HornR HelixL HelixR LobeL LobeR WristL WristR ClawL ClawR ToeL ToeR".split()}
KIND.update({n: "face" for n in "EyeL EyeR FaceBridge EyeLine Forehead CheekL CheekR Nose Mouth Chest Back".split()})
CHANNEL_OLD = {"Body": "Body", "Head": "Head", "EyeLine": "Head", "HandCatch": "Root", "HandL": "HandL", "HandR": "HandR", "FootL": "FootL", "FootR": "FootR", "Tail": "Body",
               "EarL": "Head", "EarR": "Head", "WingL": "Body", "WingR": "Body", "CharmFloat": "Root", "CharmLeft": "Root", "CharmRight": "Root", "CharmCenter": "Root", "CharmAnchor": "Root"}
SLOT_OLD = {"Tail": "Tail", "WingL": "Back", "WingR": "Back", "CharmFloat": "Charm", "CharmLeft": "Charm", "CharmRight": "Charm", "CharmCenter": "Charm", "CharmAnchor": "Charm", "HandL": "Sleeve", "HandR": "Sleeve"}
anchors = []
for o in sorted(D, key=lambda o: o.name):
    if o.type != "EMPTY" or not o.name.startswith(P + "Anchor_"): continue
    name = o.name[len(P) + 7:]; m = world(o); rot = m.to_3x3().normalized(); pos = m.to_translation()
    anchors.append({"name": name, "channel": o.get("channel") or CHANNEL_OLD.get(name, "Root"), "slot": o.get("slot") or SLOT_OLD.get(name), "kind": KIND.get(name, "swap"),
                    "positionBlender": r5(pos), "axesBlender": {"x": r5(rot.col[0]), "y": r5(rot.col[1]), "z": r5(rot.col[2])}})
manifest = {"asset": "bunny", "export": "bunny.fbx", "sourceBlend": "assets/art-source/pets/pet-bunny.blend", "builtBy": "assets/art-source/pets/build_bunny.py",
            "axes": "axis_forward=-Z axis_up=Y (same as bear.fbx). Blender pet-local: front -Y, up +Z, L = -X, paws at z = 0, 1 unit = 1 stud.",
            "conversions": {"blenderToRuntime": "(x, y, z) -> (x, z, -y)", "blenderToStudioTemplate": "(x, y, z) -> (-x, z, y)"},
            "textures": {"EyeL": "bunny-textures/bunny-eye.png", "EyeR": "bunny-textures/bunny-eye.png", "MouthSmile": "bunny-textures/bunny-mouth.png (cut-out; Closest filtering)",
                         "BlushL": "bunny-textures/bunny-blush.png", "BlushR": "bunny-textures/bunny-blush.png"},
            "note": "Body, HandL, HandR, FootL and FootR are the Bear v2 candidate's meshes, unchanged. Wings, horns, wearables and the other charm shapes are the Bear's assets.",
            "triangles": TOTAL, "objects": objects, "anchorsBlender": {a["name"]: a["positionBlender"] for a in anchors}, "anchors": anchors}
with open(os.path.join(EXPORT, "bunny-export-manifest.json"), "w") as f: json.dump(manifest, f, indent=1)

# ---------- rig-definition proposal, in BearRigDefinition's shape (runtime axes: front +Z, up +Y) ----------
def to_def(c): return [round(c[0], 5) + 0.0, round(c[2], 5) + 0.0, round(-c[1], 5) + 0.0]
def size_of(s): return [round(s[0], 5), round(s[2], 5), round(s[1], 5)]
def runtime_rotation(axes):
    m = lambda vec: [vec[0], vec[2], -vec[1]]
    x, y, z = m(axes["x"]), m(axes["z"]), m([-c for c in axes["y"]])
    return [round(c, 6) + 0.0 for c in (x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])]
ROLE = {"Body": ("Body", "body", "ellipsoid"), "Head": ("Head", "body", "ellipsoid"), "EarL": ("Head", "body", "ellipsoid"), "EarR": ("Head", "body", "ellipsoid"),
        "EarInnerL": ("Head", "secondary", "ellipsoid"), "EarInnerR": ("Head", "secondary", "ellipsoid"), "Muzzle": ("Head", "secondary", "ellipsoid"),
        "Nose": ("Head", "nose", "ellipsoid"), "MouthSmile": ("Head", "mouth", "smile"), "EyeL": ("Head", "face", "ellipsoid"), "EyeR": ("Head", "face", "ellipsoid"),
        "BlushL": ("Head", "blush", "ellipsoid"), "BlushR": ("Head", "blush", "ellipsoid"), "Tail": ("Body", "secondary", "ellipsoid"),
        "HandL": ("HandL", "body", "ellipsoid"), "HandR": ("HandR", "body", "ellipsoid"), "FootL": ("FootL", "body", "ellipsoid"), "FootR": ("FootR", "body", "ellipsoid"),
        "CharmDot": ("Charm", "secondary", "ellipsoid")}
pieces = []
for o in objects:
    name = o["name"].split("__", 1)[1]; channel, role, shape = ROLE[name]
    pieces.append({"name": name, "channel": channel, "shape": shape, "center": to_def(o["centerBlender"]), "size": size_of(o["sizeBlender"]), "xyzEulerDeg": [0, 0, 0], "colorRole": role})
mouth = next(p_ for p_ in pieces if p_["name"] == "MouthSmile")
pieces.append({"name": "MouthO", "channel": "Head", "shape": "ellipsoid", "center": [0.0, mouth["center"][1], round(mouth["center"][2] + mouth["size"][2] / 2 - .004, 5)],
               "size": [.05, .058, .022], "xyzEulerDeg": [0, 0, 0], "colorRole": "mouth"})
BEAR = json.loads(re.search(r"\[=\[(.*)\]=\]", open(os.path.join(REPO, "src", "shared", "BearRigDefinition.lua"), encoding="utf-8").read(), re.S).group(1))   # read only
def_anchors = {"Root": [0, 0, 0]}; frames = {}; delta = {}
for a in anchors:
    def_anchors[a["name"]] = to_def(a["positionBlender"])
    frames[a["name"]] = {"position": to_def(a["positionBlender"]), "channel": a["channel"], "kind": a["kind"], "slot": a["slot"], "rotation": runtime_rotation(a["axesBlender"])}
    live = BEAR["anchors"].get(a["name"]); live_rot = BEAR["anchorFrames"].get(a["name"], {}).get("rotation")
    if live:
        d = [round(def_anchors[a["name"]][i] - live[i], 5) + 0.0 for i in range(3)]
        turned = live_rot is not None and max(abs(x - y) for x, y in zip(live_rot, frames[a["name"]]["rotation"])) > 1e-4
        if max(abs(c) for c in d) > 1e-4 or turned: delta[a["name"]] = {"offset": d, "rotationChanged": turned}
proposal = {
    "schema": 1, "id": "bunny", "status": "PROPOSAL 2026-11-19: data only, not wired into src/", "twoTone": True, "favouriteStat": "Jump",
    "axes": {"up": "+Y", "front": "+Z", "right": "+X"}, "units": "studs at garden size", "nativeScaleFactor": BEAR["nativeScaleFactor"],
    "palette": {"body": PRIMARY, "secondary": SECONDARY, "face": EYE_HEX, "mouth": INK_HEX, "ivory": "#FFF6E9", "blush": BLUSH_HEX, "nose": NOSE_HEX},
    "fixedColorRoles": ["face", "mouth", "blush", "nose"],
    "colorRoles": {"body": "primary dye; the UV gradient blends to secondary at paw tips, toes and lower belly", "secondary": "secondary dye: ear insides, snout pad, tail, charm",
                   "nose": "fixed pink", "blush": "fixed pink decal (64 px, soft edge)", "face": "fixed eye texture (128 px)", "mouth": "fixed ink cut-out (32 x 16 px, Closest)"},
    "sharedWithBear": ["Body", "HandL", "HandR", "FootL", "FootR"],
    "triangles": {"total": TOTAL, "byPiece": {EXPORT_NAME.get(k, k): val for k, val in tris.items()}},
    "textures": {"eye": "bunny-export/bunny-textures/bunny-eye.png", "mouth": "bunny-export/bunny-textures/bunny-mouth.png", "blush": "bunny-export/bunny-textures/bunny-blush.png"},
    "anchors": def_anchors, "pieces": pieces, "anchorFrames": frames,
    "attachmentTemplate": "BearAttachments",
    "inheritFromBear": ["attachments", "attachmentTextures", "slots", "features", "exclusions", "wearableItems", "charmLift"],
    "anchorDeltaFromBear": delta,
    "earPose": {"rest": {"tiltDeg": EAR_TILT, "note": "baked into the meshes"},
                "hat": {"whenSlot": "Hat", "unlessFlag": "openCrown", "EarL": {"hinge": "EarL", "zDeg": EAR_HAT_TILT}, "EarR": {"hinge": "EarR", "zDeg": -EAR_HAT_TILT},
                        "note": "Turn each ear (and its inner ear and piercings) about its hinge anchor, round the runtime front axis (+Z), so the ears tip out to 40 degrees and clear the hat."}},
    "replaces": {"Eyes": {"L": ["EyeL"], "R": ["EyeR"]}, "Mouth": {"": ["MouthSmile"]}, "Tail": {"": ["Tail"]}},
}
def lua(val, ind=0):
    pad_ = "  " * ind
    if val is None: return "nil"
    if isinstance(val, bool): return "true" if val else "false"
    if isinstance(val, (int, float)): return repr(round(val, 6)) if isinstance(val, float) else str(val)
    if isinstance(val, str): return json.dumps(val)
    if isinstance(val, (list, tuple)):
        if all(not isinstance(x, (dict, list, tuple)) for x in val): return "{" + ", ".join(lua(x) for x in val) + "}"
        return "{\n" + "".join(pad_ + "  " + lua(x, ind + 1) + ",\n" for x in val) + pad_ + "}"
    flat = all(not isinstance(x, dict) for x in val.values()) and "name" in val
    key = lambda k: k if re.match(r"^[A-Za-z_]\w*$", k) else "[" + json.dumps(k) + "]"
    items = [(key(k), lua(x, ind + 1)) for k, x in val.items() if x is not None]
    if flat: return "{" + ", ".join("%s = %s" % kv for kv in items) + "}"
    return "{\n" + "".join(pad_ + "  %s = %s,\n" % kv for kv in items) + pad_ + "}"
with open(os.path.join(HERE, "bunny-rig-proposal.lua"), "w", newline="\n") as f:
    f.write("-- Bunny rig definition: a PROPOSAL as data. Generated by assets/art-source/pets/build_bunny.py; do not edit by hand.\n"
            "-- It mirrors src/shared/BearRigDefinition.lua (runtime axes: front +Z, up +Y, paws at the origin) and is NOT required by anything in src/.\n"
            "-- inheritFromBear lists the keys to copy from the Bear's definition unchanged (the wearables are the Bear's meshes).\n"
            "-- anchorDeltaFromBear is each moved anchor's offset from the LIVE Bear anchor: attachments on those anchors need that offset on the Bunny.\n"
            "return " + lua(proposal) + "\n")

# ---------- save as a NEW file ----------
root.location = ROOT_HOME
bpy.data.orphans_purge(do_recursive=True)
assert os.path.normcase(OUT_BLEND) != os.path.normcase(bpy.data.filepath)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True, copy=True)
print("SAVED", OUT_BLEND, "TRIS", TOTAL)
