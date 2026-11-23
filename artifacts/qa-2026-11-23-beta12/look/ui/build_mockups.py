"""Mockups for DASH-DECK-UI-LOOK.md (Fable, 2026-11-23). Hand-drawn with PIL: no generated images.
Units are Roblox offset px ("pt") on Spencer's phone: 874 x 402 pt (his 2048 x 942 screenshots, 2.343 px per pt).
Run: python artifacts/qa-2026-11-23-beta12/look/ui/build_mockups.py"""
import glob, math, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RBX = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")
def _find(name, fallback):
    hits = sorted(glob.glob(os.path.join(RBX, name)))
    return hits[-1] if hits else fallback
FILES = {"disp": _find("FredokaOne-Regular.ttf", "C:/Windows/Fonts/Nunito-Black.ttf"),
         "b": _find("BuilderSans-Bold.otf", "C:/Windows/Fonts/Nunito-Bold.ttf"),
         "m": _find("BuilderSans-Medium.otf", "C:/Windows/Fonts/Nunito-SemiBold.ttf"),
         "r": _find("BuilderSans-Regular.otf", "C:/Windows/Fonts/Nunito-Regular.ttf")}
_fc = {}
def font(key, px):
    k = (key, int(round(px)))
    if k not in _fc: _fc[k] = ImageFont.truetype(FILES[key], k[1])
    return _fc[k]

INK, INK_SOFT = "#15143A", "#4A4972"
CREAM, CREAM_LIP, WHITE = "#FFF4DC", "#D6C196", "#FFFFFF"
SHELL, TRAY, WELL, SOFT = "#23752E", "#164F1E", "#091F0C", "#CEF0D2"
GO, LEMON, STARS = "#43DB5F", "#FFE14D", "#FFC14D"
STRIP, CHIP, STRIP_SOFT = "#20234A", "#2C3060", "#DCE5FF"
HEART, POWER, ENERGY, JUMP, SPEED = "#FF86A8", "#FF9D4D", "#6CCBFF", "#B9EE5A", "#8FA8FF"
PUFF, NOTE = "#B9B6C9", "#FF2E93"

def rgba(c, a=255):
    c = c.lstrip("#"); return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)

class Cv:
    """A canvas in pt; drawn at k px per pt (already supersampled), saved at k/ss."""
    def __init__(s, w, h, k=4, ss=2, bg=None):
        s.w, s.h, s.k, s.ss = w, h, k, ss
        s.im = Image.new("RGBA", (int(w * k), int(h * k)), rgba(bg) if bg else (0, 0, 0, 0))
        s.d = ImageDraw.Draw(s.im)
    def P(s, v): return v * s.k
    def layer(s):
        l = Image.new("RGBA", s.im.size, (0, 0, 0, 0)); return l, ImageDraw.Draw(l)
    def over(s, l):
        s.im = Image.alpha_composite(s.im, l); s.d = ImageDraw.Draw(s.im)
    def rect(s, x, y, w, h, fill=None, r=0, stroke=None, sw=0, a=255):
        box = [s.P(x), s.P(y), s.P(x + w), s.P(y + h)]
        if a < 255:
            l, d = s.layer(); d.rounded_rectangle(box, s.P(r), fill=rgba(fill, a)); s.over(l)
        elif fill: s.d.rounded_rectangle(box, s.P(r), fill=rgba(fill))
        if stroke: s.d.rounded_rectangle(box, s.P(r), outline=rgba(stroke), width=max(1, int(s.P(sw))))
    def panel(s, x, y, w, h, fill, r=12, sw=2, stroke=INK):
        s.rect(x - sw, y - sw, w + 2 * sw, h + 2 * sw, stroke, r + sw); s.rect(x, y, w, h, fill, r)
    def ell(s, x, y, w, h, fill, a=255, stroke=None, sw=0):
        box = [s.P(x), s.P(y), s.P(x + w), s.P(y + h)]
        if a < 255:
            l, d = s.layer(); d.ellipse(box, fill=rgba(fill, a)); s.over(l)
        else: s.d.ellipse(box, fill=rgba(fill) if fill else None, outline=rgba(stroke) if stroke else None, width=int(s.P(sw)))
    def poly(s, pts, fill, a=255):
        pts = [(s.P(x), s.P(y)) for x, y in pts]
        if a < 255:
            l, d = s.layer(); d.polygon(pts, fill=rgba(fill, a)); s.over(l)
        else: s.d.polygon(pts, fill=rgba(fill))
    def line(s, pts, fill, w=1, a=255):
        s.d.line([(s.P(x), s.P(y)) for x, y in pts], fill=rgba(fill, a), width=max(1, int(s.P(w))), joint="curve")
    def tw(s, t, key, size): return font(key, s.P(size)).getlength(t) / s.k
    def text(s, x, y, t, key="b", size=14, fill=WHITE, anchor="la", stroke=None, sw=0, a=255):
        f = font(key, s.P(size))
        if a < 255:
            l, d = s.layer(); d.text((s.P(x), s.P(y)), t, font=f, fill=rgba(fill, a), anchor=anchor); s.over(l)
        else:
            s.d.text((s.P(x), s.P(y)), t, font=f, fill=rgba(fill), anchor=anchor,
                     stroke_width=int(s.P(sw)) if stroke else 0, stroke_fill=rgba(stroke) if stroke else None)
    def paste(s, im, x, y, w, h):
        im = im.resize((int(s.P(w)), int(s.P(h))), Image.LANCZOS); s.im.alpha_composite(im, (int(s.P(x)), int(s.P(y)))); s.d = ImageDraw.Draw(s.im)
    def save(s, name):
        out = s.im.resize((s.im.width // s.ss, s.im.height // s.ss), Image.LANCZOS)
        out.save(os.path.join(HERE, name)); print(name, out.size)
    # ---- house pieces ----
    def button(s, x, y, w, h, label, kind="cream", size=15, lip=4, r=12, sub=None):
        face = {"cream": CREAM, "go": GO, "lemon": LEMON}[kind]
        s.rect(x - 2, y - 2, w + 4, h + 4, INK, r + 2); s.rect(x, y, w, h - lip, face, r)
        if kind == "go": s.rect(x + 8, y + 3, w - 16, 2, WHITE, 1, a=150)
        cy = y + (h - lip) / 2
        if sub:
            s.text(x + w / 2, cy - 10, label, "disp", size, INK, "mm"); s.text(x + w / 2, cy + 11, sub, "m", 11, INK_SOFT, "mm")
        else: s.text(x + w / 2, cy, label, "disp", size, INK, "mm")
    def close(s, x, y, d=32):
        s.ell(x - 2, y - 2, d + 4, d + 6, INK); s.ell(x, y, d, d, CREAM)
        c, r = (x + d / 2, y + d / 2), d * .2
        s.line([(c[0] - r, c[1] - r), (c[0] + r, c[1] + r)], INK, 3); s.line([(c[0] - r, c[1] + r), (c[0] + r, c[1] - r)], INK, 3)
    def star(s, cx, cy, R, fill=STARS):
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5; rr = R if i % 2 == 0 else R * .48
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        s.poly(pts, fill)
    def heart(s, cx, cy, R, fill=HEART):
        s.ell(cx - R, cy - R * .8, R, R, fill); s.ell(cx, cy - R * .8, R, R, fill)
        s.poly([(cx - R * .96, cy - R * .12), (cx + R * .96, cy - R * .12), (cx, cy + R * .9)], fill)
    def pet(s, cx, by, sz, body=WHITE, shade="#D9E6F5"):
        """Placeholder pet (a round bunny blob) standing with its feet at by. Not final art."""
        u = sz / 100
        s.ell(cx - 30 * u, by - 8 * u, 60 * u, 12 * u, "#000000", a=50)
        for dx in (-17, 5): s.rect(cx + dx * u, by - 118 * u, 13 * u, 46 * u, body, 6 * u, stroke=shade, sw=1.2 * u)
        s.ell(cx - 30 * u, by - 56 * u, 60 * u, 54 * u, body, stroke=shade, sw=1.2 * u)
        s.ell(cx - 34 * u, by - 96 * u, 68 * u, 56 * u, body, stroke=shade, sw=1.2 * u)
        for dx in (-17, 9):
            s.ell(cx + dx * u, by - 74 * u, 9 * u, 11 * u, INK); s.ell(cx + (dx + 2) * u, by - 73 * u, 3.4 * u, 3.4 * u, WHITE)
        for dx in (-28, 17): s.ell(cx + dx * u, by - 62 * u, 11 * u, 6 * u, "#FFB3C7", a=200)
        for dx in (-22, 9): s.ell(cx + dx * u, by - 8 * u, 14 * u, 9 * u, body, stroke=shade, sw=1.2 * u)
    def scene(s, sky="#7FC8FF", grass="#3FA34A", horizon=.42, dim=0):
        s.rect(0, 0, s.w, s.h * horizon, sky)
        for i, (x, w) in enumerate(((60, 150), (300, 110), (620, 170), (800, 90))):
            s.ell(x * s.w / 874, s.h * horizon - 24 - (i % 2) * 10, w * s.w / 874, 70, "#2F8A3C")
        s.rect(0, s.h * horizon, s.w, s.h * (1 - horizon), grass)
        for i in range(60):
            x = (i * 137) % int(s.w); y = s.h * horizon + 8 + (i * 71) % int(s.h * (1 - horizon) - 10)
            s.rect(x, y, 5, 2, "#58BD5F", 1)
        if dim: s.rect(0, 0, s.w, s.h, INK, a=dim)
    def roblox(s):
        s.ell(76, 12, 43, 43, WHITE, a=235); s.rect(127, 12, 136, 43, WHITE, 21, a=235)
        s.rect(89, 25, 17, 17, "#222222", 3); s.rect(94, 30, 7, 7, WHITE, 1)
    # ---- annotation ----
    def dim_h(s, x1, x2, y, label, up=True):
        s.line([(x1, y), (x2, y)], NOTE, .8)
        for x in (x1, x2): s.line([(x, y - 3), (x, y + 3)], NOTE, .8)
        s.note((x1 + x2) / 2 - s.tw(label, "b", 8.5) / 2, y - 14 if up else y + 4, label, size=8.5)
    def dim_v(s, x, y1, y2, label, left=False):
        s.line([(x, y1), (x, y2)], NOTE, .8)
        for y in (y1, y2): s.line([(x - 3, y), (x + 3, y)], NOTE, .8)
        s.note(x - 7 - s.tw(label, "b", 8.5) if left else x + 7, (y1 + y2) / 2 - 5, label, size=8.5)
    def note(s, x, y, t, anchor="la", size=9):
        lines = t.split("\n"); w = max(s.tw(l, "b", size) for l in lines); lh = size * 1.25
        s.rect(x - 3, y - 1.5, w + 6, lh * len(lines) + 2, WHITE, 3, a=235)
        for i, l in enumerate(lines): s.text(x, y + i * lh, l, "b", size, "#C2185B", "la")
    def tag(s, n, x, y):
        s.ell(x - 8, y - 8, 16, 16, NOTE); s.text(x, y, str(n), "b", 10, WHITE, "mm")

# ------------------------------------------------------------------ icons (256 px, transparent)
def icon_canvas(): return Cv(256, 256, k=4, ss=4)
def icon_dash(color=INK):
    c = icon_canvas()
    bolt = [(168, 18), (92, 140), (136, 140), (108, 238), (212, 100), (158, 100), (192, 18)]
    c.poly(bolt, color); c.line(bolt + [bolt[0]], color, 12)
    for x, y in bolt: c.ell(x - 6, y - 6, 12, 12, color)
    for y, x1, x2 in ((70, 26, 86), (128, 14, 66), (186, 34, 84)):
        c.line([(x1, y), (x2, y)], color, 16); c.ell(x1 - 8, y - 8, 16, 16, color); c.ell(x2 - 8, y - 8, 16, 16, color)
    return c
def icon_jump(color=INK):
    c = icon_canvas()
    # the hoop (the course's own hurdle): a bar on two legs
    c.rect(48, 184, 160, 22, color, 11); c.rect(58, 194, 20, 46, color, 8); c.rect(178, 194, 20, 46, color, 8)
    # the hop: one fat arrow going up over it
    c.rect(106, 84, 44, 76, color, 14)
    head = [(128, 20), (46, 104), (210, 104)]
    c.poly(head, color); c.line(head + [head[0]], color, 14)
    for x, y in head: c.ell(x - 7, y - 7, 14, 14, color)
    return c
def icon_flag(color=INK):
    c = icon_canvas()
    c.rect(44, 24, 20, 212, color, 10)
    c.rect(64, 36, 156, 108, color, 12)
    for r in range(2):
        for q in range(3):
            if (r + q) % 2 == 0: c.rect(74 + q * 46, 46 + r * 46, 44, 42, WHITE, 6)
    return c
ICONS = {}
def build_icons():
    for name, fn in (("dash", icon_dash), ("jump", icon_jump), ("racing-flag", icon_flag)):
        c = fn(); c.save(f"icons/{name}.png"); ICONS[name] = c.im
    for name, fn in (("dash", icon_dash), ("jump", icon_jump)):
        fn(WHITE).save(f"icons/{name}-white.png")
    c = Cv(520, 190, bg="#3FA34A")
    c.text(12, 10, "U4 icons on their pads: 96 pt (phone), 48 pt, 24 pt legibility check", "b", 10, WHITE)
    x = 16
    for d in (96, 48, 24):
        for name, col, label in (("dash", LEMON, "DASH"), ("jump", GO, "JUMP")):
            pad(c, x, 60 + (96 - d) / 2, d, col, name, label if d >= 48 else None); x += d + 16
    pad(c, x + 10, 60, 96, PUFF, "dash", "PHEW!"); c.note(x + 10, 44, "out of puff")
    c.save("u4-icons-sheet.png")

def pad(c, x, y, d, color, icon, label=None, pressed=False, key=None):
    lip = max(2, d * .05)
    c.ell(x - 3, y - 3, d + 6, d + 6 + lip, INK)
    c.ell(x, y + (lip if pressed else 0), d, d, color)
    isz = d * (.52 if label else .6)
    c.paste(ICONS[icon], x + (d - isz) / 2, y + (d * .09 if label else (d - isz) / 2) + (lip if pressed else 0), isz, isz)
    if label: c.text(x + d / 2, y + d * .76 + (lip if pressed else 0), label, "disp", d * .145, INK, "mm")
    if key:
        w = c.tw(key, "b", 11) + 12
        c.rect(x + d - w + 4, y - 8, w, 20, INK, 6); c.text(x + d - w / 2 + 4, y + 2, key, "b", 11, WHITE, "mm")

def strip(c, x, y, w, texts=("Ready in 8 h.", "Stamp 2: 4 Stars", "3 new quests"), h=48):
    """TomorrowStrip v2: title on its own row inside the well, three equal chips under it."""
    c.panel(x, y, w, h, STRIP, 12)
    c.ell(x + 10, y + 6, 10, 10, STRIP_SOFT); c.ell(x + 13, y + 4, 9, 9, STRIP)
    c.text(x + 25, y + 11, "See you tomorrow", "disp", 12, STRIP_SOFT, "lm")
    cw = (w - 12 - 12) / 3
    for i, t in enumerate(texts):
        cx = x + 6 + i * (cw + 6)
        c.rect(cx, y + 21, cw, 22, CHIP, 11, stroke=INK, sw=1.5)
        tw = c.tw(t, "disp", 12); sx = cx + (cw - (16 + 5 + tw)) / 2
        if i == 0:
            c.ell(sx + 2, y + 25, 12, 14, "#E9E4FF"); c.rect(sx, y + 35, 16, 4, "#C98A4B", 2)
        elif i == 1: c.star(sx + 8, y + 32, 8)
        else:
            c.rect(sx + 3, y + 25, 10, 13, WHITE, 2); c.line([(sx + 5, y + 29), (sx + 11, y + 29)], CHIP, 1); c.line([(sx + 5, y + 33), (sx + 11, y + 33)], CHIP, 1)
        c.text(sx + 21, y + 32, t, "disp", 12, STARS if i == 1 else WHITE, "lm")

def stage(c, x, y, w, h, name, sub, podium=None, hop=0):
    """The pet stage shared by the picker (U3) and the results (U6): a well, a spotlight, a pedestal."""
    c.panel(x, y, w, h, WELL, 14)
    cx = x + w / 2; floor = y + h - (62 if name else 30)
    c.poly([(cx - 18, y), (cx + 18, y), (cx + w * .40, floor + 6), (cx - w * .40, floor + 6)], WHITE, a=26)
    c.ell(cx - w * .43, floor - 8, w * .86, 30, LEMON, a=46)
    pw = min(132, w * .68)
    if podium:
        c.rect(cx - pw / 2, floor - 14, pw, 30, CREAM_LIP, 8); c.rect(cx - pw / 2, floor - 14, pw, 22, CREAM, 8)
        c.text(cx, floor - 3, podium, "disp", 14, INK, "mm")
        top = floor - 14
    else:
        c.ell(cx - pw / 2, floor - 5, pw, 26, CREAM_LIP); c.ell(cx - pw / 2, floor - 11, pw, 26, CREAM)
        top = floor + 2
    c.pet(cx, top - hop, min(w * .56, (top - y) * .80))
    if name:
        c.text(cx, y + h - 32, name, "disp", 16, WHITE, "mm"); c.text(cx, y + h - 14, sub, "m", 11, SOFT, "mm")

# ------------------------------------------------------------------ U1 + U2
def u1_u2():
    c = Cv(640, 330, k=6, ss=2, bg="#59B8F2")
    c.rect(0, 150, 640, 180, "#3FA34A")
    c.text(12, 8, "U1  hint card and toasts: content 2 pt lower", "b", 11, INK); c.text(330, 8, "U2  pet tag: one row, hugs its words", "b", 11, INK)
    msg = "Tap or rub · hold E to pet"
    for i, (label, top, bot, side, dy) in enumerate((("NOW  pad 4 / 4, sides 8; reads high", 4, 4, 8, -1.5), ("NEW  pad 6 / 4, sides 12", 6, 4, 12, 0))):
        x, y = 20, 44 + i * 52; w = c.tw(msg, "m", 14) + side * 2; h = 18 + top + bot
        c.rect(x, y, w, h, SHELL, 10, a=217)
        c.text(x + w / 2, y + top + 9 + dy, msg, "m", 14, WHITE, "mm")
        c.note(x, y - 12, label)
        c.dim_v(x + w + 8, y, y + top, f"{top}"); c.dim_v(x + w + 24, y + h - bot, y + h, f"{bot}")
    for i, (label, dy) in enumerate((("NOW  toast: content centred above the timer room", 0), ("NEW  toast: disc, words, +N and chevron +2 pt", 2))):
        x, y, w, h = 20, 176 + i * 70, 236, 40
        c.rect(x - 2, y - 2, w + 4, h + 8, INK, 14); c.rect(x, y + 4, w, h, CREAM_LIP, 12); c.rect(x, y, w, h, CREAM, 12)
        c.ell(x + 8, y + 4 + dy, 24, 24, INK); c.star(x + 20, y + 16 + dy, 8)
        c.text(x + 40, y + 15 + dy, "Quest done: Chain 4", "m", 14, INK, "lm"); c.text(x + 190, y + 15 + dy, "+8", "disp", 14, INK, "lm")
        c.rect(x + 10, y + 34, w - 20, 3, CREAM_LIP, 1.5); c.rect(x + 10, y + 34, 70, 3, STARS, 1.5)
        c.note(x, y - 13, label, size=8.5)
    bx = 330
    c.note(bx, 32, "NOW  150 x 48: 64 pt empty, 3 pt under the chip")
    c.panel(bx, 48, 150, 48, SHELL, 12)
    c.text(bx + 12, 48 + 11, "Hmm Parade", "b", 14, WHITE, "lm")
    c.rect(bx + 12, 48 + 21, 74, 24, WELL, 12, stroke=HEART, sw=1.5); c.heart(bx + 27, 48 + 33.5, 7); c.text(bx + 39, 48 + 33, "Heart 1", "b", 13, WHITE, "lm")
    c.dim_h(bx + 86, bx + 150, 82, "64 dead"); c.dim_v(bx + 158, 93, 96, "3")
    ny = 150; name = "Hmm Parade"; nw = c.tw(name, "disp", 16); chipw = 6 + 14 + 4 + c.tw("Heart", "b", 12) + 5 + 18 + 2; W = 12 + nw + 10 + chipw + 10
    def chip(cx, cy, z):
        c.rect(cx, cy, chipw * z, 22 * z, WELL, 11 * z, stroke=HEART, sw=1.5 * z); c.heart(cx + 13 * z, cy + 11.5 * z, 6.5 * z)
        c.text(cx + 24 * z, cy + 11 * z, "Heart", "b", 12 * z, "#FFD3DF", "lm")
        c.ell(cx + (chipw - 20) * z, cy + 2 * z, 18 * z, 18 * z, HEART); c.text(cx + (chipw - 11) * z, cy + 11 * z, "1", "disp", 12 * z, INK, "mm")
    c.note(bx, ny - 28, f"NEW  {W:.0f} x 48 for this name: 12 | name | 10 | chip | 10")
    c.panel(bx, ny, W, 48, SHELL, 12)
    c.text(bx + 12, ny + 24, name, "disp", 16, WHITE, "lm")
    cx = bx + 12 + nw + 10; chip(cx, ny + 13, 1)
    c.dim_h(bx, bx + 12, ny + 56, "12", up=False); c.dim_h(cx - 10, cx, ny + 56, "10", up=False); c.dim_h(cx + chipw, bx + W, ny + 56, "10", up=False)
    c.dim_v(bx + W + 8, ny, ny + 13, "13"); c.dim_v(bx + W + 24, ny + 35, ny + 48, "13"); c.note(cx + chipw + 22, ny + 19, "chip 22 tall", size=8.5)
    zy = 252; c.note(bx, zy - 14, "The chip, 2x: 6 | heart 14 | 4 | stat word | 5 | level disc 18 | 2")
    chip(bx, zy, 2)
    c.note(bx + chipw * 2 + 12, zy + 6, "word: soft pink #FFD3DF\nlevel: ink on the stat colour,\nso it reads as a level badge", size=8.5)
    c.save("u1-u2-hint-toast-pet-tag.png")

# ------------------------------------------------------------------ U3 picker
def stats_rows(c, rx, y0, rw, dimmed=False):
    c.rect(rx, y0, rw, 72, TRAY, 10)
    for i, (n, col, lv) in enumerate((("Speed", SPEED, 14), ("Energy", ENERGY, 9), ("Jump", JUMP, 8))):
        y = y0 + 8 + i * 20; a = 110 if dimmed else 255
        c.ell(rx + 10, y + 1, 14, 14, col, a=a - 1); c.text(rx + 30, y + 8, n, "b", 12, WHITE, "lm", a=a - 1)
        c.rect(rx + 92, y + 4, 210, 8, WELL, 4)
        if dimmed: c.rect(rx + 92, y + 4, 105, 8, PUFF, 4, a=150)
        else:
            c.rect(rx + 92, y + 4, max(8, 210 * lv / 40), 8, col, 4); c.text(rx + rw - 10, y + 8, f"Lv {lv}", "b", 12, WHITE, "rm")
    if dimmed:
        t = "All pets equal in this race"; w = c.tw(t, "disp", 12) + 20
        c.rect(rx + rw / 2 - w / 2, y0 + 25, w, 22, CREAM, 11, stroke=INK, sw=1.5); c.text(rx + rw / 2, y0 + 36, t, "disp", 12, INK, "mm")

def u3():
    c = Cv(874, 402); c.scene(sky="#27405E", grass="#1F5A2A", dim=110); c.roblox()
    X, Y, W, H = 127, 77, 620, 276
    c.panel(X, Y, W, H, SHELL, 22, 3)
    stage(c, X + 14, Y + 14, 196, 248, "Hmm Parade", "Sprout · Dash level 31")
    rx, rw = X + 224, 382
    c.text(rx, Y + 28, "Garden Dash", "disp", 24, WHITE, "lm"); c.close(X + W - 14 - 32, Y + 12)
    c.text(rx, Y + 55, "Your pet runs. Jump the hoops. Hold Dash to zoom!", "r", 13, SOFT, "lm")
    stats_rows(c, rx, Y + 72, rw)
    tiles = (("Just for Fun", "All pets equal", "cream"), ("Stats On", "Your levels count", "go"), ("Time Trial", "Solo. Beat the clock", "cream"))
    for i, (n, sub, kind) in enumerate(tiles): c.button(rx + i * 130, Y + 152, 122, 76, n, kind, 15, sub=sub)
    c.star(rx + 7, Y + 249, 7); c.text(rx + 20, Y + 249, "Stars races today: 2 of 5", "m", 12, SOFT, "lm")
    c.text(rx + rw, Y + 249, "Best 29.5 s", "b", 12, SOFT, "rm")
    c.tag(1, X + 14, Y + 14); c.tag(2, rx - 6, Y + 72); c.tag(3, rx - 6, Y + 152); c.tag(4, rx - 6, Y + 249)
    c.dim_h(X, X + W, Y - 8, "card 620 x 276, centre (W/2, H/2 + 14)", up=False) if False else c.note(X, Y - 20, "card 620 x 276, centre (W/2, H/2 + 14)"); c.dim_h(X + 14, X + 210, Y + H + 8, "stage 196 x 248", up=False)
    c.dim_h(rx, rx + 122, Y + H + 8, "tile 122 x 76, gap 8", up=False); c.dim_v(X + W + 8, Y + 72, Y + 144, "72"); c.dim_v(X + W + 8, Y + 152, Y + 228, "76")
    c.note(280, 6, "1 stage: the active pet runs in place on a pedestal under a spotlight (ViewportFrame + WorldModel, the Dash run pose)")
    c.note(280, 19, "2 stats: Speed / Energy / Jump, lit for Stats On; dimmed with an 'All pets equal' pill for the other two")
    c.note(280, 32, "3 one tap starts that race; the last one played is green and focused      4 today's Stars races and the best time")
    c.save("u3-dash-mode-picker.png")
    c = Cv(410, 100, bg=SHELL); stats_rows(c, 14, 14, 382, dimmed=True); c.save("u3-stats-equal-state.png")

# ------------------------------------------------------------------ U4 HUD + U5 line-up
def u4_u5():
    c = Cv(874, 402); c.scene(); c.roblox()
    for x in (176, 672): c.rect(x, 20, 26, 310, "#FF5A6B", 4); c.rect(x, 20, 26, 130, WHITE, 4)
    names = ["Noodle", "Hmm Parade", "Biscuit", "Mochi", "Pip", "Dumpling", "Sprout", "Bean"]
    for i in range(8):
        x = 437 + (i - 3.5) * 50; c.pet(x, 318, 46)
    for i in range(8):
        x = 437 + (i - 3.5) * 50; head = 318 - 46 * 1.2; high = i % 2 == 1; ty = head - (62 if high else 32); mine = i == 2
        w = min(104, c.tw(names[i], "disp", 13) + 18)
        c.line([(x, ty + 22), (x, head - 3)], INK, 2)
        c.rect(x - w / 2 - 2, ty - 2, w + 4, 26, INK, 13); c.rect(x - w / 2, ty, w, 22, LEMON if mine else CREAM, 11)
        c.text(x, ty + 11, names[i], "disp", 13, INK, "mm")
    c.text(437, 112, "3", "disp", 72, WHITE, "mm", stroke=INK, sw=4)
    c.rect(247, 14, 380, 20, INK, 10, a=166)
    for d in (0.08, 0.14, 0.2, 0.67, 0.8, 0.92): c.rect(247 + 380 * d, 18, 2, 12, WHITE, 1, a=90)
    c.rect(603, 15, 20, 18, CREAM, 5); c.paste(ICONS["racing-flag"], 605, 16, 16, 16)
    for i in range(7): c.ell(247 + 6 + i * 1.5, 18, 12, 12, CREAM, stroke=INK, sw=2)
    c.ell(247 + 4, 15, 18, 18, LEMON, stroke=INK, sw=2)
    c.rect(185, 12, 54, 24, INK, 12, a=166); c.text(212, 24, "1st", "disp", 15, WHITE, "mm")
    c.close(814, 4, 44)
    c.rect(16, 262, 96, 14, INK, 7); c.rect(18, 264, 92, 10, LEMON, 5)
    pad(c, 16, 290, 96, LEMON, "dash", "DASH"); pad(c, 762, 290, 96, GO, "jump", "JUMP")
    c.tag(1, 16, 290); c.tag(2, 762, 290); c.tag(3, 236, 216); c.tag(4, 400, 96); c.tag(5, 185, 12)
    c.dim_v(120, 290, 391, "96 + 5 lip")
    c.note(150, 352, "1 2 pads: icon 50 pt + word 14 pt, ink on lemon / green, 3 pt ink ring, 5 pt lip")
    c.note(150, 365, "3 line-up: one wide row, every name shown on two tiers with a stem to its pet; yours is lemon")
    c.note(150, 378, "4 countdown at 26% of the height, clear of pets and tags    5 place pill left of the strip, flag at its end")
    c.save("u4-u5-dash-hud-and-lineup.png")
    # plan view
    c = Cv(520, 300, bg="#3FA34A")
    c.text(12, 8, "U5 start grid from above (22 px = 1 stud across; the run up the page is squeezed). Race direction: up.", "b", 9.5, WHITE)
    s, ox, oy = 22, 280, 206
    c.rect(ox - 2 * s, 24, 4 * s, 276, "#B98B5E", 0, a=120)
    c.line([(ox - 6.4 * s, oy), (ox + 6.4 * s, oy)], WHITE, 2)
    for side in (-1, 1): c.rect(ox + side * 6.4 * s - 5, oy - 8, 10, 16, "#FF5A6B", 3)
    hy = oy - 14 * s * .5
    c.line([(ox - 2.2 * s, hy), (ox + 2.2 * s, hy)], "#FF8FC0", 4); c.note(ox + 2.5 * s, hy - 5, "first hoop: 14 studs on, 4.4 wide")
    for i in range(8):
        pts = []
        for k in range(25):
            d = k / 24 * 12.5; m = min(1, max(0, (d - 3) / 8)); m = m * m * (3 - 2 * m)
            pts.append((ox + (i - 3.5) * (1.5 + (0.5 - 1.5) * m) * s, oy + 4 + s - d * s * .5))
        c.line(pts, WHITE, 1, a=140)
    for i in range(8):
        x, y = ox + (i - 3.5) * 1.5 * s, oy + 4 + s
        c.ell(x - .6 * s, y - .6 * s, 1.2 * s, 1.2 * s, LEMON if i == 2 else WHITE, stroke=INK, sw=1.5)
        c.text(x, y, str(i + 1), "disp", 11, INK, "mm")
    c.dim_h(ox - 3.5 * 1.5 * s, ox + 3.5 * 1.5 * s, oy + 4 + 2.2 * s, "8 racers: 10.5 studs between the outer centres (now 3.5)", up=False)
    c.dim_h(ox - 3.5 * 1.5 * s, ox - 2.5 * 1.5 * s, oy - 6, "1.5")
    c.note(8, 60, "from 3 to 11 studs the lanes\nfunnel in: step 1.5 -> 0.5", size=9)
    c.note(8, 150, "arch posts out to\n+/- 6.4 studs", size=9)
    c.note(8, 250, "fewer racers stay centred:\nslot = seat order - (n+1)/2", size=9)
    c.save("u5-start-grid-plan.png")

# ------------------------------------------------------------------ U6 results
def u6():
    c = Cv(874, 402); c.scene(dim=120); c.roblox()
    X, Y, W, H = 127, 59, 620, 312
    c.panel(X, Y, W, H, SHELL, 22, 3)
    stage(c, X + 14, Y + 14, 196, 172, None, None, podium=" ", hop=10)
    for i in range(22):
        px = X + 24 + (i * 53) % 176; py = Y + 22 + (i * 37) % 90
        c.rect(px, py, 3, 8, (STARS, HEART, ENERGY, JUMP, WHITE)[i % 5], 1)
    c.ell(X + 22, Y + 22, 44, 44, INK); c.ell(X + 24, Y + 24, 40, 40, STRIP_SOFT); c.text(X + 44, Y + 44, "2nd", "disp", 16, INK, "mm")
    rx, rw = X + 224, 382
    c.text(rx + 2, Y + 33, "You finished 2nd!", "disp", 28, "#B8791A", "lm"); c.text(rx, Y + 31, "You finished 2nd!", "disp", 28, WHITE, "lm")
    c.rect(rx, Y + 54, rw, 40, TRAY, 10)
    c.text(rx + 12, Y + 74, "TIME", "b", 11, SOFT, "lm"); c.text(rx + 48, Y + 74, "29.5 s", "disp", 22, WHITE, "lm")
    c.text(rx + 166, Y + 74, "BEST", "b", 11, SOFT, "lm"); c.text(rx + 202, Y + 74, "29.5 s", "b", 16, WHITE, "lm")
    c.rect(rx + rw - 82, Y + 63, 72, 22, STARS, 11, stroke=INK, sw=1.5); c.text(rx + rw - 46, Y + 74, "NEW BEST", "disp", 11, INK, "mm")
    c.rect(rx, Y + 100, rw, 40, TRAY, 10)
    c.star(rx + 24, Y + 120, 12); c.text(rx + 44, Y + 120, "+4 Stars", "disp", 20, STARS, "lm")
    for i in range(5): c.ell(rx + 226 + i * 14, Y + 115, 10, 10, STARS if i < 2 else WELL, stroke=INK, sw=1)
    c.text(rx + rw - 10, Y + 120, "2 of 5 today", "m", 12, SOFT, "rm")
    rows = (("1", "Noodle", "28.8"), ("2", "Hmm Parade", "29.5"), ("3", "Biscuit", "31.0"), ("4", "Mochi", "33.4"))
    cw = (rw - 18) / 4
    for i, (p, n, t) in enumerate(rows):
        x = rx + i * (cw + 6); mine = i == 1
        c.rect(x, Y + 146, cw, 40, LEMON if mine else WELL, 10, stroke=INK, sw=1.5)
        col = INK if mine else WHITE
        c.ell(x + 6, Y + 152, 16, 16, (STARS, STRIP_SOFT, POWER, CREAM)[i]); c.text(x + 14, Y + 160, p, "disp", 11, INK, "mm")
        nm = n
        while c.tw(nm, "b", 11) > cw - 32: nm = nm[:-2] + "…"
        c.text(x + 27, Y + 160, nm, "b", 11, col, "lm"); c.text(x + 27, Y + 175, t + " s", "m", 11, INK_SOFT if mine else SOFT, "lm")
    strip(c, X + 14, Y + 194, 592)
    c.button(X + 14, Y + 250, 388, 48, "Race again", "go", 17); c.button(X + 410, Y + 250, 196, 48, "Done", "cream", 15)
    for n, (x, y) in enumerate(((X + 14, Y + 14), (rx - 6, Y + 33), (rx - 6, Y + 74), (rx - 6, Y + 120), (rx - 6, Y + 166), (X + 14, Y + 194), (X + 14, Y + 250)), 1): c.tag(n, x, y)
    c.dim_h(X + 140, X + W, Y - 8, "card 620 x 312 (256 with no strip), centre (W/2, H/2 + 14)")
    c.dim_h(X + 14, X + 402, Y + H + 8, "Race again 388", up=False); c.dim_h(X + 410, X + 606, Y + H + 8, "Done 196", up=False)
    c.dim_v(X + W + 8, Y + 194, Y + 242, "strip 48")
    c.note(8, 366, "1 pet hops on a podium step,\n  medal top left\n2 headline lands", size=8.5)
    c.note(752, 110, "3 time counts up\n4 Stars count up,\n  pips fill\n5 the field,\n  you in lemon", size=8.5)
    c.note(752, 262, "6 See you tomorrow\n7 one green next step;\n  Done is quiet; no X", size=8.5)
    c.save("u6-dash-results.png")

# ------------------------------------------------------------------ U7 deck results
def u7():
    c = Cv(874, 402, bg="#0B1430")
    c.rect(70, 72, 734, 316, "#8FD16A", 60, stroke="#C9D2D8", sw=5)   # the deck shell (existing art, sketched)
    c.rect(209, 88, 456, 290, "#0E1A10", 16)
    c.ell(92, 190, 92, 92, "#1B3A1C"); c.ell(700, 164, 78, 78, "#B6E86A", stroke="#3D6B2A", sw=3); c.text(739, 203, "A", "disp", 26, INK, "mm")
    c.ell(681, 250, 50, 50, "#20203A"); c.text(706, 275, "B", "disp", 16, WHITE, "mm")
    lx, mx, rx, ty, hh = 222, 354, 523, 100, 207
    lw, mw, rw = 125, 162, 126
    cx = mx + mw / 2
    c.rect(mx, ty, mw, hh, TRAY, 10)
    for a in range(0, 360, 30):
        c.poly([(cx, ty + 106), (cx + math.cos(math.radians(a - 5)) * 76, ty + 106 + math.sin(math.radians(a - 5)) * 76),
                (cx + math.cos(math.radians(a + 5)) * 76, ty + 106 + math.sin(math.radians(a + 5)) * 76)], STARS, a=40)
    c.rect(mx, ty, mw, hh, None, 10, stroke="#2E6B38", sw=1)
    for x, w in ((lx, lw), (rx, rw)): c.rect(x, ty, w, hh, TRAY, 10, stroke="#2E6B38", sw=1)
    c.text(lx + 10, ty + 15, "PAYOUT", "b", 11, SOFT, "lm")
    for i, (n, v) in enumerate((("Good effort", "1"), ("Supporter", "+2"))):
        c.text(lx + 10, ty + 38 + i * 22, n, "m", 13, WHITE, "lm"); c.text(lx + lw - 10, ty + 38 + i * 22, v, "b", 13, WHITE, "rm")
    c.rect(lx + 10, ty + 72, lw - 20, 1, WHITE, a=50)
    c.text(lx + 10, ty + 86, "Total", "b", 15, STARS, "lm"); c.text(lx + lw - 10, ty + 86, "3", "disp", 16, STARS, "rm"); c.star(lx + lw - 30, ty + 86, 6)
    for i, (n, v, col, up) in enumerate((("Heart", "+2", HEART, "Lv 2"), ("Power", "+64", POWER, "Lv 4"), ("Energy", "+12", ENERGY, None))):
        y = ty + 110 + i * 18
        c.ell(lx + 10, y - 5, 10, 10, col); c.text(lx + 25, y, n, "m", 12, col, "lm"); c.text(lx + 25 + c.tw(n, "m", 12) + 4, y, v, "b", 12, WHITE, "lm")
        if up:
            w = c.tw(up, "disp", 10) + 10; c.rect(lx + lw - 8 - w, y - 7, w, 14, col, 7); c.text(lx + lw - 8 - w / 2, y, up, "disp", 10, INK, "mm")
    c.rect(lx + 8, ty + hh - 36, 74, 28, CREAM, 14, stroke=INK, sw=2); c.ell(lx + 10, ty + hh - 34, 24, 24, INK); c.star(lx + 22, ty + hh - 22, 8)
    c.text(lx + 40, ty + hh - 22, "555", "disp", 15, INK, "lm")
    c.text(cx + 1.5, ty + 27.5, "SO CLOSE!", "disp", 24, "#B8791A", "mm"); c.text(cx, ty + 26, "SO CLOSE!", "disp", 24, WHITE, "mm")
    c.text(cx, ty + 46, "Bank pair", "m", 12, SOFT, "mm")
    c.star(cx, ty + 106, 40)
    c.text(cx - 8, ty + 167, "+3", "disp", 26, STARS, "mm"); c.star(cx + 22, ty + 166, 10)
    c.text(cx, ty + 192, "Tucked into your wallet", "m", 11, SOFT, "mm")
    c.text(rx + 10, ty + 14, "GOALS", "b", 11, SOFT, "lm"); c.text(rx + rw - 10, ty + 14, "0/2", "b", 11, SOFT, "rm")
    for i, n in enumerate(("Chain left", "Chain right")):
        y = ty + 34 + i * 22
        c.ell(rx + 10, y - 6, 12, 12, None, stroke=SOFT, sw=1.5); c.text(rx + 28, y, n, "m", 12, WHITE, "lm", a=200)
    ax, aw = rx + 6, rw - 12; ay = ty + hh - 6 - 128
    c.button(ax, ay, aw, 44, "Replay", "go", 15)
    c.button(ax, ay + 48, aw, 36, "Medium", "cream", 13, lip=3, r=10)
    c.text(ax + 12, ay + 48 + 15, "‹", "b", 18, INK_SOFT, "mm"); c.text(ax + aw - 12, ay + 48 + 15, "›", "b", 18, INK_SOFT, "mm")
    hw = (aw - 4) / 2
    c.button(ax, ay + 88, hw, 40, "Hatch", "cream", 13, lip=3, r=10); c.button(ax + hw + 4, ay + 88, hw, 40, "Leave", "cream", 13, lip=3, r=10)
    strip(c, lx, ty + hh + 6, rx + rw - lx)
    for n, (x, y) in enumerate(((lx, ty), (mx, ty), (rx, ty), (rx, ay), (lx, ty + hh + 6)), 1): c.tag(n, x, y)
    c.dim_v(rx + rw + 6, ay, ay + 128, "128 (was 188)"); c.dim_v(lx - 6, ty, ty + hh, "panes: h - 54", left=True)
    c.note(8, 8, "U7 Pocket Deck results (in place), 874 x 402 phone.  1 payout: rows, total, stat gains with level-up pills, wallet   2 the Star keeps the middle", size=8.5)
    c.note(8, 20, "3 goals   4 actions: Replay 44, difficulty stepper 36, Hatch | Leave 40   5 See you tomorrow: the full LCD width x 48, whole words", size=8.5)
    c.save("u7-deck-results.png")

# ------------------------------------------------------------------ G4 racing tag + strip
def g4():
    c = Cv(420, 210, k=6, ss=2); c.scene(horizon=.5)
    c.text(10, 8, "G4  what an onlooker sees over a racing pet", "b", 10, INK)
    for x, sz in ((110, 90), (330, 46)):
        c.pet(x, 186, sz); ty = 186 - sz * 1.22 - 26
        w = 7 + 14 + 4 + c.tw("Racing", "disp", 12) + 9
        c.rect(x - w / 2 - 2, ty - 2, w + 4, 24, INK, 12); c.rect(x - w / 2, ty, w, 20, CREAM, 10)
        c.paste(ICONS["racing-flag"], x - w / 2 + 7, ty + 3, 14, 14); c.text(x - w / 2 + 25, ty + 10, "Racing", "disp", 12, INK, "lm")
    c.dim_v(160, 186 - 90 * 1.22 - 26, 186 - 90 * 1.22 - 6, "20")
    c.note(200, 40, "pill 20 tall: 7 | flag 14 | 4 | word 12 | 9\nink on cream, 2 pt ink ring\nthe same size near or far;\ngone past 60 studs", size=8.5)
    c.save("g4-racing-tag.png")
    c = Cv(640, 150, k=6, ss=2, bg=SHELL)
    c.note(10, 6, "TomorrowStrip v2 (U6, U7). Top: 592 wide. Bottom: under 400 wide, the short values (under 240: no strip)")
    strip(c, 14, 24, 592); strip(c, 14, 88, 300, texts=("8 h", "4", "3"))
    c.dim_v(616, 24, 72, "48"); c.dim_v(322, 88 + 21, 88 + 43, "chips 22"); c.dim_v(350, 88, 88 + 21, "title row 21")
    c.save("tomorrow-strip-v2.png")

if __name__ == "__main__":
    build_icons(); u1_u2(); u3(); u4_u5(); u6(); u7(); g4()
