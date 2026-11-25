"""The cliff path, the Play Den and the terrace top: the beta's island sculpt (grey blockout).

Fable's CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md; scope CLIFF-DEN-ISLAND-SCOPE.md (architect review applied). Live never sees
this: scripts/build_world_v7_chunks.py --beta and scripts/build_world_v7_collision.py --beta import it, carve the
island's source meshes and add new rock and earth, and write beta-only outputs (world-v7-beta*.json/.fbx). Everything
here is built from code (sweeps, height fields, boxes with seeded noise); no AI mesh, no samples.

Coordinates: Roblox studs (x, y, z) unless a name says Blender. Blender (x, y, z) = Roblox (x, -z, y - 4).

The path is fitted to the ground (the walk grid of world-v7-walk.json): Fable's foot, turn, arrival and gradient, but each
shelf runs along the contour where the slope meets the path's own height, so it is half cut, half built up (her line
was drawn from the 4-stud grid and sat 5 to 10 studs inside the ridge). The den is a rounded room inside the perimeter
ring. The terrace top: every island face over the terrace footprint above y 27 goes (the greybox slab is 27 to 29).
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
LIVE_WALK = ROOT / "assets" / "world" / "world-v7-walk.json"

# --------------------------------------------------------------------------------------------- the tier frame (Tier.lua)


def _unit(x, z):
    m = math.hypot(x, z)
    return x / m, z / m


TIER_C = (-60.0, -96.0)
TIER_Y = 29.0
TIER_D = _unit(-64, 46)                       # along the ridge, NE -> SW (s)
TIER_N = (-TIER_D[1], TIER_D[0])
if TIER_N[0] * (-30 - TIER_C[0]) + TIER_N[1] * (4 - TIER_C[1]) < 0:
    TIER_N = (TIER_D[1], -TIER_D[0])          # toward the garden (t)
TIER_HALF = (38.0, 22.0)


def tier_xz(s, t):
    return (TIER_C[0] + TIER_D[0] * s + TIER_N[0] * t, TIER_C[1] + TIER_D[1] * s + TIER_N[1] * t)


def tier_st(x, z):
    dx, dz = x - TIER_C[0], z - TIER_C[1]
    return dx * TIER_D[0] + dz * TIER_D[1], dx * TIER_N[0] + dz * TIER_N[1]


# ------------------------------------------------------------------------------------------------ the ground (live walk)
_GRID = None


def ground(x, z):
    """The live island's top surface height at (x, z) (bilinear on the 2-stud walk grid), or None off the island."""
    global _GRID
    if _GRID is None:
        _GRID = json.loads(LIVE_WALK.read_text())["grid"]
    g = _GRID
    fx, fz = (x - g["x0"]) / g["step"], (z - g["z0"]) / g["step"]
    i, j = int(math.floor(fx)), int(math.floor(fz))
    a, b = fx - i, fz - j
    total, weight = 0.0, 0.0
    for di, dj, w in ((0, 0, (1 - a) * (1 - b)), (1, 0, a * (1 - b)), (0, 1, (1 - a) * b), (1, 1, a * b)):
        jj, ii = j + dj, i + di
        if 0 <= jj < len(g["heights"]) and 0 <= ii < len(g["heights"][0]):
            v = g["heights"][jj][ii]
            if v is not None:
                total += v * w
                weight += w
    return total / weight if weight > .25 else None


# ------------------------------------------------------------------------------------------------------------ the path
# (s, t, height, width): fitted to the ground's contours (see the module note). Foot on the lawn by the cave; the bank;
# two long shelves (about 16 degrees); the turn pocket on the shoulder (8 wide, hidden by the fin); the return leg up
# beside the terrace's garden face (about 26 degrees: drawn as steps, collision a smooth ramp); the arrival through the
# notch onto the terrace's south-west end.
PATH_CTRL = [
    (-28.0, 29.5, 4.6, 6.0),     # foot
    (-20.0, 30.5, 6.9, 6.0),
    (-12.0, 33.0, 9.2, 6.0),
    (-4.0, 34.2, 11.5, 6.0),
    (4.0, 32.6, 13.8, 6.0),
    (12.0, 32.0, 16.1, 6.0),
    (20.0, 31.5, 18.4, 6.0),
    (28.0, 31.0, 20.7, 6.0),     # code review: the outbound leg stays at t 31 to the turn, so the return leg (t 25)
    (35.0, 31.0, 22.7, 6.0),     # is a full width away from it (it overhung it at knee height)
    (40.0, 30.0, 23.0, 7.0),     # the turn pocket
    (42.0, 26.5, 23.0, 7.0),
    (37.5, 25.0, 24.6, 6.0),     # the return leg (outside the terrace footprint, t >= 22)
    (30.0, 22.0, 29.0, 6.0),     # the arrival (on the terrace's garden edge, through the notch)
]
STEPS_FROM = 10                  # the return leg (PATH_CTRL[10] -> [11]) is drawn as steps
STEP_COUNT = 6
LEAN = math.tan(math.radians(20))   # the cut back wall leans back 20 degrees
SAMPLE = .6


def _catmull(points, per):
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (Vector(p) for p in pts[i - 1:i + 3])
        for k in range(per):
            t = k / per
            out.append(.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                             + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(Vector(points[-1]))
    return out


_SAMPLES = None


def path_samples():
    """Points along the path: dict(x, z, h, w, out=(dx, dz) toward the lawn, seg = control index, step = bool)."""
    global _SAMPLES
    if _SAMPLES is not None:
        return _SAMPLES
    curve = _catmull([(s, t, h, w) for s, t, h, w in PATH_CTRL], 24)
    # resample by plan arc length
    xz = [tier_xz(p[0], p[1]) for p in curve]
    lens = [0.0]
    for a, b in zip(xz, xz[1:]):
        lens.append(lens[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = lens[-1]
    n = int(total / SAMPLE) + 1
    seg_of = [min(len(PATH_CTRL) - 2, k // 24) for k in range(len(curve))]
    out = []
    k = 0
    for i in range(n + 1):
        d = min(total, i * total / n)
        while k < len(lens) - 2 and lens[k + 1] < d:
            k += 1
        f = (d - lens[k]) / max(1e-9, lens[k + 1] - lens[k])
        p = curve[k].lerp(curve[k + 1], f)
        x, z = tier_xz(p[0], p[1])
        out.append({"x": x, "z": z, "h": p[2], "w": p[3], "seg": seg_of[k], "d": d})
    prev = None
    for i, s in enumerate(out):
        a, b = out[max(0, i - 1)], out[min(len(out) - 1, i + 1)]
        hx, hz = _unit(b["x"] - a["x"], b["z"] - a["z"])
        sx, sz = -hz, hx
        if prev is None:
            if sx * TIER_N[0] + sz * TIER_N[1] < 0:
                sx, sz = -sx, -sz
        elif sx * prev[0] + sz * prev[1] < 0:
            sx, sz = -sx, -sz                  # keep turning with the curve: ribbons never twist at the hairpin
        prev = (sx, sz)
        flip = 1 if sx * TIER_N[0] + sz * TIER_N[1] >= 0 else -1
        s["dir"], s["side"], s["flip"] = (hx, hz), (sx, sz), flip
        s["out"] = (sx * flip, sz * flip)      # the lawn side (walls, supports, the lip)
        s["step"] = s["seg"] >= STEPS_FROM
    # The steps: the return leg's heights quantised into STEP_COUNT treads (drawn); `h` stays the smooth ramp.
    leg = [s for s in out if s["step"]]
    if leg:
        h0, h1 = leg[0]["h"], leg[-1]["h"]
        for s in leg:
            f = (s["h"] - h0) / max(1e-9, h1 - h0)
            s["tread"] = h0 + (h1 - h0) * round(f * (STEP_COUNT - 1)) / (STEP_COUNT - 1)   # within half a step of the ramp
    # The back wall: where the ground behind the inner edge is above the path, a wall leaning back 20 degrees up to
    # where it meets the ground; `back` is how far behind the inner edge its top stands.
    for s in out:
        ex, ez = s["x"] - s["out"][0] * s["w"] / 2, s["z"] - s["out"][1] * s["w"] / 2
        s["back"], s["top"] = 0.0, s["h"]
        for k in range(0, 41):
            dd = k * .25
            g = ground(ex - s["out"][0] * dd, ez - s["out"][1] * dd)
            if g is None:
                break
            wall = s["h"] + dd / LEAN
            if wall >= g + .4:
                s["back"], s["top"] = dd, max(s["h"], min(wall, g + .4))
                break
            s["back"], s["top"] = dd, wall
    _SAMPLES = out
    return out


def _nearest(x, z):
    best, bd = None, 1e18
    for s in path_samples():
        d = (s["x"] - x) ** 2 + (s["z"] - z) ** 2
        if d < bd:
            best, bd = s, d
    return best


def in_path_cut(x, y, z):
    """Is (x, y, z) in the rock and earth the path removes: over the walk surface (from 1.5 past the lawn edge back to
    the leaning wall), and anything inside the walking corridor up to head height."""
    s = _nearest(x, z)
    if s is None:
        return False
    along = (x - s["x"]) * s["dir"][0] + (z - s["z"]) * s["dir"][1]
    if abs(along) > SAMPLE * 1.5:
        return False                        # past either end
    a = (x - s["x"]) * s["out"][0] + (z - s["z"]) * s["out"][1]
    if abs(a) <= s["w"] / 2:
        return y >= s["h"] - .3             # under the walk surface (it covers the hole) and over it
    if y < s["h"] + .15:
        return False                        # beside it: only what stands clearly above the path goes
    if a > s["w"] / 2 + 1.5:
        return False
    behind = -s["w"] / 2 - a                # how far behind the inner edge
    return behind < (y - s["h"]) * LEAN + .05 and behind <= s["back"] + .3


# ---------------------------------------------------------------------------------------------------------- the den
DEN = {"x0": -22.0, "x1": 6.0, "z0": -119.0, "z1": -100.5, "floor": 4.2, "wall": 11.0, "peak": 16.0, "corner": 5.0}
MOUTH = {"x0": -14.5, "x1": .5, "top": 9.85, "west_to": -95.0, "east_to": -99.0}   # under the lintel trim (y 10.2)


def den_inside(x, z, grow=0.0):
    """Inside the den's rounded plan (back corners radius 5), grown by `grow`."""
    d = DEN
    if not (d["x0"] - grow <= x <= d["x1"] + grow and d["z0"] - grow <= z <= d["z1"] + grow):
        return False
    r = d["corner"]
    for cx in (d["x0"] + r, d["x1"] - r):
        cz = d["z0"] + r
        if (x - cx) * (1 if cx > -8 else -1) > 0 and z < cz:
            return math.hypot(x - cx, z - cz) <= r + grow
    return True


def den_roof(x, z):
    d = DEN
    u = (x - (d["x0"] + d["x1"]) / 2) / ((d["x1"] - d["x0"]) / 2)
    v = (z - (d["z0"] + d["z1"]) / 2) / ((d["z1"] - d["z0"]) / 2)
    return d["wall"] + (d["peak"] - d["wall"]) * max(0.0, 1 - u * u) * max(0.0, 1 - v * v)


def den_floor_plan(x, z):
    """Over the den's floor: the room (grown .3) or the mouth's floor trapezoid."""
    if den_inside(x, z, .3):
        return True
    m = MOUTH
    if m["x0"] - .1 <= x <= m["x1"] + .1:
        reach = m["west_to"] if x < (m["x0"] + m["x1"]) / 2 else m["east_to"]
        return DEN["z1"] - .5 <= z <= reach + .1
    return False


def in_den_cut(x, y, z):
    d = DEN
    if den_inside(x, z, .3) and d["floor"] + .05 < y < den_roof(x, z) + .3:
        return True
    m = MOUTH
    if m["x0"] - .1 <= x <= m["x1"] + .1 and d["floor"] + .05 < y < m["top"]:
        reach = m["west_to"] if x < (m["x0"] + m["x1"]) / 2 else m["east_to"]
        return d["z1"] - .5 <= z <= reach + .1
    return False


# ------------------------------------------------------------------------------------------------ the terrace top
def in_terrace_cut(x, y, z):
    s, t = tier_st(x, z)
    return abs(s) <= TIER_HALF[0] and abs(t) <= TIER_HALF[1] and y > 27.0


def in_cut(x, y, z):
    return in_den_cut(x, y, z) or in_path_cut(x, y, z) or in_terrace_cut(x, y, z)


# ---------------------------------------------------------------------------------------------------------- carving
CARVE = ("Rocks_Walls__", "Terrain_Ground__", "Landmarks__", "Anim__Landmark_GlowGrotto_Crystals__")
KEEP = ("Landmarks__trim",)          # the lintel over the mouth stays


def _roblox(v):
    return v.x, v.z + 4, -v.y


def carve(objs):
    """Delete the faces of the carved categories that lie in the cut (face centre in it, or any corner inside the walking
    corridor or the room). Returns the names actually changed."""
    changed = []
    for o in objs:
        if not o.name.startswith(CARVE) or o.name in KEEP:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        mw = o.matrix_world
        doomed = []
        for f in bm.faces:
            c = _roblox(mw @ f.calc_center_median())
            if in_cut(*c):
                doomed.append(f)
                continue
            corners = [_roblox(mw @ v.co) for v in f.verts]
            ys = [q[1] for q in corners]
            # Long faces whose centre misses the cut but which span it (the old grotto's floor-to-roof slivers; rock
            # poking up through the terrace floor).
            if den_inside(c[0], c[2], .3) and min(ys) < den_roof(c[0], c[2]) - .1 and max(ys) > DEN["floor"] - .5:
                doomed.append(f)
                continue
            st = tier_st(c[0], c[2])
            if abs(st[0]) <= TIER_HALF[0] and abs(st[1]) <= TIER_HALF[1] and max(ys) > 28.5:
                doomed.append(f)
                continue
            # Fable blockout R1 1: one floor at the threshold. Any old floor or sill over the room and the mouth goes
            # (the new floor covers it): the dark triangle and the raised sill at the mouth.
            if all(den_floor_plan(q[0], q[2]) for q in corners) and max(ys) > DEN["floor"] - .8 and min(ys) < DEN["floor"] + 2.5:
                doomed.append(f)
                continue
            if any(in_den_cut(*p) or (in_path_cut(*p) and _nearest(p[0], p[2])["h"] + .3 < p[1] < _nearest(p[0], p[2])["h"] + 6)
                   for p in corners):
                doomed.append(f)
        if doomed:
            bmesh.ops.delete(bm, geom=doomed, context="FACES")
            # Fable blockout R1 5: orphan shards left over the terrace (small islands of faces) go too.
            seen, shards = set(), []
            bm.faces.ensure_lookup_table()
            for f in bm.faces:
                if f.index in seen:
                    continue
                stack, island = [f], []
                seen.add(f.index)
                while stack:
                    g = stack.pop()
                    island.append(g)
                    for e in g.edges:
                        for h in e.link_faces:
                            if h.index not in seen:
                                seen.add(h.index)
                                stack.append(h)
                if len(island) <= 8:
                    cs = [_roblox(mw @ g.calc_center_median()) for g in island]
                    if all(abs(tier_st(q[0], q[2])[0]) <= TIER_HALF[0] + 3 and abs(tier_st(q[0], q[2])[1]) <= TIER_HALF[1] + 3
                           and q[1] > 25 for q in cs):
                        shards += island
            if shards:
                bmesh.ops.delete(bm, geom=shards, context="FACES")
            bm.to_mesh(o.data)
            o.data.update()
            changed.append(o.name)
        bm.free()
    return changed


# ------------------------------------------------------------------------------------------------- new geometry
class Piece:
    """New faces for one source-like object, UVs world-projected at the island's density for its material."""

    def __init__(self, name, density, colour):
        self.name, self.k, self.colour = name, density, colour
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.float_color.new("Col")

    def face(self, pts, out):
        """pts in Roblox studs; wound to face `out` (Roblox)."""
        vs = [Vector((p[0], -p[2], p[1] - 4)) for p in pts]
        n = (vs[1] - vs[0]).cross(vs[2] - vs[0])
        o = Vector((out[0], -out[2], out[1]))
        if n.length > 1e-9 and n.dot(o) < 0:
            vs = vs[::-1]
            n = -n
        f = self.bm.faces.new([self.bm.verts.new(v) for v in vs])
        f.smooth = True
        ax = max(range(3), key=lambda i: abs(n[i])) if n.length > 1e-9 else 2
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            co = loop.vert.co
            loop[self.uv].uv = (co[a] * self.k, co[b] * self.k)
            loop[self.col] = self.colour

    def quad_strip(self, rows, out_fn):
        """rows: list of lists of points (same length); faces between consecutive rows; out_fn(i, j) -> outward."""
        for i in range(len(rows) - 1):
            for j in range(len(rows[i]) - 1):
                q = [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
                self.face(q, out_fn(i, j))

    def box(self, centre, size, yaw=0.0, rnd=None, jitter=.0):
        """A rough block (corners jittered), Roblox centre/size, yaw about Y."""
        cx, cy, cz = centre
        sx, sy, sz = (v / 2 for v in size)
        c, s = math.cos(yaw), math.sin(yaw)
        corners = {}
        for ix in (-1, 1):
            for iy in (-1, 1):
                for iz in (-1, 1):
                    j = (rnd.uniform(-jitter, jitter) if rnd else 0.0)
                    lx, ly, lz = ix * sx + j, iy * sy, iz * sz + j * .7
                    corners[(ix, iy, iz)] = (cx + lx * c + lz * s, cy + ly, cz - lx * s + lz * c)
        for axis in range(3):
            for sign in (-1, 1):
                quad = []
                for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    key = [0, 0, 0]
                    key[axis] = sign
                    others = [i for i in range(3) if i != axis]
                    key[others[0]], key[others[1]] = u, v
                    quad.append(corners[tuple(key)])
                nl = [0.0, 0.0, 0.0]
                nl[axis] = sign
                out = (nl[0] * c + nl[2] * s, nl[1], -nl[0] * s + nl[2] * c)
                self.face(quad, out)

    def build(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def _density_and_colour(objs, source_name, fallback=.25):
    o = next((x for x in objs if x.name == source_name), None)
    if o is None:
        return fallback, (1.0, 1.0, 1.0, 1.0)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    ratios = []
    for f in list(bm.faces)[:200]:
        for loop in f.loops:
            nxt = loop.link_loop_next
            d = (nxt.vert.co - loop.vert.co).length
            if d > .2:
                ratios.append((nxt[uvl].uv - loop[uvl].uv).length / d)
    col = bm.loops.layers.float_color.get("Col")
    colour = tuple(bm.faces[0].loops[0][col]) if col is not None and len(bm.faces) else (1.0, 1.0, 1.0, 1.0)
    bm.free()
    ratios.sort()
    return (ratios[len(ratios) // 2] if ratios else fallback), colour


def build_path(objs):
    """CD_CliffPath__dirt_path (the walk surface), CD_CliffPath__cliff_rock (back wall, banks, steps, lip, fin, notch)."""
    rock_k, rock_c = _density_and_colour(objs, "Rocks_Walls__cliff_rock")
    dirt_k, dirt_c = _density_and_colour(objs, "Terrain_Ground__dirt_path")
    dirt = Piece("CD_CliffPath__dirt_path", dirt_k, dirt_c)
    rock = Piece("CD_CliffPath__cliff_rock", rock_k, rock_c)
    S = path_samples()
    rnd = random.Random(2611)

    def P(s, a, y):
        return (s["x"] + s["out"][0] * a, y, s["z"] + s["out"][1] * a)

    def Q(s, a, y):                                   # along the consistent side (ribbons)
        return (s["x"] + s["side"][0] * a, y, s["z"] + s["side"][1] * a)
    for s0, s1 in zip(S, S[1:]):
        w0, w1 = s0["w"] / 2, s1["w"] / 2
        if s0["step"] and s1["step"]:
            # drawn steps (the walk-surface group: they never collide; the smooth ramp carries feet), treads and risers
            y0, y1 = s0["tread"], s1["tread"]
            dirt.face([Q(s0, -w0, y0), Q(s0, w0, y0), Q(s1, w1, y0), Q(s1, -w1, y0)], (0, 1, 0))
            if abs(y1 - y0) > 1e-3:
                dirt.face([Q(s1, -w1, y0), Q(s1, w1, y0), Q(s1, w1, y1), Q(s1, -w1, y1)],
                          (-s1["dir"][0], 0, -s1["dir"][1]))
        else:
            dirt.face([Q(s0, -w0, s0["h"]), Q(s0, w0, s0["h"]), Q(s1, w1, s1["h"]), Q(s1, -w1, s1["h"])], (0, 1, 0))
        if s0["flip"] != s1["flip"]:
            continue                                  # the hairpin's apex: the lawn side swaps; no wall or bank quad here
        # the back wall (cut face), leaning back 20 degrees up to the ground, with a .6 cap into the hill
        if s0["back"] > .05 or s1["back"] > .05:
            b0, b1 = s0["back"], s1["back"]
            out0 = (-s0["out"][0], .35, -s0["out"][1])
            rock.face([P(s0, -w0, s0["h"] - .1), P(s1, -w1, s1["h"] - .1), P(s1, -w1 - b1, s1["top"]), P(s0, -w0 - b0, s0["top"])],
                      (s0["out"][0], .35, s0["out"][1]))
            rock.face([P(s0, -w0 - b0, s0["top"]), P(s1, -w1 - b1, s1["top"]), P(s1, -w1 - b1 - .6, s1["top"] + .15),
                       P(s0, -w0 - b0 - .6, s0["top"] + .15)], (0, 1, 0))
        # the supports: where the ground beside an edge is below the path, a bank down to it (dry stone)
        for side in (1, -1):
            a0, a1 = side * w0, side * w1
            g0 = ground(*P(s0, a0 + side * .5, 0)[::2]) or s0["h"] - 8
            g1 = ground(*P(s1, a1 + side * .5, 0)[::2]) or s1["h"] - 8
            if side < 0 and (s0["back"] > .05 or s1["back"] > .05):
                continue
            drop0, drop1 = s0["h"] - g0, s1["h"] - g1
            if drop0 > .3 or drop1 > .3:
                d0, d1 = max(drop0, .3), max(drop1, .3)
                rock.face([P(s0, a0, s0["h"]), P(s1, a1, s1["h"]), P(s1, a1 + side * d1 * .55, s1["h"] - d1 - .4),
                           P(s0, a0 + side * d0 * .55, s0["h"] - d0 - .4)], (s0["out"][0] * side, .3, s0["out"][1] * side))
    # the stone lip on the lawn side where the drop is over 1.2: blocks 2.0 long, gaps 1.2, 1.2 to 1.8 high
    run = 0.0
    for s in S:
        if s["step"]:
            continue
        g = ground(*P(s, s["w"] / 2 + 1.0, 0)[::2])
        if g is None or s["h"] - g < 1.2:
            run = 0.0
            continue
        run += SAMPLE
        if run >= 3.2:
            run = 0.0
            hgt = rnd.uniform(1.2, 1.8)
            c = P(s, s["w"] / 2 + .35, s["h"] + hgt / 2 - .15)
            rock.box(c, (2.0, hgt, .7), yaw=math.atan2(-s["dir"][1], s["dir"][0]), rnd=rnd, jitter=.12)
    # the rock fin hiding the turn (10 wide, top 28), and the notch's two rocks at the arrival
    fx, fz = tier_xz(41.0, 38.0)
    fg = ground(fx, fz) or 5.0
    yaw = math.atan2(-TIER_D[1], TIER_D[0])        # local X along the ridge
    rock.box((fx, (fg - 1 + 28) / 2, fz), (10.0, 28 - fg + 1, 2.4), yaw=yaw, rnd=rnd, jitter=.4)
    end = PATH_CTRL[-1]
    for ds in (-4.2, 4.2):
        nx, nz = tier_xz(end[0] + ds, end[1] + .6)
        ng = ground(nx, nz) or 23.0
        rock.box((nx, (ng - .5 + 32.0) / 2, nz), (2.6, 32.0 - ng + .5, 2.6), yaw=yaw, rnd=rnd, jitter=.3)
    return [dirt.build(), rock.build()]


def build_den(objs):
    """CD_PlayDen__cliff_rock (walls, the low dome, the mouth's jambs and soffit, facing in) and CD_PlayDen__dirt_path
    (the floor, room and mouth)."""
    rock_k, rock_c = _density_and_colour(objs, "Landmarks__cliff_rock")
    dirt_k, dirt_c = _density_and_colour(objs, "Terrain_Ground__dirt_path")
    rock = Piece("CD_PlayDen__cliff_rock", rock_k, rock_c)
    floor = Piece("CD_PlayDen__dirt_path", dirt_k, dirt_c)
    d, m = DEN, MOUTH
    rnd = random.Random(1907)
    # the boundary, walked anticlockwise seen from above (Roblox x right, z down the page): front (z1) west -> east
    # stops at the mouth; the corners at the back are arcs.
    r = d["corner"]
    pts = []
    def line(a, b, n):
        for k in range(n):
            pts.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    line((m["x1"], d["z1"]), (d["x1"], d["z1"]), 4)
    line((d["x1"], d["z1"]), (d["x1"], d["z0"] + r), 8)
    for k in range(7):
        a = -math.pi / 2 * k / 6
        pts.append((d["x1"] - r + r * math.cos(a), d["z0"] + r + r * math.sin(a)))
    line((d["x1"] - r, d["z0"]), (d["x0"] + r, d["z0"]), 16)
    for k in range(7):
        a = -math.pi / 2 - math.pi / 2 * k / 6
        pts.append((d["x0"] + r + r * math.cos(a), d["z0"] + r + r * math.sin(a)))
    line((d["x0"], d["z0"] + r), (d["x0"], d["z1"]), 8)
    line((d["x0"], d["z1"]), (m["x0"], d["z1"]), 4)
    pts.append((m["x0"], d["z1"]))
    pts = [p for i, p in enumerate(pts) if i == 0 or (abs(p[0] - pts[i - 1][0]) > 1e-6 or abs(p[1] - pts[i - 1][1]) > 1e-6)]
    noise = lambda x, z: .25 * math.sin(x * 1.3 + z * .7) * math.cos(z * 1.1 - x * .4)
    cx, cz = (d["x0"] + d["x1"]) / 2, (d["z0"] + d["z1"]) / 2
    rows_n = 4
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        inward = _unit(cx - (x0 + x1) / 2, cz - (z0 + z1) / 2)
        col0 = [(x0 + inward[0] * noise(x0, z0), d["floor"] - .3 + (den_roof(x0, z0) - d["floor"] + .3) * k / rows_n,
                 z0 + inward[1] * noise(x0, z0)) for k in range(rows_n + 1)]
        col1 = [(x1 + inward[0] * noise(x1, z1), d["floor"] - .3 + (den_roof(x1, z1) - d["floor"] + .3) * k / rows_n,
                 z1 + inward[1] * noise(x1, z1)) for k in range(rows_n + 1)]
        for k in range(rows_n):
            rock.face([col0[k], col1[k], col1[k + 1], col0[k + 1]], (inward[0], 0, inward[1]))
    # over the mouth: the front wall from the soffit up to the roof's edge
    for k in range(6):
        xa, xb = m["x0"] + (m["x1"] - m["x0"]) * k / 6, m["x0"] + (m["x1"] - m["x0"]) * (k + 1) / 6
        rock.face([(xa, m["top"], d["z1"]), (xb, m["top"], d["z1"]), (xb, den_roof(xb, d["z1"]), d["z1"]),
                   (xa, den_roof(xa, d["z1"]), d["z1"])], (0, 0, -1))
    # the roof: a height field over the room, facing down
    nx, nz = 14, 10
    grid = []
    for i in range(nx + 1):
        row = []
        for j in range(nz + 1):
            x = d["x0"] + (d["x1"] - d["x0"]) * i / nx
            z = d["z0"] + (d["z1"] - d["z0"]) * j / nz
            row.append((x, den_roof(x, z) + .15 * math.sin(x * .9) * math.sin(z * .8), z))
        grid.append(row)
    rock.quad_strip(grid, lambda i, j: (0, -1, 0))
    # the mouth: jambs (facing into the opening) and the soffit under the lintel
    for x, sgn, reach in ((m["x0"], 1, m["west_to"]), (m["x1"], -1, m["east_to"])):
        rock.face([(x, d["floor"] - .3, d["z1"]), (x, d["floor"] - .3, reach), (x, m["top"], reach), (x, m["top"], d["z1"])],
                  (sgn, 0, 0))
    rock.face([(m["x0"], m["top"], d["z1"] + .2), (m["x1"], m["top"], d["z1"] + .2), (m["x1"], m["top"], m["east_to"]),
               (m["x0"], m["top"], m["west_to"])], (0, -1, 0))
    # the floor: the room (fan from its middle over the boundary) and the mouth
    centre = (cx, d["floor"], cz)
    ring = [(x, d["floor"], z) for x, z in pts]
    for a, b in zip(ring, ring[1:] + ring[:1]):           # closed: the last wedge spans the mouth's width
        floor.face([centre, a, b], (0, 1, 0))
    # the mouth's floor: two halves to the same reach as the cut (west to -95, east to -99), .6 over the lawn (no seam)
    mid = (m["x0"] + m["x1"]) / 2
    for xa, xb, reach in ((m["x0"], mid, m["west_to"]), (mid, m["x1"], m["east_to"])):
        floor.face([(xa, d["floor"], d["z1"]), (xb, d["floor"], d["z1"]), (xb, d["floor"], reach + .6),
                    (xa, d["floor"], reach + .6)], (0, 1, 0))
    return [rock.build(), floor.build()]


def apply(sources):
    """--beta: carve the sources in place and add the new pieces. Returns (sources + new, carved names, new names)."""
    carved = carve(sources)
    new = build_path(sources) + build_den(sources)
    return sources + new, set(carved), {o.name for o in new}


def path_collision():
    """W7C_CD_CliffPath: the walk surface as one smooth ramp (the drawn steps never catch a foot), thickened down 1.5
    into a closed slab like the ground tiles, in Blender coordinates."""
    bm = bmesh.new()
    S = path_samples()
    top, bot = [], []
    for s in S:
        w = s["w"] / 2
        row_t, row_b = [], []
        for a in (-w, w):
            x, z = s["x"] + s["side"][0] * a, s["z"] + s["side"][1] * a
            row_t.append(bm.verts.new((x, -z, s["h"] - 4)))
            row_b.append(bm.verts.new((x, -z, s["h"] - 4 - 1.5)))
        top.append(row_t)
        bot.append(row_b)
    for i in range(len(S) - 1):
        bm.faces.new([top[i][0], top[i][1], top[i + 1][1], top[i + 1][0]])
        bm.faces.new([bot[i][0], bot[i + 1][0], bot[i + 1][1], bot[i][1]])
        for k in (0, 1):
            bm.faces.new([top[i][k], top[i + 1][k], bot[i + 1][k], bot[i][k]])
    for row_t, row_b in ((top[0], bot[0]), (top[-1], bot[-1])):
        bm.faces.new([row_t[0], row_b[0], row_b[1], row_t[1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("W7C_CD_CliffPath")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("W7C_CD_CliffPath", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def anchors():
    """The code side's anchors (world studs): den, path, terrace, evacuation."""
    S = path_samples()
    d, m = DEN, MOUTH
    centre_line = [{"x": round(s["x"], 3), "y": round(s["h"], 3), "z": round(s["z"], 3), "width": s["w"],
                    "steps": s["step"]} for s in S[::max(1, int(2.0 / SAMPLE))]]
    foot, arrival = S[0], S[-1]
    turn = min(S, key=lambda s: (s["x"] - tier_xz(41.0, 28.5)[0]) ** 2 + (s["z"] - tier_xz(41.0, 28.5)[1]) ** 2)
    outline = []
    for x, z in [(d["x1"], d["z1"]), (d["x1"], d["z0"] + d["corner"])] + [
            (d["x1"] - d["corner"] + d["corner"] * math.cos(-math.pi / 2 * k / 6), d["z0"] + d["corner"] + d["corner"] * math.sin(-math.pi / 2 * k / 6)) for k in range(7)] + [
            (d["x0"] + d["corner"] + d["corner"] * math.cos(-math.pi / 2 - math.pi / 2 * k / 6), d["z0"] + d["corner"] + d["corner"] * math.sin(-math.pi / 2 - math.pi / 2 * k / 6)) for k in range(7)] + [
            (d["x0"], d["z1"])]:
        if not outline or [round(x, 3), round(z, 3)] != outline[-1]:
            outline.append([round(x, 3), round(z, 3)])
    roof = {"x0": d["x0"], "z0": d["z0"], "step": 1.0, "nx": int(d["x1"] - d["x0"]) + 1, "nz": int(d["z1"] - d["z0"]) + 1,
            "y": [[round(den_roof(d["x0"] + i, d["z0"] + j), 2) for i in range(int(d["x1"] - d["x0"]) + 1)]
                  for j in range(int(d["z1"] - d["z0"]) + 1)]}
    return {
        "den": {"floorY": d["floor"], "outline": outline, "roof": roof, "wallY": d["wall"], "peakY": d["peak"],
                # The closer (Play Den architect review): the world builds a colliding CaveBlocker here, closed by
                # default; the code only opens it. A box on the mouth line, into each jamb .3, floor to the lintel.
                "mouth": {"x0": m["x0"], "x1": m["x1"], "top": m["top"], "z": d["z1"],
                          "blocker": {"center": [round((m["x0"] + m["x1"]) / 2, 3), round((d["floor"] + 10.2) / 2, 3), d["z1"]],
                                      "size": [round(m["x1"] - m["x0"] + .6, 3), round(10.2 - d["floor"], 3), 1.0], "yaw": 0}},
                # Fable's five bays along the back wall, facing the mouth (+Z); roof = the dome over each.
                "bays": [{"name": n, "use": u, "at": [x, d["floor"], z], "facing": [0, 0, 1], "width": 7.0,
                          "roof": round(den_roof(x, z), 2)} for n, u, x, z in (
                    ("Bay1", "DashGate", -18.0, -110.0), ("Bay2", "Niche", -12.0, -116.0), ("Bay3", "DeckTable", -7.0, -117.0),
                    ("Bay4", "Niche", -2.0, -116.0), ("Bay5", "Niche", 4.0, -110.0))],
                "doorstep": [-7.0, d["floor"], -98.5],        # just outside the mouth, on the threshold floor
                "pin": [-7.0, 12.0, -99.5],                    # a Show me pin over the mouth (the lintel is 10.2)
                "notice": {"at": [3.0, round(ground(3.0, -96.0) or 4.2, 2), -96.0], "facing": [0, 0, 1]},
                "backWallZ": d["z0"], "sign": {"under": "W7_Landmarks__trim", "y": 10.2, "x": -7.0, "z": -100.07},
                "lanterns": [[-15.5, 7.0, -98.0], [1.5, 7.0, -98.0], [-14.0, 8.0, -117.0], [0.0, 8.0, -117.0]],
                "region": {"min": [d["x0"], d["floor"], d["z0"]], "max": [d["x1"], d["peak"], d["z1"]]}},
        "path": {"foot": [round(foot["x"], 3), foot["h"], round(foot["z"], 3)],
                 "turn": [round(turn["x"], 3), turn["h"], round(turn["z"], 3)],
                 "arrival": [round(arrival["x"], 3), arrival["h"], round(arrival["z"], 3)],
                 "centreLine": centre_line, "control": [list(c) for c in PATH_CTRL]},
        "terrace": {"maxGroundY": 27.0, "gap": {"s": [26.0, 34.0]}},
        "evacuate": [-27.0, ground(-27.0, -84.0) or 4.6, -84.0],
    }
