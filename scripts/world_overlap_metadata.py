"""Compare regenerated world metadata against the captured v634 baseline."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "artifacts/world-overlaps-2026-11-14"
BASE, CURRENT = OUT / "baseline", ROOT / "assets/world"
read = lambda path: json.loads(path.read_text())
old, new = read(BASE / "world-v7-manifest.json"), read(CURRENT / "world-v7-manifest.json")
a, b = ({p["name"]: p for p in data["parts"]} for data in (old, new))
assert a.keys() == b.keys()
delta = {n: {k: [a[n].get(k), b[n].get(k)] for k in set(a[n]) | set(b[n]) if a[n].get(k) != b[n].get(k)}
         for n in a if a[n] != b[n]}
assert all(set(fields) <= {"hash", "tris"} for fields in delta.values())
assert max(p["tris"] for p in new["parts"]) <= 9000
assert (BASE / "world-v7-palette.json").read_bytes() == (CURRENT / "world-v7-palette.json").read_bytes()
w, z = read(BASE / "world-v7-walk.json"), read(CURRENT / "world-v7-walk.json")
assert all(w[k] == z[k] for k in w if k not in {"grid", "surface"})
walk = {}
for key, height_key, tag_key in (("grid", "heights", "hits"), ("surface", "h", "rows")):
    source, target = w[key], z[key]
    assert all(source[k] == target[k] for k in source if k not in {height_key, tag_key})
    rows = []
    for j, row in enumerate(source[height_key]):
        for i, height in enumerate(row):
            tag = source[tag_key][j][i]
            after, after_tag = target[height_key][j][i], target[tag_key][j][i]
            if (height, tag) != (after, after_tag):
                x, zz = source["x0"]+i*source["step"], source["z0"]+j*source["step"]
                assert min((x+36)**2+(zz+52)**2, (x+50)**2+(zz+42)**2) <= 2, ("unexpected topography change", x, zz)
                rows.append(dict(x=x, z=zz, before=[height, tag], after=[after, after_tag]))
    walk[key] = rows
summary = dict(parts_before=old["count"], parts_after=new["count"], triangles_before=old["triangles"],
               triangles_after=new["triangles"], changed_parts=delta, walk_changes=walk,
               palette_unchanged=True, all_bounds_materials_collision_animations_unchanged=True,
               maximum_part_triangles=max(p["tris"] for p in new["parts"]))
(OUT / "generated-metadata-diff.json").write_text(json.dumps(summary, indent=2, sort_keys=True))
print("METADATA PASS", len(delta), "changed of", len(a), "parts; grid", len(walk["grid"]), "surface", len(walk["surface"]), "only cleared trunks")
