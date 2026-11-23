"""Write src/client/LifeSpots.lua: where the garden life sits (ALIVE-LIFE-BUILD-PLAN-2026-11-22, revision 1).

The blossom crowns are three merged MeshParts in the world, not one part per tree, so the places come from the
same data the trees were built from: artifacts/world1-mockup/v7/vegetation-placements.json (minus the trees the
declutter removed, assets/world/world-v7-declutter.json) and the crown clumps of build_world_v7.py
(x, y, z, radius, squash in Blender units at scale 1; the trunk leans .4 along x).

    Landings  AmbientPerches index -> the top of that tree's crown, where a bird stands (GardenLife adds its own
              .56 lift). An index without a landing (a tree the declutter removed after the perches were written,
              the Hatch Tree, a crown within KEEP studs of a station) shows no bird; the chirp still plays.
    Crowns    every blossom crown still standing: its middle and the box petals leave from.

Blender to Roblox: X = x, Y = z (+ the placement's own height), Z = -y; the placement yaw turns about +Y.

    python scripts/build_life_spots.py          write the module
    python scripts/build_life_spots.py --check  fail when the committed module differs
"""
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src/client/LifeSpots.lua"
PERCHES = ROOT / "src/client/AmbientPerches.lua"
SRC = ROOT / "artifacts/world1-mockup/v7/vegetation-placements.json"
DECLUTTER = ROOT / "assets/world/world-v7-declutter.json"
LAYOUT = ROOT / "src/shared/HollowWorldLayout.lua"
KEEP = 8.0  # nothing lands within this many studs of a station
LEAN = .4
# build_world_v7.py: ROUND, TALL, BLOSSOM (the Lite trees use the first 4, 3 and 3 clumps).
CLUMPS = {
    "Round": [(0, 0, 8.5, 3.6, .78), (2.3, .6, 7.0, 2.9, .78), (-2.2, -.9, 7.2, 2.6, .76), (.3, 2.0, 9.6, 2.2, .8), (-.4, -2.2, 9.0, 2.0, .8), (.3, .2, 11.0, 1.7, .8)],
    "Tall": [(0, 0, 8.8, 3.0, .82), (.4, .3, 11.0, 2.6, .88), (-.3, -.3, 13.0, 2.0, .92), (.1, .1, 14.7, 1.4, 1.0), (1.5, -.8, 9.6, 1.6, .8)],
    "Blossom": [(0, 0, 7.4, 3.4, .74), (2.3, -.5, 6.5, 2.7, .74), (-2.1, 1.0, 6.7, 2.6, .74), (.4, 1.9, 8.5, 1.9, .78), (-.5, -2.0, 8.2, 1.9, .78), (1.3, .8, 9.2, 1.5, .8)],
}
LITE = {"Round": 4, "Tall": 3, "Blossom": 3}


def clumps(mesh):
    lite, kind = mesh.startswith("TreeLite_"), mesh.split("_", 1)[1]
    return CLUMPS[kind][:LITE[kind]] if lite else CLUMPS[kind]


def world(item, x, y, z):
    """A Blender-space offset at scale 1 on this placement, in Roblox studs."""
    s, yaw = item["scale"], item.get("yaw_rad", 0.0)
    X, Y, Z = x * s, z * s, -y * s
    c, n = math.cos(yaw), math.sin(yaw)
    px, py, pz = item["roblox_position"]
    return (px + X * c + Z * n, py + Y, pz - X * n + Z * c)


def top(item):
    """The highest point of the crown: the top of its highest clump."""
    best = max(clumps(item["mesh"]), key=lambda k: k[2] + k[3] * k[4])
    return world(item, best[0] + LEAN, best[1], best[2] + best[3] * best[4])


def crown(item):
    """Middle and size of the box round the crown (petals leave from it)."""
    ks, s = clumps(item["mesh"]), item["scale"]
    main = ks[0]
    reach = max(math.hypot(k[0] - main[0], k[1] - main[1]) + k[3] for k in ks)
    low = min(k[2] - k[3] * k[4] for k in ks)
    high = max(k[2] + k[3] * k[4] for k in ks)
    middle = world(item, main[0] + LEAN, main[1], (low + high) / 2)
    return middle, (2 * reach * s, (high - low) * s)


def perches():
    text = PERCHES.read_bytes().decode().replace("\r\n", "\n")
    return [tuple(float(v) for v in row) for row in re.findall(r"Vector3\.new\((-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\)", text)]


def stations():
    block = LAYOUT.read_text(encoding="utf-8").split("Stations=table.freeze({")[1].split("}),")[0]
    return [(float(x), float(z)) for x, _, z in re.findall(r"CFrame\.new\((-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\)", block)]


def n(v):
    return f"{round(v, 2):g}"


def emit():
    removed = set(json.loads(DECLUTTER.read_text(encoding="utf-8"))["removed"])
    trees = [i for i in json.loads(SRC.read_text(encoding="utf-8"))["instances"] if i["mesh"].startswith(("Tree_", "TreeLite_"))]
    keep = stations()
    landings, notes = [], []
    for index, (x, y, z) in enumerate(perches(), 1):
        # AmbientPerches rows are the tree's own spot plus 7 x scale up (build_ambient_perches.py).
        match = [t for t in trees if abs(t["roblox_position"][0] - x) < .02 and abs(t["roblox_position"][2] - z) < .02
                 and abs(t["roblox_position"][1] + 7 * t["scale"] - y) < .02]
        if not match:
            notes.append(f"{index} no tree (the Hatch Tree or a moved tree)")
            continue
        tree = match[0]
        if tree["object"] in removed:
            notes.append(f"{index} {tree['object']} removed")
            continue
        at = top(tree)
        near = min(math.hypot(at[0] - sx, at[2] - sz) for sx, sz in keep)
        if near < KEEP:
            notes.append(f"{index} {tree['object']} {near:.1f} studs from a station")
            continue
        landings.append(f" [{index}]=Vector3.new({n(at[0])},{n(at[1])},{n(at[2])}), -- {tree['object']}")
    crowns = []
    for tree in trees:
        if tree["mesh"].endswith("_Blossom") and tree["object"] not in removed:
            (x, y, z), (width, height) = crown(tree)
            crowns.append(f" table.freeze({{position=Vector3.new({n(x)},{n(y)},{n(z)}),size=Vector3.new({n(width)},{n(height)},{n(width)})}}), -- {tree['object']}")
    count = len(perches())
    return (
        "-- Generated by scripts/build_life_spots.py from vegetation-placements.json and the v7 crown clumps; do not edit by hand.\n"
        "-- Garden life (ALIVE-LIFE-BUILD-PLAN-2026-11-22, revision 1). Landings: AmbientPerches index -> the crown top a bird\n"
        f"-- stands on ({len(landings)} of {count}; none for: {'; '.join(notes) or 'nothing'}).\n"
        "-- Crowns: the blossom crowns still standing, their middle and the box petals leave from.\n"
        "return table.freeze({\n"
        f"Perches={count},\n"
        "Landings=table.freeze({\n" + "\n".join(landings) + "\n}),\n"
        "Crowns=table.freeze({\n" + "\n".join(crowns) + "\n}),\n"
        "})\n"
    )


def main():
    text = emit()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_bytes().decode().replace("\r\n", "\n") != text:
            raise SystemExit("LifeSpots.lua is stale: rerun scripts/build_life_spots.py")
        print("LifeSpots.lua is current")
        return
    OUT.write_text(text, encoding="utf-8", newline="\r\n")
    print(text)


if __name__ == "__main__":
    main()
