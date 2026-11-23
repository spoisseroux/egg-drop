"""Draw the two garden-life particle textures (Fable, 2026-11-22).

Script-drawn, deterministic, no outside art:
  assets/life/petal.png   64x64   white/grey petal, tinted by ParticleEmitter.Color
  assets/life/bubble.png  128x128 soap bubble: thin ring, curved highlight, faint rainbow edge
Round 2 (LOOK-R2.md), Decals on thin transparent parts:
  assets/life/bird-eye.png          64x64    cream rim, ink pupil, top glint (full colour; cylinder cap)
  assets/life/bird-wing.png         128x184  three-feather wing, tip down, left-right symmetric (tinted by Decal.Color3)
  assets/life/butterfly-wing.png    160x192  one side of a butterfly, root at the LEFT edge, fore wing up (tinted)
  assets/life/butterfly-wing-m.png  the same mirrored, root at the RIGHT edge

Run:  python scripts/draw_life_textures.py [--preview DIR]
--preview also writes contact sheets on grass / sky / pet-white at in-game pixel sizes.
"""
from __future__ import annotations

import colorsys
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "life"
SS = 4  # supersample factor


def smooth(edge0: float, edge1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def petal() -> Image.Image:
    n = 64 * SS
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    # Petal runs base (bottom) to tip (top). t = 0 at base, 1 at tip.
    y_base, y_tip = 0.93, 0.07
    half_max = 0.33
    for j in range(n):
        v = (j + 0.5) / n
        t = (y_base - v) / (y_base - y_tip)
        if t < 0.0 or t > 1.0:
            continue
        # Narrow foot, widest past the middle, round tip.
        half = half_max * (math.sin(math.pi * t ** 0.72) ** 0.62)
        for i in range(n):
            u = (i + 0.5) / n - 0.5
            d = half - abs(u)  # distance inside the outline, in texture units
            a = smooth(-0.004, 0.012, d)
            if a <= 0:
                continue
            # Bright centre, darker rim, so a tinted petal still has form.
            rim = 1.0 - smooth(0.0, 0.16, d)
            shade = 1.0 - 0.13 * rim
            # A touch darker at the foot.
            shade *= 0.90 + 0.10 * smooth(0.0, 0.55, t)
            # Centre vein: faint, from the foot to about 72% of the length.
            vein_w = 0.011 * (1.0 - 0.6 * t)
            vein = (1.0 - smooth(vein_w * 0.4, vein_w * 1.6, abs(u))) * (1.0 - smooth(0.50, 0.74, t))
            shade *= 1.0 - 0.17 * vein
            g = int(round(255 * max(0.0, min(1.0, shade))))
            px[i, j] = (g, g, g, int(round(255 * a)))
    return img.resize((64, 64), Image.LANCZOS)


def bubble() -> Image.Image:
    n = 128 * SS
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    c = n / 2.0
    R = 0.445 * n      # outer radius
    ring = 0.022 * n   # ring thickness
    for j in range(n):
        for i in range(n):
            x, y = i + 0.5 - c, j + 0.5 - c
            r = math.hypot(x, y)
            if r > R + 2 * SS:
                continue
            ang = math.atan2(y, x)  # 0 = right, +90 degrees = down
            rn = r / R
            outer = 1.0 - smooth(R - 0.5 * SS, R + 0.5 * SS, r)
            # Rainbow: hue runs twice round the rim; strongest on the rim, gone by 68% radius.
            hue = (ang / (2 * math.pi) * 2.0 + 0.55) % 1.0
            sat = 0.42 * smooth(0.68, 0.98, rn)
            cr, cg, cb = colorsys.hsv_to_rgb(hue, sat, 1.0)
            # Thin ring, brighter on the lit side (upper left).
            a_ring = 0.80 * smooth(R - ring - SS, R - ring, r) * outer
            lit = 0.5 + 0.5 * math.cos(ang - math.radians(225))
            a_ring *= 0.62 + 0.38 * lit
            # Film: almost clear in the middle (the pet must show through), denser to the rim.
            a_film = (0.035 + 0.30 * smooth(0.55, 1.0, rn) ** 2) * outer
            a = max(a_ring, a_film)
            # Curved highlight: crescent arc, upper left, round tapered ends.
            hr = 0.70 * R
            a0, a1 = math.radians(198), math.radians(256)
            ac = min(max(ang % (2 * math.pi), a0), a1)
            dist = math.hypot(x - hr * math.cos(ac), y - hr * math.sin(ac))
            taper = 0.55 + 0.45 * math.sin(math.pi * (ac - a0) / (a1 - a0))
            hw = 0.058 * n * taper
            a_hi = 0.92 * (1.0 - smooth(hw - 1.5 * SS, hw + 0.5 * SS, dist))
            # Small bounce light, lower right.
            bx = 0.52 * R * math.cos(math.radians(42))
            by = 0.52 * R * math.sin(math.radians(42))
            bw = 0.036 * n
            a_bo = 0.50 * (1.0 - smooth(bw - 1.5 * SS, bw + 0.5 * SS, math.hypot(x - bx, y - by)))
            white = max(a_hi, a_bo)
            if white > 0:
                total = white + a * (1 - white)
                k = white / max(total, 1e-6)
                cr, cg, cb = cr + (1 - cr) * k, cg + (1 - cg) * k, cb + (1 - cb) * k
                a = total
            px[i, j] = (
                int(round(cr * 255)),
                int(round(cg * 255)),
                int(round(cb * 255)),
                int(round(255 * min(1.0, a))),
            )
    return img.resize((128, 128), Image.LANCZOS)


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[k:k + 2], 16) for k in (0, 2, 4))


def tint(img: Image.Image, colour: str) -> Image.Image:
    r, g, b = hexrgb(colour)
    R, G, B, A = img.split()
    return Image.merge(
        "RGBA",
        (R.point(lambda v: v * r // 255), G.point(lambda v: v * g // 255), B.point(lambda v: v * b // 255), A),
    )


GROUNDS = ["#5FCB3F", "#2FA84F", "#2F9BEF", "#BFE9FF", "#F4F7FA", "#1F6B2E"]
TINTS = ["#FFFFFF", "#EFFFC4", "#C8F26A", "#FFF3A6", "#FFB8D6", "#FF9FC8", "#FFD9E8"]


def preview(directory: Path, pet: Image.Image, bub: Image.Image) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    cell = 76
    sheet = Image.new("RGBA", (cell * len(TINTS) * 2, cell * len(GROUNDS)), (0, 0, 0, 255))
    for gy, ground in enumerate(GROUNDS):
        for tx, colour in enumerate(TINTS):
            for k, size in enumerate((64, 20)):
                tile = Image.new("RGBA", (cell, cell), hexrgb(ground) + (255,))
                p = tint(pet, colour).resize((size, size), Image.LANCZOS).rotate(25 * tx, resample=Image.BICUBIC)
                tile.alpha_composite(p, ((cell - size) // 2, (cell - size) // 2))
                sheet.paste(tile, ((tx * 2 + k) * cell, gy * cell))
    sheet.save(directory / "petal-sheet.png")
    sizes = [128, 64, 40, 24]
    w = sum(s + 16 for s in sizes)
    sheet = Image.new("RGBA", (w, 144 * len(GROUNDS)), (0, 0, 0, 255))
    for gy, ground in enumerate(GROUNDS):
        row = Image.new("RGBA", (w, 144), hexrgb(ground) + (255,))
        x = 8
        for s in sizes:
            row.alpha_composite(bub.resize((s, s), Image.LANCZOS), (x, (144 - s) // 2))
            x += s + 16
        sheet.paste(row, (0, gy * 144))
    sheet.save(directory / "bubble-sheet.png")


# Round 2 decals -------------------------------------------------------------------------------------------------
DS = 6  # supersample for the ImageDraw shapes


def _ellipse(cx: float, cy: float, a: float, b: float, deg: float, k: float = 1.0, n: int = 96):
    """Polygon of an ellipse turned by deg (screen degrees, clockwise), scaled by k about its centre."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = a * k * math.cos(t), b * k * math.sin(t)
        pts.append(((cx + x * c - y * s) * DS, (cy + x * s + y * c) * DS))
    return pts


def _finish(mask: Image.Image, grey: Image.Image, size: tuple[int, int]) -> Image.Image:
    return Image.merge("RGBA", (grey, grey, grey, mask)).resize(size, Image.LANCZOS)


def bird_eye() -> Image.Image:
    n = 64 * DS
    img = Image.new("RGBA", (n, n), (255, 248, 232, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, n - 1, n - 1), fill=(255, 248, 232, 255))  # cream rim, fills the cap
    r = 0.405 * n
    d.ellipse((n / 2 - r, n / 2 - r, n / 2 + r, n / 2 + r), fill=(22, 28, 56, 255))  # ink pupil
    g = 0.125 * n
    d.ellipse((n / 2 - g, 0.275 * n - g, n / 2 + g, 0.275 * n + g), fill=(255, 255, 255, 255))  # top glint
    return img.resize((64, 64), Image.LANCZOS)


def bird_wing() -> Image.Image:
    """Tip down, symmetric left-right so it reads the same on the Left and the Right face."""
    w, h = 128, 184
    mask = Image.new("L", (w * DS, h * DS), 0)
    grey = Image.new("L", (w * DS, h * DS), 255)
    dm, dg = ImageDraw.Draw(mask), ImageDraw.Draw(grey)
    rim = 118
    # (cx, cy, a, b, deg): two side feathers, the long middle one, then the round shoulder on top.
    shapes = [(40, 104, 62, 27, 76), (88, 104, 62, 27, 104), (64, 112, 68, 28, 90), (64, 56, 58, 52, 0)]
    for cx, cy, a, b, deg in shapes:
        dm.polygon(_ellipse(cx, cy, a, b, deg), fill=255)
    for i, (cx, cy, a, b, deg) in enumerate(shapes):
        dg.polygon(_ellipse(cx, cy, a, b, deg), fill=rim)
        fill = 255 if i == 3 else (226 if i == 2 else 200)
        dg.polygon(_ellipse(cx, cy, a - 7, b - 7, deg), fill=fill)
    return _finish(mask, grey, (w, h))


def butterfly_wing() -> Image.Image:
    """One side: root at the left edge, fore wing up. White field (takes the tint), near-black border and veins."""
    w, h = 160, 192
    mask = Image.new("L", (w * DS, h * DS), 0)
    grey = Image.new("L", (w * DS, h * DS), 255)
    dm, dg = ImageDraw.Draw(mask), ImageDraw.Draw(grey)
    dark = 26
    root = (4, 104)
    lobes = [(70, 142, 64, 44, 28), (80, 60, 82, 52, -24)]  # hind, then fore on top
    for cx, cy, a, b, deg in lobes:
        dm.polygon(_ellipse(cx, cy, a, b, deg), fill=255)
    dm.polygon([(0, 84 * DS), (40 * DS, 70 * DS), (40 * DS, 140 * DS), (0, 122 * DS)], fill=255)  # the join at the body
    for cx, cy, a, b, deg in lobes:
        dg.polygon(_ellipse(cx, cy, a, b, deg), fill=dark)
        # The field: the lobe shrunk and pulled toward the root, so the border is widest at the outer edge.
        k = 0.80
        fx, fy = cx + (root[0] - cx) * 0.10, cy + (root[1] - cy) * 0.10
        dg.polygon(_ellipse(fx, fy, a, b, deg, k), fill=255)
        c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        for off in (-0.30, 0.30):  # two veins from the root through the field
            ex, ey = fx + a * k * 0.80 * c - b * k * off * 2 * s, fy + a * k * 0.80 * s + b * k * off * 2 * c
            dg.line([(root[0] * DS, root[1] * DS), (ex * DS, ey * DS)], fill=dark, width=int(3 * DS))
        for t in (-52, -18, 18, 52):  # dots in the border along the outer edge (they take the tint)
            tt = math.radians(t)
            x, y = a * 0.905 * math.cos(tt), b * 0.905 * math.sin(tt)
            qx, qy = cx + x * c - y * s, cy + x * s + y * c
            dg.ellipse(((qx - 4) * DS, (qy - 4) * DS, (qx + 4) * DS, (qy + 4) * DS), fill=255)
    dg.polygon([(0, 88 * DS), (30 * DS, 84 * DS), (30 * DS, 126 * DS), (0, 118 * DS)], fill=dark)
    return _finish(mask, grey, (w, h))


BIRDS = {"tide": ("#2A6BE0", "#173F9E", "#FF9F1C"), "coral": ("#FF7C6B", "#C93F3A", "#FFD23F"), "sun": ("#FFD23F", "#E08A10", "#FF7A1A")}
FLIES = ["#FF327A", "#FFCC00", "#7A35F0", "#0A4FD0"]


def _bird_mock(px: int, colours, eye: Image.Image, wing: Image.Image) -> Image.Image:
    """Side view, facing right; px is the body ball (1.2 studs) in pixels."""
    s = 4
    U = px / 1.2 * s  # supersampled pixels per stud
    big = Image.new("RGBA", (int(2.2 * U), int(1.8 * U)), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    ox, oy = big.width / 2, big.height / 2
    body, _, beak = (hexrgb(c) + (255,) for c in colours)
    d.polygon([(ox + 0.50 * U, oy - 0.10 * U), (ox + 0.92 * U, oy + 0.10 * U), (ox + 0.50 * U, oy + 0.16 * U)], fill=beak)
    d.ellipse((ox - 0.6 * U, oy - 0.6 * U, ox + 0.6 * U, oy + 0.6 * U), fill=body)
    hi = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ImageDraw.Draw(hi).ellipse((ox - 0.42 * U, oy - 0.52 * U, ox + 0.22 * U, oy - 0.02 * U), fill=(255, 255, 255, 46))
    big.alpha_composite(hi.filter(ImageFilter.GaussianBlur(0.08 * U)))
    wg = tint(wing, colours[1]).resize((max(2, int(0.46 * U)), max(2, int(0.66 * U))), Image.LANCZOS)
    wg = wg.rotate(-55, resample=Image.BICUBIC, expand=True)
    big.alpha_composite(wg, (int(ox - 0.14 * U - wg.width / 2), int(oy + 0.06 * U - wg.height / 2)))
    e = eye.resize((max(2, int(0.46 * U)),) * 2, Image.LANCZOS)
    big.alpha_composite(e, (int(ox + 0.20 * U - e.width / 2), int(oy - 0.14 * U - e.height / 2)))
    return big.resize((big.width // s, big.height // s), Image.LANCZOS)


def _fly_mock(px: int, colour: str, wing: Image.Image) -> Image.Image:
    """Top view, wings flat; px is the 1.5 stud span in pixels."""
    s = 4
    U = px / 1.5 * s
    big = Image.new("RGBA", (int(1.7 * U), int(1.1 * U)), (0, 0, 0, 0))
    ox, oy = big.width / 2, big.height / 2
    r = tint(wing, colour).resize((max(2, int(0.70 * U)), max(2, int(0.84 * U))), Image.LANCZOS)
    big.alpha_composite(r, (int(ox + 0.05 * U), int(oy - r.height / 2)))
    left = r.transpose(Image.FLIP_LEFT_RIGHT)
    big.alpha_composite(left, (int(ox - 0.05 * U - left.width), int(oy - left.height / 2)))
    ImageDraw.Draw(big).rounded_rectangle(
        (ox - 0.05 * U, oy - 0.25 * U, ox + 0.05 * U, oy + 0.25 * U), radius=0.05 * U, fill=(36, 48, 79, 255)
    )
    return big.resize((big.width // s, big.height // s), Image.LANCZOS)


def _sheet(directory: Path, name: str, grounds, columns, sizes, ratio: float, row: int, mock) -> None:
    cellw = sum(int(s * ratio) + 14 for s in sizes)
    sheet = Image.new("RGBA", (cellw * len(columns), row * len(grounds)), (0, 0, 0, 255))
    for gy, ground in enumerate(grounds):
        for cx, column in enumerate(columns):
            tile = Image.new("RGBA", (cellw, row), hexrgb(ground) + (255,))
            x = 5
            for s in sizes:
                m = mock(s, column)
                tile.alpha_composite(m, (x, (row - m.height) // 2))
                x += m.width + 10
            sheet.paste(tile, (cx * cellw, gy * row))
    sheet.save(directory / name)


def preview_r2(directory: Path, eye: Image.Image, wing: Image.Image, fly: Image.Image) -> None:
    """Mock side-view birds and top-view butterflies at about close, 12, 22 and 36 studs on a phone."""
    directory.mkdir(parents=True, exist_ok=True)
    _sheet(directory, "bird-sheet.png", ["#2F9BEF", "#BFE9FF", "#8FD63F", "#1F6B2E", "#F4F7FA"], list(BIRDS.values()),
           [150, 48, 26, 16], 2.2 / 1.2, 240, lambda s, c: _bird_mock(s, c, eye, wing))
    _sheet(directory, "butterfly-sheet.png", ["#5FCB3F", "#2FA84F", "#2F9BEF", "#1F6B2E"], FLIES,
           [180, 60, 30, 18], 1.7 / 1.5, 150, lambda s, c: _fly_mock(s, c, fly))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pet, bub = petal(), bubble()
    pet.save(OUT / "petal.png", optimize=True)
    bub.save(OUT / "bubble.png", optimize=True)
    print("wrote", OUT / "petal.png", pet.size, OUT / "bubble.png", bub.size)
    eye, wing, fly = bird_eye(), bird_wing(), butterfly_wing()
    eye.save(OUT / "bird-eye.png", optimize=True)
    wing.save(OUT / "bird-wing.png", optimize=True)
    fly.save(OUT / "butterfly-wing.png", optimize=True)
    fly.transpose(Image.FLIP_LEFT_RIGHT).save(OUT / "butterfly-wing-m.png", optimize=True)
    print("wrote bird-eye", eye.size, "bird-wing", wing.size, "butterfly-wing (+ -m)", fly.size)
    if "--preview" in sys.argv:
        directory = Path(sys.argv[sys.argv.index("--preview") + 1])
        preview(directory, pet, bub)
        preview_r2(directory, eye, wing, fly)


if __name__ == "__main__":
    main()
