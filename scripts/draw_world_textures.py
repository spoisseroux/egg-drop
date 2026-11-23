"""Draw the world textures that are ours to draw (Fable, 2026-11-22).

Script-drawn, deterministic, no outside art:
  assets/world/lime-leaf.png  512x512  tileable, opaque, FULL COLOUR lime leaf map for the lime crowns
                                       (WORLD-PASS-2026-11-22.md item 1A, applied as MeshPart.TextureID).

  assets/world/water-strand.png  512x512  falling strands, white on clear, tiles along Y, sides fade to clear
  assets/world/water-ribbon.png  512x512  white froth down both sides plus two broken ribbons, tiles along Y
  assets/world/foam.png          256x256  one foam clump for the impact particles
  assets/world/ripple.png        512x512  one pool ring (a bright ring and a faint inner one)
  assets/world/rainbow-band.png  256x32   pastel bands across X, constant along Y
                                       (artifacts/world-pass-2026-11-22/WATERFALL-LOOK.md). The water maps keep RGB
                                       white under clear pixels so no dark fringe shows; Beam or emitter Color tints.

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


# ---- Waterfall layers (WATERFALL-LOOK.md). The fall runs along image Y, downwards. ----
def _white(alpha: np.ndarray) -> Image.Image:
    a = np.clip(alpha, 0, 1)
    rgba = np.full(a.shape + (4,), 255, np.uint8)
    rgba[..., 3] = np.round(a * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _streaks(n: int, rng: random.Random, specs, side_fade: float) -> np.ndarray:
    """Teardrop streaks: a bright head at the bottom and a tail above it. Wraps along Y only."""
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    out = np.zeros((n, n), np.float32)
    for count, width, length, peak, wobble, lo, hi in specs:
        for _ in range(count):
            cx = rng.uniform(lo, hi) * n
            y0 = rng.uniform(0, n)
            w = width * n * rng.uniform(.75, 1.3)
            ln = length * n * rng.uniform(.7, 1.25)
            amp = wobble * n * rng.uniform(.4, 1)
            k, ph = rng.choice((1, 2, 3)), rng.uniform(0, math.tau)
            t = ((y0 - ys) % n) / ln                      # 0 at the head, 1 at the tail's end
            env = np.where(t < 1, (1 - np.minimum(t, 1)) ** 1.6 * np.clip(t / .04, 0, 1), 0)
            dx = xs - cx - amp * np.sin(ys / n * math.tau * k + ph)
            out = np.maximum(out, peak * rng.uniform(.7, 1) * env * np.exp(-(dx / w) ** 2))
    if not side_fade:
        return out
    u = xs / (n - 1)
    edge = np.clip(np.minimum(u, 1 - u) / side_fade, 0, 1)
    return out * edge * edge * (3 - 2 * edge)


def water_strand() -> Image.Image:
    rng = random.Random(SEED + 41)
    return _white(_streaks(512, rng, (
        # count, width, length, peak alpha, wobble, x range
        (8, .070, 1.60, .55, .012, .10, .90),   # broad soft bodies, longer than the tile: never a gap
        (16, .022, .90, .85, .008, .08, .92),   # strands
        (18, .0075, .50, 1.0, .004, .06, .94),  # bright threads
    ), .12))


def water_ribbon() -> Image.Image:
    n = 512
    rng = random.Random(SEED + 42)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    v = ys / n * math.tau
    out = np.zeros((n, n), np.float32)
    # Froth down each side: a column of round puffs, clear at the very rim, wrapped along Y.
    keep = np.ones((n, n), np.float32)
    for side in (0, 1):
        y = rng.uniform(0, 20)
        while y < n:
            r = rng.uniform(.030, .047) * n
            cx = rng.uniform(.050, .062) * n
            cx = cx if side == 0 else n - 1 - cx
            dy = np.abs(ys - y)
            d = np.hypot(xs - cx, np.minimum(dy, n - dy)) / r
            keep *= 1 - np.clip((1 - d) / .28, 0, 1)
            y += r * rng.uniform(.9, 1.5)
    out = 1 - keep
    # Froth beads thrown off the side bands, and two broken ribbons wandering down the face.
    out = np.maximum(out, _streaks(n, rng, ((16, .012, .22, .95, .006, .10, .20), (16, .012, .22, .95, .006, .80, .90)), 0))
    for cx, k in ((.36, 1), (.67, 2)):
        ph = rng.uniform(0, math.tau)
        centre = (cx + .045 * np.sin(v * k + ph) + .015 * np.sin(v * (k + 3) + ph * 2)) * n
        gap = np.clip(.5 + .9 * np.sin(v * (k + 1) + ph * 3), 0, 1)        # breaks along the run
        width = n * (.014 + .007 * np.sin(v * 4 + ph))
        out = np.maximum(out, .92 * gap * np.exp(-((xs - centre) / width) ** 2))
    return _white(out)


def foam() -> Image.Image:
    n = 256
    rng = random.Random(SEED + 43)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    keep = np.ones((n, n), np.float32)
    blobs = [(0.0, 0.0, .27)]
    for i in range(9):
        ang = i / 9 * math.tau + rng.uniform(-.25, .25)
        blobs.append((math.cos(ang) * rng.uniform(.19, .25), math.sin(ang) * rng.uniform(.19, .25), rng.uniform(.11, .17)))
    for bx, by, r in blobs:
        d = np.hypot(xs - (.5 + bx) * n, ys - (.5 + by) * n) / (r * n)
        keep *= 1 - np.clip((1 - d) / .22, 0, 1)
    a = 1 - keep
    for _ in range(5):                                                       # a few bubble holes
        ang, rad, r = rng.uniform(0, math.tau), rng.uniform(.05, .22), rng.uniform(.022, .04)
        d = np.hypot(xs - (.5 + math.cos(ang) * rad) * n, ys - (.5 + math.sin(ang) * rad) * n) / (r * n)
        a *= 1 - .55 * np.clip((1 - d) / .3, 0, 1)
    return _white(a)


def ripple() -> Image.Image:
    n = 512
    rng = random.Random(SEED + 44)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - (n - 1) / 2, ys - (n - 1) / 2) / (n / 2)
    th = np.arctan2(ys - (n - 1) / 2, xs - (n - 1) / 2)
    p1, p2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    outer = np.exp(-((r - .86) / .042) ** 2) * (.72 + .28 * np.cos(th * 3 + p1))
    inner = .5 * np.exp(-((r - .60) / .026) ** 2) * np.clip(.45 + .8 * np.cos(th * 2 + p2), 0, 1)
    return _white(np.maximum(outer, inner))


RAINBOW = ((0xFF, 0x9F, 0xC0), (0xFF, 0xC9, 0x8A), (0xFF, 0xF0, 0x9A), (0xC4, 0xF0, 0x60), (0x7F, 0xE0, 0xFF),
           (0x8F, 0xB4, 0xFF), (0xC6, 0xA8, 0xFF))


def rainbow_band() -> Image.Image:
    w, h = 256, 32
    u = np.linspace(0, 1, w, dtype=np.float32)
    stops = np.asarray(RAINBOW, np.float32)
    pos = np.clip((u - .1) / .8, 0, 1) * (len(stops) - 1)
    i = np.minimum(pos.astype(int), len(stops) - 2)
    f = (pos - i)[:, None]
    rgb = stops[i] * (1 - f) + stops[i + 1] * f
    alpha = np.clip(np.sin(np.clip((u - .04) / .92, 0, 1) * math.pi), 0, 1) ** .8 * 255
    row = np.concatenate([rgb, alpha[:, None]], axis=1)
    return Image.fromarray(np.round(np.repeat(row[None], h, axis=0)).astype(np.uint8), "RGBA")


WATER = {"water-strand": water_strand, "water-ribbon": water_ribbon, "foam": foam, "ripple": ripple,
         "rainbow-band": rainbow_band}


def _tint(img: Image.Image, colour, opacity: float) -> Image.Image:
    flat = Image.new("RGBA", img.size, tuple(colour) + (255,))
    flat.putalpha(img.getchannel("A").point(lambda x: int(x * opacity)))
    return flat


def _tall(img: Image.Image, width: int, height: int, tile: int, shift: int = 0) -> Image.Image:
    scaled = img.resize((width, tile), Image.LANCZOS)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y in range(shift % tile - tile, height, tile):
        out.paste(scaled, (0, y))
    return out


def water_preview(directory: Path, maps: dict[str, Image.Image]) -> None:
    """The layers as they stack on the lower fall, at 1:1, a third and a sixth; and each sprite at small sizes."""
    directory.mkdir(parents=True, exist_ok=True)
    W, H = 300, 460                                    # 13 studs wide, 20 tall, 23 px a stud
    fall = Image.new("RGBA", (W + 120, H + 150), (0x8B, 0x9A, 0x9C, 255))
    ImageDraw.Draw(fall).rectangle((0, H + 40, W + 120, H + 150), fill=(0x7F, 0xE0, 0xFF, 255))
    ImageDraw.Draw(fall).rectangle((60 + 12, 30, 60 + W - 12, H + 40), fill=(0x16, 0x89, 0xD6, 255))
    for name, colour, opacity, width, tile, shift, dx in (
            ("water-strand", (0x3C, 0xC8, 0xF0), .65, W, 460, 0, 0),
            ("water-strand", (0xDD, 0xF6, 0xFF), .55, int(W * .7), 300, 130, 14),
            ("water-ribbon", (255, 255, 255), .8, W + 14, 368, 60, 0)):
        layer = _tint(_tall(maps[name], width, H + 10, tile, shift), colour, opacity)
        fall.alpha_composite(layer, (60 + (W - width) // 2 + dx, 30))
    ImageDraw.Draw(fall).rounded_rectangle((60, 18, 60 + W, 42), 12, fill=(255, 255, 255, 255))     # lip roll
    for size, opacity in ((230, .4), (150, .6), (90, .75)):
        flat = _tint(maps["ripple"].resize((size, int(size * .32)), Image.LANCZOS), (255, 255, 255), opacity)
        fall.alpha_composite(flat, (60 + W // 2 - size // 2, H + 78 - int(size * .16)))
    rng = random.Random(7)
    for _ in range(16):
        s = rng.randint(26, 46)
        puff = _tint(maps["foam"].resize((s, s), Image.LANCZOS).rotate(rng.uniform(0, 360)), (255, 255, 255), rng.uniform(.6, .9))
        fall.alpha_composite(puff, (60 + rng.randint(0, W - s), H + 40 - s // 2 - rng.randint(0, 26)))
    bow = maps["rainbow-band"].resize((30, 4), Image.LANCZOS)
    arc = Image.new("RGBA", fall.size, (0, 0, 0, 0))
    span, rise = W + 60, 140
    for step in range(400):
        t = step / 399
        slope = math.degrees(math.atan2(-math.cos(t * math.pi) * rise * math.pi, span))
        piece = bow.rotate(90 - slope, expand=True)
        fade = .22 * math.sin(t * math.pi)
        piece.putalpha(piece.getchannel("A").point(lambda v, k=fade: int(v * k)))
        arc.alpha_composite(piece, (int(30 + t * span - piece.width / 2), int(H + 10 - math.sin(t * math.pi) * rise - piece.height / 2)))
    fall.alpha_composite(arc)
    sheet = Image.new("RGB", (fall.width + fall.width // 3 + fall.width // 6 + 40, fall.height + 20), (0x2F, 0x9B, 0xEF))
    x = 10
    for div in (1, 3, 6):
        small = fall.convert("RGB").resize((fall.width // div, fall.height // div), Image.LANCZOS)
        sheet.paste(small, (x, 10))
        x += small.width + 10
    sheet.save(directory / "waterfall-stack.png")
    sprites = Image.new("RGBA", (760, 300), (0x16, 0x89, 0xD6, 255))
    ImageDraw.Draw(sprites).rectangle((380, 0, 760, 300), fill=(0x7F, 0xE0, 0xFF, 255))
    for half in (0, 380):
        for name, sizes, y in (("foam", (96, 40, 20), 8), ("ripple", (128, 64, 32), 140)):
            x = half + 8
            for s in sizes:
                sprites.alpha_composite(maps[name].resize((s, s), Image.LANCZOS), (x, y))
                x += s + 8
        sprites.alpha_composite(maps["water-strand"].resize((96, 96), Image.LANCZOS), (half + 270, 8))
        sprites.alpha_composite(maps["water-ribbon"].resize((96, 96), Image.LANCZOS), (half + 270, 110))
        sprites.alpha_composite(maps["rainbow-band"].resize((96, 24), Image.LANCZOS), (half + 270, 240))
    sprites.convert("RGB").save(directory / "waterfall-sprites.png")
    lines = []
    for name in ("water-strand", "water-ribbon"):
        a = np.asarray(maps[name].getchannel("A"), np.float32)
        lines.append("%s: alpha mean %.1f, step inside %.2f, across the Y wrap %.2f, at the X rim max %.0f" % (
            name, a.mean(), np.abs(a[1:] - a[:-1]).mean(), np.abs(a[0] - a[-1]).mean(), max(a[:, 0].max(), a[:, -1].max())))
    for name in ("foam", "ripple"):
        a = np.asarray(maps[name].getchannel("A"))
        lines.append("%s: alpha max on the border %d (must be 0)" % (name, max(a[0].max(), a[-1].max(), a[:, 0].max(), a[:, -1].max())))
    (directory / "waterfall-report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img = lime_leaf()
    img.save(OUT / "lime-leaf.png", optimize=True)
    print("wrote", OUT / "lime-leaf.png", img.size)
    print(seam_report(img))
    maps = {name: draw() for name, draw in WATER.items()}
    for name, water in maps.items():
        water.save(OUT / (name + ".png"), optimize=True)
        print("wrote", OUT / (name + ".png"), water.size)
    if "--preview" in sys.argv:
        directory = Path(sys.argv[sys.argv.index("--preview") + 1])
        preview(directory, img)
        water_preview(directory, maps)


if __name__ == "__main__":
    main()
