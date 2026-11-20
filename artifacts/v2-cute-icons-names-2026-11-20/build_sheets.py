"""Review sheets for V2-CUTE-ICONS-AND-NAMES-2026-11-20.md (Fable as Astra). Proposal drawings only.

Drawn with PIL. The icons come from assets/ui/stat-icons/build_icons.py (run that first). The two
screen mockups are drawn over real Studio captures from artifacts/v2-toy-shell-build/; the Bear is
the capture's own pixels. No generated art.

Run from the repo root:  python artifacts/v2-cute-icons-names-2026-11-20/build_sheets.py
"""
import glob, importlib.util, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, path)); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
icons = _load("build_icons", "assets/ui/stat-icons/build_icons.py")
runes = _load("build_runes", "assets/ui/stat-runes/build_runes.py")
ICON_DIR, RUNE_DIR, SNACKS = os.path.join(ROOT, "assets/ui/stat-icons"), os.path.join(ROOT, "assets/ui/stat-runes"), os.path.join(ROOT, "assets/art-source/snacks/export")
CAP = os.path.join(ROOT, "artifacts/v2-toy-shell-build")
ORDER, COLOR, rgb, mix = icons.ORDER, icons.COLOR, icons.rgb, icons.mix
NAMES = {s[0]: s[1] for s in icons.STATS}

RBX = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")
def _find(name, fallback):
    hits = sorted(glob.glob(os.path.join(RBX, name))); return hits[-1] if hits else fallback
FILES = {"disp": _find("FredokaOne-Regular.ttf", "C:/Windows/Fonts/Nunito-Black.ttf"), "b": _find("BuilderSans-Bold.otf", "C:/Windows/Fonts/Nunito-Bold.ttf"),
         "m": _find("BuilderSans-Medium.otf", "C:/Windows/Fonts/Nunito-SemiBold.ttf"), "mono": "C:/Windows/Fonts/RobotoMono-Bold.ttf"}
_fc = {}
def font(key, size):
    k = (key, round(size))
    if k not in _fc: _fc[k] = ImageFont.truetype(FILES[key], k[1])
    return _fc[k]

INK, INK_SOFT, CREAM, CREAM_LIP, WHITE = "#15143A", "#4A4972", "#FFF4DC", "#D6C196", "#FFFFFF"
LEMON, LEMON_LIP, GO, GO_LIP, PINK, TEAL = "#FFE14D", "#D9A31C", "#43DB5F", "#1C8F3C", "#FF8FC0", "#3FD9B4"
DIS, DIS_LIP, DIS_TEXT, STARS = "#B9B6C9", "#8C89A3", "#5A5878", "#FFC14D"
# Scout deck palette, measured from the capture
SHELL_HI, SHELL, SHELL_LIP, TRAY, TROUGH, OUT, ON_SOFT = "#21806A", "#0D735B", "#0F3F33", "#084F3D", "#06392D", "#001F1A", "#D6F2E6"


def grey(im):
    g = im.convert("L").convert("RGBA"); g.putalpha(im.getchannel("A")); return g
def ic(kind, px): return icons.icon_hi(kind, px, ss=max(4, round(192 / px))).resize((px, px), Image.LANCZOS)
def put(im, sp, xy): im.paste(sp, (round(xy[0]), round(xy[1])), sp)


# ---------- 01: three directions ----------
def blank_stone(kind, px):
    keep = runes.STAVES, runes.STAVES_SMALL
    runes.STAVES = {k: [] for k in ORDER}; runes.STAVES_SMALL = runes.STAVES
    st = runes.stone_hi(kind, px, small=px < 36, ss=8).resize((px, px), Image.LANCZOS)
    runes.STAVES, runes.STAVES_SMALL = keep; return st

def stone_buddy(kind, px):
    """Direction B: the stat stone stays, with a cream buddy on it."""
    st = blank_stone(kind, px); keep = icons.COLOR[kind]; icons.COLOR[kind] = CREAM
    n = round(px * .66); b = icons.icon_hi(kind, n, ss=max(4, round(256 / n)), pad=0, d=1 if px >= 36 else 0).resize((n, n), Image.LANCZOS)
    icons.COLOR[kind] = keep; put(st, b, ((px - n) / 2, (px - n) / 2 - px * .03)); return st

def bear_pose(kind, px, ss=6):
    """Direction C sketch: the Bear's head with the stat as a small prop."""
    S = px * ss; im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im); o = max(1.5, px * .055) * ss
    def blob(cx, cy, rx, ry, fill):
        d.ellipse(((cx - rx) * S - o, (cy - ry) * S - o, (cx + rx) * S + o, (cy + ry) * S + o), fill=rgb(INK)); return (cx, cy, rx, ry, fill)
    parts = [blob(.22, .22, .12, .12, WHITE), blob(.70, .22, .12, .12, WHITE), blob(.46, .50, .36, .31, WHITE)]
    for cx, cy, rx, ry, fill in parts: d.ellipse(((cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S), fill=rgb(fill))
    for x in (.31, .61): d.ellipse(((x - .04) * S, .49 * S, (x + .04) * S, .59 * S), fill=rgb(INK))
    d.ellipse((.40 * S, .60 * S, .52 * S, .68 * S), fill=rgb("#C9C6D6")); d.ellipse((.44 * S, .60 * S, .48 * S, .63 * S), fill=rgb(INK))
    im = im.resize((px, px), Image.LANCZOS); n = round(px * .5)
    put(im, icons.icon_hi(kind, n, ss=max(4, round(256 / n)), pad=0, d=0).resize((n, n), Image.LANCZOS), (px - n, px - n)); return im

def sheet_directions():
    W, H = 1500, 900; im = Image.new("RGB", (W, H), rgb("#F1ECE6")); d = ImageDraw.Draw(im)
    d.text((40, 28), "Cuter stat icons: three directions", font=font("disp", 40), fill=rgb(INK))
    d.text((40, 80), "Each row: 64 px, then the 24 px chip at 1:1, at 3x, and at 3x in grey. Heart, Power, Energy, Jump, Speed, Smarts.", font=font("m", 20), fill=rgb(INK_SOFT))
    rows = [("Today: rune stones", "Clear and tidy, but they are letters nobody can read. Not cute.", lambda k, p: Image.open(os.path.join(RUNE_DIR, "rune-%s-%s.png" % (k, "64" if p == 64 else "small-24"))).convert("RGBA"), None),
            ("A  Pocket Buddies  (recommended)", "The thing itself with a face: a different outline for every stat, so it reads in grey.", lambda k, p: ic(k, p), GO),
            ("B  Buddy stones", "Keep the stone, put a cream buddy on it. Tidy, but six squares again; the face is tiny at 24 px.", stone_buddy, None),
            ("C  Pet poses (sketch)", "The Bear doing each stat. Cute large; at 24 px six bears look the same, and it is one species.", bear_pose, None)]
    for r, (title, note, fn, mark) in enumerate(rows):
        y = 130 + r * 190; d.rounded_rectangle((30, y, W - 30, y + 174), 26, fill=rgb("#FAF7F2"), outline=rgb(mark or "#DDD6CC"), width=5 if mark else 3)
        d.text((54, y + 14), title, font=font("disp", 26), fill=rgb(INK)); d.text((54, y + 50), note, font=font("m", 18), fill=rgb(INK_SOFT))
        d.rounded_rectangle((54, y + 84, 54 + 6 * 76 + 8, y + 160), 14, fill=rgb(CREAM), outline=rgb(CREAM_LIP), width=2)
        d.rounded_rectangle((540, y + 100, 540 + 6 * 32 + 8, y + 144), 10, fill=rgb("#1D36A6"))
        for i, k in enumerate(ORDER):
            put(im, fn(k, 64), (62 + i * 76, y + 90)); s = fn(k, 24); put(im, s, (548 + i * 32, y + 110))
            put(im, s.resize((72, 72), Image.NEAREST), (770 + i * 80, y + 86))
            put(im, grey(s).resize((48, 48), Image.NEAREST), (1260 + (i % 3) * 68, y + 62 + (i // 3) * 54))
    im.save(os.path.join(HERE, "01-icon-directions.png")); print("wrote 01-icon-directions.png")


# ---------- 02: the recommended set, on every surface, and in the real stats panel ----------
def sheet_set():
    W, H = 1688, 1500; im = Image.new("RGB", (W, H), rgb("#F1ECE6")); d = ImageDraw.Draw(im)
    d.text((40, 26), "Pocket Buddies: the production set", font=font("disp", 40), fill=rgb(INK))
    d.text((40, 78), "128 px, 64 px and the 24 px chip (drawn for each size, not scaled down). Stat colours unchanged. Ink outline, lip, soft top light.", font=font("m", 20), fill=rgb(INK_SOFT))
    for i, k in enumerate(ORDER):
        x = 40 + i * 272; d.rounded_rectangle((x, 120, x + 252, 380), 24, fill=rgb(CREAM), outline=rgb(CREAM_LIP), width=3)
        put(im, Image.open(os.path.join(ICON_DIR, "icon-%s-128.png" % k)), (x + 14, 134)); put(im, Image.open(os.path.join(ICON_DIR, "icon-%s-64.png" % k)), (x + 160, 150))
        s = Image.open(os.path.join(ICON_DIR, "icon-%s-small-24.png" % k)); put(im, s, (x + 180, 228))
        d.text((x + 18, 276), NAMES[k], font=font("disp", 26), fill=rgb(INK)); d.text((x + 18, 310), icons.STATS[i][3] + "  " + COLOR[k], font=font("mono", 16), fill=rgb(INK_SOFT))
        put(im, s.resize((96, 96), Image.NEAREST), (x + 18, 392)); put(im, grey(s).resize((96, 96), Image.NEAREST), (x + 138, 392))
    d.text((40, 496), "24 px chip at 4x, hard pixels: colour, then grey. Below: chips at 1:1 on every Toy Shell surface.", font=font("m", 18), fill=rgb(INK_SOFT))
    bgs = [("cream tile", CREAM), ("selected", LEMON), ("shell", "#2E55E6"), ("tray", "#1D36A6"), ("well", "#10133A"), ("Scout shell", SHELL), ("grass", "#6BBF4A"), ("grey", "#888888")]
    for r, (label, bg) in enumerate(bgs):
        x = 40 + r * 204; d.rounded_rectangle((x, 530, x + 194, 600), 12, fill=rgb(bg))
        for i, k in enumerate(ORDER):
            s = Image.open(os.path.join(ICON_DIR, "icon-%s-small-24.png" % k)); put(im, grey(s) if label == "grey" else s, (x + 8 + i * 30, 540))
        d.text((x + 8, 572), label, font=font("b", 16), fill=rgb(INK if r in (0, 1, 6) else WHITE))
    # the real stats panel with the buddies swapped in for the runes (capture at 2x; only the icons are redrawn)
    cap = Image.open(os.path.join(CAP, "after-05-stats-844x390-scout.png")).convert("RGB"); big = cap.resize((1688, 780), Image.LANCZOS); bd = ImageDraw.Draw(big)
    spots = [(215, 131), (423, 131), (631, 131), (215, 227), (423, 227), (631, 227)]
    for k, (x, y) in zip(ORDER, spots):
        fill = cap.getpixel((x - 2, y + 15)); bd.rectangle((x * 2 - 2, y * 2 - 2, (x + 31) * 2 + 2, (y + 31) * 2 + 2), fill=fill)
        big.paste(ic(k, 64), (x * 2 - 1, y * 2 - 1), ic(k, 64))
    fill = cap.getpixel((216, 340)); bd.rectangle((218 * 2, 326 * 2, 243 * 2, 352 * 2), fill=fill); big.paste(ic("heart", 52), (218 * 2 - 1, 326 * 2), ic("heart", 52))
    im.paste(big, (0, 660)); d.text((40, 624), "In the live stats panel (Studio capture at 2x; only the six marks are redrawn):", font=font("b", 20), fill=rgb(INK))
    im.save(os.path.join(HERE, "02-pocket-buddies-set.png")); print("wrote 02-pocket-buddies-set.png")
    big.save(os.path.join(HERE, "02b-stats-panel-with-buddies-844x390@2x.png")); print("wrote 02b-stats-panel-with-buddies-844x390@2x.png")


# ---------- 03: level-up burst and snack decals ----------
def sheet_burst_decals():
    W, H = 1100, 760; im = Image.new("RGB", (W, H), rgb("#F1ECE6")); d = ImageDraw.Draw(im)
    d.text((40, 24), "Level-up burst and snack decals", font=font("disp", 36), fill=rgb(INK))
    for r, (n, label) in enumerate((("levelup-burst-8x128.png", "all six"), ("levelup-burst-speed-8x128.png", "one stat (Speed)"))):
        y = 84 + r * 150; d.rounded_rectangle((38, y, 38 + 1024, y + 128), 14, fill=rgb("#1D36A6" if r == 0 else CREAM)); b = Image.open(os.path.join(ICON_DIR, n)); put(im, b, (38, y))
        d.text((48, y + 104), label, font=font("b", 16), fill=rgb(WHITE if r == 0 else INK))
    d.text((40, 392), "Snack icing decals, 256 px, dark cocoa on clear. Top: today's runes. Bottom: the buddies (eyes and smile are cut out, so the icing shows).", font=font("m", 17), fill=rgb(INK_SOFT))
    for r, pre in enumerate(("rune", "icon")):
        for i, k in enumerate(ORDER):
            x, y = 40 + i * 172, 428 + r * 160; d.ellipse((x, y, x + 150, y + 150), fill=mix(COLOR[k], WHITE, .30), outline=rgb("#EDBE76"), width=8)
            dc = Image.open(os.path.join(SNACKS, "%s-decal-%s-256.png" % (pre, k))).resize((150, 150), Image.LANCZOS); put(im, dc, (x, y))
    im.save(os.path.join(HERE, "03-burst-and-snack-decals.png")); print("wrote 03-burst-and-snack-decals.png")


# ---------- 04: the naming screen, 844x390 at 2x, over the Studio capture ----------
R = 4                                                    # draw at 4x, save at 2x
def S(v): return int(round(v * R))

class Canvas:
    def __init__(self, backdrop): self.im = backdrop.convert("RGB").resize((S(844), S(390)), Image.LANCZOS); self.d = ImageDraw.Draw(self.im)
    def rr(self, box, r, fill): self.d.rounded_rectangle((S(box[0]), S(box[1]), S(box[2]) - 1, S(box[3]) - 1), S(max(0, min(r, (box[2] - box[0]) / 2, (box[3] - box[1]) / 2))), fill=rgb(fill))
    def piece(self, box, r, face, lip_col, lip=3, outline=2, glint=True, edge=INK):
        """Toy Shell moulding: ink outline inside the rect, face, glint, lip."""
        x0, y0, x1, y1 = box; self.rr(box, r, edge); o = outline
        self.rr((x0 + o, y0 + o, x1 - o, y1 - o), r - o, lip_col); self.rr((x0 + o, y0 + o, x1 - o, y1 - o - lip), r - o, face)
        if glint and y1 - y0 >= 20:
            g = mix(face, WHITE, .6); gy = y0 + o + 3.2; a, b = x0 + r * .7 + 2, x1 - r * .7 - 12
            self.d.line([(S(a), S(gy)), (S(b), S(gy))], fill=g, width=S(1.5)); self.d.ellipse((S(b + 5), S(gy - .75), S(b + 6.5), S(gy + .75)), fill=g)
    def text(self, xy, s, key, size, fill, anchor="la"): self.d.text((S(xy[0]), S(xy[1])), s, font=font(key, size * R), fill=rgb(fill), anchor=anchor)
    def width(self, s, key, size): return self.d.textlength(s, font=font(key, size * R)) / R
    def sprite(self, sp, x, y): self.im.paste(sp, (S(x), S(y)), sp)
    def icon(self, kind, x, y, px): self.sprite(icons.icon_hi(kind, px, ss=R, d=0 if px < 30 else 1), x, y)
    def star4(self, cx, cy, rad, fill, outline=INK, ow=1.2): icons.star4(self.d, S(cx), S(cy), S(rad), rgb(fill), rgb(outline) if outline else None, S(ow), rot=.2)

def mark(c, kind, x, y, px=18):
    """Where a name piece comes from: a stat buddy, the starter star, the Names Egg, a Keeper leaf, the book."""
    if kind in COLOR: c.icon(kind, x - 1, y - 1, px + 2); return
    d = c.d; cx, cy = x + px / 2, y + px / 2
    if kind == "starter": c.star4(cx, cy, px * .5, GO, INK, 1.4)
    elif kind == "egg":
        d.ellipse((S(cx - px * .40), S(cy - px * .5), S(cx + px * .40), S(cy + px * .5)), fill=rgb(INK)); d.ellipse((S(cx - px * .40 + 1.5), S(cy - px * .5 + 1.5), S(cx + px * .40 - 1.5), S(cy + px * .5 - 1.5)), fill=rgb(PINK))
        d.ellipse((S(cx - 2.4), S(cy - 1), S(cx - .2), S(cy + 1.8)), fill=rgb(INK)); d.ellipse((S(cx + 1.4), S(cy - 1), S(cx + 3.6), S(cy + 1.8)), fill=rgb(INK))
    elif kind == "keeper":
        for sx in (-1, 1):
            box = (S(cx + (-.5 if sx < 0 else .02) * px), S(cy - px * .42), S(cx + (-.02 if sx < 0 else .5) * px), S(cy + px * .12))
            d.ellipse(box, fill=rgb(INK)); d.ellipse((box[0] + S(1.5), box[1] + S(1.5), box[2] - S(1.5), box[3] - S(1.5)), fill=rgb(GO))
        d.line([(S(cx), S(cy - px * .05)), (S(cx), S(cy + px * .48))], fill=rgb(INK), width=S(2.4))
    elif kind == "book":
        d.rounded_rectangle((S(cx - px * .46), S(cy - px * .40), S(cx + px * .46), S(cy + px * .42)), S(2.5), fill=rgb(INK))
        d.rounded_rectangle((S(cx - px * .46 + 1.5), S(cy - px * .40 + 1.5), S(cx + px * .46 - 1.5), S(cy + px * .42 - 1.5)), S(1.2), fill=rgb(TEAL))
        d.line([(S(cx), S(cy - px * .34)), (S(cx), S(cy + px * .36))], fill=rgb(INK), width=S(1.5))

def checker(c, box):
    x0, y0, x1, y1 = box; c.d.rectangle((S(x0), S(y0), S(x1) - 1, S(y1) - 1), fill=rgb(SHELL))
    for j in range(int((y0 - 100) // 16), int((y1 - 100) // 16) + 1):
        for i in range(int((x0 - 167.6) // 16.4), int((x1 - 167.6) // 16.4) + 1):
            if (i + j) % 2: continue
            a, b = 167.6 + i * 16.4, 100 + j * 16; t = min(1, max(0, (b - 72) / 300))
            if min(x1, a + 16.4) - max(x0, a) < .5 or min(y1, b + 16) - max(y0, b) < .5: continue
            c.d.rectangle((S(max(x0, a)), S(max(y0, b)), S(min(x1, a + 16.4)) - 1, S(min(y1, b + 16)) - 1), fill=mix(SHELL_HI, SHELL, t * .62))

def naming_screen():
    cap = Image.open(os.path.join(CAP, "after-05-stats-844x390-scout.png")); c = Canvas(cap)
    checker(c, (12, 116, 831, 377)); checker(c, (14, 76, 200, 116))                      # clear the stats body and the old title
    # header plate (the wallet, help and back keys stay from the capture)
    tw = c.width("Name your Bear", "disp", 17); c.piece((16, 80, 16 + tw + 40, 110), 8, PINK, "#C45C8E", lip=2)
    c.text((26, 84), "Name your Bear", "disp", 17, INK); c.star4(16 + tw + 26, 93, 6, WHITE)
    # left: the pet in its well (capture pixels), the name as it floats over the pet, the species chip
    c.rr((20, 124, 198, 372), 14, OUT); c.rr((22, 126, 196, 370), 12, TRAY)
    c.rr((30, 130, 188, 296), 12, "#2A0F22"); c.rr((31.5, 131.5, 186.5, 294.5), 10.5, (75, 31, 58))
    pet = cap.crop((36, 142, 180, 256)).resize((S(144), S(114)), Image.LANCZOS); c.im.paste(pet, (S(37), S(160)))       # the Bear, capture pixels
    c.rr((56, 266, 162, 290), 12, "#10133A"); c.text((109, 278), "BEAR", "b", 11.5, "#8DF0A3", "mm")
    name = "Biscuit Sprout"; nw = c.width(name, "disp", 15) + 22; nx = 109 - nw / 2
    c.d.polygon([(S(103), S(158)), (S(115), S(158)), (S(109), S(166))], fill=rgb(INK)); c.piece((nx, 136, nx + nw, 161), 12, CREAM, CREAM_LIP, lip=2, glint=False)
    c.text((109, 147.5), name, "disp", 15, INK, "mm")
    c.text((32, 303), "SHOWS", "b", 10.5, ON_SOFT); c.text((32, 317), "Over your pet", "b", 12.5, WHITE); c.text((32, 332), "On its card and stats", "b", 12.5, WHITE)
    c.text((32, 351), "Each pet has its own name.", "m", 11, ON_SOFT)
    # right, top: the two slots
    X0, X1 = 208, 824
    c.rr((X0, 124, X1, 180), 12, OUT); c.rr((X0 + 2, 126, X1 - 2, 178), 10, TRAY)
    slots = [("Biscuit", "starter", "1"), ("Sprout", "keeper", "2")]
    for i, (word, src, num) in enumerate(slots):
        x = X0 + 12 + i * 208; c.piece((x, 135, x + 166, 171), 10, LEMON, LEMON_LIP)
        mark(c, src, x + 10, 143); c.text((x + 36, 151.5), word, "disp", 16, INK, "lm")
        c.d.ellipse((S(x + 140), S(143), S(x + 157), S(160)), fill=rgb(INK)); c.text((x + 148.5, 151.5), num, "mono", 10.5, CREAM, "mm")
    sx = X0 + 12 + 166 + 6; c.d.ellipse((S(sx), S(137), S(sx + 30), S(169)), fill=rgb(INK)); c.d.ellipse((S(sx + 2), S(139), S(sx + 28), S(167)), fill=rgb(CREAM_LIP)); c.d.ellipse((S(sx + 2), S(139), S(sx + 28), S(164)), fill=rgb(CREAM))
    for dy, s in ((-3.5, 1), (3.5, -1)):                                                     # swap arrows
        y = 151.5 + dy; c.d.line([(S(sx + 9), S(y)), (S(sx + 21), S(y))], fill=rgb(INK), width=S(2.2))
        tip = sx + (21 if s > 0 else 9); c.d.polygon([(S(tip + 3 * s), S(y)), (S(tip - 1.5 * s), S(y - 3.4)), (S(tip - 1.5 * s), S(y + 3.4))], fill=rgb(INK))
    cx = X0 + 12 + 208 + 166 + 10; c.piece((cx, 139, cx + 62, 168), 10, CREAM, CREAM_LIP); c.text((cx + 31, 152), "Clear", "disp", 12.5, INK, "mm")
    c.text((cx + 76, 141), "One piece or two.", "b", 12.5, WHITE); c.text((cx + 76, 157), "No typing, ever.", "m", 11.5, ON_SOFT)
    # tabs
    c.rr((X0, 186, X1, 212), 10, OUT); c.rr((X0 + 2, 188, X1 - 2, 210), 8, TROUGH)
    tabs = [("All", "14/52"), ("Starter", "6/6"), ("Names Egg", "3/20"), ("Stats", "4/22"), ("Book", "1/4")]; tw_ = (X1 - X0 - 4) / len(tabs)
    for i, (t, n) in enumerate(tabs):
        x = X0 + 2 + i * tw_
        if i == 0: c.piece((x, 187, x + tw_, 211), 8, LEMON, LEMON_LIP, lip=2, glint=False)
        w1 = c.width(t, "disp", 12.5); w2 = c.width(n, "mono", 10); x0 = x + (tw_ - w1 - w2 - 6) / 2
        c.text((x0, 198.5), t, "disp", 12.5, INK if i == 0 else WHITE, "lm"); c.text((x0 + w1 + 6, 199), n, "mono", 10, INK_SOFT if i == 0 else ON_SOFT, "lm")
    # grid of pieces: (word, source, state, requirement)
    grid = [("Biscuit", "starter", "sel", ""), ("Puddle", "starter", "own", ""), ("Tuesday", "starter", "own", ""), ("Button", "starter", "own", ""),
            ("Velvet", "egg", "own", ""), ("Noodle", "egg", "own", ""), ("Waffle", "egg", "own", ""), ("Sprout", "keeper", "sel", ""),
            ("Cuddle", "heart", "own", ""), ("Zoomies", "speed", "lock", "SPEED 10"), ("Speedy", "speed", "lock", "SPEED 25"), ("Bookworm", "book", "lock", "10 PAGES")]
    gw = (X1 - X0 - 8 - 3 * 6) / 4
    for i, (word, src, state, req) in enumerate(grid):
        x = X0 + (i % 4) * (gw + 6); y = 218 + (i // 4) * 39; lock = state == "lock"
        face, lip = {"sel": (LEMON, LEMON_LIP), "own": (CREAM, CREAM_LIP), "lock": (DIS, DIS_LIP)}[state]
        c.piece((x, y, x + gw, y + 35), 9, face, lip, lip=2 if lock else 3, glint=not lock)
        mark(c, src, x + 9, y + 7); c.text((x + 33, y + (11.5 if lock else 16)), word, "disp", 14, DIS_TEXT if lock else INK, "lm")
        if lock: c.text((x + 33, y + 24), req, "mono", 8.5, DIS_TEXT, "lm")
        if state == "sel": c.d.ellipse((S(x + gw - 25), S(y + 8), S(x + gw - 9), S(y + 24)), fill=rgb(INK)); c.text((x + gw - 17, y + 16), "1" if word == "Biscuit" else "2", "mono", 10, CREAM, "mm")
    c.rr((X1 - 4, 218, X1, 331), 2, TROUGH); c.rr((X1 - 4, 218, X1, 250), 2, ON_SOFT)       # scroll bar
    # bottom: hint, Names Egg key, the one primary
    c.text((X0 + 2, 346), "Renaming is free, any time.", "b", 12.5, WHITE); c.text((X0 + 2, 361), "A piece you unlock is yours for every pet.", "m", 11, ON_SOFT)
    c.piece((530, 338, 690, 372), 11, CREAM, CREAM_LIP); mark(c, "egg", 541, 345, 17); c.text((566, 353.5), "Names Egg", "disp", 13.5, INK, "lm")
    c.rr((642, 345, 682, 362), 8.5, "#10133A"); c.star4(652, 353.5, 5.5, STARS, None); c.text((668, 353.5), "8", "mono", 11, STARS, "mm")
    c.piece((698, 337, 824, 373), 12, GO, GO_LIP, lip=4); c.text((761, 352.5), "Save name", "disp", 15.5, INK, "mm")
    out = c.im.resize((1688, 780), Image.LANCZOS); out.save(os.path.join(HERE, "04-naming-screen-844x390@2x.png")); print("wrote 04-naming-screen-844x390@2x.png")


if __name__ == "__main__":
    sheet_directions(); sheet_set(); sheet_burst_decals(); naming_screen()
