"""The egg machine (EGG-CORNER-LOOK section 2, Fable 2026-11-24): an egg-shaped glass globe in a scalloped leaf collar
on a pot-bellied cream base, a sunflower dial, a leaf chute into a woven cup, a sprout on top. Original design; every
shape here is built from code (lathes, curves), hand-tuned. No AI mesh, no samples.

Run in BACKGROUND Blender from an empty scene:
  blender.exe -b --factory-startup --python scripts/build_egg_machine.py -- [--render]

Machine-local Roblox axes: x right, y up, z = the machine's front (local +Z, as the spec), origin on the ground at the
base's centre. Blender (x, y, z) = Roblox (x, -z, y). FBX: forward -Z, up Y (as the Aero kit), so Roblox imports each
mesh turned by pi about Y; the manifest records each part's bounds centre and size in machine-local Roblox axes.

Parts (one FBX, one Model upload): Body (feet, base, collar, cap, chute, cup; textured), Globe (vertex tint, clear),
Dial (textured; its own part, pivot at its centre, face +Z), Sprout (pivot at the stem's foot), EggPile (18 baked eggs,
vertex-coloured), Egg (one 96-triangle egg: the 6 loose eggs and the dropped egg are clones; Color sets the type).

Writes assets/world/egg-machine/egg-machine.fbx, egg-machine-manifest.json; with --render, renders to
artifacts/qa-2026-11-24-beta15/egg-machine/ (front, three-quarter, from the path mouth).
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
OUT = ROOT / "assets" / "world" / "egg-machine"
RENDERS = ROOT / "artifacts" / "qa-2026-11-24-beta15" / "egg-machine"
TEXTURE = OUT / "egg-machine.png"
ATLAS = 512.0
REGION = {  # x0, y0, x1, y1 in atlas pixels (image y down), see scripts/draw_egg_machine_texture.py
    "base": (0, 0, 256, 256), "leaf": (256, 0, 512, 128), "straw": (256, 128, 512, 256),
    "dial": (0, 256, 256, 512), "green": (256, 256, 384, 384), "knob": (384, 256, 512, 384),
    "emboss": (256, 384, 384, 512),
}
EGG_TYPES = {"Toy": "#FFB340", "Hue": "#FF7AB8", "Material": "#8FF0E4", "Feature": "#9CFFDD", "Stat": "#FF8A5C"}
MIX = ["Toy"] * 6 + ["Stat"] * 5 + ["Hue"] * 5 + ["Material"] * 4 + ["Feature"] * 4   # 24: 18 baked + 6 loose
TRI_CAP = 6000
GLOBE_BOTTOM, GLOBE_TOP, GLOBE_R, GLOBE_WIDEST = 3.3, 7.05, 1.75, .40
GLOBE_ROUNDNESS = .65            # Fable render R1: a fuller shoulder and a blunt top (was a teardrop)
BASE_DEPTH = 1.8 / 2.1           # the belly is 4.2 wide, 3.6 deep
DIAL_CENTRE = Vector((0.0, 1.95, 0.0))   # z filled in from the base's surface
EGG_W, EGG_H = .66, .86          # Fable render R1: .55 x .72 left the globe a third full
DROP_SCALE = .72 / .66           # the dropped egg is the same mesh at this scale (0.72 x 0.94)
CREAM_BAND = (0xFF / 255, 0xF3 / 255, 0xC4 / 255)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def region_uv(name, u, v):
    """u, v in 0..1 inside a region (v = 0 at the region's top row) to Blender UV (v up)."""
    x0, y0, x1, y1 = REGION[name]
    u = min(max(u, .002), .998)
    v = min(max(v, .002), .998)
    return ((x0 + (x1 - x0) * u) / ATLAS, 1 - (y0 + (y1 - y0) * v) / ATLAS)


def bl(p):
    return Vector((p[0], -p[2], p[1]))


class Mesh:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.float_color.new("Col")

    def face(self, pts, uvs=None, cols=None, smooth=True, out=None):
        if out is not None:
            p0, p1, p2 = (Vector(q) for q in pts[:3])
            if (p1 - p0).cross(p2 - p0).dot(Vector(out)) < 0:   # wound the other way: reverse (with its uvs, colours)
                pts = pts[::-1]
                uvs = uvs[::-1] if uvs else uvs
                cols = cols[::-1] if cols else cols
        vs = [self.bm.verts.new(bl(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.smooth = smooth
        for i, loop in enumerate(f.loops):
            loop[self.uv].uv = uvs[i] if uvs else (0.0, 0.0)
            c = cols[i] if cols else (1.0, 1.0, 1.0)
            loop[self.col] = (*c, 1.0)
        return f

    def build(self, weld=True, recalc=True):
        if weld:
            bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        if recalc:
            bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def lathe(m, profile, segs, uvfn, colfn=None, sx=1.0, sz=1.0, centre=(0, 0, 0), radius_fn=None, phase=0.0):
    """Revolve [(r, y)] about the y axis (ellipse sx, sz). uvfn(i_seg_frac, j_profile_frac, r, y) -> (u, v) region uv."""
    cx, cy, cz = centre
    rows = []
    for j, (r, y) in enumerate(profile):
        row = []
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs + phase
            rr = r * (radius_fn(a, j) if radius_fn else 1.0)
            row.append((cx + rr * math.sin(a) * sx, cy + y, cz + rr * math.cos(a) * sz))
        rows.append(row)
    n = len(profile) - 1
    for j in range(n):
        for i in range(segs):
            pts = [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
            uvs = [uvfn(i / segs, j / n, *profile[j]), uvfn((i + 1) / segs, j / n, *profile[j]),
                   uvfn((i + 1) / segs, (j + 1) / n, *profile[j + 1]), uvfn(i / segs, (j + 1) / n, *profile[j + 1])]
            cols = None
            if colfn:
                cols = [colfn(p) for p in pts]
            if profile[j][0] == 0:
                m.face([pts[0], pts[2], pts[3]], [uvs[0], uvs[2], uvs[3]], cols and [cols[0], cols[2], cols[3]])
            elif profile[j + 1][0] == 0:
                m.face([pts[0], pts[1], pts[2]], uvs[:3], cols and cols[:3])
            else:
                m.face(pts, uvs, cols)
    return rows


# ------------------------------------------------------------------------------------------------------------- body
BASE_PROFILE = [(0.0, .35), (1.35, .37), (1.85, .7), (2.1, 1.4), (2.0, 2.0), (1.8, 2.55), (1.6, 2.95), (0.0, 2.95)]


def base_radius_at(y):
    pts = BASE_PROFILE[1:-1]
    for (r0, y0), (r1, y1) in zip(pts, pts[1:]):
        if y0 <= y <= y1:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    return pts[-1][0]


def build_collar(m, segs=64):
    """Fable render R1: 8 leaf lobes with a sharp notch between (valley 1.62, tip 1.95, 3.9 across), the tip rim
    dipping .08; rows: inner foot, outer foot, the lobed rim, the inner lip."""
    def lobe(a):
        return abs(math.cos(4 * a)) ** .7                 # 1 at a lobe's tip, 0 in the notch (a V)
    rows = []
    for i in range(segs + 1):
        a = 2 * math.pi * i / segs
        f = lobe(a)
        r_rim = 1.62 + (1.95 - 1.62) * f
        ring = [(1.5, 2.93), (1.62 + .1 * f, 2.95), (r_rim, 3.36 - .08 * f), (1.58, 3.5), (1.48, 3.42)]
        rows.append([(r * math.sin(a), y, r * math.cos(a) * 1.0) for r, y in ring])
    for i in range(segs):
        for j in range(4):
            pts = [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
            u0, u1 = (i * 8 / segs) % 1.0, ((i + 1) * 8 / segs) % 1.0 or 1.0
            uvs = [region_uv("leaf", u0, .1 + .1 * j), region_uv("leaf", u1, .1 + .1 * j),
                   region_uv("leaf", u1, .1 + .1 * (j + 1)), region_uv("leaf", u0, .1 + .1 * (j + 1))]
            m.face(pts, uvs)


def build_body():
    m = Mesh("Body")
    # Base: u around, v up (row 0 the top).
    lathe(m, BASE_PROFILE, 28, lambda u, t, r, y: region_uv("base", u, (2.95 - y) / 2.6), sz=BASE_DEPTH)
    # Feet: two front, one back; rounded pads.
    foot = [(0.0, 0.0), (.42, .01), (.45, .14), (.36, .29), (.18, .35), (0.0, .35)]
    for fx, fz in ((-.95, .85), (.95, .85), (0.0, -1.05)):      # half tucked under the belly, clear of the cup
        lathe(m, foot, 10, lambda u, t, r, y: region_uv("green", u, t), centre=(fx, 0, fz))
    # Leaf collar: 8 scallops, tips curling out .2.
    build_collar(m)
    # Cap on the globe's top.
    cap = [(0.0, 6.9), (.6, 6.9), (.64, 6.98), (.5, 7.08), (0.0, 7.12)]   # domed, sunk to hug the glass
    lathe(m, cap, 14, lambda u, t, r, y: region_uv("green", u, t))
    # Chute: a curled leaf trough from the base's front-right (1.1 up) down to over the cup.
    p0 = Vector((1.05, 1.1, base_radius_at(1.1) * BASE_DEPTH * .93))
    p3 = Vector((1.25, .55, 1.95))
    p1, p2 = p0 + Vector((.15, -.05, .55)), p3 + Vector((-.05, .35, -.2))
    def bez(t):
        return p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + p3 * t ** 3
    n_len, n_w = 7, 5
    grid = []
    # One fixed "across" for the whole leaf (a frame per point flipped where the curve turns steep: a twisted ribbon).
    side = (p3 - p0).cross(Vector((0, 1, 0))).normalized()
    for k in range(n_len + 1):
        t = k / n_len
        c = bez(t)
        d = (bez(min(1, t + .01)) - bez(max(0, t - .01))).normalized()
        up = side.cross(d).normalized()
        if up.y < 0:
            up = -up
        row = []
        for s in range(n_w + 1):
            q = s / n_w * 2 - 1
            w = .45 * max(0.0, 1 - t) ** .7                                 # tapers to a point
            row.append(c + side * (q * w) + up * (.18 * q * q - .02 + .1 * t ** 3))   # U trough, tip curled up
        grid.append(row)
    for k in range(n_len):
        for s in range(n_w):
            pts = [grid[k][s], grid[k][s + 1], grid[k + 1][s + 1], grid[k + 1][s]]
            # u along the leaf (the painted midrib runs along u at v .25, the middle of the trough)
            uvs = [region_uv("leaf", k / n_len, .05 + .4 * s / n_w), region_uv("leaf", k / n_len, .05 + .4 * (s + 1) / n_w),
                   region_uv("leaf", (k + 1) / n_len, .05 + .4 * (s + 1) / n_w), region_uv("leaf", (k + 1) / n_len, .05 + .4 * s / n_w)]
            m.face(pts, uvs)
            back = [p - Vector((0, .04, 0)) for p in pts[::-1]]     # underside of the leaf
            m.face(back, [region_uv("leaf", .5, .75)] * 4)
    # Cup: a woven bowl on the ground at front-right.
    cup = [(0.0, .08), (.5, .1), (.53, .4), (.6, .45), (.6, .15), (.45, 0.0), (0.0, 0.0)]
    lathe(m, cup, 16, lambda u, t, r, y: region_uv("straw", u, 1 - min(1, y / .45)), centre=(1.25, 0, 1.75))
    return m.build(), {"cup": [1.25, .1, 1.75], "chuteTop": list(p0), "chuteEnd": list(p3)}


# ------------------------------------------------------------------------------------------------------------ globe
def egg_profile(w, h, rings, bottom=0.0, widest=.42, open_bottom=None, roundness=.85):
    out = []
    for j in range(rings + 1):
        t = j / rings
        y = bottom + h * t
        s = t / widest * .5 if t < widest else .5 + (t - widest) / (1 - widest) * .5
        r = w / 2 * math.sin(math.pi * s) ** roundness
        if j in (0, rings):
            r = 0.0
        out.append((r, y))
    if open_bottom is not None:
        out = [p for p in out if p[1] >= bottom + open_bottom]
    return out


def build_globe():
    m = Mesh("Globe")
    tint = lin(hexrgb("#FFF8E6"))
    tint = tuple(c * .9 for c in tint)
    prof = egg_profile(2 * GLOBE_R, GLOBE_TOP - GLOBE_BOTTOM, 11, GLOBE_BOTTOM, GLOBE_WIDEST, open_bottom=.06,
                       roundness=GLOBE_ROUNDNESS)

    def colour(p):
        # one painted highlight streak upper left (seen from the front): brighter vertices
        a = math.atan2(p[0], p[2])
        hl = math.exp(-((a + .75) / .3) ** 2) * math.exp(-((p[1] - 5.9) / .6) ** 2)
        return tuple(min(1.0, c + .1 * hl) for c in tint)
    lathe(m, prof, 18, lambda u, t, r, y: (0.0, 0.0), colfn=colour)
    return m.build()


# ------------------------------------------------------------------------------------------------------------- dial
def build_dial():
    """In its own frame: centre at the origin, face +z. 6 rounded petals, a knob at radius .5 (straight up), an egg
    embossed in the middle."""
    m = Mesh("Dial")
    n = 48

    def rim(a):
        return .7 + .15 * math.cos(6 * a)
    outline = [(rim(2 * math.pi * i / n) * math.cos(2 * math.pi * i / n), rim(2 * math.pi * i / n) * math.sin(2 * math.pi * i / n))
               for i in range(n)]
    duv = lambda x, y: region_uv("dial", .5 + x / (2 * .85), .5 - y / (2 * .85))
    front_c = (0.0, 0.0, .3)
    for i in range(n):
        a, b = outline[i], outline[(i + 1) % n]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0)
        m.face([front_c, (a[0], a[1], .22), (b[0], b[1], .22)], [duv(0, 0), duv(*a), duv(*b)], out=(0, 0, 1))    # front
        m.face([(0, 0, 0), (b[0], b[1], 0), (a[0], a[1], 0)], [duv(0, 0), duv(*b), duv(*a)], out=(0, 0, -1))     # back
        m.face([(a[0], a[1], 0), (b[0], b[1], 0), (b[0], b[1], .22), (a[0], a[1], .22)],
               [duv(*a), duv(*b), duv(*b), duv(*a)], out=mid)                                                   # side
    # Knob at radius .5 straight up, .55 proud, cream.
    kx, ky, kr, segs = 0.0, .5, .275, 12                 # Fable render R1: .55 across, .3 proud, domed
    ring = [(kx + kr * math.cos(2 * math.pi * i / segs), ky + kr * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    for i in range(segs):
        a, b = ring[i], ring[(i + 1) % segs]
        mid_a = (a[0] * .8 + kx * .2, a[1] * .8 + ky * .2)
        mid_b = (b[0] * .8 + kx * .2, b[1] * .8 + ky * .2)
        side = ((a[0] + b[0]) / 2 - kx, (a[1] + b[1]) / 2 - ky, 0)
        m.face([(a[0], a[1], .24), (b[0], b[1], .24), (b[0], b[1], .42), (a[0], a[1], .42)], [region_uv("knob", .5, .5)] * 4, out=side)
        m.face([(a[0], a[1], .42), (b[0], b[1], .42), (mid_b[0], mid_b[1], .5), (mid_a[0], mid_a[1], .5)], [region_uv("knob", .5, .5)] * 4,
               out=(side[0], side[1], .6))
        m.face([(kx, ky, .54), (mid_a[0], mid_a[1], .5), (mid_b[0], mid_b[1], .5)], [region_uv("knob", .5, .5)] * 3, out=(0, 0, 1))
    # Embossed egg in the middle: a raised egg outline .04 above the face.
    eg = [(0.0, -.24), (.13, -.2), (.17, -.06), (.14, .1), (.08, .2), (0.0, .24), (-.08, .2), (-.14, .1), (-.17, -.06), (-.13, -.2)]
    for i in range(len(eg)):
        a, b = eg[i], eg[(i + 1) % len(eg)]
        m.face([(0, -.06, .345), (a[0], a[1] - .06, .335), (b[0], b[1] - .06, .335)], [region_uv("emboss", .5, .5)] * 3, out=(0, 0, 1))
        m.face([(a[0], a[1] - .06, .29), (b[0], b[1] - .06, .29), (b[0], b[1] - .06, .335), (a[0], a[1] - .06, .335)],
               [region_uv("emboss", .5, .5)] * 4, out=((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0))
    # Studio r1: recalc_face_normals cannot orient the open knob and emboss (half the front faced in and Roblox culled
    # it), so every face is wound to its own outward direction above and nothing is recalculated.
    return m.build(weld=True, recalc=False)


# ----------------------------------------------------------------------------------------------------------- sprout
def build_sprout():
    """Pivot at the stem's foot (origin); two leaves .9 long on a .35 stem."""
    m = Mesh("Sprout")
    green = lin(hexrgb("#6FBF73"))
    stem = [(.06, 0.0), (.05, .35)]
    for i in range(6):
        a0, a1 = 2 * math.pi * i / 6, 2 * math.pi * (i + 1) / 6
        pts = [(stem[0][0] * math.sin(a0), 0, stem[0][0] * math.cos(a0)), (stem[0][0] * math.sin(a1), 0, stem[0][0] * math.cos(a1)),
               (stem[1][0] * math.sin(a1), .35, stem[1][0] * math.cos(a1)), (stem[1][0] * math.sin(a0), .35, stem[1][0] * math.cos(a0))]
        m.face(pts, None, [green] * 4)
    for side in (-1, 1):
        base = Vector((0, .33, 0))
        d = Vector((side * .86, .28, .1 * side)).normalized()
        across = d.cross(Vector((0, 0, 1))).normalized()
        pts_top, pts_bot = [], []
        for k in range(6):
            t = k / 5
            w = .22 * math.sin(math.pi * t) ** .8
            c = base + d * (.9 * t) + Vector((0, -.18 * t * t, 0))      # droops at the tip
            pts_top.append(c + across * w)
            pts_bot.append(c - across * w)
        for k in range(5):
            q = [pts_top[k], pts_top[k + 1], pts_bot[k + 1], pts_bot[k]]
            uv = [region_uv("leaf", k / 5, .15), region_uv("leaf", (k + 1) / 5, .15), region_uv("leaf", (k + 1) / 5, .35), region_uv("leaf", k / 5, .35)]
            m.face(q, uv, [green] * 4)
            m.face([p - Vector((0, .015, 0)) for p in q[::-1]], [region_uv("leaf", .5, .75)] * 4, [green] * 4)
    return m.build(weld=False)


# ------------------------------------------------------------------------------------------------------------- eggs
def blunt_egg_profile(w, h, rings=7):
    """Fable render R1: rings spaced by angle (blunt ends), the fat end down."""
    out = []
    for j in range(rings + 1):
        th = math.pi * j / rings
        r = w / 2 * math.sin(th) * (1 + .10 * math.cos(th))
        y = -h / 2 * math.cos(th)
        out.append((0.0 if j in (0, rings) else r, y))
    return out


def egg_faces(m, centre, colour, tilt=0.0, yaw=0.0, cull=None, band=None, body=.86):
    """96 triangles: 8 around, 7 bands. A zigzag band round the middle: `band` its colour (default the body colour at
    full), the rest at `body` x the colour."""
    prof = blunt_egg_profile(EGG_W, EGG_H, 7)
    segs = 8
    rot = Matrix.Rotation(yaw, 3, "Y") @ Matrix.Rotation(tilt, 3, "Z")
    c = Vector(centre)
    tris = 0

    def col_at(j, i):
        on = (j == 4 and i % 2 == 0) or (j == 3 and i % 2 == 1)
        if on:
            return band if band else colour
        return tuple(x * body for x in colour)
    rows = []
    for j, (r, y) in enumerate(prof):
        row = []
        for i in range(segs + 1):
            a = 2 * math.pi * i / segs
            row.append(c + rot @ Vector((r * math.sin(a), y, r * math.cos(a))))
        rows.append(row)
    for j in range(len(prof) - 1):
        for i in range(segs):
            p = [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
            n = (p[1] - p[0]).cross(p[3] - p[0])
            if cull and cull(sum(p, Vector()) / 4, n):
                continue
            cols = [col_at(j, i), col_at(j, i + 1), col_at(j + 1, i + 1), col_at(j + 1, i)]
            if prof[j][0] == 0:
                m.face([p[0], p[2], p[3]], None, [cols[0], cols[2], cols[3]]); tris += 1
            elif prof[j + 1][0] == 0:
                m.face(p[:3], None, cols[:3]); tris += 1
            else:
                m.face(p, None, cols); tris += 2
    return tris


def build_egg():
    m = Mesh("Egg")
    egg_faces(m, (0, 0, 0), (1.0, 1.0, 1.0), body=.78)     # loose: body x .78, band x 1 (Color sets the type)
    return m.build(weld=True)


def pile_layout():
    """18 baked eggs heaped in the globe's bottom and 6 loose ones on top (machine-local centres)."""
    rnd = random.Random(7)
    out = []
    # Fable render R1: 9 at 1.15, 6 at .80, 3 at .40 (touching the glass at the front), top of the heap near 5.6.
    y0 = GLOBE_BOTTOM + .62
    for k in range(9):
        a = 2 * math.pi * k / 9 + .2
        out.append((1.12 * math.sin(a), y0, 1.12 * math.cos(a)))
    for k in range(6):
        a = 2 * math.pi * k / 6 + .6
        out.append((.80 * math.sin(a), y0 + .62, .80 * math.cos(a)))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 1.1
        out.append((.40 * math.sin(a), y0 + 1.18, .40 * math.cos(a)))
    loose = []
    for k in range(6):                                 # loose on top, front-weighted
        a = 2 * math.pi * k / 6 + .3
        loose.append((.65 * math.sin(a) + rnd.uniform(-.05, .05), y0 + 1.62 + rnd.uniform(0, .1), .65 * math.cos(a) + .1))
    return out, loose


def build_pile(layout):
    m = Mesh("EggPile")
    rnd = random.Random(11)
    order = MIX[:]
    rnd.shuffle(order)
    colours = []
    tris = 0
    for k, c in enumerate(layout):
        kind = order[k]
        colours.append(kind)
        col = lin(hexrgb(EGG_TYPES[kind]))
        tilt = rnd.uniform(-.5, .5)
        # Whole eggs: a cull on face normals took fronts as well (holes); 18 x 96 is inside the budget.
        band = tuple(col[i] * .5 + lin(CREAM_BAND)[i] * .5 for i in range(3))   # 50 percent toward cream
        tris += egg_faces(m, c, col, tilt=tilt, yaw=rnd.uniform(0, 6.28), band=band, body=1.0)
    return m.build(weld=True), order    # welded per egg, so the eggs shade smooth


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


def material(name, image=None, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    if image:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mat.node_tree.links.new(tex.outputs["Color"], mix.inputs[6])
        mat.node_tree.links.new(attr.outputs["Color"], mix.inputs[7])
        mat.node_tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    else:
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = .55
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
    return mat


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    body, spots = build_body()
    globe = build_globe()
    dial = build_dial()
    # The dial's face must point out (+Z machine-local = -y in Blender): Roblox culls back faces.
    front = [poly for poly in dial.data.polygons if (poly.center.y * -1) > .25 and abs(poly.normal.y) > .5]
    outward = sum(1 for poly in front if -poly.normal.y > 0)
    assert front and outward / len(front) > .95, ("dial front faces point inward", outward, len(front))
    sprout = build_sprout()
    egg = build_egg()
    layout, loose = pile_layout()
    pile, order = build_pile(layout)
    # Dial sits on the base's front surface at 1.95 up; sprout on the cap.
    dial_z = base_radius_at(DIAL_CENTRE.y) * BASE_DEPTH - .02
    dial_pos = [0.0, DIAL_CENTRE.y, round(dial_z, 4)]
    sprout_pos = [0.0, 7.08, 0.0]
    parts = []
    objs = [(body, "Body"), (globe, "Globe"), (dial, "Dial"), (sprout, "Sprout"), (pile, "EggPile"), (egg, "Egg")]
    for obj, name in objs:
        obj.name = obj.data.name = "EggMachine_" + name
    for obj, name in objs:
        # Dial, sprout and egg are built about their own pivot: their local bounds centre from that pivot.
        c, size = centred(obj)
        entry = {"name": obj.name, "part": name, "tris": tris(obj), "size": size, "hash": digest(obj)}
        if name in ("Dial", "Sprout", "Egg"):
            entry["pivotToCentre"] = c
        else:
            entry["center"] = c
        parts.append(entry)
    total = sum(p["tris"] for p in parts) + 6 * next(p["tris"] for p in parts if p["part"] == "Egg")  # 1 dropped + 6 loose
    assert total <= TRI_CAP, ("triangles", total)
    loose_kinds = MIX[18:] if False else None
    rnd = random.Random(11)
    order_all = MIX[:]
    rnd.shuffle(order_all)
    manifest = {
        "note": "Generated by scripts/build_egg_machine.py. Machine-local Roblox studs: origin on the ground at the base's "
                "centre, +Z the machine's front (EGG-CORNER-LOOK 2). Roblox imports each mesh turned by pi about Y.",
        "size": [4.2, 7.2, 3.8],
        "parts": parts,
        "pivots": {"Dial": dial_pos, "Sprout": sprout_pos},
        "dialFace": [0, 0, 1],
        "loose": [{"at": [round(v, 4) for v in p], "type": order_all[18 + k]} for k, p in enumerate(loose)],
        "pileTypes": order_all[:18],
        "cup": spots["cup"], "chute": {"top": [round(v, 4) for v in spots["chuteTop"]], "end": [round(v, 4) for v in spots["chuteEnd"]]},
        "light": [0.0, 5.0, 0.0],
        "dropScale": round(DROP_SCALE, 4),
        "eggTypes": EGG_TYPES,
        "triangles": total,
    }
    bpy.ops.object.select_all(action="DESELECT")
    for obj, _ in objs:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "egg-machine.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                             colors_type="SRGB")
    (OUT / "egg-machine-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("EGG MACHINE", total, "tris;", ", ".join(f"{p['part']} {p['tris']}" for p in parts))
    if "--render" in sys.argv:
        render(objs, dial_pos, sprout_pos, loose, egg)


def render(objs, dial_pos, sprout_pos, loose, egg):
    """Place the pivoted parts and the loose eggs, then render front, three-quarter and from the path mouth."""
    RENDERS.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.load(str(TEXTURE))
    textured = material("Textured", image)
    plain = material("Plain")
    glass = material("Glass", alpha=.22)
    by = {name: obj for obj, name in objs}
    for name in ("Body", "Dial"):
        by[name].data.materials.append(textured)
    for name in ("Sprout", "EggPile", "Egg"):
        by[name].data.materials.append(plain)
    by["Globe"].data.materials.append(glass)
    # Parts built about their pivot: move them to place (Blender axes).
    d = by["Dial"]
    d.location = bl(dial_pos) + d.location
    s = by["Sprout"]
    s.location = bl(sprout_pos) + s.location
    rnd = random.Random(11)
    order = MIX[:]
    rnd.shuffle(order)
    for k, p in enumerate(loose):
        e = by["Egg"].copy()
        e.data = by["Egg"].data.copy()
        col = lin(hexrgb(EGG_TYPES[order[18 + k]]))
        attr = e.data.color_attributes["Col"]
        for item in attr.data:
            v = item.color
            item.color = (v[0] * col[0], v[1] * col[1], v[2] * col[2], 1.0)
        e.location = bl(p)
        e.rotation_euler = (rnd.uniform(-.3, .3), rnd.uniform(-.3, .3), 0)
        bpy.context.scene.collection.objects.link(e)
    by["Egg"].hide_render = True
    # ground, light, camera
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (.18, .4, .14, 1)
    ground.data.materials.append(gm)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.5
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.context.scene.collection.objects.link(so)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.55, .75, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .4
    bpy.context.scene.world = world
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 960, 960
    try:
        scene.view_settings.view_transform = "Standard"     # Fable render R1: so the hex values can be judged
    except TypeError:
        pass
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = bl((0, 3.6, 0))
    # the path mouth (-20, 12) seen from M (-44, 4) facing (-26, 7): about 9 degrees off the front
    for label, angle, dist, height in (("front", 0, 13, 4.2), ("three-quarter", 38, 13, 5.0), ("path-mouth", 9, 26, 5.0)):
        a = math.radians(angle)
        eye = bl((dist * math.sin(a), height, dist * math.cos(a)))
        cam.location = eye
        direction = target - eye
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(RENDERS / f"render-{label}.png")
        bpy.ops.render.render(write_still=True)
    print("EGG MACHINE renders in", RENDERS)


main()
