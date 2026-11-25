"""Review renders for the world finish art (WORLD-FINISH-LOOK.md, artifacts/qa-2026-11-26-beta21), in BACKGROUND Blender.

The scene is the beta island's preview blend (the --beta sculpt with the live materials):

  WORLD_V7_PREVIEW_BLEND=<tmp>/cliff-den-preview.blend blender -b <import.blend> --python scripts/build_world_v7_chunks.py -- --beta
  (then `git checkout -- assets/world/world-v7-beta.fbx`: the FBX bytes carry a timestamp; the manifest is unchanged)

scripts/build_world_finish_art.py imports this module to light the scene and render Fable's named camera spots.
Coordinates are Roblox studs; Blender (x, y, z) = Roblox (x, -z, y - 4).
"""
from __future__ import annotations

import math

import bpy
from mathutils import Vector


def bl(p):
    return Vector((p[0], -p[2], p[1] - 4))


# The tier frame (Tier.lua): T(s, t) in plan.
_D = (-64 / math.hypot(-64, 46), 46 / math.hypot(-64, 46))
_N = (_D[1], -_D[0])


def T(s, t, y=29.0):
    return (-60 + _D[0] * s + _N[0] * t, y, -96 + _D[1] * s + _N[1] * t)


# Fable's camera spots (eye, look-at), Roblox studs. Noon unless the label says night.
CAMERAS = {
    "CAM-HUB": ((-18.0, 11.5, -8.0), (-52.0, 20.0, -80.0)),
    "CAM-LAWN01": ((-4.0, 10.0, -58.0), (-40.0, 16.0, -82.0)),
    "CAM-MOUTH30": ((-7.0, 9.5, -70.5), (-7.0, 8.0, -100.5)),
    "CAM-DEN-IN": ((-7.0, 9.6, -98.6), (-7.0, 7.4, -116.0)),
    # two extra looks at the mouth surround from the lawn, 45 degrees either side
    "CAM-MOUTH-WEST": ((-27.0, 8.5, -84.0), (-7.0, 9.0, -100.0)),
    "CAM-MOUTH-EAST": ((12.0, 8.5, -84.0), (-7.0, 9.0, -100.0)),
    "CAM-DEN-BACK": ((-7.0, 9.4, -117.6), (-7.0, 7.0, -98.0)),
    "CAM-FOOT": ((-13.0, 9.5, -93.0), (-29.0, 9.5, -79.0)),
    "CAM-SHELF2": ((-49.0, 23.5, -64.0), (-62.0, 20.0, -55.5)),
    "CAM-TURN": ((-76.5, 28.5, -48.5), (-58.0, 18.0, -62.0)),
    "CAM-ARRIVE": ((-72.8, 34.5, -56.8), (-60.0, 30.0, -90.0)),
    "CAM-BENCH": (T(0, -7, 33.6), T(0, 14, 29.0)),
    "CAM-LOOKOUT": (T(-33, 15, 34.0), T(-20, 40, 12.0)),
}


def setup(night=False, resolution=(1280, 720)):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    for o in [o for o in bpy.data.objects if o.type == "LIGHT" and o.name.startswith("WF_")]:
        bpy.data.objects.remove(o)
    for o in bpy.data.objects:
        if o.type == "LIGHT" and o.name in ("Sun", "SkyFill"):
            o.hide_render = True
    sun = bpy.data.lights.new("WF_Sun", "SUN")
    sun.energy = .35 if night else 3.2
    sun.color = (.6, .7, 1.0) if night else (1.0, .96, .88)
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("WF_Sun", sun)
    # Aero noon (ClockTime 10.5): high sun from the south-east, a little behind the plaza camera.
    so.rotation_euler = (math.radians(38), 0, math.radians(150))
    scene.collection.objects.link(so)
    world = bpy.data.worlds.new("WF_Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (.03, .04, .08, 1) if night else (.56, .72, .92, 1)
    bg.inputs[1].default_value = .35 if night else .9
    scene.world = world
    cam_data = bpy.data.cameras.get("WF_Cam") or bpy.data.cameras.new("WF_Cam")
    cam_data.lens = 20
    cam_data.clip_start = .1
    cam_data.clip_end = 3000
    cam = bpy.data.objects.get("WF_Cam") or bpy.data.objects.new("WF_Cam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def render(label, out_dir, night=False, lens=20, eye=None, look=None, resolution=(1280, 720)):
    cam = setup(night=night, resolution=resolution)
    e, l = (eye, look) if eye else CAMERAS[label]
    cam.data.lens = lens
    cam.location = bl(e)
    cam.rotation_euler = (bl(l) - bl(e)).to_track_quat("-Z", "Y").to_euler()
    path = f"{out_dir}/{label}{'-night' if night else ''}.png"
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path
