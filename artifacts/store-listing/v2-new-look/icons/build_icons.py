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


def icon_g():
    """Spencer 2026-11-21: "Make it framed more like icon a". F's scene (flat pals, the lens on
    the deck only) at A's scale: two big heads filling the square, the Bear on the left, the
    Bunny on the right with her ears near the top, the deck held up under both and running off
    the bottom edge the way the bodies do in A."""
    return icon_f(bear_s=1.05, bun_s=1.05, deck_w=900, bear_x=290, bear_y=170,
                  bun_x=576, bun_y=60, deck_x=520, deck_y=720)


# ---------------------------------------------------------------- hero deck screen
# Spencer 2026-11-21: "show a more exciting screen on the pocket deck, it doesn't have to be a
# real screen? Just larger and readable, cool colors and ui". Drawn here from the game's own
# look: the Smileys ball ramps from src/shared/BallThemes.lua (body / deep / light, ink
# #15102B), chunky LCD pixels like the in-game board, a merge burst and a big score.
BALL = [("#2E8BFF", "#0A3FD6", "#8FE1FF"), ("#FF8A1A", "#E0400A", "#FFD45C"), ("#22E06A", "#04963F", "#B4FF7A"),
        ("#FF4DA6", "#C4126F", "#FFB0DC"), ("#A66BFF", "#5B21D6", "#E3C8FF")]
BALL_INK = (21, 16, 43)
# The Bubbles theme (BallThemes.lua, 100 Stars): Sky, Peach, Melon, Blossom, Violet; ink #2A2450,
# face "dots". Its pale bodies and near-white lights match the icon's sky, cream and rose.
BUBBLES = [("#8FD0FF", "#4A9BE8", "#F0FAFF"), ("#FFC48A", "#F08A4A", "#FFF1DC"), ("#9FF0C0", "#3FC486", "#EFFFF2"),
           ("#FFA8D0", "#E85FA0", "#FFEAF4"), ("#CDB0FF", "#8B5FE8", "#F5ECFF")]
BUBBLES_INK = (42, 36, 80)
SCREEN_BOX = (306, 84, 966, 558)  # the glass inside S4-straight's bezel


def pixel_ball(px, cx, cy, r, tier, ramps=None, ink=None, face="smiley"):
    """One Smileys ball on the low-res LCD grid `px` (a PIL image): ink rim, deep shade
    bottom-right, light highlight top-left, two eyes and a smile."""
    body, deep, light = (rgb(h) for h in (ramps or BALL)[tier])
    INKC = ink or BALL_INK
    d = ImageDraw.Draw(px)
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            q = (dx * dx + dy * dy) ** 0.5
            if q > r:
                continue
            c = body
            if q > r - 1.05:
                c = INKC
            elif dx * 0.6 + dy * 0.8 > r * 0.42:
                c = deep
            elif (dx + r * 0.38) ** 2 + (dy + r * 0.42) ** 2 < (r * 0.30) ** 2:
                c = light
            d.point((x, y), fill=c)
    e = max(1, round(r * 0.16))
    ey, ex = cy - r * 0.12, r * 0.36
    for sx in (-1, 1):
        d.rectangle((round(cx + sx * ex - e / 2), round(ey - e / 2), round(cx + sx * ex - e / 2) + e - 1, round(ey - e / 2) + e), fill=INKC)
    if face == "dots":
        return
    w = max(2, round(r * 0.5))
    my = round(cy + r * 0.22)
    d.line((round(cx - w / 2), my, round(cx + w / 2), my), fill=INKC)
    d.point((round(cx - w / 2) - 1, my - 1), fill=INKC)
    d.point((round(cx + w / 2) + 1, my - 1), fill=INKC)


def hero_screen(w, h, px=6):
    """The deck's screen as an ad shot: violet-navy LCD, a tall jar of pixel balls mid-merge,
    a starburst with +240, SCORE 12,480 and a gold x5 COMBO pill. `px` is the LCD pixel size."""
    gw, gh = w // px, h // px
    lcd = Image.new("RGB", (gw, gh))
    a = np.zeros((gh, gw, 3), np.float32)
    t = np.linspace(0, 1, gh)[:, None, None]
    a[:] = np.array(rgb("#1E2A78")) * (1 - t) + np.array(rgb("#3B1670")) * t
    yy, xx = np.mgrid[0:gh, 0:gw]
    a += ((xx + yy) % 9 == 0)[..., None] * 10  # the board's diagonal dashes
    lcd = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(lcd)
    # Jar: a lighter well in the middle third with a dashed fill line.
    jx0, jx1 = int(gw * 0.30), int(gw * 0.70)
    d.rectangle((jx0, int(gh * 0.20), jx1, gh - 3), fill=(44, 54, 140))
    d.rectangle((jx0, int(gh * 0.20), jx0, gh - 3), fill=(120, 150, 255))
    d.rectangle((jx1, int(gh * 0.20), jx1, gh - 3), fill=(120, 150, 255))
    for x in range(jx0 + 2, jx1 - 1, 4):
        d.line((x, int(gh * 0.42), x + 1, int(gh * 0.42)), fill=(150, 170, 255))
    # Burst behind the merge.
    bx, by = gw * 0.50, gh * 0.58
    for i in range(16):
        ang = i * np.pi / 8
        L = (gh * 0.40) if i % 2 == 0 else (gh * 0.26)
        d.line((bx, by, bx + np.cos(ang) * L, by + np.sin(ang) * L), fill=(255, 214, 92) if i % 2 == 0 else (255, 160, 220), width=2)
    # The stack: big violet at the bottom, the rest piled up, a pink pair merging.
    cyb = gh - 3
    pixel_ball(lcd, jx0 + 9.5, cyb - 9, 8.5, 4)
    pixel_ball(lcd, jx1 - 7.5, cyb - 7, 6.6, 2)
    pixel_ball(lcd, jx0 + 22, cyb - 6, 5.2, 1)
    pixel_ball(lcd, bx - 4.5, by + 1, 6.0, 3)
    pixel_ball(lcd, bx + 6.0, by - 1, 6.0, 3)
    # Side panels.
    d.rectangle((2, 2, jx0 - 3, gh - 3), fill=(24, 34, 96))
    d.rectangle((jx1 + 3, 2, gw - 3, gh - 3), fill=(24, 34, 96))
    pixel_ball(lcd, (jx1 + gw) / 2, gh * 0.74, 6.0, 1)
    pixel_ball(lcd, jx0 / 2, gh * 0.74, 5.0, 0)
    img = lcd.resize((gw * px, gh * px), Image.NEAREST).resize((w, h), Image.NEAREST).convert("RGBA")
    # Crisp UI type over the LCD.
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype("C:/Windows/Fonts/Nunito-ExtraBold.ttf", int(h * 0.15))
    mid = ImageFont.truetype("C:/Windows/Fonts/Nunito-ExtraBold.ttf", int(h * 0.085))
    small = ImageFont.truetype("C:/Windows/Fonts/Nunito-ExtraBold.ttf", int(h * 0.065))
    lx = int(w * 0.035)
    huge = ImageFont.truetype("C:/Windows/Fonts/Nunito-ExtraBold.ttf", int(h * 0.20))
    d.text((lx, int(h * 0.015)), "12,480", font=huge, fill=(255, 255, 255), stroke_width=4, stroke_fill=BALL_INK)
    rx = int(w * 0.735)
    d.text((rx, int(h * 0.06)), "COMBO", font=small, fill=(255, 212, 92))
    # Gold combo pill, top right.
    pill = (rx - 2, int(h * 0.15), w - int(w * 0.035), int(h * 0.36))
    d.rounded_rectangle(pill, radius=(pill[3] - pill[1]) // 2, fill=(255, 212, 92), outline=BALL_INK, width=3)
    d.text(((pill[0] + pill[2]) / 2, (pill[1] + pill[3]) / 2 - 2), "x5", font=big, fill=BALL_INK, anchor="mm")
    # +240 pop over the merge.
    d.text((w * 0.50, h * 0.40), "+240", font=huge, fill=(255, 255, 255), anchor="mm", stroke_width=4, stroke_fill=(196, 18, 111))
    return img


def deck_with_hero(screen_fn=hero_screen):
    """S4-straight with its screen replaced by the hero screen, plus a faint glass glare."""
    deck = load(os.path.join(CAP, "S4-straight.png"))
    x0, y0, x1, y1 = SCREEN_BOX
    w, h = x1 - x0, y1 - y0
    scr = screen_fn(w, h)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    glare = np.clip(1 - (xx / w * 0.9 + yy / h * 0.6) / 0.75, 0, 1) ** 2 * 0.16
    g = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    g.putalpha(Image.fromarray((glare * 255).astype(np.uint8)))
    scr.alpha_composite(g)
    m = Image.new("L", (w * 3, h * 3), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * 3 - 1, h * 3 - 1), 18 * 3, fill=255)
    deck.paste(scr, (x0, y0), m.resize((w, h), Image.LANCZOS))
    return deck


def icon_h(bear_up=60, deck_w=700, tilt=9.0, deck_cx=710, deck_y=640, paw=False, paw_s=0.95, paw_h=0.42):
    """Spencer 2026-11-21: "A bit more like icon [A], characters in similar position? Bear up a
    tiny bit on the left ... same positions/poses? Maybe pocket deck tilted to compensate for
    height difference between the two chars? And show a more exciting screen". Icon A's own
    cut-outs and placement (S2 Bunny, S1-tight Bear), the Bear `bear_up` px higher, and the
    hero-screen deck in front, turned `tilt` degrees so it rises from his side to hers.
    `deck_cx` is the deck's centre x and `deck_y` its top on the 1024 canvas."""
    c = field(*SKY, floor=0.80)
    put_bubble(c, 160, 160, 180)
    put_bubble(c, 400, 92, 58, 0.9)
    bunny = relight(load(os.path.join(CAP, "S2.png"), 1.62, rot=8), cool=0.20)
    bear = relight(load(os.path.join(CAP, "S1-tight.png"), 1.08, rot=-5), cool=0.18)
    paste(c, bunny, (448, 44))
    exy = (-92, 336 - bear_up)
    soft_shadow(c, bear, exy, dx=14, dy=10, blur=18, alpha=0.26)
    paste(c, bear, exy)
    deck = deck_with_hero()
    deck = deck.resize((deck_w, round(deck.height * deck_w / deck.width)), Image.LANCZOS)
    deck = deck.rotate(tilt, Image.BICUBIC, expand=True)
    dxy = (int(deck_cx - deck.width / 2), deck_y)
    soft_shadow(c, deck, dxy, dx=10, dy=-14, blur=20, alpha=0.32)  # cast up onto the pals
    soft_shadow(c, deck, dxy, dx=-14, dy=8, blur=12, alpha=0.40)  # darker edge off the white Bear
    paste(c, deck, dxy)
    if paw:
        # The Bear's own paw (S10, the screen-right one) gripping the deck's left end.
        import sys
        sys.path.insert(0, CAP)
        import cutout
        full = np.asarray(cutout.matte("S10-black.jpg", "S10-grey.jpg")).astype(np.float32)
        pa = np.asarray(cutout.matte("S10-paws-black.jpg", "S10-paws-grey.jpg").getchannel("A")).astype(np.float32)
        full[..., 3] = np.minimum(full[..., 3], pa)
        full[:, : full.shape[1] // 2, 3] = 0
        p = Image.fromarray(full.clip(0, 255).astype(np.uint8), "RGBA")
        p = p.crop(p.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox())
        p = relight(p.resize((round(p.width * paw_s), round(p.height * paw_s)), Image.LANCZOS), cool=0.14)
        da = np.asarray(deck.getchannel("A")) > 128
        row = int(deck.height * paw_h)
        col = int(np.nonzero(da[row])[0][0])
        xy = (dxy[0] + col - p.width // 2 + 6, dxy[1] + row - p.height // 2)
        soft_shadow(c, p, xy, dx=6, dy=12, blur=10, alpha=0.30)
        paste(c, p, xy)
    return c


def font_path(name):
    for d in ("C:/Windows/Fonts", os.path.expanduser("~/AppData/Local/Microsoft/Windows/Fonts")):
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(name)


def cute_screen(w, h, px=10, ramps=None, ink=None, face="smiley", sky=("#C8F2FF", "#EADCFF")):
    """Spencer 2026-11-21: "less detail on the pocket deck ... cuter matching the vibe of the
    icon". A pastel LCD (sky to lilac), chunky pixels, three big Smileys balls and a pink pair
    merging under one gold sparkle. No type, no panels."""
    gw, gh = w // px, h // px
    t = np.linspace(0, 1, gh)[:, None, None]
    a = np.array(rgb(sky[0])) * (1 - t) + np.array(rgb(sky[1])) * t
    a = np.repeat(a, gw, 1).astype(np.float32)
    yy, xx = np.mgrid[0:gh, 0:gw]
    a -= ((xx * 3 + yy * 5) % 11 == 0)[..., None] * 10  # faint LCD speckle
    lcd = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(lcd)
    pixel_ball(lcd, gw * 0.24, gh - 14.5, 11.5, 4, ramps, ink, face)   # big violet (clear of the icon corner)
    pixel_ball(lcd, gw * 0.80, gh - 11.5, 8.6, 2, ramps, ink, face)    # green
    pixel_ball(lcd, gw * 0.45, gh * 0.40, 8.0, 3, ramps, ink, face)    # pink pair, merging
    pixel_ball(lcd, gw * 0.62, gh * 0.36, 8.0, 3, ramps, ink, face)
    sx, sy = round(gw * 0.535), round(gh * 0.14)      # gold four-point sparkle above the merge
    for i in range(-5, 6):
        k = 5 - abs(i)
        d.line((sx + i, sy - k // 3, sx + i, sy + k // 3), fill=(255, 200, 60))
        d.line((sx - k // 3, sy + i, sx + k // 3, sy + i), fill=(255, 200, 60))
    d.point((sx, sy), fill=(255, 255, 255))
    for ox, oy in ((-9, 6), (10, 3), (6, -3)):
        d.point((sx + ox, sy + oy), fill=(255, 255, 255))
    return lcd.resize((gw * px, gh * px), Image.NEAREST).resize((w, h), Image.NEAREST).convert("RGBA")


def aero_wordmark(lines=("pocket", "pals"), size=150, lead=0.80, rim=13, indent=(0.0, 0.42),
                  outline=0, depth=0):
    """Frutiger Aero type: Nunito Black, lowercase, a deep aqua body (light cyan top to royal
    blue bottom), a wet white gloss over the top half that stops on a hard edge, a light bounce
    glow along the bottom, a thick white rim, a soft white halo and an Ink Navy shadow.
    Each line is coloured from its own letter shapes, so a tall letter tucked under the line
    above (the l in pals) keeps its own gradient. `outline` adds a navy ring outside the white
    rim and `depth` a navy extrusion below it, for a title that stands off busy art."""
    f = ImageFont.truetype(font_path("Nunito-Black.ttf"), size)
    pad = int(size * 0.35) + outline + depth
    W = max(f.getbbox(t)[2] + int(indent[i] * size) for i, t in enumerate(lines)) + pad * 2
    H = int(size * lead * (len(lines) - 1) + size * 1.15) + pad * 2
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    c0, c1, c2 = (np.array(rgb(c), np.float32) for c in ("#8FE4FF", "#1C8CF2", "#0A3A9E"))
    col = np.full((H, W, 3), 255, np.float32)
    mask = Image.new("L", (W, H), 0)
    for i, t in enumerate(lines):
        y = pad + int(i * size * lead)
        lm = Image.new("L", (W, H), 0)
        ImageDraw.Draw(lm).text((pad + int(indent[i] * size), y), t, font=f, fill=255)
        x0, y0, x1, y1 = f.getbbox(t)
        top, bot = y + y0, y + y1
        p = ((yy - top) / (bot - top)).clip(0, 1)[..., None]
        fill = np.where(p < 0.55, c0 + (c1 - c0) * (p / 0.55), c1 + (c2 - c1) * ((p - 0.55) / 0.45))
        inner = np.asarray(lm.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) / 255
        gloss = np.where(p[..., 0] < 0.48, 0.80 - 0.45 * (p[..., 0] / 0.48), 0.0) * inner
        fill = fill + (255 - fill) * gloss[..., None]
        bounce = np.clip((p[..., 0] - 0.78) / 0.22, 0, 1) * 0.38 * inner
        fill = fill + (np.array(rgb("#B8F4FF"), np.float32) - fill) * bounce[..., None]
        m = (np.asarray(lm).astype(np.float32) / 255)[..., None]
        col = fill * m + col * (1 - m)
        mask = Image.fromarray(np.maximum(np.asarray(mask), np.asarray(lm)))
    rim_m = mask.filter(ImageFilter.MaxFilter(rim))
    rim_a = np.asarray(rim_m.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    halo = np.asarray(rim_m.filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255 * 0.55
    alpha = rim_a + halo * (1 - rim_a)
    img = Image.fromarray(np.dstack([col, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")
    base = Image.new("RGBA", (W, H + 16), (0, 0, 0, 0))
    shell = rim_m
    if outline:
        shell = rim_m.filter(ImageFilter.MaxFilter(outline * 2 + 1)).filter(ImageFilter.GaussianBlur(1.0))
    shadow = Image.new("RGBA", (W, H), INK + (0,))
    shadow.putalpha(shell.point(lambda v: int(v * 0.60)).filter(ImageFilter.GaussianBlur(7)))
    base.alpha_composite(shadow, (0, 12 + depth))
    if outline or depth:
        deep = Image.new("RGBA", (W, H), rgb("#06286E") + (0,))
        deep.putalpha(shell)
        for k in range(depth, 0, -1):  # extrusion, darkest at the back
            base.alpha_composite(deep, (0, k))
        ring = Image.new("RGBA", (W, H), rgb("#0B3C9C") + (0,))
        ring.putalpha(shell)
        base.alpha_composite(ring, (0, 0))
    base.alpha_composite(img, (0, 0))
    return base.crop(base.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def icon_i(word_w=470, word_xy=(18, 20)):
    """Spencer 2026-11-21, on H: "less detail on the pocket deck ... cuter matching the vibe of
    the icon? And then some frutiger aero text in the top left, like pocket pals". H's layout
    (A's poses, Bear up, deck tilted) with the cute pastel screen and an Aero "pocket pals"
    wordmark where A's big bubble was; one small bubble moves beside it."""
    c = field(*SKY, floor=0.80)
    put_bubble(c, 478, 300, 54, 0.85)
    bunny = relight(load(os.path.join(CAP, "S2.png"), 1.62, rot=8), cool=0.20)
    bear = relight(load(os.path.join(CAP, "S1-tight.png"), 1.08, rot=-5), cool=0.18)
    paste(c, bunny, (448, 44))
    exy = (-92, 336 - 60)
    soft_shadow(c, bear, exy, dx=14, dy=10, blur=18, alpha=0.26)
    paste(c, bear, exy)
    deck = deck_with_hero(cute_screen)
    deck = deck.resize((700, round(deck.height * 700 / deck.width)), Image.LANCZOS)
    deck = deck.rotate(9.0, Image.BICUBIC, expand=True)
    dxy = (int(710 - deck.width / 2), 640)
    soft_shadow(c, deck, dxy, dx=10, dy=-14, blur=20, alpha=0.32)
    soft_shadow(c, deck, dxy, dx=-14, dy=8, blur=12, alpha=0.40)
    paste(c, deck, dxy)
    wm = aero_wordmark()
    wm = wm.resize((word_w, round(wm.height * word_w / wm.width)), Image.LANCZOS)
    paste(c, wm, word_xy)
    return c


def bubbles_screen(w, h):
    """I's cute screen in the Bubbles ball theme: big Sky, Peach, and a Blossom pair merging,
    on a soft periwinkle LCD so the pale balls hold their edge."""
    return cute_screen(w, h, ramps=[BUBBLES[0], BUBBLES[1], BUBBLES[1], BUBBLES[3], BUBBLES[0]],
                       ink=BUBBLES_INK, face="dots", sky=("#E9F7FF", "#F3ECFF"))


def icon_j(word_w=650, word_xy=(10, 8), outline=5, depth=7, pals_in=1.05):
    """Spencer 2026-11-21, on I: "Make the ball's a different color scheme to match the icon? We
    can make the top left text a bit bigger, slightly overlapping the characters?" I with the
    Bubbles ball theme on the deck and a bigger wordmark laid over the pals' heads."""
    c = field(*SKY, floor=0.80)
    bunny = relight(load(os.path.join(CAP, "S2.png"), 1.62, rot=8), cool=0.20)
    bear = relight(load(os.path.join(CAP, "S1-tight.png"), 1.08, rot=-5), cool=0.18)
    paste(c, bunny, (448, 44))
    exy = (-92, 336 - 60)
    soft_shadow(c, bear, exy, dx=14, dy=10, blur=18, alpha=0.26)
    paste(c, bear, exy)
    deck = deck_with_hero(bubbles_screen)
    deck = deck.resize((700, round(deck.height * 700 / deck.width)), Image.LANCZOS)
    deck = deck.rotate(9.0, Image.BICUBIC, expand=True)
    dxy = (int(710 - deck.width / 2), 640)
    soft_shadow(c, deck, dxy, dx=10, dy=-14, blur=20, alpha=0.32)
    soft_shadow(c, deck, dxy, dx=-14, dy=8, blur=12, alpha=0.40)
    paste(c, deck, dxy)
    wm = aero_wordmark(lead=0.72, outline=outline, depth=depth, indent=(0.0, pals_in))  # navy ring + extrusion; pals over the ear, off the beanie
    wm = wm.resize((word_w, round(wm.height * word_w / wm.width)), Image.LANCZOS)
    paste(c, wm, word_xy)
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
    names = {"A": "Icon A  two pals", "B": "Icon B  one pal", "C": "Icon C  pocket deck", "D": "Icon D  show and tell", "E": "Icon E  fisheye", "F": "Icon F  lens on the deck", "G": "Icon G  framed like A", "H": "Icon H  A + hero deck", "I": "Icon I  aero wordmark", "J": "Icon J  bubbles balls"}
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
    for k, fn, master in (("A", icon_a, False), ("B", icon_b, True), ("C", icon_c, True), ("D", icon_d, False), ("E", icon_e, False), ("F", icon_f, True), ("G", icon_g, False), ("H", icon_h, False), ("I", icon_i, False), ("J", icon_j, False)):
        big = fn().convert("RGB")
        if master:
            big.save(os.path.join(HERE, f"icon-{k}-1024.png"))
        icons[k] = big.resize((512, 512), Image.LANCZOS)
        icons[k].save(os.path.join(HERE, f"icon-{k}.png"))
    icons = {k: v.convert("RGBA") for k, v in icons.items()}
    sheet({k: icons[k] for k in "ABC"}).save(os.path.join(HERE, "icons-ABC.png"))
    sheet({k: icons[k] for k in "CD"}).save(os.path.join(HERE, "icons-CD.png"))
    sheet({k: icons[k] for k in "EF"}).save(os.path.join(HERE, "icons-EF.png, icons-AG.png, icons-AH.png, icons-HI.png, icons-IJ.png, deck-hero-screen.png"))
    sheet({k: icons[k] for k in "AG"}).save(os.path.join(HERE, "icons-AG.png, icons-AH.png, icons-HI.png, icons-IJ.png, deck-hero-screen.png"))
    sheet({k: icons[k] for k in "AH"}).save(os.path.join(HERE, "icons-AH.png"))
    sheet({k: icons[k] for k in "HI"}).save(os.path.join(HERE, "icons-HI.png"))
    sheet({k: icons[k] for k in "IJ"}).save(os.path.join(HERE, "icons-IJ.png"))
    deck_with_hero().save(os.path.join(HERE, "deck-hero-screen.png"))
    print("wrote icon-A..J.png, icon-B/C/F-1024.png, icons-ABC.png, icons-CD.png, icons-EF.png, icons-AG.png, icons-AH.png, icons-HI.png, icons-IJ.png, deck-hero-screen.png")
