"""Build the station attract icons (FEEL-ALIVE-DIRECTION-2026-11-13 D1; park icon QA Q4 2026-11-13).

    python scripts/build_attract_icons.py            # all four
    python scripts/build_attract_icons.py park       # only the named kinds

Writes assets/ui/attract/attract_icon_{deck,eggs,care,park}.png (256 px, transparent,
straight alpha) for BillboardGui ImageLabels in StationAttract.lua. Same bubble
as the approved mockup icons (artifacts/feel-alive-2026-11-13/sprites/), with
Spencer's fixes: the egg glyph stands the right way up (narrow end on top,
broad round base) and the deck glyph is the plain handheld (no thumbsticks).
Upload them and put the ids in src/client/StationAttractData.lua (IconIds).
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui" / "attract"
NAVY = (36, 48, 79)
HUES = {"deck": (53, 199, 245), "eggs": (255, 200, 60), "care": (255, 111, 174), "park": (118, 224, 174)}
SIZE = 256


def sparkle(d, x, y, r, color):
    d.polygon([(x, y - r), (x + r * .26, y - r * .26), (x + r, y), (x + r * .26, y + r * .26), (x, y + r),
               (x - r * .26, y + r * .26), (x - r, y), (x - r * .26, y - r * .26)], fill=color)


def egg_outline(cx, cy, r):
    """An upright egg: the top half is taller and narrower than the round base."""
    pts = []
    for i in range(96):
        t = i / 96 * math.tau
        s = math.sin(t)
        width = r * .80 * (1 - .17 * max(s, 0))          # taper only the upper half
        height = r * (1.08 if s > 0 else .82)           # long top, short round bottom
        pts.append((cx + math.cos(t) * width, cy + r * .14 - s * height))
    return pts


def glyph(d, kind, cx, cy, r, hue):
    if kind == "deck":
        w, h = r * 1.25, r * .78
        d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=h * .55, fill=(59, 74, 120))
        d.rounded_rectangle([cx - w * .42, cy - h * .58, cx + w * .42, cy + h * .58], radius=h * .14, fill=(143, 232, 255))
        a = h * .2
        d.rectangle([cx - w * .82, cy - a * .45, cx - w * .52, cy + a * .45], fill=(255, 255, 255))
        d.rectangle([cx - w * .67 - a * .45, cy - a * 1.2, cx - w * .67 + a * .45, cy + a * 1.2], fill=(255, 255, 255))
        d.ellipse([cx + w * .55, cy - h * .5, cx + w * .55 + a * 1.3, cy - h * .5 + a * 1.3], fill=(255, 216, 74))
        d.ellipse([cx + w * .62, cy + h * .08, cx + w * .62 + a * 1.3, cy + h * .08 + a * 1.3], fill=(255, 111, 174))
    elif kind == "eggs":
        pts = egg_outline(cx, cy, r)
        d.polygon(pts, fill=(255, 249, 240))
        d.line(pts + [pts[0]], fill=NAVY, width=max(2, int(r * .09)), joint="curve")
        # Crack across the broad lower-middle, where an egg hatches.
        y0 = cy + r * .22
        zig = [(cx - r * .74, y0), (cx - r * .42, y0 - r * .22), (cx - r * .14, y0 + r * .05), (cx + r * .14, y0 - r * .22),
               (cx + r * .42, y0 + r * .05), (cx + r * .74, y0 - r * .1)]
        d.line(zig, fill=hue, width=max(3, int(r * .16)), joint="curve")
        sparkle(d, cx + r * .62, cy - r * .78, r * .26, hue)
    elif kind == "park":
        # A playground slide: ladder on the left, a pink roof deck, the chute sweeping down to the right, a ball.
        wood, pink, aqua = (201, 117, 56), (255, 141, 182), (94, 203, 240)
        lw = max(3, int(r * .1))
        base = cy + r * .78
        lx0, lx1, top = cx - r * .78, cx - r * .38, cy - r * .28
        d.line([(lx0, base), (lx0 + r * .06, top)], fill=wood, width=lw)
        d.line([(lx1, base), (lx1 + r * .06, top)], fill=wood, width=lw)
        for k in range(1, 5):
            y = base - (base - top) * k / 5
            d.line([(lx0 + r * .06 * k / 5, y), (lx1 + r * .06 * k / 5, y)], fill=aqua, width=max(2, int(r * .08)))
        d.polygon([(lx0 - r * .14, top), (lx1 + r * .2, top), ((lx0 + lx1) / 2 + r * .03, top - r * .5)], fill=pink)
        d.line([(lx0 - r * .14, top), (lx1 + r * .2, top), ((lx0 + lx1) / 2 + r * .03, top - r * .5), (lx0 - r * .14, top)],
               fill=NAVY, width=max(2, int(r * .07)), joint="curve")
        chute = []
        for i in range(25):
            u = i / 24
            x = lx1 + r * .06 + u * r * 1.22
            y = top + r * .06 + (base - top - r * .12) * (1 - math.cos(u * math.pi)) / 2
            chute.append((x, y))
        d.line(chute, fill=NAVY, width=int(lw * 2.4), joint="curve")
        d.line(chute, fill=hue, width=int(lw * 1.5), joint="curve")
        br = r * .2
        bx, by = cx + r * .62, cy - r * .36
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(255, 218, 92), outline=NAVY, width=max(2, int(r * .06)))
        d.arc([bx - br * .7, by - br * .7, bx + br * .7, by + br * .7], 200, 290, fill=(255, 255, 255), width=max(2, int(r * .05)))
        sparkle(d, cx + r * .2, cy - r * .82, r * .2, (242, 182, 46))
    else:
        s = r * .96
        pts = []
        for i in range(60):
            t = i / 60 * math.tau
            x = 16 * math.sin(t) ** 3
            y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
            pts.append((cx + x / 17 * s, cy - y / 17 * s + r * .06))
        d.polygon(pts, fill=hue)
        d.line(pts + [pts[0]], fill=NAVY, width=max(2, int(r * .09)))
        d.ellipse([cx - s * .55, cy - s * .5, cx - s * .25, cy - s * .2], fill=(255, 255, 255))


def bubble(kind, background):
    S = 4
    big = SIZE * S
    img = Image.new("RGB", (big, big), background)
    d = ImageDraw.Draw(img)
    c = big / 2
    R = big * .46
    hue = HUES[kind]
    d.ellipse([c - R, c - R, c + R, c + R], fill=NAVY)
    d.ellipse([c - R * .9, c - R * .9, c + R * .9, c + R * .9], fill=hue)
    d.ellipse([c - R * .74, c - R * .74, c + R * .74, c + R * .74], fill=(255, 255, 255) if kind != "eggs" else (255, 240, 190))
    glyph(d, kind, c, c, R * (.56 if kind != "eggs" else .58), hue if kind != "eggs" else (236, 150, 30))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    kinds = [k for k in sys.argv[1:] if k in HUES] or list(HUES)
    for kind in kinds:
        b = np.asarray(bubble(kind, (0, 0, 0)), dtype=float)
        w = np.asarray(bubble(kind, (255, 255, 255)), dtype=float)
        alpha = np.clip(1 - (w - b).mean(axis=2) / 255, 0, 1)
        rgb = np.where(alpha[..., None] > .004, b / np.maximum(alpha[..., None], .004), 0)
        out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype("uint8")
        path = OUT / f"attract_icon_{kind}.png"
        Image.fromarray(out, "RGBA").save(path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
