"""How deep must the Hush sit for its wall tops to stay behind the north ridge from cameras zoomed out on the lawn?
Terrain = the v7 4-stud ground grid (WorldV7Data). Cameras: player heads at the find spots, stations, rest spots and
the dais, zoom Z, yaw every 15 degrees, pitch -10..80 (camera above the head looking down). A camera under the terrain
is skipped (the clamp would pull it in). Targets: points along the top edge of the Hush walls (40 high)."""
import json, math, re, sys
src = open(sys.argv[1], encoding='utf8').read()
j = json.loads(src[src.index('[=[') + 3:src.rindex(']=]')])
g = j['ground']; x0, z0, st, nx, nz, H = g['x0'], g['z0'], g['step'], g['nx'], g['nz'], g['h']
def ground(x, z):
    i, k = int((x - x0) // st), int((z - z0) // st)
    if i < 0 or k < 0 or i >= nx - 1 or k >= nz - 1: return None
    vals = [H[(k + b) * nx + i + a] for a in (0, 1) for b in (0, 1)]
    vals = [v for v in vals if v > -900]
    return max(vals) if vals else None
spots = open(sys.argv[2], encoding='utf8').read()
heads = [(int(a) / 100, int(b) / 100 + 4.5, int(c) / 100) for a, b, c in re.findall(r'x=(-?\d+),y=(-?\d+),z=(-?\d+)', spots)]
heads += [(-31, 8.6, -11), (-17, 8.7, -15), (-46, 8.7, -9), (-30, 8.6, 18.5), (96, 8.5, 66), (1, 9.2, -33), (-7, 9.1, -88), (-30, 8.6, 4)]
def visible_count(floorY, Z, mouthZ=-226):
    tops = []
    for u in range(-79, 80, 8):
        for v in (-4, 30, 60, 90, 128):
            tops.append((-7 + u, floorY + 40, mouthZ - v))
    seen = 0; cams = 0
    for hx, hy, hz in heads:
        for yaw in range(0, 360, 15):
            for pitch in range(-10, 81, 10):
                p, w = math.radians(pitch), math.radians(yaw)
                cx = hx - math.sin(w) * math.cos(p) * Z; cz = hz - math.cos(w) * math.cos(p) * Z; cy = hy + math.sin(p) * Z
                gy = ground(cx, cz)
                if gy is not None and gy > cy: continue
                cams += 1
                for tx, ty, tz in tops:
                    n = int(math.dist((cx, cy, cz), (tx, ty, tz)) / 2)
                    blocked = False
                    for s in range(1, n):
                        t = s / n
                        sx, sy, sz = cx + (tx - cx) * t, cy + (ty - cy) * t, cz + (tz - cz) * t
                        gy = ground(sx, sz)
                        if gy is not None and gy > sy: blocked = True; break
                    if not blocked: seen += 1; break
    return seen, cams
for Z in (22, 30, 60, 120):
    for floorY in (-20, -40, -60, -80):
        s, c = visible_count(floorY, Z)
        print(f"zoom {Z:3d} floor {floorY:4d}: cameras seeing a wall top {s}/{c}")
