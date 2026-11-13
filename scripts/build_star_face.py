"""UI personality pass (T9): the Star's face, drawn on transparent (no star body).

star_face.png  256 x 128, two 128 px cells laid over the gold Star:
  cell 0 (x 0..127)    results hero face: eyes with glints, a smile, pink cheeks
  cell 1 (x 128..255)  wallet eyes only (the Kit.wallet Star from 20 px up)

The face sits where the Star body's centre is in the 64 px ui/icons.png star cell
and on the results Star (eyes at 39% / 61% across, 52% down).

Run: python scripts/build_star_face.py
Upload, then put the id in src/client/DeckAssets.lua Assets.Personality.starFace.
Until then Kit.wallet and DeckResults draw the same face with Frames.
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "personality")
SS = 8  # supersample factor
CELL = 128
INK = (59, 38, 8, 255)  # #3B2608, dark warm brown on Star gold
GLINT = (255, 255, 255, 255)
CHEEK = (255, 122, 140, 150)


def oval(d, cx, cy, rx, ry, fill):
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=fill)


def eyes(d, ox, glints):
    for side in (-1, 1):
        cx = ox + CELL * (0.5 + side * 0.11)
        cy = CELL * 0.52
        oval(d, cx, cy, CELL * 0.055, CELL * 0.085, INK)
        if glints:
            oval(d, cx - CELL * 0.016, cy - CELL * 0.03, CELL * 0.018, CELL * 0.022, GLINT)


def smile(d, ox):
    # A small U: an arc stroke under the eyes.
    cx, cy = ox + CELL * 0.5, CELL * 0.63
    rx, ry = CELL * 0.075, CELL * 0.055
    width = int(CELL * 0.03 * SS)
    box = [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]
    d.arc(box, start=15, end=165, fill=INK, width=width)


def cheeks(d, ox):
    for side in (-1, 1):
        oval(d, ox + CELL * (0.5 + side * 0.21), CELL * 0.62, CELL * 0.055, CELL * 0.035, CHEEK)


def main():
    os.makedirs(OUT, exist_ok=True)
    big = Image.new("RGBA", (CELL * 2 * SS, CELL * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    cheeks(d, 0)
    eyes(d, 0, glints=True)
    smile(d, 0)
    eyes(d, CELL, glints=False)
    img = big.resize((CELL * 2, CELL), Image.LANCZOS)
    path = os.path.join(OUT, "star_face.png")
    img.save(path)
    print("wrote", os.path.normpath(path), img.size)


if __name__ == "__main__":
    main()
