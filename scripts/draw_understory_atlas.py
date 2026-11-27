"""The garden understory's one atlas and its blob shadow (GARDEN-B38-BRIEF 4b, Fable 2026-11-27; FIX FIRST review round
1). Original art: every pixel is drawn here from code (seeded leaf shapes, value noise, gradients). No AI, no samples.

    python scripts/draw_understory_atlas.py

Writes assets/world/understory/:
  understory-atlas.png  512 x 512 RGB, four 256 px regions (image y down; scripts/build_understory_meshes.py maps UVs):
      A (0, 0)     round bush: about 25 leaf clusters (leaves 16 to 22 px), one step darker than the lawn, matte
                   (Fable round 2: the region's mean is about #3F6E3A, highlights #6E9A55, never near-black), darker
                   pockets between clusters. The bush's dome unwrap puts its top at the
                   region's centre and its foot at the rim.
      B (256, 0)   flowering bush: the same leaves (another seed) and seven sprays of three to five flowers (10 to 12 px,
                   70% cream, the rest coral) near the centre, where the unwrap puts the bush's top
      C (0, 256)   reeds: blades x 0..192 (eight 24 px strips: dark green base, olive middle, dry straw tip), the cattail
                   stem x 192..208, the cattail head x 208..256 (warm brown velvet, darker flecks)
      D (256, 256) reserved for the P2 plants (tufts, flower clumps, ferns): a plain grass gradient until they are drawn
  understory-blob.png   64 x 64 RGBA: the soft shade under a bush (dark green, alpha falls off to 0 at the rim)

Colours: matte and believable (Spencer: textured surroundings so the pets stand out). The Aero day light renders a
TextureID about 1.0 / 1.22 / 1.29 brighter in R / G / B on sunlit tops (memory: roblox-surfaceappearance-runtime), so
the greens are drawn a little warmer and lower in blue (COMP). The bush's base-to-top shade is the mesh's vertex colour
(a MeshPart's TextureID multiplies it), not painted here. Deterministic: the same bytes every run.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "understory"
SIZE = 512
R = 256                     # one region
SS = 3                      # supersampling for the drawn shapes
COMP = (1.0, .9, .84)       # render compensation for the Aero sun (greens and browns)
FLOWER_COMP = (1.0, .96, .9)
SEED = 20261127

GAP = "#2C5336"
LEAVES = ["#336740", "#407C44", "#4C904B", "#5AA153"]
HIGHLIGHT = "#6EAB65"    # #6E9A55 after COMP


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


def leaf(d, x, y, length, width, turn, colour, rib):
    """A pointed leaf (both ends) with a darker midrib."""
    pts = []
    for s in range(16):
        t = s / 16 * math.tau
        px = math.cos(t) * length / 2
        py = math.sin(t) * width / 2 * abs(math.cos(t * .5)) ** .3
        pts.append((x + px * math.cos(turn) - py * math.sin(turn), y + px * math.sin(turn) + py * math.cos(turn)))
    d.polygon(pts, fill=colour)
    dx, dy = math.cos(turn) * length * .42, math.sin(turn) * length * .42
    d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=rib, width=max(1, SS))


def leaf_region(seed, flowers):
    py = random.Random(seed)
    npr = np.random.default_rng(seed)
    n = R * SS
    img = Image.new("RGB", (n, n), comp(hexrgb(GAP)))
    d = ImageDraw.Draw(img)
    # About 25 clusters, each a rosette of leaves round its centre, lighter toward its top left (the sun side): clumps
    # with dark pockets between them. A few clusters sit across the edges so the rim (the bush's foot) is leafy too.
    clusters = [(py.random() * n, py.random() * n) for _ in range(25)]
    for cx, cy in clusters:
        rad = (40 + py.random() * 16) * SS
        for _ in range(72):
            a = py.random() * math.tau
            r = rad * math.sqrt(py.random())
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            lit = .55 - (math.cos(a) * r + math.sin(a) * r) / (2.6 * rad)
            idx = int(max(0, min(3, round(lit * 3 + (py.random() - .5)))))
            colour = HIGHLIGHT if (idx == 3 and py.random() < .14) else LEAVES[idx]
            length = (16 + py.random() * 6) * SS
            width = length * (.36 + py.random() * .1)
            # leaves point out from their cluster's middle, give or take
            turn = a + py.uniform(-.6, .6)
            leaf(d, x, y, length, width, turn, comp(hexrgb(colour)), comp(hexrgb(LEAVES[max(0, idx - 1)])))
    if flowers:
        cream, coral, centre = hexrgb("#F2E6CC"), hexrgb("#E0785C"), hexrgb("#C9983C")
        mid = n / 2
        for spray in range(7):
            a, r = py.random() * math.tau, (18 + py.random() * 62) * SS
            sx, sy = mid + math.cos(a) * r, mid + math.sin(a) * r
            colour = coral if spray in (2, 5) else cream          # five of seven cream (70%)
            for _ in range(py.randint(3, 5)):
                x, y = sx + py.uniform(-14, 14) * SS, sy + py.uniform(-14, 14) * SS
                size = (10 + py.random() * 2) * SS / 2          # 10 to 12 px across
                turn = py.random() * math.tau
                for p in range(5):
                    pa = turn + p * math.tau / 5
                    px, pyy = x + math.cos(pa) * size * .52, y + math.sin(pa) * size * .52
                    shade = .86 if math.sin(pa) > .3 else 1.0
                    c = comp(tuple(int(v * shade) for v in colour), FLOWER_COMP)
                    d.ellipse([px - size * .5, pyy - size * .5, px + size * .5, pyy + size * .5], fill=c)
                d.ellipse([x - size * .26, y - size * .26, x + size * .26, y + size * .26], fill=comp(centre, FLOWER_COMP))
    img = img.resize((R, R), Image.LANCZOS)
    arr = np.asarray(img).astype(np.float64)
    arr *= (value_noise(R, R, 32, npr) * .14 + .93)[:, :, None]   # matte wobble, +-7%
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def reed_region(rng):
    """Blades (x 0..192), stem (192..208), cattail head (208..256). Image top = blade tip, bottom = base."""
    out = np.zeros((R, R, 3))
    base, mid, tip = (np.array(comp(hexrgb(h)), dtype=np.float64) for h in ("#2F4F27", "#5F7A3C", "#A89F62"))
    ys = np.linspace(1, 0, R)[:, None]
    lower = np.clip(ys / .6, 0, 1)
    upper = np.clip((ys - .6) / .4, 0, 1)
    grad = base * (1 - lower)[..., None] + mid * lower[..., None]
    grad = grad * (1 - upper)[..., None] + tip * upper[..., None]
    out[:, :192] = grad
    streak = rng.random(192) * .18 + .91
    long = value_noise(192, R, 16, rng) * .1 + .95
    out[:, :192] *= streak[None, :, None] * long[:, :, None]
    for x in range(12, 192, 24):
        out[:, x - 1:x + 1] *= .82
    stem = np.array(comp(hexrgb("#55703A")), dtype=np.float64)
    out[:, 192:208] = stem * (.8 + .2 * ys)[..., None]
    brown, dark = np.array(comp(hexrgb("#6E4A2C")), dtype=np.float64), np.array(comp(hexrgb("#4A311E")), dtype=np.float64)
    fleck = (rng.random((R, 48)) < .22)[:, :, None]
    out[:, 208:] = np.where(fleck, dark, brown) * (value_noise(48, R, 8, rng) * .16 + .92)[:, :, None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def reserved_region():
    ys = np.linspace(0, 1, R)[:, None, None]
    top, bottom = np.array(comp(hexrgb("#4C7A3A"))), np.array(comp(hexrgb("#2E5528")))
    arr = top * (1 - ys) + bottom * ys
    return Image.fromarray(np.repeat(arr, R, axis=1).astype(np.uint8))


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
    atlas.paste(leaf_region(SEED, False), (0, 0))
    atlas.paste(leaf_region(SEED + 1, True), (R, 0))
    atlas.paste(reed_region(np.random.default_rng(SEED + 2)), (0, R))
    atlas.paste(reserved_region(), (R, R))
    atlas.save(OUT / "understory-atlas.png", optimize=False)
    blob().save(OUT / "understory-blob.png", optimize=False)
    print("understory atlas ->", (OUT / "understory-atlas.png").relative_to(ROOT), "and blob")


if __name__ == "__main__":
    main()
