"""Bear restyled to CUTE-DESIGN-RULES.md: a production candidate (2026-11-19, Fable as Astra).

Run headless from the repo root. It opens the live attachments file, edits it in memory and saves a NEW file;
pet-bear.blend and pet-bear-attachments.blend are never written:
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python artifacts/v2-bear-restyle-2026-11-19/build_bear_v2.py

Writes assets/art-source/pets/pet-bear-v2-cute.blend, and next to this file bear-v2-report.json,
bear-eye-cute.png and pet-blush.png (both textures are drawn here with numpy and packed into the .blend).
Original geometry only, built or edited by this script. No generated or imported models, no AI images.

What changes on the Bear:
  Head, Body, EarL, EarR   re-meshed as smooth round forms within 0.005 of the live surface, so no wearable is poked through
  Muzzle          narrowed to a snout pad (25% of head width); its front stays where it was, so mouth items still sit on it
  Nose, Mouth     a small soft nose; the same "v" mouth texture on a lighter patch
  EyeL, EyeR      dark eyes with two catchlights and no white ring, 0.058 lower and 0.0105 further apart
  BlushL, BlushR  new soft blush decals
What does not: hands, feet, inner ears, tail, every wearable mesh, and 42 of the 46 anchors.
The four eye anchors (EyeL, EyeR, EyeLine, FaceBridge) move down with the eye line so eye items and glasses follow the eyes.
"""
import bpy, bmesh, math, os, json
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_BLEND = os.path.join(REPO, "assets", "art-source", "pets", "pet-bear-v2-cute.blend")
P = "PetBear__"
root = bpy.data.objects["PetBear"]
ROOT_HOME = root.location.copy()
root.location = (0, 0, 0)                      # build in root-local space; put back before saving
bpy.context.view_layer.update()
obj = lambda n: bpy.data.objects[P + n]
anchor = lambda n: bpy.data.objects[P + "Anchor_" + n]

# ---------- tunables ----------
HEAD_SEG, HEAD_RINGS = 20, 10                  # 18 degree corners round the head (rule S1 wants under 25)
BODY_SEG, BODY_RINGS = 16, 8
EAR_GROW = 1.02                                 # the ears get the same treatment; hands and feet are the live meshes, untouched
HEAD_GROW, BODY_GROW = 1.012, 1.015             # the smoothed shape sits inside the live facets; grow it back to split the difference
EYE_X, EYE_Z, EYE_W, EYE_H = .225, .972, .150, .200
EYE_DZ, EYE_DX = EYE_Z - 1.03, EYE_X - .2145
PAD_KX, PAD_KZ, PAD_Z0 = .74, .78, .83         # muzzle to snout pad: scale across and up/down only, never front to back
NOSE_Z = .898
BLUSH_X, BLUSH_Z, BLUSH_RX, BLUSH_RZ = .345, .858, .088, .052
BLUSH_HEX, EYE_HEX = "#FFB0BC", "#2B1A20"
ROUGH = .5                                     # rule S7

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)

# ---------- geometry helpers (all in root-local = world while the root is at the origin) ----------
def world_bvh(o, me=None):
    me = me or o.data; mw = o.matrix_world
    return BVHTree.FromPolygons([mw @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])

def signed(bvhs, p):
    """Signed distance to the union of closed surfaces: negative = inside."""
    best = 1e9
    for b in bvhs:
        loc, nrm, _, dist = b.find_nearest(p)
        best = min(best, dist if (p - loc).dot(nrm) >= 0 else -dist)
    return best

def front_hit(bvhs, x, z):
    """First surface met looking at the face from the front (camera at -Y)."""
    best = None
    for b in bvhs:
        loc, nrm, _, _ = b.ray_cast(Vector((x, -5, z)), Vector((0, 1, 0)))
        if loc is not None and (best is None or loc.y < best[0].y): best = (loc, nrm)
    return best

def smooth_target(o, levels=3):
    """The live mesh, Catmull-Clark smoothed. A convex cage's smooth surface lies inside the cage."""
    tmp = bpy.data.objects.new("tmp_target", o.data.copy()); bpy.context.scene.collection.objects.link(tmp)
    tmp.matrix_world = o.matrix_world.copy()
    md = tmp.modifiers.new("s", "SUBSURF"); md.levels = md.render_levels = levels
    bpy.context.view_layer.update()
    ev = tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = ev.to_mesh()
    bvh = BVHTree.FromPolygons([tmp.matrix_world @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
    ev.to_mesh_clear(); bpy.data.objects.remove(tmp)
    return bvh

def refit(o, seg, rings, grow=1.0, poles="z"):
    """Replace o's mesh with a seg x rings round mesh cast onto its own smoothed shape. UVs come from the old mesh."""
    old = o.data; mw = o.matrix_world.copy(); inv = mw.inverted()
    pts = [mw @ v.co for v in old.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2; e = (hi - lo) / 2
    target = smooth_target(o); old_bvh = world_bvh(o)
    uv_old = old.uv_layers.active.data
    def cast(d):
        loc, _, _, _ = target.ray_cast(c, d.normalized())
        return c + (loc - c) * grow
    def uv_at(p):
        loc, _, idx, _ = old_bvh.find_nearest(p); poly = old.polygons[idx]
        w = poly_3d_calc([mw @ old.vertices[i].co for i in poly.vertices], loc)
        u = sum(uv_old[li].uv[0] * wi for li, wi in zip(poly.loop_indices, w)); v = sum(uv_old[li].uv[1] * wi for li, wi in zip(poly.loop_indices, w))
        return (u, v)
    bm = bmesh.new(); uvs = {}
    def add(d):
        if poles == "y": d = Vector((d.x, d.z, -d.y))                 # poles front and back, so the rim seen from the front is the round loop
        p = cast(d); v = bm.verts.new(inv @ p); uvs[v] = uv_at(p); return v
    top = add(Vector((0, 0, 1))); bot = add(Vector((0, 0, -1))); loops = []
    for i in range(1, rings):
        phi = math.pi * i / rings
        ey, ez = (e.z, e.y) if poles == "y" else (e.y, e.z)
        loops.append([add(Vector((e.x * math.sin(phi) * math.cos(2 * math.pi * j / seg), ey * math.sin(phi) * math.sin(2 * math.pi * j / seg), ez * math.cos(phi)))) for j in range(seg)])
    for j in range(seg):
        bm.faces.new((top, loops[0][j], loops[0][(j + 1) % seg])); bm.faces.new((bot, loops[-1][(j + 1) % seg], loops[-1][j]))
    for a, b in zip(loops, loops[1:]):
        for j in range(seg): bm.faces.new((a[j], b[j], b[(j + 1) % seg], a[(j + 1) % seg]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    layer = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l in f.loops: l[layer].uv = uvs[l.vert]
    me = bpy.data.meshes.new(old.name + "_cute"); bm.to_mesh(me); bm.free()
    for m in old.materials: me.materials.append(m)
    o.data = me
    return old

def new_piece(name, bm, mat, parent, props, uv_fn=None, v=.05):
    """A mesh named PetBear__<name>, parented to an anchor with an identity transform (bm is in world space)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    inv = parent.matrix_world.inverted(); layer = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l in f.loops: l[layer].uv = uv_fn(l.vert.co) if uv_fn else (.5, v)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=inv)
    me = bpy.data.meshes.new(P + name); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    old = bpy.data.objects.get(P + name)
    if old:
        o = old; o.data = me
    else:
        o = bpy.data.objects.new(P + name, me); bpy.data.collections["EggDrop_PetBear"].objects.link(o)
        o.parent = parent; o.matrix_parent_inverse = Matrix.Identity(4)
    for k, val in props.items(): o[k] = val
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

def image(name, px, filename):
    """px: float array (h, w, 4), sRGB values 0..1, row 0 at the bottom (Blender's order)."""
    h, w, _ = px.shape
    im = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=True)
    im.pixels.foreach_set(px.astype(np.float32).ravel()); im.filepath_raw = os.path.join(HERE, filename); im.file_format = "PNG"; im.save(); im.pack()
    return im

def srgb(h): h = h.lstrip("#"); return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]

# ---------- record the live fit before anything moves ----------
SURFACES = ("Head", "Body", "EarL", "EarR", "HandL", "HandR", "FootL", "FootR", "Muzzle", "Tail")
WEAR = [o for c in ("PetBear_Wearables", "PetBear_FeatureHorns", "PetBear_FeatureWings") for o in bpy.data.collections[c].objects if o.type == "MESH"]
def wear_points(): return {o.name: [o.matrix_world @ v.co for v in o.data.vertices] for o in WEAR}
old_bvhs = [world_bvh(obj(n)) for n in SURFACES]
old_head, old_muzzle = world_bvh(obj("Head")), world_bvh(obj("Muzzle"))
old_fit = {n: [signed(old_bvhs, p) for p in pts] for n, pts in wear_points().items()}
REFIT = ("Head", "Body", "EarL", "EarR")
old_verts = {n: [obj(n).matrix_world @ v.co for v in obj(n).data.vertices] for n in REFIT}
old_anchor = {a.name[len(P) + 7:]: a.matrix_world.translation.copy() for a in bpy.data.objects if a.name.startswith(P + "Anchor_")}
def live_tris():
    total = 0
    for o in bpy.data.collections["EggDrop_PetBear"].objects:
        if o.type == "MESH" and not o.hide_render and "Charm" not in o.name:
            o.data.calc_loop_triangles(); total += len(o.data.loop_triangles)
    return total
tris_live = live_tris()

# ---------- 1. head and body: smooth, round, and inside the live surface ----------
refit(obj("Head"), HEAD_SEG, HEAD_RINGS, HEAD_GROW)
refit(obj("Body"), BODY_SEG, BODY_RINGS, BODY_GROW)
for n in ("EarL", "EarR"): refit(obj(n), 16, 4, EAR_GROW, "y")
bpy.context.view_layer.update()
head = world_bvh(obj("Head"))

# ---------- 2. snout pad: the live muzzle, narrower and shorter, same front ----------
mz = obj("Muzzle"); mz.data = mz.data.copy(); z0 = PAD_Z0 - mz.matrix_world.translation.z
for v in mz.data.vertices: v.co.x *= PAD_KX; v.co.z = z0 + (v.co.z - z0) * PAD_KZ
mz.data.update(); bpy.context.view_layer.update()
pad = world_bvh(mz); face = [head, pad]

# ---------- 3. nose: small, soft, dark ----------
p, n = front_hit([pad], 0, NOSE_Z)
bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=4, radius=1)
bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))   # poles front and back: a round outline
for v in bm.verts:
    if v.co.z < 0: v.co.z *= .8                                   # a rounded bean: a touch flatter underneath
bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(p + Vector((0, .006, 0))) @ Matrix.Diagonal((.033, .020, .025, 1)))
nose = new_piece("Nose", bm, bpy.data.materials["petBear__nose"], anchor("Head"), {})

# ---------- 4. mouth: the same "v" texture on a lighter patch that follows the pad ----------
mo = obj("Mouth"); mpts = [mo.matrix_world @ v.co for v in mo.data.vertices]
MX = max(q.x for q in mpts); MZ1 = max(q.z for q in mpts); MZ0 = min(q.z for q in mpts); MZ_CUT = .765
bm = bmesh.new(); N = 4; grid = []
for i in range(N + 1):
    row = []
    for j in range(N + 1):
        x = -MX + 2 * MX * j / N; z = MZ1 - (MZ1 - MZ_CUT) * i / N
        q, nn = front_hit(face, x, z); row.append(bm.verts.new(q + Vector((0, -1, 0)).lerp(nn, .6).normalized() * .010))
    grid.append(row)
for i in range(N):
    for j in range(N): bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
new_piece("Mouth", bm, bpy.data.materials["petBear__mouth"], anchor("Head"), {}, lambda co: ((co.x + MX) / (2 * MX), (MZ1 - co.z) / (MZ1 - MZ0)))

# ---------- 5. eyes: one dark shape, two catchlights, no white ring ----------
S = 4; n_px = 128 * S
yy, xx = np.mgrid[0:n_px, 0:n_px]; u = (xx + .5) / n_px - .5; v = (yy + .5) / n_px - .5
tex = np.zeros((n_px, n_px, 4)); tex[..., :3] = srgb(EYE_HEX); tex[..., 3] = 1
for cu, cv, r in ((-.14, .19, .19), (.15, -.21, .085)):               # big upper-left, small lower-right; same side on both eyes
    inside = ((u - cu) / r) ** 2 + ((v - cv) / (r * 1.08 * EYE_W / EYE_H)) ** 2 <= 1
    tex[inside, :3] = 1
tex = tex.reshape(128, S, 128, S, 4).mean(axis=(1, 3))
eye_img = image("petBearEyeCuteTex", tex, "bear-eye-cute.png")
eye_mat = bpy.data.materials.new("petBear__eyeCute"); eye_mat.use_nodes = True
nt = eye_mat.node_tree; bsdf = next(nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED")
tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = eye_img; tx.extension = "EXTEND"
nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"]); nt.links.new(tx.outputs["Color"], bsdf.inputs["Emission Color"])
bsdf.inputs["Emission Strength"].default_value = .35                   # only the white catchlights have anything to emit
bsdf.inputs["Roughness"].default_value = .6
for sx, tag in ((-1, "L"), (1, "R")):
    x0 = sx * EYE_X
    bm = oval_patch([head], x0, EYE_Z, EYE_W / 2, EYE_H / 2, lambda k: .004 + .018 * (1 - k * k), 2, 24)
    new_piece("Eye" + tag, bm, eye_mat, anchor("Head"), {}, lambda co, x0=x0: (.5 + (co.x - x0) / EYE_W, .5 + (co.z - EYE_Z) / EYE_H))

# ---------- 6. blush: two soft decals outside and just below the eyes ----------
n_px = 64 * S; yy, xx = np.mgrid[0:n_px, 0:n_px]; r = np.hypot((xx + .5) / n_px - .5, (yy + .5) / n_px - .5) * 2
t = np.clip((1 - r) / .45, 0, 1); a = t * t * (3 - 2 * t)
tex = np.zeros((n_px, n_px, 4)); tex[..., :3] = srgb(BLUSH_HEX); tex[..., 3] = a * .95
blush_img = image("petBlushTex", tex.reshape(64, S, 64, S, 4).mean(axis=(1, 3)), "pet-blush.png")
blush_mat = bpy.data.materials.new("petBear__blush"); blush_mat.use_nodes = True
nt = blush_mat.node_tree; bsdf = next(nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED")
tx = nt.nodes.new("ShaderNodeTexImage"); tx.image = blush_img; tx.extension = "EXTEND"
bsdf.inputs["Base Color"].default_value = lin(BLUSH_HEX); bsdf.inputs["Roughness"].default_value = .8
nt.links.new(tx.outputs["Alpha"], bsdf.inputs["Alpha"])
try: blush_mat.surface_render_method = "BLENDED"
except Exception: pass
for sx, tag in ((-1, "L"), (1, "R")):
    x0 = sx * BLUSH_X
    bm = oval_patch([head], x0, BLUSH_Z, BLUSH_RX, BLUSH_RZ, lambda k: .008, 2, 12)
    new_piece("Blush" + tag, bm, blush_mat, anchor("Head"), {"role": "Blush" + tag, "channel": "Head"},
              lambda co, x0=x0: (.5 + (co.x - x0) / (2 * BLUSH_RX), .5 + (co.z - BLUSH_Z) / (2 * BLUSH_RZ)))

# ---------- 7. the four eye anchors follow the eye line; everything else stays ----------
def keep_depth(name, x, z):
    a = anchor(name); was = a.matrix_world.translation.copy()
    off = was.y - front_hit([old_head], was.x, was.z)[0].y            # how far it sat from the live head
    a.location = Vector((x, front_hit([head], x, z)[0].y + off, z))   # anchors are children of the root, which is at the origin
keep_depth("EyeL", -EYE_X, EYE_Z); keep_depth("EyeR", EYE_X, EYE_Z)
keep_depth("EyeLine", 0, EYE_Z); keep_depth("FaceBridge", 0, old_anchor["FaceBridge"].z + EYE_DZ)
bpy.context.view_layer.update()

# ---------- 8. finish (rule S7) ----------
for name in ("petBear__body", "petBear__secondary"):
    next(nd for nd in bpy.data.materials[name].node_tree.nodes if nd.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = ROUGH

# ---------- numbers ----------
def bounds(name):
    o = obj(name); pts = [o.matrix_world @ v.co for v in o.data.vertices]
    return [min(q[i] for q in pts) for i in range(3)], [max(q[i] for q in pts) for i in range(3)]
def tri(name): me = obj(name).data; me.calc_loop_triangles(); return len(me.loop_triangles)
VISIBLE = ("Body", "Head", "EarL", "EarR", "EarInnerL", "EarInnerR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR", "Tail", "HandL", "HandR", "FootL", "FootR")
(hlo, hhi), (blo, bhi), (plo, phi_) = bounds("Head"), bounds("Body"), bounds("Muzzle")
HW, HH = hhi[0] - hlo[0], hhi[2] - hlo[2]
new_bvhs = [world_bvh(obj(n)) for n in SURFACES]; new_fit = {n: [signed(new_bvhs, q) for q in pts] for n, pts in wear_points().items()}
contain = {}
for n in REFIT:
    live = [world_bvh(obj(n), None)]; o = obj(n)
    outside = max(signed([old_bvhs[SURFACES.index(n)]], o.matrix_world @ v.co) for v in o.data.vertices)
    inside = max(signed(live, q) for q in old_verts[n])
    contain[n] = {"new_surface_outside_live_max": round(outside, 4), "live_corner_above_new_surface_max": round(inside, 4)}
fit = []
for o in WEAR:
    a, b = old_fit[o.name], new_fit[o.name]
    row = {"mesh": o.name[len(P):], "item": o.get("item") or o.get("feature") or "", "slot": o.get("slot") or "",
           "live_deepest": round(min(a), 4), "v2_deepest": round(min(b), 4), "live_mean": round(sum(a) / len(a), 4), "v2_mean": round(sum(b) / len(b), 4)}
    row["mean_shift"] = round(row["v2_mean"] - row["live_mean"], 4); row["deepest_shift"] = round(row["v2_deepest"] - row["live_deepest"], 4)
    row["ok"] = abs(row["mean_shift"]) <= .03 and row["deepest_shift"] >= -.03 and (row["v2_deepest"] <= .03 or row["live_deepest"] > .03)
    fit.append(row)
moved = {}
for a in bpy.data.objects:
    if a.name.startswith(P + "Anchor_"):
        k = a.name[len(P) + 7:]; d = a.matrix_world.translation - old_anchor[k]
        if d.length > 1e-6: moved[k] = {"from": [round(c, 4) for c in old_anchor[k]], "to": [round(c, 4) for c in a.matrix_world.translation]}
pad_front = front_hit([pad], 0, .846)[0].y; head_there = front_hit([head], 0, .846)[0].y
tris = {n: tri(n) for n in VISIBLE}
report = {
    "file": "assets/art-source/pets/pet-bear-v2-cute.blend",
    "tris": {"live_bear": tris_live, "v2_total": sum(tris.values()), "by_piece": tris},
    "measures": {
        "head_width": round(HW, 3), "head_height": round(HH, 3), "body_width": round(bhi[0] - blo[0], 3),
        "P1_head_over_height_to_crown": round(HH / hhi[2], 3), "P2_head_width_over_body_width": round(HW / (bhi[0] - blo[0]), 2), "P3_head_width_over_height": round(HW / HH, 2),
        "E1_eye_width_over_head_width": round(EYE_W / HW, 3), "E1_eye_height_over_width": round(EYE_H / EYE_W, 2),
        "E2_eye_line_up_the_head": round((EYE_Z - hlo[2]) / HH, 3), "E3_eye_centres_over_head_width": round(2 * EYE_X / HW, 3),
        "E3_gap_in_eye_widths": round((2 * EYE_X - EYE_W) / EYE_W, 2),
        "F1_highest_feature_up_the_head": round((EYE_Z + EYE_H / 2 - hlo[2]) / HH, 3),
        "F2_nose_width_over_head_width": round(.066 / HW, 3), "F3_mouth_glyph_width_over_head_width": round(2 * MX * 13 / 32 / HW, 3),
        "F4_pad_width_over_head_width": round((phi_[0] - plo[0]) / HW, 3), "F4_pad_sticks_out": round(head_there - pad_front, 3),
        "F5_blush_width_over_head_width": round(2 * BLUSH_RX * .9 / HW, 3),
        "S1_head_outline_corner_degrees": round(360 / HEAD_SEG, 1), "S1_head_profile_corner_degrees": round(180 / HEAD_RINGS, 1), "S1_body_outline_corner_degrees": round(360 / BODY_SEG, 1),
    },
    "anchors": {"total": len(old_anchor), "moved": moved},
    "containment": contain,
    "mouth_anchor_to_pad_surface": {"live": round(old_anchor["Mouth"].y - front_hit([old_muzzle], 0, .80)[0].y, 4), "v2": round(old_anchor["Mouth"].y - front_hit([pad], 0, .80)[0].y, 4)},
    "wearable_fit": {"meshes": len(fit), "ok": sum(r["ok"] for r in fit), "not_ok": [r for r in fit if not r["ok"]], "rows": fit},
    "palette": {"primary": "#FFFFFF", "secondary": "#A8A5AE", "eye": EYE_HEX, "blush": BLUSH_HEX},
}
with open(os.path.join(HERE, "bear-v2-report.json"), "w") as f: json.dump(report, f, indent=1)
short = dict(report); short["wearable_fit"] = {k: v for k, v in report["wearable_fit"].items() if k != "rows"}
print("REPORT", json.dumps(short, indent=1))
for r in sorted(fit, key=lambda r: -abs(r["mean_shift"]))[:14]: print("FIT", r)

# ---------- save as a NEW file ----------
for nd in bpy.data.node_groups["PetPalette"].nodes:                     # undyed, like PetBaseColors
    if nd.type == "RGB": nd.outputs[0].default_value = lin("#FFFFFF" if nd.name == "Primary" else "#A8A5AE")
root.location = ROOT_HOME
root["candidate"] = "v2-cute 2026-11-19; not exported, not live"
assert os.path.normcase(OUT_BLEND) != os.path.normcase(bpy.data.filepath)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True, copy=True)
print("SAVED", OUT_BLEND)
