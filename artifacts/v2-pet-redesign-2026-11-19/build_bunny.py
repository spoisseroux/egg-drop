"""Bunny blockout + Bear tweak study (2026-11-19, Fable as Astra). Study only, no live asset is touched.

Run headless from the repo root (never saves over the Bear source):
  blender -b assets/art-source/pets/pet-bear.blend --python artifacts/v2-pet-redesign-2026-11-19/build_bunny.py

Original geometry only, built here with bmesh. No generated or imported models, no AI images.
The Bunny reuses the Bear's Body, Hands, Feet and Head (smoothed one level); ears, eyes, nose,
mouth, blush, snout pad and tail are new and follow CUTE-DESIGN-RULES.md.
Writes raw/*.png, bunny-report.json and bunny-blockout.blend next to this file.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw"); os.makedirs(RAW, exist_ok=True)
scene = bpy.context.scene
bear_coll = bpy.data.collections["EggDrop_PetBear"]
if bear_coll.name not in scene.collection.children: scene.collection.children.link(bear_coll)
bpy.data.objects["PetBear"].location = (0, 0, 0)
bpy.context.view_layer.update()

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)

def plain(name, hexcol, rough=.45, coat=0.0, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hexcol); b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    if emit and "Emission Color" in b.inputs:
        b.inputs["Emission Color"].default_value = lin(hexcol); b.inputs["Emission Strength"].default_value = emit
    return m

def set_palette(group, primary, secondary):
    for n in group.nodes:
        if n.type == "RGB": n.outputs[0].default_value = lin(primary if n.name == "Primary" else secondary)

# ---------- palettes ----------
BEAR = ("#FFFFFF", "#A8A5AE")          # undyed Bear (PetBaseColors)
BUNNY = ("#FFFFFF", "#A8A5AE")         # undyed, the same as the Bear (Spencer, 2026-11-19): white with a soft grey secondary
PEACH = ("#FFC6B8", "#FFF6EC")         # "Peach Milk", now a dyed example: HSV S 28%, V 100% / cream
HONEY = ("#FFD98A", "#FFB9B0")         # a dyed Bear, for the Bear-tweak comparison only
bear_group = bpy.data.node_groups["PetPalette"]; set_palette(bear_group, *BEAR)
def palette_copy(name, cols):
    g = bear_group.copy(); g.name = name; set_palette(g, *cols); return g
def mat_copy(src, new, group, rough=None):
    m = bpy.data.materials[src].copy(); m.name = new
    for n in m.node_tree.nodes:
        if n.type == "GROUP": n.node_tree = group
        if n.type == "BSDF_PRINCIPLED" and rough is not None: n.inputs["Roughness"].default_value = rough
    return m
g_bun, g_honey = palette_copy("BunnyPalette", BUNNY), palette_copy("HoneyPalette", HONEY)
M_BODY, M_SEC = mat_copy("petBear__body", "bunny__body", g_bun, .5), mat_copy("petBear__secondary", "bunny__secondary", g_bun, .5)
T_BODY, T_SEC = mat_copy("petBear__body", "tweak__body", g_honey, .5), mat_copy("petBear__secondary", "tweak__secondary", g_honey, .5)
M_EYE = plain("cute__eye", "#2B1A20", .65, 0)   # matte here: the catchlights are modelled, so stray speculars never fight them
M_SPARK = plain("cute__catchlight", "#FFFFFF", .3, 0, 1.2)
M_NOSE = plain("bunny__nose", "#F58CA5", .4)
M_INK = plain("cute__mouth", "#5A2F33", .5)
M_BLUSH = plain("cute__blush", "#FFB0BC", .7)
M_BLUSH_T = plain("cute__blush_honey", "#FFAE96", .7)
M_HAT = plain("demo__hat", "#8FC7FF", .5)

# ---------- helpers ----------
bear_root = bpy.data.objects["PetBear"]
HEAD = bpy.data.objects["PetBear__Anchor_Head"].matrix_world.translation.copy()
deps = lambda: bpy.context.evaluated_depsgraph_get()

class Pet:
    def __init__(self, name):
        self.name = name; self.parts = []
        self.root = bpy.data.objects.new(name, None); scene.collection.objects.link(self.root)
    def add(self, o): self.parts.append(o); return o
    def finish(self):
        bpy.context.view_layer.update()
        for o in self.parts:
            w = o.matrix_world.copy(); o.parent = self.root; o.matrix_world = w

def reuse(pet, src_name, role, mat=None, soft=0, xform=None):
    src = bpy.data.objects[src_name]
    o = bpy.data.objects.new(pet.name + "__" + role, src.data.copy()); scene.collection.objects.link(o)
    o.matrix_world = (xform @ src.matrix_world) if xform else src.matrix_world.copy()
    if mat: o.data.materials.clear(); o.data.materials.append(mat)
    if soft:
        md = o.modifiers.new("Soft", "SUBSURF"); md.levels = md.render_levels = soft
    return pet.add(o)

def new_mesh(name, bm, mat, v=.9, soft=0):
    """v = gradient coordinate (0 = secondary, >= .64 = primary)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l in f.loops: l[uv].uv = (.5, v)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o); me.materials.append(mat)
    if soft:
        md = o.modifiers.new("Soft", "SUBSURF"); md.levels = md.render_levels = soft
    return o

def ellipsoid(name, mat, radii, matrix, seg=12, rings=8, v=.9, soft=0):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=matrix @ Matrix.Diagonal((*radii, 1)))
    return new_mesh(name, bm, mat, v, soft)

class Face:
    """Places features on a head by ray casting from the front, so nothing floats or sinks."""
    def __init__(self, head):
        bpy.context.view_layer.update()
        self.inv = head.matrix_world.inverted(); self.mw = head.matrix_world.copy()
        self.bvh = BVHTree.FromObject(head, deps())
    def hit(self, x, z):
        o = self.inv @ Vector((x, -5, z)); d = (self.inv.to_3x3() @ Vector((0, 1, 0))).normalized()
        loc, nrm, _, _ = self.bvh.ray_cast(o, d)
        return self.mw @ loc, (self.mw.to_3x3() @ nrm).normalized()
    def frame(self, x, z, follow=.5, lift=0.0):
        """Matrix whose local -Y points out of the face. follow 0 = faces the camera, 1 = follows the surface."""
        p, n = self.hit(x, z)
        out = (Vector((0, -1, 0)).lerp(n, follow)).normalized()
        yl = -out; xl = yl.cross(Vector((0, 0, 1))).normalized(); zl = xl.cross(yl).normalized()
        m = Matrix((xl, yl, zl)).transposed().to_4x4(); m.translation = p + out * lift
        return m

def patch(name, mat, face, x0, z0, rx, rz, lift, dome=0.0, rings=4, seg=20):
    """An oval that hugs the head like a sewn-on felt piece: upright from the front, never tilted by the curve."""
    bm = bmesh.new()
    def vert(x, z, k):
        p, n = face.hit(x, z); out = Vector((0, -1, 0)).lerp(n, .6).normalized()
        return bm.verts.new(p + out * (lift(x, z) + dome * (1 - k * k)))
    centre = vert(x0, z0, 0); loops = []
    for i in range(1, rings + 1):
        k = i / rings
        loops.append([vert(x0 + rx * k * math.cos(2 * math.pi * j / seg), z0 + rz * k * math.sin(2 * math.pi * j / seg), k) for j in range(seg)])
    for j in range(seg): bm.faces.new((centre, loops[0][j], loops[0][(j + 1) % seg]))
    for a, b in zip(loops, loops[1:]):
        for j in range(seg): bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
    return new_mesh(name, bm, mat)

def sparkle_eye(pet, face, sx, x, z, w, h, tag):
    """A dark glossy oval with two catchlights and no white ring (rules E1 to E5)."""
    x0 = sx * x; EDGE, DOME = .003, .018
    def eye_lift(px, pz): return EDGE + DOME * max(0.0, 1 - ((px - x0) / (w / 2)) ** 2 - ((pz - z) / (h / 2)) ** 2)
    pet.add(patch(pet.name + "__Eye" + tag, M_EYE, face, x0, z, w / 2, h / 2, lambda px, pz: EDGE, DOME))
    for i, (u, v_, r) in enumerate(((-.14, .19, .19), (.15, -.21, .085))):   # big upper-left, small lower-right, same side on both eyes
        pet.add(patch(pet.name + "__Eye%sSpark%d" % (tag, i + 1), M_SPARK, face, x0 + u * w, z + v_ * h, r * w, r * w * 1.08,
                      lambda px, pz: eye_lift(px, pz) + .004, 0, 2, 14))

def blush(pet, face, sx, x, z, mat, tag):
    pet.add(ellipsoid(pet.name + "__Blush" + tag, mat, (.078, .012, .046), face.frame(sx * x, z, 1.0, -.004), 12, 6))

def tube(name, mat, pts, rad, seg=6):
    bm = bmesh.new(); rings = []
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = tan.cross(Vector((0, 1, 0))).normalized(); b = tan.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * k / seg) + b * math.sin(2 * math.pi * k / seg)) * rad) for k in range(seg)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(seg): bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k]))
    bm.faces.new(rings[0]); bm.faces.new(list(reversed(rings[-1])))
    return new_mesh(name, bm, mat)

def ear(pet, sx, tag, mat, inner_mat, tilt_deg, flop=0.0, suffix=""):
    """A long rounded paddle with a round tip: no point anywhere (rule S2). flop bends the top forward."""
    L, W, T, N, SEG = .62, .15, .062, 11, 10
    tilt = math.radians(tilt_deg)
    side = Vector((math.cos(tilt), 0, -sx * math.sin(tilt)))                 # across the ear
    up = Vector((sx * math.sin(tilt), .10, math.cos(tilt))).normalized()     # along the ear, leaning back a touch
    front = side.cross(up).normalized()
    if front.y > 0: front = -front
    base = Vector((sx * .25, .03, 1.24))
    def half_width(t):
        if t < .55: return W * (.56 + .44 * math.sin(math.pi / 2 * t / .55))
        return W * math.sqrt(max(0.0, 1 - ((t - .55) / .45) ** 2))
    target = (Vector((sx, 0, 0)) * .9 + front * .45).normalized()      # a flopped ear droops out to the side and a little forward
    axis = up.cross(target).normalized()
    dt = 1 / 80; samples = []; pos, dirv, sidev, frontv = base.copy(), up.copy(), side.copy(), front.copy(); tt = 0.0
    samples.append((pos.copy(), dirv.copy(), sidev.copy(), frontv.copy()))
    while tt < 1:
        tt += dt
        if flop and .36 < tt < .92:
            rot = Matrix.Rotation(flop * math.radians(105) * dt / .56, 3, axis)
            dirv, sidev, frontv = (rot @ dirv).normalized(), (rot @ sidev).normalized(), (rot @ frontv).normalized()
        pos = pos + dirv * L * dt; samples.append((pos.copy(), dirv.copy(), sidev.copy(), frontv.copy()))
    def build(name, m, k_w, k_t, t0, t1, push, v):
        bm = bmesh.new(); rings = []
        for i in range(N + 1):
            t = t0 + (t1 - t0) * math.sin(math.pi / 2 * i / N) ** .8          # more rings near the round tip
            c, dv, sv, fv = samples[min(len(samples) - 1, round(t / dt))]
            hw = max(.004, half_width(t) * k_w); th = max(.003, T * k_t * (half_width(t) / W))
            rings.append([bm.verts.new(c + fv * push * (half_width(t) / W) + sv * hw * math.cos(2 * math.pi * k / SEG) + fv * th * math.sin(2 * math.pi * k / SEG)) for k in range(SEG)])
        for r0, r1 in zip(rings, rings[1:]):
            for k in range(SEG): bm.faces.new((r0[k], r0[(k + 1) % SEG], r1[(k + 1) % SEG], r1[k]))
        bm.faces.new(rings[0]); bm.faces.new(list(reversed(rings[-1])))
        return pet.add(new_mesh(name, bm, m, v, 0))
    a = build(pet.name + "__Ear" + tag + suffix, mat, 1, 1, 0, .995, 0, .9)
    b = build(pet.name + "__EarInner" + tag + suffix, inner_mat, .58, .5, .14, (.50 if flop else .92), T * .62, 0)
    return [a, b]

# ---------- the Bunny ----------
bun = Pet("PetBunny")
reuse(bun, "PetBear__Body", "Body", M_BODY, 1)
for part in ("HandL", "HandR", "FootL", "FootR"): reuse(bun, "PetBear__" + part, part, M_BODY, 1)
bun_head = reuse(bun, "PetBear__Head", "Head", M_BODY, 1)          # the Bear's head, unchanged in size: every hat fits (fit.Head = 1)
bf = Face(bun_head)
HEAD_BOTTOM, HEAD_TOP, HEAD_W = .63, 1.39, .984
EYE_Z, EYE_X, EYE_W, EYE_H = .945, .232, .158, .200                # eye line 41% up the head, centres 47% of head width apart
for sx, tag in ((-1, "L"), (1, "R")):
    sparkle_eye(bun, bf, sx, EYE_X, EYE_Z, EYE_W, EYE_H, tag)
    blush(bun, bf, sx, .335, .845, M_BLUSH, tag)
# snout pad: a low cream oval, a fifth of the head wide, so the nose and mouth have a soft home
PAD = (.105, .030, .068); PAD_Z = .842
bun.add(ellipsoid("PetBunny__SnoutPad", M_SEC, PAD, bf.frame(0, PAD_Z, 1.0, -.008), 14, 8, 0))
def pad_lift(x, z): return PAD[1] * math.sqrt(max(0.0, 1 - (x / PAD[0]) ** 2 - ((z - PAD_Z) / PAD[2]) ** 2)) - .008
NOSE_Z = .872
bun.add(ellipsoid("PetBunny__Nose", M_NOSE, (.030, .016, .020), bf.frame(0, NOSE_Z, 1.0, pad_lift(0, NOSE_Z) + .004), 10, 6))
pts = []
for i in range(17):                                               # a tiny "w" mouth right under the nose
    t = -1 + 2 * i / 16; x = t * .042; z = NOSE_Z - .026 - .020 * math.sin(math.pi * abs(t))
    p, n = bf.hit(x, z); pts.append(p + Vector((0, -1, 0)).lerp(n, 1).normalized() * (pad_lift(x, z) + .004))
bun.add(tube("PetBunny__Mouth", M_INK, pts, .0065))
ears_default = ear(bun, -1, "L", M_BODY, M_SEC, 13) + ear(bun, 1, "R", M_BODY, M_SEC, 13, flop=1.0)
ears_hat = ear(bun, -1, "L", M_BODY, M_SEC, 40, suffix="_HatPose") + ear(bun, 1, "R", M_BODY, M_SEC, 40, flop=1.0, suffix="_HatPose")
bun.add(ellipsoid("PetBunny__Tail", M_BODY, (.135, .125, .13), Matrix.Translation((0, .30, .34)), 12, 8, 0, 0))
# placeholder cap for the hat-fit test only (Bear-sized, on the Bear's HatCrown anchor)
hat = [bun.add(ellipsoid("Demo__HatDome", M_HAT, (.27, .27, .20), Matrix.Translation((0, -.03, 1.35)), 14, 8)),
       bun.add(ellipsoid("Demo__HatBrim", M_HAT, (.34, .34, .035), Matrix.Translation((0, -.05, 1.33)), 16, 6))]
bun.finish()

# ---------- Bear tweak (a copy; the live Bear is not edited) ----------
twk = Pet("PetBearTweak")
for part in ("Body", "HandL", "HandR", "FootL", "FootR", "EarL", "EarR", "Tail"): reuse(twk, "PetBear__" + part, part, T_BODY, 1)
twk_head = reuse(twk, "PetBear__Head", "Head", T_BODY, 1)
for part in ("EarInnerL", "EarInnerR"): reuse(twk, "PetBear__" + part, part, T_SEC, 1)
C = Vector((0, -.40, .80)); K = .84                                 # muzzle group 16% smaller and .025 lower
shrink = Matrix.Translation(C + Vector((0, 0, -.025))) @ Matrix.Scale(K, 4) @ Matrix.Translation(-C)
reuse(twk, "PetBear__Muzzle", "Muzzle", T_SEC, 1, shrink); reuse(twk, "PetBear__Nose", "Nose", None, 0, shrink); reuse(twk, "PetBear__Mouth", "Mouth", None, 0, shrink)
tf = Face(twk_head)
for sx, tag in ((-1, "L"), (1, "R")):
    sparkle_eye(twk, tf, sx, .225, .975, .150, .200, tag)          # eyes .055 lower, no white ring
    blush(twk, tf, sx, .345, .86, M_BLUSH_T, tag)
twk.finish()

# ---------- stage ----------
world = bpy.data.worlds.new("StudyWorld"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = lin("#F1ECE6"); bg.inputs[1].default_value = .8
def light(name, energy, rot):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy; d.angle = math.radians(25)
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.rotation_euler = [math.radians(v) for v in rot]; o.location = (0, 0, 4)
light("Key", 2.4, (52, 0, -32)); light("Fill", .8, (60, 0, 140))
cam_d = bpy.data.cameras.new("StudyCam"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("StudyCam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
r = scene.render; r.film_transparent = True; r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
try: scene.view_settings.view_transform = "Standard"
except TypeError: pass
try: scene.eevee.taa_render_samples = 48
except Exception: pass

bear_hidden = [o for o in bear_root.children_recursive if o.hide_render or "Charm" in o.name]   # a new pet starts with no charm
ROOTS = (bear_root, bun.root, twk.root)
def show(*roots, hat_on=False):
    for root in ROOTS:
        for o in [root, *root.children_recursive]: o.hide_render = root not in roots
    for o in bear_hidden: o.hide_render = True
    if bun.root in roots:
        for o in hat: o.hide_render = not hat_on
        for o in ears_hat: o.hide_render = not hat_on
        for o in ears_default: o.hide_render = hat_on
def yaw(deg):
    for root in ROOTS: root.rotation_euler.z = math.radians(deg)
def shot(name, w, h, scale, x, z):
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    cam_d.ortho_scale = scale; cam.location = (x, -10, z); cam.rotation_euler = (math.radians(90), 0, 0)
    r.filepath = os.path.join(RAW, name + ".png"); bpy.ops.render.render(write_still=True)

PPU = 350                       # pixels per stud in every solo frame, the same as the 2026-11-19 Kitten frames
VIEWS = (("front", 0), ("threeq", -35), ("side", -90), ("back", 180))
bear_root.location.x, bun.root.location.x, twk.root.location.x = -.85, .85, 0
for name, deg in VIEWS:
    yaw(deg); show(bear_root, bun.root); shot("turn-" + name, 1600, 1000, 4.0, 0, .98)
for root in ROOTS: root.location.x = 0
for name, deg in VIEWS:
    yaw(deg)
    show(bear_root); shot("solo-bear-" + name, 840, 840, 840 / PPU, 0, 1.0)
    show(bun.root); shot("solo-bunny-" + name, 840, 840, 840 / PPU, 0, 1.0)
set_palette(g_bun, *PEACH)                                         # the dyed example
for name, deg in (("front", 0), ("threeq", -35)):
    yaw(deg); show(bun.root); shot("solo-bunny-peach-" + name, 840, 840, 840 / PPU, 0, 1.0)
set_palette(g_bun, *BUNNY)
yaw(0); show(bun.root); shot("face-bunny-front", 1200, 1200, 1.5, 0, 1.12)
yaw(-30); shot("face-bunny-threeq", 1200, 1200, 1.5, 0, 1.12)
yaw(-20); show(bun.root, hat_on=True); shot("hat-fit", 900, 900, 900 / PPU, 0, 1.0)
set_palette(bear_group, *HONEY)                                    # the same dye on both, so only shape and face differ
for name, deg in (("front", 0), ("threeq", -30)):
    yaw(deg); show(bear_root); shot("bear-live-" + name, 840, 840, 840 / PPU * .78, 0, .80)
    show(twk.root); shot("bear-tweak-" + name, 840, 840, 840 / PPU * .78, 0, .80)
set_palette(bear_group, *BEAR); yaw(0); show(*ROOTS)
bear_root.location.x, bun.root.location.x, twk.root.location.x = -1.2, 0, 1.2

# ---------- numbers ----------
bpy.context.view_layer.update(); dg = deps()
def tris(objs):
    total = 0
    for o in objs:
        if o.type != "MESH": continue
        ev = o.evaluated_get(dg); me = ev.to_mesh(); me.calc_loop_triangles(); total += len(me.loop_triangles); ev.to_mesh_clear()
    return total
def size(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    return [round(max(p[i] for p in pts) - min(p[i] for p in pts), 3) for i in range(3)]
live = [o for o in bun.parts if o not in hat and o not in ears_hat]
shared = [o for o in live if o.name.split("__")[1] in ("Body", "HandL", "HandR", "FootL", "FootR", "Head")]
head_h = HEAD_TOP - HEAD_BOTTOM
report = {
    "bunny": {"tris_blockout": tris(live), "tris_shared_smoothed": tris(shared), "tris_new_pieces": tris([o for o in live if o not in shared]),
              "size_xyz": size(live), "new_pieces": sorted(o.name for o in live if o not in shared)},
    "bear": {"tris": tris([o for o in bear_root.children_recursive if o not in bear_hidden]), "size_xyz": size([o for o in bear_root.children_recursive if o not in bear_hidden])},
    "measures": {
        "head_height_over_height_to_crown": round(head_h / HEAD_TOP, 3),
        "head_width_over_body_width": round(HEAD_W / .604, 2),
        "eye_width_over_head_width": round(EYE_W / HEAD_W, 3),
        "eye_line_up_the_head": round((EYE_Z - HEAD_BOTTOM) / head_h, 3),
        "eye_centre_spacing_over_head_width": round(2 * EYE_X / HEAD_W, 3),
        "gap_between_eyes_in_eye_widths": round((2 * EYE_X - EYE_W) / EYE_W, 2),
        "nose_width_over_head_width": round(.060 / HEAD_W, 3),
        "mouth_width_over_head_width": round(.084 / HEAD_W, 3),
        "bear_eye_line_up_the_head": round((1.029 - HEAD_BOTTOM) / head_h, 3),
        "bear_muzzle_width_over_head_width": round(.328 / HEAD_W, 3),
    },
    "palette": {"primary": BUNNY[0], "secondary": BUNNY[1], "dyed_example_peach_milk": list(PEACH), "nose": "#F58CA5", "blush": "#FFB0BC", "eye": "#2B1A20"},
    "pixels_per_stud_solo": PPU,
}
with open(os.path.join(HERE, "bunny-report.json"), "w") as f: json.dump(report, f, indent=1)
print("REPORT", json.dumps(report))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "bunny-blockout.blend"), compress=True, copy=True)
