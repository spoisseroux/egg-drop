"""Pocket Deck faceplates: 16 textures, 4 shared overlay textures, faceplates.json and a contact sheet.

Run: python scripts/deck_art/build_faceplates.py
Textures are 1024 x 499 (the plate rect is 1560 x 760 deck units) with the rounded corners baked into alpha.
All art is procedural and original: gradients, bubbles, chrome, gel, aurora, water and flare shapes.
"""
from __future__ import annotations

import colorsys
import json
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from common import ASSETS, DECK, MOCKUPS, contrast, hx, mix, rounded_mask, to_hex, ui_theme, INK

OUT = ASSETS / "faceplates"
W, H = 1024, 499
SS = 2
GW, GH = W * SS, H * SS
ASPECT = GW / GH
Yn, Xn = np.mgrid[0:GH, 0:GW].astype(np.float32)
X = Xn / (GW - 1)          # 0..1 across
Y = Yn / (GH - 1)          # 0..1 down
XA = X * ASPECT            # aspect-true x, so circles stay round (units of plate height)


def rgb(h):
    c = hx(h)
    return np.array([c[0], c[1], c[2]], dtype=np.float32) / 255


def solid(h):
    return np.ones((GH, GW, 3), dtype=np.float32) * rgb(h)


def ramp3(t, stops):
    ts = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.array([rgb(s[1]) for s in stops], dtype=np.float32)
    return np.stack([np.interp(t, ts, cols[:, i]) for i in range(3)], axis=-1).astype(np.float32)


def lin(angle_deg, lo=0.0, hi=1.0):
    a = math.radians(angle_deg)
    t = XA / ASPECT * math.cos(a) + Y * math.sin(a)
    mn, mx = min(0, math.cos(a)) + min(0, math.sin(a)), max(0, math.cos(a)) + max(0, math.sin(a))
    return np.clip(((t - mn) / (mx - mn) - lo) / (hi - lo), 0, 1)


def over(base, color, alpha):
    a = alpha[..., None] if alpha.ndim == 2 else alpha
    return base * (1 - a) + (rgb(color) if isinstance(color, str) else color) * a


def add(base, color, amount):
    return base + (rgb(color) if isinstance(color, str) else color) * amount[..., None]


def screen(base, color, amount):
    c = (rgb(color) if isinstance(color, str) else color) * amount[..., None]
    return 1 - (1 - base) * (1 - np.clip(c, 0, 1))


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def vnoise(cx, cy, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, cy), max(2, cx))).astype(np.float32)
    return np.clip(np.asarray(Image.fromarray(small, "F").resize((GW, GH), Image.BICUBIC)), 0, 1)


def fbm(cells, seed, octaves=4):
    out, amp, tot = np.zeros((GH, GW), dtype=np.float32), 1.0, 0.0
    for o in range(octaves):
        out += vnoise(int(cells * ASPECT * 2 ** o), int(cells * 2 ** o), seed + o * 17) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def blob(cx, cy, r, soft=1.0):
    """Soft round blob, cx in aspect-true units (0..ASPECT), cy 0..1, r in plate heights."""
    d = np.sqrt((XA - cx) ** 2 + (Y - cy) ** 2) / r
    return np.clip(1 - d, 0, 1) ** soft


def gloss_arc(img, strength=0.22, y0=-0.55, r=0.98):
    """Big Aero top-gloss: a lighter ellipse cap across the top of the plate."""
    d = np.sqrt(((X - 0.5) / 0.75) ** 2 + ((Y - y0) / r) ** 2)
    cap = smooth(1.0, 0.985, d) * (0.55 + 0.45 * (1 - Y))
    return over(img, "#FFFFFF", cap * strength)


def bubbles(img, items, tintc="#FFFFFF"):
    """Glass bubbles: faint body, bright rim, specular dot and a lower bounce crescent."""
    for cx, cy, r in items:
        d = np.sqrt((XA - cx) ** 2 + (Y - cy) ** 2) / r
        inside = smooth(1.0, 0.97, d)
        rim = np.exp(-((d - 0.93) / 0.06) ** 2) * inside
        light = np.clip(0.55 - ((XA - cx) / r * 0.5 + (Y - cy) / r * 0.8), 0, 1)
        img = over(img, tintc, inside * 0.07 + rim * (0.18 + 0.5 * light))
        spec = np.exp(-(((XA - (cx - r * .38)) / (r * .26)) ** 2 + ((Y - (cy - r * .42)) / (r * .16)) ** 2) * 2.2)
        img = over(img, "#FFFFFF", np.clip(spec * 0.95, 0, 1))
        bounce = np.exp(-((d - 0.72) / 0.10) ** 2) * np.clip(((XA - cx) / r * .6 + (Y - cy) / r * .8) - 0.35, 0, 1) * inside
        img = over(img, tintc, np.clip(bounce * 0.9, 0, 1))
    return img


def rand_bubbles(seed, n, rmin, rmax, grips=True):
    """Bubble positions biased to the grips and the top and bottom strips (the glass hides the middle)."""
    rng = np.random.default_rng(seed)
    out = []
    tries = 0
    while len(out) < n and tries < 4000:
        tries += 1
        x, y = rng.random() * ASPECT, rng.random()
        r = rmin + (rmax - rmin) * rng.random() ** 2.2
        hidden = 0.24 * ASPECT < x < 0.76 * ASPECT and 0.10 < y < 0.90
        if grips and hidden and rng.random() < 0.85:
            continue
        if all(math.hypot(x - a, y - b) > (r + c) * 0.9 for a, b, c in out):
            out.append((x, y, r))
    return out


def brushed(img, seed, amount=0.07, radial=None):
    rng = np.random.default_rng(seed)
    if radial is None:
        streak = (rng.random((GH, 24)) * 255).astype(np.uint8)
        s = np.asarray(Image.fromarray(streak).resize((GW, GH), Image.BILINEAR)).astype(np.float32) / 255
        fine = (rng.random((GH, 6)) * 255).astype(np.uint8)
        s = s * .6 + np.asarray(Image.fromarray(fine).resize((GW, GH), Image.BILINEAR)).astype(np.float32) / 255 * .4
    else:
        cx, cy = radial
        dist = np.sqrt((XA - cx) ** 2 + (Y - cy) ** 2)
        table = rng.random(4096).astype(np.float32)
        k = np.ones(9, dtype=np.float32) / 9
        table = np.convolve(table, k, mode="same") * 0.6 + rng.random(4096).astype(np.float32) * 0.4
        s = table[np.clip((dist * 1500).astype(np.int32), 0, 4095)]
    return img * (1 + (s - 0.5)[..., None] * 2 * amount)


def finish(img, vignette=0.10):
    v = 1 - vignette * (((X - 0.5) * 2) ** 2 * 0.6 + ((Y - 0.5) * 2) ** 2 * 0.4)
    img = np.clip(img * v[..., None], 0, 1)
    im = Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGB").resize((W, H), Image.LANCZOS).convert("RGBA")
    im.putalpha(rounded_mask(W, H, round(DECK["plateRadius"] * W / DECK["plate"][2])))
    return im


def base3(hi, mid, lo, angle=62):
    return ramp3(lin(angle), [(0, hi), (0.34, mid), (1, lo)])


# ------------------------------------------------------------------ the eight starters
def scout():
    img = base3("#69F4B3", "#23BF89", "#147863")
    sw = np.exp(-((Y - (0.70 - 0.42 * np.sin(X * 2.6 + 0.3))) / 0.16) ** 2)
    img = over(img, "#B9FFDD", sw * 0.20)
    return finish(gloss_arc(img, 0.20))


def pebble():
    img = base3("#B8DD9D", "#739877", "#48685E", 70)
    rng = np.random.default_rng(4)
    sp = Image.new("L", (GW, GH), 128)
    d = ImageDraw.Draw(sp)
    for _ in range(2600):
        x, y, r = rng.random() * GW, rng.random() * GH, 1.2 + rng.random() ** 3 * 6
        d.ellipse([x - r, y - r * .8, x + r, y + r * .8], fill=int(128 + (rng.random() - .5) * 150))
    s = np.asarray(sp.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255 - 0.5
    img = img * (1 + s[..., None] * 0.36)
    img = img * (0.96 + 0.08 * fbm(40, 9, 2))[..., None]
    return finish(img, 0.12)


def creek():
    img = base3("#7FF7EE", "#23B9D7", "#216892", 68)
    # clear plastic: you can see ribs and a board outline inside
    inner = Image.new("L", (GW, GH), 0)
    d = ImageDraw.Draw(inner)
    for i in range(-10, 40):
        x = i * GW / 26
        d.line([(x, 0), (x + GH * .5, GH)], fill=60, width=int(GH * .012))
    for x0, x1 in ((0.035, 0.205), (0.795, 0.965)):
        d.rounded_rectangle([GW * x0, GH * .16, GW * x1, GH * .84], GH * .09, outline=150, width=int(GH * .012))
        for j in range(4):
            yy = GH * (.30 + j * .13)
            d.line([(GW * (x0 + .02), yy), (GW * (x1 - .02), yy)], fill=90, width=int(GH * .006))
    for cx, cy in ((0.07, 0.28), (0.17, 0.72), (0.83, 0.26), (0.93, 0.74)):
        d.ellipse([GW * cx - GH * .03, GH * cy - GH * .03, GW * cx + GH * .03, GH * cy + GH * .03], outline=190, width=int(GH * .008))
    a = np.asarray(inner.filter(ImageFilter.GaussianBlur(GH * .004))).astype(np.float32) / 255
    img = over(img, "#0E4466", a * 0.42)
    img = over(img, "#E8FFFF", np.clip(np.roll(a, int(GH * .006), axis=0) - a, 0, 1) * 0.5)
    img = bubbles(img, rand_bubbles(31, 9, 0.02, 0.06), "#E8FFFF")
    return finish(gloss_arc(img, 0.26))


def ember():
    img = base3("#FFB568", "#F56444", "#AB3047", 75)
    img = brushed(img, 5, 0.085)
    band_ = np.exp(-((Y - 0.24) / 0.10) ** 2) * 0.22 + np.exp(-((Y - 0.80) / 0.05) ** 2) * 0.10
    img = over(img, "#FFE2B8", band_)
    return finish(img)


def canopy():
    img = base3("#BBF477", "#61BD44", "#27734A", 66)
    rng = np.random.default_rng(12)
    lay = Image.new("RGBA", (GW, GH), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay, "RGBA")
    for i in range(46):
        x, y = rng.random() * GW, rng.random() * GH
        L, ang = GH * (0.07 + rng.random() * 0.09), rng.random() * math.pi
        wd = L * 0.42
        c, s = math.cos(ang), math.sin(ang)
        pts = []
        for sign in (1, -1):
            for t in (np.linspace(0, 1, 14) if sign == 1 else np.linspace(1, 0, 14)):
                lx, ly = L * (2 * t - 1), sign * wd * math.sin(math.pi * t) ** 0.8
                pts.append((x + lx * c - ly * s, y + lx * s + ly * c))
        light = rng.random() < 0.5
        d.polygon(pts, fill=(220, 255, 170, 58) if light else (14, 70, 40, 62))
        d.line([(x - L * c, y - L * s), (x + L * c, y + L * s)], fill=(235, 255, 200, 70) if light else (10, 50, 30, 80), width=max(2, int(GH * .004)))
    a = np.asarray(lay).astype(np.float32) / 255
    img = img * (1 - a[..., 3:4]) + a[..., :3] * a[..., 3:4]
    return finish(gloss_arc(img, 0.14))


def honey():
    img = base3("#FFE49A", "#F2A73E", "#AF622F", 64)
    # honeycomb emboss
    sz = 0.15
    px_, py_ = XA / sz, Y / sz
    rx, ry = 1.0, math.sqrt(3)
    ax, ay = np.mod(px_, rx) - rx / 2, np.mod(py_, ry) - ry / 2
    bx, by = np.mod(px_ - rx / 2, rx) - rx / 2, np.mod(py_ - ry / 2, ry) - ry / 2
    use_a = (ax * ax + ay * ay) < (bx * bx + by * by)
    gx, gy = np.abs(np.where(use_a, ax, bx)), np.abs(np.where(use_a, ay, by))
    hexd = np.maximum(gx, gx * 0.5 + gy * math.sqrt(3) / 2)      # 0 at the cell centre, 0.5 on the wall
    wall = smooth(0.43, 0.49, hexd)
    img = img * (1 - wall * 0.13)[..., None]
    img = over(img, "#FFF8D8", np.exp(-((hexd - 0.40) / 0.025) ** 2) * 0.16)
    # pearl shimmer
    n = fbm(3, 21, 3)
    hue = (n * 1.7 + X * 0.6) % 1.0
    pearl = np.stack([0.5 + 0.5 * np.cos(2 * np.pi * (hue + o)) for o in (0.0, 0.33, 0.67)], axis=-1)
    img = img * 0.90 + (img * 0.6 + pearl * 0.4) * 0.10 + pearl * 0.035
    return finish(gloss_arc(img, 0.24))


def gloaming():
    edge = 0.56 + 0.34 * (Y - 0.5) + 0.035 * np.sin(Y * 5.0)
    left = ramp3(lin(70), [(0, "#8FF5E5"), (0.5, "#4A9FA7"), (1, "#2F7C8B")])
    right = ramp3(lin(70), [(0, "#6E7FC4"), (0.5, "#465489"), (1, "#2B3261")])
    t = smooth(-0.004, 0.004, X - edge)
    img = left * (1 - t[..., None]) + right * t[..., None]
    img = over(img, "#DFFFFA", np.exp(-((X - edge + 0.012) / 0.010) ** 2) * 0.55)
    img = over(img, "#141A3A", np.exp(-((X - edge - 0.012) / 0.012) ** 2) * 0.28)
    rng = np.random.default_rng(8)
    for _ in range(26):
        sx, sy, r = (0.62 + rng.random() * 0.38) * ASPECT, rng.random(), 0.004 + rng.random() * 0.006
        if sx / ASPECT < 0.58 + 0.34 * (sy - 0.5) + 0.06:
            continue
        img = over(img, "#E9F4FF", blob(sx, sy, r * 2.2, 2.0) * 0.9)
    return finish(gloss_arc(img, 0.20))


def copperleaf():
    img = base3("#FFBE83", "#DB7351", "#8D4456", 70)
    img = brushed(img, 14, 0.10, radial=(0.86 * ASPECT, 0.36))
    ang = np.arctan2(Y - 0.36, XA - 0.86 * ASPECT)
    sheen = np.abs(np.cos(ang * 2 + 0.6)) ** 10
    img = over(img, "#FFE8C8", sheen * 0.22)
    return finish(img)


# ------------------------------------------------------------------ eight new Y2K / Aero plates
def aqua_pop():
    img = ramp3(Y, [(0, "#1E9BF0"), (0.45, "#43C9F7"), (0.78, "#A6F0FF"), (1, "#E9FDFF")])
    img = over(img, "#FFFFFF", blob(0.18 * ASPECT, 1.15, 0.9, 1.4) * 0.35)
    img = over(img, "#7CFFD2", blob(0.9 * ASPECT, 1.1, 0.8, 1.6) * 0.30)
    wave = np.exp(-((Y - (0.62 + 0.10 * np.sin(X * 5.2 + 1.0))) / 0.045) ** 2)
    img = over(img, "#FFFFFF", wave * 0.22)
    img = bubbles(img, rand_bubbles(3, 26, 0.022, 0.13))
    return finish(gloss_arc(img, 0.30), 0.06)


def lime_gel():
    img = ramp3(Y, [(0, "#D8FF5E"), (0.4, "#93E01F"), (1, "#3F9A12")])
    edge = np.minimum(np.minimum(X, 1 - X) * ASPECT, np.minimum(Y, 1 - Y))
    img = img * (0.72 + 0.28 * smooth(0, 0.16, edge))[..., None]          # darker, thicker-looking rim
    img = over(img, "#F4FF9A", blob(0.5 * ASPECT, 0.62, 0.9, 1.3) * 0.36)   # inner glow
    for cx, cy, rx, ry, a in ((0.11, 0.20, 0.16, 0.045, .55), (0.89, 0.17, 0.13, 0.04, .5), (0.5, 0.05, 0.40, 0.016, .32), (0.15, 0.88, 0.10, 0.02, .28), (0.87, 0.9, 0.12, 0.02, .28)):
        e = np.clip(1 - (((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2), 0, 1) ** 0.8
        img = over(img, "#FFFFFF", e * a)
    img = bubbles(img, rand_bubbles(11, 18, 0.012, 0.045), "#F6FFC8")
    return finish(img, 0.04)


def sorbet_sky():
    img = ramp3(lin(78), [(0, "#FF7EB6"), (0.42, "#FF9E7A"), (0.78, "#FFD166"), (1, "#FFF2A8")])
    for i, (amp, y0, col, a) in enumerate(((0.10, 0.70, "#FFFFFF", .24), (0.07, 0.82, "#FF5E9E", .20), (0.12, 0.30, "#FFE9B0", .16))):
        w = smooth(0, 0.012, Y - (y0 + amp * np.sin(X * (3.4 + i) + i * 1.7)))
        img = over(img, col, w * a)
    rng = np.random.default_rng(6)
    for _ in range(16):
        x, y, r = rng.random() * ASPECT, rng.random(), 0.05 + rng.random() * 0.12
        d = np.sqrt((XA - x) ** 2 + (Y - y) ** 2) / r
        img = over(img, "#FFFFFF", smooth(1.0, 0.94, d) * (0.06 + 0.10 * rng.random()) + np.exp(-((d - 0.96) / 0.04) ** 2) * 0.10)
    return finish(gloss_arc(img, 0.26), 0.05)


def liquid_chrome():
    n = fbm(2, 40, 2)
    m = fbm(3, 47, 2)
    phase = Y * 5.2 + np.sin(XA * 2.3 + n * 4.0) * 1.25 + np.sin(XA * 0.9 - Y * 2.0 + 1.0) * 0.9 + (m - 0.5) * 1.8
    t = 0.5 + 0.5 * np.sin(phase * 3.3)
    chrome = [(0, "#0C1228"), (0.22, "#31487A"), (0.42, "#A9C0E2"), (0.50, "#FFFFFF"), (0.57, "#4A3A30"),
              (0.68, "#8E7660"), (0.86, "#D9CDBE"), (1, "#F6F8FC")]
    img = ramp3(t, chrome)
    img = img * 0.84 + ramp3(Y, [(0, "#E4EEFC"), (1, "#8794AE")]) * 0.16
    hot = np.exp(-((t - 0.5) / 0.02) ** 2) * (0.5 + 0.5 * np.sin(XA * 3.0 + 0.5))
    img = over(img, "#FFFFFF", np.clip(hot, 0, 1) * 0.5)
    return finish(gloss_arc(img, 0.14), 0.08)


def aurora_layers():
    out = np.zeros((GH, GW, 3), dtype=np.float32)
    n1 = fbm(6, 60, 2)
    for i, (y0, amp, freq, ph, width, c1, c2, gain) in enumerate((
            (0.62, 0.12, 2.1, 0.3, 0.30, "#3DFFB0", "#45C8FF", 1.0), (0.48, 0.10, 3.0, 2.0, 0.24, "#6BFFE0", "#9D7BFF", 0.85),
            (0.80, 0.08, 1.6, 4.1, 0.26, "#B8FF6B", "#3DFFB0", 0.6), (0.34, 0.07, 2.6, 5.2, 0.22, "#C58BFF", "#FF7AD9", 0.6))):
        yc = y0 + amp * np.sin(XA * freq + ph) + (n1 - .5) * 0.10
        dy = yc - Y                                    # positive above the ribbon base
        body = np.where(dy >= 0, np.exp(-(np.maximum(dy, 0) / width) ** 1.4), np.exp(-(dy / 0.022) ** 2))
        rays = 0.55 + 0.45 * vnoise(int(70 + i * 23), 2, 70 + i)
        col = rgb(c1) * (1 - np.clip(dy / width, 0, 1))[..., None] + rgb(c2) * np.clip(dy / width, 0, 1)[..., None]
        out += col * (body * rays * gain)[..., None]
    return out


def aurora_glass():
    img = ramp3(Y, [(0, "#0A1030"), (0.55, "#10305A"), (1, "#0E5560")])
    img = 1 - (1 - img) * (1 - np.clip(aurora_layers() * 0.72, 0, 1))
    rng = np.random.default_rng(2)
    for _ in range(70):
        x, y, r = rng.random() * ASPECT, rng.random() ** 1.6 * 0.8, 0.0025 + rng.random() ** 3 * 0.006
        img = over(img, "#FFFFFF", blob(x, y, r * 2, 2.0) * (0.5 + 0.5 * rng.random()))
    return finish(gloss_arc(img, 0.13), 0.14)


def caustics(seed, scale=1.0):
    n1, n2 = fbm(4, seed, 3), fbm(4, seed + 5, 3)
    u = XA * 9 * scale + n1 * 7
    v = Y * 9 * scale + n2 * 7
    a = np.abs(np.sin(u) + np.sin(v * 1.13 + u * 0.37)) / 2
    b = np.abs(np.sin(u * 0.71 - v * 0.9 + 1.3) + np.sin(v * 0.6 + 2.1)) / 2
    return np.clip((1 - a) ** 7 + (1 - b) ** 9 * 0.8, 0, 1)


def tidepool():
    img = ramp3(Y, [(0, "#63E6E2"), (0.35, "#1FB6D9"), (0.75, "#136FB8"), (1, "#0C3F86")])
    c = caustics(90)
    img = screen(img, "#D8FFFA", c * (0.55 - 0.25 * Y))
    rays = np.clip(np.sin((XA - Y * 0.35) * 9 + fbm(2, 97, 2) * 4), 0, 1) ** 3 * (1 - Y) ** 1.4
    img = screen(img, "#FFFFFF", rays * 0.20)
    img = bubbles(img, rand_bubbles(19, 12, 0.012, 0.05), "#E8FFFF")
    return finish(gloss_arc(img, 0.22), 0.10)


def flare(img, sx, sy, strength=1.0):
    d = np.sqrt((XA - sx) ** 2 + (Y - sy) ** 2)
    ang = np.arctan2(Y - sy, XA - sx)
    img = screen(img, "#FFFFFF", np.clip(np.exp(-(d / 0.035) ** 2) * 1.2 + np.exp(-d / 0.12) * 0.45, 0, 1) * strength)
    rays = (np.abs(np.cos(ang * 3 + 0.4)) ** 60 + np.abs(np.cos(ang * 2 - 0.2)) ** 140 * 0.9) * np.exp(-d / 0.42)
    img = screen(img, "#FFF8E8", np.clip(rays, 0, 1) * 0.75 * strength)
    streak = np.exp(-((Y - sy) / 0.006) ** 2) * np.exp(-np.abs(XA - sx) / 0.9)
    img = screen(img, "#BFE4FF", streak * 0.7 * strength)
    for rr_, wd, col, a in ((0.20, 0.010, "#FFD6F2", .30), (0.31, 0.022, "#BFF2FF", .16)):
        img = screen(img, col, np.exp(-((d - rr_) / wd) ** 2) * a * strength)
    # ghosts on the line through the plate centre
    cx, cy = 0.5 * ASPECT, 0.5
    for t, r, col, a, hexa in ((0.35, 0.05, "#9EF0FF", .22, True), (0.62, 0.03, "#FFC6EE", .26, False), (1.25, 0.08, "#C9B8FF", .16, True), (1.55, 0.045, "#B8FFD8", .22, False), (1.85, 0.11, "#FFE9B8", .12, True)):
        gx, gy = sx + (cx - sx) * t, sy + (cy - sy) * t
        if hexa:
            dx, dy = np.abs(XA - gx), np.abs(Y - gy)
            dd = np.maximum(dx, dx * 0.5 + dy * 0.866) / r
        else:
            dd = np.sqrt((XA - gx) ** 2 + (Y - gy) ** 2) / r
        img = screen(img, col, (smooth(1.0, 0.92, dd) * 0.6 + np.exp(-((dd - 0.95) / 0.05) ** 2) * 0.5) * a * strength)
    return img


def prism_flare():
    n = fbm(2, 120, 3)
    hue = (X * 0.9 + Y * 0.55 + n * 0.55) % 1.0
    holo = np.stack([0.5 + 0.5 * np.cos(2 * np.pi * (hue + o)) for o in (0.0, 0.33, 0.67)], axis=-1)
    img = 0.60 + holo * 0.38
    img = img * ramp3(Y, [(0, "#FFFFFF"), (1, "#D9D2F2")])
    foil = np.abs(np.sin((XA + Y * 0.6) * 46 + n * 16)) ** 6
    img = over(img, "#FFFFFF", foil * 0.09)
    img = flare(img, 0.865 * ASPECT, 0.20, 1.0)
    img = flare(img, 0.10 * ASPECT, 0.86, 0.35)
    return finish(gloss_arc(img, 0.14), 0.07)


def night_orb():
    img = ramp3(lin(80), [(0, "#231A5C"), (0.5, "#120E33"), (1, "#070716")])
    for cx, cy, r, col, a in ((0.10, 0.38, 0.30, "#FF4FCB", .62), (0.90, 0.66, 0.34, "#3FD9FF", .58), (0.80, 0.14, 0.13, "#9B6BFF", .6), (0.20, 0.90, 0.16, "#3FD9FF", .42), (0.5, 0.02, 0.2, "#FF7AD9", .35)):
        d = np.sqrt((XA - cx * ASPECT) ** 2 + (Y - cy) ** 2) / r
        inside = smooth(1.0, 0.97, d)
        shade = np.clip(1.05 - d * 0.75, 0, 1)
        lit = np.clip(0.9 - ((XA - cx * ASPECT) / r * 0.45 + (Y - cy) / r * 0.75), 0, 1.4)
        img = screen(img, col, inside * shade * (0.35 + 0.5 * lit) * a + np.exp(-((d - 1.0) / 0.22) ** 2) * 0.16 * a)
        img = over(img, "#FFFFFF", np.exp(-(((XA - (cx * ASPECT - r * .36)) / (r * .30)) ** 2 + ((Y - (cy - r * .46)) / (r * .16)) ** 2) * 2) * 0.55 * inside)
    # chrome rings
    for cx, cy, r, wd in ((0.10, 0.38, 0.39, 0.007), (0.90, 0.66, 0.43, 0.007)):
        d = np.sqrt((XA - cx * ASPECT) ** 2 + (Y - cy) ** 2)
        ang = np.arctan2(Y - cy, XA - cx * ASPECT)
        ring = np.exp(-((d - r) / wd) ** 2)
        img = over(img, ramp3((np.sin(ang * 2 + 1.0) * 0.5 + 0.5), [(0, "#3A3F66"), (0.5, "#FFFFFF"), (1, "#8C92C8")]), ring[..., None] * 0.9)
    rng = np.random.default_rng(77)
    for _ in range(46):
        x, y, r = rng.random() * ASPECT, rng.random(), 0.003 + rng.random() ** 3 * 0.01
        g = blob(x, y, r * 2.4, 2.0) + (np.exp(-((XA - x) / (r * 6)) ** 2 - ((Y - y) / (r * .5)) ** 2) + np.exp(-((XA - x) / (r * .5)) ** 2 - ((Y - y) / (r * 6)) ** 2)) * (r > 0.008) * 0.8
        img = over(img, "#FFFFFF", np.clip(g, 0, 1) * 0.9)
    return finish(gloss_arc(img, 0.12), 0.12)


# ------------------------------------------------------------------ shared overlay textures (pulse opacity only)
def save_overlay(name, color, alpha):
    a = np.clip(alpha, 0, 1)
    arr = np.zeros((GH, GW, 4), dtype=np.float32)
    arr[..., :3] = color if not isinstance(color, str) else rgb(color)
    arr[..., 3] = a
    im = Image.fromarray((np.clip(arr, 0, 1) * 255 + .5).astype(np.uint8), "RGBA").resize((W, H), Image.LANCZOS)
    m = np.asarray(rounded_mask(W, H, round(DECK["plateRadius"] * W / DECK["plate"][2]))).astype(np.float32) / 255
    out = np.asarray(im).astype(np.float32)
    out[..., 3] *= m
    Image.fromarray(out.astype(np.uint8), "RGBA").save(OUT / name)


def overlays():
    sweep = np.exp(-(((X - 0.5) + (Y - 0.5) * 0.45) / 0.10) ** 2) * 0.55 + np.exp(-(((X - 0.66) + (Y - 0.5) * 0.45) / 0.03) ** 2) * 0.35
    save_overlay("overlay-gloss-sweep.png", "#FFFFFF", sweep)
    au = aurora_layers()
    lum = np.clip(au.max(axis=-1), 0, 1)
    save_overlay("overlay-aurora.png", np.clip(au / np.maximum(lum, 1e-3)[..., None], 0, 1), lum * 0.9)
    save_overlay("overlay-water.png", "#E4FFFB", caustics(333, 0.9) * 0.85)
    rng = np.random.default_rng(5)
    sp = np.zeros((GH, GW), dtype=np.float32)
    for _ in range(60):
        x, y, r = rng.random() * ASPECT, rng.random(), 0.004 + rng.random() ** 2 * 0.012
        sp += blob(x, y, r * 2, 2.0) + np.exp(-((XA - x) / (r * 5)) ** 2 - ((Y - y) / (r * .45)) ** 2) * .9 + np.exp(-((XA - x) / (r * .45)) ** 2 - ((Y - y) / (r * 5)) ** 2) * .9
    save_overlay("overlay-sparkle.png", "#FFFFFF", sp)


# ------------------------------------------------------------------ catalogue
G, S, GM, RS = "#EBC978", "#FFFFFF", "#6F7480", "#F0B8B0"
PLATES = [
    # id, name, fn, tier, accent, deep, band tint, finish, roblox material, overlay, legacy rule
    ("sherbet", "Scout", scout, "starter", "#76F6B0", "#147863", S, "gloss", "SmoothPlastic", ("gloss", 0.0, 0.35, 6.0), None),
    ("stone", "Pebble", pebble, "starter", "#C8EB9B", "#48685E", GM, "matte speckle", "Plastic", None, None),
    ("ice", "Creek", creek, "starter", "#70ECFF", "#216892", S, "clear plastic", "Glass", ("water", 0.10, 0.40, 5.0), None),
    ("brick", "Ember", ember, "starter", "#FF9B70", "#AB3047", GM, "brushed metal", "Metal", None, None),
    ("moss", "Canopy", canopy, "starter", "#BCF57B", "#27734A", S, "leaf print gloss", "SmoothPlastic", None, None),
    ("honey", "Honey", honey, "starter", "#FFD77D", "#AF622F", G, "pearl", "SmoothPlastic", ("gloss", 0.0, 0.30, 7.0), "firstWin"),
    ("gloaming", "Gloaming", gloaming, "starter", "#92ECE6", "#465489", S, "two-tone gloss", "SmoothPlastic", ("sparkle", 0.0, 0.55, 3.2), "rankI"),
    ("copperleaf", "Copperleaf", copperleaf, "starter", "#FFBC90", "#8D4456", RS, "brushed copper", "Metal", None, "rankII"),
    ("aqua_pop", "Aqua Pop", aqua_pop, "common", "#6FE3FF", "#1B6FA8", S, "glossy bubbles", "SmoothPlastic", ("gloss", 0.0, 0.40, 5.0), None),
    ("lime_gel", "Lime Gel", lime_gel, "common", "#B6F24B", "#3E7D12", S, "translucent gel", "Glass", ("gloss", 0.0, 0.35, 5.5), None),
    ("sorbet_sky", "Sorbet Sky", sorbet_sky, "common", "#FFB37A", "#B8456B", RS, "glossy gradient", "SmoothPlastic", ("gloss", 0.0, 0.35, 6.0), None),
    ("liquid_chrome", "Liquid Chrome", liquid_chrome, "rare", "#DCE6F5", "#4A5568", S, "chrome", "Metal", ("gloss", 0.0, 0.50, 4.0), None),
    ("tidepool", "Tidepool", tidepool, "rare", "#5CD6E8", "#0E4A7A", S, "water overlay", "Glass", ("water", 0.15, 0.70, 4.5), None),
    ("aurora_glass", "Aurora Glass", aurora_glass, "rare", "#7CF5C4", "#1B2A5E", GM, "aurora overlay", "SmoothPlastic", ("aurora", 0.10, 0.75, 6.5), None),
    ("prism_flare", "Prism Flare", prism_flare, "showcase", "#F3B6FF", "#5B4BA8", S, "holographic lens flare", "Foil", ("sparkle", 0.0, 0.80, 2.8), None),
    ("night_orb", "Night Orb", night_orb, "showcase", "#FF7AD9", "#1A1440", GM, "glass orbs and chrome rings", "SmoothPlastic", ("sparkle", 0.0, 0.70, 3.4), None),
]
LIGHT_ENGRAVE = {"aurora_glass", "night_orb", "tidepool"}
PRICE = {"starter": 0, "common": 20, "rare": 40, "showcase": 80}
BAND_NAME = {S: "silver", GM: "gunmetal", G: "gold", RS: "rose"}
OVERLAY_FILE = {"gloss": "overlay-gloss-sweep.png", "water": "overlay-water.png", "aurora": "overlay-aurora.png", "sparkle": "overlay-sparkle.png"}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    overlays()
    rows = []
    for i, (pid, name, fn, tier, accent, deep, bandc, fin, mat, ov, rule) in enumerate(PLATES):
        im = fn()
        im.save(OUT / f"{pid}.png")
        th = ui_theme(accent, deep)
        ink = to_hex(th["ink"])
        row = {
            "id": pid, "name": name, "order": i + 1, "tier": tier, "priceStars": PRICE[tier],
            "texture": f"{pid}.png", "finish": fin,
            "accent": accent, "ink": ink, "accentInkContrast": round(contrast(hx(accent), th["ink"]), 2),
            "deep": deep, "band": {"name": BAND_NAME[bandc], "tint": bandc},
            "engrave": ({"color": "#FFFFFF", "opacity": 0.78} if pid in LIGHT_ENGRAVE else {"color": "#0E0F12", "opacity": 0.42}),
            "ui": {k: to_hex(th[k]) for k in ("panel", "raised", "well", "selected", "line")},
            "overlay": ({"texture": OVERLAY_FILE[ov[0]], "kind": ov[0], "opacity": [ov[1], ov[2]], "periodSeconds": ov[3],
                         "ease": "sine in-out, ping-pong", "reducedEffects": "hold at the lower opacity"} if ov else None),
            "held3d": {"material": mat, "reflectance": 0.25 if mat in ("Metal", "Foil") else 0.08, "transparency": 0.25 if mat == "Glass" else 0},
        }
        if tier == "starter":
            row["legacyThemeId"] = pid
            row["unlock"] = rule or "free"
        rows.append(row)
        print(pid, ink, row["accentInkContrast"])
    doc = {
        "schema": 1, "textureSize": [W, H], "plateRect": DECK["plate"],
        "tiers": {"starter": {"priceStars": 0, "note": "the 8 existing deck styles; ids are the saved DeckThemes ids, unlock rules unchanged"},
                  "common": {"priceStars": 20}, "rare": {"priceStars": 40}, "showcase": {"priceStars": 80}},
        "tintRule": "UI surfaces: glass #15171B, raised #23262C, well #0C0D10 lean 14% / 16% / 10% toward `deep`. `accent` is used only for selection, focus fill, the primary action and progress. Text on an accent fill uses `ink`. The `ui` block is that derivation, precomputed.",
        "overlayRule": "Overlay textures share the plate rect and already carry its rounded alpha. Animate ImageTransparency only (no scrolling, the plate cannot clip). opacity = [min, max].",
        "faceplates": rows,
    }
    (OUT / "faceplates.json").write_text(json.dumps(doc, indent=1), newline="\n")


if __name__ == "__main__":
    main()
