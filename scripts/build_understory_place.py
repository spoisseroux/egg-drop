"""Where the garden understory stands, P1 (GARDEN-B38-BRIEF 4b, Fable 2026-11-27): 24 round bushes in eight clusters
of three, 8 flowering bushes in pairs, 14 reed clumps. Clustered by rule, never sprinkled.

    python scripts/build_understory_place.py

Writes src/shared/UnderstoryData.lua. Every site is a named anchor (the brief's places, read off the v7 / beta surface
maps); the script searches outward from it (1-stud rings, up to SEARCH studs) for the nearest spot where the whole
group passes every rule below, and records the rows. scripts/Understory.spec.lua re-checks every row against the LIVE
modules (Understory.check: GroundDressing.Keep, GardenClearance, GardenKeepOut, the ball homes, the frond bushes), so
when a module moves the spec fails and this script is rerun. Deterministic.

Rules (bush footprint r = across / 2; reeds r = REED_R):
  ground   bushes: every 1-stud cell under the footprint is lawn ("G" / "g") on the BETA surface map
           (world-v7-beta-walk.json: the cliff den sculpt is in); reeds: the foot on lawn or bank rock ("G", "g", "R").
           The beta height and the v7 4-stud grid (World.groundY, what the client may fall back to) agree within .4.
  paths    no dirt path cell ("P") within r + 1.5, no marble (paving, kerbs, fences: "M") within r + .4.
  water    bushes: no water cell ("W") within r + 1 and off every wet box by Keep.water + r; reeds: the foot on a dry
           cell with a water cell within REED_BAND (on the bank, not in the stream). The wet boxes are the pets' coarse
           water and often cover the bank, so a reed may stand inside one (pets never go there anyway).
  the rest GroundDressing.Keep (course 4, pad 6, find 3, kerb 2, station 4.9, nest 1, water 1) and GardenClearance
           (routes 3, lamps 1, spans and blocked ground .5, rest daises, the nest and the egg corner 4.9 here), tree
           trunks (GardenKeepOut's radius x TRUNK_GROW, for the tree grades now landing), the fountain basin, the
           Wobble Egg, the crunchy toys, the ball homes (BumbleBalls.HomeSlack 4 + 1), the frond bushes (2 + r).
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src/shared/UnderstoryData.lua"
BETA = json.loads((ROOT / "assets/world/world-v7-beta-walk.json").read_text(encoding="utf-8"))
SURF = BETA["surface"]
X0, Z0, ROWS, H = SURF["x0"], SURF["z0"], SURF["rows"], SURF["h"]
SEARCH = 12
REED_R = 1.0
REED_BAND = (.6, 2.8)
TRUNK_GROW = 1.6            # GARDEN-B38-BRIEF 4a: the outer round trees go to x 1.6
KEEP = {"course": 4, "pad": 6, "find": 3, "kerb": 2, "station": 4.9, "nest": 1, "water": 1}


def text(path):
    return (ROOT / path).read_text(encoding="utf-8")


def lua_json(path):
    return json.loads(re.search(r"\[=\[(.*)\]=\]", text(path), re.S).group(1))


DATA = lua_json("src/shared/WorldV7Data.lua")
KIT = lua_json("src/shared/WorldAeroKit.lua")
G = DATA["ground"]


def cell(x, z):
    i, j = int(round(x - X0)), int(round(z - Z0))
    if j < 0 or j >= len(ROWS) or i < 0 or i >= len(ROWS[j]):
        return "."
    return ROWS[j][i]


def beta_h(x, z):
    i, j = int(round(x - X0)), int(round(z - Z0))
    if j < 0 or j >= len(H) or i < 0 or i >= len(H[j]):
        return None
    v = H[j][i]
    return None if v is None or v <= -900 else float(v)


def grid_at(a, b):
    if a < 0 or b < 0 or a >= G["nx"] or b >= G["nz"]:
        return None
    v = G["h"][b * G["nx"] + a]
    return v if isinstance(v, (int, float)) and v > -900 else None


def ground_known(x, z):
    fx, fz = (x - G["x0"]) / G["step"], (z - G["z0"]) / G["step"]
    i, j = math.floor(fx), math.floor(fz)
    return all(grid_at(a, b) is not None for a, b in ((i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)))


def ground_y(x, z):
    """HollowWorldLayout V7.groundY."""
    fx, fz = (x - G["x0"]) / G["step"], (z - G["z0"]) / G["step"]
    i, j = math.floor(fx), math.floor(fz)
    h = [grid_at(i, j), grid_at(i + 1, j), grid_at(i, j + 1), grid_at(i + 1, j + 1)]
    known = [v for v in h if v is not None]
    if not known:
        return 4.0
    if len(known) < 4:
        return sum(known) / len(known)
    u, v = fx - i, fz - j
    return h[0] * (1 - u) * (1 - v) + h[1] * u * (1 - v) + h[2] * (1 - u) * v + h[3] * u * v


def seg(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    length = dx * dx + dz * dz
    t = 0 if length < 1e-9 else max(0, min(1, ((px - ax) * dx + (pz - az) * dz) / length))
    return math.hypot(px - ax - dx * t, pz - az - dz * t)


def poly(px, pz, pts):
    return min(seg(px, pz, *pts[k], *pts[k + 1]) for k in range(len(pts) - 1))


def lua_list(path, name):
    body = re.search(re.escape(name) + r"=table\.freeze\(\{(.*?)\}\)", text(path), re.S).group(1)
    return [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", body)]


COURSE = []
for name in ("Course.Main", "Course.Branch"):
    v = lua_list("src/shared/DashCourse.lua", name)
    COURSE.append([(v[k * 4 + 1] / 100, v[k * 4 + 3] / 100) for k in range(len(v) // 4)])
PAD = (64.5, -21.0)
FINDS = [(float(x) / 100, float(z) / 100) for x, z in re.findall(r"x=(-?\d+),y=-?\d+,z=(-?\d+)", text("src/shared/FindSpots.lua"))]
# ParkLayout.Specs: the arrival, the old grove, the Hollow, the Top Lawn (Tier.T(0, 5)).
PARKS = [(36.0, 66.0, 16.0, 11.0), (-38.0, -46.0, 16.0, 11.0), (-39.8, -47.7, 12.0, 12.0), (-57.08, -91.94, 13.0, 13.0)]
# HollowWorldLayout V7: stations, rest daises; Nest.Spot, EggCorner.Spot.
SPOTS = [(-31, -11), (-17, -15), (-46, -9), (-30, 18.5), (96, 66), (1, -33), (49.5, 14), (54.5, 14), (-25.12, -9.82), (-41, 2)]
LAMPS = [(69.65, 51.97), (29.44, 29.85), (-9, 28), (-12, -44), (-70, -3), (50, -10), (-22, 38)]
ROUTE = [(96, 66), (60, 50), (32, 29), (14, 21), (-9, 21), (-20, 12), (-30, 4)]
WET = [(b["center"][0], b["center"][2], b["size"][0], b["size"][2], b.get("yaw", 0), b.get("name", "")) for b in DATA["wet"]]
WET.append((52, 3, 7, 4.4, 0, "BubbleSpring"))
BOXES = [(-63, 45, 38, 44, 0), (-46, 31.5, 34, 9, math.atan2(-25, -22)), (2.5, 21, 21, 4, 0)]   # knoll, its stairs, the bridge
SOLIDS = [(52, 3, 4.6), (17, -45, 2.6)]                                                            # fountain basin, Wobble Egg
TOYS = [(-26, 37, 2.6), (-13, -40, 2.6), (15, 38.5, 5.1), (42, 12, 3.6), (77.22, 66.24, 2.9)]
BALLS = [(float(x), float(z)) for x, z in re.findall(r"home=Vector2\.new\((-?[\d.]+),(-?[\d.]+)\)", text("src/shared/BumbleBalls.lua"))]
TRUNKS = []
for crown in KIT["crowns"]:
    special = {"Landmark_HatchTree": 2.2, "Landmark_BlossomPointTree": 1.1}.get(crown["tree"])
    TRUNKS.append((crown["pivot"][0], crown["pivot"][2], special or .6 * crown["scale"] * TRUNK_GROW))
FRONDS = [(float(a), float(c)) for a, c in re.findall(r"\{(-?[\d.]+),-?[\d.]+,(-?[\d.]+),",
                                                     re.search(r"Dressing\.Bushes=table\.freeze\(\{(.*?)\n\}\)", text("src/shared/WorldDressing.lua"), re.S).group(1))]
assert len(BALLS) == 5 and len(FRONDS) > 30 and len(FINDS) > 10


def in_box(x, z, cx, cz, sx, sz, yaw, grow):
    c, s = math.cos(yaw), math.sin(yaw)
    # CFrame.Angles(0, yaw, 0):PointToObjectSpace
    lx, lz = (x - cx) * c - (z - cz) * s, (x - cx) * s + (z - cz) * c
    qx, qz = max(0, abs(lx) - sx / 2), max(0, abs(lz) - sz / 2)
    return math.hypot(qx, qz) <= grow


def near(x, z, radius, codes):
    r = int(math.ceil(radius))
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            if dx * dx + dz * dz <= radius * radius and cell(x + dx, z + dz) in codes:
                return True
    return False


def common(x, z, r, skip=()):
    """The rules bushes and reeds share; None when clear, else why. `skip`: rule names a caller checks its own way."""
    if not ground_known(x, z) or any(not ground_known(x + math.cos(a) * r, z + math.sin(a) * r) for a in (0, 1.57, 3.14, 4.71)):
        return "ground"
    by, gy = beta_h(x, z), ground_y(x, z)
    if by is None or abs(by - gy) > .4:
        return "height"
    if near(x, z, r + 1.5, "P"):
        return "path"
    if "marble" not in skip and near(x, z, r + .4, "M."):
        return "marble"
    if min(poly(x, z, line) for line in COURSE) < KEEP["course"] + r + .25:
        return "course"
    if math.hypot(x - PAD[0], z - PAD[1]) < KEEP["pad"] + r + .25:
        return "pad"
    if any(math.hypot(x - fx, z - fz) < KEEP["find"] + r for fx, fz in FINDS):
        return "find"
    for cx, cz, rx, rz in PARKS:
        g = KEEP["kerb"] + r
        if ((x - cx) / (rx + g)) ** 2 + ((z - cz) / (rz + g)) ** 2 <= 1:
            return "park"
    if any(math.hypot(x - sx, z - sz) < KEEP["station"] + r for sx, sz in SPOTS):
        return "station"
    if any(math.hypot(x - lx, z - lz) < 1 + r + .3 for lx, lz in LAMPS):
        return "lamp"
    if poly(x, z, ROUTE) < 3 + r:
        return "route"
    if any(in_box(x, z, *b, .5 + r) for b in BOXES):
        return "blocked"
    if any(math.hypot(x - sx, z - sz) < sr + r + .3 for sx, sz, sr in (TOYS if "basin" in skip else SOLIDS + TOYS)):
        return "solid"
    if any(math.hypot(x - tx, z - tz) < tr + r + .2 for tx, tz, tr in TRUNKS):
        return "trunk"
    if any(math.hypot(x - bx, z - bz) < 4 + 1 + r for bx, bz in BALLS):
        return "ball"
    if any(math.hypot(x - fx, z - fz) < 2 + r for fx, fz in FRONDS):
        return "frond"
    return None


def bush_ok(x, z, r):
    for dx in range(-int(r), int(r) + 1):
        for dz in range(-int(r), int(r) + 1):
            if dx * dx + dz * dz <= r * r and cell(x + dx, z + dz) not in "Gg":
                return "lawn"
    if near(x, z, r + 1, "W"):
        return "water"
    if any(in_box(x, z, cx, cz, sx, sz, yaw, KEEP["water"] + r) for cx, cz, sx, sz, yaw, _ in WET):
        return "wet box"
    return common(x, z, r)


def water_distance(x, z, limit=4):
    best = math.inf
    for dx in range(-limit, limit + 1):
        for dz in range(-limit, limit + 1):
            if cell(x + dx, z + dz) == "W":
                best = min(best, math.hypot(dx, dz))
    return best


def reed_ok(x, z, names=None):
    if cell(x, z) not in "GgR":
        return "bank"
    d = water_distance(x, z)
    if not (REED_BAND[0] <= d <= REED_BAND[1]):
        return "band"
    if names and not any(n in names and in_box(x, z, cx, cz, sx, sz, yaw, REED_BAND[1] + 1.5)
                         for cx, cz, sx, sz, yaw, n in WET):
        return "not this water"
    # reeds keep the shared rules, but water and kerbs are theirs: the banks carry marble kerbs, so a clump may stand
    # beside one (never on one), and the fountain's clumps stand at its basin
    if near(x, z, .7, "M."):
        return "marble"
    return common(x, z, REED_R, ("marble", "basin") if names == ("BubbleSpring",) else ("marble",))


def rings(x, z):
    yield x, z
    for radius in range(1, SEARCH + 1):
        steps = max(8, int(radius * 6))
        for k in range(steps):
            a = k / steps * math.tau
            yield round(x + math.cos(a) * radius, 1), round(z + math.sin(a) * radius, 1)


# Cluster layouts (offsets from the group's centre at turn 0; sizes across, tall): one big and two small, or two big and
# one small, touching like one clump (centres about .8 of the sum of radii apart).
CLUSTER_A = [((0, 0), 4.0, 2.4), ((2.75, .9), 2.5, 1.6), ((-1.3, 2.75), 2.6, 1.7)]
CLUSTER_B = [((0, 0), 4.0, 2.3), ((3.2, -.6), 3.8, 2.2), ((1.3, 2.7), 2.5, 1.5)]
PAIR = [((0, 0), 3.0, 2.0), ((2.6, .6), 2.6, 1.8)]

# The brief's places. Bush clusters: fence corners, pavilion backs, the knoll steps' foot, path forks.
BUSH_SITES = [
    ("bridge_west", (-14, 29), CLUSTER_A),         # the stream's marble kerb meets the bridge, west bank
    ("bridge_east", (20, 12), CLUSTER_B),          # the same corner on the east bank, south of the Dash line
    ("east_rim", (104, 38), CLUSTER_A),            # the rim balustrade's corner below the arrival lawn
    ("rotunda_back", (-82, 62), CLUSTER_B),        # behind the knoll's rotunda, away from its stairs
    ("colonnade_back", (-46, -32), CLUSTER_A),     # behind the curved colonnade at the Hatch Tree
    ("knoll_steps", (-40, 22), CLUSTER_B),         # the foot of the knoll stairs, the plaza side
    ("fork_east", (66, 42), CLUSTER_A),            # where the east loop leaves the arrival path
    ("fork_south", (-20, 17), CLUSTER_B),          # the hub's south fork (bridge path and the toy lawn path)
]
# Flowering bushes: either side of the hub's old bench spots (BenchWest -43, 5; BenchEast -17, 5), the fountain lawn.
FLOWER_SITES = [("hub_west", (-47, 10), PAIR), ("hub_east", (-13, 10), PAIR),
                ("fountain_west", (43, 6), PAIR), ("fountain_east", (61, 8), PAIR)]


def place_group(anchor, layout, taken):
    for cx, cz in rings(*anchor):
        for turn in range(0, 360, 30):
            t = math.radians(turn)
            rows = []
            for (ox, oz), across, tall in layout:
                x = cx + ox * math.cos(t) - oz * math.sin(t)
                z = cz + ox * math.sin(t) + oz * math.cos(t)
                r = across / 2
                if bush_ok(x, z, r) or any(math.hypot(x - p[0], z - p[2]) < r + p[3] / 2 + .3 for p in taken):
                    rows = None
                    break
                rows.append((x, z, across, tall))
            if rows:
                return rows
    return None


def r2(v):
    return round(v, 2)


def bushes(seed_yaw):
    out, flowers, taken = [], [], []
    for groups, sink, kind in ((BUSH_SITES, out, "bush"), (FLOWER_SITES, flowers, "flower")):
        for k, (site, anchor, layout) in enumerate(groups):
            rows = place_group(anchor, layout, taken)
            assert rows, f"no clear spot for the {kind} group {site} within {SEARCH} of {anchor}"
            for n, (x, z, across, tall) in enumerate(rows):
                yaw = (seed_yaw * (len(taken) + 7) * 2.399963) % math.tau
                row = (r2(x), r2(beta_h(x, z) - .12), r2(z), across, tall, r2(yaw), site)
                sink.append(row)
                taken.append((x, 0, z, across))
    return out, flowers, taken


def reeds(taken):
    out = []

    def pick(names, want, spacing, prefer, label, tall=(1.0, .85, 1.1, .9)):
        cands = []
        for j, row in enumerate(ROWS):
            for i, code in enumerate(row):
                x, z = X0 + i, Z0 + j
                if code in "GgR" and not reed_ok(x, z, names):
                    cands.append((prefer(x, z), x, z))
        cands.sort()
        got = []
        for _, x, z in cands:
            if any(math.hypot(x - p[0], z - p[2]) < spacing for p in got) or any(math.hypot(x - p[0], z - p[2]) < 4 for p in out):
                continue
            if any(math.hypot(x - p[0], z - p[2]) < REED_R + p[3] / 2 + .3 for p in taken):
                continue
            got.append((x, 0, z, 2 * REED_R))
            if len(got) == want:
                break
        assert len(got) == want, f"reeds {label}: {len(got)} of {want}"
        for n, (x, _, z, _) in enumerate(got):
            s = tall[n % len(tall)]
            out.append((r2(x), r2(beta_h(x, z) - .05), r2(z), r2(s), r2((n * 2.399963 + len(out)) % math.tau), label))
        return got

    stream = ("Water_Stream", "Water_SkyFalls_Channel")
    # the stream: four a bank, 12+ apart along it, nearest the hub's view first, none past z -42 (the pool has its own).
    # The bank is the side of the stream's centre line (its wet boxes' centres, in flow order) the clump stands on.
    line = [(b[0], b[1]) for b in WET if b[5] == "Water_Stream"]

    def side(x, z):
        best = min(range(len(line) - 1), key=lambda k: seg(x, z, *line[k], *line[k + 1]))
        (ax, az), (bx, bz) = line[best], line[best + 1]
        return (bx - ax) * (z - az) - (bz - az) * (x - ax)
    for want_side, label in ((1, "stream_east"), (-1, "stream_west")):
        pick(stream, 4, 12, lambda x, z, s=want_side: (side(x, z) * s <= 0 or z < -42, abs(z - 5) + abs(x - 5) * .5), label)
        assert all(side(r[0], r[2]) * want_side > 0 and r[2] >= -42 for r in out if r[5] == label), label
    # the pool under the falls: three on its garden side (south and west), 5+ apart
    pick(("Water_Pool_Falls",), 3, 5, lambda x, z: math.hypot(x - 55, z - 55), "falls_pool")
    # the fountain basin's lawn side: three together, round the basin's rim
    pick(("BubbleSpring",), 3, 2.6, lambda x, z: (abs(math.hypot(x - 52, z - 3) - 5.6) > .9, math.hypot(x - 52, z - 12)), "fountain")
    return out


def main():
    bush_rows, flower_rows, taken = bushes(.618)
    reed_rows = reeds(taken)
    lines = [
        "-- Generated by scripts/build_understory_place.py; do not edit by hand: change the script and rerun it.",
        "-- GARDEN-B38-BRIEF 4b (P1): where the understory stands. Pure data, shared; Understory has the rules and the look.",
        "-- Bushes and flowering bushes: {x, ground y, z, across, tall, yaw, site}; reeds: {x, ground y, z, scale, yaw, site}.",
        "-- Ground y is the beta surface map's (1 stud) less the sink, so the foot sits in the lawn.",
        "local Data={}",
    ]
    for name, rows, fmt in (("Bushes", bush_rows, "{%s,%s,%s,%s,%s,%s,\"%s\"}"),
                            ("Flowering", flower_rows, "{%s,%s,%s,%s,%s,%s,\"%s\"}"),
                            ("Reeds", reed_rows, "{%s,%s,%s,%s,%s,\"%s\"}")):
        lines.append(f"Data.{name}=table.freeze({{")
        for row in rows:
            lines.append("\ttable.freeze(" + fmt % row + "),")
        lines.append("})")
    lines.append("return table.freeze(Data)")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print({"bushes": len(bush_rows), "flowering": len(flower_rows), "reeds": len(reed_rows)}, "->", OUT.relative_to(ROOT))
    for row in bush_rows + flower_rows:
        print("  ", row[6], row[0], row[2], row[3])
    for row in reed_rows:
        print("  ", row[5], row[0], row[2])


if __name__ == "__main__":
    main()
