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
from PIL import Image, ImageDraw, ImageFilter

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
def hero(c, ox=0, oy=0, k=1.0, beanie=False, tilt=-3.0, extras=True):
    """Drawn in the 1024 icon frame, then placed at (ox, oy) scaled by k.
    Back to front: light, the deck with its screen lit, the cap flying off, the egg's inside, the Bear, the cup,
    his paws on its rim, shell chips and sparkles."""
    def X(x):
        return ox + x * k

    def Y(y):
        return oy + y * k

    ex, rim_y = 512, 642  # the egg's centre line and the height of its crack, in the icon frame
    glow(c, X(ex), Y(560), 900 * k, 0.42)
    rays(c, X(ex), Y(600), n=18, alpha=0.11, length=1500 * k)

    # the deck
    deck = bi.deck_with_hero(hatch_screen)
    deck = scaled(deck, 968 * k / deck.width, tilt)
    dxy = (int(X(ex) - deck.width / 2), int(Y(506)))
    bi.contact(c, X(ex), Y(1000), deck.width * 0.40, 20 * k, alpha=90, blur=int(18 * k))
    bi.soft_shadow(c, deck, dxy, dx=int(12 * k), dy=int(14 * k), blur=int(20 * k), alpha=0.34)
    bi.paste(c, deck, dxy)
    glow(c, X(ex), Y(740), 520 * k, 0.55, (255, 244, 190))  # the screen's light, spilling up over the shell

    cap, cup = egg_parts()
    e = 1.04 * k  # egg scale: 405 wide capture -> about 420 in the icon frame
    etop = Y(rim_y) - 240 * e  # capture row 240 (mid zigzag) sits on rim_y
    exy = (int(X(ex) - 405 * e / 2), int(etop))

    # the cap, thrown up and to the right, behind the Bear's ear
    cp = cap.crop((0, 0, 405, 285))
    cp = scaled(cp, e * 0.78, -32)
    cxy = (int(X(668)), int(Y(28)))
    bi.soft_shadow(c, cp, cxy, dx=int(8 * k), dy=int(12 * k), blur=int(12 * k), alpha=0.22)
    bi.paste(c, cp, cxy)

    # the egg's inside: a deep amber mouth behind the Bear, with a hot core
    s = 3
    mw, mh = int(390 * e), int(120 * e)
    mouth = Image.new("RGBA", (mw * s, mh * s), (0, 0, 0, 0))
    ImageDraw.Draw(mouth).ellipse((0, 0, mw * s - 1, mh * s - 1), fill=(214, 120, 12, 255))
    ImageDraw.Draw(mouth).ellipse((mw * s * 0.14, mh * s * 0.16, mw * s * 0.86, mh * s * 0.9), fill=(255, 226, 120, 255))
    mouth = mouth.resize((mw, mh), Image.LANCZOS).filter(ImageFilter.GaussianBlur(2 * k))
    bi.paste(c, mouth, (int(X(ex) - mw / 2), int(Y(rim_y) - mh * 0.62)))

    # the Bear, rising out of it
    if beanie:
        body, _, _ = bs.bear_parts(1.22 * k)
        head = body.crop((0, 0, body.width, round(640 * 1.22 * k)))
        bxy = (int(X(ex + 8) - 402 * 1.22 * k), int(Y(rim_y - 30) - 482 * 1.22 * k))
    else:
        head = bi.load(os.path.join(CAP, "S3.png"))
        head = bi.relight(scaled(head.crop((0, 0, head.width, 652)), 0.76 * k), cool=0.14)  # shoulders stay in the egg
        bxy = (int(X(ex + 14) - head.width / 2), int(Y(rim_y + 8) - 640 * 0.76 * k))
    bi.soft_shadow(c, head, bxy, dx=int(12 * k), dy=int(8 * k), blur=int(16 * k), alpha=0.18)
    bi.paste(c, head, bxy)

    # the cup in front, then his paws on its rim
    cupc = scaled(cup, e)
    bi.soft_shadow(c, cupc, exy, dx=0, dy=int(-10 * k), blur=int(10 * k), alpha=0.22)  # up onto his chin
    bi.soft_shadow(c, cupc, exy, dx=int(10 * k), dy=int(12 * k), blur=int(14 * k), alpha=0.30)  # onto the screen
    bi.paste(c, cupc, exy)
    pl, pr = paws(0.78 * k)
    for paw, px, r in ((pl, ex - 186, 16), (pr, ex + 188, -16)):
        paw = paw.rotate(r, Image.BICUBIC, expand=True)
        xy = (int(X(px) - paw.width / 2), int(Y(rim_y + 22) - paw.height * 0.55))
        bi.soft_shadow(c, paw, xy, dx=int(4 * k), dy=int(12 * k), blur=int(8 * k), alpha=0.34)
        bi.paste(c, paw, xy)

    if extras:
        for x, y, r, rot in ((250, 470, 26, 20), (196, 330, 18, -30), (800, 430, 22, 200), (905, 330, 15, 60)):
            shard(c, X(x), Y(y), r * k, rot)
        for x, y, r in ((150, 210, 30), (880, 80, 22), (300, 120, 16), (940, 470, 18), (86, 430, 16)):
            sparkle(c, X(x), Y(y), r * k)


# ---------------------------------------------------------------- icon K
def icon_k(beanie=False):
    """The handheld, an egg cracking on its screen, the Bear popping out. No type (see REVIEW.md). Sky."""
    c = bi.field(*bi.SKY, floor=0.84)
    bi.put_bubble(c, 96, 96, 110, 0.9)
    bi.put_bubble(c, 964, 250, 56, 0.85)
    hero(c, beanie=beanie)
    return c


# ---------------------------------------------------------------- thumbnails
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


def t1(words=NAME, steps=True, mark=False, bunny=True):
    """The lead frame and the Home Page tile: the name, the hatch on the handheld, and the first minute in three
    numbered chips. The Rose Bunny watches from the left (the second pal, bottom corner, clearly smaller).
    The ad drops the Bunny and the chips: one hero, one line, the name as a small mark."""
    c = bs.base(0.86)
    bs.bubbles(c, [(820, 96, 70), (1880, 560, 56), (60, 560, 44)])
    hero(c, ox=790, oy=8, k=0.985)
    if bunny:
        bun = bs.cut("B2", 0.80)
        bs.put(c, bun, 196, bottom=1048)
    wm = bs.caption(list(words), 800, [0.0, 0.0])
    bi.paste(c, wm, (36, 16))
    if steps:
        y = 16 + wm.height + 2
        for i, txt in enumerate(("merge balls", "hatch your pal", "raise it in the garden")):
            ch = step_chip(i + 1, txt, 46)
            bi.paste(c, ch, (40 + i * 34, y))
            y += ch.height - 22
    if mark:
        m = name_mark(470)
        bi.paste(c, m, (40, H - m.height - 176))  # clear of the bottom 15%
    return c


def retitled(fn, *a, pos="tr", **k):
    """A live v2 frame, unchanged, with the corner mark reading the new name."""
    c = fn(*a, **k)
    m = name_mark(372)
    xy = (W - m.width - 20, H - m.height - 8) if pos == "br" else (W - m.width - 20, 10)
    bi.paste(c, m, xy)
    return c


SET_LIST = [
    ("T1-hatch-a-handheld-pal", lambda: t1()),
    ("T2-merge", lambda: retitled(bs.t3, ("merge", "big chains"))),
    ("T3-hatch-eggs", lambda: retitled(bs.t4)),
    ("T4-level-up", lambda: retitled(bs.t7)),
    ("T5-dress-up", lambda: retitled(bs.t2)),
    ("T6-play", lambda: retitled(bs.t5)),
    ("T7-decks", lambda: retitled(bs.t6, pos="br")),
    ("ad-D-merge-hatch", lambda: t1(("merge balls.", "hatch a pal."), steps=False, mark=True, bunny=False)),
]


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
    contact([n for n, _ in SET_LIST if os.path.exists(os.path.join(HERE, n + "-480.png"))])
