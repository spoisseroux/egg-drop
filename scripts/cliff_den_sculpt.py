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
    # round 6 (Spencer beta 25 "everything feels a little too small"; Fable DEN-ROUND6-LOOK 2): 9 wide, the turn pocket
    # 12; the return leg stays 6 (it is outside the terrace footprint only at t >= 22); the outbound leg moves out to
    # t 33 from s 28 so its inner edge (28.5) clears the return leg's outer edge (28) where they pass (architect: at 9
    # wide on t 31 the legs overlapped by 2.7 in plan)
    (-28.0, 29.5, 4.6, 9.0),     # foot
    (-20.0, 30.5, 6.9, 9.0),
    (-12.0, 33.0, 9.2, 9.0),
    (-4.0, 34.2, 11.5, 9.0),
    (4.0, 31.1, 13.8, 9.0),      # round 6: past the Paw Glade the wider path grows into the hill (t -1.5), so its
    (12.0, 30.5, 16.1, 9.0),     # lawn edge and the glade's rim keep their room (ParkSites)
    (20.0, 31.0, 18.4, 9.0),
    (28.0, 33.0, 20.7, 9.0),     # code review: the outbound leg stays clear of the return leg (it overhung it at
    (35.0, 33.0, 22.7, 9.0),     # knee height)
    (40.0, 31.0, 23.0, 12.0),    # the turn pocket
    (42.0, 26.5, 23.0, 12.0),
    (37.5, 25.0, 24.6, 6.5),     # the return leg (outside the terrace footprint, t >= 22); 6.5 so the spline from the
    (30.0, 22.0, 29.0, 6.5),     # 12-wide pocket never dips under 6 (Tier spec)
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


_TREAD_GRID = None


def _tread_grid():
    """Path samples bucketed by 4-stud cell (each in every cell its tread and a little more can reach)."""
    global _TREAD_GRID
    if _TREAD_GRID is None:
        grid = {}
        for s in path_samples():
            r = s["w"] / 2 + SAMPLE + 1.0
            for cx in range(math.floor((s["x"] - r) / 4), math.floor((s["x"] + r) / 4) + 1):
                for cz in range(math.floor((s["z"] - r) / 4), math.floor((s["z"] + r) / 4) + 1):
                    grid.setdefault((cx, cz), []).append(s)
        _TREAD_GRID = grid
    return _TREAD_GRID


def over_tread(x, y, z, margin=.3, head=6.5):
    """Round 6 (Studio R6c rays): is (x, y, z) over ANY sample's tread (its width plus `margin`), 0.3 to `head` above
    it? Unlike in_path_cut this tests every nearby sample, not only the nearest, so where the hairpin's legs run side
    by side a face over the lower leg is not let off by the upper leg's height."""
    for s in _tread_grid().get((math.floor(x / 4), math.floor(z / 4)), ()):
        along = (x - s["x"]) * s["dir"][0] + (z - s["z"]) * s["dir"][1]
        if abs(along) > SAMPLE * .6:
            continue
        a = (x - s["x"]) * s["out"][0] + (z - s["z"]) * s["out"][1]
        if abs(a) <= s["w"] / 2 + margin and s["h"] + .3 < y < s["h"] + head:
            return True
    return False


def face_over_tread(corners, margin=.3, head=6.5):
    """Round 6 (Studio R6d: big decimated faces spanned the tread with every probe point off it): does the face (a
    polygon of Roblox points) pass 0.3 to `head` over any tread point under its footprint? Tread points are each path
    sample's cross-section at 1-stud steps (plus the edges and `margin`); the face's height there comes from its plane."""
    xs, zs = [q[0] for q in corners], [q[2] for q in corners]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    seen = set()
    grid = _tread_grid()
    for cx in range(math.floor(x0 / 4), math.floor(x1 / 4) + 1):
        for cz in range(math.floor(z0 / 4), math.floor(z1 / 4) + 1):
            for s in grid.get((cx, cz), ()):
                if id(s) in seen:
                    continue
                seen.add(id(s))
                half = s["w"] / 2 + margin
                k = max(2, int(math.ceil(half * 2)))
                for j in range(k + 1):
                    a = -half + 2 * half * j / k
                    px, pz = s["x"] + s["out"][0] * a, s["z"] + s["out"][1] * a
                    if not (x0 <= px <= x1 and z0 <= pz <= z1):
                        continue
                    for t in range(1, len(corners) - 1):      # fan triangles
                        A, B, C = corners[0], corners[t], corners[t + 1]
                        den = (B[2] - C[2]) * (A[0] - C[0]) + (C[0] - B[0]) * (A[2] - C[2])
                        if abs(den) < 1e-9:
                            continue
                        u = ((B[2] - C[2]) * (px - C[0]) + (C[0] - B[0]) * (pz - C[2])) / den
                        v = ((C[2] - A[2]) * (px - C[0]) + (A[0] - C[0]) * (pz - C[2])) / den
                        w = 1 - u - v
                        if u < -1e-6 or v < -1e-6 or w < -1e-6:
                            continue
                        y = u * A[1] + v * B[1] + w * C[1]
                        if s["h"] + .3 < y < s["h"] + head:
                            return True
    return False


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
# Round 6 (Spencer beta 25: "the cave entrance is way too smal"; Fable DEN-ROUND6-LOOK 1-2; fit checked against the
# walk grid: 3+ studs of rock over the roof everywhere behind the front strip): the room 36 x 24, walls 10 over the
# floor, peak 17; the mouth a rough arch 18 wide, 11 clear at the crown and 8.5 at the shoulders.
DEN = {"x0": -25.0, "x1": 11.0, "z0": -124.5, "z1": -100.5, "floor": 4.2, "wall": 14.2, "peak": 21.2, "corner": 6.0}
MOUTH = {"x0": -16.0, "x1": 2.0, "top": 15.2, "shoulder": 12.7, "west_to": -95.0, "east_to": -99.0}


def mouth_top(x):
    """The arch over the mouth at x: the crown (MOUTH top) at the middle, the shoulders at the jambs."""
    m = MOUTH
    u = (x - (m["x0"] + m["x1"]) / 2) / ((m["x1"] - m["x0"]) / 2)
    return m["shoulder"] + (m["top"] - m["shoulder"]) * max(0.0, 1 - u * u)
SOFFIT_TO = -99.8                                 # the soffit's outer edge: just past the lintel trim (z -100.07)


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
    if m["x0"] - .1 <= x <= m["x1"] + .1 and d["floor"] + .05 < y < mouth_top(x):
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
# round 6 (Studio R6c rays): the plain rock tiles were never carved, so a colliding rock kept its hulls over the 9-wide
# path (the path art only drew a visual re-cut over it). They get the corridor and room rules only (no den-roof,
# tier or floor-plan rules, no shard sweep).
CARVE_ROCKS = ("Rocks__",)
KEEP = ()   # round 6: the old door (marble, trim, gold and teal caps) goes with the bigger mouth; bars hidden while open


def _roblox(v):
    return v.x, v.z + 4, -v.y


def carve(objs):
    """Delete the faces of the carved categories that lie in the cut (face centre in it, or any corner inside the walking
    corridor or the room). Returns the names actually changed."""
    changed = []
    for o in objs:
        rock = o.name.startswith(CARVE_ROCKS)
        if not (o.name.startswith(CARVE) or rock) or o.name in KEEP:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        mw = o.matrix_world
        doomed = []
        for f in bm.faces:
            c = _roblox(mw @ f.calc_center_median())
            if rock:
                corners = [_roblox(mw @ v.co) for v in f.verts]
                n = len(corners)
                probes = corners + [tuple((corners[k][j] + corners[(k + 1) % n][j]) / 2 for j in range(3)) for k in range(n)]
                probes += [tuple((q[j] + c[j]) / 2 for j in range(3)) for q in corners] + [c]
                if any(in_den_cut(*p) or over_tread(*p) for p in probes) or face_over_tread(corners):
                    doomed.append(f)
                continue
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
            # round 6 (Studio R6 rays: big faces whose corners sat outside the 9-wide corridor still spanned over the
            # tread, 1 to 5 over it): test the edge midpoints and the points halfway to the centre too, not only corners
            n = len(corners)
            probes = corners + [tuple((corners[k][j] + corners[(k + 1) % n][j]) / 2 for j in range(3)) for k in range(n)]
            probes += [tuple((q[j] + c[j]) / 2 for j in range(3)) for q in corners] + [c]
            if any(in_den_cut(*p) or over_tread(*p) for p in probes) or face_over_tread(corners):
                doomed.append(f)
        if doomed and rock:
            bmesh.ops.delete(bm, geom=doomed, context="FACES")
            loose = [v for v in bm.verts if not v.link_faces]
            if loose:
                bmesh.ops.delete(bm, geom=loose, context="VERTS")
            bm.to_mesh(o.data)
            o.data.update()
            changed.append(o.name)
        elif doomed:
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
            # round 6: no loose vertices left behind (they kept a carved part's bounds at the old size)
            loose = [v for v in bm.verts if not v.link_faces]
            if loose:
                bmesh.ops.delete(bm, geom=loose, context="VERTS")
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


PATH_BLOCKS = []   # (kind, centre, size, yaw) of the lip stones, the fin and the notch rocks, as build_path placed them


def build_path(objs):
    """CD_CliffPath__dirt_path (the walk surface), CD_CliffPath__cliff_rock (back wall, banks, steps, lip, fin, notch)."""
    PATH_BLOCKS.clear()
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
            PATH_BLOCKS.append(("lip", c, (2.0, hgt, .7), math.atan2(-s["dir"][1], s["dir"][0])))
    # the rock fin hiding the turn (10 wide, top 28), and the notch's two rocks at the arrival
    fx, fz = tier_xz(41.0, 38.0)
    fg = ground(fx, fz) or 5.0
    yaw = math.atan2(-TIER_D[1], TIER_D[0])        # local X along the ridge
    rock.box((fx, (fg - 1 + 28) / 2, fz), (10.0, 28 - fg + 1, 2.4), yaw=yaw, rnd=rnd, jitter=.4)
    PATH_BLOCKS.append(("fin", (fx, (fg - 1 + 28) / 2, fz), (10.0, 28 - fg + 1, 2.4), yaw))
    # the notch's rocks stand either side of the arrival, across the path (Studio R1: placed along the ridge, one stood
    # in the path's last run, which also runs along the ridge)
    last = S[-1]
    for side in (-1, 1):
        off = last["w"] / 2 + 1.5
        nx, nz = last["x"] + last["side"][0] * off * side, last["z"] + last["side"][1] * off * side
        ng = ground(nx, nz) or 23.0
        rock.box((nx, (ng - .5 + 32.0) / 2, nz), (2.6, 32.0 - ng + .5, 2.6), yaw=yaw, rnd=rnd, jitter=.3)
        PATH_BLOCKS.append(("notch", (nx, (ng - .5 + 32.0) / 2, nz), (2.6, 32.0 - ng + .5, 2.6), yaw))
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
    # The soffit only spans the cliff's thickness, under the lintel trim (z -100.07): out to the jambs' reach it lay
    # under open sky on the west half and was the lawn's top surface (Play Den schema check, 2026-11-24).
    rock.face([(m["x0"], m["top"], d["z1"] + .2), (m["x1"], m["top"], d["z1"] + .2), (m["x1"], m["top"], SOFFIT_TO),
               (m["x0"], m["top"], SOFFIT_TO)], (0, -1, 0))
    # East of the east jamb the mouth's cut took the whole old ground face (a corner was in it): a rock shoulder from
    # the jamb's top down to the live ground covers the hole (x .5..3.5, z -100.5..-99).
    sx = m["x1"] + 3.0
    shoulder = [(m["x1"], m["top"], d["z1"]), (m["x1"], m["top"], m["east_to"]),
                (sx, (ground(sx, m["east_to"]) or 5.0) - .1, m["east_to"]), (sx, (ground(sx, d["z1"]) or 12.0) - .1, d["z1"])]
    rock.face(shoulder, (0, 1, 0))
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
        # a skirt under the lawn's edge, sloping .25 down: the carve takes whole lawn faces that reach into the mouth's
        # cut, which left a hole past the floor's edge at (-9, -94) (Play Den schema check, 2026-11-24)
        floor.face([(xa, d["floor"], reach + .6), (xb, d["floor"], reach + .6), (xb, d["floor"] - .25, reach + 1.8),
                    (xa, d["floor"] - .25, reach + 1.8)], (0, 1, 0))
    return [rock.build(), floor.build()]


# ------------------------------------------------------------------------------------------- collision (Studio R1)
# Roblox bakes a colliding mesh into a few convex hulls, solid behind single-sided faces: on the carved island those
# hulls filled the room, bridged the apron and the path (STUDIO-PROBE-R1). So near the den and the path no island mesh
# collides: their faces there move to non-colliding visual parts (CD_Region__<mat>), what is left of each colliding mesh
# near the region is cut into 32-stud tiles (small hulls), and the den and the path collide on boxes the server builds
# from CliffDenData.collision (architect review: primitives, exact, nothing to upload).
REGION_TOP = 23.0   # round 6: over the bigger den peak (21.2)
TILE = 32.0
# Studio R2 (2026-11-25): the carved island-wide cliff rock, left as one mesh past the ring, re-baked with hulls that
# moved by up to 10 studs on the east mountain and the north-west band (the decomposition is global: any cut changes it
# everywhere). These are tiled whole, so every hull stays inside its 32-stud tile, near the drawn surface.
TILE_ALL = ("Rocks_Walls__cliff_rock", "Landmarks__cliff_rock",
            # round 6 (architect): the old door's marble and trim stood inside the new mouth; carved, they are tiled
            # whole like the rock (a carved island-wide marble re-baked one hull bridging the plaza, Studio R2)
            "Landmarks__marble", "Landmarks__trim")


def in_region(x, y, z):
    """Where no island mesh may collide: the den (grown 2.5) under REGION_TOP, the mouth and its jambs, the path's
    corridor from its cut back wall to past the lawn edge, 6 under to 1 over the wall's top."""
    d, m = DEN, MOUTH
    if den_inside(x, z, 2.5) and y < REGION_TOP:
        return True
    if m["x0"] - 1.5 <= x <= m["x1"] + 1.5 and d["z1"] - .5 <= z <= m["west_to"] + 1.0 and y < m["top"] + 2.0:
        return True
    s = _nearest(x, z)
    a = (x - s["x"]) * s["out"][0] + (z - s["z"]) * s["out"][1]       # toward the lawn
    along = abs((x - s["x"]) * s["dir"][0] + (z - s["z"]) * s["dir"][1])
    return (along <= 1.5 and -(s["w"] / 2 + s["back"] + 1.5) <= a <= s["w"] / 2 + 3.0
            and s["h"] - 6.0 <= y <= s["top"] + 1.0)


def _tile_number(x, z):
    return (math.floor(x / TILE) + 20) * 100 + (math.floor(z / TILE) + 20)


def split_region(objs, collides):
    """Colliding island meshes: faces in the region move to CDRegion_<cat>__<mat> (visual, never colliding); faces in
    the 32-stud tiles around the region move to CDTile<NN>_<cat>__<mat> (colliding, small); the rest stays. Returns
    (objects, names changed)."""
    ring = set()
    for x in range(-110, 40, 4):
        for z in range(-140, -20, 4):
            for y in (5.0, 12.0, 20.0, 27.0):
                if in_region(x, y, z):
                    for dx in (-TILE, 0, TILE):
                        for dz in (-TILE, 0, TILE):
                            ring.add(_tile_number(x + dx, z + dz))
                    break
    out, changed = [], set()
    col = bpy.context.scene.collection
    for o in objs:
        if not (o.name.startswith(("Rocks_", "Landmarks__")) and collides(o.name)):
            out.append(o)
            continue
        cat, mat = o.name.rsplit("__", 1)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        mw = o.matrix_world
        where = {}
        for f in bm.faces:
            c = _roblox(mw @ f.calc_center_median())
            if in_region(*c):
                where[f.index] = "CDRegion_" + cat
            else:
                n = _tile_number(c[0], c[2])
                if n in ring or o.name in TILE_ALL:
                    where[f.index] = f"CDTile{n}_" + cat
        bm.free()
        if not where:
            out.append(o)
            continue
        for name in sorted(set(where.values())):
            keep = {i for i, v in where.items() if v == name}
            piece = o.copy()
            piece.data = o.data.copy()
            pb = bmesh.new()
            pb.from_mesh(piece.data)
            pb.faces.ensure_lookup_table()
            bmesh.ops.delete(pb, geom=[f for f in pb.faces if f.index not in keep], context="FACES")
            bmesh.ops.delete(pb, geom=[v for v in pb.verts if not v.link_faces], context="VERTS")   # round 6
            pb.to_mesh(piece.data)
            pb.free()
            piece.name = name + "__" + mat
            col.objects.link(piece)
            out.append(piece)
        rb_ = bmesh.new()
        rb_.from_mesh(o.data)
        rb_.faces.ensure_lookup_table()
        bmesh.ops.delete(rb_, geom=[f for f in rb_.faces if f.index in where], context="FACES")
        bmesh.ops.delete(rb_, geom=[v for v in rb_.verts if not v.link_faces], context="VERTS")   # round 6
        rb_.to_mesh(o.data)
        rb_.free()
        o.data.update()
        changed.add(o.name)
        if len(o.data.polygons):
            out.append(o)
    return out, changed


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
    n = math.sqrt(sum(v * v for v in a)) or 1.0
    return tuple(v / n for v in a)


def _dot(a, b):
    return sum(p * q for p, q in zip(a, b))


def _box(kind, centre, size, X=(1.0, 0.0, 0.0), Y=(0.0, 1.0, 0.0)):
    """A collision box: centre, size along its own X, Y, Z (Z = X cross Y), r = CFrame.new's nine numbers by rows."""
    X, Y = _norm(X), _norm(Y)
    Z = _cross(X, Y)
    return {"kind": kind, "c": [round(v, 4) for v in centre], "s": [round(max(v, .05), 4) for v in size],
            "r": [round(v, 6) for v in (X[0], Y[0], Z[0], X[1], Y[1], Z[1], X[2], Y[2], Z[2])]}


def _aabb(kind, lo, hi):
    return _box(kind, [(a + b) / 2 for a, b in zip(lo, hi)], [b - a for a, b in zip(lo, hi)])


def collision_boxes():
    """The den, the mouth and the path as boxes (CliffDenData.collision.boxes): exact, every top a walk surface."""
    d, m = DEN, MOUTH
    F, top = d["floor"], d["wall"]   # round 6: the ceiling box at the wall top (the dome rises over it)
    out = [_aabb("floor", (d["x0"], F - 2, d["z0"]), (d["x1"], F, d["z1"]))]
    # the mouth and the apron's first studs: one slab to the west jamb's reach (the lawn there sits 4.1 to 4.5)
    # code review r6: to x1 + 1, under the east jamb's foot (no floor there before: non-colliding region)
    out.append(_aabb("floor", (m["x0"], F - 2, d["z1"] - .5), (m["x1"] + 1.0, F, m["west_to"] + 1.8)))
    # the walls: each outline edge but the front, 2 thick outward, from under the floor to the ceiling
    pts = [(x, z) for x, z in anchors_outline()]
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    for (ax, az), (bx, bz) in zip(pts, pts[1:] + pts[:1]):
        if abs(az - d["z1"]) < 1e-6 and abs(bz - d["z1"]) < 1e-6:
            continue
        ln = math.hypot(bx - ax, bz - az)
        if ln < 1e-6:
            continue
        X = ((bx - ax) / ln, 0.0, (bz - az) / ln)
        nx, nz = -X[2], X[0]
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        if nx * (mx - cx) + nz * (mz - cz) < 0:
            nx, nz = -nx, -nz
        out.append(_box("wall", (mx + nx, (F - 1 + top + 1) / 2, mz + nz), (ln + .6, top + 1 - (F - 1), 2.0), X, (0, 1, 0)))
    # the front either side of the mouth (thin: the lawn beside the east jamb stays walkable), the jambs, the lintel
    for xa, xb in ((d["x0"] - 2, m["x0"]), (m["x1"], d["x1"] + 2)):
        out.append(_aabb("front", (xa, F - 1, d["z1"]), (xb, REGION_TOP, d["z1"] + .6)))
    out.append(_aabb("jamb", (m["x0"] - 1.0, F - 1, d["z1"]), (m["x0"], m["top"] + 1.0, m["west_to"])))
    # code review r6: the east jamb to the drawn collar's end (z1 + 3.6), so the drawn east wall cannot be walked through
    out.append(_aabb("jamb", (m["x1"], F - 1, d["z1"]), (m["x1"] + 1.0, m["top"] + 1.0, d["z1"] + 3.6)))
    # round 6: the arch's lintel box sits at the shoulders (a flat collider under the drawn crown)
    out.append(_aabb("lintel", (m["x0"] - 1.0, m["shoulder"], d["z1"]), (m["x1"] + 1.0, REGION_TOP, SOFFIT_TO)))
    out.append(_aabb("ceiling", (d["x0"] - 2, top, d["z0"] - 2), (d["x1"] + 2, top + 1.5, d["z1"])))
    # the path: treads on the smooth ramp (1.5 thick, each run overlapping the next), the cut back wall, the blocks
    S = path_samples()
    run = S[::3] + ([S[-1]] if (len(S) - 1) % 3 else [])
    for a, b in zip(run, run[1:]):
        pa, pb = (a["x"], a["h"], a["z"]), (b["x"], b["h"], b["z"])
        f = tuple(q - p for p, q in zip(pa, pb))
        ln = math.sqrt(_dot(f, f))
        X = _norm(f)
        Y = _norm(tuple(u - _dot((0, 1, 0), X) * x for u, x in zip((0, 1, 0), X)))
        c = tuple((p + q) / 2 - y * .75 for p, q, y in zip(pa, pb, Y))
        # round 6 (Studio R6e rays): on the switchback the boxes fan apart on the outer side; each overlaps its
        # neighbour by the width times the turn between them
        turn = abs(a["dir"][0] * b["dir"][1] - a["dir"][1] * b["dir"][0])
        out.append(_box("tread", c, (ln + .5 + max(a["w"], b["w"]) * turn, 1.5, max(a["w"], b["w"]) + .2), X, Y))
    for s0, s1 in zip(run, run[1:]):
        if s0["flip"] != s1["flip"] or not (s0["back"] > .05 or s1["back"] > .05):
            continue
        w0, w1 = s0["w"] / 2, s1["w"] / 2

        def P(s, a, y):
            return (s["x"] + s["out"][0] * a, y, s["z"] + s["out"][1] * a)
        A0, A1 = P(s0, -w0, s0["h"] - .6), P(s1, -w1, s1["h"] - .6)
        B0, B1 = P(s0, -w0 - s0["back"], s0["top"] + .5), P(s1, -w1 - s1["back"], s1["top"] + .5)
        Am = tuple((p + q) / 2 for p, q in zip(A0, A1))
        Bm = tuple((p + q) / 2 for p, q in zip(B0, B1))
        X = _norm(tuple(q - p for p, q in zip(A0, A1)))
        up = tuple(q - p for p, q in zip(Am, Bm))
        Y = _norm(tuple(u - _dot(up, X) * x for u, x in zip(up, X)))
        Z = _cross(X, Y)
        hill = (-s0["out"][0], 0.0, -s0["out"][1])
        if _dot(Z, hill) < 0:
            X = tuple(-v for v in X)
            Z = _cross(X, Y)
        hgt = abs(_dot(up, Y))
        c = tuple((p + q) / 2 + z * .75 for p, q, z in zip(Am, Bm, Z))
        out.append(_box("backwall", c, (math.dist(A0, A1) + .6, hgt + .4, 1.5), X, Y))
    assert PATH_BLOCKS, "build_path first"
    for kind, c, size, yaw in PATH_BLOCKS:
        out.append(_box(kind, c, size, (math.cos(yaw), 0.0, -math.sin(yaw)), (0, 1, 0)))
    return out


def anchors_outline():
    d = DEN
    outline = []
    for x, z in [(d["x1"], d["z1"]), (d["x1"], d["z0"] + d["corner"])] + [
            (d["x1"] - d["corner"] + d["corner"] * math.cos(-math.pi / 2 * k / 6), d["z0"] + d["corner"] + d["corner"] * math.sin(-math.pi / 2 * k / 6)) for k in range(7)] + [
            (d["x0"] + d["corner"] + d["corner"] * math.cos(-math.pi / 2 - math.pi / 2 * k / 6), d["z0"] + d["corner"] + d["corner"] * math.sin(-math.pi / 2 - math.pi / 2 * k / 6)) for k in range(7)] + [
            (d["x0"], d["z1"])]:
        if not outline or [round(x, 3), round(z, 3)] != outline[-1]:
            outline.append([round(x, 3), round(z, 3)])
    return outline


def apply(sources):
    """--beta: carve the sources in place and add the new pieces. Returns (sources + new, carved names, new names)."""
    carved = carve(sources)
    new = build_path(sources) + build_den(sources)
    return sources + new, set(carved), {o.name for o in new}


def anchors():
    """The code side's anchors (world studs): den, path, terrace, evacuation."""
    S = path_samples()
    d, m = DEN, MOUTH
    picked = S[::max(1, int(2.0 / SAMPLE))]
    if picked[-1] is not S[-1]:
        picked.append(S[-1])          # round 6: the line always ends at the arrival (the longer bend moved the stride)
    centre_line = [{"x": round(s["x"], 3), "y": round(s["h"], 3), "z": round(s["z"], 3), "width": s["w"],
                    "steps": s["step"]} for s in picked]
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
    def lawn(x, z):
        return round(ground(x, z) or 4.6, 2)
    # Fable's five bays, each a point it stands on and a point it looks toward (DenLayout: CFrame.lookAt): the side
    # bays face the room's middle, the back ones the mouth. roof = the dome over each.
    # round 6: the bays spread with the room; the Garden Dash gate's bay is 9 clear wide (Fable 4: 9 x 9)
    bays = [{"name": n, "use": u, "at": [x, d["floor"], z], "facing": [fx, d["floor"], fz], "width": w,
             "roof": round(den_roof(x, z), 2)} for n, u, x, z, fx, fz, w in (
        ("Bay1", "DashGate", -20.0, -112.0, -7.0, -106.0, 9.0), ("Bay2", "Niche", -13.0, -120.5, -13.0, -100.0, 7.0),
        ("Bay3", "DeckTable", -7.0, -121.5, -7.0, -100.0, 7.0), ("Bay4", "Niche", -1.0, -120.5, -1.0, -100.0, 7.0),
        ("Bay5", "Niche", 6.0, -112.0, -7.0, -106.0, 7.0))]
    # DenLayout.fromData's contract (schema 1, PLAY-DEN-BUILD-PLAN section 10): points as {x, y, z}; a spot is
    # {at, facing} with facing a point to look toward.
    return {
        "den": {"floorY": d["floor"], "roofY": min(b["roof"] for b in bays), "outline": outline, "roof": roof,
                "wallY": d["wall"], "peakY": d["peak"], "backWallZ": d["z0"],
                "room": {"min": [d["x0"], d["floor"], d["z0"]], "max": [d["x1"], d["peak"], d["z1"]]},
                # The closer (Play Den architect review): the world builds a colliding CaveBlocker here, closed by
                # default; the code only opens it. A box on the mouth line, into each jamb .3, floor to the lintel.
                "mouth": {"x1": m["x0"], "x2": m["x1"], "top": m["top"], "shoulder": m["shoulder"], "z": d["z1"],
                          # round 6 (architect): floor to the crown, so a closed den cannot be jumped
                          "blocker": {"center": [round((m["x0"] + m["x1"]) / 2, 3), round((d["floor"] + m["top"]) / 2, 3), d["z1"]],
                                      "size": [round(m["x1"] - m["x0"] + .6, 3), round(m["top"] - d["floor"], 3), 1.0], "yaw": 0}},
                "bays": bays,
                # The sign hangs under the lintel trim (y 10.2), its top under the mouth's top, facing the lawn.
                # round 6 (Fable 1.5): 8 x 2.2 hung under the brow, its bottom 9 over the floor
                # code review r6: 0.9 lower (its top 14.5, under the arch's 14.66 at the sign's ends)
                "sign": {"at": [-7.0, round(d["floor"] + 9.2, 3), round(d["z1"] + .6, 3)],
                         "facing": [-7.0, round(d["floor"] + 9.2, 3), -80.0]},
                # The notice board on the lawn east of the mouth, facing the lawn.
                # round 6 (architect): out of the east buttress, on the apron's east end
                "board": {"at": [9.0, lawn(9.0, -93.0), -93.0], "facing": [9.0, lawn(9.0, -93.0), -80.0]},
                # Show me's pin: on the mouth's floor just out of the mouth.
                "pin": [-7.0, d["floor"], -96.0],
                # Where the close puts players (past the waiting area and the apron, on the home Floor), facing out,
                # and their pets' landing.
                "doorstep": {"at": [-7.0, lawn(-7.0, -87.0), -87.0], "facing": [-7.0, lawn(-7.0, -87.0), -70.0],
                             "landing": [-7.0, lawn(-7.0, -84.0), -84.0]},
                # Two posts out of the mouth (the west one past the jamb's end, on the mouth's floor; the east one on
                # the lawn past the east jamb) and two wall lamps on the back wall.
                # round 6 (Fable 1.6): on hooks on the jambs' props at 7.5 over the floor; the wall lamps on the new back
                # code review r6: DenGreybox hangs them from the props (feet 1.6 in the opening, tops on the jambs);
                # these are where that lands, in the opening clear of the jamb rock
                "lanterns": [{"at": [m["x0"] + 1.45, d["floor"], round(d["z1"] + 1.0, 3)], "post": True},
                             {"at": [m["x1"] - 1.45, d["floor"], round(d["z1"] + 1.0, 3)], "post": True},
                             {"at": [-16.0, round(d["floor"] + 6.0, 3), round(d["z0"] + .6, 3)], "post": False},
                             {"at": [2.0, round(d["floor"] + 6.0, 3), round(d["z0"] + .6, 3)], "post": False}]},
        "path": {"foot": [round(foot["x"], 3), foot["h"], round(foot["z"], 3)],
                 "turn": [round(turn["x"], 3), turn["h"], round(turn["z"], 3)],
                 "arrival": [round(arrival["x"], 3), arrival["h"], round(arrival["z"], 3)],
                 "centreLine": centre_line, "control": [list(c) for c in PATH_CTRL]},
        # round 6 (Studio R6e rays): the return leg arrives at an angle, its inner edge out to s 36.1 (cl47)
        "terrace": {"maxGroundY": 27.0, "gap": {"s": [26.0, 37.0]}},
        "evacuate": [-27.0, ground(-27.0, -84.0) or 4.6, -84.0],
        "collision": {"boxes": collision_boxes()},
    }
