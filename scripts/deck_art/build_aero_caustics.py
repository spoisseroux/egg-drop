"""The deck's Aero light-net (AERO-JUICE-BRIEF 2 P5): one original tiling caustic pattern, drawn from scratch.

    python scripts/deck_art/build_aero_caustics.py

Writes assets/ui/aero-caustics-512.png: white light lines on transparent, 2 x 2 copies of a 256 px tile, so AeroUI can
scroll it by ImageRectOffset (0..256) inside a 256 px ImageRectSize without a seam. AeroUI draws it at 6% alpha.
Upload it and put its rbxassetid in AeroUI.CausticsImage (an empty slot until then).

The net: the sum of four wrapped sine waves on a torus (integer frequencies, so the tile wraps), folded with abs() into
ridges; the ridges are the bright lines. Deterministic (no randomness).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TILE = 256
OUT = ROOT / "assets/ui/aero-caustics-512.png"


def tile():
    y, x = np.mgrid[0:TILE, 0:TILE] / TILE * 2 * np.pi
    field = np.zeros((TILE, TILE))
    for fx, fy, phase in ((2, 1, 0.3), (-1, 3, 1.7), (3, -2, 2.9), (1, 2, 4.1)):
        field += np.sin(fx * x + fy * y + phase + 0.8 * np.sin(fy * x - fx * y + phase))
    ridge = 1 - np.abs(field) / np.abs(field).max()
    lines = np.clip((ridge - 0.78) / 0.22, 0, 1) ** 1.6
    return (lines * 255).astype(np.uint8)


def main():
    alpha = np.tile(tile(), (2, 2))
    rgba = np.zeros((TILE * 2, TILE * 2, 4), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = alpha
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT)
    covered = float((alpha > 32).mean())
    print(f"wrote {OUT.relative_to(ROOT)} ({TILE * 2} px, {covered:.0%} lit)")
    assert np.array_equal(alpha[:, :TILE], alpha[:, TILE:]) and np.array_equal(alpha[:TILE], alpha[TILE:]), "tile wraps"


if __name__ == "__main__":
    main()
