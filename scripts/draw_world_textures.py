"""Draw the world textures that are ours to draw (Fable, 2026-11-22).

Script-drawn, deterministic, no outside art:
  assets/world/lime-leaf.png  512x512  tileable, opaque, FULL COLOUR lime leaf map for the lime crowns
                                       (WORLD-PASS-2026-11-22.md item 1A, applied as MeshPart.TextureID).

Why full colour and not a grey map tinted by Color: an opaque TextureID replaces the part Color, and anything
that multiplies (SurfaceAppearance.Color, a tint) can only darken, which is how lime went olive before. So the
lime is in the pixels, the mean of the map IS the crown colour (#8FD63F), and the part Color is set to white so
the result is the same whether the engine composites or multiplies.

Run:  python scripts/draw_world_textures.py [--preview DIR]
--preview writes a 2x2 tile sheet, small-size swatches beside flat lime and dark foliage, and a seam report.
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world"
SIZE = 512
SS = 2  # supersample factor
SEED = 20261122

BASE = (0x8F, 0xD6, 0x3F)   # crown lime, WorldAero.Crowns.lime
SHADE = (0x6F, 0xBF, 0x2E)  # clump shade (scope 1A)
LIGHT = (0xB4, 0xEC, 0x58)  # lit clump top
FLECK = (0xC4, 0xF0, 0x60)  # sun flecks
GLOSS = (0xE8, 0xFF, 0xB0)  # gloss dots


def _wrap_blur(a: np.ndarray, radius: float) -> np.ndarray:
    """Gaussian blur that wraps at the edges, so the result still tiles."""
    n = a.shape[0]
    f = np.fft.fftfreq(n).astype(np.float32)
    g = np.exp(-2 * (math.pi * radius) ** 2 * f * f)
    return np.fft.ifft2(np.fft.fft2(a) * g[:, None] * g[None, :]).real.astype(np.float32)


def _clump_field(n: int, rng: random.Random) -> tuple[np.ndarray, list[tuple[float, float, float]]]:
    """Puffy clump height field on a torus: the max of soft domes, dart-thrown so no grid shows."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    height = np.zeros((n, n), np.float32)
    clumps: list[tuple[float, float, float]] = []
    tries = 0
    while len(clumps) < 19 and tries < 4000:
        tries += 1
        cx, cy = rng.uniform(0, n), rng.uniform(0, n)
        r = n * rng.uniform(.105, .185)

        def far(c):
            dx = abs(cx - c[0]); dx = min(dx, n - dx)
            dy = abs(cy - c[1]); dy = min(dy, n - dy)
            return math.hypot(dx, dy) > (r + c[2]) * .62
        if all(far(c) for c in clumps):
            clumps.append((cx, cy, r))
    for cx, cy, r in clumps:
        dx = np.abs(xx - cx); dx = np.minimum(dx, n - dx)
        dy = np.abs(yy - cy); dy = np.minimum(dy, n - dy)
        # A slightly squashed dome, each with its own top height, so clumps overlap like puffs.
        dome = np.clip(1 - (dx * dx + dy * dy * 1.15) / (r * r), 0, 1) ** .65 * (.75 + .25 * (r / (n * .185)))
        height = np.maximum(height, dome)
    return height, clumps


def _leaf(draw: ImageDraw.ImageDraw, n: int, x: float, y: float, length: float, angle: float, fill) -> None:
    """One pointed leaf, drawn at every wrap offset it touches."""
    half = length * .5
    wide = length * .30
    ca, sa = math.cos(angle), math.sin(angle)
    shape = [(-half, 0), (-half * .2, -wide), (half, 0), (-half * .2, wide)]
    for ox in (-n, 0, n):
        if not (-length < x + ox < n + length):
            continue
        for oy in (-n, 0, n):
            if not (-length < y + oy < n + length):
                continue
            pts = [(x + ox + px * ca - py * sa, y + oy + px * sa + py * ca) for px, py in shape]
            draw.polygon(pts, fill=fill)


def _dot(draw: ImageDraw.ImageDraw, n: int, x: float, y: float, r: float, fill) -> None:
    for ox in (-n, 0, n):
        for oy in (-n, 0, n):
            if -r < x + ox < n + r and -r < y + oy < n + r:
                draw.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=fill)


def lime_leaf() -> Image.Image:
    rng = random.Random(SEED)
    n = SIZE * SS
    height, clumps = _clump_field(n, rng)
    height = _wrap_blur(height, 5 * SS)

    # Light from the upper left: slope shading plus a little darkening in the gaps between clumps.
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    slope = _wrap_blur(-(gx * .62 + gy * .78) * (n / 10.0), 3 * SS)
    gap = np.clip(.42 - height, 0, 1) / .42
    tone = np.clip(slope * .85 + (height - .55) * .35 - gap * .55, -1, 1)
    tone = tone - float(tone.mean())  # the mean of the map stays the base lime

    base, shade, light = (np.array(c, np.float32) for c in (BASE, SHADE, LIGHT))
    up = np.clip(tone, 0, 1)[..., None]
    down = np.clip(-tone, 0, 1)[..., None]
    rgb = base + (light - base) * up * .85 + (shade - base) * down * .75
    img = Image.fromarray(np.clip(rgb + .5, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # Leaves: shade leaves where the clump turns away, sun flecks where it faces the light. Each kind is one
    # union mask (overlaps merge, no outlines), faded by how lit the spot is. Low alpha: soft.
    lit_mask = Image.new("L", (n, n), 0)
    dark_mask = Image.new("L", (n, n), 0)
    lit_draw, dark_draw = ImageDraw.Draw(lit_mask), ImageDraw.Draw(dark_mask)
    for _ in range(620):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        iy, ix = int(y) % n, int(x) % n
        t = float(tone[iy, ix])
        length = rng.uniform(15, 27) * SS
        # Leaves fan out and down from the clump tops, with a loose spread.
        angle = math.atan2(float(gy[iy, ix]), float(gx[iy, ix])) + math.pi + rng.uniform(-.8, .8)
        if t > 0 or rng.random() < .3:
            _leaf(lit_draw, n, x, y, length, angle, 255)
        else:
            _leaf(dark_draw, n, x, y, length, angle, 255)
    soft = ImageFilter.GaussianBlur(.9 * SS)
    lit_a = np.asarray(lit_mask.filter(soft), np.float32) / 255 * (.22 + .40 * np.clip(tone * 2, 0, 1))
    dark_a = np.asarray(dark_mask.filter(soft), np.float32) / 255 * (.18 + .30 * np.clip(-tone * 2, 0, 1))
    rgb = np.asarray(img.convert("RGB"), np.float32)
    rgb = rgb + (np.array(FLECK, np.float32) - rgb) * lit_a[..., None]
    rgb = rgb + (np.array(SHADE, np.float32) - rgb) * dark_a[..., None]
    rgb += (np.array(BASE, np.float32) - rgb.reshape(-1, 3).mean(axis=0))  # hold the mean on the crown lime
    img = Image.fromarray(np.clip(rgb + .5, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # A few gloss dots on the lit shoulder of some clumps: the Aero wet-leaf glint.
    gloss = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(gloss)
    for cx, cy, r in clumps:
        if rng.random() < .7:
            for _ in range(rng.randint(1, 3)):
                x = cx - r * rng.uniform(.25, .5) + rng.uniform(-8, 8) * SS
                y = cy - r * rng.uniform(.25, .5) + rng.uniform(-8, 8) * SS
                _dot(gdraw, n, x % n, y % n, rng.uniform(1.6, 3.0) * SS, GLOSS + (rng.randint(140, 200),))
    img.alpha_composite(gloss.filter(ImageFilter.GaussianBlur(.7 * SS)))

    return img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)


def seam_report(img: Image.Image) -> str:
    a = np.asarray(img, np.float32)
    inner = float(np.abs(a[:, 1:] - a[:, :-1]).mean() + np.abs(a[1:] - a[:-1]).mean()) / 2
    edge = float(np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2
    mean = a.reshape(-1, 3).mean(axis=0)
    lum = a @ np.array([.2126, .7152, .0722], np.float32)
    return ("mean #%02X%02X%02X (target #8FD63F)  luma min %.0f p5 %.0f p95 %.0f max %.0f\n"
            "neighbour step inside %.2f, across the wrap %.2f (equal = no seam)"
            % (*[int(round(v)) for v in mean], lum.min(), np.percentile(lum, 5), np.percentile(lum, 95), lum.max(),
               inner, edge))


def preview(directory: Path, img: Image.Image) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    tiled = Image.new("RGB", (SIZE * 2, SIZE * 2))
    for ox in (0, SIZE):
        for oy in (0, SIZE):
            tiled.paste(img, (ox, oy))
    tiled.save(directory / "lime-leaf-2x2.png")
    # Offset by half: the wrap seam lands in the middle of the picture, where a seam would show.
    np_img = np.roll(np.asarray(img), (SIZE // 2, SIZE // 2), axis=(0, 1))
    Image.fromarray(np_img).save(directory / "lime-leaf-seam-centred.png")
    # Small sizes: 3x3 tiles at 192, 96 and 48 px, beside flat lime, on sky and dark foliage.
    sheet = Image.new("RGB", (780, 250), (0x2F, 0x9B, 0xEF))
    ImageDraw.Draw(sheet).rectangle((390, 0, 780, 250), fill=(0x1F, 0x6B, 0x2E))
    big = Image.new("RGB", (SIZE * 3, SIZE * 3))
    for ox in range(3):
        for oy in range(3):
            big.paste(img, (ox * SIZE, oy * SIZE))
    for half in (0, 390):
        x = half + 12
        for s in (192, 96, 48):
            mask = Image.new("L", (s * 4, s * 4), 0)
            ImageDraw.Draw(mask).ellipse((0, 0, s * 4 - 1, s * 4 - 1), fill=255)
            mask = mask.resize((s, s), Image.LANCZOS)
            sheet.paste(big.resize((s, s), Image.LANCZOS), (x, 20), mask)
            x += s + 10
        flat = Image.new("L", (192, 192), 0)
        ImageDraw.Draw(flat).ellipse((0, 0, 191, 191), fill=255)
        small = flat.resize((36, 36), Image.LANCZOS)
        sheet.paste(Image.new("RGB", (36, 36), BASE), (half + 290, 150), small)
    sheet.save(directory / "lime-leaf-sizes.png")
    (directory / "lime-leaf-report.txt").write_text(seam_report(img) + "\n", encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img = lime_leaf()
    img.save(OUT / "lime-leaf.png", optimize=True)
    print("wrote", OUT / "lime-leaf.png", img.size)
    print(seam_report(img))
    if "--preview" in sys.argv:
        preview(Path(sys.argv[sys.argv.index("--preview") + 1]), img)


if __name__ == "__main__":
    main()
