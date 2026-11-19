"""Pocket Pals: Pet Garden, store page v2 (icons + thumbnails).

Every picture element is a Roblox Studio Play capture of place 96451847774961
(raw/, 2026-11-19, plus the ad-v1 captures of 2026-11-18). Subjects were shot twice
with the frame frozen, over a black and a light backdrop, and cut out by difference
matting (helpers shared with ../ad-v1/build_ad.py). The only additions are text in the
game's own Roblox fonts, sticker outlines, shadows, rays, gradients and a colour grade.
No generated or stock imagery.

Run: python artifacts/store-listing/v2/build_v2.py
Writes layers/, icon/, thumbnails/ and contact-sheet.png.
"""
import importlib.util
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
LAYERS = os.path.join(HERE, "layers")
AD = os.path.join(HERE, "..", "ad-v1")
V1 = os.path.join(HERE, "..", "v1")

_spec = importlib.util.spec_from_file_location("build_ad", os.path.join(AD, "build_ad.py"))
ad = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ad)

W, H = 1920, 1080
INK = (22, 14, 40)
CREAM = (255, 246, 222)
GOLD = (255, 196, 64)
MINT = (118, 246, 176)
WHITE = (255, 255, 255)

scale, outline, padded, shadow = ad.scale, ad.outline, ad.padded, ad.shadow
paste_clip, screen, rays, radial, trim, keep_solid = ad.paste_clip, ad.screen, ad.rays, ad.radial, ad.trim, ad.keep_solid


def raw(name):
    return os.path.join(RAW, name)


def matte(black, light, box=None):
    return ad.matte(raw(black), raw(light), box=box)


def fill_holes(mask):
    """Binary mask (bool array) with enclosed holes filled (flood from the border)."""
    h, w = mask.shape
    img = Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), "L")
    big = Image.new("L", (w + 2, h + 2), 0)
    big.paste(img, (1, 1))
    ImageDraw.floodfill(big, (0, 0), 128)
    out = np.asarray(big)[1:-1, 1:-1]
    return out != 128


def solid(black, light, box, source="light"):
    """Cut-out for see-through subjects (glass jars, the Jelly finish): the silhouette comes
    from the difference matte, the colour from one capture, fully opaque inside."""
    m = matte(black, light, box=box)
    a = np.asarray(m.getchannel("A")).astype(np.float32) / 255
    hull = fill_holes(a > 0.22)
    hull_img = Image.fromarray(np.where(hull, 255, 0).astype(np.uint8), "L")
    hull_img = hull_img.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    src = Image.open(raw(light if source == "light" else black)).convert("RGB").crop(box)
    out = src.convert("RGBA")
    out.putalpha(hull_img)
    return out


def harden(img, lo=0.5, hi=0.9):
    """Push soft matte alpha to opaque inside the body (JPEG noise leaves 0.9-0.97 patches)."""
    a = np.asarray(img.getchannel("A")).astype(np.float32) / 255
    a = np.clip((a - lo) / (hi - lo), 0, 1)
    hull = fill_holes(a > 0.6)
    a = np.where(hull, np.maximum(a, 1.0), a)
    out = img.copy()
    out.putalpha(Image.fromarray((a * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.6)))
    return out


def lcd_key(rgb, seeds=()):
    """Key a merge cluster off the deck LCD: flood-fill dark low-saturation pixels from the
    crop's edges only, so the balls' dark eyes, mouths and outlines survive."""
    sat = rgb.max(2) - rgb.min(2)
    cand = (rgb.max(2) < 112) & (sat < 46)
    bg = np.zeros_like(cand)
    bg[0, :], bg[-1, :], bg[:, 0], bg[:, -1] = cand[0, :], cand[-1, :], cand[:, 0], cand[:, -1]
    for (x0, y0, x1, y1) in seeds:
        bg[y0:y1, x0:x1] |= cand[y0:y1, x0:x1]
    while True:
        grown = bg.copy()
        grown[1:, :] |= bg[:-1, :]; grown[:-1, :] |= bg[1:, :]; grown[:, 1:] |= bg[:, :-1]; grown[:, :-1] |= bg[:, 1:]
        grown &= cand
        if (grown == bg).all():
            break
        bg = grown
    a = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8), "L")
    a = a.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
    pop = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    pop.putalpha(a)
    return trim(keep_solid(pop, threshold=200, grow=1), 1)


# ---------------------------------------------------------------- layers


def build_layers():
    os.makedirs(LAYERS, exist_ok=True)
    L = {}

    # Bears: client-only PetFactory Bears with real catalogue colours, finishes and wearables,
    # frozen in rig poses (wave, cheer, sit, stand) over black and light Neon backdrops.
    thirds = [(0, 0, 550, 734), (550, 0, 1085, 734), (1085, 0, 1649, 734)]
    for name, box in zip(("bear_white", "bear_tide", "bear_mint"), thirds):
        L[name] = trim(harden(matte("bears1-black.jpg", "bears1-grey.jpg", box=box)))
    for name, box in zip(("bear_rose", "bear_citrus"), thirds[:2]):
        L[name] = trim(harden(matte("bears2-black.jpg", "bears2-grey.jpg", box=box)))
    L["bear_iris"] = trim(solid("bears2-black.jpg", "bears2-grey.jpg", thirds[2]))  # Jelly finish
    halves = [(0, 0, 825, 734), (825, 0, 1649, 734)]
    for name, box in zip(("close_white", "close_tide"), halves):
        L[name] = trim(harden(matte("closeup-black.jpg", "closeup-grey.jpg", box=box)))
    for name, box in zip(("close_rose", "close_white_sparkle"), halves):
        L[name] = trim(harden(matte("closeup2-black.jpg", "closeup2-grey.jpg", box=box)))

    # Eggs: Shared.EggModels meshes and colour maps (Toy Egg, Customization Egg, Companion Egg),
    # the open ones in the hatch pose over their Neon core.
    eggs = {"egg_toy_open": (0, 120, 340, 640), "egg_look_open": (350, 120, 700, 640), "egg_toy": (730, 220, 1050, 640),
            "egg_look": (1060, 220, 1370, 640), "egg_companion_open": (1372, 160, 1649, 640)}
    for name, box in eggs.items():
        L[name] = trim(harden(matte("eggs-black.jpg", "eggs-grey.jpg", box=box)), 2)

    # Toys (PetToyGeometry) and Customization jars (JarModel).
    toys = {"toy_ball": (30, 60, 285, 300), "toy_bone": (285, 90, 575, 270), "toy_sparkler": (630, 20, 745, 320),
            "toy_top": (850, 20, 1065, 300), "toy_carrot": (1135, 30, 1355, 290), "toy_deck": (1370, 120, 1615, 250)}
    for name, box in toys.items():
        L[name] = trim(harden(matte("toys-black.jpg", "toys-grey.jpg", box=box)), 2)
    jars = {"jar_tide": (215, 10, 500, 290), "jar_iris": (685, 10, 965, 290), "jar_jelly": (1130, 35, 1445, 365),
            "jar_citrus": (450, 335, 735, 610), "jar_charm": (1380, 370, 1649, 670)}
    for name, box in jars.items():
        L[name] = trim(solid("jars-black.jpg", "jars-grey.jpg", box, source="black"), 2)

    # Pocket Decks, each a real round frozen on a merge: Night Orb + Kittens (x2), Sorbet Sky +
    # Gems (x3), and from ad-v1 Prism Flare + Smileys (x3) and Scout + Smileys (x4).
    box = (150, 55, 1520, 734)
    L["deck_night"] = matte("deck-nightorb-kittens-black.jpg", "deck-nightorb-kittens-white.jpg", box=box)
    L["deck_sorbet"] = matte("deck-sorbet-gems-chain3-black.jpg", "deck-sorbet-gems-chain3-white.jpg", box=box)
    L["deck_prism"] = Image.open(os.path.join(AD, "layers", "deck.png")).convert("RGBA")
    L["deck_scout"] = ad.matte("deck-chain4-black.jpg", "deck-chain4-white.jpg", box=(270, 60, 1650, 777))
    k = ad.load(raw("deck-sorbet-gems-chain3-black.jpg"))[478:628, 692:956]
    L["pop_gems"] = lcd_key(k)
    k = ad.load(raw("deck-nightorb-kittens-black.jpg"))[515:628, 706:940]
    L["pop_kittens"] = lcd_key(k)
    L["pop_smileys"] = Image.open(os.path.join(AD, "layers", "merge_pop.png")).convert("RGBA")

    for n in "abcde":
        L["star_" + n] = Image.open(os.path.join(AD, "layers", "star_%s.png" % n)).convert("RGBA")

    for name, img in L.items():
        img.save(os.path.join(LAYERS, name + ".png"))
    return L


def layer_sheet(L, path):
    names = sorted(L)
    cell = 300
    cols = 8
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cols * cell, rows * cell), (90, 60, 120))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = L[n].copy()
        im.thumbnail((cell - 20, cell - 40))
        x, y = (i % cols) * cell + 10, (i // cols) * cell + 10
        sheet.paste(im, (x, y), im)
        d.text((x, y + cell - 34), n, fill=(255, 255, 255))
    sheet.save(path)


if __name__ == "__main__":
    import sys
    L = build_layers()
    if "--layers" in sys.argv:
        layer_sheet(L, os.path.join(os.environ.get("TEMP", HERE), "v2-layer-sheet.jpg"))
        print("layers ok")
        raise SystemExit
    import compose_v2
    compose_v2.main(L)
