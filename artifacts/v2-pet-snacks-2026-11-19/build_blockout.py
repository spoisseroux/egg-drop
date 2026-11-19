"""Kitten + Stat Snack blockout (2026-11-19, Fable as Astra). Scope study only.

Run headless from the repo root (never saves over the Bear source):
  blender -b assets/art-source/pets/pet-bear.blend --python artifacts/v2-pet-snacks-2026-11-19/build_blockout.py

Original geometry only, built here with bmesh. No generated or imported models.
The Kitten reuses the Bear's own Body, Hands, Feet, Eyes and Mouth patch (PET-STYLE-GUIDE:
"a new animal changes its head pieces and its tail, not the body"). Its head is the Bear
head reshaped (wider cheeks, lower crown); ears, cheek tufts, whisker pads, nose and tail are new.
Writes raw/*.png, blockout-report.json and kitten-and-snacks-blockout.blend next to this file.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw"); os.makedirs(RAW, exist_ok=True)
scene = bpy.context.scene
# The Bear's collection is not linked to the source file's active scene: link it (in memory only).
bear_coll = bpy.data.collections["EggDrop_PetBear"]
if bear_coll.name not in scene.collection.children: scene.collection.children.link(bear_coll)
bpy.data.objects["PetBear"].location = (0, 0, 0)
bpy.context.view_layer.update()

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)

def plain(name, hexcol, rough=.4, coat=.1):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hexcol); b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    return m

def set_palette(group, primary, secondary):
    for n in group.nodes:
        if n.type == "RGB":
            n.outputs[0].default_value = lin(primary if n.name == "Primary" else secondary)

# ---------- palettes ----------
BEAR = ("#FFFFFF", "#A8A5AE")            # undyed Bear (PetBaseColors)
KITTEN = ("#FFB86B", "#FFF2DD")          # proposed "Marmalade": ginger body, cream socks
bear_group = bpy.data.node_groups["PetPalette"]
set_palette(bear_group, *BEAR)
kit_group = bear_group.copy(); kit_group.name = "KittenPalette"; set_palette(kit_group, *KITTEN)
def kitten_copy(mat_name, new_name):
    m = bpy.data.materials[mat_name].copy(); m.name = new_name
    for n in m.node_tree.nodes:
        if n.type == "GROUP": n.node_tree = kit_group
    return m
M_BODY, M_SEC = kitten_copy("petBear__body", "kitten__body"), kitten_copy("petBear__secondary", "kitten__secondary")
M_NOSE = plain("kitten__nose", "#E8879A", .45, 0)

# ---------- pet roots ----------
bear_root = bpy.data.objects["PetBear"]
HEAD = bpy.data.objects["PetBear__Anchor_Head"].matrix_world.translation.copy()
kit_root = bpy.data.objects.new("PetKitten", None); scene.collection.objects.link(kit_root)
kit_parts = []

def adopt(o):
    kit_parts.append(o); return o

def reuse(src_name, new_name, mat=None, edit=None):
    src = bpy.data.objects[src_name]
    o = bpy.data.objects.new(new_name, src.data.copy()); scene.collection.objects.link(o)
    o.matrix_world = src.matrix_world.copy()
    if mat: o.data.materials.clear(); o.data.materials.append(mat)
    if edit:
        for v in o.data.vertices: v.co = edit(v.co.copy())
    return adopt(o)

def new_mesh(name, bm, mat, v_of=None, subsurf=0):
    """v_of(co) -> gradient v (0 = secondary, >= .64 = primary); default fully primary."""
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = True
        for l in f.loops: l[uv].uv = (.5, v_of(l.vert.co) if v_of else .9)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scene.collection.objects.link(o); me.materials.append(mat)
    if subsurf:
        md = o.modifiers.new("Soft", "SUBSURF"); md.levels = md.render_levels = subsurf
    return o

def cone(name, mat, r1, r2, depth, seg, scale, rot, loc, subsurf=1):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1)))
    return adopt(new_mesh(name, bm, mat, subsurf=subsurf))

def ball(name, mat, radius, scale, loc, seg=10, rings=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((*scale, 1)))
    return adopt(new_mesh(name, bm, mat))

# Shared with the Bear, unchanged.
for part in ("Body", "HandL", "HandR", "FootL", "FootR"): reuse("PetBear__" + part, "PetKitten__" + part, M_BODY)
for part in ("EyeL", "EyeR", "Mouth"): reuse("PetBear__" + part, "PetKitten__" + part)

# Head: the Bear head, cheeks 10% wider low down, crown 10% lower. Face surface kept, so eyes fit.
def cat_head(co):
    low = min(1.0, max(0.0, (.45 - co.z) / .5))
    side = min(1.0, abs(co.x) / .3)
    co.x *= 1 + .10 * low * side
    if co.z > .45: co.z = .45 + (co.z - .45) * .9
    return co
reuse("PetBear__Head", "PetKitten__Head", M_BODY, cat_head)

for sx, tag in ((-1, "L"), (1, "R")):
    # Soft pointed ears, set wide and tipped out, so the crown stays free for hats.
    cone("PetKitten__Ear" + tag, M_BODY, .22, .06, .40, 8, (1, .55, 1), (0, sx * math.radians(20), 0), HEAD + Vector((sx * .31, .02, .70)))
    cone("PetKitten__EarInner" + tag, M_SEC, .135, .02, .27, 8, (1, .3, 1), (0, sx * math.radians(20), 0), HEAD + Vector((sx * .30, -.075, .68)))
    # Two cheek tufts a side: the cat read from the front and the back.
    cone("PetKitten__CheekTuftA" + tag, M_BODY, .14, .05, .20, 6, (1, .6, 1), (0, sx * math.radians(104), 0), HEAD + Vector((sx * .53, -.03, .20)))
    cone("PetKitten__CheekTuftB" + tag, M_BODY, .11, .04, .15, 6, (1, .6, 1), (0, sx * math.radians(128), 0), HEAD + Vector((sx * .49, -.03, .08)))
    ball("PetKitten__WhiskerPad" + tag, M_SEC, .1, (1.05, .9, .82), HEAD + Vector((sx * .078, -.405, .125)))
ball("PetKitten__Nose", M_NOSE, 1, (.052, .034, .036), HEAD + Vector((0, -.497, .212)), 8, 5)

# Tail: a long tube that sweeps round to the pet's left so it shows from the front. Cream tip.
def catmull(p, n):
    out = []
    for i in range(len(p) - 1):
        a, b, c, d = p[max(i - 1, 0)], p[i], p[i + 1], p[min(i + 2, len(p) - 1)]
        for k in range(n):
            t = k / n
            out.append(.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    return out + [p[-1]]
path = catmull([Vector(v) for v in ((0, .18, .30), (.12, .42, .24), (.34, .48, .26), (.52, .38, .34), (.63, .24, .45), (.68, .13, .57), (.72, .08, .68))], 3)
bm = bmesh.new(); rings = []; SEG = 6
for i, p in enumerate(path):
    t = i / (len(path) - 1)
    tan = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
    side = tan.cross(Vector((0, 0, 1))); side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    up = side.cross(tan).normalized(); rad = .082 - .014 * t
    rings.append([(bm.verts.new(p + (side * math.cos(2 * math.pi * k / SEG) + up * math.sin(2 * math.pi * k / SEG)) * rad), t) for k in range(SEG)])
tip = bm.verts.new(path[-1] + (path[-1] - path[-2]).normalized() * .07)
tmap = {v: t for ring in rings for v, t in ring}; tmap[tip] = 1.0
for a, b in zip(rings, rings[1:]):
    for k in range(SEG): bm.faces.new((a[k][0], a[(k + 1) % SEG][0], b[(k + 1) % SEG][0], b[k][0]))
for k in range(SEG): bm.faces.new((rings[-1][k][0], rings[-1][(k + 1) % SEG][0], tip))
bm.faces.new([v for v, _ in reversed(rings[0])])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
uv = bm.loops.layers.uv.new("UVMap")
for f in bm.faces:
    f.smooth = True
    for l in f.loops: l[uv].uv = (.5, .9 if tmap[l.vert] < .74 else 0.0)
me = bpy.data.meshes.new("PetKitten__Tail"); bm.to_mesh(me); bm.free()
tail = bpy.data.objects.new("PetKitten__Tail", me); scene.collection.objects.link(tail); me.materials.append(M_BODY)
adopt(tail)

bpy.context.view_layer.update()
for o in kit_parts:
    w = o.matrix_world.copy(); o.parent = kit_root; o.matrix_world = w

# ---------- Stat Snacks ----------
STATS = [("heart", "Heart", "#FF86A8"), ("power", "Power", "#FF9D4D"), ("energy", "Energy", "#6CCBFF"),
         ("jump", "Jump", "#B9EE5A"), ("speed", "Speed", "#8FA8FF"), ("smarts", "Smarts", "#E58CFF")]
SIZES = [("nibble", 1, .20), ("snack", 2, .25), ("feast", 3, .30)]   # layers, diameter in studs
M_BISCUIT, M_MARK, M_PEARL = plain("snack__biscuit", "#EFC27A", .6, 0), plain("snack__mark", "#4A2B22", .5, 0), plain("snack__pearl", "#FFF6E9", .3, .2)
M_STAT = {sid: plain("snack__" + sid, col, .35, .15) for sid, _, col in STATS}

def circle(cx, cy, rx, ry, n=10): return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
def bar(p, q, w):
    d = Vector((q[0] - p[0], q[1] - p[1])).normalized(); n = Vector((-d.y, d.x)) * w / 2
    return [(p[0] + n.x, p[1] + n.y), (q[0] + n.x, q[1] + n.y), (q[0] - n.x, q[1] - n.y), (p[0] - n.x, p[1] - n.y)]
def heart():
    pts = []
    for i in range(18):
        t = 2 * math.pi * i / 18
        pts.append((16 * math.sin(t) ** 3 / 17, (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17 + .1))
    return [pts]
MARKS = {   # original chunky marks, each readable without colour (unit square, +y = away from the camera)
    "heart": heart(),
    "power": [circle(0, -.3, .56, .44), circle(-.58, .34, .22, .25, 8), circle(0, .6, .22, .25, 8), circle(.58, .34, .22, .25, 8)],
    "energy": [[(.15, 1), (-.55, -.1), (-.05, -.1), (-.2, -1), (.55, .2), (.05, .2)]],
    "jump": [[(0, 1), (-.78, .08), (.78, .08)], bar((0, .12), (0, -.42), .42), bar((-.62, -.82), (.62, -.82), .24)],   # hop up off a pad
    "speed": [bar((-.9, .5), (.45, .5), .24), bar((-.45, 0), (.9, 0), .24), bar((-.9, -.5), (.15, -.5), .24)],
    "smarts": [circle(0, .05, .5, .5, 12), bar((0, -.4), (0, -.78), .44), bar((0, -.84), (0, -.98), .26), bar((0, 1.0), (0, .72), .15),
               bar((-.74, .74), (-.52, .54), .15), bar((.74, .74), (.52, .54), .15), bar((-1.0, .05), (-.7, .05), .15), bar((1.0, .05), (.7, .05), .15)],
}
def disc_mesh(bm, pts, z0, z1, inset=1.0):
    """Extrude a 2D outline from z0 to z1; the top ring is scaled by `inset` for a soft edge."""
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]; hi = [bm.verts.new((x * inset, y * inset, z1)) for x, y in pts]
    n = len(pts)
    for i in range(n): bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    bm.faces.new(hi); bm.faces.new(list(reversed(lo)))

def snack(stat, size, layers, dia, at):
    r = dia / 2; h = dia * .28; gap = h * .55
    root = bpy.data.objects.new("Snack_%s_%s" % (stat, size), None); scene.collection.objects.link(root); root.location = at
    def part(name, bm, mat):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        o = new_mesh("Snack_%s_%s__%s" % (stat, size, name), bm, mat)
        for p in o.data.polygons: p.use_smooth = False     # biscuits are crisp; the pets stay smooth
        o.parent = root; return o
    z = 0
    for i in range(layers):
        bm = bmesh.new()   # scalloped biscuit: ten bumps, bevelled top
        disc_mesh(bm, [((r if k % 2 == 0 else r * .9) * math.cos(math.pi * k / 10), (r if k % 2 == 0 else r * .9) * math.sin(math.pi * k / 10)) for k in range(20)], z, z + h * .7)
        disc_mesh(bm, circle(0, 0, r * .9, r * .9, 20), z + h * .7, z + h, .93)
        part("Biscuit%d" % (i + 1), bm, M_BISCUIT); z += h
        if i < layers - 1:
            bm = bmesh.new(); disc_mesh(bm, circle(0, 0, r * .86, r * .86, 16), z - .002, z + gap + .002)
            part("Cream%d" % (i + 1), bm, M_STAT[stat]); z += gap
    bm = bmesh.new(); disc_mesh(bm, circle(0, 0, r * .76, r * .76, 16), z - .002, z + h * .22, .9)
    part("Icing", bm, M_STAT[stat]); z += h * .22
    bm = bmesh.new(); k = r * .46
    for shape in MARKS[stat]: disc_mesh(bm, [(x * k, y * k) for x, y in shape], z - .002, z + dia * .05)
    part("Mark", bm, M_MARK)
    if size == "feast":   # sugar pearls: the Feast's own tell, with no extra colour
        bm = bmesh.new()
        for i in range(8):
            a = 2 * math.pi * (i + .5) / 8
            bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=r * .075, matrix=Matrix.Translation((r * .82 * math.cos(a), r * .82 * math.sin(a), z - h * .18)))
        part("Pearls", bm, M_PEARL)
    return root

GRID_Y, DX, DY = 30.0, .46, .64
grid = [snack(sid, size, layers, dia, Vector(((c - 2.5) * DX, GRID_Y + (1 - r_) * DY, 0)))
        for r_, (size, layers, dia) in enumerate(SIZES) for c, (sid, _, _) in enumerate(STATS)]
# Feeding scale study: a Jump Snack offered to the Kitten, a Heart Feast to the Bear.
demo = [snack("jump", "snack", 2, .25, Vector((1.10, -.80, HEAD.z + .02))), snack("heart", "feast", 3, .30, Vector((-.50, -.80, HEAD.z)))]
for d in demo: d.name = "FeedDemo_" + d.name; d.rotation_euler = (math.radians(62), 0, math.radians(18))

# ---------- stage ----------
bear_root.location.x, kit_root.location.x = -.8, .8
world = bpy.data.worlds.new("StudyWorld"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = lin("#F1ECE6"); bg.inputs[1].default_value = .75
def light(name, kind, energy, rot):
    d = bpy.data.lights.new(name, kind); d.energy = energy
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.rotation_euler = [math.radians(v) for v in rot]; o.location = (0, 0, 4)
light("Key", "SUN", 2.6, (52, 0, -32)); light("Fill", "SUN", .8, (60, 0, 140))
cam_d = bpy.data.cameras.new("StudyCam"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("StudyCam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
r = scene.render; r.film_transparent = True; r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
try: scene.view_settings.view_transform = "Standard"
except TypeError: pass
try: scene.eevee.taa_render_samples = 48
except Exception: pass

hidden_bear = [o for o in bear_root.children_recursive if o.hide_render or "Charm" in o.name]   # a new pet starts with no charm
def hide(roots, state):
    for root in roots:
        for o in [root, *root.children_recursive]: o.hide_render = state
    for o in hidden_bear: o.hide_render = True       # the Bear's alternates and wings stay off
def shot(name, w, h, scale, loc, rot):
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    cam_d.ortho_scale = scale; cam.location = loc; cam.rotation_euler = [math.radians(v) for v in rot]
    r.filepath = os.path.join(RAW, name + ".png"); bpy.ops.render.render(write_still=True)

hide(grid, True); hide(demo, True)
bpy.context.view_layer.update()
_z = [(o.matrix_world @ Vector(c)).z for o in [*bear_root.children_recursive, *kit_parts] if o.type == "MESH" and not o.hide_render for c in o.bound_box]
MID = (min(_z) + max(_z)) / 2      # frame both pets, feet to ear tips
for name, yaw in (("front", 0), ("threeq", -35), ("side", -90), ("back", 180)):
    for root in (bear_root, kit_root): root.rotation_euler.z = math.radians(yaw)
    shot("turn-" + name, 1500, 900, 3.5, (0, -10, MID), (90, 0, 0))
    for root, tag, x in ((bear_root, "bear", -.8), (kit_root, "kitten", .8)):   # solo frames for silhouettes
        other = kit_root if root is bear_root else bear_root
        hide([other], True); shot("solo-%s-%s" % (tag, name), 700, 700, 2.0, (x, -10, MID), (90, 0, 0)); hide([other], False)
for root in (bear_root, kit_root): root.rotation_euler.z = math.radians(-25)
hide(demo, False); shot("feed-scale", 1500, 900, 3.5, (0, -10, MID), (90, 0, 0)); hide(demo, True)
hide([bear_root, kit_root], True); hide(grid, False)
elev = math.radians(52)
shot("snack-grid", 1800, 1000, 3.0, (0, GRID_Y - 10 * math.cos(elev), .1 + 10 * math.sin(elev)), (90 - 52, 0, 0))
hide([bear_root, kit_root], False); hide(demo, False)
for root in (bear_root, kit_root): root.rotation_euler.z = 0

# ---------- numbers for the scope ----------
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
def tris(objs):
    total = 0
    for o in objs:
        if o.type != "MESH" or o.hide_render: continue
        ev = o.evaluated_get(deps); me = ev.to_mesh(); me.calc_loop_triangles(); total += len(me.loop_triangles); ev.to_mesh_clear()
    return total
def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" and not o.hide_render for c in o.bound_box]
    return [round(max(p[i] for p in pts) - min(p[i] for p in pts), 3) for i in range(3)]
SHARED = ("Body", "HandL", "HandR", "FootL", "FootR", "EyeL", "EyeR", "Mouth")
new_parts = [o for o in kit_parts if o.name.split("__")[1] not in SHARED]
report = {
    "bear": {"tris": tris(bear_root.children_recursive), "size_xyz": bounds(bear_root.children_recursive)},
    "kitten": {"tris": tris(kit_parts), "new_piece_tris": tris(new_parts), "size_xyz": bounds(kit_parts), "new_pieces": sorted(o.name for o in new_parts)},
    "snacks": {size: {"diameter": dia, "tris": tris(grid[i * 6].children_recursive)} for i, (size, _, dia) in enumerate(SIZES)},
    "feet_z": round(min(_z), 3), "palette": {"kitten_primary": KITTEN[0], "kitten_secondary": KITTEN[1]},
}
with open(os.path.join(HERE, "blockout-report.json"), "w") as f: json.dump(report, f, indent=1)
print("REPORT", json.dumps(report))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "kitten-and-snacks-blockout.blend"), compress=True, copy=True)
