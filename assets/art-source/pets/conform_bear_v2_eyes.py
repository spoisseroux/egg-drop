"""Conform every eye surface (and the cheek blush) to the v2 "cute" Bear head. Fable, 2026-11-21.

  blender -b assets/art-source/pets/pet-bear-v2-cute.blend --python assets/art-source/pets/conform_bear_v2_eyes.py
  (add `-- --no-save` to measure and export without saving the .blend)

Why: the v2 ship moved the eye items by their anchor's offset, a rigid slide. They were modelled as
cushions over the LIVE head (scripts/build_bear_wearables.py: face_patch / face_stroke, each vertex
at face_y(x, z) - h), so on the rounder v2 head their top edges sank into the head.

What it does, per vertex: keep x and z (the outline seen from the front does not change), read the
design height h the vertex had over the head it was modelled on, and put it back at that height
over the new surface: y = S(x, z) - max(h, FLOOR). S is the front surface of the v2 Bear head; for
the wardrobe items it is the nearer of the Bear head and the Bunny head (seen through the Bunny's
anchor change), because both pets wear the same mesh. Then the visible vertices and the inside of
the visible faces are checked against the real (faceted) heads and nudged out until every vertex is
MIN_VERT clear and every face sample MIN_FACE clear.

Skirts stay sunk. A cushion's last ring and a stroke's two edge rows were modelled BELOW the surface
(h < 0) so the piece meets the face with no gap under its edge. Those vertices keep their depth,
measured from the farther of the two heads, so the edge is sealed on both pets. They are hidden
inside the head by design and are reported apart from the visible surface (`skirt` in the JSON).

Sources, read only: pet-bear-attachments.blend (the items as modelled, the live head) and
pet-bunny.blend (the Bunny head and anchors). Only pet-bear-v2-cute.blend is written. Each conformed
mesh keeps its rigid-move shape in the point attribute `pre_conform`, so a rerun gives the same
result and the before/after sheet can be redrawn.

Writes:
- assets/garden-babies/attachments/patches/v2-eye-conform.fbx   every changed mesh, Bear__<piece>,
  transforms baked, pet root at the origin, axis_forward=-Z, axis_up=Y (the bear.fbx settings)
- assets/garden-babies/attachments/patches/v2-eye-conform.json  new bounds and the depth numbers
Then rerun export_bear_v2.py so bear-v2.fbx carries the same EyeL, EyeR, BlushL and BlushR.
"""
import bpy, os, sys, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PATCH = os.path.join(REPO, "assets", "garden-babies", "attachments", "patches")
assert os.path.basename(bpy.data.filepath) == "pet-bear-v2-cute.blend", "open pet-bear-v2-cute.blend"
MODE = os.environ.get("CONFORM_MODE", "envelope")        # "bear": ignore the Bunny (for comparison only)
FLOOR, MIN_VERT, MIN_FACE = 0.006, 0.005, 0.0035
P = "PetBear__"; D = bpy.data.objects
OWN = ("EyeL", "EyeR", "BlushL", "BlushR")
ID_LISTS = ("objects", "meshes", "materials", "images", "node_groups", "collections", "textures", "actions", "cameras", "lights", "worlds")


def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


def r5(v): return [round(float(x), 5) + 0.0 for x in v]


def extract(path, prefix, shorts):
    """Root-local geometry and anchors from another .blend; everything appended is removed again."""
    before = {a: {i.name for i in getattr(bpy.data, a)} for a in ID_LISTS}
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        names = [n for n in src.objects if n == prefix[:-2] or n.startswith(prefix + "Anchor_") or (n.startswith(prefix) and n[len(prefix):] in shorts)]
        dst.objects = list(names)
    objs = dict(zip(names, dst.objects))
    inv = world(objs[prefix[:-2]]).inverted()
    out = {"anchors": {}, "meshes": {}}
    for n, o in objs.items():
        m = inv @ world(o); short = n[len(prefix):]
        if o.type == "EMPTY" and short.startswith("Anchor_"): out["anchors"][short[7:]] = m.to_translation()
        elif o.type == "MESH": out["meshes"][short] = ([m @ v.co for v in o.data.vertices], [tuple(p.vertices) for p in o.data.polygons])
    for a in ID_LISTS:
        coll = getattr(bpy.data, a)
        for i in [i for i in coll if i.name not in before[a]]: coll.remove(i)
    return out


class Surface:
    """A head (+ muzzle) in the Bear's root-local frame; `shift` carries a Bear-frame point into this head's frame."""
    def __init__(self, parts, shift=Vector((0, 0, 0))):
        pts, polys = [], []
        for vs, ps in parts:
            b = len(pts); pts += vs; polys += [tuple(b + i for i in p) for p in ps]
        self.tree = BVHTree.FromPolygons(pts, polys); self.shift = shift

    def front(self, x, z, d=None):
        """(y, normal) of the front (-Y) surface, in the Bear frame, for the piece whose anchor moved by d."""
        d = self.shift if d is None else d
        hit = self.tree.ray_cast(Vector((x + d.x, -3.0, z + d.z)), Vector((0, 1, 0)))
        return (hit[0].y - d.y, hit[1]) if hit[0] else (None, None)

    def height(self, p, d=None):
        """Signed distance: positive outside the head."""
        d = self.shift if d is None else d
        q = p + d; loc, nrm, _, dist = self.tree.find_nearest(q)
        y, _ = self.front(p.x, p.z, d)
        return dist if (y is None or p.y < y) else -dist


root = D["PetBear"]; RL = world(root).inverted()
def rl(o): return RL @ world(o)

live = extract(os.path.join(HERE, "pet-bear-attachments.blend"), P,
               {"Head", "Muzzle"} | {o.name[len(P):] for o in D if o.name.startswith(P)})
bunny = extract(os.path.join(HERE, "pet-bunny.blend"), "PetBunny__", {"Head", "Muzzle"})
anchor_v2 = {o.name.split("__Anchor_")[1]: rl(o).to_translation() for o in D if "__Anchor_" in o.name}
S_LIVE = Surface([live["meshes"]["Head"], live["meshes"]["Muzzle"]])
S_BEAR = Surface([([rl(D[P + n]) @ v.co for v in D[P + n].data.vertices], [tuple(p.vertices) for p in D[P + n].data.polygons]) for n in ("Head", "Muzzle")])
S_BUNNY = Surface([bunny["meshes"]["Head"], bunny["meshes"]["Muzzle"]])


def samples(pts, tris, n=6):
    out = []
    for t in tris:
        a, b, c = (pts[i] for i in t)
        for i in range(n + 1):
            for j in range(n + 1 - i):
                if (i, j) not in ((0, 0), (n, 0), (0, n)): out.append((t, (a * i + b * j + c * (n - i - j)) / n, (i / n, j / n, (n - i - j) / n)))
    return out


def depth(surface, pts, tris, skirt, d=None):
    """Heights of the visible surface (vertices that are not skirt, faces that touch no skirt vertex)."""
    hv = [surface.height(p, d) for p, k in zip(pts, skirt) if not k]
    hf = [surface.height(q, d) for _, q, _ in samples(pts, [t for t in tris if not any(skirt[i] for i in t)])]
    out = {"deepest": round(min(hv), 4), "mean": round(sum(hv) / len(hv), 4), "highest": round(max(hv), 4), "faceDeepest": round(min(hf + hv), 4)}
    if any(skirt): out["skirt"] = [round(f(surface.height(p, d) for p, k in zip(pts, skirt) if k), 4) for f in (min, max)]
    return out


targets = sorted(o.name[len(P):] for o in D if o.type == "MESH" and o.name.startswith(P)
                 and (o.name[len(P):] in OWN or (o.name[len(P):].startswith(("Eye", "Cheek")) and not o.name[len(P):].startswith("Eyewear"))))
report, made, shapes = [], [], {}
for short in targets:
    o = D[P + short]; me = o.data; M = rl(o); Minv = M.inverted()
    me.calc_loop_triangles(); tris = [tuple(t.vertices) for t in me.loop_triangles]
    own = short in OWN; role = o.get("role", short)
    if own:
        att = me.attributes.get("pre_conform")
        pre = [M @ Vector(a.vector) for a in att.data] if att else [M @ v.co for v in me.vertices]
        ref, ref_pts, surfaces = S_BEAR, pre, [(S_BEAR, None)]
    else:
        slide = anchor_v2[role] - live["anchors"][role]                 # the rigid move the ship made
        ref, ref_pts = S_LIVE, live["meshes"][short][0]
        assert len(ref_pts) == len(me.vertices), short
        pre = [p + slide for p in ref_pts]
        surfaces = [(S_BEAR, None)] + ([(S_BUNNY, bunny["anchors"][role] - anchor_v2[role])] if MODE == "envelope" else [])
    bunny_d = None if own else bunny["anchors"][role] - anchor_v2[role]

    # 1. design height of each vertex over the head it was modelled on
    h = []
    for p in ref_pts:
        y, _ = ref.front(p.x, p.z)
        h.append((y - p.y) if y is not None else ref.height(p))
    skirt = [(not own) and v < 0 for v in h]
    stacked = (not own) and role.startswith("Eye")                   # other pieces may sit on top of it
    top = [t for t in tris if not any(skirt[i] for i in t)]
    # 2. the same height over the new surface: the nearer head for the visible vertices, the farther for the skirt
    def place(i, extra):
        ys = [y for y, _ in (s.front(pre[i].x, pre[i].z, d) for s, d in surfaces) if y is not None]
        if not ys: return pre[i].copy()
        if skirt[i]: return Vector((pre[i].x, max(ys) - h[i], pre[i].z))
        return Vector((pre[i].x, min(ys) - max(h[i], FLOOR) - extra, pre[i].z))
    extra = [0.0] * len(pre); pts = [place(i, 0.0) for i in range(len(pre))]
    # 3. clear the real facets: vertices, then face interiors
    first_face_low = None
    for _ in range(80):
        moved = False
        for i, p in enumerate(pts):
            if skirt[i]: continue
            low = min(s.height(p, d) for s, d in surfaces)
            if low < MIN_VERT: extra[i] += (MIN_VERT - low) * 1.25 + 1e-5; moved = True
        if moved:
            pts = [place(i, extra[i]) for i in range(len(pre))]; continue
        worst = {}
        for t, q, w in samples(pts, top):
            low = min(s.height(q, d) for s, d in surfaces)
            if low < MIN_FACE:
                # lift the low corners (the rim), not the whole triangle: the layers above keep their clearance
                base = min(h[i] for i in t); pick = [k for k in range(3) if not stacked or h[t[k]] <= base + 0.002]
                share = max(sum(w[k] for k in pick), 0.34)
                for k in pick: worst[t[k]] = max(worst.get(t[k], 0.0), (MIN_FACE - low) / share)
        if first_face_low is None: first_face_low = max(worst.values()) if worst else 0.0
        if not worst: break
        for i, need in worst.items(): extra[i] += need * 0.6 + 1e-5
        pts = [place(i, extra[i]) for i in range(len(pre))]
    else:
        raise RuntimeError("did not settle: " + short)

    row = {"name": "Bear__" + short, "source": o.name, "kind": "bear" if own else "item", "anchor": None if own else role,
           "item": o.get("item") or o.get("variant"), "piece": o.get("piece"),
           "vertices": len(pts), "triangles": len(tris), "material": me.materials[0].name if me.materials else "",
           "designHeight": {"lowest": round(min(h), 4), "highest": round(max(h), 4)},
           "nudgedVertices": sum(1 for e in extra if e > 0), "largestNudge": round(max(extra), 4),
           "largestMove": round(max((a - b).length for a, b in zip(pts, pre)), 4),
           "skirtVertices": sum(skirt),
           "bear": {"before": depth(S_BEAR, pre, tris, skirt), "after": depth(S_BEAR, pts, tris, skirt)}}
    if not own:
        row["bunny"] = {"anchorDelta": r5(bunny_d), "before": depth(S_BUNNY, pre, tris, skirt, bunny_d), "after": depth(S_BUNNY, pts, tris, skirt, bunny_d)}
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c, s = (lo + hi) / 2, hi - lo
    row.update(centerBlender=r5(c), sizeBlender=r5(s), centerRuntime=r5((c.x, c.z, -c.y)), sizeRuntime=r5((s.x, s.z, s.y)))
    report.append(row)

    att = me.attributes.get("pre_conform") or me.attributes.new("pre_conform", "FLOAT_VECTOR", "POINT")
    for a, p in zip(att.data, pre): a.vector = Minv @ p
    for v, p in zip(me.vertices, pts): v.co = Minv @ p
    me.update(); o["conformed"] = "v2 head, 2026-11-21 (conform_bear_v2_eyes.py)"
    made.append(short); shapes[short] = (ref_pts, pre, pts, tris, skirt)
    b, a = row["bear"]["before"], row["bear"]["after"]
    line = "%-24s bear %+.4f/%+.4f -> %+.4f/%+.4f (face %+.4f hi %+.4f skirt %s)" % (short, b["deepest"], b["mean"], a["deepest"], a["mean"], a["faceDeepest"], a["highest"], a.get("skirt"))
    if not own:
        b, a = row["bunny"]["before"], row["bunny"]["after"]
        line += " | bunny %+.4f/%+.4f -> %+.4f/%+.4f (face %+.4f hi %+.4f skirt %s)" % (b["deepest"], b["mean"], a["deepest"], a["mean"], a["faceDeepest"], a["highest"], a.get("skirt"))
    print("CONFORM", line, "| nudged", row["nudgedVertices"], "max", row["largestNudge"])

# ---------- stacked pieces: the upper layer must stay in front of the lower one, as modelled ----------
ORDER = {"White": 0, "Pupil": 1, "Main": 1, "Iris": 2, "Shine": 3}
layers = []
for up in made:
    for low in made:
        a, b = D[P + up], D[P + low]
        if up == low or up in OWN or low in OWN or a.get("item") is None or a.get("item") != b.get("item") or a.get("role") != b.get("role"): continue
        if ORDER[a.get("piece")] <= ORDER[b.get("piece")]: continue
        gaps = []
        for which in (0, 1, 2):                                   # as modelled, rigid move, conformed
            tree = BVHTree.FromPolygons(shapes[low][which], shapes[low][3])
            tris_up = [t for t in shapes[up][3] if not any(shapes[up][4][i] for i in t)]
            probe = [p for p, k in zip(shapes[up][which], shapes[up][4]) if not k] + [q for _, q, _ in samples(shapes[up][which], tris_up, 3)]
            g = [hit[0].y - p.y for p in probe for hit in [tree.ray_cast(Vector((p.x, -3.0, p.z)), Vector((0, 1, 0)))] if hit[0]]
            gaps.append(round(min(g), 4) if g else None)
        layers.append({"upper": "Bear__" + up, "lower": "Bear__" + low, "clearanceAsModelled": gaps[0], "clearanceAfter": gaps[2]})
        print("LAYER %-24s over %-24s modelled %s after %s" % (up, low, gaps[0], gaps[2]))

# ---------- export: one patch FBX with every changed mesh, the bear.fbx settings ----------
scene = bpy.data.scenes.new("EyeConformExport"); objs = []
for short in made:
    src = D[P + short]; me = src.data.copy(); me.transform(rl(src)); me.update()
    if me.attributes.get("pre_conform"): me.attributes.remove(me.attributes["pre_conform"])
    ob = bpy.data.objects.new("Bear__" + short, me); scene.collection.objects.link(ob); objs.append(ob)
bpy.context.window.scene = scene
for ob in objs: ob.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
os.makedirs(PATCH, exist_ok=True)
bpy.ops.export_scene.fbx(filepath=os.path.join(PATCH, "v2-eye-conform.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0,
                         apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"}, add_leaf_bones=False, bake_anim=False,
                         path_mode="AUTO", mesh_smooth_type="FACE")
bpy.context.window.scene = bpy.data.scenes[0]
for ob in objs:
    me = ob.data; bpy.data.objects.remove(ob, do_unlink=True); bpy.data.meshes.remove(me)
bpy.data.scenes.remove(scene)

out = {
    "schema": 1, "date": "2026-11-21", "builtBy": "assets/art-source/pets/conform_bear_v2_eyes.py",
    "sourceBlend": "assets/art-source/pets/pet-bear-v2-cute.blend", "fbx": "assets/garden-babies/attachments/patches/v2-eye-conform.fbx",
    "axes": "FBX axis_forward=-Z axis_up=Y, world transform baked, pet root at the origin. Blender pet-local: front -Y, up +Z, L = -X.",
    "mode": MODE, "floor": FLOOR, "minVertexHeight": MIN_VERT, "minFaceHeight": MIN_FACE,
    "note": "Heights are distances to the Head+Muzzle surface in studs, positive outside. deepest/mean/highest are over the visible vertices; faceDeepest also samples inside every visible triangle. "
            "`skirt` is [deepest, highest] of the edge vertices that are modelled sunk into the head to seal the edge (hidden by design, not counted in the other numbers). "
            "`before` is the shipped rigid move. Same vertex and triangle counts, same x and z per vertex: only the depth (Blender y) changed, so centre and size change in y only. "
            "Items are checked on the Bunny at the Bear position plus bunny.anchorDelta (Bunny anchor minus v2 Bear anchor, Blender axes).",
    "layers": layers,
    "meshes": report,
}
with open(os.path.join(PATCH, "v2-eye-conform.json"), "w", newline="\n") as f: json.dump(out, f, indent=1)
if "--no-save" not in sys.argv:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_mainfile()
print("CONFORMED", len(made), "meshes; saved" if "--no-save" not in sys.argv else "meshes; not saved")
