"""Hatch v2 (Pop-Out Stage) UI art: two 1024 atlases, white on transparent so the game tints them.

V2-HATCH-REDESIGN-2026-11-19 R1.2 / R1.3: the rays, shafts and edge patterns are one image
each (never 12 separate wedges); the bloom is a soft radial; sparkles are four-point (never a
five-point star, which means Stars); pebbles are blank rune stones. Deterministic (no random).

    python scripts/build_hatch_v2_art.py
Writes assets/ui/hatch-v2/hatch-v2-burst.png and hatch-v2-bits.png and prints the rects
that src/client/HatchStageArt.lua uses.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "hatch-v2")
SS = 2  # supersample


def smooth(a, b, x):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def radial_mask(size, inner, outer, square=True):
    """Alpha 0 inside `inner`, 1 past `outer` (shares of the half-size)."""
    m = Image.new("L", (size, size), 0)
    px = m.load()
    h = size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = (x + .5 - h) / h, (y + .5 - h) / h
            d = max(abs(dx), abs(dy)) * .55 + math.hypot(dx, dy) * .45 if square else math.hypot(dx, dy)
            px[x, y] = int(255 * smooth(inner, outer, d))
    return m


def sunburst(size=512, rays=12):
    big = size * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    c = big / 2
    r = big * .75
    for i in range(rays):
        a0 = (i / rays) * 2 * math.pi
        a1 = a0 + (math.pi / rays)  # rays fill half the turn
        d.polygon([(c, c), (c + r * math.cos(a0), c + r * math.sin(a0)), (c + r * math.cos(a1), c + r * math.sin(a1))], fill=255)
    img = img.resize((size, size), Image.LANCZOS)
    # Readability rule 1: rays fade in from 16% to 42% of the well's radius (the image is
    # drawn at 1.42x the well, so in image units 0.11 to 0.30).
    mask = radial_mask(size, .11, .30, square=False)
    out = Image.new("LA", (size, size))
    out.putdata([(255, a * m // 255) for a, m in zip(img.getdata(), mask.getdata())])
    return out


def shafts(size=512, count=12):
    big = size * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    c = big / 2
    for i in range(count):
        a = (i / count) * 2 * math.pi + .13
        w = math.radians(2.6 + 1.6 * ((i * 7) % 3))
        r = big * .72
        d.polygon([(c, c), (c + r * math.cos(a - w), c + r * math.sin(a - w)), (c + r * math.cos(a + w), c + r * math.sin(a + w))], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(SS * 3)).resize((size, size), Image.LANCZOS)
    fade_in = radial_mask(size, .18, .40, square=False)
    fade_out = radial_mask(size, .70, 1.0, square=False)
    out = Image.new("LA", (size, size))
    out.putdata([(255, a * fi * (255 - fo) // (255 * 255)) for a, fi, fo in zip(img.getdata(), fade_in.getdata(), fade_out.getdata())])
    return out


def pattern(size, kind):
    big = size * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    step = big // 14
    if kind == "dots":
        r = step * .16
        for j in range(16):
            for i in range(16):
                x = i * step + (step / 2 if j % 2 else 0)
                y = j * step
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    elif kind == "stripes":
        w = step * .22
        for k in range(-30, 30):
            x0 = k * step
            d.polygon([(x0, 0), (x0 + w, 0), (x0 + w + big, big), (x0 + big, big)], fill=255)
    else:  # diamonds
        r = step * .2
        for j in range(16):
            for i in range(16):
                x = i * step + (step / 2 if j % 2 else 0)
                y = j * step
                d.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], fill=255)
    img = img.resize((size, size), Image.LANCZOS)
    # The pattern starts at 50% of the radius (rule 1): the middle stays the core colour.
    mask = radial_mask(size, .50, .66)
    out = Image.new("LA", (size, size))
    out.putdata([(255, a * m // 255) for a, m in zip(img.getdata(), mask.getdata())])
    return out


def glow(size=256):
    out = Image.new("LA", (size, size))
    px = []
    h = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + .5 - h, y + .5 - h) / h
            a = max(0.0, 1 - d) ** 2.2
            px.append((255, int(255 * a)))
    out.putdata(px)
    return out


def sparkle(size=128):
    big = size * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    c = big / 2
    long, thin = big * .48, big * .09
    pts = []
    for k in range(8):
        a = k * math.pi / 4 - math.pi / 2
        r = long if k % 2 == 0 else thin
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=255)
    return Image.merge("LA", (Image.new("L", (size, size), 255), img.resize((size, size), Image.LANCZOS)))


def pebble(size=64):
    """A blank rune stone: white face with an ink rim and a top glint (tinted in game)."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = big * .08
    d.rounded_rectangle([pad, pad, big - pad, big - pad], radius=big * .3, fill=(21, 20, 58, 255))
    t = big * .07
    d.rounded_rectangle([pad + t, pad + t, big - pad - t, big - pad - t * 1.8], radius=big * .24, fill=(255, 255, 255, 255))
    d.rounded_rectangle([big * .3, big * .24, big * .55, big * .34], radius=big * .05, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def egg(w=256, h=320, belt=False):
    big = (w * SS, h * SS)
    img = Image.new("RGBA", big, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, H = big
    # Egg outline: wider at the bottom.
    pts = []
    for k in range(200):
        a = k / 200 * 2 * math.pi
        x = math.sin(a)
        y = -math.cos(a)
        sx = .44 * (1 + .1 * y)
        pts.append((W / 2 + x * W * sx, H * .52 + y * H * .46))
    ink = (21, 20, 58, 255)
    d.polygon(pts, fill=ink)
    inner = [(W / 2 + (px - W / 2) * .94, H * .52 + (py - H * .52) * .955) for px, py in pts]
    d.polygon(inner, fill=(255, 244, 220, 255))
    # Soft lower shade and a glint.
    d.ellipse([W * .26, H * .14, W * .40, H * .30], fill=(255, 255, 255, 255))
    if belt:
        colours = [(255, 106, 160), (255, 160, 64), (82, 196, 255), (120, 214, 90), (128, 128, 255), (214, 110, 255)]
        for i, col in enumerate(colours):
            cx = W * (.2 + i * .12)
            cy = H * .62 + math.sin(i / 5 * math.pi) * H * .03
            r = W * .055
            d.rounded_rectangle([cx - r, cy - r, cx + r, cy + r], radius=r * .5, fill=ink)
            r2 = r * .74
            d.rounded_rectangle([cx - r2, cy - r2, cx + r2, cy + r2], radius=r2 * .5, fill=col + (255,))
    return img.resize((w, h), Image.LANCZOS)


def to_rgba(la):
    if la.mode == "RGBA":
        return la
    l, a = la.split()
    return Image.merge("RGBA", (l, l, l, a))


def main():
    os.makedirs(OUT, exist_ok=True)
    rects = {}
    a = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    for name, img, at in (("sunburst", sunburst(), (0, 0)), ("shafts", shafts(), (512, 0)),
                          ("dots", pattern(512, "dots"), (0, 512)), ("stripes", pattern(512, "stripes"), (512, 512))):
        a.alpha_composite(to_rgba(img), at)
        rects[name] = ("burst",) + at + img.size
    a.save(os.path.join(OUT, "hatch-v2-burst.png"))
    b = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    for name, img, at in (("diamonds", pattern(512, "diamonds"), (0, 0)), ("glow", glow(), (512, 0)),
                          ("sparkle", sparkle(), (768, 0)), ("pebble", pebble(), (768, 128)),
                          ("statEgg", egg(belt=True), (512, 256)), ("egg", egg(), (768, 256))):
        b.alpha_composite(to_rgba(img), at)
        rects[name] = ("bits",) + at + img.size
    b.save(os.path.join(OUT, "hatch-v2-bits.png"))
    for name, r in rects.items():
        print(f"{name}={{atlas='{r[0]}',x={r[1]},y={r[2]},w={r[3]},h={r[4]}}}")


if __name__ == "__main__":
    main()
