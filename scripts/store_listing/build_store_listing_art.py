"""Build the Roblox listing icon options and 1920x1080 thumbnails for Egg Drop.

Inputs are only real Roblox Studio captures in artifacts/store-listing/raw/ (Play mode,
place 96451847774961, 2026-11-13) and the game's own type (Builder Extended Bold and
Fredoka One, both shipped with Roblox) and UI palette (DeckKit.lua). No generated imagery.

Studio returns captures at 1920x813 (the 2107x893 viewport scaled down), so each
thumbnail is a 16:9 crop of 1445x813 scaled up 1.33x with Lanczos. Re-shoot at native
1080p in the Roblox player if crisper thumbnails are wanted.

Run: python scripts/store_listing/build_store_listing_art.py
"""
import glob
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "artifacts", "store-listing", "raw")
OUT_THUMBS = os.path.join(ROOT, "artifacts", "store-listing", "thumbnails")
OUT_ORIG = os.path.join(OUT_THUMBS, "originals")
OUT_ICON = os.path.join(ROOT, "artifacts", "store-listing", "icon")

# DeckKit.lua palette
INK = (14, 15, 18)
STARS = (255, 193, 77)
MINT = (118, 246, 176)
PANEL = (21, 37, 37)
CREAM = (255, 244, 220)


def roblox_font(name):
    hits = sorted(glob.glob(os.path.expanduser(
        "~/AppData/Local/Roblox/Versions/*/content/fonts/" + name)))
    if not hits:
        raise SystemExit("Roblox font not found: " + name)
    return hits[-1]


EXTENDED = roblox_font("BuilderExtended-Bold.otf")
FREDOKA = roblox_font("FredokaOne-Regular.ttf")
SANS = roblox_font("BuilderSans-Bold.otf")

# (output name, raw file, crop centre x in the 1920-wide capture, caption or None)
THUMBS = [
    ("01-pocket-deck-round", "deck-round-chain3.jpg", 960, "Merge balls on your Pocket Deck"),
    ("02-results-stars", "results-tidy-win-STAGED-no-pass-rows.jpg", 960, "Win rounds, earn Stars"),
    ("03-hatch-bear", "hatch-reveal-a.jpg", 1190, "Hatch your own baby Bear"),
    ("04-garden-dusk", "garden-vista.jpg", 820, "Roam the dusk garden together"),
    ("05-pet-park", "park-slide-a.jpg", 723, "Your pet plays in the Pet Park"),
    ("06-dress-up", "garden-bear-dressed.jpg", 1120, "Dress your Bear up"),
    ("07-wardrobe", "wardrobe-pom-beanie.jpg", 960, "Hats, collars and more, at fixed prices"),
    ("08-deck-style", "deck-style-faceplates.jpg", 960, "Style your deck. Looks only."),
    ("09-hatch-odds", "hatch-eggs-odds.jpg", 960, "Odds shown before every hatch"),
    ("10-ball-styles", "deck-style-balls-kittens.jpg", 960, "Ball styles: just for looks"),
]


def crop16x9(img, cx):
    w, h = img.size
    cw = round(h * 16 / 9)
    x0 = max(0, min(w - cw, round(cx - cw / 2)))
    return img.crop((x0, 0, x0 + cw, h))


def upscale(img, size=(1920, 1080)):
    big = img.resize(size, Image.LANCZOS)
    return big.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def caption(img, text):
    """One short caption in the game's own pill style: dark panel, mint dot, Fredoka One.
    Kept in the upper-left third, away from the bottom edge where Roblox overlays metadata."""
    d = ImageDraw.Draw(img, "RGBA")
    font = ImageFont.truetype(FREDOKA, 52)
    pad_x, pad_y, dot = 34, 20, 18
    tw = d.textlength(text, font=font)
    box_w = int(tw + pad_x * 2 + dot + 20)
    box_h = 52 + pad_y * 2
    x, y = 56, 52
    d.rounded_rectangle((x + 4, y + 6, x + box_w + 4, y + box_h + 6), radius=box_h // 2, fill=(0, 0, 0, 90))
    d.rounded_rectangle((x, y, x + box_w, y + box_h), radius=box_h // 2, fill=PANEL + (232,),
                        outline=(141, 190, 172, 120), width=2)
    cy = y + box_h // 2
    d.ellipse((x + pad_x, cy - dot // 2, x + pad_x + dot, cy + dot // 2), fill=MINT)
    d.text((x + pad_x + dot + 20, cy), text, font=font, fill=(255, 255, 255), anchor="lm")
    return img


def build_thumbs():
    os.makedirs(OUT_ORIG, exist_ok=True)
    for name, src, cx, text in THUMBS:
        raw = Image.open(os.path.join(RAW, src)).convert("RGB")
        clean = upscale(crop16x9(raw, cx))
        clean.save(os.path.join(OUT_ORIG, name + ".png"))
        shutil.copyfile(os.path.join(RAW, src), os.path.join(OUT_ORIG, name + "__studio-capture.jpg"))
        if text:
            caption(clean.copy(), text).save(os.path.join(OUT_THUMBS, name + ".png"))


def wordmark(size_px, img, centre_y, max_w):
    """'EGG DROP' set in Builder Extended Bold (the game's celebration face) as a tilted
    sticker: cream fill, ink outline, gold underline, like the in-game result banners."""
    font_size = size_px
    while True:
        font = ImageFont.truetype(EXTENDED, font_size)
        probe = ImageDraw.Draw(img)
        bbox = probe.textbbox((0, 0), "EGG DROP", font=font, stroke_width=max(4, font_size // 9))
        if bbox[2] - bbox[0] <= max_w or font_size < 20:
            break
        font_size -= 2
    stroke = max(4, font_size // 9)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    layer = Image.new("RGBA", (w + 80, h + 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((40 - bbox[0] + 5, 40 - bbox[1] + 7), "EGG DROP", font=font, fill=INK + (150,),
           stroke_width=stroke, stroke_fill=INK + (150,))
    d.text((40 - bbox[0], 40 - bbox[1]), "EGG DROP", font=font, fill=CREAM,
           stroke_width=stroke, stroke_fill=INK)
    uy = 40 + h + stroke + 4
    d.rounded_rectangle((44, uy, 40 + w - 4, uy + max(5, font_size // 10)), radius=4, fill=STARS,
                        outline=INK, width=2)
    layer = layer.rotate(4, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (img.width // 2 - layer.width // 2, centre_y - layer.height // 2))
    return img


def square(raw, cx, cy, side):
    half = side // 2
    return raw.crop((cx - half, cy - half, cx + half, cy + half)).resize((512, 512), Image.LANCZOS)


def build_icons():
    os.makedirs(OUT_ICON, exist_ok=True)
    # A: the hatch reveal spotlight (black and gold), Bear centred.
    raw = Image.open(os.path.join(RAW, "hatch-reveal-a.jpg")).convert("RGB")
    a = square(raw, 800, 405, 560).convert("RGBA")
    a.save(os.path.join(OUT_ICON, "icon-a-hatch-spotlight-notext.png"))
    wordmark(78, a.copy(), 446, 440).save(os.path.join(OUT_ICON, "icon-a-hatch-spotlight.png"))

    # B: the dressed Bear holding its Sparkler in the dusk garden.
    raw = Image.open(os.path.join(RAW, "bear-portrait-sparkler-a.jpg")).convert("RGB")
    b = square(raw, 955, 545, 536).convert("RGBA")
    b.save(os.path.join(OUT_ICON, "icon-b-garden-sparkler-notext.png"))
    wordmark(66, b.copy(), 62, 400).save(os.path.join(OUT_ICON, "icon-b-garden-sparkler.png"))

    # C: the Pocket Deck mid-round, with the Bear in a sticker badge (Kit.Sticker style).
    raw = Image.open(os.path.join(RAW, "deck-round-chain3.jpg")).convert("RGB")
    c = square(raw, 958, 440, 760).convert("RGBA")
    bear_src = Image.open(os.path.join(RAW, "hatch-reveal-a.jpg")).convert("RGB")
    bear = bear_src.crop((640, 230, 960, 550)).resize((206, 206), Image.LANCZOS)
    mask = Image.new("L", bear.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, 205, 205), fill=255)
    badge = Image.new("RGBA", (232, 232), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bd.ellipse((4, 8, 231, 231), fill=(0, 0, 0, 110))
    bd.ellipse((0, 0, 225, 225), fill=CREAM + (255,))
    badge.paste(bear, (10, 10), mask)
    badge = badge.rotate(-4, resample=Image.BICUBIC, expand=True)
    c.alpha_composite(badge, (512 - badge.width - 6, 512 - badge.height - 4))
    c.save(os.path.join(OUT_ICON, "icon-c-pocket-deck-bear-notext.png"))
    wordmark(70, c.copy(), 66, 420).save(os.path.join(OUT_ICON, "icon-c-pocket-deck-bear.png"))

    # Preview sheet: each option at 512 and at the 150 px size Roblox uses in lists.
    names = ["icon-a-hatch-spotlight", "icon-b-garden-sparkler", "icon-c-pocket-deck-bear"]
    sheet = Image.new("RGB", (3 * 560 + 40, 512 + 220), PANEL)
    sd = ImageDraw.Draw(sheet)
    lab = ImageFont.truetype(SANS, 26)
    for i, n in enumerate(names):
        im = Image.open(os.path.join(OUT_ICON, n + ".png")).convert("RGB")
        x = 40 + i * 560
        sheet.paste(im, (x, 40))
        small = im.resize((150, 150), Image.LANCZOS)
        sheet.paste(small, (x, 40 + 512 + 20))
        sd.text((x + 170, 40 + 512 + 30), n.replace("icon-", "").replace("-", " "), font=lab, fill=(255, 255, 255))
        sd.text((x + 170, 40 + 512 + 70), "150 px preview", font=lab, fill=(141, 190, 172))
    sheet.save(os.path.join(OUT_ICON, "icon-options-preview.png"))


if __name__ == "__main__":
    build_thumbs()
    build_icons()
    print("done")
