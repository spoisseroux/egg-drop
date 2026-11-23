"""Draw the Sleepy Nest textures (Fable, 2026-11-23; artifacts/onboarding-2026-11-23/NEST-LOOK.md).

Script-drawn, deterministic, no outside art. Needs numpy + Pillow (as scripts/build_egg_textures.py).
  assets/onboarding/sleepy-egg-color.png  1024      ColorMap for the existing egg mesh (EggModels.Egg): pale lilac
                                                    shell, cream belly band, closed-eye face at the front (u = 0.5),
                                                    a moon and stars on the top shell. Same UV layout as the six eggs.
  assets/onboarding/nest-weave.png        128x64    tileable strand lines (dark + light, alpha) over the part colour
  assets/onboarding/nest-flag.png         96x160    stick + cream pennant with a lilac moon (decal plate, side faces)
  assets/onboarding/nest-leaves.png       160x96    three lime leaves fanned from the bottom centre (decal plate)
  assets/onboarding/sleepy-halo.png       256       soft white radial glow (BillboardGui image, tinted)
  assets/onboarding/sleepy-z.png          64        a bold white Z with a violet edge (particle)
  assets/onboarding/nest-chip.png         128       HUD / strip icon: the sleeping egg in its nest, full colour

Run:  python scripts/draw_onboarding_textures.py [--preview DIR]
--preview also writes contact sheets (the egg from the front in a mock nest on grass at small sizes, the chip icon
on HUD ink and on cream at 16 to 48 px).
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import egg_types as E  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "onboarding"

LILAC, LILAC_DEEP, LILAC_LIGHT = "#C9B4FF", "#8A6EE0", "#F1E9FF"
CREAM, CREAM_DEEP = "#FFF4DA", "#EBD3A4"
INK = "#2A2356"
BLUSH = "#FF8FBE"
MOON = "#FFF0A8"
TWIG, TWIG_DARK, TWIG_INK = "#B07A45", "#8A5A30", "#3E2613"
LEAF, LEAF_DARK, LEAF_INK = "#B4E640", "#7FC42B", "#2C6A1E"
GRASS = "#2F9E3A"


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgbf(h: str) -> np.ndarray:
    return np.array(hexrgb(h)) / 255.0


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(img, color, mask):
    return img * (1 - mask[..., None]) + color * mask[..., None]


# ---------------------------------------------------------------- the egg's ColorMap
def egg_color(size: int = 1024, ss: int = 2) -> Image.Image:
    w = h = size * ss
    xs = (np.arange(w) + 0.5) / w
    ys = 1.0 - (np.arange(h) + 0.5) / h
    U, V = np.meshgrid(xs, ys)
    T = np.clip((V - E.UV_OUTER_V0) / (1 - E.UV_OUTER_V0), 0, 1)
    PH = np.pi * T
    RAD = (E.WIDTH / 2) * np.sin(PH) * (1 + E._K * np.cos(PH)) / E._RMAX
    Z = (E.HEIGHT / 2) * (1 - np.cos(PH))
    ANG = 2 * np.pi * (U - E.FRONT_U)
    A = RAD * ANG  # arc length round the egg from the front, in studs
    aa = 0.005

    lilac, deep, light = rgbf(LILAC), rgbf(LILAC_DEEP), rgbf(LILAC_LIGHT)
    cream, ink = rgbf(CREAM), rgbf(INK)
    img = np.broadcast_to(lilac, (h, w, 3)).copy()

    # Cream belly band under the seam (the seam's lowest tooth is at z 0.617), with a deeper line on each edge.
    lo, hi = 0.27, 0.592
    band = smooth(lo - aa, lo + aa, Z) * (1 - smooth(hi - aa, hi + aa, Z))
    img = mix(img, cream, band)
    for edge in (lo, hi):
        img = mix(img, deep, (1 - smooth(0.011, 0.011 + 2 * aa, np.abs(Z - edge))) * 0.85)

    # Lilac beads round the back and sides of the band (none behind the face).
    for k in range(12):
        a0 = 2 * math.pi * (k / 12 - 0.5)
        if abs(a0) < 1.0:
            continue
        r0 = E.profile(0.42)[0]
        da = (ANG - a0 + np.pi) % (2 * np.pi) - np.pi
        d = np.hypot(da * r0, Z - 0.44)
        img = mix(img, lilac * 0.96, 1 - smooth(0.036, 0.036 + aa, d))

    # Moon and stars: cream-yellow on the lilac. One crescent on the top shell, front; four-point stars round it.
    moon = rgbf(MOON)
    mz, ma, mr = 0.93, 0.0, 0.115
    d1 = np.hypot(A - ma, Z - mz)
    d2 = np.hypot(A - (ma + 0.062), Z - (mz + 0.03))
    crescent = (1 - smooth(mr - aa, mr + aa, d1)) * smooth(mr * 0.86 - aa, mr * 0.86 + aa, d2)
    img = mix(img, moon, crescent)
    rng = random.Random(20261123)
    placed = []
    for _ in range(400):
        if len(placed) >= 13:
            break
        u, t = rng.random(), rng.choice([rng.uniform(0.63, 0.9), rng.uniform(0.07, 0.2)])
        r, z = E.profile(t)
        a0 = 2 * math.pi * (u - 0.5)
        x, y = r * math.sin(a0), -r * math.cos(a0)
        if z > 0.74 and abs(a0) * r < 0.2 and abs(z - mz) < 0.2:
            continue  # clear of the moon
        if any(math.dist((x, y, z), q) < 0.2 for q in placed):
            continue
        placed.append((x, y, z))
        rad = rng.choice([0.05, 0.06, 0.07])
        da = ((ANG - a0 + np.pi) % (2 * np.pi) - np.pi) * r
        dz = Z - z
        p = 0.6
        star = (np.abs(da) ** p + np.abs(dz) ** p) ** (1 / p)
        img = mix(img, moon, (1 - smooth(rad - aa, rad + aa, star)) * 0.95)

    # The sleeping face, on the band: two closed eyes (the lower half of a ring), a tiny mouth, blush.
    blush = rgbf(BLUSH)
    for side in (-1, 1):
        b = np.hypot((A - side * 0.275) / 0.07, (Z - 0.405) / 0.045)
        img = mix(img, blush, (1 - smooth(0.75, 1.0, b)) * 0.62)
    eye_r, eye_w, eye_z, eye_x = 0.088, 0.027, 0.5, 0.165
    for side in (-1, 1):
        d = np.hypot(A - side * eye_x, Z - eye_z)
        ring = 1 - smooth(eye_w - aa, eye_w + aa, np.abs(d - eye_r))
        lower = 1 - smooth(eye_z - 0.012, eye_z + 0.004, Z)
        img = mix(img, ink, ring * lower)
        for end in (-1, 1):  # round caps
            cap = np.hypot(A - (side * eye_x + end * eye_r), Z - (eye_z - 0.004))
            img = mix(img, ink, 1 - smooth(eye_w - aa, eye_w + aa, cap))
    mouth = np.hypot((A - 0.0) / 0.034, (Z - 0.385) / 0.03)
    img = mix(img, ink, 1 - smooth(0.85, 1.0, mouth))

    # Shared finish (as build_egg_textures.finish): top light, bottom shade, crack line, the inside strip.
    img = mix(img, np.ones(3), smooth(0.55, 1.0, T) * 0.16)
    shade = smooth(0.42, 0.0, T)
    img = img * (1 - 0.14 * shade[..., None])
    img = mix(img, deep, shade * 0.16)
    ph = (U * E.TEETH) % 1.0
    seam = E.SEAM_T - E.SEAM_AMP_T * (1 - 2 * np.abs(ph * 2 - 1))
    d = (T - seam) * (math.pi * E.HEIGHT / 2) * np.sin(PH)
    dark = img * 0.42 + deep * 0.12
    img = mix(img, light, (1 - smooth(0.004, 0.012, np.abs(d - 0.022))) * 0.6)
    img = mix(img, dark, (1 - smooth(0.008, 0.014, np.abs(d))) * 0.9)
    inner = rgbf("#FFF7EA")
    strip = np.broadcast_to(inner, (h, w, 3)).copy()
    f = np.clip((V - E.UV_INNER_V[0]) / (E.UV_INNER_V[1] - E.UV_INNER_V[0]), 0, 1)
    strip = mix(strip, inner * 0.55 + deep * 0.45, (1 - f) * 0.8)
    strip = mix(strip, inner * 0.4 + 0.6, smooth(0.054, 0.058, V))
    img = np.where((V < 0.075)[..., None], strip, img)

    arr = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    return Image.fromarray(arr, "RGB").resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- small drawn pieces (Pillow, 4x supersample)
SS = 4


def canvas(w: int, h: int):
    img = Image.new("RGBA", (w * SS, h * SS), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def done(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.LANCZOS)


def pts(points):
    return [(x * SS, y * SS) for x, y in points]


def box(x0, y0, x1, y1):
    return [x0 * SS, y0 * SS, x1 * SS, y1 * SS]


def nest_weave() -> Image.Image:
    """Diagonal strand lines, period 32 px on both axes, so it tiles at 128x64. Alpha over the part's own brown."""
    w, h = 128, 64
    n = np.zeros((h * SS, w * SS, 4))
    y, x = np.mgrid[0:h * SS, 0:w * SS]
    f = ((x + y) / SS % 32) / 32  # 0..1 across one strand
    dark = 1 - smooth(0.0, 0.10, np.minimum(f, 1 - f))        # the gap between strands
    lite = 1 - smooth(0.04, 0.12, np.abs(f - 0.36))           # a highlight along each strand
    # short cross nicks so a strand reads as wound, not striped
    g = ((x - y) / SS % 64) / 64
    nick = (1 - smooth(0.0, 0.035, np.abs(g - 0.5))) * smooth(0.12, 0.2, f) * (1 - smooth(0.8, 0.88, f))
    a_dark = np.clip(dark * 0.62 + nick * 0.4, 0, 1)
    a_lite = lite * 0.24 * (1 - a_dark)
    alpha = a_dark + a_lite
    rgb = (np.array(hexrgb(TWIG_INK))[None, None, :] * a_dark[..., None] + 255 * a_lite[..., None]) / np.maximum(alpha, 1e-6)[..., None]
    n[..., :3], n[..., 3] = rgb, alpha * 255
    return Image.fromarray(n.astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)


def crescent(d: ImageDraw.ImageDraw, img: Image.Image, cx, cy, r, colour, bite=(0.5, -0.28), cut=0.84):
    """A crescent opening to the upper right: a disc with a smaller disc bitten out."""
    layer = Image.new("L", img.size, 0)
    ld = ImageDraw.Draw(layer)
    ld.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=255)
    bx, by, br = cx + bite[0] * r, cy + bite[1] * r, r * cut
    ld.ellipse(box(bx - br, by - br, bx + br, by + br), fill=0)
    img.paste(Image.new("RGBA", img.size, hexrgb(colour) + (255,)), (0, 0), layer)


def nest_flag() -> Image.Image:
    w, h = 96, 160
    img, d = canvas(w, h)
    d.rounded_rectangle(box(12, 6, 24, 158), radius=6 * SS, fill=hexrgb(TWIG_INK) + (255,))
    d.rounded_rectangle(box(15, 9, 21, 155), radius=3 * SS, fill=hexrgb(TWIG) + (255,))
    flag = [(20, 10), (90, 44), (20, 80)]
    d.polygon(pts(flag), fill=hexrgb(INK) + (255,))
    d.line(pts(flag + flag[:1]), fill=hexrgb(INK) + (255,), width=7 * SS, joint="curve")
    d.polygon(pts([(25, 19), (79, 44), (25, 71)]), fill=hexrgb(CREAM) + (255,))
    crescent(d, img, 41, 45, 14, LILAC_DEEP)
    return done(img, w, h)


def leaf(d: ImageDraw.ImageDraw, base, tip, half, fill, edge):
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    outline, inner = [], []
    steps = 24
    for s in (1, -1):
        rng = range(steps + 1) if s == 1 else range(steps, -1, -1)
        for i in rng:
            t = i / steps
            wdt = half * math.sin(math.pi * t ** 0.8) ** 0.75
            outline.append((bx + dx * t + nx * wdt * s, by + dy * t + ny * wdt * s))
    d.polygon(pts(outline), fill=hexrgb(edge) + (255,))
    d.line(pts(outline + outline[:1]), fill=hexrgb(edge) + (255,), width=5 * SS, joint="curve")
    for s in (1, -1):
        rng = range(steps + 1) if s == 1 else range(steps, -1, -1)
        for i in rng:
            t = i / steps
            wdt = max(0.0, half * math.sin(math.pi * t ** 0.8) ** 0.75 - 2.2)
            inner.append((bx + dx * (0.04 + 0.92 * t) + nx * wdt * s, by + dy * (0.04 + 0.92 * t) + ny * wdt * s))
    d.polygon(pts(inner), fill=hexrgb(fill) + (255,))
    d.line(pts([(bx + dx * 0.1, by + dy * 0.1), (bx + dx * 0.8, by + dy * 0.8)]), fill=hexrgb(edge) + (255,), width=2 * SS)


def nest_leaves() -> Image.Image:
    w, h = 160, 96
    img, d = canvas(w, h)
    leaf(d, (80, 92), (22, 30), 17, LEAF_DARK, LEAF_INK)
    leaf(d, (80, 92), (138, 30), 17, LEAF_DARK, LEAF_INK)
    leaf(d, (80, 94), (80, 6), 20, LEAF, LEAF_INK)
    return done(img, w, h)


def halo() -> Image.Image:
    n = 256
    y, x = np.mgrid[0:n, 0:n]
    r = np.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5) / (n / 2)
    a = (1 - smooth(0.12, 1.0, r)) ** 1.6
    arr = np.zeros((n, n, 4))
    arr[..., :3], arr[..., 3] = 255, a * 255
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def sleepy_z() -> Image.Image:
    w = h = 64
    img, d = canvas(w, h)
    z = [(14, 12), (50, 12), (50, 22), (29, 42), (50, 42), (50, 52), (14, 52), (14, 42), (35, 22), (14, 22)]
    d.polygon(pts(z), fill=hexrgb(LILAC_DEEP) + (255,))
    d.line(pts(z + z[:1]), fill=hexrgb(LILAC_DEEP) + (255,), width=9 * SS, joint="curve")
    d.polygon(pts(z), fill=(255, 255, 255, 255))
    d.line(pts(z + z[:1]), fill=(255, 255, 255, 255), width=2 * SS, joint="curve")
    return done(img, w, h)


def nest_chip() -> Image.Image:
    """Reads at 16 px: a fat lilac egg with two closed eyes, a brown nest across its foot, ink outline all round."""
    w = h = 128
    img, d = canvas(w, h)
    ink = hexrgb("#15143A") + (255,)
    # egg: outline then body (a fat ellipse, slightly narrower at the top via a second ellipse)
    d.ellipse(box(22, 2, 106, 118), fill=ink)
    d.ellipse(box(31, 11, 97, 110), fill=hexrgb(LILAC) + (255,))
    # cream belly band, clipped to the egg
    body = Image.new("L", img.size, 0)
    ImageDraw.Draw(body).ellipse(box(31, 11, 97, 110), fill=255)
    bandm = Image.new("L", img.size, 0)
    ImageDraw.Draw(bandm).rectangle(box(0, 41, 128, 73), fill=255)
    img.paste(Image.new("RGBA", img.size, hexrgb(CREAM) + (255,)), (0, 0), Image.composite(bandm, Image.new("L", img.size, 0), body))
    d = ImageDraw.Draw(img)
    # gloss
    d.ellipse(box(42, 18, 56, 31), fill=(255, 255, 255, 235))
    # closed eyes: thick ink arcs (lower half)
    for cx in (49, 79):
        d.arc(box(cx - 11, 42, cx + 11, 66), start=5, end=175, fill=ink, width=8 * SS)
    # nest: a wide ink bowl with a twig-brown face and three notches
    d.rounded_rectangle(box(3, 84, 125, 126), radius=21 * SS, fill=ink)
    d.rounded_rectangle(box(11, 92, 117, 118), radius=13 * SS, fill=hexrgb(TWIG) + (255,))
    for x in (40, 64, 88):
        d.line(pts([(x - 6, 95), (x + 6, 116)]), fill=hexrgb(TWIG_INK) + (255,), width=6 * SS)
    d.rounded_rectangle(box(16, 92, 112, 99), radius=3 * SS, fill=hexrgb("#D9A566") + (255,))
    return done(img, w, h)


# ---------------------------------------------------------------- previews (not shipped)
def egg_front(tex: Image.Image, px_h: int, lean: float = 0.0) -> Image.Image:
    """The egg seen from the front (orthographic), sampled from its ColorMap; px_h = the egg's height in pixels."""
    t = np.asarray(tex.convert("RGB")).astype(float)
    n = t.shape[0]
    ssn = 3
    hh = px_h * ssn
    ww = int(round(hh * E.WIDTH / E.HEIGHT))
    out = np.zeros((hh, ww, 4))
    ts = np.linspace(0, 1, 4000)
    zs = (E.HEIGHT / 2) * (1 - np.cos(np.pi * ts))
    for j in range(hh):
        z = E.HEIGHT * (1 - (j + 0.5) / hh)
        tt = float(np.interp(z, zs, ts))
        r = E.profile(tt)[0]
        v = E.UV_OUTER_V0 + tt * (1 - E.UV_OUTER_V0)
        row = min(n - 1, int((1 - v) * n))
        for i in range(ww):
            x = ((i + 0.5) / ww - 0.5) * E.WIDTH
            if abs(x) >= r:
                continue
            ang = math.asin(x / r)
            u = 0.5 + ang / (2 * math.pi)
            c = t[row, int(u * n) % n]
            lightf = 0.82 + 0.18 * math.cos(ang) + 0.10 * (z / E.HEIGHT - 0.5)
            out[j, i, :3] = np.clip(c * lightf, 0, 255)
            out[j, i, 3] = 255
    img = Image.fromarray(out.astype(np.uint8), "RGBA").resize((ww // ssn, px_h), Image.LANCZOS)
    return img.rotate(lean, resample=Image.BICUBIC, expand=True) if lean else img


def nest_mock(tex: Image.Image, stud_px: float, egg_scale: float, glow: float, lean: float, flag: Image.Image, leaves: Image.Image,
              halo_img: Image.Image) -> Image.Image:
    """A front, slightly-from-above mock of the 10-part nest with the egg, at stud_px pixels a stud."""
    w, h = int(stud_px * 6), int(stud_px * 5.2)
    img = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = stud_px * 2
    cx, gy = w, h * 2 - s * 0.5
    sq = 0.42  # vertical squash of ground circles from the garden camera
    def disc(r, y, hgt, top, side):
        d.ellipse([cx - r * s, gy - y * s - r * s * sq, cx + r * s, gy - y * s + r * s * sq], fill=side)
        d.rectangle([cx - r * s, gy - (y + hgt) * s, cx + r * s, gy - y * s], fill=side)
        d.ellipse([cx - r * s, gy - (y + hgt) * s - r * s * sq, cx + r * s, gy - (y + hgt) * s + r * s * sq], fill=top)
    disc(1.45, 0, 0.3, hexrgb(TWIG_DARK) + (255,), hexrgb("#6E4524") + (255,))
    # back rolls, cushion, egg, front rolls
    def roll(a, colour):
        x, zz = math.sin(a) * 1.45, math.cos(a) * 1.45
        px, py = cx + x * s, gy - 0.45 * s + zz * s * sq
        lw = 0.78 * s * (0.55 + 0.45 * abs(math.cos(a)))
        d.ellipse([px - lw, py - 0.36 * s, px + lw, py + 0.36 * s], fill=hexrgb(TWIG_INK) + (255,))
        d.ellipse([px - lw + s * .05, py - 0.31 * s, px + lw - s * .05, py + 0.31 * s], fill=colour)
    order = [k * math.pi / 3 + math.pi / 6 for k in range(6)]
    back = [a for a in order if math.cos(a) < 0]
    front = [a for a in order if math.cos(a) >= 0]
    for i, a in enumerate(back):
        roll(a, hexrgb(TWIG if i % 2 else TWIG_DARK) + (255,))
    fl = flag.resize((int(0.96 * s), int(1.6 * s)), Image.LANCZOS)
    img.alpha_composite(fl, (int(cx - 1.75 * s), int(gy - 2.35 * s)))
    disc(1.15, 0.3, 0.3, hexrgb(CREAM) + (255,), hexrgb(CREAM_DEEP) + (255,))
    if glow > 0:
        gs = int(egg_scale * 2.6 * s)
        hl = halo_img.resize((gs, gs), Image.LANCZOS)
        a = hl.split()[3].point(lambda v: int(v * glow))
        tint = Image.new("RGBA", hl.size, hexrgb("#FFF3C4") + (0,))
        tint.putalpha(a)
        img.alpha_composite(tint, (int(cx - gs / 2), int(gy - 0.5 * s - egg_scale * 0.65 * s - gs / 2)))
    eg = egg_front(tex, max(6, int(E.HEIGHT * egg_scale * s)), lean)
    img.alpha_composite(eg, (int(cx - eg.width / 2), int(gy - 0.5 * s - E.HEIGHT * egg_scale * s + (eg.height - E.HEIGHT * egg_scale * s) / 2)))
    for i, a in enumerate(front):
        roll(a, hexrgb(TWIG_DARK if i % 2 else TWIG) + (255,))
    lv = leaves.resize((int(1.0 * s), int(0.6 * s)), Image.LANCZOS)
    img.alpha_composite(lv, (int(cx + 0.75 * s), int(gy - 1.15 * s)))
    return img.resize((w, h), Image.LANCZOS)


def preview(directory: Path, made: dict[str, Image.Image]) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    tex = made["sleepy-egg-color.png"]
    looks = [("small", 1.25, 0.0, 0), ("glow", 1.6, 0.45, 0), ("rocking", 2.0, 0.6, 9), ("ready", 2.0, 1.0, -7)]
    scales = [44, 22, 12, 7]  # pixels a stud: close, 20 studs, 40 studs, phone far
    cell_w, cell_h = int(44 * 6), int(44 * 5.2)
    sheet = Image.new("RGBA", (cell_w * len(looks), sum(int(p * 5.2) + 8 for p in scales) + 8), hexrgb(GRASS) + (255,))
    y = 4
    for p in scales:
        for i, (_, sc, glow, lean) in enumerate(looks):
            m = nest_mock(tex, p, sc, glow, lean, made["nest-flag.png"], made["nest-leaves.png"], made["sleepy-halo.png"])
            sheet.alpha_composite(m, (i * cell_w + (cell_w - m.width) // 2, y))
        y += int(p * 5.2) + 8
    sheet.convert("RGB").save(directory / "nest-stages.png")

    eggs = Image.new("RGBA", (760, 300), hexrgb(GRASS) + (255,))
    x = 10
    for px in (260, 140, 80, 48, 28, 16):
        e = egg_front(tex, px)
        eggs.alpha_composite(e, (x, 290 - px))
        x += e.width + 16
    eggs.convert("RGB").save(directory / "egg-front.png")

    chip = made["nest-chip.png"]
    sizes = (64, 48, 32, 24, 20, 16)
    grounds = ["#15143A", "#FFF3D6", "#3B4A78", GRASS]
    sh = Image.new("RGBA", (sum(sizes) + 12 * (len(sizes) + 1), 80 * len(grounds)), (0, 0, 0, 255))
    for r, gcol in enumerate(grounds):
        ImageDraw.Draw(sh).rectangle([0, r * 80, sh.width, r * 80 + 80], fill=hexrgb(gcol) + (255,))
        x = 12
        for px in sizes:
            sh.alpha_composite(chip.resize((px, px), Image.LANCZOS), (x, r * 80 + (80 - px) // 2))
            x += px + 12
    sh.convert("RGB").save(directory / "chip-sizes.png")

    bits = Image.new("RGBA", (700, 200), hexrgb(GRASS) + (255,))
    x = 8
    for name, hs in (("nest-flag.png", (160, 64, 32)), ("nest-leaves.png", (96, 40, 20)), ("sleepy-z.png", (64, 32, 16)), ("nest-weave.png", (64,))):
        for hh in hs:
            im = made[name]
            im = im.resize((max(1, int(im.width * hh / im.height)), hh), Image.LANCZOS)
            if name == "nest-weave.png":
                tile = Image.new("RGBA", (256, 128), hexrgb(TWIG) + (255,))
                for tx in range(0, 256, 128):
                    for ty in range(0, 128, 64):
                        tile.alpha_composite(made[name], (tx, ty))
                im = tile
            bits.alpha_composite(im, (x, 190 - im.height))
            x += im.width + 10
    bits.convert("RGB").save(directory / "bits.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    made = {
        "sleepy-egg-color.png": egg_color(),
        "nest-weave.png": nest_weave(),
        "nest-flag.png": nest_flag(),
        "nest-leaves.png": nest_leaves(),
        "sleepy-halo.png": halo(),
        "sleepy-z.png": sleepy_z(),
        "nest-chip.png": nest_chip(),
    }
    for name, img in made.items():
        img.save(OUT / name, optimize=True)
        print("wrote", (OUT / name).relative_to(ROOT), img.size)
    if "--preview" in sys.argv:
        directory = Path(sys.argv[sys.argv.index("--preview") + 1])
        preview(directory, made)
        print("previews in", directory)


if __name__ == "__main__":
    main()
