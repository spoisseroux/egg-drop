"""The egg machine's one 512 px texture (EGG-CORNER-LOOK section 2, Fable 2026-11-24). Drawn from scratch with
numpy/PIL, fixed seed: enamel cream base with a hand-painted darker band and brush grain, leaf green with painted
veins, straw weave, sunflower dial with petal shading, a cream knob, deep garden green. No AI art.

Atlas (pixel rectangles x0, y0, x1, y1; image y down). scripts/build_egg_machine.py maps UVs into these:
  BASE  (0, 0, 256, 256)     cream enamel; u around the base, v up it (row 255 = the foot, row 0 = the top). The band
                             sits where the base is widest (1.25 to 1.55 studs up of 0.35 to 2.95).
  LEAF  (256, 0, 512, 128)   leaf green, veins along u (the leaf's length), underside darker in the lower half
  STRAW (256, 128, 512, 256) straw weave (u around the cup, v up it)
  DIAL  (0, 256, 256, 512)   sunflower, planar: centre at (128, 384), radius 128 = the dial's outer petal tip
  GREEN (256, 256, 384, 384) deep garden green, matte (feet, cap)
  KNOB  (384, 256, 512, 384) knob cream
  EMBOSS (256, 384, 384, 512) darker sunflower #E0A422 (the dial's embossed egg)
  (384, 384, 512, 512): spare, cream

Run from the repository root:  python -I scripts/draw_egg_machine_texture.py
Writes assets/world/egg-machine/egg-machine.png and egg-machine-rough60.png
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "world", "egg-machine", "egg-machine.png")

CREAM, BAND = (0xF4, 0xE8, 0xCF), (0xE2, 0xD2, 0xB0)
LEAF, LEAF_UNDER = (0x6F, 0xBF, 0x73), (0x4E, 0x9A, 0x5A)
SUN, KNOB = (0xFF, 0xC8, 0x3C), (0xFF, 0xF3, 0xC4)
GREEN = (0x38, 0x69, 0x4A)
STRAW, STRAW_DARK = (0xC9, 0xA5, 0x60), (0x8A, 0x6A, 0x3A)


def wrapped_noise(rng, w, h, cycles, octaves=8):
    y, x = np.mgrid[0:h, 0:w]
    x, y = x / w, y / h
    out = np.zeros((h, w))
    for _ in range(octaves):
        fx, fy = rng.integers(-cycles, cycles + 1, 2)
        if fx == 0 and fy == 0:
            fx = 1
        out += np.sin(2 * np.pi * (fx * x + fy * y) + rng.uniform(0, 2 * np.pi)) / math.hypot(fx, fy)
    return out / np.max(np.abs(out))


def fill(img, box, colour):
    x0, y0, x1, y1 = box
    img[y0:y1, x0:x1] = colour


def base(img, rng):
    w = h = 256
    v = np.arange(h)[:, None] / (h - 1)                  # 0 top .. 1 foot
    height = 2.95 - v * 2.6                               # studs up the base
    band = np.clip(1 - np.abs(height - 1.4) / .15, 0, 1) ** .6
    band = band * (.85 + .15 * wrapped_noise(rng, w, h, 6)[:, :] ** 2)    # hand-painted: uneven edge
    col = np.array(CREAM, float) * (1 - band[..., None]) + np.array(BAND, float) * band[..., None]
    grain = wrapped_noise(rng, w, h, 40, 14) * .025 + np.repeat(rng.normal(0, .012, (1, w)), h, 0)  # vertical brush grain
    col = col * (1 + grain[..., None])
    # a few chips at the top rim and foot: small slightly darker blots
    for _ in range(7):
        cx, cy = rng.uniform(0, w), rng.choice([rng.uniform(2, 14), rng.uniform(240, 254)])
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.hypot((xx - cx + w / 2) % w - w / 2, yy - cy)
        col = col * (1 - .10 * np.clip(1 - d / rng.uniform(2, 4.5), 0, 1)[..., None])
    img[0:256, 0:256] = np.clip(col, 0, 255)


def leaf(img, rng):
    w, h = 256, 128
    v = np.arange(h)[:, None] / (h - 1)
    under = np.clip((v - .5) * 6, 0, 1)
    col = np.array(LEAF, float) * (1 - under[..., None]) + np.array(LEAF_UNDER, float) * under[..., None]
    col = np.repeat(col, w, 1) if col.shape[1] == 1 else col
    col = col * (1 + .03 * wrapped_noise(rng, w, h, 10)[..., None])
    yy, xx = np.mgrid[0:h, 0:w]
    # midrib along u at v = .25 (top side) and .75 (underside); side veins every 32 px, angled forward
    for mid in (.25 * h, .75 * h):
        col = col * (1 - .10 * np.clip(1 - np.abs(yy - mid) / 1.6, 0, 1)[..., None])
        for k in range(8):
            x0 = k * 32 + 8
            for side in (-1, 1):
                d = np.abs((yy - mid) * side * .9 - (xx - x0) * .55)
                mask = (np.abs(yy - mid) < h * .22) & (xx > x0) & (np.sign(yy - mid) == side)
                col = col * (1 - .07 * (np.clip(1 - d / 1.2, 0, 1) * mask)[..., None])
    img[0:128, 256:512] = np.clip(col, 0, 255)


def straw(img, rng):
    w, h = 256, 128
    yy, xx = np.mgrid[0:h, 0:w]
    rows = (yy // 10) % 2
    weave = .5 + .5 * np.sin(2 * np.pi * (xx + rows * 8) / 16)
    t = np.clip(weave * .8 + .1 * wrapped_noise(rng, w, h, 8), 0, 1)
    col = np.array(STRAW_DARK, float) * (1 - t[..., None]) + np.array(STRAW, float) * t[..., None]
    gaps = (yy % 10 == 0)
    col[gaps] = col[gaps] * .8
    img[128:256, 256:512] = np.clip(col, 0, 255)


def dial(img, rng):
    s = 256
    yy, xx = np.mgrid[0:s, 0:s] + .5
    u, v = (xx - 128) / 128, (yy - 128) / 128
    r = np.hypot(u, v)
    th = np.arctan2(v, u)
    petal = .5 + .5 * np.cos(6 * th)                     # 6 petals
    shade = 1 - .14 * (1 - petal) * np.clip(r, 0, 1)      # darker between petals, toward the rim
    shade *= 1 - .08 * np.clip((r - .8) / .2, 0, 1)        # darker edge
    shade *= 1 + .06 * np.clip(1 - r / .35, 0, 1)          # warm centre
    col = np.array(SUN, float)[None, None, :] * shade[..., None]
    col *= 1 + .02 * wrapped_noise(rng, s, s, 12)[..., None]
    img[256:512, 0:256] = np.clip(col, 0, 255)


def main():
    rng = np.random.default_rng(424)
    img = np.zeros((512, 512, 3)) + np.array(CREAM, float)
    base(img, rng)
    leaf(img, rng)
    straw(img, rng)
    dial(img, rng)
    fill(img, (256, 256, 384, 384), GREEN)
    g = img[256:384, 256:384] * (1 + .03 * wrapped_noise(rng, 128, 128, 6)[..., None])
    img[256:384, 256:384] = np.clip(g, 0, 255)
    fill(img, (384, 256, 512, 384), KNOB)
    fill(img, (256, 384, 384, 512), (0xE0, 0xA4, 0x22))   # EMBOSS: darker sunflower (Fable render R1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(img.round().astype(np.uint8), "RGB").save(OUT)
    # The body's flat roughness .6 (painted enamel), 8 x 8 grey 153.
    Image.new("L", (8, 8), 153).save(os.path.join(os.path.dirname(OUT), "egg-machine-rough60.png"))
    print("wrote", os.path.relpath(OUT, ROOT), "and egg-machine-rough60.png")


if __name__ == "__main__":
    main()
