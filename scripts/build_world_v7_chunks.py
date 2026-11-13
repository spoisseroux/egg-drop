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


def main():
    SLOTS.update(build_palette())
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    sources = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
    sources = declutter(sources)
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
                 "top": round(hi.z + 4, 4)}
        if m.get("note"):
            entry["note"] = m["note"]
        assert max(entry["size"]) < 2040, (obj.name, entry["size"])
        manifest.append(entry)
    previous_path = OUT / "world-v7-manifest.json"
    previous = {e["name"]: e for e in json.loads(previous_path.read_text())["parts"]} if previous_path.exists() else {}
    export(finals, OUT / "world-v7.fbx")
    current = {e["name"]: e for e in manifest}

    def same(a, b):
        return a["tris"] == b["tris"] and all(abs(x - y) < 1e-3 for x, y in zip(a["center"] + a["size"], b["center"] + b["size"]))
    changed = sorted(n for n in current if n in previous and not same(current[n], previous[n]))
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
        yaw = math.atan2(-(b[1] - a[1]), b[0] - a[0])  # Roblox: X along +x, Z = -y
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
