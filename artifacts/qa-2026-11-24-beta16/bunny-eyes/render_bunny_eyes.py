"""Before/after frames for the Bunny eye conform (Opus, 2026-11-24, beta 16 B4). Nothing is saved back.
  blender -b assets/art-source/pets/pet-bunny.blend --python artifacts/qa-2026-11-24-beta16/bunny-eyes/render_bunny_eyes.py -- <frames dir>
before = the shipped meshes (each conformed mesh's `pre_conform` attribute) with the shipped glance (a straight
.018 slide toward runtime -X). after = the conformed meshes with the new glance (a turn round the head's upright
axis through the Head centre, GardenPetVisual 2026-11-24). Rest and curious, front and both three-quarters.
Then: python artifacts/qa-2026-11-24-beta16/bunny-eyes/build_bunny_eyes_sheet.py <frames dir>
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix
OUT = sys.argv[-1]; os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene; P = "PetBunny__"; D = bpy.data.objects
def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()
root = D["PetBunny"]; root.location = (0, 0, 0); bpy.context.view_layer.update()
RL = world(root).inverted()
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

SHOWN = ("Body", "Head", "EarL", "EarR", "EarInnerL", "EarInnerR", "Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR", "Tail", "HandL", "HandR", "FootL", "FootR")
for o in D:
    if o.type == "MESH": o.hide_render = not (o.name.startswith(P) and o.name[len(P):] in SHOWN)
for c in bpy.data.collections: c.hide_render = False
conformed = [D[P + n] for n in ("EyeL", "EyeR", "BlushL", "BlushR")]
after = {o.name: [v.co.copy() for v in o.data.vertices] for o in conformed}
before = {o.name: [Vector(a.vector) for a in o.data.attributes["pre_conform"].data] for o in conformed}
head_pts = [RL @ world(D[P + "Head"]) @ v.co for v in D[P + "Head"].data.vertices]
HC = Vector([(min(p[i] for p in head_pts) + max(p[i] for p in head_pts)) / 2 for i in range(3)])

def set_state(which, curious):
    for o in conformed:
        M = world(root).inverted() @ world(o); Minv = M.inverted(); pts = [M @ c for c in (before if which == "before" else after)[o.name]]
        if curious and o.name[len(P):].startswith("Eye"):
            lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); c = (lo + hi) / 2
            pts = [Vector((p.x, p.y, c.z + (p.z - c.z) * 1.16 + .01)) for p in pts]          # eye height 1.16, up .01
            if which == "before": pts = [p + Vector((-.018, 0, 0)) for p in pts]              # the shipped straight slide
            else:
                R = Matrix.Rotation(math.asin(-.018 / (HC.y - c.y)), 4, "Z"); pv = Vector((HC.x, HC.y, 0))
                pts = [pv + R @ (p - pv) for p in pts]                                         # the turn round the head
        for v, p in zip(o.data.vertices, pts): v.co = Minv @ p
        o.data.update()
def shot(name, deg, pitch=8, w=760, h=560, ppu=640, z=1.0, x=0.0):
    root.rotation_euler.z = math.radians(deg)
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    cam_d.ortho_scale = w / ppu; t = math.radians(pitch)
    cam.location = (x, -10 * math.cos(t), z + 10 * math.sin(t)); cam.rotation_euler = (math.radians(90) - t, 0, 0)
    r.filepath = os.path.join(OUT, name + ".png"); bpy.ops.render.render(write_still=True)
VIEWS = (("front", 0), ("threeq-left", 38), ("threeq-right", -38))   # threeq-right: the face's viewer-right side (EyeR's outer edge) turned to the camera
for which in ("before", "after"):
    for curious in (False, True):
        set_state(which, curious)
        for view, deg in VIEWS: shot("bunny-%s-%s-%s" % ("curious" if curious else "rest", view, which), deg)
    set_state(which, True); shot("bunny-curious-eyeR-closeup-%s" % which, -52, pitch=14, ppu=1500, z=.87, x=-.2)
print("RENDERED", OUT)
