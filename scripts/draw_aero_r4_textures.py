"""Round 4 Aero maps (LOOK-R4, Fable 2026-11-23): the falls atlas (static streaks that read with no motion) and the
denser leaf-cluster tiles. Drawn from scratch with numpy/PIL, fixed seeds, seamless where they tile.

Run from the repository root:  python -I scripts/draw_aero_r4_textures.py
Writes assets/world/textures/aero/{falls-atlas, leaf-dark, leaf-lime}.png (leaf-rough stays flat 1.0) and
artifacts/world-pass-2026-11-22/reexport/r8/textures-r4-report.json (+ preview sheets).

Falls atlas, 512 x 512 (image rows from the top):
  rows 0-383    streaks: 16 studs wide (32 px a stud, U wraps), 24 studs tall (16 px a stud, top and bottom rows match)
  rows 384-399  white gutter
  rows 400-511  white block (rock faces, foam, lip, apron sample it at row ~456)
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "world", "textures", "aero")
EVIDENCE = os.path.join(ROOT, "artifacts", "world-pass-2026-11-22", "reexport", "r8")

STREAK_ROWS = 384
RENDER_COMP = (1.21, .99, .90)
PX_U, PX_V = 32, 16          # px per stud across / down in the streak region
BASE = (168, 205, 224)
LAYERS = [  # name, width studs, count per 16 studs, length studs, colour
    # counts raised from Fable's 4 / 9 / 5 to reach her area shares (deep 8, mid 25, wide 35 percent)
    ("deep", (.3, .5), 22, (5, 10), (132, 180, 206)),
    ("mid", (.4, .8), 36, (8, 20), (222, 238, 245)),
    ("wide", (.9, 1.6), 9, (10, 24), (246, 251, 253)),
    ("hair", (.12, .25), 20, (3, 8), (236, 246, 250)),
]


def spaced(rng, count, width, min_gap, tries=500):
    """`count` positions on a ring of `width` px, at least `min_gap` apart (wrapped), not evenly spaced."""
    for _ in range(tries):
        xs = sorted(rng.uniform(0, width, count))
        gaps = np.diff(np.append(xs, xs[0] + width))
        if gaps.min() >= min_gap and gaps.std() > min_gap * .25:
            return xs
    return sorted(rng.uniform(0, width, count))


def falls_atlas(report):
    rng = np.random.default_rng(1123)
    w, h = 512, STREAK_ROWS
    img = np.zeros((h, w, 3)) + np.array(BASE, float)
    owner = np.zeros((h, w), np.int8)  # 0 base, 1 deep, 2 mid, 3 wide (for the area report)
    yy = np.arange(h)
    for li, (name, (w0, w1), count, (l0, l1), colour) in enumerate(LAYERS):
        min_gap = 2 * PX_U if name == "deep" else 0
        xs = spaced(rng, count, w, min_gap) if name in ("deep", "wide") else rng.uniform(0, w, count)
        for xc in xs:
            width = rng.uniform(w0, w1) * PX_U
            length = rng.uniform(l0, l1) * PX_V
            y0 = rng.uniform(0, h)
            taper = rng.uniform(2, 3) * PX_V
            wob_amp, wob_per, wob_ph = rng.uniform(0, .15) * PX_U, rng.uniform(4, 9) * PX_V, rng.uniform(0, 2 * math.pi)
            # rows along the streak, wrapped in y (period h)
            d = (yy - y0) % h
            on = d < length
            along = np.where(on, np.minimum(np.minimum(d, length - d) / taper, 1.0), 0.0)
            centre = xc + wob_amp * np.sin(2 * math.pi * yy / wob_per + wob_ph)
            for y in np.nonzero(on)[0]:
                xs_ = np.arange(int(centre[y] - width / 2 - 4), int(centre[y] + width / 2 + 5))
                dist = np.abs(xs_ + .5 - centre[y]) - width / 2
                a = np.clip(1 - (dist + 1.5) / 3.0, 0, 1) * along[y]      # 3 px feather
                cols = xs_ % w
                img[y, cols] = img[y, cols] * (1 - a[:, None]) + np.array(colour, float) * a[:, None]
                if name != "hair":
                    owner[y, cols[a > .5]] = li + 1
    floor = np.array(LAYERS[0][4], float)
    img = np.maximum(img, floor)  # nothing darker than the deep accents (no "cracks")
    # Studio r14: the sheet leans its shading toward the sky, which lifts blue and leaves red short; drawn at Fable's
    # values it rendered (124, 194, 248) against the layers-on (150, 192, 224). The file holds compensated values.
    img = np.clip(img * np.array(RENDER_COMP), 0, 255)
    atlas = np.full((512, 512, 3), 255.0)
    atlas[:h] = img
    out = atlas.round().astype(np.uint8)
    Image.fromarray(out, "RGB").save(os.path.join(OUT, "falls-atlas.png"))
    shares = {n: round(float((owner == i).mean()), 3) for i, n in enumerate(("base", "deep", "mid", "wide"))}
    report["falls-atlas"] = {"px": 512, "streak_rows": h, "studs": [16, 24], "shares": shares,
                             "streak_mean": [round(float(v), 1) for v in out[:h].reshape(-1, 3).mean(0)],
                             "streak_min": [int(v) for v in out[:h].reshape(-1, 3).min(0)],
                             "periodic_in_v": True}


# ------------------------------------------------------------------------------------------------------ leaf tiles
LEAF_STEPS = {  # gap, layer 1 (deepest) .. 3, tips (top layer only)
    "leaf-lime": [(40, 104, 34), (72, 138, 40), (108, 172, 48), (140, 200, 58), (176, 222, 84)],
    "leaf-dark": [(22, 70, 40), (34, 96, 50), (44, 118, 58), (58, 138, 66), (84, 160, 80)],
}
# (layer, sprigs): tuned to the visible shares (gap 8, 22, 34, 30, tips 6 percent). Fable's 1100-1300 leaves cannot close
# the gaps to 8 percent at 0.20-0.31-stud leaves (a 4-stud tile needs ~4x that leaf area), so the shares win.
LEAF_LAYERS = [(1, 250), (2, 125), (3, 64), (4, 10)]


def wrapped_noise(rng, size, cycles, octaves=8):
    y, x = np.mgrid[0:size, 0:size] / size
    out = np.zeros((size, size))
    for _ in range(octaves):
        fx, fy = rng.integers(-cycles, cycles + 1, 2)
        if fx == 0 and fy == 0:
            fx = 1
        out += np.sin(2 * np.pi * (fx * x + fy * y) + rng.uniform(0, 2 * np.pi)) / math.hypot(fx, fy)
    return out / np.max(np.abs(out))


def shade(c, k):
    return tuple(int(max(0, min(255, round(v * k)))) for v in c)


def leaf_layout(rng, size):
    """Sprigs of 5-7 leaves fanning from one point, pointing within 50 degrees of straight down, in four layers."""
    leaves = []
    for layer, sprigs in LEAF_LAYERS:
        for _ in range(sprigs):
            sx, sy = rng.uniform(0, size), rng.uniform(0, size)
            sdir = math.pi / 2 + math.radians(rng.uniform(-50, 50))      # image +y is down
            n = int(rng.integers(5, 8))
            for k in range(n):
                ang = sdir + math.radians(-45 + 90 * (k + rng.uniform(-.3, .3)) / max(1, n - 1))
                length = rng.uniform(26, 40) * size / 512          # px at the supersampled size (0.20-0.31 stud)
                width = length * rng.uniform(.45, .55)
                step = rng.uniform(.1, .35) * length
                bx, by = sx + math.cos(ang) * step, sy + math.sin(ang) * step
                leaves.append((layer, bx, by, ang, length, width, rng.uniform() < .5))
    return leaves


def leaf_tiles(report):
    size, ss = 512, 2
    big = size * ss
    rng = np.random.default_rng(91)
    leaves = leaf_layout(rng, big)
    drift = wrapped_noise(np.random.default_rng(7), size, 2) * .06 + 1   # +-6 percent, ~2-stud period
    out = {}
    layer_img = None
    for tile, steps in LEAF_STEPS.items():
        im = Image.new("RGB", (big, big), steps[0])
        lay = Image.new("L", (big, big), 0)
        d = ImageDraw.Draw(im)
        dl = ImageDraw.Draw(lay)
        for layer, bx, by, ang, length, width, flip in leaves:
            base = steps[layer]
            ca, sa = math.cos(ang), math.sin(ang)
            left, right = [], []
            for k in range(11):
                t = k / 10
                half = width / 2 * math.sin(math.pi * t) ** .75
                left.append((t * length, -half))
                right.append((t * length, half))

            def place(pts, ox, oy):
                return [(bx + ox + a * ca - b * sa, by + oy + a * sa + b * ca) for a, b in pts]
            dark_half = right if flip else left
            for ox in (-big, 0, big):
                for oy in (-big, 0, big):
                    if not (-60 < bx + ox < big + 60 and -60 < by + oy < big + 60):
                        continue
                    d.polygon(place(left + right[::-1], ox, oy), fill=base)
                    dl.polygon(place(left + right[::-1], ox, oy), fill=layer)
                    d.polygon(place(dark_half + [(length, 0), (0, 0)], ox, oy), fill=shade(base, .92))   # one half 8% darker
                    d.line(place([(length * .05, 0), (length * .92, 0)], ox, oy), fill=shade(base, .88), width=2 * ss // 2 + 1)
                    lower = right if math.sin(ang) * 1 >= 0 else left
                    d.line(place(lower, ox, oy), fill=shade(base, .85), width=ss)                       # darker lower rim
        small = np.array(im.resize((size, size), Image.LANCZOS)).astype(float) * drift[..., None]
        arr = np.clip(small, 0, 255).round().astype(np.uint8)
        Image.fromarray(arr, "RGB").save(os.path.join(OUT, tile + ".png"))
        out[tile] = [round(float(v), 1) for v in arr.reshape(-1, 3).mean(0)]
        layer_img = np.array(lay.resize((size, size), Image.NEAREST))
    shares = {name: round(float((layer_img == i).mean()), 3) for i, name in enumerate(("gap", "layer1", "layer2", "layer3", "tips"))}
    report["leaf-tiles"] = {"px": size, "studs": 4, "leaves": len(leaves), "shares": shares, "means": out}


def sheet(names, path, tile=3):
    imgs = [Image.open(os.path.join(OUT, n + ".png")).convert("RGB") for n in names]
    w = sum(i.width * (tile if t else 1) for i, t in zip(imgs, [True] * len(imgs)))
    h = max(i.height for i in imgs) * tile
    canvas = Image.new("RGB", (w, h), (30, 30, 30))
    x = 0
    for im in imgs:
        for i in range(tile):
            for j in range(tile):
                canvas.paste(im, (x + i * im.width, j * im.height))
        x += im.width * tile
    canvas.thumbnail((2400, 2400))
    canvas.save(path, quality=88)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(EVIDENCE, exist_ok=True)
    report = {}
    falls_atlas(report)
    leaf_tiles(report)
    sheet(["leaf-lime", "leaf-dark"], os.path.join(EVIDENCE, "leaf-tiles-3x3.jpg"))
    sheet(["falls-atlas"], os.path.join(EVIDENCE, "falls-atlas-3x3.jpg"))
    with open(os.path.join(EVIDENCE, "textures-r4-report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
