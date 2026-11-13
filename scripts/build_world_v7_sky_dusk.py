"""Paint the locked-dusk skybox for World 1 v7 (batch 2026-11-13, W1). Original art; mood only.

  python scripts/build_world_v7_sky_dusk.py

A warm golden-hour sky: pale gold at the horizon through peach and rose to a soft lilac zenith, a broad golden
glow toward the key light (the engine draws the sun disc itself, so the painted sky has no hard sun), a few
posterised pink puffs on the horizon and, below it, a pink cloud sea seen from above (noise sampled on a plane
under the island, so the tops shrink in perspective toward the horizon).

Writes assets/art-source/environment/sky/dusk/Sky_{Bk,Dn,Ft,Lf,Rt,Up}.png (1024 px) in the generate_sky.py
convention and _preview.png; then run scripts/build_world_v7_sky.py to write the Roblox-ready faces to
assets/world/sky/dusk/ for upload (ids go to world-v7-uploads.json "sky"."dusk").
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art-source" / "environment" / "sky" / "dusk"
GLOW = np.array([-.52, .12, .42]); GLOW /= np.linalg.norm(GLOW)     # broad warm side, low in the sky


def hexc(h):
    h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def ramp(t, xs, cols):
    cols = np.array([hexc(c) for c in cols]); t = np.clip(t, xs[0], xs[-1])
    return np.stack([np.interp(t, xs, cols[:, k]) for k in range(3)], -1)


def _hash(i, j, k, s):
    n = np.sin(i * 127.1 + j * 311.7 + k * 74.7 + s * 19.19) * 43758.5453
    return n - np.floor(n)


def noise3(x, y, z, s=0):
    i, j, k = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - i, y - j, z - k
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy); fz = fz * fz * (3 - 2 * fz)

    def L(a, b, t): return a + (b - a) * t
    return L(L(L(_hash(i, j, k, s), _hash(i + 1, j, k, s), fx), L(_hash(i, j + 1, k, s), _hash(i + 1, j + 1, k, s), fx), fy),
             L(L(_hash(i, j, k + 1, s), _hash(i + 1, j, k + 1, s), fx), L(_hash(i, j + 1, k + 1, s), _hash(i + 1, j + 1, k + 1, s), fx), fy), fz)


def fbm3(x, y, z, s=0, octs=4):
    t = 0; a = 1; tot = 0
    for o in range(octs):
        t = t + a * noise3(x, y, z, s + o * 7); tot += a; a *= .5; x, y, z = x * 2, y * 2, z * 2
    return t / tot


def sm(a, b, t):
    t = np.clip((t - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def sky(X, Y, Z):
    d = np.sqrt(X * X + Y * Y + Z * Z); X, Y, Z = X / d, Y / d, Z / d
    col = ramp(Y, [-.02, .0, .05, .16, .34, .6, 1.0],
               ["#FFD9A6", "#FFE6B2", "#FFE9C2", "#FCD8C2", "#F2C6CF", "#DCC0DD", "#C4B6E2"])
    glow = np.clip(X * GLOW[0] + Y * GLOW[1] + Z * GLOW[2], 0, 1)
    col = col + (glow ** 5)[..., None] * np.array([.10, .05, -.04]) + (glow ** 40)[..., None] * np.array([.10, .07, .0])
    # Horizon puffs: posterised, lit from the warm side.
    n = fbm3(X * 2.4, Y * 2.4 * 3.0, Z * 2.4, 5)
    lit = fbm3(X * 2.4 + .3, Y * 7.2 + .55, Z * 2.4, 5)
    band = np.exp(-((Y - .06) / .09) ** 2)
    m = sm(.50, .56, n) * band
    shade = np.round(np.clip(.55 + (lit - n) * 8 + glow * .5, 0, 1) * 2) / 2
    puff = ramp(shade, [0, .5, 1], ["#E9A4C8", "#F8C6DC", "#FFEAD8"])
    col = col * (1 - m[..., None]) + puff * m[..., None]
    # Cloud sea below the island: tops on a plane one unit down.
    below = Y < -.004
    t = np.where(below, 1 / np.maximum(-Y, .004), 0)
    px, pz = X * t, Z * t
    big = fbm3(px * .35, pz * .35, np.zeros_like(px) + 3.1, 21, 3)
    sea_n = fbm3(px * 1.3, pz * 1.3, np.zeros_like(px) + 7.7, 31, 4) * .55 + big * .45
    sea_l = fbm3(px * 1.3 + .07, pz * 1.3 - .05, np.zeros_like(px) + 7.7, 31, 4) * .55 + big * .45
    # Billow tops: brighter where the surface rises toward the warm side, darker in the folds.
    tone = np.clip(.45 + (sea_n - sea_l) * 10 + (sea_n - .5) * 2.2 + glow * .3, 0, 1)
    tone = np.round(tone * 3) / 3
    sea = ramp(tone, [0, 1 / 3, 2 / 3, 1], ["#C47FB6", "#E296C8", "#F5B9D9", "#FFE2EC"])
    # Haze where the sea meets the sky; the far sea fades to the warm horizon colour.
    far = sm(-.22, -.004, Y)
    haze = ramp(Y * 0, [0, 1], ["#F9CDD6", "#F9CDD6"])
    sea = sea * (1 - far[..., None] * .75) + haze * (far[..., None] * .75)
    edge = sm(-.03, .004, Y)
    col = np.where(below[..., None], sea * (1 - edge[..., None]) + col * edge[..., None], col)
    return np.clip(col, 0, 1)


FACES = {  # name: (forward, right, up) in Roblox axes, the generate_sky.py convention
    "Ft": ((0, 0, -1), (1, 0, 0), (0, 1, 0)), "Bk": ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    "Rt": ((1, 0, 0), (0, 0, 1), (0, 1, 0)), "Lf": ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    "Up": ((0, 1, 0), (1, 0, 0), (0, 0, 1)), "Dn": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
}


def face(name, n=1024):
    f, r, u = (np.array(v, float) for v in FACES[name])
    a = (np.arange(n) + .5) / n * 2 - 1
    A, Bv = np.meshgrid(a, -a)
    D = f[None, None, :] + A[..., None] * r + Bv[..., None] * u
    return sky(D[..., 0], D[..., 1], D[..., 2])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    imgs = {nm: face(nm) for nm in FACES}
    for nm, im in imgs.items():
        Image.fromarray((im * 255 + .5).astype(np.uint8)).save(OUT / f"Sky_{nm}.png")
    small = {nm: im[::4, ::4] for nm, im in imgs.items()}; blank = np.ones_like(small["Ft"])
    strip = np.concatenate([np.concatenate([blank, small["Up"], blank, blank], 1),
                            np.concatenate([small["Lf"], small["Ft"], small["Rt"], small["Bk"]], 1),
                            np.concatenate([blank, small["Dn"], blank, blank], 1)], 0)
    Image.fromarray((strip * 255 + .5).astype(np.uint8)).save(OUT / "_preview.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
