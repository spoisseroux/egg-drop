"""Measure where the blossom crown's leaves are, for the canopy fruit's seats (beta 42 E20, GardenFruit.Surface).

    python scripts/crown_fruit_surface.py            prints the Lua table GardenFruit.Surface holds
    python scripts/crown_fruit_surface.py --check    exits 1 when GardenFruit.lua's table differs from the FBX

Reads assets/world/aero-kit/aero-kit.fbx (binary FBX, no Blender) and the Crown_Blossom mesh in it: its leaf clumps
(the 12 thin leaf cards, connected pieces of 20 triangles or fewer, are left out: a fruit is never seated on a card's
tip). For each seat direction in the crown part's own frame (crown.cframe: d = (cos lat cos a, sin lat, cos lat sin a),
lat 10 to 45 degrees above the widest line in steps of 5, a in 24 steps), a ray from the bounds centre in the space
normalised by the half extents finds the outermost leaf face: that distance is the share of the bounding ellipsoid the
leaves reach there (GardenFruit.surfaceAt). Each value is the median of nine rays (+-3 degrees lat, +-4 degrees a).

Frames: the FBX holds Blender's local coordinates (Z up). The part's frame is centre * yaw * AeroKit.Turn (pi about Y)
and the world offset of a Blender offset (x, y, z) is yaw * (x, z, -y) (build_world_aero_kit.py rb), so a Blender
offset is (-x, z, y) in the part's frame.
"""
from __future__ import annotations

import math
import re
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FBX = ROOT / "assets/world/aero-kit/aero-kit.fbx"
MESH = "W7_Kit_Crown_Blossom__foliage_blossom"
LATS = list(range(10, 46, 5))
AZ = 24
CARD_TRIS = 20


def parse(data: bytes):
    wide = struct.unpack_from("<I", data, 23)[0] >= 7500

    def props(off, count):
        out = []
        for _ in range(count):
            t = chr(data[off]); off += 1
            if t in "YCILFD":
                fmt = {"Y": "<h", "C": "<?", "I": "<i", "L": "<q", "F": "<f", "D": "<d"}[t]
                out.append(struct.unpack_from(fmt, data, off)[0]); off += struct.calcsize(fmt)
            elif t in "fdlib":
                n, enc, clen = struct.unpack_from("<III", data, off); off += 12
                raw = data[off:off + clen]; off += clen
                if enc == 1:
                    raw = zlib.decompress(raw)
                out.append(list(struct.unpack("<%d%s" % (n, {"f": "f", "d": "d", "l": "q", "i": "i", "b": "?"}[t]), raw)))
            elif t in "SR":
                n = struct.unpack_from("<I", data, off)[0]; off += 4
                out.append(data[off:off + n]); off += n
            else:
                raise ValueError("FBX property type " + t)
        return out

    def node(off):
        if wide:
            end, count, length = struct.unpack_from("<QQQ", data, off); off += 24
        else:
            end, count, length = struct.unpack_from("<III", data, off); off += 12
        name_len = data[off]; off += 1
        name = data[off:off + name_len].decode(); off += name_len
        if end == 0:
            return None, off
        values = props(off, count)
        off += length
        children = []
        while off < end:
            child, off = node(off)
            if child is None:
                break
            children.append(child)
        return {"name": name, "props": values, "children": children}, end

    off, top = 27, []
    while off < len(data) - 200:
        item, off = node(off)
        if item is None:
            break
        top.append(item)
    return top


def crown_mesh():
    top = parse(FBX.read_bytes())
    objects = next(n for n in top if n["name"] == "Objects")
    for g in objects["children"]:
        if g["name"] == "Geometry" and g["props"][1].split(b"\0")[0].decode(errors="replace").startswith(MESH):
            kids = {c["name"]: c for c in g["children"]}
            v = kids["Vertices"]["props"][0]
            verts = [tuple(v[i:i + 3]) for i in range(0, len(v), 3)]
            tris, poly = [], []
            for k in kids["PolygonVertexIndex"]["props"][0]:
                poly.append(-k - 1 if k < 0 else k)
                if k < 0:
                    tris += [(poly[0], poly[j], poly[j + 1]) for j in range(1, len(poly) - 1)]
                    poly = []
            return verts, tris
    raise SystemExit("no " + MESH + " in " + str(FBX))


def table():
    verts, tris = crown_mesh()
    lo = [min(p[a] for p in verts) for a in range(3)]
    hi = [max(p[a] for p in verts) for a in range(3)]
    c = [(hi[a] + lo[a]) / 2 for a in range(3)]
    h = [(hi[a] - lo[a]) / 2 for a in range(3)]
    # Part-frame normalised points: Blender (x, y, z) -> (-x, z, y), over the half extents (part X = Blender x, part
    # Y = Blender z, part Z = Blender y).
    pts = [(-(p[0] - c[0]) / h[0], (p[2] - c[2]) / h[2], (p[1] - c[1]) / h[1]) for p in verts]
    # Leave out the leaf cards (small connected pieces).
    parent = list(range(len(tris)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    owner = {}
    for ti, tri in enumerate(tris):
        for vi in tri:
            key = tuple(round(x, 4) for x in verts[vi])
            if key in owner:
                ra, rb = find(owner[key]), find(ti)
                if ra != rb:
                    parent[ra] = rb
            else:
                owner[key] = ti
    sizes = {}
    for ti in range(len(tris)):
        sizes[find(ti)] = sizes.get(find(ti), 0) + 1
    tris = [t for i, t in enumerate(tris) if sizes[find(i)] > CARD_TRIS]

    def outer(d):
        best = None
        for i, j, k in tris:
            a, b, q = pts[i], pts[j], pts[k]
            e1 = [b[n] - a[n] for n in range(3)]
            e2 = [q[n] - a[n] for n in range(3)]
            px = [d[1] * e2[2] - d[2] * e2[1], d[2] * e2[0] - d[0] * e2[2], d[0] * e2[1] - d[1] * e2[0]]
            det = sum(e1[n] * px[n] for n in range(3))
            if abs(det) < 1e-12:
                continue
            s = [-a[n] for n in range(3)]
            u = sum(s[n] * px[n] for n in range(3)) / det
            if u < 0 or u > 1:
                continue
            qq = [s[1] * e1[2] - s[2] * e1[1], s[2] * e1[0] - s[0] * e1[2], s[0] * e1[1] - s[1] * e1[0]]
            v = sum(d[n] * qq[n] for n in range(3)) / det
            if v < 0 or u + v > 1:
                continue
            t = sum(e2[n] * qq[n] for n in range(3)) / det
            if t > 0 and (best is None or t > best):
                best = t
        return best

    out = []
    for lat in LATS:
        for k in range(AZ):
            vals = []
            for dl in (-3, 0, 3):
                for da in (-4, 0, 4):
                    la, az = math.radians(lat + dl), math.radians(360 * k / AZ + da)
                    r = outer((math.cos(la) * math.cos(az), math.sin(la), math.cos(la) * math.sin(az)))
                    if r is not None:
                        vals.append(r)
            vals.sort()
            out.append(round(vals[len(vals) // 2], 2))
    return out


def lua(values):
    return "r=table.freeze({" + ",".join("%.2f" % v for v in values) + "})"


if __name__ == "__main__":
    values = table()
    if "--check" in sys.argv:
        text = (ROOT / "src/shared/GardenFruit.lua").read_text(encoding="utf-8")
        found = re.search(r"r=table\.freeze\(\{([0-9.,\s]+)\}\)", text)
        have = [float(x) for x in found.group(1).replace("\n", "").replace("\t", "").split(",")] if found else []
        if len(have) != len(values) or any(abs(a - b) > .005 for a, b in zip(have, values)):
            print("GardenFruit.Surface differs from the FBX: run this script and paste its table")
            sys.exit(1)
        print("GardenFruit.Surface matches the FBX (%d values, %.2f to %.2f)" % (len(values), min(values), max(values)))
        sys.exit(0)
    print("lat0=%d,step=%d,lats=%d,az=%d," % (LATS[0], LATS[1] - LATS[0], len(LATS), AZ))
    print(lua(values))
    print("-- min %.2f max %.2f mean %.3f" % (min(values), max(values), sum(values) / len(values)))
