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
        out.append((ps + ux * off, pt + uy * off))
    return out


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
    for i in range(n):
        cap_f.append([0, 1 + i, 1 + (i + 1) % n][::-1])
    for r in range(len(rings) - 1):
        for i in range(n):
            a, b = 1 + r * n + i, 1 + r * n + (i + 1) % n
            c, d = a + n, b + n
            cap_f.append([a, c, d, b][::-1])
    # the lip: a ring 0.6 down, 0.4 further out
    base = len(cap_v)
    lip_ring = []
    for k, (s_, t_) in enumerate(ol):
        ln = math.hypot(s_, t_) or 1
        # Fable E1 1: the rim's drop varies 0.4 to 1.2 so no run reads as a ruled line
        drop = .8 + .4 * math.sin(k * .55 + 1.1) * math.cos(k * .21)
        lip_ring.append(T(s_ + s_ / ln * .4, t_ + t_ / ln * .4, Y - drop))
    cap_v += lip_ring
    last = 1 + (len(rings) - 1) * n
    for i in range(n):
        a, b = last + i, last + (i + 1) % n
        cap_f.append([a, base + i, base + (i + 1) % n, b][::-1])
    cap = L.mesh_object("W7_F_Terrace__grass", cap_v, cap_f)
    # the face: from the lip ring down, leaning back 15 to 26 degrees, in 1.5-stud rows, to 0.6 under the ground
    face = Pth.Mesh("W7_F_TerraceFace__cliff_rock")
    cols = []
    for k, ((x, y, z), (s_, t_)) in enumerate(zip(lip_ring, ol)):
        lean = math.tan(lean_at(k, n))
        ln = math.hypot(s_, t_) or 1
        ox, oz = S.tier_xz(s_ / ln, t_ / ln)
        cx, cz = S.tier_xz(0, 0)
        dx, dz = ox - cx, oz - cz
        col = [(x, y, z)]
        yy = y
        while True:
            yy -= 1.5
            drop = y - yy
            px, pz = x + dx * drop * lean, z + dz * drop * lean
            g = S.ground(px, pz)
            jitter = .45 * math.sin(px * .7 + pz * .5) * math.cos(yy * .9)
            col.append((px + dx * jitter, yy, pz + dz * jitter))
            if g is None or yy < g - .6 or yy < 12:
                break
        cols.append(col)
    for i in range(n):
        c0, c1 = cols[i], cols[(i + 1) % n]
        m = min(len(c0), len(c1))
        for r in range(m - 1):
            pts = [c0[r], c1[r], c1[r + 1], c0[r + 1]]
            if any(near_path(p[0], p[2])[0] and p[1] > near_path(p[0], p[2])[1]["h"] - .2 for p in pts):
                continue                                    # never over the cliff path's tread
            face.quad(*pts)
    return cap, face, ol, cols


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
        u, v = 3.5 * r * math.cos(th), 2.5 * r * math.sin(th)
        pts.append((cx + S.TIER_D[0] * u + S.TIER_N[0] * v, cz + S.TIER_D[1] * u + S.TIER_N[1] * v))
    for k in range(10):
        a, b = pts[k], pts[(k + 1) % 10]
        slab.quad((cx, Y + .32, cz), (a[0], Y + .3, a[1]), (b[0], Y + .3, b[1]), (cx, Y + .32, cz))
        slab.quad((a[0], Y + .3, a[1]), (a[0], Y - .3, a[1]), (b[0], Y - .3, b[1]), (b[0], Y + .3, b[1]))
    return rocks, slab


def log_bench():
    """A log 6 long, 0.9 across, its top flattened, facing the garden (local: along x, base at y 0)."""
    v, f = [], []
    n = 10
    for end in (-3.0, 3.0):
        for k in range(n):
            a = 2 * math.pi * k / n
            y = .45 + .45 * math.sin(a)
            y = min(y, .78)                              # the flattened seat
            v.append((end, y, .45 * math.cos(a)))
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
    for y, r, dx in ((-.5, .8, 0), (1.2, .52, .08), (5, .42, .35), (9, .35, .62)):
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
            if not (24 <= s_ <= 36 or -36.5 <= s_ <= -29.5) and s_ + length <= HALF[0] - 1:
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
