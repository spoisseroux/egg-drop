"""Build the Hidden Grove art pack (artifacts/qa-2026-11-28-grove: GROVE-MOCKUP.md, GROVE-BUILD-PLAN.md,
ARCH-REVIEW-GROVE.md). Fable lane: art only. Nothing here touches Studio, src/ or the island export.

Run in BACKGROUND Blender only, never saving a .blend:
  blender.exe -b --factory-startup --python scripts/build_world_grove.py -- [--renders garden,wide,within,up,dusk]
                                                    [--res 1280] [--samples 48] [--skip-textures] [--skip-export]
                                                    [--void-check]   (review renders: the BACK of any single-sided mesh
                                                    shows in a flat colour, as in game it is a hole; cameras skirt,
                                                    skirtb and cove look at the island's foot)

The playable island (assets/world/world-v7.fbx) is loaded only to measure its footprint and to stand in the review
renders; it is never exported. Round it the script builds the hollow as game meshes:
- near band: GV_Bank__stone (the plinth the island stands on: a mossed cap tucked inside the cliff shell above the cliff
  feet, a shoulder just past the island's edge below them, then down to the moat bed and out to the first wall's foot;
  moat spires), GV_Moat__water (the water surface, 30 studs below the lawn)
- mid band: three cliff tiers, each a stone wall mesh (stepped strata) and a moss cap mesh (treads, lips, ledges),
  four waterfall gorges (GV_Falls__fall), ledge spires and stone lantern posts (GV_Rocks__stone), ledge trees
- the giants: nine old trees from 3 trunk and 3 crown variants (one mesh per variant, placed by `instances`), their
  crowns arching in over the rim round an oval sky opening, with the sun gate left empty toward the 10.5 sun
- dressing: lip ferns and hanging vine strands (leaf), six scenery tree houses, rope bridges, lantern strings, small trunks
  (GV_Props__paint, vertex-coloured), lanterns and windows (GV_Glow__glow, vertex-coloured warm/aqua)
- far band: eight opaque forest-rim sector meshes (GV_Far_1..8__leaf)
Everything is opaque geometry: no alpha cards anywhere.

Writes:
- assets/world/grove/grove.fbx            every pack mesh (static: origin at its bounds centre; giants: at the root)
- assets/world/grove/grove-manifest.json  the contract the runtime and the upload gate read
- assets/world/grove/tex/grove-{stone,moss,bark,leaf}.png   four tiling 1024 colour maps, drawn procedurally here
- assets/world/grove/tex/grove-ray.png    256 x 1024 white with alpha: the god rays' Beam texture (Y along the beam)
- artifacts/qa-2026-11-28-grove/build/build-<camera>.png    Cycles renders of the BUILT pack (with --renders)

ONE coordinate rule: Roblox (X, Y, Z) = Blender (x, z + 4, -y). (grove.py's "Blender (x, y, z) = Roblox (x, -z, y - 4)"
and the Aero kit's "Roblox (x, z + 4, -y)" are the same rule read in the two directions.) Yaw is about Roblox +Y and
equals the Blender angle about +Z. The Roblox import turns each mesh by pi about Y; the manifest does NOT bake that
turn (turnApplied false): a part shows the authored geometry at CFrame.new(center) * CFrame.Angles(0, math.pi, 0).
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "artifacts" / "qa-2026-11-28-grove" / "source"
OUT = ROOT / "assets" / "world" / "grove"
TEX = OUT / "tex"
REVIEW = ROOT / "artifacts" / "qa-2026-11-28-grove" / "build"
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


RENDERS = [c for c in (arg("--renders", "") or "").split(",") if c]
RES, SAMPLES = int(arg("--res", "1280")), int(arg("--samples", "48"))

TAU = math.tau
CX, CY = 12.0, 8.0            # the hollow's centre (Blender), as the mockup
PREFIX = "GV_"                # unique to this pack (world-finish-template-names)
WATER_Z = -30.0               # Blender; Roblox Y -26 (arch review: the moat surface at or below -25)
BANK_TOP_Z = -8.0             # the plinth's cap: 1 stud ABOVE the island's cliff feet (Blender -9 all round the rim),
                              # tucked inside the cliff shell, so no sight line passes under the cliffs (in-game critique 4)
SHOULDER_Z = -10.5            # the plinth's shoulder: 1.5 studs below the cliff feet, 1.5 studs outside the island's edge
CLIFF_FOOT_Z = -9.0           # where the island's rim cliffs end (measured: Roblox Y -5.0 to -4.0 round the whole rim)
CAP_IN = 14.0                 # the cap runs this far in under the island from the bank's top ring
CANOPY_MIN_Y = 130.0          # Roblox: crown undersides over the island stay above this (balloons fly below)
MID_MIN = 45.0                # studs past the rim every mid and far piece keeps
FALLS = [0.55, 2.35, 3.75, 5.35]                                  # gorge angles (Blender, about the centre)
GIANT_ANGLES = [0.2, 0.82, 1.45, 2.0, 2.7, 3.25, 4.02, 4.42, 4.8]   # none in the sun gate (4.80 .. 6.48)
GATE = (4.8, 0.2 + math.tau)                                       # the widest gap, centred on the 10.5 sun
HOUSES = (0, 2, 4, 6, 8, 1)
TILE = {"stone": 32.0, "moss": 16.0, "bark": 24.0, "leaf": 24.0}  # studs per 1024 tile
BUDGET = {"mesh": 10000, "far": 2000, "total": 45000, "groups": 40}
WHITE = (1.0, 1.0, 1.0)
UP = Vector((0, 0, 1))


# ------------------------------------------------------------------------------------------------------------- maths
def S(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def n1(theta, k, f=1.0):
    """Smooth periodic noise in -1..1 (the mockup's)."""
    return noise.noise(Vector((math.cos(theta) * f * 1.7 + k * 9.1, math.sin(theta) * f * 1.7 - k * 4.3, k * 2.7)))


def rin(theta):
    a, b, n = 122.0, 106.0, 2.6
    c, s = abs(math.cos(theta)), abs(math.sin(theta))
    return (c ** n / a ** n + s ** n / b ** n) ** (-1 / n)


def wrap(a):
    return math.atan2(math.sin(a), math.cos(a))


def gorge(theta):
    return max(math.exp(-(wrap(theta - f) / .09) ** 2) for f in FALLS)


def rb(v):
    """Blender point to Roblox studs."""
    return [round(v[0], 3), round(v[2] + 4, 3), round(-v[1], 3)]


def bl(p):
    return Vector((p[0], -p[2], p[1] - 4))


def lin(c):
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def mix(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))


def sun_direction(clock=10.5, latitude=41.7333):
    """The engine's sun for Lighting.ClockTime / GeographicLatitude (Roblox axes, unit, pointing AT the sun): the sun
    circles in the XY plane (east +X at 6:00, overhead at noon) and leans toward +Z by latitude - 23.5 degrees.
    Not read back in Studio from here: the runtime compares it with Lighting:GetSunDirection() (manifest sun.verified)."""
    a = TAU * clock / 24
    lean = math.radians(latitude - 23.5)
    v = Vector((math.sin(a) * math.cos(lean), -math.cos(a) * math.cos(lean), math.sin(lean)))
    return v.normalized()


# --------------------------------------------------------------------------------------------------------- footprint
EXCLUDE = ("W7_Crystals", "W7_CastleFlag", "W7_Water__cloud", "W7_Water__waterfall_sky", "W7_Underside")
NB = 1440


class Footprint:
    """The island in plan on a 1-stud grid, from every triangle of the meshes the grove keeps."""

    def __init__(self, objects):
        self.x0, self.y0, self.n = -180, -180, 400
        occ = np.zeros((self.n, self.n), bool)
        zmin = np.full((self.n, self.n), 1e9)
        zmax = np.full((self.n, self.n), -1e9)
        for o in objects:
            me = o.data
            me.calc_loop_triangles()
            if not me.loop_triangles:
                continue
            vs = np.array([tuple(o.matrix_world @ v.co) for v in me.vertices])
            tri = np.array([tuple(t.vertices) for t in me.loop_triangles])
            a, b, c = vs[tri[:, 0]], vs[tri[:, 1]], vs[tri[:, 2]]
            edge = np.maximum.reduce([np.linalg.norm((a - b)[:, :2], axis=1), np.linalg.norm((b - c)[:, :2], axis=1),
                                      np.linalg.norm((c - a)[:, :2], axis=1)])
            steps = np.clip(np.ceil(edge / .6).astype(int), 1, 400)
            for n in np.unique(steps):
                sel = steps == n
                w = np.array([(i / n, j / n, 1 - (i + j) / n) for i in range(n + 1) for j in range(n + 1 - i)])
                p = (w[:, 0, None, None] * a[sel][None] + w[:, 1, None, None] * b[sel][None]
                     + w[:, 2, None, None] * c[sel][None]).reshape(-1, 3)
                ix = np.floor(p[:, 0] - self.x0).astype(int)
                iy = np.floor(p[:, 1] - self.y0).astype(int)
                ok = (ix >= 0) & (ix < self.n) & (iy >= 0) & (iy < self.n)
                occ[ix[ok], iy[ok]] = True
                np.minimum.at(zmin, (ix[ok], iy[ok]), p[ok, 2])
                np.maximum.at(zmax, (ix[ok], iy[ok]), p[ok, 2])
        self.occ = occ
        self.zmax = zmax
        self.zmin = float(zmin[occ].min())
        inner = occ.copy()
        inner[1:-1, 1:-1] = occ[1:-1, 1:-1] & occ[:-2, 1:-1] & occ[2:, 1:-1] & occ[1:-1, :-2] & occ[1:-1, 2:]
        edge = np.argwhere(occ & ~inner)
        self.kd = KDTree(len(edge))
        for i, (ix, iy) in enumerate(edge):
            self.kd.insert((ix + self.x0 + .5, iy + self.y0 + .5, 0), i)
        self.kd.balance()
        # the outline: furthest occupied cell per direction from the centre
        cells = np.argwhere(occ)
        px, py = cells[:, 0] + self.x0 + .5 - CX, cells[:, 1] + self.y0 + .5 - CY
        r = np.hypot(px, py) + .75
        k = (np.floor((np.arctan2(py, px) % TAU) / TAU * NB).astype(int)) % NB
        out = np.zeros(NB)
        np.maximum.at(out, k, r)
        for _ in range(3):  # a cell is wider than a bin near the centre: fill single gaps
            out = np.maximum(out, np.minimum(np.roll(out, 1), np.roll(out, -1)))
        while (out == 0).any():  # a wider gap (small radii): take a filled neighbour, never 0 (the bank's top ring
            out = np.where(out == 0, np.maximum(np.roll(out, 1), np.roll(out, -1)), out)   # fell to the centre there)
        self.outline = out
        dil = np.max([np.roll(out, s) for s in range(-12, 13)], axis=0)
        raw = np.maximum(dil, [rin((i + .5) / NB * TAU) for i in range(NB)])
        sm = raw.copy()
        for _ in range(3):
            sm = np.mean([np.roll(sm, s) for s in range(-20, 21)], axis=0)
        self.rim = np.maximum(sm, dil + 1.0)                      # R(theta): the ring's reference radius
        self.top = np.min([np.roll(out, s) for s in range(-10, 11)], axis=0) - 3.0   # the bank's top ring
        self.shoulder = dil + 1.5                                                    # the plinth's shoulder, past the edge

    @staticmethod
    def _at(table, theta):
        x = (theta % TAU) / TAU * NB - .5
        i = math.floor(x)
        f = x - i
        return float(table[i % NB] * (1 - f) + table[(i + 1) % NB] * f)

    def R(self, theta):
        return self._at(self.rim, theta)

    def bank_top(self, theta):
        return self._at(self.top, theta)

    def shoulder_r(self, theta):
        return self._at(self.shoulder, theta)

    def top_z(self, p):
        """The island's highest surface over this cell (None off the island)."""
        ix, iy = math.floor(p[0] - self.x0), math.floor(p[1] - self.y0)
        return float(self.zmax[ix, iy]) if 0 <= ix < self.n and 0 <= iy < self.n and self.occ[ix, iy] else None

    def inside(self, p):
        ix, iy = math.floor(p[0] - self.x0), math.floor(p[1] - self.y0)
        return 0 <= ix < self.n and 0 <= iy < self.n and bool(self.occ[ix, iy])

    def dist(self, p):
        """Plan distance past the island's edge (negative over the island)."""
        d = self.kd.find((p[0], p[1], 0))[2]
        return -d if self.inside(p) else d - .71


# ------------------------------------------------------------------------------------------------------ mesh builder
class MB:
    def __init__(self, name, role, band, texture, max_level, smooth=False, double=False, kind=None, note=None):
        self.name, self.role, self.band, self.texture, self.max_level = PREFIX + name, role, band, texture, max_level
        self.smooth, self.double, self.kind, self.note = smooth, double, kind or texture, note
        self.F = []

    def poly(self, pts, uvs=None, col=WHITE, smooth=None, facing=None):
        pts = [Vector(p) for p in pts]
        cols = list(col) if isinstance(col, list) else [col] * len(pts)
        if facing is not None:
            n = (pts[1] - pts[0]).cross(pts[-1] - pts[0])
            if len(pts) == 4:
                n += (pts[2] - pts[1]).cross(pts[0] - pts[1]) + (pts[3] - pts[2]).cross(pts[1] - pts[2])
            if n.dot(facing) < 0:
                pts.reverse()
                cols.reverse()
                uvs = list(reversed(uvs)) if uvs else None
        self.F.append((pts, uvs, cols, self.smooth if smooth is None else smooth))

    def world_points(self):
        return [p for f in self.F for p in f[0]]

    def build(self):
        tile = TILE.get(self.texture, 16.0)
        bm = bmesh.new()
        col_l = bm.loops.layers.float_color.new("Col")
        uv_l = bm.loops.layers.uv.new("UVMap")
        for pts, uvs, cols, smooth in self.F:
            try:
                face = bm.faces.new([bm.verts.new(p) for p in pts])
            except ValueError:
                continue
            face.smooth = smooth
            face.normal_update()
            ax = max(range(3), key=lambda k: abs(face.normal[k]))
            for i, loop in enumerate(face.loops):
                loop[col_l] = (*lin(cols[i]), 1.0)
                if uvs:
                    loop[uv_l].uv = uvs[i]
                else:  # box-mapped by the face's own normal: tiles at TILE studs wherever it sits
                    q = loop.vert.co
                    loop[uv_l].uv = ((q.y, q.z) if ax == 0 else (q.x, q.z) if ax == 1 else (q.x, q.y))
                    loop[uv_l].uv = (loop[uv_l].uv[0] / tile, loop[uv_l].uv[1] / tile)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-3)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        me.color_attributes.active_color = me.color_attributes["Col"]
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def ring_frame(spine, i):
    n = len(spine)
    t = (spine[min(i + 1, n - 1)] - spine[max(i - 1, 0)]).normalized()
    ref = UP if abs(t.z) < .9 else Vector((1, 0, 0))
    u = t.cross(ref).normalized()
    return u, t.cross(u)


def tube(mb, spine, radii, segs, col=WHITE, lobes=0, lobe_amp=None, cap=True, wraps=None, smooth=True):
    """A tube along `spine` with cylindrical UVs: `wraps` whole tiles round it, the tile's own scale along it."""
    tile = TILE.get(mb.texture, 16.0)
    spine = [Vector(p) for p in spine]
    wraps = wraps or max(1, round(TAU * (sum(radii) / len(radii)) / tile))
    rings, vs, run = [], [], 0.0
    for i, p in enumerate(spine):
        u, w = ring_frame(spine, i)
        ring = []
        for k in range(segs + 1):
            a = TAU * (k % segs) / segs
            r = radii[i]
            if lobes and lobe_amp:
                r *= 1 + lobe_amp[i] * (.5 + .5 * math.cos(lobes * a + i * .15)) ** 2
            ring.append(p + (u * math.cos(a) + w * math.sin(a)) * r)
        if i:
            run += (p - spine[i - 1]).length
        rings.append(ring)
        vs.append(run / tile)
    for i in range(len(spine) - 1):
        mid = (spine[i] + spine[i + 1]) / 2
        for k in range(segs):
            pts = [rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]]
            uvs = [(k / segs * wraps, vs[i]), ((k + 1) / segs * wraps, vs[i]), ((k + 1) / segs * wraps, vs[i + 1]),
                   (k / segs * wraps, vs[i + 1])]
            mb.poly(pts, uvs, col, smooth, facing=(sum(pts, Vector()) / 4 - mid))
    if cap:
        tip = spine[-1] + (spine[-1] - spine[-2]).normalized() * radii[-1] * .6
        for k in range(segs):
            pts = [rings[-1][k], rings[-1][k + 1], tip]
            uvs = [(k / segs * wraps, vs[-1]), ((k + 1) / segs * wraps, vs[-1]), ((k + .5) / segs * wraps, vs[-1] + radii[-1] / tile)]
            mb.poly(pts, uvs, col, smooth, facing=tip - spine[-2])


def low_sphere(seg, bands):
    """A unit sphere of 2 * seg * (bands - 1) triangles."""
    verts, faces = [Vector((0, 0, 1))], []
    for b in range(1, bands):
        phi = math.pi * b / bands
        for s in range(seg):
            th = TAU * (s + (.5 if b % 2 else 0)) / seg
            verts.append(Vector((math.sin(phi) * math.cos(th), math.sin(phi) * math.sin(th), math.cos(phi))))
    verts.append(Vector((0, 0, -1)))
    last = len(verts) - 1
    for s in range(seg):
        faces.append((0, 1 + s, 1 + (s + 1) % seg))
        faces.append((last, 1 + (bands - 2) * seg + (s + 1) % seg, 1 + (bands - 2) * seg + s))
    for b in range(bands - 2):
        r0, r1 = 1 + b * seg, 1 + (b + 1) * seg
        for s in range(seg):
            a, b2, c, d = r0 + s, r0 + (s + 1) % seg, r1 + (s + 1) % seg, r1 + s
            if b % 2 == 0:   # the next ring is half a step on
                faces.append((a, d, b2)); faces.append((b2, d, c))
            else:
                faces.append((a, d, c)); faces.append((a, c, b2))
    return verts, faces


SPH_CROWN, SPH_TREE, SPH_LAMP = low_sphere(8, 5), low_sphere(7, 4), low_sphere(5, 3)


def blob(mb, c, r, squash=.6, shape=SPH_TREE, amp=.28, freq=.09, top=WHITE, under=None, sink=None):
    """A lumpy ball; its underside tinted `under` so each clump reads. `sink`: clamp its foot at this height."""
    c = Vector(c)
    under = under or top
    vs, cs = [], []
    for v in shape[0]:
        k = 1 + amp * noise.noise((c + v * r) * freq * 2.2) + amp * .5 * noise.noise((c + v * r) * freq * 6)
        p = c + Vector((v.x * r * k, v.y * r * k, v.z * r * k * squash))
        if sink is not None:
            p.z = max(p.z, sink)
        vs.append(p)
        cs.append(mix(under, top, S(v.z * .7 + .55)))
    for f in shape[1]:
        pts = [vs[i] for i in f]
        mb.poly(pts, None, [cs[i] for i in f], True, facing=sum(pts, Vector()) / 3 - c)


def ribbon(mb, pts, half, side, col=WHITE, taper=False, tile=None, u0=0.0):
    """A strip along `pts`, `half` wide each way along `side` (double-sided at run time)."""
    tile = tile or TILE.get(mb.texture, 16.0)
    run = 0.0
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        ln = (b - a).length
        ha = half
        hb = half * (0.05 if taper and i == len(pts) - 2 else 1)
        cols = col if isinstance(col, tuple) else col[i % len(col)]
        mb.poly([a - side * ha, a + side * ha, b + side * hb, b - side * hb],
                [(u0, run / tile), (u0 + 2 * half / tile, run / tile), (u0 + 2 * half / tile, (run + ln) / tile), (u0, (run + ln) / tile)],
                cols, False)
        run += ln


# ----------------------------------------------------------------------------------------------------------- terrain
class Terrain:
    """The hollow's section at any angle: bank and moat bed, three walls of stepped strata, ledges, the top."""
    TIERS = (  # strata as fractions of the wall's height, lean per riser, tread width
        ((0, .27, .52, .78, 1), 1.0, 3.0),
        ((0, .36, .70, 1), 1.3, 4.0),
        ((0, .36, .70, 1), 1.6, 5.0),
    )

    def __init__(self, fp):
        self.fp = fp

    def section(self, th):
        fp = self.fp
        g = gorge(th)
        R = fp.R(th)
        d0 = fp.bank_top(th) - R
        w1 = 55 + 4 * n1(th, 1, 2) + 12 * g
        zf = WATER_Z + 3 + 1.2 * n1(th, 7, 4)
        L1 = 30 + 10 * n1(th, 2, 3) - 5 * g
        L2 = L1 + 46 + 12 * n1(th, 4, 2) - 4 * g
        L3 = L2 + 48 + 16 * n1(th, 6, 2) - 8 * g
        led = (20 + 8 * n1(th, 3, 3), 24 + 9 * n1(th, 5, 3))
        c, s = math.cos(th), math.sin(th)

        def blk(row, amp):
            # noise.cell is -1..1. (The first build took it for 0..1: offsets ran -3 * amp .. amp, some treads came
            # out narrower than nothing and turned face down, which is a hole in a single-sided mesh.)
            return noise.cell(Vector(((R + w1) * c / 22, (R + w1) * s / 22, row * 5.3))) * amp
        ds = fp.shoulder_r(th) - R
        # the plinth the island stands on: a flat cap under the cliffs, a shoulder past their feet, then down to the bed
        rows = [(d0 - CAP_IN, BANK_TOP_Z, "bank"), (d0, BANK_TOP_Z, "bank"), (ds, SHOULDER_Z, "bank"),
                (ds + 3 + blk(1, 1.0), -17.5, "bank"), (ds + 7 + blk(2, 1.2), -24, "bank"),
                (ds + 12, WATER_Z - 1.5, "bank"), (w1 - 9, WATER_Z - 1.5, "bank"), (w1 - 3, WATER_Z + 1.2, "bank")]
        a, z0 = w1, zf
        info = {"R": R, "w1": w1, "zf": zf, "g": g, "tiers": [], "ds": ds}
        for k, (top, (fr, lean, tread)) in enumerate(zip((L1, L2, L3), self.TIERS)):
            foot_d, foot_z = a, z0
            for i in range(1, len(fr)):
                off = blk(k * 10 + i, 1.2)
                z1 = z0 + (top - z0) * fr[i] if i < len(fr) - 1 else top
                rows.append((a + off, foot_z if i == 1 else rows[-1][1] + .3, "T%ds" % (k + 1)))
                rows.append((a + lean + off, z1, "T%dm" % (k + 1)))
                a += lean + (tread if i < len(fr) - 1 else 0)
            lip_d = a
            if k < 2:
                rows.append((lip_d + 3.5, top + 1.0, "T%dm" % (k + 1)))
                a, z0 = lip_d + led[k], top + 1.6
                info["tiers"].append({"foot": (foot_d, foot_z), "lip": (lip_d, top), "ledge": (lip_d + 3.5, a - 1.5, top + 1.3)})
            else:
                rows.append((lip_d + 4, top + 1.0, "T3m"))
                rows.append((lip_d + 16, top + 2.5, None))
                info["tiers"].append({"foot": (foot_d, foot_z), "lip": (lip_d, top), "ledge": (lip_d + 4, lip_d + 14, top + 1.5)})
        info["rows"] = rows
        return info

    def at(self, th, d, z):
        r = self.fp.R(th) + d
        return Vector((CX + r * math.cos(th), CY + r * math.sin(th), z))


BANK_OUT_ROWS = 5                                   # rows[0..5] are the island side of the bank (cap, shoulder, slopes)
PLINTH_MOSS, PLINTH_EDGE = (.62, .86, .46), (.80, .93, .70)   # the cap and shoulder: mossed stone (a tint on the tile)
BANK_COLS = (PLINTH_MOSS, PLINTH_MOSS, PLINTH_EDGE, WHITE, WHITE, WHITE, WHITE, WHITE, WHITE)
RISER_FOOT = (.90, .89, .87)


def columns():
    n = 144
    ths = [TAU * j / n for j in range(n)]
    for f in FALLS:
        j = round(f / (TAU / n))
        ths[j - 1], ths[j], ths[j + 1] = f - .03, f, f + .03
    return ths


def build_terrain(T, M):
    ths = columns()
    secs = [T.section(th) for th in ths]
    mesh_of = {"bank": M["Bank"], "T1s": M["T1s"], "T1m": M["T1m"], "T2s": M["T2s"], "T2m": M["T2m"], "T3s": M["T3s"], "T3m": M["T3m"]}
    n = len(ths)
    wraps = {}
    turned = 0
    for j in range(n):
        a, b = secs[j], secs[(j + 1) % n]
        tha, thb = ths[j], ths[(j + 1) % n] + (TAU if j == n - 1 else 0)
        inward = Vector((-math.cos(tha), -math.sin(tha), 0))
        run_a = run_b = 0.0
        for i in range(len(a["rows"]) - 1):
            (da, za, tag), (da1, za1, _) = a["rows"][i], a["rows"][i + 1]
            (db, zb, _), (db1, zb1, _) = b["rows"][i], b["rows"][i + 1]
            la, lb = math.hypot(da1 - da, za1 - za), math.hypot(db1 - db, zb1 - zb)
            mb = mesh_of[tag]
            pts = [T.at(tha, da, za), T.at(thb, db, zb), T.at(thb, db1, zb1), T.at(tha, da1, za1)]
            uvs = None
            if mb.texture == "stone":
                w = wraps.setdefault(tag, max(8, round(TAU * (a["R"] + da) / TILE["stone"])))
                uvs = [(tha / TAU * w, run_a / 32), (thb / TAU * w, run_b / 32), (thb / TAU * w, (run_b + lb) / 32),
                       (tha / TAU * w, (run_a + la) / 32)]
            cols, facing = WHITE, inward * .6 + UP
            if tag == "bank":
                # The island-side slopes face OUT from the centre. (They were given the walls' inward rule: the steep
                # ones turned inside out and vanished in game, where a mesh is single-sided.)
                if i < BANK_OUT_ROWS:
                    nq = (pts[1] - pts[0]).cross(pts[3] - pts[0]) + (pts[3] - pts[2]).cross(pts[1] - pts[2])
                    turned += (nq.dot(facing) < 0) != (nq.dot(UP - inward * .6) < 0)
                    facing = UP - inward * .6
                cols = [BANK_COLS[i]] * 2 + [BANK_COLS[i + 1]] * 2
            elif mb.texture == "stone":
                # each riser: its own block tone, and a soft crease shadow at its foot (the ring casts no shadows)
                k = .5 + .5 * noise.cell(Vector((round(tha * 9), i * 3.7, 11.0)))
                tone = (1 - .06 * k, 1 - .065 * k, 1 - .08 * k)
                foot = tuple(t * f for t, f in zip(tone, RISER_FOOT))
                cols = [foot, foot, tone, tone]
            mb.poly(pts, uvs, cols, facing=facing)
            run_a += la
            run_b += lb
    print("GROVE bank faces the walls' inward rule would turn inside out:", turned)
    # the moat's surface: one flat ring from under the bank to under the far shore
    W = M["Water"]
    for j in range(n):
        tha, thb = ths[j], ths[(j + 1) % n]
        a, b = secs[j], secs[(j + 1) % n]
        da, db = T.fp.bank_top(tha) - a["R"] + 8, T.fp.bank_top(thb) - b["R"] + 8
        W.poly([T.at(tha, da, WATER_Z), T.at(thb, db, WATER_Z), T.at(thb, b["w1"] - 4, WATER_Z), T.at(tha, a["w1"] - 4, WATER_Z)],
               None, WHITE, facing=UP)
    return ths, secs


def build_falls(T, M):
    """Each gorge: a sheet over each wall, arcing clear of the strata, and a stream across each ledge."""
    F, out = M["Falls"], []
    water, deep = (.86, .97, 1.0), (.70, .90, .98)
    for gi, f in enumerate(FALLS):
        sec = T.section(f)
        width = 13.0 + 2 * n1(f, 9, 1)
        tan = Vector((-math.sin(f), math.cos(f), 0))
        prev_bottom = None
        for k in (2, 1, 0):
            tier = sec["tiers"][k]
            (fd, fz), (ld, lz) = tier["foot"], tier["lip"]
            land = WATER_Z + .1 if k == 0 else fz + .4
            top = T.at(f, ld - .6, lz + .5)
            if prev_bottom is not None:   # the stream across the ledge above this wall
                a, b = prev_bottom, T.at(f, ld + 1.5, lz + 1.5)
                for sgn in (-1, 1):
                    F.poly([a, a + tan * sgn * width / 2, b + tan * sgn * width / 2, b],
                           [(.5, 0), (.5 + .5 * sgn, 0), (.5 + .5 * sgn, 1), (.5, 1)], deep, False, facing=UP)
                F.poly([b - tan * width / 2, b + tan * width / 2, top + tan * width / 2, top - tan * width / 2],
                       [(0, 0), (1, 0), (1, .2), (0, .2)], water, True, facing=UP)
            rows = 7
            line = []
            for i in range(rows + 1):
                s = i / rows
                d = (ld - .6) - ((ld - .6) - (fd - 2.5)) * (1 - (1 - s) ** 2)
                line.append(T.at(f, d, lz + .5 + (land - lz - .5) * s))
            run = 0.0
            for i in range(rows):
                ln = (line[i + 1] - line[i]).length
                for sgn in (-1, 1):
                    F.poly([line[i], line[i] + tan * sgn * width / 2, line[i + 1] + tan * sgn * width / 2, line[i + 1]],
                           [(.5, run / 16), (.5 + .5 * sgn, run / 16), (.5 + .5 * sgn, (run + ln) / 16), (.5, (run + ln) / 16)],
                           water, True, facing=Vector((-math.cos(f), -math.sin(f), .3)))
                run += ln
            out.append({"gorge": gi + 1, "tier": k + 1, "top": rb(line[0]), "bottom": rb(line[-1]), "width": round(width, 2),
                        "into": "moat" if k == 0 else "ledge"})
            prev_bottom = line[-1]
    return out


# ------------------------------------------------------------------------------------------------------------ giants
UNDER_LEAF = (.70, .80, .72)
CROWN_TINT = ((1, 1, 1), (.90, 1, .88), (1, 1, .84))


def giant_variant(idx, trunk, crown):
    """One old tree in its own frame: origin at the root, +X toward the garden, Z up. Returns its spine and radii."""
    rng = random.Random(9100 + idx)
    H = (215.0, 228.0, 240.0)[idx]
    r0 = (12.0, 13.5, 15.0)[idx]
    bend = (24.0, 30.0, 36.0)[idx]
    sway = (6.0, -8.0, 4.0)[idx]
    N = 11
    spine, rad, amp = [], [], []
    for k in range(N):
        t = k / (N - 1)
        spine.append(Vector((bend * t * t, sway * math.sin(t * 3), -8 + (H + 8) * t)))
        rad.append(r0 * (1 - .52 * t) + r0 * 1.3 * math.exp(-t * 11))
        amp.append(.75 * math.exp(-t * 9))
    tube(trunk, spine, rad, 12, lobes=5, lobe_amp=amp, wraps=3)
    tint = CROWN_TINT[idx]
    tips = [(spine[-1], 25.0), (spine[-1] + Vector((8, -6, 10)), 20.0), (spine[-2] + Vector((12, 9, 8)), 23.0),
            (spine[-2] + Vector((-9, 11, 4)), 21.0), (spine[-1] + Vector((16, 2, -3)), 24.0)]
    for q in range(7):
        a = TAU * q / 7 + rng.uniform(-.3, .3) + idx * .4
        reach = max(0.0, math.cos(a))
        t0 = rng.uniform(.72, .9)
        i0 = min(N - 2, int(t0 * (N - 1)))
        dirn = Vector((math.cos(a), math.sin(a), 0))
        ln = 34 + 44 * reach + rng.uniform(-4, 4)
        bs = [spine[i0] + dirn * ln * s + Vector((0, 0, ln * .5 * s - 12 * s * s)) for s in (0, .3, .6, .85, 1)]
        tube(trunk, bs, [rad[i0] * .5, rad[i0] * .38, rad[i0] * .26, rad[i0] * .16, .7], 6, wraps=1)
        tips.append((bs[4], rng.uniform(20, 26) + 3 * reach))
        tips.append((bs[3] if reach < .5 else bs[2] + Vector((0, 0, 4)), rng.uniform(18, 23)))
        if reach >= .5:
            tips.append((bs[3], rng.uniform(19, 24)))
        if reach < .2 and q % 2 == 0:   # a hanging vine on an outward bough (never over the garden)
            p = bs[3] + Vector((0, 0, -5))
            ln2 = rng.uniform(22, 44)
            pts = [p + Vector((1.5 * math.sin(i * 1.3), 0, -ln2 * i / 4)) for i in range(5)]
            ribbon(crown, pts, 1.6, Vector((-dirn.y, dirn.x, 0)), mix(tint, UNDER_LEAF, .4), taper=True)
    for tip, r in tips:
        c = tip + Vector((rng.uniform(-7, 7), rng.uniform(-7, 7), rng.uniform(3, 9)))
        blob(crown, c, r, .58, SPH_CROWN, .26, .09, tint, mix(tint, UNDER_LEAF, 1.0) if tint == WHITE else UNDER_LEAF)
    return spine, rad, H


# ------------------------------------------------------------------------------------------------------- dressing
WOOD, CREAM, ROOF, ROPE = (.66, .47, .28), (.97, .95, .88), (.12, .72, .78), (.80, .68, .46)
WOOD_DARK, SMALL_BARK = (.52, .36, .21), (.62, .46, .30)
WARM, AQUA = (1.0, .84, .48), (.48, .94, 1.0)


def disc(mb, c, r, h, segs, col, col_side=None):
    c = Vector(c)
    ring = [c + Vector((math.cos(TAU * k / segs), math.sin(TAU * k / segs), 0)) * r for k in range(segs + 1)]
    for k in range(segs):
        a, b = ring[k], ring[k + 1]
        mb.poly([c + UP * h, a + UP * h, b + UP * h], None, col, False, facing=UP)
        mb.poly([c, a, b], None, col_side or col, False, facing=-UP)
        mb.poly([a, b, b + UP * h, a + UP * h], None, col_side or col, False, facing=(a + b) / 2 - c)


def cone(mb, c, profile, segs, col):
    """Rings of (radius, height) about `c`, the last closing to a point."""
    c = Vector(c)
    rings = [[c + Vector((math.cos(TAU * k / segs) * r, math.sin(TAU * k / segs) * r, h)) for k in range(segs + 1)]
             for r, h in profile]
    for i in range(len(rings) - 1):
        for k in range(segs):
            pts = [rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]]
            if profile[i + 1][0] < .01:
                pts = pts[:3]
            mb.poly(pts, None, col, False, facing=sum(pts, Vector()) / len(pts) - c)


class Dressing:
    def __init__(self, M, lanterns):
        self.M, self.lanterns = M, lanterns
        self.rng = random.Random(77)

    def lantern(self, p, big=1.0, kind=None, source="string", hang=True):
        kind = kind or ("warm" if self.rng.random() < .6 else "aqua")
        col = WARM if kind == "warm" else AQUA
        p = Vector(p)
        blob(self.M["Glow"], p, 1.3 * big, 1.15, SPH_LAMP, 0, 1, col)
        if hang:
            top = Vector(p) + UP * 1.3 * big
            ribbon(self.M["Props"], [top, top + UP * 1.6 * big], .12, Vector((1, 0, 0)), ROPE)
        self.lanterns.append({"pos": rb(p), "kind": kind, "radius": round(1.3 * big, 2), "source": source})

    def swag(self, a, b, sag, n, planks=False):
        P = self.M["Props"]
        pts = [a.lerp(b, i / n) + Vector((0, 0, -sag * math.sin(math.pi * i / n))) for i in range(n + 1)]
        dirn = (b - a).normalized()
        sd = Vector((-dirn.y, dirn.x, 0)).normalized()
        if not planks:
            ribbon(P, pts, .22, UP, ROPE)
            for i in range(1, n, 2):
                self.lantern(pts[i] + Vector((0, 0, -2.9 * 1.4)), 1.4, source="string")
            return
        fine = [a.lerp(b, i / (n * 3)) + Vector((0, 0, -sag * math.sin(math.pi * i / (n * 3)))) for i in range(n * 3 + 1)]
        for i in range(n * 3):
            p, q = fine[i], fine[i].lerp(fine[i + 1], .72)
            P.poly([p - sd * 2.4, p + sd * 2.4, q + sd * 2.4, q - sd * 2.4], None, WOOD if i % 2 else WOOD_DARK, False, facing=UP)
        for off in (-2.4, 2.4):
            ribbon(P, [p + sd * off + UP * 3.4 for p in pts], .2, UP, ROPE)
            for i in range(0, n + 1, 2):
                ribbon(P, [pts[i] + sd * off, pts[i] + sd * off + UP * 3.4], .2, dirn, ROPE)
        for i in range(2, n - 1, 2):
            self.lantern(pts[i] + sd * (2.4 if i % 4 else -2.4) + UP * (3.3 + 1.5 * 1.2), 1.2, source="bridge", hang=False)


# ------------------------------------------------------------------------------------------------------------ build
def build(fp):
    T = Terrain(fp)
    M = {
        "Bank": MB("Bank__stone", "bank", "near", "stone", 2, note="seals island cliff bottoms to the moat bed; moat spires"),
        "Water": MB("Moat__water", "water", "near", "", 2, kind="water", note="the existing pool look; no texture"),
        "T1s": MB("Tier1__stone", "tier", "mid", "stone", 2), "T1m": MB("Tier1__moss", "tier", "mid", "moss", 2, smooth=True),
        "T2s": MB("Tier2__stone", "tier", "mid", "stone", 2), "T2m": MB("Tier2__moss", "tier", "mid", "moss", 2, smooth=True),
        "T3s": MB("Tier3__stone", "tier", "mid", "stone", 2), "T3m": MB("Tier3__moss", "tier", "mid", "moss", 2, smooth=True),
        "Falls": MB("Falls__fall", "falls", "mid", "", 2, double=True, kind="fall", note="white water sheets; vertex-coloured, u across, v = studs / 16 down the flow"),
        "Rocks": MB("Rocks__stone", "rocks", "mid", "stone", 2, note="ledge spires and stone lantern posts"),
        "TreeLeaf": MB("LedgeTrees__leaf", "trees", "mid", "leaf", 2, smooth=True),
        "Dress": MB("Dressing__leaf", "dressing", "dressing", "leaf", 1, double=True, note="lip ferns and hanging vine strands"),
        "Props": MB("Props__paint", "props", "dressing", "", 1, double=True, kind="paint",
                    note="tree houses, decks, rope bridges, lantern strings, small trunks; vertex-coloured, no texture"),
        "Glow": MB("Glow__glow", "lanterns", "dressing", "", 1, smooth=True, kind="glow",
                   note="lanterns and windows; vertex-coloured warm #FFD67A / aqua #7AF0FF; Neon at night"),
    }
    for k in range(8):
        M["Far%d" % (k + 1)] = MB("Far_%d__leaf" % (k + 1), "far", "far", "leaf", 2, smooth=True)
    for i, v in enumerate("ABC"):
        M["Trunk" + v] = MB("Giant_Trunk%s__bark" % v, "giant_trunk", "giant", "bark", 2, smooth=True)
        M["Crown" + v] = MB("Giant_Crown%s__leaf" % v, "giant_crown", "giant", "leaf", 2, smooth=True, double=True)
    rng = random.Random(7)
    ths, secs = build_terrain(T, M)
    falls = build_falls(T, M)
    lanterns, instances = [], []
    D = Dressing(M, lanterns)

    def clear_of(th, items, gap):
        return all(abs(wrap(th - x)) > gap for x in items)

    # the far forest rim: eight sectors, each a rolling canopy and rounded crowns
    for k in range(8):
        mb = M["Far%d" % (k + 1)]
        cols = 12
        grid = []
        for j in range(cols + 1):
            th = TAU * (k + j / cols) / 8
            sec = T.section(th)
            ld, lz = sec["tiers"][2]["lip"]
            wob = 14 * n1(th, 11, 4)
            grid.append([T.at(th, ld + 10, lz + 1.2), T.at(th, ld + 48, lz + 12 + wob), T.at(th, ld + 115, lz + 8 - wob),
                         T.at(th, ld + 200, lz - 30)])
        for j in range(cols):
            for i in range(3):
                mb.poly([grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]], None, (.86, .96, .86), facing=UP)
        for c in range(11):
            th = TAU * (k + (c + rng.uniform(.15, .85)) / 11) / 8
            sec = T.section(th)
            ld, lz = sec["tiers"][2]["lip"]
            far = (c % 3) / 2
            d = ld + 16 + 70 * far + rng.uniform(0, 26)
            r = rng.uniform(20, 27) + 9 * far
            z = lz + 6 + 12 * far + rng.uniform(0, 8) + r * .35
            tint = rng.choice(CROWN_TINT)
            blob(mb, T.at(th, d, z), r, .7, SPH_TREE, .22, .05, tint, UNDER_LEAF)

    # the giants: three variants, nine placements
    variants = [giant_variant(i, M["Trunk" + v], M["Crown" + v]) for i, v in enumerate("ABC")]
    giants = []
    for gi, th0 in enumerate(GIANT_ANGLES):
        th = th0 + rng.uniform(-.04, .04)
        sec = T.section(th)
        v = (gi * 2 + gi // 3) % 3
        scale = rng.uniform(.96, 1.04)
        base = T.at(th, sec["w1"] + 13 + rng.uniform(0, 4), sec["zf"] - 1)
        yaw = (th + math.pi) % TAU
        mat = Matrix.Translation(base) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
        for part in ("Trunk", "Crown"):
            instances.append({"tree": "Giant_%d" % (gi + 1), "mesh": M[part + "ABC"[v]].name, "pivot": rb(base),
                              "yaw": round(yaw, 6), "scale": round(scale, 6)})
        giants.append({"th": th, "mat": mat, "variant": v, "scale": scale, "base": base})

    def spine_point(g, t):
        spine, rad, H = variants[g["variant"]]
        x = t * (len(spine) - 1)
        i = min(len(spine) - 2, int(x))
        p = spine[i].lerp(spine[i + 1], x - i)
        r = rad[i] + (rad[i + 1] - rad[i]) * (x - i)
        return g["mat"] @ p, r * g["scale"]

    # tree houses on round decks (scenery), with lit windows
    P = M["Props"]
    houses = []
    for gi in HOUSES:
        g = giants[gi]
        t = rng.uniform(.2, .32)
        c, r = spine_point(g, t)
        inward = Vector((-math.cos(g["th"]), -math.sin(g["th"]), 0))
        side = Vector((-inward.y, inward.x, 0))
        rr = r + 3.5
        disc(P, c, rr + 4.5, 1.0, 16, WOOD, WOOD_DARK)
        hc = c + (inward * .7 + side * .7).normalized() * (rr + .3) + UP
        cone(P, hc, [(4.4, 0), (4.4, 6.5)], 10, CREAM)
        cone(P, hc, [(6.1, 6.3), (3.5, 8.4), (0, 12.6)], 10, ROOF)
        for a in range(4):
            wpos = hc + Vector((math.cos(a * 1.57 + .4), math.sin(a * 1.57 + .4), 0)) * 4.3 + UP * 3.6
            blob(M["Glow"], wpos, 1.1, 1.25, SPH_LAMP, 0, 1, WARM)
        lanterns.append({"pos": rb(hc + UP * 3.6), "kind": "warm", "radius": 4.5, "source": "house"})
        for a in range(10):
            p = c + Vector((math.cos(a * .628), math.sin(a * .628), 0)) * (rr + 4.1) + UP
            ribbon(P, [p, p + UP * 3.2], .25, Vector((-math.sin(a * .628), math.cos(a * .628), 0)), WOOD_DARK)
        rail = [c + Vector((math.cos(TAU * k / 16), math.sin(TAU * k / 16), 0)) * (rr + 4.1) + UP * 4.2 for k in range(17)]
        ribbon(P, rail, .22, UP, ROPE)
        D.lantern(c + inward * (rr + 4.2) + UP * 7.8, 1.7, "warm", "deck", hang=False)
        ribbon(P, [c + inward * (rr + 4.2) + UP, c + inward * (rr + 4.2) + UP * 5.5], .2, side, WOOD_DARK)
        houses.append((c + UP, rr + 4.3, g["th"]))
    gate = sum(GATE) / 2

    def crosses_gate(tha, thb):
        return abs(wrap((tha + wrap(thb - tha) / 2) - gate)) < .75
    order = sorted(houses, key=lambda h: h[2])
    bridges = 0
    for (a, ra, tha), (b, rbb, thb) in zip(order, order[1:] + order[:1]):
        if (a - b).length < 200 and not crosses_gate(tha, thb):
            dirn = (b - a).normalized()
            dirn.z = 0
            dirn.normalize()
            D.swag(a + dirn * ra, b - dirn * rbb, (a - b).length * .07, max(6, int((a - b).length / 11)), planks=True)
            bridges += 1
    strings = 0
    for g1, g2 in zip(giants, giants[1:] + giants[:1]):
        if crosses_gate(g1["th"], g2["th"]):
            continue
        (a, ra), (b, rbb) = spine_point(g1, .09), spine_point(g2, .09)
        if (a - b).length < 185:
            dirn = (b - a).normalized()
            D.swag(a + dirn * ra * .9, b - dirn * rbb * .9, (a - b).length * .1, max(6, int((a - b).length / 12)))
            strings += 1

    # rock spires: in the moat (with the bank) and on the ledges (with the lantern posts)
    spire_ths = []
    for i in range(26):
        for _ in range(40):
            th = rng.uniform(0, TAU)
            if clear_of(th, FALLS, .16) and clear_of(th, spire_ths, .1):
                break
        spire_ths.append(th)
        sec = T.section(th)
        if i < 16:
            d = rng.uniform(30, sec["w1"] - 13)
            base = T.at(th, d, WATER_Z - 4)
            h = rng.uniform(22, 58)
            mb, r = M["Bank"], rng.uniform(3.5, 6.5)
        else:
            tier = sec["tiers"][i % 2]
            lo, hi, z = tier["ledge"]
            if hi - lo < 8 or not clear_of(th, [g["th"] for g in giants], .12):
                continue
            base = T.at(th, rng.uniform(lo + 3, hi - 3), z - 2)
            h = rng.uniform(16, 38)
            mb, r = M["Rocks"], rng.uniform(3, 5)
        lean = Vector((rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5), 0))
        spine = [base + lean * (k / 4) + UP * (h * k / 4) for k in range(5)]
        tube(mb, spine, [r * (1.15 - .2 * k * k / 4 + .12 * math.sin(k * 2.1 + th * 7)) for k in range(5)], 6, smooth=False)
    # stone lantern posts on ledge one, facing the garden
    posts = 0
    for k in range(24):
        th = TAU * k / 24 + rng.uniform(-.05, .05)
        sec = T.section(th)
        if sec["g"] > .25:
            continue
        ld, lz = sec["tiers"][0]["lip"]
        p = T.at(th, ld + 2.2, lz + .6)
        tube(M["Rocks"], [p - UP, p + UP * 4.6], [.75, .55], 5, cap=False, smooth=False, wraps=1)
        cone(M["Rocks"], p + UP * 4.6, [(1.1, 0), (1.1, .4), (0, 1.1)], 5, WHITE)
        D.lantern(p + UP * 7.9, 1.7, None, "post", hang=False)
        posts += 1

    # ledge trees: small trunks (painted) and rounded crowns
    trees = 0
    for _ in range(60):
        if trees >= 28:
            break
        th = rng.uniform(0, TAU)
        sec = T.section(th)
        tier = sec["tiers"][0 if rng.random() < .5 else 1]
        lo, hi, z = tier["ledge"]
        if sec["g"] > .2 or hi - lo < 9 or not clear_of(th, [g["th"] for g in giants], .1):
            continue
        base = T.at(th, rng.uniform(lo + 3, hi - 2.5), z)
        H = rng.uniform(22, 42)
        lean = Vector((rng.uniform(-3, 3), rng.uniform(-3, 3), 0))
        spine = [base + UP * (-2 + (H + 2) * k / 2) + lean * (k / 2) ** 2 for k in range(3)]
        tube(P, spine, [H * .07, H * .05, H * .028], 5, SMALL_BARK, cap=False, smooth=False)
        tint = rng.choice(CROWN_TINT)
        for b_ in range(2 if H < 30 else 3):
            c = spine[-1] + Vector((rng.uniform(-.22, .22) * H, rng.uniform(-.22, .22) * H, rng.uniform(-.08, .12) * H))
            blob(M["TreeLeaf"], c, H * rng.uniform(.26, .36), .72, SPH_TREE, .26, .12, tint, UNDER_LEAF)
        trees += 1

    # ferns along the ledge lips (where they show against the wall from below)
    DR = M["Dress"]
    ferns = 0
    for _ in range(400):
        if ferns >= 60:
            break
        th = rng.uniform(0, TAU)
        sec = T.section(th)
        if sec["g"] > .25:
            continue
        k = rng.randrange(3)
        ld, lz = sec["tiers"][k]["lip"]
        d = rng.uniform(.8, 3.4)
        p = T.at(th, ld + d, lz + .29 * d + .1)
        size = rng.uniform(3.4, 6.2)
        tint = rng.choice(((.9, 1, .9), (1, 1, .85), (.85, 1, .95)))
        for bld in range(6):
            a = TAU * bld / 6 + rng.uniform(-.3, .3)
            out = Vector((math.cos(a), math.sin(a), 0))
            sd = Vector((-out.y, out.x, 0))
            m = p + out * size * .55 + UP * size * .5
            tip = p + out * size + UP * size * .12
            u0 = rng.random()
            DR.poly([p, m + sd * size * .2, tip, m - sd * size * .2],
                    [(u0, 0), (u0 + size * .4 / 24, size * .5 / 24), (u0, size / 24), (u0 - size * .4 / 24, size * .5 / 24)],
                    tint, True)
        ferns += 1

    # Hanging vines. In game the old curtains (flat cards up to 6 studs wide, hung 3 studs clear of the lip and longer than
    # the stratum under it) read as floating green squares. Now: bundles of three thin tapered strands with leaves, each
    # draped over a stratum's edge and lying on the rock face down to no further than that stratum's foot.
    n_col = len(ths)
    risers = [i for i, row in enumerate(secs[0]["rows"][:-1]) if row[2] and row[2][0] == "T" and row[2].endswith("s")]

    def wall_point(th, i):
        """Row `i` of the wall at any angle, as the MESH has it (a chord between the two columns either side)."""
        th %= TAU
        j = max(k for k in range(n_col) if ths[k] <= th)
        t0, t1 = ths[j], ths[j + 1] if j + 1 < n_col else TAU
        ra, rb_ = secs[j]["rows"][i], secs[(j + 1) % n_col]["rows"][i]
        return T.at(t0, ra[0], ra[1]).lerp(T.at(t1 % TAU, rb_[0], rb_[1]), (th - t0) / (t1 - t0))
    vines = strands = 0
    for _ in range(600):
        if vines >= 48:
            break
        th = rng.uniform(0, TAU)
        if gorge(th) > .3:
            continue
        i = rng.choice(risers)
        top0 = wall_point(th, i + 1)
        if top0.z - wall_point(th, i).z < 7:
            continue
        r_here = math.hypot(top0.x - CX, top0.y - CY)
        tint = rng.choice(((.80, .95, .78), (.90, 1, .80), (.74, .92, .82)))
        for sn in range(3):
            th_s = th + ((sn - 1) * rng.uniform(1.1, 1.9) + rng.uniform(-.3, .3)) / r_here
            top, bot = wall_point(th_s, i + 1), wall_point(th_s, i)
            h = top.z - bot.z
            inward = Vector((-math.cos(th_s), -math.sin(th_s), 0))
            tan = Vector((-inward.y, inward.x, 0))
            ln = min(22.0, h * rng.uniform(.45, .92))
            r0 = rng.uniform(.38, .55)

            def face(f):
                return top.lerp(bot, f) + inward * .55
            pts = [top - inward * 1.3 + UP * .45, top + inward * .5 - UP * .2,
                   face(.5 * ln / h) + tan * rng.uniform(-.5, .5), face(ln / h)]
            tube(DR, pts, [r0, r0, r0 * .7, r0 * .15], 3, tint, cap=False, wraps=1)
            for q, f in enumerate((.3, .55, .8)):
                at = pts[1].lerp(pts[3], f) + inward * .3
                side = tan * (1 if (q + sn) % 2 else -1)
                size = rng.uniform(1.5, 2.3) * (1 - .3 * f)
                DR.poly([at + UP * .35, at - UP * .35 + inward * .2, at + side * size - UP * size * .55 + inward * .5],
                        None, tint, False)
            strands += 1
        vines += 1
    counts = {"giants": len(giants), "houses": len(houses), "bridges": bridges, "lanternStrings": strings, "posts": posts,
              "ledgeTrees": trees, "ferns": ferns, "vineCurtains": vines, "vineStrands": strands}
    return T, M, giants, variants, instances, falls, lanterns, counts


# ---------------------------------------------------------------------------------------------------------- textures
def pnoise(n, freq, rng, fy=None):
    """Tiling value noise in 0..1 with `freq` cells across (and `fy` down)."""
    fy = fy or freq
    lat = rng.random((fy, freq))
    x = np.arange(n) * freq / n
    y = np.arange(n) * fy / n
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fyy = x - x0, y - y0
    fx, fyy = fx * fx * (3 - 2 * fx), fyy * fyy * (3 - 2 * fyy)
    a = lat[np.ix_(y0 % fy, x0 % freq)]
    b = lat[np.ix_(y0 % fy, (x0 + 1) % freq)]
    c = lat[np.ix_((y0 + 1) % fy, x0 % freq)]
    d = lat[np.ix_((y0 + 1) % fy, (x0 + 1) % freq)]
    return (a * (1 - fx) + b * fx) * (1 - fyy[:, None]) + (c * (1 - fx) + d * fx) * fyy[:, None]


def fbm(n, freq, rng, octaves=4, fy=None):
    out, amp, total = np.zeros((n, n)), 1.0, 0.0
    for o in range(octaves):
        out += amp * pnoise(n, freq * 2 ** o, rng, (fy or freq) * 2 ** o)
        total += amp
        amp *= .5
    return out / total


def voronoi_edge(n, cells, rng, stretch=1.0):
    """Tiling Voronoi: distance to the nearest cell edge (F2 - F1), in cell units."""
    cy = max(1, round(cells * stretch))
    px = rng.random((cy, cells))
    py = rng.random((cy, cells))
    u = (np.arange(n) + .5) / n * cells
    v = (np.arange(n) + .5) / n * cy
    U, V = np.meshgrid(u, v)
    iu, iv = np.floor(U).astype(int), np.floor(V).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ju, jv = iu + dx, iv + dy
            qx = ju + px[jv % cy, ju % cells]
            qy = jv + py[jv % cy, ju % cells]
            d = np.hypot(U - qx, (V - qy) / stretch * 1.0)
            near = d < f1
            f2 = np.where(near, f1, np.minimum(f2, d))
            f1 = np.where(near, d, f1)
    return f2 - f1


def ramp(x, stops):
    xs = [s[0] for s in stops]
    return np.stack([np.interp(x, xs, [s[1][i] for s in stops]) for i in range(3)], axis=-1)


def lerp_img(a, b, k):
    return a + (b - a) * k[..., None]


def tex_stone(n, rng):
    """Warm white limestone: crisp grey cracks, cream patches, a few cool patches, faint strata.
    In game the first bake (mean .81 .85 .88, blue-grey cracks) went sky-blue under WorldAero's haze (#CFEFFF, density
    .29) and blue sky light. The tile is now warm of neutral, so the haze brings it back to pale blue-white, not ice."""
    tone = fbm(n, 3, rng, 4)
    img = ramp(tone, [(.30, (.90, .88, .83)), (.50, (.96, .94, .89)), (.70, (1.0, .985, .95))])
    cream = np.clip((fbm(n, 4, rng, 3) - .50) / .12, 0, 1)
    img = lerp_img(img, np.array((.96, .87, .68)), cream * .9)
    cool = np.clip((fbm(n, 5, rng, 3) - .60) / .10, 0, 1)
    img = lerp_img(img, np.array((.85, .90, .94)), cool * .5)
    strata = fbm(n, 2, rng, 3, fy=28)
    img *= (1 - .07 * np.clip((strata - .55) / .1, 0, 1))[..., None]
    big = voronoi_edge(n, 7, rng, 1.0)
    fine = voronoi_edge(n, 19, rng, .6)
    line = 1 - np.clip(big / .045, 0, 1)
    hair = (1 - np.clip(fine / .05, 0, 1)) * .6
    img = lerp_img(img, np.array((.40, .39, .40)), np.clip(line, 0, 1) * .95)
    img = lerp_img(img, np.array((.60, .59, .58)), hair * (1 - line))
    bevel = np.clip((big - .045) / .10, 0, 1)            # a light lip beside each crack keeps them crisp
    img *= (.92 + .08 * bevel)[..., None]
    img *= (1 + .05 * (pnoise(n, 256, rng) - .5))[..., None]
    return np.clip(img, 0, 1)


def tex_moss(n, rng):
    """Lime to emerald, blade-level speckle."""
    base = fbm(n, 5, rng, 5)
    img = ramp(base, [(.28, (.13, .52, .14)), (.50, (.27, .70, .14)), (.72, (.56, .88, .22))])
    blades = fbm(n, 96, rng, 2, fy=40)
    img = lerp_img(img, np.array((.70, .94, .30)), np.clip((blades - .62) / .12, 0, 1) * .55)
    img = lerp_img(img, np.array((.09, .44, .14)), np.clip((.36 - blades) / .12, 0, 1) * .45)
    dots = pnoise(n, 200, rng)
    img = lerp_img(img, np.array((.86, .98, .46)), (dots > .93) * .6)
    return np.clip(img, 0, 1)


def tex_bark(n, rng):
    """Warm tan with long vertical ridges and crisp dark furrows; a little moss on the upper sides (small blotches)."""
    warp = (fbm(n, 5, rng, 3) - .5) * 46
    cols = (np.arange(n)[None, :] + warp).astype(int) % n
    ridge = np.take_along_axis(fbm(n, 34, rng, 2, fy=3), cols, axis=1)
    fine = np.take_along_axis(fbm(n, 110, rng, 2, fy=7), cols, axis=1)
    r = (1 - np.abs(2 * ridge - 1)) ** .8 * .75 + (1 - np.abs(2 * fine - 1)) * .25
    img = ramp(r, [(.30, (.38, .25, .16)), (.48, (.58, .41, .26)), (.70, (.74, .57, .38)), (.92, (.87, .72, .51))])
    furrow = np.clip((.36 - r) / .05, 0, 1)
    img = lerp_img(img, np.array((.30, .19, .12)), furrow * .75)
    img *= (1 + .10 * (fbm(n, 5, rng, 2, fy=64) - .5))[..., None]      # short cross checks
    img *= (1 + .05 * (pnoise(n, 256, rng) - .5))[..., None]
    moss = np.clip((fbm(n, 9, rng, 4) - .655) / .025, 0, 1) * (pnoise(n, 120, rng) > .22)
    green = ramp(pnoise(n, 80, rng), [(0, (.20, .58, .15)), (1, (.50, .84, .22))])
    img = img * (1 - moss[..., None]) + green * moss[..., None]
    return np.clip(img, 0, 1)


def tex_leaf(n, rng):
    """Clustered leaves in three greens, stamped in layers from deep to lime."""
    img = ramp(fbm(n, 6, rng, 3), [(0, (.06, .34, .11)), (1, (.11, .44, .14))])
    layers = (((.09, .42, .13), (.14, .52, .15), 150), ((.17, .60, .14), (.27, .72, .16), 135), ((.44, .82, .18), (.62, .92, .26), 95))
    for lo, hi, clusters in layers:
        for _ in range(clusters):
            cx, cy = rng.random() * n, rng.random() * n
            base = np.array(lo) + (np.array(hi) - np.array(lo)) * rng.random()
            for k in range(int(rng.integers(5, 8))):
                ang = TAU * k / 6 + rng.uniform(-.35, .35)
                ln = rng.uniform(34, 56)
                wd = ln * rng.uniform(.34, .46)
                ox, oy = cx + math.cos(ang) * ln * .55, cy + math.sin(ang) * ln * .55
                half = int(ln * .62) + 5
                ys = np.arange(int(oy) - half, int(oy) + half + 1)
                xs = np.arange(int(ox) - half, int(ox) + half + 1)
                X, Y = np.meshgrid(xs - ox, ys - oy)
                a = X * math.cos(ang) + Y * math.sin(ang)       # along the leaf, -ln/2 .. ln/2
                b = -X * math.sin(ang) + Y * math.cos(ang)
                t = a / (ln / 2)
                width = wd / 2 * (1 - t * t) * (1 - .25 * t)
                inside = (np.abs(t) < 1) & (np.abs(b) < width)
                edge = np.clip((width - np.abs(b)) / 2.2, 0, 1)
                shade = (.80 + .26 * (t * .5 + .5)) * (.86 + .14 * edge)
                rib = np.clip(1 - np.abs(b) / 1.3, 0, 1) * .18
                colour = np.clip(base[None, None, :] * shade[..., None] + rib[..., None] * np.array((.5, .6, .3)), 0, 1)
                iy, ix = np.ix_(ys % n, xs % n)
                # a soft shadow under the leaf first (down-right), then the leaf
                sy, sx = np.ix_((ys + 4) % n, (xs + 3) % n)
                img[sy, sx] = np.where(inside[..., None], img[sy, sx] * .86, img[sy, sx])
                img[iy, ix] = np.where(inside[..., None], colour, img[iy, ix])
    return np.clip(img, 0, 1)


RAY_PX, RAY_STUDS = (256, 1024), 140.0   # width x height; image Y runs ALONG the Beam (as water-strand.png), X across


def tex_ray(rng):
    """God-ray shaft for the Beams: white, alpha only. A broad soft body, straight soft bands and a few fine streaks
    (light does not wander), clear edges; each band breathes slowly along Y and the tile repeats along Y."""
    w, h = RAY_PX
    u = ((np.arange(w) + .5) / w)[None, :]
    y = ((np.arange(h) + .5) / h)[:, None] * TAU
    edge = np.clip(np.minimum(u, 1 - u) / .26, 0, 1)
    edge = edge * edge * (3 - 2 * edge)
    alpha = .50 * np.exp(-((u - .5) / .27) ** 2) * (1 + .10 * np.sin(y + 1.0))
    for lo, hi, amp_lo, amp_hi, count in ((.045, .10, .14, .30, 6), (.012, .022, .10, .20, 5)):
        for _ in range(count):
            cx, wd, amp = rng.uniform(.16, .84), rng.uniform(lo, hi), rng.uniform(amp_lo, amp_hi)
            k, ph = int(rng.integers(1, 3)), rng.uniform(0, TAU)
            alpha = alpha + amp * (1 + .22 * np.sin(y * k + ph)) / 1.22 * np.exp(-((u - cx) / wd) ** 2)
    alpha = np.clip(alpha / alpha.max() * .92, 0, 1) * edge
    return np.concatenate([np.ones((h, w, 3)), alpha[..., None]], axis=-1)


def write_textures():
    TEX.mkdir(parents=True, exist_ok=True)
    out = {}
    for seed, (name, fn) in enumerate((("stone", tex_stone), ("moss", tex_moss), ("bark", tex_bark), ("leaf", tex_leaf))):
        n = 1024
        path = TEX / ("grove-%s.png" % name)
        if "--skip-textures" not in ARGV or not path.exists():
            rgb = fn(n, np.random.default_rng(4100 + seed))
            rgba = np.concatenate([rgb[::-1], np.ones((n, n, 1))], axis=-1).astype(np.float32)
            image = bpy.data.images.new("grove-" + name, n, n, alpha=False)
            image.pixels.foreach_set(rgba.ravel())
            image.filepath_raw = str(path)
            image.file_format = "PNG"
            image.save()
            bpy.data.images.remove(image)
            print("GROVE texture", path.name, "mean", [round(float(x), 3) for x in rgb.reshape(-1, 3).mean(axis=0)])
        out[name] = {"color": "assets/world/grove/tex/" + path.name, "colorId": "", "studsPerTile": TILE[name], "pixels": 1024,
                     "texelsPerStud": round(1024 / TILE[name], 2), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    path = TEX / "grove-ray.png"
    if "--skip-textures" not in ARGV or not path.exists():
        rgba = tex_ray(np.random.default_rng(4190))
        image = bpy.data.images.new("grove-ray", RAY_PX[0], RAY_PX[1], alpha=True)
        image.alpha_mode = "STRAIGHT"
        image.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel())
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
        bpy.data.images.remove(image)
        print("GROVE texture", path.name, "mean alpha", round(float(rgba[..., 3].mean()), 3), "max", round(float(rgba[..., 3].max()), 3))
    out["ray"] = {"color": "assets/world/grove/tex/" + path.name, "colorId": "", "studsPerTile": RAY_STUDS, "pixels": list(RAY_PX),
                  "alpha": True, "use": "Beam.Texture for the god rays (no mesh wears it): image Y along the beam, X across; "
                                        "studsPerTile is the Beam's TextureLength",
                  "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    return out


# ------------------------------------------------------------------------------------------------------------ export
def geom_digest(me):
    h = hashlib.sha1()
    for v in me.vertices:
        h.update(("%.4f %.4f %.4f;" % tuple(v.co)).encode())
    for p in me.polygons:
        h.update((",".join(str(i) for i in p.vertices) + ";").encode())
    attr = me.color_attributes.active_color
    if attr:
        for d in attr.data:
            h.update(("%.3f %.3f %.3f;" % tuple(d.color[:3])).encode())
    return hashlib.sha1(h.digest()).hexdigest()[:16]


def centred(obj):
    """Origin at the bounds centre (as the island and kit meshes); returns the Blender centre."""
    vs = [v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2
    obj.data.transform(Matrix.Translation(-c))
    obj.location = c
    return c


def extent(obj):
    vs = [v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    return lo, hi


def main():
    sys.path.insert(0, str(SRC))
    import island  # the mockup's island loader: placement and checks only
    island.REPO = str(ROOT).replace("\\", "/")
    island.TEX = island.REPO + "/assets/world/textures/grounded/"
    island.load_island(False)
    island_objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith(EXCLUDE)]
    for o in list(bpy.data.objects):   # under the moat now: not part of the grove's island (hides / runtime)
        if o.type == "MESH" and o.name.startswith(EXCLUDE):
            bpy.data.objects.remove(o)
    fp = Footprint(island_objs)
    assert BANK_TOP_Z > CLIFF_FOOT_Z > SHOULDER_Z, "the plinth must straddle the cliff feet"
    textures = write_textures()
    T, M, giants, variants, instances, falls, lanterns, counts = build(fp)

    # ---- objects, checks, manifest
    sun = sun_direction()
    sun_b = Vector((sun.x, -sun.z, sun.y))
    meshes, export, objs = {}, [], {}
    violations, total = [], 0
    inst_of = {}
    for inst in instances:
        inst_of.setdefault(inst["mesh"], []).append(inst)
    crown_world = []
    for key, mb in M.items():
        obj = mb.build()
        tris = len(obj.data.polygons)
        placed = inst_of.get(mb.name)
        if placed:
            mats = [g["mat"] for g in giants for part in ("Trunk", "Crown") if M[part + "ABC"[g["variant"]]] is mb]
            world = [m @ v.co for m in mats for v in obj.data.vertices]
            if key.startswith("Crown"):
                crown_world += world
        else:
            world = [v.co.copy() for v in obj.data.vertices]
        # nothing of the ring over the playable island, except the canopy high above it and the bank under its skirt
        dists = [fp.dist(p) for p in world]
        for p, d in zip(world, dists):
            if d < 0 and not (p.z <= BANK_TOP_Z + .3 or p.z + 4 >= CANOPY_MIN_Y):
                violations.append((mb.name, rb(p), round(d, 2)))
        if key == "Bank":   # the plinth's cap stays buried: under the island's own surface wherever it is over the island
            cover = sorted((round(fp.top_z(p) - p.z, 2), rb(p)) for p, d in zip(world, dists)
                           if d < -2.5 and fp.top_z(p) is not None)
            print("GROVE plinth cap vertices under the island:", len(cover), "least cover", cover[:4])
            assert cover and cover[0][0] >= .3, ("the plinth's cap shows through the island", cover[:4])
            bank_cover = cover[0][0]
        if mb.role in ("tier", "bank"):   # no face of the terrain looks down (a mesh is single-sided in game)
            down = [rb(obj.data.vertices[t.vertices[0]].co) for t in obj.data.polygons if t.normal.z < -.25]
            assert not down, (mb.name, "triangles facing down", len(down), down[:5])
        min_rim = min(dists)
        lo, hi = extent(obj)
        size = [round(hi.x - lo.x, 4), round(hi.z - lo.z, 4), round(hi.y - lo.y, 4)]
        entry = {"name": mb.name, "role": mb.role, "band": mb.band, "kind": mb.kind, "texture": mb.texture, "tris": tris,
                 "size": size, "shadow": False, "doubleSided": mb.double, "maxLevel": mb.max_level,
                 "minRimDist": round(min_rim, 2)}
        c = (lo + hi) / 2
        if placed:
            entry["pivotToCentre"] = [round(c.x, 4), round(c.z, 4), round(-c.y, 4)]   # origin stays at the root
            entry["instances"] = len(placed)
        else:
            centred(obj)
            entry["center"] = rb(c)
        entry["hash"] = geom_digest(obj.data)
        if mb.note:
            entry["note"] = mb.note
        assert tris <= (BUDGET["far"] if mb.band == "far" else BUDGET["mesh"]), (mb.name, tris)
        if mb.band in ("mid", "far"):
            assert min_rim >= MID_MIN, (mb.name, "is", min_rim, "studs past the rim")
        total += tris * (len(placed) if placed else 1)
        meshes[mb.name] = entry
        objs[mb.name] = obj
        export.append(obj)
    assert not violations, ("ring geometry over the playable island", len(violations), violations[:8])
    groups = sum(1 for m in meshes.values() if "instances" not in m) + len(instances)
    assert total <= BUDGET["total"], ("triangles", total)
    assert groups <= BUDGET["groups"], ("groups", groups)
    assert len(set(meshes)) == len(M) and all(n.startswith(PREFIX) for n in meshes)

    # the canopy: its underside over the island, and the sky opening it leaves
    over = [p for p in crown_world if fp.dist(p) < 0]
    canopy_bottom = min(p.z for p in over) + 4
    assert canopy_bottom >= CANOPY_MIN_Y, ("canopy underside", canopy_bottom)
    bins = [None] * 72
    for p in crown_world:
        k = int((math.atan2(p.y - CY, p.x - CX) % TAU) / TAU * 72) % 72
        r = math.hypot(p.x - CX, p.y - CY)
        bins[k] = r if bins[k] is None else min(bins[k], r)

    def mean_r(centre):
        vals = [bins[(centre + i) % 72] for i in range(-5, 6) if bins[(centre + i) % 72] is not None]
        return sum(vals) / len(vals) if vals else None
    rx = [v for v in (mean_r(0), mean_r(36)) if v]
    rz = [v for v in (mean_r(18), mean_r(54)) if v]
    opening = {"center": rb(Vector((CX, CY, canopy_bottom - 4))), "radii": [round(sum(rx) / len(rx), 1), round(sum(rz) / len(rz), 1)],
               "minRadius": round(min(b for b in bins if b is not None), 1),
               "openBins": [round((k + .5) * 5, 1) for k in range(72) if bins[k] is None],
               "note": "radii along Roblox X and Z: nearest crown per direction from the centre; openBins are the directions "
                       "(degrees from +X toward -Z) with no crown at all: the sun gate"}

    # the sun gate and the god-ray cards (Beams): from the canopy down to just above the lawn, along the 10.5 sun
    az_b = math.atan2(sun_b.y, sun_b.x) % TAU
    assert GATE[0] + .5 < az_b < GATE[1] - .5, ("the sun is not in the gate", az_b, GATE)
    gate_sec = T.section(az_b)
    gate_pos = T.at(az_b, gate_sec["tiers"][2]["lip"][0], gate_sec["tiers"][2]["lip"][1] + 40)
    dome = bl((-31, 5.6, -11))
    keep_off = [(dome, 20.0), (bl((72.7, 3.2, -72.7)), 26.0), (bl((79.7, 22, -79.7)), 26.0), (bl((-5.4, 3.25, 62.2)), 24.0)]
    ends = [(-52, -6, True), (-30, -52, True), (30, 4, True), (62, -42, True), (-78, 32, False), (6, 42, True),
            (88, 16, False), (-28, 72, False)]
    rays = []
    rr = random.Random(31)
    for i, (x, y, phone) in enumerate(ends):
        foot = Vector((x, y, 9.0))                    # Roblox Y 13: above the lawn, the pets and the dome
        assert fp.inside(foot), ("ray off the island", x, y)
        for p, gap in keep_off:
            assert math.hypot(foot.x - p.x, foot.y - p.y) >= gap, ("ray too near", rb(p), x, y)
        top = foot + sun_b * ((208 - foot.z) / sun_b.z)
        w = rr.uniform(15, 24)                        # broad soft shafts (in game the 9..16 ones were lost on the walls)
        rays.append({"from": rb(top), "to": rb(foot), "w0": round(w * .5, 2), "w1": round(w, 2), "phone": phone})

    # a few slow soap bubbles: closed loops inside the opening, under the canopy
    bubbles = []
    for i, (rad, hgt, ph) in enumerate(((46, 22, 0.0), (70, 44, 1.3), (58, 66, 2.9), (84, 30, 4.4))):
        path = [rb(Vector((CX + rad * 1.1 * math.cos(ph + TAU * k / 8), CY + rad * .9 * math.sin(ph + TAU * k / 8),
                           hgt + 9 * math.sin(k * 1.7 + i)))) for k in range(8)]
        bubbles.append({"path": path, "closed": True, "radius": [2.2, 3.0, 1.8, 2.6][i], "seconds": [150, 190, 170, 210][i]})

    hides = sorted(p["name"] for p in json.loads((ROOT / "assets/world/world-v7-manifest.json").read_text())["parts"]
                   if p["name"].startswith(("W7_Backdrop", "W7_DriftRocks", "W7_Islets", "W7_CastleFlag", "W7_Water__cloud",
                                            "W7_Underside")))   # the plinth seals the cliff feet now (in-game critique 4)
    manifest = {
        "note": "Generated by scripts/build_world_grove.py. Roblox studs. The Hidden Grove ring round the unchanged island.",
        "version": 1,
        "assetId": "",
        "coordinateRule": "Roblox (X, Y, Z) = Blender (x, z + 4, -y); every position here is already Roblox. Yaw is about +Y.",
        "turnApplied": False,
        "importTurn": {"axis": "Y", "angle": round(math.pi, 6),
                       "static": "part.CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi, 0); part.Size = size",
                       "instance": "part.CFrame = CFrame.new(pivot) * CFrame.Angles(0, yaw, 0) * CFrame.new(pivotToCentre * scale) "
                                   "* CFrame.Angles(0, math.pi, 0); part.Size = size * scale",
                       "check": "compare a built part's LookVector with a live W7 part's (fbx-import-pi-turn) before trusting it"},
        "meshes": meshes,
        "instances": instances,
        "textures": textures,
        "rays": rays,
        "sun": {"clockTime": 10.5, "latitude": 41.7333, "dir": [round(sun.x, 5), round(sun.y, 5), round(sun.z, 5)],
                "verified": False, "note": "computed (sun leans to +Z by latitude - 23.5); compare with Lighting:GetSunDirection()"},
        "sunGate": {"az": round(math.degrees(math.atan2(sun.z, sun.x)), 2), "el": round(math.degrees(math.asin(sun.y)), 2),
                    "pos": rb(gate_pos), "from": round(math.degrees(GATE[0]), 1), "to": round(math.degrees(GATE[1]), 1),
                    "note": "az in degrees from +X toward +Z (Roblox), el above the horizon; no giant stands between `from` "
                            "and `to` (degrees from +X toward -Z, about the centre)"},
        "opening": opening,
        "canopyBottomY": round(canopy_bottom, 2),
        "moat": {"surfaceY": WATER_Z + 4, "bedOpaque": True, "bankTopY": BANK_TOP_Z + 4, "shoulderY": SHOULDER_Z + 4,
                 "cliffFootY": CLIFF_FOOT_Z + 4,
                 "note": "GV_Bank__stone is the plinth the island stands on: a cap inside the cliff shell at bankTopY (above "
                         "the cliff feet), a shoulder 1.5 studs past the island's edge at shoulderY (below them), then down "
                         "to the bed and out to the first wall's foot, under the water. W7_Underside is in hides"},
        "center": rb(Vector((CX, CY, 0))),
        "lanterns": lanterns,
        "falls": falls,
        "bubbles": bubbles,
        "hides": hides,
        "keeps": [],
        "counts": counts,
        "budget": BUDGET,
        "checks": {"islandIntrusions": 0, "midMinRimDist": MID_MIN, "canopyMinY": CANOPY_MIN_Y, "islandLowestY": round(fp.zmin + 4, 2),
                   "plinthCapMinCover": bank_cover},
        "totals": {"triangles": total, "meshes": len(meshes), "instances": len(instances), "groups": groups,
                   "uniqueTriangles": sum(m["tris"] for m in meshes.values())},
        "triangles": total,
    }
    if "--skip-export" not in ARGV:
        OUT.mkdir(parents=True, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in export:
            obj.select_set(True)
        bpy.ops.export_scene.fbx(filepath=str(OUT / "grove.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                                 global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                                 add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                                 colors_type="SRGB")
        (OUT / "grove-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("GROVE", len(meshes), "meshes,", len(instances), "instances,", groups, "groups,", total, "triangles; canopy bottom Y",
          round(canopy_bottom, 1), "opening", opening["radii"], "min", opening["minRadius"])
    for m in meshes.values():
        print("GROVE mesh %-28s %5d x%d  rim %7.1f  %s" % (m["name"], m["tris"], m.get("instances", 1), m["minRimDist"], m["size"]))
    print("GROVE counts", counts, "lanterns", len(lanterns), "falls", len(falls))
    if RENDERS:
        render(manifest, objs, island, fp)


# ----------------------------------------------------------------------------------------------------------- renders
def bsdf(m):
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


VOID_CHECK = "--void-check" in ARGV   # review only: any BACK of a single-sided mesh renders magenta (in game it is a hole)


def render_material(kind, texture, double=False):
    m = bpy.data.materials.new("GV_" + (texture or kind) + ("_2" if double else ""))
    m.use_nodes = True
    nt, b = m.node_tree, bsdf(m)
    L = nt.links.new
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    b.inputs["Roughness"].default_value = .92
    if texture:
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(str(TEX / ("grove-%s.png" % texture)))
        mul = nt.nodes.new("ShaderNodeMixRGB")
        mul.blend_type = "MULTIPLY"
        mul.inputs["Fac"].default_value = 1
        L(img.outputs["Color"], mul.inputs["Color1"])
        L(vc.outputs["Color"], mul.inputs["Color2"])
        L(mul.outputs["Color"], b.inputs["Base Color"])
    elif kind == "water":
        b.inputs["Base Color"].default_value = (.06, .52, .60, 1)
        b.inputs["Emission Color"].default_value = (.10, .78, .80, 1)
        b.inputs["Emission Strength"].default_value = .45
        b.inputs["Roughness"].default_value = .06
    else:
        L(vc.outputs["Color"], b.inputs["Base Color"])
        if kind in ("glow", "fall"):
            L(vc.outputs["Color"], b.inputs["Emission Color"])
            b.inputs["Emission Strength"].default_value = 2.5 if kind == "glow" else .8
    if VOID_CHECK and not double:
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = {"stone": (1, 0, 1, 1), "moss": (1, 0, 0, 1), "leaf": (1, .4, 0, 1),
                                            "bark": (1, 1, 0, 1)}.get(texture, (0, 0, 1, 1))
        em.inputs["Strength"].default_value = 8
        mx = nt.nodes.new("ShaderNodeMixShader")
        L(geo.outputs["Backfacing"], mx.inputs[0])
        L(b.outputs[0], mx.inputs[1])
        L(em.outputs[0], mx.inputs[2])
        L(mx.outputs[0], out.inputs["Surface"])
    return m


def render(manifest, objs, island, fp):
    sc = bpy.context.scene
    REVIEW.mkdir(parents=True, exist_ok=True)
    mats = {}
    for name, entry in manifest["meshes"].items():
        key = (entry["kind"], entry["texture"], entry["doubleSided"])
        if key not in mats:
            mats[key] = render_material(*key)
        objs[name].data.materials.append(mats[key])

    def mat_of(kind):
        return next(m for k, m in mats.items() if k[0] == kind)
    # the giants as the runtime will place them: straight from the manifest's instances
    for inst in manifest["instances"]:
        src = objs[inst["mesh"]]
        o = bpy.data.objects.new(inst["tree"] + "_" + inst["mesh"], src.data)
        o.matrix_world = Matrix.Translation(bl(inst["pivot"])) @ Matrix.Rotation(inst["yaw"], 4, "Z") @ Matrix.Scale(inst["scale"], 4)
        sc.collection.objects.link(o)
    for name, entry in manifest["meshes"].items():
        if "instances" in entry:
            objs[name].hide_render = True
    # the island's bare rock wears the grove's stone
    stone = bpy.data.materials.new("GV_island_stone")
    stone.use_nodes = True
    nt = stone.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / 32, 1 / 32, 1 / 32)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(str(TEX / "grove-stone.png"))
    img.projection = "BOX"
    img.projection_blend = .2
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], img.inputs["Vector"])
    nt.links.new(img.outputs["Color"], bsdf(stone).inputs["Base Color"])
    bsdf(stone).inputs["Roughness"].default_value = .9
    for o in bpy.data.objects:
        if o.type == "MESH":
            for sl in o.material_slots:
                if sl.material and sl.material.name.startswith("W1_ground"):
                    sl.material = stone
    sun_v = Vector(manifest["sun"]["dir"])
    sun_b = Vector((sun_v.x, -sun_v.z, sun_v.y))
    # sky, sun, haze
    w = bpy.data.worlds.new("GroveSky")
    w.use_nodes = True
    sc.world = w
    wt = w.node_tree
    bg = wt.nodes["Background"]
    tc = wt.nodes.new("ShaderNodeTexCoord")
    sep = wt.nodes.new("ShaderNodeSeparateXYZ")
    wt.links.new(tc.outputs["Generated"], sep.inputs[0])
    sky = wt.nodes.new("ShaderNodeValToRGB")
    while len(sky.color_ramp.elements) < 3:
        sky.color_ramp.elements.new(.5)
    wt.links.new(sep.outputs["Z"], sky.inputs["Fac"])
    wt.links.new(sky.outputs["Color"], bg.inputs[0])
    sun = bpy.data.lights.new("Sun", "SUN")
    so = bpy.data.objects.new("Sun", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = sun_b.to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(CX, CY, 150))
    hz = bpy.context.object
    hz.scale = (1500, 1500, 460)
    hm = bpy.data.materials.new("GroveHaze")
    hm.use_nodes = True
    for n in list(hm.node_tree.nodes):
        if n.type != "OUTPUT_MATERIAL":
            hm.node_tree.nodes.remove(n)
    vs = hm.node_tree.nodes.new("ShaderNodeVolumeScatter")
    vs.inputs["Anisotropy"].default_value = .55
    hm.node_tree.links.new(vs.outputs[0], next(n for n in hm.node_tree.nodes if n.type == "OUTPUT_MATERIAL").inputs["Volume"])
    hz.data.materials.append(hm)
    hz.visible_shadow = False
    # the ray cards, as Beams would draw them (from the manifest)
    rm = bpy.data.materials.new("GroveRay")
    rm.use_nodes = True
    rt = rm.node_tree
    for n in list(rt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            rt.nodes.remove(n)
    em = rt.nodes.new("ShaderNodeEmission")
    tr = rt.nodes.new("ShaderNodeBsdfTransparent")
    lw = rt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = .5
    inv = rt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1
    rt.links.new(lw.outputs["Facing"], inv.inputs[1])
    uv = rt.nodes.new("ShaderNodeTexCoord")
    sp = rt.nodes.new("ShaderNodeSeparateXYZ")
    rt.links.new(uv.outputs["UV"], sp.inputs[0])
    fade = rt.nodes.new("ShaderNodeValToRGB")
    e = fade.color_ramp.elements
    e[0].position, e[0].color = 0, (0, 0, 0, 1)
    e[1].position, e[1].color = .2, (1, 1, 1, 1)
    last = e.new(1)
    last.color = (0, 0, 0, 1)
    e.new(.75).color = (.8, .8, .8, 1)
    rt.links.new(sp.outputs["Y"], fade.inputs["Fac"])
    m1 = rt.nodes.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    rt.links.new(inv.outputs[0], m1.inputs[0])
    rt.links.new(fade.outputs["Color"], m1.inputs[1])
    m2 = rt.nodes.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    m2.inputs[1].default_value = .10          # lighter than the mockup: "drawn heavier than they should ship"
    rt.links.new(m1.outputs[0], m2.inputs[0])
    ms = rt.nodes.new("ShaderNodeMixShader")
    rt.links.new(m2.outputs[0], ms.inputs[0])
    rt.links.new(tr.outputs[0], ms.inputs[1])
    rt.links.new(em.outputs[0], ms.inputs[2])
    rt.links.new(ms.outputs[0], next(n for n in rt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
    for ray in manifest["rays"]:
        a, b_ = bl(ray["to"]), bl(ray["from"])
        axis = (b_ - a).normalized()
        ref = axis.cross(UP).normalized()
        wv = axis.cross(ref)
        segs, verts, faces = 12, [], []
        for p, r in ((a, ray["w1"] / 2), (b_, ray["w0"] / 2)):
            for q in range(segs):
                an = TAU * q / segs
                verts.append(tuple(p + (ref * math.cos(an) + wv * math.sin(an)) * r))
        for q in range(segs):
            faces.append((q, (q + 1) % segs, segs + (q + 1) % segs, segs + q))
        me = bpy.data.meshes.new("Ray")
        me.from_pydata(verts, [], faces)
        uvl = me.uv_layers.new()
        for poly in me.polygons:
            poly.use_smooth = True
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                uvl.data[li].uv = ((vi % segs) / segs, 0 if vi < segs else 1)
        o = bpy.data.objects.new("GroveRay", me)
        o.data.materials.append(rm)
        sc.collection.objects.link(o)
        o.visible_shadow = False
    # clouds, as the mockup's
    cm = bpy.data.materials.new("AeroCloud")
    cm.use_nodes = True
    bsdf(cm).inputs["Roughness"].default_value = 1
    cloud = MB("ReviewClouds", "review", "review", "", 0, smooth=True)
    cr = random.Random(5)
    for _ in range(26):
        p = Vector((cr.uniform(-900, 900), cr.uniform(-900, 900), cr.uniform(420, 560)))
        for k in range(5):
            blob(cloud, p + Vector((cr.uniform(-70, 70), cr.uniform(-70, 70), cr.uniform(-8, 12))), cr.uniform(40, 80), .4, SPH_CROWN, .2, .01)
    cloud.build().data.materials.append(cm)

    night_lights = []

    def set_time(night):
        stops = ([(.0, (.10, .22, .42)), (.25, (.07, .13, .36)), (1, (.03, .05, .20))] if night else
                 [(.0, (.80, .95, 1.0)), (.18, (.50, .82, 1.0)), (1, (.12, .50, .98))])
        for el, (p, c) in zip(sky.color_ramp.elements, stops):
            el.position, el.color = p, (*c, 1)
        bg.inputs[1].default_value = .7 if night else 1.7
        sun.energy, sun.color, sun.angle = (.9, (.45, .72, 1.0), math.radians(3)) if night else (5.2, (1, .97, .88), math.radians(2.5))
        vs.inputs["Color"].default_value = (.6, .85, 1, 1) if night else (.85, .97, 1, 1)
        vs.inputs["Density"].default_value = .0005 if night else .0012
        em.inputs["Color"].default_value = (.62, .9, 1, 1) if night else (1, .97, .82, 1)
        em.inputs["Strength"].default_value = .22 if night else 1.5
        bsdf(mat_of("glow")).inputs["Emission Strength"].default_value = 14 if night else 2.5
        bsdf(mat_of("fall")).inputs["Emission Strength"].default_value = 2.0 if night else .8
        bsdf(mat_of("water")).inputs["Emission Strength"].default_value = 1.5 if night else .45
        bsdf(cm).inputs["Emission Strength"].default_value = .03 if night else .08
        for m in bpy.data.materials:
            if m.name.startswith("W1_glow"):
                bsdf(m).inputs["Emission Strength"].default_value = 14 if night else 2.0
        if night and not night_lights:
            spots = [(bl(l["pos"]), (1, .72, .35) if l["kind"] == "warm" else (.35, .9, 1), 1.0) for l in manifest["lanterns"][::2]]
            spots += [(Vector((x, y, 5.6)), (1, .8, .5), 1.0) for x, y in
                      ((69.65, -51.97), (29.44, -29.85), (-9, -28), (-12, 44), (-70, 3), (50, 10), (-22, -38))]
            for p, c, s_ in spots:
                l = bpy.data.lights.new("L", "POINT")
                l.energy, l.color, l.shadow_soft_size = 9000 * s_, c, 1.5
                o = bpy.data.objects.new("L", l)
                o.location = p
                sc.collection.objects.link(o)
                night_lights.append(o)
        for o in night_lights:
            o.hide_render = not night
        sc.view_settings.exposure = -.1 if night else -.15

    sc.render.engine = "CYCLES"
    cy = sc.cycles
    cy.samples, cy.use_denoising, cy.volume_bounces, cy.max_bounces, cy.volume_step_rate = SAMPLES, True, 0, 5, 4
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for t in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = t
                break
            except TypeError:
                pass
        prefs.get_devices()
        for dv in prefs.devices:
            dv.use = dv.type != "CPU"
        cy.device = "GPU"
    except Exception as problem:  # noqa: BLE001
        print("GPU setup failed", problem)
    sc.render.resolution_x, sc.render.resolution_y = RES, int(RES * 9 / 16)
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    # the mockup's cameras (eye, target, vertical fov), Blender studs
    def pol(deg, r, z):
        return (CX + r * math.cos(math.radians(deg)), CY + r * math.sin(math.radians(deg)), z)
    table = {
        # the island's foot (in-game critique 4): low over the moat, steep from above, and across a cove from the lawn
        "skirt": (pol(205, 168, -16), pol(205, 120, -8), 60),
        "skirtb": (pol(60, 186, 30), pol(60, 150, -9), 55),
        "cove": (pol(236, 104, 8), pol(262, 76, -7), 70),
        "garden": ((-12, -30, 10.5), (-52, 60, 19), 70),
        "garden2": ((40, -52, 9.0), (110, 40, 42), 70),
        "wide": ((99, -155, 122), (0, 25, 12), 62),   # the mockup's (62, -158, 122) now stands inside giant 9: moved along the rim
        "within": ((112, -92, 52), (-30, 30, 24), 68),
        "up": ((-20, -10, 6), (5, 30, 160), 85),
        "dusk": ((18, -44, 10.5), (-34, 60, 26), 70),
    }
    skin, shirt, legs, pet = ((.98, .8, .62), (.25, .7, .95), (.95, .95, 1), (1, .82, .55))

    def flat(name, c):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf(m).inputs["Base Color"].default_value = (*c, 1)
        bsdf(m).inputs["Roughness"].default_value = .6
        return m

    stand_ins = []

    def avatar(p, yaw):
        ms_ = [flat("AvLegs", legs), flat("AvShirt", shirt), flat("AvSkin", skin), flat("AvPet", pet)]
        before = set(bpy.data.objects)

        def box(c, s_, m):
            bpy.ops.mesh.primitive_cube_add(size=1, location=p + Vector(c))
            o = bpy.context.object
            o.scale, o.rotation_euler = s_, (0, 0, yaw)
            o.data.materials.append(m)
        box((0, 0, 1), (1.9, .95, 2), ms_[0])
        box((0, 0, 3), (1.9, .95, 2), ms_[1])
        box((0, 0, 4.6), (1.25, 1.25, 1.25), ms_[2])
        for sx in (-1.45, 1.45):
            box((sx * math.cos(yaw), sx * math.sin(yaw), 3), (.95, .95, 2), ms_[2])
        pp = p + Vector((2.8 * math.cos(yaw) - 1.5 * math.sin(yaw), 2.8 * math.sin(yaw) + 1.5 * math.cos(yaw), .75))
        for c, r in (((0, 0, 0), .8), ((0, 0, .85), .62), ((-.42, 0, 1.4), .22), ((.42, 0, 1.4), .22)):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=pp + Vector(c))
            bpy.ops.object.shade_smooth()
            bpy.context.object.data.materials.append(ms_[3])
        stand_ins.extend(set(bpy.data.objects) - before)
    for name in RENDERS:
        eye, tgt, fov = table[name]
        eye, tgt = Vector(eye), Vector(tgt)
        cam = bpy.data.cameras.new(name)
        co = bpy.data.objects.new(name, cam)
        sc.collection.objects.link(co)
        cam.sensor_fit, cam.clip_start, cam.clip_end = "VERTICAL", .3, 6000
        cam.angle_y = math.radians(fov)
        co.location = eye
        co.rotation_euler = (tgt - eye).to_track_quat("-Z", "Y").to_euler()
        sc.camera = co
        for o in stand_ins:
            o.hide_render = True
        if name in ("garden", "garden2", "dusk"):
            f = tgt - eye
            f.z = 0
            f.normalize()
            p = eye + f * 19
            p.z = .1
            avatar(p, math.atan2(f.y, f.x) - math.pi / 2)
        set_time(name == "dusk")
        sc.render.filepath = str(REVIEW / ("build-%s.png" % name))
        bpy.ops.render.render(write_still=True)
        print("GROVE render", sc.render.filepath)


if __name__ == "__main__":
    main()
