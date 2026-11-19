"""V2 UI retro restyle mockups (2026-11-19, Fable as Astra). Proposal drawings only: nothing is built.

Hand-drawn with PIL over real Studio captures. No generated art. Every rect is measured from the
capture it is drawn over, so nothing moves: only the surface changes ("Toy Shell" direction).
3D content (pets, eggs, jellies, the Star) is cut out of the capture and put back in the same place.

Run from the repo root:  python artifacts/v2-ui-restyle-2026-11-19/build_mockups.py
"""
import glob, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
R, OUT = 4, 2                       # render scale, output scale
RBX = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")


def _find(name, fallback):
    hits = sorted(glob.glob(os.path.join(RBX, name)))
    return hits[-1] if hits else fallback


FILES = {  # the game's real faces (they ship with Roblox); Nunito only if Roblox is not installed
    "disp": _find("FredokaOne-Regular.ttf", "C:/Windows/Fonts/Nunito-Black.ttf"),
    "b": _find("BuilderSans-Bold.otf", "C:/Windows/Fonts/Nunito-Bold.ttf"),
    "xb": _find("BuilderSans-ExtraBold.otf", "C:/Windows/Fonts/Nunito-ExtraBold.ttf"),
    "m": _find("BuilderSans-Medium.otf", "C:/Windows/Fonts/Nunito-SemiBold.ttf"),
    "ext": _find("BuilderExtended-Bold.otf", "C:/Windows/Fonts/Nunito-Black.ttf"),
    "mono": "C:/Windows/Fonts/RobotoMono-Bold.ttf",
}
_fc = {}
def font(key, size, scale=R):
    k = (key, round(size * scale))
    if k not in _fc: _fc[k] = ImageFont.truetype(FILES[key], k[1])
    return _fc[k]

# ---------------- tokens (the proposed Kit.Toy table) ----------------
INK, INK_SOFT = "#15143A", "#4A4972"
CREAM, CREAM_LIP, WHITE = "#FFF4DC", "#D6C196", "#FFFFFF"
SHELL, SHELL_HI, SHELL_LIP, TRAY = "#2E55E6", "#7C9BFF", "#1A2F9C", "#1D36A6"
WELL, WELL_DOT = "#10133A", "#2A2F6B"
ON_SHELL, ON_SHELL_SOFT = "#FFFFFF", "#DCE5FF"
GO, GO_LIP = "#43DB5F", "#1C8F3C"
LEMON, LEMON_LIP = "#FFE14D", "#D9A31C"
TOMATO, TOMATO_LIP, TOMATO_TEXT = "#FF5A4D", "#B92E2A", "#B3261E"
SKY, ORANGE, PINK, GRAPE, TEAL, FOG = "#7FD4FF", "#FF9838", "#FF8FC0", "#A98BFF", "#3FD9B4", "#C9CCE0"
STARS = "#FFC14D"                    # unchanged, Stars only
DISABLED, DISABLED_LIP, DISABLED_TEXT = "#B9B6C9", "#8C89A3", "#5A5878"
STAT = [("Heart", "#FF86A8", "wunjo"), ("Power", "#FF9D4D", "uruz"), ("Energy", "#6CCBFF", "dagaz"),
        ("Jump", "#B9EE5A", "ehwaz"), ("Speed", "#8FA8FF", "raidho"), ("Smarts", "#E58CFF", "ansuz")]


def rgb(c):
    if not isinstance(c, str): return tuple(c)
    c = c.lstrip("#"); return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
def mix(a, b, t):
    a, b = rgb(a), rgb(b); return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
def lum(c):
    v = [x / 255 for x in rgb(c)]
    v = [x / 12.92 if x <= .03928 else ((x + .055) / 1.055) ** 2.4 for x in v]
    return .2126 * v[0] + .7152 * v[1] + .0722 * v[2]
def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + .05) / (lb + .05)
def S(v): return int(round(v * R))


class Canvas:
    def __init__(self, w, h, backdrop=None, fill="#101018"):
        self.w, self.h = w, h
        self.im = backdrop.convert("RGB").resize((S(w), S(h)), Image.LANCZOS) if backdrop else Image.new("RGB", (S(w), S(h)), rgb(fill))
        self.d = ImageDraw.Draw(self.im)

    def _redraw(self): self.d = ImageDraw.Draw(self.im)
    def rr(self, box, r, fill=None, outline=None, width=1):
        x0, y0, x1, y1 = box
        r = max(0, min(r, (x1 - x0) / 2, (y1 - y0) / 2))
        self.d.rounded_rectangle((S(x0), S(y0), S(x1) - 1, S(y1) - 1), S(r), fill=rgb(fill) if fill else None,
                                 outline=rgb(outline) if outline else None, width=max(1, S(width)))
    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse(tuple(S(v) for v in box), fill=rgb(fill) if fill else None, outline=rgb(outline) if outline else None, width=max(1, S(width)))
    def poly(self, pts, fill): self.d.polygon([(S(x), S(y)) for x, y in pts], fill=rgb(fill))
    def line(self, pts, fill, width=1, round_=True):
        self.d.line([(S(x), S(y)) for x, y in pts], fill=rgb(fill), width=max(1, S(width)), joint="curve")
        if round_:
            for x, y in pts: self.d.ellipse((S(x - width / 2), S(y - width / 2), S(x + width / 2), S(y + width / 2)), fill=rgb(fill))
    def text(self, xy, s, f, fill=INK, anchor="lm", stroke=0, stroke_fill=INK):
        self.d.text((S(xy[0]), S(xy[1])), s, font=f, fill=rgb(fill), anchor=anchor, stroke_width=S(stroke), stroke_fill=rgb(stroke_fill))
    def tw(self, s, f): return self.d.textlength(s, font=f) / R

    # ---- the frame language ----
    def toy(self, box, r, face=CREAM, lip_col=CREAM_LIP, lip=3, o=2, glint=True, pressed=False):
        """Raised toy piece: ink outline (inside the rect), face, bottom lip below the rect, top glint."""
        x0, y0, x1, y1 = box
        if pressed:
            self.rr((x0, y0 + lip, x1, y1 + lip), r, fill=INK)
            self.rr((x0 + o, y0 + lip + o, x1 - o, y1 + lip - o), r - o, fill=mix(face, INK, .10))
            return
        self.rr((x0, y0, x1, y1 + lip), r, fill=INK)
        self.rr((x0 + o, y0 + o, x1 - o, y1 + lip - o), r - o, fill=lip_col)
        self.rr((x0 + o, y0 + o, x1 - o, y1 - o), r - o, fill=face)
        if glint and (y1 - y0) >= 20:
            g = mix(face, WHITE, .6); inset = max(r * .7, 6)
            self.line([(x0 + inset, y0 + o + 2.6), (x1 - inset - 9, y0 + o + 2.6)], g, 1.6)
            self.line([(x1 - inset - 4, y0 + o + 2.6), (x1 - inset - 3, y0 + o + 2.6)], g, 1.6)

    def tray(self, box, r, fill=TRAY, o=2, depth=3):
        """Inset information pane: no lip, a shadow under its top edge."""
        x0, y0, x1, y1 = box
        self.rr(box, r, fill=INK)
        self.rr((x0 + o, y0 + o, x1 - o, y1 - o), r - o, fill=mix(fill, INK, .45))
        self.rr((x0 + o, y0 + o + depth, x1 - o, y1 - o), r - o, fill=fill)

    def well(self, box, r, o=2, dots=True, fill=WELL):
        """Little screen: the LCD window that holds 3D previews."""
        x0, y0, x1, y1 = box
        self.rr(box, r, fill=INK)
        self.rr((x0 + o, y0 + o, x1 - o, y1 - o), r - o, fill=fill)
        if dots:
            y = y0 + o + 5
            while y < y1 - o - 3:
                x = x0 + o + 5
                while x < x1 - o - 3:
                    self.ellipse((x - .7, y - .7, x + .7, y + .7), fill=WELL_DOT); x += 6
                y += 6
        self.line([(x0 + r * .8, y1 - o - 2.2), (x1 - r * .8, y1 - o - 2.2)], mix(fill, WHITE, .16), 1.2)

    def round_key(self, cx, cy, rad, face=CREAM, lip_col=CREAM_LIP, lip=3, o=2):
        self.ellipse((cx - rad, cy - rad, cx + rad, cy + rad + lip), fill=INK)
        self.ellipse((cx - rad + o, cy - rad + o, cx + rad - o, cy + rad + lip - o), fill=lip_col)
        self.ellipse((cx - rad + o, cy - rad + o, cx + rad - o, cy + rad - o), fill=face)
        g = mix(face, WHITE, .65)
        self.d.arc((S(cx - rad + o + 3), S(cy - rad + o + 3), S(cx + rad - o - 3), S(cy + rad - o - 3)), 205, 255, fill=g, width=S(1.6))

    def focus(self, box, r, lip=3, pad=3.5):
        x0, y0, x1, y1 = box
        self.rr((x0 - pad - 1.5, y0 - pad - 1.5, x1 + pad + 1.5, y1 + lip + pad + 1.5), r + pad + 1.5, outline=INK, width=1.5)
        self.rr((x0 - pad, y0 - pad, x1 + pad, y1 + lip + pad), r + pad, outline=WHITE, width=2.6)

    def plate(self, x, cy, s, f, face, padx=9, h=26, lip=2, star_=True):
        """Header plate: the title keeps its position, a coloured label plate goes behind it."""
        w = self.tw(s, f)
        box = (x - padx, cy - h / 2, x + w + padx + (14 if star_ else 0), cy + h / 2)
        self.toy(box, 9, face, mix(face, INK, .38), lip=lip, o=2)
        self.text((x, cy), s, f, INK)
        if star_: sparkle(self, x + w + 9, cy, 5, INK)
        return box

    def tab_label(self, x, y, s, face, size=8.6):
        f = font("xb", size); w = self.tw(s, f)
        self.rr((x, y, x + w + 10, y + 13), 4, fill=INK)
        self.rr((x + 1.2, y + 1.2, x + w + 8.8, y + 11.8), 3, fill=face)
        self.text((x + 5, y + 6.6), s, f, INK)
        return x + w + 10

    def chip(self, box, s, fill=INK, text=CREAM, f=None):
        x0, y0, x1, y1 = box; f = f or font("xb", 9)
        self.rr(box, (y1 - y0) / 2, fill=INK)
        if fill != INK: self.rr((x0 + 1.6, y0 + 1.6, x1 - 1.6, y1 - 1.6), (y1 - y0) / 2, fill=fill)
        self.text(((x0 + x1) / 2, (y0 + y1) / 2 + .2), s, f, text, "mm")

    def sticker(self, cx, cy, w, h, s, face=ORANGE, tilt=6, f=None, edge=CREAM):
        f = f or font("xb", 9.5)
        pad = 12
        t = Image.new("RGBA", (S(w + pad * 2), S(h + pad * 2)), (0, 0, 0, 0)); d = ImageDraw.Draw(t)
        b = (S(pad), S(pad), S(pad + w), S(pad + h))
        d.rounded_rectangle((b[0], b[1] + S(2.4), b[2], b[3] + S(2.4)), S(h / 2), fill=rgb(INK) + (150,))
        d.rounded_rectangle(b, S(h / 2), fill=rgb(INK) + (255,))
        d.rounded_rectangle((b[0] + S(1.6), b[1] + S(1.6), b[2] - S(1.6), b[3] - S(1.6)), S(h / 2), fill=rgb(edge) + (255,))
        d.rounded_rectangle((b[0] + S(3.4), b[1] + S(3.4), b[2] - S(3.4), b[3] - S(3.4)), S(h / 2), fill=rgb(face) + (255,))
        d.text((S(pad + w / 2), S(pad + h / 2)), s, font=f, fill=rgb(INK) + (255,), anchor="mm")
        t = t.rotate(tilt, Image.BICUBIC)
        self.im.paste(t, (S(cx) - t.width // 2, S(cy) - t.height // 2), t); self._redraw()

    def checker(self, box, r, a, b, size=12, fade=(1.0, .35), o=3):
        """Two-tone checker inside a rounded rect, fading down so text areas stay calm."""
        x0, y0, x1, y1 = (S(v) for v in box)
        w, h = x1 - x0, y1 - y0
        yy, xx = np.mgrid[0:h, 0:w]
        m = (((xx // S(size)) + (yy // S(size))) % 2).astype(np.float32)
        m *= np.linspace(fade[0], fade[1], h, dtype=np.float32)[:, None]
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((S(o), S(o), w - S(o) - 1, h - S(o) - 1), S(r - o), fill=255)
        m = (m * np.asarray(mask, dtype=np.float32)).astype(np.uint8)
        self.im.paste(Image.new("RGB", (w, h), rgb(b)), (x0, y0), Image.fromarray(m, "L")); self._redraw()

    def sunburst(self, box, r, cx, cy, a, b, rays=12, o=2):
        x0, y0, x1, y1 = (S(v) for v in box)
        w, h = x1 - x0, y1 - y0
        t = Image.new("RGB", (w, h), rgb(a)); d = ImageDraw.Draw(t)
        px, py, L = S(cx) - x0, S(cy) - y0, (w + h) * 2
        for i in range(rays):
            a0 = (i * 2) * math.pi / rays - math.pi / 2 - math.pi / rays / 2; a1 = a0 + math.pi / rays
            d.polygon([(px, py), (px + math.cos(a0) * L, py + math.sin(a0) * L), (px + math.cos(a1) * L, py + math.sin(a1) * L)], fill=rgb(b))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((S(o), S(o), w - S(o) - 1, h - S(o) - 1), S(r - o), fill=255)
        self.im.paste(t, (x0, y0), mask); self._redraw()

    def paste_rgba(self, t, x, y):
        self.im.paste(t, (S(x), S(y)), t); self._redraw()

    def paste_round(self, src, box, r):
        """Raw crop of the capture (thumbnails with their own background), rounded."""
        x0, y0, x1, y1 = box
        t = src.crop(box).resize((S(x1 - x0), S(y1 - y0)), Image.LANCZOS)
        mask = Image.new("L", t.size, 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, t.width - 1, t.height - 1), S(r), fill=255)
        self.im.paste(t, (S(x0), S(y0)), mask); self._redraw()

    def clip_begin(self): self._saved = self.im.copy()
    def clip_end(self, box):
        b = tuple(S(v) for v in box); new = self.im.crop(b)
        self.im = self._saved; self.im.paste(new, b[:2]); self._redraw()

    def out(self): return self.im.resize((self.w * OUT, self.h * OUT), Image.LANCZOS)


# ---------------- cut 3D content out of a capture ----------------
def cutout(src, box, tol=26, pixel=False, grow=0, shrink=0):
    """Flood the background away from the crop's border; what is left is the pet, egg or jelly."""
    crop = src.crop(box).convert("RGB"); w, h = crop.size
    a = np.asarray(crop).astype(np.int32)
    seeds = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    bg = np.zeros((h, w), bool); seen = np.zeros((h, w), bool); stack = []
    ref = np.median(np.array([a[y, x] for x, y in seeds]), axis=0)
    for x, y in seeds:
        if np.abs(a[y, x] - ref).sum() <= tol * 2: stack.append((x, y)); seen[y, x] = True
    while stack:
        x, y = stack.pop(); bg[y, x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny, nx]:
                seen[ny, nx] = True
                if np.abs(a[ny, nx] - ref).sum() <= tol * 2 or np.abs(a[ny, nx] - a[y, x]).sum() <= 10: stack.append((nx, ny))
    mask = Image.fromarray((~bg * 255).astype(np.uint8), "L")
    if grow: mask = mask.filter(ImageFilter.MaxFilter(grow))
    if shrink: mask = mask.filter(ImageFilter.MinFilter(shrink))
    mode = Image.NEAREST if pixel else Image.LANCZOS
    big = crop.resize((w * R, h * R), mode).convert("RGBA")
    m = mask.resize((w * R, h * R), mode)
    if not pixel: m = m.filter(ImageFilter.GaussianBlur(R * .45)).point(lambda v: max(0, min(255, int((v - 96) * 2.4))))
    big.putalpha(m); return big


def key_yellow(src, box):
    """The 3D Star: keep saturated yellow, drop the amber rays and the dark panel."""
    crop = src.crop(box).convert("RGB"); w, h = crop.size
    a = np.asarray(crop).astype(np.int32); r_, g_, b_ = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip((r_ - 185) * 6, 0, 255) * (g_ > 130) * ((r_ - b_) > 95)
    mask = Image.fromarray(m.astype(np.uint8), "L").filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    big = crop.resize((w * R, h * R), Image.LANCZOS).convert("RGBA")
    big.putalpha(mask.resize((w * R, h * R), Image.LANCZOS).filter(ImageFilter.GaussianBlur(R * .5)).point(lambda v: max(0, min(255, int((v - 90) * 2.6)))))
    return big


# ---------------- small drawn parts ----------------
def burst(c, cx, cy, r, fill, points=5, inner=.46, rot=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        a = rot + i * math.pi / points; rad = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    c.poly(pts, fill)
def sparkle(c, cx, cy, r, fill): burst(c, cx, cy, r, fill, points=4, inner=.3)
def star(c, cx, cy, r, face=True):
    burst(c, cx, cy, r + 1.8, INK, inner=.56); burst(c, cx, cy, r, STARS, inner=.5)
    if face and r >= 7:
        for dx in (-r * .22, r * .22): c.ellipse((cx + dx - .9, cy - .2, cx + dx + .9, cy + 2.4), fill="#3B2608")

def arrow_left(c, cx, cy, s, fill=INK, w=2.4):
    c.line([(cx + s, cy), (cx - s, cy)], fill, w); c.line([(cx - s * .2, cy - s * .75), (cx - s, cy), (cx - s * .2, cy + s * .75)], fill, w)
def chevron(c, cx, cy, s, fill=INK, w=1.8):
    c.line([(cx - s * .45, cy - s), (cx + s * .5, cy), (cx - s * .45, cy + s)], fill, w)
def check(c, cx, cy, s, fill, w=2.2):
    c.line([(cx - s, cy), (cx - s * .3, cy + s * .7), (cx + s, cy - s * .8)], fill, w)
def ball(c, cx, cy, r, fill):
    c.ellipse((cx - r - 1.5, cy - r - 1.5, cx + r + 1.5, cy + r + 1.5), fill=INK); c.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)
    c.ellipse((cx - r * .5, cy - r * .62, cx - r * .05, cy - r * .2), fill=mix(fill, WHITE, .7))

def icon(c, kind, cx, cy, s, fill=INK):
    """Menu glyphs: filled ink silhouettes, round ends, one cut-out or glint each."""
    if kind == "egg":
        c.ellipse((cx - s * .62, cy - s * .85, cx + s * .62, cy + s * .85), fill=fill)
        c.ellipse((cx - s * .3, cy - s * .5, cx - s * .05, cy - s * .15), fill=mix(fill, WHITE, .75))
    elif kind == "deck":
        c.rr((cx - s, cy - s * .55, cx + s, cy + s * .55), s * .5, fill=fill)
        c.rr((cx - s * .42, cy - s * .28, cx + s * .42, cy + s * .28), s * .12, fill=mix(fill, WHITE, .78))
    elif kind == "paw":
        c.ellipse((cx - s * .55, cy - s * .05, cx + s * .55, cy + s * .85), fill=fill)
        for dx, dy in ((-.78, -.25), (-.28, -.78), (.28, -.78), (.78, -.25)):
            c.ellipse((cx + s * dx - s * .24, cy + s * dy - s * .24, cx + s * dx + s * .24, cy + s * dy + s * .24), fill=fill)
    elif kind == "quests":
        c.rr((cx - s * .68, cy - s * .78, cx + s * .68, cy + s * .9), s * .22, fill=fill)
        c.rr((cx - s * .3, cy - s, cx + s * .3, cy - s * .58), s * .12, fill=fill)
        for i in range(3): c.line([(cx - s * .34, cy - s * .22 + i * s * .38), (cx + s * .34, cy - s * .22 + i * s * .38)], mix(fill, WHITE, .8), s * .15)
    elif kind == "book":
        c.poly([(cx - s, cy - s * .62), (cx - s * .08, cy - s * .4), (cx - s * .08, cy + s * .78), (cx - s, cy + s * .56)], fill)
        c.poly([(cx + s, cy - s * .62), (cx + s * .08, cy - s * .4), (cx + s * .08, cy + s * .78), (cx + s, cy + s * .56)], fill)
    elif kind == "settings":
        for i, k in enumerate((.35, -.3, .1)):
            y = cy + (i - 1) * s * .62
            c.line([(cx - s * .85, y), (cx + s * .85, y)], fill, s * .2)
            c.ellipse((cx + s * k - s * .26, y - s * .26, cx + s * k + s * .26, y + s * .26), fill=fill)
    elif kind == "drop":
        c.ellipse((cx - s * .7, cy - s * .2, cx + s * .7, cy + s), fill=fill)
        c.poly([(cx, cy - s), (cx + s * .62, cy + s * .12), (cx - s * .62, cy + s * .12)], fill)
    elif kind == "charm":
        sparkle(c, cx - s * .15, cy + s * .1, s * .95, fill); sparkle(c, cx + s * .7, cy - s * .65, s * .4, fill)
    elif kind == "finish":
        c.ellipse((cx - s * .85, cy - s * .85, cx + s * .85, cy + s * .85), fill=fill)
        c.ellipse((cx - s * .45, cy - s * .55, cx - s * .05, cy - s * .15), fill=mix(fill, "#8090C0", .7) if fill != INK else mix(fill, WHITE, .75))
    elif kind == "toys":
        c.line([(cx - s * .55, cy + s * .4), (cx + s * .55, cy - s * .4)], fill, s * .42)
        for sx, sy in ((-1, 1), (1, -1)):
            for dx, dy in ((-.22, -.2), (.22, .2)):
                px, py = cx + sx * s * .62 + dx * s, cy + sy * s * .45 + dy * s
                c.ellipse((px - s * .3, py - s * .3, px + s * .3, py + s * .3), fill=fill)

def badge(c, cx, cy, rad, face, kind, lip=2):
    c.round_key(cx, cy, rad, face, mix(face, INK, .4), lip=lip)
    icon(c, kind, cx, cy, rad * .5)

RUNES = {  # six Elder Futhark letters as plain staves, unit box -1..1
    "wunjo": [[(-.35, -1), (-.35, 1)], [(-.35, -1), (.5, -.45), (-.35, .1)]],
    "uruz": [[(-.55, 1), (-.55, -1), (.55, -.35), (.55, 1)]],
    "dagaz": [[(-.8, -.7), (-.8, .7)], [(.8, -.7), (.8, .7)], [(-.8, -.7), (.8, .7)], [(-.8, .7), (.8, -.7)]],
    "ehwaz": [[(-.6, 1), (-.6, -1), (0, -.2), (.6, -1), (.6, 1)]],
    "raidho": [[(-.4, -1), (-.4, 1)], [(-.4, -1), (.45, -.5), (-.4, 0), (.5, 1)]],
    "ansuz": [[(-.35, -1), (-.35, 1)], [(-.35, -1), (.55, -.3)], [(-.35, -.3), (.55, .4)]],
}
def stone(c, cx, cy, size, colour, rune, outline=True):
    """Rune stat stone as a small toy key: stat colour face, ink rune, ink outline, bottom lip."""
    h = size / 2; lip = max(1.2, size * .1); o = max(1.1, size * .07) if outline else 0
    r = size * .32
    if outline: c.rr((cx - h, cy - h, cx + h, cy + h + lip), r, fill=INK)
    c.rr((cx - h + o, cy - h + o, cx + h - o, cy + h + lip - o), r - o, fill=mix(colour, INK, .42))
    c.rr((cx - h + o, cy - h + o, cx + h - o, cy + h - o), r - o, fill=colour)
    if size >= 24: c.line([(cx - h * .45, cy - h + o + size * .09), (cx + h * .2, cy - h + o + size * .09)], mix(colour, WHITE, .6), size * .05)
    k = h * .5
    for seg in RUNES[rune]: c.line([(cx + x * k, cy + y * k + size * .02) for x, y in seg], INK, max(1.1, size * .1))

def primary(c, box, label, r=10, lip=4, glyph="A", size=14):
    x0, y0, x1, y1 = box
    c.toy(box, r, GO, GO_LIP, lip=lip)
    f = font("disp", size); w = c.tw(label, f); gw = 24 if glyph else 0
    x = (x0 + x1) / 2 - (w + gw) / 2; cy = (y0 + y1) / 2
    if glyph:
        c.ellipse((x - 1, cy - 9, x + 17, cy + 9), fill=INK); c.ellipse((x + .6, cy - 7.4, x + 15.4, cy + 6.4), fill=WHITE)
        c.text((x + 8, cy - .4), glyph, font("xb", 9.5), INK, "mm")
    c.text((x + gw, cy), label, f, INK)

def key(c, box, label, r=10, lip=3, size=12, face=CREAM, lip_col=CREAM_LIP):
    c.toy(box, r, face, lip_col, lip=lip)
    c.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, font("disp", size), INK, "mm")

def wallet(c, box, amount):
    x0, y0, x1, y1 = box
    c.well(box, (y1 - y0) / 2, dots=False)
    star(c, x0 + 20, (y0 + y1) / 2, 8)
    c.text((x1 - 14, (y0 + y1) / 2), amount, font("mono", 12), STARS, "rm")

def load(rel): return Image.open(os.path.join(ROOT, rel)).convert("RGB")


# ================= screens =================
def screen_deck():
    src = load("artifacts/qa-2026-11-16c-v775/ui-batch/after-14-deck-board-bottom-844x390.png")
    c = Canvas(844, 390, src)
    board = src.crop((342, 93, 501, 363)).resize((S(159), S(270)), Image.LANCZOS)
    jellies = [(cutout(src, b, tol=30, pixel=True), b) for b in ((520, 117, 558, 153), (578, 124, 604, 150))]
    # LCD glass: same rect, navy instead of grey-teal. The board is pasted back untouched.
    c.rr((191, 90, 652, 367), 10, fill=WELL)
    c.rr((339, 90, 504, 366), 6, fill=INK); c.im.paste(board, (S(342), S(93))); c._redraw()
    def hud(box, label, colour):
        c.tray(box, 9, fill="#1B2670", depth=2.5)
        if label: c.tab_label(box[0] + 7, box[1] + 6, label, colour)
    hud((195, 94, 334, 140), "CHAIN", TOMATO); c.text((206, 127), "×0", font("mono", 14), WHITE)
    hud((195, 146, 334, 191), "SCORE", LEMON); c.text((206, 178), "0", font("mono", 14), WHITE)
    hud((195, 198, 334, 297), "GOALS 0/2", GO)
    for i, y in enumerate((240, 274)):
        ball(c, 215, y, 8, GO)
        c.text((229, y - 5), "+", font("xb", 8), ON_SHELL_SOFT, "mm")
        c.rr((236, y - 6.5, 257, y + 6.5), 4, outline=WHITE, width=1.6)
        c.rr((239.5 + i * 8.5, y - 3.5, 245 + i * 8.5, y + 3.5), 1.5, fill=WHITE)
        c.text((323, y), "0/1", font("mono", 10.5), ON_SHELL_SOFT, "rm")
    c.toy((195, 315, 334, 357), 10, CREAM, CREAM_LIP, lip=3)          # Quests is the one pressable card here
    icon(c, "quests", 217, 336, 7); c.text((233, 336), "Quests", font("disp", 12), INK); c.text((290, 336.5), "0/3", font("mono", 10.5), INK_SOFT)
    hud((507, 94, 648, 160), None, SKY); c.tab_label(514, 100, "NEXT", SKY); c.tab_label(573, 100, "THEN", "#B7C2F0")
    for t, b in jellies: c.paste_rgba(t, b[0], b[1])
    hud((507, 166, 648, 212), "EGGS LEFT", ORANGE); c.text((519, 198), "24", font("mono", 14), WHITE); c.text((539, 200), "/24", font("mono", 9.5), ON_SHELL_SOFT)
    hud((507, 218, 648, 264), None, GO)
    for i, hh in enumerate((7, 12, 17)):
        c.rr((519 + i * 7.5 - 1.2, 251 - hh - 1.2, 525 + i * 7.5 + 1.2, 252.2), 2.4, fill=INK)
        c.rr((519 + i * 7.5, 251 - hh, 525 + i * 7.5, 251), 1.6, fill=GO if i == 0 else "#3A4690")
    c.text((554, 241), "Easy", font("disp", 13), WHITE)
    hud((507, 270, 648, 316), "WIN PAYS", STARS); star(c, 524, 302, 5.5, face=False); c.text((537, 302), "11–13", font("mono", 12), STARS)
    c.round_key(810, 29, 22, lip=3); arrow_left(c, 810, 29, 7)
    return src, c


def screen_results():
    src = load("artifacts/qa-2026-11-15-v735/verify-D/D6-results-844x390.png")
    c = Canvas(860, 406, src)
    star3d = key_yellow(src, (380, 176, 482, 304))
    c.rr((135, 92, 725, 376), 10, fill=WELL)
    c.tray((144, 101, 341, 368), 10, fill="#1B2670")
    c.tab_label(152, 108, "PAYOUT", STARS)
    for y, a, b in ((139, "Round win", "5"), (167, "Tidy stack", "+1"), (195, "Supporter", "+7")):
        c.text((155, y), a, font("m", 11.5), WHITE); c.text((330, y), b, font("mono", 11), WHITE, "rm")
    for x in range(155, 330, 7): c.line([(x, 216), (x + 3, 216)], "#5C6CC8", 1.4, round_=False)
    c.toy((151, 221, 236, 243), 8, STARS, mix(STARS, INK, .4), lip=2)
    c.text((159, 232), "Total", font("disp", 12), INK); burst(c, 199, 232, 5.5, INK); c.text((208, 232), "13", font("mono", 12), INK)
    burst(c, 159, 259, 4, ON_SHELL_SOFT); c.text((167, 259), "13 earned", font("m", 10), ON_SHELL_SOFT)
    wallet(c, (155, 337, 221, 361), "25")
    box = (347, 101, 513, 368)
    c.rr(box, 10, fill=INK); c.sunburst(box, 10, 430, 243, "#1B2670", SHELL, rays=12)
    c.paste_rgba(star3d, 380, 176)
    t = Image.new("RGBA", (S(170), S(40)), (0, 0, 0, 0)); d = ImageDraw.Draw(t)
    d.text((S(85), S(20)), "TIDY WIN!", font=font("ext", 17), fill=rgb(LEMON) + (255,), anchor="mm", stroke_width=S(2.4), stroke_fill=rgb(INK) + (255,))
    t = t.rotate(3, Image.BICUBIC); c.paste_rgba(t, 345, 110)
    c.text((430, 158), "Bank pair", font("b", 10), WHITE, "mm", stroke=1.6)
    c.text((424, 320), "+13", font("mono", 16), STARS, "mm", stroke=2); star(c, 449, 319, 7, face=False)
    c.text((430, 348), "Tucked into your wallet", font("m", 9.5), WHITE, "mm", stroke=1.6)
    c.tray((519, 101, 716, 368), 10, fill="#1B2670")
    c.tab_label(527, 108, "GOALS 2/2", GO)
    for y, s in ((139, "LEFT"), (167, "RIGHT")):
        check(c, 534, y, 4, GO); ball(c, 548, y, 4.5, GO)
        c.line([(558, y + 4), (558, y - 4)], WHITE, 1.5); c.line([(555, y - 1.5), (558, y - 4.5), (561, y - 1.5)], WHITE, 1.5)
        c.text((566, y), s, font("b", 11), WHITE)
    c.text((530, 195), "Score 0 · Best 100 · Chain ×0", font("m", 10), ON_SHELL_SOFT)
    primary(c, (526, 269, 615, 311), "Replay", lip=3, glyph=None, size=12.5); c.focus((526, 269, 615, 311), 10, lip=3, pad=3)
    key(c, (620, 269, 708, 311), "Medium"); key(c, (526, 318, 615, 358), "Hatch eggs"); key(c, (620, 318, 708, 358), "Leave")
    c.round_key(818, 37, 22, lip=3); arrow_left(c, 818, 37, 7)
    return src, c


def screen_customize():
    src = load("artifacts/qa-2026-11-16c-v775/customization-egg/08-customize-hue-jars-750x402.png")
    c = Canvas(750, 402, src)
    pet = cutout(src, (584, 103, 644, 184), tol=22)
    jars = {b: cutout(src, b, tol=34, shrink=3) for b in ((221, 216, 246, 242), (451, 216, 476, 242), (221, 287, 246, 313), (451, 287, 476, 313))}
    sheet = (13, 33, 744, 394)
    c.toy(sheet, 18, SHELL, SHELL_LIP, lip=4, o=3, glint=False); c.checker(sheet, 18, SHELL, mix(SHELL, WHITE, .09))
    c.line([(34, 39.5), (700, 39.5)], SHELL_HI, 1.8)
    c.plate(30, 60, "Customize", font("disp", 16), PINK)
    c.round_key(584, 59, 19); c.text((584, 58.5), "?", font("disp", 15), INK, "mm")
    wallet(c, (611, 41, 688, 78), "172")
    c.round_key(713, 59, 19); arrow_left(c, 713, 59, 6)
    # tab trough + raised active key
    c.tray((26, 89, 489, 125), 18, fill=SHELL_LIP, depth=2.5)
    c.toy((30, 92, 144, 119), 14, LEMON, LEMON_LIP, lip=2)
    for i, (kind, s) in enumerate((("drop", "Hue"), ("charm", "Charm"), ("finish", "Finish"), ("toys", "Toys"))):
        f = font("disp", 12); w = c.tw(s, f); cx = 87 + i * 115; col = INK if i == 0 else WHITE
        icon(c, kind, cx - w / 2 - 6, 106.5 if i else 105.5, 6.5, col); c.text((cx - w / 2 + 8, 106.5 if i else 105.5), s, f, col)
    c.tray((28, 135, 485, 171), 18, fill=SHELL_LIP, depth=2.5)
    c.toy((33, 139, 257, 165), 13, CREAM, CREAM_LIP, lip=2)
    c.text((145, 152), "Main", font("disp", 12), INK, "mm"); c.text((370, 153), "Secondary", font("disp", 12), WHITE, "mm")
    c.rr((485.5, 135, 489.5, 367), 2, fill=INK); c.rr((486.3, 137, 488.7, 290), 1.2, fill=CREAM)
    rows = [(181, [("Rose jar", "0 of 5 · ×2", 0), ("Tide jar", "0 of 5 · ×3", 1)]), (252, [("Citrus jar", "0 of 5 · ×1", 2), ("Iris jar", "0 of 5 · ×4", 3)]), (324, [("Original colour", None, None)])]
    jar_boxes = list(jars)
    c.clip_begin()
    for y, items in rows:
        for col, (name, sub, j) in enumerate(items):
            x = 28 + col * 231; sel = y == 181 and col == 0
            box = (x, y, x + 223, y + 63)
            c.toy(box, 12, LEMON if sel else CREAM, LEMON_LIP if sel else CREAM_LIP, lip=3)
            tb = (x + 11, y + 11, x + 55, y + 55)
            c.rr((tb[0] - 2, tb[1] - 2, tb[2] + 2, tb[3] + 2), 10, fill=INK); c.paste_round(src, tb, 8)
            c.text((x + 67, y + 25), name, font("disp", 12), INK)
            if sub: c.text((x + 67, y + 45), sub, font("m", 10.5), INK_SOFT)
            else: c.chip((x + 66, y + 37, x + 124, y + 53), "CURRENT", fill=GO, text=INK, f=font("xb", 8.5))
            if j is not None: b = jar_boxes[j]; c.paste_rgba(jars[b], b[0], b[1])
    c.clip_end((20, 176, 492, 388))
    c.focus((28, 181, 251, 244), 12, lip=3)
    # detail pane: information, so an inset tray, with the LCD well for the live pet
    c.tray((501, 89, 731, 381), 14)
    c.well((512, 100, 720, 186), 10); c.paste_rgba(pet, 584, 103)
    c.text((513, 204), "Rose jar", font("disp", 15), WHITE)
    c.chip((688, 192, 720, 214), "×2", fill=LEMON, text=INK, f=font("mono", 9.5))
    c.text((513, 225), "Main 0 of 5 → 1 of 5", font("m", 10.5), ON_SHELL_SOFT)
    primary(c, (513, 328, 719, 370), "Use 1 jar", r=12, lip=4)
    return src, c


def screen_menu():
    src = load("artifacts/qa-2026-11-16c-v775/ui-batch/after-09-pocket-menu-animated-tiles-750x402.png")
    c = Canvas(750, 402, src)
    cuts = {"egg": ((167, 143, 240, 201), 24), "deck": ((407, 153, 478, 193), 24), "bear": ((656, 153, 704, 209), 24), "ball": ((409, 273, 476, 341), 24)}
    art = {k: (cutout(src, b, tol=t), b) for k, (b, t) in cuts.items()}
    sheet = (8, 66, 743, 395)
    c.toy(sheet, 18, SHELL, SHELL_LIP, lip=4, o=3, glint=False); c.checker(sheet, 18, SHELL, mix(SHELL, WHITE, .09))
    c.line([(30, 72.5), (700, 72.5)], SHELL_HI, 1.8)
    c.plate(25, 95, "Pocket menu", font("disp", 16), GO)
    wallet(c, (622, 76, 686, 112), "0"); c.round_key(712, 93, 19); arrow_left(c, 712, 93, 6)
    tiles = [("egg", "Hatch eggs", "Eggs and their odds", "1/6 TOYS", "#FF8A5C", None), ("deck", "Deck style", "This week: Lime Gel", "0/15 STYLES", GRAPE, "promo"),
             ("paw", "Companio…", "20% off this week", "0/23 OUTFITS", PINK, "promo"), ("quests", "Quests", "Quests and the daily…", "0/3 TODAY", SKY, None),
             ("book", "Book", "Pages to fill, Stars to find", "1% FOUND", TEAL, None), ("settings", "Settings", "Sound, music and motion", None, FOG, None)]
    for i, (kind, title, sub, chip_, colour, promo) in enumerate(tiles):
        col, row = i % 3, i // 3; x = 19 + col * 239; y = 123 + row * 137
        box = (x, y, x + 232, y + 127); sel = i == 0
        c.toy(box, 14, LEMON if sel else CREAM, LEMON_LIP if sel else CREAM_LIP, lip=3)
        badge(c, x + 31, y + 30, 17.5, colour, kind)
        c.text((x + 57, y + 23), title, font("disp", 14), INK)
        c.text((x + 13, y + 65), sub, font("b" if promo else "m", 10), TOMATO_TEXT if promo else INK_SOFT)
        if chip_:
            f = font("xb", 9); w = c.tw(chip_, f); c.chip((x + 12, y + 99, x + 12 + w + 22, y + 125 - 1), chip_, f=f)
        wb = (x + 145, y + 10, x + 223, y + 88); c.well(wb, 10)
        if kind == "egg": t, b = art["egg"]; c.paste_rgba(t, b[0], b[1])
        if kind == "deck": t, b = art["deck"]; c.paste_rgba(t, b[0], b[1])
        if kind == "paw": t, b = art["bear"]; c.paste_rgba(t, b[0], b[1])
        if kind == "book": t, b = art["ball"]; c.paste_rgba(t, b[0], b[1])
        if kind == "quests":
            for k in range(8):
                px, py = wb[0] + 16 + (k % 4) * 15.5, wb[1] + 31 + (k // 4) * 16
                if k == 7: star(c, px, py, 6, face=False)
                else: c.ellipse((px - 6, py - 6, px + 6, py + 6), outline="#4450A8", width=1.5)
        if kind == "settings":
            for k, (colr, t_) in enumerate(((GO, .72), (GRAPE, .4), (TOMATO, .58))):
                py = wb[1] + 17 + k * 22
                c.line([(wb[0] + 12, py), (wb[2] - 12, py)], "#2A2F6B", 4); c.line([(wb[0] + 12, py), (wb[0] + 12 + 54 * t_, py)], colr, 4)
                c.ellipse((wb[0] + 12 + 54 * t_ - 7.5, py - 7.5, wb[0] + 12 + 54 * t_ + 7.5, py + 7.5), fill=INK)
                c.ellipse((wb[0] + 12 + 54 * t_ - 5.8, py - 5.8, wb[0] + 12 + 54 * t_ + 5.8, py + 5.8), fill=CREAM)
        c.round_key(x + 215, y + 80, 10, lip=2, o=1.6); chevron(c, x + 215.5, y + 80, 3.6)
        if promo: c.sticker(x + 187, y + 16, 80, 24, "THIS WEEK")
    c.focus((19, 123, 251, 250), 14, lip=3)
    return src, c


# ================= style sheet =================
def style_sheet():
    W, H = 844, 600
    c = Canvas(W, H, fill="#0E1030")
    c.toy((10, 10, W - 10, H - 14), 20, SHELL, SHELL_LIP, lip=5, o=3, glint=False); c.checker((10, 10, W - 10, H - 14), 20, SHELL, mix(SHELL, WHITE, .09))
    c.plate(30, 38, "Toy Shell kit", font("disp", 17), LEMON)
    c.text((200, 38), "one frame language: ink outline, face, top glint, bottom lip", font("m", 11), ON_SHELL_SOFT)
    lab = lambda x, y, s: c.text((x, y), s, font("xb", 9), ON_SHELL_SOFT)
    # palette
    lab(28, 70, "PALETTE  (ratio = text on that fill)")
    sw = [("Ink", INK, WHITE), ("Cream", CREAM, INK), ("Shell", SHELL, WHITE), ("Tray", TRAY, WHITE), ("Well", WELL, WHITE), ("Go", GO, INK), ("Lemon", LEMON, INK),
          ("Tomato", TOMATO, INK), ("Sky", SKY, INK), ("Orange", ORANGE, INK), ("Pink", PINK, INK), ("Grape", GRAPE, INK), ("Teal", TEAL, INK), ("Stars", STARS, INK)]
    for i, (n, col, tx) in enumerate(sw):
        x = 28 + i * 57
        c.toy((x, 80, x + 51, 124), 9, col, mix(col, INK, .4), lip=3)
        c.text((x + 25.5, 95), n, font("disp", 9.5), tx, "mm"); c.text((x + 25.5, 110), "%.1f" % contrast(col, tx), font("mono", 8), tx, "mm")
        c.text((x + 25.5, 137), col, font("mono", 7), ON_SHELL_SOFT, "mm")
    # surfaces
    lab(28, 158, "THREE SURFACES");
    c.toy((28, 168, 188, 232), 12); c.text((40, 190), "Tile", font("disp", 13), INK); c.text((40, 210), "You can press it. Has a lip.", font("m", 9.5), INK_SOFT)
    c.tray((198, 168, 358, 235), 12); c.text((210, 192), "Tray", font("disp", 13), WHITE); c.text((210, 212), "You read it. Sunk, no lip.", font("m", 9.5), ON_SHELL_SOFT)
    c.well((368, 168, 528, 235), 12); c.text((380, 192), "Well", font("disp", 13), WHITE, stroke=0); c.text((380, 212), "A little screen for 3D.", font("m", 9.5), ON_SHELL_SOFT)
    c.toy((538, 168, 698, 232), 12, LEMON, LEMON_LIP); c.focus((538, 168, 698, 232), 12); c.text((550, 190), "Selected + focus", font("disp", 13), INK); c.text((550, 210), "Lemon face, white ring.", font("m", 9.5), INK_SOFT)
    c.sticker(770, 200, 86, 26, "THIS WEEK")
    # buttons
    lab(28, 258, "BUTTON STATES  (primary above, key below)")
    states = ["Rest", "Hover", "Press", "Focus", "Disabled"]
    for i, s in enumerate(states):
        x = 28 + i * 160; b = (x, 270, x + 146, 314); k = (x, 330, x + 146, 370)
        if s == "Rest": primary(c, b, "Hatch", glyph="A"); key(c, k, "Leave")
        if s == "Hover":
            c.toy((b[0], b[1] - 1, b[2], b[3] - 1), 10, mix(GO, WHITE, .22), GO_LIP, lip=5); c.text(((b[0] + b[2]) / 2, (b[1] + b[3]) / 2 - 1), "Hatch", font("disp", 14), INK, "mm")
            c.toy((k[0], k[1] - 1, k[2], k[3] - 1), 10, WHITE, CREAM_LIP, lip=4); c.text(((k[0] + k[2]) / 2, (k[1] + k[3]) / 2 - 1), "Leave", font("disp", 12), INK, "mm")
        if s == "Press":
            c.toy(b, 10, GO, GO_LIP, lip=4, pressed=True); c.text(((b[0] + b[2]) / 2, (b[1] + b[3]) / 2 + 4), "Hatch", font("disp", 14), INK, "mm")
            c.toy(k, 10, CREAM, CREAM_LIP, lip=3, pressed=True); c.text(((k[0] + k[2]) / 2, (k[1] + k[3]) / 2 + 3), "Leave", font("disp", 12), INK, "mm")
        if s == "Focus": primary(c, b, "Hatch", glyph="A"); c.focus(b, 10, lip=4); key(c, k, "Leave"); c.focus(k, 10, lip=3)
        if s == "Disabled":
            c.toy(b, 10, DISABLED, DISABLED_LIP, lip=2, glint=False); c.text(((b[0] + b[2]) / 2, (b[1] + b[3]) / 2), "Hatch", font("disp", 14), DISABLED_TEXT, "mm")
            c.toy(k, 10, DISABLED, DISABLED_LIP, lip=2, glint=False); c.text(((k[0] + k[2]) / 2, (k[1] + k[3]) / 2), "Leave", font("disp", 12), DISABLED_TEXT, "mm")
        c.text((x + 73, 388), s, font("xb", 9), ON_SHELL_SOFT, "mm")
    # tabs, chips, header plates
    lab(28, 412, "TABS: a sunk trough, the active tab is a raised key")
    c.tray((28, 422, 388, 458), 18, fill=SHELL_LIP, depth=2.5); c.toy((32, 425, 148, 452), 14, LEMON, LEMON_LIP, lip=2)
    for i, s in enumerate(("Hue", "Charm", "Finish")): c.text((90 + i * 118, 439 if i == 0 else 440), s, font("disp", 12), INK if i == 0 else WHITE, "mm")
    lab(410, 412, "CHIPS AND HUD LABELS")
    c.chip((410, 426, 474, 450), "1/6 TOYS"); c.chip((482, 428, 540, 448), "CURRENT", fill=GO, text=INK); c.chip((548, 428, 580, 448), "×2", fill=LEMON, text=INK, f=font("mono", 9.5))
    x = 592
    for s, col in (("CHAIN", TOMATO), ("SCORE", LEMON), ("NEXT", SKY), ("WIN PAYS", STARS)): x = c.tab_label(x, 431, s, col) + 5
    lab(28, 482, "HEADER PLATES: the screen's tint, title in ink")
    x = 34
    for s, col in (("Hatch eggs", "#FF8A5C"), ("Deck style", GRAPE), ("Companions", PINK), ("Quests", SKY), ("Book", TEAL)):
        b = c.plate(x, 508, s, font("disp", 13), col, h=24); x = b[2] + 20
    lab(28, 540, "ICON BADGES AND RUNE STONES: the same toy key, small")
    for i, (kind, col) in enumerate((("egg", "#FF8A5C"), ("deck", GRAPE), ("paw", PINK), ("quests", SKY), ("book", TEAL), ("settings", FOG))):
        badge(c, 46 + i * 44, 566, 16, col, kind)
    for i, (n, col, rune) in enumerate(STAT):
        x = 318 + i * 86; stone(c, x, 565, 28, col, rune); c.text((x + 20, 566), n, font("disp", 11), WHITE)
    return c


# ================= mood board =================
def mood_toy(c, ox, oy):
    box = (ox, oy, ox + 400, oy + 262)
    c.toy(box, 18, SHELL, SHELL_LIP, lip=5, o=3, glint=False); c.checker(box, 18, SHELL, mix(SHELL, WHITE, .09))
    c.plate(ox + 22, oy + 30, "Wardrobe", font("disp", 15), PINK)
    wallet(c, (ox + 300, oy + 14, ox + 370, oy + 46), "97")
    c.tray((ox + 16, oy + 58, ox + 384, oy + 90), 16, fill=SHELL_LIP, depth=2.5); c.toy((ox + 20, oy + 61, ox + 138, oy + 85), 12, LEMON, LEMON_LIP, lip=2)
    for i, s in enumerate(("Hat", "Shirt", "Neck")): c.text((ox + 79 + i * 122, oy + 73.5 + (0 if i == 0 else 1)), s, font("disp", 11.5), INK if i == 0 else WHITE, "mm")
    for i, (n, sub) in enumerate((("Pearl Beads", None), ("Bell Collar", "WEARING"))):
        x = ox + 16 + i * 188; b = (x, oy + 102, x + 180, oy + 162); sel = i == 1
        c.toy(b, 12, LEMON if sel else CREAM, LEMON_LIP if sel else CREAM_LIP, lip=3)
        c.well((x + 9, oy + 111, x + 51, oy + 153), 8); ball(c, x + 30, oy + 132, 9, PINK if i else SKY)
        c.text((x + 60, oy + 123), n, font("disp", 12), INK)
        if sub: c.chip((x + 59, oy + 135, x + 117, oy + 151), sub, fill=GO, text=INK, f=font("xb", 8))
        else: burst(c, x + 65, oy + 143, 5, INK); c.text((x + 74, oy + 143), "15", font("mono", 10.5), INK)
    c.focus((ox + 204, oy + 102, ox + 384, oy + 162), 12)
    primary(c, (ox + 16, oy + 186, ox + 250, oy + 228), "Take off")
    key(c, (ox + 262, oy + 186, ox + 384, oy + 226), "Back")

def mood_pixel(c, ox, oy):
    """Pixel LCD: drawn at 1/3 size with no smoothing, then scaled up square, so every edge is stepped."""
    k = 3; w, h = 400 // k + 1, 270 // k
    BG, LINE, DIM, PH, AMB = "#0E2A1E", "#9BE36B", "#1F5A3A", "#D8FF9E", "#FFC14D"
    t = Image.new("RGB", (w, h), rgb(BG)); d = ImageDraw.Draw(t)
    def pr(b, fill=None, outline=None):  # pixel rect with one-pixel notched corners
        x0, y0, x1, y1 = b
        if fill: d.rectangle((x0 + 1, y0, x1 - 1, y1), fill=rgb(fill)); d.rectangle((x0, y0 + 1, x1, y1 - 1), fill=rgb(fill))
        if outline:
            d.line((x0 + 1, y0, x1 - 1, y0), fill=rgb(outline)); d.line((x0 + 1, y1, x1 - 1, y1), fill=rgb(outline))
            d.line((x0, y0 + 1, x0, y1 - 1), fill=rgb(outline)); d.line((x1, y0 + 1, x1, y1 - 1), fill=rgb(outline))
    for y in range(0, h, 2):
        for x in range((y // 2) % 2 * 2, w, 4): d.point((x, y), fill=rgb("#123524"))
    pr((0, 0, w - 1, h - 3), outline=LINE); d.line((1, h - 2, w - 2, h - 2), fill=rgb(DIM)); d.line((2, h - 1, w - 3, h - 1), fill=rgb(DIM))
    pr((5, 19, w - 6, 30), fill="#0A1F16", outline=DIM); pr((6, 20, 44, 28), fill=LINE)
    for i in range(2):
        x = 5 + i * 63; sel = i == 1
        pr((x, 34, x + 60, 54), fill=PH if sel else "#143D2A", outline=LINE); d.line((x + 1, 55, x + 59, 55), fill=rgb(DIM))
        pr((x + 3, 37, x + 16, 51), fill="#0A1F16", outline=DIM)
        for a in range(5):
            for b_ in range(5):
                if (a - 2) ** 2 + (b_ - 2) ** 2 <= 5: d.point((x + 7 + a, 41 + b_), fill=rgb(AMB if i else LINE))
    pr((5, 62, 83, 75), fill=LINE); d.line((6, 76, 82, 76), fill=rgb(DIM)); d.line((6, 77, 82, 77), fill=rgb(DIM))
    pr((88, 62, w - 6, 75), outline=LINE)
    pr((w - 30, 4, w - 6, 14), fill="#0A1F16", outline=DIM)
    big = t.resize((w * k * R, h * k * R), Image.NEAREST)
    c.im.paste(big, (S(ox), S(oy))); c._redraw()
    c.text((ox + 14, oy + 27), "Wardrobe", font("disp", 15), PH)
    c.text((ox + 334, oy + 29), "97", font("mono", 11), AMB, "mm")
    for i, s in enumerate(("Hat", "Shirt", "Neck")): c.text((ox + 78 + i * 122, oy + 74), s, font("disp", 11.5), "#0E2A1E" if i == 0 else LINE, "mm")
    c.text((ox + 72, oy + 122), "Pearl Beads", font("disp", 12), PH); c.text((ox + 72, oy + 143), "15 Stars", font("mono", 9.5), AMB)
    c.text((ox + 261, oy + 122), "Bell Collar", font("disp", 12), "#0E2A1E"); c.text((ox + 261, oy + 143), "WEARING", font("xb", 8.5), "#1F5A3A")
    c.text((ox + 133, oy + 207), "Take off", font("disp", 14), "#0E2A1E", "mm"); c.text((ox + 325, oy + 207), "Back", font("disp", 12), LINE, "mm")

def mood_sticker(c, ox, oy):
    PAPER, GING, SEAM, MINT_, ROSE, BUTTER, BROWN = "#FFF6E6", "#FFE3EC", "#E2B9A0", "#BFEFD2", "#FFB7CC", "#FFE9A8", "#5A3E36"
    box = (ox, oy, ox + 400, oy + 264)
    c.rr((ox + 2, oy + 5, ox + 402, oy + 269), 20, fill="#C9B7A6"); c.rr(box, 20, fill=PAPER)
    x0, y0, x1, y1 = (S(v) for v in box); w, h = x1 - x0, y1 - y0
    yy, xx = np.mgrid[0:h, 0:w]; g = (((xx // S(10)) % 2) * 110 + ((yy // S(10)) % 2) * 110).astype(np.uint8)
    mask = Image.new("L", (w, h), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), S(20), fill=255)
    g = (g.astype(np.float32) * np.asarray(mask, np.float32) / 255 * np.linspace(1, .15, h, dtype=np.float32)[:, None]).astype(np.uint8)
    c.im.paste(Image.new("RGB", (w, h), rgb(GING)), (x0, y0), Image.fromarray(g, "L")); c._redraw()
    for i in range(0, 372, 9): c.line([(ox + 14 + i, oy + 9), (ox + 18 + i, oy + 9)], SEAM, 1.3); c.line([(ox + 14 + i, oy + 255), (ox + 18 + i, oy + 255)], SEAM, 1.3)
    c.text((ox + 22, oy + 30), "Wardrobe", font("disp", 15), BROWN);
    for i in range(8): c.line([(ox + 22 + i * 10, oy + 43 + (i % 2) * 3), (ox + 32 + i * 10, oy + 46 - (i % 2) * 3)], ROSE, 2)
    c.rr((ox + 300, oy + 15, ox + 370, oy + 45), 15, fill=WHITE, outline="#EAD9C8", width=1.5); burst(c, ox + 320, oy + 30, 8, STARS); c.text((ox + 356, oy + 30), "97", font("mono", 12), BROWN, "rm")
    c.rr((ox + 16, oy + 58, ox + 384, oy + 90), 16, fill="#F3E4D3"); c.rr((ox + 20, oy + 62, ox + 138, oy + 86), 12, fill=MINT_)
    for i, s in enumerate(("Hat", "Shirt", "Neck")): c.text((ox + 79 + i * 122, oy + 74), s, font("disp", 11.5), BROWN if i == 0 else "#9A7F72", "mm")
    for i, (n, sub) in enumerate((("Pearl Beads", None), ("Bell Collar", "WEARING"))):
        x = ox + 16 + i * 188; b = (x, oy + 102, x + 180, oy + 164)
        c.rr((b[0] + 1, b[1] + 3, b[2] + 1, b[3] + 3), 14, fill="#D9C8B6"); c.rr(b, 14, fill=WHITE)
        if i: c.rr(b, 14, outline=ROSE, width=3)
        c.rr((x + 9, oy + 111, x + 51, oy + 155), 10, fill=BUTTER if i else "#D7EEFF"); c.ellipse((x + 21, oy + 124, x + 39, oy + 142), fill=ROSE if i else "#8CC8FF")
        c.text((x + 60, oy + 123), n, font("disp", 12), BROWN)
        if sub: c.text((x + 60, oy + 143), sub, font("xb", 8.5), "#2E8A5A")
        else: burst(c, x + 65, oy + 143, 5, "#C98A12"); c.text((x + 74, oy + 143), "15", font("mono", 10.5), "#8A5A00")
    c.rr((ox + 17, oy + 190, ox + 251, oy + 232), 21, fill="#6FCB99"); c.rr((ox + 16, oy + 186, ox + 250, oy + 228), 21, fill=MINT_)
    c.text((ox + 133, oy + 207), "Take off", font("disp", 14), BROWN, "mm")
    c.rr((ox + 262, oy + 186, ox + 384, oy + 228), 21, fill=WHITE, outline="#EAD9C8", width=1.5); c.text((ox + 323, oy + 207), "Back", font("disp", 12), BROWN, "mm")
    c.sticker(ox + 350, oy + 100, 62, 22, "NEW", face=ROSE, edge=WHITE, tilt=-8)

def mood_board():
    W, H = 1300, 500
    c = Canvas(W, H, fill="#17172B")
    c.text((30, 30), "Three directions for the menu surface (all drawn for this page, same layout, same type)", font("disp", 17), WHITE)
    cols = [("A  Toy Shell", "RECOMMENDED", mood_toy, ["Menus are moulded from the same plastic as the deck:", "blue shell, cream keys, ink outline, lip you can press.", "Bright primaries, checker shell, little LCD wells."], "#16214F"),
            ("B  Pixel LCD", None, mood_pixel, ["Every menu is the deck's screen: phosphor green,", "stepped pixel corners, dither. Most retro, but dark again,", "one colour, and it fights the rounded display face."], "#101812"),
            ("C  Sticker Book", None, mood_sticker, ["Paper, gingham, pastel stickers, stitched edges.", "Cutest and softest, but it is 2020s cosy, not retro,", "and pastels on cream leave little contrast to spend."], "#3A2F38")]
    for i, (name, tag, fn, notes, bg) in enumerate(cols):
        ox = 24 + i * 424
        c.rr((ox, 56, ox + 412, 486), 16, fill=bg)
        c.text((ox + 14, 80), name, font("disp", 16), WHITE)
        if tag: c.chip((ox + 290, 69, ox + 400, 91), tag, fill=LEMON, text=INK, f=font("xb", 9))
        fn(c, ox + 6, 104)
        for j, s in enumerate(notes): c.text((ox + 14, 412 + j * 18), s, font("m", 11.5), "#E4E6F2")
    return c


# ================= output =================
def side_by_side(src, c, name, title, note):
    after = c.out(); before = src.resize(after.size, Image.LANCZOS)
    after.save(os.path.join(HERE, name + "-after@2x.png"), optimize=True)
    pad, head = 24, 76
    sheet = Image.new("RGB", (after.width * 2 + pad * 3, after.height + head + pad), rgb("#15152A")); d = ImageDraw.Draw(sheet)
    d.text((pad, 14), title, font=font("disp", 12, 2), fill=(255, 255, 255))
    d.text((pad, 48), "NOW  Studio capture", font=font("xb", 8, 2), fill=rgb("#AEB4D6"))
    d.text((pad * 2 + after.width, 48), "PROPOSED  drawing over the same capture, every rect unchanged. " + note, font=font("xb", 8, 2), fill=rgb(LEMON))
    sheet.paste(before, (pad, head)); sheet.paste(after, (pad * 2 + after.width, head))
    sheet.save(os.path.join(HERE, name + "-before-after.png"), optimize=True); print("wrote", name, sheet.size)
    return sheet


def main():
    for name, a, b in (("ink on cream", INK, CREAM), ("soft ink on cream", INK_SOFT, CREAM), ("soft ink on lemon", INK_SOFT, LEMON), ("ink on lemon", INK, LEMON), ("ink on go", INK, GO),
                       ("white on shell", WHITE, SHELL), ("soft on shell", ON_SHELL_SOFT, SHELL), ("white on tray", WHITE, TRAY), ("soft on tray", ON_SHELL_SOFT, TRAY),
                       ("soft on hud tray", ON_SHELL_SOFT, "#1B2670"), ("stars on hud tray", STARS, "#1B2670"), ("stars on well", STARS, WELL), ("promo red on cream", TOMATO_TEXT, CREAM),
                       ("disabled text", DISABLED_TEXT, DISABLED), ("cream on ink", CREAM, INK), ("ink on tomato", INK, TOMATO), ("ink on stars", INK, STARS), ("white ring on shell", WHITE, SHELL)):
        print("%-22s %5.2f" % (name, contrast(a, b)))
    for _, col, _r in STAT: print("ink on stat %s %5.2f" % (col, contrast(INK, col)))
    sheets = [
        side_by_side(*screen_deck(), "01-pocket-deck-hud-844x390", "1  Pocket Deck round HUD, phone 844x390", "The board is untouched."),
        side_by_side(*screen_customize(), "02-customize-hue-750x402", "2  Customize, Hue tab, phone 750x402 (the capture size)", "Pets and jars are the capture's own."),
        side_by_side(*screen_menu(), "03-pocket-menu-750x402", "3  Pocket menu (the hub), phone 750x402 (the capture size)", "Eggs, deck, Bear and ball are the capture's own."),
        side_by_side(*screen_results(), "04-results-844x390", "4  Round results in the deck, phone 844x390", "The Star is the capture's own."),
    ]
    style_sheet().out().save(os.path.join(HERE, "00-style-system.png"), optimize=True)
    mood_board().out().save(os.path.join(HERE, "05-mood-board-three-directions.png"), optimize=True)
    w = max(s.width for s in sheets) // 2
    small = [s.resize((w, round(s.height * w / s.width)), Image.LANCZOS) for s in sheets]
    cs = Image.new("RGB", (w, sum(s.height for s in small)), rgb("#15152A")); y = 0
    for s in small: cs.paste(s, (0, y)); y += s.height
    cs.save(os.path.join(HERE, "contact-sheet.png"), optimize=True); print("wrote contact sheet", cs.size)


if __name__ == "__main__":
    main()
