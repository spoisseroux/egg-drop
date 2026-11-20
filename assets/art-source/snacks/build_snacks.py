"""Production Stat Snack models (2026-11-19, Fable as Astra). V2-PET-AND-SNACKS-SCOPE-2026-11-19.md part 2.

Run headless from the repo root, after build_snack_images.py has written the textures:
  blender -b --factory-startup --python assets/art-source/snacks/build_snacks.py

Original geometry only, built here with bmesh. No generated or imported models, no AI images.
One scalloped biscuit family in three sizes. Count the layers for the size:
  Nibble 1 layer, Snack 2 layers, Feast 3 layers and five sugar pearls.
Pieces per size (one mesh each):
  Biscuit  every biscuit layer; the shared texture export/biscuit.png
  Icing    the icing top and the cream between layers; no texture, the game tints it with the stat colour.
           Its top is UV-mapped to the whole 0..1 square for the rune decal; the cream's UVs sit in a clear corner.
  Pearls   Feast only; no texture, sugar white.
Writes stat-snacks.blend, export/snack-<size>.fbx, export/snack-export-manifest.json and raw renders in
artifacts/v2-snack-production/raw/ (the Bear is appended in memory for one render and is not saved anywhere).
"""
import bpy, bmesh, math, os, json
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EXPORT = os.path.join(HERE, "export")
OUT = os.path.join(REPO, "artifacts", "v2-snack-production"); RAW = os.path.join(OUT, "raw"); os.makedirs(RAW, exist_ok=True)
BEAR_BLEND = os.path.join(REPO, "assets", "art-source", "pets", "pet-bear.blend")

STATS = [("heart", "#FF86A8"), ("power", "#FF9D4D"), ("energy", "#6CCBFF"), ("jump", "#B9EE5A"), ("speed", "#8FA8FF"), ("smarts", "#E58CFF")]  # StatCatalog.ById
SIZES = [("nibble", "Nibble", 1, .20, 150), ("snack", "Snack", 2, .25, 250), ("feast", "Feast", 3, .30, 400)]   # id, name, layers, width in studs, triangle budget
PEARL_HEX = "#FFF6E9"
SCALLOPS, ICING_SEG, CREAM_SEG, PEARLS = 10, 16, {"snack": 12, "feast": 10}, 5
CLEAR_UV = (.012, .012)                 # a corner of the rune decal that is always clear

scene = bpy.context.scene
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)

def bsdf(m): return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
def material(name, hexcol=None, rough=.5, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = bsdf(m)
    if hexcol: b.inputs["Base Color"].default_value = lin(hexcol)
    b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    return m
def image(path):
    im = bpy.data.images.load(path, check_existing=True); im.filepath = bpy.path.relpath(path, start=HERE); return im

M_BISCUIT = material("snack__biscuit", rough=.65)
_t = M_BISCUIT.node_tree.nodes.new("ShaderNodeTexImage"); _t.image = image(os.path.join(EXPORT, "biscuit.png"))
M_BISCUIT.node_tree.links.new(_t.outputs["Color"], bsdf(M_BISCUIT).inputs["Base Color"])
M_ICING = material("snack__icing", "#FFFFFF", .35, .15)        # white in the source file: the game tints it
M_PEARL = material("snack__pearl", PEARL_HEX, .3, .2)
def icing_material(stat, hexcol):
    """Preview only: the stat tint with the rune decal laid over it, as a Decal does in Roblox."""
    m = material("preview__icing_" + stat, hexcol, .35, .15); nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = image(os.path.join(EXPORT, "icon-decal-%s-256.png" % stat)); tex.extension = "EXTEND"
    mixn = nt.nodes.new("ShaderNodeMix"); mixn.data_type = "RGBA"
    col_in = [s for s in mixn.inputs if s.type == "RGBA"]; col_in[0].default_value = lin(hexcol)
    nt.links.new(tex.outputs["Alpha"], mixn.inputs[0]); nt.links.new(tex.outputs["Color"], col_in[1])
    nt.links.new(next(s for s in mixn.outputs if s.type == "RGBA"), bsdf(m).inputs["Base Color"])
    return m


# ---------- geometry ----------
def ring(bm, n, radius, z, scallop=1.0, turn=0.0):
    """n points round the z axis; every second point is pulled in by `scallop`."""
    out = []
    for k in range(n):
        a = 2 * math.pi * (k + turn) / n; r = radius * (scallop if k % 2 else 1.0)
        out.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
    return out

def band(bm, uv, lo, hi, v0=None, v1=None, uv_of=None):
    n = len(lo); faces = []
    for k in range(n):
        f = bm.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k])); faces.append(f)
        strip = ((k / n, v0), ((k + 1) / n, v0), ((k + 1) / n, v1), (k / n, v1))
        for l, st in zip(f.loops, strip): l[uv].uv = uv_of(l.vert.co) if uv_of else st
    return faces

def build_snack(size, layers, dia):
    """Returns {piece: bmesh} with the snack standing on z = 0, and its dimensions."""
    r = dia / 2; h = dia * .24; gap = h * .34; n = SCALLOPS * 2
    bis, ice, prl = bmesh.new(), bmesh.new(), bmesh.new()
    ub, ui, up = (b.loops.layers.uv.new("UVMap") for b in (bis, ice, prl))
    z = 0.0
    for i in range(layers):
        lo, mid, hi = ring(bis, n, r * .80, z), ring(bis, n, r, z + h * .5, .9), ring(bis, n, r * .80, z + h)
        band(bis, ub, lo, mid, .03, .25); band(bis, ub, mid, hi, .25, .47)
        if i == 0:      # the baked underside; a flat cap with a crisp edge so it sits like a biscuit
            f = bis.faces.new(list(reversed(lo)))
            for l in f.loops: l[ub].uv = (.25 + l.vert.co.x / (r * .80) * .22, .75 + l.vert.co.y / (r * .80) * .22)
            for e in f.edges: e.smooth = False
        z += h
        if i < layers - 1:   # cream: a plain ring that overlaps both biscuits, so no inner caps are needed
            m = CREAM_SEG[size]; a, b = ring(ice, m, r * .86, z - h * .12), ring(ice, m, r * .86, z + gap + h * .12)
            band(ice, ui, a, b, uv_of=lambda co: CLEAR_UV); z += gap
    # icing: a soft puddle that covers the whole top of the biscuit; the rune decal sits on it
    ih = h * .34; R = r * .83; m = ICING_SEG
    a, b = ring(ice, m, R, z - ih * .25), ring(ice, m, r * .72, z + ih * .8)
    top_uv = lambda co: (.5 + co.x / (2 * R), .5 + co.y / (2 * R))       # planar from above; +Y (the back) is the rune's top
    band(ice, ui, a, b, uv_of=top_uv)
    c = ice.verts.new((0, 0, z + ih))
    for k in range(m):
        f = ice.faces.new((b[k], b[(k + 1) % m], c))
        for l in f.loops: l[ui].uv = top_uv(l.vert.co)
    top = z + ih
    if size == "feast":   # sugar pearls on every second scallop: the Feast's own tell, with no extra colour
        pr = r * .12; zc = z - h * .30
        for j in range(PEARLS):
            a0 = 2 * math.pi * (2 * j) / SCALLOPS      # scallop tips are the even ring points
            centre = Vector((r * .915 * math.cos(a0), r * .915 * math.sin(a0), zc))
            def pearl_ring(rad, dz, turn):
                return [prl.verts.new(centre + Vector((rad * math.cos(a0 + math.pi * (q + turn) / 2), rad * math.sin(a0 + math.pi * (q + turn) / 2), dz))) for q in range(4)]
            lo_, hi_ = pearl_ring(pr, -pr * .2, 0), pearl_ring(pr * .6, pr * .85, .5)      # a twisted dome: eight sides from above, a small flat top, no point
            for q in range(4):
                for tri in ((lo_[q], lo_[(q + 1) % 4], hi_[q]), (lo_[(q + 1) % 4], hi_[(q + 1) % 4], hi_[q])):
                    f = prl.faces.new(tri)
                    for l in f.loops: l[up].uv = (.5, .5)
            f = prl.faces.new(hi_)
            for l in f.loops: l[up].uv = (.5, .9)
    pieces = {"Biscuit": bis, "Icing": ice}
    if size == "feast": pieces["Pearls"] = prl
    else: prl.free()
    for bm in pieces.values():
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -top / 2))      # the origin is the middle of the snack: it shrinks and turns about its centre
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        for f in bm.faces: f.smooth = True
    return pieces, top

MATS = {"Biscuit": M_BISCUIT, "Icing": M_ICING, "Pearls": M_PEARL}
masters = bpy.data.collections.new("StatSnacks"); scene.collection.children.link(masters)
built = {}
for x, (sid, name, layers, dia, budget) in enumerate(SIZES):
    pieces, height = build_snack(sid, layers, dia); objs = {}
    for piece, bm in pieces.items():
        me = bpy.data.meshes.new("StatSnack_%s__%s" % (name, piece)); bm.to_mesh(me); bm.free(); me.materials.append(MATS[piece])
        o = bpy.data.objects.new(me.name, me); masters.objects.link(o); o.location = ((x - 1) * .5, 0, 0); objs[piece] = o
    built[sid] = (objs, height)


# ---------- export: one FBX per size, the same settings as bear.fbx ----------
def bounds(objs):
    pts = [Vector(v.co) for o in objs for v in o.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); return lo, hi
def r5(v): return [round(float(x), 5) + 0.0 for x in v]
manifest_sizes = []
for sid, name, layers, dia, budget in SIZES:
    objs, height = built[sid]; keep = {}
    for o in objs.values(): keep[o] = o.location.copy(); o.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs.values(): o.select_set(True)
    bpy.context.view_layer.objects.active = objs["Biscuit"]
    bpy.ops.export_scene.fbx(filepath=os.path.join(EXPORT, "snack-%s.fbx" % sid), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True,
                             use_mesh_modifiers=False, object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO", mesh_smooth_type="FACE")
    for o, loc in keep.items(): o.location = loc
    lo, hi = bounds(objs.values()); total = sum(len(o.data.polygons) for o in objs.values())
    assert total <= budget, "%s is %d triangles, over the %d budget" % (sid, total, budget)
    plo, phi = {}, {}
    for piece, o in objs.items(): plo[piece], phi[piece] = bounds([o])
    manifest_sizes.append({
        "id": sid, "name": name, "export": "snack-%s.fbx" % sid, "layers": layers, "pearls": PEARLS if "Pearls" in objs else 0,
        "triangles": total, "budget": budget, "sizeStuds": r5(hi - lo),
        "pieces": {piece.lower(): {"mesh": o.name, "triangles": len(o.data.polygons), "centerBlender": r5((plo[piece] + phi[piece]) / 2), "sizeBlender": r5(phi[piece] - plo[piece]),
                                   "texture": "biscuit.png" if piece == "Biscuit" else None,
                                   "color": {"Biscuit": "#FFFFFF (shows the texture)", "Icing": "the stat colour (StatCatalog.ById[stat].color)", "Pearls": PEARL_HEX}[piece]}
                   for piece, o in objs.items()}})
    print("SIZE", sid, total, "tris", r5(hi - lo))


# ---------- save the source file (masters only) ----------
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "stat-snacks.blend"), compress=True)


# ---------- renders (nothing below is saved to the .blend) ----------
PREVIEW = {sid: icing_material(sid, col) for sid, col in STATS}
def place(size, stat, at, rot=(0, 0, 0)):
    root = bpy.data.objects.new("Show_%s_%s" % (stat, size), None); scene.collection.objects.link(root); root.location = at; root.rotation_euler = rot
    for piece, src in built[size][0].items():
        o = bpy.data.objects.new(root.name + "__" + piece, src.data.copy()); scene.collection.objects.link(o); o.parent = root
        if piece == "Icing": o.data.materials.clear(); o.data.materials.append(PREVIEW[stat])
    return root

world = bpy.data.worlds.new("SnackWorld"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = lin("#F1ECE6"); bg.inputs[1].default_value = .75
def light(name, energy, rot):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.rotation_euler = [math.radians(v) for v in rot]; o.location = (0, 0, 4)
light("Key", 2.6, (52, 0, -32)); light("Fill", .8, (60, 0, 140))
cam_d = bpy.data.cameras.new("SnackCam"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("SnackCam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
rs = scene.render; rs.film_transparent = True; rs.image_settings.file_format = "PNG"; rs.image_settings.color_mode = "RGBA"
try: scene.view_settings.view_transform = "Standard"
except TypeError: pass
try: scene.eevee.taa_render_samples = 64
except Exception: pass
def shot(name, w, h, scale, loc, rot):
    rs.resolution_x, rs.resolution_y, rs.resolution_percentage = w, h, 100
    cam_d.ortho_scale = scale; cam.location = loc; cam.rotation_euler = [math.radians(v) for v in rot]
    rs.filepath = os.path.join(RAW, name + ".png"); bpy.ops.render.render(write_still=True)
def hide(roots, state):
    for root in roots:
        for o in [root, *root.children_recursive]: o.hide_render = state

for o in masters.objects: o.hide_render = True
# 1. the grid: six stats across, three sizes down, seen from above the front so the rune and the layers both show
GRID_Y, DX, DY, ELEV = 30.0, .44, .50, 48
grid = [place(sid, stat, Vector(((c - 2.5) * DX, GRID_Y + (1 - r_) * DY, 0)), (0, 0, math.radians(-8)))
        for r_, (sid, *_) in enumerate(SIZES) for c, (stat, _) in enumerate(STATS)]
e = math.radians(ELEV)
shot("grid", 2400, 1010, 2.72, (0, GRID_Y - 10 * math.cos(e), -.02 + 10 * math.sin(e)), (90 - ELEV, 0, 0))
hide(grid, True)

# 2. a Heart Feast held at the Bear's cheek. The Bear is appended into memory only.
with bpy.data.libraries.load(BEAR_BLEND, link=False) as (src, dst): dst.collections = ["EggDrop_PetBear"]
bear_coll = dst.collections[0]; scene.collection.children.link(bear_coll)
bear = bpy.data.objects["PetBear"]; bear.location = (0, 0, 0)
for n in bpy.data.node_groups["PetPalette"].nodes:
    if n.type == "RGB": n.outputs[0].default_value = lin("#FFFFFF" if n.name == "Primary" else "#A8A5AE")     # the undyed Bear
for o in bear.children_recursive:
    if "Charm" in o.name: o.hide_render = True
bpy.context.view_layer.update()
head = bpy.data.objects["PetBear__Head"]
hp = [head.matrix_world @ v.co for v in head.data.vertices]
head_w = max(p.x for p in hp) - min(p.x for p in hp); head_c = Vector([(max(p[i] for p in hp) + min(p[i] for p in hp)) / 2 for i in range(3)])
head_front = min(p.y for p in hp)
feast_w = SIZES[2][3]
YAW = math.radians(-22); bear.rotation_euler.z = YAW
# The snack floats beside the cheek, level with the mouth, tipped to show its rune (scope 2.3 step 2).
local = Vector((head_w * .5 + feast_w * .52, head_front * .45, head_c.z - head_w * .17))
at = Vector((local.x * math.cos(YAW) - local.y * math.sin(YAW), local.x * math.sin(YAW) + local.y * math.cos(YAW), local.z))
held = place("feast", "heart", at, (math.radians(58), 0, math.radians(14)))
bpy.context.view_layer.update()
zs = [(o.matrix_world @ Vector(c)).z for o in bear.children_recursive if o.type == "MESH" and not o.hide_render for c in o.bound_box]
shot("cheek", 1500, 1500, 1.95, (.12, -10, (min(zs) + max(zs)) / 2), (90, 0, 0))
shot("cheek-close", 1200, 1200, .95, (at.x * .55, -10, head_c.z - .02), (90, 0, 0))

manifest = {
    "asset": "stat-snacks", "sourceBlend": "assets/art-source/snacks/stat-snacks.blend", "builtBy": ["assets/art-source/snacks/build_snack_images.py", "assets/art-source/snacks/build_snacks.py"],
    "axes": "axis_forward=-Z axis_up=Y (same as bear.fbx). Blender: front -Y, up +Z, 1 unit = 1 stud. Every piece's origin is the middle of its snack.",
    "pieceNames": ["biscuit", "icing", "pearls"],
    "textures": {"biscuit": "biscuit.png (256 px, shared by all three sizes)"},
    "iconDecals": {stat: "icon-decal-%s-256.png" % stat for stat, _ in STATS},
    "statColors": {stat: col for stat, col in STATS},
    "decalNote": "Put the stat icon as a Decal on the icing MeshPart. The icing top's UVs fill the whole image (the icon's top is the snack's back, Blender +Y); "
                 "the cream ring's UVs sit in a clear corner, so the decal shows only on top. The decal is dark cocoa on clear; do not tint it.",
    "sizes": manifest_sizes,
    "cheekCheck": {"bearHeadWidth": round(head_w, 3), "feastWidth": feast_w, "ratio": round(feast_w / head_w, 3), "limit": "under one third"},
}
assert feast_w / head_w < 1 / 3, "the Feast must stay under a third of the Bear's head width"
with open(os.path.join(EXPORT, "snack-export-manifest.json"), "w") as f: json.dump(manifest, f, indent=1)
print("MANIFEST", json.dumps({s["id"]: s["triangles"] for s in manifest_sizes}), manifest["cheekCheck"])
