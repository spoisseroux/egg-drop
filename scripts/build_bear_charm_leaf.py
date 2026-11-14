"""Leaf charm for the Bear (follow-up 2026-11-14): the third earned charm shape (14 stamps).

Run (background Blender only):
  blender -b assets/art-source/pets/pet-bear.blend --python scripts/build_bear_charm_leaf.py
Pass `-- --no-save` to leave the .blend untouched.

Adds `PetBear__CharmDot_AltLeaf` beside the hidden AltHeart / AltStar charms (same parent anchor, same
secondary material, hidden like them) and exports it alone as assets/garden-babies/bear-charm-leaf.fbx,
mesh name `Bear__CharmLeaf`, with the bear.fbx convention (axis_forward=-Z, axis_up=Y, world transform
baked, 1 unit = 1 stud). The mesh is procedural: a 13-point leaf outline with a short stem and a slight
lean, pillowed front and back (rim ring, inset ring, crown vertex). It prints the manifest row for
assets/garden-babies/bear-export-manifest.json. After the Studio import, add the mesh id and MeshSize
to bear-studio-import.json, then run build_bear_attachments.py and build_bear_assets.py.
"""
import bpy, bmesh, json, sys
from pathlib import Path
from mathutils import Vector

REPO = Path(bpy.data.filepath).resolve().parents[3]
OUT = REPO / "assets" / "garden-babies" / "bear-charm-leaf.fbx"
D = bpy.data.objects
NAME = "PetBear__CharmDot_AltLeaf"
heart = D["PetBear__CharmDot_AltHeart"]
anchor = heart.parent

old = D.get(NAME)
if old:
    me = old.data
    D.remove(old, do_unlink=True)
    if me.users == 0:
        bpy.data.meshes.remove(me)

# Half outline (x half-width, z), base to tip, in charm-local units (front -Y, up +Z).
HALF = [(0.011, -0.118), (0.020, -0.084), (0.070, -0.060), (0.094, -0.016), (0.080, 0.030), (0.042, 0.078)]
TIP = (0.0, 0.118)
LEAN = 0.10                                    # the tip leans toward +X
T_RIM, T_IN, T_TOP = 0.0, 0.043, 0.055         # half thickness at the rim, the inset ring and the crown


def lean(x, z):
    return x + LEAN * (z + 0.118) ** 2 / 0.236, z


outline = [lean(x, z) for x, z in HALF] + [lean(*TIP)] + [lean(-x, z) for x, z in reversed(HALF)]
n = len(outline)
cx = sum(p[0] for p in outline[2:-2]) / (n - 4)   # blade centroid (the stem does not pull it down)
cz = sum(p[1] for p in outline[2:-2]) / (n - 4)

bm = bmesh.new()
rim = [bm.verts.new((x, T_RIM, z)) for x, z in outline]
for side in (-1, 1):
    ring = [bm.verts.new((cx + (x - cx) * 0.56, side * T_IN, cz + (z - cz) * 0.56)) for x, z in outline]
    top = bm.verts.new((cx, side * T_TOP, cz))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((rim[i], rim[j], ring[j]))
        bm.faces.new((rim[i], ring[j], ring[i]))
        bm.faces.new((ring[i], ring[j], top))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
for f in bm.faces:
    f.smooth = True
# UVs: the same box projection the other charms get (front view, 0..1 over the bounding box).
uv = bm.loops.layers.uv.new("UVMap")
lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
size = Vector([max(v.co[i] for v in bm.verts) - lo[i] for i in range(3)])
for f in bm.faces:
    for l in f.loops:
        l[uv].uv = ((l.vert.co.x - lo.x) / size.x, (l.vert.co.z - lo.z) / size.z)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me)
bm.free()
for m in heart.data.materials:
    me.materials.append(m)
ob = D.new(NAME, me)
for c in heart.users_collection:
    c.objects.link(ob)
ob.parent = anchor
ob.matrix_parent_inverse = heart.matrix_parent_inverse.copy()
ob.matrix_basis = heart.matrix_basis.copy()
for k, v in heart.items():
    ob[k] = v
ob["variant"] = "Leaf"
ob.hide_viewport = ob.hide_render = True
bpy.context.view_layer.update()

# Export a baked copy from a scratch scene (hidden objects cannot be selected).
world = anchor.matrix_world @ ob.matrix_parent_inverse @ ob.matrix_basis
tmp_me = me.copy()
tmp_me.transform(world)
tmp = D.new("Bear__CharmLeaf", tmp_me)
tmp_me.name = "Bear__CharmLeaf"
scene = bpy.data.scenes.new("LeafExport")
scene.collection.objects.link(tmp)
bpy.context.window.scene = scene
tmp.select_set(True)
bpy.context.view_layer.objects.active = tmp
bpy.ops.export_scene.fbx(filepath=str(OUT), use_selection=True, axis_forward="-Z", axis_up="Y",
                         global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False,
                         object_types={"MESH"}, add_leaf_bones=False, bake_anim=False, path_mode="AUTO",
                         mesh_smooth_type="FACE")
pts = [v.co for v in tmp_me.vertices]
lo = [min(p[i] for p in pts) for i in range(3)]
hi = [max(p[i] for p in pts) for i in range(3)]
tmp_me.calc_loop_triangles()
row = {"name": "Bear__CharmLeaf", "centerBlender": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
       "sizeBlender": [round(hi[i] - lo[i], 5) for i in range(3)], "triangles": len(tmp_me.loop_triangles)}
print("LEAF_ROW " + json.dumps(row))
first = next(s for s in bpy.data.scenes if s != scene)
bpy.context.window.scene = first
bpy.data.scenes.remove(scene)
D.remove(tmp, do_unlink=True)
bpy.data.meshes.remove(tmp_me)

if "--no-save" not in sys.argv:
    bpy.context.preferences.filepaths.save_version = 0      # no .blend1 beside the source
    bpy.ops.wm.save_mainfile()
    print("saved", bpy.data.filepath)
