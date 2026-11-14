"""Bounded world-v7 coplanar surface union. Runs inside background Blender only.

No scene save or exports here. Original import faces are identified by geometry;
indices are used only as transient handles within this one freshly-loaded mesh.
"""
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

AREA_EPS = 1e-7
PLANE_EPS = 1e-4
NORMAL_EPS = 1e-6
NEAR_EPS = .012
GROUP_COUNTS = {
    ("Architecture_Stairs__marble",) * 2: 14,
    ("Architecture_Rotunda__marble",) * 2: 5,
    ("Architecture_MarbleArch__marble",) * 2: 2,
    ("Architecture_Bridge__marble",) * 2: 10,
    ("Architecture_Balustrades__marble",) * 2: 147,
    ("Stations_PocketDeckKiosk__deck_cream", "Stations_PocketDeckKiosk__glow_aqua"): 2,
    ("Landmarks__gold", "Landmarks__marble"): 2,
    ("Landmarks__marble",) * 2: 2,
    ("Stations_EggNest__marble_smooth",) * 2: 2,
    ("Stations_EggNest__marble", "Stations_EggNest__marble_smooth"): 2,
    ("Stations_EggNest__marble", "Stations_EggNest__trim"): 1,
    ("Stations_PocketDeckKiosk__deck_cream",) * 2: 4,
    ("Architecture_Edging__marble",) * 2: 1,
    ("Stations_CareCradle__deck_cream", "Stations_CareCradle__gold"): 2,
}
NAMES = set(n for pair in GROUP_COUNTS for n in pair)
# Outer guards include the complete affected polygon, not just its intersection.
GUARDS = {
    "Architecture_Stairs": ((-60, 3, 17), (-30, 16, 50)),
    "Architecture_Rotunda": ((-70, 13, 39), (-50, 24, 61)),
    "Architecture_MarbleArch": ((77, 4, 48), (93, 7, 67)),
    "Architecture_Bridge": ((-8, 2, 15), (16, 6, 27)),
    "Architecture_Balustrades": ((-110, 2, -30), (114, 9, 88)),
    "Landmarks": ((-18, 3, -104), (4, 12, -96)),
    "Stations_EggNest": ((-35, 3, -16), (-25, 8, -8)),
    "Stations_PocketDeckKiosk": ((-50, 5, -12), (-43, 12, -5)),
    "Architecture_Edging": ((20, 3, -11), (25, 6, -5)),
    "Stations_CareCradle": ((-22, 4, -17), (-17, 9, -12)),
}


def signed_area(poly):
    return sum(p[0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * p[1]
               for i, p in enumerate(poly)) / 2


def clean(poly):
    result = []
    for p in poly:
        if not result or sum((a - b) ** 2 for a, b in zip(p, result[-1])) > 1e-16:
            result.append(p)
    if len(result) > 1 and sum((a - b) ** 2 for a, b in zip(result[0], result[-1])) < 1e-16:
        result.pop()
    return result if len(result) >= 3 and abs(signed_area(result)) > AREA_EPS else []


def half(poly, a, b, inside):
    """Clip one convex polygon to either side of a directed edge."""
    if not poly:
        return []
    side = lambda p: (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
    result = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        sp, sq = side(p), side(q)
        pin = sp >= 0 if inside else sp <= 0
        qin = sq >= 0 if inside else sq <= 0
        if pin:
            result.append(p)
        if pin != qin:
            t = sp / (sp - sq)
            result.append(tuple(p[k] + (q[k] - p[k]) * t for k in range(2)))
    return clean(result)


def intersect(poly, cutter):
    cutter = cutter if signed_area(cutter) >= 0 else list(reversed(cutter))
    for i, a in enumerate(cutter):
        poly = half(poly, a, cutter[(i + 1) % len(cutter)], True)
        if not poly:
            break
    return poly


def subtract(poly, cutter):
    """Convex difference: disjoint outside pieces plus a progressively clipped inside.

    Shared edges have zero area. Unlike a fan around a hole, these pieces never
    cover the removed footprint. Sequential callers use current owner fragments.
    """
    overlap = intersect(poly, cutter)
    if not overlap:
        return [poly], 0.0
    cutter = cutter if signed_area(cutter) >= 0 else list(reversed(cutter))
    remaining, out = poly, []
    for i, a in enumerate(cutter):
        b = cutter[(i + 1) % len(cutter)]
        outside = half(remaining, a, b, False)
        if outside:
            out.append(outside)
        remaining = half(remaining, a, b, True)
        if not remaining:
            break
    removed = abs(signed_area(overlap))
    assert abs(sum(abs(signed_area(p)) for p in out) + removed - abs(signed_area(poly))) < 1e-5
    return out, removed


def basis(n):
    axis = min(range(3), key=lambda i: abs(n[i]))
    u = n.cross((Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))[axis]).normalized()
    return u, n.cross(u)


def project(points, u, v):
    return [(p.dot(u), p.dot(v)) for p in points]


def bounds(points):
    rb = [(p.x, p.z + 4, -p.y) for p in points]
    return [min(p[i] for p in rb) for i in range(3)], [max(p[i] for p in rb) for i in range(3)]


def signature(rec):
    corners = sorted(tuple(round(v, 5) for v in p) for p in rec["points"])
    return hashlib.sha1(repr((rec["obj"].name, corners, tuple(rec["normal"]))).encode()).hexdigest()[:16]


def records(sources):
    out = []
    for obj in sources:
        if obj.name not in NAMES:
            continue
        mw = obj.matrix_world
        assert max(abs(mw[i][j] - (1 if i == j else 0)) for i in range(4) for j in range(4)) < 1e-6, obj.name
        for p in obj.data.polygons:
            if p.area < 1e-5:
                continue
            rec = dict(obj=obj, index=p.index, points=[mw @ obj.data.vertices[i].co for i in p.vertices],
                       normal=p.normal.copy(), area=p.area)
            rec["id"] = signature(rec)
            out.append(rec)
    return out


def candidates(recs):
    """Legacy coarse candidates, followed by strict per-vertex plane verification."""
    planes = defaultdict(list)
    for rec in recs:
        n = rec["normal"]
        k = [round(c, 2) for c in n]
        planes[(*k, round(n.dot(rec["points"][0]), 2))].append(rec)
    out = []
    for faces in planes.values():
        if len(faces) < 2:
            continue
        u, v = basis(faces[0]["normal"])
        flat = [project(f["points"], u, v) for f in faces]
        cells = defaultdict(list)
        for i, poly in enumerate(flat):
            for x in range(math.floor(min(p[0] for p in poly) / 4), math.floor(max(p[0] for p in poly) / 4) + 1):
                for y in range(math.floor(min(p[1] for p in poly) / 4), math.floor(max(p[1] for p in poly) / 4) + 1):
                    cells[x, y].append(i)
        seen = set()
        for members in cells.values():
            for ai, i in enumerate(members):
                for j in members[ai + 1:]:
                    if (i, j) in seen:
                        continue
                    seen.add((i, j))
                    a, b = faces[i], faces[j]
                    pair = tuple(sorted((a["obj"].name, b["obj"].name)))
                    if pair not in GROUP_COUNTS:
                        continue
                    overlap = intersect(flat[i], flat[j])
                    area = abs(signed_area(overlap)) if overlap else 0.0
                    if area < 1e-4:
                        continue
                    da = max(abs(a["normal"].dot(p - a["points"][0])) for p in b["points"])
                    db = max(abs(b["normal"].dot(p - b["points"][0])) for p in a["points"])
                    dot = a["normal"].dot(b["normal"])
                    arange = [a["normal"].dot(p-a["points"][0]) for p in b["points"]]
                    brange = [b["normal"].dot(p-b["points"][0]) for p in a["points"]]
                    parallel = max(max(arange)-min(arange), max(brange)-min(brange)) <= PLANE_EPS
                    out.append(dict(a=a, b=b, pair=pair, area=area, distance=max(da, db), dot=dot,
                                    repairable=max(da, db) <= NEAR_EPS and dot >= 1-NORMAL_EPS and parallel,
                                    strict=max(da, db) <= PLANE_EPS and dot >= 1 - NORMAL_EPS))
    return out


def triangles(rec, u, v):
    pts = rec["points"]
    # Blender's tessellator respects concave polygon outlines; no convex-hull fill.
    return [project([pts[i] for i in ids], u, v) for ids in tess_indices(pts)]


def tess_indices(coords):
    # Blender 5.2 returns corner indices; earlier mathutils returned Vectors.
    result = tessellate_polygon([coords])
    return [list(t) if isinstance(t[0], int) else
            [min(range(len(coords)), key=lambda i: (coords[i] - q).length_squared) for q in t] for t in result]


def priority(rec):
    material = rec["obj"].name.rsplit("__", 1)[-1]
    overlay = material in {"glow_aqua", "gold", "trim"}
    # Faces here share an oriented normal. Greatest plane depth is the actual
    # outward surface (including lowest undersides); no assembly is translated.
    depth = rec["normal"].dot(sum(rec["points"], Vector()) / len(rec["points"]))
    return (0 if overlay else 1, -round(depth, 4), -round(rec["area"], 6), rec["obj"].name, rec["id"])


def payload(pair):
    a, b = pair["a"], pair["b"]
    owner, background = sorted((a, b), key=priority)
    da = [a["normal"].dot(p-a["points"][0]) for p in b["points"]]
    db = [b["normal"].dot(p-b["points"][0]) for p in a["points"]]
    return dict(group=list(pair["pair"]), a=pair["a"]["id"], b=pair["b"]["id"],
                a_face=pair["a"]["index"], b_face=pair["b"]["index"], area=pair["area"],
                max_plane_distance=pair["distance"], normal_dot=pair["dot"], confirmed=pair["strict"],
                repairable=pair["repairable"],
                owner=dict(chunk=owner["obj"].name, id=owner["id"]),
                clipped_background=dict(chunk=background["obj"].name, id=background["id"]),
                a_to_b_signed_range=[min(da), max(da)], b_to_a_signed_range=[min(db), max(db)],
                a_bounds=bounds(pair["a"]["points"]), b_bounds=bounds(pair["b"]["points"]))


def barycentric(p, a, b, c):
    den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    assert abs(den) > 1e-12
    x = ((b[1] - c[1]) * (p[0] - c[0]) + (c[0] - b[0]) * (p[1] - c[1])) / den
    y = ((c[1] - a[1]) * (p[0] - c[0]) + (a[0] - c[0]) * (p[1] - c[1])) / den
    return x, y, 1 - x - y


def rewrite(obj, replacements):
    me = obj.data
    # Source has no authored custom normals. Preserve all existing BMesh layers;
    # refusing unknown custom normals prevents silently discarding future art.
    assert not me.has_custom_normals, (obj.name, "custom normals need explicit interpolation")
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    original_faces = dict(enumerate(bm.faces))
    uv_layers = list(bm.loops.layers.uv.values())
    color_layers = list(bm.loops.layers.color.values()) + list(bm.loops.layers.float_color.values())
    vert_color_layers = list(bm.verts.layers.color.values()) + list(bm.verts.layers.float_color.values())
    audit = dict(custom_normals=False, uv_layers=list(me.uv_layers.keys()),
                 colors=[(a.name, a.domain, a.data_type) for a in me.color_attributes], faces=[])
    for index, rec, fragments, u, v in replacements:
        original = original_faces[index]
        orig_loops = list(original.loops)
        coords = [l.vert.co.copy() for l in orig_loops]
        projected = project(coords, u, v)
        # Tessellation indices provide the original corner source of every attribute.
        corner_triangles = tess_indices(coords)
        original_area = original.calc_area()
        emitted = 0.0
        for poly in fragments:
            if signed_area(poly) < 0:
                poly = list(reversed(poly))
            # Convex pieces from subtraction can be emitted as convex ngons;
            # this avoids unnecessary new diagonals/triangle growth.
            verts = []
            attributes = []
            for p in poly:
                choices = []
                for ids in corner_triangles:
                    weights = barycentric(p, *(projected[i] for i in ids))
                    choices.append((min(weights), ids, weights))
                _, ids, weights = max(choices, key=lambda row: row[0])
                assert min(weights) > -2e-4, (obj.name, index, p, weights)
                # Accumulate in Python doubles before one float32 mesh conversion.
                # Repeated mathutils Vector additions tilt very thin seam fragments.
                co = Vector(tuple(sum(float(coords[i][k]) * w for i, w in zip(ids, weights)) for k in range(3)))
                assert all(math.isfinite(c) for c in co)
                vert = bm.verts.new(co)
                for layer in vert_color_layers:
                    vert[layer] = tuple(sum(orig_loops[i].vert[layer][k] * w for i, w in zip(ids, weights)) for k in range(4))
                verts.append(vert)
                attrs = {}
                for layer in uv_layers:
                    attrs[layer] = sum((orig_loops[i][layer].uv * w for i, w in zip(ids, weights)), Vector((0, 0)))
                for layer in color_layers:
                    attrs[layer] = tuple(sum(orig_loops[i][layer][k] * w for i, w in zip(ids, weights)) for k in range(4))
                attributes.append(attrs)
            face = bm.faces.new(verts)
            face.material_index, face.smooth = original.material_index, original.smooth
            for loop, attrs in zip(face.loops, attributes):
                for layer in uv_layers:
                    loop[layer].uv = attrs[layer]
                for layer in color_layers:
                    loop[layer] = attrs[layer]
            face.normal_update()
            assert face.normal.dot(rec["normal"]) > .9999, (obj.name, index, list(face.normal), list(rec["normal"]),
                                                           face.calc_area(), poly, [list(v.co) for v in verts])
            emitted += face.calc_area()
        audit["faces"].append(dict(id=rec["id"], original_area=original_area, kept_area=emitted,
                                   fragments=len(fragments), smooth=original.smooth))
        bmesh.ops.delete(bm, geom=[original], context="FACES_ONLY")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.update()
    assert not me.validate(verbose=True), (obj.name, "mesh validate repaired invalid geometry")
    return audit


def contains(poly, p, tol=1e-5):
    direction = 1 if signed_area(poly) >= 0 else -1
    return all(direction * ((poly[(i+1)%len(poly)][0]-a[0])*(p[1]-a[1]) -
                            (poly[(i+1)%len(poly)][1]-a[1])*(p[0]-a[0])) >= -tol
               for i, a in enumerate(poly))


def verify_coverage(affected, fragments, frames):
    """Boundary/interior witness check complements exact convex-difference accounting.

    Every emitted point remains in its original polygon; original triangulated
    footprint witnesses must remain covered by a current owner on that plane.
    """
    witnesses = 0
    for rec in affected.values():
        u, v = frames[rec["id"]]
        original = triangles(rec, u, v)
        for poly in fragments[rec["id"]]:
            assert all(any(contains(t, p) for t in original) for p in poly), (rec["id"], "fragment outside original")
        owners = []
        for other in affected.values():
            if rec["normal"].dot(other["normal"]) < 1-NORMAL_EPS:
                continue
            if max(abs(rec["normal"].dot(p-rec["points"][0])) for p in other["points"]) > NEAR_EPS:
                continue
            ou, ov = frames[other["id"]]
            n = other["normal"]
            d = n.dot(other["points"][0])
            owners.extend(project([ou*p[0]+ov*p[1]+n*d for p in poly], u, v) for poly in fragments[other["id"]])
        for t in original:
            for a in range(9):
                for b in range(9-a):
                    weights = (a/8, b/8, 1-(a+b)/8)
                    p = tuple(sum(t[i][k]*weights[i] for i in range(3)) for k in range(2))
                    assert any(contains(poly, p, 2e-4) for poly in owners), (rec["id"], "surface hole", p)
                    witnesses += 1
    return witnesses


def fix(sources, artifact_dir=None):
    recs = records(sources)
    pairs = candidates(recs)
    counts = defaultdict(int)
    for pair in pairs:
        counts[pair["pair"]] += 1
        for rec in (pair["a"], pair["b"]):
            lo, hi = bounds(rec["points"])
            guard_lo, guard_hi = GUARDS[rec["obj"].name.split("__")[0]]
            assert all(guard_lo[k] <= lo[k] <= hi[k] <= guard_hi[k] for k in range(3)), (rec["obj"].name, lo, hi)
    assert dict(counts) == GROUP_COUNTS, ("baseline candidates changed; inspect before modifying geometry", dict(counts))
    assert all(p["repairable"] for p in pairs), ("sloped/crossing candidate requires a local repair", [payload(p) for p in pairs if not p["repairable"]])
    affected = {r["id"]: r for p in pairs for r in (p["a"], p["b"])}
    neighbors = defaultdict(list)
    for p in pairs:
        a, b = sorted((p["a"], p["b"]), key=priority)
        neighbors[b["id"]].append(a)
    fragments, frames, replacements = {}, {}, defaultdict(list)
    removed_area = 0.0
    for rec in sorted(affected.values(), key=priority):
        u, v = basis(rec["normal"])
        current = triangles(rec, u, v)
        before = sum(abs(signed_area(p)) for p in current)
        # Current higher-priority owner fragments, not stale original polygons:
        # triple intersections retain exactly one surface owner.
        for owner in sorted(neighbors[rec["id"]], key=priority):
            ou, ov = frames[owner["id"]]
            on = owner["normal"]
            od = on.dot(owner["points"][0])
            for piece in fragments[owner["id"]]:
                cutter = project([ou * p[0] + ov * p[1] + on * od for p in piece], u, v)
                next_fragments = []
                for poly in current:
                    kept, _ = subtract(poly, cutter)
                    next_fragments.extend(kept)
                current = next_fragments
        after = sum(abs(signed_area(p)) for p in current)
        fragments[rec["id"]], frames[rec["id"]] = current, (u, v)
        if before - after > AREA_EPS:
            removed_area += before - after
            replacements[rec["obj"]].append((rec["index"], rec, current, u, v))
    witnesses = verify_coverage(affected, fragments, frames)
    audits = {obj.name: rewrite(obj, rows) for obj, rows in replacements.items()}
    after_pairs = candidates(records(sources))
    strict_after = [p for p in after_pairs if p["strict"]]
    assert not after_pairs, ("overlapping exact/near-plane footprints remain", [payload(p) for p in after_pairs[:10]])
    ledger = dict(candidate_pairs=len(pairs), confirmed_pairs=sum(p["strict"] for p in pairs),
                  removed_surface_area=removed_area, coverage_witnesses=witnesses, changed_chunks=sorted(audits), attributes=audits,
                  before=[payload(p) for p in pairs], after=[payload(p) for p in after_pairs],
                  near_plane_repaired=[payload(p) for p in pairs if not p["strict"]], exclusions=[])
    if artifact_dir:
        path = Path(artifact_dir)
        path.mkdir(parents=True, exist_ok=True)
        (path / "repair-ledger.json").write_text(json.dumps(ledger, indent=2))
    print("WORLD OVERLAPS", len(pairs), "candidates", ledger["confirmed_pairs"], "confirmed; changed", sorted(audits),
          "remaining", len(after_pairs), "coarse,", len(strict_after), "confirmed")
    return set(audits), ledger


def self_test():
    square = [(0, 0), (2, 0), (2, 2), (0, 2)]
    cases = [(square, [], 0), ([(.5, .5), (1.5, .5), (1.5, 1.5), (.5, 1.5)], None, 3),
             ([(1, -1), (3, -1), (3, 3), (1, 3)], None, 2),
             ([(2, 0), (3, 0), (3, 2), (2, 2)], None, 4)]
    for cutter, _, expected in cases:
        pieces, _ = subtract(square, cutter)
        assert abs(sum(abs(signed_area(p)) for p in pieces) - expected) < 1e-7
        assert all(not intersect(p, cutter) for p in pieces)
    # Triple ownership: clipping an already clipped owner cannot remove a hole.
    first = [(0, 0), (1, 0), (1, 2), (0, 2)]
    second, _ = subtract(square, first)
    third = [square]
    for cutter in [first] + second:
        third = [piece for p in third for piece in subtract(p, cutter)[0]]
    assert not third
    print("WORLD OVERLAP polygon self-tests PASS (containment, partial, shared edge, triple)")
