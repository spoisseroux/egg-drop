"""UI personality pass (T5) tiled images: the title squiggle and the halftone fade.

White art on transparent, tinted in game with ImageColor3. Drawn at 2x:
  squiggle.png  24 x 12  -> TileSize 12 x 6 (one wave per tile, seamless left/right)
  halftone.png  96 x 96  -> TileSize 48 x 48 (dots grow toward the bottom edge)

Run: python scripts/build_ui_personality_tiles.py
Upload both, then put the ids in src/client/DeckAssets.lua Assets.Personality.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "personality")
SS = 8  # supersample factor for smooth edges


def squiggle():
    w, h = 24, 12
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    stroke = 2.6 * SS  # about 1.3 px at 1x
    amp = (h * SS - stroke) / 2 - SS * 0.5
    mid = h * SS / 2
    # Sample one full sine period across the tile plus a little overlap each side,
    # so the stroke caps meet the neighbouring tile with no seam.
    pts = []
    steps = 96
    for i in range(-4, steps + 5):
        x = i / steps * w * SS
        y = mid - amp * math.sin(2 * math.pi * i / steps)
        pts.append((x, y))
    r = stroke / 2
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.line([(x0, y0), (x1, y1)], fill=(255, 255, 255, 255), width=int(stroke))
        d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=(255, 255, 255, 255))
    return big.resize((w, h), Image.LANCZOS)


def halftone():
    size = 96
    pitch = 12  # 6 px at 1x; 8 columns, 8 rows
    big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    rows = size // pitch
    for row in range(rows):
        # Row 0 is the top (faint, tiny dots); the last row sits on the panel edge.
        t = (row + 1) / rows
        radius = (0.6 + 3.4 * t * t) * SS
        offset = pitch / 2 if row % 2 else 0  # staggered grid
        cy = (row * pitch + pitch / 2) * SS
        for col in range(-1, size // pitch + 1):
            cx = (col * pitch + pitch / 2 + offset) * SS
            d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(255, 255, 255, 255))
    return big.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    squiggle().save(os.path.join(OUT, "squiggle.png"))
    halftone().save(os.path.join(OUT, "halftone.png"))
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
