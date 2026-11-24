"""Round 3 Aero maps (LOOK-R3, Fable 2026-11-23): the pool tile, its glint layer, the falls' foot shade and the crowns'
leaf-cluster tiles. Drawn from scratch with numpy/PIL, fixed seeds, every tile seamless by construction (all noise is
a sum of whole-cycle waves on the tile, Voronoi points are wrapped, leaves crossing an edge are drawn again opposite).

Run from the repository root:  python -I scripts/draw_aero_r3_textures.py
Writes assets/world/textures/aero/{pool-aero, pool-glint, foot-shade, leaf-dark, leaf-lime, leaf-rough}.png and
artifacts/world-pass-2026-11-22/reexport/r5/textures-report.json (+ 3x3 seam sheets).
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "world", "textures", "aero")
EVIDENCE = os.path.join(ROOT, "artifacts", "world-pass-2026-11-22", "reexport", "r5")


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


def smoothstep(e0, e1, x):
    k = np.clip((x - e0) / (e1 - e0), 0, 1)
    return k * k * (3 - 2 * k)


def wrapped_noise(rng, size, max_cycles, octaves=12):
    """Seamless smooth noise in [-1, 1]: a sum of waves with whole cycles across the tile."""
    y, x = np.mgrid[0:size, 0:size] / size
    out = np.zeros((size, size))
    for _ in range(octaves):
        fx, fy = rng.integers(-max_cycles, max_cycles + 1, 2)
        if fx == 0 and fy == 0:
            fx = 1
        out += math.sqrt(1 / (1 + fx * fx + fy * fy)) * np.sin(2 * np.pi * (fx * x + fy * y) + rng.uniform(0, 2 * np.pi))
    return out / np.max(np.abs(out))


def voronoi_net(rng, size, studs, grid, drop=0, warp=.4, warp_cycles=2):
    """Wrapped Voronoi on a size px tile of `studs` studs. Returns (edge distance in studs, F1 in studs, edge id)."""
    pts = []
    for j in range(grid):
        for i in range(grid):
            pts.append(((i + rng.uniform(.15, .85)) / grid, (j + rng.uniform(.15, .85)) / grid))
    for _ in range(drop):
        pts.pop(rng.integers(len(pts)))
    pts = np.array(pts)
    y, x = np.mgrid[0:size, 0:size] / size
    wx = wrapped_noise(rng, size, warp_cycles, 6) * warp / studs
    wy = wrapped_noise(rng, size, warp_cycles, 6) * warp / studs
    x, y = x + wx, y + wy
    best1 = np.full((size, size), 9.0)
    best2 = np.full((size, size), 9.0)
    id1 = np.zeros((size, size), dtype=np.int64)
    id2 = np.zeros((size, size), dtype=np.int64)
    for k, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.hypot(x - (px + ox), y - (py + oy))
                closer = d < best1
                second = ~closer & (d < best2)
                best2 = np.where(closer, best1, np.where(second, d, best2))
                id2 = np.where(closer, id1, np.where(second, k, id2))
                best1 = np.where(closer, d, best1)
                id1 = np.where(closer, k, id1)
    edge = (best2 - best1) / 2 * studs
    pair = np.minimum(id1, id2) * 1000 + np.maximum(id1, id2)
    return edge, best1 * studs, pair, len(pts)


def pool_tile(report):
    size, studs = 512, 14.0
    rng = np.random.default_rng(31)
    edge, f1, pair, count = voronoi_net(rng, size, studs, 5, drop=1)
    width = 1 + .4 * wrapped_noise(rng, size, 4, 10)                      # .6x to 1.4x along a line
    core, soft = .10 / 2 * width, .45 * width
    line = 1 - smoothstep(core, soft, edge)
    # 30 percent of the edges fade out along their length.
    pairs = np.unique(pair)
    broken = set(rng.choice(pairs, int(len(pairs) * .3), replace=False).tolist())
    fade = smoothstep(-.6, .5, wrapped_noise(rng, size, 3, 8))
    mask = np.isin(pair, list(broken))
    line = np.where(mask, line * fade, line)
    base, peak, centre = hexrgb("#379DB9"), hexrgb("#5DB7CD"), hexrgb("#3193AF")
    dip = smoothstep(1.2, 0.0, f1) * .6                                    # a soft dip at the cell centres
    img = base[None, None, :] * (1 - dip[..., None]) + centre[None, None, :] * dip[..., None]
    img = img * (1 - line[..., None]) + peak[None, None, :] * line[..., None]
    mottle = wrapped_noise(rng, size, int(studs / 3), 10)                  # blobs about 3 studs
    img = img + (hexrgb("#3AA7B4") - img) * (np.clip(mottle, 0, 1) * .5)[..., None] * .04
    img = np.minimum(img, hexrgb("#7CC8D8"))
    mean = img.reshape(-1, 3).mean(0)
    # Studio r5: under the Aero sun and sky the part renders its map about 1.0 / 1.22 / 1.29 times brighter (R / G / B):
    # the drawn tile #3BA3BE showed as (58, 200, 246). So the file holds RENDER_LIFT-compensated values; what the
    # player sees is Fable's #3BA3BE with its net, measured from the capture.
    lift = np.array([1.0, 1.22, 1.29])
    target = hexrgb("#3BA3BE") / lift
    img = np.clip(img * (target / mean), 0, 255)                          # hold the (compensated) mean
    img = np.minimum(img, hexrgb("#7CC8D8") / lift)
    out = img.round().astype(np.uint8)
    Image.fromarray(out, "RGB").save(os.path.join(OUT, "pool-aero.png"))
    report["pool-aero"] = {"px": size, "studs": studs, "points": count, "edges": int(len(pairs)), "broken": len(broken),
                           "mean_shift": [round(float(v), 1) for v in (target - mean)],
                           "mean": [round(float(v), 1) for v in out.reshape(-1, 3).mean(0)],
                           "max": [int(v) for v in out.reshape(-1, 3).max(0)]}
    return out


def glint_tile(report):
    size, studs = 256, 9.0
    rng = np.random.default_rng(47)
    grid = round(studs / 1.8)
    edge, _, pair, count = voronoi_net(rng, size, studs, grid, warp=.3)
    px = studs / size
    pairs = np.unique(pair)
    keep = set(rng.choice(pairs, int(len(pairs) * .35), replace=False).tolist())
    line = 1 - smoothstep(px * 1.0, px * 4.6, edge)                       # core 2 px, soft to ~9 px across
    line *= np.isin(pair, list(keep))
    line *= .55 + .45 * smoothstep(-.8, .6, wrapped_noise(rng, size, 3, 8))
    alpha = (np.clip(line, 0, 1) * 255).round().astype(np.uint8)
    rgba = np.dstack([np.full((size, size), 255, np.uint8)] * 3 + [alpha])
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "pool-glint.png"))
    report["pool-glint"] = {"px": size, "studs": studs, "cells": count, "kept_edges": len(keep), "of": int(len(pairs)),
                            "lit_share": round(float((alpha > 25).mean()), 3)}
    return alpha


def foot_shade(report):
    """128 px white with alpha. Image X across the foot (12 studs), image Y out from the foot (5 studs, row 0 at the
    foot). Full at the middle of the foot edge, zero by 4 studs out, zero on the three outer edges."""
    size = 128
    y, x = (np.mgrid[0:size, 0:size] + .5) / size
    across = (x - .5) * 12 / 6.0                                         # 1 at the side edges
    out = y * 5 / 4.0                                                     # 1 at 4 studs out
    r = np.sqrt(across ** 2 + out ** 2)
    # Studio r5: a plain smooth falloff read as a thin strip at the very foot (under the boil). Hold full strength out to
    # 40 percent of the radius, then fade.
    alpha = 1 - smoothstep(.4, 1.0, r)
    alpha *= smoothstep(1.0, .85, np.abs(x - .5) * 2)                    # clean side edges
    a = (alpha * 255).round().astype(np.uint8)
    a[:, 0] = a[:, -1] = 0
    a[-1, :] = 0
    rgba = np.dstack([np.full((size, size), 255, np.uint8)] * 3 + [a])
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "foot-shade.png"))
    report["foot-shade"] = {"px": size, "foot_row_peak": int(a[0].max()), "outer_edges_max": int(max(a[:, 0].max(), a[:, -1].max(), a[-1].max()))}


def leaf_tiles(report, colour=True):
    """One leaf layout (256 px = 4 studs), two palettes and one roughness map."""
    size, ss = 256, 4
    big = size * ss
    rng = np.random.default_rng(83)
    layers = []  # (layer, polygon points in big px), drawn in order
    def leaf(layer):
        length = rng.uniform(22, 34) * ss
        width = rng.uniform(10, 16) * ss
        if rng.uniform() < .6:
            ang = math.pi / 2 + math.radians(rng.uniform(-40, 40))          # hanging: tip toward the image bottom
        else:
            ang = rng.uniform(0, 2 * math.pi)
        cx, cy = rng.uniform(0, big), rng.uniform(0, big)
        ca, sa = math.cos(ang), math.sin(ang)
        left, right = [], []
        for k in range(13):
            t = k / 12
            half = width / 2 * math.sin(math.pi * t) ** .8                # a pointed oval
            ax = (t - .35) * length
            left.append((ax, -half))
            right.append((ax, half))
        def place(pts):
            return [(cx + a * ca - b * sa, cy + a * sa + b * ca) for a, b in pts]
        # The leaf is two halves: the lit long edge and the shaded one.
        lit = place(left + [(right[-1][0], 0), (right[0][0], 0)][::-1])
        shade = place([(p[0], 0) for p in left][::-1] + right)
        layers.append((layer, place(left + right[::-1]), lit, shade))
    counts = {"mid": 290, "light": 56}
    for name, n in counts.items():
        for _ in range(n):
            leaf(name)
    # Index image: 0 gap, 1 mid, 2 mid lit edge, 3 light, 4 light lit edge.
    idx = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(idx)
    code = {"mid": (1, 2), "light": (3, 4)}
    for layer in ("mid", "light"):
        for name, whole, lit, _ in layers:
            if name != layer:
                continue
            for ox in (-big, 0, big):
                for oy in (-big, 0, big):
                    draw.polygon([(x + ox, y + oy) for x, y in whole], fill=code[name][0])
                    draw.polygon([(x + ox, y + oy) for x, y in lit], fill=code[name][1])
    small = np.array(idx)
    report_cover = {"gap": float((small == 0).mean()), "mid": float(np.isin(small, (1, 2)).mean()),
                    "light": float(np.isin(small, (3, 4)).mean())}
    out = {}
    for tile, (light, mid, gap) in {"leaf-dark": ("#3F9A4E", "#2A7A3C", "#17522A"),
                                     "leaf-lime": ("#A6D552", "#86BE3C", "#4F8F2A")}.items():
        L, M, G = hexrgb(light), hexrgb(mid), hexrgb(gap)
        lut = np.array([G, M, M * 1.06, L, np.minimum(L * 1.05, 255)])
        rgb = lut[small]
        img = Image.fromarray(rgb.round().astype(np.uint8), "RGB").resize((size, size), Image.LANCZOS)
        if colour:
            img.save(os.path.join(OUT, tile + ".png"))
        out[tile] = [round(float(v), 1) for v in np.array(img).reshape(-1, 3).mean(0)]
    # LOOK-R3 round 6: leaves .88 left a grey-tan sheen on shaded faces; leaves and gaps both 1.0 (flat 255).
    rough = np.full(small.shape, 255, np.uint8)
    Image.fromarray(rough, "L").resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "leaf-rough.png"))
    report["leaf-tiles"] = {"px": size, "studs": 4, "leaves": sum(counts.values()), "cover": {k: round(v, 3) for k, v in report_cover.items()},
                            "means": out}


def seam_sheet(name):
    img = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
    w, h = img.size
    sheet = Image.new("RGBA", (w * 3, h * 3), (40, 40, 40, 255))
    for i in range(3):
        for j in range(3):
            sheet.alpha_composite(img, (i * w, j * h))
    sheet.convert("RGB").save(os.path.join(EVIDENCE, name + "-3x3.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(EVIDENCE, exist_ok=True)
    report = {}
    pool_tile(report)
    glint_tile(report)
    foot_shade(report)
    # The leaf tiles moved to scripts/draw_aero_r4_textures.py (LOOK-R4 W2, denser); leaf-rough stays drawn here (flat 1.0).
    leaf_tiles(report, colour=False)
    for name in ("pool-aero", "pool-glint"):
        seam_sheet(name)
    with open(os.path.join(EVIDENCE, "textures-report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
