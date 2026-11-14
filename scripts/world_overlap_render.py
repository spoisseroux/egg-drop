"""Matched before/after actual procedural geometry renders; never saves the scene."""
import importlib.util
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "artifacts/world-overlaps-2026-11-14/renders"
OUT.mkdir(parents=True, exist_ok=True)
src = (HERE / "build_world_v7_chunks.py").read_text(encoding="utf-8")
ns = {"__file__": str(HERE / "build_world_v7_chunks.py"), "__name__": "render_chunks"}
exec(compile(src.rsplit("\nmain()", 1)[0], ns["__file__"], "exec"), ns)
sources = [o for o in bpy.data.objects if o.type == "MESH" and any(c.name.startswith("Import_") for c in o.users_collection)]
production_out = ns["OUT"]
baseline = OUT.parent / "baseline"
ns["OUT"] = baseline
sources = ns["qa_fixes"](ns["declutter"](sources), remaining=False)
ns["OUT"] = production_out
for obj in bpy.data.objects:
    obj.hide_render = obj.type == "MESH" and obj not in sources
    if obj.type == "LIGHT":
        obj.hide_render = True
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1100, 760, 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("OverlapReviewWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.25, .33, .4, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .7
scene.view_settings.view_transform = "AgX"
sun = bpy.data.lights.new("OverlapReviewSun", "SUN")
sun.energy, sun.angle = 2.0, .2
light = bpy.data.objects.new("OverlapReviewSun", sun)
scene.collection.objects.link(light)
light.rotation_euler = (.3, -.5, -.6)
cam_data = bpy.data.cameras.new("OverlapReviewCamera")
cam = bpy.data.objects.new("OverlapReviewCamera", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam_data.type = "ORTHO"


def bv(p):
    return Vector((p[0], -p[2], p[1]-4))


VIEWS = [
    ("stairs", (-46, 9, 33), (-22, 31, 63), 38),
    ("rotunda", (-60, 18, 50), (-39, 31, 75), 24),
    ("arch-underside", (85, 7, 57), (71, 1.5, 72), 20),
    ("arch-garden", (85, 12, 57), (109, 8, 75), 32),
    ("arch-underside-isolated", (85, 12, 57), (108, 1.5, 74), 34),
    ("bridge", (4, 4, 21), (22, 15, 42), 25),
    ("balustrades", (-95, 5.5, -22), (-86, 12, -12), 11),
    ("kiosk", (-46.6, 8, -9), (-40, 13, 0), 7),
    ("eggnest", (-29, 5.5, -12), (-23, 11, -4), 8),
    ("care-cradle", (-19.5, 6, -14.5), (-13, 11, -5), 7),
    ("landmark", (-7, 7, -100), (-2, 14, -83), 24),
    ("stairs-grazing", (-46, 10, 33), (-18, 12, 55), 31),
    ("balustrades-grazing", (-95, 6.6, -22), (-86, 6.9, -12), 7),
    ("bridge-grazing", (4, 4.3, 21), (22, 5.8, 42), 23),
    ("eggnest-grazing", (-29, 4.6, -11), (-23, 5.1, -6), 5),
    ("structures-far", (-30, 10, 26), (48, 62, 118), 130),
    ("park-site-cleared", (-38, 5, -46), (-22, 34, -22), 42),
]


def render(stage):
    for name, target, eye, width in VIEWS:
        if "--only-arch" in sys.argv and name not in {"arch-garden", "arch-underside-isolated"}:
            continue
        hidden = {o: o.hide_render for o in bpy.data.objects if o.type == "MESH"}
        if name == "arch-underside-isolated":
            # Diagnostic isolation only: geometry and materials are unmodified.
            # Explicit filename/README disclosure; terrain cannot occlude the base.
            for obj in hidden:
                obj.hide_render = not obj.name.startswith("Architecture_MarbleArch__")
        cam.location = bv(eye)
        cam.rotation_euler = (bv(target)-cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_data.ortho_scale = width
        scene.render.filepath = str(OUT / (name+"-"+stage+".png"))
        bpy.ops.render.render(write_still=True)
        for obj, value in hidden.items():
            obj.hide_render = value
        print("OVERLAP RENDER", name, stage, flush=True)


render("before")
import json
new = json.loads((production_out / "world-v7-declutter.json").read_text())
old = json.loads((baseline / "world-v7-declutter.json").read_text())
clearing = {k: v for k, v in new["objects"].items() if k not in old["objects"]}
clearing_dir = OUT.parent / "clearing-only"
clearing_dir.mkdir(exist_ok=True)
(clearing_dir / "world-v7-declutter.json").write_text(json.dumps({"objects": clearing}))
ns["OUT"] = clearing_dir
sources = ns["declutter"](sources)
ns["OUT"] = production_out
spec = importlib.util.spec_from_file_location("world_overlap_geometry", HERE / "world_overlap_geometry.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
helper.fix(sources)
render("after")
