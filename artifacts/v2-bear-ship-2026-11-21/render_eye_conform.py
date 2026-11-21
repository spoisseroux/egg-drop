"""Before/after frames for the eye conform (Fable, 2026-11-21). Nothing is saved back.
  blender -b assets/art-source/pets/pet-bear-v2-cute.blend --python artifacts/v2-bear-ship-2026-11-21/render_eye_conform.py -- <frames dir>
"before" is the shipped rigid move, read back from each mesh's `pre_conform` attribute. The Bunny wears the
Bear's item meshes through its anchor change (Bunny anchor minus v2 Bear anchor), as PetAttachments does.
Then: python artifacts/v2-bear-ship-2026-11-21/build_eye_conform_sheet.py <frames dir>
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix
OUT = sys.argv[-1]; os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__)); PETS = os.path.join(HERE, "..", "..", "assets", "art-source", "pets")
scene = bpy.context.scene; P = "PetBear__"; D = bpy.data.objects
def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()
bear = D["PetBear"]; bear.location = (0, 0, 0)

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c) + (1.0,)
for o in list(scene.objects):
    if o.type in ("LIGHT", "CAMERA"): bpy.data.objects.remove(o)
wd = bpy.data.worlds.new("StudyWorld"); scene.world = wd; wd.use_nodes = True
bg = next(n for n in wd.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = lin("#F1ECE6"); bg.inputs[1].default_value = .8
def light(name, energy, rot):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy; d.angle = math.radians(25)
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.rotation_euler = [math.radians(v) for v in rot]; o.location = (0, 0, 4)
light("Key", 2.4, (52, 0, -32)); light("Fill", .8, (60, 0, 140))
cam_d = bpy.data.cameras.new("StudyCam"); cam_d.type = "ORTHO"; cam = bpy.data.objects.new("StudyCam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
r = scene.render; r.film_transparent = False; r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGB"
try: scene.view_settings.view_transform = "Standard"
except TypeError: pass
try: scene.eevee.taa_render_samples = 64
except Exception: pass
for c in bpy.data.collections: c.hide_render = False

# ---- the Bunny, appended beside the Bear
with bpy.data.libraries.load(os.path.join(PETS, "pet-bunny.blend"), link=False) as (src, dst):
    names = [n for n in src.objects if n.startswith("PetBunny")]; dst.objects = list(names)
bun = dict(zip(names, dst.objects))
for o in bun.values(): scene.collection.objects.link(o)
bunny = bun["PetBunny"]; bunny.location = (0, 0, 0)
bpy.context.view_layer.update()
def anchor(o_root, o): return (world(o_root).inverted() @ world(o)).to_translation()

DEFAULT = ("Body", "Head", "EarL", "EarR", "EarInnerL", "EarInnerR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR", "Tail", "HandL", "HandR", "FootL", "FootR")
conformed = [o for o in D if o.type == "MESH" and o.name.startswith(P) and o.data.attributes.get("pre_conform")]
after = {o.name: [v.co.copy() for v in o.data.vertices] for o in conformed}
before = {o.name: [Vector(a.vector) for a in o.data.attributes["pre_conform"].data] for o in conformed}
# the Bear's item meshes on the Bunny: one copy per state, parented to the Bunny root
bunny_copies = {}
for o in conformed:
    role = o.get("role")
    if not (o.get("item") or o.get("variant")) or "PetBunny__Anchor_" + role not in bun: continue
    d = anchor(bunny, bun["PetBunny__Anchor_" + role]) - anchor(bear, D[P + "Anchor_" + role])
    M = Matrix.Translation(d) @ world(bear).inverted() @ world(o)
    for state, coords in (("before", before[o.name]), ("after", after[o.name])):
        me = o.data.copy(); 
        for v, c in zip(me.vertices, coords): v.co = M @ c
        ob = bpy.data.objects.new("BunnyWears_%s_%s" % (state, o.name[len(P):]), me); scene.collection.objects.link(ob); ob.parent = bunny
        ob["item"] = o.get("item") or str(o.get("variant")).lower(); bunny_copies[ob.name] = (state, ob)
def state(which):
    for o in conformed:
        for v, c in zip(o.data.vertices, (before if which == "before" else after)[o.name]): v.co = c
        o.data.update()
ITEM_OF = lambda o: o.get("item") or (str(o.get("variant")).lower() if o.get("variant") else None)
def show(pet, which, item=None):
    for o in D:
        if o.type != "MESH": continue
        on = False
        if pet == "bear" and o.name.startswith(P):
            n = o.name[len(P):]
            on = (n in DEFAULT and not (item and n in ("EyeL", "EyeR"))) or (item is not None and ITEM_OF(o) == item and n.startswith("Eye"))
        elif pet == "bunny" and o.name.startswith("PetBunny__"):
            n = o.name[len("PetBunny__"):]
            on = n in DEFAULT and not (item and n in ("EyeL", "EyeR"))
        elif pet == "bunny" and o.name in bunny_copies:
            on = bunny_copies[o.name][0] == which and o["item"] == item
        o.hide_render = not on; o.hide_viewport = False
    state(which)
def shot(name, pet, deg, pitch=10, w=760, h=600, ppu=640, z=.985, x=0.0):
    for root in (bear, bunny): root.rotation_euler.z = math.radians(deg)
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    cam_d.ortho_scale = w / ppu; t = math.radians(pitch)
    cam.location = (x, -10 * math.cos(t), z + 10 * math.sin(t)); cam.rotation_euler = (math.radians(90) - t, 0, 0)
    r.filepath = os.path.join(OUT, name + ".png"); bpy.ops.render.render(write_still=True)
for which in ("before", "after"):
    show("bear", which); shot("bear-default-front-" + which, "bear", 0); shot("bear-default-threeq-" + which, "bear", -38)
    show("bear", which, "sparkle"); shot("bear-sparkle-front-" + which, "bear", 0); shot("bear-sparkle-threeq-" + which, "bear", -38)
    shot("bear-sparkle-eye-" + which, "bear", -52, pitch=24, w=760, h=600, ppu=1500, z=.99, x=-.1)
    show("bunny", which, "sparkle"); shot("bunny-sparkle-front-" + which, "bunny", 0, z=.96); shot("bunny-sparkle-threeq-" + which, "bunny", -38, z=.96)
    show("bunny", which, "lash"); shot("bunny-lash-threeq-" + which, "bunny", -38, z=.96)
    show("bear", which, "lash"); shot("bear-lash-threeq-" + which, "bear", -38)
    show("bear", which, "happy"); shot("bear-happy-threeq-" + which, "bear", -38)
    show("bear", which, "round"); shot("bear-round-threeq-" + which, "bear", -38)
    show("bear", which, "sleepy"); shot("bear-sleepy-threeq-" + which, "bear", -38)
print("RENDERED", OUT)
