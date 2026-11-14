"""In-memory before/after diagnostic; never saves .blend or generated world assets."""
import importlib.util
import json
import os
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = ROOT / "artifacts/world-overlaps-2026-11-14"
src = (HERE / "build_world_v7_chunks.py").read_text(encoding="utf-8")
ns = {"__file__": str(HERE / "build_world_v7_chunks.py"), "__name__": "probe_chunks"}
exec(compile(src.rsplit("\nmain()", 1)[0], ns["__file__"], "exec"), ns)
sources = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
sources = ns["qa_fixes"](ns["declutter"](sources), remaining=False)
spec = importlib.util.spec_from_file_location("world_overlap_geometry", HERE / "world_overlap_geometry.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def stats():
    out = {}
    for o in sources:
        lo, hi = ns["centre_of"](o)
        out[o.name] = dict(hash=ns["geom_hash"](o), vertices=len(o.data.vertices),
                           polygons=len(o.data.polygons), tris=ns["tris"](o),
                           lo=list(lo), hi=list(hi), materials=[m.name for m in o.data.materials],
                           custom_normals=o.data.has_custom_normals,
                           uv_layers=list(o.data.uv_layers.keys()),
                           colors=[(a.name, a.domain, a.data_type) for a in o.data.color_attributes])
    return out


before = stats()
helper.self_test()
changed, ledger = helper.fix(sources, OUT)
after = stats()
delta = {n: dict(before=before[n], after=after[n]) for n in before if before[n] != after[n]}
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "chunk-metadata-diff.json").write_text(json.dumps(delta, indent=2))
assert set(delta) == changed, (set(delta), changed)
assert all(max(abs(a-b) for a,b in zip(before[n]["lo"] + before[n]["hi"], after[n]["lo"] + after[n]["hi"])) < 1e-5 for n in changed)
assert all(before[n]["materials"] == after[n]["materials"] for n in changed)
print("PROBE PASS changed", len(delta), "unchanged", len(before) - len(delta))
