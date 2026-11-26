"""Render the join loading screen's five waving pals and pack them into one sprite sheet.

Original renders of the game's own pet models (the v2 Bear and the Bunny, their wearables and dye
palettes); no generated or downloaded imagery. Two steps, background Blender only (no .blend is saved):

  blender -b assets/art-source/pets/pet-bear-v2-cute.blend --python scripts/render_loading_pals.py
  blender -b assets/art-source/pets/pet-bunny.blend        --python scripts/render_loading_pals.py
  python scripts/render_loading_pals.py      # packs raw/*.png into the sheet (needs Pillow)

Writes artifacts/loading-screen-2026-11-25/raw/<pal>-<frame>.png (768 px, transparent) and
assets/ui/loading/loading-pals.png: a 1024x512 sheet (Roblox keeps images up to 1024 px) of 204x256
cells, column = pal (PALS order, left to right on screen), row 0 = frame "out", row 1 = "in", each with
a white sticker outline and a transparent gutter so a downscaled cell never picks up its neighbour.
LoadingScreen.client.lua reads the same layout (Sheet, column = pal index - 1, row = frame).

Art direction: Fable, 2026-11-25 (five pals, two wave frames, 8 deg camera, matte stage light).
"""
import math, os, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RAW = REPO / "artifacts" / "loading-screen-2026-11-25" / "raw"
SHEET = REPO / "assets" / "ui" / "loading" / "loading-pals.png"
RENDER = 768          # raw render size
CELL_W, CELL_H = 204, 256   # 5 x 204 = 1020 <= 1024 wide, 2 x 256 = 512 tall
OUTLINE = 4           # sticker outline at cell size
GUTTER = 6            # transparent margin inside each cell

HUE = {"rose": "#FF327A", "tide": "#008DFF", "citrus": "#FFCC00", "iris": "#9350FF", "tide:citrus": "#00BE77"}

# Left to right on screen. side: the waving arm on screen ("L" = screen left), or "both".
# yaw: degrees the pal turns toward the row's centre (+ = toward screen right).
PALS = [
    dict(id="bear-citrus", pet="Bear", body=("citrus", 1.0), secondary="rose", yaw=20, side="L",
         outfit=dict(Hat="partyhat", Neck="beads", Eyes="sparkle")),
    dict(id="bunny-tide", pet="Bunny", body=("tide", 0.84), secondary="citrus", yaw=10, side="L",
         outfit=dict(Hat="flowercrown", Eyewear="specs", Neck="acorn")),
    dict(id="bear-iris", pet="Bear", body=("iris", 0.84), secondary="citrus", yaw=0, side="both",
         outfit=dict(Shirt="tee", Neck="bellcollar", Eyes="sparkle", Mouth="blep")),
    dict(id="bunny-white", pet="Bunny", body=None, secondary="rose", yaw=-10, side="R",
         outfit=dict(Hat="beanie", Shirt="hoodie", Eyes="happy")),
    dict(id="bear-mint", pet="Bear", body=("tide:citrus", 0.84), secondary="citrus", yaw=-20, side="R",
         outfit=dict(Hat="sunhat", Wrist="bands", Tail="heart")),
]
FRAMES = ("out", "in")
# Wave: the arm rotates about the front axis at the shoulder (hand anchor), paw beside the cheek on "out"
# and above it on "in" (Fable's review: 105/140, the cheer 120/145); "in" also tilts the head 4 deg toward
# the raised arm. REACH moves the waving shoulder out and toward the camera (a 2D cheat: the stubby arm
# would otherwise hide behind the big head) so the whole paw draws in front of the head's edge.
# Fable's round 2: "in" lowered and shifted further out so no paw covers an eye.
RAISE = {"wave": {"out": 105.0, "in": 128.0}, "cheer": {"out": 120.0, "in": 132.0}}
FORWARD = 10.0
REACH = {"out": (0.22, -0.24, 0.04), "in": (0.30, -0.24, 0.04)}
TILT = {"out": 0.0, "in": 4.0}
CAM_ELEVATION = 8.0
ORTHO = 2.55          # world units across the frame (the Bunny's ears and the party hat fit)
TARGET_Z = 0.98


def lin(hexcode):
    h = hexcode.lstrip("#")
    f = lambda c: (c / 255 / 12.92) if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4
    return tuple(f(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def body_linear(body):
    """PetPalette.tint(white, hue, weight) in linear light, as the game mixes a dyed body."""
    if body is None:
        return (1.0, 1.0, 1.0, 1.0)
    hue, weight = body
    target = lin(HUE[hue])
    return tuple(1.0 * (1 - weight) + t * weight for t in target) + (1.0,)


HEAD_ANCHORS = ("Head", "EarL", "EarR", "EyeL", "EyeR", "EyeLine", "FaceBridge", "HatCrown", "Forehead", "Mouth", "Nose",
                "CheekL", "CheekR", "HelixL", "HelixR", "LobeL", "LobeR", "HornL", "HornR")


def blender_main():
    import bpy
    from mathutils import Matrix, Vector
    D = bpy.data.objects
    root = next(o for o in D if o.type == "EMPTY" and o.parent is None and o.name in ("PetBear", "PetBunny"))
    pet = "Bear" if root.name == "PetBear" else "Bunny"
    pre = root.name + "__"
    scene = bpy.context.scene
    wear = [o for c in bpy.data.collections if c.name.endswith("_Wearables") for o in c.objects]
    for c in bpy.data.collections:
        if c.name.endswith(("_FeatureHorns", "_FeatureWings")) or c.name == "MockOnly_HornSizeLineup":
            for o in c.objects:
                o.hide_render = True
    for o in D:
        if o.name.startswith(pre + "CharmDot") or o.name in (pre + "WingL", pre + "WingR"):
            o.hide_render = True   # no charm, no wings on a loading-screen pal
    scene.render.engine = scene.render.engine  # keep the file's EEVEE stage
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = scene.render.resolution_y = RENDER
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    cam = bpy.data.objects.new("PalCam", bpy.data.cameras.new("PalCam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ORTHO
    scene.camera = cam
    palette = bpy.data.node_groups["PetPalette"].nodes
    SWAPS = {"Eyes": [pre + "EyeL", pre + "EyeR"], "Mouth": [pre + "Mouth"], "Tail": [pre + "Tail"]}

    base_root = root.matrix_world.copy()
    names = ["Hand" + s for s in "LR"] + ["Wrist" + s for s in "LR"] + list(HEAD_ANCHORS)
    anchors = {n: D.get(pre + "Anchor_" + n) for n in names}
    rest = {n: (a.matrix_world.copy() if a else None) for n, a in anchors.items()}
    local = {n: (base_root.inverted() @ m if m is not None else None) for n, m in rest.items()}

    def rot_about(pivot, axis, degrees):
        p = Vector(pivot)
        return Matrix.Translation(p) @ Matrix.Rotation(math.radians(degrees), 4, axis) @ Matrix.Translation(-p)

    RAW.mkdir(parents=True, exist_ok=True)
    only = os.environ.get("LOADING_PALS_ONLY", "")   # comma-separated pal ids, for quick looks
    for pal in PALS:
        if pal["pet"] != pet or (only and pal["id"] not in only.split(",")):
            continue
        palette["Primary"].outputs[0].default_value = body_linear(pal["body"])
        palette["Secondary"].outputs[0].default_value = lin(HUE[pal["secondary"]]) + (1.0,)
        outfit = pal["outfit"]
        for o in wear:
            o.hide_render = outfit.get(o["slot"]) != o["item"]
        for slot, objs in SWAPS.items():
            for n in objs:
                if n in D:
                    D[n].hide_render = slot in outfit
        # Screen left is the pet's L side (-X) with the camera in front (-Y).
        sides = ["L", "R"] if pal["side"] == "both" else [pal["side"]]
        yaw = Matrix.Rotation(math.radians(pal["yaw"]), 4, "Z")
        for frame in FRAMES:
            # Pose in pet-local space, then the whole pet turns by yaw about its root.
            pose = {n: (m.copy() if m is not None else None) for n, m in local.items()}
            for s in sides:
                sign = 1 if s == "R" else -1
                hand = local["Hand" + s].translation
                dx, dy, dz = REACH[frame]
                reach = Matrix.Translation(Vector((sign * dx, dy, dz)))
                raise_ = RAISE["cheer" if pal["side"] == "both" else "wave"][frame]
                m = reach @ rot_about(hand, "Y", -sign * raise_) @ rot_about(hand, "X", -FORWARD)
                for n in ("Hand" + s, "Wrist" + s):
                    if pose[n] is not None:
                        pose[n] = m @ pose[n]
            tilt = TILT[frame]
            if tilt:
                toward = (1 if sides[0] == "R" else -1) if len(sides) == 1 else 0
                neck = Vector((0.0, -0.07, 0.63))
                m = rot_about(neck, "Y", toward * tilt)
                for n in HEAD_ANCHORS:
                    if pose[n] is not None:
                        pose[n] = m @ pose[n]
            for n, a in anchors.items():
                if a is not None:
                    a.matrix_world = base_root @ yaw @ pose[n]
            # Camera: in front of the pet (-Y), 8 deg above, looking at the body's middle.
            e = math.radians(CAM_ELEVATION)
            target = base_root @ Vector((0.0, 0.0, TARGET_Z))
            d = Vector((0.0, -math.cos(e), math.sin(e)))
            cam.location = target + d * 8.0
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(RAW / f"{pal['id']}-{frame}.png")
            bpy.ops.render.render(write_still=True)
            print("RENDERED", scene.render.filepath)
        for n, a in anchors.items():
            if a is not None:
                a.matrix_world = rest[n]


def pack_main():
    from PIL import Image, ImageFilter
    cells = []
    for frame in FRAMES:
        for pal in PALS:
            cells.append(Image.open(RAW / f"{pal['id']}-{frame}.png").convert("RGBA"))
    # One scale for every cell (feet share a baseline): the union of the opaque boxes, centred.
    boxes = [c.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox() for c in cells]
    top = min(b[1] for b in boxes); bottom = max(b[3] for b in boxes)
    half = max(max(RENDER / 2 - b[0], b[2] - RENDER / 2) for b in boxes)
    # Every render cropped to the same box around the render's centre line, feet on its bottom edge, at
    # the one scale where the tallest pal (the Bunny's ears) fills the cell height and the widest fits.
    pad = OUTLINE + GUTTER
    inner_w, inner_h = CELL_W - 2 * pad, CELL_H - 2 * pad
    scale = min(inner_h / (bottom - top), inner_w / (2 * half))
    span_w, span_h = inner_w / scale, inner_h / scale
    crop = (round(RENDER / 2 - span_w / 2), round(bottom - span_h), round(RENDER / 2 + span_w / 2), bottom)
    sheet = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
    for i, img in enumerate(cells):
        small = img.crop(crop).resize((inner_w, inner_h), Image.LANCZOS)
        cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        cell.alpha_composite(small, (pad, pad))
        alpha = cell.getchannel("A").point(lambda a: 255 if a > 40 else 0)
        ring = alpha.filter(ImageFilter.MaxFilter(OUTLINE * 2 + 1)).filter(ImageFilter.GaussianBlur(0.7))
        sticker = Image.new("RGBA", (CELL_W, CELL_H), (255, 255, 255, 0))
        sticker.putalpha(ring)
        sticker.alpha_composite(cell)
        column, row = i % len(PALS), i // len(PALS)
        sheet.alpha_composite(sticker, (column * CELL_W, row * CELL_H))
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET, optimize=True)
    # The hatless Bear's feet-to-ear-tip height as a share of the cell height: the Lua sizes cells from it.
    iris = boxes[[p["id"] for p in PALS].index("bear-iris")]
    print("SHEET", SHEET, sheet.size, "scale", round(scale, 4), "bytes", SHEET.stat().st_size,
          "bearHeight/cell", round((iris[3] - iris[1]) * scale / CELL_H, 3), "feet above cell bottom", pad)


try:
    import bpy  # noqa: F401
    blender_main()
except ImportError:
    pack_main()
