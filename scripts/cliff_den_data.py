"""Write src/shared/CliffDenData.lua: the beta's cliff path / Play Den / terrace top contract (CLIFF-DEN-ISLAND-SCOPE).

Plain Python. Reads the --beta outputs (world-v7-beta-manifest.json, world-v7-beta-collision.json,
world-v7-beta-walk.json, world-v7-beta-anchors.json) and the live island's data (src/shared/WorldV7Data.lua,
assets/world/world-v7-walk.json), never writes either.

  blender -b <import.blend> --python scripts/build_world_v7_chunks.py -- --beta --beta-base   (the baseline walk map)
  blender -b <import.blend> --python scripts/build_world_v7_chunks.py -- --beta                (the sculpted island)
  python scripts/cliff_den_data.py           write the module
  python scripts/cliff_den_data.py --check   fail if the module is stale (or the live island moved under it)

The module (world studs, as WorldV7Data):
  version, live = {worldV7Data, walk}     sha256 (LF-normalised) of the live files the patch was made against: a live
                                          re-export makes it stale (scripts/cliff_den_data_test.py)
  swap = {{hide, show}, ...}              swap at server start on the beta place (LoungeWorldV7Art.meshes, before the
                                          clone); show = nil: a new part, hide = nil: none
  parts[name] = {region, collide, center, size[, motion]}   every shown part (carved copies keep their live entry's
                                          region and motion: the crystals pulse)
  den, path, terrace, evacuate            anchors (cliff_den_sculpt.anchors)
  caveBlocker = false                     the den has walls
  ground = {i (1-based, row-major as WorldV7Data.ground.h), h}   the 4-stud bare-ground patch
  walk = {grid = {{i, j, h}}, surface = {{i, j, code, h}}}  the 2-stud height grid and 1-stud surface map patches
                                          (0-based cell indices, as world-v7-walk.json)
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "assets" / "world"
OUT = ROOT / "src" / "shared" / "CliffDenData.lua"
VERSION = 1


def sha_text(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def live_data():
    text = (ROOT / "src" / "shared" / "WorldV7Data.lua").read_text(encoding="utf-8")
    return json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))


def r(v, n=3):
    return round(v, n) if isinstance(v, float) else v


def build():
    manifest = json.loads((WORLD / "world-v7-beta-manifest.json").read_text())
    collision = json.loads((WORLD / "world-v7-beta-collision.json").read_text())
    anchors = json.loads((WORLD / "world-v7-beta-anchors.json").read_text())
    beta_walk = json.loads((WORLD / "world-v7-beta-walk.json").read_text())
    live_walk = json.loads((WORLD / "world-v7-beta-base-walk.json").read_text())   # same builder, no sculpt
    live = live_data()
    swap, parts = [], {}
    for e in manifest["parts"]:
        if e["replaces"] is not None:
            was = live["parts"][e["replaces"]]
            entry = {"region": was["region"], "collide": was["collide"]}
            if "motion" in was:
                entry["motion"] = was["motion"]
        else:
            entry = {"region": e["region"], "collide": e["collide"]}
        entry.update(center=e["center"], size=e["size"])
        parts[e["name"]] = entry
        swap.append({"hide": e["replaces"], "show": e["name"]})
    for e in collision["parts"]:
        parts[e["name"]] = {"region": "GroundCollision", "collide": True, "center": e["center"], "size": e["size"]}
        swap.append({"hide": e["replaces"], "show": e["name"]})
    for name in collision["removed"]:
        swap.append({"hide": name, "show": None})
    # The 4-stud bare ground (WorldV7Data.ground.h is row-major with -999 for none).
    ground = []
    lg, bg = live_walk["ground"], beta_walk["ground"]
    for j in range(lg["nz"]):
        for i in range(lg["nx"]):
            a, b = lg["heights"][j][i], bg["heights"][j][i]
            if (a is None) != (b is None) or (a is not None and abs(a - b) > .02):
                ground.append([j * lg["nx"] + i + 1, -999 if b is None else b])
    grid = []
    lg, bg = live_walk["grid"], beta_walk["grid"]
    for j in range(lg["nz"]):
        for i in range(lg["nx"]):
            a, b = lg["heights"][j][i], bg["heights"][j][i]
            if (a is None) != (b is None) or (a is not None and abs(a - b) > .02):
                grid.append([i, j, -999 if bg["heights"][j][i] is None else bg["heights"][j][i]])
    surface = []
    ls, bs = live_walk["surface"], beta_walk["surface"]
    for j in range(ls["nz"]):
        for i in range(ls["nx"]):
            if ls["rows"][j][i] != bs["rows"][j][i] or abs(ls["h"][j][i] - bs["h"][j][i]) > .02:
                surface.append([i, j, bs["rows"][j][i], bs["h"][j][i]])
    data = {
        "version": VERSION,
        "live": {"worldV7Data": sha_text(ROOT / "src" / "shared" / "WorldV7Data.lua"),
                 "walk": sha_text(WORLD / "world-v7-walk.json")},
        "swap": swap,
        "parts": parts,
        "den": anchors["den"], "path": anchors["path"], "terrace": anchors["terrace"], "evacuate": anchors["evacuate"],
        "caveBlocker": False,
        "ground": ground,
        "walk": {"grid": grid, "surface": surface},
        "pack": "WorldBeta",
    }
    body = json.dumps(data, separators=(",", ":"), sort_keys=True)
    return ("-- Generated by scripts/cliff_den_data.py (CLIFF-DEN-ISLAND-SCOPE): the beta's cliff path, Play Den and terrace\n"
            "-- top. World studs, as WorldV7Data. Swapped in at server start on the beta place only. Do not edit by hand.\n"
            f"return game:GetService(\"HttpService\"):JSONDecode([=[{body}]=])\n"), data


def main(argv):
    text, data = build()
    if "--check" in argv:
        ok = OUT.exists() and OUT.read_text(encoding="utf-8").replace("\r\n", "\n") == text
        print("CliffDenData current" if ok else "STALE: src/shared/CliffDenData.lua")
        return 0 if ok else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote", OUT.relative_to(ROOT), f"({len(text)} bytes): swap {len(data['swap'])}, parts {len(data['parts'])},",
          f"ground {len(data['ground'])}, grid {len(data['walk']['grid'])}, surface {len(data['walk']['surface'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
