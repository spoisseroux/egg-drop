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
- Falls: ONE vertex-coloured mesh for Tumble Falls: both back sheets (tapered, wavy sides, bowed out), the two foam lip
  rolls, and the wet rocks. Rock footprints are checked against the pets' surface map: only water, rock, empty or
  ground pets cannot reach (above LEDGE_Y).

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
# Section 4 layer 1: tapered, wavy sides, bowed out BOW studs at mid-height. The bow is exactly the cubic curve a Roblox
# Beam draws between the sheet's top and bottom attachments (axis n) with CurveSize0 = CURVE and CurveSize1 = -CURVE,
# CURVE = BOW / .75, so AeroFalls' flow beam, strands and ribbons bend with the sheet. Top (the lip) and foot stay on
# today's plane. Lip rolls: Fable's round 1 thickness (.5 upper,
# .6 lower: "hard white bars ... too thick" at .9 and 1.1).
FALLS = {
    "Water_TumbleFalls_Upper": {"rows": 14, "cols": 6, "bow": 1.5, "wave": .3, "waves": 1.6, "phase": .1,
                                "lip": {"over": .15, "radius": .26, "out": .2}},
    "Water_TumbleFalls_Lower": {"rows": 14, "cols": 6, "bow": 1.5, "wave": .35, "waves": 1.3, "phase": .55,
                                "lip": {"over": .2, "radius": .3, "out": .2}},
}
WHITE = (0xF4, 0xFC, 0xFF)
# Multiplies the falls texture: full in the middle, a little deeper where the sheet turns away at its sides.
SHEET_MIDDLE, SHEET_EDGE = (0xFF, 0xFF, 0xFF), (0xC8, 0xD8, 0xEE)
# Fable review r1: wet and darker than the marble ring (#9AA8B4 / #5E6B76 read dry and pale).
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


def sheet_point(name, u, v):
    """Roblox position on a kit sheet at beam parameter u (0 top, 1 bottom) and v -1 to 1 across (along t). A Beam with
    both attachments' Axis n, CurveSize0 c and CurveSize1 -c runs through P0 + 3c u(1-u) n along the straight line's
    cubic blend 3u^2 - 2u^3, and widens linearly in u: the sheet is built on the same curve."""
    top, bottom, w0, w1, n, t = frame(name)
    spec = FALLS[name]
    side = 1 if v >= 0 else -1
    h = 3 * u * u - 2 * u * u * u
    half = (w0 + (w1 - w0) * u) / 2 + spec["wave"] * math.sin(2 * math.pi * (h * spec["waves"] + spec["phase"] + .25 * side))
    out = 3 * curve(name) * u * (1 - u)
    return top + (bottom - top) * h + t * (half * v) + n * out


class Builder:
    def __init__(self, name):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.name = name

    def quad(self, pts, colors, uvs=None):
        vs = [self.bm.verts.new(bl(*p)) for p in pts]
        face = self.bm.faces.new(vs)
        for i, (loop, c) in enumerate(zip(face.loops, colors)):
            loop[self.col] = (*c, 1.0)
            loop[self.uv].uv = uvs[i] if uvs else (0.0, 0.0)

    def tri(self, pts, colors):
        self.quad(pts, colors)

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


def add_sheet(b, name):
    """The sheet carries today's falls texture with today's mapping (build_world_v7.py ribbon3: U = across / 6 from the
    middle, V = -distance down the fall / 14), so it keeps its stripes; vertex colours only shade its sides."""
    spec = FALLS[name]
    rows, cols = spec["rows"], spec["cols"]
    grid = [[sheet_point(name, r / rows, -1 + 2 * c / cols) for c in range(cols + 1)] for r in range(rows + 1)]
    top = frame(name)[0]
    down = [0.0]
    for r in range(1, rows + 1):
        down.append(down[-1] + (grid[r][cols // 2] - grid[r - 1][cols // 2]).length)

    def uv(r, c):
        middle = grid[r][cols // 2]
        across = (grid[r][c] - middle).length * (1 if c >= cols // 2 else -1)
        return (across / 6, -down[r] / 14)

    def color(r, c):
        v = abs(-1 + 2 * c / cols)
        return lin(mix(SHEET_MIDDLE, SHEET_EDGE, v ** 2))
    for r in range(rows):
        for c in range(cols):
            b.quad([grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]],
                   [color(r, c), color(r, c + 1), color(r + 1, c + 1), color(r + 1, c)],
                   [uv(r, c), uv(r, c + 1), uv(r + 1, c + 1), uv(r + 1, c)])


def add_lip(b, name):
    """A foam roll along the sheet's top edge, a little in front of it, thinning to the ends."""
    spec = FALLS[name]["lip"]
    _, _, _, _, n, _ = frame(name)
    up = Vector((0, 1, 0))
    segs, sides = 14, 6
    over = 1 + spec["over"] / (frame(name)[2] / 2)
    rings = []
    for i in range(segs + 1):
        v = -over + 2 * over * i / segs
        centre = sheet_point(name, 0, max(-1, min(1, v))) + n * spec["out"] + up * .1
        if abs(v) > 1:  # past the sheet's edge: carry on straight along t
            centre += frame(name)[5] * ((abs(v) - 1) * frame(name)[2] / 2 * (1 if v > 0 else -1))
        k = abs(v) / over
        radius = spec["radius"] * (1 - .55 * k ** 3)
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            ring.append(centre + (n * math.cos(a) + up * math.sin(a)) * radius)
        rings.append(ring)
    white = lin(WHITE)
    for i in range(segs):
        for j in range(sides):
            jj = (j + 1) % sides
            b.quad([rings[i][j], rings[i][jj], rings[i + 1][jj], rings[i + 1][j]], [white] * 4)
    for ring in (rings[0], rings[-1]):
        c = sum(ring, Vector()) / sides
        for j in range(sides):
            b.tri([c, ring[j], ring[(j + 1) % sides]], [white] * 3)


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
    sheets = Builder("Sheets__waterfall_tumble")
    b = Builder("Falls__kitwater")
    for name in FALLS:
        add_sheet(sheets, name)
        add_lip(b, name)
    list_ = rocks()
    check_rocks(list_)
    for i, rock in enumerate(list_):
        add_rock(b, rock, 40 + i)
    frames = {}
    for name, spec in FALLS.items():
        top, bottom, w0, w1, n, t = frame(name)
        frames[name] = {"bow": spec["bow"], "curve": round(curve(name), 6),
                        "lip": {"over": spec["lip"]["over"], "radius": spec["lip"]["radius"], "out": spec["lip"]["out"]}}
    return [sheets.build(facing=frame(next(iter(FALLS)))[4]), b.build()], list_, frames


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
        role = "falls" if obj.name.startswith(("W7_Kit_Falls", "W7_Kit_Sheets")) else "rest"
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
              "W7_Water__waterfall_tumble": merged["Water__waterfall_tumble"]}
    manifest = {
        "note": "Generated by scripts/build_world_aero_kit.py. Roblox studs. Crown pivotToCentre is the mesh bounds "
                "centre from its pivot in the tree's own frame at scale 1 (Roblox axes, before the tree's yaw).",
        "meshes": meshes, "crowns": instances, "rocks": rock_list, "falls": frames, "hides": hidden,
        "triangles": sum(m["tris"] for m in meshes)}
    (OUT / "aero-kit-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("KIT", len(meshes), "meshes", manifest["triangles"], "tris,", len(instances), "crowns,", len(rock_list), "rocks")
    for m in meshes:
        print("KIT mesh", m["name"], m["tris"], m["size"])


if __name__ == "__main__":
    main()
