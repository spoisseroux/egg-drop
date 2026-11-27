"""The garden understory's one atlas and its blob shadow (GARDEN-B38-BRIEF 4b, Fable 2026-11-27). Original art: every
pixel is drawn here from code (seeded ellipses, value noise, gradients). No AI, no samples, no photos.

    python scripts/draw_understory_atlas.py

Writes assets/world/understory/:
  understory-atlas.png  256 x 256 RGB, four 128 px regions (image y down; scripts/build_understory_meshes.py maps UVs):
      A (0, 0)     round bush: overlapping leaf clusters, darker green than the lawn, matte, dark gaps between clusters
      B (128, 0)   flowering bush: the same leaves (another seed) with small cream and coral five-petal flowers
      C (0, 128)   reeds: blades x 0..96 (base dark green, mid olive, dry straw tip; fine streaks), the cattail stem
                   x 96..104, the cattail head x 104..128 (warm brown, darker flecks)
      D (128, 128) reserved for the P2 plants (tufts, flower clumps, ferns): a plain grass gradient until they are drawn
  understory-blob.png   64 x 64 RGBA: the soft shade under a bush (dark green, alpha falls off to 0 at the rim)

Colours: matte and believable (Spencer: textured surroundings so the pets stand out). The Aero day light renders a
TextureID about 1.0 / 1.22 / 1.29 brighter in R / G / B on sunlit tops (memory: roblox-surfaceappearance-runtime), so
the greens are drawn a little warmer and lower in blue (COMP) to land on the brief's colours in game. Deterministic:
the same bytes every run.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "understory"
SIZE = 256
SS = 4                      # supersampling for the drawn shapes
COMP = (1.0, .9, .84)       # render compensation for the Aero sun (greens and browns only; flowers get FLOWER_COMP)
FLOWER_COMP = (1.0, .96, .9)
SEED = 20261127


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def comp(rgb, k=COMP):
    return tuple(int(round(min(255, c * f))) for c, f in zip(rgb, k))


def value_noise(w, h, cell, rng):
    gx, gy = w // cell + 2, h // cell + 2
    grid = rng.random((gy, gx))
    ys, xs = np.mgrid[0:h, 0:w] / cell
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = grid[y0, x0], grid[y0, x0 + 1]
    c, d = grid[y0 + 1, x0], grid[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# Leaves: the gap colour, then four leaf greens from shade to sun, then a sparse highlight (all darker than the lawn,
# GroundDressing's lawn tints #246F2F / #56A54B).
GAP = "#21422A"
LEAVES = ["#2A5230", "#346333", "#3E7338", "#4A813E"]
HIGHLIGHT = "#68984C"


def leaf_region(rng, flowers=False):
    """One 128 px leaf-cluster region (RGB), drawn at SS x and filtered down."""
    n = 128 * SS
    img = Image.new("RGB", (n, n), comp(hexrgb(GAP)))
    d = ImageDraw.Draw(img)
    # Clusters: each a loose rosette of leaves round a centre, lighter toward its top-left (the sun side), so the
    # region reads as clumps with dark pockets between them, not as an even leaf print.
    clusters = [(rng.random() * n, rng.random() * n) for _ in range(80)]
    for cx, cy in clusters:
        rad = (10 + rng.random() * 8) * SS
        for k in range(30):
            a = rng.random() * math.tau
            r = rad * math.sqrt(rng.random())
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            # sun from the top left: leaves there take the lighter greens
            lit = .5 - (math.cos(a) * r + math.sin(a) * r) / (2.8 * rad)
            idx = int(max(0, min(3, round(lit * 3 + (rng.random() - .5)))))
            colour = LEAVES[idx]
            if idx == 3 and rng.random() < .18:
                colour = HIGHLIGHT
            length, width = (6 + rng.random() * 4) * SS, (2.8 + rng.random() * 1.8) * SS
            turn = rng.random() * math.pi
            pts = []
            for s in range(14):
                t = s / 14 * math.tau
                # a leaf: pointed ends (|sin| ** .8 keeps the middle full)
                px = math.cos(t) * length / 2
                py = math.sin(t) * width / 2 * abs(math.cos(t * .5)) ** .3
                pts.append((x + px * math.cos(turn) - py * math.sin(turn), y + px * math.sin(turn) + py * math.cos(turn)))
            d.polygon(pts, fill=comp(hexrgb(colour)))
            # the midrib: a hairline a step darker
            dx, dy = math.cos(turn) * length * .4, math.sin(turn) * length * .4
            d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=comp(hexrgb(LEAVES[max(0, idx - 1)])), width=max(1, SS // 2))
    if flowers:
        cream, coral = hexrgb("#F2E6CC"), hexrgb("#E0785C")
        centre = hexrgb("#C9983C")
        for _ in range(40):
            x, y = rng.random() * n, rng.random() * n
            colour = cream if rng.random() < .6 else coral
            r = (2.2 + rng.random() * 1.2) * SS
            turn = rng.random() * math.tau
            # five round petals, a shade darker on the lower side
            for p in range(5):
                a = turn + p * math.tau / 5
                px, py = x + math.cos(a) * r * .55, y + math.sin(a) * r * .55
                shade = .86 if math.sin(a) > .3 else 1.0
                c = comp(tuple(int(v * shade) for v in colour), FLOWER_COMP)
                d.ellipse([px - r * .5, py - r * .5, px + r * .5, py + r * .5], fill=c)
            d.ellipse([x - r * .28, y - r * .28, x + r * .28, y + r * .28], fill=comp(centre, FLOWER_COMP))
    img = img.resize((128, 128), Image.LANCZOS)
    # matte texture: a soft value wobble (+-7%) so no two clusters read the same
    arr = np.asarray(img).astype(np.float64)
    wob = value_noise(128, 128, 16, rng) * .14 + .93
    arr *= wob[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def reed_region(rng):
    """Blades (x 0..96), stem (96..104), cattail head (104..128). v: image top = blade tip, bottom = base."""
    out = np.zeros((128, 128, 3))
    base, mid, tip = (np.array(comp(hexrgb(h)), dtype=np.float64) for h in ("#2F4F27", "#5F7A3C", "#A89F62"))
    ys = np.linspace(1, 0, 128)[:, None]          # 1 at the top (tip), 0 at the bottom (base)
    lower = np.clip(ys / .6, 0, 1)
    upper = np.clip((ys - .6) / .4, 0, 1)
    grad = base * (1 - lower)[..., None] + mid * lower[..., None]
    grad = grad * (1 - upper)[..., None] + tip * upper[..., None]
    out[:, :96] = grad
    # fine vertical streaks: every column its own value, stretched noise along the blade
    streak = rng.random(96) * .18 + .91
    long = value_noise(96, 128, 8, rng)[:, :] * .1 + .95
    out[:, :96] *= streak[None, :, None] * long[:, :, None]
    # a darker midrib line every 12 px (one per blade's UV strip)
    for x in range(6, 96, 12):
        out[:, x] *= .82
    # the stem: plain olive, darker at the base
    stem = np.array(comp(hexrgb("#55703A")), dtype=np.float64)
    out[:, 96:104] = stem * (.8 + .2 * ys)[..., None]
    # the cattail head: warm brown velvet with darker flecks and a lighter top edge
    brown, dark = np.array(comp(hexrgb("#6E4A2C")), dtype=np.float64), np.array(comp(hexrgb("#4A311E")), dtype=np.float64)
    fleck = (rng.random((128, 24)) < .22)[:, :, None]
    head = np.where(fleck, dark, brown) * (value_noise(24, 128, 4, rng) * .16 + .92)[:, :, None]
    out[:, 104:] = head
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def reserved_region():
    """P2 plants are not drawn yet: a plain lawn-dark gradient, so a stray UV here shows grass, never a hole."""
    ys = np.linspace(0, 1, 128)[:, None, None]
    top, bottom = np.array(comp(hexrgb("#4C7A3A"))), np.array(comp(hexrgb("#2E5528")))
    arr = top * (1 - ys) + bottom * ys
    return Image.fromarray(np.repeat(arr, 128, axis=1).astype(np.uint8))


def blob():
    n = 64
    ys, xs = np.mgrid[0:n, 0:n]
    r = np.hypot(xs - (n - 1) / 2, ys - (n - 1) / 2) / (n / 2)
    alpha = np.clip(1 - r * r, 0, 1) ** 1.6 * 230
    rgba = np.zeros((n, n, 4), dtype=np.uint8)
    rgba[..., :3] = hexrgb("#132A14")
    rgba[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGB", (SIZE, SIZE))
    atlas.paste(leaf_region(_Rng(SEED), False), (0, 0))
    atlas.paste(leaf_region(_Rng(SEED + 1), True), (128, 0))
    atlas.paste(reed_region(np.random.default_rng(SEED + 2)), (0, 128))
    atlas.paste(reserved_region(), (128, 128))
    atlas.save(OUT / "understory-atlas.png", optimize=False)
    blob().save(OUT / "understory-blob.png", optimize=False)
    print("understory atlas ->", (OUT / "understory-atlas.png").relative_to(ROOT), "and blob")


class _Rng:
    """random.Random with numpy's random((h, w)) for value_noise (one seeded stream per region)."""

    def __init__(self, seed):
        import random
        self.py = random.Random(seed)
        self.np = np.random.default_rng(seed)

    def random(self, shape=None):
        return self.py.random() if shape is None else self.np.random(shape)


if __name__ == "__main__":
    main()
