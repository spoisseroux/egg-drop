"""Slice D, the cliff path (WORLD-FINISH-LOOK.md section 4): an old shelf worn into the rock by feet. Imported by
scripts/build_world_finish_art.py inside background Blender. Everything follows cliff_den_sculpt.path_samples() (the
path the collision boxes, the pets and the anchors already use): the walking surface and its collision are unchanged.

  W7_F_Path__dirt_path        the tread (dirt) over the smooth ramp, +0.03; not on the two flights
  W7_F_PathGrass__grass       a ragged grass strip over the outer third, +0.08
  W7_F_PathWall__cliff_rock   the cut: a lower face 3 to 5 high leaning back 20 degrees, a bench, the upper rise to the old
                              cut's top line (so it meets the island exactly where the sculpt's wall did); its foot bows
                              0 to 2.5 back from the tread, twice, along the walled run; the shoulders (dry stone banks)
                              where the slope is convex
  W7_F_PathFoot__dirt_path    the wall's lowest stud and the pebbly talus between the tread and a bowed-back wall
  W7_F_PathSteps__boulder_rock  the two flights: 4 steps at the foot (the foot is 16 degrees: rise 0.5), 8 on the return
                              leg (rise 0.75, tread 1.4), level tops within half a rise of the ramp
  W7_F_PathRocks__cliff_rock  the fin at the turn (an irregular boulder round its collision box) and the notch's two
                              leaning boulders
  kit: W7_F_Lip1..5__boulder_rock (five lip stones), W7_F_Stake__wood (a timber stake)
"""
from __future__ import annotations

import math
import re

import bmesh
import bpy
import numpy as np

import cliff_den_sculpt as S
import world_finish_lib as L

LEAN = math.tan(math.radians(20))
GLADE = (-58.0, -48.0)              # the Paw Glade (the Hollow's old spot) under shelf 2
FLIGHT1 = (0.0, 7.2)                # the foot's flight, by plan distance d
FLIGHT1_STEPS, FLIGHT2_STEPS = 4, 8


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def samples(every=2):
    S_ = S.path_samples()
    out = S_[::every]
    if out[-1] is not S_[-1]:
        out.append(S_[-1])
    return out


def P(s, a, y):
    """A point `a` studs toward the lawn from sample s's centre line, at height y."""
    return (s["x"] + s["out"][0] * a, y, s["z"] + s["out"][1] * a)


def Q(s, a, y):
    """Along the consistent side (no flip at the hairpin): ribbons."""
    return (s["x"] + s["side"][0] * a, y, s["z"] + s["side"][1] * a)


def on_flight(s):
    return FLIGHT1[0] <= s["d"] <= FLIGHT1[1] or s["step"]


class Mesh:
    def __init__(self, name):
        self.name, self.v, self.f, self.uv = name, [], [], []

    def quad(self, a, b, c, d, uv=None):
        k = len(self.v)
        self.v += [a, b, c, d]
        self.f.append([k, k + 1, k + 2, k + 3])
        self.uv.append(uv)

    def poly(self, pts, uv=None):
        k = len(self.v)
        self.v += list(pts)
        self.f.append(list(range(k, k + len(pts))))
        self.uv.append(uv)

    def build(self, k_uv, up=None):
        # when every quad carries its own UVs (in studs), they are kept, times k_uv (uv units per stud)
        uvs = None
        if k_uv and self.uv and all(self.uv):
            uvs = [[(a * k_uv, b * k_uv) for a, b in u] for u in self.uv]
        obj = L.mesh_object(self.name, self.v, self.f, uvs=uvs)
        obj["own_uvs"] = uvs is not None
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        # round 6: a closed solid (no open edge) gets one outward winding; open sheets keep their built winding
        if bm.edges and not any(e.is_boundary for e in bm.edges):
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        return obj


GRASS_EDGE = -.05                   # round 7 (Fable ROUND7 6a): the grass strip's outer edge, from the tread's edge
GRASS_SKIRT = .4                    # and its turf skirt straight down over the rock skirt's top
DIRT_SKIRT = (.6, 1.15)             # round 7 (Fable ROUND7 2): the tread's inner edge grows out and down over the deeper cut


def has_grass(s0, s1):
    return not (s0["flip"] != s1["flip"] or on_flight(s0) or on_flight(s1))     # round 6 (Fable R6-CDE 7): none by the flights


def tread():
    """Dirt over the ramp (+0.03) with a skirt down at its inner edge, and the grass strip (outer third, ragged, +0.08)
    with a turf skirt at its outer edge, off the flights."""
    dirt, grass = Mesh("W7_F_Path__dirt_path"), Mesh("W7_F_PathGrass__grass")
    S_ = samples(2)
    rnd = np.random.default_rng(41)
    # Fable D1 9: a 2.0 mean (1.2 to 2.6)
    gw = [min(2.6, max(1.2, 2.0 + .45 * math.sin(s["d"] * .9) + .25 * rnd.uniform(-1, 1))) for s in S_]
    out_, down = DIRT_SKIRT
    for i, (s0, s1) in enumerate(zip(S_, S_[1:])):
        if on_flight(s0) and on_flight(s1):
            continue
        w0, w1 = s0["w"] / 2, s1["w"] / 2
        dirt.quad(Q(s0, -w0, s0["h"] + .03), Q(s1, -w1, s1["h"] + .03), Q(s1, w1, s1["h"] + .03), Q(s0, w0, s0["h"] + .03))
        # round 7 (Fable ROUND7 2): the island is cut 1.0 under the tread out to 0.5 past each edge (recut_test); the
        # inner edge's skirt (out 0.6, down 1.15) closes that from the side. The outer edge has the rock skirt.
        if s0["flip"] == s1["flip"]:
            q = [P(s0, -w0 - out_, s0["h"] - down), P(s1, -w1 - out_, s1["h"] - down), P(s1, -w1, s1["h"] + .03),
                 P(s0, -w0, s0["h"] + .03)]
            dirt.quad(*(q if s0["flip"] > 0 else q[::-1]))      # wound as the tread (Q runs the other way when flipped)
        if not has_grass(s0, s1):
            continue
        g0, g1 = gw[i], gw[i + 1]
        e = GRASS_EDGE
        grass.quad(P(s0, w0 - g0, s0["h"] + .08), P(s1, w1 - g1, s1["h"] + .08), P(s1, w1 + e, s1["h"] + .07),
                   P(s0, w0 + e, s0["h"] + .07))
        # round 7 (Fable ROUND7 6a: the strip overhung the edge with a dark underside line): it stops 0.05 inside the
        # edge and turns down 0.4, a turf lip over the rock skirt, a touch outward so the two never fight
        grass.quad(P(s0, w0 + e, s0["h"] + .07), P(s1, w1 + e, s1["h"] + .07), P(s1, w1 + e + .08, s1["h"] - GRASS_SKIRT),
                   P(s0, w0 + e + .08, s0["h"] - GRASS_SKIRT))
    foot_apron(dirt)
    return dirt, grass


FOOT_APRON = (3.0, 3)               # round 8: how far the tread runs back from the foot's first step, in how many rows


def foot_apron(dirt):
    """Round 8 (Spencer beta 34, shot 52; Studio and Blender: the island's underside showed 40 down in front of the
    lowest step): the sculpt's ramp (CD_CliffPath__dirt_path, hidden by this slice) began before the foot's first step,
    where the island was carved away and no tread is drawn (the flights have none). The tread now runs back from the
    foot FOOT_APRON[0] studs at its full width, just over the lawn round it."""
    length, rows = FOOT_APRON
    s0 = S.path_samples()[0]
    w, h0 = s0["w"] / 2 + .4, s0["h"] + .03

    def back(k):
        d = length * k / rows
        s = dict(s0, x=s0["x"] - s0["dir"][0] * d, z=s0["z"] - s0["dir"][1] * d)
        g = S.ground(s["x"], s["z"])
        # over the lawn it meets (the kept lawn's big faces reach 4.66; under it they cut it into a zigzag), and within
        # a stud of the foot inside the tread's band (check_world_finish_path: 0.1 over the ramp at most)
        h = h0 + .05 if d <= 1.0 + 1e-6 else max(h0 + .05, (g if g is not None else h0) + .06)
        return s, h

    for k in range(rows):
        (sa, ha), (sb, hb) = back(k + 1), back(k)
        dirt.quad(Q(sa, -w, ha), Q(sb, -w, hb), Q(sb, w, hb), Q(sa, w, ha))


BANK_SPAN = (5.0, 6.0, 4.0)         # round 7 (Fable ROUND7 1): the wall's least reach over a bank, how far behind
                                    # the edge a bank is looked for, and how far it must stand over the wall's top
_SPAN = {}


def behind_ground(s, dd):
    x, _, z = P(s, -s["w"] / 2 - dd, 0)
    return S.ground(x, z)


def wall_span(s):
    """(back, top) of the drawn cut at sample s: the sculpt's, except over a bank. Round 7 (Fable ROUND7 1, studio-r6e
    02/04: island ground stood on edge in a hole in the wall by the foot, d 3 to 4): where the ground dips at the inner
    edge the sculpt's wall stops at the dip (back 0.25, 0.6 high) though a bank rises 16 within 6 behind it. There the
    wall reaches back BANK_SPAN[0] and up to the ground at its back line, as its neighbours do."""
    k = id(s)
    if k in _SPAN:
        return _SPAN[k]
    back, top = s["back"], s["top"]
    reach, look, over = BANK_SPAN
    gs = [g for g in (behind_ground(s, i * .25) for i in range(int(look / .25) + 1)) if g is not None]
    if gs and back < reach and max(gs) > top + over:
        g_back = behind_ground(s, reach)
        back = reach
        top = max(top, (g_back if g_back is not None else max(gs)) + .4)
    _SPAN[k] = (back, top)
    return back, top


def wall_and_shoulders():
    """The cut (back wall), its dirt foot, and the dry-stone shoulders."""
    wall, foot = Mesh("W7_F_PathWall__cliff_rock"), Mesh("W7_F_PathFoot__dirt_path")
    S_ = samples(2)
    walled = [s for s in S_ if wall_span(s)[0] > .05]
    d0, d1 = (walled[0]["d"], walled[-1]["d"]) if walled else (0, 1)
    rnd = np.random.default_rng(43)
    R1 = {id(s): 3.6 + 1.2 * (.5 + .5 * math.sin(s["d"] * .37 + 1.3)) for s in S_}

    def profile(s):
        """(u behind the inner edge, v over the tread): always the same eight points (round 3: neighbours with different
        point counts were joined crosswise, the stretched strips and slivers in studio-r2/05), from the foot up the lower
        face (3.6 to 4.8, leaning 20 degrees), a bench, the upper rise in two halves to the old cut's top line, then the
        cap 1.2 and 3.4 on up the old slope. Where there is no room for a bench its points close up (zero-width faces)."""
        back, top = wall_span(s)
        hgt = top - s["h"]
        t = (s["d"] - d0) / max(1e-6, d1 - d0)
        bow = 1.25 - 1.25 * math.cos(4 * math.pi * min(1, max(0, t)))          # two bows, 0 to 2.5
        r1 = min(R1[id(s)], hgt)
        bow = min(bow, max(0.0, back - r1 * LEAN - .3))
        u1 = bow + r1 * LEAN
        ub = max(back, u1)
        bench = max(0.0, min(1.2, (ub - u1) * .45))
        rest = max(0.0, hgt - r1)
        pts = [(bow, -.25), (u1, r1), (u1 + bench, r1 + min(.15, rest)),
               (u1 + bench + (ub - u1 - bench) * .5, r1 + min(.15, rest) + (rest - min(.15, rest)) * .5),
               (ub, hgt)]
        v_prev = hgt
        for du in (1.2, 3.4):
            x, _, z = P(s, -s["w"] / 2 - ub - du, 0)
            g = S.ground(x, z)
            v = max(v_prev, (g - s["h"]) if g is not None else v_prev) + .2
            pts.append((ub + du, v))
            v_prev = v
        return pts, bow

    k_rock = None
    for s0, s1 in zip(S_, S_[1:]):
        if s0["flip"] != s1["flip"]:
            continue
        w0, w1 = s0["w"] / 2, s1["w"] / 2
        if wall_span(s0)[0] > .05 and wall_span(s1)[0] > .05:
            p0, b0 = profile(s0)
            p1, b1 = profile(s1)

            def arcs(pts, h):
                # round 6 (Fable 3.6, capture 03: stretched cells): v runs along the profile's own length from a world
                # height base, so the bench and the cap going back are not squeezed into a streak
                out, acc = [h + pts[0][1]], h + pts[0][1]
                for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
                    acc += math.hypot(u1 - u0, v1 - v0)
                    out.append(acc)
                return out
            a0, a1 = arcs(p0, s0["h"]), arcs(p1, s1["h"])
            for k in range(len(p0) - 1):
                (ua, va), (ub, vb) = p0[k], p0[k + 1]
                (uc, vc), (ud, vd) = p1[k], p1[k + 1]
                # UVs along the cut (plan distance d, profile length): one cell size over the whole face, no axis switching
                wall.quad(P(s0, -w0 - ua, s0["h"] + va), P(s1, -w1 - uc, s1["h"] + vc), P(s1, -w1 - ud, s1["h"] + vd),
                          P(s0, -w0 - ub, s0["h"] + vb),
                          uv=[(s0["d"], a0[k]), (s1["d"], a1[k]), (s1["d"], a1[k + 1]), (s0["d"], a0[k + 1])])
            # the foot: talus from the tread's inner edge to the bowed wall, then the wall's lowest stud in dirt
            foot.quad(P(s0, -w0 + .05, s0["h"] + .04), P(s1, -w1 + .05, s1["h"] + .04),
                      P(s1, -w1 - b1, s1["h"] + .3 + .25 * b1), P(s0, -w0 - b0, s0["h"] + .3 + .25 * b0))
            foot.quad(P(s0, -w0 - b0 + .02, s0["h"] - .2), P(s1, -w1 - b1 + .02, s1["h"] - .2),
                      P(s1, -w1 - b1 - 1.0 * LEAN + .02, s1["h"] + 1.0), P(s0, -w0 - b0 - 1.0 * LEAN + .02, s0["h"] + 1.0))
        # Fable D1 7: the outer edge always has thickness, a skirt 1.3 deep tucked under 15 degrees. Round 7 (Fable
        # ROUND7 6a): its top no longer stands out past the edge (the dark line under the grass): behind the grass's
        # turf skirt where there is grass, flush with the tread's edge where there is none
        e = -.1 if has_grass(s0, s1) else .02
        wall.quad(P(s0, w0 + e, s0["h"] + .02), P(s1, w1 + e, s1["h"] + .02), P(s1, w1 - .2, s1["h"] - 1.3),
                  P(s0, w0 - .2, s0["h"] - 1.3),
                  uv=[(s0["d"], s0["h"] + .02), (s1["d"], s1["h"] + .02), (s1["d"], s1["h"] - 1.3), (s0["d"], s0["h"] - 1.3)])
        # shoulders: where the ground beside an edge is under the path, a stepped dry-stone bank down to it
        for side in (1, -1):
            if side < 0 and (wall_span(s0)[0] > .05 or wall_span(s1)[0] > .05):
                continue
            a0, a1 = side * w0, side * w1
            g0 = S.ground(*P(s0, a0 + side * .5, 0)[::2]) or s0["h"] - 8
            g1 = S.ground(*P(s1, a1 + side * .5, 0)[::2]) or s1["h"] - 8
            drop0, drop1 = s0["h"] - g0, s1["h"] - g1
            if drop0 <= .3 and drop1 <= .3:
                continue
            d0_, d1_ = max(drop0, .3) + 1.2, max(drop1, .3) + 1.2      # round 3: one battered face, 1.2 under the ground
            courses = 1                                                  # (Fable R3: the courses read as gapped strips)
            prev = (P(s0, a0, s0["h"]), P(s1, a1, s1["h"]))
            pv = (s0["h"], s1["h"])
            for c in range(1, courses + 1):
                f = c / courses
                # a battered face, each course a little further out (round 3: no per-segment jitter, which shingled it)
                q0 = P(s0, a0 + side * d0_ * f * .45, s0["h"] - d0_ * f)
                q1 = P(s1, a1 + side * d1_ * f * .45, s1["h"] - d1_ * f)
                wall.quad(prev[0], prev[1], q1, q0,
                          uv=[(s0["d"], pv[0]), (s1["d"], pv[1]), (s1["d"], q1[1]), (s0["d"], q0[1])])
                prev, pv = (q0, q1), (q0[1], q1[1])
    return wall, foot


def steps():
    """The flights' stone steps: level slabs over the ramp, irregular fronts, worn in the middle."""
    m = Mesh("W7_F_PathSteps__boulder_rock")
    S_ = S.path_samples()
    rnd = np.random.default_rng(47)
    out = []
    for name, sel, n in (("foot", [s for s in S_ if FLIGHT1[0] <= s["d"] <= FLIGHT1[1]], FLIGHT1_STEPS),
                         ("return", [s for s in S_ if s["step"]], FLIGHT2_STEPS)):
        if not sel:
            continue
        da, db = sel[0]["d"], sel[-1]["d"]
        runs = [[s for s in sel if da + (db - da) * k / n - 1e-6 <= s["d"] <= da + (db - da) * (k + 1) / n + 1e-6]
                for k in range(n)]
        for k in range(n):
            lo, hi = da + (db - da) * k / n, da + (db - da) * (k + 1) / n
            run = runs[k]
            if len(run) < 2:
                continue
            # round 9b (Spencer beta 35 follow-up, the turn: the return flight's steps fanned apart, grass showing in
            # wedges between them): a step's block runs on to the next step's first row, under its riser, so
            # neighbouring steps meet edge to edge round the curve (the next block's front, pushed forward, covers it)
            body = run + ([runs[k + 1][0]] if k + 1 < n and runs[k + 1] and runs[k + 1][0] is not run[-1] else [])
            # 0.2 over the ramp's middle: the island's carved ground never shows through a tread (Fable D1 1), and
            # every point of the tread stays within 0.8 of the ramp
            top = run[len(run) // 2]["h"] + .2
            out.append({"flight": name, "top": round(top, 3), "front": round(lo, 2), "back": round(hi, 2),
                        "dev": round(max(abs(s["h"] - top) for s in run), 3)})
            jf = [rnd.uniform(-.3, .3) for _ in range(5)]          # Fable D1 4: fronts vary 0.3, a 0.15 nosing
            step_block(m, body, top, jf, nose=.15)
    return m, out


STEP_LAP = .1                       # round 9b: the least a step's front stands forward of its first row


def step_block(m, run, top, jf, nose=.15, depth=1.2, cols=5):
    """Round 6 (Fable DEN-ROUND6-LOOK 3.1; audit: 444 open and 26 flipped edges): one step is ONE closed stone block.
    A grid over the run (rows = samples, `cols` points across) whose inner columns sit 0.1 low (the worn middle as a
    continuous dip: the old separate strips left 0.1 slits), the front row pushed out by the irregular front plus the
    nosing, a flat bottom `depth` under the top, and the front, back, both cheeks and the bottom closing it. Faces are
    wound consistently (code review: the riser and back were reversed); Mesh.build welds the shared points and still
    recalculates the normals outward, and the mesh gate fails loudly if a step ever comes out flipped."""
    rows = len(run)
    wear = [0.0] + [.1] * (cols - 2) + [0.0]
    bx = (-run[0]["dir"][0], -run[0]["dir"][1])

    def edge(s, c, y, front):
        w = s["w"] / 2 - .1
        p = Q(s, -w + 2 * w * c / (cols - 1), y)
        if front:
            # round 9b: never pulled back behind its row (a step's front always laps the step below it)
            push = max(STEP_LAP, jf[min(c, len(jf) - 1)] + nose)
            p = (p[0] + bx[0] * push, p[1], p[2] + bx[1] * push)
        return p

    top_g = [[edge(s, c, top - wear[c], r == 0) for c in range(cols)] for r, s in enumerate(run)]
    bot_g = [[edge(s, c, top - depth, r == 0) for c in range(cols)] for r, s in enumerate(run)]
    # which way round is "up" depends on Q's side axis against the run: test the first top quad once
    a, b, c = top_g[0][0], top_g[1][0], top_g[0][1]
    u, v = (b[0] - a[0], b[1] - a[1], b[2] - a[2]), (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    ny = u[2] * v[0] - u[0] * v[2]
    flip = ny < 0

    def face(p0, p1, p2, p3):
        if flip:
            m.quad(p3, p2, p1, p0)
        else:
            m.quad(p0, p1, p2, p3)

    last, e = cols - 1, rows - 1
    for r in range(rows - 1):
        for col in range(cols - 1):
            face(top_g[r][col], top_g[r + 1][col], top_g[r + 1][col + 1], top_g[r][col + 1])     # top
            face(bot_g[r][col + 1], bot_g[r + 1][col + 1], bot_g[r + 1][col], bot_g[r][col])     # bottom
        face(top_g[r + 1][0], top_g[r][0], bot_g[r][0], bot_g[r + 1][0])                         # cheek, col 0
        face(top_g[r][last], top_g[r + 1][last], bot_g[r + 1][last], bot_g[r][last])             # cheek, far col
    for col in range(cols - 1):
        face(top_g[0][col], top_g[0][col + 1], bot_g[0][col + 1], bot_g[0][col])                 # front riser
        face(top_g[e][col + 1], top_g[e][col], bot_g[e][col], bot_g[e][col + 1])                 # back


# ---------------------------------------------------------------------------------------------------------- rocks
def rock_mass(name, blobs, keep_out=None, voxel=.3, target=1500, cell=2.6, seed=91, floor_y=None):
    """A sculpted rock from ellipsoid masses: voxel union, smoothed, Voronoi facets, decimated, kept out of keep_out."""
    bm = bmesh.new()
    for (c, r, yaw, tilt) in blobs:
        geom = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        cy, sy = math.cos(yaw), math.sin(yaw)
        ct, st = math.cos(tilt), math.sin(tilt)
        for v in geom["verts"]:
            x, y, z = v.co.x * r[0], v.co.z * r[1], -v.co.y * r[2]
            x, y = x * ct - y * st, x * st + y * ct                     # lean (about local z)
            x, z = x * cy + z * sy, -x * sy + z * cy                    # yaw
            v.co = L.bl((c[0] + x, c[1] + y, c[2] + z))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    L.only([obj])
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode, mod.voxel_size = "VOXEL", voxel
    bpy.ops.object.modifier_apply(modifier=mod.name)
    sm = obj.modifiers.new("Smooth", "SMOOTH")
    sm.factor, sm.iterations = .6, 10
    bpy.ops.object.modifier_apply(modifier=sm.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    Pts = np.array([L.rb(v.co) for v in bm.verts])
    edge, _ = L.voronoi_edge(Pts / cell, seed=seed)
    push = -.18 * smooth(0, .25, edge) + .12 * (L.fbm(Pts * .3, 3, seed=seed + 1) - .5) * 2
    for v, d in zip(bm.verts, push):
        v.co = v.co + v.normal * float(d)
    bm.to_mesh(obj.data)
    bm.free()
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target / max(1, L.tris(obj)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    if keep_out:
        for v in obj.data.vertices:
            v.co = L.bl(keep_out(L.rb(v.co)))
    if floor_y is not None:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        gone = [f for f in bm.faces if all(L.rb(v.co)[1] < floor_y for v in f.verts)]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
    # round 6 (mesh gate): the decimation leaves a few needle triangles; turn their edges (beauty fill) and drop the
    # ones that are still degenerate
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.beautify_fill(bm, faces=bm.faces, edges=[e for e in bm.edges if not e.is_boundary])
    bmesh.ops.dissolve_degenerate(bm, dist=.02, edges=bm.edges)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def fin_lobes(c, yaw):
    """The fin cluster's masses (centre, radii, yaw, tilt) on the ground at the fin's foot: along the ridge (D) and
    uphill (-N, away from the garden)."""
    D, N = S.TIER_D, S.TIER_N
    g = S.ground(c[0], c[2]) or 20.0
    out = []
    for ds, dt, ry, r, tilt in ((0, 0, 3.6, (4.6, 3.8, 3.2), .17), (-3.4, -1.8, 2.8, (3.4, 2.9, 2.8), .1),
                                (3.2, -1.0, 2.4, (3.0, 2.5, 2.5), -.08)):
        x = c[0] + D[0] * ds + N[0] * dt
        z = c[2] + D[1] * ds + N[1] * dt
        out.append(((x, g + ry, z), r, yaw, tilt))
    return out


def in_fin(points, grow=1.15):
    """Round 3 (Fable R3, CAM-TURN): island faces inside the fin cluster's masses (grown 15%) interleaved with it as
    pale strips; any point inside a lobe condemns the face."""
    lobes = []
    for kind, c, size, yaw in S.PATH_BLOCKS:
        if kind == "fin":
            lobes += fin_lobes(c, yaw)
    for p in points:
        for (cx, cy, cz), r, yw, _ in lobes:
            dx, dy, dz = p[0] - cx, p[1] - cy, p[2] - cz
            c_, s_ = math.cos(yw), math.sin(yw)
            lx, lz = dx * c_ - dz * s_, dx * s_ + dz * c_
            if (lx / (r[0] * grow)) ** 2 + (dy / (r[1] * grow)) ** 2 + (lz / (r[2] * grow)) ** 2 < 1:
                return True
    return False


def fin_boxes():
    """Collision for the fin cluster (kind "finrock"), one box per lobe, a little inside its drawn mass."""
    boxes = []
    for kind, c, size, yaw in S.PATH_BLOCKS:
        if kind != "fin":
            continue
        for (x, y, z), r, yw, _ in fin_lobes(c, yaw):
            boxes.append({"kind": "finrock", "c": [round(x, 3), round(y, 3), round(z, 3)],
                          "s": [round(r[0] * 1.5, 3), round(r[1] * 1.7, 3), round(r[2] * 1.4, 3)], "yaw": round(yw, 4)})
    return boxes


def corridor_keep_out(p, margin=.3):
    """Push a point out of the walking corridor (the tread's width + `margin`, from 0.2 under to 7 over the tread)
    sideways."""
    s = S._nearest(p[0], p[2])
    along = (p[0] - s["x"]) * s["dir"][0] + (p[2] - s["z"]) * s["dir"][1]
    if abs(along) > 1.0:
        return p
    a = (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1]
    half = s["w"] / 2 + margin
    if abs(a) < half and s["h"] - .2 < p[1] < s["h"] + 7:
        to = half if a >= 0 else -half
        return (p[0] + s["out"][0] * (to - a), p[1], p[2] + s["out"][1] * (to - a))
    return p


def fin_and_notch():
    """The fin hiding the turn as an irregular boulder round its collision box, and the notch's two leaning boulders,
    one sculpted mesh (cliff rock). Masses from the sculpt's own boxes (cliff_den_sculpt.PATH_BLOCKS)."""
    blobs = []
    for kind, c, size, yaw in S.PATH_BLOCKS:
        if kind == "fin":
            # Fable D1 5: a boulder cluster, not a menhir: three lobes, base wider than 1.3 x its height, the top
            # leaning 10 degrees, the extra mass uphill. Its own collision boxes (FIN_BOXES) replace the old tall fin box.
            for lobe in fin_lobes(c, yaw):
                blobs.append(lobe)
        elif kind == "notch":
            h = size[1]
            for k, f in enumerate((.25, .7)):
                blobs.append(((c[0], c[1] - h / 2 + h * f, c[2]), (2.0 - .3 * k, h * .34, 2.0 - .3 * k), yaw, .12))
    extra = flight_cheek_blobs() + wall_end_blobs()
    return rock_mass("W7_F_PathRocks__cliff_rock", blobs + extra, keep_out=corridor_keep_out,
                     target=1800 + 110 * len(extra), floor_y=3.5)


CHEEK = ((2.0, 1.9, 2.2), 2.0, -.9, 2.2)   # round 9: the return flight's outer cheek masses: radii (along, up, depth),
                                          # centre past the tread's edge, centre height from the ramp, spacing


CHEEK_FROM_W = 6.6                  # round 9: the cheek starts where the flight is under 6.6 wide (the turn's pocket is
                                    # the outbound leg's tread too: path check)


def flight_cheek_blobs():
    """Round 9 (Spencer beta 35, shot 55: "missing faces in the stairs area"; Studio: the right side of the return flight
    was the path's single shoulder sheet, a bare slanted plane beside the steps): rock masses along the flight's outer
    side, from the turn to the head, their tops up to a stud over the steps (a rock cheek; the corridor keep-out holds
    them off the treads)."""
    r, off, dy, every = CHEEK
    leg = [s for s in S.path_samples() if s["step"] and s["w"] < CHEEK_FROM_W]   # past the turn's pocket
    out, last = [], None
    for s in leg:
        if last is not None and s["d"] - last < every:
            continue
        last = s["d"]
        c = P(s, s["w"] / 2 + off, s["h"] + dy)
        out.append((c, r, math.atan2(s["out"][0], s["out"][1]), 0.0))
    return out


WALL_END = ((2.6, 2.4, 2.6), .6, 3.0)    # round 9: masses over the cut wall's open end at the foot: radii, how far
                                        # before the end (toward the den), the height step


def wall_end_blobs():
    """Round 9 (Spencer beta 35, shot 58: a missing panel and a seam left of the den's mouth by the foot's first steps;
    Studio: the cut wall began at the foot with a bare upright edge 18 high standing 2 to 5 in front of the mouth's west
    backing rock): a column of rock masses over that edge, from the lawn to the wall's top, reaching back into the mouth
    rock."""
    r, before, step = WALL_END
    s = samples(2)[0]
    back, top = wall_span(s)
    if back <= .05:
        return []
    bx, bz = -s["dir"][0], -s["dir"][1]
    out = []
    v = 3.6 + r[1] - s["h"]                       # the lowest mass's foot stays over the rock's floor (3.5)
    while v < top - s["h"] + .5:
        u = min(back, max(0.0, v) * LEAN) + r[2] + .3     # its inner side 0.3 behind the tread's edge (path check)
        x, y, z = P(s, -s["w"] / 2 - u, s["h"] + v)
        out.append(((x + bx * before, y, z + bz * before), r, math.atan2(s["out"][0], s["out"][1]), 0.0))
        v += step
    return out


MASS_SEAT = (1.0, 1.5)              # Fable R7 review A: a mass must overlap the cliff or another mass by 1.0; sunk 1.5


def _radius(r, yaw, u):
    """An ellipsoid's radius (radii r, yawed as rock_mass yaws: local z along (sin yaw, cos yaw)) along unit vector u."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    lx, lz = u[0] * cy - u[2] * sy, u[0] * sy + u[2] * cy
    return 1.0 / math.sqrt((lx / r[0]) ** 2 + (u[1] / r[1]) ** 2 + (lz / r[2]) ** 2)


def mass_overlap(a, b):
    """How deep two masses ((centre, radii, yaw), Roblox, yaw in radians) overlap along the line between their centres."""
    d = [b[0][k] - a[0][k] for k in range(3)]
    n = math.sqrt(sum(v * v for v in d))
    if n < 1e-6:
        return min(a[1]) + min(b[1])
    u = [v / n for v in d]
    return _radius(a[1], a[2], u) + _radius(b[1], b[2], [-v for v in u]) - n


def seat_masses(blobs, fixed, cliff_depth, need=MASS_SEAT[0], sink=MASS_SEAT[1]):
    """Fable R7 review A: every backing blob ((x, y, z), radii, yaw, tilt) sinks `sink` into the wall (back along its
    outward normal), then stays only if it reaches `need` into the cliff (cliff_depth(centre, inward unit, reach): how
    far in from the centre the cliff's surface is, or None) or overlaps a fixed mass ((centre, radii, yaw)) or a kept
    blob by `need`. Returns (kept, dropped)."""
    sunk = []
    for c, r, yaw, tilt in blobs:
        nx, nz = math.sin(yaw), math.cos(yaw)
        sunk.append(((c[0] - nx * sink, c[1], c[2] - nz * sink), r, yaw, tilt))
    kept, left = [], list(sunk)
    anchors = [(c, r, yaw) for c, r, yaw in fixed]
    changed = True
    while changed:
        changed = False
        for b in list(left):
            c, r, yaw, _ = b
            inward = (-math.sin(yaw), 0.0, -math.cos(yaw))
            t = cliff_depth(c, inward, r[2])
            seated = t is not None and r[2] - t >= need
            if seated or any(mass_overlap((c, r, yaw), a) >= need for a in anchors):
                kept.append(b)
                anchors.append((c, r, yaw))
                left.remove(b)
                changed = True
    return kept, left


def backing_mass(name, blobs):
    """Round 7 (Fable ROUND7 3): one sculpted rock over the swept holes, rock cells about 6 studs (5 to 7), kept out of
    the walking corridor. None when there is nothing to back."""
    if not blobs:
        return None
    return rock_mass(name, blobs, keep_out=lambda p: corridor_keep_out(p, BACKING_CLEAR), target=min(1600, 420 * len(blobs)),
                     cell=6.0, seed=93, floor_y=3.5)


# --------------------------------------------------------------------------------------------------------- the kit
# round 6 (Fable DEN-ROUND6-LOOK 2): 1.2 to 2.6 showing, 2 to 5 long
LIP_KIT = [(2.0, 1.5, 101), (2.8, 1.9, 102), (3.6, 2.2, 103), (4.3, 2.6, 104), (5.0, 2.9, 105)]   # length, height (0.8 to 1.8 showing: sunk 0.3), seed


def lip_stone(k):
    """Kit stone k (60 to 90 tris): a jittered, flattened icosphere, its base at y -0.3 (sunk 0.3), centred on x/z."""
    length, height, seed = LIP_KIT[k]
    rnd = np.random.default_rng(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)       # 80 tris
    for v in bm.verts:
        x, y, z = v.co.x, v.co.z, -v.co.y
        j = 1 + rnd.uniform(-.12, .12)
        y = max(y, -.55)                                                 # flat base
        top = 1.0 if y < .55 else .82 + .1 * rnd.uniform(-1, 1)          # rounded, slightly flattened top
        v.co = (x * j * length / 2, -z * j * (.45 + .1 * length), ((y + .55) / 1.55) * height * top - .3)   # round 6: deeper with length
    me = bpy.data.meshes.new(f"W7_F_Lip{k + 1}__boulder_rock")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(me.name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def stake():
    """A timber stake 0.5 square, 3.4 high (round 6, Fable 2), base at y 0 (local), a slanted cut top."""
    v, f = [], []
    s = .25
    for y, sc in ((-.4, 1.0), (3.25, .92)):
        for x, z in ((-s, -s), (s, -s), (s, s), (-s, s)):
            v.append((x * sc, y + (.12 if x > 0 else 0) * (y > 0), z * sc))
    for k in range(4):
        f.append([k, (k + 1) % 4, 4 + (k + 1) % 4, 4 + k])
    f.append([4, 5, 6, 7])
    f.append([3, 2, 1, 0])                  # round 6: the buried end closes too (one closed solid, wound outward)
    return outward(L.mesh_object("W7_F_Stake__wood", v, f, smooth=False, local=True))


def outward(obj):
    """Round 6: weld and wind a closed solid outward (bmesh), so no face of it renders inside out."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


LIP_KITS = 3                        # round 7: the path's lip stones use the three lower kit stones
LIP_OUT, LIP_SINK = .1, .4          # Fable R7 review B: the centre at most 0.1 past the edge; sunk 0.4
LIP_INTRUDE = .75                   # round 7 (Fable ROUND7 4): a lip stone reaches at most 0.75 over the tread (walk > 7)


def shelf_of(s):
    """1: the lower shelf (the foot's flight to the bend at PATH_CTRL[4]); 2: the upper shelf (the bend to the turn
    pocket, PATH_CTRL[8]); 3: the pocket and the return leg."""
    return 1 if s["seg"] < 4 else 2 if s["seg"] < 8 else 3


def lip_layout():
    """Lip stones along the lawn side where the drop is over 1.2 (off the flights). Round 7 (Fable ROUND7 4: round 6 left
    one stone on the wider path): each stone straddles the edge (centre 0.2 inside it, so the tread or its bank is under
    it; never more than LIP_INTRUDE over the tread), sunk 0.3, gaps 2.5 to 4.5 (about one per 7 studs), every fourth
    missing on shelf 1 only, three gaps of 4+ over the Paw Glade. Returns [{kit, at, yaw, box, shelf}] with `at` the
    stone's base point."""
    S_ = S.path_samples()
    rnd = np.random.default_rng(53)
    out, count, glade_gaps = [], 0, 0
    last_kit = -1
    i = 0
    while i < len(S_):
        s = S_[i]
        g = S.ground(*P(s, s["w"] / 2 + 1.0, 0)[::2])
        if on_flight(s) or g is None or s["h"] - g < 1.2 or s["flip"] != S_[min(i + 1, len(S_) - 1)]["flip"]:
            i += 1
            continue
        near_glade = math.hypot(s["x"] - GLADE[0], s["z"] - GLADE[1]) < 13 and glade_gaps < 3
        # round 7 (Fable ROUND7 4: 0.8 to 1.8 showing): kits 1 to 3 (1.2 to 1.9 over the tread); 4 and 5 stand 2.3+
        kit = int(rnd.integers(0, LIP_KITS))
        if kit == last_kit:
            kit = (kit + 1) % LIP_KITS
        last_kit = kit
        length, height, _ = LIP_KIT[kit]
        count += 1
        shelf = shelf_of(s)
        turn = math.radians(rnd.uniform(-15, 15))
        if shelf != 1 or count % 4 != 0:
            yaw = math.atan2(-s["dir"][1], s["dir"][0]) + turn
            depth = 2 * (.45 + .1 * length)          # the drawn stone's depth (lip_stone)
            # its inner reach from its centre (a turned stone's corner too): the centre sits 0.2 inside the edge, or as
            # far out as keeps that reach within LIP_INTRUDE of the edge
            reach = lambda t: depth / 2 * math.cos(t) + abs(math.sin(t)) * length / 2
            # Fable R7 review B: the centre never more than LIP_OUT past the edge (outer stones hung on the wall face);
            # the turn eases off until the stone's inner reach still keeps within LIP_INTRUDE of the edge
            while reach(turn) > LIP_INTRUDE + LIP_OUT and abs(turn) > .01:
                turn *= .8
            yaw = math.atan2(-s["dir"][1], s["dir"][0]) + turn
            a = min(s["w"] / 2 + LIP_OUT, max(s["w"] / 2 - .2, s["w"] / 2 - LIP_INTRUDE + reach(turn)))
            at = P(s, a, s["h"] - (LIP_SINK - .3))      # the kit stone's base is 0.3 under its point: sunk LIP_SINK
            out.append({"kit": kit + 1, "at": [round(v, 3) for v in at], "yaw": round(yaw, 4), "shelf": shelf,
                        "seat": round(s["h"], 3),
                        "box": {"c": [round(at[0], 3), round(s["h"] + height / 2 - LIP_SINK, 3), round(at[2], 3)],
                                "s": [round(length * .9, 3), round(height, 3), round(depth * .9, 3)], "yaw": round(yaw, 4)}})
        gap = 4.2 + rnd.uniform(0, .6) if near_glade else rnd.uniform(2.5, 4.5)
        if near_glade:
            glade_gaps += 1
        step = (length + gap) / S.SAMPLE
        i += max(1, int(round(step)))
    return out


def stake_layout():
    """Three stakes along the outer side of the return leg's flight (round 7: none at the foot's) and four round the
    turn, 4 to 5 apart, leaning a few degrees;
    the rope sags between them. Returns stakes [{at, yaw, lean}] and ropes [[from, to], ...] (rope attach points)."""
    S_ = S.path_samples()
    rnd = np.random.default_rng(59)
    stakes, ropes = [], []
    # Fable R7 review (R6 item 8): the foot flight's stakes read as two flat brown boards by the boulder; they go
    groups = [[s for s in S_ if s["step"]],
              [s for s in S_ if 62 <= s["d"] <= 74]]
    for g, n in zip(groups, (3, 4)):
        if not g:
            continue
        span = [g[int(round(k * (len(g) - 1) / (n - 1)))] for k in range(n)]
        group = []
        for s in span:
            at = P(s, s["w"] / 2 + .45, 0)
            at = (at[0], min(s["h"] - .1, S.ground(at[0], at[2]) or s["h"]) - .05, at[2])   # seated on the ground
            n = S._nearest(at[0], at[2])            # at the hairpin the outer side of one leg is the other leg's tread
            if abs((at[0] - n["x"]) * n["out"][0] + (at[2] - n["z"]) * n["out"][1]) < n["w"] / 2 + .3:
                continue
            group.append({"at": [round(v, 3) for v in at], "yaw": round(float(rnd.uniform(0, math.pi)), 3),
                          "lean": round(math.radians(float(rnd.uniform(3, 5))), 4)})
        stakes += group
        for a, b in zip(group, group[1:]):
            ropes.append([[a["at"][0], a["at"][1] + 2.2, a["at"][2]], [b["at"][0], b["at"][1] + 2.2, b["at"][2]]])
    return stakes, ropes


def facet(obj, cell=3.5, depth=.35):
    """Fable D1 3: break the cut into 3 to 4 stud facets: Voronoi planes pushed 0 to `depth` into the hill (never toward
    the tread), the foot and the outer skirt left as they are."""
    for v in obj.data.vertices:
        p = L.rb(v.co)
        s = S._nearest(p[0], p[2])
        a = (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1]
        if p[1] < s["h"] + .3 or a > -s["w"] / 2:
            continue
        edge, _ = L.voronoi_edge(np.array([p]) / cell, seed=97)
        push = depth * float(smooth(0, .25, edge)[0])
        v.co = L.bl((p[0] - s["out"][0] * push, p[1], p[2] - s["out"][1] * push))


def recut_test(points):
    """A face of a visual island part that reaches into the new cut's lower envelope (tread to 3.5 over it, from 2.8
    behind the inner edge to 0.3 past the outer) goes: the old island poked through the new wall and talus there."""
    # Fable world R1 8: by volume, the cut's whole box: from 0.3 past the outer edge to 3.6 behind the old cut line (the
    # new wall's cap reaches 3.4 behind it), from under the tread to 1.0 over the cap
    # round 6 (Studio R6e: a bank of island ground stood up beside the inner edge, pale against the wall): every sample
    # near the point, not only the nearest (the hairpin's other leg let it off), and the no-wall envelope to head height
    # round 7: the wall's span over a bank (wall_span), not the sculpt's
    for p in points:
        near = S._tread_grid().get((math.floor(p[0] / 4), math.floor(p[2] / 4)), ())
        if not _recut_one(p, near):
            continue
        return True
    return False


def _recut_one(p, near):
    for s in tuple(near) + (S._nearest(p[0], p[2]),):      # the nearest too (the grid reaches only 1.6 past the tread)
        along = (p[0] - s["x"]) * s["dir"][0] + (p[2] - s["z"]) * s["dir"][1]
        a = (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1]
        if abs(along) > 1.0:
            continue
        back, top = wall_span(s)
        if back <= .05:                          # no cut wall here: only the envelope over the tread, to head height
            if -s["w"] / 2 - 2.8 <= a <= s["w"] / 2 + .3 and s["h"] - .25 < p[1] < s["h"] + 6.5:
                return True
            continue
        if not (-s["w"] / 2 - back - 3.6 <= a <= s["w"] / 2 + .3):
            continue
        x, _, z = P(s, -s["w"] / 2 - back - 3.4, 0)
        g = S.ground(x, z)
        roof = max(top, g if g is not None else top) + 1.0
        if s["h"] - .3 < p[1] < roof:
            return True
    return False


_NEAR = None


def _near_samples(x, z):
    """Path samples whose cross-section (the tread plus 11 behind or past it) can reach (x, z): 4-stud buckets."""
    global _NEAR
    if _NEAR is None:
        _NEAR = {}
        for s in S.path_samples():
            r = s["w"] / 2 + 11.0
            for cx in range(math.floor((s["x"] - r) / 4), math.floor((s["x"] + r) / 4) + 1):
                for cz in range(math.floor((s["z"] - r) / 4), math.floor((s["z"] + r) / 4) + 1):
                    _NEAR.setdefault((cx, cz), []).append(s)
    return _NEAR.get((math.floor(x / 4), math.floor(z / 4)), ())


def _cross(p, s):
    """(along, a) of a Roblox point against sample s: along its direction, and toward the lawn from its centre line."""
    return ((p[0] - s["x"]) * s["dir"][0] + (p[2] - s["z"]) * s["dir"][1],
            (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1])


BANK = (6.0, -.25, 12.0, .5)        # round 7 (Fable ROUND7 1): behind the inner edge, from / to over the tread, normal y


def bank_face(points, ny):
    """Round 7 (Fable ROUND7 1, the pale bank): an island GROUND face standing on edge (normal y under 0.5) with a point
    within 6 behind the inner edge, from 0.25 under the tread to 12 over it. Nothing but the cliff's rock stands there."""
    depth, lo, hi, steep = BANK
    if ny >= steep:
        return False
    for p in points:
        for s in _near_samples(p[0], p[2]):
            along, a = _cross(p, s)
            if abs(along) <= .6 and -s["w"] / 2 - depth <= a <= -s["w"] / 2 + .3 and s["h"] + lo < p[1] < s["h"] + hi:
                return True
    return False


PLANK = ((-26.0, 3.0, -104.0), (-10.0, 20.0, -88.0), .5)   # round 7c (Studio: a tan plank at the west jamb)


def plank_face(points, ny):
    """Round 7c (Studio, beta 7b: a tall tan "plank" at the mouth's west jamb, island ground on edge): an island
    ground or grass face standing on edge (normal y under 0.5) whose centre (the last point) is in the PLANK box."""
    (x0, y0, z0), (x1, y1, z1), steep = PLANK
    c = points[-1]
    return ny < steep and x0 <= c[0] <= x1 and y0 <= c[1] <= y1 and z0 <= c[2] <= z1


def earth_face(points, ny):
    """The path slice's face rule for island ground and grass: the pale bank (ROUND7 1) and the west-jamb plank (7c)."""
    return bank_face(points, ny) or plank_face(points, ny)


FOOT_LAWN = ((-33.0, -96.0), (-11.0, -75.0), .15)   # round 8: (x, z) min, max round the foot's flight; over its foot


def foot_lawn(points):
    """Round 8 (Spencer beta 34, shot 52: "at the bottom of the stairs ... some missing faces / under/between the
    stairs"; Studio and Blender: the island's lawn round the foot's flight was cut away, and the island's underside
    showed 40 studs down beside and below the lowest steps, where no tread is drawn): an island ground or grass face at
    the foot whose every point stays at or under the path's foot height + 0.15 is lawn the steps stand on, never cut.
    Nothing of it reaches a step's top (the lowest is 0.4 over the foot) or a tread."""
    (x0, z0), (x1, z1), over = FOOT_LAWN
    top = S.path_samples()[0]["h"] + over
    return all(x0 <= p[0] <= x1 and z0 <= p[2] <= z1 and p[1] <= top for p in points)


UNDER = (.5, 1.0)                   # round 7 (Fable ROUND7 2): 0.5 past each edge, down to 1.0 under the tread


def under_tread(c):
    """Round 7 (Fable ROUND7 2, rock slivers through the tread): a face whose centre is within 0.5 past either edge and
    from 1.0 under the tread up goes (the island's carve stops at 0.3 under it); the tread's skirt hides the hole."""
    past, down = UNDER
    for s in _near_samples(c[0], c[2]):
        along, a = _cross(c, s)
        if abs(along) <= .6 and abs(a) <= s["w"] / 2 + past and s["h"] - down <= c[1] <= s["h"] + .3:
            return True
    return False


# Round 7 (Fable ROUND7 3, jagged shards): the orphan sweep (cliff_den_sculpt.carve's, over the terrace only) over two
# more envelopes. A connected island of 12 faces or fewer, or of 6 square studs or less, whose centre is in one goes.
SWEEP = (12, 6.0)
# Fable R7 review A (den/CAM-MOUTH-EAST: hanging cards west of the mouth): the west flank's envelope widened, and there
# an island of 20 faces or fewer, or of 12 square studs or less, goes
FLANK = ((-60.0, 6.0, -110.0), (-18.0, 40.0, -90.0))     # the mouth's west flank (x, y, z min and max)
SWEEP_BY = {"path": SWEEP, "flank": (20, 12.0)}


def sweepable(faces, area, env, most=None):
    """Is an island of `faces` faces and `area` square studs, centred in envelope `env`, small enough to go? `most`
    (faces, area), when given, raises the envelope's own limit."""
    lim = SWEEP_BY.get(env) if env else None
    if lim is None:
        return False
    if most:
        lim = (max(lim[0], most[0]), max(lim[1], most[1]))
    return len(faces) <= lim[0] or area <= lim[1]


def path_envelope(c):
    """0 to 10 behind the inner edge, from the tread to 14 over it."""
    for s in _near_samples(c[0], c[2]):
        along, a = _cross(c, s)
        behind = -s["w"] / 2 - a
        if abs(along) <= .6 and -.3 <= behind <= 10.0 and s["h"] - .3 <= c[1] <= s["h"] + 14.0:
            return True
    return False


def flank_envelope(c):
    (x0, y0, z0), (x1, y1, z1) = FLANK
    return x0 <= c[0] <= x1 and y0 <= c[1] <= y1 and z0 <= c[2] <= z1


def sweep_envelope(c):
    return "flank" if flank_envelope(c) else "path" if path_envelope(c) else None


def islands(obj):
    """The connected face islands of a mesh object: ([(faces (bmesh), centre (Roblox), area, normal (Roblox, area
    weighted))], the bmesh (the caller frees it))."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    mw = obj.matrix_world
    rot = mw.to_3x3()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, isl = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        area = sum(g.calc_area() for g in isl) or 1e-9
        cen, nrm = [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]
        for g in isl:
            c, w = L.rb(mw @ g.calc_center_median()), g.calc_area()
            n = L.rb(rot @ g.normal)
            for k in range(3):
                cen[k] += c[k] * w / area
                nrm[k] += n[k] * w
        out.append((isl, tuple(cen), area, tuple(nrm)))
    return out, bm


def sweep(obj, where=sweep_envelope, most=None):
    """Delete the small islands (sweepable: per envelope, SWEEP_BY, or `most` if bigger) whose centre is in an envelope.
    Returns the holes left: [(centre, area, unit normal (Roblox), envelope, [(face centre, its normal)] (biggest first),
    backed)]; a
    grass island's hole is not backed (Fable ROUND7 5: the flaps go outright, no masses chase them)."""
    backed = not re.search(r"__(grass|meadow)", obj.name)
    isl, bm = islands(obj)
    gone, holes = [], []
    for faces, cen, area, nrm in isl:
        env = where(cen)
        if not sweepable(faces, area, env, most):
            continue
        gone += faces
        ln = math.sqrt(sum(v * v for v in nrm)) or 1.0
        mw = obj.matrix_world
        rot = mw.to_3x3()
        pts = [(L.rb(mw @ f.calc_center_median()), L.rb(rot @ f.normal)) for f in sorted(faces, key=lambda f: -f.calc_area())]
        holes.append((cen, area, tuple(v / ln for v in nrm), env, pts, backed))
    if gone:
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(obj.data)
    bm.free()
    return holes


BACKING_CLEAR = 1.0                  # a backing mass's vertices stay this far past the tread's edge (its big decimated
                                    # faces then never reach over the tread: the tread probe)
BACKING = ((5.0, 4.0, 2.5), .8, 10.0)   # Fable ROUND7 3: a blob's radii (along, up, depth), how proud, the spacing


def backing_blobs(holes, radii=BACKING[0], proud=BACKING[1], spacing=BACKING[2], covered=()):
    """Rock masses backing the swept holes: one blob per `spacing` studs of hole (its middle, then any of its faces
    farther than spacing / 2 from a blob or from a `covered` point, a mass already there), its face `proud` in front of
    the hole along the hole's outward normal (the path side for a hole with no clear normal). Returns rock_mass blobs
    ((x, y, z), radii, yaw, tilt)."""
    blobs, at = [], list(covered)
    reach = min(spacing / 2, radii[0], radii[1])          # a blob covers this far round its point
    back = radii[2] - proud                               # the blob's front stands `proud` in front of the hole
    for cen, area, n, env, pts, backed in sorted(holes, key=lambda h: -h[1]):
        if not backed:
            continue
        for p, fn in [(cen, n)] + list(pts):              # the hole's middle first, then its faces, biggest first
            if any(math.dist(p, q) < reach for q in at):
                continue
            nx, nz = fn[0], fn[2]
            if math.hypot(nx, nz) < .3:                   # flat or unclear: the hole's own, else face the path
                nx, nz = (n[0], n[2]) if math.hypot(n[0], n[2]) >= .3 else S._nearest(p[0], p[2])["out"]
            m = math.hypot(nx, nz)
            nx, nz = nx / m, nz / m
            at.append(p)
            blobs.append(((p[0] - nx * back, p[1], p[2] - nz * back), radii, math.atan2(nx, nz), 0.0))
    return blobs


def tuck(obj):
    """Where the turn brings the two legs close, the outbound leg's cut rises under the return leg's tread: any wall
    vertex over another stretch's tread (inside its width) is tucked 0.05 under that tread."""
    for v in obj.data.vertices:
        p = L.rb(v.co)
        s = S._nearest(p[0], p[2])
        along = (p[0] - s["x"]) * s["dir"][0] + (p[2] - s["z"]) * s["dir"][1]
        a = (p[0] - s["x"]) * s["out"][0] + (p[2] - s["z"]) * s["out"][1]
        if abs(along) <= .9 and abs(a) < s["w"] / 2 and p[1] > s["h"] - .05:
            v.co = L.bl((p[0], s["h"] - .05, p[2]))


def foot_stones():
    """Kit stones as boulders: two flanking the foot, one hiding the live marble column stub at the path's foot (x -23.4
    to -20.6, z -78.8 to -77.2, top 5.1), and six fallen stones on the lawn under shelf 1 as if the cut shed them.
    Returns [{kit, at, yaw, scale}] (scale multiplies the kit stone). Beta 42 E21: the three at the foot carry
    "foot": True, and build_world_finish_pack.foot_boxes gives each an invisible collision box (0.85 of it, same yaw;
    scripts/check_world_finish_path.py --boxes keeps them off the tread)."""
    S_ = S.path_samples()
    foot = S_[0]
    rnd = np.random.default_rng(67)
    out = []
    along = math.atan2(-foot["dir"][1], foot["dir"][0])
    # round 5 (Fable): the lawn side only; the uphill one sat on the cliff over the foot and read as a round boulder stuck
    # in the wall west of the mouth
    for side in (1,):
        a = side * (foot["w"] / 2 + 1.6)
        at = P(foot, a, S.ground(*P(foot, a, 0)[::2]) or foot["h"])
        out.append({"kit": 4, "at": [round(v, 3) for v in at], "yaw": round(along, 3), "scale": [1.0, 1.6, 2.2],
                    "foot": True})
    # the white column stub at the path's foot (x -23.4..-20.6, z -79.4..-76.6, up to y 9.5; Fable world R1 7): one big
    # boulder over it and a smaller one in front, so it is buried from CAM-MOUTH30 and CAM-FOOT. Round 5: its top was
    # only 0.2 over the stub (the stub still showed in Studio); 4.0 tall puts it about 1.3 over.
    g = S.ground(-22.0, -78.0) or 4.6
    out.append({"kit": 5, "at": [-22.0, round(g - .1, 3), -78.0], "yaw": .3, "scale": [1.8, 4.0, 6.0], "foot": True})
    out.append({"kit": 3, "at": [-20.4, round(g - .1, 3), -75.6], "yaw": 1.2, "scale": [1.4, 2.0, 2.6], "foot": True})
    shelf1 = [s for s in S_ if 10 <= s["d"] <= 40]
    for k in range(6):
        s = shelf1[int(k * (len(shelf1) - 1) / 5)]
        a = s["w"] / 2 + 2.0 + float(rnd.uniform(0, 3.5))
        x, _, z = P(s, a, 0)
        g = S.ground(x, z)
        if g is None or s["h"] - g < 1.0:
            continue
        kit = int(rnd.integers(1, 4))
        sc = float(rnd.uniform(.6, 1.0))
        out.append({"kit": kit, "at": [round(x, 3), round(g, 3), round(z, 3)], "yaw": round(float(rnd.uniform(0, 6.28)), 3),
                    "scale": [round(sc, 3)] * 3})
    return out


def tufts():
    """Ferns and tufts in the back wall's foot every 8 to 12 studs (12 at most), WorldDressing bush rows."""
    S_ = S.path_samples()
    rnd = np.random.default_rng(61)
    out, next_d = [], 6.0
    for s in S_:
        if s["back"] > .5 and s["d"] >= next_d and len(out) < 12:
            at = P(s, -s["w"] / 2 - .6, s["h"])
            out.append([round(at[0], 3), round(s["h"] + .1, 3), round(at[2], 3), int(rnd.choice([1, 3])),
                        round(float(rnd.uniform(0, 6.28)), 2), round(float(rnd.uniform(.7, 1.0)), 2)])
            next_d = s["d"] + float(rnd.uniform(8, 12))
    return out
