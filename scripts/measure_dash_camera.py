"""Where the island's meshes come between the Garden Dash camera and the pet (DashFade.Zones), and what stands close to
the line, measured on the authored world meshes (assets/world/world-v7.fbx and world-v7-declutter.fbx). Needs numpy.

    python scripts/measure_dash_camera.py

The meshes are placed by WorldV7Data's centre and size (the FBX is Z up, one unit a stud). The camera numbers are read
from DashCamera.lua, the line from DashCourse.lua. Dressing, park and gate parts are not in these meshes: check them
in Studio.
"""
import json
import re
import struct
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PET = .8  # the middle of a pet, over the ground


def fbx(path):
    d = path.read_bytes()
    head = "<QQQB" if struct.unpack_from("<I", d, 23)[0] >= 7500 else "<IIIB"
    size = struct.calcsize(head)

    def prop(p):
        t = chr(d[p])
        p += 1
        if t in "YCIFDL":
            f = {"Y": "<h", "C": "<B", "I": "<i", "F": "<f", "D": "<d", "L": "<q"}[t]
            return struct.unpack_from(f, d, p)[0], p + struct.calcsize(f)
        if t in "fdlib":
            n, packed, c = struct.unpack_from("<III", d, p)
            p += 12
            kind = {"f": "<f4", "d": "<f8", "l": "<i8", "i": "<i4", "b": "<i1"}[t]
            raw = zlib.decompress(d[p:p + c]) if packed else d[p:p + n * np.dtype(kind).itemsize]
            return np.frombuffer(raw, kind), p + (c if packed else len(raw))
        n = struct.unpack_from("<I", d, p)[0]
        return d[p + 4:p + 4 + n], p + 4 + n

    def node(p):
        end, count, _, name = struct.unpack_from(head, d, p)
        if end == 0:
            return None, p + size
        p += size
        out, kids, label = [], [], d[p:p + name].decode()
        p += name
        for _ in range(count):
            v, p = prop(p)
            out.append(v)
        while p < end:
            kid, p = node(p)
            if kid is None:
                break
            kids.append(kid)
        return (label, out, kids), end

    top, p = {}, 27
    while p < len(d):
        item, p = node(p)
        if item is None:
            break
        top[item[0]] = item[2]
    models, shapes, out = {}, {}, {}
    for label, values, kids in top["Objects"]:
        if label == "Model":
            models[values[0]] = values[1].split(b"\0")[0].decode().split(".")[0]
        elif label == "Geometry":
            inner = {k: v for k, v, _ in kids}
            if "Vertices" in inner:
                shapes[values[0]] = (inner["Vertices"][0].reshape(-1, 3), inner["PolygonVertexIndex"][0])
    for _, values, _ in top["Connections"]:
        if values[1] in shapes and values[2] in models:
            points, index = shapes[values[1]]
            triangles, poly = [], []
            for i in index:
                poly.append(i if i >= 0 else ~i)
                if i < 0:
                    triangles += [(poly[0], poly[k], poly[k + 1]) for k in range(1, len(poly) - 1)]
                    poly = []
            out[models[values[2]]] = (points, np.array(triangles))
    return out


def lua(path):
    return (ROOT / path).read_text(encoding="utf-8")


data = json.loads(re.search(r"\[=\[(.*)\]=\]", lua("src/shared/WorldV7Data.lua"), re.S).group(1))["parts"]
MESH = {}
for name in ("world-v7.fbx", "world-v7-declutter.fbx"):
    for part, (points, triangles) in fbx(ROOT / "assets/world" / name).items():
        if part not in data or re.search("Backdrop|Islets|Underside|Drift|Water", part):
            continue
        c, v = data[part]["center"], points - (points.min(0) + points.max(0)) / 2
        MESH[part] = np.stack([c[0] + v[:, 0], c[1] + v[:, 2], c[2] - v[:, 1]], 1)[triangles]

course, camera = lua("src/shared/DashCourse.lua"), lua("src/client/DashCamera.lua")


def rows(key):
    text = re.search(r"Course\.%s=table\.freeze\(\{(.*?)\}\)" % key, course, re.S).group(1)
    return np.array([int(x) for x in re.findall(r"-?\d+", text)]).reshape(-1, 4) / 100


def number(text, table, key, scale=1.0):
    return float(re.search(r"%s\.%s=([\d.]+)" % (table, key), text).group(1)) / scale


MAIN, BRANCH = rows("Main"), rows("Branch")
LENGTH, FORK, REJOIN, STONES = (number(course, "Course", k, 100) for k in ("Length", "Fork", "Rejoin", "StonesLength"))
BACK, AHEAD, ROOM = (number(camera, "Camera", k, 100) for k in ("Back", "Ahead", "StartRoom"))
EYE, LOOK = number(camera, "Camera", "EyeHeight"), number(camera, "Camera", "LookHeight")


def at(line, d):
    return np.array([np.interp(d, line[:, 0], line[:, k]) for k in (1, 2, 3)])


def rail(d, stones, via, past, off):  # DashCamera.rail
    d += past
    if stones:
        if d < 0:
            d, stones = d + FORK, False
        elif d > STONES:
            d, stones = d - STONES + REJOIN, False
    elif via and past < 0 and d < REJOIN:
        d, stones = STONES - (REJOIN - d), True
        if d < 0:
            d, stones = d + FORK, False
    line = BRANCH if stones else MAIN
    clip = min(max(d, .6), line[-1, 0] - .6)
    h = (at(line, clip + .5) - at(line, clip - .5))[[0, 2]]
    h /= np.linalg.norm(h)
    extra = 0 if stones else min(d, 0) + max(0, d - LENGTH)
    return at(line, d) + np.array([-h[1] * off + h[0] * extra, 0, h[0] * off + h[1] * extra])


def eye(d, stones, via, off):
    back = BACK if stones or via else min(BACK, d + ROOM)
    return rail(d, stones, via, -back, off) + np.array([0, LOOK + (EYE - LOOK) * (back + AHEAD) / (BACK + AHEAD), 0])


def hit(t, a, b):
    e1, e2, way = t[:, 1] - t[:, 0], t[:, 2] - t[:, 0], b - a
    p = np.cross(way, e2)
    det = (e1 * p).sum(1)
    with np.errstate(all="ignore"):
        s = a - t[:, 0]
        u = (s * p).sum(1) / det
        q = np.cross(s, e1)
        v, k = (q @ way) / det, (e2 * q).sum(1) / det
        return bool(((np.abs(det) > 1e-12) & (u >= 0) & (v >= 0) & (u + v <= 1) & (k >= 0) & (k <= 1)).any())


def main():
    paths = {"Main": [(d, False, False) for d in np.arange(0, LENGTH, .5)],
             "Branch": [(d, True, False) for d in np.arange(0, STONES, .5)],
             "Main after the stones": [(d, False, True) for d in np.arange(REJOIN, REJOIN + 20, .5)]}
    for label, path in paths.items():
        found = {}
        for d, stones, via in path:
            for off in (-1.75, 0, 1.75):
                a, b = eye(d, stones, via, off), rail(d, stones, via, 0, off) + np.array([0, PET, 0])
                for name, t in MESH.items():
                    near = (t.min(1) <= np.maximum(a, b)).all(1) & (t.max(1) >= np.minimum(a, b)).all(1)
                    if near.any() and hit(t[near], a, b):
                        found.setdefault(name, set()).add(round(float(d), 1))
        for name, spots in sorted(found.items()):
            print(f"{label}: {name} covers the pet at {sorted(spots)}")
    for label, line, end in (("Main", MAIN, LENGTH), ("Branch", BRANCH, STONES)):
        for name, t in MESH.items():
            if re.search("Ground|Bridge|grass|dirt|foliage", name):
                continue
            p = np.concatenate([t[:, 0], t[:, 1], t[:, 2], t.mean(1)])
            close = []
            for d in np.arange(0, end, 1.0):
                q = at(line, d)
                low = p[(p[:, 1] > q[1] + .5) & (p[:, 1] < q[1] + 3)]
                if len(low):
                    close.append((round(float(np.hypot(low[:, 0] - q[0], low[:, 2] - q[2]).min()), 2), float(d)))
            if close and min(close)[0] < 2.2:
                print(f"{label}: {name} stands {min(close)[0]} studs from the centre line at {min(close)[1]}")


if __name__ == "__main__":
    main()
