"""Merge the World 1 v7 import chunks into Roblox-sized MeshParts and export one FBX.

Run in BACKGROUND Blender only (never the live session):
  blender.exe -b assets/art-source/environment/world1-mockup-v7-import.blend --python scripts/build_world_v7_chunks.py

Reads the 249 single-material chunks (identity transforms, origin at the world origin) and writes:
- assets/world/world-v7.fbx            merged meshes, origin at each mesh's bounds centre
- assets/world/world-v7-manifest.json  name, material, tris, Roblox centre/size, collide class, anim, pivot
- assets/world/world-v7-walk.json      perimeter wall boxes, cave blocker, fall catch, wet boxes, ground heights,
                                       and a 1-stud top-surface map (grass / path / water / rock / structure)
Declutter (batch 2026-11-13, W1): faces listed in assets/world/world-v7-declutter.json (scripts/build_world_v7_declutter.py:
12 hub props and the 3D flower clusters) are deleted from the import chunks before merging. When the merge changes
meshes, it also writes
- assets/world/world-v7-declutter.fbx  only the changed / new meshes, for upload
- assets/world/world-v7-pending.json   changed names + their previous manifest entries; build_world_v7_assets.py
                                       keeps the previous geometry for these until their new mesh ids are in
                                       world-v7-studio-import.json (then delete the pending file)
The .blend is never saved.

Coordinates: Blender (x, y, z) = Roblox (x, z + 4, -y).
"""
from __future__ import annotations

import json
import math
from collections import defaultdict
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(bpy.data.filepath).resolve().parents[3]
OUT = ROOT / "assets" / "world"
OUT.mkdir(parents=True, exist_ok=True)
TRI_CAP = 9000
BACKDROP_SPAN = 1900.0  # keeps every backdrop MeshPart under Roblox's 2048-stud limit


def rb(v):
    return [round(v[0], 4), round(v[2] + 4, 4), round(-v[1], 4)]


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


FLAT_KEEP = {"glow_warm", "glow_aqua", "glow_pink", "cloud", "foam", "bubble"}
FLAT = {}  # material name -> sRGB colour, filled from the blend


def raw_material(name):
    return name.rsplit("__", 1)[1]


def material_of(name):
    mat = raw_material(name)
    return "palette" if mat in FLAT else mat


COLLIDE_MATERIALS = {"marble", "marble_smooth", "wood_plank", "trim", "cliff_rock", "grass", "ground", "dirt_path",
                     "meadow", "pebble_bed", "boulder_rock", "bark", "deck_cream", "deck_shell", "teal", "gold"}


def classify(name):
    """Return (group key, collide, anim, region)."""
    cat = name.rsplit("__", 1)[0]
    mat = material_of(name)
    if cat.startswith("Anim__"):
        obj = cat[len("Anim__"):]
        if obj.startswith("Water_"):
            return "Water__" + mat, False, None, "Water"
        if obj.startswith("Chime_") or obj.startswith("Pennant_"):
            return obj + "__" + mat, False, "sway", obj
        if obj.startswith("Landmark_HatchTree_Lantern"):
            return "Lantern__" + mat, False, "sway", "Lantern"
        if obj.startswith("Station_CareCradle_Canopy_Mobile"):
            return "CradleMobile__" + mat, False, "sway", "CradleMobile"
        if obj.startswith("Islet_Near_"):
            islet = obj[len("Islet_Near_"):].split("_")[0]
            phase = "A" if islet in ("East", "SouthEast", "South") else "B"
            return f"Islets{phase}__" + mat, False, "bob", "Islets" + phase
        if obj.startswith("Drifting_Rock_"):
            phase = "A" if int(obj.rsplit("_", 1)[1]) % 2 else "B"
            return f"DriftRocks{phase}__" + mat, False, "bob", "DriftRocks" + phase
        if obj.startswith("Lamp_"):
            return "LampOrbs__" + mat, False, "pulse", "LampOrbs"
        if "BubbleSpring_Bubble" in obj:
            return "Bubbles__" + mat, False, "bob", "Bubbles"
        if "Crystals" in obj:
            return "Crystals__" + mat, False, "pulse", "Crystals"
        if obj.startswith("Station_ArrivalDais_Glow"):
            return "ArrivalGlow__" + mat, False, "pulse", "ArrivalGlow"
        if obj.startswith("Station_EggNest_Glow"):
            return "NestHalo__" + mat, False, "pulse", "NestHalo"
        return obj + "__" + mat, False, None, obj
    if cat.startswith("Terrain_Ground"):
        return "Ground__" + mat, True, None, "Ground"
    if cat == "Rocks_Underside":
        return "Underside__" + mat, False, None, "Underside"
    if cat.startswith("Rocks_"):
        return "Rocks__" + mat, True, None, "Rocks"
    if cat in ("Architecture_Rotunda", "Architecture_Stairs"):
        return "Rotunda__" + mat, True, None, "Rotunda"
    if cat == "Architecture_Bridge":
        return "Bridge__" + mat, True, None, "Bridge"
    if cat == "Architecture_Balustrades":
        return "Balustrades__" + mat, True, None, "Balustrades"
    if cat == "Architecture_Aqueduct":
        return "Aqueduct__" + mat, True, None, "Aqueduct"
    if cat.startswith("Architecture_"):
        return "Architecture__" + mat, mat in COLLIDE_MATERIALS or mat == "palette", None, "Architecture"
    if cat == "Landmarks":
        return "Landmarks__" + mat, mat in COLLIDE_MATERIALS, None, "Landmarks"
    if cat.startswith("Stations_"):
        return "Stations__" + mat, mat in ("marble", "marble_smooth", "wood_plank", "trim"), None, "Stations"
    if cat == "Props":
        return "Props__" + mat, True, None, "Props"
    if cat in ("Vegetation_Trees", "Vegetation_HatchTree") and mat == "bark":
        return "Trunks__bark", True, None, "Trunks"
    if cat.startswith("Vegetation_"):
        return "Vegetation__" + mat, False, None, "Vegetation"
    if cat.startswith("Backdrop_"):
        return "Backdrop__" + mat, False, None, "Backdrop"
    raise ValueError(name)


ANIM_BY_OBJECT = {}
for o in bpy.data.objects:
    if o.type == "MESH" and o.get("anim"):
        ANIM_BY_OBJECT[o.name] = str(o["anim"])


def linear_to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def build_palette():
    for m in bpy.data.materials:
        key = m.name[3:] if m.name.startswith("W1_") else m.name
        if key in FLAT_KEEP or not m.use_nodes:
            continue
        if any(n.type == "TEX_IMAGE" and n.image for n in m.node_tree.nodes):
            continue
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        col = bsdf.inputs["Base Color"].default_value
        FLAT[key] = [linear_to_srgb(col[i]) for i in range(3)]
    names = sorted(FLAT)
    side = 8  # 8x8 swatches, 8 px each -> 64x64 png
    slots = {}
    for i, name in enumerate(names):
        sx, sy = i % side, i // side
        slots[name] = ((sx + 0.5) / side, (sy + 0.5) / side)
    # The PNG is written by scripts/build_world_v7_assets.py (Blender's image save wrote black here).
    (OUT / "world-v7-palette.json").write_text(json.dumps({
        "side": side, "px": 8, "order": names, "srgb": {n: [round(c, 5) for c in FLAT[n]] for n in names},
        "note": "Slot i sits at column i % side, row i // side counted from the BOTTOM in Blender UV space."}, indent=1))
    return slots


SLOTS = {}


def duplicate(obj, name):
    new = obj.copy()
    new.data = obj.data.copy()
    mat = raw_material(obj.name)
    if mat in SLOTS:
        uv = new.data.uv_layers.active or new.data.uv_layers.new()
        u, v = SLOTS[mat]
        for loop in uv.data:
            loop.uv = (u, v)
    new.name = name
    bpy.context.scene.collection.objects.link(new)
    return new


def join(objs, name):
    if len(objs) == 1:
        objs[0].name = name
        return objs[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def split_loose(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    return [o for o in bpy.context.selected_objects]


def centre_of(obj):
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    return lo, hi


def bins_by_x(objs, cap):
    objs = sorted(objs, key=lambda o: (centre_of(o)[0] + centre_of(o)[1]).x)
    out, cur, count = [], [], 0
    for o in objs:
        t = tris(o)
        if cur and count + t > cap:
            out.append(cur)
            cur, count = [], 0
        cur.append(o)
        count += t
    if cur:
        out.append(cur)
    return out


def recentre(obj):
    lo, hi = centre_of(obj)
    c = (lo + hi) / 2
    obj.data.transform(__import__("mathutils").Matrix.Translation(-c))
    obj.location = c
    return lo, hi, c


def declutter(sources):
    """Delete import faces whose vertices all match a removed source face (world-v7-declutter.json)."""
    path = OUT / "world-v7-declutter.json"
    if not path.exists():
        return sources
    data = json.loads(path.read_text())
    points, owner = [], []
    for name, entry in data["objects"].items():
        for v in entry["verts"]:
            points.append(v)
            owner.append(name)
    kd = KDTree(len(points))
    for i, p in enumerate(points):
        kd.insert(p, i)
    kd.balance()
    removed = defaultdict(int)
    keep = []
    for o in sources:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill = []
        for f in bm.faces:
            names = []
            for v in f.verts:
                _, index, dist = kd.find(o.matrix_world @ v.co)
                if index is None or dist > 2e-3:
                    names = None
                    break
                names.append(owner[index])
            if names:
                kill.append(f)
                removed[names[0]] += 1
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="FACES")
            bm.to_mesh(o.data)
            o.data.update()
        bm.free()
        if len(o.data.polygons) == 0:
            print("DECLUTTER emptied", o.name)
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        keep.append(o)
    for name, entry in data["objects"].items():
        got = removed.get(name, 0)
        print("DECLUTTER", name, got, "/", entry["faces"])
        # The entablature span also owns one end face per material whose centre sits nearer the next span (its
        # vertices are all span-01 vertices, so it goes too): 21 import faces for the 18 listed.
        assert entry["faces"] <= got <= entry["faces"] + 3, (name, got, entry["faces"])
    return keep


# ---------------------------------------------------------------------------------------------------------------
# QA 2026-11-13 (Q3) world fixes, applied to the import chunks after the declutter. Every chunk a fix touches is
# recorded in TOUCHED so its merged mesh re-exports even when tris / bounds are unchanged (normal-only edits).
# ---------------------------------------------------------------------------------------------------------------
TOUCHED = set()
# Chunks touched by THIS round's fixes (QA v2 R5). Only these force a re-export of unchanged-bounds meshes; TOUCHED keeps
# the earlier rounds' log (their meshes are already uploaded) and later runs compare the manifest "hash" instead.
FRESH = set()
EXTRA_META = {}  # merged-mesh group key -> extra manifest fields (castle flag pivots)

# Lamps 1 and 2 stood on the Spawn-to-Hub dirt path: moved onto the grass just off the path edge
# (Roblox studs dx, dy, dz; dy follows the ground). src/shared/HollowWorldLayout.lua Lamps moves with them.
LAMP_MOVES = {1: (-0.35, -0.018, 1.97), 2: (-0.56, -0.014, -3.15)}


def obj_named(sources, name):
    return next(o for o in sources if o.name == name)


def move_lamps(sources):
    from mathutils import Matrix
    for k, (dx, dy, dz) in LAMP_MOVES.items():
        hits = [o for o in sources if o.name.startswith(f"Stations_Lamp_{k}__") or o.name.startswith(f"Anim__Lamp_{k}_Orb_Glow__")]
        assert len(hits) == 3, (k, [o.name for o in hits])
        for o in hits:
            o.data.transform(Matrix.Translation((dx, -dz, dy)))
            o.data.update()
            TOUCHED.add(o.name)
    print("QA3 lamps moved", sorted(LAMP_MOVES))


def split_castle_flags(sources):
    """The three distant castles carry 9 pennants authored as two coincident faces of opposite winding. The merged
    backdrop mesh renders double-sided, so the pair z-fought (the flicker while moving). Keep one face per flag as
    its own tiny mesh (Anim__CastleFlag_N) so the client can wave it about its pole."""
    chunk = obj_named(sources, "Backdrop_Islands__far_peak")
    me = chunk.data
    groups = defaultdict(list)
    for p in me.polygons:
        key = tuple(sorted(tuple(round(c, 3) for c in me.vertices[v].co) for v in p.vertices))
        groups[key].append(p.index)
    pairs = sorted(sorted(v) for v in groups.values() if len(v) == 2)
    assert len(pairs) == 9, len(pairs)
    made = []
    for n, (keep, twin) in enumerate(pairs, 1):
        flag = chunk.copy()
        flag.data = me.copy()
        bm = bmesh.new()
        bm.from_mesh(flag.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index != keep], context="FACES")
        bm.to_mesh(flag.data)
        bm.free()
        flag.name = f"Anim__CastleFlag_{n}__far_peak"
        bpy.context.scene.collection.objects.link(flag)
        pts = [v.co.copy() for v in flag.data.vertices]
        # The pole edge: the vertices sharing one (x, y); the flag waves about that vertical line.
        cols = defaultdict(list)
        for v in pts:
            cols[(round(v.x, 2), round(v.y, 2))].append(v)
        pole = max(cols.values(), key=len)
        mid = sum(pole, Vector()) / len(pole)
        EXTRA_META[f"CastleFlag_{n}__far_peak"] = {"pivot": rb(mid)}
        made.append(flag)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    gone = {i for pair in pairs for i in pair}
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in gone], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()
    TOUCHED.add(chunk.name)
    print("QA3 castle flags split", len(made))
    return sources + made


def fix_foam(sources):
    """Foam blobs: some were wound inward (dark, see-through bottoms). Recalculate outward normals per blob."""
    for o in sources:
        if not o.name.endswith("__foam"):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        before = [f.normal.copy() for f in bm.faces]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        flipped = sum(1 for f, n in zip(bm.faces, before) if f.normal.dot(n) < 0)
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
        if flipped:
            TOUCHED.add(o.name)
        print("QA3 foam normals", o.name, "flipped", flipped, "of", len(before))


def _colour_layer(bm):
    for layers in (bm.loops.layers.float_color, bm.loops.layers.color):
        if layers.get("Col") is not None:
            return "loop", layers.get("Col")
    for layers in (bm.verts.layers.float_color, bm.verts.layers.color):
        if layers.get("Col") is not None:
            return "vert", layers.get("Col")
    return None, None


def _paint(face, uvl, uvs, domain, col, colour):
    for loop, uv in zip(face.loops, uvs):
        loop[uvl].uv = uv
        if domain == "loop":
            loop[col] = colour
        elif domain == "vert":
            loop.vert[col] = colour


def _uv_scale(bm, uvl, count=60):
    ratios = []
    for f in list(bm.faces)[:count]:
        for loop in f.loops:
            nxt = loop.link_loop_next
            d = (nxt.vert.co - loop.vert.co).length
            if d > 0.2:
                ratios.append((nxt[uvl].uv - loop[uvl].uv).length / d)
    ratios.sort()
    return ratios[len(ratios) // 2] if ratios else 0.25


def cap_edging(sources):
    """Stream / pool curbs are open boxes (top + inner + outer wall per segment). Where a run ends or two runs meet
    at an angle the hollow end showed, and bends left wedge gaps. Cap every unshared segment end; where two loose
    ends nearly touch, loft between them instead so the curb reads continuous."""
    o = obj_named(sources, "Architecture_Edging__marble")
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    domain, col = _colour_layer(bm)
    k = _uv_scale(bm, uvl)
    seen, islands = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        islands.append(island)

    def key(co):
        return (round(co.x, 3), round(co.y, 3), round(co.z, 3))
    tops, sides = [], []
    for isl in islands:
        verts = {key(v.co): v.co.copy() for f in isl for v in f.verts}
        colour = None
        if domain == "loop":
            colour = tuple(isl[0].loops[0][col])
        elif domain == "vert":
            colour = tuple(isl[0].loops[0].vert[col])
        entry = {"verts": verts, "colour": colour}
        (tops if abs(isl[0].normal.z) > 0.9 else sides).append(entry)
    side_by_top = defaultdict(list)
    for s in sides:
        zs = [c.z for c in s["verts"].values()]
        top_z, bot_z = max(zs), min(zs)
        edge = tuple(sorted(kk for kk, c in s["verts"].items() if c.z > top_z - 1e-3))
        if len(edge) == 2:
            s["bottom"] = bot_z
            side_by_top[edge].append(s)
    ends, segs = [], []
    for t in tops:
        ks = list(t["verts"])
        if len(ks) != 4:
            continue
        long_edges = []
        for i in range(4):
            for j in range(i + 1, 4):
                e = tuple(sorted((ks[i], ks[j])))
                if e in side_by_top:
                    long_edges.append((e, side_by_top[e][0]))
        if len(long_edges) != 2:
            continue
        (a, sa), (b, sb) = long_edges
        pa = [t["verts"][x] for x in a]
        pb = [t["verts"][x] for x in b]
        if (pa[0] - pb[0]).length > (pa[0] - pb[1]).length:
            pb.reverse()
        bottom = min(sa["bottom"], sb["bottom"])
        centre = sum(pa + pb, Vector()) / 4
        seg = len(segs)
        segs.append(centre)
        for i in range(2):
            ends.append({"seg": seg, "p": pa[i], "q": pb[i], "bottom": bottom, "centre": centre, "colour": t["colour"]})
    count = defaultdict(int)
    for e in ends:
        count[frozenset((key(e["p"]), key(e["q"])))] += 1
    loose = [e for e in ends if count[frozenset((key(e["p"]), key(e["q"])))] == 1]
    used, lofts, caps = set(), 0, 0
    # Loft pairs: two loose ends of different segments whose corners nearly meet.
    pairs = []
    for i, e in enumerate(loose):
        for j in range(i + 1, len(loose)):
            f2 = loose[j]
            if f2["seg"] == e["seg"]:
                continue
            d1 = max((e["p"] - f2["p"]).length, (e["q"] - f2["q"]).length)
            d2 = max((e["p"] - f2["q"]).length, (e["q"] - f2["p"]).length)
            d = min(d1, d2)
            if d < 1.1:
                pairs.append((d, i, j, d2 < d1))
    pairs.sort()

    def face(points, normal_hint, colour):
        vs = []
        for co in points:
            if vs and (vs[-1].co - co).length < 1e-4:
                continue
            vs.append(bm.verts.new(co))
        if len(vs) > 2 and (vs[0].co - vs[-1].co).length < 1e-4:
            vs.pop()
        if len(vs) < 3:
            return None
        f = bm.faces.new(vs)
        f.material_index = 0
        f.smooth = False
        f.normal_update()
        if f.normal.dot(normal_hint) < 0:
            f.normal_flip()
        # Planar UVs: horizontal faces map x/y, walls map their run along the top edge and the height.
        if abs(f.normal.z) > 0.7:
            uvs = [(l.vert.co.x * k, l.vert.co.y * k) for l in f.loops]
        else:
            run = Vector((f.normal.y, -f.normal.x, 0))
            uvs = [(l.vert.co.dot(run) * k, l.vert.co.z * k) for l in f.loops]
        _paint(f, uvl, uvs, domain, col, colour)
        return f

    def down(co, z):
        return Vector((co.x, co.y, z))
    for d, i, j, swap in pairs:
        if i in used or j in used:
            continue
        used.update((i, j))
        e, g = loose[i], loose[j]
        gp, gq = (g["q"], g["p"]) if swap else (g["p"], g["q"])
        z = min(e["bottom"], g["bottom"])
        mid = (e["p"] + e["q"] + gp + gq) / 4
        face([e["p"], e["q"], gq, gp], Vector((0, 0, 1)), e["colour"])
        for a, b in ((e["p"], gp), (e["q"], gq)):
            wall_mid = (a + b) / 2
            face([a, b, down(b, z), down(a, z)], Vector((wall_mid.x - mid.x, wall_mid.y - mid.y, 0)), e["colour"])
        lofts += 1
    for i, e in enumerate(loose):
        if i in used:
            continue
        m = (e["p"] + e["q"]) / 2
        face([e["p"], e["q"], down(e["q"], e["bottom"]), down(e["p"], e["bottom"])],
             Vector((m.x - e["centre"].x, m.y - e["centre"].y, 0)), e["colour"])
        caps += 1
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    TOUCHED.add(o.name)
    print("QA3 edging segments", len(segs), "loose ends", len(loose), "lofts", lofts, "caps", caps)


# Dirt-path aprons so the paths run straight onto both bridge deck ends (Roblox x, z outlines, measured on a
# top-down render of the import scene: deck x -3.6 .. 11.6, z 17.6 .. 24.4).
APRONS = {
    "west": [(-3.75, 17.5), (-3.75, 24.5), (-6.6, 24.6), (-8.3, 22.2), (-7.6, 19.4), (-5.6, 16.9)],
    "east": [(11.75, 17.5), (14.6, 17.4), (17.4, 20.8), (19.6, 25.4), (15.2, 27.0), (11.75, 24.5)],
}


def bridge_aprons(sources):
    import numpy as np
    path = obj_named(sources, "Terrain_Ground__dirt_path")
    ground = [obj_named(sources, n) for n in ("Terrain_Ground__grass", "Terrain_Ground__ground", "Terrain_Ground__dirt_path")]
    trees = []
    for g in ground:
        b = bmesh.new()
        b.from_mesh(g.data)
        b.transform(g.matrix_world)
        trees.append(BVHTree.FromBMesh(b))
        b.free()

    def height(x, y):
        best = None
        for t in trees:
            hit = t.ray_cast(Vector((x, y, 200)), Vector((0, 0, -1)))
            if hit[0] is not None and (best is None or hit[0].z > best):
                best = hit[0].z
        return best
    bm = bmesh.new()
    bm.from_mesh(path.data)
    uvl = bm.loops.layers.uv.active
    domain, col = _colour_layer(bm)
    # The path UVs are a planar projection: fit u, v = A (x, y, 1) so the aprons tile seamlessly into it.
    rows, us, vs, colours = [], [], [], []
    for f in bm.faces:
        for loop in f.loops:
            rows.append((loop.vert.co.x, loop.vert.co.y, 1.0))
            us.append(loop[uvl].uv.x)
            vs.append(loop[uvl].uv.y)
            if domain == "loop":
                colours.append(tuple(loop[col]))
            elif domain == "vert":
                colours.append(tuple(loop.vert[col]))
    A = np.array(rows)
    fu, ru, *_ = np.linalg.lstsq(A, np.array(us), rcond=None)
    fv, rv, *_ = np.linalg.lstsq(A, np.array(vs), rcond=None)
    rms = math.sqrt(float((ru[0] if len(ru) else 0) + (rv[0] if len(rv) else 0)) / max(len(rows), 1))
    colour = tuple(float(np.mean([c[i] for c in colours])) for i in range(len(colours[0]))) if colours else None
    added = 0
    for name, outline in APRONS.items():
        new = bmesh.new()
        ring = [new.verts.new((x, -z, 0)) for x, z in outline]
        new.faces.new(ring)
        bmesh.ops.triangulate(new, faces=new.faces[:])
        bmesh.ops.subdivide_edges(new, edges=new.edges[:], cuts=3, use_grid_fill=True)
        bmesh.ops.triangulate(new, faces=new.faces[:])
        lift = {}
        for v in new.verts:
            h = height(v.co.x, v.co.y)
            assert h is not None, (name, tuple(v.co))
            lift[v.index] = h + 0.035
        new.verts.index_update()
        mapping = {}
        for v in new.verts:
            mapping[v.index] = bm.verts.new((v.co.x, v.co.y, lift[v.index]))
        for f in new.faces:
            nf = bm.faces.new([mapping[v.index] for v in f.verts])
            nf.smooth = True
            nf.normal_update()
            if nf.normal.z < 0:
                nf.normal_flip()
            uvs = [(fu[0] * l.vert.co.x + fu[1] * l.vert.co.y + fu[2], fv[0] * l.vert.co.x + fv[1] * l.vert.co.y + fv[2]) for l in nf.loops]
            _paint(nf, uvl, uvs, domain, col, colour)
            added += 1
        new.free()
    bm.to_mesh(path.data)
    bm.free()
    path.data.update()
    TOUCHED.add(path.name)
    print("QA3 bridge aprons faces", added, "path uv fit rms", round(rms, 4))


# Cliff edges: the terrain and crag chunks were smooth-shaded with no sharp edges, so normals bled across the
# island rim and cliff creases (dark smears, lit-wrong skirts). Split normals at creases sharper than 40 degrees.
SHARPEN = ("Terrain_Ground__ground", "Terrain_Ground__grass", "Rocks_Walls__cliff_rock", "Rocks_Walls__grass",
           "Landmarks__cliff_rock")


def sharpen_cliffs(sources):
    for o in sources:
        if o.name in SHARPEN:
            o.data.set_sharp_from_angle(angle=math.radians(40))
            o.data.update()
            TOUCHED.add(o.name)
    print("QA3 sharpened", [n for n in SHARPEN])


# ---------------------------------------------------------------------------------------------------------------
# QA v2 2026-11-13 (R5.4): "the marble river lining still flickers" (shot 193213). Found with a coplanar-overlap scan
# of the import chunks (every pair of same-plane faces whose outlines overlap):
# - Architecture_Edging__marble: EVERY curb face had a twin on the same four vertices facing the other way (534 pairs:
#   178 tops, 356 walls; the mockup's one-sided-render workaround). WorldAssets renders opaque scenery DoubleSided, so
#   each curb surface drew twice and z-fought along every stream and pool. Keep the outward face of each twin.
# - Architecture_Aqueduct__marble: in the sky-falls channel (Roblox x -9..0, z 50..57) slab bottoms and a channel floor
#   lie exactly in Terrain_Ground__pebble_bed's top plane (y 2.1), seen through the water: drop the hidden bottoms,
#   lift the floor faces 0.05 studs.
# - Anim__Water_SkyFalls_Channel__water_stream: the channel water quad was coplanar with the stream water it overlaps
#   (y 3.2, both translucent, same merged mesh): lower it 0.04 studs so the stream draws over it.
# ---------------------------------------------------------------------------------------------------------------
def dedupe_edging(sources):
    o = obj_named(sources, "Architecture_Edging__marble")
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()

    def key(co):
        return (round(co.x, 3), round(co.y, 3), round(co.z, 3))
    twins = defaultdict(list)
    for f in bm.faces:
        twins[frozenset(v.index for v in f.verts)].append(f)
    # Top centres by corner key, so a wall finds the top it hangs from (its two highest corners are top corners).
    top_of = defaultdict(list)
    for f in bm.faces:
        if f.normal.z > 0.9:
            centre = f.calc_center_median()
            corners = frozenset(key(u.co) for u in f.verts)
            for v in f.verts:
                top_of[key(v.co)].append((corners, centre))
    kill, tops, walls, guessed = [], 0, 0, 0
    for faces in twins.values():
        if len(faces) != 2:
            continue
        a, b = faces
        if a.normal.dot(b.normal) > -0.99:
            continue
        if abs(a.normal.z) > 0.9:
            kill.append(a if a.normal.z < 0 else b)
            tops += 1
            continue
        corners = sorted(a.verts, key=lambda v: -v.co.z)[:2]
        k0, k1 = key(corners[0].co), key(corners[1].co)
        centre = next((c for ks, c in top_of[k0] if k1 in ks), None)
        mid = a.calc_center_median()
        if centre is None:
            guessed += 1
            kill.append(b)
            continue
        out = Vector((mid.x - centre.x, mid.y - centre.y, 0))
        kill.append(a if a.normal.dot(out) < 0 else b)
        walls += 1
    bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    FRESH.add(o.name)
    TOUCHED.add(o.name)
    print("R5 edging twins removed", len(kill), "tops", tops, "walls", walls, "unmatched", guessed,
          "faces left", len(o.data.polygons))
    assert len(kill) == 534 and guessed == 0, (len(kill), guessed)


def _bed_planes(bed):
    """Up-facing pebble-bed faces: (height, xy bounds) in world space."""
    out = []
    mw = bed.matrix_world
    for p in bed.data.polygons:
        if p.normal.z < 0.999:
            continue
        pts = [mw @ bed.data.vertices[v].co for v in p.vertices]
        out.append((pts[0].z, min(c.x for c in pts), max(c.x for c in pts), min(c.y for c in pts), max(c.y for c in pts)))
    return out


def aqueduct_bed(sources):
    bed = _bed_planes(obj_named(sources, "Terrain_Ground__pebble_bed"))
    dropped = lifted = 0
    for name in ("Architecture_Aqueduct__marble", "Architecture_Aqueduct__marble_smooth"):
        o = obj_named(sources, name)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill, lift = [], set()
        for f in bm.faces:
            if abs(f.normal.z) < 0.999:
                continue
            zs = [v.co.z for v in f.verts]
            if max(zs) - min(zs) > 1e-3:
                continue
            x0, x1 = min(v.co.x for v in f.verts), max(v.co.x for v in f.verts)
            y0, y1 = min(v.co.y for v in f.verts), max(v.co.y for v in f.verts)
            hit = any(abs(z - zs[0]) < 0.01 and min(x1, bx1) - max(x0, bx0) > 0.05 and min(y1, by1) - max(y0, by0) > 0.05
                      for z, bx0, bx1, by0, by1 in bed)
            if not hit:
                continue
            if f.normal.z < 0:
                kill.append(f)
            else:
                lift.update(f.verts)
        for v in lift:
            v.co.z += 0.05
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
        dropped += len(kill)
        lifted += len(lift)
        if kill or lift:
            bm.to_mesh(o.data)
            o.data.update()
            FRESH.add(o.name)
            TOUCHED.add(o.name)
        bm.free()
    print("R5 aqueduct on pebble bed: bottoms dropped", dropped, "floor verts lifted", lifted)
    assert dropped >= 2 and lifted >= 3, (dropped, lifted)


def channel_water(sources):
    o = obj_named(sources, "Anim__Water_SkyFalls_Channel__water_stream")
    for v in o.data.vertices:
        v.co.z -= 0.04
    o.data.update()
    FRESH.add(o.name)
    TOUCHED.add(o.name)
    print("R5 sky-falls channel water lowered", len(o.data.vertices), "verts")


def qa_fixes(sources):
    move_lamps(sources)
    sources = split_castle_flags(sources)
    fix_foam(sources)
    dedupe_edging(sources)
    cap_edging(sources)
    bridge_aprons(sources)
    sharpen_cliffs(sources)
    aqueduct_bed(sources)
    channel_water(sources)
    return sources


def geom_hash(obj):
    """Content hash of a merged mesh (positions, corners, normals, UVs) so a later run re-exports exactly the meshes
    whose geometry changed."""
    import hashlib
    import numpy as np
    me = obj.data
    h = hashlib.sha1()
    co = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    h.update(np.round(co, 4).tobytes())
    idx = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", idx)
    h.update(idx.tobytes())
    try:
        nrm = np.empty(len(me.loops) * 3, dtype=np.float32)
        me.corner_normals.foreach_get("vector", nrm)
        h.update(np.round(nrm, 3).tobytes())
    except (AttributeError, RuntimeError):
        pass
    if me.uv_layers.active:
        uv = np.empty(len(me.loops) * 2, dtype=np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        h.update(np.round(uv, 4).tobytes())
    return h.hexdigest()[:16]


def main():
    SLOTS.update(build_palette())
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    sources = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
    sources = declutter(sources)
    sources = qa_fixes(sources)
    groups = defaultdict(list)
    meta = {}
    for o in sources:
        key, collide, anim, region = classify(o.name)
        anim = anim or ANIM_BY_OBJECT.get(o.name.rsplit("__", 1)[0]) or None
        if o.name.startswith("Anim__") and anim is None:
            anim = {"Chime": "sway", "Pennan": "sway", "Water_": None}.get(key[:6])
        groups[key].append(duplicate(o, "tmp_" + o.name))
        meta[key] = {"collide": collide, "anim": anim, "region": region, "material": "W1_" + material_of(o.name),
                     "sources": meta.get(key, {}).get("sources", []) + [o.name]}
    # Anim chunks carry an anim property on the chunk itself in the import file.
    for o in sources:
        if o.get("anim"):
            key = classify(o.name)[0]
            meta[key]["anim"] = meta[key]["anim"] or str(o["anim"])
            if o.get("anim_note"):
                meta[key]["note"] = str(o["anim_note"])
    finals = []
    for key, objs in sorted(groups.items()):
        if key.startswith("Backdrop__"):
            joined = join(objs, "tmp_bd")
            pieces = split_loose(joined)
            info = []
            for p in pieces:
                lo, hi = centre_of(p)
                c = (lo + hi) / 2
                info.append((math.atan2(c.y, c.x), p, lo, hi))
            info.sort(key=lambda t: t[0])
            bins, cur = [], None
            for _, p, lo, hi in info:
                if cur:
                    nlo = Vector([min(cur["lo"][i], lo[i]) for i in range(3)])
                    nhi = Vector([max(cur["hi"][i], hi[i]) for i in range(3)])
                    if max(nhi - nlo) < BACKDROP_SPAN and cur["tris"] + tris(p) <= TRI_CAP:
                        cur["objs"].append(p); cur["lo"], cur["hi"] = nlo, nhi; cur["tris"] += tris(p)
                        continue
                cur = {"objs": [p], "lo": lo, "hi": hi, "tris": tris(p)}
                bins.append(cur)
            for index, b in enumerate(bins, 1):
                finals.append((join(b["objs"], f"W7_{key}_{index}"), key))
            continue
        total = sum(tris(o) for o in objs)
        if total <= TRI_CAP:
            finals.append((join(objs, "W7_" + key), key))
        else:
            for i, chunk in enumerate(bins_by_x(objs, TRI_CAP), 1):
                finals.append((join(chunk, f"W7_{key}_{i}"), key))
    manifest = []
    for obj, key in finals:
        lo, hi, c = recentre(obj)
        m = meta[key]
        size = hi - lo
        entry = {"name": obj.name, "group": key, "material": m["material"], "tris": tris(obj),
                 "collide": m["collide"], "anim": m["anim"], "region": m["region"],
                 "center": rb(c), "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
                 "top": round(hi.z + 4, 4), "hash": geom_hash(obj)}
        if m.get("note"):
            entry["note"] = m["note"]
        entry.update(EXTRA_META.get(key, {}))
        assert max(entry["size"]) < 2040, (obj.name, entry["size"])
        manifest.append(entry)
    previous_path = OUT / "world-v7-manifest.json"
    previous = {e["name"]: e for e in json.loads(previous_path.read_text())["parts"]} if previous_path.exists() else {}
    export(finals, OUT / "world-v7.fbx")
    current = {e["name"]: e for e in manifest}

    def same(a, b):
        return a["tris"] == b["tris"] and all(abs(x - y) < 1e-3 for x, y in zip(a["center"] + a["size"], b["center"] + b["size"]))
    # QA 2026-11-13: normal-only fixes keep tris and bounds, so meshes built from a chunk touched by this round's
    # fixes (FRESH) count as changed. Once the previous manifest carries hashes, the hash decides.
    touched_keys = {key for key, m in meta.items() if FRESH.intersection(m["sources"])}
    touched = {obj.name for obj, key in finals if key in touched_keys}

    def differs(n):
        if previous[n].get("hash") and current[n].get("hash"):
            return previous[n]["hash"] != current[n]["hash"]
        return not same(current[n], previous[n]) or n in touched
    changed = sorted(n for n in current if n in previous and differs(n))
    added = sorted(n for n in current if n not in previous)
    dropped = sorted(n for n in previous if n not in current)
    if previous and (changed or added or dropped):
        export([(o, k) for o, k in finals if o.name in changed or o.name in added], OUT / "world-v7-declutter.fbx")
        (OUT / "world-v7-pending.json").write_text(json.dumps({
            "note": "Meshes changed by the last build_world_v7_chunks.py run. Upload world-v7-declutter.fbx, read back each "
                    "MeshPart's MeshId and MeshSize into world-v7-studio-import.json, then delete this file and rerun "
                    "scripts/build_world_v7_assets.py.",
            "changed": changed, "added": added, "dropped": dropped,
            "previous": {n: previous[n] for n in changed + dropped}}, indent=1))
        print("WORLDV7 changed", changed, "added", added, "dropped", dropped)
    previous_path.write_text(json.dumps({
        "note": "Generated by scripts/build_world_v7_chunks.py. center/size in Roblox studs (Blender (x,y,z) = Roblox (x, z+4, -y)).",
        "parts": manifest, "count": len(manifest), "triangles": sum(e["tris"] for e in manifest)}, indent=1))
    walk_data(finals, manifest)
    print("WORLDV7", len(manifest), sum(e["tris"] for e in manifest))
    preview = __import__("os").environ.get("WORLD_V7_PREVIEW_BLEND")
    if preview:
        # Review renders only: a copy holding just the merged meshes (the import .blend itself is never saved).
        keep = {obj.name for obj, _ in finals}
        for o in list(bpy.data.objects):
            if o.type == "MESH" and o.name not in keep:
                bpy.data.objects.remove(o, do_unlink=True)
        bpy.ops.wm.save_as_mainfile(filepath=preview, copy=True)


def export(finals, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj, _ in finals:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE")


SURFACE = {"grass": "G", "meadow": "G", "ground": "g", "dirt_path": "P", "pebble_bed": "P", "sand_pebble": "P",
           "stone_tile": "P", "cliff_rock": "R", "boulder_rock": "R", "bark": "T"}


def surface_code(name):
    group, mat = name[len("W7_"):].split("__", 1)
    if mat.rsplit("_", 1)[-1].isdigit():
        mat = mat.rsplit("_", 1)[0]
    if group == "Water" or mat.startswith("water") or mat == "foam":
        return "W"
    if group in ("Ground", "Rocks", "Trunks"):
        return SURFACE.get(mat, "M")
    return "M"


def surface_map(finals):
    """Top surface per 1-stud cell (G grass, g soft ground, P path, W water, R rock, T trunk, M structure, . none)
    with its height, for the ground dressing scatter (scripts/build_world_v7_dressing.py)."""
    skip = ("Backdrop", "Underside", "Vegetation", "IsletsA", "IsletsB", "DriftRocksA", "DriftRocksB", "Lantern",
            "CradleMobile", "LampOrbs", "Bubbles", "Crystals", "ArrivalGlow", "NestHalo", "Chime", "Pennant")
    trees = []
    for o, key in finals:
        group = key.split("__")[0]
        if group.startswith(skip) or key == "Water__cloud":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        trees.append((surface_code(o.name), BVHTree.FromBMesh(bm)))
        bm.free()
    grid = {"x0": -114, "z0": -112, "step": 1, "nx": 236, "nz": 206, "rows": [], "h": []}
    for j in range(grid["nz"]):
        row, hs = [], []
        for i in range(grid["nx"]):
            x, z = grid["x0"] + i, grid["z0"] + j
            best, code = None, "."
            for c, tree in trees:
                hit = tree.ray_cast(Vector((x, -z, 200)), Vector((0, 0, -1)))
                if hit[0] is not None and (best is None or hit[0].z > best):
                    best, code = hit[0].z, c
            row.append(code)
            hs.append(-999 if best is None else round(best + 4, 2))
        grid["rows"].append("".join(row))
        grid["h"].append(hs)
    return grid


ISLAND_CENTRE = Vector((4.0, 2.0))  # Blender xy of the island middle (Roblox x 4, z -2)


def falls_planes():
    """One flat sheet per waterfall for the scrolling beams (QA 2026-11-13: the old single camera-facing beam per
    falls billboarded and the lower tumble sheet had none). Roblox top / bottom centres, widths and the facing
    normal (horizontal, toward the island so it faces the players), offset 0.2 studs in front of the mesh."""
    out = []
    for name in ("Anim__Water_TumbleFalls_Upper__waterfall_tumble", "Anim__Water_TumbleFalls_Lower__waterfall_tumble",
                 "Anim__Water_SkyFalls__waterfall_sky"):
        o = bpy.data.objects[name]
        pts = [o.matrix_world @ v.co for v in o.data.vertices]
        zmax, zmin = max(p.z for p in pts), min(p.z for p in pts)
        span = zmax - zmin
        # Ignore the lip that curls over the ledge: fit the hanging part only.
        hang = [p for p in pts if p.z < zmax - min(span * 0.08, 1.5)] or pts
        c = sum(hang, Vector()) / len(hang)
        cxx = sum((p.x - c.x) ** 2 for p in hang)
        cyy = sum((p.y - c.y) ** 2 for p in hang)
        cxy = sum((p.x - c.x) * (p.y - c.y) for p in hang)
        ang = 0.5 * math.atan2(2 * cxy, cxx - cyy)
        along = Vector((math.cos(ang), math.sin(ang), 0))  # width direction of the sheet
        normal = Vector((-along.y, along.x, 0))
        if normal.to_2d().dot(ISLAND_CENTRE - c.to_2d()) < 0:
            normal = -normal
        top = [p for p in hang if p.z > max(q.z for q in hang) - min(span * 0.1, 2.0)]
        bottom = [p for p in pts if p.z < zmin + min(span * 0.1, 2.0)]

        def centre(ps):
            m = sum(ps, Vector()) / len(ps)
            return m + normal * (max((p - m).dot(normal) for p in ps) + 0.2)

        def width(ps):
            ws = [(p - c).dot(along) for p in ps]
            return round(max(ws) - min(ws), 3)
        t, b = centre(top), centre(bottom)
        # The sheets bulge: push the (possibly tilted) top-bottom plane forward until no vertex pokes through it.
        push = 0.0
        for p in pts:
            f = min(max((t.z - p.z) / max(t.z - b.z, 1e-3), 0.0), 1.0)
            push = max(push, (p - t.lerp(b, f)).dot(normal) + 0.2)
        t, b = t + normal * push, b + normal * push
        out.append({"name": name.split("__")[1], "top": rb(Vector((t.x, t.y, zmax))),
                    "bottom": rb(Vector((b.x, b.y, min(p.z for p in bottom)))), "width0": width(top), "width1": width(bottom),
                    "normal": [round(normal.x, 4), 0.0, round(-normal.y, 4)]})
    return out


def foam_boxes():
    """Where the falls land and break: bounds of each foam chunk, for the splash and mist emitters."""
    out = []
    for name in ("Anim__Water_TumbleFalls_Foam_Bottom__foam", "Anim__Water_TumbleFalls_Foam_Ledge__foam",
                 "Anim__Water_SkyFalls_Foam__foam"):
        o = bpy.data.objects[name]
        lo, hi = centre_of(o)
        c, s = (lo + hi) / 2, hi - lo
        out.append({"name": name.split("__")[1], "center": rb(c), "size": [round(s.x, 3), round(s.z, 3), round(s.y, 3)]})
    return out


def walk_data(finals, manifest):
    data = {}
    # Perimeter wall: a ring mesh. Slice it into ~6-stud boxes along its loop.
    wall = bpy.data.objects["PerimeterWall"]
    vs = [wall.matrix_world @ v.co for v in wall.data.vertices]
    cx = sum(v.x for v in vs) / len(vs)
    cy = sum(v.y for v in vs) / len(vs)
    buckets = defaultdict(list)
    for v in vs:
        a = math.atan2(v.y - cy, v.x - cx)
        buckets[int((a + math.pi) / (2 * math.pi) * 180) % 180].append(v)
    ring = []
    for i in range(180):
        b = buckets.get(i)
        if not b:
            continue
        mx = sum(v.x for v in b) / len(b)
        my = sum(v.y for v in b) / len(b)
        ring.append((mx, my, min(v.z for v in b), max(v.z for v in b)))
    boxes = []
    for i, a in enumerate(ring):
        b = ring[(i + 1) % len(ring)]
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        if length < 0.05:
            continue
        lo, hi = min(a[2], b[2]), max(a[3], b[3])
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        # Roblox Ry(yaw) maps local X to (cos yaw, 0, -sin yaw); the run along Roblox (dx, dz) = (bx - ax, -(by - ay))
        # needs sin yaw = by - ay. QA 2026-11-13: the old -(by - ay) mirrored every box across the ring tangent, so
        # the wall was a row of crossed slats with walk-through gaps.
        yaw = math.atan2(b[1] - a[1], b[0] - a[0])
        boxes.append({"center": [round(mid[0], 3), round((lo + hi) / 2 + 4, 3), round(-mid[1], 3)],
                      "size": [round(length + 1.0, 3), round(hi - lo, 3), 1.5], "yaw": round(yaw, 5)})
    data["perimeter"] = boxes
    for name in ("CaveBlocker", "FallCatch"):
        o = bpy.data.objects[name]
        lo, hi = centre_of(o)
        c, s = (lo + hi) / 2, hi - lo
        data[name] = {"center": rb(c), "size": [round(s.x, 3), round(s.z, 3), round(s.y, 3)]}
    # Wet regions: oriented boxes along each flat water mesh, sliced by its V (flow) coordinate.
    wet = []
    for name in ("Anim__Water_Stream__water_stream", "Anim__Water_SkyFalls_Channel__water_stream",
                 "Anim__Water_Pool_Lily__water_pool", "Anim__Water_Pool_Falls__water_pool"):
        o = bpy.data.objects[name]
        bm = bmesh.new()
        bm.from_mesh(o.data)
        pts = [(o.matrix_world @ v.co) for v in bm.verts]
        if "Pool" in name or "Channel" in name:
            xs = [p.x for p in pts]
            ys = [p.y for p in pts]
            wet.append({"name": name.split("__")[1], "center": [round((min(xs) + max(xs)) / 2, 3), 3.2, round(-(min(ys) + max(ys)) / 2, 3)],
                        "size": [round(max(xs) - min(xs), 3), 0.2, round(max(ys) - min(ys), 3)], "yaw": 0})
            bm.free()
            continue
        uv = bm.loops.layers.uv.active
        samples = []
        for f in bm.faces:
            for loop in f.loops:
                samples.append((loop[uv].uv.y, o.matrix_world @ loop.vert.co))
        bm.free()
        samples.sort(key=lambda s: s[0])
        vmin, vmax = samples[0][0], samples[-1][0]
        # Slice into ~14 segments along the flow.
        n = 14
        cents = []
        for i in range(n):
            a = vmin + (vmax - vmin) * i / n
            b = vmin + (vmax - vmin) * (i + 1) / n
            seg = [p for v, p in samples if a <= v <= b]
            if seg:
                cents.append(seg)
        for seg in cents:
            sx = sum(p.x for p in seg) / len(seg)
            sy = sum(p.y for p in seg) / len(seg)
            # principal direction of the slice
            cxx = sum((p.x - sx) ** 2 for p in seg)
            cyy = sum((p.y - sy) ** 2 for p in seg)
            cxy = sum((p.x - sx) * (p.y - sy) for p in seg)
            ang = 0.5 * math.atan2(2 * cxy, cxx - cyy)
            ux, uy = math.cos(ang), math.sin(ang)
            along = [((p.x - sx) * ux + (p.y - sy) * uy) for p in seg]
            across = [(-(p.x - sx) * uy + (p.y - sy) * ux) for p in seg]
            # Roblox yaw: rotation about +Y; local X axis = (ux, 0, -uy)
            yaw = math.atan2(uy, ux)
            wet.append({"name": "Water_Stream", "center": [round(sx + ux * (max(along) + min(along)) / 2 - uy * (max(across) + min(across)) / 2, 3), 3.2,
                                                    round(-(sy + uy * (max(along) + min(along)) / 2 + ux * (max(across) + min(across)) / 2), 3)],
                        "size": [round(max(along) - min(along), 3), 0.2, round(max(across) - min(across), 3)], "yaw": round(yaw, 5)})
    data["wet"] = wet
    data["falls"] = falls_planes()
    data["foam"] = foam_boxes()
    # Ground heights: top-down rays against the collidable ground-ish meshes on a 2-stud grid.
    targets = [o for o, key in finals if key.split("__")[0] in ("Ground", "Rocks", "Rotunda", "Bridge", "Architecture", "Landmarks", "Stations", "Props", "Balustrades", "Trunks", "Aqueduct")]
    trees = []
    for o in targets:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        trees.append((o.name, BVHTree.FromBMesh(bm)))
        bm.free()
    grid = {"x0": -114, "z0": -136, "step": 2, "nx": 132, "nz": 115, "heights": [], "hits": []}
    for j in range(grid["nz"]):
        row, names = [], []
        for i in range(grid["nx"]):
            x = grid["x0"] + i * grid["step"]
            z = grid["z0"] + j * grid["step"]
            best, who = None, ""
            for name, tree in trees:
                hit = tree.ray_cast(Vector((x, -z, 200)), Vector((0, 0, -1)))
                if hit[0] is not None and (best is None or hit[0].z > best):
                    best, who = hit[0].z, name
            row.append(None if best is None else round(best + 4, 2))
            names.append(who.split("__")[0] if who else "")
        grid["heights"].append(row)
        grid["hits"].append(names)
    data["grid"] = grid
    # Bare ground height (ground meshes only) on a 4-stud grid, for pet waypoints and the on-ground test.
    ground_trees = [(n, t) for n, t in trees if n.startswith("W7_Ground__")]
    gg = {"x0": -114, "z0": -136, "step": 4, "nx": 66, "nz": 58, "heights": []}
    for j in range(gg["nz"]):
        row = []
        for i in range(gg["nx"]):
            x, z = gg["x0"] + i * gg["step"], gg["z0"] + j * gg["step"]
            best = None
            for _, tree in ground_trees:
                hit = tree.ray_cast(Vector((x, -z, 200)), Vector((0, 0, -1)))
                if hit[0] is not None and (best is None or hit[0].z > best):
                    best = hit[0].z
            row.append(None if best is None else round(best + 4, 2))
        gg["heights"].append(row)
    data["ground"] = gg
    data["surface"] = surface_map(finals)
    (OUT / "world-v7-walk.json").write_text(json.dumps(data))


main()
