"""Garden life for beta (14) QA: the textures (Fable's WORLD-AND-NEST-LOOK sections 1, 6, 7; GARDEN-LIFE-BUILD-PLAN 9).

Spencer's rule: ambient life and the ground are realistic, textured and matte, lower-saturation natural colour, so the
pets stay the brightest things on screen. Script-drawn, deterministic (fixed seeds), numpy + Pillow, no outside art.
Nothing is uploaded here (Studio MCP upload_image later); ids go into src/shared/LifeArtR4.lua.

Writes to artifacts/qa-2026-11-23-beta14/look/ :
  leaf-sheet.png        192x192  2 x 2 flipbook of 96 cells: A broad #5E8F3A, B willow #7C7A3A -> #7A5A30 at the tip,
                                 C lime heart with a saw-tooth edge #8FA83E (midrib #C9D08A), D dry curl #A8762E / #5C3D1C.
                                 Stem down, no outline, the shade half 12% darker, a 2 px rim on the shade side only.
  leaf-sheet-ac.png     192x96   the flipbook fallback (A + C); leaf-sheet-bd.png 192x96 (B + D).
  dewdrop-stem.png      192x262  assets/world/dewdrop.png with a 2 px #5A4A2A stem from the fruit to the top edge.
  dapple.png            256x256  soft leaf shade (white; the Decal tints it #1E2A16), alpha, fading to the edges.
  koi-a/b/c.png         48x128   seen from above, head at the top: orange and white, pale gold, slate. No outline.
  litter.png            256x256  the four leaves at rest, scattered, alpha.
  lawn-patch-a.png      256x256  mown stripes, grey value, soft alpha (the Decal tints it); lawn-patch-b.png clover.
  path-fray.png         256x96   dirt (bottom) breaking into grass tufts (top), alpha fading at the ends.
  preview-r4.png                 a contact sheet (not for upload).

Run:  python scripts/draw_garden_life_r4_textures.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "qa-2026-11-23-beta14" / "look"
SS = 4  # supersampling for anti-aliased edges


def rgb(h: str, k: float = 1.0) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(max(0, min(255, int(int(h[i:i + 2], 16) * k))) for i in (0, 2, 4))


def lerp(a: tuple, b: tuple, t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def down(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    return img.resize(size, Image.LANCZOS)


def noise(shape: tuple[int, int], seed: int, blur: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    img = Image.fromarray((rng.random(shape) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(img, dtype=np.float32) / 255
    return (a - a.min()) / max(1e-6, a.max() - a.min())


def leaf_outline(kind: str, cx: float, cy: float, length: float, width: float) -> list[tuple[float, float]]:
    """A leaf silhouette, point up, stalk down, centred at (cx, cy)."""
    pts = []
    n = 60
    for i in range(n + 1):
        t = i / n  # 0 at the base, 1 at the tip
        if kind == "A":
            w = width * math.sin(math.pi * t) ** .9 * (1 - .15 * t)
        elif kind == "B":
            w = width * .45 * math.sin(math.pi * t) ** .7
        else:  # C: heart, a lopsided base
            w = width * (math.sin(math.pi * min(1, t * 1.15)) ** .6) * (1.1 - .6 * t)
        pts.append((t, w))
    left = [(cx - w + (0 if kind != "B" else 6 * math.sin(t * 2)), cy + length / 2 - t * length) for t, w in pts]
    right = [(cx + w * (1.08 if kind == "C" else 1) + (0 if kind != "B" else 6 * math.sin(t * 2)), cy + length / 2 - t * length)
             for t, w in reversed(pts)]
    if kind == "C":
        # Saw-tooth edge: nudge every other point out.
        left = [(x - (2.5 * SS if i % 4 == 0 and 0 < i < len(left) - 3 else 0), y) for i, (x, y) in enumerate(left)]
        right = [(x + (2.5 * SS if i % 4 == 0 and 3 < i < len(right) else 0), y) for i, (x, y) in enumerate(right)]
    return left + right


def draw_leaf(kind: str, size: int = 96, seed: int = 1) -> Image.Image:
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2 - 4 * SS
    if kind == "D":
        # A dry leaf seen side-on, curled into a "C", a notch out of one edge.
        outside, inside = rgb("#A8762E"), rgb("#5C3D1C")
        box = (S * .18, S * .16, S * .82, S * .80)
        d.pieslice(box, 200, 520, fill=outside + (255,))
        inner = (S * .30, S * .28, S * .70, S * .68)
        d.pieslice(inner, 210, 510, fill=inside + (255,))
        d.ellipse((S * .40, S * .40, S * .60, S * .60), fill=(0, 0, 0, 0))
        d.polygon([(S * .70, S * .30), (S * .86, S * .36), (S * .74, S * .42)], fill=(0, 0, 0, 0))  # the notch
        d.line([(S * .5, S * .78), (S * .48, S * .94)], fill=rgb("#6B4A2B") + (255,), width=3 * SS)  # stalk
    else:
        base = {"A": rgb("#5E8F3A"), "B": rgb("#7C7A3A"), "C": rgb("#8FA83E")}[kind]
        tip = rgb("#7A5A30") if kind == "B" else base
        length, width = (S * .70, S * .22) if kind != "B" else (S * .80, S * .26)
        outline = leaf_outline(kind, cx, cy, length, width)
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).polygon(outline, fill=255)
        # Colour: along the leaf toward the tip colour, the shade half (right of the midrib) 12% darker.
        ys = np.linspace(0, 1, S)[:, None]
        t = np.clip((cy + length / 2 - ys * S) / length, 0, 1)
        col = np.zeros((S, S, 3), dtype=np.float32)
        for c in range(3):
            col[..., c] = base[c] + (tip[c] - base[c]) * t
        xs = np.arange(S)[None, :]
        shade = (xs > cx).astype(np.float32)
        col *= (1 - .12 * shade)[..., None]
        col *= (.94 + .12 * noise((S, S), seed, 6))[..., None]
        a = np.asarray(mask, dtype=np.float32) / 255
        # The 2 px darker rim on the shade side only.
        edge = np.asarray(mask.filter(ImageFilter.MinFilter(2 * SS * 2 + 1)), dtype=np.float32) / 255
        rim = np.clip(a - edge, 0, 1) * shade
        col *= (1 - .25 * rim)[..., None]
        img = Image.fromarray(np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8), "RGBA")
        d = ImageDraw.Draw(img)
        mid = rgb("#C9D08A") if kind == "C" else lerp(base, (230, 225, 170), .25)
        d.line([(cx, cy + length / 2), (cx + (6 * SS if kind == "B" else 0), cy - length / 2 + 6 * SS)], fill=mid + (200,), width=SS * 2)
        d.line([(cx, cy + length / 2), (cx, cy + length / 2 + 10 * SS)], fill=lerp(base, (90, 70, 40), .5) + (255,), width=SS * 3)
    return down(img, (size, size))


def leaf_sheet(cells: list[Image.Image], cols: int, rows: int, cell: int = 96) -> Image.Image:
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for i, leaf in enumerate(cells):
        sheet.paste(leaf, ((i % cols) * cell, (i // cols) * cell), leaf)
    return sheet


def dewdrop_stem() -> Image.Image:
    fruit = Image.open(ROOT / "assets/world/dewdrop.png").convert("RGBA")
    w, h = fruit.size  # 192 x 224
    out = Image.new("RGBA", (w, 262), (0, 0, 0, 0))
    out.paste(fruit, (0, 262 - h), fruit)
    alpha = np.asarray(out.split()[3])
    col = w // 2
    top = next(y for y in range(out.size[1]) if alpha[y, col] > 128)
    big = out.resize((w * SS, 262 * SS), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    stem = rgb("#5A4A2A") + (255,)
    d.line([(col * SS, 0), (col * SS + 2 * SS, (top + 3) * SS)], fill=stem, width=2 * SS)
    return down(big, (w, 262))


def dapple() -> Image.Image:
    S = 256
    n = noise((S, S), 31, 9) * .65 + noise((S, S), 32, 3) * .35
    shade = np.clip((n - .38) / .25, 0, 1)  # soft dark blobs with light gaps
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x - S / 2, y - S / 2) / (S / 2)
    fall = np.clip((1 - r) / .35, 0, 1)
    a = shade * fall * 255
    return Image.fromarray(np.dstack([np.full((S, S, 3), 255), a]).astype(np.uint8), "RGBA")


KOI = {"a": ("#D9833F", "#EFE6D6"), "b": ("#D8C27A", "#EADFB4"), "c": ("#5F6B73", "#8C979D")}


def koi(kind: str) -> Image.Image:
    W, H = 48 * SS, 128 * SS
    main, second = (rgb(v) for v in KOI[kind])
    body = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(body)
    # Head at the top: a long tapered body, two pectoral fins, a forked tail.
    d.ellipse((W * .22, H * .04, W * .78, H * .70), fill=255)
    d.polygon([(W * .32, H * .60), (W * .68, H * .60), (W * .56, H * .86), (W * .44, H * .86)], fill=255)
    d.polygon([(W * .50, H * .82), (W * .18, H * .99), (W * .50, H * .90), (W * .82, H * .99)], fill=255)
    d.polygon([(W * .25, H * .26), (W * .02, H * .36), (W * .27, H * .38)], fill=170)
    d.polygon([(W * .75, H * .26), (W * .98, H * .36), (W * .73, H * .38)], fill=170)
    a = np.asarray(body.filter(ImageFilter.GaussianBlur(SS * .8)), dtype=np.float32) / 255
    patches = noise((H, W), {"a": 41, "b": 42, "c": 43}[kind], 7 * SS)
    mix = np.clip((patches - .45) / .12, 0, 1) if kind == "a" else np.clip((patches - .5) / .3, 0, 1) * .4
    col = np.zeros((H, W, 3), dtype=np.float32)
    for c in range(3):
        col[..., c] = main[c] + (second[c] - main[c]) * mix
    # A soft darker back line (matte, no gloss).
    x = np.arange(W)[None, :]
    col *= (1 - .10 * np.exp(-((x - W / 2) / (W * .08)) ** 2))[..., None]
    img = Image.fromarray(np.dstack([np.clip(col, 0, 255), a * 235]).astype(np.uint8), "RGBA")
    return down(img, (48, 128))


def litter(cells: list[Image.Image]) -> Image.Image:
    S = 256
    rng = random.Random(51)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for i in range(16):
        leaf = cells[i % 4]
        k = rng.uniform(.38, .55)
        small = leaf.resize((int(96 * k), int(96 * k)), Image.LANCZOS).rotate(rng.uniform(0, 360), expand=True, resample=Image.BICUBIC)
        # Fallen leaves are a touch duller.
        small = Image.merge("RGBA", [*(ImageChops.multiply(ch, Image.new("L", small.size, 225)) for ch in small.split()[:3]), small.split()[3]])
        r = rng.uniform(0, S * .38)
        a = rng.uniform(0, math.tau)
        x, y = S / 2 + math.cos(a) * r - small.size[0] / 2, S / 2 + math.sin(a) * r - small.size[1] / 2
        out.alpha_composite(small, (int(x), int(y)))
    return out


def lawn_patch(kind: str) -> Image.Image:
    S = 256
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x - S / 2, y - S / 2) / (S / 2)
    edge = np.clip((1 - r) / .45, 0, 1) * (0.75 + .25 * noise((S, S), 61, 12))
    if kind == "a":
        stripes = .5 + .5 * np.sin((x * .9 + y * .4) / S * math.tau * 3)
        value = .78 + .14 * stripes + .08 * noise((S, S), 62, 1.2)
    else:
        value = .8 + .1 * noise((S, S), 63, 1.2)
        img = Image.new("L", (S * SS, S * SS), 0)
        d = ImageDraw.Draw(img)
        rng = random.Random(64)
        for _ in range(160):
            cx, cy, s = rng.uniform(0, S * SS), rng.uniform(0, S * SS), rng.uniform(2.5, 4.5) * SS
            for k in range(3):
                a = k * math.tau / 3 + rng.uniform(0, 1)
                d.ellipse((cx + math.cos(a) * s - s, cy + math.sin(a) * s - s, cx + math.cos(a) * s + s, cy + math.sin(a) * s + s), fill=255)
        clover = np.asarray(img.resize((S, S), Image.LANCZOS), dtype=np.float32) / 255
        value = value + .12 * clover
    grey = np.clip(value * 255, 0, 255)
    return Image.fromarray(np.dstack([grey, grey, grey, edge * 255]).astype(np.uint8), "RGBA")


def path_fray() -> Image.Image:
    W, H = 256 * SS, 96 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dirt, dirtDark, grass = rgb("#8A6A45"), rgb("#6E5234"), rgb("#4E7F3A")
    rng = random.Random(71)
    # Dirt crumbs in the bottom half, thinning upward.
    for _ in range(900):
        x, t = rng.uniform(0, W), rng.random() ** 1.6
        y = H - t * H * .62
        s = rng.uniform(1.5, 4) * SS
        d.ellipse((x - s, y - s, x + s, y + s), fill=(dirt if rng.random() < .7 else dirtDark) + (255,))
    # Grass tufts from the top half reaching down into the dirt.
    for _ in range(260):
        x, base = rng.uniform(0, W), rng.uniform(H * .05, H * .55)
        for _ in range(3):
            length, lean = rng.uniform(8, 20) * SS, rng.uniform(-4, 4) * SS
            col = lerp(grass, (120, 140, 70), rng.random() * .4)
            d.line([(x, base), (x + lean, base + length)], fill=col + (255,), width=int(1.5 * SS))
    a = np.asarray(img.split()[3], dtype=np.float32) / 255
    xs = np.arange(W)[None, :] / W
    ends = np.clip(np.minimum(xs, 1 - xs) / .18, 0, 1)
    img.putalpha(Image.fromarray((a * ends * 255).astype(np.uint8), "L"))
    return down(img, (256, 96))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cells = [draw_leaf(k, seed=i + 1) for i, k in enumerate("ABCD")]
    files = {
        "leaf-sheet.png": leaf_sheet(cells, 2, 2),
        "leaf-sheet-ac.png": leaf_sheet([cells[0], cells[2]], 2, 1),
        "leaf-sheet-bd.png": leaf_sheet([cells[1], cells[3]], 2, 1),
        "dewdrop-stem.png": dewdrop_stem(),
        "dapple.png": dapple(),
        "koi-a.png": koi("a"),
        "koi-b.png": koi("b"),
        "koi-c.png": koi("c"),
        "litter.png": litter(cells),
        "lawn-patch-a.png": lawn_patch("a"),
        "lawn-patch-b.png": lawn_patch("b"),
        "path-fray.png": path_fray(),
    }
    for name, img in files.items():
        img.save(OUT / name, optimize=False)
    # A contact sheet on lawn green and on sky (not for upload).
    pad = 12
    width = sum(img.size[0] for img in files.values()) + pad * (len(files) + 1)
    sheet = Image.new("RGB", (width, 2 * (262 + pad) + pad), (0, 0, 0))
    x = pad
    for img in files.values():
        for row, ground in enumerate(((74, 120, 60), (170, 190, 215))):
            tile = Image.new("RGBA", img.size, ground + (255,))
            tile.alpha_composite(img)
            sheet.paste(tile.convert("RGB"), (x, pad + row * (262 + pad)))
        x += img.size[0] + pad
    sheet.save(OUT / "preview-r4.png")
    print("wrote", len(files), "textures to", OUT)


if __name__ == "__main__":
    main()
