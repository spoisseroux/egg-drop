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


def T(s, t, y=Y):
    x, z = S.tier_xz(s, t)
    return (x, y, z)


def edge_offset(theta):
    """How far the drawn edge stands outside the wall line, by angle round the terrace: 0.5 to 2.5, wandering (the
    noise's period keeps straight runs under 12 studs)."""
    p = np.array([[math.cos(theta) * 6, 0, math.sin(theta) * 6]])
    return .5 + 2.0 * float(L.fbm(p, 3, seed=111)[0])


def outline(n=96):
    """The bean: points (s, t) round the rectangle (rounded corners r 4), each pushed out by edge_offset."""
    out = []
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
        off = edge_offset(th)
        ln = math.hypot(c, s_ * a / b) or 1
        out.append((ps + c / ln * off, pt + s_ * a / b / ln * off))
    return out


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
    for (s_, t_) in ol:
        ln = math.hypot(s_, t_) or 1
        lip_ring.append(T(s_ + s_ / ln * .4, t_ + t_ / ln * .4, Y - .55))
    cap_v += lip_ring
    last = 1 + (len(rings) - 1) * n
    for i in range(n):
        a, b = last + i, last + (i + 1) % n
        cap_f.append([a, base + i, base + (i + 1) % n, b][::-1])
    cap = L.mesh_object("W7_F_Terrace__grass", cap_v, cap_f)
    # the face: from the lip ring down, leaning back 20 degrees, in 1.5-stud rows, to 0.6 under the ground
    face = Pth.Mesh("W7_F_TerraceFace__cliff_rock")
    lean = math.tan(math.radians(20))
    cols = []
    for (x, y, z), (s_, t_) in zip(lip_ring, ol):
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
            jitter = .25 * math.sin(px * .7 + pz * .5) * math.cos(yy * .9)
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
    """Three grass tongues down the face at chosen angles (garden side, outer side, south-west end), 3 to 5 long."""
    m = Pth.Mesh("W7_F_TerraceTongues__grass")
    n = len(ol)
    for th, length, width in ((math.radians(100), 4.5, 3), (math.radians(250), 3.5, 3), (math.radians(345), 5.0, 2)):
        i = int(round(th / (2 * math.pi) * n)) % n
        for k in range(width):
            c0, c1 = cols[(i + k) % n], cols[(i + k + 1) % n]
            rows = min(len(c0), len(c1), int(length / 1.5) + 2)
            for r in range(rows - 1):
                taper = 1 - r / rows
                if taper <= 0:
                    break
                lift = .06
                pts = [c0[r], c1[r], c1[r + 1], c0[r + 1]]
                if any(near_path(p[0], p[2])[0] for p in pts):
                    continue
                m.quad(*[(p[0], p[1] + lift, p[2]) for p in pts])
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
    blobs = []
    for (s_, t_), r in (((-12.0, -19.0), (4.0, 2.4, 2.6)), ((6.0, -19.5), (3.4, 2.0, 2.4)), ((-35.0, -9.0), (2.8, 2.2, 4.0))):
        x, _, z = T(s_, t_)
        blobs.append(((x, Y + r[1] * .6, z), r, math.atan2(-S.TIER_D[1], S.TIER_D[0]), .05))
        x2, _, z2 = T(s_ + 2.5, t_ + 1.0)
        blobs.append(((x2, Y + r[1] * .3, z2), (r[0] * .6, r[1] * .6, r[2] * .7), .4, -.05))
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
    for y, r, dx in ((-.5, .6, 0), (3, .45, .1), (6, .36, .25), (9, .3, .4)):
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
    rnd = np.random.default_rng(121)
    out, s_ = [], -36.0
    while s_ < 37:
        kit = int(rnd.integers(1, 6))
        length = Pth.LIP_KIT[kit - 1][0]
        if not (24 <= s_ <= 36 or -36.5 <= s_ <= -29.5):
            x, _, z = T(s_, HALF[1] + 1.0)
            out.append({"kit": kit, "at": [round(x, 3), Y - .05, round(z, 3)],
                        "yaw": round(math.atan2(-S.TIER_D[1], S.TIER_D[0]) + math.radians(rnd.uniform(-15, 15)), 4)})
        s_ += length + float(rnd.uniform(2, 6))
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
    """Collision for the outcrops (players): one box each, inside the drawn rock, 4 high."""
    yaw = math.atan2(-S.TIER_D[1], S.TIER_D[0])
    out = []
    for (s_, t_), size in (((-12.0, -19.0), (6.4, 3.6, 3.6)), ((6.0, -19.5), (5.4, 3.0, 3.2)), ((-35.0, -9.0), (4.2, 3.2, 6.0))):
        x, _, z = T(s_, t_)
        out.append({"kind": "outcrop", "c": [round(x, 3), Y + size[1] / 2, round(z, 3)], "s": list(size), "yaw": round(yaw, 4)})
    return out
