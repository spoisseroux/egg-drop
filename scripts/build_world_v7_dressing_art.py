"""Ground dressing textures for World 1 v7 (batch 2026-11-13, W1). Original pixel art.

  python scripts/build_world_v7_dressing_art.py

Flower patches: flat, upward-facing clusters of flower heads seen from above, laid on the grass as Decals on thin
invisible parts (src/client/WorldDressingClient.lua). Same retro language as the feel-alive sprites
(artifacts/feel-alive-2026-11-13/sprites/): hard pixels, a darker selective outline, no gradients, the world v7
palette. Each patch is drawn on a 64 x 64 logical grid (a patch is about 4 studs across, 16 px per stud) and
saved 4x with nearest-neighbour (256 px) so Roblox filtering keeps the pixels crisp.

  assets/world/textures/flower_patch_<kind>.png   kinds: daisy, tulip, bellflower, buttercup, starbloom
  assets/world/textures/frond_leaf.png            128 px leaf strip for the frond bush meshes (u across, v base->tip)
  assets/world/textures/_dressing-sheet.png       review sheet (patches on a grass swatch)

Upload each as an Image; put the ids into assets/world/world-dressing-import.json ("flowers": {kind: id}, and
"texture" = the frond_leaf id), then rerun scripts/build_world_v7_dressing.py and build_world_v7_assets.py.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "textures"
G = 64
KINDS = ["daisy", "tulip", "bellflower", "buttercup", "starbloom"]
PAL = {
    "leaf": "#2FA83F", "leaf_d": "#1F8338", "leaf_l": "#4FCB62",
    "white": "#FFFFFF", "white_d": "#D9E6F7",
    "yellow": "#FFD84A", "yellow_d": "#F2B62E", "orange": "#F29A2E",
    "pink": "#FF6FAE", "pink_d": "#E04C93", "pink_l": "#FFC9DC",
    "lilac": "#A88BFF", "lilac_d": "#7F63DE", "lilac_l": "#D4C6FF",
    "aqua": "#35C7F5", "aqua_d": "#1E9FD6", "aqua_l": "#B8ECFF",
    "cream": "#FFF3D6",
}
OUTLINE = {"leaf": "#17642B", "leaf_l": "#17642B", "leaf_d": "#17642B", "white": "#8E96B8", "white_d": "#8E96B8",
           "yellow": "#B9781C", "yellow_d": "#B9781C", "orange": "#A35E14", "pink": "#A8326A", "pink_d": "#A8326A",
           "pink_l": "#A8326A", "lilac": "#5A43A8", "lilac_d": "#5A43A8", "lilac_l": "#5A43A8", "aqua": "#14719E",
           "aqua_d": "#14719E", "aqua_l": "#14719E", "cream": "#B9781C"}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


class Grid:
    def __init__(self):
        self.c = [[None] * G for _ in range(G)]

    def px(self, x, y, col):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < G and 0 <= y < G:
            self.c[y][x] = col

    def shape(self, cx, cy, fn, col, r):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if fn(x + .5 - cx, y + .5 - cy):
                    self.px(x, y, col)

    def disc(self, cx, cy, r, col):
        self.shape(cx, cy, lambda dx, dy: dx * dx + dy * dy <= r * r, col, r)

    def petals(self, cx, cy, n, r, col, rot=0.0, width=.55):
        """n rounded petals around (cx, cy): polar rose clipped to radius r."""
        def inside(dx, dy):
            d = math.hypot(dx, dy)
            if d > r:
                return False
            a = math.atan2(dy, dx) - rot
            lobe = abs(math.cos(a * n / 2))
            return d <= r * (1 - width + width * lobe)
        self.shape(cx, cy, inside, col, r)

    def leaf(self, cx, cy, angle, length, fat, col, shade):
        n = 20
        ux, uy = math.cos(angle), math.sin(angle)
        for i in range(n + 1):
            t = i / n
            x, y = cx + ux * length * t, cy + uy * length * t
            r = fat * math.sin(math.pi * min(1, t * 1.1)) ** .8
            for k in range(-int(r) - 1, int(r) + 2):
                if abs(k) <= r:
                    self.px(x - uy * k, y + ux * k, shade if k > r * .2 else col)

    def image(self, scale=4):
        im = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        for y in range(G):
            for x in range(G):
                col = self.c[y][x]
                if col:
                    im.putpixel((x, y), rgb(PAL[col]) + (255,))
                    continue
                near = [self.c[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < G and 0 <= y + dy < G and self.c[y + dy][x + dx]]
                if near:
                    im.putpixel((x, y), rgb(OUTLINE[near[0]]) + (255,))
        return im.resize((G * scale, G * scale), Image.NEAREST)


def head(g, kind, cx, cy, s, rng):
    rot = rng.uniform(0, math.tau)
    if kind == "daisy":
        g.petals(cx, cy, 8, 3.6 * s, "white", rot, .5)
        g.petals(cx, cy, 8, 2.6 * s, "white_d", rot + math.pi / 8, .4)
        g.petals(cx, cy, 8, 2.4 * s, "white", rot, .5)
        g.disc(cx, cy, 1.25 * s, "yellow")
        g.px(cx - .4 * s, cy - .4 * s, "yellow_d")
    elif kind == "tulip":       # a cup seen from above: three outer petals, darker throat
        g.petals(cx, cy, 3, 3.2 * s, "pink", rot, .45)
        g.petals(cx, cy, 3, 2.3 * s, "pink_l", rot + math.pi / 3, .45)
        g.disc(cx, cy, 1.2 * s, "pink_d")
        g.px(cx, cy, "yellow")
    elif kind == "bellflower":  # an open bell from above: five lobes, pale rim
        g.petals(cx, cy, 5, 3.1 * s, "lilac", rot, .35)
        g.petals(cx, cy, 5, 2.0 * s, "lilac_d", rot, .35)
        g.disc(cx, cy, .9 * s, "lilac_l")
    elif kind == "buttercup":
        g.petals(cx, cy, 5, 3.2 * s, "yellow", rot, .45)
        g.petals(cx, cy, 5, 2.0 * s, "yellow_d", rot, .45)
        g.disc(cx, cy, 1.0 * s, "orange")
        g.px(cx, cy, "cream")
    elif kind == "starbloom":   # five sharp points
        g.petals(cx, cy, 5, 3.6 * s, "aqua", rot, .8)
        g.petals(cx, cy, 5, 2.2 * s, "aqua_l", rot, .7)
        g.disc(cx, cy, 1.0 * s, "white")


def patch(kind, seed):
    rng = random.Random(seed)
    g = Grid()
    heads = []
    for _ in range(400):
        if len(heads) >= 8:
            break
        a, d = rng.uniform(0, math.tau), 22 * math.sqrt(rng.random())
        x, y = 32 + math.cos(a) * d, 32 + math.sin(a) * d
        s = rng.uniform(1.2, 1.6)
        if all(math.hypot(x - hx, y - hy) > 7.5 * max(s, hs) for hx, hy, hs, _ in heads):
            k = kind if rng.random() > .18 or kind == "daisy" else "daisy"
            heads.append((x, y, s, k))
    # Leaf rosettes under every head, then a few loose leaves, then the heads on top.
    for x, y, s, _ in heads:
        for j in range(rng.randint(3, 5)):
            ang = rng.uniform(0, math.tau)
            g.leaf(x, y, ang, rng.uniform(5, 7.5) * s, 1.5 * s, "leaf_l" if j % 2 else "leaf", "leaf_d")
    for x, y, s, k in heads:
        head(g, k, x, y, s, rng)
    return g.image()


def frond_leaf():
    """Leaf strip: deep green at the base to a light tip, a pale midrib, darker edges. u across, v base (bottom)."""
    w = h = 128
    im = Image.new("RGB", (w, h))
    base, tip, rib, edge = rgb("#1F7A37"), rgb("#86E07C"), rgb("#C8F5A8"), rgb("#145C29")
    for y in range(h):
        t = 1 - y / (h - 1)                      # image top = leaf tip (v = 1)
        t = round(t * 6) / 6                      # banded, painted rather than smooth
        c = tuple(round(base[i] + (tip[i] - base[i]) * t) for i in range(3))
        for x in range(w):
            u = abs(x / (w - 1) - .5) * 2
            col = c
            if u < .06:
                col = rib
            elif u > .82:
                col = edge
            elif 0.38 < u < 0.44 and (y // 10) % 2 == 0:
                col = tuple(round(v * .88) for v in c)  # vein dashes
            im.putpixel((x, y), col)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (len(KINDS) * 264 + 8, 272), rgb("#2DA83A"))
    for i, kind in enumerate(KINDS):
        img = patch(kind, 7 + i * 31)
        img.save(OUT / f"flower_patch_{kind}.png")
        sheet.paste(img, (8 + i * 264, 8), img)
    frond_leaf().save(OUT / "frond_leaf.png")
    sheet.save(OUT / "_dressing-sheet.png")
    print("wrote", len(KINDS), "flower patches and frond_leaf.png to", OUT)


if __name__ == "__main__":
    main()
