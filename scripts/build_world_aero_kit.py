"""Build the Aero world kit (WORLD-PASS-2026-11-22 row 6; artifacts/world-pass-2026-11-22/reexport/PLAN.md).

Run in BACKGROUND Blender only (the import .blend is never saved):
  blender.exe -b assets/art-source/environment/world1-mockup-v7-import.blend --python scripts/build_world_aero_kit.py

An additive kit that only the Aero look shows (live keeps the merged island exactly as it is):
- Crowns: the island's tree crowns split out of the merged W7_Vegetation__foliage / __foliage_blossom meshes. Three
  shared meshes (Round, Tall, Blossom: one per tree kind, placed per tree) plus the Hatch Tree's own crown, each with
  its pivot at the trunk top so it can sway. The builder rebuilds the merged meshes from the same chunks with the
  chunk script's own declutter and QA fixes, checks their geometry hash against assets/world/world-v7-manifest.json,
  and proves every placed shared crown lands on its tree's leaves (max vertex error under MAX_FIT studs).
- Rest: what the merged crown meshes hold besides trees (the blob bushes), static, so the merged parts can hide.
- Falls (LOOK-R2 2): ONE vertex-coloured mesh for Tumble Falls: dark wet rock faces with ledges, five white chutes per
  drop on the beam curve, and the wet rocks. Rock footprints are checked against the pets' surface map: only water,
  rock, empty or ground pets cannot reach (above LEDGE_Y).
- Fountain (LOOK-R2 3): a two-tier stone fountain inside the Bubble Spring's basin (its glass bubbles are hidden).

Writes (never touches the island export, its manifest, walk map or the native collision checkpoint):
- assets/world/aero-kit/aero-kit.fbx            every kit mesh, origin at its bounds centre
- assets/world/aero-kit/aero-kit-manifest.json  meshes (tris, size, hash), crown instances, rocks, falls frames

Then: upload the FBX as one Model, read MeshId / MeshSize back, and run scripts/build_world_aero_kit_assets.py.
Coordinates: Blender (x, y, z) = Roblox (x, z + 4, -y). Roblox import turns each mesh by pi about Y.

The trunk pack (GARDEN-B38-BRIEF 4a, the tree grades), its own upload so the kit above is untouched:
  blender.exe -b assets/art-source/environment/world1-mockup-v7-import.blend --python scripts/build_world_aero_kit.py -- --trunks
splits the island's trunks out of the merged W7_Trunks__bark (Vegetation_Trees__bark and Vegetation_HatchTree__bark):
three shared trunks (Round, Tall, Blossom: one per tree kind, origin at the tree's root, placed per tree and proven on
every tree's own bark like the crowns) and the two landmarks' trunks as one static mesh, so the merged part can hide
its visual (its collision stays). Writes assets/world/aero-trunks/aero-trunks.fbx and aero-trunks-manifest.json; then
upload the FBX as one Model, read MeshId / MeshSize back and run build_world_aero_kit_assets.py --trunks --confirm.
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
from mathutils.kdtree import KDTree

ROOT = Path(bpy.data.filepath).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
import build_world_v7_chunks as C  # noqa: E402  (main() only runs as __main__)

OUT = ROOT / "assets" / "world" / "aero-kit"
MAX_FIT = 0.01
LEDGE_Y = 15.0  # pets never reach ground above this (the falls ledge is walled; WORLD-PASS 5)
PET_OK = set("W R .".split())  # surface codes a rock may cover

# Tree kinds: the clump tables of artifacts/world1-mockup/v7/build_world_v7.py (x, y, z, radius, squash); the trunk top
# (the crown's pivot) is tree_mesh_v7's (c0.x + lean, c0.y, c0.z - c0.r * c0.sq * .2).
LEAN = .4
FIRST_CLUMP = {"Tree_Round": (0, 0, 8.5, 3.6, .78), "Tree_Tall": (0, 0, 8.8, 3.0, .82), "Tree_Blossom": (0, 0, 7.4, 3.4, .74)}
KIND = {"Tree_Round": ("Crown_Round", "foliage"), "Tree_Tall": ("Crown_Tall", "foliage"),
        "Tree_Blossom": ("Crown_Blossom", "foliage_blossom")}



def rb(v):
    return [round(v[0], 4), round(v[2] + 4, 4), round(-v[1], 4)]


def bl(x, y, z):
    """Roblox studs to Blender."""
    return Vector((x, -z, y - 4))


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
    return h.hexdigest()[:16]


# ----------------------------------------------------------------------------------------------------------- sources
def prepared_sources():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    sources = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
    sources = C.declutter(sources)
    return C.qa_fixes(sources)


def check_merged(sources):
    """The kit is cut from exactly the geometry the island ships."""
    manifest = {p["name"]: p for p in json.loads((ROOT / "assets/world/world-v7-manifest.json").read_text())["parts"]}
    groups = {}
    for o in sources:
        groups.setdefault(C.classify(o.name)[0], []).append(o)
    out = {}
    for key in ("Vegetation__foliage", "Vegetation__foliage_blossom", "Water__waterfall_tumble"):
        objs = groups[key]
        joined = C.join([C.duplicate(o, "chk_" + o.name) for o in objs], "chk_" + key)
        C.recentre(joined)
        got, want = C.geom_hash(joined), manifest["W7_" + key]["hash"]
        assert got == want, ("merged geometry drifted", key, got, want)
        out[key] = [o.name for o in objs]
        bpy.data.objects.remove(joined, do_unlink=True)
    print("KIT merged hashes match:", sorted(out))
    return out


def world_verts(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def islands(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            comp.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        out.append(comp)
    bm.free()
    return out


def sub_object(src, vert_ids, name):
    """A new object holding the faces of `src` whose vertices are all in vert_ids, in world coordinates."""
    keep = set(vert_ids)
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bm.transform(src.matrix_world)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for mat in src.data.materials:
        me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ------------------------------------------------------------------------------------------------------------ crowns
# LOOK-R3 2 (Fable, 2026-11-23): Round, Tall and Blossom rebuilt as 5-7 uneven clumps with a flat underside and ragged
# rim tufts, at today's triangle counts. Clump 0 is today's, so the trunk top (the pivot) and the sway do not move.
# Clumps: (x, y, z, radius, squash, segments, latitude bands): an ellipsoid of 2 * segments * (bands - 1) triangles.
# Tufts: (angle in degrees, z of a shoulder tuft or None for the rim). A tuft is a 4-sided spike with no base, 4 triangles.
UV_SCALE_DENSE = .375  # Fable R5: the lime leaves at about 0.5 stud (1.5x the tile)
CARD_SIDES = 10        # a leaf-cluster card: a scalloped disc of 10 triangles
CARD_RADIUS = (1.0, 1.5)
CARD_BUDGET = 1000     # extra triangles all placed crowns' cards may add (ALIVE-SAFETY: counted on their own)
RESHAPE = {
    "Crown_Round": {"floor": 5.6, "tris": 240,
                    "clumps": [(0, 0, 8.5, 3.6, .78, 8, 4), (2.5, .7, 7.2, 2.7, .74, 8, 3), (-2.3, -1, 7.4, 2.5, .74, 8, 3),
                               (.4, 2.3, 9.4, 2.1, .8, 8, 3), (-.6, -2.4, 8.8, 2, .78, 8, 3), (-1.3, .9, 10.7, 1.8, .82, 5, 3),
                               (1.5, -1.2, 10.3, 1.4, .85, 5, 3)],
                    "tufts": [(20, None), (75, None), (140, None), (200, None), (255, None), (320, None)]},
    "Crown_Tall": {"floor": 6.4, "tris": 220,
                   "clumps": [(0, 0, 8.8, 3, .82, 11, 3), (.5, .3, 10.9, 2.5, .86, 10, 3), (-.4, -.4, 12.8, 2, .9, 6, 4),
                              (.1, .1, 14.6, 1.3, 1, 6, 3), (1.6, -.8, 9.5, 1.6, .78, 6, 3), (-1.5, .9, 10.2, 1.4, .78, 6, 3)],
                   "tufts": [(30, None), (120, None), (210, None), (300, None), (75, 9.6), (195, 11.6), (315, 13.6)]},
    # Fable R5 (W2): the lime crown's edge is leaves, not facets: 12 leaf-cluster cards on the outline (10 triangles
    # each), the skirt's spikes gone, and its leaf tile 1.5x denser.
    "Crown_Blossom": {"floor": 4.9, "tris": 216 + 12 * 10, "cards": 12, "uv": UV_SCALE_DENSE,
                      "clumps": [(0, 0, 7.4, 3.4, .74, 8, 4), (2.4, -.5, 6.6, 2.6, .72, 8, 3), (-2.2, 1, 6.8, 2.5, .72, 8, 3),
                                 (.4, 2.1, 8.3, 1.9, .78, 8, 3), (-.5, -2.2, 8, 1.9, .78, 8, 3), (1.4, .9, 9.1, 1.5, .8, 5, 3),
                                 (-1.3, -.6, 8.9, 1.3, .82, 5, 3)],
                      "tufts": []},
}
# The rim tufts a carded crown dropped (Fable R5): their triangles are no longer in the crown (the kit tests read
# `droppedTufts` from the manifest).
RESHAPE_TUFTS_DROPPED = {"Crown_Blossom": ((35, None), (95, None), (150, None), (215, None), (270, None), (330, None))}
RESHAPE_KIND = {"Crown_Round": "Tree_Round", "Crown_Tall": "Tree_Tall", "Crown_Blossom": "Tree_Blossom"}
UV_SCALE = .25          # one 4-stud leaf tile (LOOK-R3 2), box-mapped by face normal (per crown: spec "uv")
JITTER = .13            # of each clump's radius (LOOK-R3 round 6: .08 read as regular)
TILT = (20, 40)         # degrees each clump's pole leans, random direction (round 6: all poles up made lids)
TUFT_IN = .3            # studs a tuft's root sits inside the leaves (round 6: rim roots floated in clear air)
CREASE = .85            # a vertex inside another clump
UNDER = {"foliage": (0xA6 / 255, 0xB8 / 255, 0xAE / 255), "foliage_blossom": (0xA1 / 255, 0xCE / 255, 0xB7 / 255)}
OVERHANG_MAX = 1.0      # studs the new crown may stand outside today's bounds (rim tufts), any side
TRUNK_DEPTH_MIN = .5    # the trunk top sits this far above the flat underside at least
RING_PHI = {3: (0, 48, 108, 180), 4: (0, 36, 74, 118, 180)}  # latitudes (degrees from the top) per band count


def smooth01(k):
    k = min(max(k, 0.0), 1.0)
    return k * k * (3 - 2 * k)


def in_clump(p, cl, k=1.0):
    x, y, z, r, sq = cl[:5]
    return ((p.x - x - LEAN) / (r * k)) ** 2 + ((p.y - y) / (r * k)) ** 2 + ((p.z - z) / (r * sq * k)) ** 2 < 1


def rim_radius(cl, z):
    x, y, cz, r, sq = cl[:5]
    return r * math.sqrt(max(0.0, 1 - ((z - cz) / (r * sq)) ** 2))


def new_crown(name, material, pivot, materials):
    """The reshaped crown in its tree's frame at scale 1, pivot at the origin (as the shared crowns are)."""
    spec = RESHAPE[name]
    name = name + "__" + material
    rng = random.Random(name)
    uv_scale = spec.get("uv", UV_SCALE)
    card_faces = set()
    floor = spec["floor"]
    clumps = spec["clumps"]
    top = max(c[2] + c[3] * c[4] for c in clumps)
    under = UNDER[material]
    bm = bmesh.new()
    col = bm.loops.layers.float_color.new("Col")
    uvl = bm.loops.layers.uv.new("UVMap")
    tag = bm.faces.layers.int.new("kit_card")  # made before any face: adding a layer later invalidates face references
    normal_of, shade_of = {}, {}

    def shade(p, own):
        c = mix(under, (1.0, 1.0, 1.0), smooth01((p.z - floor) / (top - floor)))
        if any(in_clump(p, cl) for i, cl in enumerate(clumps) if i != own):
            c = tuple(v * CREASE for v in c)
        return c

    for ci, cl in enumerate(clumps):
        x, y, z, r, sq, seg, bands = cl
        cen = Vector((x + LEAN, y, z))
        lean_dir = rng.uniform(0, 2 * math.pi)
        tilt = Matrix.Rotation(math.radians(rng.uniform(*TILT)), 3, Vector((math.cos(lean_dir), math.sin(lean_dir), 0)))
        rows = []
        # Studio r5: evenly spaced latitudes put a 3-band clump's two rings at the same radius (a prism: the crowns read
        # as boxes). Uneven latitudes give a rounded top and a fuller lower belly at the same triangle count.
        phis = RING_PHI[bands]
        for b_ in range(bands + 1):
            phi = math.radians(phis[b_]) + (rng.uniform(-6, 6) * math.pi / 180 if 0 < b_ < bands else 0)
            row = []
            for s_ in range(1 if b_ in (0, bands) else seg):
                th = 2 * math.pi * (s_ + (.5 if b_ % 2 else 0)) / seg + ci * .7
                d = Vector((math.sin(phi) * math.cos(th), math.sin(phi) * math.sin(th), math.cos(phi)))
                j = 1 + rng.uniform(-JITTER, JITTER)
                p = cen + tilt @ Vector((d.x * r * j, d.y * r * j, d.z * r * sq * j))
                clamped = p.z < floor
                if clamped:
                    p.z = floor                         # the flat underside: clamp, no cap (caps cost triangles)
                v = bm.verts.new(p - pivot)
                n = (tilt @ Vector((d.x / r, d.y / r, d.z / (r * sq)))).normalized()
                normal_of[v] = (n + Vector((0, 0, -1))).normalized() if clamped else n
                shade_of[v] = shade(p, ci)
                row.append(v)
            rows.append(row)
        for b_ in range(bands):
            a_, b2 = rows[b_], rows[b_ + 1]
            for s_ in range(seg):
                if len(a_) == 1:
                    bm.faces.new((a_[0], b2[(s_ + 1) % seg], b2[s_]))
                elif len(b2) == 1:
                    bm.faces.new((a_[s_], a_[(s_ + 1) % seg], b2[0]))
                else:
                    p0, p1, q0, q1 = a_[s_], a_[(s_ + 1) % seg], b2[s_], b2[(s_ + 1) % seg]
                    bm.faces.new((p0, p1, q1))
                    bm.faces.new((p0, q1, q0))
    # Tufts, rooted on the built mesh (round 6): the leaf vertex that reaches furthest out at that angle, in the rim band
    # (just above the flat underside) or on the shoulder band, pulled TUFT_IN studs back into the leaves.
    leaf_pts = [v.co + pivot for v in bm.verts]
    for angle, shoulder in spec["tufts"]:
        th = math.radians(angle)
        out = Vector((math.cos(th), math.sin(th), 0))
        band = []
        for reach, cone in ((.9, .85), (1.5, .75), (2.2, .6)):    # widen until some leaves face that way
            lo, hi = (floor, floor + reach) if shoulder is None else (shoulder - reach, shoulder + reach)
            band = [q for q in leaf_pts if lo <= q.z <= hi and Vector((q.x - LEAN, q.y, 0)).normalized().dot(out) > cone]
            if band:
                break
        assert band, (name, "no leaves for the tuft at", angle, shoulder)
        edge = max(band, key=lambda q: q.dot(out))
        root = edge - out * TUFT_IN
        root.z = max(root.z, floor + .25)
        if shoulder is None:
            tip = root + out * (TUFT_IN + rng.uniform(.5, .8)) + Vector((0, 0, -.6))
        else:
            down = (out * math.cos(math.radians(20)) - Vector((0, 0, math.sin(math.radians(20))))).normalized()
            tip = root + down * (TUFT_IN + rng.uniform(.5, .8))
        side = Vector((-out.y, out.x, 0))
        half = .45
        base = [root + side * half, root + Vector((0, 0, half * .8)), root - side * half, root - Vector((0, 0, half * .5))]
        c = shade(root, -1)
        tv = bm.verts.new(tip - pivot)
        normal_of[tv] = (tip - root).normalized()
        shade_of[tv] = c
        bv = []
        for q in base:
            v = bm.verts.new(q - pivot)
            normal_of[v] = ((q - root).normalized() + out).normalized()
            shade_of[v] = c
            bv.append(v)
        for k in range(4):
            bm.faces.new((bv[k], bv[(k + 1) % 4], tv))
    # Code review r3: the clump fans and quads were wound inward (only the tufts faced out); each clump and tuft is its
    # own closed or open island, so recalculating faces them all out, as Builder.build does.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Leaf-cluster cards (Fable R5): on the outline, round the crown at three heights, each a scalloped disc lying on
    # the surface and facing out, centred on the leaf vertex that reaches furthest that way.
    up = Vector((0, 0, 1))
    leaf_pts = [v.co + pivot for v in bm.verts]
    lo_z, hi_z = floor + 1.0, top - 1.2
    for i in range(spec.get("cards", 0)):
        ang = 2 * math.pi * i / spec["cards"] + rng.uniform(-.2, .2)
        zc = lo_z + (hi_z - lo_z) * ((i * 0.38) % 1.0)
        out = Vector((math.cos(ang), math.sin(ang), 0))
        band = [q for q in leaf_pts if abs(q.z - zc) < 1.2 and Vector((q.x - LEAN, q.y, 0)).normalized().dot(out) > .7]
        assert band, (name, "no outline for card", i)
        edge = max(band, key=lambda q: Vector((q.x - LEAN, q.y, 0)).dot(out))   # from the trunk axis, as the band
        normal = (out + up * .25).normalized()
        e1 = up.cross(normal).normalized()
        e2 = normal.cross(e1).normalized()
        r = rng.uniform(*CARD_RADIUS)
        centre = edge + normal * .05
        cv = bm.verts.new(centre - pivot)
        normal_of[cv] = normal
        shade_of[cv] = shade(edge, -1)
        rim = []
        for k in range(CARD_SIDES):
            a = 2 * math.pi * k / CARD_SIDES
            rr = r * (1 + (.2 if k % 2 else -.1) + rng.uniform(-.06, .06))
            q = centre + e1 * (rr * math.cos(a)) + e2 * (rr * math.sin(a))
            v = bm.verts.new(q - pivot)
            normal_of[v] = normal
            shade_of[v] = shade_of[cv]
            rim.append(v)
        for k in range(CARD_SIDES):
            f = bm.faces.new((cv, rim[k], rim[(k + 1) % CARD_SIDES]))
            card_faces.add(f)
    bm.normal_update()
    for face in bm.faces:
        face.smooth = True
        fn = face.normal
        ax = max(range(3), key=lambda k: abs(fn[k]))
        for loop in face.loops:
            q = loop.vert.co + pivot                    # tree frame: the tile does not move with the pivot
            if ax == 0:
                loop[uvl].uv = (q.y * uv_scale, q.z * uv_scale)
            elif ax == 1:
                loop[uvl].uv = (q.x * uv_scale, q.z * uv_scale)
            else:
                loop[uvl].uv = (q.x * uv_scale, q.y * uv_scale)
            c = shade_of[loop.vert]
            loop[col] = (c[0], c[1], c[2], 1.0)
    order = list(bm.verts)
    normals = [tuple(normal_of[v]) for v in order]
    for f in card_faces:
        f[tag] = 1
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # The shading is authored as sRGB values (FBX colors_type SRGB, as the falls and the old lime gradient).
    attr = me.color_attributes["Col"]
    for i in range(len(me.loops)):
        c = tuple(attr.data[i].color)
        attr.data[i].color_srgb = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = attr
    me.normals_split_custom_set_from_vertices(normals)
    for m in materials:
        me.materials.append(m)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def bounds(vs):
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    return lo, hi


def reshape(canon):
    """Swap the proven shared crowns' geometry for LOOK-R3's. Every tree was proven on today's geometry (its crown sits
    on its own leaves: pivot, yaw and scale), so checking the new geometry against today's in the shared frame covers
    every tree: today's triangle count, inside today's bounds by OVERHANG_MAX, the flat underside at least
    TRUNK_DEPTH_MIN below the trunk top, the trunk top inside clump 0, no zero-area triangle."""
    for name, spec in RESHAPE.items():
        entry = canon[name]
        old = entry["obj"]
        c0 = FIRST_CLUMP[RESHAPE_KIND[name]]
        assert tuple(spec["clumps"][0][:5]) == tuple(c0), (name, "clump 0 moved")
        old_lo, old_hi = bounds([v.co for v in old.data.vertices])
        obj = new_crown(name, entry["material"], entry["pivot"], list(old.data.materials))
        new_lo, new_hi = bounds([v.co for v in obj.data.vertices])
        tris = C.tris(obj)
        card_tris = sum(1 for poly, flag in zip(obj.data.polygons, obj.data.attributes["kit_card"].data) if flag.value == 1) \
            if "kit_card" in obj.data.attributes else 0
        dropped = 4 * len(RESHAPE_TUFTS_DROPPED.get(name, ()))
        assert tris == spec["tris"] and tris - card_tris == C.tris(old) - dropped, \
            (name, "triangles", tris, card_tris, C.tris(old), spec["tris"])
        assert card_tris == spec.get("cards", 0) * CARD_SIDES, (name, "card triangles", card_tris)
        overhang = max(max(old_lo[i] - new_lo[i], new_hi[i] - old_hi[i]) for i in range(3))
        # A card lies along the outline: up to its largest rim (radius x (1 + .2 + .06)).
        limit = CARD_RADIUS[1] * 1.26 if spec.get("cards") else OVERHANG_MAX
        assert overhang <= limit, (name, "overhang", overhang, limit)
        trunk_depth = entry["pivot"].z - spec["floor"]     # the pivot is the trunk top
        assert trunk_depth >= TRUNK_DEPTH_MIN, (name, "trunk depth", trunk_depth)
        assert in_clump(entry["pivot"], c0, .999), (name, "trunk top outside clump 0")
        degenerate = sum(1 for poly in obj.data.polygons if poly.area < 1e-6)
        assert degenerate == 0, (name, "zero-area triangles", degenerate)
        entry["reshape"] = {"overhang": round(overhang, 4), "overhangMax": limit, "floor": round(-trunk_depth, 4), "trunkDepth": round(trunk_depth, 4),
                            "cardTris": card_tris, "droppedTufts": dropped, "cardBudget": CARD_BUDGET,
                            "oldBounds": [rb(old_lo), rb(old_hi)], "newBounds": [rb(new_lo), rb(new_hi)], "tris": tris}
        bpy.data.objects.remove(old, do_unlink=True)
        entry["obj"] = obj
        print("KIT reshape", name, entry["reshape"])


def placements():
    data = json.loads((ROOT / "artifacts/world1-mockup/v7/vegetation-placements.json").read_text())["instances"]
    removed = set(json.loads((ROOT / "assets/world/world-v7-declutter.json").read_text())["removed"])
    return [p for p in data if p["mesh"] in KIND and p["object"] not in removed]


def placement_matrix(p):
    x, y, z = p["roblox_position"]
    loc = bl(x, y, z)
    return Matrix.Translation(loc) @ Matrix.Rotation(p["yaw_rad"], 4, "Z") @ Matrix.Scale(p["scale"], 4)


def assign(chunk, trees):
    """Island vertex lists of a merged tree chunk, grouped by the tree they belong to (nearest trunk, in plan)."""
    pts = world_verts(chunk)
    owner = {}
    for comp in islands(chunk):
        cx = sum(pts[i].x for i in comp) / len(comp)
        cy = sum(pts[i].y for i in comp) / len(comp)
        best = min(trees, key=lambda p: (placement_matrix(p).translation.x - cx) ** 2 + (placement_matrix(p).translation.y - cy) ** 2)
        owner.setdefault(best["object"], []).extend(comp)
    return owner, pts


def crowns(sources):
    trees = placements()
    objects = {o.name: o for o in sources}
    canon, instances = {}, []
    for chunk_name, kinds in (("Vegetation_Trees__foliage", ("Tree_Round", "Tree_Tall")),
                              ("Vegetation_Trees__foliage_blossom", ("Tree_Blossom",))):
        chunk = objects[chunk_name]
        # The Blossom Point tree is a landmark: its crown is in the Hatch chunk (below).
        group = [p for p in trees if p["mesh"] in kinds and not p["object"].startswith("Landmark_")]
        owner, pts = assign(chunk, group)
        assert len(owner) == len(group), (chunk_name, sorted(owner), [p["object"] for p in group])
        for p in sorted(group, key=lambda q: q["object"]):
            name, material = KIND[p["mesh"]]
            inverse = placement_matrix(p).inverted()
            ids = owner[p["object"]]
            if name not in canon:
                obj = sub_object(chunk, ids, name + "__" + material)
                obj.data.transform(inverse)  # tree-local, Blender units at scale 1
                c0 = FIRST_CLUMP[p["mesh"]]
                pivot = Vector((c0[0] + LEAN, c0[1], c0[2] - c0[3] * c0[4] * .2))
                obj.data.transform(Matrix.Translation(-pivot))  # origin at the trunk top
                canon[name] = {"obj": obj, "pivot": pivot, "material": material, "verts": [v.co.copy() for v in obj.data.vertices]}
            # Proof: the shared crown, placed on this tree, sits on this tree's own leaves.
            entry = canon[name]
            m = placement_matrix(p) @ Matrix.Translation(entry["pivot"])
            kd = KDTree(len(ids))
            for k, i in enumerate(ids):
                kd.insert(pts[i], k)
            kd.balance()
            err = max(kd.find(m @ v)[2] for v in entry["verts"])
            assert len(entry["verts"]) == len(ids) and err < MAX_FIT, (p["object"], name, err, len(entry["verts"]), len(ids))
            pivot_world = m.translation
            instances.append({"tree": p["object"], "mesh": name, "material": material, "pivot": rb(pivot_world),
                              "yaw": round(p["yaw_rad"], 6), "scale": round(p["scale"], 6), "fit": round(err, 6)})
    # The Hatch Tree: its own crown, swaying about the middle of its lowest leaves.
    hatch = objects["Vegetation_HatchTree__foliage"]
    pts = world_verts(hatch)
    lo = Vector([min(v[i] for v in pts) for i in range(3)])
    hi = Vector([max(v[i] for v in pts) for i in range(3)])
    pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z + .6))
    obj = sub_object(hatch, range(len(pts)), "Crown_Hatch__foliage")
    obj.data.transform(Matrix.Translation(-pivot))
    canon["Crown_Hatch"] = {"obj": obj, "pivot": pivot, "material": "foliage"}
    instances.append({"tree": "Landmark_HatchTree", "mesh": "Crown_Hatch", "material": "foliage", "pivot": rb(pivot),
                      "yaw": 0.0, "scale": 1.0, "fit": 0.0})
    # The Blossom Point tree lives in the Hatch chunk's blossom part: a Blossom crown at scale 1.7, proven the same way.
    point = next(p for p in json.loads((ROOT / "artifacts/world1-mockup/v7/vegetation-placements.json").read_text())["instances"]
                 if p["object"] == "Landmark_BlossomPointTree")
    chunk = objects["Vegetation_HatchTree__foliage_blossom"]
    pts = world_verts(chunk)
    entry = canon["Crown_Blossom"]
    m = placement_matrix(point) @ Matrix.Translation(entry["pivot"])
    kd = KDTree(len(pts))
    for k, v in enumerate(pts):
        kd.insert(v, k)
    kd.balance()
    err = max(kd.find(m @ v)[2] for v in entry["verts"])
    assert len(pts) == len(entry["verts"]) and err < MAX_FIT, ("Landmark_BlossomPointTree", err)
    instances.append({"tree": point["object"], "mesh": "Crown_Blossom", "material": "foliage_blossom", "pivot": rb(m.translation),
                      "yaw": round(point["yaw_rad"], 6), "scale": round(point["scale"], 6), "fit": round(err, 6)})
    reshape(canon)
    return canon, instances


def rest(sources):
    objects = {o.name: o for o in sources}
    out = []
    for chunk, name in (("Vegetation_Bushes__foliage", "Rest__foliage"), ("Vegetation_Bushes__foliage_blossom", "Rest__foliage_blossom")):
        src = objects[chunk]
        out.append(sub_object(src, range(len(src.data.vertices)), name))
    return out


# ------------------------------------------------------------------------------------------------------------- falls
WALK = json.loads((ROOT / "assets/world/world-v7-walk.json").read_text())
SHEETS = {f["name"]: f for f in WALK["falls"]}
# The falls' white water bows out BOW studs at mid-height on exactly the cubic curve a Roblox Beam draws between the
# drop's top and bottom attachments (axis n) with CurveSize0 = CURVE and CurveSize1 = -CURVE, CURVE = BOW / .75, so
# AeroFalls' flow beams bend with the chutes. Top (the lip) and foot stay on today's plane. Rocks: Fable review r1 (wet,
# darker than the marble ring, not an even row).
# LOOK-R2 round 4: bow .5 (1.5 pushed the water a full chute off the flow beams from the pool edge).
FALLS = {"Water_TumbleFalls_Upper": {"bow": .5}, "Water_TumbleFalls_Lower": {"bow": .5}}
ROCK_TOP, ROCK_BOTTOM = (0x74, 0x85, 0x8C), (0x3F, 0x4E, 0x55)


def lin(c):
    def f(x):
        x /= 255
        return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4
    return tuple(f(x) for x in c)


def mix(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))


def frame(name):
    s = SHEETS[name]
    n = Vector(s["normal"]).normalized()
    t = Vector((n.z, 0, -n.x)).normalized()
    return Vector(s["top"]), Vector(s["bottom"]), s["width0"], s["width1"], n, t


def curve(name):
    return FALLS[name]["bow"] / .75


class Builder:
    def __init__(self, name, default_uv=(0.0, 0.0)):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.name = name
        self.default_uv = default_uv
        self.normals = {}  # face -> shading normal (Roblox axes), for faces that ask for one

    def quad(self, pts, colors, uvs=None, smooth=False, normal=None):
        vs = [self.bm.verts.new(bl(*p)) for p in pts]
        face = self.bm.faces.new(vs)
        face.smooth = smooth
        if normal is not None:
            self.normals[face] = (bl(*normal) - bl(0, 0, 0)).normalized()
        for i, (loop, c) in enumerate(zip(face.loops, colors)):
            loop[self.col] = (*c, 1.0)
            loop[self.uv].uv = uvs[i] if uvs else self.default_uv

    def tri(self, pts, colors, uvs=None, smooth=False, normal=None):
        self.quad(pts, colors, uvs, smooth, normal)

    def build(self, facing=None):
        """Weld shared corners first: each quad is added with its own vertices, and loose faces get arbitrary normals
        (flat-shaded, half of them lit from behind). Closed shapes then face out; an open sheet faces `facing`
        (a Roblox direction)."""
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        if facing is not None:
            want = bl(*facing) - bl(0, 0, 0)
            for face in self.bm.faces:
                face.normal_update()
                if face.normal.dot(want) < 0:
                    face.normal_flip()
        custom = None
        if self.normals:
            # LOOK-R4 W1: faces that carry their own shading normal (the falls sheet leans its shading toward the sky so
            # it lights like water, not like a wall in shade); every other loop keeps its smooth or flat normal.
            self.bm.normal_update()
            custom = []
            for face in self.bm.faces:
                for loop in face.loops:
                    n = self.normals.get(face)
                    custom.append(tuple(n) if n is not None else tuple(loop.vert.normal if face.smooth else face.normal))
        self.bm.to_mesh(me)
        self.bm.free()
        if custom is not None:
            me.normals_split_custom_set(custom)
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# LOOK-R4: wet stone, darker than the boulders, no blue. Round 2: they rendered (35, 60, 75) (shade turns them blue), so
# their shading leans toward the sky (ROCK_SKY) and the vertex colours are warmed to land in R 60-80, G 72-88, B 76-92.
ROCK_TOP_FACE, ROCK_FOOT_FACE = (116, 94, 83), (100, 80, 71)  # r16 rendered (57-66, 84-91, 90-102): warmed toward the middle
ROCK_SKY = .6
# Per drop: three ledges (fraction of the drop's height, how far proud).
LEDGES = {"Water_TumbleFalls_Upper": ((.24, .7), (.52, 1.0), (.78, .6)),
          "Water_TumbleFalls_Lower": ((.27, .9), (.55, .6), (.8, 1.0))}
KINK = .3  # LOOK-R2 round 4 (round 3's .8 sawtoothed the edges and banded the sheet)


def add_rock_face(b, name, rows=16, cols=7):
    """LOOK-R2 2: the wet rock the water falls over: today's sheet plane widened by 2, a little behind it, with three
    ledges standing proud across it. Slate from #55666B at the top to #44545A at the foot (round 3)."""
    top, bottom, w0, w1, n, t = frame(name)
    rnd = random.Random(sum(map(ord, name)))
    jitter = [[rnd.uniform(-.12, .12) for _ in range(cols + 1)] for _ in range(rows + 1)]
    grid = []
    for r in range(rows + 1):
        h = r / rows
        row = []
        for c in range(cols + 1):
            v = -1 + 2 * c / cols
            half = (w0 + (w1 - w0) * h) / 2 - .5   # Fable R5: behind the sheet (the two dark frame slabs go)
            proud = sum(p * math.exp(-((h - at) / .045) ** 2) for at, p in LEDGES[name])
            out = -.35 + proud * (1 - .25 * abs(v)) + jitter[r][c]
            row.append(top + (bottom - top) * h + t * (half * v) + n * out)
        grid.append(row)
    sky = (n + Vector((0, ROCK_SKY, 0))).normalized()
    for r in range(rows):
        cs = [lin(mix(ROCK_TOP_FACE, ROCK_FOOT_FACE, rr / rows)) for rr in (r, r, r + 1, r + 1)]
        for c in range(cols):
            b.quad([grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]], cs, normal=sky)


# LOOK-R4 W1 (Fable): the static falls carry the read with no motion. One sheet per drop (the slits are closed), its
# faces UV-mapped to the streak region of the falls atlas (scripts/draw_aero_r4_textures.py: 16 studs across, 24 down,
# periodic down so a taller drop restarts at a cut row); everything else samples the atlas's white block and keeps its
# vertex colour. Hue lives in the map: the sheet's vertices go near-white.
ATLAS_U_STUDS, ATLAS_V_STUDS, ATLAS_STREAK_V = 16.0, 24.0, 384 / 512
WHITE_UV = (0.5, 1 - 456 / 512)
SHEET_TOP, SHEET_LOW = (226, 238, 246), (255, 255, 255)
FOAM, FOAM_LOW, LIP = (250, 252, 253), (226, 241, 246), (250, 253, 254)
APRON_IN, APRON_OUT = (226, 241, 246), (190, 222, 232)
SHEET_COLS = 4   # Fable R5: the edge fade is in the atlas now (u spans each sheet), so fewer columns
LOBE = .45       # Fable R5: each side edge breaks into 3-5 uneven lobes, up to 2 x LOBE studs in
SHEET_SKY = 1.0   # the sheet's shading normal: n + SHEET_SKY * up, normalised (Studio r13: facing out it rendered ~50 darker)


def falls_h(u):
    return 3 * u * u - 2 * u * u * u


def add_sheet(b, name, lip_b, rows=22, lip=True):
    """One sheet per drop on the beam curve (bow .5, ledge kink .3), UV-mapped to the atlas streaks: u runs 0..1 across
    the sheet between its lobed edges (the atlas draws the far-read bands and the edge fade), v down the drop. The top
    lip line (only where `lip`) goes in `lip_b` (the foam part)."""
    top, bottom, w0, w1, n, t = frame(name)
    c = curve(name)
    length = (bottom - top).length
    rnd = random.Random(name + "-lobes")
    waves = [(rnd.uniform(1.6, 2.4), rnd.uniform(0, 2 * math.pi), rnd.uniform(3.2, 4.4), rnd.uniform(0, 2 * math.pi))
             for _ in range(2)]

    def inset(side, h):
        k1, p1, k2, p2 = waves[side]
        wave = .6 * math.sin(2 * math.pi * k1 * h + p1) + .4 * math.sin(2 * math.pi * k2 * h + p2)
        return LOBE + LOBE * max(-1.0, min(1.0, wave))

    def point(u, x):
        h = falls_h(u)
        kink = sum(KINK * math.exp(-((h - at) / .07) ** 2) for at, _ in LEDGES[name])
        return top + (bottom - top) * h + t * x + n * (3 * c * u * (1 - u) + .05 + kink)

    # Row boundaries in u, plus one exactly where the streak map restarts (every ATLAS_V_STUDS down the drop).
    us = [r / rows for r in range(rows + 1)]
    k = 1
    while k * ATLAS_V_STUDS < length:
        target = k * ATLAS_V_STUDS / length
        lo, hi = 0.0, 1.0
        for _ in range(60):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if falls_h(mid) < target else (lo, mid)
        us.append((lo + hi) / 2)
        k += 1
    us = sorted(set(round(u, 9) for u in us))

    def colour(u):
        return lin(mix(SHEET_TOP, SHEET_LOW, min(1.0, falls_h(u) / .4)))
    sky = (n + Vector((0, SHEET_SKY, 0))).normalized()
    for r in range(len(us) - 1):
        u0, u1 = us[r], us[r + 1]
        s0, s1 = falls_h(u0) * length, falls_h(u1) * length
        seg = math.floor(s0 / ATLAS_V_STUDS + 1e-6)
        v0 = 1 - (s0 - seg * ATLAS_V_STUDS) / ATLAS_V_STUDS * ATLAS_STREAK_V
        v1 = 1 - (s1 - seg * ATLAS_V_STUDS) / ATLAS_V_STUDS * ATLAS_STREAK_V
        assert v1 >= 1 - ATLAS_STREAK_V - 1e-6, (name, "a row crosses the streak restart", s0, s1)
        h0, h1 = falls_h(u0), falls_h(u1)
        sw0, sw1 = w0 + (w1 - w0) * h0, w0 + (w1 - w0) * h1
        l0, r0 = -sw0 / 2 + inset(0, h0), sw0 / 2 - inset(1, h0)
        l1, r1 = -sw1 / 2 + inset(0, h1), sw1 / 2 - inset(1, h1)
        for col in range(SHEET_COLS):
            a, bb = col / SHEET_COLS, (col + 1) / SHEET_COLS
            xa0, xb0 = l0 + (r0 - l0) * a, l0 + (r0 - l0) * bb
            xa1, xb1 = l1 + (r1 - l1) * a, l1 + (r1 - l1) * bb
            uvs = [(a, v0), (bb, v0), (bb, v1), (a, v1)]
            b.quad([point(u0, xa0), point(u0, xb0), point(u1, xb1), point(u1, xa1)],
                   [colour(u0), colour(u0), colour(u1), colour(u1)], uvs=uvs, smooth=True, normal=sky)
    if not lip:
        return
    # The lip line: a 0.5-stud white strip along the top edge, just in front of the sheet, lit like the sheet.
    lo, hi = 0.0, 1.0
    for _ in range(60):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if falls_h(mid) * length < .5 else (lo, mid)
    du = (lo + hi) / 2
    l0, r0 = -w0 / 2 + inset(0, 0.0), w0 / 2 - inset(1, 0.0)
    for col in range(SHEET_COLS):
        a, bb = col / SHEET_COLS, (col + 1) / SHEET_COLS
        xa, xb = l0 + (r0 - l0) * a, l0 + (r0 - l0) * bb
        lift = n * .06
        lip_b.quad([point(0, xa) + lift, point(0, xb) + lift, point(du, xb) + lift, point(du, xa) + lift], [lin(LIP)] * 4,
                   smooth=True, normal=sky)


FOAM_SKY = 1.4   # foam faces: outward + FOAM_SKY * up (round 2: facing out they rendered grey, darker than the water)


def add_lobe(b, centre, n, t, width, height, proud, low, high):
    """A foam roll lobe: a half-dome on the water against the sheet, 4 around by 3 up (20 triangles). The bottom row
    takes `low`, the rest `high`."""
    up = Vector((0, 1, 0))  # Roblox axes, as frame() and Builder.quad

    def lit(pts):
        mid = sum(pts, Vector((0, 0, 0))) / len(pts)
        return ((mid - centre).normalized() + up * FOAM_SKY).normalized()
    A, E = 4, 3
    ring = []
    for e in range(E + 1):
        th = math.pi / 2 * e / E
        row = []
        for a in range(A + 1):
            ph = math.pi * a / A
            row.append(centre + t * (width / 2 * math.cos(ph) * math.cos(th)) + n * (proud * math.sin(ph) * math.cos(th))
                       + up * (height * math.sin(th)))
        ring.append(row)
    for e in range(E):
        c0 = lin(mix(low, high, min(1.0, e / 1.0)))
        c1 = lin(mix(low, high, min(1.0, (e + 1) / 1.0)))
        for a in range(A):
            if e == E - 1:
                pts = [ring[e][a + 1], ring[e][a], ring[e + 1][0]]
                b.tri(pts, [c0, c0, c1], smooth=True, normal=lit(pts))
            else:
                pts = [ring[e][a + 1], ring[e][a], ring[e + 1][a], ring[e + 1][a + 1]]
                b.quad(pts, [c0, c0, c1, c1], smooth=True, normal=lit(pts))


def add_step_lip(b):
    """Fable R5: no white line across the step: a dark rock lip there instead (wet stone, lit like the rock face)."""
    top, bottom, w0, w1, n, t = frame("Water_TumbleFalls_Upper")
    up = Vector((0, 1, 0))
    half, tall, deep = w1 / 2 + .4, .5, .55
    base = bottom + n * .05 - up * .1
    corners = {}
    for sx in (-1, 1):
        for sy in (0, 1):
            for sz in (0, 1):
                corners[(sx, sy, sz)] = base + t * (sx * half) + up * (sy * tall) + n * (sz * deep)
    c_top, c_foot = lin(ROCK_TOP_FACE), lin(ROCK_FOOT_FACE)
    sky = (n + Vector((0, ROCK_SKY, 0))).normalized()
    faces = [((-1, 0, 1), (1, 0, 1), (1, 1, 1), (-1, 1, 1), sky),                      # front
             ((-1, 1, 1), (1, 1, 1), (1, 1, 0), (-1, 1, 0), (n * .3 + up).normalized()),  # top
             ((-1, 0, 0), (-1, 0, 1), (-1, 1, 1), (-1, 1, 0), (-t + up * .5).normalized()),
             ((1, 0, 1), (1, 0, 0), (1, 1, 0), (1, 1, 1), (t + up * .5).normalized())]
    for *keys, normal in faces:
        b.quad([corners[k] for k in keys], [c_foot if k[1] == 0 else c_top for k in keys], normal=normal)


def add_foam(b):
    """Ledge roll (5 lobes, 1.6 tall, .6 proud), the foot roll (7 lobes 1.0-1.8 wide, 1.4-2.6 tall, .8 proud, the sheet
    plus .6 each side) and a scalloped apron fanning 3.5 studs out on the pool, .08 above the water."""
    rnd = random.Random(4421)
    # Fable R5: only the foot keeps a roll, low and uneven (at most .8 tall); the step's roll and line are gone.
    for name, lobes, tall, proud, extra in (("Water_TumbleFalls_Lower", 7, (.45, .8), .6, .6),):
        top, bottom, w0, w1, n, t = frame(name)
        foot = bottom + n * .05
        span = w1 + 2 * extra
        widths = [rnd.uniform(1.0, 1.8) for _ in range(lobes)]
        scale = span / sum(widths) * 1.15                      # lobes overlap a little: no gaps in the roll
        x = -span / 2
        for wd in widths:
            wd *= scale
            centre = foot + t * (x + wd / 2 / 1.15)
            add_lobe(b, centre, n, t, wd, rnd.uniform(*tall), proud, FOAM_LOW, FOAM)
            x += wd / 1.15
    # The apron: a scalloped half-fan in front of the lower foot.
    top, bottom, w0, w1, n, t = frame("Water_TumbleFalls_Lower")
    water = bottom.y + .08
    centre = Vector((bottom.x, water, bottom.z)) + n * .4
    segs = 12
    rim = []
    for i in range(segs + 1):
        ph = math.pi * i / segs
        r = 3.5 + (.5 if i % 2 else -.3) + rnd.uniform(-.15, .15)
        rx = (w1 / 2 + .6) * math.cos(ph)
        rim.append(centre + t * rx + n * (r * math.sin(ph)))
    for i in range(segs):
        b.tri([centre, rim[i + 1], rim[i]], [lin(APRON_IN), lin(APRON_OUT), lin(APRON_OUT)], smooth=True, normal=(0, 1, 0))


def rock_shape(seed, size):
    """A wet boulder: an 8 x 5 ring sphere, squashed to size, roughened, its foot flattened. About 64 triangles."""
    rnd = random.Random(seed)
    segs, rings = 8, 5
    pts = []
    for r in range(1, rings):
        a = math.pi * r / rings
        row = []
        for s in range(segs):
            b = 2 * math.pi * (s + rnd.uniform(-.15, .15)) / segs
            k = 1 + rnd.uniform(-.14, .14)
            p = Vector((math.sin(a) * math.cos(b) * k, math.cos(a) * k, math.sin(a) * math.sin(b) * k))
            p.y = max(p.y, -.35)
            row.append(Vector((p.x * size[0] / 2, p.y * size[1] / 2, p.z * size[2] / 2)))
        pts.append(row)
    top = Vector((rnd.uniform(-.1, .1) * size[0], size[1] / 2 * (1 + rnd.uniform(-.08, .05)), rnd.uniform(-.1, .1) * size[2]))
    foot = Vector((0, -.35 * size[1] / 2, 0))
    return top, pts, foot


def add_rock(b, rock, seed):
    top, rows, foot = rock_shape(seed, rock["size"])
    yaw = rock["yaw"]
    rot = Matrix.Rotation(yaw, 3, "Y")  # Roblox yaw about +Y, in Roblox axes (x, y, z)
    centre = Vector(rock["center"])

    def at(p):
        return centre + rot @ p
    h = rock["size"][1] / 2

    def col(p):
        return lin(mix(ROCK_BOTTOM, ROCK_TOP, max(0, min(1, (p.y / h + .35) / 1.35))))
    segs = len(rows[0])
    for s in range(segs):
        ss = (s + 1) % segs
        b.tri([at(top), at(rows[0][s]), at(rows[0][ss])], [col(top), col(rows[0][s]), col(rows[0][ss])])
        for r in range(len(rows) - 1):
            a, c = rows[r], rows[r + 1]
            b.quad([at(a[s]), at(c[s]), at(c[ss]), at(a[ss])], [col(a[s]), col(c[s]), col(c[ss]), col(a[ss])])
        b.tri([at(foot), at(rows[-1][ss]), at(rows[-1][s])], [col(foot)] * 3)


def rocks():
    """Section 4 layer 10, placed from the falls' own frames. size: along t, up, along n (studs)."""
    out = []

    def place(kind, name, s, o, at, size, yaw):
        top, bottom, _, _, n, t = frame(name)
        base = bottom if at == "bottom" else top
        # Seated: about a third of the rock under the water (or ledge) top.
        c = base + t * s + n * o + Vector((0, size[1] * .15, 0))
        rock = {"kind": kind, "center": [round(x, 3) for x in c], "size": list(size),
                "yaw": round(math.atan2(t.x, t.z) + yaw, 4), "radius": round(min(size[0], size[2]) * .42, 3)}
        if at == "bottom" and name == lower:
            settle(rock)  # a pool rock that would cover a pet cell steps into the pool
        out.append(rock)
    lower, upper = "Water_TumbleFalls_Lower", "Water_TumbleFalls_Upper"
    # Three at the foot of the lower fall, where the water breaks white.
    # Fable review r1: one big, one small, one between, not an even row.
    place("split", lower, -4.2, 1.4, "bottom", (3.0, 2.2, 2.4), .4)
    place("split", lower, -.8, 2.7, "bottom", (1.3, .9, 1.2), 1.3)
    place("split", lower, 3.3, 1.9, "bottom", (2.1, 1.5, 1.8), 2.2)
    # Two flanking the upper fall's foot on the ledge (out of reach: the ledge is walled).
    place("flank", upper, -6.2, .3, "bottom", (3.0, 2.6, 2.6), .9)
    place("flank", upper, 6.4, .2, "bottom", (2.8, 2.4, 2.4), 2.8)
    # Two in the pool.
    place("pool", lower, -2.2, 7.5, "bottom", (1.5, 1.1, 1.4), .2)
    place("pool", lower, 3.0, 9.5, "bottom", (1.2, .9, 1.1), 1.9)
    # Three breaking the pool's marble ring from the water side (west and north bends): each starts on the ring and
    # steps toward the pool's middle until no pet cell is under it, so it overhangs the ring by its own edge.
    for x, z, size, yaw in ((54.2, -61.5, (2.6, 1.7, 2.2), .7), (54.0, -69.5, (2.2, 1.5, 2.0), 2.1), (59.0, -74.6, (2.4, 1.6, 2.1), 1.2)):
        rock = {"kind": "rim", "center": [x, round(3.2 + size[1] * .15, 3), z], "size": list(size), "yaw": yaw,
                "radius": round(min(size[0], size[2]) * .42, 3)}
        settle(rock)
        out.append(rock)
    return out


def settle(rock):
    """Step a pool rock toward the pool's middle, a quarter stud at a time, until no pet cell is under it."""
    middle = WALK_POOL
    for _ in range(40):
        if not pet_cells(rock):
            return
        dx, dz = middle[0] - rock["center"][0], middle[1] - rock["center"][2]
        d = math.hypot(dx, dz)
        rock["center"][0] = round(rock["center"][0] + dx / d * .25, 3)
        rock["center"][2] = round(rock["center"][2] + dz / d * .25, 3)


WALK_POOL = next((w["center"][0], w["center"][2]) for w in WALK["wet"] if w["name"] == "Water_Pool_Falls")


def pet_cells(rock):
    """Surface cells under a rock's footprint that pets can stand on (not water, rock or nothing, at or under the ledge)."""
    s = WALK["surface"]
    cx, _, cz = rock["center"]
    r = rock["radius"]
    out = []
    for z in range(math.floor(cz - r), math.ceil(cz + r) + 1):
        for x in range(math.floor(cx - r), math.ceil(cx + r) + 1):
            if (x + .5 - cx) ** 2 + (z + .5 - cz) ** 2 > r * r:
                continue
            code = s["rows"][z - s["z0"]][x - s["x0"]]
            height = s["h"][z - s["z0"]][x - s["x0"]]
            if code not in PET_OK and height <= LEDGE_Y:
                out.append((x, z, code, height))
    return out


def check_rocks(list_):
    """Pets walk the surface map: a rock may cover water, rock, nothing, or ground above the walled ledge."""
    bad = [(rock["kind"], rock["center"], cell) for rock in list_ for cell in pet_cells(rock)]
    assert not bad, ("rock over pet ground", bad[:8])


def falls():
    """LOOK-R2 2: rock face, chutes and the wet rocks: one vertex-coloured mesh (the lip bars and the striped sheet are gone)."""
    b = Builder("Falls__kitwater", default_uv=WHITE_UV)
    # LOOK-R4 round 2: the foam (rolls, lips, apron) is its own part: the cliff shades the foot, so lit only by the blue
    # sky it rendered grey-blue; its own SurfaceAppearance takes a small white emissive lift (AeroKit, WorldAero.FallsFoam).
    fb = Builder("Falls__kitfoam", default_uv=WHITE_UV)
    for name in FALLS:
        add_rock_face(b, name)
        add_sheet(b, name, fb, lip=name == "Water_TumbleFalls_Upper")
    add_step_lip(b)
    add_foam(fb)
    list_ = rocks()
    check_rocks(list_)
    for i, rock in enumerate(list_):
        add_rock(b, rock, 40 + i)
    frames = {name: {"bow": spec["bow"], "curve": round(curve(name), 6)} for name, spec in FALLS.items()}
    return [b.build(), fb.build()], list_, frames


# LOOK-R2 3 and round 3: a two-tier garden fountain in the Bubble Spring's basin, 5.2 tall, its bowl 3.2 up and 3.2
# across, 16 sides, one marble tint (#B9BEC2, base #9AA3A6). The old basin is an octagon inside a shared marble mesh, so a
# round 16-sided rim and its own water (#3BA3BE) sit over it (the old water, W7_Landmarks__water, is hidden). Measured old
# basin: outer +-4.3 by +-2.67, inner about +-3.4 by +-2.1, rim top 5.2 to 5.3, a mound in the middle up to about 1.2 out.
FOUNTAIN = {"x": 52.0, "z": 3.0, "base": 3.95, "water": 4.7, "segs": 16,
            # (height above the base, radius), from the foot up a pedestal that covers the old basin's mound (up to
            # about 1.35 above the base, 1.2 out), the stem, out over the bowl, back in and up the finial
            "profile": ((0, 1.5), (1.4, 1.45), (1.5, 1.2), (1.65, .6), (2.9, .48), (3.1, .62), (3.25, 1.2), (3.65, 1.6),
                        (3.75, 1.62), (3.8, 1.5), (3.6, 1.15), (3.85, .22), (4.45, .32), (4.7, .18), (5.2, 0)),
            "bowlWater": 3.7, "bowlWaterRadius": 1.4,
            # A low rim (Fable: pets step in): top .4 over the water, raised to read full.
            "rim": {"outer": (4.45, 2.82), "inner": (3.45, 2.05), "top": 4.95, "foot": 4.2}}  # LOOK-R2 r4: low wall
STONE_TOP, STONE_BASE, MOSS, POOL_WATER = (0xB9, 0xBE, 0xC2), (0x9A, 0xA3, 0xA6), (0x6E, 0x8B, 0x5A), (0x3B, 0xA3, 0xBE)


def fountain():
    """Stem, bowl and finial as one lathe, the bowl's water, a round rim over the old octagon and the basin's water.
    Vertex tint: one marble, a touch darker at the foot, a moss band at the waterline. UV: around (U) by height (V)."""
    f = FOUNTAIN
    b = Builder("Fountain__kitstone")
    centre = Vector((f["x"], f["base"], f["z"]))
    segs = f["segs"]

    def ring(hgt, r, k, squash=(1.0, 1.0)):
        a = math.tau * k / segs
        return centre + Vector((math.cos(a) * r * squash[0], hgt, math.sin(a) * r * squash[1]))

    def tint(hgt):
        y = f["base"] + hgt
        if f["water"] - .05 <= y <= f["water"] + .3:
            return lin(MOSS)
        return lin(mix(STONE_BASE, STONE_TOP, min(1.0, hgt / 2.0)))
    prof = f["profile"]
    for i in range(len(prof) - 1):
        (h0, r0), (h1, r1) = prof[i], prof[i + 1]
        for k in range(segs):
            kk = k + 1
            pts = [ring(h0, r0, k), ring(h0, r0, kk), ring(h1, r1, kk), ring(h1, r1, k)]
            uvs = [(k / segs * 3, h0 / 2), (kk / segs * 3, h0 / 2), (kk / segs * 3, h1 / 2), (k / segs * 3, h1 / 2)]
            b.quad(pts, [tint(h0), tint(h0), tint(h1), tint(h1)], uvs, smooth=True)
    water = lin(POOL_WATER)

    def disc(height, rx, rz):
        mid = centre + Vector((0, height, 0))
        for k in range(segs):
            b.tri([mid, ring(height, 1, k + 1, (rx, rz)), ring(height, 1, k, (rx, rz))], [water] * 3)
    disc(f["bowlWater"], f["bowlWaterRadius"], f["bowlWaterRadius"])
    # The round rim: outer wall, top, inner wall down to the water, then the basin's water.
    rim = f["rim"]
    top, foot, wet = rim["top"] - f["base"], rim["foot"] - f["base"], f["water"] - f["base"]
    for k in range(segs):
        kk = k + 1
        o0, o1 = ring(top, 1, k, rim["outer"]), ring(top, 1, kk, rim["outer"])
        i0, i1 = ring(top, 1, k, rim["inner"]), ring(top, 1, kk, rim["inner"])
        stone = lin(STONE_TOP)
        b.quad([ring(foot, 1, k, rim["outer"]), ring(foot, 1, kk, rim["outer"]), o1, o0], [lin(STONE_BASE)] * 2 + [stone] * 2,
               [(k / 4, 0), (kk / 4, 0), (kk / 4, .7), (k / 4, .7)])
        b.quad([o0, o1, i1, i0], [stone] * 4, [(k / 4, 0), (kk / 4, 0), (kk / 4, .6), (k / 4, .6)])
        b.quad([i0, i1, ring(wet, 1, kk, rim["inner"]), ring(wet, 1, k, rim["inner"])], [stone, stone, lin(MOSS), lin(MOSS)],
               [(k / 4, 0), (kk / 4, 0), (kk / 4, .5), (k / 4, .5)])
    disc(wet + .01, rim["inner"][0], rim["inner"][1])
    return b.build()


# ------------------------------------------------------------------------------------------------------------ export
def centred(obj):
    """Origin at the bounds centre (as the island meshes); returns Roblox centre and size."""
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    c = (lo + hi) / 2
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    obj.data.transform(Matrix.Translation(-c))
    obj.location = c
    size = hi - lo
    return c, [round(size.x, 4), round(size.z, 4), round(size.y, 4)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = prepared_sources()
    merged = check_merged(sources)
    canon, instances = crowns(sources)
    rest_objs = rest(sources)
    falls_objs, rock_list, frames = falls()
    falls_objs.append(fountain())
    meshes, export = [], []
    for name, entry in canon.items():
        obj = entry["obj"]
        obj.name = obj.data.name = "W7_Kit_" + name + "__" + entry["material"]
        # The shared crown's local origin is its pivot; record where the bounds centre sits from it (Roblox axes).
        c, size = centred(obj)
        meshes.append({"name": obj.name, "role": "crown", "kind": entry["material"], "tris": C.tris(obj), "size": size,
                       "pivotToCentre": [round(c.x, 4), round(c.z, 4), round(-c.y, 4)],
                       "hash": geom_digest(obj.data), **({"reshape": entry["reshape"]} if "reshape" in entry else {})})
        export.append(obj)
    for obj in rest_objs + falls_objs:
        obj.name = obj.data.name = "W7_Kit_" + obj.name
        c, size = centred(obj)
        role = ("falls" if obj.name.startswith("W7_Kit_Falls") else "fountain" if obj.name.startswith("W7_Kit_Fountain")
                else "rest")
        meshes.append({"name": obj.name, "role": role, "kind": obj.name.rsplit("__", 1)[1], "tris": C.tris(obj),
                       "size": size, "center": rb(c), "hash": geom_digest(obj.data)})
        export.append(obj)
    for inst in instances:
        inst["mesh"] = next(m["name"] for m in meshes if m["name"].startswith("W7_Kit_" + inst["mesh"] + "__"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "aero-kit.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                             colors_type="SRGB")
    hidden = {"W7_Vegetation__foliage": merged["Vegetation__foliage"],
              "W7_Vegetation__foliage_blossom": merged["Vegetation__foliage_blossom"],
              "W7_Water__waterfall_tumble": merged["Water__waterfall_tumble"],
              # LOOK-R2 3: the fountain replaces the spring's glass bubbles (the basin and its water stay).
              "W7_Bubbles__bubble": ["Anim__Landmark_BubbleSpring_Bubble_0..5__bubble"],
              # LOOK-R2 round 3: the old basin water under the kit's own, and the faceted foam at the falls' feet.
              "W7_Landmarks__water": ["Landmark_BubbleSpring water"],
              "W7_Water__foam": ["Anim__Water_TumbleFalls_Foam_Bottom/Ledge, Anim__Water_SkyFalls_Foam"]}
    manifest = {
        "note": "Generated by scripts/build_world_aero_kit.py. Roblox studs. Crown pivotToCentre is the mesh bounds "
                "centre from its pivot in the tree's own frame at scale 1 (Roblox axes, before the tree's yaw).",
        "meshes": meshes, "crowns": instances, "rocks": rock_list, "falls": frames, "hides": hidden,
        "fountain": {"centre": [FOUNTAIN["x"], FOUNTAIN["base"], FOUNTAIN["z"]], "top": FOUNTAIN["base"] + 5.2,
                     "bowl": {"y": FOUNTAIN["base"] + 3.75, "radius": 1.6}, "water": FOUNTAIN["water"],
                     "basin": [6.82, 4.2284]},
        "triangles": sum(m["tris"] for m in meshes)}
    (OUT / "aero-kit-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("KIT", len(meshes), "meshes", manifest["triangles"], "tris,", len(instances), "crowns,", len(rock_list), "rocks")
    for m in meshes:
        print("KIT mesh", m["name"], m["tris"], m["size"])


# ------------------------------------------------------------------------------------------------------------ trunks
TRUNK_OUT = ROOT / "assets" / "world" / "aero-trunks"
# Template names unique to this slice (a pack's names must never repeat another pack's: world-finish-template-names).
TRUNK_PREFIX = "W7_Trees38_"
TRUNK_KIND = {"Tree_Round": "Trunk_Round", "Tree_Tall": "Trunk_Tall", "Tree_Blossom": "Trunk_Blossom"}


def check_trunks(sources):
    """The trunks are cut from exactly the bark the island ships (W7_Trunks__bark's geometry hash)."""
    manifest = {p["name"]: p for p in json.loads((ROOT / "assets/world/world-v7-manifest.json").read_text())["parts"]}
    objs = [o for o in sources if C.classify(o.name)[0] == "Trunks__bark"]
    joined = C.join([C.duplicate(o, "chk_" + o.name) for o in objs], "chk_Trunks__bark")
    C.recentre(joined)
    got, want = C.geom_hash(joined), manifest["W7_Trunks__bark"]["hash"]
    assert got == want, ("merged trunk geometry drifted", got, want)
    bpy.data.objects.remove(joined, do_unlink=True)
    names = sorted(o.name for o in objs)
    print("TRUNKS merged hash matches:", names)
    return {o.name: o for o in objs}


def trunks(sources):
    chunks = check_trunks(sources)
    trees_chunk = next(o for name, o in chunks.items() if name.startswith("Vegetation_Trees"))
    landmark_chunk = next(o for name, o in chunks.items() if name.startswith("Vegetation_HatchTree"))
    assert len(chunks) == 2, sorted(chunks)
    group = [p for p in placements() if not p["object"].startswith("Landmark_")]
    owner, pts = assign(trees_chunk, group)
    assert len(owner) == len(group), ("a tree without bark", sorted(set(p["object"] for p in group) - set(owner)))
    assert sum(len(v) for v in owner.values()) == len(trees_chunk.data.vertices)
    canon, instances = {}, []
    for p in sorted(group, key=lambda q: q["object"]):
        name = TRUNK_KIND[p["mesh"]]
        ids = owner[p["object"]]
        if name not in canon:
            obj = sub_object(trees_chunk, ids, name + "__bark")
            obj.data.transform(placement_matrix(p).inverted())  # tree-local at scale 1: the origin is the root
            canon[name] = {"obj": obj, "verts": [v.co.copy() for v in obj.data.vertices]}
        entry = canon[name]
        m = placement_matrix(p)
        kd = KDTree(len(ids))
        for k, i in enumerate(ids):
            kd.insert(pts[i], k)
        kd.balance()
        err = max(kd.find(m @ v)[2] for v in entry["verts"])
        assert len(entry["verts"]) == len(ids) and err < MAX_FIT, (p["object"], name, err, len(entry["verts"]), len(ids))
        instances.append({"tree": p["object"], "mesh": name, "root": rb(m.translation), "yaw": round(p["yaw_rad"], 6),
                          "scale": round(p["scale"], 6), "fit": round(err, 6)})
    landmarks = sub_object(landmark_chunk, range(len(landmark_chunk.data.vertices)), "Trunks_Landmarks__bark")
    return canon, instances, landmarks


def main_trunks():
    TRUNK_OUT.mkdir(parents=True, exist_ok=True)
    sources = prepared_sources()
    canon, instances, landmarks = trunks(sources)
    meshes, export = [], []
    for name, entry in canon.items():
        obj = entry["obj"]
        obj.name = obj.data.name = TRUNK_PREFIX + name + "__bark"
        # The shared trunk's local origin is its root; where its bounds centre sits from it (Roblox axes, scale 1).
        c, size = centred(obj)
        meshes.append({"name": obj.name, "role": "trunk", "kind": "bark", "tris": C.tris(obj), "size": size,
                       "rootToCentre": [round(c.x, 4), round(c.z, 4), round(-c.y, 4)], "hash": geom_digest(obj.data)})
        export.append(obj)
    landmarks.name = landmarks.data.name = TRUNK_PREFIX + "Trunks_Landmarks__bark"
    c, size = centred(landmarks)
    meshes.append({"name": landmarks.name, "role": "rest", "kind": "bark", "tris": C.tris(landmarks), "size": size,
                   "center": rb(c), "hash": geom_digest(landmarks.data)})
    export.append(landmarks)
    for inst in instances:
        inst["mesh"] = TRUNK_PREFIX + inst["mesh"] + "__bark"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(TRUNK_OUT / "aero-trunks.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                             colors_type="SRGB")
    manifest = {
        "note": "Generated by scripts/build_world_aero_kit.py --trunks. Roblox studs. Trunk rootToCentre is the mesh bounds "
                "centre from the tree's root in its own frame at scale 1 (Roblox axes, before the tree's yaw).",
        "meshes": meshes, "trunks": instances, "hides": ["W7_Trunks__bark"],
        "triangles": sum(m["tris"] for m in meshes)}
    (TRUNK_OUT / "aero-trunks-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("TRUNKS", len(meshes), "meshes", manifest["triangles"], "tris,", len(instances), "trees")
    for m in meshes:
        print("TRUNKS mesh", m["name"], m["tris"], m["size"])


if __name__ == "__main__":
    if "--trunks" in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else False:
        main_trunks()
    else:
        main()
