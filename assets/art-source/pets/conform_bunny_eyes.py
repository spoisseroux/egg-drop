"""Conform the Bunny's own eyes and blush to its head, through every pose the face takes. Opus, 2026-11-24 (beta 16 B4).

  blender -b assets/art-source/pets/pet-bunny.blend --python assets/art-source/pets/conform_bunny_eyes.py
  (add `-- --no-save` to measure and export without saving the .blend)

Why: Spencer saw the Bunny's eye on the viewer's right sink into the head at its outer edge. The 2026-11-21 conform
(conform_bear_v2_eyes.py) fixed the Bear's own eyes and the shared eye/cheek items, never the Bunny's own EyeL, EyeR,
BlushL and BlushR. Measured on the shipped meshes: at rest the eyes clear the head (vertices +0.005, faces +0.0039),
but the curious glance (GardenPetVisual: both eyes slide .018 sideways, toward runtime -X) carries EyeR inward onto
the steeper part of the round head and its outer edge goes under the surface (faces -0.0066, 11% of the eye). The
blush halves already dip under the head's facets at rest (faces -0.0009 / -0.0013).

The runtime half of the fix (same commit): the glance now turns the eyes round the head's upright axis through the
Head piece's centre (same sideways travel), so they ride the curve. This script makes the meshes clear the head in
that glance too, in both directions (the pair stays mirror-symmetric), and in the wide-eyed startled pose
(Size X 1.12, Y 1.36), on top of rest. Per vertex it keeps x and z (the outline seen from the front does not
change) and only brings the vertex forward (Blender -Y) until every vertex is MIN_VERT and every face sample
MIN_FACE clear of the Head + Muzzle surface in every pose. Nothing else moves: anchors, the other 15 pieces, sizes
in x and z, UVs and textures are unchanged.

Not covered (the same on the Bear and every eye item, unchanged): a squint (eye Size Y under 1: pleased, joy,
content, dozy, sleepy, affectionate, blinks) scales the eye toward its centre, so its lower rim moves up the face
and tucks under the head. Clearing that would float the rim about .03 off the head at rest.

Each conformed mesh keeps its shipped shape in the point attribute `pre_conform`, so a rerun gives the same result.

Writes:
- assets/art-source/pets/bunny-export/bunny-eye-conform.fbx   Bunny__EyeL, EyeR, BlushL, BlushR only (the upload)
- assets/art-source/pets/bunny-export/bunny.fbx                every piece again, so the full export matches the .blend
- assets/art-source/pets/bunny-export/bunny-eye-conform.json   depth numbers per pose, new bounds
- bunny-export-manifest.json and bunny-rig-proposal.lua: the four pieces' centre and size (depth only changes)
Same FBX settings as build_bunny.py (axis_forward=-Z, axis_up=Y, world transform baked, pet root at the origin).
"""
import bpy, os, sys, json, math, re
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "bunny-export")
assert os.path.basename(bpy.data.filepath) == "pet-bunny.blend", "open pet-bunny.blend"
MIN_VERT, MIN_FACE = 0.005, 0.0035                    # the Bear conform's clearances
GLANCE_X, GLANCE_UP, GLANCE_EYE = .018, .01, 1.16     # GardenPetVisual: curious glance and eye height
D = bpy.data.objects; P = "PetBunny__"
EYES, BLUSH = ("EyeL", "EyeR"), ("BlushL", "BlushR")


def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


def r5(v): return [round(float(x), 5) + 0.0 for x in v]


root = D["PetBunny"]; RL = world(root).inverted()
def rl(o): return RL @ world(o)
def tris_of(o): o.data.calc_loop_triangles(); return [tuple(t.vertices) for t in o.data.loop_triangles]

hv, hp = [], []
for n in ("Head", "Muzzle"):
    o = D[P + n]; M = rl(o); b = len(hv)
    hv += [M @ v.co for v in o.data.vertices]; hp += [tuple(b + i for i in t) for t in tris_of(o)]
TREE = BVHTree.FromPolygons(hv, hp)
head_pts = [rl(D[P + "Head"]) @ v.co for v in D[P + "Head"].data.vertices]
HC = Vector([(min(p[i] for p in head_pts) + max(p[i] for p in head_pts)) / 2 for i in range(3)])   # = the Head piece's centre


def height(p):
    """Signed distance to the head + snout pad: positive outside."""
    _, _, _, dist = TREE.find_nearest(p)
    hit = TREE.ray_cast(Vector((p.x, -3.0, p.z)), Vector((0, 1, 0)))
    return dist if (hit[0] is None or p.y < hit[0].y) else -dist


def bbox_centre(pts): return Vector([(min(p[i] for p in pts) + max(p[i] for p in pts)) / 2 for i in range(3)])


def poses_for(short, c):
    """Pose name -> function(point) in the Bunny's root frame, with the eye's part centre c (Blender axes)."""
    out = {"rest": lambda p: p}
    if short not in EYES: return out
    reach = HC.y - c.y                                 # runtime: eye part Z minus Head centre Z (front +Z = Blender -Y)
    for sign, tag in ((-1, "glanceRuntime"), (1, "glanceMirror")):
        th = math.asin(sign * GLANCE_X / reach); R = Matrix.Rotation(th, 4, "Z"); pivot = Vector((HC.x, HC.y, 0))
        def glance(p, R=R, pivot=pivot):
            q = Vector((p.x, p.y, c.z + (p.z - c.z) * GLANCE_EYE + GLANCE_UP))
            return pivot + R @ (q - pivot)
        out[tag] = glance
    out["startled"] = lambda p: Vector((c.x + (p.x - c.x) * 1.12, p.y, c.z + (p.z - c.z) * 1.36))
    return out


def samples(pts, tris, n=6):
    out = []
    for t in tris:
        a, b, cc = (pts[i] for i in t)
        for i in range(n + 1):
            for j in range(n + 1 - i):
                if (i, j) not in ((0, 0), (n, 0), (0, n)): out.append((t, (a * i + b * j + cc * (n - i - j)) / n, (i / n, j / n, (n - i - j) / n)))
    return out


def depth(pts, tris, f):
    hv_ = [height(f(p)) for p in pts]; hf = [height(f(q)) for _, q, _ in samples(pts, tris)]
    return {"deepest": round(min(hv_), 4), "mean": round(sum(hv_) / len(hv_), 4), "faceDeepest": round(min(hf + hv_), 4),
            "facesUnder": round(sum(1 for h in hf if h < 0) / len(hf), 3)}


def straight_glance(c):
    """The glance as shipped (a straight slide), for the before numbers."""
    return lambda p: Vector((p.x - GLANCE_X, p.y, c.z + (p.z - c.z) * GLANCE_EYE + GLANCE_UP))


report, made, pre_c = [], [], {}
for short in EYES + BLUSH:
    o = D[P + short]; me = o.data; M = rl(o); Minv = M.inverted(); tris = tris_of(o)
    att = me.attributes.get("pre_conform")
    pre = [M @ Vector(a.vector) for a in att.data] if att else [M @ v.co for v in me.vertices]
    c = bbox_centre(pre); pre_c[short] = c; poses = poses_for(short, c)
    extra = [0.0] * len(pre)
    place = lambda: [Vector((p.x, p.y - e, p.z)) for p, e in zip(pre, extra)]
    pts = place()
    for _ in range(120):
        moved = False
        for i, p in enumerate(pts):
            low = min(height(f(p)) for f in poses.values())
            if low < MIN_VERT: extra[i] += (MIN_VERT - low) * 1.25 + 1e-5; moved = True
        if moved: pts = place(); continue
        worst = {}
        for t, q, w in samples(pts, tris):
            low = min(height(f(q)) for f in poses.values())
            if low < MIN_FACE:
                for k in range(3): worst[t[k]] = max(worst.get(t[k], 0.0), MIN_FACE - low)
        if not worst: break
        for i, need in worst.items(): extra[i] += need * 0.6 + 1e-5
        pts = place()
    else:
        raise RuntimeError("did not settle: " + short)
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); nc, s = (lo + hi) / 2, hi - lo
    row = {"name": "Bunny__" + short, "source": o.name, "vertices": len(pts), "triangles": len(tris),
           "nudgedVertices": sum(1 for e in extra if e > 0), "largestMove": round(max(extra), 4), "meanMove": round(sum(extra) / len(extra), 4),
           "poses": {}, "centerBlender": r5(nc), "sizeBlender": r5(s), "centerRuntime": r5((nc.x, nc.z, -nc.y)), "sizeRuntime": r5((s.x, s.z, s.y))}
    for name, f in poses.items():
        row["poses"][name] = {"before": depth(pre, tris, f), "after": depth(pts, tris, f)}
    if short in EYES:
        row["poses"]["glanceShippedSlide"] = {"before": depth(pre, tris, straight_glance(c)), "after": depth(pts, tris, straight_glance(nc))}
    report.append(row)
    att = me.attributes.get("pre_conform") or me.attributes.new("pre_conform", "FLOAT_VECTOR", "POINT")
    for a, p in zip(att.data, pre): a.vector = Minv @ p
    for v, p in zip(me.vertices, pts): v.co = Minv @ p
    me.update(); o["conformed"] = "Bunny head through rest, glance and startled, 2026-11-24 (conform_bunny_eyes.py)"
    made.append(short)
    print("CONFORM %-7s moved %d/%d max %.4f |" % (short, row["nudgedVertices"], len(pts), row["largestMove"]),
          " ".join("%s %+.4f->%+.4f" % (k, v["before"]["faceDeepest"], v["after"]["faceDeepest"]) for k, v in row["poses"].items()))

# ---------- export: the patch (four pieces) and the full bunny.fbx, build_bunny.py's settings ----------
EXPORT_NAME = {"Mouth": "MouthSmile"}
FULL = ("Body", "Head", "EarL", "EarR", "EarInnerL", "EarInnerR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR", "Tail",
        "HandL", "HandR", "FootL", "FootR", "CharmDot")
def export(path, names):
    scene = bpy.data.scenes.new("BunnyConformExport"); objs = []
    for n in names:
        src = D[P + n]; me = src.data.copy(); me.transform(rl(src)); me.update()      # root-local: the root at the origin
        if me.attributes.get("pre_conform"): me.attributes.remove(me.attributes["pre_conform"])
        ob = bpy.data.objects.new("Bunny__" + EXPORT_NAME.get(n, n), me); scene.collection.objects.link(ob); objs.append(ob)
    bpy.context.window.scene = scene
    for ob in objs: ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True,
                             use_mesh_modifiers=False, object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO", mesh_smooth_type="FACE")
    bpy.context.window.scene = bpy.data.scenes[0]
    for ob in objs:
        me = ob.data; bpy.data.objects.remove(ob, do_unlink=True); bpy.data.meshes.remove(me)
    bpy.data.scenes.remove(scene)
export(os.path.join(EXPORT, "bunny-eye-conform.fbx"), made)
export(os.path.join(EXPORT, "bunny.fbx"), FULL)

# ---------- the four pieces' bounds in the export manifest and the rig proposal ----------
mpath = os.path.join(EXPORT, "bunny-export-manifest.json"); man = json.load(open(mpath))
by = {r["name"]: r for r in report}
for ob in man["objects"]:
    if ob["name"] in by: ob["centerBlender"], ob["sizeBlender"] = by[ob["name"]]["centerBlender"], by[ob["name"]]["sizeBlender"]
man["eyeConform"] = "2026-11-24: EyeL, EyeR, BlushL, BlushR conformed by conform_bunny_eyes.py (depth only); patch bunny-eye-conform.fbx"
with open(mpath, "w") as f: json.dump(man, f, indent=1)
ppath = os.path.join(HERE, "bunny-rig-proposal.lua"); text = open(ppath, encoding="utf-8").read()
def num(x): return repr(round(x, 5) + 0.0)
for r in report:
    short = r["name"][len("Bunny__"):]
    pat = re.compile(r'(\{name = "%s", channel = "Head", shape = "ellipsoid", center = )\{[^}]*\}(, size = )\{[^}]*\}' % short)
    sz = [round(r["sizeBlender"][0], 5), round(r["sizeBlender"][2], 5), round(r["sizeBlender"][1], 5)]
    text, n = pat.subn(lambda m: m.group(1) + "{%s}" % ", ".join(num(x) for x in r["centerRuntime"]) + m.group(2) + "{%s}" % ", ".join(num(x) for x in sz), text)
    assert n == 1, short
with open(ppath, "w", encoding="utf-8", newline="\n") as f: f.write(text)

out = {"schema": 1, "date": "2026-11-24", "builtBy": "assets/art-source/pets/conform_bunny_eyes.py", "sourceBlend": "assets/art-source/pets/pet-bunny.blend",
       "fbx": "assets/art-source/pets/bunny-export/bunny-eye-conform.fbx", "minVertexHeight": MIN_VERT, "minFaceHeight": MIN_FACE,
       "headCentreBlender": r5(HC), "glance": {"sideways": GLANCE_X, "up": GLANCE_UP, "eyeHeight": GLANCE_EYE,
       "how": "turn round the upright axis through the Head centre (GardenPetVisual, 2026-11-24); glanceRuntime is the direction the game uses, glanceMirror the other"},
       "note": "Heights are distances to the Head + Muzzle surface in studs, positive outside; deepest/mean over vertices, faceDeepest also samples inside every triangle, "
               "facesUnder is the share of face samples under the head. before = the shipped mesh. glanceShippedSlide is the old straight slide, for comparison. "
               "Only Blender y (depth) changed per vertex.",
       "meshes": report}
with open(os.path.join(EXPORT, "bunny-eye-conform.json"), "w", newline="\n") as f: json.dump(out, f, indent=1)
if "--no-save" not in sys.argv:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_mainfile()
print("CONFORMED", len(made), "meshes;", "saved" if "--no-save" not in sys.argv else "not saved")
