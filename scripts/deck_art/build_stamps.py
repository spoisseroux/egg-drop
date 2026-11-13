"""Stamp card art (QA 2026-11-13 Q5): seven original rubber-stamp impressions for
StampCardView. Slot order: paw, star, egg, ball, flower, heart, crown (the 7th, the
bigger gift, in Stars gold with a double ring and sparkles).

Each stamp is a scalloped ink seal with a cream ring and a cream knock-out icon, with
a light ink speckle so it reads as printed. The "upcoming" variant is a white outline
of the same seal and icon (the client tints it and fades it right down).

Outputs (128 px cells, drawn at 4x and downsampled):
  assets/ui/stamps/stamp-<name>.png          full colour
  assets/ui/stamps/stamp-<name>-outline.png  white outline
  assets/ui/stamps/stamps-atlas.png          896 x 256: row 0 full colour, row 1 outline
                                             (the one upload: StampCardView.Art.atlas)
  artifacts/qa-2026-11-13/q5/stamps-preview.png  review sheet on the panel colour

Usage: python scripts/deck_art/build_stamps.py
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "stamps")
PREVIEW = os.path.join(ROOT, "artifacts", "qa-2026-11-13", "q5", "stamps-preview.png")

CELL = 128
SS = 4
N = CELL * SS  # 512 working canvas
C = N / 2
R = N * 0.43  # seal radius
RHO = R * 0.5  # icon radius

CREAM = (255, 244, 220)
STAMPS = [
    ("paw", (255, 158, 196)),
    ("star", (140, 200, 255)),
    ("egg", (255, 169, 143)),
    ("ball", (127, 224, 200)),
    ("flower", (201, 167, 255)),
    ("heart", (255, 122, 147)),
    ("crown", (255, 193, 77)),
]


def shade(color, k):
    return tuple(max(0, min(255, int(c * k))) for c in color)


def mask():
    return Image.new("L", (N, N), 0)


def scallop(radius, bumps=18, depth=0.045):
    pts = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        r = radius * (1 + depth * math.cos(bumps * t))
        pts.append((C + r * math.cos(t), C + r * math.sin(t)))
    return pts


def circle(d, cx, cy, r, fill):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def ell(d, cx, cy, rx, ry, fill):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)


def at(x, y):
    """Icon space (units of RHO, y down) to canvas px."""
    return C + x * RHO, C + y * RHO


# ── Icons: each draws into an "L" mask (255 = icon) and may add ink-coloured
# details to a second mask (`detail`, cut back out of the cream icon).
def icon_paw(m, detail):
    d = ImageDraw.Draw(m)
    x, y = at(0, 0.32)
    ell(d, x, y, 0.62 * RHO, 0.5 * RHO, 255)
    for tx, ty in ((-0.66, -0.22), (-0.24, -0.62), (0.24, -0.62), (0.66, -0.22)):
        x, y = at(tx, ty)
        ell(d, x, y, 0.24 * RHO, 0.3 * RHO, 255)


def icon_star(m, detail):
    d = ImageDraw.Draw(m)
    pts = []
    for i in range(10):
        t = -math.pi / 2 + i * math.pi / 5
        r = 1.08 if i % 2 == 0 else 0.5
        pts.append(at(r * math.cos(t), r * math.sin(t) + 0.08))
    d.polygon(pts, fill=255)
    # Round the points a little.
    m2 = m.filter(ImageFilter.GaussianBlur(6)).point(lambda v: 255 if v > 120 else 0)
    m.paste(m2)
    dd = ImageDraw.Draw(detail)
    for ex in (-0.2, 0.2):
        x, y = at(ex, 0.12)
        ell(dd, x, y, 0.08 * RHO, 0.11 * RHO, 255)


def icon_egg(m, detail):
    d = ImageDraw.Draw(m)
    pts = []
    for i in range(240):
        t = 2 * math.pi * i / 240
        x = 0.74 * math.cos(t)
        y = 0.98 * math.sin(t)
        if y < 0:
            x *= 1 - 0.2 * (-math.sin(t))
        pts.append(at(x, y + 0.06))
    d.polygon(pts, fill=255)
    dd = ImageDraw.Draw(detail)
    zig = [at(-0.8, 0.12), at(-0.45, -0.08), at(-0.15, 0.16), at(0.15, -0.08), at(0.45, 0.16), at(0.8, -0.04)]
    dd.line(zig, fill=255, width=int(0.13 * RHO), joint="curve")


def icon_ball(m, detail):
    d = ImageDraw.Draw(m)
    x, y = at(0, 0)
    circle(d, x, y, 0.9 * RHO, 255)
    dd = ImageDraw.Draw(detail)
    # A curved band across the ball and a shine.
    box = (C - 1.6 * RHO, C - 0.15 * RHO, C + 1.6 * RHO, C + 2.2 * RHO)
    dd.arc(box, 200, 340, fill=255, width=int(0.22 * RHO))
    x, y = at(-0.38, -0.42)
    ell(dd, x, y, 0.16 * RHO, 0.11 * RHO, 255)


def icon_flower(m, detail):
    d = ImageDraw.Draw(m)
    for i in range(5):
        t = -math.pi / 2 + i * 2 * math.pi / 5
        x, y = at(0.56 * math.cos(t), 0.56 * math.sin(t))
        circle(d, x, y, 0.4 * RHO, 255)
    dd = ImageDraw.Draw(detail)
    x, y = at(0, 0)
    circle(dd, x, y, 0.3 * RHO, 255)
    # Cream pip back in the middle of the ink centre.
    d2 = ImageDraw.Draw(m)
    circle(d2, x, y, 0.12 * RHO, 255)
    dd2 = Image.new("L", (N, N), 0)
    circle(ImageDraw.Draw(dd2), x, y, 0.12 * RHO, 255)
    detail.paste(ImageChops.subtract(detail, dd2))


def icon_heart(m, detail):
    d = ImageDraw.Draw(m)
    pts = []
    for i in range(360):
        t = 2 * math.pi * i / 360
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append(at(x / 16 * 0.98, -y / 16 * 0.98 + 0.06))
    d.polygon(pts, fill=255)
    dd = ImageDraw.Draw(detail)
    x, y = at(-0.42, -0.32)
    ell(dd, x, y, 0.15 * RHO, 0.1 * RHO, 255)


def icon_crown(m, detail):
    d = ImageDraw.Draw(m)
    base_top, base_bot = 0.3, 0.72
    pts = [at(-0.95, base_bot), at(-0.95, -0.28), at(-0.5, 0.12), at(0, -0.62), at(0.5, 0.12), at(0.95, -0.28), at(0.95, base_bot)]
    d.polygon(pts, fill=255)
    for tx, ty in ((-0.95, -0.36), (0, -0.72), (0.95, -0.36)):
        x, y = at(tx, ty)
        circle(d, x, y, 0.17 * RHO, 255)
    dd = ImageDraw.Draw(detail)
    x0, y0 = at(-0.95, base_top)
    x1, y1 = at(0.95, base_top + 0.1)
    dd.rectangle((x0, y0, x1, y1), fill=255)
    for gx in (-0.5, 0, 0.5):
        x, y = at(gx, 0.52)
        circle(dd, x, y, 0.1 * RHO, 255)


ICONS = {"paw": icon_paw, "star": icon_star, "egg": icon_egg, "ball": icon_ball,
         "flower": icon_flower, "heart": icon_heart, "crown": icon_crown}


def seal_masks(name):
    rim = mask()
    ImageDraw.Draw(rim).polygon(scallop(R), fill=255)
    ring = mask()
    d = ImageDraw.Draw(ring)
    circle(d, C, C, R * 0.82, 255)
    circle(d, C, C, R * 0.75, 0)
    if name == "crown":
        circle(d, C, C, R * 0.71, 255)
        circle(d, C, C, R * 0.67, 0)
    icon, detail = mask(), mask()
    ICONS[name](icon, detail)
    detail = ImageChops.multiply(detail, icon)
    return rim, ring, icon, detail


def sparkles(name, rng):
    if name != "crown":
        return mask()
    m = mask()
    d = ImageDraw.Draw(m)
    for tx, ty, s in ((-1.25, -1.05, 0.2), (1.2, -1.1, 0.16), (1.3, 0.95, 0.13)):
        x, y = at(tx, ty)
        r = s * RHO
        d.polygon([(x, y - r * 1.6), (x + r * 0.35, y - r * 0.35), (x + r * 1.6, y), (x + r * 0.35, y + r * 0.35),
                   (x, y + r * 1.6), (x - r * 0.35, y + r * 0.35), (x - r * 1.6, y), (x - r * 0.35, y - r * 0.35)], fill=255)
    return m


def full_colour(name, color, rng):
    rim, ring, icon, detail = seal_masks(name)
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    edge = shade(color, 0.72)
    img.paste(Image.new("RGBA", (N, N), edge + (255,)), (0, 0), rim)
    inner = rim.filter(ImageFilter.MinFilter(13))
    img.paste(Image.new("RGBA", (N, N), color + (255,)), (0, 0), inner)
    img.paste(Image.new("RGBA", (N, N), CREAM + (255,)), (0, 0), ring)
    knock = ImageChops.subtract(icon, detail)
    img.paste(Image.new("RGBA", (N, N), CREAM + (255,)), (0, 0), knock)
    # Ink speckle: a few cream flecks on the ink and ink flecks on the cream (printed feel).
    speck = mask()
    sd = ImageDraw.Draw(speck)
    for _ in range(140):
        x, y = rng.uniform(C - R, C + R), rng.uniform(C - R, C + R)
        r = rng.uniform(2, 6)
        sd.ellipse((x - r, y - r, x + r, y + r), fill=rng.randint(60, 140))
    speck = ImageChops.multiply(speck, inner)
    cream_flecks = ImageChops.multiply(speck, ImageChops.invert(ImageChops.lighter(ring, knock)))
    ink_flecks = ImageChops.multiply(speck, ImageChops.lighter(ring, knock))
    img.paste(Image.new("RGBA", (N, N), CREAM + (255,)), (0, 0), cream_flecks)
    img.paste(Image.new("RGBA", (N, N), color + (255,)), (0, 0), ink_flecks)
    spark = sparkles(name, rng)
    if spark.getbbox():
        img.paste(Image.new("RGBA", (N, N), CREAM + (255,)), (0, 0), spark.filter(ImageFilter.MaxFilter(9)))
        img.paste(Image.new("RGBA", (N, N), color + (255,)), (0, 0), spark)
    return img.resize((CELL, CELL), Image.LANCZOS)


def outline(name):
    rim, ring, icon, detail = seal_masks(name)
    w = 11
    def edge(m):
        return ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(w)))
    lines = ImageChops.lighter(edge(rim), edge(icon))
    spark = sparkles(name, None)
    if spark.getbbox():
        lines = ImageChops.lighter(lines, edge(spark))
    img = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    img.putalpha(lines)
    return img.resize((CELL, CELL), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    rng = random.Random(1113)
    atlas = Image.new("RGBA", (CELL * len(STAMPS), CELL * 2), (0, 0, 0, 0))
    fulls, lines = [], []
    for i, (name, color) in enumerate(STAMPS):
        f = full_colour(name, color, rng)
        o = outline(name)
        f.save(os.path.join(OUT, "stamp-%s.png" % name))
        o.save(os.path.join(OUT, "stamp-%s-outline.png" % name))
        atlas.paste(f, (i * CELL, 0))
        atlas.paste(o, (i * CELL, CELL))
        fulls.append(f)
        lines.append(o)
    atlas.save(os.path.join(OUT, "stamps-atlas.png"))
    # Review sheet: the panel colour, full stamps on top, faint tinted outlines under.
    pad = 24
    sheet = Image.new("RGBA", (pad + (CELL + pad) * len(STAMPS), pad * 3 + CELL * 2), (21, 37, 37, 255))
    for i, (name, color) in enumerate(STAMPS):
        x = pad + i * (CELL + pad)
        sheet.alpha_composite(fulls[i].rotate(8, resample=Image.BICUBIC), (x, pad))
        faint = Image.new("RGBA", (CELL, CELL), (195, 200, 208, 0))
        faint.putalpha(lines[i].getchannel("A").point(lambda v: int(v * 0.35)))
        sheet.alpha_composite(faint, (x, pad * 2 + CELL))
    sheet.save(PREVIEW)
    print("wrote", OUT, "and", PREVIEW)


if __name__ == "__main__":
    main()
