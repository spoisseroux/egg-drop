"""Review renders of the cliff path, the Play Den and the terrace top (grey blockout) from the --beta preview blend.

  WORLD_V7_PREVIEW_BLEND=<tmp>/cliff-den-preview.blend blender -b <import.blend> --python scripts/build_world_v7_chunks.py -- --beta
  blender -b <tmp>/cliff-den-preview.blend --python scripts/render_cliff_den.py -- OUT_DIR
Cameras in Roblox studs (Blender = (x, -z, y - 4)). A grey slab stands in for the terrace floor (27 to 29).
"""
import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."


def bl(p):
    return Vector((p[0], -p[2], p[1] - 4))


def tier_slab():
    c, d = (-60.0, -96.0), (-64, 46)
    m = math.hypot(*d)
    dx, dz = d[0] / m, d[1] / m
    bpy.ops.mesh.primitive_cube_add(size=1)
    slab = bpy.context.object
    slab.scale = (76, 44, 2)
    slab.location = bl((c[0], 28, c[1]))
    slab.rotation_euler = (0, 0, math.atan2(-dz, dx))
    mat = bpy.data.materials.new("Slab")
    mat.use_nodes = True
    next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (.5, .5, .52, 1)
    slab.data.materials.append(mat)


def main():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 1280, 800
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    # highlight the beta's new pieces in a warm grey so the blockout reads
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name.startswith("W7_CD_") and ("CliffPath" in o.name or "PlayDen" in o.name):
            mat = bpy.data.materials.new("Blockout_" + o.name)
            mat.use_nodes = True
            bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = (.62, .55, .45, 1) if "dirt" in o.name else (.45, .45, .47, 1)
            o.data.materials.clear()
            o.data.materials.append(mat)
    tier_slab()
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.5
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(45), 0, math.radians(200))
    scene.collection.objects.link(so)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.55, .75, 1.0, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .6
    scene.world = world
    # interior light for the den
    lamp = bpy.data.lights.new("Den", "POINT")
    lamp.energy = 3000
    lo = bpy.data.objects.new("DenLight", lamp)
    lo.location = bl((-8, 10, -110))
    scene.collection.objects.link(lo)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 24
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = [
        ("01-from-plaza", (-22, 12, -12), (-48, 14, -72)),
        ("02-path-foot", (-8, 8, -76), (-40, 12, -76)),
        ("03-shelf-2", (-44, 22, -56), (-72, 22, -54)),
        ("04-turn", (-62, 26, -60), (-77, 23, -50)),
        ("05-den-mouth-30", (-7, 9, -70), (-7, 7, -102)),
        ("06-den-inside", (-7, 7, -99.5), (-7, 8, -116)),
        ("07-terrace-top", (-30, 55, -55), (-62, 28, -92)),
        ("08-den-from-back", (-7, 9, -116), (-7, 6, -98)),
    ]
    for label, eye, look in views:
        e = bl(eye)
        cam.location = e
        cam.rotation_euler = (bl(look) - e).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{OUT}/{label}.png"
        bpy.ops.render.render(write_still=True)
    print("CLIFFDEN renders in", OUT)


main()
