"""Pet Park playground equipment (slice K2, 2026-11-13). Original low-poly models, Astra art direction.

Run in BACKGROUND Blender only (deterministic, re-runnable; wipes and rebuilds the scene):
  blender.exe --factory-startup -b --python scripts/build_park_equipment.py            # build + export + renders
  blender.exe --factory-startup -b --python scripts/build_park_equipment.py -- --no-render

Writes
  assets/art-source/park/park.blend      source scene (collection Export = the uploaded meshes, Preview = layout,
                                          scale figures and cameras; nothing in Preview is exported)
  assets/park/park-equipment.fbx         ONE Model upload: every mesh a separately named object
  assets/park/palette-park.png           flat-colour palette (8 x 8 swatches of 32 px); every face's UVs sit
                                          inside one swatch, so the same image is the TextureID of every MeshPart
  assets/park/park-manifest.json         mesh list (Roblox size, tris, role, pivot), anchors, layout, colliders
  artifacts/pet-park-2026-11-13/art/*.png  dusk preview renders

Look: chunky, rounded, toy-like; marble/white trim, warm wood, pastel accents, read at dusk. Same family as the
island's benches and stations (marble end pieces + warm orange wood), with pastel paint and gold/star accents.

Axes and units: 1 Blender unit = 1 stud, exported like the world meshes (axis_forward=-Z, axis_up=Y,
global_scale=1, apply_unit_scale). Blender (x, y, z) = Roblox (x, z, -y). Every group's FRONT is Blender -Y =
Roblox +Z (the Bear rig's front is +Z too). Blender origins sit at the pivots, but Roblox recentres every mesh on
its bounds, so the manifest gives each mesh's `pivotFromCenter` (set MeshPart.PivotOffset = CFrame.new(it)) and
`offset` (where that pivot sits in its group's root frame).
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "assets", "art-source", "park")
OUT = os.path.join(ROOT, "assets", "park")
ART = os.path.join(ROOT, "artifacts", "pet-park-2026-11-13", "art")
NO_RENDER = "--no-render" in sys.argv

# ---------------------------------------------------------------------------------------------------------------
# Palette: dusk-graded PICO-8-ish swatches. Slot i: column i % 8, row i // 8 from the BOTTOM in UV space.
PALETTE = [
    ("marble", "#F4EFF5"), ("marble_d", "#DCD2E4"), ("white", "#FFFFFF"), ("wood", "#C97538"),
    ("wood_d", "#99552E"), ("wood_l", "#E39A5C"), ("pink", "#FF8DB6"), ("pink_d", "#E9578F"),
    ("mint", "#76E0AE"), ("mint_d", "#3FB98A"), ("aqua", "#5ECBF0"), ("aqua_d", "#2E9FD0"),
    ("lilac", "#AE97FF"), ("lilac_d", "#8068E0"), ("butter", "#FFDA5C"), ("butter_d", "#F5C443"),
    ("gold", "#F2B62E"), ("sand", "#F8E6BC"), ("sand_d", "#E9C890"), ("sand_w", "#C99B67"),
    ("leaf", "#3EAE4B"), ("leaf_d", "#25873B"), ("rope", "#FFF1D2"), ("red", "#F25A5E"),
    ("glow", "#FFE68A"), ("sand_c", "#EFC27F"), ("sand_k", "#DDA262"),
]
SLOT = {k: i for i, (k, _) in enumerate(PALETTE)}
SIDE, PX = 8, 32

# Preview-only colours (scale figures, lawn); never exported.
PREVIEW_COL = {"bear": "#FFFFFF", "bear_2": "#A8A5AE", "bear_face": "#2A2226", "avatar": "#8C94A8",
               "avatar_head": "#F2D3B3", "grass": "#3FAE45", "path": "#E79A62", "label": "#FFFFFF"}


def srgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def lin(c):
    return tuple(((v + .055) / 1.055) ** 2.4 if v > .04045 else v / 12.92 for v in c)


def rb(v):
    """Blender vector -> Roblox [x, y, z] (rounded)."""
    return [round(v[0], 3) + 0.0, round(v[2], 3) + 0.0, round(-v[1], 3) + 0.0]


# ---------------------------------------------------------------------------------------------------------------
# Geometry helpers. A Builder gathers primitives (each with a colour key) into one mesh.

def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(rx=0.0, ry=0.0, rz=0.0):
    return (Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(ry), 4, "Y")
            @ Matrix.Rotation(math.radians(rx), 4, "X"))


def S(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1.0))


class Builder:
    def __init__(self):
        self.v, self.f, self.c, self.s = [], [], [], []

    def add(self, bm, col, mat=None, smooth=False):
        if mat is not None:
            bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
        bm.verts.index_update()
        base = len(self.v)
        self.v += [v.co.copy() for v in bm.verts]
        for face in bm.faces:
            self.f.append(tuple(base + v.index for v in face.verts))
            self.c.append(col(face) if callable(col) else col)
            self.s.append(smooth)
        bm.free()
        return self

    def tris(self):
        return sum(len(f) - 2 for f in self.f)


def bm_box(sx, sy, sz, chamfer=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if chamfer > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=chamfer, offset_type="OFFSET", segments=1, profile=.5,
                        affect="EDGES", clamp_overlap=True)
    return bm


def bm_cyl(r, h, segs, r2=None):
    """Cylinder/frustum along Z, centred at the origin."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    return bm


def bm_sphere(r, u, v):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    return bm


def bm_from(verts, faces, recalc=True):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def bm_prism(poly, z0, z1, bottom=True):
    """Extrude a CCW 2D polygon from z0 to z1 (walls outward, top +Z)."""
    n = len(poly)
    verts = [(x, y, z0) for x, y in poly] + [(x, y, z1) for x, y in poly]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(range(n, 2 * n)))
    if bottom:
        faces.append(tuple(reversed(range(n))))
    return bm_from(verts, faces, recalc=False)


def stadium(length, width, cap_segs=3):
    """CCW stadium outline along X (rounded ends)."""
    r = width / 2
    hx = length / 2 - r
    pts = []
    for i in range(cap_segs + 1):          # right cap, -90 -> +90
        a = -math.pi / 2 + math.pi * i / cap_segs
        pts.append((hx + r * math.cos(a), r * math.sin(a)))
    for i in range(cap_segs + 1):          # left cap, +90 -> 270
        a = math.pi / 2 + math.pi * i / cap_segs
        pts.append((-hx + r * math.cos(a), r * math.sin(a)))
    return pts


def star(r_out, r_in, points=5, rot=90.0):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot) + math.pi * i / points
        r = r_out if i % 2 == 0 else r_in
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def rod(b, p0, p1, r, segs, col, smooth=False):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    b.add(bm_cyl(r, d.length, segs), col, Matrix.Translation((p0 + p1) / 2) @ rot, smooth)


def ball_cap(b, p, r, col, u=6, v=4):
    b.add(bm_sphere(r, u, v), col, Matrix.Translation(p), True)


# ---------------------------------------------------------------------------------------------------------------
# Equipment. Each function returns {mesh_name: (Builder, origin_in_group_blender)} plus anchors (Blender coords,
# relative to the group root at ground level).

GROUPS = {}


def group(name, layout, yaw, front_note):
    GROUPS[name] = {"meshes": {}, "anchors": {}, "layout": layout, "yaw": yaw, "front": front_note, "colliders": []}
    return GROUPS[name]


def mesh(g, name, builder, origin, role, extra=None):
    g["meshes"][name] = {"b": builder, "origin": Vector(origin), "role": role, "extra": extra or {}}


def collider(g, center, size, pitch=0.0):
    g["colliders"].append({"center": rb(center), "size": [round(size[0], 3), round(size[2], 3), round(size[1], 3)],
                           "pitchDeg": round(pitch, 2)})


# --- 1. Swing set ------------------------------------------------------------------------------------------------
BAR_Z, SWING_X, ROPE_LEN, SEAT_T = 4.2, 1.35, 3.12, .16


def build_swing():
    g = group("SwingSet", (-7.5, 4.0), 0.0, "swings move along Roblox Z (front/back); seats face +Z")
    b = Builder()
    b.add(bm_cyl(.21, 6.7, 8), "pink", T(0, 0, BAR_Z) @ R(ry=90))
    for sx in (-1, 1):
        ball_cap(b, (sx * 3.42, 0, BAR_Z), .3, "gold")
        x = sx * 2.95
        for sy in (-1, 1):
            rod(b, (x, sy * 1.35, 0.1), (x, sy * .1, BAR_Z), .17, 6, "wood")
            b.add(bm_box(.62, .62, .26), "marble", T(x, sy * 1.35, .13))
        rod(b, (x, -.9, 1.45), (x, .9, 1.45), .1, 6, "wood_d")
        for k in (-1, 1):                         # rope brackets either side of each swing pivot
            b.add(bm_box(.16, .5, .5, .03), "gold", T(sx * SWING_X + k * .47, 0, BAR_Z))
    mesh(g, "Park_SwingFrame", b, (0, 0, 0), "static")
    collider(g, (-2.95, 0, 2.1), (.5, 2.9, 4.2))
    collider(g, (2.95, 0, 2.1), (.5, 2.9, 4.2))
    for tag, sx, col in (("A", -1, "aqua"), ("B", 1, "pink")):
        s = Builder()
        for k in (-1, 1):
            rod(s, (k * .47, 0, -.05), (k * .47, 0, -ROPE_LEN + .02), .05, 4, "rope")
            s.add(bm_box(.12, .12, .14, .02), "gold", T(k * .47, 0, -ROPE_LEN + .05))
        s.add(bm_box(1.2, .62, SEAT_T, .05), col, T(0, 0, -ROPE_LEN - SEAT_T / 2 + .03))
        s.add(bm_box(1.0, .5, .05), col + "_d", T(0, 0, -ROPE_LEN - SEAT_T + .015))
        pivot = Vector((sx * SWING_X, 0, BAR_Z))
        seat_top = -ROPE_LEN + .03
        mesh(g, "Park_Swing" + tag, s, pivot, "swing",
             {"axis": "X", "maxSwingDeg": 32, "seatFromPivot": rb((0, 0, seat_top))})
        g["anchors"]["swing%s_seat" % tag] = rb(pivot + Vector((0, 0, seat_top)))
        g["anchors"]["swing%s_approach" % tag] = rb(pivot + Vector((0, -1.7, -BAR_Z)))
    return g


# --- 2. Slide ----------------------------------------------------------------------------------------------------
PLAT_Z, PLAT_T = 2.4, .22
CHUTE_Y0, CHUTE_Y1, CHUTE_Z1 = -.95, -6.0, .34
FLOOR_T, WALL_H, IN_W, OUT_W = .12, .32, 1.2, 1.44


def chute_point(t):
    z0 = PLAT_Z + PLAT_T / 2
    y = CHUTE_Y0 + (CHUTE_Y1 - CHUTE_Y0) * t
    z = CHUTE_Z1 + (z0 - CHUTE_Z1) * (.5 + .5 * math.cos(math.pi * t))
    return Vector((0, y, z))


def build_slide():
    g = group("Slide", (5.0, 5.5), -90.0, "climb at the back (Roblox -Z), slide toward the front (+Z)")
    b = Builder()
    b.add(bm_box(1.95, 1.95, PLAT_T, .05), "wood", T(0, 0, PLAT_Z))
    for x in (-.85, .85):
        for y in (-.85, .85):
            rod(b, (x, y, 0), (x, y, 4.05), .14, 6, "wood")
            b.add(bm_box(.42, .42, .2), "marble", T(x, y, .1))
        b.add(bm_box(.14, 1.75, .36, .04), "marble", T(x, 0, PLAT_Z + PLAT_T / 2 + .18))
    roof = bm_cyl(1.62, 1.05, 4, r2=0.0)
    b.add(roof, "pink", T(0, 0, 4.05 + .525) @ R(rz=45))
    b.add(bm_cyl(1.66, .16, 4), "pink_d", T(0, 0, 4.06) @ R(rz=45))
    ball_cap(b, (0, 0, 5.15), .2, "gold")
    # Ladder at the back (+Y): two rails, five mint rungs.
    lb, lt = Vector((0, 2.0, 0)), Vector((0, .98, PLAT_Z + .1))
    for x in (-.62, .62):
        rod(b, (x, lb.y, 0), (x, lt.y, lt.z + .55), .09, 6, "wood")
    for i in range(5):
        t = (i + 1) / 6
        p = lb.lerp(lt, t)
        rod(b, (-.62, p.y, p.z), (.62, p.y, p.z), .07, 6, "aqua")
    # Chute: thick U extruded along an S curve (flat at the top lip and at the run-out).
    prof = [(-OUT_W / 2, WALL_H), (-OUT_W / 2, -FLOOR_T), (OUT_W / 2, -FLOOR_T), (OUT_W / 2, WALL_H),
            (IN_W / 2, WALL_H), (IN_W / 2, 0), (-IN_W / 2, 0), (-IN_W / 2, WALL_H)]
    n, m = 10, len(prof)
    verts, faces = [], []
    for i in range(n + 1):
        t = i / n
        p = chute_point(t)
        tan = (chute_point(min(1, t + .01)) - chute_point(max(0, t - .01))).normalized()
        nrm = Vector((1, 0, 0)).cross(tan).normalized()
        if nrm.z < 0:
            nrm = -nrm
        verts += [p + Vector((px, 0, 0)) + nrm * pz for px, pz in prof]
    for i in range(n):
        for j in range(m):
            a, c = i * m + j, i * m + (j + 1) % m
            faces.append((a, c, c + m, a + m))
    faces.append(tuple(range(m)))
    faces.append(tuple(range(n * m, n * m + m)))

    def chute_col(face):
        nz = face.normal.z
        cz = face.calc_center_median()
        if nz < -.3:
            return "butter_d"
        if abs(face.normal.x) > .7 and abs(cz.x) > IN_W / 2 + .05:
            return "butter_d"
        return "butter"
    b.add(bm_from(verts, faces), chute_col)
    for x in (-.5, .5):                         # supports under the chute
        p = chute_point(.58)
        rod(b, (x, p.y, 0), (x, p.y, p.z - FLOOR_T - .02), .1, 6, "wood")
        b.add(bm_box(.34, .34, .16), "marble", T(x, p.y, .08))
    pe = chute_point(1.0)
    b.add(bm_box(1.3, .5, pe.z - FLOOR_T, .04), "marble", T(0, pe.y + .15, (pe.z - FLOOR_T) / 2))
    mesh(g, "Park_Slide", b, (0, 0, 0), "static")
    collider(g, (0, 0, PLAT_Z / 2 + .3), (2.0, 2.0, PLAT_Z + .6))
    pts = [chute_point(i / 6) for i in range(7)]
    for i in range(6):
        a, c = pts[i], pts[i + 1]
        mid = (a + c) / 2 - Vector((0, 0, FLOOR_T / 2))
        d = c - a
        collider(g, mid, (OUT_W, d.length, FLOOR_T + .05), math.degrees(math.atan2(d.z, -d.y)))
    A = g["anchors"]
    A["ladderBottom"] = rb((0, 2.55, 0))
    A["ladderTop"] = rb((0, .55, PLAT_Z + PLAT_T / 2))
    A["platform"] = rb((0, 0, PLAT_Z + PLAT_T / 2))
    A["chuteTop"] = rb(chute_point(0))
    A["chuteEnd"] = rb(chute_point(1))
    A["landing"] = rb((0, CHUTE_Y1 - 1.2, 0))
    A["chutePath"] = [rb(chute_point(i / 10)) for i in range(11)]
    A["ladderRungs"] = [rb(lb.lerp(lt, (i + 1) / 6)) for i in range(5)]
    return g


# --- 3. See-saw ----------------------------------------------------------------------------------------------------
PIVOT_Z, BEAM_HALF, SEAT_X = 1.0, 3.1, 2.62


def build_seesaw():
    g = group("SeeSaw", (-1.0, -6.3), 0.0, "beam along Roblox X, tilts about Roblox Z; seats face inward")
    b = Builder()
    b.add(bm_box(1.3, 1.5, .26, .07), "marble", T(0, 0, .13))
    for y in (-.48, .48):
        b.add(bm_box(.34, .24, 1.05, .05), "wood", T(0, y, .26 + .5))
        ball_cap(b, (0, y * 1.32, PIVOT_Z), .13, "gold")
    rod(b, (0, -.66, PIVOT_Z), (0, .66, PIVOT_Z), .08, 6, "gold")
    mesh(g, "Park_SeeSawBase", b, (0, 0, 0), "static")
    collider(g, (0, 0, .55), (1.3, 1.5, 1.1))
    beam = Builder()
    beam.add(bm_box(BEAM_HALF * 2, .56, .16, .05), "wood", T(0, 0, .17))
    beam.add(bm_box(.62, .62, .16, .05), "mint", T(0, 0, .02))
    for sx, col in ((-1, "pink"), (1, "aqua")):
        beam.add(bm_box(.8, .66, .16, .06), col, T(sx * SEAT_X, 0, .33))
        beam.add(bm_box(.3, .5, .1, .03), "wood_d", T(sx * (BEAM_HALF - .2), 0, .04))
        hx = sx * (SEAT_X - .58)
        for y in (-.22, .22):
            rod(beam, (hx, y, .25), (hx, y, .78), .045, 5, "gold")
        rod(beam, (hx, -.27, .78), (hx, .27, .78), .06, 6, col + "_d")
    seat_top = .33 + .08
    mesh(g, "Park_SeeSawBeam", beam, (0, 0, PIVOT_Z), "beam",
         {"axis": "Z", "maxTiltDeg": 17, "seatAFromPivot": rb((-SEAT_X, 0, seat_top)),
          "seatBFromPivot": rb((SEAT_X, 0, seat_top))})
    A = g["anchors"]
    A["pivot"] = rb((0, 0, PIVOT_Z))
    A["seatA"] = rb((-SEAT_X, 0, PIVOT_Z + seat_top))
    A["seatB"] = rb((SEAT_X, 0, PIVOT_Z + seat_top))
    A["seatAFacing"] = "+X (toward the fulcrum)"
    A["seatBFacing"] = "-X (toward the fulcrum)"
    A["approachA"] = rb((-SEAT_X - .3, -1.1, 0))
    A["approachB"] = rb((SEAT_X + .3, -1.1, 0))
    return g


# --- 4. Sandbox + castle stages + toys ------------------------------------------------------------------------------
SB_OUT, SB_H, SB_T, SAND_Z = 4.6, .5, .32, .3


def build_sandbox():
    g = group("Sandbox", (-9.0, -3.4), 0.0, "square; pets dig on the left/right of the castle facing it")
    b = Builder()
    half = SB_OUT / 2 - SB_T / 2
    for k in (-1, 1):
        b.add(bm_box(SB_OUT - .5, SB_T, SB_H, .05), "wood", T(0, k * half, SB_H / 2))
        b.add(bm_box(SB_T, SB_OUT - .5, SB_H, .05), "wood", T(k * half, 0, SB_H / 2))
    for x in (-half, half):
        for y in (-half, half):
            b.add(bm_box(.52, .52, .62, .08), "marble", T(x, y, .31))
            ball_cap(b, (x, y, .72), .16, "pink")
    # Sand: a gently bumpy 5 x 5 grid inside the frame, with a few darker damp cells.
    w, n = SB_OUT - 2 * SB_T + .04, 5
    verts, faces = [], []
    for i in range(n + 1):
        for j in range(n + 1):
            x, y = -w / 2 + w * i / n, -w / 2 + w * j / n
            edge = i in (0, n) or j in (0, n)
            z = SAND_Z if edge else SAND_Z + .05 * math.sin(i * 1.7 + j * .9) + .03 * math.cos(j * 2.3)
            verts.append((x, y, z))
    for i in range(n):
        for j in range(n):
            a = i * (n + 1) + j
            faces.append((a, a + n + 1, a + n + 2, a + 1))
    damp = {(1, 3), (3, 1), (4, 4), (0, 2)}
    cells = iter(range(n * n))

    def sand_col(face):
        k = next(cells)
        return "sand_d" if (k // n, k % n) in damp else "sand"
    b.add(bm_from(verts, faces, recalc=False), sand_col)
    mesh(g, "Park_SandboxFrame", b, (0, 0, 0), "static")
    for k in (-1, 1):
        collider(g, (0, k * half, SB_H / 2), (SB_OUT, SB_T, SB_H))
        collider(g, (k * half, 0, SB_H / 2), (SB_T, SB_OUT, SB_H))

    def skirt(c, r):
        c.add(bm_cyl(r, .12, 8, r2=r * .82), "sand_d", T(0, 0, .06))
    # Castle body is packed (darker) sand with caramel caps so it separates from the pale sand fill.

    def turret(c, x, y, r, h, z0=0.0, crenels=True, cone=False, col="sand_c"):
        c.add(bm_cyl(r, h, 8), col, T(x, y, z0 + h / 2))
        if cone:
            c.add(bm_cyl(r * 1.1, r * 1.5, 8, r2=0.0), "sand_k", T(x, y, z0 + h + r * .75))
        elif crenels:
            for i in range(4):
                a = math.tau * i / 4 + math.pi / 4
                c.add(bm_box(r * .55, r * .55, .14), "sand_k",
                      T(x + math.cos(a) * r * .72, y + math.sin(a) * r * .72, z0 + h + .07))

    # Stage 1: a patted mound with a pink shell on top.
    c1 = Builder()
    c1.add(bm_cyl(.72, .18, 8, r2=.58), "sand_c", T(0, 0, .09))
    c1.add(bm_cyl(.58, .2, 8, r2=.32), "sand_c", T(0, 0, .28))
    c1.add(bm_cyl(.32, .12, 8, r2=.1), "sand_k", T(0, 0, .44))
    c1.add(bm_sphere(.11, 5, 3), "pink", T(.08, -.06, .52) @ S(1, 1, .6))
    # Stage 2: block base and two front turrets.
    c2 = Builder()
    skirt(c2, .78)
    c2.add(bm_box(1.0, .9, .46, .06), "sand_c", T(0, 0, .12 + .23))
    for x in (-.45, .45):
        turret(c2, x, -.4, .2, .72, .12, cone=True)
    c2.add(bm_box(.26, .06, .26, .02), "sand_w", T(0, -.46, .25))
    # Stage 3: full castle with four turrets, a keep and a pink flag.
    c3 = Builder()
    skirt(c3, .95)
    c3.add(bm_box(1.22, 1.22, .52, .06), "sand_c", T(0, 0, .12 + .26))
    for x in (-.58, .58):
        for y in (-.58, .58):
            turret(c3, x, y, .24, .92, .12, cone=(y < 0))
    c3.add(bm_box(.62, .62, .55, .04), "sand_c", T(0, 0, .64 + .275))
    for x in (-.22, .22):
        for y in (-.22, .22):
            c3.add(bm_box(.16, .16, .14), "sand_k", T(x, y, 1.19 + .07))
    c3.add(bm_box(.3, .06, .34, .02), "sand_w", T(0, -.62, .3))
    rod(c3, (0, 0, 1.19), (0, 0, 1.95), .03, 4, "gold")
    flag = [(0, 1.92), (0, 1.62), (.48, 1.77)]
    fv = [(x, y, z) for x, z in flag for y in (-.025, .025)]
    c3.add(bm_from(fv, [(0, 2, 4), (1, 5, 3), (0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 1, 0)]), "pink_d")
    sand_top = Vector((0, 0, SAND_Z + .02))
    for i, c in enumerate((c1, c2, c3), 1):
        mesh(g, "Park_Castle%d" % i, c, sand_top, "castleStage", {"stage": i})
    # Bucket and spade, resting in the back-right corner.
    t = Builder()
    t.add(bm_cyl(.19, .3, 8, r2=.25), "aqua", T(0, 0, .15))
    t.add(bm_cyl(.255, .05, 8), "aqua_d", T(0, 0, .3))
    rod(t, (-.24, 0, .3), (0, 0, .5), .025, 4, "gold")
    rod(t, (0, 0, .5), (.24, 0, .3), .025, 4, "gold")
    t.add(bm_box(.2, .28, .04, .01), "red", T(.42, -.1, .05) @ R(rz=20))
    rod(t, (.38, .06, .06), (.3, .42, .16), .03, 4, "butter")
    toys_at = Vector((1.15, 1.2, SAND_Z + .02))
    mesh(g, "Park_SandToys", t, toys_at, "static")
    A = g["anchors"]
    A["castle"] = rb(sand_top)
    A["spotA"] = rb((-1.05, -.15, SAND_Z + .02))
    A["spotB"] = rb((1.05, -.15, SAND_Z + .02))
    A["spotAFacing"] = "+X (toward the castle)"
    A["spotBFacing"] = "-X (toward the castle)"
    A["entry"] = rb((0, -SB_OUT / 2 - .8, 0))
    return g


# --- 5. Ball corner ------------------------------------------------------------------------------------------------
BALL_R = .42


def build_balls():
    g = group("BallCorner", (8.0, -4.6), 0.0, "round mat; star = the balls' home")
    m = Builder()
    m.add(bm_cyl(2.25, .08, 14), "marble", T(0, 0, .04))
    m.add(bm_cyl(1.95, .06, 14), "lilac", T(0, 0, .1))
    m.add(bm_prism(star(.62, .28), .1, .15, bottom=False), "butter")
    mesh(g, "Park_BallMat", m, (0, 0, 0), "static")
    for tag, (c1, c2), x in (("A", ("pink", "white"), -.75), ("B", ("aqua", "butter"), .75)):
        bb = Builder()
        k = [0]
        u = 8

        def stripe(face, c1=c1, c2=c2):
            cen = face.calc_center_median()
            if abs(cen.z) > BALL_R * .86:
                return c2
            a = math.atan2(cen.y, cen.x) % math.tau
            return c1 if int(a / (math.tau / u)) % 2 == 0 else c2
        bb.add(bm_sphere(BALL_R, u, 6), stripe, None, True)
        center = Vector((x, 0, .15 + BALL_R))
        mesh(g, "Park_Ball" + tag, bb, center, "ball", {"radius": BALL_R})
        g["anchors"]["ball%sHome" % tag] = rb(center)
    A = g["anchors"]
    A["matTop"] = rb((0, 0, .13))
    A["spotA"] = rb((-1.6, 0, .13))
    A["spotB"] = rb((1.6, 0, .13))
    A["soloSpot"] = rb((0, -1.2, .13))
    return g


# --- 6. Kerb segment + gateway post --------------------------------------------------------------------------------
KERB_LEN, KERB_W, KERB_H = 3.6, .9, .4


def build_kerb():
    g = group("Kerb", (0, 0), 0.0, "segment along Roblox X; instance around the ellipse (see layout.kerb)")
    k = Builder()
    k.add(bm_prism(stadium(KERB_LEN, KERB_W), 0, KERB_H, bottom=False), "marble")
    k.add(bm_prism(stadium(KERB_LEN - .3, KERB_W - .3), KERB_H, KERB_H + .1, bottom=False), "leaf")
    for x, col in ((-.85, "pink"), (.85, "butter")):
        k.add(bm_sphere(.17, 5, 3), col, T(x, 0, KERB_H + .15) @ S(1, 1, .6))
    mesh(g, "Park_KerbSegment", k, (0, 0, 0), "static")
    p = Builder()
    p.add(bm_cyl(.58, .3, 8), "marble_d", T(0, 0, .15) @ R(rz=22.5))
    p.add(bm_cyl(.37, 2.4, 8), "marble", T(0, 0, .3 + 1.2) @ R(rz=22.5))
    p.add(bm_cyl(.43, .14, 8), "gold", T(0, 0, 1.25) @ R(rz=22.5))
    p.add(bm_cyl(.52, .22, 8), "marble", T(0, 0, 2.81) @ R(rz=22.5))
    p.add(bm_cyl(.3, .18, 8, r2=.16), "gold", T(0, 0, 3.01) @ R(rz=22.5))
    mesh(g, "Park_GatePost", p, (0, 0, 0), "static")
    o = Builder()
    o.add(bm_sphere(.36, 8, 6), "glow", None, True)
    for i in range(5):
        a = math.radians(90 + 72 * i)
        d = Vector((math.cos(a), 0, math.sin(a)))
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        o.add(bm_cyl(.15, .34, 5, r2=0.0), "gold", Matrix.Translation(d * .44) @ rot)
    orb_z = 3.1 + .5
    mesh(g, "Park_GateStarOrb", o, (0, 0, orb_z), "orb",
         {"note": "mount above each Park_GatePost; suggested Material Neon or a PointLight, slow bob/spin"})
    g["anchors"]["gateOrbAbovePostBase"] = rb((0, 0, orb_z))
    return g


# --- 7. Bench ------------------------------------------------------------------------------------------------------
SEAT_TOP = 1.8


def build_bench():
    g = group("Bench", (0, 0), 0.0, "sitter faces Roblox +Z")
    b = Builder()
    for sx in (-1, 1):
        x = sx * 2.02
        b.add(bm_box(.36, 1.3, SEAT_TOP - .1, .1), "marble", T(x, 0, (SEAT_TOP - .1) / 2))
        b.add(bm_box(.36, .34, 1.45, .08), "marble", T(x, .5, SEAT_TOP + .62))
        b.add(bm_box(.46, 1.38, .12), "marble_d", T(x, 0, .06))
        ball_cap(b, (x, .5, SEAT_TOP + 1.42), .2, "pink")
    for y in (-.42, 0, .42):
        b.add(bm_box(3.72, .38, .14, .05), "wood", T(0, y, SEAT_TOP - .07))
    for z in (2.3, 2.8):
        b.add(bm_box(3.72, .14, .3, .05), "wood", T(0, .56, z) @ R(rx=-8))
    b.add(bm_box(3.5, .3, .12), "wood_d", T(0, 0, SEAT_TOP - .22))
    mesh(g, "Park_Bench", b, (0, 0, 0), "static")
    collider(g, (0, 0, (SEAT_TOP) / 2), (4.4, 1.3, SEAT_TOP))
    collider(g, (0, .56, SEAT_TOP + .62), (4.4, .3, 1.4))
    A = g["anchors"]
    A["seats"] = [{"center": rb((x, 0, SEAT_TOP - .1)), "size": [1.8, .2, 1.2]} for x in (-1.0, 1.0)]
    return g


# --- 8. Long bench (QA Q4 2026-11-13: one 5-seat bench by the entrance) ---------------------------------------------
LONG_SEATS, LONG_PITCH = 5, 1.75


def build_bench_long():
    """Same family as Park_Bench, stretched to five seats; a middle leg pair keeps the long seat from looking thin.
    Exported on its own (assets/park/park-bench-long.fbx) so the existing park meshes keep their asset ids."""
    g = group("BenchLong", (0, 0), 0.0, "sitter faces Roblox +Z; five seats along X")
    b = Builder()
    half = LONG_SEATS * LONG_PITCH / 2          # seat run: +-4.375
    post_x = half + .18
    for sx in (-1, 1):
        x = sx * post_x
        b.add(bm_box(.36, 1.3, SEAT_TOP - .1, .1), "marble", T(x, 0, (SEAT_TOP - .1) / 2))
        b.add(bm_box(.36, .34, 1.45, .08), "marble", T(x, .5, SEAT_TOP + .62))
        b.add(bm_box(.46, 1.38, .12), "marble_d", T(x, 0, .06))
        ball_cap(b, (x, .5, SEAT_TOP + 1.42), .2, "pink")
    for x in (-1.75, 1.75):                     # middle legs under the seat (no backrest post)
        b.add(bm_box(.3, 1.0, SEAT_TOP - .3, .06), "marble_d", T(x, 0, (SEAT_TOP - .3) / 2))
    run = 2 * half + .2
    for y in (-.42, 0, .42):
        b.add(bm_box(run, .38, .14, .05), "wood", T(0, y, SEAT_TOP - .07))
    for z in (2.3, 2.8):
        b.add(bm_box(run, .14, .3, .05), "wood", T(0, .56, z) @ R(rx=-8))
    b.add(bm_box(run - .2, .3, .12), "wood_d", T(0, 0, SEAT_TOP - .22))
    mesh(g, "Park_BenchLong", b, (0, 0, 0), "static")
    width = 2 * post_x + .46
    collider(g, (0, 0, (SEAT_TOP) / 2), (width - .1, 1.3, SEAT_TOP))
    collider(g, (0, .56, SEAT_TOP + .62), (width - .1, .3, 1.4))
    A = g["anchors"]
    A["seats"] = [{"center": rb(((i - (LONG_SEATS - 1) / 2) * LONG_PITCH, 0, SEAT_TOP - .1)), "size": [1.6, .2, 1.2]}
                  for i in range(LONG_SEATS)]
    return g


# ---------------------------------------------------------------------------------------------------------------
# Park layout (suggested, Roblox studs relative to the park centre; K1's ParkLayout is authoritative).
ELL_A, ELL_B, GATE_GAP = 15.0, 11.0, 4.6
GATES = (0.0, math.pi)


def ellipse_pt(th):
    return Vector((ELL_A * math.cos(th), ELL_B * math.sin(th), 0))


def kerb_layout():
    """Equal chords along the two arcs between the gateway gaps; segment centre + yaw (deg, Blender Z = Roblox Y)."""
    N = 4000
    ths = [i * math.tau / N for i in range(N + 1)]
    s = [0.0]
    for i in range(N):
        s.append(s[-1] + (ellipse_pt(ths[i + 1]) - ellipse_pt(ths[i])).length)
    total = s[-1]

    def th_at(dist):
        dist %= total
        lo, hi = 0, N
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if s[mid] < dist:
                lo = mid
            else:
                hi = mid
        return ths[lo]
    gate_s = [s[int(round(g / math.tau * N))] for g in GATES]
    segs, posts = [], []
    for gi in range(2):
        start = gate_s[gi] + GATE_GAP / 2
        end = gate_s[(gi + 1) % 2] - GATE_GAP / 2 + (total if gi == 1 else 0)
        arc = end - start
        n = max(1, math.ceil(arc / 3.35))
        for k in range(n):
            a = ellipse_pt(th_at(start + arc * k / n))
            c = ellipse_pt(th_at(start + arc * (k + 1) / n))
            m = (a + c) / 2
            d = c - a
            segs.append({"pos": rb(m), "yawDeg": round(math.degrees(math.atan2(d.y, d.x)), 2),
                         "chord": round(d.length, 3)})
        for dist in (start - .45, end + .45):
            p = ellipse_pt(th_at(dist))
            posts.append({"pos": rb(p)})
    return segs, posts


# ---------------------------------------------------------------------------------------------------------------
# Scene assembly.

def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for d in list(blk):
            blk.remove(d)


def palette_image():
    size = SIDE * PX
    img = bpy.data.images.new("palette-park", size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, (_, hx) in enumerate(PALETTE):
        col = srgb(hx)
        cx, cy = i % SIDE, i // SIDE
        for y in range(cy * PX, cy * PX + PX):
            for x in range(cx * PX, cx * PX + PX):
                o = (y * size + x) * 4
                px[o:o + 4] = [col[0], col[1], col[2], 1.0]
    for i in range(len(PALETTE), SIDE * SIDE):     # unused slots: neutral marble so stray UVs read as trim
        col = srgb("#F4EFF5")
        cx, cy = i % SIDE, i // SIDE
        for y in range(cy * PX, cy * PX + PX):
            for x in range(cx * PX, cx * PX + PX):
                o = (y * size + x) * 4
                px[o:o + 4] = [col[0], col[1], col[2], 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, "palette-park.png")
    img.file_format = "PNG"
    img.save()
    return img


def palette_material(img):
    mat = bpy.data.materials.new("Park_Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = .62
    return mat


def flat_material(name, hx, emit=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = lin(srgb(hx)) + (1.0,)
    bsdf.inputs["Roughness"].default_value = .7
    if emit:
        bsdf.inputs["Emission Color"].default_value = lin(srgb(hx)) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def make_object(name, b, coll, palette_mat=None, mats=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in b.v], [], b.f)
    me.validate(clean_customdata=False)
    if palette_mat is not None:
        me.materials.append(palette_mat)
        uv = me.uv_layers.new(name="UVMap")
        w = 1.0 / SIDE
        for poly, key in zip(me.polygons, b.c):
            i = SLOT[key]
            cu, cv = (i % SIDE + .5) * w, (i // SIDE + .5) * w
            nl = len(poly.loop_indices)
            for k, li in enumerate(poly.loop_indices):
                a = math.tau * k / nl
                uv.data[li].uv = (cu + .25 * w * math.cos(a), cv + .25 * w * math.sin(a))
    else:
        keys = sorted(set(b.c))
        for k in keys:
            me.materials.append(mats[k])
        for poly, key in zip(me.polygons, b.c):
            poly.material_index = keys.index(key)
    for poly, sm in zip(me.polygons, b.s):
        poly.use_smooth = sm
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    return obj


def bounds(me):
    xs = [v.co for v in me.vertices]
    lo = Vector([min(v[i] for v in xs) for i in range(3)])
    hi = Vector([max(v[i] for v in xs) for i in range(3)])
    return lo, hi


def place(obj_src, coll, loc, yaw=0.0, extra_rot=None):
    o = bpy.data.objects.new(obj_src.name + "_pv", obj_src.data)
    o.location = loc
    o.rotation_euler = (0, 0, math.radians(yaw))
    if extra_rot is not None:
        o.rotation_mode = "XYZ"
        o.rotation_euler = (extra_rot[0], extra_rot[1], math.radians(yaw) + extra_rot[2])
    coll.objects.link(o)
    return o


def group_matrix(layout, yaw):
    return Matrix.Translation((layout[0], layout[1], 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")


def bear_figure(b, loc, yaw=0.0, sit=False, lean=0.0):
    """Bear-rig stand-in (white body, grey ear insides) at garden size; loc = root (feet) or seat contact if sit."""
    M = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(lean, 4, "X")
    dz = -.22 if sit else 0.0

    def ell(c, size, col):
        b.add(bm_sphere(.5, 10, 7), col, M @ T(c[0], -c[2], c[1] + dz) @ S(size[0], size[2], size[1]), True)
    ell((0, .455, .085), (.6, .58, .64), "bear")
    ell((0, 1.01, .03), (.98, .76, .89), "bear")
    for x in (-.345, .345):
        ell((x, 1.33, 0), (.3, .3, .15), "bear")
        ell((x, 1.335, .05), (.18, .18, .07), "bear_2")
        ell((x * .62, 1.03, .42), (.16, .24, .09), "bear_face")
        ell((x * .48, .1 if not sit else .3, .08 if not sit else .38), (.3, .21, .53), "bear")
    ell((0, .85, .395), (.33, .24, .27), "bear_2")
    ell((0, .907, .516), (.1, .07, .06), "bear_face")


def avatar_figure(b, loc, yaw=0.0):
    M = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    for x in (-.5, .5):
        b.add(bm_box(.95, 1, 2), "avatar", M @ T(x, 0, 1))
        b.add(bm_box(.95, 1, 2), "avatar", M @ T(x * 3, 0, 3))
    b.add(bm_box(2, 1, 2), "avatar", M @ T(0, 0, 3))
    b.add(bm_box(1.2, 1.2, 1.2), "avatar_head", M @ T(0, 0, 4.6))


def setup_render(scene):
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    try:
        scene.eevee.taa_render_samples = 48
    except Exception:
        pass
    for attr, val in (("use_shadows", True), ("use_raytracing", False)):
        try:
            setattr(scene.eevee, attr, val)
        except Exception:
            pass
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except Exception:
        pass
    scene.view_settings.exposure = .15
    world = bpy.data.worlds.new("Dusk") if not scene.world else scene.world
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    sep = nt.nodes.new("ShaderNodeTexCoord")
    mapn = nt.nodes.new("ShaderNodeMapping")
    mapn.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
    nt.links.new(sep.outputs["Generated"], mapn.inputs["Vector"])
    nt.links.new(mapn.outputs["Vector"], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = lin(srgb("#FFC4B8")) + (1,)
    ramp.color_ramp.elements[1].color = lin(srgb("#F7A9C9")) + (1,)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    sun_data = bpy.data.lights.new("DuskSun", "SUN")
    sun_data.color = lin(srgb("#FFC58E"))
    sun_data.energy = 3.2
    sun_data.angle = math.radians(6)
    sun = bpy.data.objects.new("DuskSun", sun_data)
    sun.rotation_euler = (math.radians(62), 0, math.radians(-128))
    scene.collection.objects.link(sun)
    fill_data = bpy.data.lights.new("SkyFill", "SUN")
    fill_data.color = lin(srgb("#C9B8FF"))
    fill_data.energy = .55
    fill = bpy.data.objects.new("SkyFill", fill_data)
    fill.rotation_euler = (math.radians(35), 0, math.radians(60))
    try:
        fill_data.use_shadow = False
    except Exception:
        pass
    scene.collection.objects.link(fill)


def camera(scene, coll, name, loc, target, fov=None, lens=40):
    cd = bpy.data.cameras.new(name)
    if fov:
        cd.sensor_fit = "VERTICAL"
        cd.angle = math.radians(fov)
    else:
        cd.lens = lens
    cd.clip_end = 500
    cam = bpy.data.objects.new(name, cd)
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    coll.objects.link(cam)
    return cam


def render(scene, cam, path, w, h):
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def main():
    reset()
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(ART, exist_ok=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    exp = bpy.data.collections.new("Export")
    pv = bpy.data.collections.new("Preview")
    scene.collection.children.link(exp)
    scene.collection.children.link(pv)
    img = palette_image()
    pmat = palette_material(img)

    builders = [build_swing, build_slide, build_seesaw, build_sandbox, build_balls, build_kerb, build_bench, build_bench_long]
    for fn in builders:
        fn()

    # Export objects: one per unique mesh, laid out in a row (group roots 12 studs apart) for inspection.
    meshes_out, objects, total = [], {}, 0
    for gi, (gname, g) in enumerate(GROUPS.items()):
        row = Vector((gi * 12.0, 30.0, 0))
        for name, m in g["meshes"].items():
            b = m["b"]
            # Every builder is authored around its own origin (the pivot / base point), so the mesh data is
            # already in object space; the object just sits at its group offset.
            obj = make_object(name, b, exp, palette_mat=pmat)
            obj.location = row + m["origin"]
            obj.hide_render = True
            objects[name] = obj
            lo, hi = bounds(obj.data)
            ctr = (lo + hi) / 2
            tris = len(obj.data.polygons)
            total += tris
            size = hi - lo
            entry = {"name": name, "group": gname, "role": m["role"], "tris": tris,
                     "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],
                     "offset": rb(m["origin"]), "pivotFromCenter": rb(-ctr),
                     "baseFromCenter": round(ctr.z - lo.z, 3)}
            entry.update(m["extra"])
            meshes_out.append(entry)

    # ----- Preview layout (park) + showcase row (clean close-ups, far behind the overview camera) -----
    segs, posts = kerb_layout()
    mats = {k: flat_material("pv_" + k, h) for k, h in PREVIEW_COL.items()}
    figs = Builder()
    SWING_POSE = -24.0      # swing A swung forward (about +X), bear riding it
    TILT = 12.0             # see-saw tilt about Blender +Y (seat A up)

    def populate(gname, at, yaw, castle_stage=3):
        g = GROUPS[gname]
        G = group_matrix(at, yaw)

        def gp(v):
            return G @ Vector(v)

        def anc(key, idx=None):
            a = g["anchors"][key] if idx is None else g["anchors"][key][idx]
            return gp((a[0], -a[2], a[1]))
        for name, m in g["meshes"].items():
            if name.startswith("Park_Castle") and name != "Park_Castle%d" % castle_stage:
                continue
            rot = None
            if name == "Park_SeeSawBeam":
                rot = (0, math.radians(TILT), 0)
            if name == "Park_SwingA":
                rot = (math.radians(SWING_POSE), 0, 0)
            place(objects[name], pv, gp(m["origin"]), yaw, rot)
        if gname == "SwingSet":
            bear_figure(figs, anc("swingB_seat"), yaw=yaw, sit=True)
            piv = Vector((-SWING_X, 0, BAR_Z))
            seat = piv + Matrix.Rotation(math.radians(SWING_POSE), 3, "X") @ Vector((0, 0, BAR_Z - ROPE_LEN + .03 - BAR_Z))
            bear_figure(figs, gp(seat), yaw=yaw, sit=True, lean=math.radians(SWING_POSE))
        elif gname == "Slide":
            bear_figure(figs, anc("platform"), yaw=yaw)
            bear_figure(figs, anc("chutePath", 6), yaw=yaw, sit=True, lean=math.radians(20))
            bear_figure(figs, anc("ladderBottom"), yaw=yaw + 180)
        elif gname == "SeeSaw":
            piv = Vector((0, 0, PIVOT_Z))
            tilt = Matrix.Rotation(math.radians(TILT), 3, "Y")
            for sx, by in ((-1, 90), (1, -90)):
                bear_figure(figs, gp(piv + tilt @ Vector((sx * SEAT_X, 0, .41))), yaw=yaw + by, sit=True)
        elif gname == "Sandbox":
            bear_figure(figs, anc("spotA"), yaw=yaw + 90)
            bear_figure(figs, anc("spotB"), yaw=yaw - 90)
        elif gname == "BallCorner":
            bear_figure(figs, anc("spotA"), yaw=yaw + 90)
            bear_figure(figs, anc("spotB"), yaw=yaw - 90)

    for gname, g in GROUPS.items():
        if gname not in ("Kerb", "Bench", "BenchLong"):
            populate(gname, g["layout"], g["yaw"])
    for sgm in segs:
        place(objects["Park_KerbSegment"], pv, (sgm["pos"][0], -sgm["pos"][2], 0), sgm["yawDeg"])
    orb_z = objects["Park_GateStarOrb"].location.z
    for p in posts:
        x, y = p["pos"][0], -p["pos"][2]
        place(objects["Park_GatePost"], pv, (x, y, 0))
        place(objects["Park_GateStarOrb"], pv, (x, y, orb_z))
    bench_spots = [((-3.0, 8.4), 180.0), ((3.2, -8.6), 0.0)]
    for (x, y), yaw in bench_spots:
        place(objects["Park_Bench"], pv, (x, y, 0), yaw)
    avatar_figure(figs, (3.0, -14.5, 0), yaw=180)
    avatar_figure(figs, (12.2, .6, 0), yaw=-100)

    SHOW = {n: (i * 30.0, -220.0) for i, n in enumerate(["SwingSet", "Slide", "SeeSaw", "Sandbox", "BallCorner",
                                                          "Gate", "Stages"])}
    for gname in ("SwingSet", "Slide", "SeeSaw", "Sandbox", "BallCorner"):
        populate(gname, SHOW[gname], 0.0)
    for gname, dx in (("SwingSet", 4.6), ("Slide", 3.0), ("SeeSaw", 4.4), ("Sandbox", 3.6), ("BallCorner", 3.4)):
        avatar_figure(figs, (SHOW[gname][0] + dx + 3.5, SHOW[gname][1] + 4.0, 0), yaw=-160)
    gx, gy = SHOW["Gate"]
    for sx in (-1, 1):
        place(objects["Park_GatePost"], pv, (gx + sx * 2.3, gy, 0))
        place(objects["Park_GateStarOrb"], pv, (gx + sx * 2.3, gy, orb_z))
        for k in (0, 1):
            place(objects["Park_KerbSegment"], pv, (gx + sx * (2.3 + .45 + 1.6 + k * 3.3), gy, 0), 0.0)
    place(objects["Park_Bench"], pv, (gx + 1.0, gy + 4.5, 0), 180.0)
    avatar_figure(figs, (gx - 5.0, gy + 3.0, 0), yaw=-150)
    bear_figure(figs, (gx + .2, gy - .6, 0), yaw=-20)
    sx0, sy0 = SHOW["Stages"]
    slab = Builder()
    slab.add(bm_box(6.4, 2.6, .1, .04), "sand", T(sx0, sy0, .05))
    make_object("StageLineupSlab", slab, pv, palette_mat=pmat)
    for i in (1, 2, 3):
        place(objects["Park_Castle%d" % i], pv, (sx0 + (i - 2) * 2.1, sy0, .1))
    bear_figure(figs, (sx0 + 3.6, sy0 - .4, 0), yaw=40)
    make_object("ScaleFigures", figs, pv, mats=mats)
    lawn = Builder()
    lawn.add(bm_cyl(70, .1, 24), "grass", T(0, 0, -.05))
    lawn.add(bm_box(240, 40, .1), "grass", T(100, -222, -.05))
    make_object("Lawn", lawn, pv, mats=mats)

    # ----- Manifest -----
    tri_by = {m["name"]: m["tris"] for m in meshes_out}
    placed = (total - tri_by["Park_KerbSegment"] - tri_by["Park_GatePost"] - tri_by["Park_GateStarOrb"]
              - tri_by["Park_Bench"] + tri_by["Park_KerbSegment"] * len(segs)
              + (tri_by["Park_GatePost"] + tri_by["Park_GateStarOrb"]) * len(posts) + tri_by["Park_Bench"] * 2
              - tri_by["Park_Castle1"] - tri_by["Park_Castle2"])
    groups_out = {}
    for gname, g in GROUPS.items():
        groups_out[gname] = {"meshes": list(g["meshes"].keys()), "front": g["front"],
                             "suggestedPos": [g["layout"][0], 0, -g["layout"][1]], "suggestedYawDeg": g["yaw"],
                             "anchors": g["anchors"], "colliders": g["colliders"]}
    groups_out["Bench"]["suggested"] = [{"pos": [x, 0, -y], "yawDeg": yaw} for (x, y), yaw in bench_spots]
    del groups_out["Bench"]["suggestedPos"], groups_out["Bench"]["suggestedYawDeg"]
    del groups_out["Kerb"]["suggestedPos"], groups_out["Kerb"]["suggestedYawDeg"]
    del groups_out["BenchLong"]["suggestedPos"], groups_out["BenchLong"]["suggestedYawDeg"]
    groups_out["BenchLong"]["fbx"] = "assets/park/park-bench-long.fbx"
    manifest = {
        "note": ("Generated by scripts/build_park_equipment.py (slice K2). Units: studs. All vectors are Roblox "
                 "(x, y, z). size = MeshPart bounds. Roblox centres each mesh on its bounds: set "
                 "MeshPart.PivotOffset = CFrame.new(pivotFromCenter), then part:PivotTo(groupCFrame * "
                 "CFrame.new(offset) * motion). offset = the mesh's pivot in its group's root frame (root = ground "
                 "level centre of the group, front = +Z). Anchors are in the group root frame too. Texture: every "
                 "mesh uses palette-park.png as TextureID (flat swatches). Visual meshes: Anchored, CanCollide/"
                 "CanQuery/CanTouch=false; colliders = invisible Parts for players (pitchDeg rotates about X)."),
        "fbx": "assets/park/park-equipment.fbx",
        "texture": "assets/park/palette-park.png",
        "palette": {k: h for k, h in PALETTE},
        "trianglesUnique": total,
        "trianglesPlacedSuggestedLayout": placed,
        "meshes": meshes_out,
        "groups": groups_out,
        "layout": {
            "ellipse": {"radiusX": ELL_A, "radiusZ": ELL_B, "note": "suggested; K1 ParkLayout is authoritative"},
            "gateways": [{"angleDeg": round(math.degrees(t), 1), "gapStuds": GATE_GAP,
                          "center": rb(ellipse_pt(t))} for t in GATES],
            "kerb": {"mesh": "Park_KerbSegment", "segments": segs,
                     "rule": "equal chords between gateway gaps; segment yaw = chord direction; rounded ends overlap"},
            "gatePosts": {"mesh": "Park_GatePost", "orb": "Park_GateStarOrb", "posts": posts},
        },
        "scale": {"bearHeight": 1.39, "avatarHeight": 5.0, "benchSeatTop": SEAT_TOP,
                  "swingSeatTop": round(BAR_Z - ROPE_LEN + .03, 3), "slidePlatformTop": PLAT_Z + PLAT_T / 2,
                  "seesawPivot": PIVOT_Z},
    }
    with open(os.path.join(OUT, "park-manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)

    # ----- Export -----
    bpy.ops.object.select_all(action="DESELECT")
    fbx_options = dict(use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True,
                       use_mesh_modifiers=False, object_types={"MESH"}, add_leaf_bones=False, bake_anim=False,
                       path_mode="STRIP", mesh_smooth_type="FACE")
    # The long bench (QA Q4) ships as its own FBX so the uploaded park meshes keep their ids.
    separate = {"Park_BenchLong": "park-bench-long.fbx"}
    for name, o in objects.items():
        o.select_set(name not in separate)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "park-equipment.fbx"), **fbx_options)
    for name, fname in separate.items():
        bpy.ops.object.select_all(action="DESELECT")
        objects[name].select_set(True)
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, fname), **fbx_options)
    print("PARK unique tris", total, "placed", placed, "kerb segs", len(segs), "posts", len(posts))
    for m in meshes_out:
        print("  %-20s %-11s tris %4d size %s" % (m["name"], m["role"], m["tris"], m["size"]))

    # ----- Renders -----
    setup_render(scene)
    def sc(gname, off, tgt, lens):
        x, y = SHOW[gname]
        return (x + off[0], y + off[1], off[2]), (x + tgt[0], y + tgt[1], tgt[2]), lens
    shots = {
        "swing": sc("SwingSet", (5.5, -9.0, 4.0), (0, 0, 2.0), 32),
        "slide": sc("Slide", (7.0, -6.5, 4.2), (0, -2.4, 1.8), 30),
        "seesaw": sc("SeeSaw", (2.2, -7.0, 2.8), (0, 0, .9), 34),
        "sandbox": sc("Sandbox", (2.8, -6.6, 4.6), (0, 0, .5), 34),
        "sandbox-castle-stages": sc("Stages", (0.6, -6.4, 2.6), (.6, 0, .75), 38),
        "ball-corner": sc("BallCorner", (2.2, -6.8, 3.2), (0, 0, .5), 36),
        "gate-kerb-bench": sc("Gate", (3.5, -10.5, 3.6), (0, 1.0, 1.5), 32),
    }
    cams = {
        "playground-overview": camera(scene, pv, "CamOverview", (-21, -27, 21), (0, -.5, 0), lens=30),
        "roblox-camera-view": camera(scene, pv, "CamRoblox", (3.4, -25.5, 7.2), (2.4, -6, 1.5), fov=70),
    }
    for k, (loc, tgt, lens) in shots.items():
        cams[k] = camera(scene, pv, "Cam_" + k, loc, tgt, lens=lens)
    bpy.context.preferences.filepaths.save_version = 0      # no park.blend1 backups in the repo
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "park.blend"))
    if NO_RENDER:
        return
    for name, cam in cams.items():
        w, h = (1600, 900) if name in ("playground-overview", "roblox-camera-view") else (1200, 800)
        render(scene, cam, os.path.join(ART, name + ".png"), w, h)
    print("RENDERED", list(cams))


main()
