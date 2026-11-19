"""Renders for the production Bunny sheets (2026-11-19). Nothing is saved back.
  blender -b assets/art-source/pets/pet-bunny.blend --python artifacts/v2-bunny-production/render_bunny.py
Same camera, lights and scale as artifacts/v2-bear-restyle-2026-11-19/render_bear.py (350 px per stud, orthographic),
so Bunny frames sit beside the Bear's. Set BUNNY_ONLY=<text> to render only the frames whose name contains it.
"""
import bpy, math, os
from mathutils import Matrix
ONLY = os.environ.get("BUNNY_ONLY", "")
HERE = os.path.dirname(os.path.abspath(__file__)); RAW = os.path.join(HERE, "raw"); os.makedirs(RAW, exist_ok=True)
scene = bpy.context.scene; P = "PetBunny__"
root = bpy.data.objects["PetBunny"]; root.location = (0, 0, 0)

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)
def palette(primary, secondary):
    for n in bpy.data.node_groups["PetPalette"].nodes:
        if n.type == "RGB": n.outputs[0].default_value = lin(primary if n.name == "Primary" else secondary)
WHITE, PEACH, HONEY, SKY = ("#FFFFFF", "#A8A5AE"), ("#FFC6B8", "#FFF6EC"), ("#FFD98A", "#FFB9B0"), ("#9CCBF5", "#FFF3D0")

for o in list(scene.objects):
    if o.type in ("LIGHT", "CAMERA"): bpy.data.objects.remove(o)
world = bpy.data.worlds.new("StudyWorld"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = lin("#F1ECE6"); bg.inputs[1].default_value = .8
def light(name, energy, rot):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy; d.angle = math.radians(25)
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.rotation_euler = [math.radians(v) for v in rot]; o.location = (0, 0, 4)
light("Key", 2.4, (52, 0, -32)); light("Fill", .8, (60, 0, 140))
cam_d = bpy.data.cameras.new("StudyCam"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("StudyCam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
r = scene.render; r.film_transparent = True; r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
try: scene.view_settings.view_transform = "Standard"
except TypeError: pass
try: scene.eevee.taa_render_samples = 64
except Exception: pass
for c in bpy.data.collections: c.hide_render = False

DEFAULT = ("Body", "Head", "EarL", "EarR", "EarInnerL", "EarInnerR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR", "Tail", "HandL", "HandR", "FootL", "FootR")
SWAPS = {"Eyes": ("EyeL", "EyeR"), "Mouth": ("Mouth",), "Tail": ("Tail",)}
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
A = lambda n: bpy.data.objects[P + "Anchor_" + n]
REST = {n: A(n).matrix_basis.copy() for n in ("EarL", "EarR", "HelixL", "HelixR", "LobeL", "LobeR")}
def ears(tip_deg):
    """The hat pose: each ear, with its piercing anchors, turns about its joint (the proposal's earPose.hat)."""
    for tag, sign in (("L", -1), ("R", 1)):
        pivot = REST["Ear" + tag].translation
        turn = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(sign * tip_deg), 4, "Y") @ Matrix.Translation(-pivot)
        for n in ("Ear", "Helix", "Lobe"): A(n + tag).matrix_basis = turn @ REST[n + tag]
def wear(items=(), extra=(), hat_pose=None):
    hidden = set(); hat = False
    for o in meshes:
        if o.get("item") in items and o.get("slot") in SWAPS: hidden.update(SWAPS[o["slot"]])
        if o.get("item") in items and o.get("slot") == "Hat" and not o.get("openCrown"): hat = True
    for o in meshes:
        name = o.name[len(P):] if o.name.startswith(P) else None
        on = name is not None and ((name in DEFAULT and name not in hidden) or o.get("item") in items or name in extra)
        o.hide_render = not on; o.hide_viewport = False
    ears(27 if (hat if hat_pose is None else hat_pose) else 0)
PPU = 350
def shot(name, deg, size=840, zoom=1.0, z=1.0):
    if ONLY and ONLY not in name: return
    root.rotation_euler.z = math.radians(deg)
    r.resolution_x = r.resolution_y = size; r.resolution_percentage = 100
    cam_d.ortho_scale = size / PPU / zoom; cam.location = (0, -10, z); cam.rotation_euler = (math.radians(90), 0, 0)
    r.filepath = os.path.join(RAW, "bunny-%s.png" % name); bpy.ops.render.render(write_still=True)

VIEWS = (("front", 0), ("threeq", -35), ("side", -90), ("back", 180), ("threeq-back", 145), ("threeq-left", 35))
palette(*WHITE); wear()
for name, deg in VIEWS: shot("turn-" + name, deg)
shot("face-front", 0, 1200, 2.2857, 1.01)                 # 800 px per stud
wear(hat_pose=True)
for name, deg in (("front", 0), ("threeq", -35)): shot("hatpose-" + name, deg)
palette(*PEACH); wear()
for name, deg in (("front", 0), ("threeq", -35)): shot("dyed-" + name, deg)
OUTFITS = (                                               # the same five outfits as 02-bear-wearable-fit.png
    ("a", WHITE, ("beanie", "tee", "beads", "sparkle"), ()),
    ("b", HONEY, ("sunhat", "hoodie", "bellcollar", "sleepy", "starstud"), ()),
    ("c", SKY, ("flowercrown", "acorn", "specs", "blush", "ring", "bands"), ()),
    ("d", WHITE, ("partyhat", "happy", "blep", "bowtail", "bands"), ("WingL_S3", "WingR_S3")),
    ("e", HONEY, ("lash", "w", "heart"), ("HornL_S5", "HornR_S5")),
)
for key, pal, items, extra in OUTFITS:
    palette(*pal); wear(items, extra)
    shot("fit-%s-front" % key, 0); shot("fit-%s-threeq" % key, -35)
    if key in ("b", "d", "e"): shot("fit-%s-back" % key, 145)
    if key in ("a", "c"): shot("fit-%s-side" % key, -90)
print("RENDERED")
