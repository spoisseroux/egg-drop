"""Shared drawing helpers and the Pocket Deck Slim layout constants.

Everything is authored in "deck units": the deck body is 1600 x 800 units (2:1). All art is
drawn supersampled and scaled down, so edges are smooth. Python + Pillow + numpy only.
"""
from __future__ import annotations

import glob
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "deck"
MOCKUPS = ROOT / "artifacts" / "deck-rebuild" / "mockups"

# ---------------------------------------------------------------- layout (deck units)
DECK = {
    "size": [1600, 800],
    "bandRadius": 150, "bandThickness": 20,
    "plate": [20, 20, 1560, 760], "plateRadius": 132,
    "glass": [360, 80, 880, 640], "glassRadius": 44,
    "lcd": [376, 96, 848, 608], "lcdRadius": 30,
    "dpad": {"center": [190, 424], "diameter": 208, "well": 232},
    "menu": [128, 618, 124, 44],
    "wordmark": {"center": [190, 172], "pixel": 6},
    "led": {"center": [190, 258], "diameter": 12},
    "buttonA": {"center": [1432, 372], "diameter": 176},
    "buttonB": {"center": [1318, 548], "diameter": 104},
    "speaker": {"center": [1456, 652]},
    "screws": [[66, 66], [1534, 66]],
    "shoulderL": [170, -12, 220, 24], "shoulderR": [1210, -12, 220, 24],
}

# ---------------------------------------------------------------- colour
def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def to_hex(c):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in c[:3])


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + ((a[3] + (b[3] - a[3]) * t,) if len(a) > 3 and len(b) > 3 else ())


def mix(a, b, t, alpha=255):
    c = lerp(hx(a) if isinstance(a, str) else a, hx(b) if isinstance(b, str) else b, t)
    return (int(round(c[0])), int(round(c[1])), int(round(c[2])), alpha)


def luminance(c):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2])


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


GLASS, RAISED, WELL = "#15171B", "#23262C", "#0C0D10"
TEXT, SOFT, DIM, INK = "#F3F4F6", "#C3C8D0", "#8A909A", "#0E0F12"
STAR, DANGER, GOOD = "#FFC14D", "#FF5A6E", "#7BE495"


def ui_theme(accent, deep):
    """Mirror of DeckThemes: neutral glass leaning toward the plate's deep colour."""
    panel = mix(GLASS, deep, .14)
    raised = mix(RAISED, deep, .16)
    well = mix(WELL, deep, .10)
    selected = mix(raised, accent, .14)
    line = mix("#9AA0AA", accent, .35)
    ink = hx(INK) if contrast(hx(accent), hx(INK)) >= 4.5 else hx("#FFFFFF")
    return {"panel": panel, "raised": raised, "well": well, "selected": selected, "line": line,
            "accent": hx(accent), "ink": ink, "text": hx(TEXT), "soft": hx(SOFT), "dim": hx(DIM),
            "star": hx(STAR), "danger": hx(DANGER), "deep": hx(deep)}


# ---------------------------------------------------------------- fonts
def _find(pattern):
    hits = sorted(glob.glob(pattern))
    return hits[-1] if hits else None


_RBX = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts")
FONT_FILES = {
    "r": _find(_RBX + r"\BuilderSans-Regular.otf"), "m": _find(_RBX + r"\BuilderSans-Medium.otf"),
    "b": _find(_RBX + r"\BuilderSans-Bold.otf"), "xb": _find(_RBX + r"\BuilderSans-ExtraBold.otf"),
    "mono": _find(_RBX + r"\RobotoMono-Regular.ttf") or r"C:\Windows\Fonts\RobotoMono-Regular.ttf",
    "monob": r"C:\Windows\Fonts\RobotoMono-Bold.ttf",
}
_cache = {}


def font(key, px):
    k = (key, int(round(px)))
    if k not in _cache:
        _cache[k] = ImageFont.truetype(FONT_FILES[key], k[1])
    return _cache[k]


# ---------------------------------------------------------------- canvas
class Cv:
    """Supersampled RGBA canvas. Coordinates are in output pixels; z is the supersample factor."""

    def __init__(self, w, h, z=2, bg=(0, 0, 0, 0)):
        self.w, self.h, self.z = w, h, z
        # An opaque canvas is RGB so Pillow really blends translucent fills; an RGBA canvas replaces pixels
        # (alpha included), which is what the transparent sprite layers want.
        self.opaque = len(bg) > 3 and bg[3] == 255
        self.im = Image.new("RGB" if self.opaque else "RGBA", (int(round(w * z)), int(round(h * z))), bg[:3] if self.opaque else bg)
        self.d = ImageDraw.Draw(self.im, "RGBA")

    def _c(self, c):
        return hx(c) if isinstance(c, str) else tuple(int(round(v)) for v in c)

    def refresh(self):
        self.d = ImageDraw.Draw(self.im, "RGBA")

    def out(self):
        return self.im.resize((int(round(self.w)), int(round(self.h))), Image.LANCZOS) if self.z != 1 else self.im

    # --- primitives
    def rr(self, x, y, w, h, r, fill=None, stroke=None, sw=1.0):
        z = self.z
        r = max(0, min(r, w / 2, h / 2))
        box = [x * z, y * z, (x + w) * z - 1, (y + h) * z - 1]
        if fill is not None:
            self.d.rounded_rectangle(box, r * z, fill=self._c(fill))
        if stroke is not None:
            self.d.rounded_rectangle(box, r * z, outline=self._c(stroke), width=max(1, int(round(sw * z))))

    def mask_rr(self, x, y, w, h, r):
        z = self.z
        m = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([x * z, y * z, (x + w) * z - 1, (y + h) * z - 1], max(0, min(r, w / 2, h / 2)) * z, fill=255)
        return m

    def grad_rr(self, x, y, w, h, r, stops, angle=90):
        """Rounded rect filled with a linear gradient. stops: [(t, colour)], angle 90 = top to bottom."""
        z = self.z
        W, H = max(1, int(round(w * z))), max(1, int(round(h * z)))
        g = gradient(W, H, stops, angle)
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], max(0, min(r, w / 2, h / 2)) * z, fill=255)
        a = ImageChops.multiply(g.getchannel("A"), m)
        g.putalpha(a)
        self.paste(g, x * z, y * z, raw=True)

    def ell(self, cx, cy, rx, ry=None, fill=None, stroke=None, sw=1.0):
        z = self.z
        ry = rx if ry is None else ry
        box = [(cx - rx) * z, (cy - ry) * z, (cx + rx) * z, (cy + ry) * z]
        self.d.ellipse(box, fill=self._c(fill) if fill is not None else None,
                       outline=self._c(stroke) if stroke is not None else None, width=max(1, int(round(sw * z))))

    def line(self, pts, fill, w=2.0, round_caps=True):
        z = self.z
        p = [(a * z, b * z) for a, b in pts]
        self.d.line(p, fill=self._c(fill), width=max(1, int(round(w * z))), joint="curve")
        if round_caps:
            rr_ = w * z / 2
            for a, b in p:
                self.d.ellipse([a - rr_, b - rr_, a + rr_, b + rr_], fill=self._c(fill))

    def poly(self, pts, fill):
        z = self.z
        self.d.polygon([(a * z, b * z) for a, b in pts], fill=self._c(fill))

    def arc(self, cx, cy, r, a0, a1, fill, w=2.0):
        z = self.z
        self.d.arc([(cx - r) * z, (cy - r) * z, (cx + r) * z, (cy + r) * z], a0, a1, fill=self._c(fill), width=max(1, int(round(w * z))))

    def text(self, x, y, s, key="r", size=16, fill=TEXT, anchor="la", tracking=0.0):
        z = self.z
        f = font(key, size * z)
        if tracking:
            total = sum(f.getlength(ch) for ch in s) + tracking * z * (len(s) - 1)
            cx = x * z - (total if anchor[0] == "r" else total / 2 if anchor[0] == "m" else 0)
            for ch in s:
                self.d.text((cx, y * z), ch, font=f, fill=self._c(fill), anchor="l" + anchor[1])
                cx += f.getlength(ch) + tracking * z
            return total / z
        self.d.text((x * z, y * z), s, font=f, fill=self._c(fill), anchor=anchor)
        return f.getlength(s) / z

    def tw(self, s, key="r", size=16, tracking=0.0):
        return font(key, size * self.z).getlength(s) / self.z + tracking * (len(s) - 1)

    def wrap(self, x, y, s, width, key="r", size=16, fill=TEXT, lh=None, max_lines=3):
        lh = lh or size * 1.25
        words, lines, cur = s.split(), [], ""
        for wd in words:
            t = (cur + " " + wd).strip()
            if self.tw(t, key, size) <= width or not cur:
                cur = t
            else:
                lines.append(cur)
                cur = wd
        lines.append(cur)
        for i, ln in enumerate(lines[:max_lines]):
            self.text(x, y + i * lh, ln, key, size, fill)
        return min(len(lines), max_lines) * lh

    # --- effects
    def shadow(self, x, y, w, h, r, blur=18, color=(0, 0, 0, 120), dx=0, dy=8, spread=0):
        z = self.z
        pad = int((blur * 3 + abs(dx) + abs(dy) + spread) * z)
        W, H = int(w * z) + pad * 2, int(h * z) + pad * 2
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).rounded_rectangle([pad - spread * z, pad - spread * z, pad + w * z + spread * z, pad + h * z + spread * z], (r + spread) * z, fill=255)
        m = m.filter(ImageFilter.GaussianBlur(blur * z / 2))
        c = self._c(color)
        layer = Image.new("RGBA", (W, H), c[:3] + (0,))
        layer.putalpha(m.point(lambda v: int(v * c[3] / 255)))
        self.paste(layer, x * z - pad + dx * z, y * z - pad + dy * z, raw=True)

    def glow_ring(self, x, y, w, h, r, color=(255, 255, 255, 255), width=2.5, glow=10, glow_alpha=90):
        """Focus ring: crisp stroke plus a soft outer glow."""
        z = self.z
        pad = int(glow * 3 * z)
        W, H = int(w * z) + pad * 2, int(h * z) + pad * 2
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).rounded_rectangle([pad, pad, pad + w * z, pad + h * z], r * z, outline=255, width=int(width * 2 * z))
        m = m.filter(ImageFilter.GaussianBlur(glow * z / 2))
        c = self._c(color)
        layer = Image.new("RGBA", (W, H), c[:3] + (0,))
        layer.putalpha(m.point(lambda v: int(min(255, v * glow_alpha / 255 * 1.6))))
        self.paste(layer, x * z - pad, y * z - pad, raw=True)
        self.rr(x, y, w, h, r, stroke=color, sw=width)

    def paste(self, img, x, y, raw=False):
        """Alpha-composite an RGBA image. raw=True: img and x, y already in supersampled pixels."""
        if not raw:
            img = img.resize((max(1, int(round(img.width * self.z))), max(1, int(round(img.height * self.z)))), Image.LANCZOS) if self.z != 1 else img
            x, y = x * self.z, y * self.z
        x, y = int(round(x)), int(round(y))
        # alpha_composite needs the source inside the destination
        sx, sy = max(0, -x), max(0, -y)
        ex, ey = min(img.width, self.im.width - x), min(img.height, self.im.height - y)
        if ex <= sx or ey <= sy:
            return
        part = img.crop((sx, sy, ex, ey)).convert("RGBA")
        if self.opaque:
            self.im.paste(part, (x + sx, y + sy), part)
        else:
            self.im.alpha_composite(part, (x + sx, y + sy))
        self.refresh()


def gradient(W, H, stops, angle=90):
    """Linear gradient RGBA image. angle in degrees: 0 = left to right, 90 = top to bottom."""
    stops = [(t, hx(c) if isinstance(c, str) else tuple(c) + ((255,) if len(c) == 3 else ())) for t, c in stops]
    a = math.radians(angle)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    dx, dy = math.cos(a), math.sin(a)
    proj = xs * dx + ys * dy
    lo = min(0, (W - 1) * dx) + min(0, (H - 1) * dy)
    hi = max(0, (W - 1) * dx) + max(0, (H - 1) * dy)
    t = (proj - lo) / max(1e-6, hi - lo)
    return Image.fromarray(ramp(t, stops), "RGBA")


def ramp(t, stops):
    """Map a float array t (0..1) through colour stops -> uint8 RGBA array."""
    ts = np.array([s[0] for s in stops], dtype=np.float32)
    out = np.zeros(t.shape + (4,), dtype=np.float32)
    for ch in range(4):
        out[..., ch] = np.interp(t, ts, np.array([s[1][ch] for s in stops], dtype=np.float32))
    return np.clip(out + 0.5, 0, 255).astype(np.uint8)


def rounded_mask(W, H, r, ss=4):
    m = Image.new("L", (W * ss, H * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W * ss - 1, H * ss - 1], r * ss, fill=255)
    return m.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------- pixel wordmark
GLYPHS = {
    "P": ["#####.", "##..##", "##..##", "#####.", "##....", "##....", "##...."],
    "O": ["..##..", ".####.", ".####.", "######", "######", "######", ".####."],  # the egg
    "C": [".#####", "##....", "##....", "##....", "##....", "##....", ".#####"],
    "K": ["##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##"],
    "E": ["######", "##....", "##....", "#####.", "##....", "##....", "######"],
    "T": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
    "D": ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "#####."],
}
SMALL = {
    "E": ["###", "#..", "##.", "#..", "###"], "G": ["###", "#..", "#.#", "#.#", "###"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"], "P": ["###", "#.#", "###", "#..", "#.."],
    " ": ["..", "..", "..", "..", ".."],
}
WORD_W, WORD_H = 41, 16  # POCKET over DECK, 2 px line gap


def wordmark_cells():
    """Yield (col, row, kind) for the stacked wordmark. kind: 'ink' or 'egg' (the O) or 'glint'."""
    cells = []
    for row, word in enumerate(("POCKET", "DECK")):
        width = len(word) * 6 + (len(word) - 1)
        x0 = (WORD_W - width) // 2
        for i, ch in enumerate(word):
            for gy, line in enumerate(GLYPHS[ch]):
                for gx, px in enumerate(line):
                    if px == "#":
                        kind = "egg" if ch == "O" else "ink"
                        if ch == "O" and (gx, gy) == (2, 2):
                            kind = "glint"
                        cells.append((x0 + i * 7 + gx, row * 9 + gy, kind))
    return cells


def small_text_cells(s):
    cells, x = [], 0
    for ch in s:
        g = SMALL[ch]
        for gy, line in enumerate(g):
            for gx, px in enumerate(line):
                if px == "#":
                    cells.append((x + gx, gy))
        x += len(g[0]) + 1
    return cells, x - 1


# ---------------------------------------------------------------- icons (24 grid, 2 px stroke, round caps)
def star_pts(cx, cy, r, inner=0.46, rot=-90):
    pts = []
    for i in range(10):
        a = math.radians(rot + i * 36)
        rr_ = r if i % 2 == 0 else r * inner
        pts.append((cx + rr_ * math.cos(a), cy + rr_ * math.sin(a)))
    return pts


def icon(cv: Cv, name, cx, cy, s=24, color=TEXT, accent=None, w=None):
    """Draw one system icon centred on (cx, cy) in an s x s box."""
    u = s / 24
    w = w or 2 * u
    P = lambda x, y: (cx + (x - 12) * u, cy + (y - 12) * u)
    L = lambda pts: cv.line([P(*p) for p in pts], color, w)
    if name == "star":
        cv.poly(star_pts(cx, cy + 0.6 * u, 10.5 * u), accent or STAR)
    elif name == "back":
        L([(19, 12), (5, 12)]); L([(11, 6), (5, 12), (11, 18)])
    elif name == "check":
        L([(5, 12.5), (10, 17.5), (19, 7)])
    elif name == "lock":
        cv.rr(cx - 6.5 * u, cy - 1 * u, 13 * u, 10 * u, 2.5 * u, fill=color)
        cv.arc(cx, cy - 2 * u, 4.2 * u, 180, 360, color, w)
        L([(7.8, 10), (7.8, 11)]); L([(16.2, 10), (16.2, 11)])
    elif name == "reroll":
        cv.arc(cx, cy, 7.5 * u, 40, 320, color, w)
        cv.poly([P(15.2, 3.2), P(20.2, 6.2), P(14.6, 8.9)], color)
    elif name == "replay":
        cv.arc(cx, cy, 7.5 * u, -60, 220, color, w)
        cv.poly([P(4.2, 3.6), P(9.8, 5.4), P(5.2, 9.6)], color)
    elif name == "bars":
        for i, hgt in enumerate((6, 10, 14)):
            cv.rr(cx + (-9 + i * 7) * u, cy + (7 - hgt) * u, 4.6 * u, hgt * u, 1.4 * u, fill=color)
    elif name == "quests":
        cv.rr(cx - 7 * u, cy - 8 * u, 14 * u, 17 * u, 2.5 * u, stroke=color, sw=w)
        L([(9.5, 9), (14.5, 9)]); L([(9.5, 13), (14.5, 13)])
        cv.rr(cx - 3 * u, cy - 10 * u, 6 * u, 3.6 * u, 1.2 * u, fill=color)
    elif name == "faceplate":
        cv.rr(cx - 9.5 * u, cy - 5.5 * u, 19 * u, 11 * u, 4 * u, stroke=color, sw=w)
        cv.rr(cx - 4 * u, cy - 2.6 * u, 8 * u, 5.2 * u, 1.2 * u, fill=accent or color)
    elif name == "settings":
        for yy, kx in ((7, 15), (12, 9), (17, 14)):
            L([(4, yy), (20, yy)])
            cv.ell(*P(kx, yy), 2.6 * u, fill=accent or color)
    elif name == "clock":
        cv.ell(cx, cy, 8.5 * u, stroke=color, sw=w)
        L([(12, 7.5), (12, 12), (15.2, 14)])
    elif name == "chain":
        cv.ell(cx - 3.6 * u, cy, 5.2 * u, stroke=color, sw=w)
        cv.ell(cx + 3.6 * u, cy, 5.2 * u, stroke=accent or color, sw=w)
    elif name == "trophy":
        cv.rr(cx - 5 * u, cy - 8 * u, 10 * u, 9 * u, 3.5 * u, fill=color)
        cv.arc(cx - 5 * u, cy - 4.5 * u, 3 * u, 90, 270, color, w)
        cv.arc(cx + 5 * u, cy - 4.5 * u, 3 * u, -90, 90, color, w)
        L([(12, 13), (12, 17)]); L([(8, 18.5), (16, 18.5)])
    elif name == "egg":
        cv.poly(egg_pts(cx, cy, 6.6 * u, 8.6 * u), accent or color)
    elif name == "target":
        cv.ell(cx, cy, 8.5 * u, stroke=color, sw=w)
        cv.ell(cx, cy, 3.2 * u, fill=accent or color)
    elif name == "close":
        L([(6, 6), (18, 18)]); L([(18, 6), (6, 18)])
    elif name == "cart":
        cv.rr(cx - 8 * u, cy - 5 * u, 16 * u, 12 * u, 3 * u, stroke=color, sw=w)
        cv.arc(cx, cy - 5 * u, 4 * u, 180, 360, color, w)


def egg_pts(cx, cy, rx, ry, n=40):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        s, c = math.sin(a), math.cos(a)
        k = 1 - 0.18 * (-s)  # narrower at the top
        pts.append((cx + rx * c * (k if s < 0 else 1), cy + ry * s))
    return pts


TIERS = [("#35A8FF", "#0B5FD0", "I"), ("#FFA51F", "#D15A00", "II"), ("#3FE06B", "#0E8F3A", "III"),
         ("#FF6FB1", "#C22470", "IV"), ("#B78BFF", "#6A35D9", "V")]


def egg_ball(cv: Cv, cx, cy, r, tier, label=True):
    """Glossy round egg used on the board (tier 1..5)."""
    hi, lo, name = TIERS[tier - 1]
    z = cv.z
    d = int(r * 2 * z) + 4
    ys, xs = np.mgrid[0:d, 0:d].astype(np.float32)
    c = d / 2
    dist = np.sqrt((xs - c) ** 2 + (ys - c) ** 2) / (r * z)
    lit = np.clip(1 - np.sqrt((xs - c * 0.72) ** 2 + (ys - c * 0.62) ** 2) / (r * z * 1.55), 0, 1)
    arr = ramp(lit, [(0, hx(lo)), (0.55, hx(hi)), (1, mix(hi, "#FFFFFF", .45))])
    arr[..., 3] = (np.clip((1 - dist) * r * z * 0.9, 0, 1) * 255).astype(np.uint8)
    cv.paste(Image.fromarray(arr, "RGBA"), cx * z - d / 2, cy * z - d / 2, raw=True)
    cv.ell(cx - r * .32, cy - r * .42, r * .30, r * .19, fill=(255, 255, 255, 150))
    cv.ell(cx, cy, r, stroke=mix(lo, "#000000", .35, 190), sw=max(1, r * .06))
    if label and r >= 9:
        cv.text(cx, cy + r * .06, name, "xb", r * (.95 if len(name) < 3 else .8), (255, 255, 255, 235), "mm")
