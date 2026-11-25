"""Collision tiles for the World 1 v7 ground.

Roblox's PreciseConvexDecomposition of the big merged ground sheets left hulls up to ~0.8 studs above the
lawn, so feet and pets hovered. This makes invisible collision-only meshes instead: the ground chunks are
thickened downward into a closed slab and cut into 32-stud tiles, small enough to decompose tightly.
The visual ground meshes then stop colliding.

Run in BACKGROUND Blender only:
  blender.exe -b assets/art-source/environment/world1-mockup-v7-import.blend --python scripts/build_world_v7_collision.py
Writes assets/world/world-v7-collision.fbx and world-v7-collision.json. The .blend is never saved.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(bpy.data.filepath).resolve().parents[3]
OUT = ROOT / "assets" / "world"
BETA = "--beta" in __import__("sys").argv
TILE = 32.0
THICK = 1.5


def main():
    sources = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Terrain_Ground__")]
    if BETA:
        return beta(sources)
    parts = tiles(sources)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.pop("obj").select_set(True)
        p.pop("cell")
        p.pop("digest")
    bpy.ops.export_scene.fbx(filepath=str(OUT / "world-v7-collision.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE")
    (OUT / "world-v7-collision.json").write_text(json.dumps({"tile": TILE, "thickness": THICK, "parts": parts}, indent=1))
    print("COLLISION", len(parts), sum(p["tris"] for p in parts), max(p["tris"] for p in parts))


def beta(sources):
    """--beta (CLIFF-DEN-ISLAND-SCOPE): the tiles the sculpt changes, under their live numbers (W7C_CD_Ground_NN, the
    tile they replace), new cells numbered on from the last live tile, and the path's smooth ramp (W7C_CD_CliffPath).
    Writes ONLY world-v7-beta-collision.fbx/.json."""
    import sys as _sys
    _sys.path.insert(0, str(Path(__file__).resolve().parent))
    import cliff_den_sculpt as cd
    live = tiles(sources, "live_")
    by_cell = {p["cell"]: p for p in live}
    cd.carve(sources)
    floor = [o for o in cd.build_den(list(bpy.data.objects)) if o.name.startswith("CD_PlayDen__dirt_path")
             or bpy.data.objects.remove(o, do_unlink=True)]
    after = tiles(sources + floor, "beta_")
    next_number = len(live) + 1
    keep = []
    for p in after:
        was = by_cell.get(p["cell"])
        if was is not None and was["digest"] == p["digest"]:
            continue
        if was is not None:
            number, replaces = int(was["name"].rsplit("_", 1)[1]), was["name"]
        else:
            number, replaces = next_number, None
            next_number += 1
        p["obj"].name = p["obj"].data.name = f"W7C_CD_Ground_{number:02d}"
        p["name"], p["replaces"] = p["obj"].name, replaces
        keep.append(p)
    gone = sorted(c for c in by_cell if c not in {p["cell"] for p in after})
    # The den floor answers the server's ground rays (Play Den architect review): rays down from 3 over the floor, over
    # the room, the mouth and the apron, hit the beta's tiles at the floor (4.2) or the lawn (within .6), never nothing.
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()     # the tiles were recentred: refresh their world matrices before casting
    trees = []
    for p in after:
        tb = bmesh.new()
        tb.from_mesh(p["obj"].data)
        tb.transform(p["obj"].matrix_world)
        trees.append(BVHTree.FromBMesh(tb))
        tb.free()
    bad, probes = [], 0
    for x in range(-20, 5):
        for z in range(-117, -88):
            if not (cd.den_floor_plan(x, z) or (cd.MOUTH["x0"] + 1 <= x <= cd.MOUTH["x1"] - 1 and z >= cd.DEN["z1"])):
                continue
            if cd.den_floor_plan(x, z) and not cd.den_inside(x, z, -1.0) and z < cd.DEN["z1"]:
                continue
            probes += 1
            # from 3 over the floor, as a player's or a pet's ground ray (the hill over the room is above this)
            hits = [t.ray_cast(Vector((x, -z, cd.DEN["floor"] + 3 - 4)), Vector((0, 0, -1))) for t in trees]
            ys = [h[0].z + 4 for h in hits if h[0] is not None]
            top = max(ys) if ys else None
            if top is None or abs(top - cd.DEN["floor"]) > .6 or (z > cd.DEN["z1"] + .5 and top > cd.DEN["floor"] + .6):
                bad.append((x, z, None if top is None else round(top, 2)))
    assert not bad, ("den floor / apron rays", bad[:8])
    print("COLLISION BETA den floor rays", probes, "all at the floor")
    ramp = cd.path_collision()
    vs = [v.co for v in ramp.data.vertices]
    lo = Vector([min(v[k] for v in vs) for k in range(3)])
    hi = Vector([max(v[k] for v in vs) for k in range(3)])
    c = (lo + hi) / 2
    ramp.data.transform(__import__("mathutils").Matrix.Translation(-c))
    ramp.location = c
    size = hi - lo
    keep.append({"name": ramp.name, "replaces": None, "obj": ramp, "tris": len(ramp.data.polygons),
                 "center": [round(c.x, 4), round(c.z + 4, 4), round(-c.y, 4)], "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)]})
    bpy.ops.object.select_all(action="DESELECT")
    for p in keep:
        p.pop("obj").select_set(True)
        p.pop("cell", None)
        p.pop("digest", None)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "world-v7-beta-collision.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE")
    removed = [by_cell[c]["name"] for c in gone]
    (OUT / "world-v7-beta-collision.json").write_text(json.dumps({
        "note": "Generated by scripts/build_world_v7_collision.py --beta: tiles the cliff path / Play Den / terrace sculpt "
                "changed (replaces = the live tile) and the path's smooth ramp. removed = live tiles with nothing left.",
        "tile": TILE, "thickness": THICK, "parts": keep, "removed": removed}, indent=1))
    print("COLLISION BETA", [(p["name"], p["replaces"], p["tris"]) for p in keep], "removed", removed)


def tiles(sources, prefix=""):
    bm = bmesh.new()
    for o in sources:
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        tmp.transform(o.matrix_world)
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    # Thicken every face straight down into a closed slab.
    ret = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    down = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=down, vec=Vector((0, 0, -THICK)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    parts = []
    col = bpy.context.scene.collection
    i = 0
    for gx in range(math.floor(x0 / TILE), math.ceil(x1 / TILE)):
        for gy in range(math.floor(y0 / TILE), math.ceil(y1 / TILE)):
            t = bm.copy()
            for co, no in (((gx * TILE, 0, 0), (-1, 0, 0)), (((gx + 1) * TILE, 0, 0), (1, 0, 0)),
                           ((0, gy * TILE, 0), (0, -1, 0)), ((0, (gy + 1) * TILE, 0), (0, 1, 0))):
                geom = t.verts[:] + t.edges[:] + t.faces[:]
                res = bmesh.ops.bisect_plane(t, geom=geom, plane_co=Vector(co), plane_no=Vector(no), clear_outer=True)
                cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
                if cut:
                    bmesh.ops.holes_fill(t, edges=cut, sides=0)
            if len(t.faces) == 0:
                t.free()
                continue
            bmesh.ops.triangulate(t, faces=t.faces[:])
            i += 1
            mesh = bpy.data.meshes.new(f"{prefix}W7C_Ground_{i:02d}")
            t.to_mesh(mesh)
            t.free()
            obj = bpy.data.objects.new(mesh.name, mesh)
            col.objects.link(obj)
            vs = [v.co for v in mesh.vertices]
            lo = Vector([min(v[k] for v in vs) for k in range(3)])
            hi = Vector([max(v[k] for v in vs) for k in range(3)])
            c = (lo + hi) / 2
            mesh.transform(__import__("mathutils").Matrix.Translation(-c))
            obj.location = c
            size = hi - lo
            parts.append({"name": obj.name[len(prefix):], "tris": len(mesh.polygons), "center": [round(c.x, 4), round(c.z + 4, 4), round(-c.y, 4)],
                          "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)]})
            parts[-1]["obj"] = obj
            parts[-1]["cell"] = (gx, gy)
            parts[-1]["digest"] = __import__("hashlib").sha1((";".join(sorted("%.3f,%.3f,%.3f" % tuple(v.co) for v in mesh.vertices))
                                                         + "|area %.2f" % sum(f.area for f in mesh.polygons)).encode()).hexdigest()
            # vertices (order-free) and the surface area: triangulation-proof, and a strip of deleted faces whose corners
            # all survive still moves the area (code review)
            if not prefix:
                obj.name = mesh.name
    bm.free()
    return parts


main()
