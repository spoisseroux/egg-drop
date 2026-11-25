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
SCHEMA = 1        # the shape of this module (the code checks it); separate from the live-world stamp


def sha_text(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def live_data():
    text = (ROOT / "src" / "shared" / "WorldV7Data.lua").read_text(encoding="utf-8")
    return json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))


def ring():
    """IslandGround's perimeter ring (tenths of a stud, x then z), as (x, z) studs."""
    text = (ROOT / "src" / "shared" / "IslandGround.lua").read_text(encoding="utf-8")
    body = re.search(r"Ring=table\.freeze\(\{(.*?)\}\)", text, re.S).group(1)
    nums = [int(v) for v in re.findall(r"-?\d+", body)]
    return [(nums[k] / 10, nums[k + 1] / 10) for k in range(0, len(nums), 2)]


def _inside(x, z, poly):
    hit = False
    for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
        if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
            hit = not hit
    return hit


def _seg_dist(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / max(1e-9, dx * dx + dz * dz)))
    return ((px - a[0] - t * dx) ** 2 + (pz - a[1] - t * dz) ** 2) ** .5


def safe_cells(anchors):
    """The den floor, the mouth and the apron out to the home Floor's edge (z -89) as IslandGround's one-stud safe
    cells (IslandGround's rule: 3 studs inside the ring), 1 stud off the den's walls. Rows: {z, x0, x1} inclusive runs
    of cell centres (cells are whole studs, as IslandGround: x = X0 + index)."""
    den = anchors["den"]
    outline = [tuple(p) for p in den["outline"]]
    m = den["mouth"]
    loop = ring()
    def ok(x, z):
        on = (_inside(x, z, outline) and min(_seg_dist(x, z, a, b) for a, b in zip(outline, outline[1:] + outline[:1])) >= 1.0)             or (m["x0"] + 1 <= x <= m["x1"] - 1 and m["z"] - 1 <= z <= -89)
        return on and min(_seg_dist(x, z, a, b) for a, b in zip(loop, loop[1:] + loop[:1])) >= 3.0
    rows = []
    for z in range(-120, -88):
        run = None
        for x in range(-24, 9):
            if ok(x, z):
                run = [z, x, x] if run is None else [z, run[1], x]
            elif run is not None:
                rows.append(run)
                run = None
        if run is not None:
            rows.append(run)
    return {"note": "one-stud cells, rows {z, x0, x1}, as IslandGround (3 studs inside the ring, 1 off the den walls)",
            "rows": rows}


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
        # The pack's stamp (code review): a hash of the beta outputs, so a pack built from older outputs never matches.
        "version": hashlib.sha256((WORLD / "world-v7-beta-manifest.json").read_bytes().replace(b"\r\n", b"\n")
                                  + (WORLD / "world-v7-beta-collision.json").read_bytes().replace(b"\r\n", b"\n")).hexdigest()[:16],
        "schema": SCHEMA,
        "live": {"worldV7Data": sha_text(ROOT / "src" / "shared" / "WorldV7Data.lua"),
                 "walk": sha_text(WORLD / "world-v7-walk.json")},
        "swap": swap,
        "parts": parts,
        "den": anchors["den"], "path": anchors["path"], "terrace": anchors["terrace"], "evacuate": anchors["evacuate"],
        "safe": safe_cells(anchors),
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
