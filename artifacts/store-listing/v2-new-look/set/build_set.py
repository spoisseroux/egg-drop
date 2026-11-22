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
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

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


# ---------------------------------------------------------------- the peek (S10 Bear over a deck edge)
PAW_DY = 508  # S10-paws.png is the same frame as S10.png, trimmed: its rows start 508 px down


def bear_parts(scale, cool=0.14):
    """S10 (front-on Bear, paws forward) split like build_icons.icon_e: the body with the paws
    matted out, and each paw on its own. Returned at `scale`, relit; the body keeps S10's frame."""
    full = np.asarray(Image.open(os.path.join(CAP, "S10.png")).convert("RGBA")).astype(np.float32)
    pm = np.asarray(Image.open(os.path.join(CAP, "S10-paws.png")).convert("RGBA")).astype(np.float32)
    paw_a = np.zeros(full.shape[:2], np.float32)
    paw_a[PAW_DY:PAW_DY + pm.shape[0]] = pm[:full.shape[0] - PAW_DY, :, 3] / 255
    body = full.copy()
    body[..., 3] *= 1 - np.clip(paw_a * 1.4, 0, 1)
    pw = full.copy()
    pw[..., 3] = np.minimum(full[..., 3], paw_a * 255)
    mid = full.shape[1] // 2
    left, right = pw.copy(), pw.copy()
    left[:, mid:, 3] = 0
    right[:, :mid, 3] = 0

    def img(arr, trim=True):
        im = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
        if trim:
            im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
        return bi.relight(im, cool=cool) if cool else im

    return img(body, trim=False), img(left), img(right)


def peek_head(c, cx, edge_y, scale=0.70, tilt=0.0, chin=482, hide=70):
    """Stage 1 of a peek, pasted BEFORE the deck: the Bear's head tucked so the deck's top edge
    (canvas y `edge_y`) crosses S10 row `chin`, just under his mouth. `hide` more rows carry on
    behind the deck so a tilt never opens a gap. Returns the paws for peek_paws()."""
    body, paw_l, paw_r = bear_parts(scale)
    head = body.crop((0, 0, body.width, round((chin + hide) * scale)))
    px, py = 402 * scale, chin * scale  # the chin point, in the head image
    if tilt:
        big = Image.new("RGBA", (head.width * 2, head.height * 2), (0, 0, 0, 0))
        big.paste(head, (int(head.width - px), int(head.height - py)))  # chin at the centre
        head = big.rotate(tilt, Image.BICUBIC)
        px, py = head.width / 2, head.height / 2
    xy = (int(cx - px), int(edge_y - py))
    bi.soft_shadow(c, head, xy, dx=12, dy=8, blur=16, alpha=0.18)
    bi.paste(c, head, xy)
    return paw_l, paw_r


def peek_paws(c, deck, dxy, paws, xs, edge_y, over=0.50, rot=(14, -14)):
    """Stage 2, pasted AFTER the deck: each paw rests on the top edge at canvas x in `xs`, with
    `over` of its height above the edge and the rest in front of the faceplate. Under each paw a
    tight contact shadow and a longer soft one, both clipped to the deck so nothing lands on sky."""
    on_deck = Image.new("L", c.size, 0)
    on_deck.paste(deck.getchannel("A"), dxy)
    for paw, x, r in zip(paws, xs, rot):
        if r:
            paw = paw.rotate(r, Image.BICUBIC, expand=True)
        xy = (int(x - paw.width / 2), int(edge_y - paw.height * over))
        for ddx, ddy, blur, alpha in ((4, 22, 13, 0.50), (1, 7, 4, 0.60)):
            sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
            a = paw.getchannel("A").point(lambda v: int(v * alpha))
            ink = Image.new("RGBA", paw.size, (8, 30, 86, 0))
            ink.putalpha(a)
            sh.paste(ink, (xy[0] + ddx, xy[1] + ddy))
            sh = sh.filter(ImageFilter.GaussianBlur(blur))
            sh.putalpha(Image.fromarray((np.asarray(sh.getchannel("A")).astype(np.float32)
                                         * np.asarray(on_deck) / 255).astype(np.uint8)))
            c.alpha_composite(sh)
        bi.paste(c, paw, xy)


# ---------------------------------------------------------------- the set
WEAR, N_WEAR = wearables()
DECKS, N_DECKS = decks()
BALL_IDS, BALL_RAMPS, BALL_NAMES = ball_themes()
EGGS = egg_prices()
STATS, TIERS = stats()
FEAST_NAME, FEAST_MULT = feast()
N_TOYS = toy_count()
N_CHARMS = len(re.findall(r'"([a-z]+)"', re.search(r"Order=table\.freeze\(\{(.*?)\}", read("src/shared/PetCharmCatalog.lua")).group(1)))


def gold_star(c, cx, cy, r, rot=-90):
    """A chunky gold star with a navy rim, like the Stars wallet icon."""
    s = 3
    n = int(r * 2 + 16)
    big = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    m = n * s / 2
    d.polygon(star_poly(m, m, (r + 6) * s, inner=0.52, rot=rot), fill=NAVY + (255,))
    d.polygon(star_poly(m, m, r * s, inner=0.50, rot=rot), fill=bi.rgb("#FFC93C") + (255,))
    d.polygon(star_poly(m - r * s * 0.10, m - r * s * 0.12, r * s * 0.52, inner=0.50, rot=rot), fill=bi.rgb("#FFE58A") + (255,))
    im = drop(big.resize((n, n), Image.LANCZOS), 5, 0.25, blur=5)
    paste_center(c, im, cx, cy)


def loose_ball(c, cx, cy, tier, k, theme="bubbles", r=None, face="dots"):
    """One pixel ball of a theme, flying free of the screen: drawn on the LCD grid, scaled by k."""
    r = r or (5, 8, 11, 15, 21)[tier]
    n = int(r * 2 + 6)
    px = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    bi.pixel_ball(px, n / 2, n / 2, r, tier, ramps=BALL_RAMPS[theme], ink=(42, 36, 80), face=face)
    px = px.resize((n * k, n * k), Image.NEAREST)
    paste_center(c, drop(px, 7, 0.24, blur=6), cx, cy)


def t1(tag=True):
    """pocket pals + merge · hatch · dress up. Deck big lower left, the pals right; a cracked Toy
    Egg top centre with its toys bursting right across the top."""
    c = base(0.86)
    glow(c, 1400, 560, 900, 0.30)
    rays(c, 1400, 560, alpha=0.08)
    ex, ey = EGG1
    glow(c, ex, ey, 620, 0.40)
    rays(c, ex, ey, n=16, alpha=0.13, length=760)
    bubbles(c, B1)
    deck = cut("D-cloud", 0.98, rot=4, cool=0)
    bi.soft_shadow(c, deck, (-60, 526), dx=16, dy=14, blur=20, alpha=0.32)
    bi.paste(c, deck, (-60, 526))  # its top edge clear of the count chips
    for name, sc, x, y, r in TOYS1:
        im = cut(name, sc, rot=r, cool=0)
        bi.soft_shadow(c, im, (int(x - im.width / 2), int(y - im.height / 2)), dx=6, dy=8, blur=8, alpha=0.2)
        paste_center(c, im, x, y)
    egg = cut("P-egg-open", EGG1_S, rot=-8, cool=0)
    bi.soft_shadow(c, egg, (ex - egg.width // 2, ey - egg.height // 2), dx=8, dy=10, blur=10, alpha=0.22)
    paste_center(c, egg, ex, ey)
    for x, y, r, rot in STARS1:
        gold_star(c, x, y, r, rot)
    bun = cut("B2", 1.10)
    put(c, bun, 1720, bottom=1040)  # clear of the Bear's cheek
    bear = cut("B1", 1.28)
    put(c, bear, 1300, bottom=1075)
    for sx, sy, r in SPARK1:
        sparkle(c, sx, sy, r)
    wm = caption(["pocket", "pals"], 700, [0.0, 1.05])
    bi.paste(c, wm, (40, 20))
    if tag:
        p = chip("merge · hatch · dress up · train", 50)
        bi.paste(c, p, (40, 20 + wm.height - 10))
        x = 40
        for txt in ("clothes", "colors", "toys", "decks", "stats", "& more"):
            ch = chip(txt, 36)
            bi.paste(c, ch, (x, 20 + wm.height + p.height - 34))
            x += ch.width - 20
    return c


EGG1, EGG1_S = (1010, 262), 0.84
B1 = [(790, 60, 70), (1900, 420, 60)]
TOYS1 = (("P-toy-top", 0.30, 838, 230, -14), ("P-jar-tide", 0.24, 850, 455, -10),
         ("P-toy-sparkler", 0.36, 1168, 118, -28), ("P-toy-ball", 0.38, 1318, 168, 0),
         ("P-jar-citrus", 0.24, 1208, 352, 12), ("P-toy-bone", 0.30, 1502, 96, 14),
         ("P-toy-carrot", 0.33, 1668, 196, 30), ("P-toy-deck", 0.30, 1812, 92, -12),
         ("P-jar-rose", 0.25, 1846, 268, 12), ("P-jar-iris", 0.22, 1482, 262, -8))
STARS1 = ((930, 60, 30, -80), (1420, 60, 22, -100), (1590, 330, 24, -75), (1745, 330, 18, -95), (760, 330, 20, -100))
SPARK1 = ((1100, 60, 22), (1250, 60, 16), (1400, 300, 18), (1610, 60, 16), (1900, 180, 18), (900, 370, 16), (1740, 150, 14))


def t2(prices=True, words=("dress up", "your pal")):
    """Five pals shoulder to shoulder, each with its item's name and price; the four dyes."""
    c = base(0.86)
    glow(c, 960, 640, 900, 0.28)
    rays(c, 960, 640, alpha=0.07)
    bubbles(c, [(1840, 330, 80), (1500, 120, 40)])
    floor = 1000
    row = [("C7a", 1.02, 205, ("flowercrown",)), ("F7b", 1.04, 560, ("sunhat_peach",)),
           ("C1", 1.22, 960, ("beanie_butter",)), ("C7c", 1.02, 1360, ("hoodie",)), ("C13", 1.04, 1715, ("beads",))]
    for name, s, cx, _ in row[:2] + row[3:]:
        put(c, cut(name, s), cx, bottom=floor)
    put(c, cut("C1", 1.22), 960, bottom=floor + 40)
    if prices:
        for name, s, cx, items in row:
            nm, pr = WEAR[items[0]]
            ch = chip(nm, 30, pr)
            paste_center(c, ch, cx, 1030)
    cap = caption(list(words), 760, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    # dye dots, top right: the four hue jars
    x = 930
    for jar in ("rose", "tide", "citrus", "iris"):
        j = cut("P-jar-" + jar, 0.32, cool=0)
        bi.paste(c, drop(j, 6, 0.22), (x, 30))
        x += j.width + 4
    ch = chip(f"4 dyes · 3 finishes · {N_CHARMS} charms", 32)
    bi.paste(c, ch, (930, 190))
    return c


def t3(words=("merge", "big chains")):
    """The real deck, straight-on, frozen at Chain ×4; the Bear peeking over it, the Rose Bunny at
    its left end; stars and Bubbles balls bursting out; the five sizes on the right."""
    c = base(0.88)
    glow(c, 1000, 600, 1000, 0.34)
    rays(c, 1000, 600, n=20, alpha=0.11)
    bubbles(c, [(1500, 70, 80), (800, 330, 46), (60, 330, 50)])
    deck = cut("D-bigmerge", 1.0, cool=0)
    dx, dy = 318, 428
    edge = dy + 16  # the faceplate's top edge (the shoulder buttons stand a little above it)
    bx = dx + 766
    # behind everything: balls flying up out of the deck
    for x, y, t, k in ((770, 372, 1, 4), (1462, 262, 2, 4), (1580, 180, 0, 4), (1368, 150, 1, 4)):
        loose_ball(c, x, y, t, k)
    paws = peek_head(c, bx, edge, scale=0.86, tilt=-5, chin=490)
    bi.soft_shadow(c, deck, (dx, dy), dx=0, dy=-12, blur=14, alpha=0.30)  # the deck's shadow up onto his chin
    bi.soft_shadow(c, deck, (dx, dy), dx=14, dy=12, blur=20, alpha=0.34)
    bi.paste(c, deck, (dx, dy))
    peek_paws(c, deck, (dx, dy), paws, (bx - 268, bx + 258), edge)
    b = burst("×4", 92)
    paste_center(c, b, dx + 1232, dy + 44)  # on the deck's top corner: clear of the screen, the A button and his paw
    for x, y, r, rot in ((1330, 290, 22, -100), (690, 400, 24, -100), (1280, 60, 22, -80), (1640, 330, 20, -80)):
        gold_star(c, x, y, r, rot)
    for sx, sy, r in ((1450, 200, 22), (1620, 120, 16), (860, 300, 16), (1330, 380, 14), (250, 470, 18)):
        sparkle(c, sx, sy, r)
    bun = cut("C13", 1.06)
    put(c, bun, 204, bottom=1052)  # in front of the deck's left end, watching the chain
    cap = caption(list(words), 720, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    # size ladder, right: the Bubbles balls I..V, each merging into the next
    ramps = BALL_RAMPS["bubbles"]
    lad = Image.new("RGBA", (56, 176), (0, 0, 0, 0))
    ys = [8, 27, 52, 86, 136]
    rs = [5, 8, 11, 15, 21]
    xs = [24, 34, 26, 34, 30]
    for i, (x, y, r) in enumerate(zip(xs, ys, rs)):
        bi.pixel_ball(lad, x, y, r, i, ramps=ramps, ink=(42, 36, 80), face="dots")
    lad = lad.resize((lad.width * 5, lad.height * 5), Image.NEAREST)
    bi.paste(c, drop(lad, 8, 0.22), (1640, 262))
    ch = chip("5 sizes", 40)
    bi.paste(c, ch, (1668, 196))
    return c


def t4():
    """Hatch surprise eggs: the Bunny meets a cracked Toy Egg; six toys and four dye jars fly out."""
    c = base(0.86)
    ex, ey = 1080, 640
    glow(c, ex, ey - 80, 1000, 0.45)
    rays(c, ex, ey - 80, n=22, alpha=0.16)
    bubbles(c, [(1570, 120, 80)])
    bun = cut("C13", 1.12)
    put(c, bun, 330, bottom=1040)
    egg = cut("P-egg-open", 1.12, cool=0)
    put(c, egg, ex, bottom=1000)
    arc = [("P-toy-ball", 0.42, 690, 520), ("P-toy-bone", 0.38, 792, 338), ("P-toy-top", 0.40, 930, 150),
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


def park_plate(ox=150, blur=1.6):
    """The real Pet Park at dusk, cropped to cover the frame and pushed back a touch."""
    im = Image.open(os.path.join(CAP, "raw", "park-plate.jpg")).convert("RGB")
    k = H / im.height
    im = im.resize((round(im.width * k), H), Image.LANCZOS).crop((round(ox * k), 0, round(ox * k) + W, H))
    im = im.filter(ImageFilter.GaussianBlur(blur))
    im = ImageEnhance.Color(im).enhance(1.10)
    im = ImageEnhance.Brightness(im).enhance(1.04)
    a = np.asarray(im).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # a navy wash top-left so the caption reads, and a gentle corner vignette
    v = np.clip(1 - np.hypot((xx - 200) / 1050, (yy - 60) / 520), 0, 1)[..., None] ** 1.3 * 0.62
    a = a * (1 - v) + np.array(NAVY, np.float32) * v
    e = np.clip(np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2)) - 0.85, 0, 1)[..., None] * 0.5
    a = a * (1 - e) + np.array((40, 20, 70), np.float32) * e
    return Image.fromarray(a.clip(0, 255).astype(np.uint8)).convert("RGBA"), k


def heart(c, cx, cy, r, color=(255, 92, 150), rot=0):
    s = 4
    n = int(r * 3) * s
    big = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    m, R = n / 2, r * s

    def shape(R, fill):
        d.ellipse((m - R, m - R * 0.95, m, m + R * 0.05), fill=fill)
        d.ellipse((m, m - R * 0.95, m + R, m + R * 0.05), fill=fill)
        d.polygon([(m - R * 0.96, m - R * 0.25), (m + R * 0.96, m - R * 0.25), (m, m + R * 0.95)], fill=fill)
    shape(R, (255, 255, 255, 255))
    shape(R * 0.78, color + (255,))
    im = big.resize((n // s, n // s), Image.LANCZOS).rotate(rot, Image.BICUBIC)
    bi.paste(c, drop(im, 4, 0.25, 4), (int(cx - im.width / 2), int(cy - im.height / 2)))


def note(c, cx, cy, r, color=(255, 255, 255), rot=0):
    s = 4
    n = int(r * 4) * s
    big = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    m, R = n / 2, r * s
    for w, col in ((R * 0.30, NAVY + (255,)), (0, color + (255,))):
        d.ellipse((m - R - w, m + R * 0.3 - w, m + w, m + R * 1.1 + w), fill=col)
        d.rectangle((m - R * 0.22 - w, m - R * 1.2 - w, m + w, m + R * 0.7 + w), fill=col)
        d.polygon([(m - w, m - R * 1.2 - w), (m + R * 0.8 + w, m - R * 0.7 - w), (m + R * 0.8 + w, m - R * 0.2 + w),
                   (m - w, m - R * 0.7 + w)], fill=col)
    im = big.resize((n // s, n // s), Image.LANCZOS).rotate(rot, Image.BICUBIC)
    bi.paste(c, im, (int(cx - im.width / 2), int(cy - im.height / 2)))


def swish(c, cx, cy, r, a0, a1, width=9, alpha=215):
    """A curved motion stroke: part of a circle round (cx, cy)."""
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).arc((cx - r, cy - r, cx + r, cy + r), a0, a1, fill=(255, 255, 255, alpha), width=width)
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.0)))


def t5():
    """Play with friends: seven pals all over the real Pet Park at dusk."""
    ox = 150
    c, k = park_plate(ox)

    def P(px, py):  # plate pixel -> canvas
        return (px - ox) * k, py * k

    def pal(name, scale, px, py, rot=0.0, ry=10, flip=False, sh=90):
        im = cut(name, scale, rot, cool=0)
        if flip:
            im = ImageOps.mirror(im)
        x, y = P(px, py)
        bi.contact(c, x, y - 4, im.width * 0.40, ry, alpha=sh, blur=10)
        bi.paste(c, im, (int(x - im.width / 2), int(y - im.height)))
        return x, y - im.height

    # the plate's camera stood on a yellow marker block: lay the kerb beside it over it
    c.paste(ImageOps.mirror(c.crop((680, 960, 945, H))), (945, 960))
    glow(c, 1500, 330, 900, 0.16)
    # ---- on the equipment, far to near
    # by the slide and the ball mat
    pal("C7c", 0.36, 1122, 478, rot=-6, ry=8, sh=95)
    # swing
    x, y = pal("C7a", 0.40, 418, 520, rot=8, ry=1, sh=0)
    bi.contact(c, x + 10, P(0, 545)[1], 60, 10, alpha=80, blur=10)
    swish(c, x - 10, y - 40, 300, 100, 125, width=8)
    swish(c, x - 10, y - 40, 340, 104, 122, width=6)
    swish(c, x + 10, y - 40, 300, 52, 76, width=8)
    # see-saw: Bunny down, Bear up
    pal("F7b", 0.40, 752, 566, rot=6, ry=6, sh=70)
    x, y = pal("S14", 0.40, 1003, 494, rot=-8, ry=5, sh=50, flip=True)
    for dx, a in ((-70, -28), (0, 0), (70, 28)):
        layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
        t = np.radians(a)
        ImageDraw.Draw(layer).line((x + dx, y - 14, x + dx + 46 * np.sin(t), y - 14 - 46 * np.cos(t)),
                                   fill=(255, 255, 255, 225), width=9)
        c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1)))
    # ---- toys on the lawn
    for name, s, px, py, rot in (("P-toy-top", 0.26, 452, 662, 14), ("P-toy-bone", 0.28, 1075, 640, -12),
                                 ("P-toy-carrot", 0.24, 700, 715, 62), ("P-toy-deck", 0.50, 885, 733, -8)):
        im = cut(name, s, rot, cool=0)
        x, y = P(px, py)
        bi.contact(c, x, y - 6, im.width * 0.40, 10, alpha=90, blur=10)
        bi.paste(c, im, (int(x - im.width / 2), int(y - im.height)))
    # ---- foreground pals
    bun = cut("B2", 0.94, cool=0)
    bi.contact(c, 190, 1062, bun.width * 0.42, 20, alpha=110, blur=14)
    bi.paste(c, bun, (190 - bun.width // 2, 1075 - bun.height))
    bear = cut("B1", 1.02, cool=0)
    bi.contact(c, 1700, 1064, bear.width * 0.42, 20, alpha=110, blur=14)
    bi.paste(c, bear, (1700 - bear.width // 2, 1078 - bear.height))
    hop = cut("CJ", 0.92, rot=-8, cool=0)
    hx, top, ground = 690, 340, 1000
    bi.contact(c, hx, ground, hop.width * 0.24, 14, alpha=95, blur=16)
    puff(c, hx - 10, ground - 6)
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for off, L in ((-0.30, 70), (-0.10, 110), (0.10, 90), (0.30, 60)):
        x0 = hx + 10 + off * hop.width
        d.line((x0, top + hop.height + 6, x0 - 8, top + hop.height + 6 + L), fill=(255, 255, 255, 190), width=10)
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.6)))
    bi.paste(c, hop, (hx - hop.width // 2, top))
    # ---- the ball, thrown from the Bear to the Bunny
    dots(c, 1600, 560, 1110, 330, lift=110, n=8)
    ball = cut("P-toy-ball", 0.36, rot=20, cool=0)
    bi.soft_shadow(c, ball, (1040 - ball.width // 2, 300 - ball.height // 2), dx=10, dy=12, blur=12, alpha=0.25)
    paste_center(c, ball, 1040, 300)
    swish(c, 1040, 300, 96, -50, 20, width=8)
    swish(c, 1040, 300, 122, -38, 8, width=6)
    # ---- joy
    for hx_, hy_, r, rot in ((470, 520, 26, 14), (1470, 440, 26, -12), (1840, 380, 22, 16), (585, 470, 18, -10)):
        heart(c, hx_, hy_, r, rot=rot)
    for nx, ny, r, rot in ((1120, 500, 24, -12), (1330, 470, 18, 10), (520, 600, 18, 12), (1560, 520, 20, 8)):
        note(c, nx, ny, r, rot=rot)
    for sx, sy, r in ((930, 470, 24), (1180, 160, 20), (1420, 250, 16), (620, 380, 16), (1600, 150, 22),
                      (60, 520, 18), (1870, 620, 16), (1010, 900, 18)):
        sparkle(c, sx, sy, r)
    cap = caption(["play with", "friends"], 700, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    ch = chip("park · toys · friends", 34)
    bi.paste(c, ch, (40, 20 + cap.height - 10))
    return c


def puff(c, x, y):
    """A little dust cloud where she took off."""
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for dx, dy, r in ((-60, 0, 30), (-20, -14, 38), (30, -6, 34), (70, 4, 24), (5, 10, 30)):
        d.ellipse((x + dx - r, y + dy - r, x + dx + r, y + dy + r), fill=(255, 255, 255, 215))
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2)))


def speed_lines(c, cx, y, width):
    """Short white strokes under her feet, streaming down: she is going up."""
    layer = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, off in enumerate((-0.32, -0.12, 0.08, 0.28)):
        x = cx + off * width
        L = 120 + (i % 2) * 50
        d.line((x, y + 10, x - 18, y + 10 + L), fill=(255, 255, 255, 220), width=12)
    c.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2)))


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
    """Customize your deck: three real decks fanned evenly about the centre, their names and
    prices; the Bear peeking over the front one; the ball themes top right."""
    c = base(0.86)
    glow(c, 1000, 620, 1000, 0.32)
    rays(c, 1000, 620, alpha=0.09)
    bubbles(c, [(1260, 70, 70), (60, 470, 50)])
    back_l = cut("D-prism", 0.84, rot=11, cool=0)
    back_r = cut("D-lagoon", 0.84, rot=-11, cool=0)
    front = cut("D-cloud", 0.86, cool=0)
    mid = 1000
    for im, xy in ((back_l, (mid - 968, 312)), (back_r, (mid + 968 - back_r.width, 312))):
        bi.soft_shadow(c, im, xy, dx=12, dy=14, blur=18, alpha=0.30)
        bi.paste(c, im, xy)
    fxy = (int(mid - front.width / 2), 426)
    edge = fxy[1] + 14
    bx = mid - 20
    paws = peek_head(c, bx, edge, scale=0.76, tilt=4, chin=490)  # in front of the back decks, behind his own
    bi.soft_shadow(c, front, fxy, dx=0, dy=-12, blur=14, alpha=0.30)
    bi.soft_shadow(c, front, fxy, dx=14, dy=16, blur=22, alpha=0.38)
    bi.paste(c, front, fxy)
    peek_paws(c, front, fxy, paws, (bx - 240, bx + 236), edge)
    for pid, cx, y in (("prism_flare", 250, 968), ("lagoon", 1700, 468), ("cloud_glass", mid, 940)):
        nm, pr = DECKS[pid]
        ch = chip(nm, 36, pr)
        bi.paste(c, ch, (cx - ch.width // 2, y))
    cap = caption(["customize", "your deck"], 700, [0.0, 0.0])
    bi.paste(c, cap, (40, 20))
    y = 20 + cap.height + 10
    ch = chip(f"{N_DECKS} decks", 36)
    bi.paste(c, ch, (40, y))
    # ball themes, top right: one ball of each of five, over the count
    x0, y = 1330, 60
    for i, tid in enumerate(("smileys", "gems", "kittens", "bubbles", "midnight")):
        rp = BALL_RAMPS[tid]
        lad = Image.new("RGBA", (26, 26), (0, 0, 0, 0))
        ink = (255, 255, 255) if tid == "midnight" else (21, 16, 43)
        bi.pixel_ball(lad, 13, 13, 11.5, i, ramps=rp, ink=ink, face="dots" if tid in ("gems", "bubbles", "midnight") else "smiley")
        lad = lad.resize((104, 104), Image.NEAREST)
        bi.paste(c, drop(lad, 6, 0.25), (x0 + i * 108, y + (18 if i % 2 else 0)))
    ch = chip(f"{len(BALL_IDS)} ball themes", 36)
    bi.paste(c, ch, (x0 + 290 - ch.width // 2, y + 150))
    for sx, sy, r in ((1290, 250, 18), (1890, 330, 16), (640, 400, 16), (120, 640, 14)):
        sparkle(c, sx, sy, r)
    return c


def t7():
    """Level up your pal: the Bunny, a stats card from StatCatalog, a Feast snack."""
    c = base(0.86)
    glow(c, 420, 600, 800, 0.30)
    bubbles(c, [(1500, 130, 100), (1400, 70, 40)])  # out from behind the wordmark
    put(c, cut("C13", 1.10), 345, bottom=1040)  # ears and heart charm clear of the caption
    # card
    cx0, cy0, cw, chh = 780, 250, 1090, 740
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
    fe = cut("P-feast", 0.58, cool=0)
    put(c, fe, 652, bottom=1046)  # beside the card, not over its stat icons
    ch = chip(f"{FEAST_NAME} ×{FEAST_MULT} XP", 36)
    bi.paste(c, ch, (652 - ch.width // 2, 1080 - ch.height - 2))
    cap = caption(["level up", "your pal"], 640, [0.0, 0.0])
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
    ("T5-play", lambda: with_mark(t5, pos="tr")),
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
