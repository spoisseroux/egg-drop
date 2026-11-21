"""Export the v2 "cute" Bear (Fable's pet-bear-v2-cute.blend) for Studio. Read only: no .blend is written.

  blender -b assets/art-source/pets/pet-bear-v2-cute.blend --python assets/art-source/pets/export_bear_v2.py

Writes:
- assets/garden-babies/bear-v2.fbx: one mesh per CHANGED piece (Body, Head, EarL, EarR, Muzzle, Nose,
  MouthSmile, EyeL, EyeR, BlushL, BlushR), named Bear__<piece>, world transforms baked, the bear.fbx
  settings (axis_forward=-Z, axis_up=Y). Hands, feet, inner ears, tail, charms and wings are unchanged
  and keep their live mesh ids.
- assets/garden-babies/bear-textures/bear-eye-cute.png: the eye texture (the blush is the Bunny's
  pet-blush.png byte for byte, so the Bear reuses that image id).
- assets/garden-babies/bear-v2-export.json: centres/sizes/triangles of the exported pieces, the four moved
  anchors (root-local Blender), the unchanged pieces checked against bear-export-manifest.json, and the
  mouth items' gap to the new snout pad against the live one.
"""
import bpy, os, json, shutil
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "garden-babies")
assert os.path.basename(bpy.data.filepath) == "pet-bear-v2-cute.blend", "open pet-bear-v2-cute.blend"
P = "PetBear__"; D = bpy.data.objects
root = D["PetBear"]; root.location = (0, 0, 0)          # in memory only: pet-local = root-local

def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()
def wverts(o): mw = world(o); return [mw @ v.co for v in o.data.vertices]
def bounds(pts): return Vector([min(q[i] for q in pts) for i in range(3)]), Vector([max(q[i] for q in pts) for i in range(3)])
def r5(v): return [round(float(x), 5) + 0.0 for x in v]

CHANGED = ("Body", "Head", "EarL", "EarR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR")
UNCHANGED = ("EarInnerL", "EarInnerR", "Tail", "HandL", "HandR", "FootL", "FootR", "CharmDot")
EXPORT_NAME = {"Mouth": "MouthSmile"}
live = {o["name"]: o for o in json.load(open(os.path.join(OUT, "bear-export-manifest.json")))["objects"]}

report = {"objects": [], "unchanged": {}, "anchorsBlender": {}, "mouthGap": {}}
for n in UNCHANGED:
    lo, hi = bounds(wverts(D[P + n])); c, s = (lo + hi) / 2, hi - lo; L = live["Bear__" + n]
    report["unchanged"][n] = round(max(max(abs(c[i] - L["centerBlender"][i]), abs(s[i] - L["sizeBlender"][i])) for i in range(3)), 6)

scene = bpy.data.scenes.new("BearV2Export"); made = []
for n in CHANGED:
    src = D[P + n]; me = src.data.copy(); me.transform(world(src)); me.update()
    ob = bpy.data.objects.new("Bear__" + EXPORT_NAME.get(n, n), me); scene.collection.objects.link(ob); made.append(ob)
    me.calc_loop_triangles(); lo, hi = bounds([v.co for v in me.vertices])
    report["objects"].append({"name": ob.name, "centerBlender": r5((lo + hi) / 2), "sizeBlender": r5(hi - lo), "triangles": len(me.loop_triangles),
                              "material": src.data.materials[0].name})
bpy.context.window.scene = scene
for o in made: o.select_set(True)
bpy.context.view_layer.objects.active = made[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "bear-v2.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True,
                         use_mesh_modifiers=False, object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO", mesh_smooth_type="FACE")
bpy.context.window.scene = bpy.data.scenes[0]

for n in ("EyeL", "EyeR", "EyeLine", "FaceBridge", "Mouth", "Nose"):
    report["anchorsBlender"][n] = [round(float(x), 6) for x in world(D[P + "Anchor_" + n]).to_translation()]

# Mouth items against the new pad + head, and against the live ones (appended read-only from the live file).
LIVE_BLEND = os.path.join(HERE, "pet-bear-attachments.blend")
with bpy.data.libraries.load(LIVE_BLEND, link=False) as (src, dst):
    dst.objects = [P + "Head", P + "Muzzle"]
def bvh_of(pts, polys): return BVHTree.FromPolygons(pts, polys)
def face_bvhs(head_o, muzzle_o): return [bvh_of(wverts(o), [tuple(p.vertices) for p in o.data.polygons]) for o in (head_o, muzzle_o)]
new_face = face_bvhs(D[P + "Head"], D[P + "Muzzle"])
old_objects = dict(zip(("Head", "Muzzle"), dst.objects))
def old_bvh(piece):
    me = old_objects[piece].data
    mw = world(D[P + piece])            # the live pieces sat under the same anchors with the same transforms
    return bvh_of([mw @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
old_face = [old_bvh("Head"), old_bvh("Muzzle")]
def signed(bvhs, p):
    best = 1e9
    for b in bvhs:
        loc, nrm, _, dist = b.find_nearest(p)
        best = min(best, dist if (p - loc).dot(nrm) >= 0 else -dist)
    return best
for n in ("Mouth_AltW", "Mouth_AltBlep", "Mouth_AltBlep_Tongue", "Mouth", "Nose"):
    o = D.get(P + n)
    if not o: continue
    pts = wverts(o); a = [signed(old_face, p) for p in pts]; b = [signed(new_face, p) for p in pts]
    report["mouthGap"][n] = {"live_deepest": round(min(a), 4), "v2_deepest": round(min(b), 4), "live_mean": round(sum(a) / len(a), 4), "v2_mean": round(sum(b) / len(b), 4)}

# textures
eye = bpy.data.images["petBearEyeCuteTex"]; mouth = bpy.data.images["petBearMouthTex"]
os.makedirs(os.path.join(OUT, "bear-textures"), exist_ok=True)
shutil.copyfile(os.path.join(REPO, "artifacts", "v2-bear-restyle-2026-11-19", "bear-eye-cute.png"), os.path.join(OUT, "bear-textures", "bear-eye-cute.png"))
livemouth = bpy.data.images.load(os.path.join(OUT, "bear-textures", "bear-mouth.png"))
a = np.array(mouth.pixels[:]); b = np.array(livemouth.pixels[:])
report["mouthTextureMatchesLive"] = bool(a.shape == b.shape and np.abs(a - b).max() < 1 / 255)
report["eyeTextureSize"] = list(eye.size)

with open(os.path.join(OUT, "bear-v2-export.json"), "w", newline="\n") as f: json.dump(report, f, indent=1)
print("EXPORT", json.dumps(report, indent=1))
