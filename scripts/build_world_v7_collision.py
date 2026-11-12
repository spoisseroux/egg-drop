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
TILE = 32.0
THICK = 1.5


def main():
    sources = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Terrain_Ground__")]
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
            mesh = bpy.data.meshes.new(f"W7C_Ground_{i:02d}")
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
            parts.append({"name": obj.name, "tris": len(mesh.polygons), "center": [round(c.x, 4), round(c.z + 4, 4), round(-c.y, 4)],
                          "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)]})
            parts[-1]["obj"] = obj
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.pop("obj").select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "world-v7-collision.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE")
    (OUT / "world-v7-collision.json").write_text(json.dumps({"tile": TILE, "thickness": THICK, "parts": parts}, indent=1))
    print("COLLISION", len(parts), sum(p["tris"] for p in parts), max(p["tris"] for p in parts))


main()
