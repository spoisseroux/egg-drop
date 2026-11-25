"""Check what was generated from the live walk map against the beta's cliff path, Play Den and terrace top
(architect review): find spots, the Garden Dash course, the ground dressing (flowers, bushes, plates) and the Aero kit's
crowns and rocks. Writes artifacts/qa-2026-11-24-beta16/cliff-den/placement-checks.json: every item inside the den,
in the path's corridor, on rock the path cut away, or over the terrace floor, for the code side's hide list.

  python scripts/cliff_den_checks.py
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "src" / "shared"
ANCHORS = json.loads((ROOT / "assets" / "world" / "world-v7-beta-anchors.json").read_text())
OUT = ROOT / "artifacts" / "qa-2026-11-24-beta16" / "cliff-den" / "placement-checks.json"


def unit(x, z):
    m = math.hypot(x, z)
    return x / m, z / m


C, D = (-60.0, -96.0), unit(-64, 46)
N = (-D[1], D[0])
if N[0] * (-30 - C[0]) + N[1] * (4 - C[1]) < 0:
    N = (D[1], -D[0])


def tier_st(x, z):
    dx, dz = x - C[0], z - C[1]
    return dx * D[0] + dz * D[1], dx * N[0] + dz * N[1]


def inside_polygon(x, z, poly):
    hit = False
    for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
        if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
            hit = not hit
    return hit


def path_near(x, z):
    """(plan distance to the centre line, the path's height and half width there)."""
    best = (1e9, 0.0, 3.0)
    line = ANCHORS["path"]["centreLine"]
    for a, b in zip(line, line[1:]):
        dx, dz = b["x"] - a["x"], b["z"] - a["z"]
        t = max(0.0, min(1.0, ((x - a["x"]) * dx + (z - a["z"]) * dz) / max(1e-9, dx * dx + dz * dz)))
        px, pz = a["x"] + dx * t, a["z"] + dz * t
        d = math.hypot(x - px, z - pz)
        if d < best[0]:
            best = (d, a["y"] + (b["y"] - a["y"]) * t, a["width"] / 2)
    return best


def classify(x, y, z):
    den = ANCHORS["den"]
    outline = [tuple(p) for p in den["outline"]]
    if inside_polygon(x, z, outline) and den["floorY"] - 1 <= y <= den["peakY"] + 1:
        return "den"
    m = den["mouth"]
    if m["x1"] - .5 <= x <= m["x2"] + .5 and m["z"] - .5 <= z <= m["z"] + 5 and y < m["top"] + .5:
        return "den mouth"
    d, h, half = path_near(x, z)
    if d <= half + 1.5 and h - 2 <= y <= h + 5:
        return "path corridor"
    if d <= half + 8 and y > h + .3 and y < h + 16:
        return "path cut (may float or block)"
    s, t = tier_st(x, z)
    if abs(s) <= 38 and abs(t) <= 22 and y > 26:
        return "terrace top"
    return None


def items():
    out = []
    text = (SHARED / "FindSpots.lua").read_text()
    for m in re.finditer(r"lawn=\"(\w+)\",x=(-?\d+),y=(-?\d+),z=(-?\d+)", text):
        out.append(("FindSpots", m.group(1), int(m.group(2)) / 100, int(m.group(3)) / 100, int(m.group(4)) / 100))
    text = (SHARED / "DashCourse.lua").read_text()
    for name, body in re.findall(r"Course\.(\w+)=table\.freeze\(\{(.*?)\}\)", text, re.S):
        nums = [int(v) for v in re.findall(r"-?\d+", body)]
        if len(nums) >= 8 and len(nums) % 4 == 0 and "=" not in body:
            for k in range(0, len(nums), 4):
                out.append(("DashCourse", name, nums[k + 1] / 100, nums[k + 2] / 100, nums[k + 3] / 100))
    for path, label in ((SHARED / "WorldDressing.lua", "WorldDressing"), (SHARED / "GroundDressing.lua", "GroundDressing")):
        text = path.read_text()
        for m in re.finditer(r"\{(-?\d+\.?\d*),(-?\d+\.?\d*),(-?\d+\.?\d*),", text):
            out.append((label, "row", float(m.group(1)), float(m.group(2)), float(m.group(3))))
    kit = json.loads(re.search(r"\[=\[(.*)\]=\]", (SHARED / "WorldAeroKit.lua").read_text(), re.S).group(1))
    for c in kit.get("crowns", []):
        out.append(("AeroKit crown", c.get("tree", "?"), *c["pivot"]))
    for r in kit.get("rocks", []):
        out.append(("AeroKit rock", r.get("kind", "?"), *r["center"]))
    return out


def main():
    found = []
    every = items()
    for source, tag, x, y, z in every:
        where = classify(x, y, z)
        if where:
            found.append({"source": source, "tag": tag, "at": [round(x, 2), round(y, 2), round(z, 2)], "where": where})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checked": len(every), "conflicts": found}, indent=1), encoding="utf-8")
    by = {}
    for f in found:
        by.setdefault((f["source"], f["where"]), 0)
        by[(f["source"], f["where"])] += 1
    print("checked", len(every), "items;", len(found), "conflicts:", {f"{s} / {w}": n for (s, w), n in sorted(by.items())})
    for f in found:
        if f["source"] in ("FindSpots", "AeroKit crown", "AeroKit rock") or f["source"] == "DashCourse":
            print("  ", f)


if __name__ == "__main__":
    main()
