"""Draw the two garden-life particle textures (Fable, 2026-11-22).

Script-drawn, deterministic, no outside art:
  assets/life/petal.png   64x64   white/grey petal, tinted by ParticleEmitter.Color
  assets/life/bubble.png  128x128 soap bubble: thin ring, curved highlight, faint rainbow edge

Run:  python scripts/draw_life_textures.py [--preview DIR]
--preview also writes contact sheets on grass / sky / pet-white at in-game pixel sizes.
"""
from __future__ import annotations

import colorsys
import math
import sys
from pathlib import Path

from PIL import Image

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


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pet, bub = petal(), bubble()
    pet.save(OUT / "petal.png", optimize=True)
    bub.save(OUT / "bubble.png", optimize=True)
    print("wrote", OUT / "petal.png", pet.size, OUT / "bubble.png", bub.size)
    if "--preview" in sys.argv:
        preview(Path(sys.argv[sys.argv.index("--preview") + 1]), pet, bub)


if __name__ == "__main__":
    main()
