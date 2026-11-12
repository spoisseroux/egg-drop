"""Build the held 3D Pocket Deck Slim: .blend, FBX, manifest and two preview renders.

Run (background Blender only):
  blender -b --python scripts/build_pocket_deck_slim.py

Blender axes: screen faces -Y, up +Z, the d-pad is on -X (the viewer's left when looking at the screen).
FBX: axis_forward=-Z, axis_up=Y, the same preset as the pets. In Studio that puts the screen on part -Z
(NormalId.Front) and the d-pad on +X, which is what Lounge.lua's `mount` already expects.
Sizes follow the 2D shell: 1600 x 800 deck units = 1.84 x 0.92 studs.
"""
import bpy, bmesh, json, math, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art-source" / "deck"
OUT.mkdir(parents=True, exist_ok=True)
EVID = ROOT / "artifacts" / "deck-rebuild"
PLATES = ROOT / "assets" / "deck" / "faceplates"
U = 1.84 / 1600.0           # studs per deck unit
HALF_D = 0.07               # body is 0.14 deep
FRONT = -HALF_D


def ux(x):  # deck-unit x -> Blender x
    return (x - 800) * U


def uz(y):  # deck-unit y (down) -> Blender z (up)
    return (400 - y) * U


def rrect(w, h, r, seg=5):
    pts = []
    for cx, cz, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def circle(r, seg):
    return [(r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


def prism(name, profile, y_front, y_back, chamfer=0.0, center=(0, 0), back_cap=True, planar_uv=None):
    """Extrude a convex XZ profile along Y with an optional chamfer on the front edge."""
    bm = bmesh.new()
    cx, cz = center
    n = len(profile)

    def ring(y, shrink):
        vs = []
        for x, z in profile:
            L = math.hypot(x, z) or 1
            vs.append(bm.verts.new((cx + x - x / L * shrink, y, cz + z - z / L * shrink)))
        return vs
    rings = []
    if chamfer > 0:
        rings.append(ring(y_front, chamfer))
        rings.append(ring(y_front + chamfer, 0))
    else:
        rings.append(ring(y_front, 0))
    rings.append(ring(y_back, 0))
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], b[i], b[(i + 1) % n], a[(i + 1) % n]))
    bm.faces.new(list(reversed(rings[0])))
    if back_cap:
        bm.faces.new(rings[-1])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    x0, x1, z0, z1 = planar_uv or (min(xs), max(xs), min(zs), max(zs))
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0))
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new("PocketDeckSlim__" + name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def join(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = "PocketDeckSlim__" + name
    objs[0].data.name = name
    return objs[0]


def material(name, color, metallic=0.0, rough=0.4, emit=None, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 1.0
    if image and Path(image).exists():
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(str(image))
        m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    return m


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- geometry
shell = prism("ShellBody", rrect(1.84, 0.92, 150 * U), -HALF_D, HALF_D, chamfer=0.012)
# back chamfer: pull the back ring in a little by scaling the back face verts
for v in shell.data.vertices:
    if v.co.y > HALF_D - 1e-5:
        L = math.hypot(v.co.x, v.co.z)
        v.co.x -= v.co.x / L * 0.02
        v.co.z -= v.co.z / L * 0.02
nubs = []
for key_x in (280, 1320):
    nubs.append(prism("Nub", rrect(220 * U, 0.05, 0.012, seg=2), -0.035, 0.035, center=(ux(key_x), 0.46 + 0.0138 - 0.025)))
shell = join("Shell", [shell] + nubs)

pw, ph = 1560 * U, 760 * U
plate = prism("FrontPlate", rrect(pw, ph, 132 * U), FRONT - 0.008, FRONT, chamfer=0.003, back_cap=False, planar_uv=(-pw / 2, pw / 2, -ph / 2, ph / 2))
bezel = prism("Bezel", rrect(880 * U, 640 * U, 44 * U, seg=3), FRONT - 0.014, FRONT - 0.006, chamfer=0.002, back_cap=False)
sw, sh = 848 * U, 608 * U
screen = prism("Screen", rrect(sw, sh, 30 * U, seg=3), FRONT - 0.016, FRONT - 0.012, back_cap=False, planar_uv=(-sw / 2, sw / 2, -sh / 2, sh / 2))
pad = prism("AimRocker", circle(104 * U, 16), FRONT - 0.024, FRONT - 0.004, chamfer=0.006, center=(ux(190), uz(424)), back_cap=False)
btn_a = prism("Confirm", circle(88 * U, 16), FRONT - 0.034, FRONT - 0.004, chamfer=0.010, center=(ux(1432), uz(372)), back_cap=False)
btn_b = prism("Back", circle(52 * U, 12), FRONT - 0.028, FRONT - 0.004, chamfer=0.007, center=(ux(1318), uz(548)), back_cap=False)
menu = prism("Customize", rrect(124 * U, 44 * U, 21.9 * U, seg=3), FRONT - 0.018, FRONT - 0.004, chamfer=0.003, center=(ux(190), uz(640)), back_cap=False)
power = prism("Power", circle(8 * U, 8), FRONT - 0.011, FRONT - 0.004, center=(ux(190), uz(258)), back_cap=False)
parts = [shell, plate, bezel, screen, pad, btn_a, btn_b, menu, power]

plate_id = "aqua_pop"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    plate_id = argv[0]
mats = {
    "Shell": material("deck__band", srgb("#C9CED8"), metallic=1.0, rough=0.28),
    "FrontPlate": material("deck__plate", srgb("#43C9F7"), rough=0.18, image=PLATES / f"{plate_id}.png"),
    "Bezel": material("deck__glass", srgb("#08090B"), rough=0.08),
    "Screen": material("deck__screen", srgb("#0C0D10"), rough=0.1, emit=srgb("#1B2A33")),
    "AimRocker": material("deck__smoked", srgb("#1D1F25"), rough=0.3),
    "Confirm": material("deck__accent", srgb("#6FE3FF"), rough=0.2),
    "Back": material("deck__smoked_b", srgb("#3A3E47"), rough=0.3),
    "Customize": material("deck__smoked_c", srgb("#1D1F25"), rough=0.3),
    "Power": material("deck__led", srgb("#6FE3FF"), emit=srgb("#6FE3FF")),
}
for ob in parts:
    short = ob.name.split("__")[1]
    ob.data.materials.clear()
    ob.data.materials.append(mats[short])
    ob["role"] = short
bpy.context.view_layer.update()

# ---------------------------------------------------------------- manifest
rows, total = [], 0
for ob in parts:
    me = ob.data
    me.calc_loop_triangles()
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    c, s = (lo + hi) / 2, hi - lo
    total += len(me.loop_triangles)
    rows.append({"name": ob.name, "robloxName": ob["role"], "triangles": len(me.loop_triangles),
                 "centerBlender": [round(v, 5) for v in c], "sizeBlender": [round(v, 5) for v in s],
                 "centerRoblox": [round(-c.x, 5) + 0.0, round(c.z, 5) + 0.0, round(c.y, 5) + 0.0],
                 "sizeRoblox": [round(s.x, 5), round(s.z, 5), round(s.y, 5)]})
notes = {
    "Shell": "band + both shoulder nubs. Color = faceplate band tint; Material Metal.",
    "FrontPlate": "planar UV 0..1 across the face, so a faceplate texture maps straight on (SurfaceAppearance.ColorMap, or a Decal/Texture on the Front face). Material from faceplates.json held3d.",
    "Bezel": "black glass, SmoothPlastic #08090B, Reflectance 0.15.",
    "Screen": "separate part. Keep the SurfaceGui / 'Playing' badge adornee here. Color = LCD glass #0C0D10; Neon tint optional.",
    "AimRocker": "the round four-way pad (keeps the old part name so paintDevice still finds it). Color #1D1F25.",
    "Confirm": "A. Color = faceplate accent.",
    "Back": "B. Color #3A3E47.",
    "Customize": "the Menu pill (old part name kept). Color #1D1F25.",
    "Power": "LED. Neon, Color = faceplate accent.",
}
for r in rows:
    r["note"] = notes[r["robloxName"]]
manifest = {
    "schema": 1, "asset": "pocket-deck-slim", "fbx": "pocket-deck-slim.fbx", "blend": "pocket-deck-slim.blend",
    "builtBy": "scripts/build_pocket_deck_slim.py",
    "axes": "FBX axis_forward=-Z axis_up=Y (pet preset). Blender: screen -Y, up +Z, d-pad on -X. Roblox part space: (x, y, z) = (-bx, bz, by), so the screen is on -Z (Front) and the d-pad on +X.",
    "sizeStuds": [1.84, 0.92, 0.14], "unitsPerStud": round(1 / U, 3), "triangles": total,
    "import": "Studio's default FBX units give 100x MeshSize; set Size = MeshSize / 100 as for the pets, or import with scale unit Studs.",
    "attach": {
        "convention": "unchanged from Lounge.setMode: every part is welded to the torso with C0 = mount * CFrame.new(centerRoblox).",
        "mount": "CFrame.new(0, -0.39, -1.02) * CFrame.Angles(math.rad(-22), math.pi, 0)",
        "grips": {"LeftGrip": [0.88, -0.27, -0.10], "RightGrip": [-0.88, -0.27, -0.10], "parent": "Shell", "note": "same attachments as today; the shell is still 1.84 wide"},
        "removed": ["Lounge cap", "AimDivider", "SpeakerSlot x3 (now in the faceplate overlay)", "StickerFace SurfaceGui (stickers are retired)"],
        "paintDevice": "Shell.Color = band tint; FrontPlate texture + material from faceplates.json; Confirm.Color and Power.Color = accent; Screen.Color stays the LCD glass.",
    },
    "parts": rows,
}
(OUT / "pocket-deck-slim.json").write_text(json.dumps(manifest, indent=1), newline="\n")

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.fbx(filepath=str(OUT / "pocket-deck-slim.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                         global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                         add_leaf_bones=False, bake_anim=False, path_mode="AUTO", mesh_smooth_type="FACE")

# ---------------------------------------------------------------- preview renders
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (*srgb("#AEB6C2"), 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
scene.world = world
for name, loc, energy, size in (("Key", (-1.2, -2.4, 2.0), 70, 2.5), ("Fill", (2.2, -1.6, 0.4), 25, 3.0), ("Rim", (0.5, 1.5, 1.5), 60, 2.0)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size = energy, size
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(lo)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 70
scene.collection.objects.link(cam)
scene.camera = cam
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    pass
scene.render.resolution_x, scene.render.resolution_y = 1280, 760
scene.view_settings.view_transform = "Standard"
EVID.mkdir(parents=True, exist_ok=True)
for tag, pos in (("front", (0.0, -4.4, 0.25)), ("angle", (-2.3, -3.4, 1.5)), ("top", (0.6, -2.0, 3.6))):
    cam.location = pos
    cam.rotation_euler = (Vector((0, 0, 0)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(EVID / f"held3d-{plate_id}-{tag}.png")
    bpy.ops.render.render(write_still=True)

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "pocket-deck-slim.blend"))
print("DECK3D triangles", total, [(r["robloxName"], r["triangles"]) for r in rows])
