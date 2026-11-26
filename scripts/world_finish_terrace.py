"""Slice E, the terrace (WORLD-FINISH-LOOK.md section 3): the top of the hill, mown by nobody. Imported by
scripts/build_world_finish_art.py inside background Blender. Tier frame (s, t) as Tier.lua: s along the ridge (NE -38,
SW +38), t toward the garden (+22 the garden edge); the floor (collision) stays the greybox's at 29, the walls stay.

  W7_F_Terrace__grass         the cap: the floor in the home lawn's grass, its visual edge a soft bean 0.5 to 2.5 outside
                              the wall line (never inside), rolling over in a 0.6 grass lip
  W7_F_TerraceFace__cliff_rock  the hillside under the lip: rock leaning back 20 degrees down to the island (no
                              retaining wall); off the cliff path's corridor
  W7_F_TerraceTongues__grass  three grass tongues spilling 3 to 5 down the face
  W7_F_TerraceEarth__dirt_path  the worn patch where the path arrives (6 x 5)
  W7_F_TerraceRocks__cliff_rock three low outcrops (5 high at most) on the outer side and the north-east end, and the
                              lookout's slab (7 x 5) over the den's mouth
  W7_F_TerraceLog__bark       the lookout's log bench (6 long, top flattened)
  W7_F_TerraceTrunk__bark     the one tree's trunk (its crown: the Aero kit's round crown, cloned in game)
Lip stones (the path's kit) along the garden edge with gaps 2 to 6; tufts and shrubs as WorldDressing rows.
"""
from __future__ import annotations

import math

import bmesh
import bpy
import numpy as np

import cliff_den_sculpt as S
import world_finish_lib as L
import world_finish_path as Pth

Y = 29.0
HALF = (38.0, 22.0)
PARK = ((0.0, 5.0), 13.0)               # the Top Lawn's circle: kept clear
LOOKOUT = (-33.0, 16.0)
TREE = (20.0, -12.0)


def T(s, t, y=Y):
    x, z = S.tier_xz(s, t)
    return (x, y, z)


def edge_offset(d, perimeter):
    """How far the drawn edge stands outside the wall line, by distance d (studs) round the wall line: 0.5 to 2.5.
    Round 5 (Fable world R1 13): driven by the distance walked, not the angle, so the long garden side wanders as much
    as the ends do; three waves of about 10.5, 6.3 and 3.7 studs keep every straight run well under 12. Each wave is
    snapped to a whole number of waves round the loop, so the edge closes without a step (code review)."""
    w = 0.0
    for amp, lam, ph in ((.75, 10.5, .4), (.45, 6.3, 1.9), (.25, 3.7, .2)):
        lam = perimeter / max(1, round(perimeter / lam))
        w += amp * math.sin(2 * math.pi * d / lam + ph)
    return max(.5, min(2.5, 1.5 + w))


def outline(n=160):
    """The bean: points (s, t) round the rectangle (rounded corners r 4), each pushed out by edge_offset."""
    base = []
    a, b, r = HALF[0], HALF[1], 4.0
    for k in range(n):
        th = 2 * math.pi * k / n
        c, s_ = math.cos(th), math.sin(th)
        # a superellipse-ish rounded rectangle
        e = 8.0
        rx = a / (abs(c) ** e + (a / b * abs(s_)) ** e) ** (1 / e) if (c or s_) else a
        ps, pt = rx * c, rx * s_
        ps = max(-a, min(a, ps))
        pt = max(-b, min(b, pt))
        ln = math.hypot(c, s_ * a / b) or 1
        base.append((ps, pt, c / ln, s_ * a / b / ln))
    dist = [0.0]
    for k in range(1, n):
        dist.append(dist[-1] + math.hypot(base[k][0] - base[k - 1][0], base[k][1] - base[k - 1][1]))
    perimeter = dist[-1] + math.hypot(base[0][0] - base[-1][0], base[0][1] - base[-1][1])
    out = []
    for (ps, pt, ux, uy), d in zip(base, dist):
        off = edge_offset(d, perimeter)
        p = (ps + ux * off, pt + uy * off)
        x, z = S.tier_xz(*p)
        # round 9 (Spencer beta 35, shot 55: a band across the top of the stairs): the return leg's flight climbs along
        # the garden edge, half under the cap's rim, so the lip crossed its upper steps at chest height. The edge now
        # stands NOTCH back from the flight's inner edge all the way up (a notch in the bean for the stairs).
        fs = flight_side(x, z)
        if fs is not None and -(fs[1]["w"] / 2 + NOTCH) < fs[0] < fs[1]["w"] / 2:
            s = fs[1]
            to = -(s["w"] / 2 + NOTCH) - fs[0]
            p = S.tier_st(x + s["out"][0] * to, z + s["out"][1] * to)
        out.append(p)
    return out


NOTCH = .5                          # round 9: the cap and the face stand this far off the return flight's inner edge


def flight_side(x, z):
    """Round 9: (a, sample) for the return leg's flight at plan point (x, z): a is the signed offset from its centre line
    toward the lawn (`out`), from the sample whose cross-section holds the point (samples are 0.6 apart); None off the
    flight's length."""
    best = None
    for s in S.path_samples():
        if not s["step"]:
            continue
        along = (x - s["x"]) * s["dir"][0] + (z - s["z"]) * s["dir"][1]
        if abs(along) > .35 or (best is not None and abs(along) >= best[2]):
            continue
        best = ((x - s["x"]) * s["out"][0] + (z - s["z"]) * s["out"][1], s, abs(along))
    return None if best is None else best[:2]


def flight_clamp(x, z):
    """Round 9 (shot 55, the stairs' left cheek: the island's grass showed between the face and the steps): a face
    point over the flight (inside its width, or on its inner side closer than NOTCH) moves out to NOTCH past the
    inner edge. Returns (x, z, the flight's tread height there or None when the point is off the flight)."""
    fs = flight_side(x, z)
    if fs is None:
        return x, z, None
    a, s = fs
    if a >= s["w"] / 2 or a <= -(s["w"] / 2 + NOTCH + 2.0):
        return x, z, None
    if a > -(s["w"] / 2 + NOTCH):
        to = -(s["w"] / 2 + NOTCH) - a
        x, z = x + s["out"][0] * to, z + s["out"][1] * to
    return x, z, s["h"]


TUCK = (3.0, 6.0, .4, 8.0)          # round 9: a face point with the path's cut wall within 3.0 behind it (or within 6.0
                                    # in front of it) ends its column there, 0.4 into the wall; a column that ends on the
                                    # ground still reaches back into the wall when it stands within 8.0 of it
FLIGHT_FOOT = 1.9                   # round 9: by the flight the face runs down to this far under the tread (the steps
                                    # are 1.2 deep and stand up to 0.54 over the ramp)


def wall_tree():
    """Round 9 (Spencer beta 35, shots 56 and 57: the face's ragged foot hung loose over the path's cut wall, with holes
    showing the cap's underside): the path slice's cut wall (in the scene the terrace is built on), for tucking the
    face's columns into it. None when the scene has no path."""
    o = bpy.data.objects.get("W7_F_PathWall__cliff_rock")
    if o is None:
        return None
    from mathutils.bvhtree import BVHTree
    return BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get()), o.matrix_world, o.matrix_world.inverted()


def tuck_into(tree, p, out_dir, behind=None):
    """Round 9: where the face point p (Roblox) meets the cut wall: the point to end its column at, or None. out_dir is
    the face's outward plan direction (dx, dz). Behind the wall (the wall within TUCK[1] outward): p itself; in front of
    it (the wall within TUCK[0] inward): the wall's surface TUCK[2] further in."""
    if tree is None:
        return None
    t, mw, inv = tree
    from mathutils import Vector
    ln = math.hypot(*out_dir) or 1.0
    ox, oz = out_dir[0] / ln, out_dir[1] / ln
    o = inv @ L.bl(p)
    for sign, reach in ((1, TUCK[1]), (-1, behind or TUCK[0])):
        d = (inv.to_3x3() @ Vector((sign * ox, -sign * oz, 0))).normalized()
        hit = t.ray_cast(o, d, reach)
        if hit[0] is None:
            continue
        if sign > 0:
            return p
        w = L.rb(mw @ hit[0])
        return (w[0] - ox * TUCK[2], p[1], w[2] - oz * TUCK[2])
    return None


def edge_t(ol, s_):
    """The garden-side edge's t at s: the nearest outline point to (s, the wall line) on the garden side."""
    side = [p for p in ol if p[1] > 15]
    return min(side, key=lambda p: math.hypot(p[0] - s_, p[1] - HALF[1]))[1]


def lean_at(k, n):
    """Round 5 (Fable world R1 13): the face leans back 15 to 26 degrees from upright, varying round the terrace."""
    u = k / n * 2 * math.pi
    return math.radians(max(15.0, min(26.0, 21.5 + 4.0 * math.sin(7 * u + 1.0) + 2.0 * math.sin(17 * u))))


def near_path(x, z, grow=.6):
    s = S._nearest(x, z)
    a = (x - s["x"]) * s["out"][0] + (z - s["z"]) * s["out"][1]
    along = (x - s["x"]) * s["dir"][0] + (z - s["z"]) * s["dir"][1]
    return abs(along) <= 1.0 and abs(a) < s["w"] / 2 + grow, s


FLIGHT_GRASS = (1.5, .8)            # round 7 (Fable ROUND7 6b): within 1.5 of the flight, standing 0.8 over its tread


def by_flight(pts):
    """Is a face (Roblox points) within FLIGHT_GRASS[0] of the return leg's flight (beside it, along it) and standing
    more than FLIGHT_GRASS[1] over its tread there?"""
    near, over = FLIGHT_GRASS
    c = tuple(sum(p[k] for p in pts) / len(pts) for k in range(3))
    for s in S.path_samples():
        if not s["step"]:
            continue
        along = (c[0] - s["x"]) * s["dir"][0] + (c[2] - s["z"]) * s["dir"][1]
        a = (c[0] - s["x"]) * s["out"][0] + (c[2] - s["z"]) * s["out"][1]
        if abs(along) <= .6 and abs(a) <= s["w"] / 2 + near and c[1] > s["h"] + over:
            return True
    return False


MOUTH_ZONE = (3.0, 2.0, 5.0)        # round 8: past either jamb, in front of the den's front wall, over the crown


def over_mouth(x, y, z):
    """Round 8 (Spencer beta 34, shot 51: a flap hanging at the top left of the den's arch; Studio: the face's columns
    at the terrace's north-east end ran down past the brow to y 11.7, into the opening): a face point in front of the
    den's mouth (MOUTH_ZONE[0] past either jamb, from MOUTH_ZONE[1] behind the front wall out) and under
    MOUTH_ZONE[2] over its crown ends its column there; the mouth's brow and backing rock stand over that height."""
    side, behind, over = MOUTH_ZONE
    m, d = S.MOUTH, S.DEN
    return m["x0"] - side < x < m["x1"] + side and z > d["z1"] - behind and y < m["top"] + over


def cap_and_face():
    """The cap (a fan from the middle to the outline, rings every ~2 studs, the last ring rolling over) and the face from
    the rolled edge down at 20 degrees to the island's ground."""
    ol = outline()
    rings = [i / 6 for i in range(1, 7)]
    cap_v, cap_f = [T(0, 0, Y + .05)], []
    for k, f in enumerate(rings):
        for (s_, t_) in ol:
            y = Y + .05
            cap_v.append(T(s_ * f, t_ * f, y))
    n = len(ol)
    # round 6 (mesh gate: 160 needles): no fan from the middle; the first ring's hole is filled after building, with
    # rings of fewer points (below, after the rings)
    for r in range(len(rings) - 1):
        for i in range(n):
            a, b = 1 + r * n + i, 1 + r * n + (i + 1) % n
            c, d = a + n, b + n
            cap_f.append([a, c, d, b][::-1])
    # the lip: a ring 0.6 down, 0.4 further out
    base = len(cap_v)
    lip_ring, notched = [], []
    for k, (s_, t_) in enumerate(ol):
        ln = math.hypot(s_, t_) or 1
        # Fable E1 1: the rim's drop varies 0.4 to 1.2 so no run reads as a ruled line
        drop = .8 + .4 * math.sin(k * .55 + 1.1) * math.cos(k * .21)
        x, z = S.tier_xz(s_, t_)
        fs = flight_side(x, z)
        # round 9: in the stairs' notch the rim rolls straight down 0.3 (pushed out it would hang over the steps)
        notched.append(fs is not None and abs(fs[0] + fs[1]["w"] / 2 + NOTCH) < 1e-3)
        if notched[-1]:
            lip_ring.append(T(s_, t_, Y - .3))
        else:
            lip_ring.append(T(s_ + s_ / ln * .4, t_ + t_ / ln * .4, Y - drop))
    cap_v += lip_ring
    last = 1 + (len(rings) - 1) * n
    lip_rock = []
    for i in range(n):
        a, b = last + i, last + (i + 1) % n
        quad = [a, base + i, base + (i + 1) % n, b][::-1]
        # round 7 (Fable ROUND7 6b, studio-r6e 06: a green wall 3 high left of the top flight): beside the return leg's
        # flight, where the lip stands over its steps, the lip is the cliff's rock, not grass
        if by_flight([cap_v[k] for k in quad]):
            lip_rock.append((i, [cap_v[k] for k in quad]))
        else:
            cap_f.append(quad)
    # round 6 (mesh gate: the old fan was 160 needles): the middle steps down through rings of half as many points
    # (n, n/2, n/4, n/8) to a fan of n/8 spokes, so no triangle is a needle
    assert n % 8 == 0, n                     # code review: the halving rings need n divisible by 8
    prev, stride = list(range(1, 1 + n)), 1
    for f in (1 / 8, 1 / 11, 1 / 16):
        stride *= 2
        idx = []
        for i in range(0, n, stride):
            s_, t_ = ol[i]
            cap_v.append(T(s_ * f, t_ * f, Y + .05))
            idx.append(len(cap_v) - 1)
        m = len(idx)
        for j in range(m):
            o0, o1, o2 = prev[(2 * j) % len(prev)], prev[(2 * j + 1) % len(prev)], prev[(2 * j + 2) % len(prev)]
            i0, i1 = idx[j], idx[(j + 1) % m]
            cap_f += [[o1, o0, i0], [o2, o1, i1], [o1, i0, i1][::-1]]
        prev = idx
    for j in range(len(prev)):
        cap_f.append([prev[(j + 1) % len(prev)], prev[j], 0])
    cap = up_facing(L.mesh_object("W7_F_Terrace__grass", cap_v, cap_f))
    # the face: from the lip ring down, leaning back 15 to 26 degrees, in 1.5-stud rows, to 0.6 under the ground
    face = Pth.Mesh("W7_F_TerraceFace__cliff_rock")
    cols, beside, mouth = [], [], []  # beside: per column point, set by the flight (never cut as over the tread)
    wall = wall_tree()
    for k, ((x, y, z), (s_, t_)) in enumerate(zip(lip_ring, ol)):
        lean = 0.0 if notched[k] else math.tan(lean_at(k, n))   # round 9: the notch's cheek stands upright
        ln = math.hypot(s_, t_) or 1
        ox, oz = S.tier_xz(s_ / ln, t_ / ln)
        cx, cz = S.tier_xz(0, 0)
        dx, dz = ox - cx, oz - cz
        col, by = [(x, y, z)], [notched[k] or flight_clamp(x, z)[2] is not None]
        yy = y
        mouth.append(False)
        while True:
            yy -= 1.5
            drop = y - yy
            px, pz = x + dx * drop * lean, z + dz * drop * lean
            if over_mouth(px, yy, pz):
                mouth[-1] = True
                break
            g = S.ground(px, pz)
            jitter = 0.0 if notched[k] else .45 * math.sin(px * .7 + pz * .5) * math.cos(yy * .9)
            px, pz = px + dx * jitter, pz + dz * jitter
            # round 9: by the return flight the face keeps NOTCH off its inner edge and runs down past the steps' feet
            px, pz, tread = flight_clamp(px, pz)
            p = (px, yy, pz)
            if tread is None:
                over, near_s = near_path(px, pz)
                if over and yy > near_s["h"] - .2:
                    # round 9 (shot 57: holes in the face where its quads over the tread were dropped): the column ends
                    # before it reaches over the tread, reaching back into the cut wall when it is near
                    end = tuck_into(wall, p, (dx, dz), behind=TUCK[3])
                    if end is not None and end != p:
                        col.append(end)
                        by.append(False)
                    break
            tucked = tuck_into(wall, p, (dx, dz)) if tread is None and drop > 1.0 else None
            if tucked is not None:
                col.append(tucked)
                by.append(False)
                break
            col.append(p)
            by.append(tread is not None)
            if tread is not None:
                if yy < tread - FLIGHT_FOOT:
                    break
            elif g is None or yy < g - .6 or yy < 12:
                # round 9: the column's foot reaches back into the cut wall when it stands near it (no loose edge)
                end = tuck_into(wall, (px, yy - .75, pz), (dx, dz), behind=TUCK[3])
                if end is not None and end != (px, yy - .75, pz):
                    col.append(end)
                    by.append(False)
                break
        cols.append(col)
        beside.append(by)
    # Round 8b (Spencer beta 34 follow-up: blocky, stretched rock patches high over the lower path, the face's top rows):
    # the face was mapped per face on its dominant axis, so neighbouring quads leaning across 45 degrees in plan swapped
    # projections (a seam and up to 1.4x stretch each), and the lip's rock strip, near level, took a top-down map. Now the
    # whole face is one continuous map in studs: across, the distance along the lip ring; down, the distance down each
    # column from its lip point (the lip's rock strip continues it upward to the cap's edge).
    along = [0.0]
    for a, b in zip(lip_ring, lip_ring[1:] + lip_ring[:1]):
        along.append(along[-1] + math.hypot(b[0] - a[0], b[2] - a[2]))
    down = []
    for col in cols:
        acc = [0.0]
        for a, b in zip(col, col[1:]):
            acc.append(acc[-1] + math.dist(a, b))
        down.append(acc)
    for i, pts in lip_rock:
        j = i + 1                                           # along[n] closes the ring without a jump
        cap_i, cap_j = cap_v[last + i], cap_v[last + (i + 1) % n]
        up_i, up_j = math.dist(cap_i, lip_ring[i]), math.dist(cap_j, lip_ring[(i + 1) % n])
        # pts = [cap j, lip j, lip i, cap i] (the cap quad's order, reversed)
        face.quad(*pts, uv=[(along[j], up_j), (along[j], 0.0), (along[i], 0.0), (along[i], up_i)])
    def over_tread(pts, flags):
        # never over the cliff path's tread (a point the flight set beside the stairs is not over it)
        return any(not f and near_path(p[0], p[2])[0] and p[1] > near_path(p[0], p[2])[1]["h"] - .2
                   for p, f in zip(pts, flags))

    for i in range(n):
        i1 = (i + 1) % n
        c0, c1, b0, b1 = cols[i], cols[i1], beside[i], beside[i1]
        d0, d1 = down[i], down[i1]
        m = min(len(c0), len(c1))
        for r in range(m - 1):
            pts = [c0[r], c1[r], c1[r + 1], c0[r + 1]]
            if over_tread(pts, [b0[r], b1[r], b1[r + 1], b0[r + 1]]):
                continue
            face.quad(*pts, uv=[(along[i], -d0[r]), (along[i + 1], -d1[r]), (along[i + 1], -d1[r + 1]),
                                (along[i], -d0[r + 1])])
        # round 9 (shots 56, 57: the face's foot was a staircase of loose ends, one column longer than the next): the
        # longer column's tail closes onto the shorter one's end in triangles (not over the den's mouth, where the
        # columns end short on purpose)
        if mouth[i] or mouth[i1]:
            continue
        for r in range(m - 1, len(c0) - 1):
            pts, fl = [c0[r], c1[m - 1], c0[r + 1]], [b0[r], b1[m - 1], b0[r + 1]]
            if not over_tread(pts, fl):
                face.poly(pts, [(along[i], -d0[r]), (along[i + 1], -d1[m - 1]), (along[i], -d0[r + 1])])
        for r in range(m - 1, len(c1) - 1):
            pts, fl = [c0[m - 1], c1[r], c1[r + 1]], [b0[m - 1], b1[r], b1[r + 1]]
            if not over_tread(pts, fl):
                face.poly(pts, [(along[i], -d0[m - 1]), (along[i + 1], -d1[r]), (along[i + 1], -d1[r + 1])])
    return cap, face, ol, cols


def up_facing(obj):
    """Round 6: one winding over the cap (recalculated), facing up (Blender z) on average."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    if sum(f.normal.z * f.calc_area() for f in bm.faces) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def tongues(cols, ol):
    """Three grass tongues down the face, 3 to 5 long. Round 5 (Fable world R1 13: only one short one showed): all three
    on the garden side, where the lawn sees them, between the lookout and the path's arrival; each narrows to its tip."""
    # Fable round 5: one strip per tongue down the face (no loose squares), at least 4 segments, its sides ragged and
    # closing to a point; laid on the face by interpolating its columns and rows, 0.08 proud.
    m = Pth.Mesh("W7_F_TerraceTongues__grass")
    n = len(ol)

    def at(ci, r):
        i0 = math.floor(ci)
        fi = ci - i0
        out = []
        for c in (cols[i0 % n], cols[(i0 + 1) % n]):
            r0 = min(int(r), len(c) - 2)
            fr = min(1.0, r - r0)
            p, q = c[r0], c[r0 + 1]
            out.append([p[j] + (q[j] - p[j]) * fr for j in range(3)])
        a, b = out
        return tuple(a[j] + (b[j] - a[j]) * fi for j in range(3))

    for th, length, width in ((math.radians(62), 4.0, 3.2), (math.radians(97), 5.0, 4.2), (math.radians(128), 3.5, 3.0)):
        ci = th / (2 * math.pi) * n                           # the tongue's centre column (fractional)
        k0 = int(ci) % n
        step = math.hypot(ol[(k0 + 1) % n][0] - ol[k0][0], ol[(k0 + 1) % n][1] - ol[k0][1]) or 1.4
        half = width / 2 / step                               # its half width in columns
        rows_avail = min(len(cols[math.floor(ci - half - 1) % n]), len(cols[math.ceil(ci + half + 1) % n])) - 1
        r_end = min(length / 1.6, rows_avail - .01)
        if r_end < 1.5:
            continue
        segs = max(4, math.ceil(r_end * 2))
        strip = []
        for j in range(segs + 1):
            u = j / segs
            hw = half * (1 - u) ** .7 * (1 + .18 * math.sin(j * 2.3 + th * 5))
            left, right = at(ci - hw, u * r_end), at(ci + hw, u * r_end)
            strip.append(((left[0], left[1] + .08, left[2]), (right[0], right[1] + .08, right[2])))
        if any(near_path(p[0], p[2])[0] for pair in strip for p in pair):
            continue
        for j in range(segs):
            (a, b), (d, c) = strip[j], strip[j + 1]
            m.quad(a, b, c, d)
    return m


def earth_patch():
    """The worn earth (6 x 5) where the path arrives through the notch (s 30, t 22 at the floor), +0.02 over the cap."""
    m = Pth.Mesh("W7_F_TerraceEarth__dirt_path")
    n = 14
    cs, ct = 29.0, 18.5
    ring = []
    for k in range(n):
        th = 2 * math.pi * k / n
        r = 1 + .18 * math.sin(3 * th + 1)
        ring.append(T(cs + 3.0 * r * math.cos(th), ct + 2.5 * r * math.sin(th), Y + .07))
    c = T(cs, ct, Y + .07)
    for k in range(n):
        m.quad(c, ring[k], ring[(k + 1) % n], c)
    return m


def outcrops_and_slab():
    """Three low outcrops (the old clumps, now boulders) and the lookout slab, one rock mesh."""
    # Fable E1 6: three distinct outcrops, sunk 15 to 25%: a cluster of three (5 high, 9 wide), a single (3 high), a low
    # shelf (2 high) at the north-east end
    blobs = []
    ridge = math.atan2(-S.TIER_D[1], S.TIER_D[0])
    for (s_, t_), r, sink, tilt in (((-13.0, -19.0), (3.2, 3.1, 2.8), .2, .08), ((-9.6, -19.8), (2.2, 2.4, 2.2), .25, -.1),
                                    ((-15.8, -18.2), (1.9, 1.8, 1.8), .2, .15), ((7.0, -19.6), (2.4, 2.0, 2.2), .15, .05),
                                    ((-35.0, -7.0), (2.6, 1.3, 4.6), .2, 0.0)):
        x, _, z = T(s_, t_)
        r = tuple(q * 1.4 for q in r)                   # round 6 (Fable 2): the outcrops 7 high
        blobs.append(((x, Y + r[1] * (1 - 2 * sink), z), r, ridge + .3 * tilt, tilt))
    rocks = Pth.rock_mass("W7_F_TerraceRocks__cliff_rock", blobs, target=1400, floor_y=Y - .3)
    # the lookout slab: a flat stone 7 x 5, 0.35 thick, its top at 29.3
    slab = Pth.Mesh("W7_F_TerraceSlab__boulder_rock")
    yaw = math.atan2(-S.TIER_D[1], S.TIER_D[0])
    cx, _, cz = T(*LOOKOUT)
    pts = []
    for k in range(10):
        th = 2 * math.pi * k / 10
        r = 1 + .08 * math.sin(2 * th + .7)
        u, v = 5.0 * r * math.cos(th), 3.5 * r * math.sin(th)        # round 6 (Fable 2): the slab 10 x 7
        pts.append((cx + S.TIER_D[0] * u + S.TIER_N[0] * v, cz + S.TIER_D[1] * u + S.TIER_N[1] * v))
    for k in range(10):
        a, b = pts[k], pts[(k + 1) % 10]
        slab.quad((cx, Y + .32, cz), (a[0], Y + .3, a[1]), (b[0], Y + .3, b[1]), (cx, Y + .32, cz))
        slab.quad((a[0], Y + .3, a[1]), (a[0], Y - .3, a[1]), (b[0], Y - .3, b[1]), (b[0], Y + .3, b[1]))
        slab.quad((cx, Y - .3, cz), (b[0], Y - .3, b[1]), (a[0], Y - .3, a[1]), (cx, Y - .3, cz))   # round 6: closed
    return rocks, slab


def log_bench():
    """A log 8 long (round 6, Fable 2), 1.1 across, its top flattened, facing the garden (local: along x, base at y 0)."""
    v, f = [], []
    n = 10
    for end in (-4.0, 4.0):
        for k in range(n):
            a = 2 * math.pi * k / n
            y = .55 + .55 * math.sin(a)
            y = min(y, .95)                              # the flattened seat
            v.append((end, y, .55 * math.cos(a)))
    for k in range(n):
        f.append([k, (k + 1) % n, n + (k + 1) % n, n + k])
    f.append(list(range(n))[::-1])
    f.append(list(range(n, 2 * n)))
    return L.mesh_object("W7_F_TerraceLog__bark", v, f, smooth=True, local=True)


def trunk():
    """The tree's trunk: 9 tall, 1.1 across at the base tapering to 0.6, a slight lean (local, base at y 0)."""
    v, f = [], []
    n = 8
    # Fable E1 8: a flared foot (1.6 across) tapering to 0.7, leaning about 4 degrees
    for y, r, dx in ((-.5, 1.0, 0), (1.6, .65, .1), (6.6, .52, .46), (12, .44, .82)):   # round 6: the tree 18 tall
        for k in range(n):
            a = 2 * math.pi * k / n
            v.append((dx + r * math.cos(a), y, r * math.sin(a)))
    for ring in range(3):
        for k in range(n):
            a, b = ring * n + k, ring * n + (k + 1) % n
            f.append([a, b, b + n, a + n])
    return L.mesh_object("W7_F_TerraceTrunk__bark", v, f, smooth=True, local=True)


def lip_layout(ol):
    """Kit lip stones along the garden side (t over 20), gaps 2 to 6, off the arrival (s 24 to 36) and the lookout's
    6-stud gap (s -36 to -30)."""
    # Fable E1 5: groups of two or three (kit 1 to 4: 0.8 to 1.5 showing), gaps 2 to 6 between groups, yaw varied,
    # sunk 0.2 more
    rnd = np.random.default_rng(121)
    out, s_ = [], -36.0
    while s_ < 37:
        for _ in range(int(rnd.integers(2, 4))):
            kit = int(rnd.integers(1, 5))
            length = Pth.LIP_KIT[kit - 1][0]
            if not (24 <= s_ <= 39 or -36.5 <= s_ <= -29.5) and s_ + length <= HALF[0] - 1:   # round 6: gap to 37
                # round 5: on the wandering edge (0.6 inside it), not on a ruled line at t 23
                t_ = max(HALF[1] + .3, edge_t(ol, s_ + length / 2) - .6) + float(rnd.uniform(-.2, .2))
                x, _, z = T(s_ + length / 2, t_)
                out.append({"kit": kit, "at": [round(x, 3), Y - .25, round(z, 3)],
                            "yaw": round(math.atan2(-S.TIER_D[1], S.TIER_D[0]) + math.radians(rnd.uniform(-25, 25)), 4)})
            s_ += length + float(rnd.uniform(.2, .6))
        s_ += float(rnd.uniform(2, 6))
    return out


def plants():
    """Tufts (LeafTuft, kind 3) along the lip and the outcrops (30 at most, none in the park's circle) and two blossom
    shrubs (FrondSpray, kind 2) against the outcrops; WorldDressing rows {x, y, z, kind, yaw, scale}."""
    rnd = np.random.default_rng(131)
    rows = []
    for k in range(22):
        s_ = -36 + 72 * k / 21 + float(rnd.uniform(-1, 1))
        t_ = HALF[1] + .3 if k % 2 == 0 else -HALF[1] - .3
        if math.hypot(s_ - PARK[0][0], t_ - PARK[0][1]) < PARK[1] + 1 or 24 <= s_ <= 36 and t_ > 0:
            continue
        x, _, z = T(s_, t_)
        rows.append([round(x, 3), Y, round(z, 3), 3, round(float(rnd.uniform(0, 6.28)), 2), round(float(rnd.uniform(.8, 1.1)), 2)])
    for s_, t_ in ((-9.0, -16.5), (8.5, -17.0)):
        x, _, z = T(s_, t_)
        rows.append([round(x, 3), Y, round(z, 3), 2, round(float(rnd.uniform(0, 6.28)), 2), 1.4])
    return rows[:30]


def outcrop_boxes():
    """Collision for the outcrops (players): one box each, inside the drawn rock; and the tree's trunk (code review E1:
    the greybox pole it replaces collided)."""
    yaw = math.atan2(-S.TIER_D[1], S.TIER_D[0])
    tx, _, tz = T(*TREE)
    out = [{"kind": "trunk", "c": [round(tx, 3), Y + 4.5, round(tz, 3)], "s": [1.2, 9.0, 1.2], "yaw": 0.0}]
    for (s_, t_), size in (((-12.6, -19.0), (8.0, 4.4, 4.0)), ((7.0, -19.6), (3.6, 2.6, 3.2)), ((-35.0, -7.0), (4.0, 1.6, 7.0))):
        x, _, z = T(s_, t_)
        out.append({"kind": "outcrop", "c": [round(x, 3), Y + size[1] / 2, round(z, 3)], "s": list(size), "yaw": round(yaw, 4)})
    return out
