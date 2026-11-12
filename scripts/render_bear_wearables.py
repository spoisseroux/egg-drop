"""Render the Bear's wearables and compose the review sheets in artifacts/pet-attachments/final/.

Two steps (background Blender only; the .blend is never saved):
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/render_bear_wearables.py -- [--build] [--only <prefix>]
  python scripts/render_bear_wearables.py          # composes the sheets from the raw renders (needs Pillow)

--build rebuilds the wearables first (scripts/build_bear_wearables.py) without saving.
"""
import json, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "artifacts" / "pet-attachments" / "final"
RAW = OUT / "raw"

# palettes for the pet (primary, secondary), sRGB hex: shows what "tint by secondary" does
PALETTES = {"honey": ("#FFC629", "#FF9E9A"), "snow": ("#F4F1EC", "#A9B4C9"), "mint": ("#7FD9B4", "#FFE38A"),
            "berry": ("#B48CF2", "#FFC6E6"), "sky": ("#6FBDF5", "#FFF3D0"), "cocoa": ("#B9805A", "#FFDDB5")}

# view = (camera direction from the target, target (pet-local), distance)
FRONT = ((-0.30, -1.0, 0.20), (0.0, -0.02, 0.78), 4.5)
BACK = ((0.42, 1.0, 0.22), (0.0, 0.05, 0.78), 4.5)
V_HAT = ((-0.30, -1.0, 0.34), (0.0, -0.05, 1.28), 3.1)
V_SHIRT = ((-0.42, -1.0, 0.14), (0.0, -0.06, 0.56), 2.9)
V_SHIRT_BACK = ((0.55, 1.0, 0.25), (0.0, 0.02, 0.58), 2.9)
V_NECK = ((-0.25, -1.0, 0.02), (0.0, -0.20, 0.66), 2.5)
V_HELIX = ((-0.55, -1.0, 0.16), (-0.41, 0.0, 1.36), 1.45)
V_HELIX_BACK = ((-0.6, 1.0, 0.2), (-0.41, 0.0, 1.36), 1.45)
V_EYES = ((-0.16, -1.0, 0.06), (0.0, -0.40, 1.02), 2.3)
V_MOUTH = ((-0.22, -1.0, 0.04), (0.0, -0.50, 0.84), 1.25)
V_TAIL = ((0.45, 1.0, 0.25), (0.02, 0.38, 0.52), 2.5)

LINEUP = [  # item id, slot key(s), view
    ("beanie", "Hat", FRONT), ("sunhat", "Hat", FRONT), ("flowercrown", "Hat", FRONT), ("tee", "Shirt", FRONT),
    ("hoodie", "Shirt", FRONT), ("beads", "Neck", FRONT), ("bellcollar", "Neck", FRONT), ("ring", "EarPiercing", FRONT),
    ("starstud", "EarPiercing", FRONT), ("sparkle", "Eyes", FRONT), ("sleepy", "Eyes", FRONT), ("blep", "Mouth", FRONT),
    ("heart", "Tail", BACK),
]
COMBOS = [
    ("Garden Party", "honey", dict(Hat="flowercrown", Neck="beads", Eyes="sparkle", EarPiercing="starstud", Tail="heart")),
    ("Cosy Morning", "snow", dict(Hat="beanie", Shirt="hoodie", Eyes="sleepy", Mouth="blep")),
    ("Seaside", "mint", dict(Hat="sunhat", Shirt="tee", EarPiercing="ring", Mouth="blep")),
    ("Good Kitty", "berry", dict(Neck="bellcollar", Eyes="sparkle", EarPiercing="ring", Tail="heart", Shirt="tee")),
]
CLOSEUPS = {
    "03-closeup-hats": [("beanie", "Hat", V_HAT, "honey"), ("sunhat", "Hat", V_HAT, "sky"), ("flowercrown", "Hat", V_HAT, "snow")],
    "04-closeup-shirts": [("tee", "Shirt", V_SHIRT, "honey"), ("tee", "Shirt", V_SHIRT_BACK, "honey"),
                          ("hoodie", "Shirt", V_SHIRT, "mint"), ("hoodie", "Shirt", V_SHIRT_BACK, "mint")],
    "05-closeup-necklaces": [("beads", "Neck", V_NECK, "honey"), ("bellcollar", "Neck", V_NECK, "cocoa")],
    "06-closeup-helix": [("ring", "EarPiercing", V_HELIX, "honey"), ("ring", "EarPiercing", V_HELIX_BACK, "honey"),
                         ("starstud", "EarPiercing", V_HELIX, "berry"), ("starstud", "EarPiercing", V_HELIX_BACK, "berry")],
    "07-closeup-eyes": [("sparkle", "Eyes", V_EYES, "honey"), ("sparkle", "Eyes", V_EYES, "sky"), ("sleepy", "Eyes", V_EYES, "snow")],
    "08-closeup-mouth": [("blep", "Mouth", V_MOUTH, "honey"), ("blep", "Mouth", V_EYES, "berry")],
    "09-closeup-tail": [("heart", "Tail", V_TAIL, "honey"), ("heart", "Tail", ((1.0, 0.25, 0.12), (0.0, 0.25, 0.55), 3.2), "mint")],
}


def blender_main():
    import bpy
    from mathutils import Vector
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = args[args.index("--only") + 1] if "--only" in args else ""
    if "--build" in args:
        src = (REPO / "scripts" / "build_bear_wearables.py").read_text()
        exec(compile(src, "build_bear_wearables.py", "exec"), {"__name__": "build"})
    RAW.mkdir(parents=True, exist_ok=True)
    D = bpy.data.objects
    scene = bpy.context.scene
    wear = list(bpy.data.collections["PetBear_Wearables"].objects)
    for cname in ("PetBear_FeatureHorns", "PetBear_FeatureWings", "MockOnly_HornSizeLineup"):
        for o in bpy.data.collections[cname].objects:
            o.hide_render = True
    for o in D:
        if o.name.startswith("PetBear__CharmDot"):
            o.hide_render = True        # a new pet has no charm
    base = D["PetBear"].matrix_world.translation.copy()
    cam = bpy.data.objects.new("WearCam", bpy.data.cameras.new("WearCam"))
    scene.collection.objects.link(cam)
    cam.data.lens = 85
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    palette = bpy.data.node_groups["PetPalette"].nodes

    def lin(hexcode):
        h = hexcode.lstrip("#")
        f = lambda c: (c / 255 / 12.92) if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4
        return (f(int(h[0:2], 16)), f(int(h[2:4], 16)), f(int(h[4:6], 16)), 1.0)

    SWAPS = {"Eyes": ["PetBear__EyeL", "PetBear__EyeR"], "Mouth": ["PetBear__Mouth"], "Tail": ["PetBear__Tail"]}
    meta = {}

    def shot(name, outfit, view, pal="honey"):
        if only and not name.startswith(only):
            return
        palette["Primary"].outputs[0].default_value = lin(PALETTES[pal][0])
        palette["Secondary"].outputs[0].default_value = lin(PALETTES[pal][1])
        for o in wear:
            o.hide_render = outfit.get(o["slot"]) != o["item"]
        for slot, names in SWAPS.items():
            for n in names:
                D[n].hide_render = slot in outfit
        direction, target, dist = view
        d = Vector(direction).normalized()
        cam.location = base + Vector(target) + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(RAW / (name + ".png"))
        bpy.ops.render.render(write_still=True)

    for item, slot, view in LINEUP:
        shot("lineup-" + item, {slot: item}, view)
    shot("lineup-bare", {}, FRONT)
    for i, (title, pal, outfit) in enumerate(COMBOS):
        shot(f"combo-{i}-front", outfit, FRONT, pal)
        shot(f"combo-{i}-back", outfit, BACK, pal)
    for sheet, tiles in CLOSEUPS.items():
        for i, (item, slot, view, pal) in enumerate(tiles):
            shot(f"{sheet}-{i}", {slot: item}, view, pal)
    for o in wear:
        row = meta.setdefault(o["item"], dict(name=o["displayName"], slot=o["slot"], tier=o["tier"], price=o["price"], tris=0,
                                              tint=False))
        row["tris"] += o["tris"]
        row["tint"] = row["tint"] or bool(o["tintBySecondary"])
    (RAW / "items.json").write_text(json.dumps(meta, indent=1))
    print("RENDERED ->", RAW)


def compose_main():
    from PIL import Image, ImageDraw, ImageFont
    meta = json.loads((RAW / "items.json").read_text())

    def font(size, bold=True):
        for f in (("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")):
            try:
                return ImageFont.truetype("C:/Windows/Fonts/" + f, size)
            except OSError:
                pass
        return ImageFont.load_default()

    BG, INK, SOFT = (253, 247, 238), (70, 52, 44), (150, 128, 116)
    TIER = {"common": (120, 190, 140), "rare": (104, 160, 240), "showcase": (240, 150, 70)}
    TILE_BG = [(255, 232, 214), (222, 240, 226), (226, 234, 250), (250, 228, 238), (252, 240, 204)]

    def tile(raw, size, colour, title=None, sub=None, tier=None, price=None):
        im = Image.new("RGB", (size, size + (74 if title else 0)), BG)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((0, 0, size - 1, size - 1), 28, fill=colour)
        shot = Image.open(RAW / (raw + ".png")).convert("RGBA").resize((size, size), Image.LANCZOS)
        im.paste(shot, (0, 0), shot)
        if title:
            d.text((8, size + 8), title, font=font(24), fill=INK)
            d.text((8, size + 40), sub, font=font(17, False), fill=SOFT)
            if tier:
                label = f"{tier} · {price} Stars"
                w = d.textlength(label, font=font(16))
                d.rounded_rectangle((size - w - 44, size + 10, size - 4, size + 38), 14, fill=TIER[tier])
                d.text((size - w - 34, size + 13), label, font=font(16), fill=(255, 255, 255))
        return im

    def sheet(name, heading, note, tiles, cols, gap=22, pad=36):
        tw, th = tiles[0].size
        rows = (len(tiles) + cols - 1) // cols
        W = pad * 2 + cols * tw + (cols - 1) * gap
        H = pad + 96 + rows * th + (rows - 1) * gap + pad
        im = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(im)
        d.text((pad, pad - 8), heading, font=font(40), fill=INK)
        d.text((pad, pad + 44), note, font=font(19, False), fill=SOFT)
        for i, t in enumerate(tiles):
            r, c = divmod(i, cols)
            in_row = min(cols, len(tiles) - r * cols)
            x0 = pad + (W - pad * 2 - (in_row * tw + (in_row - 1) * gap)) // 2
            im.paste(t, (x0 + c * (tw + gap), pad + 96 + r * (th + gap)))
        OUT.mkdir(parents=True, exist_ok=True)
        im.save(OUT / (name + ".png"))
        print("SHEET", OUT / (name + ".png"), im.size)

    def sub(i):
        m = meta[i]
        return f"{m['slot']} \u00b7 {m['tris']} tris" + (" \u00b7 tints with secondary" if m["tint"] else "")

    tiles = [tile("lineup-" + item, 360, TILE_BG[i % 5], meta[item]["name"], sub(item), meta[item]["tier"], meta[item]["price"])
             for i, (item, slot, view) in enumerate(LINEUP)]
    sheet("01-lineup", "Bear wearables: launch set", "13 collectibles, one per tile, on the plain Bear. Heart Tail is shown from behind.",
          tiles, 5)
    tiles = []
    for i, (title, pal, outfit) in enumerate(COMBOS):
        names = ", ".join(meta[v]["name"] for v in outfit.values())
        names = names if len(names) < 50 else names[:names.rfind(",", 0, 50)] + " and more"
        for side in ("front", "back"):
            t = tile(f"combo-{i}-{side}", 430, TILE_BG[i % 5], title if side == "front" else " ", names if side == "front" else f"{pal} palette, from behind")
            tiles.append(t)
    sheet("02-combos", "Outfits", "Four mixes on four pet palettes. Secondary-tinted pieces pick up each pet's second colour.", tiles, 4)
    HEAD = {"03-closeup-hats": "Hats", "04-closeup-shirts": "Shirts (torso + two sleeves)", "05-closeup-necklaces": "Necklaces",
            "06-closeup-helix": "Helix piercings (a pair, one per ear)", "07-closeup-eyes": "Eyes", "08-closeup-mouth": "Mouth",
            "09-closeup-tail": "Tail"}
    for name, rows in CLOSEUPS.items():
        tiles = [tile(f"{name}-{i}", 480, TILE_BG[i % 5], meta[item]["name"], sub(item), meta[item]["tier"], meta[item]["price"])
                 for i, (item, slot, view, pal) in enumerate(rows)]
        sheet(name, HEAD[name], "Close-up, slot by slot.", tiles, len(tiles))


try:
    import bpy  # noqa: F401
    blender_main()
except ImportError:
    compose_main()
