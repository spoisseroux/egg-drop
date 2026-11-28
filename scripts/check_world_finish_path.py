"""Check the cliff path art against its walking corridor (WORLD-FINISH-LOOK.md probe 2, the art half), in BACKGROUND
Blender on the scene build_world_finish_art.py path saved (--save):

  blender -b <path-built.blend> --python scripts/check_world_finish_path.py
  python scripts/check_world_finish_path.py --boxes      (no Blender) the path slice's collision boxes in
                                                          src/server/WorldFinishData.lua (beta 42 E21: the foot rocks)

PASS when no drawn rock, lip stone, stake or boulder stands over the tread at body height (0.4 to 5.5 over it, inside the
tread's width less 0.05, sampled at every vertex and face centre; round 7: a lip stone less world_finish_path.LIP_INTRUDE,
as it straddles the edge), the steps' level tops are within 0.8 of the ramp, and
the grass and dirt lie 0.0 to 0.1 over it.

--boxes: every `footrock` box (sampled on a 9 x 9 x 9 grid through its volume) is held to the same rule and to the
stricter one a walking character needs (cliff_den_sculpt.over_tread with the tread's width plus FOOT_MARGIN, 0.3 to 6.5
over it, the rule build_world_finish_pack.foot_boxes trims them by), and it keeps FOOT_MARGIN studs (flat) off the
first flight's tread (plan distance 0 to world_finish_path.FLIGHT1's end).
"""
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import path_offline  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
BOXES = "--boxes" in sys.argv
FOOT_MARGIN = .5    # build_world_finish_pack.FOOT_MARGIN
FLIGHT1_END = 7.2   # world_finish_path.FLIGHT1 (that module needs Blender)
S = path_offline.sculpt()


def corridor(p, edge=.05):
    s = S._nearest(p[0], p[2])
    along = (p[0] - s["x"]) * s["dir"][0] + (p[2] - s["z"]) * s["dir"][1]
    a = (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1]
    return s, abs(along) <= .9 and abs(a) < s["w"] / 2 - edge


def box_points(b, n=9):
    c, h, r = b["c"], [v / 2 for v in b["s"]], b.get("r") or [1, 0, 0, 0, 1, 0, 0, 0, 1]
    for i in range(n):
        for j in range(n):
            for k in range(n):
                lx, ly, lz = (h[0] * (2 * i / (n - 1) - 1), h[1] * (2 * j / (n - 1) - 1), h[2] * (2 * k / (n - 1) - 1))
                yield (c[0] + r[0] * lx + r[1] * ly + r[2] * lz, c[1] + r[3] * lx + r[4] * ly + r[5] * lz,
                       c[2] + r[6] * lx + r[7] * ly + r[8] * lz)


def check_boxes():
    text = (ROOT / "src/server/WorldFinishData.lua").read_text(encoding="utf-8")
    data = json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))
    boxes = [b for b in data["slices"]["path"]["boxes"] if b["kind"] == "footrock"]
    first = [s for s in S.path_samples() if s["d"] <= FLIGHT1_END]
    ok = len(boxes) > 0
    if not boxes:
        print("PATHCHECK no footrock boxes in WorldFinishData's path slice")
    for n, b in enumerate(boxes, 1):
        over, strict, clear = [], [], math.inf
        for q in box_points(b):
            s, inside = corridor(q)
            if inside and .4 < q[1] - s["h"] < 5.5:
                over.append(q)
            if S.over_tread(*q, margin=FOOT_MARGIN):
                strict.append(q)
            for f in first:
                along = (q[0] - f["x"]) * f["dir"][0] + (q[2] - f["z"]) * f["dir"][1]
                a = (q[0] - f["x"]) * f["out"][0] + (q[2] - f["z"]) * f["out"][1]
                if abs(along) <= S.SAMPLE and f["h"] + .3 < q[1] < f["h"] + 6.5:
                    clear = min(clear, abs(a) - f["w"] / 2)
        good = not over and not strict and clear >= FOOT_MARGIN - 1e-6
        ok = ok and good
        print("PATHCHECK footrock %d at (%.1f, %.1f, %.1f) size %s %s: over the tread %d, within the walking margin %d, "
              "clear of the first flight %.2f (need %.2f)" % (n, b["c"][0], b["c"][1], b["c"][2], b["s"],
                                                            "ok" if good else "BAD", len(over), len(strict), clear,
                                                            FOOT_MARGIN))
    print("PATHCHECK boxes", "PASS" if ok else "FAIL")
    return ok


def main():
    import bpy
    import world_finish_lib as L
    import world_finish_path as Pth
    bad = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.hide_render:
            continue
        solid = o.name.startswith(("W7_F_PathWall", "W7_F_PathRocks", "W7_F_PathBacking", "WF_Lip", "WF_Stake",
                                   "WF_Boulder"))
        # round 7 (Fable ROUND7 4): a lip stone straddles the edge and may reach LIP_INTRUDE over the tread (walk > 7)
        edge = Pth.LIP_INTRUDE + .05 if o.name.startswith("WF_Lip") else .05
        surface = o.name.startswith(("W7_F_Path__", "W7_F_PathGrass"))
        if not (solid or surface):
            continue
        mw = o.matrix_world
        pts = [L.rb(mw @ v.co) for v in o.data.vertices] + [L.rb(mw @ p.center) for p in o.data.polygons]
        for q in pts:
            s, inside = corridor(q, edge)
            if not inside:
                continue
            over = q[1] - s["h"]
            if solid and .4 < over < 5.5:
                bad.setdefault(o.name, []).append(tuple(round(v, 2) for v in q))
            if surface and not (-.01 <= over <= .1) and not s["step"] and not 8 <= s["seg"] <= 10:   # (the hairpin: two legs)
                bad.setdefault(o.name + " (off the tread)", []).append(tuple(round(v, 2) for v in q) + (round(over, 2),))
    for name, pts in bad.items():
        print("PATHCHECK over the tread:", name, len(pts), pts[:4])
    report = json.loads((ROOT / "assets/world/world-finish/world-finish-path.json").read_text())["report"]
    dev = report["stepMaxDeviation"]
    print("PATHCHECK step tops vs ramp: max %.3f (allowed 0.8)" % dev)
    print("PATHCHECK", "PASS" if not bad and dev <= .8 else "FAIL")


if __name__ == "__main__":
    if BOXES:
        sys.exit(0 if check_boxes() else 1)
    main()
