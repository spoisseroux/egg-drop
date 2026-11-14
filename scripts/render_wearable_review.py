"""Review renders of the Bear wearing chosen items (art QA, not shipped).

  blender -b --factory-startup assets/art-source/pets/pet-bear-attachments.blend \
      --python scripts/render_wearable_review.py -- <out.png> [--body #hex] [--secondary #hex] [--night] \
      [--views front,q,side,back,face,phone] item [item ...]

Shows the default Bear plus every mesh of the named item ids (the `item` custom property), hides the
default pieces a swap replaces, and writes <out>-<view>.png per view (scripts/montage_review.py joins
them into <out.png>). `phone` is the front view at 96 px. Add `--python scripts/build_bear_wearables.py`
before this script (and `--no-save` after `--`) to review unsaved wearable code.
Reuses the book icon scene (scripts/deck_art/render_book_icons.py).
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "deck_art"))
import render_book_icons as R  # noqa: E402

args = [a for a in sys.argv[sys.argv.index("--") + 1:] if a != "--no-save"]
out = os.path.abspath(args.pop(0))
body, secondary, night, views = "#FFFFFF", "#A8A5AE", False, "front,q,side,back,face,phone"
items = []
while args:
    a = args.pop(0)
    if a == "--body":
        body = args.pop(0)
    elif a == "--secondary":
        secondary = args.pop(0)
    elif a == "--night":
        night = True
    elif a == "--views":
        views = args.pop(0)
    else:
        items.append(a)

scene, cam = R.setup_scene()
ROOT_NAME = next(o.name for o in bpy.data.objects if o.name in ("PetBear", "PetBlip"))
PRE = ROOT_NAME + "__"
MAT = "petBear" if ROOT_NAME == "PetBear" else "petBlip"
defaults = [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render and o.name.startswith(PRE)
            and "Charm" not in o.name]
for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = True
bmat = R.flat("review_body", body, rough=0.62, spec=0.35)
smat = R.flat("review_secondary", secondary, rough=0.55)
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    for slot in o.material_slots:
        if slot.material and slot.material.name == MAT + "__body":
            slot.material = bmat
        elif slot.material and slot.material.name in (MAT + "__secondary", MAT + "__wing"):
            slot.material = smat
pieces = [o for o in bpy.data.objects if o.type == "MESH" and (o.get("item") in items or o.name.split("__")[-1] in items)]
hidden = set()
for o in pieces:
    for name in R.REPLACES.get(o.get("slot"), []):
        if o.get("slot") != "Eyes" or name.endswith(o.name.split("__")[1][3]):
            hidden.add(name.replace("PetBear__", PRE))
for o in defaults:
    o.hide_render = o.name in hidden
for o in pieces:
    o.hide_render = False
if night:
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.13, 0.30, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    for name, energy in (("Key", 0.9), ("Fill", 0.3), ("Rim", 1.2)):
        bpy.data.objects[name].data.energy = energy
        bpy.data.objects[name].data.color = (0.62, 0.72, 1.0)
scene.render.film_transparent = False
X = bpy.data.objects[ROOT_NAME].matrix_world.translation.x
VIEWS = {
    "front": ((X, -0.05, 0.78), 1.9, 0, 8, 512),
    "q": ((X, -0.05, 0.78), 1.9, -35, 10, 512),
    "side": ((X, -0.05, 0.78), 1.9, -90, 6, 512),
    "back": ((X, -0.05, 0.78), 1.9, 180, 10, 512),
    "bq": ((X, -0.05, 0.78), 1.9, 145, 12, 512),
    "face": ((X, -0.3, 1.02), 1.15, 0, 4, 512),
    "arm": ((X - 0.36, -0.15, 0.45), 0.6, -30, 8, 512),
    "phone": ((X, -0.05, 0.78), 1.9, 0, 8, 96),
}
for v in views.split(","):
    target, scale, yaw, pitch, size = VIEWS[v]
    scene.render.resolution_x = scene.render.resolution_y = size
    R.frame(cam, target, scale, yaw, pitch)
    R.render(scene, out[:-4] + "-" + v + ".png")
print("REVIEW", out)
