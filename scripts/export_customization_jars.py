"""Exports the approved Customization Egg jar art for upload (2026-11-16, slice 3).

  blender --background assets/art-source/jars/customization-jars.blend --python scripts/export_customization_jars.py

Writes, next to the manifest:
  customization-jars.fbx         every Jar_<item>__<part> mesh, upload as one Model
  customization-jars-parts.json  per part: item, part, colour (mean of the "Col" corner
                                 attribute), alpha (material Alpha) and Blender bbox centre

Roblox MeshParts draw one colour per part, so the vertex-colour gradient becomes its mean.
Every part is unparented before export (keeping its local transform), so each jar is built at the
origin; placement in the game comes from the imported Model (customization-jars-meshids.json).
The 2026-11-16 upload ran the same steps inside the live Blender, with the jar objects appended
into a temporary scene so the open file was untouched. Do not save the .blend after running this.
"""
import json
import os

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "art-source", "jars")


def mean_colour(obj):
    mesh = obj.data
    attr = mesh.color_attributes.get("Col")
    if not attr or not len(attr.data):
        return None
    total = [0.0, 0.0, 0.0]
    for entry in attr.data:
        c = entry.color
        for i in range(3):
            total[i] += c[i]
    n = len(attr.data)
    lin = [t / n for t in total]

    def srgb(c):
        return 12.92 * c if c <= .0031308 else 1.055 * c ** (1 / 2.4) - .055

    return "#%02X%02X%02X" % tuple(max(0, min(255, round(srgb(c) * 255))) for c in lin)


def material_alpha(obj):
    for slot in obj.material_slots:
        mat = slot.material
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    return round(float(node.inputs["Alpha"].default_value), 3)
    return 1.0


def main():
    parts = []
    bpy.ops.object.select_all(action="DESELECT")
    for obj in sorted(bpy.data.objects, key=lambda o: o.name):
        if obj.type != "MESH" or not obj.name.startswith("Jar_") or "__" not in obj.name:
            continue
        item, part = obj.name[4:].split("__", 1)
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        centre = sum(corners, Vector()) / 8
        parts.append({"name": obj.name, "item": item, "part": part, "colour": mean_colour(obj),
                      "alpha": material_alpha(obj), "centre": [round(v, 5) for v in centre]})
        obj.parent = None  # keep the local transform: every jar sits at the origin
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "customization-jars.fbx"), use_selection=True,
                             axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=True,
                             use_mesh_modifiers=True, object_types={"MESH"}, add_leaf_bones=False,
                             bake_anim=False, path_mode="AUTO", mesh_smooth_type="FACE")
    with open(os.path.join(OUT, "customization-jars-parts.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"schema": 1, "source": "scripts/export_customization_jars.py", "parts": parts}, handle, indent=1)
    print("exported", len(parts), "parts")


main()
