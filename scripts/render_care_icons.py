"""The pet screen's carry icons (beta 42 note 14, D14; POINTER-STORK-BRIEF section 3): Pick up and Set down.

Original vector art drawn here with PIL (no generated art, no downloads), in the DashIcons style: 256 x 256,
transparent, ink #15143A, round caps, plus white copies that tint with ImageColor3. Deterministic: the same shapes,
drawn 4x and scaled down with LANCZOS, give the same bytes on every run.

  pick-up:  a Pal head (circle r 46 at (128,112), ears r 18 at (92,74) and (164,74), eye holes r 7 at (112,110) and
            (144,110)) in a cupped hand (an open arc, centre (128,150), r 78, 20 to 160 degrees, stroke 22), with two
            lift marks over the ears ((76,34)-(92,50) and (180,34)-(164,50), stroke 14).
  set-down: the same head; the hand arc r 70; no lift marks; a flat ground line (56,236)-(200,236), stroke 14.

Writes assets/ui/care/{pick-up,set-down,pick-up-white,set-down-white}.png.
Run: python scripts/render_care_icons.py
Upload each, then put the ids in src/client/CareIcons.lua CareIcons.Ids (pickUp, setDown, pickUpWhite, setDownWhite).
Until then GardenCareClient draws the old frame-built arrow (DeckArt.carryArrow).
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "care")
SIZE = 256
SS = 4
INK = (0x15, 0x14, 0x3A, 255)
WHITE = (255, 255, 255, 255)


def s(value):
    return value * SS


def disc(draw, cx, cy, r, fill):
    draw.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=fill)


def stroke(draw, a, b, width, fill):
    """A straight stroke with round caps."""
    draw.line([s(a[0]), s(a[1]), s(b[0]), s(b[1])], fill=fill, width=s(width))
    for x, y in (a, b):
        disc(draw, x, y, width / 2, fill)


def arc(draw, cx, cy, r, start, end, width, fill):
    """An open arc (degrees clockwise from 3 o'clock, y down) with round caps. Drawn as short round-capped chords so
    the edge is as smooth as the discs after the downscale."""
    steps = 96
    points = []
    for i in range(steps + 1):
        t = math.radians(start + (end - start) * i / steps)
        points.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    for a, b in zip(points, points[1:]):
        stroke(draw, a, b, width, fill)


def head(img, colour):
    draw = ImageDraw.Draw(img)
    for x, y in ((92, 74), (164, 74)):
        disc(draw, x, y, 18, colour)
    disc(draw, 128, 112, 46, colour)
    # The eye holes are holes: cut back to transparent.
    clear = (0, 0, 0, 0)
    for x, y in ((112, 110), (144, 110)):
        disc(draw, x, y, 7, clear)


def icon(kind, colour):
    img = Image.new("RGBA", (s(SIZE), s(SIZE)), (0, 0, 0, 0))
    head(img, colour)
    draw = ImageDraw.Draw(img)
    if kind == "pick-up":
        arc(draw, 128, 150, 78, 20, 160, 22, colour)
        stroke(draw, (76, 34), (92, 50), 14, colour)
        stroke(draw, (180, 34), (164, 50), 14, colour)
    else:
        arc(draw, 128, 150, 70, 20, 160, 22, colour)
        stroke(draw, (56, 236), (200, 236), 14, colour)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for kind in ("pick-up", "set-down"):
        for suffix, colour in (("", INK), ("-white", WHITE)):
            path = os.path.join(OUT, f"{kind}{suffix}.png")
            icon(kind, colour).save(path, optimize=False)
            written.append(os.path.relpath(path))
    for path in written:
        print(path)


if __name__ == "__main__":
    main()
