"""Coplanar-overlap scan of the World 1 v7 import chunks (the z-fight finder behind QA R5.4).

Run in BACKGROUND Blender only:
  blender.exe -b assets/art-source/environment/world1-mockup-v7-import.blend --python scripts/scan_world_v7_coplanar.py [-- regex [--detail]]
Reports every pair of same-plane faces whose outlines overlap, grouped by chunk pair, with the overlap
area and the Roblox-space bounds (Blender (x, y, z) = Roblox (x, z + 4, -y)). Only pairs with at least
one face in a chunk matching the regex (default: built structures) are listed. Read-only.
With --fixed the declutter and qa_fixes of scripts/build_world_v7_chunks.py are applied in memory first (nothing is
saved or exported), so the scan shows what the merged meshes will really contain.
"""
import re
import sys
import time
from collections import defaultdict

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PAT = re.compile(ARGS[0] if ARGS else r"Arch|Aqueduct|Colonn|Rotunda|Landmark|Bridge|Balustr|Station|Prop", re.I)
DETAIL = "--detail" in ARGS                   # list each same-facing pair (opposite-facing contacts are hidden)
CELL, EPS = 4.0, 1e-4


def clip(subject, clipper):
    """Sutherland-Hodgman: subject polygon clipped by a convex clipper (2D, either winding)."""
    area2 = sum(clipper[i][0] * clipper[(i + 1) % len(clipper)][1] - clipper[(i + 1) % len(clipper)][0] * clipper[i][1] for i in range(len(clipper)))
    if area2 < 0:
        clipper = clipper[::-1]
    out = subject
    for i in range(len(clipper)):
        a, b = clipper[i], clipper[(i + 1) % len(clipper)]
        inp, out = out, []
        if not inp:
            break
        ex, ey = b[0] - a[0], b[1] - a[1]
        side = lambda p: ex * (p[1] - a[1]) - ey * (p[0] - a[0])
        for j in range(len(inp)):
            p, q = inp[j], inp[(j + 1) % len(inp)]
            sp, sq = side(p), side(q)
            if sp >= 0:
                out.append(p)
            if (sp >= 0) != (sq >= 0):
                t = sp / (sp - sq)
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def area(poly):
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2


OBJECTS = list(bpy.data.objects)
if "--fixed" in ARGS:
    from pathlib import Path
    _src = Path(__file__).with_name("build_world_v7_chunks.py").read_text(encoding="utf-8")
    _ns = {"__name__": "world_v7_chunks", "__file__": str(Path(__file__).with_name("build_world_v7_chunks.py"))}
    exec(compile(_src.rsplit(chr(10) + "main()", 1)[0], _ns["__file__"], "exec"), _ns)
    OBJECTS = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
    OBJECTS = _ns["qa_fixes"](_ns["declutter"](OBJECTS))
t0 = time.time()
planes = defaultdict(list)
names = []
for o in OBJECTS:
    if o.type != "MESH":
        continue
    oi = len(names)
    names.append(o.name)
    mw = o.matrix_world
    vs = [mw @ v.co for v in o.data.vertices]
    for p in o.data.polygons:
        n = (mw.to_3x3() @ p.normal).normalized()
        if p.area < 1e-5:
            continue
        k = [round(n.x, 2), round(n.y, 2), round(n.z, 2)]
        lead = next((c for c in k if c != 0), 0)
        sgn = -1 if lead < 0 else 1
        co = [vs[i] for i in p.vertices]
        d = n.dot(co[0]) * sgn
        planes[(k[0] * sgn + 0.0, k[1] * sgn + 0.0, k[2] * sgn + 0.0, round(d, 2))].append((oi, p.index, co, n * sgn, sgn))
pairs = defaultdict(lambda: [0, 0.0, [1e9] * 3, [-1e9] * 3, 0])
for key, faces in planes.items():
    if len(faces) < 2:
        continue
    n = faces[0][3]
    ax = min(range(3), key=lambda i: abs(n[i]))
    u = n.cross([(1, 0, 0), (0, 1, 0), (0, 0, 1)][ax]).normalized()
    v = n.cross(u)
    flat = [[(c.dot(u), c.dot(v)) for c in f[2]] for f in faces]
    grid = defaultdict(list)
    for i, poly in enumerate(flat):
        x0, x1 = min(p[0] for p in poly), max(p[0] for p in poly)
        y0, y1 = min(p[1] for p in poly), max(p[1] for p in poly)
        for gx in range(int(x0 // CELL), int(x1 // CELL) + 1):
            for gy in range(int(y0 // CELL), int(y1 // CELL) + 1):
                grid[(gx, gy)].append(i)
    seen = set()
    for cell in grid.values():
        for a in range(len(cell)):
            for b in range(a + 1, len(cell)):
                i, j = cell[a], cell[b]
                if (i, j) in seen:
                    continue
                seen.add((i, j))
                fi, fj = faces[i], faces[j]
                if not (PAT.search(names[fi[0]]) or PAT.search(names[fj[0]])):
                    continue
                ov = clip(flat[i], flat[j])
                ar = area(ov) if len(ov) >= 3 else 0.0
                if ar < EPS:
                    continue
                same = fi[4] == fj[4]                    # both faces look the same way: an exposed z-fight
                if DETAIL and same:
                    c = fi[2][0]
                    print("SAME %s#%d (%.2f) | %s#%d (%.2f) | overlap %.3f | n (%.0f,%.0f,%.0f) | roblox (%.2f, %.2f, %.2f)" % (
                        names[fi[0]], fi[1], area(flat[i]), names[fj[0]], fj[1], area(flat[j]), ar, n.x * fi[4], n.z * fi[4], -n.y * fi[4], c.x, c.z + 4, -c.y))
                if DETAIL and not same:
                    continue
                rec = pairs[tuple(sorted((names[fi[0]], names[fj[0]])))]
                rec[0] += 1
                rec[1] += ar
                rec[4] += 1 if set(map(lambda c: (round(c.x, 3), round(c.y, 3), round(c.z, 3)), fi[2])) == set(map(lambda c: (round(c.x, 3), round(c.y, 3), round(c.z, 3)), fj[2])) else 0
                for c in fi[2] + fj[2]:
                    r = (c.x, c.z + 4, -c.y)
                    for q in range(3):
                        rec[2][q] = min(rec[2][q], r[q])
                        rec[3][q] = max(rec[3][q], r[q])
print("SCAN chunks", len(names), "planes", len(planes), "secs", round(time.time() - t0, 1))
for (a, b), (cnt, ar, lo, hi, twins) in sorted(pairs.items(), key=lambda kv: -kv[1][1]):
    print("PAIR %s | %s | faces %d twins %d area %.2f | roblox lo (%.1f, %.1f, %.1f) hi (%.1f, %.1f, %.1f)" % (a, b, cnt, twins, ar, *lo, *hi))
