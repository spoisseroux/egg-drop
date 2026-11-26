"""Check the cliff path art against its walking corridor (WORLD-FINISH-LOOK.md probe 2, the art half), in BACKGROUND
Blender on the scene build_world_finish_art.py path saved (--save):

  blender -b <path-built.blend> --python scripts/check_world_finish_path.py

PASS when no drawn rock, lip stone, stake or boulder stands over the tread at body height (0.4 to 5.5 over it, inside the
tread's width less 0.05, sampled at every vertex and face centre; round 7: a lip stone less world_finish_path.LIP_INTRUDE,
as it straddles the edge), the steps' level tops are within 0.8 of the ramp, and
the grass and dirt lie 0.0 to 0.1 over it.
"""
import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cliff_den_sculpt as S  # noqa: E402
import world_finish_lib as L  # noqa: E402
import world_finish_path as Pth  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def corridor(p, edge=.05):
    s = S._nearest(p[0], p[2])
    along = (p[0] - s["x"]) * s["dir"][0] + (p[2] - s["z"]) * s["dir"][1]
    a = (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1]
    return s, abs(along) <= .9 and abs(a) < s["w"] / 2 - edge


def main():
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


main()
