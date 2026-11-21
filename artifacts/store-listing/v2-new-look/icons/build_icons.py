"""Dewdrop store icons A, B, C, D (ART-DIRECTION.md, "Update 2026-11-21").
D is Spencer's follow-up to C: the Bear holds his deck out to the camera (S10).

Everything is drawn in code (numpy + PIL) from our own Studio cut-outs in ../captures
(S1-tight, S2, S3, S4, S5) and the game's own 3D Star token capture
(../../ad-v1/layers/star_a.png). No AI imagery, no third-party images, no type.

Each icon is composed on a 1024 canvas and reduced to 512 (the Roblox icon size).
A 1024 master is written only where no cut-out is enlarged past its capture size.

Run: python build_icons.py
 ->  icon-A..D.png (512), icon-B-1024.png icon-C-1024.png, icons-ABC.png, icons-CD.png
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
CAP = os.path.join(HERE, "..", "captures")
STAR = os.path.join(HERE, "..", "..", "ad-v1", "layers", "star_a.png")
M = 1024  # working canvas
INK = (12, 42, 74)
SKY = ("#0A6BE0", "#6FD0FF")
LEAF = ("#2FB344", "#C6F56A")
COOL = np.array([178, 214, 255], np.float32)  # sky fill colour for the relight


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------- field, floor, bubbles
def field(top, bottom, floor, w=M, h=M):
    """One colour field: vertical gradient, soft glow top-left, glossy floor with a bright lip."""
    t, b = np.array(rgb(top), np.float32), np.array(rgb(bottom), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (yy / (h * floor)).clip(0, 1)[..., None]
    img = t + (b - t) * v ** 1.2
    glow = np.exp(-(((xx - w * 0.20) / (w * 0.52)) ** 2 + ((yy - h * 0.10) / (h * 0.55)) ** 2))[..., None]
    img = img + (255 - img) * glow * 0.36
    fl = ((yy - h * floor) / (h * (1 - floor))).clip(0, 1)[..., None]
    floor_col = b + (255 - b) * 0.60 * (1 - fl) ** 2
    floor_col = floor_col * (1 - 0.34 * fl) + t * 0.34 * fl
    img = np.where((yy >= h * floor)[..., None], floor_col, img)
    return Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")


def bubble(d, strength=1.0):
    """Glass bubble: thin rim, faint fill, one wet highlight top-left, bounce crescent bottom-right."""
    yy, xx = (np.mgrid[0:d, 0:d].astype(np.float32) + 0.5) / d * 2 - 1
    r = np.sqrt(xx ** 2 + yy ** 2)
    inside = np.clip((1 - r) * d / 2, 0, 1)
    rim = np.exp(-((r - 0.93) / 0.05) ** 2) * 0.60
    fill = 0.07 + 0.10 * r ** 3
    hi = np.exp(-(((xx + 0.38) / 0.24) ** 2 + ((yy + 0.42) / 0.15) ** 2)) * 0.95
    bounce = np.exp(-((r - 0.74) / 0.07) ** 2) * np.clip((xx + yy) * 0.9 - 0.5, 0, 1) * 0.55
    a = np.clip((rim + fill + hi + bounce) * strength, 0, 1) * inside
    out = np.zeros((d, d, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def put_bubble(base, cx, cy, d, strength=1.0):
    base.alpha_composite(bubble(d, strength), (int(cx - d / 2), int(cy - d / 2)))


# ---------------------------------------------------------------- cut-outs
def load(path, scale=1.0, rot=0.0):
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getbbox())
    if scale != 1.0:
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    if rot:
        im = im.rotate(rot, Image.BICUBIC, expand=True)
    return im


def relight(im, cool=0.26, lift=0.0):
    """Gentle sky fill from the right: the right side and right-hand rim take a cool tint.
    Multiplicative, so the model's own shading, colours and face stay as captured."""
    a = np.asarray(im).astype(np.float32)
    col, al = a[..., :3], a[..., 3:] / 255.0
    h, w = al.shape[:2]
    xx = np.linspace(0, 1, w, dtype=np.float32)[None, :, None]
    side = np.clip((xx - 0.42) / 0.58, 0, 1) ** 1.4
    soft = np.asarray(im.getchannel("A").filter(ImageFilter.GaussianBlur(max(2, w * 0.035)))).astype(np.float32)[..., None] / 255.0
    rim = np.clip((1 - soft) * 2.2, 0, 1)  # high near the silhouette
    f = (side * (0.45 + 0.55 * rim) * cool).clip(0, 1)
    col = col * (1 - f) + (col * COOL / 255.0) * f
    if lift:
        col = col + (255 - col) * lift
    out = np.concatenate([col.clip(0, 255), al * 255], -1).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def contact(base, cx, y, rx, ry, alpha=95, blur=12):
    s = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(s).ellipse((cx - rx, y - ry, cx + rx, y + ry), fill=INK + (alpha,))
    base.alpha_composite(s.filter(ImageFilter.GaussianBlur(blur)))


def soft_shadow(base, im, xy, dx=10, dy=16, blur=16, alpha=0.30):
    """Ink Navy shadow of a cut-out cast on whatever is behind it."""
    a = im.getchannel("A").point(lambda v: int(v * alpha))
    sh = Image.new("RGBA", im.size, INK + (0,))
    sh.putalpha(a)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(sh, (xy[0] + dx, xy[1] + dy))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def reflect(base, im, x, foot_y, strength=0.30, frac=0.34):
    rh = int(im.height * frac)
    ref = im.transpose(Image.FLIP_TOP_BOTTOM).crop((0, 0, im.width, rh))
    fade = np.linspace(strength, 0, rh)[:, None] ** 1.4
    ref.putalpha(Image.fromarray((np.asarray(ref)[..., 3] * fade).astype(np.uint8)))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(ref, (x, foot_y))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2.0)))


def paste(base, im, xy):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(im, xy)
    base.alpha_composite(layer)


# ---------------------------------------------------------------- icons
def icon_a():
    """Two pals: S1 Bear (hero, front left) and S2 Rose Bunny (behind, right), cheek to cheek. Sky."""
    c = field(*SKY, floor=0.80)
    put_bubble(c, 160, 160, 180)
    put_bubble(c, 400, 92, 58, 0.9)
    bunny = relight(load(os.path.join(CAP, "S2.png"), 1.62, rot=8), cool=0.20)
    bear = relight(load(os.path.join(CAP, "S1-tight.png"), 1.08, rot=-5), cool=0.18)
    bxy = (448, 44)
    paste(c, bunny, bxy)
    exy = (-92, 336)
    soft_shadow(c, bear, exy, dx=14, dy=10, blur=18, alpha=0.26)
    paste(c, bear, exy)
    return c


def icon_b():
    """One pal: S3 Bear face at about 70% of the square, one Star resting on the floor. Sky."""
    c = field(*SKY, floor=0.80)
    put_bubble(c, 892, 142, 170)
    put_bubble(c, 96, 196, 58, 0.9)
    bear = relight(load(os.path.join(CAP, "S3.png"), 1.0), cool=0.22)
    xy = (96, M - bear.height + 6)
    contact(c, 470, 985, 420, 40, alpha=70, blur=26)
    paste(c, bear, xy)
    star = load(STAR, 0.86, rot=-10)
    sx, foot = 760, 968
    reflect(c, star, sx, foot - 6, strength=0.34, frac=0.4)
    contact(c, sx + star.width / 2, foot - 2, star.width * 0.40, 13, alpha=110, blur=9)
    soft_shadow(c, star, (sx, foot - star.height), dx=-10, dy=6, blur=14, alpha=0.22)
    paste(c, star, (sx, foot - star.height))
    return c


def icon_c():
    """Pocket deck: S4 Cloud Glass deck, tilted 5 degrees, S5 Bear peeking over its top edge. Leaf."""
    c = field(*LEAF, floor=0.78)
    put_bubble(c, 900, 150, 150)
    put_bubble(c, 92, 300, 60, 0.9)
    bear = relight(load(os.path.join(CAP, "S5.png"), 0.72), cool=0.14)
    deck = load(os.path.join(CAP, "S4.png"), 0.78, rot=5)
    dx, dy = (M - deck.width) // 2 + 4, 322
    paste(c, bear, ((M - bear.width) // 2 + 10, 118))
    foot = dy + deck.height - 26
    contact(c, M / 2, foot, deck.width * 0.40, 24, alpha=110, blur=18)
    reflect(c, deck, dx, foot - 18, strength=0.22, frac=0.22)
    soft_shadow(c, deck, (dx, dy), dx=0, dy=-10, blur=14, alpha=0.30)  # deck's shadow up onto the Bear
    paste(c, deck, (dx, dy))
    return c


def icon_d(deck_yaw=-22.0, deck_pitch=-12.0, s=1.06, top=16, deck_w=760, deck_dy=-55, deck_dx=24):
    """Spencer 2026-11-21: C's idea, but the Bear shows his deck to the camera, arms forward,
    higher in the frame with the whole face clear. S10 is the front-on Bear with his paws
    placed at the deck's ends in Studio; S10-paws (same frame, paws only) masks the paws so
    they sit over the deck's top corners. The deck is S4-straight turned like S4. Leaf.
    Fable's pass: deck 800 -> 760 to keep the bottom edge in frame, yaw -22 to match C, s 1.06."""
    import sys
    sys.path.insert(0, CAP)
    import cutout
    full = cutout.matte("S10-black.jpg", "S10-grey.jpg")
    paw_a = np.asarray(cutout.matte("S10-paws-black.jpg", "S10-paws-grey.jpg").getchannel("A"))
    fa = np.asarray(full)
    paws = fa.copy()
    paws[..., 3] = np.minimum(fa[..., 3], paw_a)
    box = full.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    full, paws = full.crop(box), Image.fromarray(paws, "RGBA").crop(box)
    size = (round(full.width * s), round(full.height * s))
    bear = relight(full.resize(size, Image.LANCZOS), cool=0.14)
    paws = relight(paws.resize(size, Image.LANCZOS), cool=0.14)
    # Paw centres in the cut-out (from the paw matte), in canvas units.
    pa = np.asarray(paws.getchannel("A")) > 128
    ys, xs = np.nonzero(pa)
    mid = paws.width / 2
    lx, rx = xs[xs < mid].mean(), xs[xs >= mid].mean()
    py = ys.mean()

    c = field(*LEAF, floor=0.82)
    put_bubble(c, 120, 150, 150)
    put_bubble(c, 936, 300, 64, 0.9)
    put_bubble(c, 900, 120, 40, 0.8)
    bx = (M - bear.width) // 2
    paste(c, bear, (bx, top))

    flat = Image.open(os.path.join(CAP, "S4-straight.png")).convert("RGBA")
    deck = cutout.three_quarter(flat, yaw=deck_yaw, pitch=deck_pitch)
    k = deck_w / deck.width
    deck = deck.resize((deck_w, round(deck.height * k)), Image.LANCZOS)
    dcx = bx + (lx + rx) / 2
    dx = int(dcx - deck.width / 2) + deck_dx  # keeps the left paw off the wordmark
    dy = int(top + py + deck_dy)
    soft_shadow(c, deck, (dx, dy), dx=0, dy=-14, blur=16, alpha=0.30)  # cast up onto the Bear
    contact(c, dcx, min(M - 30, dy + deck.height + 22), deck.width * 0.36, 18, alpha=70, blur=22)
    paste(c, deck, (dx, dy))
    soft_shadow(c, paws, (bx, top), dx=6, dy=10, blur=8, alpha=0.28)  # paws on the deck
    paste(c, paws, (bx, top))
    return c


def fisheye(src, out=M, mag=1.25, k=0.45):
    """Barrel lens over a finished scene: the middle is magnified `mag` times and the
    edges are squeezed (k), like a 90s handheld ad shot right up against a fisheye.
    Bilinear resample of `src` (square, centred on the lens) into an `out` square."""
    a = np.asarray(src.convert("RGB")).astype(np.float32)
    H, W = a.shape[:2]
    half = out / 2
    yy, xx = (np.mgrid[0:out, 0:out].astype(np.float32) + 0.5 - half) / half
    r2 = xx ** 2 + yy ** 2
    g = (1 + k * r2) / mag
    sx = W / 2 + xx * g * half - 0.5
    sy = H / 2 + yy * g * half - 0.5
    x0, y0 = np.floor(sx).astype(int), np.floor(sy).astype(int)
    fx, fy = (sx - x0)[..., None], (sy - y0)[..., None]
    x0, y0 = x0.clip(0, W - 2), y0.clip(0, H - 2)
    p = a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x0 + 1] * fx * (1 - fy) \
        + a[y0 + 1, x0] * (1 - fx) * fy + a[y0 + 1, x0 + 1] * fx * fy
    vig = (1 - 0.16 * np.clip(r2 - 0.55, 0, None) ** 1.3)[..., None]  # soft lens fall-off
    return Image.fromarray((p * vig).clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")


def icon_e(S=1600, bear_s=1.0, bun_s=1.05, deck_w=940, mag=1.34, k=0.95, bun_dx=200, bun_y=200, deck_cx=40, deck_y=780):
    """Spencer 2026-11-21, after D: "less warped, make it just make sense visually like he's
    holding it up to a fish eye lens, maybe make the characters distorted with fish eye lens
    too, add the bunny back too, on the right, like a retro game boy ad!!! Make the background
    blue again". The deck is flat-on (S4-straight); the Bear (S10, paws split off and set on
    the deck's top corners) holds it up to the lens; the Rose Bunny (S11) leans in from the
    right. The whole scene is then shot through one fisheye. Sky."""
    import sys
    sys.path.insert(0, CAP)
    import cutout
    full = cutout.matte("S10-black.jpg", "S10-grey.jpg")
    paw_a = np.asarray(cutout.matte("S10-paws-black.jpg", "S10-paws-grey.jpg").getchannel("A")).astype(np.float32) / 255
    fa = np.asarray(full).astype(np.float32)
    body = fa.copy()
    body[..., 3] *= 1 - np.clip(paw_a * 1.4, 0, 1)
    pw = fa.copy()
    pw[..., 3] = np.minimum(fa[..., 3], paw_a * 255)
    mid = fa.shape[1] // 2
    left, right = pw.copy(), pw.copy()
    left[:, mid:, 3] = 0
    right[:, :mid, 3] = 0

    def cut(arr, s):
        im = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
        return relight(im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS), cool=0.14)

    bear, paw_l, paw_r = cut(body, bear_s), cut(left, bear_s), cut(right, bear_s)
    bun = relight(load(os.path.join(CAP, "S11.png"), bun_s, rot=-4), cool=0.10)

    c = field(*SKY, floor=0.80, w=S, h=S)
    put_bubble(c, 330, 380, 190)
    put_bubble(c, 560, 250, 60, 0.9)
    put_bubble(c, 1250, 300, 80, 0.85)
    cx = S // 2
    # Bunny behind, right; Bear in the middle, a touch left.
    bun_xy = (cx + bun_dx, bun_y)
    soft_shadow(c, bun, bun_xy, dx=10, dy=10, blur=16, alpha=0.18)
    paste(c, bun, bun_xy)
    bear_xy = (cx - 70 - bear.width // 2, 250)
    soft_shadow(c, bear, bear_xy, dx=-12, dy=10, blur=18, alpha=0.20)
    paste(c, bear, bear_xy)
    # The deck, flat to the lens, held just under his chin.
    deck = load(os.path.join(CAP, "S4-straight.png"))
    deck = deck.resize((deck_w, round(deck.height * deck_w / deck.width)), Image.LANCZOS)
    dx, dy = cx + deck_cx - deck_w // 2, deck_y
    soft_shadow(c, deck, (dx, dy), dx=0, dy=-18, blur=20, alpha=0.32)
    contact(c, dx + deck_w / 2, min(S - 40, dy + deck.height + 60), deck_w * 0.38, 26, alpha=70, blur=30)
    paste(c, deck, (dx, dy))
    # Paws over the top corners, clear of the wordmark.
    for paw, px in ((paw_l, dx + 10), (paw_r, dx + deck_w - 10)):
        xy = (int(px - paw.width / 2), int(dy + 34 - paw.height / 2))
        soft_shadow(c, paw, xy, dx=6, dy=12, blur=10, alpha=0.30)
        paste(c, paw, xy)
    return fisheye(c, M, mag=mag, k=k)


def bulge(im, mag=1.18, k=0.5, pad=1.18):
    """Fisheye on one cut-out only (premultiplied RGBA): its middle swells toward the
    viewer and its straight edges bow out, as if just this object is up against the lens."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    al = a[..., 3:4] / 255
    a = np.concatenate([a[..., :3] * al, a[..., 3:4]], -1)
    H, W = a.shape[:2]
    oh, ow = int(H * pad), int(W * pad)
    R = max(ow, oh) / 2
    yy, xx = np.mgrid[0:oh, 0:ow].astype(np.float32) + 0.5
    xx, yy = (xx - ow / 2) / R, (yy - oh / 2) / R
    g = (1 + k * (xx ** 2 + yy ** 2)) / mag
    sx, sy = W / 2 + xx * g * R - 0.5, H / 2 + yy * g * R - 0.5
    inside = ((sx >= 0) & (sx <= W - 1) & (sy >= 0) & (sy <= H - 1))[..., None]
    x0, y0 = np.floor(sx).astype(int).clip(0, W - 2), np.floor(sy).astype(int).clip(0, H - 2)
    fx, fy = (sx - x0).clip(0, 1)[..., None], (sy - y0).clip(0, 1)[..., None]
    p = a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x0 + 1] * fx * (1 - fy) \
        + a[y0 + 1, x0] * (1 - fx) * fy + a[y0 + 1, x0 + 1] * fx * fy
    p = p * inside
    oa = p[..., 3:4] / 255
    rgb = p[..., :3] / np.maximum(oa, 1e-3)
    out = Image.fromarray(np.concatenate([rgb, p[..., 3:4]], -1).clip(0, 255).astype(np.uint8), "RGBA")
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())


def icon_f(bear_s=0.84, bun_s=0.80, deck_w=780, mag=1.12, k=0.45,
           bear_x=400, bear_y=40, bun_x=580, bun_y=136, deck_x=512, deck_y=600, paw_in=-14, paw_h=0.42):
    """Spencer 2026-11-21, after E: "Try a version with the characters and background un
    fish eyed? And framed better". E's scene with the lens taken off everything but the deck:
    the Bear and the Rose Bunny sit flat on Sky, and only the deck (held up to the camera)
    bulges. Tighter frame: faces fill the top, the deck the bottom. Positions are on the
    1024 canvas (bear_x / deck_x are centres)."""
    import sys
    sys.path.insert(0, CAP)
    import cutout
    full = cutout.matte("S10-black.jpg", "S10-grey.jpg")
    paw_a = np.asarray(cutout.matte("S10-paws-black.jpg", "S10-paws-grey.jpg").getchannel("A")).astype(np.float32) / 255
    fa = np.asarray(full).astype(np.float32)
    body = fa.copy()
    body[..., 3] *= 1 - np.clip(paw_a * 1.4, 0, 1)
    pw = fa.copy()
    pw[..., 3] = np.minimum(fa[..., 3], paw_a * 255)
    mid = fa.shape[1] // 2
    left, right = pw.copy(), pw.copy()
    left[:, mid:, 3] = 0
    right[:, :mid, 3] = 0

    def cut(arr, s):
        im = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
        return relight(im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS), cool=0.14)

    bear, paw_l, paw_r = cut(body, bear_s), cut(left, bear_s), cut(right, bear_s)
    bun = relight(load(os.path.join(CAP, "S11.png"), bun_s, rot=-4), cool=0.10)

    c = field(*SKY, floor=0.80)
    put_bubble(c, 120, 150, 150)
    put_bubble(c, 300, 70, 44, 0.9)
    paste(c, bun, (bun_x, bun_y))
    bxy = (bear_x - bear.width // 2, bear_y)
    soft_shadow(c, bear, bxy, dx=14, dy=10, blur=18, alpha=0.22)  # onto the Bunny
    paste(c, bear, bxy)
    flat = load(os.path.join(CAP, "S4-straight.png"))
    flat = flat.resize((deck_w, round(flat.height * deck_w / flat.width)), Image.LANCZOS)
    deck = bulge(flat, mag=mag, k=k)
    dx, dy = deck_x - deck.width // 2, deck_y
    soft_shadow(c, deck, (dx, dy), dx=0, dy=-16, blur=18, alpha=0.32)
    paste(c, deck, (dx, dy))
    # Paws grip the bulged deck's sides, like hands on a handheld: centred on the outline's
    # left and right edge at `paw_h` of its height, clear of the wordmark and the D-pad.
    da = np.asarray(deck.getchannel("A")) > 128
    row = int(deck.height * paw_h)
    cols = np.nonzero(da[row])[0]
    for paw, col in ((paw_l, cols[0] + paw_in), (paw_r, cols[-1] - paw_in)):
        pys, pxs = np.nonzero(np.asarray(paw.getchannel("A")) > 128)  # solid centre, not the bbox
        xy = (int(dx + col - pxs.mean()), int(dy + row - pys.mean()))
        soft_shadow(c, paw, xy, dx=6, dy=12, blur=10, alpha=0.30)
        paste(c, paw, xy)
    return c


# ---------------------------------------------------------------- sheet
def rounded(im, r):
    m = Image.new("L", (im.width * 3, im.height * 3), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, m.width - 1, m.height - 1), r * 3, fill=255)
    out = im.copy()
    out.putalpha(m.resize(im.size, Image.LANCZOS))
    return out


def sheet(icons):
    f = ImageFont.truetype("C:/Windows/Fonts/Nunito-ExtraBold.ttf", 30)
    fs = ImageFont.truetype("C:/Windows/Fonts/Quicksand-Bold.ttf", 22)
    names = {"A": "Icon A  two pals", "B": "Icon B  one pal", "C": "Icon C  pocket deck", "D": "Icon D  show and tell", "E": "Icon E  fisheye", "F": "Icon F  lens on the deck"}
    keys = list(icons)
    gw, pad, top = 512 + 30 + 150, 56, 70
    band_h = top + 512 + 60
    W = pad + len(keys) * (gw + pad)
    out = Image.new("RGBA", (W, band_h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for bi, (bg, ink, sub) in enumerate((((244, 247, 251), INK, (90, 110, 135)), ((22, 25, 32), (255, 255, 255), (150, 160, 175)))):
        y0 = bi * band_h
        d.rectangle((0, y0, W, y0 + band_h), fill=bg)
        for i, k in enumerate(keys):
            x = pad + i * (gw + pad)
            d.text((x, y0 + 20), names[k], font=f, fill=ink)
            for size, ox, oy in ((512, 0, 0), (150, 542, 0), (50, 542, 150 + 62)):
                im = icons[k].resize((size, size), Image.LANCZOS)
                out.alpha_composite(rounded(im, max(3, round(size * 0.11))), (x + ox, y0 + top + oy))
                d.text((x + ox, y0 + top + oy + size + 6), f"{size} px", font=fs, fill=sub)
    return out.convert("RGB")


if __name__ == "__main__":
    icons = {}
    for k, fn, master in (("A", icon_a, False), ("B", icon_b, True), ("C", icon_c, True), ("D", icon_d, False), ("E", icon_e, False), ("F", icon_f, True)):
        big = fn().convert("RGB")
        if master:
            big.save(os.path.join(HERE, f"icon-{k}-1024.png"))
        icons[k] = big.resize((512, 512), Image.LANCZOS)
        icons[k].save(os.path.join(HERE, f"icon-{k}.png"))
    icons = {k: v.convert("RGBA") for k, v in icons.items()}
    sheet({k: icons[k] for k in "ABC"}).save(os.path.join(HERE, "icons-ABC.png"))
    sheet({k: icons[k] for k in "CD"}).save(os.path.join(HERE, "icons-CD.png"))
    sheet({k: icons[k] for k in "EF"}).save(os.path.join(HERE, "icons-EF.png"))
    print("wrote icon-A..F.png, icon-B/C/F-1024.png, icons-ABC.png, icons-CD.png, icons-EF.png")
