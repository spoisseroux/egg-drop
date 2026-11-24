"""The Sleepy Nest landmark (NEST-LANDMARK-LOOK, Fable 2026-11-24): a cream stoneware bowl on three green feet with the
egg machine's leaf collar and a painted band of moons, a fat plaited twig nest, a straw bed with an egg dent, a bent
crook with a three-leaf awning and a paper moon lantern, a teal quilt (draped and folded), a coiled straw mat for the
Bear. Original design: every shape is built here from code (lathes, swept tubes, curves), hand-tuned. No AI mesh, no
samples.

Run in BACKGROUND Blender from an empty scene:
  blender.exe -b --factory-startup --python scripts/build_nest_landmark.py -- [--render]

Nest-local Roblox axes, as NestClient: x = the root's +X (the plaza's west), y up, **front -Z**; origin on the ground at
the bowl's centre. Blender (x, y, z) = Roblox (x, -z, y). FBX: forward -Z, up Y (as the egg machine), so Roblox imports
each mesh turned by pi about Y; the manifest records each part's bounds centre and size nest-local, and the pivots the
code side moves parts about.

Parts (one FBX, one Model upload): Body (feet, bowl, collar, plaited nest, twig ends, straw bed, crook, sign loops, pet
mat), Awning (three leaves; pivot the crook's apex), Moon (crescent and cord; pivot the crook's tip), BlanketDraped
(pivot its lower front edge), BlanketFolded (pivot its centre). Every face is wound to its own outward direction (no
recalculation: Roblox culls back faces; the egg machine's dial lesson).

Writes assets/world/nest-landmark/nest-landmark.fbx and nest-landmark-manifest.json; with --render, renders to
artifacts/qa-2026-11-24-beta16/nest-landmark/ (front, three-quarter, path mouth x empty / tucked / ready; beside the
machine).
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
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "nest-landmark"
RENDERS = ROOT / "artifacts" / "qa-2026-11-24-beta16" / "nest-landmark"
TEXTURE = OUT / "nest-landmark.png"
MACHINE = ROOT / "assets" / "world" / "egg-machine"
ATLAS = 512.0
REGION = {  # x0, y0, x1, y1 in atlas pixels (image y down): scripts/draw_nest_landmark_texture.py
    "bowl": (0, 0, 512, 128), "twig": (0, 128, 256, 224), "twigend": (0, 224, 256, 256),
    "leaf": (256, 128, 512, 192), "awning": (256, 192, 512, 256), "straw": (0, 256, 128, 384),
    "crook": (128, 256, 256, 320), "green": (128, 320, 192, 384), "cord": (192, 320, 224, 352),
    "sun": (224, 320, 256, 352), "paper": (192, 352, 256, 384), "moon": (256, 256, 384, 384),
    "collar": (384, 256, 512, 384), "quilt": (0, 384, 256, 512), "mat": (256, 384, 384, 512),
}
TRI_CAP = 5000              # the whole landmark: these meshes + the code egg (cap 320) + code parts (about 60)
CODE_EGG_CAP, CODE_PARTS = 320, 60
EGG_BASE, EGG_W, EGG_H = 2.15, 1.6, 2.1
MOON_R, MOON_BITE_C, MOON_BITE_R = .5, (.325, .075), .45     # the painter's crescent (bite toward +u); Fable R1 4
MOON_UV = 1.2                                                    # studs across the MOON region (128 px)
MOON_CENTRE, CROOK_TIP = Vector((2.0, 4.25, -.5)), Vector((2.0, 5.1, -.5))
CROOK_APEX = Vector((1.2, 6.45, .9))
SIGN = {"centre": [0.0, 1.15, -2.45], "size": [1.7, .85, .1], "tiltBack": 10}
MAT = {"centre": [-2.9, 0.0, -2.0], "radius": 1.1}
FOLDED_CENTRE = Vector((-1.5, 2.9, -1.1))
AWNING_YAWS = (20.0, 75.0, 130.0)   # degrees from +Z toward -X (Fable R2 2)
AWNING_DROP = (0.0, .2, .4)          # attach heights staggered .2 (Fable R2 2)
AWNING_ATTACH = Vector((-.05, -.5, .22))   # below and behind the apex (Fable R1 1)
COLLIDER_R, COLLIDER_H = 2.4, 2.75
VERSION = 1   # NestLandmarkData.version and the template's LandmarkVersion value: a stale template falls back


def r4(v):
    return [round(float(x), 4) for x in v]


def awning_axis():
    """Horizontal, across the leaves' mean direction, signed so a positive (right-handed) turn raises their tips."""
    mean = sum((Vector((-math.sin(math.radians(a)), -.27, math.cos(math.radians(a)))) for a in AWNING_YAWS), Vector())
    axis = Vector((mean.z, 0, -mean.x)).normalized()
    if axis.cross(mean).y < 0:
        axis = -axis
    return axis


def folded_long():
    yaw = math.atan2(FOLDED_CENTRE.x, FOLDED_CENTRE.z)
    return Matrix.Rotation(yaw, 3, "Y") @ Vector((1, 0, 0))


def region_uv(name, u, v):
    """u, v in 0..1 inside a region (v = 0 at the region's top row) to Blender UV (v up)."""
    x0, y0, x1, y1 = REGION[name]
    u = min(max(u, .002), .998)
    v = min(max(v, .002), .998)
    return ((x0 + (x1 - x0) * u) / ATLAS, 1 - (y0 + (y1 - y0) * v) / ATLAS)


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def V(*a):
    return Vector(a)


class Mesh:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.tris = 0

    def face(self, pts, uvs, out, smooth=True):
        """pts nest-local; wound so its normal faces `out` (a nest-local direction)."""
        p0, p1, p2 = (Vector(q) for q in pts[:3])
        n = (p1 - p0).cross(p2 - p0)
        if n.length < 1e-12:
            p3 = Vector(pts[3]) if len(pts) > 3 else p2
            n = (p2 - p0).cross(p3 - p0)
        if n.dot(Vector(out)) < 0:
            pts, uvs = pts[::-1], uvs[::-1]
        vs = [self.bm.verts.new(bl(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.smooth = smooth
        for i, loop in enumerate(f.loops):
            loop[self.uv].uv = uvs[i]
        self.tris += len(pts) - 2

    def build(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def wrap_u(i, segs, repeats):
    """u for column i of segs when the texture repeats `repeats` times round: the seam column gets 1.0, not 0."""
    u = (i * repeats / segs) % 1.0
    return 1.0 if (u == 0.0 and i > 0) else u


def lathe(m, profile, segs, uvfn, centre=(0, 0, 0), sx=1.0, sz=1.0, flip=False, radius_fn=None):
    """Revolve [(r, y)] about the vertical axis through `centre`. Each face's outward normal is (dy, -dr) in the
    profile plane (the profile runs bottom-centre, out, up, over and down the inside), or the reverse with `flip`.
    uvfn(i, j) -> (u, v) region uv for column i, profile row j."""
    cx, cy, cz = centre
    pts = []
    for j, (r, y) in enumerate(profile):
        row = []
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            rr = r * (radius_fn(a) if radius_fn else 1.0)
            row.append(V(cx + rr * math.sin(a) * sx, cy + y, cz + rr * math.cos(a) * sz))
        pts.append(row)
    for j in range(len(profile) - 1):
        (r0, y0), (r1, y1) = profile[j], profile[j + 1]
        dr, dy = r1 - r0, y1 - y0
        for i in range(segs):
            a = 2 * math.pi * (i + .5) / segs
            radial = V(math.sin(a) * sx, 0, math.cos(a) * sz).normalized()
            out = radial * dy + V(0, -dr, 0)
            if flip:
                out = -out
            q = [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
            uv = [uvfn(i, j), uvfn(i + 1, j), uvfn(i + 1, j + 1), uvfn(i, j + 1)]
            if r0 == 0:
                m.face([q[0], q[2], q[3]], [uv[0], uv[2], uv[3]], out)
            elif r1 == 0:
                m.face(q[:3], uv[:3], out)
            else:
                m.face(q, uv, out)


def tube(m, spine, radii, sides, uvfn, cap_end=True, cap_start=False):
    """A swept tube along spine points (radius per point; 0 closes to a tip). uvfn(k, s) -> region uv for spine
    point k, side s. Faces wound away from the spine."""
    frames = []
    up_hint = V(0, 1, 0)
    for k, p in enumerate(spine):
        d = (spine[min(k + 1, len(spine) - 1)] - spine[max(k - 1, 0)]).normalized()
        a = d.cross(up_hint)
        if a.length < 1e-4:
            a = d.cross(V(1, 0, 0))
        a.normalize()
        b = d.cross(a).normalized()
        frames.append((a, b))
    rings = []
    for k, p in enumerate(spine):
        a, b = frames[k]
        rings.append([p + (a * math.cos(2 * math.pi * s / sides) + b * math.sin(2 * math.pi * s / sides)) * radii[k]
                      for s in range(sides + 1)])
    for k in range(len(spine) - 1):
        for s in range(sides):
            mid = (rings[k][s] + rings[k][s + 1] + rings[k + 1][s] + rings[k + 1][s + 1]) / 4
            axis = (spine[k] + spine[k + 1]) / 2
            out = mid - axis
            uv = [uvfn(k, s), uvfn(k, s + 1), uvfn(k + 1, s + 1), uvfn(k + 1, s)]
            q = [rings[k][s], rings[k][s + 1], rings[k + 1][s + 1], rings[k + 1][s]]
            if radii[k + 1] == 0:
                m.face([q[0], q[1], q[2]], uv[:3], out)
            elif radii[k] == 0:
                m.face([q[0], q[2], q[3]], [uv[0], uv[2], uv[3]], out)
            else:
                m.face(q, uv, out)
    for k, want in ((len(spine) - 1, cap_end), (0, cap_start)):
        if want and radii[k] > 0:
            d = spine[k] - spine[k - 1 if k else 1]
            ring = rings[k][:sides]
            m.face(ring, [uvfn(k, s) for s in range(sides)], d)
    return rings


def catmull(points, per):
    """A Catmull-Rom spline through `points`, `per` samples per span."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(per):
            t = k / per
            out.append(.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                             + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(points[-1])
    return out


# ------------------------------------------------------------------------------------------------------------- body
BOWL = [(0.0, .35), (1.6, .36), (1.92, .55), (2.2, .95), (2.35, 1.35), (2.4, 1.62), (2.4, 1.75), (2.3, 1.8),
        (2.2, 1.75), (2.05, 1.5)]
FEET = ((-1.169, -.675), (1.169, -.675), (0.0, 1.35))   # two front (-Z), one back, at radius 1.35 (Fable R1 8)
NEST_R, NEST_Y, NEST_TUBE = 1.8, 2.25, .5


def bowl_uv(i, j):
    r, y = BOWL[j]
    return region_uv("bowl", wrap_u(i, 24, 2), (1.75 - y) / 1.4)


def build_collar(m, segs=36):
    """The machine's 8 lobes, bigger and drooping over the rim: inner foot against the nest, out over the rim, the tip
    down to 1.55 and curled out .2 (5.0 across at the tips)."""
    def lobe(a):
        return abs(math.cos(4 * a)) ** .7
    rows = []
    for i in range(segs + 1):
        a = 2 * math.pi * i / segs + math.pi / 8
        f = lobe(a)
        ring = [(2.1, 2.08), (2.43, 2.05), (2.45 + .03 * f, 1.88 - .06 * f), (2.45 + .04 * f, 1.66 + .2 * (1 - f)),
                (2.45 + .05 * f, 1.55 + .3 * (1 - f))]
        rows.append([V(r * math.sin(a), y, r * math.cos(a)) for r, y in ring])
    for i in range(segs):
        a = 2 * math.pi * (i + .5) / segs + math.pi / 8
        radial = V(math.sin(a), 0, math.cos(a))
        u0, u1 = (i * 8 / segs) % 1.0, ((i + 1) * 8 / segs) % 1.0 or 1.0
        for j in range(4):
            q = [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
            dr = (rows[i][j + 1] - rows[i][j])
            out = radial * (-dr.y) + V(0, dr.dot(radial), 0) * 1.0      # the upper (outer) side of the sheet
            if out.length < 1e-6:
                out = V(0, 1, 0)
            uv = [region_uv("collar", u0, .25 * j), region_uv("collar", u1, .25 * j),
                  region_uv("collar", u1, .25 * (j + 1)), region_uv("collar", u0, .25 * (j + 1))]
            m.face(q, uv, out)
            if j >= 2:                                                 # the drooping lobes show their undersides
                back = [p - out.normalized() * .025 for p in q]
                m.face(back, [region_uv("leaf", .5, .8)] * 4, -out)


def nest_point(phi, wob):
    r = NEST_R + .06 * math.sin(3 * phi + .7) + .04 * math.sin(5 * phi)      # lopsided
    y = NEST_Y + .05 * math.sin(2 * phi + 1.9) * wob
    return r, y


def build_nest(m, rnd):
    """Three plies twisted round the ring (a fat 3-ply rope reads as plaited); 5 twists round."""
    segs, sides, twists, e, rad = 36, 5, 5, .2, .31
    for ply in range(3):
        spine, radii = [], []
        for k in range(segs + 1):
            phi = 2 * math.pi * k / segs
            r, y = nest_point(phi, 1.0)
            psi = 2 * math.pi * ply / 3 + twists * phi
            radial = V(math.sin(phi), 0, math.cos(phi))
            spine.append(V(0, y, 0) + radial * (r + e * math.cos(psi) * 1.1) + V(0, e * math.sin(psi) * .95, 0))
            radii.append(rad)
        tube(m, spine, radii, sides,
             lambda k, s: region_uv("twig", wrap_u(k, segs, twists * 2), s / sides), cap_end=False)
    # Twig ends: about 24 thin sticks out of the ring's outside, never across the front (the blanket spills there),
    # tips within 2.6 of the centre.
    count, tries = 0, 0
    while count < 24 and tries < 400:
        tries += 1
        phi = rnd.uniform(0, 2 * math.pi)
        front = abs(((phi - math.pi) + math.pi) % (2 * math.pi) - math.pi)    # 0 at the front (-Z)
        if front < math.radians(40):
            continue
        r, y = nest_point(phi, 1.0)
        radial = V(math.sin(phi), 0, math.cos(phi))
        tangent = V(math.cos(phi), 0, -math.sin(phi))
        h = rnd.uniform(-.3, .35)
        start = V(0, y + h, 0) + radial * (r + .3)
        d = radial * rnd.uniform(.5, 1.0) + tangent * rnd.uniform(-.7, .7) + V(0, rnd.uniform(-.15, .6), 0)
        d.normalize()
        length = rnd.uniform(.25, .6)
        tip = start + d * length
        if math.hypot(tip.x, tip.z) > 2.52 or tip.y > 3.05:
            continue
        mid = start + d * length * .5 + V(0, .03, 0)
        tube(m, [start - d * .2, mid, tip], [.06, .05, .035], 4,
             lambda k, s: region_uv("twigend", .97 if k == 2 else k * .4, s / 4), cap_end=True)
        count += 1
    assert count == 24, ("twig ends", count)


def build_bed(m):
    """Straw disc in the ring's opening: 2.3 at the twigs, 2.2 across most of it, an egg-shaped dent to 2.1."""
    rings, segs = [0, .25, .5, .75, 1.0, 1.15, 1.35], 16
    def height(x, z):
        r = math.hypot(x, z)
        h = 2.2 + .1 * max(0.0, (r - 1.0) / .35) ** 2
        dent = max(0.0, 1 - (x / .78) ** 2 - (z / .66) ** 2)
        return h - .1 * dent ** .6 - .02 * (1 - min(1, r / 1.0))
    pts = []
    for r in rings:
        row = []
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            x, z = r * math.sin(a), r * math.cos(a)
            row.append(V(x, height(x, z), z))
        pts.append(row)
    uv = lambda p: region_uv("straw", .5 + p.x / 2.8, .5 + p.z / 2.8)
    for j in range(len(rings) - 1):
        for i in range(segs):
            q = [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
            if rings[j] == 0:
                m.face([q[0], q[2], q[3]], [uv(q[0]), uv(q[2]), uv(q[3])], V(0, 1, 0))
            else:
                m.face(q, [uv(p) for p in q], V(0, 1, 0))


def build_crook(m):
    pts = [V(1.5, 1.75, 1.9), V(1.66, 3.0, 2.08), V(1.85, 4.0, 2.25), V(1.72, 5.1, 1.98), V(1.4, 6.05, 1.5), CROOK_APEX,
           V(1.42, 6.36, .3), V(1.8, 5.86, -.32), CROOK_TIP]
    spine = catmull(pts, 3)
    n = len(spine)
    radii = [.225 - (.225 - .1) * k / (n - 1) for k in range(n)]                # Fable R1 1: a visible linear taper
    tube(m, spine, radii, 6, lambda k, s: region_uv("crook", k / (n - 1), s / 6), cap_end=True, cap_start=False)
    # two small leaf buds on the outside of the bend
    for k, side in ((int(n * .45), 1), (int(n * .72), -1)):
        p = spine[k]
        d = (spine[k + 1] - spine[k - 1]).normalized()
        out = d.cross(V(0, 0, 1) * side).normalized()
        base = p + out * radii[k] * .9
        tip = base + (out * .9 + d * .5).normalized() * .32
        tube(m, [base, base + (tip - base) * .5, tip], [.06, .07, 0.0], 4,
             lambda k2, s: region_uv("leaf", .3 + k2 * .2, .2 + s * .05), cap_end=False)
    return spine


def build_loops(m):
    """Two rope loops from the bowl's rim to the sign board's top corners (the board itself is a code Part)."""
    c = Vector(SIGN["centre"])
    tilt = math.radians(SIGN["tiltBack"])
    board_top = c + V(0, math.cos(tilt) * SIGN["size"][1] / 2, math.sin(tilt) * SIGN["size"][1] / 2)
    for x in (-.55, .55):
        a = V(x, 1.78, -2.33)                           # over the rim's lip
        b = V(x, board_top.y - .04, board_top.z - .04)
        loop = [a + V(0, .05, .12), a + V(0, .1, -.06), (a + b) / 2 + V(0, 0, -.16), b + V(0, -.05, -.05),
                b + V(0, .02, .08), (a + b) / 2 + V(0, 0, .02), a + V(0, .05, .12)]
        spine = catmull(loop, 1)
        tube(m, spine, [.035] * len(spine), 3, lambda k, s: region_uv("cord", .5, s / 3), cap_end=False)


def build_mat(m):
    prof = [(0.0, .06), (1.0, .06), (1.07, .05), (1.1, .02), (1.1, 0.0)]
    cx, _, cz = MAT["centre"]
    lathe(m, prof, 20, lambda i, j: region_uv("mat", wrap_u(i, 20, 1), prof[j][0] / 1.1 * .98 + .01),
          centre=(cx, 0, cz), flip=True)


def build_body(rnd):
    m = Mesh("Body")
    lathe(m, BOWL, 24, bowl_uv)
    foot = [(0.0, 0.0), (.48, .01), (.5, .14), (.4, .29), (.2, .36), (0.0, .36)]
    for fx, fz in FEET:
        lathe(m, foot, 8, lambda i, j: region_uv("green", wrap_u(i, 8, 1), j / 5), centre=(fx, 0, fz))
    build_collar(m)
    build_nest(m, rnd)
    build_bed(m)
    crook = build_crook(m)
    build_loops(m)
    build_mat(m)
    return m, crook


# ----------------------------------------------------------------------------------------------------------- awning
def build_awning():
    """Fable R1 1: three broad leaves with rounded tips (2.2 long, .95 wide, the machine sprout's shape), attached .5
    below the apex on its back side, 35 degrees apart, drooping 15 degrees, over the back half only (the arch and droop
    keep each chord inside z .3 .. 2.5)."""
    m = Mesh("Awning")
    lengths = []
    for yaw, drop in zip(AWNING_YAWS, AWNING_DROP):
        attach = CROOK_APEX + AWNING_ATTACH - V(0, drop, 0)
        a = math.radians(yaw)
        flat = V(-math.sin(a), 0, math.cos(a))                 # yaw from +Z toward -X
        d = (flat * math.cos(math.radians(15)) + V(0, -math.sin(math.radians(15)), 0)).normalized()
        across = d.cross(V(0, 1, 0)).normalized()
        up = across.cross(d).normalized()
        if up.y < 0:
            up = -up
        n = 9
        per = .92 * math.cos(math.radians(15)) * math.cos(a)        # tip z per stud of leaf
        length = 2.2
        if per > 0:
            length = min(length, (2.5 - attach.z) / per)
        elif per < 0:
            length = min(length, (attach.z - .3) / -per)
        lengths.append(round(length, 3))
        top_rows, bot_rows = [], []
        for k in range(n + 1):
            t = k / n
            c = attach + d * (length * .92 * t) + up * (.28 * math.sin(math.pi * t)) - V(0, .18 * t * t, 0)
            w = .475 * math.sin(math.pi * min(1.0, t)) ** .5          # rounded at the tip, a short stalk at the base
            fold = .06 * w / .475
            row = [c + across * (-w) - up * fold, c, c + across * w - up * fold]
            top_rows.append(row)
            bot_rows.append([q - up * .02 for q in row])
        for k in range(n):
            for sd in range(2):
                q = [top_rows[k][sd], top_rows[k][sd + 1], top_rows[k + 1][sd + 1], top_rows[k + 1][sd]]
                uv = [region_uv("awning", k / n, .05 + .2 * sd), region_uv("awning", k / n, .05 + .2 * (sd + 1)),
                      region_uv("awning", (k + 1) / n, .05 + .2 * (sd + 1)), region_uv("awning", (k + 1) / n, .05 + .2 * sd)]
                m.face(q, uv, up)
                qb = [bot_rows[k][sd], bot_rows[k][sd + 1], bot_rows[k + 1][sd + 1], bot_rows[k + 1][sd]]
                m.face(qb, [region_uv("awning", .5, .8)] * 4, -up)
        tube(m, [attach + V(.06, .05, -.08), attach + d * .12], [.05, .04], 4, lambda k, s2: region_uv("crook", .9, .5),
             cap_end=False)
    print("AWNING leaf lengths", lengths)
    return m


# ------------------------------------------------------------------------------------------------------------- moon
def crescent_outline(n_outer=26, n_inner=20):
    """Nest-local x-y outline of the crescent (bite toward -X: the moon cradles toward the egg), centred on 0."""
    bx, by = -MOON_BITE_C[0], MOON_BITE_C[1]
    # intersections of the two circles
    d = math.hypot(bx, by)
    a = (MOON_R ** 2 - MOON_BITE_R ** 2 + d * d) / (2 * d)
    h = math.sqrt(MOON_R ** 2 - a * a)
    mx, my = a * bx / d, a * by / d
    p1 = (mx + h * by / d, my - h * bx / d)
    p2 = (mx - h * by / d, my + h * bx / d)
    a1, a2 = math.atan2(p1[1], p1[0]), math.atan2(p2[1], p2[0])
    # the outer arc that is outside the bite: from p1 to p2 the long way, away from the bite
    if (a2 - a1) % (2 * math.pi) < math.pi:
        a1, a2 = a2, a1
    span = (a2 - a1) % (2 * math.pi)
    outer = [(MOON_R * math.cos(a1 + span * k / n_outer), MOON_R * math.sin(a1 + span * k / n_outer)) for k in range(n_outer + 1)]
    end, startp = outer[-1], outer[0]
    b1 = math.atan2(end[1] - by, end[0] - bx)
    b2 = math.atan2(startp[1] - by, startp[0] - bx)
    span_b = (b2 - b1) % (2 * math.pi)
    if span_b > math.pi:
        span_b -= 2 * math.pi
    inner = [(bx + MOON_BITE_R * math.cos(b1 + span_b * k / n_inner), by + MOON_BITE_R * math.sin(b1 + span_b * k / n_inner))
             for k in range(1, n_inner)]
    return outer + inner


def build_moon():
    m = Mesh("Moon")
    outline = crescent_outline()
    half = .09
    c = MOON_CENTRE
    def uv(x, y):                       # planar: the painter's crescent has its bite to +u; the mesh's is to -X
        return region_uv("moon", .5 - x / MOON_UV, .5 - y / MOON_UV)
    front = [c + V(x, y, -half) for x, y in outline]
    back = [c + V(x, y, half) for x, y in outline]
    m.face(front, [uv(x, y) for x, y in outline], V(0, 0, -1), smooth=False)
    m.face(back, [uv(x, y) for x, y in outline], V(0, 0, 1), smooth=False)
    n = len(outline)
    for k in range(n):
        a, b = outline[k], outline[(k + 1) % n]
        q = [c + V(a[0], a[1], -half), c + V(b[0], b[1], -half), c + V(b[0], b[1], half), c + V(a[0], a[1], half)]
        mid = V((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0)
        edge = V(b[0] - a[0], b[1] - a[1], 0)
        normal = V(edge.y, -edge.x, 0)
        # outward: away from the crescent's interior (test a point a hair along the normal)
        probe = mid + normal.normalized() * .01
        inside = math.hypot(probe.x, probe.y) < MOON_R and math.hypot(probe.x + MOON_BITE_C[0], probe.y - MOON_BITE_C[1]) > MOON_BITE_R
        m.face(q, [region_uv("sun", .5, .5)] * 4, -normal if inside else normal, smooth=False)
    top = max(outline, key=lambda p: p[1])
    tube(m, [CROOK_TIP + V(0, .02, 0), c + V(top[0], top[1] - .02, 0)], [.022, .022], 4,
         lambda k, s: region_uv("cord", .5, s / 4), cap_end=False)
    return m, c + V(top[0], top[1], 0)


# --------------------------------------------------------------------------------------------------------- blankets
def egg_radius(y):
    """The ready egg (1.6 x 2.1, base 2.15, fat end down): radius at height y."""
    t = max(-1.0, min(1.0, (EGG_BASE + EGG_H / 2 - y) / (EGG_H / 2)))
    th = math.acos(t)
    return EGG_W / 2 * math.sin(th) * (1 + .1 * math.cos(th))


CLEAR = .15   # architect: the blanket ripple lags the breath .15 s, so the egg (+2.5 percent) must not reach it


def build_draped(name="BlanketDraped", top_frac=.45, slipped=False):
    """Over the egg's front and sides to `top_frac` of its height, across the bed, over the twigs, 0.5 over the front
    rim; shorter toward the sides. u across (-120 to 120 degrees from the front), v along the drape. `slipped` (the
    ready pose): down to 20 percent, the east corner (toward the Bear) slid off the rim and hanging down the bowl."""
    m = Mesh(name)
    top = EGG_BASE + top_frac * EGG_H
    low = EGG_BASE + min(top_frac, .25) * EGG_H                     # the top edge at the ends (Fable R2 1: 25 percent)
    path = []
    for k in range(6):                                   # down the egg's face; the stand-off widens .05 -> .15
        y = top - (top - (EGG_BASE + .35)) * k / 5
        path.append((egg_radius(y) + .05 + (CLEAR - .05) * k / 5, y))
    path += [(1.22, 2.55), (1.56, 2.8), (1.86, 2.9), (2.14, 2.8), (2.38, 2.52), (2.47, 2.22)]   # taut over the crest
    if slipped:
        path += [(2.52, 1.92), (2.5, 1.62)]             # the corner's extra length, down the collar and bowl
    lens = [0.0]
    for (r0, y0), (r1, y1) in zip(path, path[1:]):
        lens.append(lens[-1] + math.hypot(r1 - r0, y1 - y0))
    total = lens[-1]

    def at(s):                                           # path point at arc length s
        for k in range(len(lens) - 1):
            if lens[k] <= s <= lens[k + 1]:
                t = (s - lens[k]) / max(1e-9, lens[k + 1] - lens[k])
                return (path[k][0] + (path[k + 1][0] - path[k][0]) * t, path[k][1] + (path[k + 1][1] - path[k][1]) * t)
        return path[-1]
    cols, rows = 14, 12
    grid = []
    spill = lens[len(path) - (3 if slipped else 1)] / total           # the arc share up to the front spill's end
    for i in range(cols + 1):
        th = math.radians(-120 + 240 * i / cols)
        half = math.degrees(.9 / 2.4)                                  # the flap: 1.8 wide at the rim (r 2.4)
        edge = max(0.0, min(1.0, (abs(math.degrees(th)) - half) / 16))
        flap = .5 + .5 * math.cos(math.pi * edge)                      # 1 across the flap, rounded off over 16 degrees
        reach = (.36 + .64 * (max(0.0, math.cos(th)) ** 3 if slipped else flap)) * spill   # slipped: R1's accepted pose
        if slipped:
            corner = math.exp(-((math.degrees(th) + 65) / 28) ** 2)        # the east corner, about 65 degrees round
            reach = reach + (1 - reach) * corner
        row = []
        side = min(1.0, abs(math.degrees(th)) / 120)
        drop_to = top - (top - low) * side ** 1.5                     # 45 percent at the front, 25 at the ends
        start = 0.0
        while start < lens[5] and at(start)[1] > drop_to:
            start += .01
        for j in range(rows + 1):
            r, y = at(start + (total * reach - start) * j / rows)
            sag = .03 * math.sin(math.pi * i / cols * 6) * (j / rows)    # soft folds
            row.append(V(r * math.sin(th), y + sag, -r * math.cos(th)))
        grid.append(row)
    for i in range(cols):
        th = math.radians(-120 + 240 * (i + .5) / cols)
        radial = V(math.sin(th), 0, -math.cos(th))
        for j in range(rows):
            q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
            along = (grid[i][j + 1] - grid[i][j])
            dr = along.dot(radial)
            out = radial * (-along.y) + V(0, dr, 0)                  # (-dy, dr): away from the egg, up off the bed
            if out.length < 1e-6:
                out = radial
            uv = [region_uv("quilt", i / cols, j / rows), region_uv("quilt", (i + 1) / cols, j / rows),
                  region_uv("quilt", (i + 1) / cols, (j + 1) / rows), region_uv("quilt", i / cols, (j + 1) / rows)]
            m.face(q, uv, out)
    front_edge = grid[cols // 2][rows]
    return m, V(0.0, round(front_edge.y, 3), round(front_edge.z, 3))


def build_folded():
    """Fable R1 10: one soft block 1.1 x 0.8 x 0.35, bevel .08, its +z long edge fully rounded (the fold), along the
    rim's tangent. A subdivided box pushed out from an inner box (each point's radius by its side)."""
    m = Mesh("BlanketFolded")
    c = FOLDED_CENTRE
    yaw = math.atan2(c.x, c.z)                                    # long side (x) along the rim's tangent
    rot = Matrix.Rotation(yaw, 3, "Y")
    hx, hy, hz = .55, .175, .4
    n = 4

    def shape(p):
        r = hy if p.z > 0 else .08
        inner = V(max(-hx + r, min(hx - r, p.x)), max(-hy + r, min(hy - r, p.y)), max(-hz + r, min(hz - r, p.z)))
        off = p - inner
        return inner + (off.normalized() * r if off.length > 1e-9 else V(0, 0, 0))
    faces = ((V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)), (V(-1, 0, 0), V(0, 0, 1), V(0, 1, 0)),
             (V(0, 1, 0), V(0, 0, 1), V(1, 0, 0)), (V(0, -1, 0), V(1, 0, 0), V(0, 0, 1)),
             (V(0, 0, 1), V(1, 0, 0), V(0, 1, 0)), (V(0, 0, -1), V(0, 1, 0), V(1, 0, 0)))
    ext = V(hx, hy, hz)
    for normal, a, b in faces:
        grid = []
        for i in range(n + 1):
            row = []
            for j in range(n + 1):
                u, v = i / n * 2 - 1, j / n * 2 - 1
                q = V(normal.x * ext.x, normal.y * ext.y, normal.z * ext.z) + V(a.x * ext.x, a.y * ext.y, a.z * ext.z) * u \
                    + V(b.x * ext.x, b.y * ext.y, b.z * ext.z) * v
                row.append(shape(q))
            grid.append(row)
        for i in range(n):
            for j in range(n):
                q = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                world = [c + rot @ x for x in q]
                mid = sum(q, Vector()) / 4
                uv = [region_uv("quilt", .3 + .4 * (x.x / hx * .5 + .5), .25 + .5 * (x.z / hz * .5 + .5)) for x in q]
                m.face(world, uv, rot @ (mid - V(0, 0, 0)))
    return m


# ------------------------------------------------------------------------------------------------------------ export
def centred(obj):
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2
    obj.data.transform(Matrix.Translation(-c))
    obj.location = c
    size = hi - lo
    return [round(c.x, 4), round(c.z, 4), round(-c.y, 4)], [round(size.x, 4), round(size.z, 4), round(size.y, 4)]


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def digest(obj):
    h = hashlib.sha1()
    for v in obj.data.vertices:
        h.update(("%.4f %.4f %.4f;" % tuple(v.co)).encode())
    return h.hexdigest()[:16]


def bounds(objs):
    vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    # Blender -> nest-local: x, z(up), -y
    return {"x": [round(lo[0], 3), round(hi[0], 3)], "y": [round(lo[2], 3), round(hi[2], 3)], "z": [round(-hi[1], 3), round(-lo[1], 3)]}


def check_outward(obj, centre_fn, label, share=.97):
    """Most faces of a closed-ish part must face away from `centre_fn(face centre)` (Roblox culls back faces)."""
    good = total = 0
    for poly in obj.data.polygons:
        c = obj.matrix_world @ poly.center
        ref = centre_fn(c)
        if ref is None:
            continue
        total += 1
        good += (obj.matrix_world.to_3x3() @ poly.normal).dot(c - ref) > 0
    assert total and good / total >= share, (label, good, total)


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    rnd = random.Random(2611)
    body_m, crook = build_body(rnd)
    body = body_m.build()
    awning = build_awning().build()
    moon_m, cord_top = build_moon()
    moon = moon_m.build()
    draped_m, draped_edge = build_draped()
    draped = draped_m.build()
    slipped_m, slipped_edge = build_draped("BlanketSlipped", .2, slipped=True)
    slipped = slipped_m.build()
    folded = build_folded().build()
    # The bowl's outer wall (y .5 to 1.7, r over 2.0) faces out; the moon's front faces -Z.
    def bowl_ref(c):
        r = math.hypot(c.x, c.y)
        return Vector((0, 0, c.z)) if (.5 < c.z < 1.45 and r > 2.0 and r < 2.42) else None   # under the collar
    check_outward(body, bowl_ref, "bowl wall")
    # The moon's two faces: the one nearer the front (-Z nest-local = +y Blender) must face front (+y), the other back.
    plus = [p.center.y for p in moon.data.polygons if p.normal.y > .9]
    minus = [p.center.y for p in moon.data.polygons if p.normal.y < -.9]
    assert plus and minus and sum(plus) / len(plus) > sum(minus) / len(minus), "moon faces wound inward"
    world = bounds([body, awning, moon, draped, slipped, folded])
    objs = [(body, "Body"), (awning, "Awning"), (moon, "Moon"), (draped, "BlanketDraped"), (slipped, "BlanketSlipped"),
            (folded, "BlanketFolded")]
    for obj, name in objs:
        obj.name = obj.data.name = "NestLandmark_" + name
    parts = []
    for obj, name in objs:
        c, size = centred(obj)
        parts.append({"name": obj.name, "part": name, "tris": tris(obj), "center": c, "size": size, "hash": digest(obj)})
    meshes = sum(p["tris"] for p in parts)
    # The blanket's three poses are never shown together: count the largest one (the drawn landmark) and all of them.
    by_part = {p["part"]: p["tris"] for p in parts}
    drawn = meshes - by_part["BlanketDraped"] - by_part["BlanketSlipped"] - by_part["BlanketFolded"] + max(
        by_part["BlanketDraped"], by_part["BlanketSlipped"], by_part["BlanketFolded"])
    total = meshes + CODE_EGG_CAP + CODE_PARTS
    assert total <= TRI_CAP, ("triangles", total)
    reach = max(math.hypot(v.co.x + body.location.x, v.co.y + body.location.y) for v in body.data.vertices
                if (v.co.z + body.location.z) > .2)            # the mat lies on the ground: not counted
    manifest = {
        "note": "Generated by scripts/build_nest_landmark.py. Nest-local Roblox studs: origin on the ground at the bowl's "
                "centre, +X the plaza's west, front -Z (NestClient's root). Roblox imports each mesh turned by pi about Y.",
        "front": [0, 0, -1],
        "bounds": world,
        "parts": parts,
        # Architect: every pivot with its axis, nest-local (the import's pi turn is in the parts' CFrames, not here).
        "pivots": {
            # sway +-2 degrees, and the ready lift: a positive turn about `axis` raises the leaf tips
            "Awning": {"at": r4(CROOK_APEX + AWNING_ATTACH), "axis": r4(awning_axis())},
            # sway +-3 degrees about the cord's top, side to side in the crescent's plane
            "Moon": {"at": r4(CROOK_TIP), "axis": [0.0, 0.0, 1.0]},
            # unrolls from its lower front edge: scale along `up` from `at` (0.2 to 1)
            "BlanketDraped": {"at": r4(draped_edge), "up": [0.0, 1.0, 0.0]},
            "BlanketSlipped": {"at": r4(slipped_edge), "up": [0.0, 1.0, 0.0]},
            "BlanketFolded": {"at": r4(FOLDED_CENTRE), "long": r4(folded_long())},
        },
        # the blankets are fitted to this egg (the ready size) with CLEAR between: for smaller looks, scale them with it
        "blanketFit": {"egg": [EGG_W, EGG_H], "clear": CLEAR, "drapedTop": round(EGG_BASE + .45 * EGG_H, 4),
                       "slippedTop": round(EGG_BASE + .2 * EGG_H, 4)},
        "moonLight": [round(v, 4) for v in MOON_CENTRE],
        "moonTop": [round(v, 4) for v in cord_top],          # the cord's lower end; its upper end is the Moon pivot
        "egg": {"base": EGG_BASE, "size": [EGG_W, EGG_H, EGG_W], "centre": [0.0, EGG_BASE + EGG_H / 2, 0.0]},
        "dent": {"centre": [0.0, 2.1, 0.0], "size": [1.56, .1, 1.32]},
        "bed": {"top": 2.2, "radius": 1.3},                     # where the blanket drops on a hatch
        "rim": 2.75,
        "sign": SIGN,
        "mat": MAT,
        "bearSpot": [-2.9, 0.0, -2.0],
        # a Y cylinder (architect: a 4.8 box's corners reach the mat). It collides, so it is also queryable (Roblox ignores
        # CanQuery while CanCollide is on): the code side keeps pets' and trails' rays off it (collision group or exclude).
        "collider": {"centre": [0.0, COLLIDER_H / 2, 0.0], "radius": COLLIDER_R, "height": COLLIDER_H},
        "version": VERSION,
        "footprintRadius": round(reach, 3),
        "triangles": {"meshes": meshes, "drawn": drawn + CODE_EGG_CAP + CODE_PARTS, "all": total, "cap": TRI_CAP},
    }
    bpy.ops.object.select_all(action="DESELECT")
    for obj, _ in objs:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "nest-landmark.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                             colors_type="NONE")
    (OUT / "nest-landmark-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("NEST LANDMARK", meshes, "mesh tris (drawn", drawn, ");", ", ".join(f"{p['part']} {p['tris']}" for p in parts),
          "; bounds", world, "; reach", round(reach, 3))
    if "--render" in sys.argv:
        render(dict((n, o) for o, n in objs), manifest)


# ------------------------------------------------------------------------------------------------------------ render
def material(name, image=None, colour=None, emit=None, rough=.85):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    if image:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    elif colour:
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        for key in ("Emission Color", "Emission"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = (*emit[0], 1)
                break
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emit[1]
    return mat


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def render_egg(colour):
    m = bmesh.new()
    rings, segs = 14, 20
    verts = []
    for j in range(rings + 1):
        th = math.pi * j / rings
        r = EGG_W / 2 * math.sin(th) * (1 + .1 * math.cos(th))
        y = EGG_BASE + EGG_H / 2 - EGG_H / 2 * math.cos(th)
        row = [m.verts.new(bl((r * math.sin(2 * math.pi * i / segs), y, r * math.cos(2 * math.pi * i / segs)))) for i in range(segs)]
        verts.append(row)
    for j in range(rings):
        for i in range(segs):
            f = m.faces.new([verts[j][i], verts[j][(i + 1) % segs], verts[j + 1][(i + 1) % segs], verts[j + 1][i]])
            f.smooth = True
    bmesh.ops.remove_doubles(m, verts=m.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(m, faces=m.faces)
    me = bpy.data.meshes.new("RenderEgg")
    m.to_mesh(me)
    m.free()
    obj = bpy.data.objects.new("RenderEgg", me)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material("Egg", colour=colour, rough=.6))
    return obj


def import_machine(offset_x):
    """The egg machine from its own FBX, turned to face -Z beside the nest, the dial and sprout at their pivots."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(MACHINE / "egg-machine.fbx"), axis_forward="-Z", axis_up="Y")
    new = [o for o in bpy.data.objects if o not in before]
    manifest = json.loads((MACHINE / "egg-machine-manifest.json").read_text())
    image = bpy.data.images.load(str(MACHINE / "egg-machine.png"))
    tex = material("MachineTex", image, rough=.6)
    plain = material("MachinePlain", colour=lin("#FFFFFF"), rough=.5)
    nodes = plain.node_tree.nodes
    vc = nodes.new("ShaderNodeVertexColor")
    plain.node_tree.links.new(vc.outputs["Color"], next(n for n in nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    glass = material("MachineGlass", colour=lin("#FFF8E6"), rough=.1)
    try:
        glass.surface_render_method = "BLENDED"
    except Exception:
        pass
    bsdf = next(n for n in glass.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = .3
    pivot = bpy.data.objects.new("MachineRoot", None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in new:
        if o.type != "MESH":
            continue
        part = o.name.split("_", 1)[-1].split(".")[0]
        o.data.materials.clear()
        o.data.materials.append(glass if part == "Globe" else tex if part in ("Body", "Dial") else plain)
        if part in ("Dial", "Sprout"):
            o.location = o.location + bl(manifest["pivots"][part])
        if part == "Egg":
            o.hide_render = True
        o.parent = pivot
    pivot.rotation_euler = (0, 0, math.pi)      # its front is +Z: turn it to face -Z like the nest
    pivot.location = bl((offset_x, 0, 0))


def render(by, manifest):
    RENDERS.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.load(str(TEXTURE))
    tex = material("Tex", image)
    paper = material("Paper", image, rough=.85)
    for name in ("Body", "Awning", "BlanketDraped", "BlanketSlipped", "BlanketFolded"):
        by[name].data.materials.append(tex)
    by["Moon"].data.materials.append(paper)
    egg = render_egg(lin("#C9B4FF"))
    # ground: plaza marble
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    ground = bpy.context.object
    ground.data.materials.append(material("Marble", colour=lin("#E6E2DA"), rough=.6))
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(48), 0, math.radians(-35))
    bpy.context.scene.collection.objects.link(so)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.55, .75, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .45
    scene = bpy.context.scene
    scene.world = world
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 960, 960
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    draped, slipped, folded = by["BlanketDraped"], by["BlanketSlipped"], by["BlanketFolded"]
    moon, awning = by["Moon"], by["Awning"]
    moon_mat_ready = material("MoonReady", image, emit=(lin("#FFE08A"), 1.2))
    apex = bl(manifest["pivots"]["Awning"]["at"])
    lift_axis = bl(manifest["pivots"]["Awning"]["axis"]).normalized()
    states = {
        "empty": dict(egg=False, draped=False, folded=True, ready=False),
        "tucked": dict(egg=True, draped=True, folded=False, ready=False),
        "ready": dict(egg=True, draped=True, folded=False, ready=True),
    }
    views = (("front", (0, 4.6, -13.5)), ("three-quarter", (-8.5, 6.2, -10.5)), ("path-mouth", (-7.6, 6.0, -24.3)))
    target = bl((0, 3.0, 0))
    awning_home = awning.matrix_world.copy()
    for state, st in states.items():
        egg.hide_render = not st["egg"]
        draped.hide_render = not (st["draped"] and not st["ready"])
        slipped.hide_render = not st["ready"]
        folded.hide_render = not st["folded"]
        moon.data.materials.clear()
        moon.data.materials.append(moon_mat_ready if st["ready"] else paper)
        # the ready lift: +6 degrees about the awning's axis through its pivot raises the tips (code review)
        turn = (Matrix.Translation(apex) @ Matrix.Rotation(math.radians(6 if st["ready"] else 0), 4, lift_axis)
                @ Matrix.Translation(-apex))
        awning.matrix_world = turn @ awning_home
        for label, eye in views:
            e = bl(eye)
            cam.location = e
            cam.rotation_euler = (target - e).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(RENDERS / f"render-{state}-{label}.png")
            bpy.ops.render.render(write_still=True)
    awning.matrix_world = awning_home
    # beside the machine, the tucked state, from the plaza's middle
    egg.hide_render, draped.hide_render, slipped.hide_render, folded.hide_render = False, False, True, True
    moon.data.materials.clear()
    moon.data.materials.append(paper)
    import_machine(7.0)
    e = bl((3.5, 6.0, -19.0))
    cam.location = e
    cam.rotation_euler = (bl((3.5, 3.3, 0)) - e).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x = 1280
    scene.render.filepath = str(RENDERS / "render-beside-machine.png")
    bpy.ops.render.render(write_still=True)
    print("NEST LANDMARK renders in", RENDERS)


main()
