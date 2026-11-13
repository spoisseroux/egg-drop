"""UI personality pass P2 images: the stitched seam (T2) and the LCD dot grid (T7).

White art on transparent; DeckKit sets the transparency in game. Drawn at 2x:
  seam.png      64 x 40 -> one sheet, three ImageRects (DeckKit Kit.SeamRects):
                  corner      (0,0,40,40)  9-slice, SliceCenter 18,18,22,22, SliceScale .5
                                           (radius 8 at 1x: a card radius 14 minus the 6 px inset)
                  horizontal  (40,0,16,4)  tiled at TileSize 8 x 2 (one 5 px stitch + 3 px gap)
                  vertical    (56,0,4,16)  tiled at TileSize 2 x 8
                The edges are separate tiles so stitches keep their length on any card
                size (a plain 9-slice would stretch them). The line centre sits 1 px
                (2 px at 2x) inside the seam rect everywhere, so corners and strips meet.
  dot_grid.png  12 x 12 -> TileSize 6 x 6 (one round dot per cell, drawn at ~6% white)

Run: python scripts/build_ui_personality_surfaces.py
Upload both, then put the ids in src/client/DeckAssets.lua Assets.Personality.seam / .dotGrid.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "personality")
SS = 8  # supersample factor for smooth edges
WHITE = (255, 255, 255, 255)
THICK = 3.0  # stitch thickness at 2x (1.5 px at 1x)
CENTRE = 2.0  # line centre from the seam rect edge at 2x


def stitch(d, p0, p1, scale):
    """One rounded stitch from p0 to p1 (2x coordinates), drawn on a supersampled canvas."""
    (x0, y0), (x1, y1) = p0, p1
    r = THICK / 2 * scale
    a, b = (x0 * scale, y0 * scale), (x1 * scale, y1 * scale)
    d.line([a, b], fill=WHITE, width=int(round(THICK * scale)))
    for cx, cy in (a, b):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)


def seam():
    w, h = 64, 40
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    # Corner sheet (0,0,40,40): one stitch centred on each quarter arc. The arc's
    # centre is 18 px in from each corner (the 9-slice corner size); radius 16.
    radius = 16.0
    corners = [((18, 18), 180), ((22, 18), 270), ((22, 22), 0), ((18, 22), 90)]
    for (cx, cy), start in corners:
        mid = math.radians(start + 45)
        half = math.radians(19)
        pts = []
        steps = 16
        for i in range(steps + 1):
            t = mid - half + 2 * half * i / steps
            pts.append((cx + radius * math.cos(t), cy + radius * math.sin(t)))
        for p0, p1 in zip(pts, pts[1:]):
            stitch(d, p0, p1, SS)
    # Horizontal dash tile (40,0,16,4): a 10 px stitch (caps included) centred in 16.
    y = CENTRE
    stitch(d, (40 + 3 + THICK / 2, y), (40 + 13 - THICK / 2, y), SS)
    # Vertical dash tile (56,0,4,16).
    x = 56 + CENTRE
    stitch(d, (x, 3 + THICK / 2), (x, 13 - THICK / 2), SS)
    return big.resize((w, h), Image.LANCZOS)


def dot_grid():
    size = 12
    big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    r = 1.7 * SS
    c = size / 2 * SS
    d.ellipse([c - r, c - r, c + r, c + r], fill=WHITE)
    return big.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    seam().save(os.path.join(OUT, "seam.png"))
    dot_grid().save(os.path.join(OUT, "dot_grid.png"))
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
