"""Dewdrop thumbnails and ads in icon J's look (Spencer picked J, 2026-11-21).

All drawn in code (numpy + PIL) from our own Studio cut-outs in ../captures (S12 Bear, S13 Rose
Bunny, S14 Bunny hop) and icon J's parts in ../icons/build_icons.py: the Aero "pocket pals"
wordmark, the Cloud Glass deck with the Bubbles-theme screen, the Sky field, bubbles and shadows.
No AI imagery, no third-party images.

  thumb-1-lineup.png   1920x1080  thumbnail 1 and Ad A: the line-up (ART-DIRECTION.md)
  ad-C-skyhop.png      1920x1080  Ad C: sky hop, one 12 degree diagonal, Sky over Leaf
  *-480.png            480x270 checks (the size ads and thumbnails show at in lists)

Run: python build_thumbs.py
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "icons"))
sys.path.insert(0, os.path.join(HERE, "..", "captures"))
import build_icons as bi  # noqa: E402
import cutout  # noqa: E402

W, H = 1920, 1080
CAP = bi.CAP


def deck_3q(width, yaw=18.0, pitch=8.0):
    """The icon's deck (Cloud Glass, Bubbles screen) turned three-quarter like S4."""
    flat = bi.deck_with_hero(bi.bubbles_screen)
    d = cutout.three_quarter(flat, yaw=yaw, pitch=pitch)
    return d.resize((width, round(d.height * width / d.width)), Image.LANCZOS)


def tag_text(text, size, italic=False, fill=(255, 255, 255), stroke=7):
    f = ImageFont.truetype(bi.font_path("Nunito-BlackItalic.ttf" if italic else "Nunito-Black.ttf"), size)
    x0, y0, x1, y1 = f.getbbox(text, stroke_width=stroke)
    im = Image.new("RGBA", (x1 - x0 + 40, y1 - y0 + 40), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((20 - x0, 20 - y0), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=bi.rgb("#0B3C9C"))
    sh = Image.new("RGBA", im.size, bi.INK + (0,))
    sh.putalpha(im.getchannel("A").point(lambda v: int(v * 0.45)).filter(ImageFilter.GaussianBlur(6)))
    out = Image.new("RGBA", (im.width, im.height + 8), (0, 0, 0, 0))
    out.alpha_composite(sh, (0, 8))
    out.alpha_composite(im, (0, 0))
    return out


def wordmark(width):
    wm = bi.aero_wordmark(lead=0.72, outline=5, depth=7, indent=(0.0, 1.05))
    return wm.resize((width, round(wm.height * width / wm.width)), Image.LANCZOS)


def pet(name, scale, cool=0.16):
    return bi.relight(bi.load(os.path.join(CAP, name + ".png"), scale), cool=cool)


def thumb_lineup():
    """Thumbnail 1 = Ad A. Sky field; the Bear (S12) left of centre, the Rose Bunny (S13) beside
    and a step behind, the deck low on the floor at right with a reflection; the wordmark and
    "merge · hatch · train" top left."""
    c = bi.field(*bi.SKY, floor=0.80, w=W, h=H)
    bi.put_bubble(c, 1760, 150, 170)
    bi.put_bubble(c, 1580, 90, 60, 0.9)
    floor = int(H * 0.80)
    bun = pet("S13", 1.10)
    bear = pet("S12", 1.22)
    bx = 1180
    bun_xy = (bx + 120, floor + 30 - bun.height)
    bi.contact(c, bun_xy[0] + bun.width / 2, floor + 22, bun.width * 0.34, 16, alpha=70, blur=14)
    bi.paste(c, bun, bun_xy)
    bear_xy = (bx - bear.width + 110, floor + 70 - bear.height)
    bi.contact(c, bear_xy[0] + bear.width / 2, floor + 62, bear.width * 0.36, 18, alpha=80, blur=14)
    bi.soft_shadow(c, bear, bear_xy, dx=16, dy=8, blur=18, alpha=0.22)
    bi.paste(c, bear, bear_xy)
    deck = deck_3q(520)
    dxy = (W - deck.width - 40, floor + 150 - deck.height)
    foot = dxy[1] + deck.height - 22
    bi.contact(c, dxy[0] + deck.width / 2, foot, deck.width * 0.40, 22, alpha=100, blur=18)
    bi.reflect(c, deck, dxy[0], foot - 10, strength=0.22, frac=0.20)
    bi.soft_shadow(c, deck, dxy, dx=-14, dy=10, blur=14, alpha=0.36)
    bi.paste(c, deck, dxy)
    wm = wordmark(760)
    bi.paste(c, wm, (60, 130))
    tag = tag_text("merge · hatch · train", 84)
    bi.paste(c, tag, (84, 130 + wm.height + 4))
    return c


def diagonal_field(angle=12.0, split=0.80):
    """Sky above, Leaf below, divided by one line rising `angle` degrees to the right, with a
    glossy bright lip along the grass edge."""
    sky = np.asarray(bi.field(*bi.SKY, floor=1.0, w=W, h=H).convert("RGB")).astype(np.float32)
    leaf = np.asarray(bi.field("#5BD46A", "#1E9E3A", floor=1.0, w=W, h=H).convert("RGB")).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = np.tan(np.radians(angle))
    line = H * split - (xx - W / 2) * t
    dist = yy - line
    m = np.clip(dist / 2.0 + 0.5, 0, 1)[..., None]
    img = sky * (1 - m) + leaf * m
    lip = np.exp(-((dist - 10) / 9) ** 2)[..., None] * (dist > 0)[..., None]
    img = img + (255 - img) * lip * 0.55
    return Image.fromarray(img.clip(0, 255).astype(np.uint8)).convert("RGBA"), line


def hop_path(c, x0, y0, x1, y1, lift=220, n=9):
    """White dots along the hop's arc, from take-off (x0, y0) up to the subject's feet (x1, y1),
    growing as they near her."""
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        t = (i + 0.5) / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t - lift * 4 * t * (1 - t)
        r = 6 + 9 * t
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, int(120 + 120 * t)))
    c.alpha_composite(layer)


def ad_skyhop():
    """Ad C. One 12 degree diagonal, Sky above and Leaf below. The Rose Bunny (S14) mid-hop top
    right, the Bear (S12) lower centre looking her way. Italic "your pocket pets" top left, the
    wordmark as the tag bottom right. No deck: this is the energy test."""
    c, line = diagonal_field()
    bi.put_bubble(c, 1820, 110, 120)
    bi.put_bubble(c, 1180, 340, 56, 0.9)
    bun = bi.relight(bi.load(os.path.join(CAP, "S14.png"), 0.92, rot=-10), cool=0.14)
    bear = pet("S12", 1.10)
    # Bear standing on the grass line, lower centre.
    tilt = np.tan(np.radians(12))
    bx = 700
    ground_b = int(H * 0.80 - (bx - W / 2) * tilt) + 70
    bear_xy = (bx - bear.width // 2, ground_b - bear.height)
    bi.contact(c, bx, ground_b - 8, bear.width * 0.36, 18, alpha=90, blur=14)
    bi.paste(c, bear, bear_xy)
    # Bunny up in the air, top right, her shadow far below on the grass.
    ux = 1450
    ground_u = int(H * 0.80 - (ux - W / 2) * tilt) + 40
    bun_xy = (ux - bun.width // 2, 40)
    bi.contact(c, ux, ground_u, bun.width * 0.30, 14, alpha=110, blur=16)
    hop_path(c, 1060, int(H * 0.80 - (1060 - W / 2) * tilt) + 30, ux, bun_xy[1] + bun.height + 10, lift=220)
    bi.paste(c, bun, bun_xy)
    head = tag_text("your pocket pets", 120, italic=True)
    bi.paste(c, head, (70, 60))
    wm = wordmark(470)
    bi.paste(c, wm, (W - wm.width - 50, H - wm.height - 40))
    return c


if __name__ == "__main__":
    for name, fn in (("thumb-1-lineup", thumb_lineup), ("ad-C-skyhop", ad_skyhop)):
        im = fn().convert("RGB")
        im.save(os.path.join(HERE, name + ".png"))
        im.resize((480, 270), Image.LANCZOS).save(os.path.join(HERE, name + "-480.png"))
    print("wrote thumb-1-lineup.png, ad-C-skyhop.png (+ -480 checks)")
