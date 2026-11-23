"""Garden life round 3 and the nest remodel: the textures (Fable, 2026-11-23).

Look spec: artifacts/qa-2026-11-23-beta12/GARDEN-LIFE-NEST-LOOK.md. Spencer's rule (2026-11-23): ambient life and
world dressing are realistic and textured so the toy-like pets stand out. Script-drawn, deterministic (fixed seeds),
numpy + Pillow, no outside art. Nothing is uploaded here: that is the builder's job.

Writes to artifacts/qa-2026-11-23-beta12/look/ :
  butterfly-<amber|chalk|dusk|meadow>.png, and -m.png   160x192  full colour wing, root at the LEFT edge, fore wing up
                                                                 (-m = mirror). Decal, Color3 white.
  firefly-dot.png        64x64    soft glow dot. BillboardGui ImageLabel (hand-off) and ParticleEmitter (v7 fireflies).
  leaf-a.png, leaf-b.png 96x96    full colour leaves, stem down. ParticleEmitter.Texture.
  bird-wing-<ember|slate|moss>.png  128x176  folded wing, tip down, left-right symmetric. Decal, Color3 white.
  bird-tail.png          96x128   grey tail fan, root up, tip down. Decal, tinted by Color3.
  bird-breast.png        128x128  grey feather streaks, soft round alpha. Decal on the body ball, tinted by Color3.
  nest-twigs.png         256x128  tileable woven twigs. Texture on the rim rolls.
  nest-fringe.png        256x160  ragged twig and straw spray, alpha, roots at the bottom. Decal on a see-through plate.
  straw-bed.png          256x256  round straw bed seen from above, alpha circle. Decal on the bed disc's cap.
  straw-wisps.png        192x96   pale straw tuft, alpha, roots at the bottom. Decal on a see-through plate.
  nest-sign.png          208x128  three weathered planks, a burnt crescent at the left. Decal on the board's face.
  preview-*.png                   contact sheets (not for upload).

Run:  python scripts/draw_garden_life_r3_textures.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "artifacts" / "qa-2026-11-23-beta12" / "look"
SS = 3


def rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def rgb8(h: str, k: float = 1.0) -> tuple[int, int, int]:
    return tuple(int(max(0, min(255, round(v * 255 * k)))) for v in rgb(h))


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(base, colour, m):
    return base * (1 - m[..., None]) + colour * m[..., None]


def grain(shape, seed: int, blur: float = 0.0) -> np.ndarray:
    """Noise in -1..1, optionally blurred (still roughly -1..1)."""
    n = np.random.default_rng(seed).random(shape).astype(np.float32)
    if blur > 0:
        img = Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
        n = np.asarray(img, dtype=np.float32) / 255.0
        n = (n - n.mean()) / (n.std() + 1e-6) * 0.33 + 0.5
    return np.clip(n * 2 - 1, -1, 1)


def to_image(col: np.ndarray, alpha: np.ndarray, size: tuple[int, int]) -> Image.Image:
    arr = np.dstack([np.clip(col, 0, 1), np.clip(alpha, 0, 1)[..., None]])
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)


# Butterflies -----------------------------------------------------------------------------------------------------
# The round 2 silhouette (so the wing plates keep their size and hinge): root (4, 104), hind lobe then fore lobe.
WING = (160, 192)
ROOTPT = (4.0, 104.0)
LOBES = [(70, 142, 64, 44, 28), (80, 60, 82, 52, -24)]  # cx, cy, a, b, degrees: hind, fore

SPECIES = {
    # field at the root, field at the edge, border, vein, vein strength, border width, spots in the border, eyespot
    "amber": dict(inner="#F2B24A", outer="#D9722A", border="#2B1D14", vein="#3A2415", veins=0.85, edge=0.80,
                  dots="#F6E7C8", eye=None, tip=None),
    "chalk": dict(inner="#F7F3E4", outer="#EFE8D2", border="#EDE5CF", vein="#B9B29C", veins=0.35, edge=0.93,
                  dots=None, eye="#3B3A38", tip="#4A4844"),
    "dusk": dict(inner="#B9CBEA", outer="#7F9FD6", border="#5B5A66", vein="#6C7FA8", veins=0.30, edge=0.86,
                 dots=None, eye=None, tip=None, fringe="#F4F1E8"),
    "meadow": dict(inner="#E9DD8E", outer="#D8C460", border="#2A2622", vein="#3A342C", veins=0.75, edge=0.78,
                   dots="#E9DD8E", eye="#C2553A", tip=None, band=True),
}


def butterfly(name: str) -> Image.Image:
    sp = SPECIES[name]
    w, h = WING[0] * SS, WING[1] * SS
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x, y = (xx + 0.5) / SS, (yy + 0.5) / SS
    col = np.zeros((h, w, 3), np.float32)
    alpha = np.zeros((h, w), np.float32)
    dxr, dyr = x - ROOTPT[0], y - ROOTPT[1]
    rr = np.hypot(dxr, dyr)
    theta = np.arctan2(dyr, dxr)
    scales = grain((h, w), 11, 0.0) * 0.045 + grain((h, w), 12, 2.5 * SS) * 0.07
    for index, (cx, cy, a, b, deg) in enumerate(LOBES):
        c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        u = ((x - cx) * c + (y - cy) * s) / a
        v = (-(x - cx) * s + (y - cy) * c) / b
        rho = np.hypot(u, v)
        # A slightly scalloped outer edge on the hind wing, a straighter leading edge on the fore wing.
        ang = np.arctan2(v, u)
        edge = 1.0 + (0.035 * np.cos(ang * 7) * smooth(-0.2, 0.6, u) if index == 0 else -0.05 * smooth(0.2, 1.0, -v) * smooth(0, 1, u))
        inside = smooth(0.0, 0.03, edge - rho)
        # Field: gradient from the root out.
        t = smooth(20, 120, rr)
        field = mix(np.broadcast_to(rgb(sp["inner"]), (h, w, 3)).copy(), rgb(sp["outer"]), t)
        # Veins: rays from the root, a constant few pixels wide, fading at the root.
        rays = 9 if index == 1 else 7
        lo, hi = (-1.25, 0.05) if index == 1 else (-0.15, 1.15)
        phase = (theta - lo) / (hi - lo) * rays
        near = np.abs(phase - np.round(phase)) * (hi - lo) / rays * rr  # studs-of-texture distance to the nearest ray
        vein = (1 - smooth(0.7, 1.9, near)) * smooth(10, 34, rr) * sp["veins"]
        if sp.get("band"):  # two soft dark bars across the fore wing, one across the hind
            bar = (1 - smooth(4, 9, np.abs(rr - 62))) * 0.8 + (1 - smooth(3, 7, np.abs(rr - 96))) * 0.6
            vein = np.maximum(vein, bar * (0.9 if index == 1 else 0.5))
        field = mix(field, rgb(sp["vein"]), np.clip(vein, 0, 1))
        # Border: widest at the outer edge, away from the root.
        outer = smooth(-0.5, 0.9, u)
        bw = sp["edge"] + (1 - outer) * 0.16
        border = smooth(bw - 0.03, bw + 0.03, rho / edge)
        field = mix(field, rgb(sp["border"]), border)
        if sp.get("dots"):
            k = ang * 6.5
            dot = (1 - smooth(0.20, 0.34, np.hypot((k - np.round(k)) / 6.5 * 1.6, (rho / edge - (bw + 1) / 2) * 3.2) * 2.0))
            field = mix(field, rgb(sp["dots"]), dot * border * outer)
        if sp.get("fringe"):
            field = mix(field, rgb(sp["fringe"]), smooth(0.955, 0.985, rho / edge))
        if sp.get("tip") and index == 1:  # a smoky wing tip
            tip = smooth(0.35, 0.95, u) * smooth(0.1, 0.9, -v + 0.3)
            field = mix(field, rgb(sp["tip"]), tip * 0.85)
        if sp.get("eye"):
            ex, ey = (0.30, 0.10) if index == 1 else (0.42, 0.30)
            d = np.hypot(u - ex, (v - ey) * 1.1)
            field = mix(field, rgb(sp["eye"]), 1 - smooth(0.085, 0.13, d))
            if name == "meadow" and index == 0:
                field = mix(field, rgb("#4B6FA8"), (1 - smooth(0.03, 0.06, d)))
        # Dark dusting where the wing meets the body.
        field = mix(field, rgb("#2A2018"), (1 - smooth(8, 34, rr)) * 0.75)
        field = field * (1 + scales[..., None])
        col = mix(col, field, inside)
        alpha = np.maximum(alpha, inside)
    # The join at the body.
    join = smooth(0, 2, 40 - x) * smooth(0, 2, y - (84 - x * 0.35)) * smooth(0, 2, (122 + x * 0.45) - y)
    col = mix(col, np.broadcast_to(rgb("#2A2018"), (h, w, 3)).copy() * (1 + scales[..., None]), join * (1 - alpha))
    alpha = np.maximum(alpha, join)
    return to_image(col, alpha, WING)


# Firefly ---------------------------------------------------------------------------------------------------------
def firefly_dot() -> Image.Image:
    n = 64 * SS
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx - n / 2 + 0.5, yy - n / 2 + 0.5) / (n / 2)
    core = np.exp(-(r / 0.16) ** 2)
    halo = np.exp(-(r / 0.42) ** 2) * 0.55
    a = np.clip(core + halo, 0, 1) * smooth(1.0, 0.8, r)
    col = mix(np.broadcast_to(rgb("#F4FFB0"), (n, n, 3)).copy(), rgb("#FFFFFF"), core)
    return to_image(col, a, (64, 64))


# Leaves ----------------------------------------------------------------------------------------------------------
def leaf(kind: str) -> Image.Image:
    n = 96 * SS
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u, v = (xx + 0.5) / n - 0.5, (yy + 0.5) / n  # u: -0.5..0.5 across, v: 0 top (tip) .. 1 bottom (stem)
    if kind == "a":  # broad heart-shaped leaf (a lime tree's), fresh green
        t = np.clip((0.86 - v) / 0.78, 0, 1)  # 0 at the base, 1 at the tip
        half = 0.36 * np.clip(np.sin(np.pi * t ** 0.55), 0, 1) ** 0.8 * (1 - 0.25 * t)
        tones = ("#3F7A2E", "#5E9A3A", "#8DBF5A", "#2F5F24")
        lean, pairs = 0.03, 6
    else:  # narrower leaf turning yellow-olive, a dry brown edge
        t = np.clip((0.88 - v) / 0.80, 0, 1)
        half = 0.22 * np.clip(np.sin(np.pi * t ** 0.7), 0, 1) ** 0.75
        tones = ("#7C8A32", "#A7A545", "#D0C56A", "#5C6A26")
        lean, pairs = -0.05, 7
    mid = lean * np.sin(np.pi * t)  # the midrib bends a little
    d = half - np.abs(u - mid)
    saw = 0.008 * np.sin(t * 70)  # fine serration
    inside = smooth(-0.004, 0.008, d + saw) * (t > 0) * (t < 1)
    side = np.sign(u - mid)
    col = np.broadcast_to(rgb(tones[0]), (n, n, 3)).copy()
    col = mix(col, rgb(tones[1]), smooth(0.0, 0.2, d) * 0.8)
    col = mix(col, rgb(tones[3]), (side < 0) * 0.22 * np.ones_like(d))  # one half in shade: the leaf is folded
    # Side veins: angled up from the midrib.
    q = (t - np.abs(u - mid) * 1.3) * pairs
    veins = (1 - smooth(0.05, 0.13, np.abs(q - np.round(q)))) * smooth(0.0, 0.03, np.abs(u - mid)) * smooth(0, 0.05, d)
    col = mix(col, rgb(tones[2]), veins * 0.55)
    col = mix(col, rgb(tones[2]), (1 - smooth(0.004, 0.012, np.abs(u - mid))) * 0.9)
    if kind == "b":
        col = mix(col, rgb("#8A5A2A"), (1 - smooth(0.0, 0.05, d)) * 0.7)
        blot = smooth(0.25, 0.6, grain((n, n), 31, 5.0 * SS))
        col = mix(col, rgb("#7A5226"), blot * 0.5)
    col = col * (1 + (grain((n, n), 21, 0) * 0.05 + grain((n, n), 22, 3.0 * SS) * 0.10)[..., None])
    # Stem.
    stem = (1 - smooth(0.006, 0.012, np.abs(u - lean * 0.2))) * (v > 0.84) * (v < 0.97)
    col = mix(col, rgb("#6B5A2A"), stem * (1 - inside))
    return to_image(col, np.maximum(inside, stem), (96, 96))


# Birds -----------------------------------------------------------------------------------------------------------
BIRDS = {
    # covert (shoulder), flight feather, feather edge, wing bar or None
    "ember": dict(covert="#8A6E4E", flight="#5E4A36", edge="#B89A72", bar=None),
    "slate": dict(covert="#6F8FB3", flight="#465E7E", edge="#A9BED6", bar=None),
    "moss": dict(covert="#7F8C48", flight="#4A5230", edge="#C9CC8E", bar="#E8E6C8"),
}


def _feather(d: ImageDraw.ImageDraw, cx, cy, length, width, deg, fill, edge, shaft):
    """A feather: a long ellipse, lighter edge, dark shaft line. Screen degrees; the tip points along +deg."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    def poly(k):
        pts = []
        for i in range(40):
            a = 2 * math.pi * i / 40
            px, py = length * k * math.cos(a), width * k * math.sin(a)
            pts.append(((cx + px * c - py * s) * SS, (cy + px * s + py * c) * SS))
        return pts
    d.polygon(poly(1.0), fill=edge)
    d.polygon(poly(0.86), fill=fill)
    d.line([((cx - length * 0.8 * c) * SS, (cy - length * 0.8 * s) * SS), ((cx + length * 0.8 * c) * SS, (cy + length * 0.8 * s) * SS)],
           fill=shaft, width=max(1, SS))


def bird_wing(name: str) -> Image.Image:
    sp = BIRDS[name]
    w, h = 128, 176
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(41)
    def tone(hexc, k):
        return rgb8(hexc, k) + (255,)
    # Flight feathers: seven, fanned, tips down; drawn outside in so the middle ones lie on top. Symmetric.
    for i, off in enumerate((3, -3, 2, -2, 1, -1, 0)):
        k = 0.88 + 0.06 * (abs(off) % 2) + float(rng.random()) * 0.04
        _feather(d, 64 + off * 11.5, 104 - abs(off) * 5, 58 - abs(off) * 3, 12.5, 90 + off * 5.5,
                 tone(sp["flight"], k), tone(sp["edge"], 0.9), tone(sp["flight"], 0.6))
    # Wing bar: a pale row where the coverts end.
    if sp["bar"]:
        for off in (-3, -2, -1, 0, 1, 2, 3):
            _feather(d, 64 + off * 13, 78 - abs(off) * 2.5, 13, 8, 90 + off * 6, tone(sp["bar"], 1.0), tone(sp["bar"], 0.86), tone(sp["flight"], 0.9))
    # Coverts: three rows of small round feathers up to the shoulder, each row on top of the one below.
    for row, (yc, count, size) in enumerate(((66, 7, 15), (48, 6, 16), (30, 5, 17))):
        for j in range(count):
            off = j - (count - 1) / 2
            k = 0.94 + 0.10 * ((j + row) % 2)
            _feather(d, 64 + off * (88 / count) * 1.05, yc - abs(off) * 1.5 + 2, size, size * 0.62, 90 + off * 7,
                     tone(sp["covert"], k), tone(sp["edge"], 0.95), tone(sp["covert"], 0.7))
    # Shoulder cap.
    d.ellipse(((64 - 40) * SS, 4 * SS, (64 + 40) * SS, 40 * SS), fill=tone(sp["covert"], 1.04))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    g = grain(arr.shape[:2], 43, 0) * 0.05 + grain(arr.shape[:2], 44, 1.2 * SS) * 0.07
    # Barbs: fine lines down the feathers.
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]].astype(np.float32)
    barbs = np.sin((xx + yy * 0.25) / SS * 2.6) * 0.03
    arr[..., :3] = np.clip(arr[..., :3] * (1 + (g + barbs)[..., None]), 0, 1)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)


def bird_tail() -> Image.Image:
    w, h = 96, 128
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for off in (2, -2, 1, -1, 0):
        g = 200 + 18 * (2 - abs(off))
        _feather(d, 48 + off * 9, 66, 56, 10.5, 90 + off * 7, (g, g, g, 255), (255, 255, 255, 255), (150, 150, 150, 255))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]].astype(np.float32)
    arr[..., :3] = np.clip(arr[..., :3] * (1 + (np.sin((xx + yy * 0.2) / SS * 2.6) * 0.035 + grain(arr.shape[:2], 45, 0) * 0.04)[..., None]), 0, 1)
    # A darker tip band (most small birds have one).
    arr[..., :3] *= (1 - 0.28 * smooth(0.72, 0.95, yy / arr.shape[0]))[..., None]
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)


def bird_breast() -> Image.Image:
    n = 128 * SS
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u, v = (xx + 0.5) / n - 0.5, (yy + 0.5) / n - 0.5
    r = np.hypot(u, v * 0.9)
    # Soft feather streaks running down, broken up by noise.
    streak = np.sin(u * 95 + grain((n, n), 51, 6 * SS) * 3.0) * 0.5 + 0.5
    rows = np.sin(v * 60 + grain((n, n), 52, 8 * SS) * 4.0) * 0.5 + 0.5
    tex = 0.80 + 0.20 * streak * rows + grain((n, n), 53, 0) * 0.05
    alpha = smooth(0.46, 0.20, r) * (0.82 + 0.18 * streak)
    col = np.repeat(np.clip(tex, 0, 1)[..., None], 3, axis=2)
    return to_image(col, alpha, (128, 128))


# Nest ------------------------------------------------------------------------------------------------------------
TWIGS = ["#6B4A2C", "#7D5A38", "#5A3D24", "#8C6B46", "#4A3220", "#96785A", "#70604E"]
STRAW = ["#D9BE7A", "#E6CF8E", "#C9A860", "#EFE0A8", "#B8974F"]


def _stroke(d: ImageDraw.ImageDraw, pts, width, colour, light, dark):
    """A twig: a shadow under it, the body, a thin highlight along the top."""
    sh = [(x + width * 0.25, y + width * 0.55) for x, y in pts]
    d.line(sh, fill=dark, width=int(width), joint="curve")
    d.line(pts, fill=colour, width=int(width), joint="curve")
    hi = [(x, y - width * 0.28) for x, y in pts]
    d.line(hi, fill=light, width=max(1, int(width * 0.28)), joint="curve")


def _curve(x0, y0, length, deg, bend, n=7):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(deg + bend * (t - 0.5))
        pts.append((x0 + math.cos(a) * length * t, y0 + math.sin(a) * length * t + math.sin(t * math.pi) * bend * 0.15))
    return pts


def nest_twigs() -> Image.Image:
    w, h = 256 * SS, 128 * SS
    img = Image.new("RGB", (w, h), rgb8("#2B1C12"))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(61)
    for layer in range(3):
        for _ in range(70):
            x0, y0 = float(rng.random()) * w, float(rng.random()) * h
            length = (60 + float(rng.random()) * 120) * SS
            deg = float(rng.normal(0, 16)) + (180 if rng.random() < 0.5 else 0)
            bend = float(rng.normal(0, 22))
            width = (2.2 + float(rng.random()) * 3.6 + layer * 0.5) * SS
            straw = layer == 2 and rng.random() < 0.28
            base = STRAW[int(rng.integers(len(STRAW)))] if straw else TWIGS[int(rng.integers(len(TWIGS)))]
            k = 0.62 + layer * 0.19 + float(rng.random()) * 0.1
            if straw:
                width *= 0.45
            pts = _curve(x0, y0, length, deg, bend)
            for ox in (-w, 0, w):  # wrap, so it tiles both ways
                for oy in (-h, 0, h):
                    _stroke(d, [(x + ox, y + oy) for x, y in pts], width, rgb8(base, k), rgb8(base, min(1.5, k * 1.35)), rgb8("#1A100A"))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    arr = np.clip(arr * (1 + grain(arr.shape[:2], 62, 0)[..., None] * 0.06), 0, 1)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGB").resize((256, 128), Image.LANCZOS)


def nest_fringe() -> Image.Image:
    w, h = 256 * SS, 160 * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(63)
    for layer in range(3):
        for _ in range(46):
            x0 = (0.06 + float(rng.random()) * 0.88) * w
            y0 = h * (0.99 - float(rng.random()) * 0.10)
            # Long ones are rare: a ragged, uneven top edge.
            length = (38 + float(rng.random()) ** 2.2 * 100) * SS
            lean = (x0 / w - 0.5) * 70
            deg = -90 + lean + float(rng.normal(0, 20))
            straw = rng.random() < (0.12 + layer * 0.12)
            base = STRAW[int(rng.integers(len(STRAW)))] if straw else TWIGS[int(rng.integers(len(TWIGS)))]
            k = 0.6 + layer * 0.2 + float(rng.random()) * 0.1
            width = ((1.3 if straw else 2.4) + float(rng.random()) * 2.6) * SS
            _stroke(d, _curve(x0, y0, length, deg, float(rng.normal(0, 30))), width, rgb8(base, k) + (255,),
                    rgb8(base, min(1.5, k * 1.35)) + (255,), rgb8("#1A100A") + (255,))
    # A dense woven band along the bottom so the plate has no gap against the rim.
    for _ in range(60):
        x0, y0 = float(rng.random()) * w, h * (0.80 + float(rng.random()) * 0.2)
        base = TWIGS[int(rng.integers(len(TWIGS)))]
        k = 0.7 + float(rng.random()) * 0.4
        _stroke(d, _curve(x0 - 40 * SS, y0, (50 + float(rng.random()) * 70) * SS, float(rng.normal(0, 14)), float(rng.normal(0, 20))),
                (2.5 + float(rng.random()) * 3) * SS, rgb8(base, k) + (255,), rgb8(base, min(1.5, k * 1.35)) + (255,), rgb8("#1A100A") + (255,))
    # Fade the two side edges so neighbouring plates overlap without a seam.
    arr = np.asarray(img, dtype=np.float32) / 255.0
    xx = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    arr[..., 3] *= smooth(0.0, 0.07, xx) * smooth(1.0, 0.93, xx)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").resize((256, 160), Image.LANCZOS)


def straw_bed() -> Image.Image:
    n = 256 * SS
    img = Image.new("RGB", (n, n), rgb8("#6E5630"))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(65)
    for layer in range(3):
        for _ in range(240):
            # Straw lies round the bowl: mostly tangent to the centre, with strays.
            a = float(rng.random()) * math.tau
            r = math.sqrt(float(rng.random())) * n * 0.52
            x0, y0 = n / 2 + math.cos(a) * r, n / 2 + math.sin(a) * r
            deg = math.degrees(a) + 90 + float(rng.normal(0, 28))
            base = STRAW[int(rng.integers(len(STRAW)))]
            k = 0.62 + layer * 0.18 + float(rng.random()) * 0.1
            _stroke(d, _curve(x0, y0, (30 + float(rng.random()) * 70) * SS, deg, float(rng.normal(0, 40))),
                    (1.2 + float(rng.random()) * 1.8) * SS, rgb8(base, k), rgb8(base, min(1.5, k * 1.3)), rgb8("#4A3818"))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx - n / 2, yy - n / 2) / (n / 2)
    # The dent where the egg sits is in shade, and the bed darkens into the twigs at the rim.
    shade = 1 - 0.38 * (1 - smooth(0.10, 0.50, r)) - 0.30 * smooth(0.78, 1.0, r)
    arr = np.clip(arr * shade[..., None] * (1 + grain((n, n), 66, 0)[..., None] * 0.05), 0, 1)
    return to_image(arr, smooth(1.0, 0.965, r), (256, 256))


def straw_wisps() -> Image.Image:
    w, h = 192 * SS, 96 * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(67)
    for layer in range(3):
        for _ in range(40):
            x0 = (0.10 + float(rng.random()) * 0.80) * w
            lean = (x0 / w - 0.5) * 110
            length = (22 + float(rng.random()) ** 1.8 * 56) * SS
            base = STRAW[int(rng.integers(len(STRAW)))]
            k = 0.66 + layer * 0.17 + float(rng.random()) * 0.1
            _stroke(d, _curve(x0, h * 0.99, length, -90 + lean + float(rng.normal(0, 16)), float(rng.normal(0, 36))),
                    (1.2 + float(rng.random()) * 1.6) * SS, rgb8(base, k) + (255,), rgb8(base, min(1.5, k * 1.3)) + (255,), rgb8("#5A4420") + (255,))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    xx = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    arr[..., 3] *= smooth(0.0, 0.08, xx) * smooth(1.0, 0.92, xx)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA").resize((192, 96), Image.LANCZOS)


def nest_sign() -> Image.Image:
    w, h = 208 * SS, 128 * SS
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xx / w, yy / h
    plank = np.minimum(np.floor(v * 3), 2)
    base = np.stack([rgb("#B08A5A"), rgb("#A47E50"), rgb("#B8936A")])[plank.astype(int)]
    # Grain: long wavy lines, different on each plank, with two knots.
    warp = grain((h, w), 71, 14 * SS) * 5.0
    lines = np.sin((v * 46 + plank * 1.7 + warp * 0.35) * math.tau / 2.2) * 0.5 + 0.5
    col = base * (0.86 + 0.14 * lines[..., None])
    for kx, ky, kr in ((0.72, 0.22, 0.035), (0.86, 0.80, 0.028)):
        dk = np.hypot((u - kx) * (w / h), v - ky)
        ring = np.sin(dk / kr * 9) * 0.5 + 0.5
        m = 1 - smooth(kr * 0.6, kr * 2.2, dk)
        col = mix(col, rgb("#6A4A2A") * (0.8 + 0.2 * ring[..., None]), m * 0.85)
    # Gaps between planks, worn dark edges, four nail heads.
    gap = 1 - smooth(0.0, 0.012, np.abs((v * 3) % 1 - 0.0) / 3) * smooth(0.0, 0.012, np.abs(1 - (v * 3) % 1) / 3)
    col = mix(col, rgb("#3A2616"), np.clip(gap, 0, 1) * 0.9)
    edge = 1 - smooth(0.0, 0.05, np.minimum(np.minimum(u, 1 - u) * (w / h), np.minimum(v, 1 - v)))
    col = mix(col, rgb("#5A3E24"), edge * 0.6)
    for nx, ny in ((0.045, 0.16), (0.955, 0.16), (0.045, 0.84), (0.955, 0.84)):
        dn = np.hypot((u - nx) * (w / h), v - ny)
        col = mix(col, rgb("#3C3A38"), 1 - smooth(0.018, 0.024, dn))
        col = mix(col, rgb("#8E8C88"), 1 - smooth(0.004, 0.010, np.hypot((u - nx) * (w / h) + 0.006, v - ny + 0.006)))
    # A burnt crescent moon at the left (the Sleepy egg's mark): the words go on a SurfaceGui to its right.
    cx, cy, r = 0.19 * (w / h), 0.5, 0.26
    px = u * (w / h)
    moon = (1 - smooth(r - 0.012, r + 0.012, np.hypot(px - cx, v - cy))) * smooth(r * 0.80 - 0.012, r * 0.80 + 0.012, np.hypot(px - cx - r * 0.42, v - cy + r * 0.20))
    col = mix(col, rgb("#3B2A1A"), moon * 0.88)
    col = col * (1 + (grain((h, w), 72, 0) * 0.05)[..., None])
    return Image.fromarray((np.clip(col, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").resize((208, 128), Image.LANCZOS)


# Previews --------------------------------------------------------------------------------------------------------
GROUNDS = {"grass": "#2F8A3C", "lime": "#9BD04A", "sky": "#8FCBF2", "night": "#1B2A4A", "marble": "#E9EDF2"}


def _on(ground: str, size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, rgb8(GROUNDS[ground]) + (255,))


def sheet(name: str, rows: list[list[Image.Image]], grounds: list[str], pad: int = 10) -> None:
    """Each row of sprites repeated on each ground."""
    width = max(sum(i.width + pad for i in row) for row in rows) + pad
    height = sum(max(i.height for i in row) + pad for row in rows) + pad
    out = Image.new("RGBA", (width * len(grounds), height), (0, 0, 0, 255))
    for g, ground in enumerate(grounds):
        panel = _on(ground, (width, height))
        y = pad
        for row in rows:
            x = pad
            for sprite in row:
                panel.alpha_composite(sprite, (x, y))
                x += sprite.width + pad
            y += max(i.height for i in row) + pad
        out.paste(panel, (g * width, 0))
    out.convert("RGB").save(OUT / name)


def _fly_mock(wing: Image.Image, px: int) -> Image.Image:
    """Both wings open, seen from above, px wide."""
    w, h = wing.size
    img = Image.new("RGBA", (w * 2 + 14, h), (0, 0, 0, 0))
    img.alpha_composite(wing.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    img.alpha_composite(wing, (w + 14, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((w - 2, 40, w + 16, 168), radius=8, fill=(38, 30, 24, 255))
    return img.resize((px, int(px * h / (w * 2 + 14))), Image.LANCZOS)


def _bird_mock(name: str, wing: Image.Image, tail: Image.Image, breast: Image.Image, px: int) -> Image.Image:
    """Side view, facing left: body ball, head ball, bead eye, beak, the folded wing plate, the tail."""
    look = BIRD_LOOK[name]
    S = 4
    n = 220 * S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stud = 100 * S  # px a stud
    cx, cy = 120 * S, 130 * S
    t = tail.resize((int(0.42 * stud), int(0.62 * stud)), Image.LANCZOS)
    tint = Image.new("RGBA", t.size, rgb8(look["tail"]) + (255,))
    t = Image.composite(Image.blend(Image.new("RGBA", t.size, (0, 0, 0, 255)), tint, 1.0), Image.new("RGBA", t.size, (0, 0, 0, 0)), t.getchannel("A"))
    t = t.rotate(62, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(t, (int(cx + 0.18 * stud), int(cy - 0.18 * stud)))
    r = 0.475 * stud
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgb8(look["body"]) + (255,))
    b = breast.resize((int(r * 1.5), int(r * 1.5)), Image.LANCZOS)
    bt = Image.new("RGBA", b.size, rgb8(look["breast"]) + (255,))
    bt.putalpha(b.getchannel("A"))
    img.alpha_composite(bt, (int(cx - r * 1.05), int(cy - r * 0.55)))
    hr = 0.31 * stud
    hx, hy = cx - 0.34 * stud, cy - 0.36 * stud
    d.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=rgb8(look["head"]) + (255,))
    d.polygon([(hx - hr * 0.86, hy - 0.02 * stud), (hx - hr - 0.17 * stud, hy + 0.05 * stud), (hx - hr * 0.86, hy + 0.12 * stud)], fill=rgb8(look["beak"]) + (255,))
    er = 0.065 * stud
    ex, ey = hx - 0.13 * stud, hy - 0.04 * stud
    d.ellipse((ex - er, ey - er, ex + er, ey + er), fill=(20, 17, 15, 255))
    d.ellipse((ex - er * 0.55, ey - er * 0.6, ex - er * 0.05, ey - er * 0.1), fill=(235, 235, 235, 255))
    wg = wing.resize((int(0.50 * stud), int(0.68 * stud)), Image.LANCZOS).rotate(55, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(wg, (int(cx - 0.20 * stud), int(cy - 0.34 * stud)))
    return img.resize((px, px), Image.LANCZOS)


BIRD_LOOK = {
    "ember": dict(body="#EADBC2", breast="#D9713A", head="#7A6248", tail="#5E4A36", beak="#3A3028"),
    "slate": dict(body="#EBDCC4", breast="#E0A070", head="#6F8FB3", tail="#465E7E", beak="#2E2E33"),
    "moss": dict(body="#E6D788", breast="#A6A45E", head="#3F4438", tail="#4A5230", beak="#4A4038"),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    made: dict[str, Image.Image] = {}
    for name in SPECIES:
        made[f"butterfly-{name}.png"] = butterfly(name)
        made[f"butterfly-{name}-m.png"] = made[f"butterfly-{name}.png"].transpose(Image.FLIP_LEFT_RIGHT)
    made["firefly-dot.png"] = firefly_dot()
    made["leaf-a.png"], made["leaf-b.png"] = leaf("a"), leaf("b")
    for name in BIRDS:
        made[f"bird-wing-{name}.png"] = bird_wing(name)
    made["bird-tail.png"], made["bird-breast.png"] = bird_tail(), bird_breast()
    made["nest-twigs.png"], made["nest-fringe.png"] = nest_twigs(), nest_fringe()
    made["straw-bed.png"], made["straw-wisps.png"], made["nest-sign.png"] = straw_bed(), straw_wisps(), nest_sign()
    for name, img in made.items():
        img.save(OUT / name)
        print(f"{name:28s} {img.size[0]}x{img.size[1]} {img.mode}")
    # Sheets: butterflies at 180, 60 and 28 px of span (close, 15 studs, 35 studs on a phone); leaves at 48, 20, 10.
    flies = [made[f"butterfly-{n}.png"] for n in SPECIES]
    sheet("preview-butterflies.png", [[_fly_mock(f, px) for f in flies] for px in (180, 60, 28)], ["grass", "lime", "sky"])
    lv = [made["leaf-a.png"], made["leaf-b.png"]]
    sheet("preview-leaves-firefly.png", [[l.resize((px, px), Image.LANCZOS).rotate(a, resample=Image.BICUBIC) for l in lv for a in (0, 70, 200)] for px in (64, 24, 12)]
          + [[made["firefly-dot.png"].resize((px, px), Image.LANCZOS) for px in (64, 32, 16, 8)]], ["grass", "sky", "night"])
    sheet("preview-birds.png", [[_bird_mock(n, made[f"bird-wing-{n}.png"], made["bird-tail.png"], made["bird-breast.png"], px) for n in BIRDS] for px in (220, 72, 32)]
          + [[made[f"bird-wing-{n}.png"] for n in BIRDS] + [made["bird-tail.png"], made["bird-breast.png"]]], ["lime", "sky", "grass"])
    twig2 = Image.new("RGBA", (512, 128))
    twig2.paste(made["nest-twigs.png"], (0, 0)); twig2.paste(made["nest-twigs.png"], (256, 0))
    sheet("preview-nest.png", [[twig2], [made["nest-fringe.png"].convert("RGBA"), made["straw-wisps.png"]], [made["straw-bed.png"], made["nest-sign.png"].convert("RGBA")]],
          ["grass", "marble"])


if __name__ == "__main__":
    main()
