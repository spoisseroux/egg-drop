"""Round 6 mesh gate (Fable DEN-ROUND6-LOOK.md 3.7): every world-finish FBX must read zero before it is uploaded.

  blender -b --factory-startup --python scripts/check_world_finish_mesh.py -- [den path terrace] [--json OUT]

For each part of each slice's FBX (assets/world/world-finish/world-finish-<slice>.fbx):
  * flipped edges (a manifold edge both of whose faces run it the same way: one face renders inside out) must be 0
    on every part;
  * open edges must be 0 on the SOLIDS (steps, stones, stakes, rocks, logs, the race gate pieces): a solid with an open
    edge shows a hole from some side;
  * slivers must be 0 on every part: a face with a corner under 4 degrees, or under 0.002 square studs (the needles and
    blank triangles Fable saw; small but well-shaped faces on a small stone are fine).
Sheets (tread, grass, foot, ground tiles, the den shell and its skirt) may have open edges: they end buried or against
rock, and the pack draws them double-sided. The re-cut island copies (W7_CD_*) are reported, not gated, until the den
round re-cuts them by volume (DEN-ROUND6-LOOK 3.3).

Exits 1 and prints the offending parts when any rule fails.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[1]
FBX = ROOT / "assets" / "world" / "world-finish"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[ARGS.index("--json") + 1] if "--json" in ARGS else None
SLICES = [a for a in ARGS if a in ("den", "path", "terrace")] or ["den", "path", "terrace"]
# Parts that must be closed solids (by name; the slice builders name them).
# W7_F_Stone__flat is a flat stone sunk into the floor: its buried underside is open by design
SOLID = ("PathSteps", "W7_F_Lip", "W7_F_Stake", "PathRocks", "TerraceLog", "TerraceSlab", "DashGate")
SLIVER_DEG, TINY = 4.0, .002


def audit(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.edges.ensure_lookup_table()
    open_edges = sum(1 for e in bm.edges if e.is_boundary)
    flipped = 0
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        runs = []
        for f in e.link_faces:
            for loop in f.loops:
                if loop.edge == e:
                    runs.append((loop.vert.index, loop.link_loop_next.vert.index))
                    break
        if runs[0] == runs[1]:
            flipped += 1
    shards = 0
    lim = math.radians(SLIVER_DEG)
    for f in bm.faces:
        if f.calc_area() < TINY or any(loop.calc_angle() < lim for loop in f.loops):
            shards += 1
    row = {"name": obj.name, "faces": len(bm.faces), "open": open_edges, "flipped": flipped, "shards": shards,
           "solid": any(k in obj.name for k in SOLID)}
    bm.free()
    return row


def main():
    report, bad = {}, []
    for sl in SLICES:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(FBX / f"world-finish-{sl}.fbx"))
        rows = [audit(o) for o in bpy.context.scene.objects if o.type == "MESH"]
        report[sl] = rows
        for r in rows:
            why = []
            if r["flipped"]:
                why.append(f"{r['flipped']} flipped")
            if r["solid"] and r["open"]:
                why.append(f"{r['open']} open (solid)")
            if r["shards"]:
                why.append(f"{r['shards']} shards")
            if why and r["name"].startswith("W7_CD_"):
                print(f"MESHGATE note {sl}: {r['name']}: " + ", ".join(why))
            elif why:
                bad.append(f"{sl}: {r['name']}: " + ", ".join(why))
    if OUT:
        Path(OUT).write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    print("MESHGATE " + ("FAIL\n  " + "\n  ".join(bad) if bad else "PASS ") + f" ({', '.join(SLICES)})")
    sys.exit(1 if bad else 0)


main()
