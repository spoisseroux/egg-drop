"""Store set redo: seven thumbnails and three ads in icon J's look (FEATURE-SET-BRIEF.md).

Spencer 2026-11-21: "We need to redo all the thumbnails / update them. And the ads", and on the
first drafts: "we need more info ... customization, toys, playing, ... pocket deck game and
customization, stats". One feature per image, dense, real items only.

Everything is our own Studio captures (../captures/S*.png and ../captures/set/*.png: props,
dressed pets and three real Pocket Deck frames frozen mid-chain) plus code-drawn type, chips and
effects. Every name, price and count printed is read from the game's catalogues at build time.

Run: python build_set.py      -> T1..T7 and ad-A/B/C at 1920x1080, a -480 check of each, and
                                 contact.png (all ten at 480x270).
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(HERE, "..", "icons"))
import build_icons as bi  # noqa: E402

CAP = bi.CAP
SET = os.path.join(CAP, "set")
W, H = 1920, 1080
INK = bi.INK
NAVY = bi.rgb("#0B3C9C")


# ---------------------------------------------------------------- catalogue data (read live)
def read(path):
    return open(os.path.join(REPO, path), encoding="utf-8").read()


def wearables():
    s = read("src/shared/BearRigDefinition.lua")
    j = json.loads(s[s.index("[=[") + 3:s.index("]=]")])
    items = {w["id"]: (w.get("name"), w.get("price")) for w in j["wearableItems"]}
    for m in re.finditer(r'id="([a-z_]+)",base="([a-z_]+)",name="([^"]+)"', read("src/shared/WearableVariants.lua")):
        vid, base, name = m.groups()
        items[vid] = (name, items.get(base, (None, None))[1])
    return items, len(j["wearableItems"])


def decks():
    s = read("src/shared/DeckThemes.lua")
    out = {}
    for m in re.finditer(r'\n ([a-z_]+)=\{name="([^"]+)",order=\d+,tier="[a-z]+",priceStars=(\d+)', s):
        out[m.group(1)] = (m.group(2), int(m.group(3)))
    order = re.search(r"Order\s*=\s*\{(.*?)\}", s, re.S).group(1)
    return out, len(re.findall(r'"([a-z_]+)"', order))


def ball_themes():
    s = read("src/shared/BallThemes.lua")
    order = re.search(r"Themes\.Order=\{(.*?)\}", s, re.S).group(1)
    ids = re.findall(r'"([a-z_]+)"', order)
    ramps = {}
    for tid in ("smileys", "gems", "kittens", "bubbles", "midnight"):
        block = s[s.index("\n " + tid + "={"):]
        block = block[:block.index("pitch=")]
        rs = re.findall(r'ramp\("(#\w+)","(#\w+)","(#\w+)"\)', block)
        if not rs and "vivid" in block:
            rs = re.findall(r'ramp\("(#\w+)","(#\w+)","(#\w+)"\)', s[s.index("local vivid"):s.index("local colourWords")])
        ramps[tid] = rs
    names = dict(re.findall(r'\n ([a-z_]+)=\{name="([^"]+)"', s))
    return ids, ramps, names


def egg_prices():
    look = int(re.search(r"Price=(\d+)", read("src/shared/LookEggCatalog.lua")).group(1))
    stat = int(re.search(r"Price=(\d+)", read("src/shared/StatEggCatalog.lua")).group(1))
    toy = int(re.search(r"leaves it at (\d+), the price of the Toy Egg", read("src/shared/CoachMarks.lua")).group(1))
    return {"toy": toy, "stat": stat, "look": look}


def stats():
    s = read("src/shared/StatCatalog.lua")
    rows = re.findall(r'([a-z]+)=\{id="\1",name="([^"]+)",color=Color3\.fromHex\("(#\w+)"\)', s)
    tiers = [(int(a), b, int(c)) for a, b, c in re.findall(r'\{level=(\d+),name="([^"]+)",total=(\d+)\}', s)]
    return rows, tiers


def feast():
    m = re.search(r'feast=table\.freeze\(\{id="feast",name="([^"]+)",mult=(\d+)', read("src/shared/StatEggCatalog.lua"))
    return m.group(1), int(m.group(2))


def toy_count():
    return len(re.findall(r"^ ([a-z_]+)=table\.freeze\(\{offset", read("src/client/PetToyGeometry.lua"), re.M))


# ---------------------------------------------------------------- drawing kit
def font(size, weight="ExtraBold"):
    return ImageFont.truetype(bi.font_path(f"Nunito-{weight}.ttf"), size)


def star_poly(cx, cy, r, inner=0.45, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = np.radians(rot + i * 180 / n)
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * np.cos(a), cy + rr * np.sin(a)))
    return pts


def chip(text, size=44, price=None, pad=26, fill=(255, 255, 255), ink=INK):
    """Glass pill: white body with a soft top gloss line and a navy ring; optional ★price."""
    f = font(size)
    tw = f.getbbox(text)[2]
    pw = 0
    if price is not None:
        pf = font(size, "Black")
        ptxt = str(price)
        pw = int(size * 1.05) + pf.getbbox(ptxt)[2] + int(size * 0.45)
    h = int(size * 1.55)
    w = tw + pw + pad * 2
    s = 3
    big = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle((0, 0, w * s - 1, h * s - 1), h * s // 2, fill=NAVY + (255,))
    d.rounded_rectangle((5 * s, 5 * s, w * s - 1 - 5 * s, h * s - 1 - 5 * s), (h - 10) * s // 2, fill=fill + (245,))
    d.rounded_rectangle((14 * s, 9 * s, w * s - 14 * s, int(h * s * 0.42)), int(h * s * 0.2), fill=(255, 255, 255, 120))
    im = big.resize((w, h), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    ty = h / 2
    d.text((pad, ty), text, font=f, fill=ink, anchor="lm")
    if price is not None:
        x = pad + tw + int(size * 0.45)
        cx = x + size * 0.5
        d.polygon(star_poly(cx, ty, size * 0.5), fill=bi.rgb("#FFC93C"), outline=bi.rgb("#C77C00"))
        d.text((x + int(size * 1.05), ty), str(price), font=font(size, "Black"), fill=ink, anchor="lm")
    return drop(im, 8, 0.30)


def drop(im, dy=10, alpha=0.32, blur=8):
    sh = Image.new("RGBA", im.size, INK + (0,))
    sh.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    out = Image.new("RGBA", (im.width + blur * 4, im.height + blur * 4 + dy), (0, 0, 0, 0))
    out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)) if False else sh, (blur * 2, blur * 2 + dy))
    out = Image.alpha_composite(Image.new("RGBA", out.size, (0, 0, 0, 0)), out.filter(ImageFilter.GaussianBlur(blur)))
    out.alpha_composite(im, (blur * 2, blur * 2))
    return out


def caption(lines, width, indent=None):
    wm = bi.aero_wordmark(lines=tuple(lines), lead=0.80, outline=5, depth=7,
                          indent=tuple(indent or [0.0] * len(lines)))
    return wm.resize((width, round(wm.height * width / wm.width)), Image.LANCZOS)


def small_mark(width=330):
    return caption(["pocket", "pals"], width, [0.0, 1.05])


def glow(c, cx, cy, r, alpha=0.38):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    g = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * (r / 2.2) ** 2)))
    layer = np.zeros((H, W, 4), np.uint8)
    layer[..., :3] = 255
    layer[..., 3] = (g * alpha * 255).astype(np.uint8)
    c.alpha_composite(Image.fromarray(layer, "RGBA"))


def rays(c, cx, cy, n=18, alpha=0.14, length=1600):
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        a0 = np.radians(i * 360 / n)
        a1 = a0 + np.radians(360 / n / 2)
        d.polygon([(cx, cy), (cx + length * np.cos(a0), cy + length * np.sin(a0)),
                   (cx + length * np.cos(a1), cy + length * np.sin(a1))], fill=(255, 255, 255, int(255 * alpha)))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))


def sparkle(c, cx, cy, r, color=(255, 255, 255)):
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(star_poly(cx, cy, r, inner=0.18, n=4, rot=0), fill=color + (235,))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))


def burst(text, size, fill=(255, 210, 70), ink=(196, 18, 111)):
    """A gold starburst badge with bold text."""
    r = int(size * 1.45)
    s = 3
    big = Image.new("RGBA", (r * 2 * s, r * 2 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.polygon(star_poly(r * s, r * s, r * s, inner=0.78, n=14), fill=NAVY + (255,))
    d.polygon(star_poly(r * s, r * s, (r - 9) * s, inner=0.78, n=14), fill=fill + (255,))
    im = big.resize((r * 2, r * 2), Image.LANCZOS)
    ImageDraw.Draw(im).text((r, r), text, font=font(size, "Black"), fill=(255, 255, 255), anchor="mm",
                            stroke_width=max(4, size // 10), stroke_fill=ink)
    return drop(im, 8, 0.3)


def cut(name, scale=1.0, rot=0.0, cool=0.14, folder=None):
    path = os.path.join(folder or SET, name + ".png")
    if not os.path.exists(path):
        path = os.path.join(CAP, name + ".png")
    im = bi.load(path, scale, rot)
    return bi.relight(im, cool=cool) if cool else im


def put(c, im, cx, bottom=None, top=None, shadow=True, contact=True):
    """Paste centred at cx with its bottom (or top) edge at the given y."""
    x = int(cx - im.width / 2)
    y = int(bottom - im.height) if bottom is not None else int(top)
    if contact and bottom is not None:
        bi.contact(c, cx, bottom - 6, im.width * 0.36, 16, alpha=80, blur=14)
    if shadow:
        bi.soft_shadow(c, im, (x, y), dx=12, dy=8, blur=16, alpha=0.20)
    bi.paste(c, im, (x, y))
    return x, y


def paste_center(c, im, cx, cy):
    bi.paste(c, im, (int(cx - im.width / 2), int(cy - im.height / 2)))


def base(floor=0.84):
    c = bi.field(*bi.SKY, floor=floor, w=W, h=H)
    return c


def bubbles(c, spots):
    for x, y, d in spots:
        bi.put_bubble(c, x, y, d, 0.9)


# ---------------------------------------------------------------- the set
WEAR, N_WEAR = wearables()
DECKS, N_DECKS = decks()
BALL_IDS, BALL_RAMPS, BALL_NAMES = ball_themes()
EGGS = egg_prices()
STATS, TIERS = stats()
FEAST_NAME, FEAST_MULT = feast()
N_TOYS = toy_count()


def t1(tag=True):
    """pocket pals + merge · hatch · dress up. Deck big lower left, the pals right, an egg top right."""
    c = base(0.86)
    glow(c, 1400, 560, 900, 0.30)
    rays(c, 1400, 560, alpha=0.08)
    bubbles(c, [(1830, 90, 120), (1680, 60, 46), (900, 70, 60)])
    deck = cut("D-cloud", 0.98, rot=4, cool=0)
    bi.soft_shadow(c, deck, (-60, 500), dx=16, dy=14, blur=20, alpha=0.32)
    bi.paste(c, deck, (-60, 500))
    bun = cut("S13", 1.08)
    put(c, bun, 1660, bottom=1040)
    bear = cut("S12", 1.20)
    put(c, bear, 1330, bottom=1075)
    egg = cut("P-egg-stat", 0.55, rot=-12)
    paste_center(c, egg, 1810, 300)
    sparkle(c, 1740, 190, 26)
    sparkle(c, 1880, 400, 18)
    wm = caption(["pocket", "pals"], 700, [0.0, 1.05])
    bi.paste(c, wm, (40, 20))
    if tag:
        p = chip("merge · hatch · dress up", 50)
        bi.paste(c, p, (40, 20 + wm.height - 10))
        x = 40
        for txt in (f"{N_TOYS} toys", f"{N_WEAR} outfit items", f"{N_DECKS} decks"):
            ch = chip(txt, 36)
            bi.paste(c, ch, (x, 20 + wm.height + p.height - 34))
            x += ch.width - 20
    return c


def t2(prices=True, words=("dress up", "your pal")):
    """Five pals shoulder to shoulder, each with its item's name and price; the four dyes."""
    c = base(0.86)
    glow(c, 960, 640, 900, 0.28)
    rays(c, 960, 640, alpha=0.07)
    bubbles(c, [(1840, 330, 80), (1500, 120, 40)])
    floor = 1000
    row = [("F7a", 1.04, 205, ("flowercrown",)), ("F7b", 1.04, 560, ("sunhat_peach",)),
           ("S12", 1.16, 960, ("beanie_butter",)), ("F7c", 1.04, 1360, ("hoodie",)), ("F13", 1.04, 1715, ("beads",))]
    for name, s, cx, _ in row[:2] + row[3:]:
        put(c, cut(name, s), cx, bottom=floor)
    put(c, cut("S12", 1.16), 960, bottom=floor + 40)
    if prices:
        for name, s, cx, items in row:
            nm, pr = WEAR[items[0]]
            ch = chip(nm, 32, pr)
            paste_center(c, ch, cx, 1030)
    cap = caption(list(words), 760, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    # dye dots, top right: the four hue jars
    x = 930
    for jar in ("rose", "tide", "citrus", "iris"):
        j = cut("P-jar-" + jar, 0.32, cool=0)
        bi.paste(c, drop(j, 6, 0.22), (x, 30))
        x += j.width + 4
    ch = chip("4 dyes · 3 finishes", 32)
    bi.paste(c, ch, (930, 190))
    return c


def t3(words=("merge", "big chains")):
    """The real deck, straight-on, frozen at Chain ×4; the Bear peeking; a ×4 burst; the five sizes."""
    c = base(0.88)
    glow(c, 820, 640, 900, 0.30)
    rays(c, 820, 640, alpha=0.08)
    bubbles(c, [(1850, 100, 110), (1700, 70, 44)])
    deck = cut("D-bigmerge", 1.06, cool=0)
    dx, dy = 70, 1080 - deck.height + 40
    peek = cut("S5", 0.62)
    bi.paste(c, peek, (dx + deck.width - peek.width - 120, dy - peek.height + 80))
    bi.soft_shadow(c, deck, (dx, dy), dx=14, dy=12, blur=20, alpha=0.34)
    bi.paste(c, deck, (dx, dy))
    b = burst("×4", 92)
    paste_center(c, b, dx + 1180, dy + 170)  # clear of the merge on the screen
    cap = caption(list(words), 720, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    # size ladder, right: the Bubbles balls I..V, each merging into the next
    ramps = BALL_RAMPS["bubbles"]
    lad = Image.new("RGBA", (56, 190), (0, 0, 0, 0))
    ys = [9, 30, 58, 95, 150]
    rs = [5, 8, 11, 15, 21]
    for i, (y, r) in enumerate(zip(ys, rs)):
        bi.pixel_ball(lad, 28, y, r, i, ramps=ramps, ink=(42, 36, 80), face="dots")
    lad = lad.resize((lad.width * 7 // 2, lad.height * 7 // 2), Image.NEAREST)
    bi.paste(c, drop(lad, 8, 0.22), (1600, 380))
    ch = chip("merge up 5 sizes", 36)
    bi.paste(c, ch, (1520, 300))
    return c


def t4():
    """Hatch surprise eggs: the Bunny meets a cracked Toy Egg; six toys and four dye jars fly out."""
    c = base(0.86)
    ex, ey = 1080, 640
    glow(c, ex, ey - 80, 1000, 0.45)
    rays(c, ex, ey - 80, n=22, alpha=0.16)
    bubbles(c, [(1860, 80, 90)])
    bun = cut("F13", 1.12)
    put(c, bun, 330, bottom=1040)
    egg = cut("P-egg-open", 1.12, cool=0)
    put(c, egg, ex, bottom=1000)
    arc = [("P-toy-ball", 0.42, 690, 520), ("P-toy-bone", 0.38, 760, 300), ("P-toy-top", 0.40, 930, 150),
           ("P-toy-carrot", 0.42, 1200, 120), ("P-toy-sparkler", 0.42, 1390, 250), ("P-toy-deck", 0.42, 1500, 430),
           ("P-jar-rose", 0.36, 830, 690), ("P-jar-tide", 0.34, 1270, 330), ("P-jar-citrus", 0.34, 1010, 330),
           ("P-jar-iris", 0.36, 1350, 600)]
    for name, s, x, y in arc:
        im = cut(name, s, rot=np.random.RandomState(len(name) + x).uniform(-14, 14), cool=0)
        bi.soft_shadow(c, im, (int(x - im.width / 2), int(y - im.height / 2)), dx=8, dy=10, blur=10, alpha=0.22)
        paste_center(c, im, x, y)
    for sx, sy, r in ((880, 460, 26), (1230, 470, 22), (1100, 90, 18), (700, 380, 16), (1450, 140, 20)):
        sparkle(c, sx, sy, r)
    # the three eggs on sale, lower right
    y = 500
    for name, key, label in (("P-egg-toy", "toy", "Toy Egg"), ("P-egg-stat", "stat", "Stat Egg"), ("P-egg-hue", "look", "Customization Egg")):
        egg_im = cut(name, 0.30, cool=0)
        ch = chip(label, 30, EGGS[key])
        bi.paste(c, drop(egg_im, 6, 0.2), (W - ch.width - 30 - egg_im.width + 30, y))
        bi.paste(c, ch, (W - ch.width - 20, y + egg_im.height // 2 - ch.height // 2 + 6))
        y += egg_im.height + 18
    cap = caption(["hatch", "surprise eggs"], 760, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    nd = chip("toys never repeat", 34)
    bi.paste(c, nd, (40, 20 + cap.height - 10))
    return c


def t5():
    """Play with friends: three pals and their toys on Sky over a Leaf lawn."""
    c, _ = leaf_floor()
    glow(c, 960, 560, 900, 0.22)
    bubbles(c, [(1840, 90, 110), (1690, 60, 44)])
    put(c, cut("F7a", 0.92), 420, bottom=900)
    ball = cut("P-toy-ball", 0.34, cool=0)
    put(c, ball, 600, bottom=915, shadow=False)
    put(c, cut("S12", 1.14), 980, bottom=1010)
    bone = cut("P-toy-bone", 0.34, rot=-10, cool=0)
    put(c, bone, 1180, bottom=1030, shadow=False)
    hop = cut("S14", 1.02, rot=-8)
    bi.contact(c, 1520, 1010, hop.width * 0.26, 14, alpha=90, blur=16)
    dots(c, 1210, 940, 1450, 590, lift=200)
    bi.paste(c, hop, (1520 - hop.width // 2, 150))
    car = cut("P-toy-carrot", 0.36, rot=20, cool=0)
    paste_center(c, car, 1690, 300)
    cap = caption(["play with", "friends"], 700, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    ch = chip("park · toys · friends", 34)
    bi.paste(c, ch, (40, 20 + cap.height - 10))
    return c


def leaf_floor(split=0.80):
    sky = np.asarray(bi.field(*bi.SKY, floor=1.0, w=W, h=H).convert("RGB")).astype(np.float32)
    leaf = np.asarray(bi.field("#6EDB7A", "#1E9E3A", floor=1.0, w=W, h=H).convert("RGB")).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    line = H * split + 40 * np.sin(xx / W * np.pi * 1.2)
    dist = yy - line
    m = np.clip(dist / 2.0 + 0.5, 0, 1)[..., None]
    img = sky * (1 - m) + leaf * m
    lip = np.exp(-((dist - 9) / 8) ** 2)[..., None] * (dist > 0)[..., None]
    img = img + (255 - img) * lip * 0.6
    return Image.fromarray(img.clip(0, 255).astype(np.uint8)).convert("RGBA"), line


def dots(c, x0, y0, x1, y1, lift=200, n=9):
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        t = (i + 0.5) / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t - lift * 4 * t * (1 - t)
        r = 6 + 9 * t
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, int(130 + 110 * t)))
    c.alpha_composite(layer)


def t6():
    """Customize your deck: three real decks fanned, their names and prices; the ball themes."""
    c = base(0.86)
    glow(c, 1080, 620, 900, 0.30)
    rays(c, 1080, 620, alpha=0.08)
    bubbles(c, [(1860, 90, 100)])
    back_l = cut("D-prism", 0.78, rot=10, cool=0)
    back_r = cut("D-lagoon", 0.78, rot=-10, cool=0)
    front = cut("D-cloud", 0.92, cool=0)
    for im, xy in ((back_l, (300, 400)), (back_r, (1120, 250))):
        bi.soft_shadow(c, im, xy, dx=12, dy=14, blur=18, alpha=0.30)
        bi.paste(c, im, xy)
    fxy = (int(1120 - front.width / 2), 500)
    bi.soft_shadow(c, front, fxy, dx=14, dy=16, blur=22, alpha=0.38)
    bi.paste(c, front, fxy)
    for pid, xy in (("prism_flare", (330, 430)), ("lagoon", (1560, 200)), ("cloud_glass", (1120, 1000))):
        nm, pr = DECKS[pid]
        ch = chip(nm, 36, pr)
        bi.paste(c, ch, (xy[0] - ch.width // 2 if pid == "cloud_glass" else xy[0], xy[1]))
    cap = caption(["customize", "your deck"], 700, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    # ball themes: one size-III ball of each, with names
    y = 20 + cap.height + 10
    ch = chip(f"{N_DECKS} decks · {len(BALL_IDS)} ball themes", 36)
    bi.paste(c, ch, (40, y))
    y = 950
    for i, tid in enumerate(("smileys", "gems", "kittens", "bubbles", "midnight")):
        rp = BALL_RAMPS[tid]
        lad = Image.new("RGBA", (26, 26), (0, 0, 0, 0))
        ink = (255, 255, 255) if tid == "midnight" else (21, 16, 43)
        bi.pixel_ball(lad, 13, 13, 11.5, i, ramps=rp, ink=ink, face="dots" if tid in ("gems", "bubbles", "midnight") else "smiley")
        lad = lad.resize((104, 104), Image.NEAREST)
        bi.paste(c, drop(lad, 6, 0.25), (24 + i * 98, y))
    return c


def t7():
    """Level up your pal: the Bunny, a stats card from StatCatalog, a Feast snack."""
    c = base(0.86)
    glow(c, 420, 600, 800, 0.30)
    bubbles(c, [(1860, 90, 100), (1720, 60, 40)])
    put(c, cut("F13", 1.18), 380, bottom=1040)
    # card
    cx0, cy0, cw, chh = 760, 250, 1100, 740
    s = 2
    card = Image.new("RGBA", (cw * s, chh * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((0, 0, cw * s - 1, chh * s - 1), 46 * s, fill=NAVY + (255,))
    d.rounded_rectangle((7 * s, 7 * s, cw * s - 8 * s, chh * s - 8 * s), 40 * s, fill=(244, 250, 255, 240))
    d.rounded_rectangle((26 * s, 14 * s, cw * s - 26 * s, 120 * s), 30 * s, fill=(255, 255, 255, 150))
    card = card.resize((cw, chh), Image.LANCZOS)
    d = ImageDraw.Draw(card)
    vals = {"heart": 14, "power": 12, "energy": 9, "jump": 11, "speed": 8, "smarts": 7}
    total = sum(vals.values())
    tier = [t for t in TIERS if total >= t[2]][-1][1]
    d.text((50, 46), f"{tier} Keeper", font=font(60, "Black"), fill=INK)
    d.text((cw - 50, 56), f"total {total}", font=font(40), fill=(90, 110, 135), anchor="ra")
    y = 160
    for sid, name, hexc in STATS:
        icon = Image.open(os.path.join(REPO, "assets", "ui", "stat-icons", f"icon-{sid}-128.png")).convert("RGBA").resize((76, 76), Image.LANCZOS)
        card.alpha_composite(icon, (44, y - 6))
        d.text((140, y + 32), name, font=font(46), fill=INK, anchor="lm")
        bx0, bx1 = 400, cw - 160
        d.rounded_rectangle((bx0, y + 12, bx1, y + 52), 20, fill=(214, 226, 240))
        frac = vals[sid] / 20
        d.rounded_rectangle((bx0, y + 12, bx0 + int((bx1 - bx0) * frac), y + 52), 20, fill=bi.rgb(hexc))
        d.rounded_rectangle((bx0 + 10, y + 16, bx0 + int((bx1 - bx0) * frac) - 10, y + 26), 6, fill=(255, 255, 255, 120))
        d.text((cw - 60, y + 32), str(vals[sid]), font=font(48, "Black"), fill=INK, anchor="rm")
        y += 94
    bi.soft_shadow(c, card, (cx0, cy0), dx=10, dy=16, blur=22, alpha=0.30)
    bi.paste(c, card, (cx0, cy0))
    jx = cx0 + 400 + int((cw - 160 - 400) * vals["jump"] / 20)
    jy = cy0 + 160 + 3 * 94 + 32
    b = burst("+1", 54, fill=bi.rgb("#B9EE5A"), ink=(30, 120, 40))
    paste_center(c, b, jx + 40, jy)
    lv = chip("LEVEL UP!", 34)
    bi.paste(c, lv, (jx - 40 - lv.width, jy - lv.height // 2))
    fe = cut("P-feast", 0.62, cool=0)
    put(c, fe, 690, bottom=1050)
    ch = chip(f"{FEAST_NAME} ×{FEAST_MULT} XP", 36)
    bi.paste(c, ch, (560, 1080 - ch.height - 4))
    cap = caption(["level up", "your pal"], 680, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    return c


def with_mark(fn, *a, pos="br", **k):
    c = fn(*a, **k)
    m = small_mark(300)
    xy = (W - m.width - 24, H - m.height - 10) if pos == "br" else (W - m.width - 24, 14)
    bi.paste(c, m, xy)
    return c


SET_LIST = [
    ("T1-pocket-pals", lambda: t1()),
    ("T2-dress-up", lambda: with_mark(t2, pos="tr")),
    ("T3-merge", lambda: with_mark(t3, pos="tr")),
    ("T4-hatch", lambda: with_mark(t4, pos="tr")),
    ("T5-play", lambda: with_mark(t5)),
    ("T6-decks", lambda: with_mark(t6)),
    ("T7-level-up", lambda: with_mark(t7, pos="tr")),
    ("ad-A", lambda: t1()),
    ("ad-B", lambda: with_mark(t3, ("merge. hatch.", "repeat."), pos="tr")),
    ("ad-C", lambda: with_mark(t2, False, ("make it", "yours"), pos="tr")),
]


def contact(names):
    ims = [Image.open(os.path.join(HERE, n + "-480.png")) for n in names]
    pad = 16
    cols = 2
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * (480 + pad) + pad, rows * (270 + 40) + pad), (244, 247, 251))
    d = ImageDraw.Draw(out)
    for i, (n, im) in enumerate(zip(names, ims)):
        x, y = pad + (i % cols) * (480 + pad), pad + (i // cols) * (270 + 40)
        d.text((x, y), n, font=font(22), fill=INK)
        out.paste(im, (x, y + 28))
    out.save(os.path.join(HERE, "contact.png"))


if __name__ == "__main__":
    only = sys.argv[1:]
    done = []
    for name, fn in SET_LIST:
        if only and name not in only:
            continue
        im = fn().convert("RGB")
        im.save(os.path.join(HERE, name + ".png"))
        im.resize((480, 270), Image.LANCZOS).save(os.path.join(HERE, name + "-480.png"))
        done.append(name)
        print("wrote", name)
    contact([n for n, _ in SET_LIST if os.path.exists(os.path.join(HERE, n + "-480.png"))])
