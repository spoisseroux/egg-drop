"""Slice C, the den (WORLD-FINISH-LOOK.md section 2): the shell, the floor, the mouth surround, the lantern, the crystal and
the flat stone. Imported by scripts/build_world_finish_art.py inside background Blender.

The shell is built round the den's collision room (cliff_den_sculpt.DEN / MOUTH, the boxes in CliffDenData.collision): a
loop of columns round the room's plan (the mouth's span included), rows from 0.6 under the floor to the wall top, a dome of
rings over it, and the mouth cut out of the front wall and extruded outward as the collar. One welded surface, normals
in. The same construction at three times the density, with the mid-frequency rock on it, is the high mesh the normal
map is baked from. Scoops are Voronoi cells (about 4.4 studs) pushed outward, ridges at the cell borders.
"""
from __future__ import annotations

import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import cliff_den_sculpt as S
import world_finish_lib as L

D, M = S.DEN, S.MOUTH
FLOOR = D["floor"]              # 4.2
Z1 = D["z1"]                    # -100.5, the front wall's collision face
JW, JE = M["x0"] + .1, M["x1"] - .1   # drawn jambs, .1 inside the collision mouth (they hide the live marble's inner faces)
SOFFIT = 9.8                    # under the live trim (9.85) and the timber beam (9.85)
WALL_TOP = 12.2
PEAK = 16.2
BASE = .35                      # the drawn wall's offset outside the collision face (before scoops)
BODY = (FLOOR + 1, FLOOR + 6)   # body height: the drawn wall within -0.3 / +1.0 of the collision here
COLLAR_END = -97.4              # the timber beam's lawn face: the collar ends behind the frame
PIL = (-17.0, 3.0)              # the pilaster round the marble posts (x range incl. the 1.2 eases)
PIL_OFF = -1.0                  # its face: z -101.5, just room-side of the marble (-101.32)
LEDGE_Y = 9.4                   # over the back-wall lanterns (their centres at 8.0, cords .8)
ALCOVES = [(-22.0, -110.5), (6.0, -110.0)]   # behind the Dash gate (Bay1) and behind the crate (Bay5): wall points
LANTERNS = [(-14.0, 8.0, -118.4), (0.0, 8.0, -118.4), (-14.0, 8.5, -98.0), (0.0, 8.5, -98.0)]
CENTRE = ((D["x0"] + D["x1"]) / 2, (D["z0"] + D["z1"]) / 2)


# ---------------------------------------------------------------------------------------------------------- the loop
def loop(spacing):
    """Closed loop of plan points round the room, starting at the east jamb on the front wall; returns points, outward
    normals, the indices of the west and east jamb columns (the mouth's span is the last run, west -> east -> index 0)."""
    r = D["corner"]
    pts = []

    def seg(a, b):
        n = max(1, round(math.dist(a, b) / spacing))
        for k in range(n):
            pts.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))

    def arc(cx, cz, a0, a1):
        n = max(2, round(abs(a1 - a0) * r / spacing))
        for k in range(n):
            a = a0 + (a1 - a0) * k / n
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))

    seg((JE, Z1), (D["x1"], Z1))
    seg((D["x1"], Z1), (D["x1"], D["z0"] + r))
    arc(D["x1"] - r, D["z0"] + r, 0.0, -math.pi / 2)
    seg((D["x1"] - r, D["z0"]), (D["x0"] + r, D["z0"]))
    arc(D["x0"] + r, D["z0"] + r, -math.pi / 2, -math.pi)
    seg((D["x0"], D["z0"] + r), (D["x0"], Z1))
    seg((D["x0"], Z1), (JW, Z1))
    iw = len(pts)
    seg((JW, Z1), (JE, Z1))
    normals = []
    n = len(pts)
    for i, p in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % n]
        dx, dz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dz)
        nx, nz = dz / ln, -dx / ln
        if nx * (p[0] - CENTRE[0]) + nz * (p[1] - CENTRE[1]) < 0:
            nx, nz = -nx, -nz
        # the front wall's mouth span and its jambs face straight out (+z)
        if abs(p[1] - Z1) < 1e-6:
            nx, nz = 0.0, 1.0
        normals.append((nx, nz))
    return pts, normals, iw


def rows(step):
    lower = np.linspace(FLOOR, SOFFIT, max(2, round((SOFFIT - FLOOR) / step)) + 1)
    # a row exactly at the top of body height (10.2), so the body-height clamp holds up to it
    upper = np.linspace(BODY[1], WALL_TOP, max(2, round((WALL_TOP - BODY[1]) / step)) + 1)
    return [FLOOR - .6] + list(lower) + list(upper)


# ---------------------------------------------------------------------------------------------------- displacement
def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def scoop(p, amp):
    """Outward push (studs) at Roblox points p (N x 3): Voronoi dishes with ridges at the borders."""
    edge, d1 = L.voronoi_edge(np.asarray(p) / 4.4, seed=31)
    dish = _smooth(0, .2, edge) * .65 + .35 * np.clip(1 - (d1 / .75) ** 2, 0, 1)
    sway = .15 * (L.fbm(np.asarray(p) * .12, 3, seed=5) - .5) * 2
    return amp * dish + sway


def wall_offset(px, y, pz, nrm, detail=False):
    """The drawn wall's offset outside the collision face at wall points (arrays)."""
    p = np.stack([px, y, pz], 1)
    # Fable R1 7: deeper scoops (0 to 0.7, the clamp below keeps them within +1.0) and alcoves (a full 1.0)
    off = BASE + scoop(p, .7)
    if detail:
        off += .18 * (L.fbm(p * .8, 3, seed=11) - .5) * 2      # Fable world R1 4: the mid-frequency rock x2
    for ax, az in ALCOVES:
        along = np.hypot(px - ax, pz - az)
        w = _smooth(2.9, 1.9, along)
        arch = _smooth(4.0, 4.6, y) * _smooth(9.9 + .4 * np.cos(np.clip(along / 2.9, 0, 1) * math.pi / 2), 9.3, y)
        off = off * (1 - w * arch) + .98 * w * arch
    # Fable R1 6: the ledge is a local shelf over each back-wall lantern (3 studs wide, 0.6 deep at LEDGE_Y), not a
    # rail round the room; the wall under it is scooped back 0.2.
    back = (np.array([n[1] for n in nrm]) < -.5)
    near = np.zeros_like(px)
    for lx, _, lz in LANTERNS[:2]:
        near = np.maximum(near, _smooth(2.2, 1.2, np.hypot(px - lx, pz - (D["z0"]))))
    lip = np.exp(-((y - LEDGE_Y) / .2) ** 2) * near
    off = np.where(back, off * (1 - lip) - .6 * lip, off)
    under = np.exp(-((y - (LEDGE_Y - .6)) / .35) ** 2) * near
    off = np.where(back, off + .2 * under, off)
    # body height: never more than 0.3 inside or 1.0 outside the collision wall
    body = y <= BODY[1] + .01             # from the skirt up: the rows under body height bound the faces into it
    shelf = back & (lip > .05)            # the lantern shelves are the one place the rock stands further in (Fable R1 6)
    off = np.where(shelf, np.clip(off, -.62, .98), np.where(body, np.clip(off, -.28, .98), np.clip(off, -.28, 1.6)))
    # The live marble posts and sill stand 0.8 into the room at the mouth (x -15.67..-14.5 and 0.5..1.68, z to -101.32;
    # they collide, precise). The front wall wraps them as a rock pilaster 1.0 into the room from x -15.6 to 1.6 (over
    # the opening it is above head height), easing back to the wall over 0.8 either side.
    # Fable R1 11: its edges ease over 1.2 and its face carries shallow scoops (0 to 0.17 back toward the wall: the
    # marble's face is at -101.32, the pilaster's at -101.55 at most forward)
    front = np.abs(pz - Z1) < 1e-6
    w = np.clip(np.minimum((px - PIL[0]) / 1.2, (PIL[1] - px) / 1.2), 0, 1)
    w = w * w * (3 - 2 * w)
    face = PIL_OFF - .05 + .17 * np.clip(scoop(p, 1.0) / .9, 0, 1)
    off = np.where(front, off * (1 - w) + face * w, off)
    return off


def dome_point(qx, qz, rho, detail=False):
    """A point on the dome over wall point (qx, qz) at normalised radius rho (1 at the wall top, 0 at the apex)."""
    cx, cz = CENTRE
    x = cx + (qx - cx) * rho
    z = cz + (qz - cz) * rho
    y = WALL_TOP + (PEAK - WALL_TOP) * (1 - rho ** 2) ** .6
    return x, y, z


# ---------------------------------------------------------------------------------------------------------- the shell
def obstacles(names):
    """A BVH of the island rock that stays around the den (world space, Blender), from the named objects' faces near it."""
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for n in names:
        o = bpy.data.objects.get(n)
        if o is None:
            continue
        mw = o.matrix_world
        for p in o.data.polygons:
            cs = [mw @ o.data.vertices[k].co for k in p.vertices]
            if not any(-26 < c.x < 10 and 92 < c.y < 124 and -1 < c.z < 16 for c in cs):
                continue
            base = len(verts)
            verts.extend(cs)
            polys.append(list(range(base, base + len(cs))))
    return BVHTree.FromPolygons(verts, polys) if polys else None


def build_shell(name, spacing, row_step, rings, tunnel_steps, detail=False, bvh=None):
    pts, nrm, iw = loop(spacing)
    NC = len(pts)
    ys = rows(row_step)
    NR = len(ys)
    r98 = ys.index(SOFFIT) if SOFFIT in ys else int(np.argmin([abs(y - SOFFIT) for y in ys]))
    px = np.array([p[0] for p in pts])
    pz = np.array([p[1] for p in pts])
    nx = np.array([n[0] for n in nrm])
    nz = np.array([n[1] for n in nrm])
    verts = []
    # wall rows
    for y in ys:
        yy = np.full(NC, y)
        off = wall_offset(px, yy, pz, nrm, detail)
        # the front wall at the jambs and over the mouth: the collar's mouth stays exact (no scoop on the jamb columns
        # under the soffit, they meet the tunnel)
        front = np.abs(pz - Z1) < 1e-6
        mouth = front & (px >= JW - 1e-6) & (px <= JE + 1e-6)
        off = np.where(mouth & (y <= SOFFIT + 1e-6), PIL_OFF, off)
        # Island rock that stays (colliding tiles: their hulls must not move) and pokes inside the drawn wall: pull the
        # wall in front of it, never more than 0.28 inside the collision face (a ray from there outward).
        if bvh is not None and FLOOR - .1 < y:
            pil = front & (px > PIL[0]) & (px < PIL[1])
            for i in range(NC):
                if pil[i]:
                    continue
                o = Vector((px[i] - nx[i] * .3, y, pz[i] - nz[i] * .3))
                hit = bvh.ray_cast(L.bl(o), Vector((nx[i], -nz[i], 0)), float(off[i]) + .35)
                if hit[0] is not None:
                    off[i] = max(-.28, min(off[i], hit[3] - .3 - .16))
        for i in range(NC):
            verts.append((px[i] + nx[i] * off[i], y, pz[i] + nz[i] * off[i]))
    top = [verts[(NR - 1) * NC + i] for i in range(NC)]
    # dome rings (k = 1..rings-1), then the apex
    dome_start = len(verts)
    for k in range(1, rings):
        rho = 1 - k / rings
        ring = [dome_point(q[0], q[2], rho) for q in top]
        verts += ring
    apex = len(verts)
    verts.append((CENTRE[0], PEAK, CENTRE[1]))
    faces = []

    def wv(r, i):
        return r * NC + (i % NC)

    mouth_cols = set(range(iw, NC)) | {0}
    for r in range(NR - 1):
        for i in range(NC):
            j = (i + 1) % NC
            if i in mouth_cols and j in mouth_cols and i != 0 and ys[r + 1] <= SOFFIT + 1e-6:
                continue                                    # the mouth's hole
            faces.append([wv(r, i), wv(r + 1, i), wv(r + 1, j), wv(r, j)])
    # wall top -> first dome ring -> ... -> apex
    prev = [wv(NR - 1, i) for i in range(NC)]
    for k in range(1, rings):
        cur = [dome_start + (k - 1) * NC + i for i in range(NC)]
        for i in range(NC):
            j = (i + 1) % NC
            faces.append([prev[i], cur[i], cur[j], prev[j]])
        prev = cur
    for i in range(NC):
        faces.append([prev[i], apex, prev[(i + 1) % NC]])
    # the collar: the hole's U boundary extruded outward to COLLAR_END
    profile = [wv(r, iw) for r in range(0, r98 + 1)] + [wv(r98, c) for c in list(range(iw + 1, NC))] + \
              [wv(r, 0) for r in range(r98, -1, -1)]
    zs = np.linspace(Z1 + PIL_OFF, COLLAR_END, tunnel_steps + 1)
    prev = profile
    for z in zs[1:]:
        cur = []
        for v in profile:
            x, y, _ = verts[v]
            cur.append(len(verts))
            verts.append((x, y, float(z)))
        for a in range(len(profile) - 1):
            faces.append([prev[a], prev[a + 1], cur[a + 1], cur[a]])
        prev = cur
    obj = L.mesh_object(name, verts, faces)
    # dome displacement: scoops along the outward normal (walls already carry theirs)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # normals in: the room's inside
    c = L.bl((CENTRE[0], 9.0, CENTRE[1]))
    inward = sum(f.normal.dot(c - f.calc_center_median()) > 0 for f in bm.faces)
    if inward < len(bm.faces) / 2:
        for f in bm.faces:
            f.normal_flip()
    bm.normal_update()
    dome_ids = list(range(dome_start, apex + 1))
    P = np.array([L.rb(bm.verts[i].co) for i in dome_ids])
    push = scoop(P, .75)
    if detail:
        push += .24 * (L.fbm(P * .8, 3, seed=11) - .5) * 2
    for i, d in zip(dome_ids, push):
        v = bm.verts[i]
        out = -v.normal
        start = v.co - out * 1.2
        v.co = v.co + out * float(d)
        if bvh is not None:                       # never through island rock that stays (see the walls)
            hit = bvh.ray_cast(start, out, (v.co - start).length + .05)
            if hit[0] is not None:
                v.co = start + out * max(.2, hit[3] - .08)
    bm.normal_update()
    # Second pass, every vertex but the pilaster and the collar: if island rock stands between the vertex and the room
    # (a ray from the vertex inward finds it within 1.3), bring the vertex in front of it.
    if bvh is not None:
        cen = L.bl((CENTRE[0], 8.0, CENTRE[1]))
        for v in bm.verts:
            q = L.rb(v.co)
            collar = JW - .05 <= q[0] <= JE + .05 and q[2] > Z1 + PIL_OFF + .05
            pilaster = PIL[0] + .8 < q[0] < PIL[1] - .8 and abs(q[2] - (Z1 + PIL_OFF)) < .3
            if q[1] < FLOOR - .05 or collar or pilaster:
                continue
            inward = v.normal.normalized()
            if inward.dot(cen - v.co) < 0:
                inward = -inward
            hit = bvh.ray_cast(v.co + inward * .01, inward, 1.3)
            if hit[0] is not None:
                v.co = v.co + inward * (hit[3] + .14)
        # Third pass, everything over body height: under the lowest island surface round the vertex (the hill's skin
        # over the den is thin and dips between the dome's vertices): vertical rays from 10.2 up, at the vertex and on a
        # ring 1.0 round it.
        ring = [(0, 0)] + [(math.cos(a) * r, math.sin(a) * r) for r in (.5, 1.0) for a in np.linspace(0, 2 * math.pi, 8,
                                                                                                    endpoint=False)]
        for v in bm.verts:
            if v.co.z + 4 <= BODY[1] + .05:
                continue
            q = L.rb(v.co)
            if JW - .05 <= q[0] <= JE + .05 and q[2] > Z1 + PIL_OFF + .05:
                continue                                         # the collar
            caps = [h[0].z for h in (bvh.ray_cast(Vector((v.co.x + dx, v.co.y + dy, BODY[1] - 4)), Vector((0, 0, 1)), 20)
                                     for dx, dy in ring) if h[0] is not None]
            if caps and v.co.z > min(caps) - .18:
                v.co.z = max(BODY[1] + .2 - 4, min(caps) - .18)
        bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    info = {"NC": NC, "NR": NR, "iw": iw, "r98": r98, "dome_start": dome_start, "apex": apex}
    return obj, info


def mark_seams(obj, info):
    """Seams: the wall-top ring, a vertical cut above the mouth's middle, and the collar soffit's middle."""
    me = obj.data
    NC, NR, iw, r98 = info["NC"], info["NR"], info["iw"], info["r98"]
    top = {(NR - 1) * NC + i for i in range(NC)}
    pts = [obj.matrix_world @ v.co for v in me.vertices]
    mid = min(range(iw, NC), key=lambda c: abs(L.rb(pts[r98 * NC + c])[0] - (JW + JE) / 2))
    cut = {r * NC + mid for r in range(r98, NR)}
    # The walls band (88 x 9 studs) packs badly whole: five more vertical cuts (east wall, the back corners, the back
    # wall's middle, west wall) leave six islands of about 15 x 9. The colour is baked from 3D noise, so a seam carries
    # no jump; the cuts sit in the scoops' ridges' neighbourhood, at mid-wall.
    for target in ((6.0, -107.5), (3.6, -117.6), (-8.0, -119.0), (-19.6, -117.6), (-22.0, -107.5)):
        col = min(range(NC), key=lambda c: (L.rb(pts[c])[0] - target[0]) ** 2 + (L.rb(pts[c])[2] - target[1]) ** 2)
        cut |= {r * NC + col for r in range(NR)}
    # the collar off the front wall: a seam round the mouth's U (inside the collar's mouth, as the brief allows)
    u_ring = {r * NC + iw for r in range(r98 + 1)} | {r98 * NC + c for c in range(iw, NC)} | {r * NC for r in range(r98 + 1)}
    for e in me.edges:
        a, b = e.vertices
        if a in u_ring and b in u_ring:
            pa, pb = L.rb(pts[a]), L.rb(pts[b])
            if abs(pa[2] - pb[2]) < 1e-4:          # on the front wall's plane, not along the collar
                e.use_seam = True
    for e in me.edges:
        a, b = e.vertices
        if a in top and b in top:
            e.use_seam = True
        elif a in cut and b in cut:
            e.use_seam = True
    # the collar soffit's middle: edges whose both ends sit at the mid column's x on the soffit, along z
    mx = L.rb(pts[r98 * NC + mid])[0]
    for e in me.edges:
        pa, pb = L.rb(pts[e.vertices[0]]), L.rb(pts[e.vertices[1]])
        if abs(pa[0] - mx) < 1e-4 and abs(pb[0] - mx) < 1e-4 and abs(pa[1] - SOFFIT) < 1e-3 and abs(pb[1] - SOFFIT) < 1e-3:
            e.use_seam = True


def unwrap(obj, info, wall_share=.76):
    """Angle-based unwrap on the seams, then the dome island scaled so walls take wall_share of the atlas."""
    L.only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = obj.data
    uv = me.uv_layers.active.data
    dome = set(range(info["dome_start"], info["apex"] + 1))

    def uv_area(poly):
        c = [uv[li].uv for li in poly.loop_indices]
        return abs(sum(c[k].x * c[(k + 1) % len(c)].y - c[(k + 1) % len(c)].x * c[k].y for k in range(len(c)))) / 2

    wall_a = sum(p.area for p in me.polygons if not set(p.vertices) & dome or not set(p.vertices) <= dome)
    dome_polys = [p for p in me.polygons if set(p.vertices) <= dome or (info["apex"] in p.vertices)]
    dome_ids = {p.index for p in dome_polys}
    wall_polys = [p for p in me.polygons if p.index not in dome_ids]
    a3w, a3d = sum(p.area for p in wall_polys), sum(p.area for p in dome_polys)
    auw, aud = sum(uv_area(p) for p in wall_polys), sum(uv_area(p) for p in dome_polys)
    # density (uv area per 3D area) ratio we want: walls/dome = (share_w / a3w) / (share_d / a3d)
    want = (wall_share / a3w) / ((1 - wall_share) / a3d)
    have = (auw / a3w) / (aud / a3d)
    f = math.sqrt(have / want)                     # scale the dome island by f
    cu = sum(uv[li].uv.x for p in dome_polys for li in p.loop_indices) / sum(len(p.loop_indices) for p in dome_polys)
    cv = sum(uv[li].uv.y for p in dome_polys for li in p.loop_indices) / sum(len(p.loop_indices) for p in dome_polys)
    for p in dome_polys:
        for li in p.loop_indices:
            uv[li].uv = ((uv[li].uv.x - cu) * f + cu, (uv[li].uv.y - cv) * f + cv)
    print("WORLDFINISH unwrap before pack: wall/dome density ratio", round(math.sqrt(
        (sum(uv_area(p) for p in wall_polys) / a3w) / (sum(uv_area(p) for p in dome_polys) / a3d)), 3),
        "f", round(f, 3), "dome polys", len(dome_polys))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=.004, margin_method="FRACTION")
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = me.uv_layers.active.data
    print("WORLDFINISH unwrap after pack: wall/dome density ratio", round(math.sqrt(
        (sum(uv_area(p) for p in wall_polys) / a3w) / (sum(uv_area(p) for p in dome_polys) / a3d)), 3),
        "uv used", round(sum(uv_area(p) for p in me.polygons), 3))
    a3 = sum(p.area for p in me.polygons)
    return {"wall_area": round(a3w, 1), "dome_area": round(a3d, 1), "total": round(a3, 1)}


def build_lid(shell, name="W7_F_DenLid__cliff_rock", out=1.35):
    """Fable world R1 fixes 1 and 3: an outward-facing rock skin over the dome and the upper walls (over y 9, behind the
    front wall), 1.35 out from the shell: it closes from outside whatever the volume re-cut opened in the hill (the cut
    takes island faces within 1.5) and it stands between the sky and the room (the den was lit by sky light)."""
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bm.normal_update()
    # over y 9 behind the front wall, and over 12 everywhere (the volume cut opens the cliff over the brow too)
    keep = [f for f in bm.faces if (L.rb(f.calc_center_median())[1] > 9.0 and L.rb(f.calc_center_median())[2] < -102.0)
            or L.rb(f.calc_center_median())[1] > 12.0]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in set(keep)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    for v in bm.verts:
        v.co = v.co - v.normal * out            # the shell's normals face in: minus is outward
    for f in bm.faces:
        f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def split_halves(obj, xcut):
    """Two copies of the shell, faces with centres west / east of xcut. The cut follows vertex columns (x -8 on the back
    wall, the column next to it over the mouth), so the halves share those vertices exactly. Seams carry over."""
    out = []
    for side, west in (("west", True), ("east", False)):
        o = obj.copy()
        o.data = obj.data.copy()
        o.name = "W7_F_Den__shell" + side.capitalize()
        bpy.context.scene.collection.objects.link(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        gone = [f for f in bm.faces if (L.rb(f.calc_center_median())[0] < xcut) != west]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")   # no loose vertices
        bm.to_mesh(o.data)
        bm.free()
        out.append((o, side))
    bpy.data.objects.remove(obj)
    return out


def unwrap_half(obj):
    L.only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=.004)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=.004, margin_method="FRACTION")
    bpy.ops.object.mode_set(mode="OBJECT")


def texel_density(obj, size, polys=None):
    me = obj.data
    uv = me.uv_layers.active.data
    total3, totaluv = 0.0, 0.0
    for p in (polys or me.polygons):
        c = [uv[li].uv for li in p.loop_indices]
        totaluv += abs(sum(c[k].x * c[(k + 1) % len(c)].y - c[(k + 1) % len(c)].x * c[k].y for k in range(len(c)))) / 2
        total3 += p.area
    return math.sqrt(totaluv * size * size / total3)


# ----------------------------------------------------------------------------------------------------- the shell bake
BASE_C = L.hexrgb("#7E6B58")    # Fable R1 10 (was #7A6A5C)
BED_C = L.hexrgb("#6A5B4E")
DAMP_C = L.hexrgb("#54483E")
SOOT_C = L.hexrgb("#3C332C")


def shell_colour(pos, ao, mask):
    """Display-space colour (H, W, 3) from texel positions (Roblox studs) and baked AO."""
    H, W = pos.shape[:2]
    p = pos.reshape(-1, 3)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    base = np.tile(np.array(BASE_C), (len(p), 1))
    # broad tone (low frequency) and fine grain
    tone = (L.fbm(p * .18, 3, seed=2) - .5) * .16
    grain = (L.fbm(p * 3.1, 3, seed=3) - .5) * .12
    col = base * (1 + tone + grain)[:, None]
    # Fable world R1 4: broken value patches 2 to 4 studs across, +-8%
    patch = (L.value_noise(np.floor(p / 3.0) + .5, seed=29) - .5) * .16
    col = col * (1 + patch * _smooth(.3, .6, L.fbm(p * .4, 2, seed=31)))[:, None]
    # faint horizontal bedding every 1.2 to 2 studs (the period wanders), thin darker lines, broken so no line runs
    # more than about 5 studs (Fable world R1 4)
    period = 1.2 + .8 * L.fbm(np.stack([x * .05, np.zeros_like(x), z * .05], 1), 2, seed=7)
    phase = (y + .5 * (L.fbm(p * .2, 2, seed=8) - .5)) / period
    line = np.exp(-((phase - np.round(phase)) * period / .12) ** 2)
    line = line * _smooth(.42, .52, L.value_noise(np.stack([(x + z) / 2.5, np.round(phase), (x - z) / 2.5], 1), seed=37))
    col = col * (1 - .45 * line)[:, None] + np.array(BED_C) * (.45 * line)[:, None]
    # hairline cracks: Voronoi borders (cells ~2.6 studs), only where a sparse mask allows, under 0.15 stud wide
    # Fable R1 8: short hairlines only (dashes about 1.2 long, under 0.1 wide, at most 25% darker)
    edge, _ = L.voronoi_edge(p / 2.6, seed=17)
    allow = _smooth(.7, .78, L.fbm(p * .25, 2, seed=19)) * _smooth(.62, .7, L.fbm(p * .9, 2, seed=23))
    crack = np.exp(-(edge * 2.6 / .03) ** 2) * allow
    col = col * (1 - .22 * crack)[:, None]
    # the damp band: the first 1.5 studs over the floor
    damp = _smooth(FLOOR + 1.5, FLOOR + .2, y)
    col = col * (1 - damp)[:, None] + np.array(DAMP_C) * damp[:, None]
    # soot over each lantern
    for lx, ly, lz in LANTERNS:
        d = ((x - lx) / 1.1) ** 2 + ((z - lz) / 1.1) ** 2 + ((y - (ly + 1.6)) / 1.6) ** 2
        s = np.exp(-d) * (y > ly + .2)
        col = col * (1 - .5 * s)[:, None] + np.array(SOOT_C) * (.5 * s)[:, None]
    col = col.reshape(H, W, 3)
    # baked ambient occlusion at 60%
    # (Fable R1 8: AO floored at 0.35 before the 60% mix, so folds and contacts never bake to black gashes)
    col = col * (1 - .6 * (1 - np.clip(ao, .35, 1)))[..., None]
    return np.clip(col, 0, 1)


# ---------------------------------------------------------------------------------------------------------- the floor
FLOOR_C = L.hexrgb("#6B5240")   # Fable R1 10 (was #6E5140)
FLOOR_TILE = 6.0
THRESHOLD = 4.46


def build_floor(name, spacing=1.9):
    """Grid over the room grown 1.2 (under the shell's skirt) and the mouth's floor out to the apron; very slightly
    dished (4.21 at the edges, 4.11 mid-room), UVs world-projected one tile per 6 studs."""
    grow = 1.8
    xs = np.arange(D["x0"] - grow, D["x1"] + grow + 1e-6, spacing)
    zs = np.arange(D["z0"] - grow, -93.2 + 1e-6, spacing)
    # exact rows at the threshold's edges (it eases over 0.3 at the sill's edges, so the walkable floor stays at 4.2)
    zs = np.array(sorted(set(np.round(np.append(zs, [-101.65, -101.35, -98.0, -97.65, -93.2]), 4))))
    zs = zs[zs <= -93.2 + 1e-6]
    xs = np.array(sorted(set(np.round(np.append(xs, [JW - 1.9, JW - 1.6, JE + 1.6, JE + 1.9]), 4))))   # the threshold's ends exactly
    index, verts, faces, uvs = {}, [], [], []

    def keep(cx, cz):
        if S.den_inside(cx, cz, grow) and cz <= Z1 + 1.2:     # under the front wall too (Fable R1 11)
            return True
        if JW - 2.0 <= cx <= JE + 2.0 and Z1 - .5 <= cz <= -97.6:      # the threshold under the timber jambs too
            return True
        return JW - .6 <= cx <= JE + .6 and Z1 - .5 <= cz <= -93.2

    def height(x, z):
        u = (x - CENTRE[0]) / ((D["x1"] - D["x0"]) / 2)
        v = (z - CENTRE[1]) / ((D["z1"] - D["z0"]) / 2)
        # the threshold: earth over the live marble sill (top 4.4, z -101.32..-98.82, it collides), easing to the
        # floor a stud and a half either side
        if JW - 1.6 <= x <= JE + 1.6:      # Fable world R1 7: wide enough to bury the sill's ends at the jamb feet
            if -101.35 <= z <= -98.0:
                return THRESHOLD
            if -101.65 < z < -101.35:
                return FLOOR + (THRESHOLD - FLOOR) * (z + 101.65) / .3
            if -98.0 < z < -97.65:
                return THRESHOLD + (FLOOR - THRESHOLD) * (z + 98.0) / .35
        if z > Z1:
            return FLOOR
        return FLOOR + .01 - .1 * max(0.0, 1 - u * u) * max(0.0, 1 - v * v)

    def vid(i, j):
        key = (i, j)
        if key not in index:
            x, z = float(xs[i]), float(zs[j])
            index[key] = len(verts)
            verts.append((x, height(x, z), z))
        return index[key]

    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            if not keep(cx, cz):
                continue
            # wound to face up (Roblox +y): seen from above, x right and z down the page
            q = [vid(i, j), vid(i, j + 1), vid(i + 1, j + 1), vid(i + 1, j)]
            faces.append(q)
            uvs.append([(verts[k][0] / FLOOR_TILE, -verts[k][2] / FLOOR_TILE) for k in q])
    obj = L.mesh_object(name, verts, faces, uvs=uvs)
    me = obj.data
    me.update()
    up = sum(p.normal.z for p in me.polygons)
    if up < 0:
        bm = bmesh.new()
        bm.from_mesh(me)
        for f in bm.faces:
            f.normal_flip()
        bm.to_mesh(me)
        bm.free()
    return obj


def floor_tile(size=512):
    """Packed earth, tileable on 6 studs: colour and normal (display arrays, row 0 = bottom)."""
    n = size
    u = (np.arange(n) + .5) / n
    U, V = np.meshgrid(u, u)
    per = 6
    p = np.stack([U.ravel() * per, V.ravel() * per, np.zeros(n * n)], 1)
    h = (L.fbm(p, 4, seed=41, period=(per, per, 1)) - .5) * .7
    # small embedded grit and a few pebbles (tileable cells)
    edge, d1 = L.voronoi_edge(p * 2.0, seed=43, period=(per * 2, per * 2, 1))
    pebble = np.clip(1 - d1 / .22, 0, 1) * (L.value_noise(np.floor(p * 2.0), seed=44, period=(per * 2, per * 2, 1)) > .82)
    h += pebble * .6
    scuff = (L.fbm(p * np.array([.5, 2.0, 1]), 3, seed=45, period=(per // 2 or 1, per * 2, 1)) - .5) * .25
    h += scuff
    tone = (L.fbm(p * 1.0, 3, seed=46, period=(per, per, 1)) - .5) * .22
    grain = (L.fbm(p * 8.0, 2, seed=47, period=(per * 8, per * 8, 1)) - .5) * .14
    col = np.tile(np.array(FLOOR_C), (n * n, 1)) * (1 + tone + grain)[:, None]
    peb_c = np.array(L.hexrgb("#7E6A58"))
    col = col * (1 - .7 * pebble)[:, None] + peb_c * (.7 * pebble)[:, None]
    col = col * (1 - .12 * np.clip(-h, 0, 1))[:, None]
    H = h.reshape(n, n)
    # normal from the height field (tangent space: u along +x, v along the uv's v)
    k = 2.2
    gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * k
    gy = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * k
    nrm = np.stack([-gx, -gy, np.ones_like(H)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    return np.clip(col.reshape(n, n, 3), 0, 1), nrm * .5 + .5


# -------------------------------------------------------------------------------------------------- small templates
def box_faces(verts, faces, cx, cy, cz, sx, sy, sz, caps=True):
    b = len(verts)
    for dx in (-1, 1):
        for dy in (-1, 1):
            for dz in (-1, 1):
                verts.append((cx + dx * sx / 2, cy + dy * sy / 2, cz + dz * sz / 2))
    idx = lambda dx, dy, dz: b + ((dx + 1) // 2) * 4 + ((dy + 1) // 2) * 2 + (dz + 1) // 2
    quads = [[idx(-1, -1, -1), idx(-1, -1, 1), idx(-1, 1, 1), idx(-1, 1, -1)],
             [idx(1, -1, -1), idx(1, 1, -1), idx(1, 1, 1), idx(1, -1, 1)],
             [idx(-1, -1, -1), idx(-1, 1, -1), idx(1, 1, -1), idx(1, -1, -1)],
             [idx(-1, -1, 1), idx(1, -1, 1), idx(1, 1, 1), idx(-1, 1, 1)]]
    if caps:
        quads += [[idx(-1, 1, -1), idx(-1, 1, 1), idx(1, 1, 1), idx(1, 1, -1)],
                  [idx(-1, -1, -1), idx(1, -1, -1), idx(1, -1, 1), idx(-1, -1, 1)]]
    faces += quads


def outward(obj):
    """Recalculate normals outward (closed or nearly closed small meshes)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def build_lantern():
    """The lantern (Fable: one mesh, 4 copies, ~180 triangles): a dark iron cage (cap, hanging ring, posts, crossbars,
    base) and its four slim panes, which are their own Neon part. Local studs, centre at the origin, 0.8 x 1.1 x 0.8 like
    the greybox lamp it replaces. Returns (cage, panes)."""
    v, f = [], []
    w = .8
    # corner posts, base plate and cap rim
    for sx in (-1, 1):
        for sz in (-1, 1):
            box_faces(v, f, sx * (w / 2 - .05), 0, sz * (w / 2 - .05), .1, 1.0, .1, caps=False)
    box_faces(v, f, 0, -.52, 0, .9, .1, .9)
    box_faces(v, f, 0, .5, 0, .95, .08, .95)
    # crossbars: a wide band round the middle hides half of every pane
    for k, (cx, cz, sx, sz) in enumerate(((0, w / 2 - .04, w, .06), (0, -(w / 2 - .04), w, .06),
                                          (w / 2 - .04, 0, .06, w), (-(w / 2 - .04), 0, .06, w))):
        box_faces(v, f, cx, .02, cz, sx, .22, sz, caps=False)
    # the cap: a low square pyramid frustum
    b = len(v)
    for y, r in ((.54, .5), (.72, .2)):
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            v.append((sx * r, y, sz * r))
    for k in range(4):
        f.append([b + k, b + (k + 1) % 4, b + 4 + (k + 1) % 4, b + 4 + k])
    f.append([b + 4, b + 5, b + 6, b + 7])
    # the hanging ring: six segments, a triangular tube
    b = len(v)
    R, r = .14, .025
    for k in range(6):
        a = k / 6 * math.pi * 2
        cx, cy = R * math.cos(a), .72 + R + R * math.sin(a)
        for m in range(3):
            t = m / 3 * math.pi * 2
            v.append((cx + r * math.cos(t) * math.cos(a), cy + r * math.cos(t) * math.sin(a), r * math.sin(t)))
    for k in range(6):
        for m in range(3):
            a0, a1 = b + k * 3 + m, b + k * 3 + (m + 1) % 3
            c0, c1 = b + ((k + 1) % 6) * 3 + m, b + ((k + 1) % 6) * 3 + (m + 1) % 3
            f.append([a0, c0, c1, a1])
    cage = L.mesh_object("W7_F_Lantern__cage", v, f, smooth=False, local=True)
    outward(cage)
    # panes: four quads just inside the posts
    pv, pf = [], []
    for (ax, az), (bx, bz) in (((-1, 1), (1, 1)), ((1, 1), (1, -1)), ((1, -1), (-1, -1)), ((-1, -1), (-1, 1))):
        s = w / 2 - .07
        b = len(pv)
        pv += [(ax * s, -.46, az * s), (bx * s, -.46, bz * s), (bx * s, .46, bz * s), (ax * s, .46, az * s)]
        pf.append([b, b + 1, b + 2, b + 3])
    panes = L.mesh_object("W7_F_Lantern__pane", pv, pf, smooth=False, local=True)
    return cage, panes


def build_crystal():
    """One amber shard (40 triangles or fewer): six sides, a slight twist at mid height, a clean slanted break at the top.
    1.0 tall, base at y 0 (buried in rubble)."""
    v, f = [], []
    rings = [(0.0, .23, 0.0), (.55, .2, .12), (.86, .16, .2)]
    for y, r, tw in rings:
        for k in range(6):
            a = k / 6 * math.pi * 2 + tw
            v.append((r * math.cos(a), y, r * math.sin(a)))
    for ri in range(len(rings) - 1):
        for k in range(6):
            a, b = ri * 6 + k, ri * 6 + (k + 1) % 6
            f.append([a, b, b + 6, a + 6])
    # the break: the top ring's points lifted on a slanted plane
    top = 2 * 6
    for k in range(6):
        x, y, z = v[top + k]
        v[top + k] = (x, y + .14 * (x / .16), z)
    f.append([top + k for k in range(6)][::-1])
    obj = L.mesh_object("W7_F_Den__crystal", v, f, smooth=False, local=True)
    outward(obj)
    return obj


def build_flat_stone(name="W7_F_Stone__flat", seed=3):
    """A flat worn stone (40 triangles): 1 across, 0.24 proud of y 0, 0.3 buried."""
    rnd = np.random.default_rng(seed)
    v, f = [], []
    n = 8
    rad = 1 + rnd.uniform(-.12, .12, n)
    for y, s in ((-.3, .5), (0.0, .48), (.17, .38)):
        for k in range(n):
            a = k / n * math.pi * 2
            v.append((s * rad[k] * math.cos(a), y + rnd.uniform(-.02, .02) * (y > 0), s * rad[k] * math.sin(a) * .92))
    for ri in range(2):
        for k in range(n):
            a, b = ri * n + k, ri * n + (k + 1) % n
            f.append([a, a + n, b + n, b])
    c = len(v)
    v.append((0, .24, 0))
    for k in range(n):
        f.append([2 * n + k, c, 2 * n + (k + 1) % n])
    obj = L.mesh_object(name, v, f, smooth=True, local=True)
    outward(obj)
    return obj


# ------------------------------------------------------------------------------------------------ the mouth surround
# Rock masses (centre, radii, yaw degrees): the two leaning jamb buttresses round the live marble posts and the brow
# over the timber lintel. Union by voxel remesh, faceted by Voronoi, decimated, then kept out of the opening, the timber
# frame and the lawn in front of it.
MOUTH_BLOBS = [
    # Fable R1 1, 2: six rounded masses, nothing thinner than 2 studs. West buttress and its foot
    ((-18.0, 7.2, -99.9), (2.6, 4.4, 2.6), 10), ((-19.4, 4.6, -100.6), (2.8, 2.1, 2.6), -15),
    # east buttress and its foot
    ((3.7, 7.2, -100.0), (2.4, 4.4, 2.5), -10), ((5.1, 4.6, -100.8), (2.6, 2.1, 2.5), 15),
    # the brow: one mass over x -17..3, its face 1 stud lawnward of the timber lintel (z -96.4), its lower edge 0.5
    # over the sign's top (12.1); and the rock it hangs from
    ((-7.0, 13.9, -99.4), (10.4, 1.8, 3.0), 0), ((-7.0, 16.0, -101.3), (9.2, 2.1, 2.6), 0),
    # Fable world R1 fix 2: backing masses over the tan hole west of the mouth (about 14 x 10) and the gap east of the brow
    ((-25.5, 9.6, -100.4), (5.6, 5.4, 2.6), 8), ((-21.5, 14.0, -101.0), (4.0, 3.0, 2.4), -5),
    # round 3: the left of the mouth (studio-r2/01) buried under two more masses, up to y 20
    ((-30.5, 13.5, -101.8), (4.6, 5.2, 3.0), 15), ((-25.0, 18.0, -102.2), (5.0, 3.0, 2.8), -8),
    ((7.8, 12.2, -100.9), (3.0, 3.2, 2.3), -10),
]
# (x0, y0, z0, x1, y1, z1, push axes): nothing of the surround inside these
MOUTH_KEEP_OUT = [
    ((-14.45, 3.0, -101.5, .45, 11.25, -85.0), ("x", "y")),        # the opening, up to the brow's underside
    ((-15.85, 3.0, -98.85, -14.15, 11.25, -97.15), ("x",)),        # the west timber jamb
    ((.15, 3.0, -98.85, 1.85, 11.25, -97.15), ("x",)),             # the east timber jamb
    ((-15.85, 9.75, -98.85, 1.85, 11.3, -97.15), ("y",)),          # the timber lintel
    ((-30.0, 3.0, -97.2, 12.0, 9.5, -80.0), ("z",)),               # the lawn in front of the buttresses
    ((-24.6, 3.0, -121.0, 8.6, 21.0, -99.1), ("z",)),              # the room and its corners (round 3: to y 21 and 2.6 wider)
]
# Collision for the buttresses (players and pets stop at the rock): boxes {c, s} the mount builds with the den's boxes.
MOUTH_BOXES = [
    {"kind": "buttress", "c": [-18.2, 7.4, -99.5], "s": [4.4, 7.0, 4.0]},
    {"kind": "buttress", "c": [3.9, 7.4, -99.5], "s": [4.2, 7.0, 4.0]},
    # the brow (architect review: the clamp's spherecast respects CanCollide; without it an orbit enters drawn rock)
    {"kind": "brow", "c": [-7.0, 13.9, -98.4], "s": [20.0, 3.4, 3.4]},
]
HIDE = ["W7_CD_PlayDen__cliff_rock", "W7_CD_PlayDen__dirt_path"]
HIDE_VISUAL = []          # colliding pack parts left with nothing to show: invisible, still colliding


def _keep_out(p):
    """Push points (N x 3, Roblox) out of the keep-out boxes along their allowed axes (the shortest way)."""
    p = p.copy()
    for (x0, y0, z0, x1, y1, z1), axes in MOUTH_KEEP_OUT:
        lo, hi = np.array([x0, y0, z0]), np.array([x1, y1, z1])
        inside = np.all((p > lo) & (p < hi), axis=1)
        if not inside.any():
            continue
        q = p[inside]
        best, move = np.full(len(q), 1e9), np.zeros_like(q)
        for ax in axes:
            k = "xyz".index(ax)
            for target in (lo[k] - .02, hi[k] + .02):
                d = target - q[:, k]
                better = np.abs(d) < best
                best = np.where(better, np.abs(d), best)
                mv = np.zeros_like(q)
                mv[:, k] = d
                move = np.where(better[:, None], mv, move)
        p[inside] = q + move
    return p


def build_mouth(name, voxel=.28, target_tris=2400):
    bm = bmesh.new()
    for (c, r, yaw) in MOUTH_BLOBS:
        geom = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        for v in geom["verts"]:
            x, y, z = v.co.x * r[0], v.co.z * r[1], -v.co.y * r[2]            # local Roblox (x, y, z)
            x, z = x * cy + z * sy, -x * sy + z * cy
            v.co = L.bl((c[0] + x, c[1] + y, c[2] + z))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    L.only([obj])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    sm = obj.modifiers.new("Smooth", "SMOOTH")          # Fable R1 1: round the union before faceting
    sm.factor, sm.iterations = .6, 12
    bpy.ops.object.modifier_apply(modifier=sm.name)
    # facets: broad Voronoi planes (3-stud cells) and a little fbm along the normals
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    P = np.array([L.rb(v.co) for v in bm.verts])
    edge, _ = L.voronoi_edge(P / 3.0, seed=71)
    push = -.2 * _smooth(0, .25, edge) + .14 * (L.fbm(P * .3, 3, seed=72) - .5) * 2
    for v, d in zip(bm.verts, push):
        v.co = v.co + v.normal * float(d)
    bm.to_mesh(obj.data)
    bm.free()
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target_tris / max(1, L.tris(obj)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # keep-out after decimation (exact), then drop faces wholly under the lawn (y < 3.2)
    me = obj.data
    P = _keep_out(np.array([L.rb(v.co) for v in me.vertices]))
    for v, q in zip(me.vertices, P):
        v.co = L.bl(q)
    bm = bmesh.new()
    bm.from_mesh(me)
    under = [f for f in bm.faces if all(L.rb(v.co)[1] < 3.2 for v in f.verts)]
    bmesh.ops.delete(bm, geom=under, context="FACES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    return obj


# Crystals: one shard mesh in three sizes (0.6, 1.0, 1.5 tall), clusters of 2 or 3 rising from rubble. Two clusters
# outside at the mouth's feet, one in each alcove. `at` is where the shard's base sits (buried .15).
def _cluster(x, z, ground_y, sizes, seed):
    rnd = np.random.default_rng(seed)
    out = []
    for k, s in enumerate(sizes):
        a = k / len(sizes) * math.pi * 2 + rnd.uniform(0, 1)
        out.append({"at": [round(x + .35 * math.cos(a), 3), round(ground_y - .15, 3), round(z + .35 * math.sin(a), 3)],
                    "yaw": round(float(rnd.uniform(0, math.pi * 2)), 3), "scale": s})
    return out


def _lawn(x, z):
    # the walk grid's top surface; by the mouth it can read the old rock over the lawn, so never above 5.0 here
    return round(min(S.ground(x, z) or 4.6, 5.0), 3)


CRYSTALS = (_cluster(-16.9, -96.4, _lawn(-16.9, -96.4), (1.5, .6, 1.0), 1)
            + _cluster(2.9, -96.6, _lawn(2.9, -96.6), (1.0, .6), 2)
            + _cluster(-21.1, -110.5, FLOOR, (1.0, 1.5, .6), 3)
            + _cluster(5.1, -110.0, FLOOR, (1.0, .6), 4))


def _stone(x, y, z, sx, sz, proud, yaw):
    # the flat stone is 1 across, .24 proud and .3 buried at scale 1: scale y so it stands `proud` over y
    return {"at": [x, y, z], "size": [sx, round(proud / .24, 3), sz], "yaw": yaw}


FLOOR_STONES = [_stone(x, FLOOR, z, sx, sz, .05, yaw) for x, z, sx, sz, yaw in (
    (-9.2, -101.6, 1.6, 1.2, .3), (-4.6, -102.4, 1.3, 1.0, 1.1), (-11.9, -103.1, 1.2, .9, 2.0),
    (-9.6, -114.4, 1.5, 1.1, .7), (-4.4, -114.0, 1.3, 1.0, 2.4), (-16.0, -107.9, 1.4, 1.0, 1.6),
    (2.4, -107.6, 1.2, .9, .2))] + [
    # rubble at the crystal clusters
    _stone(c["at"][0] + .2, c["at"][1] + .15, c["at"][2] - .25, .55, .45, .14, c["yaw"]) for c in CRYSTALS[::2]]


# ------------------------------------------------------------------------------------------------------- the apron
APRON = {"x0": -25.0, "x1": 3.0, "z0": -100.0, "z1": -90.0, "top": 4.97, "mouth": (-15.5, 1.5, -93.2)}


def build_apron(name, k, spacing=1.0):
    """The worn earth patch over DenGreybox's apron slabs (their collision stays, top 4.95): flat at 4.97 over the slabs,
    its lawn side and ends rolling down into the lawn over a broken edge 0.4 to 1.6 wide; a riser where it meets the
    mouth's lower floor. UVs world-projected at the garden path's density (k)."""
    A = APRON
    mx0, mx1, mz = A["mouth"]
    xs = np.arange(A["x0"] - 2.0, A["x1"] + 2.0 + 1e-6, spacing)
    # its cliff side starts at -99.3, behind the shell's front wall (Fable R1 11: at -100.5 its edge showed in the room)
    zs = np.arange(-99.3, A["z1"] + 2.6 + 1e-6, spacing)
    X, Z = np.meshgrid(xs, zs, indexing="ij")
    P = np.stack([X.ravel() * .45, np.zeros(X.size), Z.ravel() * .45], 1)
    margin = (.4 + 1.6 * L.fbm(P, 3, seed=81)).reshape(X.shape)      # Fable R1 5: a broken edge 0.4 to 2.0
    dx = np.maximum(np.maximum(A["x0"] - X, X - A["x1"]), 0)
    dz = np.maximum(Z - A["z1"], 0)                       # only the lawn side rolls; the cliff side is under the rock
    d = np.hypot(dx, dz)
    Y = np.where(d <= 0, A["top"], A["top"] - .55 * np.clip(d / margin, 0, 1))
    inside_mouth = (X > mx0 + 1e-6) & (X < mx1 - 1e-6) & (Z < mz - 1e-6)
    keep = (d <= margin) & ~inside_mouth
    verts, faces, index = [], [], {}

    def vid(i, j):
        if (i, j) not in index:
            index[(i, j)] = len(verts)
            verts.append((float(X[i, j]), float(Y[i, j]), float(Z[i, j])))
        return index[(i, j)]

    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            if keep[i, j] and keep[i + 1, j] and keep[i, j + 1] and keep[i + 1, j + 1]:
                cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
                if mx0 < cx < mx1 and cz < mz:
                    continue
                faces.append([vid(i, j), vid(i, j + 1), vid(i + 1, j + 1), vid(i + 1, j)])
    # the riser down to the mouth's floor (4.2) along its lawn edge and its sides
    def riser(a, b, out):
        base = len(verts)
        verts.extend([(a[0], A["top"], a[1]), (b[0], A["top"], b[1]), (b[0], FLOOR - .05, b[1]), (a[0], FLOOR - .05, a[1])])
        faces.append([base, base + 1, base + 2, base + 3])
    riser((mx0, mz), (mx1, mz), (0, 0, -1))
    riser((mx0, -97.2), (mx0, mz), (1, 0, 0))
    riser((mx1, mz), (mx1, -97.2), (-1, 0, 0))
    uvs = [[(verts[q][0] * k, -verts[q][2] * k) if abs(verts[q][1] - A["top"]) < 2 else (0, 0) for q in f] for f in faces]
    obj = L.mesh_object(name, verts, faces, uvs=uvs)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    up = sum(f.normal.z for f in bm.faces)
    if up < 0:
        for f in bm.faces:
            f.normal_flip()
    bm.to_mesh(obj.data)
    bm.free()
    return obj


# Fable R1 5: eight edge stones 0.8 to 1.4 across along the lawn side and the ends, and two leaf tufts each side
# (WorldDressing bush rows {x, y, z, kind, yaw, scale}: kind 3 = W7D_LeafTuft, placed by the mount like Art.dressing)
APRON_STONES = [_stone(x, _lawn(x, z) - .02, z, sx, sz, h, yaw) for x, z, sx, sz, h, yaw in (
    (-25.6, -92.6, 1.1, .8, .34, .4), (-23.4, -89.3, 1.3, .9, .4, 1.9), (-17.9, -88.9, .9, .7, .3, .8),
    (-12.6, -89.1, 1.4, 1.0, .42, 2.6), (-6.1, -88.8, .8, .65, .28, 1.3), (-1.2, -89.2, 1.2, .85, .36, .1),
    (3.4, -89.9, 1.0, .8, .32, 2.2), (4.6, -93.4, .9, .7, .3, .9))]
APRON_TUFTS = [[x, _lawn(x, z), z, 3, yaw, s] for x, z, yaw, s in (
    (-24.8, -90.6, .3, 1.1), (-21.0, -88.9, 2.2, .9), (1.6, -88.7, 1.1, 1.0), (4.9, -91.8, 2.9, .9))]
# The Dash gate's eight paw stones (DenGreybox W7D_<bay>Paw rows) are replaced in place by the flat stone, sunk 0.1: the
# mount reads their CFrames from the built rows, so only the look is here.
PAW_STONES = []
# round 5 (Fable world R1 17: "they should nearly disappear"): sunk .05, its top 0.03 over the floor
PAW = {"size": [.95, round(.08 / .24, 3), .85], "sink": .05, "color": "#8A8378"}
# Round 5 (Fable world R1 10, the letterbox): the timber lintel thinned to one plank row (0.7, its underside where it
# was, on the trim at 9.85) and the sign, smaller, standing on it instead of hanging below it, so nothing of the frame
# hangs into the opening. The opening's own height is the sculpt's (CliffDenData mouth top 9.85, the live trim).
FRAME = {"lintel": .7, "sign": [7.0, 1.8], "gap": .15}
# Fable world R1 18: the crates' dust sheets in cloth, not speckled granite.
CLOTH = {"color": "#8C8474", "material": "SmoothPlastic"}
