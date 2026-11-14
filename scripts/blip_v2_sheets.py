"""Lay out the Blip v2 concept sheets from scripts/build_blip_v2.py renders (plain Python + Pillow).
  python scripts/blip_v2_sheets.py artifacts/blip-v2-2026-11-14
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

DIR = Path(sys.argv[1])
RAW = DIR / "raw"
BG, INK = (196, 200, 214), (40, 44, 60)
NAMES = {"A": "A  Bean", "B": "B  Saucer", "C": "C  Sprout", "bear": "Bear", "v1": "Blip v1"}


def font(size):
    try:
        return ImageFont.truetype("arialbd.ttf", size)
    except OSError:
        return ImageFont.load_default()


def tile(tag, view):
    return Image.open(RAW / f"{tag}-{view}.png").convert("RGBA")


# ---- contact sheet: each variant beside the Bear, front / three-quarter / side
TW, TH, LAB, HEAD = 288, 384, 120, 44
sheet = Image.new("RGB", (LAB + 6 * TW, HEAD + 3 * TH), BG)
d = ImageDraw.Draw(sheet)
for j, view in enumerate(("front", "three-quarter", "side")):
    d.text((LAB + j * 2 * TW + TW - 60, 10), view, font=font(22), fill=INK)
for i, tag in enumerate("ABC"):
    y = HEAD + i * TH
    d.text((10, y + TH // 2 - 14), NAMES[tag], font=font(20), fill=INK)
    if i:
        d.line((0, y, sheet.width, y), fill=(170, 174, 190), width=2)
    for j, view in enumerate(("front", "q", "side")):
        for k, who in enumerate(("bear", tag)):
            im = tile(who, view).crop((64, 0, 448, 512)).resize((TW, TH), Image.LANCZOS)
            sheet.paste(im, (LAB + (2 * j + k) * TW, y), im)
sheet.save(DIR / "blip-v2-contact-sheet.png")

# ---- phone sheet: true 96 px tiles and silhouettes, then the same pixels enlarged 3x
tags = ("bear", "v1", "A", "B", "C")
P, Z = 96, 3
W = P * Z
sheet = Image.new("RGB", (len(tags) * W, 30 + P + P + 2 * W), BG)
d = ImageDraw.Draw(sheet)
for i, tag in enumerate(tags):
    im = tile(tag, "phone")
    sil = Image.new("RGBA", im.size, INK + (255,))
    sil.putalpha(im.getchannel("A").point(lambda a: 255 if a > 127 else 0))
    x = i * W
    d.text((x + 8, 5), NAMES[tag], font=font(18), fill=INK)
    sheet.paste(im, (x + W // 2 - P, 30), im)
    sheet.paste(sil, (x + W // 2, 30), sil)
    big, bigs = im.resize((W, W), Image.NEAREST), sil.resize((W, W), Image.NEAREST)
    sheet.paste(big, (x, 30 + P), big)
    sheet.paste(bigs, (x, 30 + P + W), bigs)
sheet.save(DIR / "blip-v2-phone-96px-silhouettes.png")
print("SHEETS", DIR)
