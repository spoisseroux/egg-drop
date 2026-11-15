"""Preview render of the World 1 v7 texture sets on the real world mesh (QA 2026-11-15, W1).

  blender -b --python scripts/render_world_v7_texture_preview.py -- <texture dir> <out prefix>

Imports assets/world/world-v7.fbx, maps each W1_ material to <texture dir>/<material>.png (materials the
directory lacks fall back to assets/world/textures/dusk, the palette PNG, or a flat colour), adds a white
ball the size of a default Bear on the hub marble, and renders two stills under a plain sun and sky. It is a
like-for-like look at the colour maps only: Roblox lighting, bloom and the dusk grade are not reproduced.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
argv = sys.argv[sys.argv.index("--") + 1:]
TEX, PREFIX = Path(argv[0]), argv[1]
DUSK = ROOT / "assets" / "world" / "textures" / "dusk"
V5 = ROOT / "assets" / "art-source" / "environment" / "textures" / "v5"
ALIAS = {"W1_water_pool": "W1_water", "W1_water_stream": "W1_water", "W1_waterfall_sky": "W1_waterfall_tumble"}
FLAT = {"W1_glow_warm": (1, .85, .54), "W1_glow_aqua": (.31, .9, 1), "W1_glow_pink": (1, .5, .81),
        "W1_cloud": (.96, .76, .85), "W1_foam": (.98, .96, .96), "W1_bubble": (.87, .95, 1)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / "assets" / "world" / "world-v7.fbx"))


def image_for(name):
    key = ALIAS.get(name, name)
    for path in (TEX / f"{key}.png", DUSK / f"{key}.png"):
        if path.exists():
            return path
    if name == "W1_palette":
        return ROOT / "assets" / "world" / "textures" / "palette-roblox.png"
    if name == "W1_ground":
        return V5 / "ground_soft.png"  # reached only when the texture dir has no W1_ground.png
    return None


for mat in bpy.data.materials:
    name = mat.name.split(".")[0]
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    path = image_for(name)
    if path:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(path))
        if name == "W1_palette":
            tex.interpolation = "Closest"
        if name == "W1_ground":
            # Roblox multiplies the near-white ground detail map by the mesh vertex colours.
            tint, mix = nodes.new("ShaderNodeVertexColor"), nodes.new("ShaderNodeMixRGB")
            mix.blend_type, mix.inputs[0].default_value = "MULTIPLY", 1.0
            links.new(tex.outputs["Color"], mix.inputs[1]); links.new(tint.outputs["Color"], mix.inputs[2])
            links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        r, g, b = FLAT.get(name, (.8, .8, .8))
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1)

scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.75, .82, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (0.9, 0.1, 0.6)
scene.collection.objects.link(sun)

# The hub plaza: the highest-area marble mesh near the island centre. Find the marble under the centre by ray.
deps = bpy.context.evaluated_depsgraph_get()
bounds = [o.matrix_world @ Vector(c) for o in bpy.data.objects if o.type == "MESH" and "Architecture" in o.name for c in o.bound_box]
centre = sum(bounds, Vector()) / len(bounds)
print("ARCH_CENTRE", tuple(round(v, 2) for v in centre))
spots = []
for dx in range(-40, 41, 2):
    for dy in range(-40, 41, 2):
        hit, loc, normal, _, obj, _ = scene.ray_cast(deps, Vector((centre.x + dx, centre.y + dy, 200)), Vector((0, 0, -1)))
        if hit and "marble" in obj.name and normal.z > .95:
            spots.append((dx * dx + dy * dy, loc.copy(), obj.name))
spots.sort(key=lambda s: s[0])
print("MARBLE_SPOTS", len(spots), spots[:3])
spot = spots[0][1] if spots else centre
scale = 0.5  # the Bear stand-in is about 2 scene units tall
bear = bpy.data.materials.new("Bear")
bear.use_nodes = True
next(n for n in bear.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (.96, .95, .93, 1)
for offset, radius in (((0, 0, 0.9), 0.9), ((0, 0, 2.0), 0.7), ((-.5, 0, 2.6), 0.25), ((.5, 0, 2.6), 0.25)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius * scale, location=spot + Vector(offset) * scale)
    bpy.context.object.data.materials.append(bear)
    bpy.ops.object.shade_smooth()

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 22
cam.data.clip_end = 5000
scene.collection.objects.link(cam)
scene.camera = cam
for label, back, up in (("hub", 30, 14), ("wide", 150, 80)):
    for angle, suffix in (((1, -1), "a"), ((-1, -0.6), "b")):
        direction = Vector((angle[0], angle[1], 0)).normalized()
        cam.location = spot + (direction * back + Vector((0, 0, up))) * scale
        cam.rotation_euler = (spot + Vector((0, 0, 1)) * scale - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{PREFIX}-{label}-{suffix}.png"
        bpy.ops.render.render(write_still=True)

import numpy as np
for o in bpy.data.objects:
    if o.type == "MESH" and any(m and m.name.split(".")[0] == "W1_ground" for m in o.data.materials) and o.data.color_attributes:
        attr = o.data.color_attributes[0]
        cols = np.zeros(len(attr.data) * 4); attr.data.foreach_get("color_srgb", cols)
        cols = cols.reshape(-1, 4)[:, :3]
        print("GROUND_VC", o.name, attr.name, attr.domain, (cols.mean(0) * 255).round(), (np.percentile(cols, [5, 50, 95], axis=0) * 255).round().tolist())
