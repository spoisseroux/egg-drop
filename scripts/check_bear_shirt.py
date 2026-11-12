"""Check the Bear's three-piece shirt (Shirt_Torso, Shirt_SleeveL/R) for clipping, then render it.

Run (background Blender only, the .blend is never saved):
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/check_bear_shirt.py -- [--render]

The arm poses are the game's (GardenPetVisual hand channel): about the shoulder anchor,
CFrame.Angles(-fold, 0, side * (-fold * 0.38 + step * 0.18)), with fold from -35 to +35 degrees.

Checks, per arm:
1. Sleeve wraps the arm: no sleeve face cuts an arm face, the sleeve stays MIN_CLEAR above the arm, and
   its only open edge (the cuff lip) ends under the arm surface. Repeated with arm and sleeve rotated.
2. Arm against torso, every fold pose (step = 0): every point where the arm crosses the torso shell lies
   under the sleeve, and no bare arm below the cuff is under the torso shell.
3. Torso hugs the body: the shell stays between HUG_MIN and HUG_MAX above the body, and it is closed
   behind the sleeves (no armhole edge that a moving sleeve could uncover).
Walking adds the `step` roll, which presses the paw against the belly; that contact is reported, not failed.

Writes artifacts/pet-attachments/shirt-split/shirt-check.json and, with --render, the PNGs beside it.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

REPO = Path(bpy.data.filepath).resolve().parents[3]
OUT = REPO / "artifacts" / "pet-attachments" / "shirt-split"
OUT.mkdir(parents=True, exist_ok=True)
D = bpy.data.objects
MIN_CLEAR, HUG_MIN, HUG_MAX = 0.012, 0.012, 0.030
FOLDS = list(range(-35, 36, 5))


def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


ROOT_INV = world(D["PetBear"]).inverted()


def tris(name):
    o = D[name]
    m = ROOT_INV @ world(o)
    o.data.calc_loop_triangles()
    return [m @ v.co for v in o.data.vertices], [tuple(t.vertices) for t in o.data.loop_triangles]


def signed(bvh, p):
    co, n, _, d = bvh.find_nearest(p)
    return d if (p - co).dot(n) > 0 else -d


def samples(vs, ts, n=10):
    for a, b, c in ts:
        for i in range(n + 1):
            for j in range(n + 1 - i):
                u, v = i / n, j / n
                yield vs[a] * (1 - u - v) + vs[b] * u + vs[c] * v


def pose(fold_deg, side, step=0.0):
    fold = math.radians(fold_deg)
    return Matrix.Rotation(-fold, 3, "X") @ Matrix.Rotation(side * (-fold * 0.38 + step * 0.18), 3, Vector((0, -1, 0)))


def crossings(va, ta, vb, tb):
    """Points where the edges of one triangle set pass through the triangles of the other."""
    pairs = BVHTree.FromPolygons(va, ta).overlap(BVHTree.FromPolygons(vb, tb))
    out = []
    for ia, ib in pairs:
        A, B = [va[i] for i in ta[ia]], [vb[i] for i in tb[ib]]
        for P, Q in ((A, B), (B, A)):
            for k in range(3):
                a, d = P[k], P[(k + 1) % 3] - P[k]
                hit = intersect_ray_tri(Q[0], Q[1], Q[2], d, a, True)
                if hit and 0.0 <= (hit - a).dot(d) <= d.length_squared:
                    out.append(hit)
    return out


body_v, body_t = tris("PetBear__Body")
torso_v, torso_t = tris("PetBear__Shirt_Torso")
body_bvh, torso_bvh = BVHTree.FromPolygons(body_v, body_t), BVHTree.FromPolygons(torso_v, torso_t)
report, ok = {"minClear": MIN_CLEAR, "folds": FOLDS, "sides": {}}, True

# ---------- 3. torso hugs the body, and is closed behind the sleeves ----------
hug = [signed(body_bvh, p) for p in samples(torso_v, torso_t, 4)]
edge_use = {}
for t in torso_t:
    for k in range(3):
        e = tuple(sorted((t[k], t[(k + 1) % 3])))
        edge_use[e] = edge_use.get(e, 0) + 1
open_z = sorted({round(torso_v[i].z, 3) for e, n in edge_use.items() if n == 1 for i in e})
report["torso"] = {"triangles": len(torso_t), "aboveBodyMin": round(min(hug), 4), "aboveBodyMax": round(max(hug), 4),
                   "openEdgeHeights": open_z, "note": "open edges are the hem and the collar only"}
torso_ok = HUG_MIN <= min(hug) and max(hug) <= HUG_MAX and len(open_z) == 2
ok &= torso_ok
report["torso"]["pass"] = torso_ok

for name, side in (("L", -1), ("R", 1)):
    arm_v, arm_t = tris("PetBear__Hand" + name)
    slv_v, slv_t = tris("PetBear__Shirt_Sleeve" + name)
    pivot = (ROOT_INV @ world(D["PetBear__Anchor_Hand" + name])).translation
    origin = (ROOT_INV @ world(D["PetBear__Shirt_Sleeve" + name])).translation
    arm_bvh = BVHTree.FromPolygons(arm_v, arm_t)
    inside = [signed(arm_bvh, v) < 0 for v in slv_v]           # the inner ring of the cuff lip
    lip_t = [t for t in slv_t if any(inside[i] for i in t)]
    shell_t = [t for t in slv_t if not any(inside[i] for i in t)]
    # cuff plane: through the lip, normal pointing down the arm (away from the sleeve)
    lip_i = sorted({i for t in lip_t for i in t})
    centre = sum((slv_v[i] for i in lip_i), Vector()) / len(lip_i)
    normal = sum(((slv_v[b] - slv_v[a]).cross(slv_v[c] - slv_v[a]) for a, b, c in lip_t), Vector())
    normal.normalize()
    middle = sum(slv_v, Vector()) / len(slv_v)
    if (middle - centre).dot(normal) > 0:
        normal = -normal
    flat = max(abs((slv_v[i] - centre).dot(normal)) for i in lip_i)
    under_sleeve = lambda p, eps=0.0: (p - centre).dot(normal) < eps   # rest pose, pet-local

    # 1. sleeve wraps the arm
    cuts = len(BVHTree.FromPolygons(slv_v, shell_t).overlap(arm_bvh))
    clear = min(signed(arm_bvh, p) for p in samples(slv_v, shell_t, 4))
    edges = {}
    for t in slv_t:
        for k in range(3):
            e = tuple(sorted((t[k], t[(k + 1) % 3])))
            edges[e] = edges.get(e, 0) + 1
    open_outside = sum(1 for e, n in edges.items() if n == 1 and not (inside[e[0]] and inside[e[1]]))
    cuff_t = [(slv_v[i] - pivot).length for i in lip_i if not inside[i]]
    rotated_cuts = 0
    for fold in FOLDS:   # arm and sleeve share the channel, so they turn together; proven, not assumed
        R = pose(fold, side)
        turn = lambda vs: [pivot + R @ (v - pivot) for v in vs]
        rotated_cuts += len(BVHTree.FromPolygons(turn(slv_v), shell_t).overlap(BVHTree.FromPolygons(turn(arm_v), arm_t)))
    wrap_ok = cuts == 0 and rotated_cuts == 0 and clear >= MIN_CLEAR and open_outside == 0 and flat < 1e-4

    # 2. arm against the torso shell, per pose
    bare = [p for p in samples(arm_v, arm_t) if not under_sleeve(p, 0.004)]
    poses, pose_ok = [], True
    for step in (0.0, -1.0, 1.0):
        for fold in FOLDS:
            R = pose(fold, side, step)
            Rt = R.transposed()
            turned = [pivot + R @ (v - pivot) for v in arm_v]
            hits = crossings(turned, arm_t, torso_v, torso_t)
            exposed = sum(1 for h in hits if not under_sleeve(pivot + Rt @ (h - pivot), 1e-5))
            depth = min(signed(torso_bvh, pivot + R @ (p - pivot)) for p in bare)
            skin = min(signed(body_bvh, pivot + R @ (p - pivot)) for p in bare)
            row = {"fold": fold, "step": step, "armTorsoCrossings": len(hits), "crossingsOutsideSleeve": exposed,
                   "bareArmAboveTorso": round(depth, 4), "bareArmAboveBody": round(skin, 4)}
            if step == 0.0:
                row["pass"] = exposed == 0 and depth > 0
                pose_ok &= row["pass"]
            poses.append(row)
    fold_rows = [r for r in poses if r["step"] == 0.0]
    gait_rows = [r for r in poses if r["step"] != 0.0]
    report["sides"][name] = {
        "sleeve": "PetBear__Shirt_Sleeve" + name, "triangles": len(slv_t),
        "originOnShoulderAnchor": (origin - pivot).length < 1e-6,
        "wrap": {"sleeveFacesCuttingArm": cuts, "sameAfterRotation": rotated_cuts, "clearanceAboveArm": round(clear, 4),
                 "openEdgesOutsideArm": open_outside, "cuffFromShoulder": [round(min(cuff_t), 3), round(max(cuff_t), 3)],
                 "pass": wrap_ok},
        "foldPoses": {"pass": pose_ok, "worstBareArmAboveTorso": min(r["bareArmAboveTorso"] for r in fold_rows),
                      "crossingsOutsideSleeve": sum(r["crossingsOutsideSleeve"] for r in fold_rows), "rows": fold_rows},
        "walkingContact": {"note": "step roll of +-0.18 rad presses the paw on the belly; reported only",
                           "posesWithBareArmInShirt": sum(1 for r in gait_rows if r["bareArmAboveTorso"] <= 0),
                           "of": len(gait_rows),
                           "deepestIntoShirt": min(r["bareArmAboveTorso"] for r in gait_rows),
                           "deepestIntoBareBody": min(r["bareArmAboveBody"] for r in gait_rows)},
    }
    side_ok = wrap_ok and pose_ok and report["sides"][name]["originOnShoulderAnchor"]
    ok &= side_ok
    print(f"SHIRT {name}: wrap {'ok' if wrap_ok else 'FAIL'} (cuts {cuts}/{rotated_cuts}, clear {clear:.4f}, "
          f"open {open_outside}, cuff {min(cuff_t):.3f}-{max(cuff_t):.3f}), fold poses {'ok' if pose_ok else 'FAIL'} "
          f"(worst {report['sides'][name]['foldPoses']['worstBareArmAboveTorso']}, outside sleeve "
          f"{report['sides'][name]['foldPoses']['crossingsOutsideSleeve']}), walking "
          f"{report['sides'][name]['walkingContact']}")
    for r in fold_rows:
        print("   ", r)

report["pass"] = bool(ok)
print("SHIRT torso:", report["torso"])
(OUT / "shirt-check.json").write_text(json.dumps(report, indent=1), newline="\n")
print("SHIRT CHECK", "PASS" if ok else "FAIL", "->", OUT / "shirt-check.json")

# ---------- renders ----------
if "--render" in sys.argv:
    scene = bpy.context.scene
    keep = {"PetBear__Shirt_Torso", "PetBear__Shirt_SleeveL", "PetBear__Shirt_SleeveR"}
    for o in bpy.data.collections["PetBear_AttachPlaceholders"].objects:
        o.hide_render = o.name not in keep
    for o in bpy.data.collections["MockOnly_HornSizeLineup"].objects:
        o.hide_render = True
    base = world(D["PetBear"]).translation
    cam = bpy.data.objects.new("ShirtCheckCam", bpy.data.cameras.new("ShirtCheckCam"))
    scene.collection.objects.link(cam)
    cam.data.type, cam.data.ortho_scale = "ORTHO", 1.25
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"

    def shot(file, direction, fold=0.0, target=(0, -0.05, 0.56)):
        for name, side in (("L", -1), ("R", 1)):
            anchor = D["PetBear__Anchor_Hand" + name]
            anchor.matrix_basis = Matrix.Translation(anchor.matrix_basis.translation) @ pose(fold, side).to_4x4()
        aim = base + Vector(target)
        d = Vector(direction).normalized()
        cam.location = aim + d * 4
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / file)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", OUT / file)

    shot("shirt-front.png", (0, -1, 0.05))
    shot("shirt-side.png", (-1, -0.02, 0.05))
    shot("shirt-back.png", (0.25, 1, 0.1))
    shot("shirt-arm-raised-front.png", (-0.45, -1, 0.15), 35)
    shot("shirt-arm-raised-side.png", (-1, -0.02, 0.05), 35)
    shot("shirt-arm-back-side.png", (-1, -0.02, 0.05), -35)
    shot("shirt-arm-raised-under.png", (-0.7, -0.6, -0.55), 35)
