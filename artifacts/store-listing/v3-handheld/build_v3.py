"""Store art for the rename to "Hatch a Handheld Pal" (Fable, 2026-11-25). Drafts only; nothing is uploaded.

Extends ../v2-new-look/icons/build_icons.py and ../v2-new-look/set/build_set.py (same Dewdrop / Aero kit).
Everything is our own Studio cut-outs from ../v2-new-look/captures plus code-drawn type, chips and effects:
  S3          the bare white Bear, head and shoulders (what a new player hatches)
  S10 (+paws) the Bear in the Butter Pom Beanie, paws forward (alt icon; the paws are used on both)
  S4-straight the Pocket Deck, Cloud Glass plate, straight-on
  P-egg-toy   the Toy Egg, split along its own painted zigzag into a cap and a cup
No AI imagery, no outside assets.

Run: python build_v3.py
 ->  icon-K.png (512, pick), icon-K-1024.png, icon-K-beanie.png, icons-JK.png (old vs new at 512/150/50)
     T1-hatch-a-handheld-pal.png, ad-D-merge-hatch.png (1920x1080, each with a -480 check)
     T2..T7 retitled (same art as live, the corner mark now reads the new name)
     contact.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.join(HERE, "..", "v2-new-look")
sys.path.insert(0, os.path.join(V2, "icons"))
sys.path.insert(0, os.path.join(V2, "set"))
import build_icons as bi  # noqa: E402
import build_set as bs  # noqa: E402

CAP = bi.CAP
SET = os.path.join(CAP, "set")
NAME = ("hatch a", "handheld pal")

# The Toy Egg's own painted crack line (P-egg-toy.png is 405 x 535).
ZIG = [(0, 224), (22, 222), (45, 210), (65, 268), (100, 210), (145, 275), (200, 212), (255, 280), (300, 212),
       (350, 268), (378, 205), (405, 226)]


# ---------------------------------------------------------------- pieces
def egg_parts():
    """The Toy Egg cut along its zigzag: (cap, cup), each the full 405 x 535 frame, with a cream lip on the cut."""
    im = Image.open(os.path.join(SET, "P-egg-toy.png")).convert("RGBA")
    assert im.size == (405, 535), im.size
    s = 4
    big = Image.new("L", (im.width * s, im.height * s), 0)
    ImageDraw.Draw(big).polygon([(x * s, y * s) for x, y in ZIG] + [(im.width * s, im.height * s), (0, im.height * s)], fill=255)
    low = big.resize(im.size, Image.LANCZOS)
    lip = Image.new("L", (im.width * s, im.height * s), 0)
    ImageDraw.Draw(lip).line([(x * s, y * s) for x, y in ZIG], fill=255, width=7 * s, joint="curve")
    lip = lip.resize(im.size, Image.LANCZOS)
    a = np.asarray(im).astype(np.float32)
    out = []
    for m in (255 - np.asarray(low).astype(np.float32), np.asarray(low).astype(np.float32)):
        p = a.copy()
        l_ = (np.asarray(lip).astype(np.float32) / 255)[..., None] * 0.85
        p[..., :3] = p[..., :3] * (1 - l_) + np.array([255, 246, 214], np.float32) * l_
        p[..., 3] = p[..., 3] * m / 255
        out.append(Image.fromarray(p.clip(0, 255).astype(np.uint8), "RGBA"))
    return out[0], out[1]


def scaled(im, k, rot=0.0):
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    return im.rotate(rot, Image.BICUBIC, expand=True) if rot else im


def paws(k):
    """The Bear's two paws from S10 (same split as build_set.bear_parts), each trimmed, at scale k."""
    _, left, right = bs.bear_parts(k)
    return left, right


def hatch_screen(w, h, px=10):
    """The deck's screen for the hatch: icon J's pastel LCD in the Bubbles ball theme, the middle left clear for
    the egg, a gold pixel burst behind it, big balls either side and a Blossom pair merging top left."""
    ramps = [bi.BUBBLES[0], bi.BUBBLES[1], bi.BUBBLES[2], bi.BUBBLES[3], bi.BUBBLES[4]]
    ink = bi.BUBBLES_INK
    gw, gh = w // px, h // px
    t = np.linspace(0, 1, gh)[:, None, None]
    a = np.array(bi.rgb("#E9F7FF")) * (1 - t) + np.array(bi.rgb("#F3ECFF")) * t
    a = np.repeat(a, gw, 1).astype(np.float32)
    yy, xx = np.mgrid[0:gh, 0:gw]
    a -= ((xx * 3 + yy * 5) % 11 == 0)[..., None] * 10
    lcd = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(lcd)
    bx, by = gw * 0.5, gh * 0.62
    for i in range(16):
        ang = i * np.pi / 8 + 0.2
        L = gh * (0.95 if i % 2 == 0 else 0.7)
        d.line((bx, by, bx + np.cos(ang) * L, by + np.sin(ang) * L), fill=(255, 214, 110) if i % 2 == 0 else (255, 190, 225), width=1)
    bi.pixel_ball(lcd, gw * 0.115, gh - 9.5, 7.6, 0, ramps, ink, "dots")   # sky, bottom left
    bi.pixel_ball(lcd, gw * 0.885, gh - 9.0, 7.0, 1, ramps, ink, "dots")   # peach, bottom right
    bi.pixel_ball(lcd, gw * 0.075, gh * 0.24, 5.0, 3, ramps, ink, "dots")  # blossom pair, merging
    bi.pixel_ball(lcd, gw * 0.215, gh * 0.20, 5.0, 3, ramps, ink, "dots")
    bi.pixel_ball(lcd, gw * 0.90, gh * 0.24, 5.6, 2, ramps, ink, "dots")   # melon
    sx, sy = round(gw * 0.145), round(gh * 0.065)
    for i in range(-3, 4):
        k = 3 - abs(i)
        d.line((sx + i, sy - k // 2, sx + i, sy + k // 2), fill=(255, 200, 60))
        d.line((sx - k // 2, sy + i, sx + k // 2, sy + i), fill=(255, 200, 60))
    return lcd.resize((gw * px, gh * px), Image.NEAREST).resize((w, h), Image.NEAREST).convert("RGBA")


def glow(c, cx, cy, r, alpha=0.4, color=(255, 255, 255)):
    w, h = c.size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    g = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * (r / 2.2) ** 2)))
    layer = np.zeros((h, w, 4), np.uint8)
    layer[..., :3] = color
    layer[..., 3] = (g * alpha * 255).astype(np.uint8)
    c.alpha_composite(Image.fromarray(layer, "RGBA"))


def rays(c, cx, cy, n=18, alpha=0.12, length=1600, rot=8):
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        a0 = np.radians(rot + i * 360 / n)
        a1 = a0 + np.radians(360 / n / 2)
        d.polygon([(cx, cy), (cx + length * np.cos(a0), cy + length * np.sin(a0)),
                   (cx + length * np.cos(a1), cy + length * np.sin(a1))], fill=(255, 255, 255, int(255 * alpha)))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))


def sparkle(c, cx, cy, r, color=(255, 255, 255)):
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(bs.star_poly(cx, cy, r, inner=0.18, n=4, rot=0), fill=color + (240,))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))


def shard(c, cx, cy, r, rot, col=("#FFC629", "#E08A00")):
    """A chip of shell flying off: a small triangle in the egg's own yellow with a cream edge."""
    s = 4
    n = int(r * 3) * s
    big = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    m = n / 2
    pts = [(m + r * s * np.cos(np.radians(a)) * f, m + r * s * np.sin(np.radians(a)) * f) for a, f in ((-90, 1.0), (30, 0.8), (160, 0.95))]
    d.polygon(pts, fill=bi.rgb(col[1]) + (255,))
    d.polygon([(m + (x - m) * 0.74, m + (y - m) * 0.74 - r * s * 0.08) for x, y in pts], fill=bi.rgb(col[0]) + (255,))
    d.line(pts[:2], fill=(255, 246, 214, 255), width=int(r * s * 0.16))
    im = big.resize((n // s, n // s), Image.LANCZOS).rotate(rot, Image.BICUBIC)
    bi.soft_shadow(c, im, (int(cx - im.width / 2), int(cy - im.height / 2)), dx=4, dy=6, blur=5, alpha=0.22)
    bi.paste(c, im, (int(cx - im.width / 2), int(cy - im.height / 2)))


# ---------------------------------------------------------------- the hero: a pal hatching on the handheld
def hero(c, ox=0, oy=0, k=1.0, beanie=False, tilt=-3.0, extras=True, deck="drawn", deck_w=968, deck_y=506,
         lift=0, pal=1.0, light=True):
    """Drawn in the 1024 icon frame, then placed at (ox, oy) scaled by k.
    Back to front: light, the deck with its screen lit, the cap flying off, the egg's inside, the Bear, the cup,
    his paws on its rim, shell chips and sparkles.
    deck: "drawn" (icon J's pastel screen), a real frozen frame's name in captures/set (e.g. "D-bigmerge"), or None.
    lift raises the egg and the Bear over the deck; pal scales them about the egg's crack."""
    def X(x):
        return ox + x * k

    def Y(y):
        return oy + y * k

    ex, rim_y = 512, 642 - lift  # the egg's centre line and the height of its crack, in the icon frame
    p = pal

    def R(dx, dy):
        return X(ex + dx * p), Y(rim_y + dy * p)

    if light:
        glow(c, X(ex), Y(560 - lift * 0.5), 900 * k, 0.42)
        rays(c, X(ex), Y(600 - lift * 0.5), n=18, alpha=0.11, length=1500 * k)

    if deck:
        dk = bi.deck_with_hero(hatch_screen) if deck == "drawn" else bs.cut(deck, 1.0, cool=0)
        dk = scaled(dk, deck_w * k / dk.width, tilt)
        dxy = (int(X(ex) - dk.width / 2), int(Y(deck_y)))
        bi.contact(c, X(ex), Y(deck_y) + dk.height - 12 * k, dk.width * 0.40, 20 * k, alpha=90, blur=int(18 * k))
        bi.soft_shadow(c, dk, dxy, dx=int(12 * k), dy=int(14 * k), blur=int(20 * k), alpha=0.34)
        bi.paste(c, dk, dxy)
        if deck == "drawn":
            glow(c, X(ex), Y(740), 520 * k, 0.55, (255, 244, 190))  # the screen's light, spilling up over the shell
        else:
            glow(c, *R(0, 40), 420 * k * p, 0.45, (255, 244, 190))

    cap, cup = egg_parts()
    e = 1.04 * k * p  # egg scale: 405 wide capture -> about 420 in the icon frame
    rx, ry = R(0, 0)
    exy = (int(rx - 405 * e / 2), int(ry - 240 * e))  # capture row 240 (mid zigzag) sits on the crack

    # the cap, thrown up and to the right, behind the Bear's ear
    cp = scaled(cap.crop((0, 0, 405, 285)), e * 0.78, -32)
    cxy = tuple(int(v) for v in R(156, -614))
    bi.soft_shadow(c, cp, cxy, dx=int(8 * k), dy=int(12 * k), blur=int(12 * k), alpha=0.22)
    bi.paste(c, cp, cxy)

    # the egg's inside: a deep amber mouth behind the Bear, with a hot core
    s = 3
    mw, mh = int(390 * e), int(120 * e)
    mouth = Image.new("RGBA", (mw * s, mh * s), (0, 0, 0, 0))
    ImageDraw.Draw(mouth).ellipse((0, 0, mw * s - 1, mh * s - 1), fill=(214, 120, 12, 255))
    ImageDraw.Draw(mouth).ellipse((mw * s * 0.14, mh * s * 0.16, mw * s * 0.86, mh * s * 0.9), fill=(255, 226, 120, 255))
    mouth = mouth.resize((mw, mh), Image.LANCZOS).filter(ImageFilter.GaussianBlur(2 * k))
    bi.paste(c, mouth, (int(rx - mw / 2), int(ry - mh * 0.62)))

    # the Bear, rising out of it
    if beanie:
        bsz = 1.22 * k * p
        body, _, _ = bs.bear_parts(bsz)
        head = body.crop((0, 0, body.width, round(640 * bsz)))
        hx, hy = R(8, -30)
        bxy = (int(hx - 402 * bsz), int(hy - 482 * bsz))
    else:
        bsz = 0.76 * k * p
        head = bi.load(os.path.join(CAP, "S3.png"))
        head = bi.relight(scaled(head.crop((0, 0, head.width, 652)), bsz), cool=0.14)  # shoulders stay in the egg
        hx, hy = R(14, 8)
        bxy = (int(hx - head.width / 2), int(hy - 640 * bsz))
    bi.soft_shadow(c, head, bxy, dx=int(12 * k), dy=int(8 * k), blur=int(16 * k), alpha=0.18)
    bi.paste(c, head, bxy)

    # the cup in front, then his paws on its rim
    cupc = scaled(cup, e)
    bi.soft_shadow(c, cupc, exy, dx=0, dy=int(-10 * k), blur=int(10 * k), alpha=0.22)  # up onto his chin
    bi.soft_shadow(c, cupc, exy, dx=int(10 * k), dy=int(12 * k), blur=int(14 * k), alpha=0.30)  # onto the screen
    bi.paste(c, cupc, exy)
    pl, pr = paws(0.78 * k * p)
    for paw, dx_, r in ((pl, -186, 16), (pr, 188, -16)):
        paw = paw.rotate(r, Image.BICUBIC, expand=True)
        qx, qy = R(dx_, 22)
        xy = (int(qx - paw.width / 2), int(qy - paw.height * 0.55))
        bi.soft_shadow(c, paw, xy, dx=int(4 * k), dy=int(12 * k), blur=int(8 * k), alpha=0.34)
        bi.paste(c, paw, xy)

    if extras:
        for x, y, r, rot in ((-262, -172, 26, 20), (-316, -312, 18, -30), (288, -212, 22, 200), (393, -312, 15, 60)):
            shard(c, *R(x, y), r * k * p, rot)
        for x, y, r in ((-362, -432, 30), (368, -562, 22), (-212, -522, 16), (428, -172, 18), (-426, -212, 16)):
            sparkle(c, *R(x, y), r * k * p)


# ---------------------------------------------------------------- icon K
def icon_k(beanie=False):
    """The handheld, an egg cracking on its screen, the Bear popping out. No type (see REVIEW.md). Sky."""
    c = bi.field(*bi.SKY, floor=0.84)
    bi.put_bubble(c, 96, 96, 110, 0.9)
    bi.put_bubble(c, 964, 250, 56, 0.85)
    hero(c, beanie=beanie)
    return c


# ---------------------------------------------------------------- thumbnails and ads
W, H = bs.W, bs.H


def name_mark(width):
    return bs.caption(list(NAME), width, [0.0, 0.0])


def step_chip(n, text, size=44):
    """A numbered glass chip: a Sun disc with the step number, then the words."""
    ch = bs.chip("     " + text, size)
    d = ImageDraw.Draw(ch)
    cy = 16 + int(size * 1.55) / 2
    r = size * 0.56
    cx = 16 + 12 + r
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=bi.rgb("#FFC93C"), outline=bs.NAVY, width=3)
    d.text((cx, cy), str(n), font=bs.font(int(size * 0.86), "Black"), fill=bs.NAVY, anchor="mm")
    return ch


def prop(c, name, scale, cx, cy, rot=0.0):
    """A toy, jar, egg or snack floating free, with a small shadow."""
    im = bs.cut(name, scale, rot=rot, cool=0)
    bi.soft_shadow(c, im, (int(cx - im.width / 2), int(cy - im.height / 2)), dx=6, dy=8, blur=8, alpha=0.2)
    bs.paste_center(c, im, cx, cy)


def stat_icon(c, sid, cx, cy, size=84):
    """One of the six stat icons (assets/ui/stat-icons) on a white glass disc."""
    s = 3
    r = int(size * 0.66)
    disc = Image.new("RGBA", (r * 2 * s, r * 2 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(disc)
    d.ellipse((0, 0, r * 2 * s - 1, r * 2 * s - 1), fill=bs.NAVY + (255,))
    d.ellipse((5 * s, 5 * s, r * 2 * s - 5 * s, r * 2 * s - 5 * s), fill=(255, 255, 255, 245))
    disc = disc.resize((r * 2, r * 2), Image.LANCZOS)
    ic = Image.open(os.path.join(bs.REPO, "assets", "ui", "stat-icons", f"icon-{sid}-128.png")).convert("RGBA").resize((size, size), Image.LANCZOS)
    disc.alpha_composite(ic, (r - size // 2, r - size // 2))
    bs.paste_center(c, bs.drop(disc, 6, 0.25, 6), cx, cy)


def t1():
    """The lead frame and the Home Page tile: the name, the hatch on the handheld, the first minute in three
    numbered chips, and what comes after it on the left: three pals in their colours and outfits, a Feast snack,
    a Stat Egg and a Customization Egg, toys and dye jars flying. Every item is a real capture."""
    c = bs.base(0.86)
    bs.bubbles(c, [(1880, 560, 56), (40, 250, 40)])
    hero(c, ox=806, oy=8, k=0.985)
    # toys and jars, tumbling from the hatch toward the name
    for name, sc, x, y, r in (("P-toy-ball", 0.34, 930, 250, 0), ("P-toy-carrot", 0.32, 1010, 96, 30),
                              ("P-toy-top", 0.30, 790, 372, -14), ("P-jar-tide", 0.25, 912, 452, -10),
                              ("P-toy-bone", 0.28, 760, 560, 16), ("P-toy-sparkler", 0.32, 1186, 76, -28),
                              ("P-jar-rose", 0.24, 1856, 330, 12), ("P-jar-citrus", 0.22, 1540, 62, 10)):
        prop(c, name, sc, x, y, r)
    for x, y, r, rot in ((884, 56, 24, -80), (1080, 392, 20, -100), (700, 470, 18, -75), (1420, 60, 20, -95)):
        bs.gold_star(c, x, y, r, rot)
    # the pals on the floor: back two first, then the Bunny in front
    bs.put(c, bs.cut("C7a", 0.74), 396, bottom=1010)
    bs.put(c, bs.cut("C7c", 0.74), 640, bottom=1016)
    bs.put(c, bs.cut("B2", 0.86), 150, bottom=1052)
    bs.put(c, bs.cut("P-feast", 0.40, cool=0), 300, bottom=1058)
    bs.put(c, bs.cut("P-egg-stat", 0.32, cool=0), 520, bottom=1060)
    bs.put(c, bs.cut("P-egg-hue", 0.32, cool=0), 764, bottom=1058)
    for sx, sy, r in ((560, 600, 16), (276, 640, 14), (746, 668, 14)):
        sparkle(c, sx, sy, r)
    wm = bs.caption(list(NAME), 800, [0.0, 0.0])
    bi.paste(c, wm, (36, 16))
    y = 16 + wm.height + 2
    for i, txt in enumerate(("play your handheld", "hatch your pal", "raise it in the garden")):
        ch = step_chip(i + 1, txt, 46)
        bi.paste(c, ch, (40 + i * 34, y))
        y += ch.height - 22
    return c


def ad_d():
    """Ad D, the first minute: the real deck frozen mid-merge (Chain x4), the Bear bursting out of his egg on
    top of it, balls and toys flying, three more pals watching. Headline: merge balls. hatch a pal."""
    c = bs.base(0.88)
    bs.bubbles(c, [(1890, 420, 60), (760, 330, 44)])
    k, ox, oy = 1.08, 790, -64
    glow(c, ox + 512 * k, 520, 1100, 0.40)
    rays(c, ox + 512 * k, 520, n=20, alpha=0.12, length=1700)
    for x, y, t, kk in ((880, 420, 1, 5), (1836, 300, 2, 5), (1764, 130, 0, 5), (960, 250, 3, 4)):
        bs.loose_ball(c, x, y, t, kk)
    for name, sc, x, y, r in (("P-toy-ball", 0.36, 1000, 96, 0), ("P-toy-carrot", 0.30, 1040, 508, 30),
                              ("P-toy-bone", 0.28, 1650, 420, 16)):
        prop(c, name, sc, x, y, r)
    hero(c, ox=ox, oy=oy, k=k, deck="D-bigmerge", deck_w=1010, deck_y=548, lift=126, pal=0.84, tilt=-2.0, light=False)
    b = bs.burst("×4", 72)
    bs.paste_center(c, b, 1790, 606)  # on the deck's top corner, clear of the A button
    for x, y, r, rot in ((1100, 60, 24, -80), (850, 300, 20, -100), (1700, 250, 22, -75), (1880, 180, 18, -95)):
        bs.gold_star(c, x, y, r, rot)
    # the pals who are waiting for him
    bs.put(c, bs.cut("C7a", 0.80), 430, bottom=1012)
    bs.put(c, bs.cut("F7b", 0.80), 668, bottom=1024)
    bs.put(c, bs.cut("B2", 1.00), 176, bottom=1056)
    bs.put(c, bs.cut("P-feast", 0.40, cool=0), 330, bottom=1062)
    bs.put(c, bs.cut("P-egg-stat", 0.30, cool=0), 560, bottom=1064)
    cap = bs.caption(["merge balls.", "hatch a pal."], 860, [0.0, 0.0])
    bi.paste(c, cap, (30, 10))
    ch = bs.chip("then raise it in the garden", 44)
    bi.paste(c, ch, (40, 10 + cap.height - 6))
    m = name_mark(330)
    bi.paste(c, m, (W - m.width - 16, H - m.height - 6))
    return c


def ad_e():
    """Ad E, the pals: the Bear hatching in the middle of six pals in their colours and outfits,
    the four dye jars and a handful of toys. Headline: hatch a pal. make it yours."""
    c = bs.base(0.84)
    glow(c, 1000, 640, 1200, 0.36)
    rays(c, 1000, 640, n=20, alpha=0.10, length=1700)
    bs.bubbles(c, [(1880, 380, 60), (30, 420, 44)])
    floor = 990
    bs.put(c, bs.cut("C7c", 0.84), 668, bottom=floor - 30)
    bs.put(c, bs.cut("F7b", 0.84), 1318, bottom=floor - 30)
    hero(c, ox=1000 - 512 * 0.86, oy=140, k=0.86, deck=None, light=False)
    bs.put(c, bs.cut("C7a", 1.00), 170, bottom=floor + 40)
    bs.put(c, bs.cut("B2", 1.00), 420, bottom=floor + 56)
    bs.put(c, bs.cut("C13", 1.00), 1548, bottom=floor + 56)
    bs.put(c, bs.cut("C1", 1.04), 1792, bottom=floor + 44)
    x = 1010
    for jar in ("rose", "tide", "citrus", "iris"):
        j = bs.cut("P-jar-" + jar, 0.30, cool=0)
        bi.paste(c, bs.drop(j, 6, 0.22), (x, 26))
        x += j.width + 2
    ch = bs.chip(f"hats · outfits · 4 dyes · {bs.N_CHARMS} charms", 34)
    bi.paste(c, ch, (1010, 176))
    for name, sc, x, y, r in (("P-toy-ball", 0.32, 690, 336, 0), ("P-toy-top", 0.28, 1520, 330, 14)):
        prop(c, name, sc, x, y, r)
    for x, y, r, rot in ((800, 262, 22, -80), (1270, 470, 20, -100), (1700, 300, 20, -75)):
        bs.gold_star(c, x, y, r, rot)
    for hx, hy, r, rot in ((560, 400, 22, -12), (1420, 420, 20, 14)):
        bs.heart(c, hx, hy, r, rot=rot)
    cap = bs.caption(["hatch a pal.", "make it yours."], 900, [0.0, 0.0])
    bi.paste(c, cap, (30, 10))
    m = name_mark(330)
    bi.paste(c, m, (W - m.width - 16, 14))
    return c


def ad_f():
    """Ad F, raising it: the Pet Park (the real plate, as T5's flat silhouette), the Bear up front with a
    Feast snack, pals on the swing and the see-saw, a Bunny mid-jump, the six stat icons in an arc.
    Headline: raise your pal."""
    ox = 150
    c, k = bs.park_silhouette(ox)

    def P(px, py):
        return (px - ox) * k, py * k

    def pal_(name, scale, px, py, rot=0.0, ry=10, flip=False, sh=90):
        im = bs.cut(name, scale, rot, cool=0)
        if flip:
            im = ImageOps.mirror(im)
        x, y = P(px, py)
        if sh:
            bi.contact(c, x, y - 4, im.width * 0.40, ry, alpha=sh, blur=10)
        bi.paste(c, im, (int(x - im.width / 2), int(y - im.height)))
        return x, y - im.height

    pal_("A-C7c-stretch", 0.40, 1185, 455, rot=-4, ry=6, sh=50)
    x, y = pal_("A-C7a-sit", 0.52, 410, 540, rot=7, ry=1, sh=0, flip=True)
    bi.contact(c, x + 10, P(0, 560)[1], 70, 10, alpha=80, blur=10)
    pal_("A-F7b-ride", 0.58, 768, 574, rot=6, ry=6, sh=50)
    pal_("A-J3-ride", 0.55, 985, 502, rot=-8, ry=5, sh=40)
    for name, s, px, py, rot in (("P-toy-top", 0.26, 452, 662, 14), ("P-toy-bone", 0.28, 1075, 640, -12),
                                 ("P-toy-ball", 0.34, 700, 700, 0)):
        im = bs.cut(name, s, rot, cool=0)
        x, y = P(px, py)
        bi.contact(c, x, y - 6, im.width * 0.40, 10, alpha=90, blur=10)
        bi.paste(c, im, (int(x - im.width / 2), int(y - im.height)))
    bun = bs.cut("A-B2-sit", 1.10, cool=0)
    bi.contact(c, 168, 1046, bun.width * 0.46, 22, alpha=120, blur=14)
    bi.paste(c, bun, (168 - bun.width // 2, 1066 - bun.height))
    # the Bear, big, waving, with his snack and the handheld toy
    bear = bs.cut("B1", 1.16, cool=0)  # the wave capture is too small to hold up at this size
    bx = 1480
    bi.contact(c, bx, 1052, bear.width * 0.42, 22, alpha=110, blur=14)
    bi.paste(c, bear, (bx - bear.width // 2, 1074 - bear.height))
    fe = bs.cut("P-feast", 0.50, cool=0)
    bi.contact(c, 1190, 1050, fe.width * 0.42, 14, alpha=100, blur=10)
    bi.paste(c, fe, (1190 - fe.width // 2, 1062 - fe.height))
    td = bs.cut("P-toy-deck", 0.56, rot=-8, cool=0)
    bi.contact(c, 1790, 1052, td.width * 0.40, 12, alpha=100, blur=10)
    bi.paste(c, td, (1790 - td.width // 2, 1066 - td.height))
    # six stats in an arc over him
    ids = [s[0] for s in bs.STATS]
    for i, sid in enumerate(ids):
        a = np.radians(210 + i * 24)
        stat_icon(c, sid, bx + 400 * np.cos(a), 590 + 330 * np.sin(a), 78)
    b = bs.burst("+1", 50, fill=bi.rgb("#B9EE5A"), ink=(30, 120, 40))
    bs.paste_center(c, b, bx + 330, 170)
    lv = bs.chip("LEVEL UP!", 38)
    bi.paste(c, lv, (bx - lv.width // 2, 130))
    for hx_, hy_, r, rot in ((1200, 640, 24, -12), (330, 440, 22, -10), (860, 400, 20, 12)):
        bs.heart(c, hx_, hy_, r, rot=rot)
    for sx, sy, r in ((930, 300, 22), (1130, 420, 16), (40, 460, 18), (1880, 620, 18)):
        sparkle(c, sx, sy, r)
    cap = bs.caption(["raise your pal"], 900, [0.0])
    bi.paste(c, cap, (30, 10))
    ch = bs.chip("feed · train · dress up · play", 46)
    bi.paste(c, ch, (40, 10 + cap.height - 6))
    m = name_mark(330)
    bi.paste(c, m, (36, 10 + cap.height + ch.height - 20))
    return c


def retitled(fn, *a, pos="tr", **k):
    """A live v2 frame, unchanged, with the corner mark reading the new name."""
    c = fn(*a, **k)
    m = name_mark(372)
    xy = (W - m.width - 20, H - m.height - 8) if pos == "br" else (W - m.width - 20, 10)
    bi.paste(c, m, xy)
    return c


SET_LIST = [
    ("T1-hatch-a-handheld-pal", t1),
    ("T2-merge", lambda: retitled(bs.t3, ("merge", "big chains"))),
    ("T3-hatch-eggs", lambda: retitled(bs.t4)),
    ("T4-level-up", lambda: retitled(bs.t7)),
    ("T5-dress-up", lambda: retitled(bs.t2)),
    ("T6-play", lambda: retitled(bs.t5)),
    ("T7-decks", lambda: retitled(bs.t6, pos="br")),
    ("ad-D-merge-hatch", ad_d),
    ("ad-E-pals", ad_e),
    ("ad-F-raise", ad_f),
    ("ad-B-control", lambda: retitled(bs.t3, ("merge. hatch.", "repeat."))),
]
AD_SIZES = ((728, 410), (480, 270), (256, 144), (150, 84))  # 16:9 tiles, large to the small Home sort


def contact(names):
    pad, cols = 16, 2
    rows = (len(names) + cols - 1) // cols
    out = Image.new("RGB", (cols * (480 + pad) + pad, rows * (270 + 40) + pad), (244, 247, 251))
    d = ImageDraw.Draw(out)
    for i, n in enumerate(names):
        x, y = pad + (i % cols) * (480 + pad), pad + (i // cols) * (270 + 40)
        d.text((x, y), n, font=bs.font(22), fill=bi.INK)
        out.paste(Image.open(os.path.join(HERE, n + "-480.png")), (x, y + 28))
    out.save(os.path.join(HERE, "contact.png"))


def ad_sizes(names):
    """Each ad at the tile sizes a player meets it at, on Roblox's dark and light page colours."""
    pad = 20
    roww = sum(w for w, _ in AD_SIZES) + pad * (len(AD_SIZES) + 1)
    rowh = AD_SIZES[0][1] + 44
    out = Image.new("RGB", (roww, rowh * len(names) + pad), (25, 27, 29))
    d = ImageDraw.Draw(out)
    for i, n in enumerate(names):
        y = pad + i * rowh
        if i % 2:
            d.rectangle((0, y - 10, roww, y + rowh - 10), fill=(242, 244, 245))
        d.text((pad, y - 4), n, font=bs.font(22), fill=(255, 255, 255) if i % 2 == 0 else bi.INK)
        full = Image.open(os.path.join(HERE, n + ".png"))
        x = pad
        for w, h in AD_SIZES:
            im = bi.rounded(full.resize((w, h), Image.LANCZOS).convert("RGBA"), max(4, w // 40))
            out.paste(im, (x, y + 26), im)
            x += w + pad
    out.save(os.path.join(HERE, "ads-at-size.png"))


def icon_sheet(icons):
    """Old and new side by side at 512, 150 and 50 px, on light and dark."""
    f = bs.font(30)
    keys = list(icons)
    gw, pad, top = 512 + 30 + 150, 56, 70
    band = top + 512 + 40
    out = Image.new("RGBA", (pad + len(keys) * (gw + pad), band * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for b, (bg, ink) in enumerate((((244, 247, 251), bi.INK), ((22, 25, 32), (255, 255, 255)))):
        y0 = b * band
        d.rectangle((0, y0, out.width, y0 + band), fill=bg)
        for i, key in enumerate(keys):
            x = pad + i * (gw + pad)
            d.text((x, y0 + 20), key, font=f, fill=ink)
            for size, ox, oy in ((512, 0, 0), (150, 542, 0), (50, 542, 180)):
                im = icons[key].resize((size, size), Image.LANCZOS).convert("RGBA")
                out.alpha_composite(bi.rounded(im, max(3, round(size * 0.11))), (x + ox, y0 + top + oy))
    return out.convert("RGB")


if __name__ == "__main__":
    only = sys.argv[1:]
    if not only or "icons" in only:
        k = icon_k().convert("RGB")
        k.save(os.path.join(HERE, "icon-K-1024.png"))
        k.resize((512, 512), Image.LANCZOS).save(os.path.join(HERE, "icon-K.png"))
        kb = icon_k(beanie=True).convert("RGB").resize((512, 512), Image.LANCZOS)
        kb.save(os.path.join(HERE, "icon-K-beanie.png"))
        j = Image.open(os.path.join(V2, "icons", "icon-J.png"))
        icon_sheet({"J  live": j, "K  hatch (pick)": k.resize((512, 512), Image.LANCZOS), "K  beanie": kb}).save(os.path.join(HERE, "icons-JK.png"))
        print("wrote icons")
    for name, fn in SET_LIST:
        if only and name not in only and "set" not in only:
            continue
        im = fn().convert("RGB")
        im.save(os.path.join(HERE, name + ".png"))
        im.resize((480, 270), Image.LANCZOS).save(os.path.join(HERE, name + "-480.png"))
        print("wrote", name)
    have = [n for n, _ in SET_LIST if os.path.exists(os.path.join(HERE, n + "-480.png"))]
    contact(have)
    ad_sizes([n for n in have if n.startswith("ad-")])
