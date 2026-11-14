"""Bond level-up heart sprite: one soft, puffy white heart (tinted at runtime by ImageColor3).

Run: python scripts/deck_art/build_bond_heart.py
Writes assets/ui/bond/heart-burst.png (64 x 64, white on transparent). Procedural (numpy + PIL):
the heart is the implicit curve (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0, softened at the rim, shaded with
a gentle lower-edge falloff in alpha only (so any tint stays clean) and a small gloss highlight.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "bond" / "heart-burst.png"
N, SS = 64, 8


def main():
    g = N * SS
    yy, xx = np.mgrid[0:g, 0:g].astype(np.float32)
    # heart space, y up
    x = (xx / (g - 1) - 0.5) * 2.9
    y = -(yy / (g - 1) - 0.5) * 2.9 + 0.12                # the curve spans y -1..1.24: centre it
    x = x * 0.94                                              # a touch wider: puffier lobes
    f = (x * x + y * y - 1) ** 3 - x * x * y ** 3
    body = (f <= 0).astype(np.float32)
    im = Image.fromarray((body * 255).astype(np.uint8), "L")
    soft = np.asarray(im.filter(ImageFilter.GaussianBlur(SS * 1.1))).astype(np.float32) / 255
    # round the cleft and the point: threshold the blurred mask, then feather it again
    puffy = np.clip((soft - 0.42) / 0.16, 0, 1)
    edge = np.asarray(Image.fromarray((puffy * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(SS * 0.9))).astype(np.float32) / 255
    inner = np.asarray(Image.fromarray((puffy * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(SS * 3.2))).astype(np.float32) / 255
    alpha = edge * (0.80 + 0.20 * np.clip(inner * 1.25, 0, 1))  # soft pillow: fuller in the middle
    # gloss: a small bright bean on the upper-left lobe (alpha only; the sprite is pure white)
    gx, gy = (x + 0.52) / 0.30, (y - 0.48) / 0.17
    rot = gx * 0.86 - gy * 0.5, gx * 0.5 + gy * 0.86
    gloss = np.exp(-(rot[0] ** 2 + rot[1] ** 2) * 1.6) * puffy
    alpha = np.clip(alpha * 0.92 + gloss * 0.25, 0, 1)
    rgba = np.zeros((g, g, 4), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (alpha * 255 + 0.5).astype(np.uint8)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").resize((N, N), Image.LANCZOS).save(OUT)
    a = np.asarray(Image.open(OUT))[..., 3]
    ys, xs = np.nonzero(a > 8)
    print("heart", OUT.name, "bbox", xs.min(), ys.min(), xs.max(), ys.max(), "max alpha", a.max())
    # review: 4x on a dark and a light ground, tinted
    sheet = Image.new("RGB", (N * 8 + 48, N * 4 + 32), "#1B1F4A")
    for i, (bg, tint) in enumerate((("#1B1F4A", "#FFB8D0"), ("#BFE8C8", "#FF7AA8"))):
        cell = Image.new("RGB", (N * 4, N * 4), bg)
        big = Image.open(OUT).resize((N * 4, N * 4), Image.LANCZOS)
        cell.paste(Image.new("RGB", big.size, tint), (0, 0), big.split()[3])
        sheet.paste(cell, (16 + i * (N * 4 + 16), 16))
    sheet.save(ROOT / "artifacts" / "overnight-2026-11-14" / "art" / "bond-heart-preview.png")


if __name__ == "__main__":
    main()
