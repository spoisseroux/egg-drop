"""List the faces the batch 2026-11-13 declutter removes from the World 1 v7 merge (W1).

Run in BACKGROUND Blender only, on the hand-editable source scene (never saved):
  blender.exe --factory-startup -b assets/art-source/environment/world1-mockup-v7.blend --python scripts/build_world_v7_declutter.py

The import chunks (world1-mockup-v7-import.blend) are already joined per category and material, so the props can
no longer be picked by name there. This script records the world-space vertices of every removed face here, and
scripts/build_world_v7_chunks.py deletes the import faces whose vertices all match (same geometry, same world
transform: the import chunks were written from this scene with mw @ co).

Removed (FEEL-ALIVE-DIRECTION-2026-11-13.md, section C2, all 12 approved by Spencer):
  egg statues Plaza_Ornament_09/10, urns Plaza_Ornament_11/12 and Stairs_Urn_18/19, Colonnade_Column_01 and the
  entablature span from column 01 to 02, broken columns Colonnade_Column_06/07, Colonnade_FallenDrum_08,
  empty pads Pad_Future_A/B.
Pet Park interior (Spencer 2026-11-13): Tree_11_round and the blossom shrubs Bush_08 / Bush_24 inside the playground kerb
  (src/shared/ParkLayout.lua, ellipse centre (36, 66), radii 16 x 11 studs).
And every 3D flower cluster (collection Flowers, Flowers_A/B): flat ground flower patches replace them
(src/shared/WorldDressing.lua).
QA 2026-11-13 (Q3): the hub benches BenchEast/BenchWest, the four toy-lawn toys, and the Pocket Deck kiosk's two
thumbsticks (a face subset of Station_PocketDeckKiosk_Kiosk, recorded as Kiosk_Thumbsticks).
QA v2 2026-11-13 (R5.3): the two thumbsticks of the small deck lying on the kiosk table (same object, recorded as
Kiosk_TableThumbsticks); the table deck keeps its shell, screen, d-pad and buttons.

Writes assets/world/world-v7-declutter.json: {objects: {name: {faces, verts: [[x, y, z], ...]}}} in Blender units.
"""
import json
import math
import os
from collections import defaultdict

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "world", "world-v7-declutter.json")
REMOVE = ["Plaza_Ornament_09", "Plaza_Ornament_10", "Plaza_Ornament_11", "Plaza_Ornament_12",
          "Stairs_Urn_18", "Stairs_Urn_19", "Colonnade_Column_01", "Colonnade_Column_06", "Colonnade_Column_07",
          "Colonnade_FallenDrum_08", "Pad_Future_A", "Pad_Future_B",
          # Pet Park interior (Spencer 2026-11-13): the tree by the sandbox (trunk at Roblox (30, 59.5), bark + canopy
          # in one object) and the two pink blossom shrubs inside the kerb (Bush_24 touched the ball mat).
          "Tree_11_round", "Bush_08", "Bush_24",
          # QA 2026-11-13 (Q3.9): the two hub benches and the toy-lawn toys beside the hub plaza (the picnic tables
          # stay). The toy lawn itself (Ground_ToyLawn) and its gameplay anchors (GardenLayout) are unchanged.
          "Station_BenchEast_Seat_Slats", "Station_BenchEast_Supports",
          "Station_BenchWest_Seat_Slats", "Station_BenchWest_Supports",
          "Station_ToyLawn_Ball", "Station_ToyLawn_Blocks", "Station_ToyLawn_StackingRings", "Station_ToyLawn_ToyChest"]
FLOWERS = sorted(o.name for o in bpy.data.collections["Flowers"].objects if o.type == "MESH")
# QA 2026-11-13 (Q3.10): the two thumbsticks on top of the Pocket Deck kiosk's big handheld sign (deck_shell stems
# + deck_cream caps). Roblox (x, y, z) centres; every face whose vertices all sit inside one box goes.
KIOSK_STICKS = [(-47.56, 9.96, -9.16), (-45.16, 9.96, -10.32)]
KIOSK_HALF = (0.6, 0.55, 0.6)
# QA v2 (R5.3): the small deck on the kiosk table (tilted on its wood stand, top at Roblox y ~7.3) still had its two
# thumbsticks: a deck_shell collar (10 + 2 faces) and a deck_cream cap (8 + 2 faces) each, 44 faces in all. The box is
# tight enough that the d-pad, screen bezel and A/B buttons beside them keep at least one vertex outside it.
TABLE_STICKS = [(-47.46, 7.24, -8.16), (-46.78, 7.24, -8.49)]
TABLE_HALF = (0.16, 0.15, 0.16)


def kiosk_faces(centres, half, low, high, label):
    obj = bpy.data.objects["Station_PocketDeckKiosk_Kiosk"]
    mw = obj.matrix_world
    keep = set()
    for p in obj.data.polygons:
        pts = [mw @ obj.data.vertices[v].co for v in p.vertices]
        rbx = [(c.x, c.z + 4, -c.y) for c in pts]
        for cx, cy, cz in centres:
            if all(abs(x - cx) <= half[0] and abs(y - cy) <= half[1] and abs(z - cz) <= half[2] for x, y, z in rbx):
                keep.add(p.index)
    mats = sorted({obj.data.materials[obj.data.polygons[i].material_index].name for i in keep})
    assert low <= len(keep) <= high and mats == ["W1_deck_cream", "W1_deck_shell"], (label, len(keep), mats)
    print("DECLUTTER", label, "faces", len(keep))
    return world_faces(obj, keep)


def kiosk_sticks():
    return kiosk_faces(KIOSK_STICKS, KIOSK_HALF, 40, 48, "kiosk thumbsticks")


def table_sticks():
    return kiosk_faces(TABLE_STICKS, TABLE_HALF, 40, 48, "kiosk table deck thumbsticks")


def world_faces(obj, keep=None):
    me = obj.data
    mw = obj.matrix_world
    out = []
    for p in me.polygons:
        if keep is not None and p.index not in keep:
            continue
        out.append([list(mw @ me.vertices[v].co) for v in p.vertices])
    return out


def entablature_span():
    """Faces of the entablature boxes over the column 01 to 02 gap (each box is its own loose part)."""
    ent = bpy.data.objects["Colonnade_Entablature"]
    c1 = bpy.data.objects["Colonnade_Column_01"].matrix_world.translation
    cols = [bpy.data.objects["Colonnade_Column_%02d" % k].matrix_world.translation for k in range(1, 6)]
    mids = [((a + b) / 2).to_2d() for a, b in zip(cols[:-1], cols[1:])]
    bm = bmesh.new()
    bm.from_mesh(ent.data)
    bm.faces.ensure_lookup_table()
    seen, keep = set(), set()
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
        verts = {v.index: ent.matrix_world @ v.co for g in island for v in g.verts}
        centre = sum(verts.values(), Vector()) / len(verts)
        nearest = min(range(len(mids)), key=lambda k: (centre.to_2d() - mids[k]).length)
        if nearest == 0:
            keep.update(g.index for g in island)
    bm.free()
    assert keep, "no entablature span found next to column 01"
    print("DECLUTTER entablature span faces", len(keep), "column 01 at", tuple(round(v, 2) for v in c1))
    return world_faces(ent, keep)


def main():
    objects = {}
    for name in REMOVE + FLOWERS:
        obj = bpy.data.objects[name]
        faces = world_faces(obj)
        objects[name] = {"faces": len(faces), "verts": [[round(c, 5) for c in v] for f in faces for v in f]}
    span = entablature_span()
    objects["Colonnade_Entablature_Span01"] = {"faces": len(span), "verts": [[round(c, 5) for c in v] for f in span for v in f]}
    sticks = kiosk_sticks()
    objects["Kiosk_Thumbsticks"] = {"faces": len(sticks), "verts": [[round(c, 5) for c in v] for f in sticks for v in f]}
    table = table_sticks()
    objects["Kiosk_TableThumbsticks"] = {"faces": len(table), "verts": [[round(c, 5) for c in v] for f in table for v in f]}
    with open(OUT, "w") as fh:
        json.dump({"note": "Generated by scripts/build_world_v7_declutter.py. Blender world coordinates.",
                   "removed": REMOVE + ["Colonnade_Entablature_Span01", "Kiosk_Thumbsticks", "Kiosk_TableThumbsticks"], "flowers": FLOWERS,
                   "objects": objects}, fh)
    print("DECLUTTER", len(objects), "objects", sum(o["faces"] for o in objects.values()), "faces")


main()
