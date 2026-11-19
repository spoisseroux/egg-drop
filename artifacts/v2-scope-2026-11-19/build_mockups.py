"""V2 scope mockups (2026-11-19). Hand-drawn with PIL over crops of existing Studio captures.
No generated art. Proposal screens only: nothing here is built.

Run from the repo root:  python artifacts/v2-scope-2026-11-19/build_mockups.py
Writes four 1688x780 PNGs (844x390 phone landscape at 2x) next to this file.

Colours and type follow UI-DESIGN-SYSTEM.md / DeckKit as seen in the live captures
(artifacts/store-listing/raw/wardrobe-*.jpg): teal glass panel, raised cards, dark wells,
mint accent, gold Stars, Roboto Mono for numbers. Nunito stands in for the game's rounded face.
"""
import math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "artifacts", "store-listing", "raw")
W, H, R, OUT = 844, 390, 4, 2          # logical size, render scale, output scale
FONTS = "C:/Windows/Fonts/"

PANEL, PANEL2 = "#1D2D2D", "#1F3031"
RAISED, WELL, SELECTED = "#2A3A3C", "#0D1919", "#2D4E47"
TEXT, SOFT, DIM, INK = "#F3F4F6", "#C3C8D0", "#959BA5", "#0E0F12"
ACCENT, ACCENT_EDGE = "#77F6B1", "#4A996A"
STARS, DANGER, PINK = "#FFC14D", "#FF5A6E", "#F99DC2"
STAT = {  # proposed stat colours (never tinted by the faceplate, like Stars)
    "heart": ("Heart", "#FF86A8"), "pop": ("Power", "#FF9D4D"), "poise": ("Energy", "#6CCBFF"),
    "tumble": ("Jump", "#B9EE5A"), "fetch": ("Speed", "#8FA8FF"), "wonder": ("Smarts", "#E58CFF"),
}
ORDER = ["heart", "pop", "poise", "tumble", "fetch", "wonder"]


def rgb(c):
    c = c.lstrip("#"); return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
def mix(a, b, t):
    a, b = rgb(a) if isinstance(a, str) else a, rgb(b) if isinstance(b, str) else b
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
def S(v): return int(round(v * R))
def font(name, size): return ImageFont.truetype(FONTS + name, S(size))
def black(s): return font("Nunito-Black.ttf", s)
def xbold(s): return font("Nunito-ExtraBold.ttf", s)
def bold(s): return font("Nunito-Bold.ttf", s)
def mono(s): return font("RobotoMono-Bold.ttf", s)


class Canvas:
    def __init__(self, backdrop=None, shade=.5, blur=0):
        if backdrop is None:
            self.im = Image.new("RGB", (S(W), S(H)), rgb("#0B0A18"))
        else:
            self.im = backdrop.resize((S(W), S(H)), Image.LANCZOS)
            if blur: self.im = self.im.filter(ImageFilter.GaussianBlur(S(blur)))
            self.im = Image.blend(self.im, Image.new("RGB", self.im.size, (8, 12, 14)), shade)
        self.d = ImageDraw.Draw(self.im)

    def rr(self, box, r, fill=None, outline=None, width=1):
        x0, y0, x1, y1 = box
        self.d.rounded_rectangle((S(x0), S(y0), S(x1), S(y1)), S(r), fill=fill, outline=outline, width=S(width))
    def card(self, box, r=12, fill=RAISED, stroke=True):
        self.rr(box, r, fill=fill, outline=mix(fill, "#FFFFFF", .14) if stroke else None)
    def text(self, xy, s, f, fill=TEXT, anchor="la"):
        self.d.text((S(xy[0]), S(xy[1])), s, font=f, fill=fill, anchor=anchor)
    def width(self, s, f): return self.d.textlength(s, font=f) / R
    def line(self, pts, fill, width=1):
        self.d.line([(S(x), S(y)) for x, y in pts], fill=fill, width=S(width), joint="curve")
    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse(tuple(S(v) for v in box), fill=fill, outline=outline, width=S(width))
    def poly(self, pts, fill): self.d.polygon([(S(x), S(y)) for x, y in pts], fill=fill)

    def paste(self, img, box, r=10):
        x0, y0, x1, y1 = box
        size = (S(x1 - x0), S(y1 - y0))
        img = cover(img, size)
        mask = Image.new("L", size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), S(r), fill=255)
        self.im.paste(img, (S(x0), S(y0)), mask)

    def contain(self, img, box, r=10, fill=WELL):
        x0, y0, x1, y1 = box
        size = (S(x1 - x0), S(y1 - y0))
        k = min(size[0] / img.width, size[1] / img.height)
        img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
        tile = Image.new("RGB", size, img.getpixel((img.width // 2, 8)))
        tile.paste(img, ((size[0] - img.width) // 2, size[1] - img.height))
        mask = Image.new("L", size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), S(r), fill=255)
        self.im.paste(tile, (S(x0), S(y0)), mask)

    def glow(self, cx, cy, radius, color, alpha=.35):
        layer = Image.new("RGB", self.im.size, (0, 0, 0))
        ImageDraw.Draw(layer).ellipse((S(cx - radius), S(cy - radius), S(cx + radius), S(cy + radius)), fill=mix("#000000", color, alpha))
        layer = layer.filter(ImageFilter.GaussianBlur(S(radius * .45)))
        from PIL import ImageChops
        self.im = ImageChops.screen(self.im, layer); self.d = ImageDraw.Draw(self.im)

    def save(self, name):
        out = self.im.resize((W * OUT, H * OUT), Image.LANCZOS)
        out.save(os.path.join(HERE, name), optimize=True)
        print("wrote", name, out.size)


def cover(img, size):
    sw, sh = img.size; tw, th = size
    k = max(tw / sw, th / sh)
    img = img.resize((max(tw, round(sw * k)), max(th, round(sh * k))), Image.LANCZOS)
    x, y = (img.width - tw) // 2, (img.height - th) // 2
    return img.crop((x, y, x + tw, y + th))


# ---------- small drawn parts ----------
def star(c, cx, cy, r, fill=STARS):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5; rad = r if i % 2 == 0 else r * .46
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    c.poly(pts, fill)

def burst(c, cx, cy, r, fill, points=8, inner=.55):
    pts = []
    for i in range(points * 2):
        a = -math.pi / 2 + i * math.pi / points; rad = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    c.poly(pts, fill)

def sparkle(c, cx, cy, r, fill):
    burst(c, cx, cy, r, fill, points=4, inner=.28)

def glyph(c, kind, cx, cy, s, fill=INK):
    """Six original stat marks, readable without colour. s = half size."""
    if kind == "heart":
        c.ellipse((cx - s, cy - s * .85, cx, cy + s * .15), fill=fill)
        c.ellipse((cx, cy - s * .85, cx + s, cy + s * .15), fill=fill)
        c.poly([(cx - s * .96, cy - s * .12), (cx + s * .96, cy - s * .12), (cx, cy + s)], fill)
    elif kind == "pop":
        burst(c, cx, cy, s * 1.08, fill)
    elif kind == "poise":   # three balanced pebbles
        c.ellipse((cx - s, cy + s * .25, cx + s, cy + s), fill=fill)
        c.ellipse((cx - s * .68, cy - s * .38, cx + s * .68, cy + s * .2), fill=fill)
        c.ellipse((cx - s * .4, cy - s, cx + s * .4, cy - s * .44), fill=fill)
    elif kind == "tumble":  # a roll: open ring with an arrow head
        w = max(1.2, s * .36)
        c.d.arc((S(cx - s * .85), S(cy - s * .85), S(cx + s * .85), S(cy + s * .85)), 40, 320, fill=fill, width=S(w))
        a = math.radians(320); px, py = cx + math.cos(a) * s * .85, cy + math.sin(a) * s * .85
        c.poly([(px - s * .15, py - s * .62), (px + s * .62, py + s * .05), (px - s * .42, py + s * .3)], fill)
    elif kind == "fetch":   # a ball in flight
        c.ellipse((cx - s * .1, cy - s * .7, cx + s, cy + s * .4), fill=fill)
        for i, dy in enumerate((-.35, .12, .6)):
            c.line([(cx - s * (1 - i * .12), cy + s * dy), (cx - s * (.35 - i * .1), cy + s * dy)], fill, max(1, s * .22))
    elif kind == "wonder":
        sparkle(c, cx - s * .12, cy + s * .1, s * .95, fill)
        sparkle(c, cx + s * .68, cy - s * .62, s * .42, fill)

def stat_chip(c, kind, x, y, size, r=None):
    c.rr((x, y, x + size, y + size), r or size * .3, fill=STAT[kind][1])
    glyph(c, kind, x + size / 2, y + size / 2, size * .28)

def lock(c, cx, cy, s, fill=SOFT):
    c.d.arc((S(cx - s * .55), S(cy - s * 1.05), S(cx + s * .55), S(cy + s * .15)), 180, 360, fill=fill, width=S(max(1.2, s * .28)))
    c.rr((cx - s * .8, cy - s * .35, cx + s * .8, cy + s * .8), s * .22, fill=fill)

def bar(c, box, frac, color, track=WELL):
    x0, y0, x1, y1 = box; r = (y1 - y0) / 2
    c.rr(box, r, fill=track, outline=mix(track, "#FFFFFF", .14))
    if frac > 0: c.rr((x0, y0, x0 + max(y1 - y0, (x1 - x0) * frac), y1), r, fill=color)

def pill(c, x, y, s, f, fill, ink, padx=8, h=18, anchor="l", outline=None):
    w = c.width(s, f) + padx * 2
    if anchor == "r": x -= w
    c.rr((x, y, x + w, y + h), h / 2, fill=fill, outline=outline)
    c.text((x + w / 2, y + h / 2), s, f, ink, "mm")
    return w

def squiggle(c, x, y, w, color=PINK):
    pts = [(x + i * 2, y + math.sin(i * 1.15) * 1.6) for i in range(int(w / 2) + 1)]
    c.line(pts, color, 1.4)

def wallet(c, right, y, amount):
    f = mono(13); w = c.width(amount, f) + 44
    c.rr((right - w, y, right, y + 30), 15, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    star(c, right - w + 18, y + 15, 8)
    c.text((right - 13, y + 15), amount, f, TEXT, "rm")
    return w

def back_arrow(c, right, y):
    c.ellipse((right - 30, y, right, y + 30), fill=WELL, outline=mix(WELL, "#FFFFFF", .25))
    cx, cy = right - 15, y + 15
    c.line([(cx + 5, cy), (cx - 5, cy)], SOFT, 1.5); c.line([(cx - 1.5, cy - 4), (cx - 5.5, cy), (cx - 1.5, cy + 4)], SOFT, 1.5)

def close_x(c, right, y, size=30):
    c.ellipse((right - size, y, right, y + size), fill=WELL, outline=mix(WELL, "#FFFFFF", .25))
    cx, cy, k = right - size / 2, y + size / 2, size * .15
    c.line([(cx - k, cy - k), (cx + k, cy + k)], TEXT, 1.8); c.line([(cx - k, cy + k), (cx + k, cy - k)], TEXT, 1.8)

def header(c, box, eyebrow, title, amount="318"):
    x0, y0, x1, y1 = box
    c.ellipse((x0 + 16, y0 + 12, x0 + 21, y0 + 17), fill=PINK)
    c.text((x0 + 26, y0 + 14.5), eyebrow, xbold(8), PINK, "lm")
    c.text((x0 + 16, y0 + 22), title, black(18), TEXT)
    squiggle(c, x0 + 16, y0 + 47, 44)
    back_arrow(c, x1 - 14, y0 + 13)
    wallet(c, x1 - 50, y0 + 13, amount)

def panel(c, box):
    c.rr((box[0], box[1] + 3, box[2], box[3] + 3), 20, fill=(10, 16, 16))
    c.rr(box, 20, fill=PANEL, outline=mix(PANEL, "#FFFFFF", .16))

def hint(c, x, y, key, label, filled=False):
    c.ellipse((x, y, x + 16, y + 16), fill=ACCENT if filled else mix(PANEL, "#FFFFFF", .16), outline=mix(PANEL, "#FFFFFF", .3))
    c.text((x + 8, y + 8), key, xbold(7.5), INK if filled else SOFT, "mm")
    c.text((x + 21, y + 8), label, bold(9), SOFT, "lm")
    return 21 + c.width(label, bold(9)) + 14

def primary(c, box, label, key="A", star_price=None, enabled=True):
    x0, y0, x1, y1 = box
    if enabled:
        c.rr((x0, y0 + 3, x1, y1 + 3), 12, fill=ACCENT_EDGE); c.rr(box, 12, fill=ACCENT)
        c.rr((x0 + 3, y0 + 2, x1 - 3, y0 + (y1 - y0) * .45), 9, fill=mix(ACCENT, "#FFFFFF", .18))
        ink = INK
    else:
        c.rr(box, 12, fill=mix(RAISED, PANEL, .4), outline=mix(RAISED, "#FFFFFF", .14)); ink = DIM
    f = black(13); tw = c.width(label, f); cx = (x0 + x1) / 2; cy = (y0 + y1) / 2
    lead = (20 if key else 0)
    start = cx - (tw + lead) / 2
    if key:
        c.ellipse((start, cy - 8, start + 16, cy + 8), fill=mix(ACCENT, "#000000", .16) if enabled else mix(RAISED, "#FFFFFF", .1))
        c.text((start + 8, cy), key, xbold(8), ink, "mm")
    c.text((start + lead, cy), label, f, ink, "lm")

def secondary(c, box, label, ink=TEXT):
    c.rr((box[0], box[1] + 2, box[2], box[3] + 2), 12, fill=mix(RAISED, "#000000", .35))
    c.rr(box, 12, fill=RAISED, outline=mix(RAISED, "#FFFFFF", .14))
    c.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, black(12), ink, "mm")


# ---------- source crops (existing Studio captures) ----------
def raw(name): return Image.open(os.path.join(RAW, name)).convert("RGB")
def bear_plain():      # the hatch reveal's spotlit Bear
    return raw("hatch-reveal-a.jpg").crop((455, 232, 1145, 700))
def bear_beanie(): return raw("wardrobe-pom-beanie.jpg").crop((542, 277, 864, 519))
def bear_crown(): return raw("wardrobe-flower-crown.jpg").crop((542, 277, 864, 519))
def thumb(name, box): return raw(name).crop(box)
def hue_shift(img, degrees, sat_floor=70):
    hsv = img.convert("HSV"); h, s, v = hsv.split()
    h2 = h.point(lambda p: (p + int(degrees / 360 * 255)) % 255)
    from PIL import ImageChops
    mask = ImageChops.multiply(s.point(lambda p: 255 if p > sat_floor else 0), v.point(lambda p: 255 if p > 95 else 0))
    out = Image.merge("HSV", (Image.composite(h2, h, mask), s, v)).convert("RGB")
    return out
def garden(): return raw("garden-bear-front.jpg")
def xp(level):
    n = level - 1
    return (n**3 + 80 * n**2 + 480 * n) // 40
def left_of(level, frac): return round((xp(level + 1) - xp(level)) * (1 - frac))
def tier_name(level):
    return "STARBLOOM" if level >= 99 else "FULL BLOOM" if level >= 75 else "BLOOM" if level >= 50 else "SPROUT" if level >= 25 else "SEEDLING"


# ============================================================
# 1. Stats panel (the player's own Bear)
# ============================================================
def stats_panel():
    c = Canvas(raw("garden-vista.jpg"), shade=.55, blur=1.5)
    box = (12, 8, 832, 382); panel(c, box)
    header(c, box, "COMPANIONS", "Bear's stats")
    levels = {k: (l, f, left_of(l, f)) for k, (l, f) in {"heart": (34, .46), "pop": (41, .72), "poise": (38, .2), "tumble": (22, .55), "fetch": (17, .31), "wonder": (35, .88)}.items()}
    fresh = {"heart": True, "pop": False, "poise": False, "tumble": True, "fetch": True, "wonder": False}
    total = sum(v[0] for v in levels.values())

    # left column: the Bear and the total
    lx0, lx1 = 28, 226
    c.rr((lx0, 62, lx1, 196), 12, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    c.paste(bear_plain(), (lx0 + 1, 63, lx1 - 1, 195), r=11)
    pill(c, lx0 + 8, 172, "BLOOM KEEPER", xbold(7.5), mix(WELL, ACCENT, .25), ACCENT, h=16, outline=mix(WELL, ACCENT, .6))
    c.card((lx0, 202, lx1, 344), 12, fill=mix(PANEL, RAISED, .6))
    c.text((lx0 + 12, 212), "TOTAL LEVEL", xbold(8), DIM)
    c.text((lx0 + 12, 222), str(total), mono(30), TEXT)
    c.text((lx0 + 14 + c.width(str(total), mono(30)), 245), "/ 594", mono(11), DIM, "ls")
    bar(c, (lx0 + 12, 262, lx1 - 12, 270), (total - 150) / 150, ACCENT)
    c.text((lx0 + 12, 276), "Full Bloom Keeper at 300", bold(8.5), SOFT)
    # six milestone pips
    c.text((lx0 + 12, 298), "MILESTONES", xbold(8), DIM)
    for i, k in enumerate(ORDER):
        x = lx0 + 12 + i * 29; lvl = levels[k][0]
        on = lvl >= 25
        c.ellipse((x, 312, x + 22, 334), fill=STAT[k][1] if on else WELL, outline=mix(WELL, "#FFFFFF", .2))
        glyph(c, k, x + 11, 323, 5.4, INK if on else mix(WELL, "#FFFFFF", .3))

    # right: six stat tiles, 2 x 3
    gx0, gx1, gy0 = 236, 818, 62
    tw, th, gap = (gx1 - gx0 - 8) / 2, 62, 6
    sel = "pop"
    for i, k in enumerate(ORDER):
        col, row = i % 2, i // 2
        x0 = gx0 + col * (tw + 8); y0 = gy0 + row * (th + gap); x1, y1 = x0 + tw, y0 + th
        name, color = STAT[k]; lvl, frac, left = levels[k]
        if k == sel:
            c.rr((x0 - 2.5, y0 - 2.5, x1 + 2.5, y1 + 2.5), 14, outline="#FFFFFF", width=1.6)
            c.rr((x0, y0, x1, y1), 12, fill=SELECTED, outline=ACCENT, width=1.4)
        else:
            c.card((x0, y0, x1, y1), 12)
        stat_chip(c, k, x0 + 10, y0 + 10, 30)
        c.text((x0 + 48, y0 + 9), name, black(13), TEXT)
        c.text((x0 + 48, y0 + 27), tier_name(lvl), xbold(7.5), color)
        c.text((x1 - 12, y0 + 6), str(lvl), mono(24), TEXT, "ra")
        bar(c, (x0 + 10, y0 + 46, x1 - 96, y0 + 53), frac, color, track=mix(WELL, PANEL, .2))
        c.text((x1 - 12, y0 + 50), f"{left} XP to {lvl + 1}", mono(8), SOFT, "rm")
        # Bonus XP marker: a dew drop, filled while today's double is still waiting
        dx = x0 + 48 + c.width(tier_name(lvl), xbold(7.5)) + 8
        if fresh[k]:
            pill(c, dx, y0 + 25.5, "2x BONUS", xbold(7), mix(RAISED, ACCENT, .2), ACCENT, padx=6, h=13)

    # selected stat: what it is, how to train, what is next
    dy0 = gy0 + 3 * th + 2 * gap + 8
    c.card((gx0, dy0, gx1, 344), 12, fill=mix(PANEL, RAISED, .6))
    stat_chip(c, sel, gx0 + 12, dy0 + 11, 22)
    c.text((gx0 + 42, dy0 + 9), "Power  ·  merges and chains on the Pocket Deck", black(11), TEXT)
    c.text((gx0 + 42, dy0 + 26), "Every merge is 1 XP. Chains and a top-tier clear add more.", bold(9), SOFT)
    # next unlock chip
    ux = gx0 + 12; uy = dy0 + 46
    c.rr((ux, uy, ux + 268, uy + 20), 10, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    c.text((ux + 10, uy + 10), "NEXT AT 45", xbold(7.5), STAT[sel][1], "lm")
    c.text((ux + 66, uy + 10), "Comet drop trail  ·  Deck style", bold(9), TEXT, "lm")
    primary(c, (gx1 - 150, dy0 + 34, gx1 - 12, dy0 + 34 + 30), "Play a round")
    c.text((gx1 - 162, dy0 + 49), "9 more today at 2x", bold(8.5), DIM, "rm") if False else None

    # footer
    x = 30
    x += hint(c, x, 354, "+", "Browse")
    x += hint(c, x, 354, "A", "Train", True)
    x += hint(c, x, 354, "B", "Back")
    c.text((818, 362), "Levels never go down. Miss a day, lose nothing.", bold(9), DIM, "rm")
    c.save("01-stats-panel-844x390@2x.png")


# ============================================================
# 2. Inspect another player's Bear
# ============================================================
def inspect_card():
    g = garden().crop((400, 111, 1920, 813))
    c = Canvas(g, shade=.12)
    # quiet ground ring under the inspected pet (existing highlight idea)
    c.d.ellipse((S(186), S(352), S(270), S(378)), outline=rgb("#FFFFFF"), width=S(1.4))
    x0, y0, x1, y1 = 372, 30, 832, 360
    c.rr((x0, y0 + 3, x1, y1 + 3), 18, fill=(10, 16, 16)); c.rr((x0, y0, x1, y1), 18, fill=PANEL, outline=mix(PANEL, "#FFFFFF", .16))
    pad = 12
    # header
    c.text((x0 + pad + 2, y0 + 9), "Bear", black(18), TEXT)
    nw = c.width("Bear", black(18))
    c.text((x0 + pad + 8 + nw, y0 + 24), "with @mossy_otter", bold(10), SOFT, "ls")
    close_x(c, x1 - pad, y0 + 8, 28)
    # left: live preview
    px0, py0, pw = x0 + pad, y0 + 44, 150
    c.rr((px0, py0, px0 + pw, py0 + 150), 12, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    c.paste(bear_crown(), (px0 + 1, py0 + 1, px0 + pw - 1, py0 + 149), r=11)
    pill(c, px0 + pw / 2 - 30, py0 + 130, "Drag to spin", bold(7.5), mix(WELL, "#000000", .2), SOFT, padx=7, h=14, outline=mix(WELL, "#FFFFFF", .2))
    # right: tabs + stat tiles
    rx0, rx1 = px0 + pw + 10, x1 - pad
    c.rr((rx0, py0, rx1, py0 + 26), 13, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    half = (rx1 - rx0) / 2
    c.rr((rx0 + 2, py0 + 2, rx0 + half, py0 + 24), 11, fill=ACCENT)
    c.text((rx0 + half / 2, py0 + 13), "Stats", black(10.5), INK, "mm")
    c.text((rx0 + half * 1.5, py0 + 13), "Outfit", black(10.5), SOFT, "mm")
    theirs = {"heart": 52, "pop": 29, "poise": 31, "tumble": 44, "fetch": 18, "wonder": 27}
    tw = (rx1 - rx0 - 12) / 3; th = 56; ty = py0 + 32
    for i, k in enumerate(ORDER):
        tx = rx0 + (i % 3) * (tw + 6); yy = ty + (i // 3) * (th + 6)
        c.card((tx, yy, tx + tw, yy + th), 10)
        stat_chip(c, k, tx + 7, yy + 7, 18)
        c.text((tx + 30, yy + 16), STAT[k][0].upper(), xbold(7.5), SOFT, "lm")
        c.text((tx + 8, yy + 27), str(theirs[k]), mono(20), TEXT)
        t = tier_name(theirs[k])
        if theirs[k] >= 25:
            c.text((tx + tw - 7, yy + 43), t, xbold(6.5), STAT[k][1], "rm")
    # summary strip
    sy = py0 + 158
    c.rr((x0 + pad, sy, x1 - pad, sy + 50), 12, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    total = sum(theirs.values())
    c.text((x0 + pad + 12, sy + 9), "TOTAL LEVEL", xbold(7.5), DIM)
    c.text((x0 + pad + 12, sy + 18), str(total), mono(22), TEXT)
    c.text((x0 + pad + 16 + c.width(str(total), mono(22)), sy + 41), "/ 594", mono(9), DIM, "ls")
    pill(c, x0 + pad + 118, sy + 16, "BLOOM KEEPER", xbold(7.5), mix(WELL, ACCENT, .25), ACCENT, h=18, outline=mix(WELL, ACCENT, .6))
    # earned marks: a Bloom medal and the park badge
    bx = x1 - pad - 12
    c.text((bx, sy + 9), "MARKS", xbold(7.5), DIM, "ra")
    for i, k in enumerate(["wonder", "poise", "pop", "tumble", "heart"]):
        cx = bx - 10 - i * 24; big = theirs[k] >= 50
        c.ellipse((cx - 10, sy + 21, cx + 10, sy + 41), fill=STAT[k][1], outline="#FFFFFF" if big else None, width=1.4)
        glyph(c, k, cx, sy + 31, 5, INK)
    # actions
    ay = sy + 58
    primary(c, (x0 + pad, ay, x1 - pad - 128, ay + 40), "Say hello")
    secondary(c, (x1 - pad - 120, ay, x1 - pad, ay + 40), "Compare")
    c.text(((x0 + x1) / 2, y1 - 13), "Levels only. XP, Stars and history stay private.", bold(8.5), DIM, "mm")
    c.save("02-inspect-card-844x390@2x.png")


# ============================================================
# 3. Stat Egg: the treat is eaten and the stat levels up
# ============================================================
def stat_egg_level_up():
    c = Canvas()
    col = STAT["pop"][1]
    # stage: diagonal bands and a soft beam, as on the item reveal
    band = Image.new("RGB", c.im.size, (0, 0, 0)); bd = ImageDraw.Draw(band)
    for off, wdt, a in ((-120, 150, .10), (150, 60, .07), (430, 210, .09), (760, 40, .06)):
        bd.polygon([(S(off), S(H)), (S(off + wdt), S(H)), (S(off + wdt + 300), 0), (S(off + 300), 0)], fill=mix("#000000", "#6C5BD9", a * 2.2))
    from PIL import ImageChops
    c.im = ImageChops.screen(c.im, band); c.d = ImageDraw.Draw(c.im)
    c.glow(205, 190, 190, col, .30)
    # tilted item card
    card = Image.new("RGBA", (S(250), S(250)), (0, 0, 0, 0)); cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((S(6), S(6), S(244), S(244)), S(22), fill=mix(col, "#FFFFFF", .12), outline=mix(col, "#FFFFFF", .55), width=S(3))
    for y in range(S(12), S(238)):
        t = (y - S(12)) / S(226)
        cd.line([(S(12), y), (S(238), y)], fill=mix(mix(col, "#FFFFFF", .28), mix(col, "#7A2E10", .45), t))
    cd.rounded_rectangle((S(6), S(6), S(244), S(244)), S(22), outline=mix(col, "#FFFFFF", .6), width=S(3))
    sub = Canvas.__new__(Canvas); sub.im = card; sub.d = cd
    # the treat: a round biscuit stamped with the Power mark (drawn, placeholder for the model)
    cx, cy = 125, 128
    sub.ellipse((cx - 62, cy + 52, cx + 62, cy + 70), fill=mix(col, "#3A1406", .55))
    sub.ellipse((cx - 66, cy - 60, cx + 66, cy + 66), fill=rgb("#C98A45"))
    sub.ellipse((cx - 66, cy - 66, cx + 66, cy + 58), fill=rgb("#F3C988"))
    sub.ellipse((cx - 54, cy - 56, cx + 54, cy + 46), fill=rgb("#FBE0AF"))
    burst(sub, cx, cy - 6, 34, rgb(col)); burst(sub, cx, cy - 6, 17, rgb("#FFF3D6"))
    for a in range(0, 360, 45):
        r = 46; x = cx + math.cos(math.radians(a + 20)) * r; y = cy - 6 + math.sin(math.radians(a + 20)) * r * .95
        sub.ellipse((x - 3, y - 3, x + 3, y + 3), fill=rgb("#E7A75C"))
    sub.ellipse((cx - 40, cy - 52, cx - 8, cy - 40), fill=rgb("#FFF6E0"))
    card = card.rotate(5, resample=Image.BICUBIC, expand=True)
    c.im.paste(card, (S(80), S(54)), card); c.d = ImageDraw.Draw(c.im)
    for x, y, r in ((84, 76, 7), (342, 122, 4), (92, 320, 8), (330, 302, 5), (40, 190, 5)):
        sparkle(c, x, y, r, "#FFFFFF")
    close_x(c, 824, 22, 32)

    tx = 392
    # chip
    c.d.polygon([(S(tx), S(72)), (S(tx + 132), S(68)), (S(tx + 134), S(88)), (S(tx + 2), S(92))], fill=rgb(col))
    c.text((tx + 67, 80), "STAT TREAT  ·  SNACK", xbold(8.5), INK, "mm")
    c.text((tx, 98), "POWER SNACK", black(32), TEXT)
    c.line([(tx, 142), (tx + 196, 138)], col, 2.5)
    c.text((tx, 152), "Bear ate it in two bites.", bold(12), TEXT)
    c.text((tx, 170), "+100 Power XP", mono(11), col)

    # the stat row: bar runs to the end, level ticks over
    ry = 196
    c.rr((tx, ry, 812, ry + 86), 14, fill=mix("#0B0A18", "#FFFFFF", .07), outline=mix("#0B0A18", "#FFFFFF", .2))
    stat_chip(c, "pop", tx + 12, ry + 12, 30)
    c.text((tx + 52, ry + 10), "Power", black(14), TEXT)
    c.text((tx + 52, ry + 29), "SEEDLING", xbold(7.5), col)
    pill(c, 800, ry + 11, "LEVEL UP", black(9), ACCENT, INK, padx=9, h=19, anchor="r")
    c.text((tx + 190, ry + 20), "14", mono(17), DIM, "mm")
    c.line([(tx + 208, ry + 20), (tx + 226, ry + 20)], SOFT, 1.6); c.line([(tx + 221, ry + 16), (tx + 226, ry + 20), (tx + 221, ry + 24)], SOFT, 1.6)
    c.text((tx + 250, ry + 19), "15", mono(24), TEXT, "mm")
    bar(c, (tx + 12, ry + 52, 800, ry + 61), 22 / (xp(16) - xp(15)), col, track=mix("#0B0A18", "#000000", .3))
    c.text((tx + 12, ry + 73), f"22 / {xp(16) - xp(15)} XP to 16", mono(8.5), SOFT, "lm")
    c.text((800, ry + 73), "Unlocked: Fizz merge pop", bold(9.5), TEXT, "rm")
    lock_x = 800 - c.width("Unlocked: Fizz merge pop", bold(9.5)) - 12
    sparkle(c, lock_x, ry + 73, 5, col)

    # actions
    secondary(c, (tx, 306, tx + 196, 350), "")
    c.text((tx + 28, 328), "Hatch another", black(12), TEXT, "lm")
    star(c, tx + 142, 327.5, 6); c.text((tx + 152, 328), "15", mono(12), STARS, "lm")
    primary(c, (tx + 208, 306, 812, 350), "Nice!")
    # bottom-left: the promise, as on the live reveal
    c.rr((26, 348, 268, 368), 10, fill=mix("#0B0A18", "#FFFFFF", .06), outline=mix("#0B0A18", "#FFFFFF", .18))
    c.text((36, 358), "NEXT", xbold(7.5), DIM, "lm")
    c.text((64, 358), "A Feast within 5 eggs  ·  2 left in today's nest", bold(8.5), SOFT, "lm")
    c.save("03-stat-egg-level-up-844x390@2x.png")


# ============================================================
# 4. A locked item in the Wardrobe
# ============================================================
def locked_item():
    c = Canvas(raw("wardrobe-pom-beanie.jpg").crop((0, 0, 1760, 813)), shade=.5, blur=1.5)
    box = (12, 8, 832, 382); panel(c, box)
    header(c, box, "COMPANIONS", "Wardrobe")
    # slot tabs
    c.rr((28, 62, 818, 90), 14, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    tabs = ["Hat", "Shirt", "Neck", "Ears", "Eyes", "Mouth", "Tail"]; tw = 790 / 7
    c.rr((30, 64, 30 + tw - 2, 88), 12, fill=ACCENT)
    for i, t in enumerate(tabs):
        c.text((28 + tw * (i + .5), 76), t, black(10.5), INK if i == 0 else SOFT, "mm")

    # detail card (left)
    dx0, dx1, dy0, dy1 = 28, 300, 98, 344
    c.card((dx0, dy0, dx1, dy1), 14, fill=mix(PANEL, RAISED, .6))
    c.rr((dx0 + 10, dy0 + 10, dx1 - 10, dy0 + 116), 10, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
    c.contain(hue_shift(bear_beanie(), 205), (dx0 + 11, dy0 + 11, dx1 - 11, dy0 + 115), r=9)
    pill(c, dx0 + 18, dy0 + 18, "TRY-ON", xbold(7.5), mix(WELL, "#000000", .1), SOFT, h=16, outline=mix(WELL, "#FFFFFF", .25))
    c.text((dx0 + 12, dy0 + 122), "Varsity Beanie", black(14), TEXT)
    c.text((dx1 - 12, dy0 + 132), "80", mono(11), mix(STARS, PANEL, .35), "rm")
    star(c, dx1 - 34, dy0 + 131.5, 5.5, mix(STARS, PANEL, .35))
    # requirement row
    ry = dy0 + 146
    c.rr((dx0 + 10, ry, dx1 - 10, ry + 46), 10, fill=WELL, outline=mix(WELL, STAT["tumble"][1], .45))
    stat_chip(c, "tumble", dx0 + 18, ry + 8, 30)
    c.text((dx0 + 56, ry + 7), "Needs Jump 30", black(11), TEXT)
    bar(c, (dx0 + 56, ry + 28, dx1 - 72, ry + 35), 22 / 30, STAT["tumble"][1], track=mix(WELL, "#FFFFFF", .08))
    c.text((dx1 - 18, ry + 31.5), "22 / 30", mono(9), SOFT, "rm")
    # action: go train, never a dead end
    primary(c, (dx0 + 10, ry + 54, dx1 - 10, ry + 54 + 34), "Train at the Pet Park")
    c.text(((dx0 + dx1) / 2, dy1 - 5.5), "", bold(8), DIM, "mm")

    # item grid (right)
    gx0, gx1, gy0 = 310, 818, 98
    tw2 = (gx1 - gx0 - 8) / 2; th = 58
    beanie = thumb("wardrobe-pom-beanie.jpg", (913, 273, 996, 355))
    sunhat = thumb("wardrobe-pom-beanie.jpg", (1163, 273, 1246, 355))
    crown = thumb("wardrobe-pom-beanie.jpg", (913, 391, 996, 473))
    items = [
        ("Pom Beanie", "WEARING", beanie, None, "owned"),
        ("Tiny Sun Hat", "30", sunhat, None, "price"),
        ("Flower Crown", "60", crown, None, "price"),
        ("Berry Beanie", "40", hue_shift(beanie, 300), ("heart", 10, True), "price"),
        ("Varsity Beanie", "80", hue_shift(beanie, 205), ("tumble", 30, False), "locked"),
        ("Dusk Crown", "120", hue_shift(crown, 170, 40), ("wonder", 40, False), "locked"),
        ("Sunny Sun Hat", "60", hue_shift(sunhat, 320), ("fetch", 15, True), "price"),
        ("Golden Beanie", "150", hue_shift(beanie, 48), ("total", 300, False), "locked"),
    ]
    for i, (name, sub, img, req, state) in enumerate(items):
        x0 = gx0 + (i % 2) * (tw2 + 8); y0 = gy0 + (i // 2) * (th + 5); x1, y1 = x0 + tw2, y0 + th
        selected = name == "Varsity Beanie"
        if selected:
            c.rr((x0 - 2.5, y0 - 2.5, x1 + 2.5, y1 + 2.5), 14, outline="#FFFFFF", width=1.6)
            c.rr((x0, y0, x1, y1), 12, fill=SELECTED, outline=ACCENT, width=1.4)
        else:
            c.card((x0, y0, x1, y1), 12)
        c.rr((x0 + 7, y0 + 7, x0 + 51, y0 + 51), 8, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
        if img is not None:
            show = img if state != "locked" else ImageEnhance.Brightness(img).enhance(.72)
            c.paste(show, (x0 + 8, y0 + 8, x0 + 50, y0 + 50), r=7)
        else:   # the mastery kite: drawn silhouette, art to come
            kx, ky = x0 + 29, y0 + 27
            c.poly([(kx, ky - 15), (kx + 11, ky - 1), (kx, ky + 12), (kx - 11, ky - 1)], mix(WELL, STAT["heart"][1], .55))
            c.line([(kx, ky + 12), (kx - 4, ky + 17), (kx + 3, ky + 21)], mix(WELL, STAT["heart"][1], .55), 1.2)
        c.text((x0 + 60, y0 + 11), name, black(11), TEXT if state != "locked" else SOFT)
        if state == "owned":
            c.text((x0 + 60, y0 + 30), "WEARING", xbold(8), ACCENT)
        elif state == "mastery":
            c.text((x0 + 60, y0 + 30), "Earned, never sold", bold(9), SOFT)
        else:
            star(c, x0 + 65, y0 + 36.5, 5, STARS if state == "price" else mix(STARS, PANEL, .35))
            c.text((x0 + 74, y0 + 36.5), sub, mono(10), STARS if state == "price" else mix(STARS, PANEL, .35), "lm")
        if req:
            k, lvl, met = req; color = STAT[k][1] if k in STAT else ACCENT
            label = f"{STAT[k][0] if k in STAT else 'Total'} {lvl}"
            w = c.width(label, xbold(8)) + 34
            rx1 = x1 - 8; rx0 = rx1 - w; ry0 = y0 + (th - 20) / 2
            c.rr((rx0, ry0, rx1, ry0 + 20), 10, fill=WELL if not met else mix(RAISED, color, .16), outline=mix(WELL, color, .7 if not met else .45))
            if k in STAT: stat_chip(c, k, rx0 + 3, ry0 + 3, 14, 4.5)
            else:
                c.rr((rx0 + 3, ry0 + 3, rx0 + 17, ry0 + 17), 4.5, fill=ACCENT)
                for j in range(3): c.rr((rx0 + 5.5 + j * 3.6, ry0 + 13 - (j + 1) * 2.4, rx0 + 8 + j * 3.6, ry0 + 14), .6, fill=INK)
            c.text((rx0 + 21, ry0 + 10), label, xbold(8), color if not met else TEXT, "lm")
            if not met:
                lock(c, x0 + 41, y0 + 18, 4.2, "#FFFFFF")
            else:
                c.line([(rx1 - 0, ry0 + 0)] * 2, color, 1)
    x = 30
    x += hint(c, x, 354, "+", "Browse")
    x += hint(c, x, 354, "LB", "Slot")
    x += hint(c, x, 354, "A", "Train", True)
    x += hint(c, x, 354, "B", "Back")
    c.text((818, 362), "Fixed prices. Try anything on. Levels unlock, Stars buy.", bold(9), DIM, "rm")
    c.save("04-locked-item-wardrobe-844x390@2x.png")


if __name__ == "__main__":
    stats_panel(); inspect_card(); stat_egg_level_up(); locked_item()
