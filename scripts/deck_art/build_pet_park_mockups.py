"""Pet Park v1 concept mockups (PET-PARK-V1-SCOPE-2026-11-13.md). Concept paintings, not captures.

Run: python scripts/deck_art/build_pet_park_mockups.py
Writes artifacts/pet-park-2026-11-13/{01-park-overview,02-park-hud-phone,02-park-hud-phone@2x,03-park-location}.png
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

from common import font

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts" / "pet-park-2026-11-13"
MAP = ROOT / "artifacts" / "world1-mockup" / "v7" / "14-top-down-map.png"
SS = 2
INK = (24, 30, 44)
WHITE = (255, 255, 255)
GLASS = (22, 26, 38, 200)
STAR = (255, 204, 64)


def h(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + ((c[3],) if len(c) > 3 else ())


class P:
    def __init__(self, w, hh, bg=(0, 0, 0), ss=SS, base=None):
        self.w, self.h, self.ss = w, hh, ss
        self.im = base.resize((w * ss, hh * ss), Image.LANCZOS).convert("RGB") if base else Image.new("RGB", (w * ss, hh * ss), bg)
        self.d = ImageDraw.Draw(self.im, "RGBA")

    def ell(self, cx, cy, rx, ry=None, fill=None, outline=None, width=1.0):
        z = self.ss
        ry = rx if ry is None else ry
        self.d.ellipse([(cx - rx) * z, (cy - ry) * z, (cx + rx) * z, (cy + ry) * z], fill=fill, outline=outline, width=max(1, int(width * z)))

    def rr(self, x, y, w, hh, r, fill=None, outline=None, width=1.0):
        z = self.ss
        self.d.rounded_rectangle([x * z, y * z, (x + w) * z, (y + hh) * z], min(r, w / 2, hh / 2) * z, fill=fill, outline=outline, width=max(1, int(width * z)))

    def line(self, pts, fill, width=2.0):
        z = self.ss
        self.d.line([(a * z, b * z) for a, b in pts], fill=fill, width=max(1, int(width * z)), joint="curve")

    def dash(self, pts, fill, width=2.0, on=7, off=6):
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            n = math.hypot(x1 - x0, y1 - y0)
            t = 0.0
            while t < n:
                a, b = t / n, min(n, t + on) / n
                self.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill, width)
                t += on + off

    def poly(self, pts, fill, outline=None):
        z = self.ss
        self.d.polygon([(a * z, b * z) for a, b in pts], fill=fill, outline=outline)

    def text(self, x, y, s, key="b", size=14, fill=WHITE, anchor="la"):
        self.d.text((x * self.ss, y * self.ss), s, font=font(key, size * self.ss), fill=fill, anchor=anchor)

    def tw(self, s, key="b", size=14):
        return font(key, size * self.ss).getlength(s) / self.ss

    def vgrad(self, y0, y1, c0, c1):
        z = self.ss
        for i in range(int(y0 * z), int(y1 * z)):
            t = (i - y0 * z) / max(1, (y1 - y0) * z)
            self.d.line([(0, i), (self.w * z, i)], fill=tuple(int(c0[k] + (c1[k] - c0[k]) * t) for k in range(3)))

    def star(self, cx, cy, r, fill=STAR):
        pts = []
        for i in range(10):
            a = math.radians(-90 + i * 36)
            rr = r if i % 2 == 0 else r * 0.46
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        self.poly(pts, fill)

    def out(self, scale=1):
        return self.im.resize((self.w * scale, self.h * scale), Image.LANCZOS)


# ------------------------------------------------------------------ actors
def bear(p, cx, fy, s, top, bot, pose="stand", flip=1, hop=0.0, charm=None):
    """Plush Bear: two-colour body (primary on top, secondary below). s = head radius in px."""
    top, bot = h(top), h(bot)
    dark = (30, 26, 40)
    p.ell(cx, fy, s * 1.15, s * 0.3, fill=(0, 40, 20, 60))
    fy -= hop * s
    if pose == "sleep":
        p.ell(cx + 0.7 * s * flip, fy - 0.42 * s, s * 0.95, s * 0.48, fill=bot)
        p.ell(cx + 1.35 * s * flip, fy - 0.2 * s, s * 0.3, s * 0.22, fill=shade(bot, 0.94))
        hx_, hy = cx - 0.45 * s * flip, fy - 0.68 * s
        for e in (-1, 1):
            p.ell(hx_ + e * 0.72 * s, hy - 0.66 * s, s * 0.34, fill=top)
            p.ell(hx_ + e * 0.72 * s, hy - 0.66 * s, s * 0.18, fill=bot)
        p.ell(hx_, hy, s, s * 0.84, fill=top)
        p.ell(hx_, hy + 0.3 * s, s * 0.3, s * 0.2, fill=shade(bot, 1.06))
        for e in (-1, 1):
            p.line([(hx_ + e * 0.4 * s - 0.14 * s, hy), (hx_ + e * 0.4 * s, hy + 0.06 * s), (hx_ + e * 0.4 * s + 0.14 * s, hy)], dark, max(1.2, s * 0.07))
        p.ell(hx_, hy + 0.22 * s, s * 0.07, s * 0.05, fill=dark)
        return
    for e in (-1, 1):  # feet
        p.ell(cx + e * 0.34 * s, fy - 0.12 * s, s * 0.3, s * 0.2, fill=shade(bot, 0.93))
    p.ell(cx, fy - 0.78 * s, s * 0.64, s * 0.72, fill=bot)
    p.ell(cx, fy - 0.98 * s, s * 0.6, s * 0.46, fill=top)  # gradient hint
    for e in (-1, 1):  # arms
        up = -0.5 * s if pose == "cheer" else 0
        p.ell(cx + e * 0.68 * s, fy - 0.92 * s + up, s * 0.2, s * 0.32, fill=top)
    hy = fy - 1.82 * s
    for e in (-1, 1):
        p.ell(cx + e * 0.74 * s, hy - 0.68 * s, s * 0.36, fill=top)
        p.ell(cx + e * 0.74 * s, hy - 0.68 * s, s * 0.2, fill=bot)
    p.ell(cx, hy, s, s * 0.9, fill=top)
    p.ell(cx - 0.3 * s, hy - 0.42 * s, s * 0.42, s * 0.22, fill=(255, 255, 255, 70))
    look = 0.1 * s * flip
    for e in (-1, 1):
        p.ell(cx + e * 0.4 * s + look, hy + 0.02 * s, s * 0.13, s * 0.19, fill=dark)
        p.ell(cx + e * 0.4 * s + look - 0.04 * s, hy - 0.06 * s, s * 0.045, fill=WHITE)
    p.ell(cx + look, hy + 0.32 * s, s * 0.3, s * 0.21, fill=shade(bot, 1.06))
    p.ell(cx + look, hy + 0.25 * s, s * 0.08, s * 0.055, fill=dark)
    if charm:
        p.star(cx, hy - 1.35 * s, s * 0.24, h(charm))


def avatar(p, cx, fy, s, shirt, pants, skin="#F2D3B1", sit=False, arm_up=0, hair=None):
    """Blocky Roblox-style stand-in. s = head width in px; about 4.3 s tall."""
    shirt, pants, skin = h(shirt), h(pants), h(skin)
    p.ell(cx, fy, s * 0.95, s * 0.26, fill=(0, 40, 20, 60))
    leg_h = s * (0.9 if sit else 1.55)
    for e in (-1, 1):
        p.rr(cx + (e * 0.26 - 0.24) * s, fy - leg_h, s * 0.48, leg_h, s * 0.08, fill=shade(pants, 1.0 if e < 0 else 0.9))
    ty = fy - leg_h - s * 1.5
    p.rr(cx - 0.62 * s, ty, s * 1.24, s * 1.52, s * 0.1, fill=shirt)
    for e in (-1, 1):
        if e == arm_up:
            p.rr(cx + e * 0.62 * s - (0.4 * s if e < 0 else 0), ty - 0.85 * s, s * 0.4, s * 1.3, s * 0.08, fill=skin)
        else:
            p.rr(cx + e * 0.62 * s - (0.4 * s if e < 0 else 0), ty + 0.02 * s, s * 0.4, s * 1.4, s * 0.08, fill=shade(shirt, 0.9))
    p.rr(cx - 0.5 * s, ty - 1.02 * s, s, s, s * 0.22, fill=skin)
    if hair:
        p.rr(cx - 0.56 * s, ty - 1.12 * s, s * 1.12, s * 0.42, s * 0.2, fill=h(hair))
    for e in (-1, 1):
        p.ell(cx + e * 0.2 * s, ty - 0.56 * s, s * 0.06, s * 0.09, fill=INK)
    p.line([(cx - 0.16 * s, ty - 0.3 * s), (cx, ty - 0.24 * s), (cx + 0.16 * s, ty - 0.3 * s)], INK, max(1.0, s * 0.05))
    return ty - 1.1 * s  # top of head


def bubble(p, cx, by, s, size=15, quick=False):
    w = p.tw(s, "b", size) + 22 + (18 if quick else 0)
    hh = size + 16
    x, y = cx - w / 2, by - hh
    p.rr(x, y, w, hh, hh / 2, fill=(255, 255, 255, 245), outline=(20, 30, 50, 60))
    p.poly([(cx - 6, by - 1), (cx + 6, by - 1), (cx, by + 8)], (255, 255, 255, 245))
    tx = x + 11
    if quick:
        p.star(tx + 6, y + hh / 2, 7)
        tx += 18
    p.text(tx, y + hh / 2, s, "b", size, INK, "lm")


def tag(p, x, y, s, to=None, size=13, anchor="l"):
    w = p.tw(s, "b", size) + 18
    if anchor == "r":
        x -= w
    if to:
        p.line([(x + w / 2, y + 12), to], (255, 255, 255, 190), 1.5)
        p.ell(to[0], to[1], 3.2, fill=WHITE)
    p.rr(x, y, w, size + 12, 8, fill=GLASS, outline=(255, 255, 255, 60))
    p.text(x + 9, y + (size + 12) / 2, s, "b", size, WHITE, "lm")


def blossom(p, x, y, s):
    p.rr(x - s * 0.08, y - s * 0.9, s * 0.16, s * 0.9, 2, fill=h("#8A6248"))
    for dx, dy, r in ((-0.35, -1.0, 0.42), (0.3, -1.05, 0.46), (0, -1.35, 0.44)):
        p.ell(x + dx * s, y + dy * s, r * s, r * s * 0.85, fill=h("#F3B6D8"))
    p.ell(x - 0.1 * s, y - 1.4 * s, 0.22 * s, 0.14 * s, fill=(255, 255, 255, 90))


def bench(p, x, y, w):
    p.rr(x - w / 2, y - 26, w, 9, 3, fill=h("#B9824F"))
    p.rr(x - w / 2, y - 44, w, 12, 3, fill=h("#C99561"))
    for e in (-1, 1):
        p.rr(x + e * (w / 2 - 10) - 6, y - 46, 12, 46, 3, fill=h("#EEF1F6"))


def lamp(p, x, y, s=1.0):
    p.rr(x - 5 * s, y - 62 * s, 10 * s, 62 * s, 3, fill=h("#EEF1F6"))
    p.rr(x - 9 * s, y - 8 * s, 18 * s, 8 * s, 2, fill=h("#DADFE8"))
    p.ell(x, y - 72 * s, 20 * s, fill=(255, 244, 190, 60))
    p.ell(x, y - 72 * s, 12 * s, fill=h("#FFF3C4"))
    p.rr(x - 8 * s, y - 62 * s, 16 * s, 4 * s, 2, fill=h("#E2B93B"))


def backdrop(p, horizon, w):
    p.vgrad(0, horizon, h("#5FB4F2"), h("#BFE6FF"))
    for cx, cy, rw in ((220, 70, 150), (1000, 50, 190), (1420, 110, 130), (620, 120, 110)):
        k = w / 1600
        for dx, r in ((-0.4, 0.42), (0, 0.6), (0.42, 0.4)):
            p.ell((cx + dx * rw) * k, cy * k, rw * r * k, rw * r * 0.36 * k, fill=(255, 255, 255, 215))
    k = w / 1600
    for pts, c in (
        ([(0, 300), (0, 190), (110, 150), (240, 205), (330, 170), (470, 250), (520, 300)], "#A9AE9B"),
        ([(980, 300), (1080, 215), (1210, 160), (1330, 205), (1450, 140), (1600, 190), (1600, 300)], "#A3A996"),
        ([(60, 300), (150, 205), (260, 240), (360, 300)], "#8FB36B"),
        ([(1120, 300), (1250, 215), (1400, 250), (1520, 205), (1600, 240), (1600, 300)], "#86B25F"),
    ):
        p.poly([(x * k, horizon - (300 - y) * k) for x, y in pts], h(c))


# ------------------------------------------------------------------ 01 overview
def overview():
    W, H = 1600, 900
    p = P(W, H, h("#4FBF4A")[:3])
    backdrop(p, 300, W)
    p.vgrad(300, H, h("#57C44E"), h("#3FAE45"))
    # arrival path running behind the park (arrival dais on the right, bridge and hub to the left)
    path = [(1600, 372), (1380, 348), (1150, 318), (860, 314), (560, 322), (250, 318), (0, 300)]
    p.poly(path + [(0, 330), (250, 352), (560, 356), (860, 348), (1150, 354), (1380, 388), (1600, 420)], h("#E2C48B"))
    for x, y, s in ((120, 308, 70), (470, 300, 62), (1010, 300, 66), (1500, 330, 84), (720, 296, 54)):
        blossom(p, x, y, s)
    lamp(p, 1330, 352, 0.9)
    # park lawn + low marble kerb
    cx, cy, rx, ry = 800, 590, 590, 235
    p.ell(cx, cy + 10, rx + 20, ry + 16, fill=(20, 90, 40, 70))
    p.ell(cx, cy, rx + 16, ry + 12, fill=h("#F4F6FA"))
    p.ell(cx, cy + 5, rx + 16, ry + 12, outline=h("#C9D0DC"), width=3)
    p.ell(cx, cy, rx, ry, fill=h("#7EDB66"))
    p.ell(cx, cy + 30, rx - 80, ry - 60, fill=(150, 235, 120, 90))
    # two open gateways (kerb gaps), each with star-orb posts
    for gx, gy, gw in ((1150, 380, 110), (236, 500, 0)):
        if gw:
            p.poly([(gx - gw / 2, gy - 26), (gx + gw / 2, gy - 12), (gx + gw / 2 - 6, gy + 30), (gx - gw / 2 - 6, gy + 18)], h("#E2C48B"))
            lamp(p, gx - gw / 2 - 12, gy + 6, 0.8)
            lamp(p, gx + gw / 2 + 10, gy + 20, 0.8)
    p.poly([(196, 520), (232, 470), (262, 480), (232, 548)], h("#E2C48B"))
    lamp(p, 214, 470, 0.8)
    lamp(p, 226, 566, 0.8)
    # flowers inside the kerb
    for i in range(46):
        a = math.radians(i * 7.83 + 11)
        if 0.15 < (a % (2 * math.pi)) < 6.2:
            fx, fy = cx + math.cos(a) * (rx - 16), cy + math.sin(a) * (ry - 12)
            if abs(fx - 1150) < 90 and fy < 440 or fx < 270:
                continue
            p.ell(fx, fy, 4.5, 3.2, fill=h(("#FF8FB8", "#FFE066", "#FFFFFF", "#9FD8FF")[i % 4]))
    # ---- furniture (back to front)
    # ball post: the park ball always comes home here
    p.ell(800, 420, 46, 14, fill=h("#F4F6FA"))
    p.rr(782, 384, 36, 36, 6, fill=h("#EEF1F6"))
    p.rr(776, 378, 48, 10, 4, fill=h("#E2B93B"))
    p.ell(800, 364, 15, fill=h("#F5B77C"))
    p.ell(795, 359, 5, 4, fill=(255, 255, 255, 120))
    # picnic table (existing PicnicEast station)
    p.rr(300, 470, 150, 12, 4, fill=h("#B9824F"))
    p.rr(322, 440, 106, 14, 4, fill=h("#C99561"))
    p.rr(300, 498, 150, 10, 4, fill=h("#B9824F"))
    for x in (318, 420):
        p.rr(x, 452, 12, 52, 3, fill=h("#EEF1F6"))
    bench(p, 1245, 520, 150)
    bench(p, 1300, 640, 130)

    bears = {  # owner colour pairs: each player's Bear keeps its own two colours
        "a": ("#FFE45C", "#FF8FC7"), "b": ("#8FE3FF", "#5B7BFF"), "c": ("#C9A6FF", "#FF9AD5"), "d": ("#B8F27A", "#2FC7A1"),
        "e": ("#FFFFFF", "#9AD0FF"), "f": ("#FFB067", "#FF5E7E"), "g": ("#FF9AD5", "#8A5BFF"), "h": ("#FFF1B8", "#F2A23A"),
    }
    draw = []  # (y, fn)
    # players
    draw.append((484, lambda: avatar(p, 374, 484, 32, "#3B82F6", "#1F2A44", hair="#5A3A22", sit=True)))
    draw.append((500, lambda: avatar(p, 610, 500, 34, "#F59E0B", "#374151", arm_up=1, hair="#222222")))
    draw.append((516, lambda: avatar(p, 1218, 516, 32, "#10B981", "#1F2A44", sit=True, hair="#C2410C")))
    draw.append((518, lambda: avatar(p, 1280, 516, 32, "#EC4899", "#3F3F46", sit=True, hair="#FDE68A")))
    draw.append((560, lambda: avatar(p, 940, 474, 33, "#8B5CF6", "#111827", hair="#111827")))
    draw.append((562, lambda: avatar(p, 1016, 480, 33, "#EF4444", "#1E3A8A", hair="#7C2D12")))
    draw.append((700, lambda: avatar(p, 330, 668, 36, "#14B8A6", "#27272A", hair="#F5F5F4")))
    draw.append((760, lambda: avatar(p, 1160, 770, 37, "#F97316", "#0F172A", arm_up=-1, hair="#3F3F46")))
    # fetch: ball in flight, two pets chasing
    draw.append((575, lambda: bear(p, 800, 575, 20, *bears["a"], flip=1, hop=0.35, charm="#FF8FC7")))
    draw.append((600, lambda: bear(p, 738, 602, 20, *bears["b"], flip=1, hop=0.1)))
    # greet / coo pair
    draw.append((566, lambda: bear(p, 1032, 566, 19, *bears["g"], flip=1)))
    draw.append((567, lambda: bear(p, 1086, 567, 19, *bears["h"], flip=-1, charm="#F2A23A")))
    # nap pile on the cushion
    draw.append((684, lambda: (p.ell(500, 690, 96, 34, fill=h("#F7A8CC")), p.ell(500, 684, 84, 27, fill=h("#FFC4DE")))))
    draw.append((690, lambda: bear(p, 470, 692, 21, *bears["c"], pose="sleep", flip=1)))
    draw.append((700, lambda: bear(p, 540, 702, 21, *bears["d"], pose="sleep", flip=-1)))
    # tug
    draw.append((705, lambda: bear(p, 880, 705, 21, *bears["e"], flip=1)))
    draw.append((706, lambda: bear(p, 1010, 706, 21, *bears["f"], flip=-1)))
    for _, fn in sorted(draw, key=lambda t: t[0]):
        fn()
    # tug rope (drawn over both pets' hands)
    p.line([(896, 686), (945, 692), (994, 687)], h("#D9A066"), 4)
    p.rr(938, 683, 14, 14, 3, fill=h("#FF5E7E"))
    # fetch arc from the thrower's raised hand
    arc = [(646 + t * 190, 372 - math.sin(t * math.pi) * 78 + t * 150) for t in [i / 12 for i in range(13)]]
    p.dash(arc[:9], (255, 255, 255, 200), 2.2)
    bx, by = arc[8]
    p.ell(bx, by, 11, fill=h("#F5B77C"))
    p.ell(bx - 3, by - 3, 4, 3, fill=(255, 255, 255, 130))
    for i, (zx, zy) in enumerate(((520, 628), (536, 610), (556, 596))):
        p.text(zx, zy, "z", "xb", 13 + i * 3, (255, 255, 255, 220))
    for nx, ny in ((1058, 500),):
        p.ell(nx - 5, ny, 6, fill=h("#FF7BAC"))
        p.ell(nx + 5, ny, 6, fill=h("#FF7BAC"))
        p.poly([(nx - 11, ny + 2), (nx + 11, ny + 2), (nx, ny + 15)], h("#FF7BAC"))
    # chat: one typed bubble (Roblox filtered chat), one quick-chat phrase
    bubble(p, 940, 316, "omg they're friends", 15)
    bubble(p, 1160, 590, "Go go go!", 15, quick=True)
    bubble(p, 330, 500, "So sleepy", 15, quick=True)
    # callouts
    tag(p, 300, 212, "FETCH: throw the park ball, every nearby pet chases", (700, 352))
    tag(p, 1150, 250, "GREET: two pets meet, coo and bump noses", (1070, 520))
    tag(p, 96, 600, "NAP PILE: idle pets curl up together", (440, 676))
    tag(p, 730, 800, "TUG: two pets, one rope, nobody loses", (945, 706))
    tag(p, 690, 250, "BALL POST: the ball always returns here", (800, 350))
    tag(p, 1300, 430, "BENCHES: sit and chat", (1250, 478))
    tag(p, 1196, 318, "OPEN GATEWAY, ankle-high kerb", (1150, 384))
    tag(p, 60, 372, "Existing picnic table", (318, 446))
    # title
    p.rr(28, 24, 560, 74, 16, fill=GLASS, outline=(255, 255, 255, 60))
    p.text(48, 36, "PET PARK", "xb", 26, WHITE)
    p.star(204, 52, 11)
    p.text(48, 68, "Concept, east picnic lawn. 8 players, 8 pets. Not a capture.", "m", 15, (220, 228, 240))
    p.out().save(OUT / "01-park-overview.png")


# ------------------------------------------------------------------ 02 phone HUD
def round_btn(p, cx, cy, r, label, primary=False, icon=None):
    p.ell(cx, cy + 2, r, fill=(0, 0, 0, 60))
    p.ell(cx, cy, r, fill=(255, 196, 64, 240) if primary else GLASS, outline=(255, 255, 255, 150 if primary else 80), width=1.5)
    col = INK if primary else WHITE
    if icon == "ball":
        p.ell(cx, cy - 7, 9, fill=h("#F5B77C") if not primary else h("#FFFFFF"), outline=col, width=1.5)
        p.line([(cx - 14, cy - 2), (cx - 20, cy - 8)], col, 1.6)
        p.line([(cx - 15, cy - 9), (cx - 21, cy - 15)], col, 1.6)
    elif icon == "call":
        for e in (-1, 1):
            p.ell(cx + e * 6, cy - 12, 3.4, fill=col)
            p.ell(cx + e * 11, cy - 6, 3, fill=col)
        p.ell(cx, cy - 3, 7, 5.5, fill=col)
    elif icon == "emote":
        p.ell(cx, cy - 6, 10, outline=col, width=1.6)
        for e in (-1, 1):
            p.ell(cx + e * 3.6, cy - 8, 1.4, fill=col)
        p.line([(cx - 4.5, cy - 3.5), (cx, cy - 1), (cx + 4.5, cy - 3.5)], col, 1.4)
    p.text(cx, cy + r - 13, label, "b", 10, col, "mm")


def hud():
    W, H = 812, 354
    p = P(W, H, (0, 0, 0), ss=4)
    backdrop(p, 150, W)
    p.vgrad(150, H, h("#57C44E"), h("#3FAE45"))
    for x, y, s in ((90, 152, 40), (700, 156, 46), (490, 148, 30)):
        blossom(p, x, y, s)
    # park lawn seen from inside the gateway
    p.ell(406, 300, 560, 150, fill=h("#F4F6FA"))
    p.ell(406, 304, 548, 143, fill=h("#7EDB66"))
    p.ell(406, 190, 60, 8, fill=h("#F4F6FA"))  # ball post base (far)
    p.rr(398, 168, 16, 20, 3, fill=h("#EEF1F6"))
    p.ell(406, 162, 7, fill=h("#F5B77C"))
    bench(p, 610, 206, 70)
    avatar(p, 600, 204, 14, "#10B981", "#1F2A44", sit=True, hair="#C2410C")
    # other players and pets
    avatar(p, 312, 214, 15, "#8B5CF6", "#111827", hair="#111827")
    bear(p, 258, 222, 9, "#FF9AD5", "#8A5BFF")
    bear(p, 282, 223, 9, "#FFF1B8", "#F2A23A", flip=-1)
    bubble(p, 320, 150, "hi!! love the hat", 10)
    bear(p, 520, 250, 12, "#8FE3FF", "#5B7BFF", flip=-1, hop=0.25)
    bear(p, 206, 244, 12, "#B8F27A", "#2FC7A1", pose="sleep")
    p.text(226, 214, "z", "xb", 10, (255, 255, 255, 220))
    # the local player (back view stand-in) and their own pet with the "yours" ring
    p.ell(452, 284, 26, 8, outline=(255, 255, 255, 230), width=2)
    bear(p, 452, 284, 16, "#FFE45C", "#FF8FC7", flip=1, charm="#FF8FC7")
    p.poly([(446, 204), (458, 204), (452, 213)], WHITE)
    avatar(p, 372, 294, 24, "#F59E0B", "#374151", arm_up=1, hair="#222222")
    arc = [(394 + t * 120, 198 - math.sin(t * math.pi) * 36 + t * 30) for t in [i / 10 for i in range(11)]]
    p.dash(arc[:8], (255, 255, 255, 210), 1.6, 5, 4)
    p.ell(arc[7][0], arc[7][1], 6, fill=h("#F5B77C"))

    # --- Roblox-owned zones (ghosted): top-left controls, chat window, thumbstick, jump
    for i in range(2):
        p.rr(14 + i * 50, 10, 42, 42, 12, fill=(18, 20, 28, 170))
    p.line([(26, 25), (44, 25)], WHITE, 1.6)
    p.line([(26, 31), (44, 31)], WHITE, 1.6)
    p.line([(26, 37), (44, 37)], WHITE, 1.6)
    p.rr(76, 22, 18, 13, 4, outline=WHITE, width=1.5)
    p.poly([(80, 35), (86, 35), (80, 40)], WHITE)
    p.rr(10, 62, 238, 64, 8, fill=(18, 20, 28, 120))
    p.text(18, 68, "Mika_plays:", "b", 10, h("#9FD8FF"))
    p.text(80, 68, "hi!! love the hat", "m", 10, WHITE)
    p.text(18, 83, "You:", "b", 10, h("#FFE066"))
    p.text(43, 83, "Play fetch?", "m", 10, WHITE)
    p.text(18, 100, "Roblox chat (filtered). Tap to type", "m", 9, (200, 208, 222))
    p.ell(96, 268, 46, fill=(255, 255, 255, 34), outline=(255, 255, 255, 90), width=1.5)
    p.ell(96, 268, 19, fill=(255, 255, 255, 80))
    p.ell(736, 284, 34, fill=(255, 255, 255, 34), outline=(255, 255, 255, 90), width=1.5)
    p.text(736, 284, "JUMP", "b", 9, (255, 255, 255, 190), "mm")

    # --- Pet Park HUD (all at y >= 60)
    # place chip, top centre
    s = "PET PARK"
    cw = p.tw(s, "xb", 12) + p.tw("6 pets here", "m", 11) + 50
    p.rr(406 - cw / 2, 62, cw, 26, 13, fill=GLASS, outline=(255, 255, 255, 70))
    p.ell(406 - cw / 2 + 14, 75, 4, fill=h("#7EDB66"))
    p.text(406 - cw / 2 + 24, 75, s, "xb", 12, WHITE, "lm")
    p.text(406 - cw / 2 + 32 + p.tw(s, "xb", 12), 75, "6 pets here", "m", 11, (214, 222, 236), "lm")
    # wallet + play-date card, top right
    p.rr(726, 62, 72, 26, 13, fill=GLASS, outline=(255, 255, 255, 70))
    p.star(742, 75, 7.5)
    p.text(790, 75, "23", "xb", 14, WHITE, "rm")
    p.rr(598, 94, 200, 58, 12, fill=GLASS, outline=(255, 255, 255, 70))
    p.text(610, 101, "PLAY DATE", "xb", 10, h("#FFD66B"))
    p.text(786, 101, "+4", "xb", 11, WHITE, "ra")
    p.star(764, 107, 5.5)
    p.text(610, 116, "Play 3 park games", "b", 12, WHITE)
    p.rr(610, 136, 140, 7, 3.5, fill=(255, 255, 255, 50))
    p.rr(610, 136, 47, 7, 3.5, fill=h("#7EDB66"))
    p.text(786, 139, "1 / 3", "b", 10, (220, 228, 240), "rm")
    # verbs: arc above and left of the Roblox jump button
    round_btn(p, 736, 204, 32, "THROW", primary=True, icon="ball")
    round_btn(p, 664, 232, 26, "CALL", icon="call")
    round_btn(p, 650, 296, 26, "EMOTE", icon="emote")
    # quick chat row, bottom centre, between thumbstick and verbs
    x = 180
    p.rr(x, 300, 44, 44, 14, fill=GLASS, outline=(255, 255, 255, 110), width=1.5)
    p.rr(x + 11, 313, 22, 15, 5, outline=WHITE, width=1.6)
    p.poly([(x + 15, 328), (x + 22, 328), (x + 15, 334)], WHITE)
    x += 52
    for i, s in enumerate(("Hi!", "Play fetch?", "Good pet!", "So cute!", "Bye!")):
        w = p.tw(s, "b", 12) + 24
        p.rr(x, 304, w, 36, 18, fill=(255, 255, 255, 240) if i == 1 else GLASS, outline=(255, 255, 255, 90))
        p.text(x + w / 2, 322, s, "b", 12, INK if i == 1 else WHITE, "mm")
        x += w + 6
    p.out().save(OUT / "02-park-hud-phone.png")
    p.out(2).save(OUT / "02-park-hud-phone@2x.png")

    # annotated copy: who owns which screen area
    q = P(W, H, ss=4, base=p.out())
    q.dash([(0, 60), (300, 60)], (255, 80, 110, 255), 1.4, 6, 4)
    q.rr(116, 30, 176, 20, 6, fill=(255, 80, 110, 235))
    q.text(124, 40, "Roblox controls: keep clear, y < 60", "b", 10, WHITE, "lm")
    for (x, y, w, hh, s) in ((8, 60, 242, 68, "Roblox chat window"), (46, 218, 100, 100, "Roblox thumbstick"), (698, 246, 76, 76, "Roblox jump")):
        q.rr(x, y, w, hh, 8, outline=(255, 80, 110, 255), width=1.2)
        q.rr(x, y + hh - 2, q.tw(s, "b", 9) + 12, 16, 5, fill=(255, 80, 110, 235))
        q.text(x + 6, y + hh + 6, s, "b", 9, WHITE, "lm")
    for (x, y, w, hh, s) in ((594, 58, 208, 98, "Wallet + Play date (44 px rows)"), (176, 296, 400, 52, "Quick chat: fixed phrases only"), (618, 168, 154, 158, "")):
        q.rr(x, y, w, hh, 10, outline=(90, 230, 255, 255), width=1.2)
        if s:
            q.rr(x, y - 16, q.tw(s, "b", 9) + 12, 16, 5, fill=(20, 120, 160, 240))
            q.text(x + 6, y - 8, s, "b", 9, WHITE, "lm")
    q.rr(540, 168, 76, 16, 5, fill=(20, 120, 160, 240))
    q.text(546, 176, "Verbs, 52-64 px", "b", 9, WHITE, "lm")
    q.out(2).save(OUT / "02-park-hud-phone-zones@2x.png")


# ------------------------------------------------------------------ 03 location on the island map
def location():
    base = Image.open(MAP).convert("RGB")
    W, H = base.size
    p = P(W, H, base=base)

    def px(x, z):  # Roblox X,Z -> map pixel, fitted to hub (-30,4) and arrival dais (96,66)
        return 697 + (x + 30) * 3.413, 437 + (z - 4) * 3.839

    route = [(96, 66), (60, 50), (32, 29), (14, 21), (-9, 21), (-20, 12), (-30, 4)]
    p.dash([px(*r) for r in route], (255, 255, 255, 235), 3, 10, 7)
    ax, ay = px(96, 66)
    p.ell(ax, ay, 9, fill=WHITE)
    cx, cy = px(45, 59)
    p.ell(cx, cy, 15 * 3.413 + 6, 11 * 3.839 + 6, outline=(255, 255, 255, 255), width=5)
    p.ell(cx, cy, 15 * 3.413, 11 * 3.839, fill=(255, 214, 64, 90), outline=h("#FFB020"), width=3)
    p.star(cx, cy, 13)
    bx, by = px(-30, 23)
    p.ell(bx, by, 26, 20, fill=(120, 200, 255, 90), outline=h("#3FA9F5"), width=3)
    tag(p, cx + 80, cy + 60, "A (recommended): PET PARK on the east picnic lawn, about 30 x 22 studs", (cx + 30, cy + 26), 15)
    tag(p, 1150, 560, "Arrival route (dashed) passes the gateway", (px(60, 50)[0] + 4, px(60, 50)[1]), 15)
    tag(p, 250, 640, "B (fallback): the existing Toy Lawn by the hub, about 12 x 10 studs", (bx - 10, by + 14), 15)
    tag(p, 250, 250, "Hub plaza: eggs, cradle, deck kiosk", px(-30, 4), 15)
    p.rr(28, 24, 640, 74, 16, fill=GLASS, outline=(255, 255, 255, 60))
    p.text(48, 36, "WHERE THE PARK LIVES", "xb", 26, WHITE)
    p.text(48, 68, "World 1 v7 top-down render with overlays. Positions are estimates until raycast in Studio.", "m", 15, (220, 228, 240))
    p.out().save(OUT / "03-park-location.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    overview()
    hud()
    location()
    print("wrote", sorted(f.name for f in OUT.glob("*.png")))
