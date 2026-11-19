"""Shade tweaker study (2026-11-19): three flat-lit passes of the live Bear, for colour maths in build_mockups.py.
No generated art: this renders assets/art-source/pets/pet-bear.blend as it is and saves nothing back.

  blender -b assets/art-source/pets/pet-bear.blend --python artifacts/v2-shade-tweaker-2026-11-19/render_bear_passes.py

Passes (16-bit PNG, Standard view, transparent film), written to raw/:
  bear-pass-primary.png    primary white, secondary black
  bear-pass-secondary.png  primary black, secondary white
  bear-pass-rest.png       both black (face, speculars, everything that is not a body colour)
In linear light:  picture = rest + (primary-rest) * PrimaryColour + (secondary-rest) * SecondaryColour.
"""
import bpy, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw"); os.makedirs(RAW, exist_ok=True)
scene = bpy.context.scene
coll = bpy.data.collections["EggDrop_PetBear"]
if coll.name not in scene.collection.children: scene.collection.children.link(coll)
root = bpy.data.objects["PetBear"]; root.location = (0, 0, 0)
group = bpy.data.node_groups["PetPalette"]
def set_palette(primary, secondary):
    for n in group.nodes:
        if n.type == "RGB": n.outputs[0].default_value = (primary if n.name == "Primary" else secondary)
for o in root.children_recursive:
    if "Charm" in o.name: o.hide_render = True      # pets start with no charm

world = bpy.data.worlds.new("StudyWorld"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (.87, .83, .79, 1); bg.inputs[1].default_value = .8
def light(name, energy, rot):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy; d.angle = math.radians(25)
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.rotation_euler = [math.radians(v) for v in rot]; o.location = (0, 0, 4)
light("Key", 2.4, (52, 0, -32)); light("Fill", .8, (60, 0, 140))
cam_d = bpy.data.cameras.new("StudyCam"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("StudyCam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
r = scene.render; r.film_transparent = True
r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"; r.image_settings.color_depth = "16"
try: scene.view_settings.view_transform = "Standard"
except TypeError: pass
try: scene.eevee.taa_render_samples = 48
except Exception: pass
r.resolution_x, r.resolution_y, r.resolution_percentage = 720, 760, 100
cam_d.ortho_scale = 1.85; cam.location = (0, -10, .78); cam.rotation_euler = (math.radians(90), 0, 0)
root.rotation_euler.z = math.radians(-18)
W, K = (1, 1, 1, 1), (0, 0, 0, 1)
for name, p, s in (("primary", W, K), ("secondary", K, W), ("rest", K, K)):
    set_palette(p, s); r.filepath = os.path.join(RAW, "bear-pass-%s.png" % name); bpy.ops.render.render(write_still=True)
print("ENGINE", r.engine, [(n.name, n.type) for n in group.nodes])
