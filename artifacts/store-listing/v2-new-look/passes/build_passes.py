"""Store icons for the 2 game passes and 5 Star products (src/shared/StoreCatalog.lua).

Same look as the live icon (../icons/icon-J.png) and the thumbnail set (../set): Sky field,
soft glow, glass bubbles, sparkles, the Aero wordmark for every number. The Stars are the
game's own 3D Star token renders (../../ad-v1/layers/star_*.png); the Bear is our Studio
cut-out (../captures). Containers, heart, rays and type are drawn here in code (numpy + PIL).
No AI imagery, no third-party images.

Each icon is composed on a 1024 canvas and reduced to 512. Pass icons are shown cropped to a
circle in the Roblox store, so their content stays inside SAFE (84% of the inscribed circle).

Run: python build_passes.py [key ...]
 ->  doubleStars.png supporter.png starter.png handful.png pouch.png jar.png chest.png contact.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "icons"))
import build_icons as bi  # noqa: E402

M = bi.M
INK = bi.INK
NAVY = bi.rgb("#0B3C9C")
CAP = bi.CAP
LAYERS = os.path.join(HERE, "..", "..", "ad-v1", "layers")
SAFE = 0.84  # of the inscribed circle's radius

VIOLET = ("#D6BCFF", "#7C50E2")
VIOLET_BACK = ("#7446D4", "#4B279E")
ROSE = ("#FF8DB2", "#DE2F6C")
ROSE_BACK = ("#B8215A", "#8A1244")
GOLD = ("#FFE27A", "#F0A018")
CORK = ("#F6CF9C", "#C4853F")
LEAF = ("#C6F56A", "#2FB344")
LEAF_LID = ("#DBFF8E", "#4CC956")
RIBBON = ("#FFFFFF", "#D6ECFF")

_STAR = {}


def star(size, rot=0.0, v="a"):
    """A real Star token render, `size` px wide before rotation."""
    if v not in _STAR:
        im = Image.open(os.path.join(LAYERS, f"star_{v}.png")).convert("RGBA")
        _STAR[v] = im.crop(im.getbbox())
    im = _STAR[v]
    im = im.resize((size, round(im.height * size / im.width)), Image.LANCZOS)
    return im.rotate(rot, Image.BICUBIC, expand=True) if rot else im


def new():
    return Image.new("RGBA", (M, M), (0, 0, 0, 0))


def put_star(layer, cx, cy, size, rot=0.0, v="a", shadow=0.30):
    im = star(size, rot, v)
    xy = (int(cx - im.width / 2), int(cy - im.height / 2))
    if shadow:
        bi.soft_shadow(layer, im, xy, dx=5, dy=9, blur=7, alpha=shadow)
    bi.paste(layer, im, xy)


def pile(layer, spots):
    for cx, cy, size, rot, v in spots:
        put_star(layer, cx, cy, size, rot, v)


# ---------------------------------------------------------------- toy shapes
def mask_of(shapes, ox=0, oy=0, k=2):
    """Union of simple shapes on an M canvas. ('e', box) ('r', box, radius) ('p', points)."""
    m = Image.new("L", (M * k, M * k), 0)
    d = ImageDraw.Draw(m)
    for s in shapes:
        if s[0] == "p":
            d.polygon([((x + ox) * k, (y + oy) * k) for x, y in s[1]], fill=255)
            continue
        box = [(s[1][0] + ox) * k, (s[1][1] + oy) * k, (s[1][2] + ox) * k, (s[1][3] + oy) * k]
        if s[0] == "e":
            d.ellipse(box, fill=255)
        else:
            d.rounded_rectangle(box, s[2] * k, fill=255)
    return m.resize((M, M), Image.LANCZOS)


def toy(layer, shapes, ramp, ox=0, oy=0, bevel=12, gloss=0.55):
    """Paint a shape as glossy toy plastic: top-to-bottom ramp, a light bevel on the top-left
    edge, a darker one bottom-right, and a soft wet highlight in the upper left."""
    m = mask_of(shapes, ox, oy)
    box = m.getbbox()
    a = np.asarray(m).astype(np.float32) / 255
    yy, xx = np.mgrid[0:M, 0:M].astype(np.float32)
    p = ((yy - box[1]) / max(1, box[3] - box[1])).clip(0, 1)[..., None]
    c0, c1 = (np.array(bi.rgb(c), np.float32) for c in ramp)
    col = c0 + (c1 - c0) * p ** 1.1
    soft = m.filter(ImageFilter.GaussianBlur(bevel))
    lit = np.asarray(ImageChops.offset(soft, bevel, bevel)).astype(np.float32) / 255
    dark = np.asarray(ImageChops.offset(soft, -bevel, -bevel)).astype(np.float32) / 255
    col = col + (255 - col) * ((1 - lit) * 0.75)[..., None]
    col = col * (1 - (1 - dark) * 0.42)[..., None]
    w, h = box[2] - box[0], box[3] - box[1]
    hx, hy = box[0] + w * 0.30, box[1] + h * 0.24
    hi = np.exp(-(((xx - hx) / (w * 0.26)) ** 2 + ((yy - hy) / (h * 0.16)) ** 2)) * gloss
    col = col + (255 - col) * hi[..., None]
    out = np.dstack([col.clip(0, 255), a * 255]).astype(np.uint8)
    layer.alpha_composite(Image.fromarray(out, "RGBA"))
    return m


def flat(layer, shapes, color, ox=0, oy=0, alpha=255, blur=0):
    m = mask_of(shapes, ox, oy)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    im = Image.new("RGBA", (M, M), tuple(color) + (0,))
    im.putalpha(m.point(lambda v: int(v * alpha / 255)))
    layer.alpha_composite(im)


def stick(c, layer, rim=9, ring=4, shadow=0.34):
    """Lay a finished object on the field the way the wordmark sits: white rim, navy ring,
    soft Ink Navy shadow underneath."""
    a = layer.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    white = a.filter(ImageFilter.MaxFilter(rim * 2 + 1))
    navy = white.filter(ImageFilter.MaxFilter(ring * 2 + 1)).filter(ImageFilter.GaussianBlur(1.0))
    sh = Image.new("RGBA", (M, M), INK + (0,))
    sh.putalpha(ImageChops.offset(navy, 0, 16).point(lambda v: int(v * shadow)).filter(ImageFilter.GaussianBlur(12)))
    c.alpha_composite(sh)
    for m, col in ((navy, NAVY), (white.filter(ImageFilter.GaussianBlur(1.0)), (255, 255, 255))):
        im = Image.new("RGBA", (M, M), col + (0,))
        im.putalpha(m)
        c.alpha_composite(im)
    c.alpha_composite(layer)


# ---------------------------------------------------------------- field dressing
def star_poly(cx, cy, r, inner=0.45, n=5, rot=-90):
    return [(cx + (r if i % 2 == 0 else r * inner) * np.cos(np.radians(rot + i * 180 / n)),
             cy + (r if i % 2 == 0 else r * inner) * np.sin(np.radians(rot + i * 180 / n))) for i in range(n * 2)]


def sparkle(c, cx, cy, r, color=(255, 255, 255)):
    layer = new()
    d = ImageDraw.Draw(layer)
    d.polygon(star_poly(cx, cy, r, inner=0.18, n=4, rot=0), fill=color + (240,))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(4)))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))


def rays(c, cx, cy, n=16, alpha=0.13, length=1500):
    layer = new()
    d = ImageDraw.Draw(layer)
    for i in range(n):
        a0 = np.radians(i * 360 / n + 7)
        a1 = a0 + np.radians(360 / n / 2)
        d.polygon([(cx, cy), (cx + length * np.cos(a0), cy + length * np.sin(a0)),
                   (cx + length * np.cos(a1), cy + length * np.sin(a1))], fill=(255, 255, 255, int(255 * alpha)))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))


def glow(c, cx, cy, r, alpha=0.45):
    yy, xx = np.mgrid[0:M, 0:M].astype(np.float32)
    g = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * (r / 2.2) ** 2)))
    layer = np.zeros((M, M, 4), np.uint8)
    layer[..., :3] = 255
    layer[..., 3] = (g * alpha * 255).astype(np.uint8)
    c.alpha_composite(Image.fromarray(layer, "RGBA"))


def base(cx=512, cy=430, floor=0.80, glow_r=640):
    c = bi.field(*bi.SKY, floor=floor)
    rays(c, cx, cy)
    glow(c, cx, cy, glow_r)
    return c


def bubbles(c, spots):
    for x, y, d in spots:
        bi.put_bubble(c, x, y, d, 0.9)


def heart(layer, cx, cy, r, ramp=("#FF9CC0", "#F0306E")):
    R = r
    toy(layer, [("e", (cx - R, cy - R * 0.95, cx + R * 0.04, cy + R * 0.09)),
                ("e", (cx - R * 0.04, cy - R * 0.95, cx + R, cy + R * 0.09)),
                ("p", [(cx - R * 0.93, cy - R * 0.16), (cx + R * 0.93, cy - R * 0.16), (cx, cy + R * 0.98)])],
        ramp, bevel=max(6, int(r * 0.10)), gloss=0.7)


def number(c, text, width, cx, bottom, size=220):
    """The Star count (or 2x, +1) in the Aero wordmark style, centred at cx, sitting on `bottom`."""
    wm = bi.aero_wordmark(lines=(text,), size=size, indent=(0.0,), outline=7, depth=10, rim=15)
    wm = wm.resize((width, round(wm.height * width / wm.width)), Image.LANCZOS)
    bi.paste(c, wm, (int(cx - wm.width / 2), int(bottom - wm.height)))
    return wm


# ---------------------------------------------------------------- products: the size ladder
def handful():
    """20: three Stars, loose on the floor."""
    c = base(cy=400)
    bubbles(c, [(140, 150, 120), (900, 250, 70), (860, 110, 40)])
    L = new()
    pile(L, [(350, 430, 300, -16, "b"), (690, 440, 290, 14, "e"), (512, 330, 380, -4, "a")])
    bi.contact(c, 512, 610, 330, 30, alpha=90, blur=22)
    stick(c, L)
    sparkle(c, 800, 200, 46)
    sparkle(c, 215, 270, 34)
    number(c, "20", 520, 512, 1004)
    return c


def pouch():
    """60: a tied cloth pouch with Stars coming out of the top."""
    c = base(cy=400)
    bubbles(c, [(130, 170, 110), (905, 150, 80), (930, 330, 40)])
    ox, oy = 232, 150
    L = new()
    # back of the open collar
    toy(L, [("p", [(160, 250), (400, 250), (480, 120), (80, 120)])]
        + [("e", (x - 52, 60, x + 52, 164)) for x in (130, 230, 330, 430)], VIOLET_BACK, ox, oy, gloss=0.15)
    pile(L, [(ox + 165, oy + 80, 200, -22, "b"), (ox + 400, oy + 85, 200, 20, "e"), (ox + 282, oy + 30, 250, 3, "a")])
    # body, front collar, cord
    toy(L, [("e", (0, 250, 560, 640)), ("p", [(170, 240), (390, 240), (500, 400), (60, 400)])], VIOLET, ox, oy, bevel=18)
    toy(L, [("p", [(165, 262), (395, 262), (478, 150), (82, 150)])]
        + [("e", (x - 54, 100, x + 54, 208)) for x in (120, 200, 280, 360, 440)], VIOLET, ox, oy, gloss=0.35)
    toy(L, [("r", (150, 236, 410, 284), 24)], GOLD, ox, oy, bevel=7)
    toy(L, [("e", (236, 262, 300, 360)), ("e", (286, 262, 350, 360))], GOLD, ox, oy, bevel=7)
    toy(L, [("e", (252, 232, 334, 292))], GOLD, ox, oy, bevel=7)
    bi.contact(c, 512, 800, 320, 30, alpha=90, blur=22)
    stick(c, L)
    F = new()
    pile(F, [(170, 700, 150, -18, "d"), (865, 690, 160, 16, "c")])
    stick(c, F, rim=7)
    sparkle(c, 800, 150, 44)
    sparkle(c, 190, 330, 32)
    number(c, "60", 520, 512, 1010)
    return c


def jar():
    """140: a corked glass jar, full of Stars."""
    c = base(cy=420)
    bubbles(c, [(110, 190, 100), (925, 170, 84), (900, 420, 40)])
    ox, oy = 232, 40
    L = new()
    body = [("r", (0, 150, 560, 790), 120)]
    inner = mask_of([("r", (16, 166, 544, 774), 106)], ox, oy)
    flat(L, body, (214, 240, 255), ox, oy, alpha=120)
    S = new()
    spots = []
    rows = [(700, [70, 200, 345, 480]), (590, [130, 280, 420, 520]), (480, [60, 200, 350, 490]),
            (375, [130, 290, 430]), (285, [80, 220, 370, 490])]
    vs = "abecd"
    for ri, (y, xs) in enumerate(rows):
        for xi, x in enumerate(xs):
            spots.append((ox + x, oy + y + (xi % 2) * 22, 176 + ((ri + xi) % 3) * 16,
                          ((ri * 37 + xi * 61) % 50) - 25, vs[(ri + xi) % 5]))
    pile(S, spots)
    S.putalpha(ImageChops.multiply(S.getchannel("A"), inner))
    L.alpha_composite(S)
    # glass: rim, neck, gloss
    edge = ImageChops.subtract(mask_of(body, ox, oy), inner)
    g = Image.new("RGBA", (M, M), (235, 248, 255, 0))
    g.putalpha(edge.point(lambda v: int(v * 0.95)))
    L.alpha_composite(g)
    flat(L, [("r", (48, 250, 78, 560), 15)], (255, 255, 255), ox, oy, alpha=170, blur=3)
    flat(L, [("r", (470, 520, 500, 700), 14)], (255, 255, 255), ox, oy, alpha=110, blur=4)
    toy(L, [("r", (110, 100, 450, 172), 30)], ("#F4FBFF", "#A9D8FA"), ox, oy, bevel=8, gloss=0.3)
    toy(L, [("r", (140, 10, 420, 118), 34)], CORK, ox, oy, bevel=12)
    bi.contact(c, 512, 835, 330, 30, alpha=90, blur=22)
    stick(c, L)
    sparkle(c, 835, 290, 46)
    sparkle(c, 160, 400, 34)
    number(c, "140", 720, 512, 1012)
    return c


def chest():
    """400: an open toy chest, Stars heaped over the rim and spilling onto the floor."""
    c = base(cy=380, glow_r=760)
    bubbles(c, [(95, 120, 90), (945, 300, 50)])
    ox, oy = 152, 60
    L = new()
    # open lid, seen from inside
    toy(L, [("r", (30, 0, 690, 330), 110)], GOLD, ox, oy, bevel=10, gloss=0.2)
    toy(L, [("r", (58, 28, 662, 330), 86)], ROSE_BACK, ox, oy, bevel=14, gloss=0.12)
    pile(L, [(ox + 130, oy + 250, 210, -24, "b"), (ox + 590, oy + 250, 210, 22, "e"), (ox + 250, oy + 150, 220, 12, "c"),
             (ox + 470, oy + 150, 220, -14, "d"), (ox + 360, oy + 80, 230, 4, "a"),
             (ox + 60, oy + 345, 190, -30, "d"), (ox + 660, oy + 345, 190, 28, "c"),
             (ox + 220, oy + 310, 230, 18, "e"), (ox + 500, oy + 310, 230, -16, "b"), (ox + 360, oy + 250, 280, -3, "a")])
    # the box
    toy(L, [("r", (0, 380, 720, 740), 56)], ROSE, ox, oy, bevel=18, gloss=0.4)
    toy(L, [("r", (0, 380, 720, 452), 30)], GOLD, ox, oy, bevel=9, gloss=0.4)
    for x in (70, 580):
        toy(L, [("r", (x, 380, x + 70, 740), 20)], GOLD, ox, oy, bevel=9, gloss=0.3)
    toy(L, [("r", (300, 400, 420, 540), 30)], GOLD, ox, oy, bevel=10, gloss=0.5)
    flat(L, [("e", (340, 440, 380, 480)), ("p", [(350, 465), (370, 465), (378, 515), (342, 515)])], NAVY, ox, oy)
    bi.contact(c, 512, 830, 420, 30, alpha=90, blur=22)
    stick(c, L)
    F = new()
    pile(F, [(110, 770, 170, -20, "c"), (915, 765, 180, 18, "d"), (60, 600, 120, 24, "e"), (965, 610, 120, -22, "b")])
    stick(c, F, rim=7)
    sparkle(c, 850, 110, 50)
    sparkle(c, 200, 80, 36)
    sparkle(c, 930, 470, 28)
    number(c, "400", 760, 512, 1014)
    return c


def starter():
    """40, one per player: the Bear (B1: tee, beanie, star charm) beside a gift pack of Stars."""
    c = base(cx=620, cy=420)
    bubbles(c, [(940, 120, 80), (70, 110, 60)])
    ox, oy = 500, 270
    L = new()
    toy(L, [("r", (40, 190, 420, 300), 30)], ("#3FA84A", "#1E7A32"), ox, oy, gloss=0.1)  # inside of the box
    pile(L, [(ox + 110, oy + 170, 200, -20, "b"), (ox + 355, oy + 175, 200, 20, "e"), (ox + 232, oy + 95, 260, 2, "a")])
    toy(L, [("r", (30, 250, 430, 520), 44)], LEAF, ox, oy, bevel=16)
    toy(L, [("r", (190, 250, 270, 520), 8)], RIBBON, ox, oy, bevel=7, gloss=0.2)
    toy(L, [("r", (0, 216, 460, 300), 34)], LEAF_LID, ox, oy, bevel=10, gloss=0.4)
    toy(L, [("r", (190, 216, 270, 300), 6)], RIBBON, ox, oy, bevel=7, gloss=0.2)
    bi.contact(c, ox + 230, 850, 250, 26, alpha=90, blur=20)
    stick(c, L)
    bear = bi.relight(bi.load(os.path.join(CAP, "set", "B1.png"), 1.34), cool=0.14)
    B = new()
    bi.paste(B, bear, (30, 870 - bear.height))
    bi.contact(c, 30 + bear.width / 2, 862, 170, 24, alpha=90, blur=18)
    stick(c, B, rim=8)
    sparkle(c, 900, 330, 40)
    sparkle(c, 470, 120, 34)
    number(c, "40", 500, 690, 1010)
    return c


# ---------------------------------------------------------------- passes (circle-safe)
def double_stars():
    """2x Stars: a bold 2x over a pair of Stars."""
    c = base(cy=470, glow_r=700)
    bubbles(c, [(250, 250, 70), (800, 810, 56)])
    L = new()
    pile(L, [(365, 335, 310, -14, "b"), (640, 320, 380, 10, "a")])
    stick(c, L)
    sparkle(c, 800, 600, 44)
    sparkle(c, 215, 520, 36)
    sparkle(c, 480, 150, 30)
    number(c, "2×", 590, 512, 850, size=260)
    return c


def supporter():
    """Supporter: the Bear, a small thank-you heart, and "+1 Star" read as one unit.
    Spencer 2026-11-21: a big heart beside "+1" read as "+1 Heart" (Heart is a stat), so the
    +1 sits right against a Star and the heart is small and off to the side."""
    c = base(cy=470, glow_r=700)
    bubbles(c, [(250, 230, 64), (810, 300, 50)])
    bear = bi.relight(bi.load(os.path.join(CAP, "S1-tight.png"), 0.86), cool=0.16)
    B = new()
    bi.paste(B, bear, (int(512 - bear.width / 2), 150))
    stick(c, B, rim=8)
    H = new()
    heart(H, 285, 330, 58)
    stick(c, H, rim=7)
    number(c, "+1", 300, 420, 850, size=230)
    S = new()
    put_star(S, 680, 740, 200, 10, "a")
    stick(c, S, rim=8)
    sparkle(c, 760, 200, 34)
    sparkle(c, 800, 620, 26)
    return c


# ---------------------------------------------------------------- outputs
ITEMS = [("doubleStars", "2× Stars", "pass", double_stars), ("supporter", "Supporter", "pass", supporter),
         ("starter", "Starter pack  40", "product", starter), ("handful", "Handful of Stars  20", "product", handful),
         ("pouch", "Pouch of Stars  60", "product", pouch), ("jar", "Jar of Stars  140", "product", jar),
         ("chest", "Chest of Stars  400", "product", chest)]


def circle(im):
    s = 4
    m = Image.new("L", (im.width * s, im.height * s), 0)
    ImageDraw.Draw(m).ellipse((0, 0, m.width - 1, m.height - 1), fill=255)
    out = im.convert("RGBA")
    out.putalpha(m.resize(im.size, Image.LANCZOS))
    return out


def sheet(icons):
    """All seven at 512, 150, 100 and 64 px on light and dark. Passes: the store's circle crop
    (white ring) and the safe circle (rose ring) on the 512, and circle-cropped small sizes."""
    f = ImageFont.truetype(bi.font_path("Nunito-ExtraBold.ttf"), 26)
    fs = ImageFont.truetype(bi.font_path("Nunito-ExtraBold.ttf"), 18)
    pad, top = 40, 60
    cw = 512 + pad
    W = pad + len(ITEMS) * cw
    band = top + 512 + 30 + 150 + 50
    out = Image.new("RGBA", (W, band * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for b, (bg, ink, sub) in enumerate((((244, 247, 251), INK, (90, 110, 135)), ((22, 25, 32), (255, 255, 255), (150, 160, 175)))):
        y0 = b * band
        d.rectangle((0, y0, W, y0 + band), fill=bg)
        for i, (key, name, kind, _) in enumerate(ITEMS):
            x = pad + i * cw
            im = icons[key].convert("RGBA")
            d.text((x, y0 + 16), f"{key}  ·  {name}", font=f, fill=ink)
            y = y0 + top
            out.alpha_composite(bi.rounded(im, 24), (x, y))
            if kind == "pass":
                d.ellipse((x, y, x + 511, y + 511), outline=(255, 255, 255), width=3)
                r = 256 * SAFE
                d.ellipse((x + 256 - r, y + 256 - r, x + 256 + r, y + 256 + r), outline=(255, 80, 140), width=2)
            y += 512 + 30
            xx = x
            for size in (150, 100, 64):
                sm = im.resize((size, size), Image.LANCZOS)
                sm = circle(sm) if kind == "pass" else bi.rounded(sm, max(3, round(size * 0.11)))
                out.alpha_composite(sm, (xx, y))
                d.text((xx, y + size + 4), f"{size} px", font=fs, fill=sub)
                xx += size + 28
    return out.convert("RGB")


if __name__ == "__main__":
    only = sys.argv[1:]
    icons = {}
    for key, name, kind, fn in ITEMS:
        if only and key not in only:
            icons[key] = Image.open(os.path.join(HERE, f"{key}.png")).convert("RGB")
            continue
        icons[key] = fn().convert("RGB").resize((512, 512), Image.LANCZOS)
        icons[key].save(os.path.join(HERE, f"{key}.png"))
    sheet(icons).save(os.path.join(HERE, "contact.png"))
    print("wrote", ", ".join(k + ".png" for k, *_ in ITEMS), "and contact.png")
