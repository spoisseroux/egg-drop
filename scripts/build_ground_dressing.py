"""Ground texture plates for beta (14) QA W3 row 7 (WORLD-AND-NEST-LOOK section 1; GARDEN-LIFE-BUILD-PLAN section 4).

    python scripts/build_ground_dressing.py

Writes src/shared/GroundDressing.lua: three hand-placed-by-rule lists of flat decal plates that WorldDressingClient draws
on the beta (Alive `scene`), static at every budget level:
  litter  8 plates 3 x 3 under the 8 largest Aero kit crowns, 1 to 2 studs downwind (hash);
  lawn    10 plates 7 to 11 across on grass (walk map surface "G"), all grass under them, 14+ apart, in the most-seen
          lawns (the arrival lawn, round the plaza, the spring meadow);
  fray    12 plates 4 x 1.5 where the dirt path ("P") meets grass, long side along the edge, on the arrival path and
          round the plaza, 6+ apart.
Clear of: the Dash course line (4) and pad (radius 4 for the rope ring, + 2), find spots (3), park kerbs (+2), stations
(4.9), the nest's blocked square (+1), water (+1). scripts/GroundDressing.spec.lua re-checks every plate against the
LIVE modules (the nest is moving in another slice: a nest clash is a warning there, not a failure). Deterministic.
"""
from __future__ import annotations

import json
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WALK = json.loads((ROOT / "assets/world/world-v7-walk.json").read_text(encoding="utf-8"))
OUT = ROOT / "src/shared/GroundDressing.lua"
SEED = 20261123
WIND = (math.cos(math.radians(20)), -math.sin(math.radians(20)))
SURF = WALK["surface"]
X0, Z0, STEP = SURF["x0"], SURF["z0"], SURF["step"]
ROWS, H = SURF["rows"], SURF["h"]


def cell(x: float, z: float) -> str:
    i, j = int(round((x - X0) / STEP)), int(round((z - Z0) / STEP))
    if j < 0 or j >= len(ROWS) or i < 0 or i >= len(ROWS[j]):
        return "."
    return ROWS[j][i]


def height(x: float, z: float) -> float | None:
    i, j = int(round((x - X0) / STEP)), int(round((z - Z0) / STEP))
    if j < 0 or j >= len(H) or i < 0 or i >= len(H[j]):
        return None
    v = H[j][i]
    return None if v is None or v <= -900 else float(v)


def lua_numbers(path: str, name: str) -> list[float]:
    text = (ROOT / path).read_text(encoding="utf-8")
    body = re.search(name + r"=table\.freeze\(\{(.*?)\}\)", text, re.S).group(1)
    return [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", body)]


def course_points() -> list[tuple[float, float]]:
    out = []
    for name in ("Course.Main", "Course.Branch"):
        values = lua_numbers("src/shared/DashCourse.lua", re.escape(name))
        for k in range(len(values) // 4):
            out.append((values[k * 4 + 1] / 100, values[k * 4 + 3] / 100))
    return out


def seg_distance(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    length = dx * dx + dz * dz
    t = 0 if length == 0 else max(0, min(1, ((px - ax) * dx + (pz - az) * dz) / length))
    return math.hypot(px - ax - dx * t, pz - az - dz * t)


COURSE = course_points()
PAD = (66.0, -21.0, 4.0)
FINDS = [(float(x) / 100, float(z) / 100) for x, z in
         re.findall(r"x=(-?\d+),y=-?\d+,z=(-?\d+)", (ROOT / "src/shared/FindSpots.lua").read_text(encoding="utf-8"))]
KERBS = [(36.0, 66.0, 16.0, 11.0), (-38.0, -46.0, 16.0, 11.0)]
STATIONS = [(-31, -11), (-17, -15), (-46, -9), (-30, 18.5), (96, 66)]
NEST = (-17.5, -2.5, 4.2)
WET = [(b["center"][0], b["center"][2], b["size"][0], b["size"][2], b.get("yaw", 0)) for b in WALK["wet"]]


def clear(x: float, z: float, radius: float) -> str | None:
    """None when a plate of this radius at (x, z) is clear of every rule, else the rule's name."""
    if COURSE:
        best = min(seg_distance(x, z, *COURSE[k], *COURSE[k + 1]) for k in range(len(COURSE) - 1))
        if best < 4 + radius:
            return "course"
    if math.hypot(x - PAD[0], z - PAD[1]) < PAD[2] + 2 + radius:
        return "pad"
    for fx, fz in FINDS:
        if math.hypot(x - fx, z - fz) < 3 + radius:
            return "find"
    for cx, cz, rx, rz in KERBS:
        if ((x - cx) / (rx + 2 + radius)) ** 2 + ((z - cz) / (rz + 2 + radius)) ** 2 <= 1:
            return "kerb"
    for sx, sz in STATIONS:
        if math.hypot(x - sx, z - sz) < 4.9 + radius:
            return "station"
    if abs(x - NEST[0]) < NEST[2] / 2 + 1 + radius and abs(z - NEST[1]) < NEST[2] / 2 + 1 + radius:
        return "nest"
    for cx, cz, sx, sz, yaw in WET:
        c, s = math.cos(yaw), math.sin(yaw)
        lx, lz = (x - cx) * c - (z - cz) * s, (x - cx) * s + (z - cz) * c
        if abs(lx) < sx / 2 + 1 + radius and abs(lz) < sz / 2 + 1 + radius:
            return "water"
    return None


def kit_crowns() -> list[dict]:
    text = (ROOT / "src/shared/WorldAeroKit.lua").read_text(encoding="utf-8")
    data = json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))
    out = []
    for crown in data["crowns"]:
        mesh = data["meshes"][crown["mesh"]]
        s, yaw = crown["scale"], crown["yaw"]
        px, py, pz = crown["pivot"]
        vx, vy, vz = (v * s for v in mesh["pivotToCentre"])
        # CFrame.Angles(0, yaw, 0):VectorToWorldSpace
        cx = px + vx * math.cos(yaw) + vz * math.sin(yaw)
        cz = pz - vx * math.sin(yaw) + vz * math.cos(yaw)
        out.append({"tree": crown["tree"], "x": cx, "z": cz, "area": mesh["size"][0] * mesh["size"][2] * s * s})
    return out


def r2(v: float) -> float:
    return round(v, 2)


def litter(rng: random.Random) -> list[tuple]:
    out = []
    for crown in sorted(kit_crowns(), key=lambda c: (-c["area"], c["tree"])):
        off = 1 + rng.random()
        x, z = crown["x"] + WIND[0] * off, crown["z"] + WIND[1] * off
        y = height(x, z)
        if y is None or cell(x, z) not in "Gg" or clear(x, z, 1.5):
            continue
        out.append((r2(x), r2(y), r2(z), 3.0, r2(rng.random() * math.tau), crown["tree"]))
        if len(out) == 8:
            break
    return out


LAWNS = [(70.0, 56.0, 30.0), (-30.0, 4.0, 30.0), (50.0, 14.0, 26.0)]


def all_grass(x: float, z: float, radius: float) -> bool:
    r = int(math.ceil(radius))
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            if dx * dx + dz * dz <= radius * radius and cell(x + dx, z + dz) != "G":
                return False
    return True


def lawn(rng: random.Random) -> list[tuple]:
    out = []
    candidates = []
    for ax, az, reach in LAWNS:
        for dx in range(-int(reach), int(reach) + 1, 2):
            for dz in range(-int(reach), int(reach) + 1, 2):
                if dx * dx + dz * dz <= reach * reach:
                    candidates.append((ax + dx, az + dz))
    rng.shuffle(candidates)
    for x, z in candidates:
        size = 7 + rng.random() * 4
        radius = size / 2
        y = height(x, z)
        if y is None or not all_grass(x, z, radius) or clear(x, z, radius):
            continue
        if any(math.hypot(x - p[0], z - p[2]) < 14 for p in out):
            continue
        kind = "a" if len(out) % 2 == 0 else "b"
        out.append((r2(x), r2(y), r2(z), r2(size), r2(rng.random() * math.tau), kind))
        if len(out) == 10:
            break
    return out


FRAY_NEAR = [(96.0, 66.0, 34.0), (60.0, 45.0, 26.0), (-30.0, 4.0, 26.0)]


def fray(rng: random.Random) -> list[tuple]:
    edges = []
    for j, row in enumerate(ROWS):
        for i, code in enumerate(row):
            if code != "P":
                continue
            x, z = X0 + i * STEP, Z0 + j * STEP
            if not any(math.hypot(x - ax, z - az) <= r for ax, az, r in FRAY_NEAR):
                continue
            nx = nz = 0.0
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    if cell(x + dx, z + dz) == "G":
                        nx += dx
                        nz += dz
            if nx == 0 and nz == 0:
                continue
            edges.append((x, z, nx, nz))
    rng.shuffle(edges)
    out = []
    for x, z, nx, nz in edges:
        m = math.hypot(nx, nz)
        nx, nz = nx / m, nz / m
        cx, cz = x + nx * .5, z + nz * .5   # on the boundary, the grass side of the path cell
        y = height(cx, cz)
        if y is None or clear(cx, cz, 2):
            continue
        if any(math.hypot(cx - p[0], cz - p[2]) < 6 for p in out):
            continue
        # The plate's long side (X) along the edge: its local Z points into the grass (the normal).
        yaw = math.atan2(-nx, -nz) + math.pi
        out.append((r2(cx), r2(y), r2(cz), 4.0, r2(yaw % math.tau), "edge"))
        if len(out) == 12:
            break
    return out


def main() -> None:
    rng = random.Random(SEED)
    plates = {"Litter": litter(rng), "Lawn": lawn(rng), "Fray": fray(rng)}
    lines = [
        "-- Generated by scripts/build_ground_dressing.py (seed %d); do not edit by hand: change the script and rerun it." % SEED,
        "-- Beta 14 QA W3 row 7 (WORLD-AND-NEST-LOOK section 1; GARDEN-LIFE-BUILD-PLAN section 4): texture on the ground,",
        "-- drawn by WorldDressingClient on the beta (Alive `scene`), static at every budget level. Pure data, shared.",
        "-- Each row: {x, ground y, z, size (studs across; fray: the long side), yaw (radians), tag}.",
        "local Ground={}",
        "-- Plate sizes and looks (Fable): litter 3 x 3 at .15; lawn 7 to 11 at .55, tinted darker (a) or lighter (b); fray",
        "-- 4 x 1.5 at 0. Heights over the lawn so overlapping plates never fight: lawn .040, fray .045, litter .050 (the",
        "-- moving dapple .055, flowers .06).",
        "Ground.Look=table.freeze({",
        "\tlitter=table.freeze({texture=\"litter\",transparency=.15,lift=.05,depth=nil}),",
        "\tlawn=table.freeze({a=\"lawnPatchA\",b=\"lawnPatchB\",colourA=Color3.fromHex(\"#2E7A34\"),colourB=Color3.fromHex(\"#4C9A45\"),transparency=.55,lift=.04}),",
        "\tfray=table.freeze({texture=\"pathFray\",transparency=0,lift=.045,depth=1.5}),",
        "})",
        "-- The clear rules the generator used (GroundDressing.spec checks them against the live modules).",
        "Ground.Keep=table.freeze({course=4,pad=6,find=3,kerb=2,station=4.9,nest=1,water=1})",
    ]
    for name, rows in plates.items():
        lines.append(f"Ground.{name}=table.freeze({{")
        for row in rows:
            lines.append("\ttable.freeze({%s,%s,%s,%s,%s,\"%s\"})," % row)
        lines.append("})")
    lines.append("return table.freeze(Ground)")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print({name: len(rows) for name, rows in plates.items()}, "->", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
