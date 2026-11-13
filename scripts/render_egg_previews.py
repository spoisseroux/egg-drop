"""Render transparent preview frames of every egg type and the Star token (EEVEE).

Run (background Blender; opens the source scene read-only and never saves it):
  blender -b assets/art-source/eggs/eggs.blend --python scripts/render_egg_previews.py

Writes artifacts/eggs-2026-11-13/raw/<type>-{closed,peek,open}.png and star-{front,turn}.png.
scripts/compose_egg_previews.py then adds the 2D layer (well, bloom, sparkles) the game will draw.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import egg_types as E  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
RAW = REPO / "artifacts" / "eggs-2026-11-13" / "raw"
RAW.mkdir(parents=True, exist_ok=True)
TEX = REPO / "assets" / "eggs" / "textures"

scene = bpy.context.scene
D = bpy.data.objects
top, bottom, core, star = D["Egg__TopShell"], D["Egg__BottomShell"], D["Egg__Core"], D["StarToken"]

for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x = scene.render.resolution_y = 720
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 48
except AttributeError:
    pass

world = bpy.data.worlds.new("PreviewWorld")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.55, 0.62, 0.66, 1)
bg.inputs["Strength"].default_value = 0.40
scene.world = world


def light(name, loc, energy, size, color=(1, 1, 1)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.color = energy, size, color
    ob = bpy.data.objects.new(name, data)
    scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0.6)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


light("Key", (-2.6, -3.4, 3.6), 230, 2.5, (1.0, 0.97, 0.92))
light("Fill", (3.2, -2.4, 1.2), 90, 3.0, (0.85, 0.92, 1.0))
light("Rim", (1.8, 3.2, 2.6), 210, 2.0)
light("Under", (0.0, -1.5, -1.2), 40, 3.0)

cam_data = bpy.data.cameras.new("PreviewCam")
cam_data.lens = 85
cam = bpy.data.objects.new("PreviewCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def aim(loc, target):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def hex_lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


shell_mat = top.data.materials[0]
tex_node = shell_mat.node_tree.nodes["ColorMap"]
core_bsdf = next(n for n in core.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def render(name):
    scene.render.filepath = str(RAW / name)
    bpy.ops.render.render(write_still=True)


def pose(spin_deg, lift=0.0, tilt_deg=0.0, slide=0.0):
    for o in (top, bottom, core):
        o.rotation_euler = (0, 0, math.radians(spin_deg))
        o.location = (0, 0, 0)
    top.location = (slide, 0, lift)
    top.rotation_euler = (0, math.radians(tilt_deg), math.radians(spin_deg))


only = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
star.hide_render = True
aim((0, -6.4, 1.75), (0, 0, 0.70))
for tid in E.ORDER:
    if only and tid not in only:
        continue
    t = E.TYPES[tid]
    tex_node.image = bpy.data.images.load(str(TEX / f"egg-{tid}-color.png"))
    glow = hex_lin(t["core"])
    core_bsdf.inputs["Base Color"].default_value = glow
    core_bsdf.inputs["Emission Color"].default_value = glow
    core_bsdf.inputs["Emission Strength"].default_value = 5.0
    pose(-28)
    render(f"{tid}-closed.png")
    pose(-28, lift=0.055)
    render(f"{tid}-peek.png")
    core_bsdf.inputs["Emission Strength"].default_value = 1.1
    pose(-28, lift=0.50, tilt_deg=16, slide=0.10)
    render(f"{tid}-open.png")

if not only or "star" in only:
    for o in (top, bottom, core):
        o.hide_render = True
    star.hide_render = False
    star.location = (0, 0, 0)
    aim((0, -6.4, 0.25), (0, 0, 0))
    star.rotation_euler = (math.radians(-6), 0, 0)
    render("star-front.png")
    star.rotation_euler = (math.radians(-6), 0, math.radians(-38))
    render("star-turn.png")
print("RENDERED ->", RAW)
