"""Re-grade the World 1 v7 surface textures for the locked dusk (batch 2026-11-13, W1).

  python scripts/build_world_v7_dusk_textures.py

The dusk key light is golden (WorldDusk: ColorShift_Top #FFD49A, peach haze, warm grade), which pushes green
grass toward olive, beige rock toward orange and blue water toward grey. Each texture gets a small counter-grade
so the lit result stays saturated and readable, the way the mood reference reads: grass a little greener and more
saturated, rock a cooler grey-olive, water a clearer turquoise, marble and trim kept slightly cool so they read
cream (not orange) in the warm light. Sources: assets/art-source/environment/textures/v5 (the uploaded set).

Writes assets/world/textures/dusk/<material>.png (256 px) and assets/world/textures/dusk/_contact-sheet.png.
Upload each PNG as an Image and put the ids into assets/world/world-v7-uploads.json "textures" under the same
W1_ key (W1_water also feeds W1_water_pool / W1_water_stream), then run scripts/build_world_v7_assets.py.
"""
from __future__ import annotations

import colorsys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "art-source" / "environment" / "textures" / "v5"
OUT = ROOT / "assets" / "world" / "textures" / "dusk"

# material: (source file, hue shift in degrees, saturation x, value x, multiply tint)
GRADE = {
    "W1_grass": ("grass", 7, 1.22, 1.04, (0.97, 1.0, 0.98)),
    "W1_meadow": ("meadow", 7, 1.18, 1.04, (0.97, 1.0, 0.98)),
    "W1_foliage": ("foliage", 6, 1.15, 1.05, (0.97, 1.0, 0.98)),
    "W1_foliage_blossom": ("foliage_blossom", -4, 1.08, 1.03, (1.0, 0.97, 1.0)),
    "W1_cliff_rock": ("cliff_rock", 18, 0.72, 1.0, (0.95, 0.98, 0.98)),
    "W1_boulder_rock": ("boulder_rock", 18, 0.72, 1.0, (0.95, 0.98, 0.98)),
    "W1_dirt_path": ("dirt_path", -3, 0.95, 1.02, (1.0, 0.98, 0.97)),
    "W1_pebble_bed": ("pebble_bed", 0, 0.95, 1.02, (0.98, 0.98, 1.0)),
    "W1_bark": ("bark", 0, 0.95, 1.04, (0.98, 0.97, 0.98)),
    "W1_wood_plank": ("wood_plank", 0, 0.95, 1.02, (0.98, 0.98, 0.98)),
    "W1_marble": ("marble_block", 0, 1.0, 1.0, (0.97, 0.97, 1.0)),
    "W1_marble_smooth": ("marble_smooth", 0, 1.0, 1.0, (0.97, 0.97, 1.0)),
    "W1_trim": ("marble_trim", 0, 1.05, 1.0, (0.98, 0.98, 1.0)),
    "W1_water": ("water", -8, 1.15, 1.0, (0.94, 1.0, 1.0)),
    "W1_waterfall_tumble": ("waterfall", -8, 1.1, 1.0, (0.96, 1.0, 1.0)),
}


def grade(img, hue, sat, val, tint):
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255
    flat = a.reshape(-1, 3)
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in flat])
    hsv[:, 0] = (hsv[:, 0] + hue / 360) % 1
    hsv[:, 1] = np.clip(hsv[:, 1] * sat, 0, 1)
    hsv[:, 2] = np.clip(hsv[:, 2] * val, 0, 1)
    rgb = np.array([colorsys.hsv_to_rgb(*p) for p in hsv]).reshape(a.shape)
    rgb = np.clip(rgb * np.array(tint, np.float32), 0, 1)
    return Image.fromarray((rgb * 255 + .5).astype(np.uint8))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for mat, (src, hue, sat, val, tint) in GRADE.items():
        img = grade(Image.open(SRC / f"{src}.png"), hue, sat, val, tint)
        img.save(OUT / f"{mat}.png")
        before = Image.open(SRC / f"{src}.png").convert("RGB").resize((128, 128))
        tiles.append((before, img.resize((128, 128))))
    sheet = Image.new("RGB", (len(tiles) * 132, 264), (40, 40, 40))
    for i, (b, a) in enumerate(tiles):
        sheet.paste(b, (i * 132, 0)); sheet.paste(a, (i * 132, 134))
    sheet.save(OUT / "_contact-sheet.png")
    print("wrote", len(tiles), "textures to", OUT)


if __name__ == "__main__":
    main()
