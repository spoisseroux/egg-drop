"""Read-only original-object survey for the approved second park clearing."""
import json
from pathlib import Path
import bpy

OUT = Path(__file__).resolve().parent.parent / "artifacts/world-overlaps-2026-11-14"
rows = []
for o in bpy.data.objects:
    if o.type != "MESH" or not (o.name.startswith("Tree_") or o.name.startswith("Bush_")):
        continue
    by_mat = {}
    for p in o.data.polygons:
        name = o.data.materials[p.material_index].name
        by_mat.setdefault(name, []).extend(o.matrix_world @ o.data.vertices[i].co for i in p.vertices)
    all_pts = [q for points in by_mat.values() for q in points]
    if not any(((p.x + 38) / 24) ** 2 + ((-p.y + 46) / 20) ** 2 < 1 for p in all_pts):
        continue
    mats = {}
    for n, points in by_mat.items():
        rb = [(p.x, p.z + 4, -p.y) for p in points]
        mats[n] = dict(lo=[min(p[k] for p in rb) for k in range(3)], hi=[max(p[k] for p in rb) for k in range(3)],
                       clearance_hits=sum(((p[0] + 38) / 18) ** 2 + ((p[2] + 46) / 13) ** 2 <= 1 for p in rb))
    rows.append(dict(name=o.name, polygons=len(o.data.polygons), materials=mats))
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "vegetation-survey.json").write_text(json.dumps(rows, indent=2))
for row in rows:
    print("VEGETATION", row["name"], row["polygons"], json.dumps(row["materials"]))
