"""Compose the owner-facing egg and Star previews from the raw EEVEE frames.

Run with system Python (numpy + Pillow), after scripts/render_egg_previews.py:
  python scripts/compose_egg_previews.py

It adds only what the game will draw in 2D over the ViewportFrame (see assets/eggs/EGG-PREVIEW-FX.md):
the dark well, the coloured bloom, the crack-light glow, the glint and the sparkles.
Writes artifacts/eggs-2026-11-13/: egg-<type>-hero.png, eggs-sheet.png, eggs-120px.png, star-sheet.png.
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import egg_types as E  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
ART = REPO / "artifacts" / "eggs-2026-11-13"
RAW = ART / "raw"
S = 720


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def font(size, bold=True):
    for name in (("arialbd.ttf", "segoeuib.ttf") if bold else ("arial.ttf", "segoeui.ttf")):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def well(size=S):
    y, x = np.mgrid[0:size, 0:size] / size
    d = np.hypot(x - 0.5, y - 0.45)
    a, b = np.array(rgb("#173A38")), np.array(rgb("#081416"))
    img = a + (b - a) * np.clip(d * 1.5, 0, 1)[..., None]
    return img.astype(np.float64)


def radial(size, cx, cy, radius, power=2.0):
    y, x = np.mgrid[0:size, 0:size]
    return np.clip(1 - np.hypot(x - cx, y - cy) / radius, 0, 1) ** power


def add(img, mask, color, strength):
    return img + mask[..., None] * np.array(color) * strength


def star_sprite(img, cx, cy, r, color, strength=1.0):
    y0, y1, x0, x1 = int(cy - r - 2), int(cy + r + 3), int(cx - r - 2), int(cx + r + 3)
    y0, x0, y1, x1 = max(y0, 0), max(x0, 0), min(y1, img.shape[0]), min(x1, img.shape[1])
    if y1 <= y0 or x1 <= x0:
        return
    y, x = np.mgrid[y0:y1, x0:x1]
    a, b = np.abs(x - cx) / r, np.abs(y - cy) / r
    f = np.clip(1.15 - (a ** 0.5 + b ** 0.5), 0, 1) * 4
    f = np.clip(f, 0, 1) + 0.35 * np.clip(1 - np.hypot(a, b) * 1.4, 0, 1)
    img[y0:y1, x0:x1] += f[..., None] * np.array(color) * strength


def load(name):
    return np.asarray(Image.open(RAW / name).convert("RGBA")).astype(np.float64)


def over(img, rgba):
    a = rgba[..., 3:4] / 255
    return img * (1 - a) + rgba[..., :3] * a


def blur(arr, radius):
    out = np.zeros_like(arr)
    for c in range(arr.shape[2]):
        im = Image.fromarray(np.clip(arr[..., c], 0, 255).astype(np.uint8), "L")
        out[..., c] = np.asarray(im.filter(ImageFilter.GaussianBlur(radius)))
    return out


def card(tid, shot, seed=0):
    t = E.TYPES[tid]
    img = well()
    frame = load(f"{tid}-{shot}.png")
    closed = load(f"{tid}-closed.png")
    alpha = frame[..., 3] / 255
    ys, xs = np.nonzero(closed[..., 3] > 128)
    cx, cy, half = xs.mean(), ys.mean(), (xs.max() - xs.min()) / 2
    strong = shot != "closed"
    y, x = np.mgrid[0:S, 0:S]
    img = add(img, radial(S, cx, cy, half * (3.0 if strong else 2.6), 1.6), rgb(t["bloom"]), 0.55 if strong else 0.36)
    # contact shadow under the egg
    sh = np.clip(1 - np.hypot((x - cx) / (half * 1.05), (y - ys.max()) / (half * 0.16)), 0, 1)
    img = img * (1 - 0.6 * sh[..., None])
    img = over(img, frame)
    if strong:
        # light escaping the crack: bloom of whatever got brighter than the closed egg
        diff = np.clip(frame[..., :3] * alpha[..., None] - closed[..., :3] * (closed[..., 3:4] / 255), 0, 255)
        core = np.array(rgb(t["core"])) / 255
        lum = diff.max(axis=2, keepdims=True) * (0.6 + 0.4 * core)
        if shot == "open":
            lum = lum * 0.22
        img = img + blur(lum, 5) * 0.9 + blur(lum, 22) * 1.4
    else:
        # glint: one soft highlight on the upper left of the shell (a static 2D overlay in game)
        gx, gy = cx - half * 0.42, ys.min() + (ys.max() - ys.min()) * 0.26
        ang = math.radians(-32)
        xr = (x - gx) * math.cos(ang) - (y - gy) * math.sin(ang)
        yr = (x - gx) * math.sin(ang) + (y - gy) * math.cos(ang)
        g = np.clip(1 - np.hypot(xr / (half * 0.10), yr / (half * 0.26)), 0, 1) ** 0.8
        img = img + g[..., None] * 150 * alpha[..., None]
    # sparkles
    rnd = random.Random(sum(map(ord, tid)) + seed)
    n = 16 if strong else 9
    for i in range(n):
        ang = rnd.uniform(0, 2 * math.pi)
        dist = half * rnd.uniform(1.15, 2.4 if strong else 2.0)
        px, py = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist * 1.1
        star_sprite(img, px, py, rnd.uniform(9, 30 if strong else 24),
                    rgb(t["particles"][i % len(t["particles"])]), rnd.uniform(0.6, 1.0))
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def label(im, text, sub=None):
    d = ImageDraw.Draw(im)
    d.text((24, 20), text, font=font(34), fill=(255, 255, 255))
    if sub:
        d.text((24, 62), sub, font=font(19, False), fill=(190, 215, 210))
    return im


def build_eggs():
    rows = [("closed", "idle"), ("peek", "crack-light flash"), ("open", "Hatch: top shell pops")]
    cell = 480
    sheet = Image.new("RGB", (cell * len(E.ORDER), cell * len(rows)), (8, 20, 22))
    for ci, tid in enumerate(E.ORDER):
        for ri, (shot, cap) in enumerate(rows):
            c = card(tid, shot, seed=ri)
            if shot == "closed":
                label(c.copy(), E.TYPES[tid]["name"]).save(ART / f"egg-{tid}-hero.png")
            c = label(c, E.TYPES[tid]["name"] if ri == 0 else "", None)
            ImageDraw.Draw(c).text((24, S - 44), cap, font=font(22, False), fill=(190, 215, 210))
            sheet.paste(c.resize((cell, cell), Image.LANCZOS), (ci * cell, ri * cell))
    sheet.save(ART / "eggs-sheet.png")
    # readability at the size the phone well shows it
    strip = Image.new("RGB", (len(E.ORDER) * 150 + 30, 190), rgb("#12302E"))
    for ci, tid in enumerate(E.ORDER):
        strip.paste(card(tid, "closed").resize((120, 120), Image.LANCZOS), (30 + ci * 150, 20))
        ImageDraw.Draw(strip).text((30 + ci * 150, 150), tid, font=font(16, False), fill=(220, 235, 230))
    strip.save(ART / "eggs-120px.png")
    print("wrote eggs-sheet.png, eggs-120px.png, heroes")


def build_star():
    def star_card(name, missed=False, rays=True):
        img = well()
        frame = load(name)
        cx = cy = S / 2
        if rays:
            y, x = np.mgrid[0:S, 0:S]
            ang = np.arctan2(y - cy, x - cx)
            ray = (np.sin(ang * 12) > 0.15) * radial(S, cx, cy, S * 0.62, 1.2)
            img = add(img, radial(S, cx, cy, S * 0.55, 1.5), rgb("#FFD069"), 0.45)
            img = add(img, ray, rgb("#FFE9A0"), 0.20)
        if missed:
            pale = frame.copy()
            lum = pale[..., :3].mean(axis=2, keepdims=True)
            pale[..., :3] = 0.25 * lum + np.array(rgb("#DDE7EE")) * 0.75
            pale[..., 3] *= 0.4
            frame = pale
        img = over(img, frame)
        if not missed:
            rnd = random.Random(4)
            for i in range(12):
                a, dist = rnd.uniform(0, 6.28), rnd.uniform(230, 330)
                star_sprite(img, cx + math.cos(a) * dist, cy + math.sin(a) * dist, rnd.uniform(10, 26),
                            rgb(("#FFFFFF", "#FFE9A0", "#FFD069")[i % 3]), 0.9)
        return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")

    cards = [label(star_card("star-front.png"), "Star token", "front, win"),
             label(star_card("star-turn.png"), "", "mid spin"),
             label(star_card("star-front.png", missed=True, rays=False), "", "missed round: pale glass")]
    sheet = Image.new("RGB", (480 * 3, 480))
    for i, c in enumerate(cards):
        sheet.paste(c.resize((480, 480), Image.LANCZOS), (i * 480, 0))
    sheet.save(ART / "star-sheet.png")
    print("wrote star-sheet.png")


if __name__ == "__main__":
    build_eggs()
    build_star()
