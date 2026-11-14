"""Read-only near-plane candidate measurements before any near-plane repair."""
import importlib.util
import json
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "artifacts/world-overlaps-2026-11-14"
src = (HERE / "build_world_v7_chunks.py").read_text(encoding="utf-8")
ns = {"__file__": str(HERE / "build_world_v7_chunks.py"), "__name__": "nearplane_chunks"}
exec(compile(src.rsplit("\nmain()", 1)[0], ns["__file__"], "exec"), ns)
sources = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
sources = ns["qa_fixes"](ns["declutter"](sources), remaining=False)
spec = importlib.util.spec_from_file_location("world_overlap_geometry", HERE / "world_overlap_geometry.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
rows = [helper.payload(p) for p in helper.candidates(helper.records(sources))]
(OUT / "near-plane-measurements.json").write_text(json.dumps(rows, indent=2))
near = [p for p in rows if not p["confirmed"]]
cross = [p for p in near if max(p["a_to_b_signed_range"])-min(p["a_to_b_signed_range"]) > 1e-4 or
         max(p["b_to_a_signed_range"])-min(p["b_to_a_signed_range"]) > 1e-4]
print("NEARPLANES", len(near), "variable-plane gaps", len(cross))
for p in cross:
    print("VARIABLE", json.dumps(p))
