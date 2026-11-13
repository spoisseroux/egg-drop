"""Deterministic ground dressing scatter for World 1 v7 (batch 2026-11-13, W1).

  python scripts/build_world_v7_dressing.py

Reads the 1-stud top-surface map in assets/world/world-v7-walk.json ("surface", written by
scripts/build_world_v7_chunks.py after the declutter merge) and writes src/shared/WorldDressing.lua:

- Flowers: flat, upward-facing flower patches (one Decal on one thin invisible part each, built on the client by
  src/client/WorldDressingClient.lua). Every cell under a patch, plus a margin, is grass; the ground under it is
  flat enough for a flat quad; none within 4.9 studs of a station or on the toy lawn, rest daises or arrival dais.
  A hub ring (17 to 36 studs from the plaza centre), a patch where each removed prop stood when that spot is grass,
  then the rest of the island. Kinds follow FEEL-ALIVE-DIRECTION C3: tulips on the Care cradle side, buttercups
  by the egg nest, starblooms by the Pocket Deck kiosk, bellflowers in the shade of rocks, daisies everywhere.
- Bushes: low-poly frond plants (scripts/build_world_v7_fronds.py meshes, cloned on the server) at rock bases and
  path edges, on grass or the soft slope ground.

Phone-safe: at most 150 patches (2 triangles and 1 decal each, 5 textures) and 44 bushes (under 7,500 triangles).
Same inputs, same output: one seeded RNG, fixed visiting order.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WALK = json.loads((ROOT / "assets" / "world" / "world-v7-walk.json").read_text())
FRONDS = json.loads((ROOT / "assets" / "world" / "world-dressing-manifest.json").read_text())["meshes"]
OUT = ROOT / "src" / "shared" / "WorldDressing.lua"
# Uploaded ids (filled by the coordinator after the Open Cloud uploads), e.g.
# {"flowers": {"daisy": "rbxassetid://...", ...}, "texture": "rbxassetid://<frond_leaf>", "W7D_FrondFan": [meshId, x, y, z]}
IMPORT_PATH = ROOT / "assets" / "world" / "world-dressing-import.json"
IMPORT = json.loads(IMPORT_PATH.read_text()) if IMPORT_PATH.exists() else {}
SEED = 20261113
S = WALK["surface"]
X0, Z0, NX, NZ = S["x0"], S["z0"], S["nx"], S["nz"]

HUB = (-30.0, 4.0)
STATIONS = {"Eggs": (-31.0, -11.0), "Journal": (-17.0, -15.0), "Customize": (-46.0, -9.0)}
# Pet Park playground (src/shared/ParkLayout.lua: centre (36, 66), radii 16 x 11) plus a 2-stud margin:
# no flower patches or bushes inside the kerb.
PARK = (36.0, 66.0, 16.0, 11.0)


def in_park(x, z, r=0.0):
    cx, cz, rx, rz = PARK
    return ((x - cx) / (rx + 2 + r)) ** 2 + ((z - cz) / (rz + 2 + r)) ** 2 <= 1.0


KEEP_OUT = [  # (x, z, radius): stations (4.9 studs + patch margin is checked per patch), toy lawn, daises, arrival
    (-31.0, -11.0, 4.9), (-17.0, -15.0, 4.9), (-46.0, -9.0, 4.9), (-30.0, 21.5, 9.5),
    (1.0, -33.0, 4.5), (49.5, 14.0, 4.5), (54.5, 14.0, 4.5), (96.0, 66.0, 9.0), (HUB[0], HUB[1], 16.5),
]
REMOVED_PROPS = [(-42, 9.5), (-18, 9.5), (-46.5, -17), (-13.5, 5), (-41.4, 16.4), (-31.9, 23.8), (-52.1, -10.3),
                 (-12.9, -19.4), (-8.7, -12.6), (-10.5, -18.2), (-48, -22.1), (-13, -3.9)]
KINDS = ["daisy", "tulip", "bellflower", "buttercup", "starbloom"]
SIDE_KIND = {"Journal": "tulip", "Eggs": "buttercup", "Customize": "starbloom"}
FLOWER_CAP, HUB_RING = 150, 26
ROCK_BUSHES, PATH_BUSHES = 28, 16
ISLAND = (-108.0, 116.0, -88.0, 84.0)  # x min, x max, z min, z max (inside the perimeter wall)
# Pet wet boxes (generous along the stream banks) plus the bubble spring (HollowWorldLayout.V7.Wet), and the
# arrival-to-hub path (HollowWorldLayout.V7.Routes.ArrivalToHub): WorldDressing.spec checks the same shapes.
WET = [((e["center"][0], e["center"][2]), (e["size"][0], e["size"][2]), e.get("yaw", 0)) for e in WALK["wet"]] + [((52, 3), (7, 4.4), 0)]
ROUTE = [(96, 66), (60, 50), (32, 29), (14, 21), (-9, 21), (-20, 12), (-30, 4)]


def in_wet(x, z, margin):
    for (cx, cz), (sx, sz), yaw in WET:
        dx, dz = x - cx, z - cz
        qx, qz = dx * math.cos(yaw) - dz * math.sin(yaw), dx * math.sin(yaw) + dz * math.cos(yaw)
        if abs(qx) <= sx / 2 + margin and abs(qz) <= sz / 2 + margin:
            return True
    return False


def route_distance(x, z):
    best = 1e9
    for (ax, az), (bx, bz) in zip(ROUTE, ROUTE[1:]):
        abx, abz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * abx + (z - az) * abz) / (abx * abx + abz * abz)))
        best = min(best, math.hypot(x - ax - abx * t, z - az - abz * t))
    return best


def cell(x, z):
    i, j = int(round(x - X0)), int(round(z - Z0))
    if 0 <= i < NX and 0 <= j < NZ:
        return S["rows"][j][i], S["h"][j][i]
    return ".", -999


def height(x, z):
    """Bilinear top-surface height."""
    fx, fz = x - X0, z - Z0
    i, j = int(math.floor(fx)), int(math.floor(fz))
    u, v = fx - i, fz - j
    hs = []
    for a, b in ((i, j), (i + 1, j), (i, j + 1), (i + 1, j + 1)):
        hs.append(S["h"][b][a] if 0 <= a < NX and 0 <= b < NZ else -999)
    if min(hs) < -900:
        return None
    return hs[0] * (1 - u) * (1 - v) + hs[1] * u * (1 - v) + hs[2] * (1 - u) * v + hs[3] * u * v


def all_codes(x, z, r, allowed):
    for dz in range(-int(math.ceil(r)), int(math.ceil(r)) + 1):
        for dx in range(-int(math.ceil(r)), int(math.ceil(r)) + 1):
            if dx * dx + dz * dz <= r * r and cell(x + dx, z + dz)[0] not in allowed:
                return False
    return True


def near_code(x, z, r_min, r_max, codes):
    for dz in range(-int(r_max), int(r_max) + 1):
        for dx in range(-int(r_max), int(r_max) + 1):
            d = math.hypot(dx, dz)
            if r_min <= d <= r_max and cell(x + dx, z + dz)[0] in codes:
                return True
    return False


def plane(x, z, r):
    """Least-squares plane over the footprint: (y at centre, slope x, slope z, worst residual)."""
    pts = []
    for dz in (-r, -r / 2, 0, r / 2, r):
        for dx in (-r, -r / 2, 0, r / 2, r):
            h = height(x + dx, z + dz)
            if h is None:
                return None
            pts.append((dx, dz, h))
    n = len(pts)
    sx = sum(p[0] * p[0] for p in pts)
    sz = sum(p[1] * p[1] for p in pts)
    mean = sum(p[2] for p in pts) / n
    gx = sum(p[0] * (p[2] - mean) for p in pts) / sx
    gz = sum(p[1] * (p[2] - mean) for p in pts) / sz
    worst = max(abs(mean + gx * p[0] + gz * p[1] - p[2]) for p in pts)
    return mean, gx, gz, worst


def inside_island(x, z):
    return ISLAND[0] < x < ISLAND[1] and ISLAND[2] < z < ISLAND[3]


def kept_out(x, z, r):
    if in_park(x, z, r):
        return True
    return any(math.hypot(x - kx, z - kz) < kr + r for kx, kz, kr in KEEP_OUT)


def flower_kind(x, z, rng):
    name, d = min(((n, math.hypot(x - p[0], z - p[1])) for n, p in STATIONS.items()), key=lambda t: t[1])
    if d < 26 and rng.random() < .7:
        return SIDE_KIND[name]
    if near_code(x, z, 2, 7, "R") and rng.random() < .6:
        return "bellflower"
    return rng.choice(["daisy", "daisy", "daisy", "bellflower", "buttercup", "tulip", "starbloom"])


def main():
    rng = random.Random(SEED)
    patches = []

    def try_patch(x, z, size, kind=None):
        r = size / 2
        if not inside_island(x, z) or kept_out(x, z, r) or in_wet(x, z, r + .3) or route_distance(x, z) < r + 1:
            return False
        if not all_codes(x, z, r + .75, "G"):
            return False
        fit = plane(x, z, r)
        if fit is None or fit[3] > .2 or math.hypot(fit[1], fit[2]) > .35:
            return False
        if any(math.hypot(x - p["x"], z - p["z"]) < (size + p["size"]) / 2 + 1.2 for p in patches):
            return False
        patches.append({"x": round(x, 2), "y": round(fit[0], 3), "z": round(z, 2), "size": round(size, 2),
                        "yaw": round(rng.uniform(0, math.tau), 3), "kind": kind or flower_kind(x, z, rng),
                        "gx": round(fit[1], 4), "gz": round(fit[2], 4)})
        return True

    # 1. A patch where each removed prop stood, when that spot is grass now.
    for x, z in REMOVED_PROPS:
        for _ in range(12):
            if try_patch(x + rng.uniform(-1.5, 1.5), z + rng.uniform(-1.5, 1.5), rng.uniform(3.2, 4.2)):
                break
    # 2. The hub ring.
    tries = 0
    while sum(1 for p in patches if 17 <= math.hypot(p["x"] - HUB[0], p["z"] - HUB[1]) <= 36) < HUB_RING and tries < 4000:
        tries += 1
        a, d = rng.uniform(0, math.tau), rng.uniform(17, 36)
        try_patch(HUB[0] + math.cos(a) * d, HUB[1] + math.sin(a) * d, rng.uniform(3.0, 4.2))
    # 3. The rest of the island, sparser.
    tries = 0
    while len(patches) < FLOWER_CAP and tries < 20000:
        tries += 1
        x, z = rng.uniform(ISLAND[0], ISLAND[1]), rng.uniform(ISLAND[2], ISLAND[3])
        if any(math.hypot(x - p["x"], z - p["z"]) < 7.5 for p in patches):
            continue
        try_patch(x, z, rng.uniform(3.0, 4.5))

    bushes = []
    names = [m["name"] for m in FRONDS]

    def try_bush(x, z, kind, scale):
        if not inside_island(x, z) or kept_out(x, z, 2.5) or in_wet(x, z, .5):
            return False
        if cell(x, z)[0] not in "Gg" or not all_codes(x, z, 1.2, "Gg"):
            return False
        if any(math.hypot(x - b["x"], z - b["z"]) < 6 for b in bushes):
            return False
        if any(math.hypot(x - p["x"], z - p["z"]) < p["size"] / 2 + 1.5 for p in patches):
            return False
        y = height(x, z)
        if y is None:
            return False
        # Sink to the lowest ground under the footprint so no leaf base floats on a slope.
        low = min(h for h in (height(x + dx, z + dz) for dx in (-.8, 0, .8) for dz in (-.8, 0, .8)) if h is not None)
        bushes.append({"x": round(x, 2), "y": round(min(y, low) - .05, 3), "z": round(z, 2), "kind": kind,
                       "yaw": round(rng.uniform(0, math.tau), 3), "scale": round(scale, 2)})
        return True

    rock = path = 0
    tries = 0
    while rock < ROCK_BUSHES and tries < 30000:
        tries += 1
        x, z = rng.uniform(ISLAND[0], ISLAND[1]), rng.uniform(ISLAND[2], ISLAND[3])
        if not near_code(x, z, 1, 2.5, "R"):
            continue
        if try_bush(x, z, rng.choice(["W7D_FrondFan", "W7D_FrondFan", "W7D_LeafTuft"]), rng.uniform(.85, 1.25)):
            rock += 1
    tries = 0
    while path < PATH_BUSHES and tries < 30000:
        tries += 1
        x, z = rng.uniform(ISLAND[0], ISLAND[1]), rng.uniform(ISLAND[2], ISLAND[3])
        if not near_code(x, z, 1.5, 3, "P") or near_code(x, z, 0, 1.4, "P"):
            continue
        if try_bush(x, z, rng.choice(["W7D_FrondSpray", "W7D_LeafTuft"]), rng.uniform(.8, 1.15)):
            path += 1
    assert all(b["kind"] in names for b in bushes)
    write(patches, bushes)
    print("dressing", len(patches), "patches", len(bushes), "bushes", "(rock", rock, "path", path, ")")


def checksum(patches, bushes):
    """Same formula as WorldDressing.checksum in Luau: sum of rounded coordinates, modulo 2^31."""
    total = 0
    for p in patches:
        total += round(p["x"] * 100) * 3 + round(p["z"] * 100) * 7 + round(p["size"] * 100) + KINDS.index(p["kind"]) + 1
    for b in bushes:
        total += round(b["x"] * 100) * 5 + round(b["z"] * 100) * 11 + round(b["scale"] * 100)
    return total % 2147483648


def lua_num(v):
    return repr(round(v, 4))


def write(patches, bushes):
    fl = ",\n".join("\t{%s,%s,%s,%s,%s,%d,%s,%s}" % (lua_num(p["x"]), lua_num(p["y"]), lua_num(p["z"]), lua_num(p["size"]),
                                                     lua_num(p["yaw"]), KINDS.index(p["kind"]) + 1, lua_num(p["gx"]), lua_num(p["gz"]))
                    for p in patches)
    bu = ",\n".join("\t{%s,%s,%s,%d,%s,%s}" % (lua_num(b["x"]), lua_num(b["y"]), lua_num(b["z"]),
                                               [m["name"] for m in FRONDS].index(b["kind"]) + 1, lua_num(b["yaw"]), lua_num(b["scale"]))
                    for b in bushes)
    flowers = IMPORT.get("flowers", {})
    textures = ",".join('%s="%s"' % (k, flowers.get(k, "")) for k in KINDS)
    sizes = ",".join('%s={size=Vector3.new(%s,%s,%s),base=%s}' % (m["name"], *(lua_num(v) for v in m["size"]), lua_num(m["baseOffset"]))
                     for m in FRONDS)
    src = f'''-- Ground dressing for World 1 v7 (batch 2026-11-13, W1). Generated by scripts/build_world_v7_dressing.py
-- (seed {SEED}) from the declutter merge's top-surface map. Do not edit the tables by hand; rerun the script.
-- Flowers: flat, upward-facing flower patches, one Decal on one thin invisible part each, built on the client
-- (WorldDressingClient). Bushes: frond plant meshes cloned on the server from ServerStorage.WorldAssets.Dressing
-- (LoungeWorldV7Art.dressing). Phone budget: MaxFlowers patches, MaxBushes bushes, cull past CullPhone/CullDesktop.
local Dressing={{}}

Dressing.Seed={SEED}
Dressing.Kinds=table.freeze({{"daisy","tulip","bellflower","buttercup","starbloom"}})
-- Uploaded assets/world/textures/flower_patch_<kind>.png ids, from assets/world/world-dressing-import.json
-- "flowers". A kind without an id is skipped by the placer (nothing is drawn until the upload lands).
Dressing.Textures=table.freeze({{{textures}}})
Dressing.BushKinds=table.freeze({{{",".join('"%s"' % m["name"] for m in FRONDS)}}})
Dressing.BushMeshes=table.freeze({{{sizes}}})
Dressing.MaxFlowers=150
Dressing.MaxBushes=44
Dressing.CullPhone=90
Dressing.CullDesktop=150
-- Patch parts sit this far above the fitted ground plane (no z-fighting with the grass).
Dressing.Lift=.06
Dressing.Thickness=.05
-- Never within this many studs of a station prompt (FEEL-ALIVE-DIRECTION C3).
Dressing.StationClearance=4.9

-- {{x, y, z, size, yaw, kind index, ground slope dy/dx, ground slope dy/dz}}
Dressing.Flowers=table.freeze({{
{fl}
}})
-- {{x, base y, z, bush kind index, yaw, scale}}
Dressing.Bushes=table.freeze({{
{bu}
}})
Dressing.Checksum={checksum(patches, bushes)}

local function round(v)return math.floor(v*100+.5)end
function Dressing.checksum(flowers,bushes)
	local total=0
	for _,p in ipairs(flowers)do total+=round(p[1])*3+round(p[3])*7+round(p[4])+p[6]end
	for _,b in ipairs(bushes)do total+=round(b[1])*5+round(b[3])*11+round(b[6])end
	return total%2147483648
end

-- World CFrame of a flower patch part: centred on the fitted ground plane, its up axis on the plane normal.
function Dressing.flowerCFrame(entry)
	local x,y,z,_,yaw,_,gx,gz=table.unpack(entry)
	local up=Vector3.new(-gx,1,-gz).Unit
	local look=CFrame.Angles(0,yaw,0).LookVector
	local right=look:Cross(up).Unit
	local back=right:Cross(up).Unit
	return CFrame.fromMatrix(Vector3.new(x,y,z)+up*(Dressing.Lift+Dressing.Thickness*.5),right,up,back)
end

-- World CFrame and Size of a bush (its mesh pivots on its bounds centre).
function Dressing.bushPlacement(entry)
	local x,y,z,kind,yaw,scale=table.unpack(entry)
	local mesh=Dressing.BushMeshes[Dressing.BushKinds[kind]]
	return CFrame.new(x,y+mesh.base*scale,z)*CFrame.Angles(0,yaw,0),mesh.size*scale
end

return table.freeze(Dressing)
'''
    OUT.write_text(src, newline="\n")


if __name__ == "__main__":
    main()
