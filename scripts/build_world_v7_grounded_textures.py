"""Ground the World 1 v7 surface textures (QA 2026-11-15, W1): darker, less neon, more texture.

  python scripts/build_world_v7_grounded_textures.py

Spencer's phone QA on v735: the white Bear disappears on the near-white marble, the grass is neon, the water
is cyan, the dirt path is bright orange, and everything reads flat. This is a second grade on top of the dusk
set (assets/world/textures/dusk, from build_world_v7_dusk_textures.py): marble goes mid-light grey with
stronger veining, grass and foliage go deeper and less saturated, water moves from cyan to blue, the path
becomes a dark earth brown, and rock, bark and wood drop a step. Every surface also gets more local contrast
and a faint tileable mottle so it reads as a material and not a flat fill. The drawing itself is unchanged,
so the stylized look stays. All procedural (numpy); no generated art.

Writes assets/world/textures/grounded/<material>.png (256 px) and _contact-sheet.png (dusk above, grounded
below). Upload each PNG as an Image, put the ids into assets/world/world-v7-uploads.json "textures" under the
same W1_ key (W1_water also feeds W1_water_pool / W1_water_stream), then retexture the native pack with
scripts/retexture_world_native.py (texture ids only; geometry and collision buffers stay byte-identical).
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "world" / "textures" / "dusk"
OUT = ROOT / "assets" / "world" / "textures" / "grounded"

# material: hue shift (degrees), saturation x, value x, contrast about the mean, mottle depth, multiply tint
GRADE = {
    "W1_grass": (4, 0.80, 0.70, 1.35, 0.07, (1.0, 1.0, 1.0)),
    "W1_meadow": (4, 0.80, 0.70, 1.20, 0.07, (1.0, 1.0, 1.0)),
    "W1_foliage": (2, 0.84, 0.80, 1.20, 0.05, (1.0, 1.0, 1.0)),
    "W1_foliage_blossom": (0, 0.95, 0.93, 1.15, 0.03, (1.0, 1.0, 1.0)),
    "W1_cliff_rock": (0, 0.85, 0.80, 1.30, 0.06, (1.0, 0.99, 0.98)),
    "W1_boulder_rock": (0, 0.85, 0.78, 1.30, 0.06, (1.0, 0.99, 0.98)),
    "W1_dirt_path": (-6, 0.92, 0.60, 1.60, 0.08, (1.0, 0.97, 0.93)),
    "W1_pebble_bed": (0, 0.85, 0.82, 1.15, 0.04, (1.0, 1.0, 1.0)),
    "W1_bark": (0, 0.92, 0.80, 1.25, 0.05, (1.0, 1.0, 1.0)),
    "W1_wood_plank": (-2, 0.88, 0.78, 1.25, 0.05, (1.0, 1.0, 1.0)),
    "W1_marble": (0, 0.45, 0.75, 1.70, 0.05, (0.985, 0.99, 1.0)),
    "W1_marble_smooth": (0, 0.45, 0.75, 2.20, 0.05, (0.985, 0.99, 1.0)),
    "W1_trim": (0, 0.92, 0.86, 1.0, 0.03, (0.99, 0.99, 1.0)),
    "W1_water": (18, 1.12, 0.90, 1.10, 0.04, (1.0, 1.0, 1.0)),
    "W1_waterfall_tumble": (16, 1.15, 0.94, 1.05, 0.0, (1.0, 1.0, 1.0)),
    # Near-white detail map that Roblox multiplies by the mesh vertex colours (island flanks, lawn edges):
    # it drops with the rock and grass so the tinted slopes keep matching them.
    "W1_ground": (0, 1.0, 0.80, 1.60, 0.05, (1.0, 0.99, 0.98)),
}
# Materials the dusk pass never graded take their uploaded source instead.
SOURCE = {"W1_ground": ROOT / "assets" / "art-source" / "environment" / "textures" / "v5" / "ground_soft.png"}


def rgb_to_hsv(a):
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    safe = np.where(d == 0, 1, d)
    h = np.where(mx == r, ((g - b) / safe) % 6, np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) / 6
    h = np.where(d == 0, 0, h)
    return np.stack([h, np.where(mx == 0, 0, d / np.where(mx == 0, 1, mx)), mx], -1)


def hsv_to_rgb(a):
    h, s, v = a[..., 0] * 6, a[..., 1], a[..., 2]
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    choices = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]
    return np.stack([np.choose(i, [c[k] for c in choices]) for k in range(3)], -1)


def mottle(size, seed):
    """Tileable two-octave value field in [-1, 1]: whole-number sine frequencies wrap at the tile edge."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size] / size * 2 * np.pi
    field = np.zeros((size, size))
    for lo, hi, weight in ((1, 3, 1.0), (4, 9, 0.5)):
        for _ in range(6):
            fx, fy = rng.integers(-hi, hi + 1, 2)
            if abs(fx) < lo and abs(fy) < lo:
                fx = lo
            field += weight * np.sin(fx * x + fy * y + rng.uniform(0, 2 * np.pi))
    return field / np.abs(field).max()


def grade(img, hue, sat, val, contrast, depth, tint, seed):
    a = np.asarray(img.convert("RGB")).astype(np.float64) / 255
    hsv = rgb_to_hsv(a)
    hsv[..., 0] = (hsv[..., 0] + hue / 360) % 1
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 1)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 1)
    rgb = hsv_to_rgb(hsv) * np.array(tint)
    mean = rgb.mean((0, 1), keepdims=True)
    rgb = mean + (rgb - mean) * contrast
    rgb = rgb * (1 + depth * mottle(a.shape[0], seed))[..., None]
    return Image.fromarray((np.clip(rgb, 0, 1) * 255 + .5).astype(np.uint8))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for index, (mat, (hue, sat, val, contrast, depth, tint)) in enumerate(GRADE.items()):
        before = Image.open(SOURCE.get(mat, SRC / f"{mat}.png"))
        img = grade(before, hue, sat, val, contrast, depth, tint, 7350 + index)
        img.save(OUT / f"{mat}.png", optimize=True)
        tiles.append((before.convert("RGB").resize((128, 128)), img.resize((128, 128))))
    sheet = Image.new("RGB", (len(tiles) * 132, 264), (40, 40, 40))
    for i, (b, a) in enumerate(tiles):
        sheet.paste(b, (i * 132, 0)); sheet.paste(a, (i * 132, 134))
    sheet.save(OUT / "_contact-sheet.png")
    print("wrote", len(tiles), "textures to", OUT)


if __name__ == "__main__":
    main()
