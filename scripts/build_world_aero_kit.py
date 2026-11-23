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

# WORLD-PASS 1B: lime crowns shade from a cooler, darker underside to full colour on top. Vertex colours multiply the
# lime map (AeroWorld writes it on a white part), so the top is 1 and the underside is #5FAE2A over the map's #8FD63F.
LIME_UNDER = (95 / 143, 174 / 214, 42 / 63)
LIME_TOP = (1.0, 1.0, 1.0)


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
    # 1B: lime shading by height inside each crown (its own clumps keep their round form from the old colours).
    blossom = canon["Crown_Blossom"]["obj"].data
    zs = [v.co.z for v in blossom.vertices]
    z0, z1 = min(zs), max(zs)
    colors = blossom.color_attributes.active_color or blossom.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    assert colors.domain == "CORNER", colors.domain
    for loop in blossom.loops:
        k = (blossom.vertices[loop.vertex_index].co.z - z0) / max(z1 - z0, 1e-6)
        k = k * k * (3 - 2 * k)
        colors.data[loop.index].color_srgb = tuple(LIME_UNDER[i] + (LIME_TOP[i] - LIME_UNDER[i]) * k for i in range(3)) + (1.0,)
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
    def __init__(self, name):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.name = name

    def quad(self, pts, colors, uvs=None, smooth=False):
        vs = [self.bm.verts.new(bl(*p)) for p in pts]
        face = self.bm.faces.new(vs)
        face.smooth = smooth
        for i, (loop, c) in enumerate(zip(face.loops, colors)):
            loop[self.col] = (*c, 1.0)
            loop[self.uv].uv = uvs[i] if uvs else (0.0, 0.0)

    def tri(self, pts, colors, uvs=None, smooth=False):
        self.quad(pts, colors, uvs, smooth)

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
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


ROCK_TOP_FACE, ROCK_FOOT_FACE = (0x55, 0x66, 0x6B), (0x44, 0x54, 0x5A)  # LOOK-R2 r3: slate, no blue
CHUTE_TOP, CHUTE_WHITE, CHUTE_EDGE = (0x7F, 0xE0, 0xFF), (0xFF, 0xFF, 0xFF), (0xEA, 0xF6, 0xFF)
# Per drop: three ledges (fraction of the drop's height, how far proud). LOOK-R2 round 3: three chutes (width shares
# 2.4 / 4.2 / 3.0 of the sheet) with short, staggered gaps between them: (gap width in studs, from, to as fractions of the
# drop's height; closed in the top 20 percent and the foot 10 percent). The water kinks out KINK studs at each ledge.
LEDGES = {"Water_TumbleFalls_Upper": ((.24, .7), (.52, 1.0), (.78, .6)),
          "Water_TumbleFalls_Lower": ((.27, .9), (.55, .6), (.8, 1.0))}
CHUTE_SHARES = (2.4, 4.2, 3.0)
GAPS = {"Water_TumbleFalls_Upper": ((.35, .22, .62), (.45, .40, .86)),
        "Water_TumbleFalls_Lower": ((.4, .30, .78), (.3, .21, .55))}
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
            half = (w0 + (w1 - w0) * h) / 2 + 1.0
            proud = sum(p * math.exp(-((h - at) / .045) ** 2) for at, p in LEDGES[name])
            out = -.35 + proud * (1 - .25 * abs(v)) + jitter[r][c]
            row.append(top + (bottom - top) * h + t * (half * v) + n * out)
        grid.append(row)
    for r in range(rows):
        cs = [lin(mix(ROCK_TOP_FACE, ROCK_FOOT_FACE, rr / rows)) for rr in (r, r, r + 1, r + 1)]
        for c in range(cols):
            b.quad([grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]], cs)


def add_chutes(b, name, rows=22):
    """LOOK-R2 round 3: one white sheet per drop on the beam curve (bow 1.5), split into three chutes only where the
    staggered gaps run (never at the lip or the foot), kinking out KINK studs over each ledge. White in the middle,
    #EAF6FF at the edges, clear aqua only at the very lip. Smooth shaded."""
    top, bottom, w0, w1, n, t = frame(name)
    c = curve(name)
    total = sum(CHUTE_SHARES)
    bounds = [0.0]
    for share in CHUTE_SHARES:
        bounds.append(bounds[-1] + share / total)
    # Columns: the chute edges either side of each gap, and a middle line in each chute.
    gaps = GAPS[name]

    def columns(u):
        sheet = w0 + (w1 - w0) * u
        xs = []
        for i in range(len(CHUTE_SHARES)):
            lo, hi = bounds[i] * sheet, bounds[i + 1] * sheet
            if i > 0:
                lo += gaps[i - 1][0] / 2
            if i < len(CHUTE_SHARES) - 1:
                hi -= gaps[i][0] / 2
            xs.append((lo - sheet / 2, (lo + hi) / 2 - sheet / 2, hi - sheet / 2))
        return xs

    def point(u, x):
        h = 3 * u * u - 2 * u * u * u
        kink = sum(KINK * math.exp(-((h - at) / .07) ** 2) for at, _ in LEDGES[name])
        return top + (bottom - top) * h + t * x + n * (3 * c * u * (1 - u) + .05 + kink)

    def core(u):
        return CHUTE_WHITE if u > .12 else mix(CHUTE_TOP, CHUTE_WHITE, max(0.0, (u - .04) / .08))

    def edge(u):
        return lin(mix(core(u), CHUTE_EDGE, 1.0))
    for r in range(rows):
        u0, u1 = r / rows, (r + 1) / rows
        h_mid = 3 * ((u0 + u1) / 2) ** 2 - 2 * ((u0 + u1) / 2) ** 3
        c0, c1 = columns(u0), columns(u1)
        k0, k1 = lin(core(u0)), lin(core(u1))
        for i in range(len(CHUTE_SHARES)):
            (l0, m0, h0), (l1, m1, h1) = c0[i], c1[i]
            b.quad([point(u0, l0), point(u0, m0), point(u1, m1), point(u1, l1)], [edge(u0), k0, k1, edge(u1)],
                   smooth=True)
            b.quad([point(u0, m0), point(u0, h0), point(u1, h1), point(u1, m1)], [k0, edge(u0), edge(u1), k1], smooth=True)
            # A gap closed at this height: water bridges it.
            if i < len(CHUTE_SHARES) - 1:
                width, lo, hi = gaps[i]
                if not (lo <= h_mid <= hi):
                    n0, n1 = c0[i + 1], c1[i + 1]
                    b.quad([point(u0, h0), point(u0, n0[0]), point(u1, n1[0]), point(u1, h1)], [edge(u0), edge(u0), edge(u1), edge(u1)],
                           smooth=True)


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
    b = Builder("Falls__kitwater")
    for name in FALLS:
        add_rock_face(b, name)
        add_chutes(b, name)
    list_ = rocks()
    check_rocks(list_)
    for i, rock in enumerate(list_):
        add_rock(b, rock, 40 + i)
    frames = {name: {"bow": spec["bow"], "curve": round(curve(name), 6)} for name, spec in FALLS.items()}
    return [b.build()], list_, frames


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
                       "hash": geom_digest(obj.data)})
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


if __name__ == "__main__":
    main()
