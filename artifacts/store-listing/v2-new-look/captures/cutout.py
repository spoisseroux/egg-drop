"""Difference-matte cut-outs for the v2-new-look shot list (S1 to S9).

Each shot is one frozen Studio Play frame captured twice, over a dark and a light
backdrop (pets: black and grey Neon; deck: black and white full-screen frames).
The game's grade adds a soft vignette and haze, so the backdrop is not flat: its
colour under the subject is a smooth polynomial fitted to the pixels around it.

    alpha = 1 - (light - dark) . (Bl - Bd) / |Bl - Bd|^2
    colour = (dark - (1 - alpha) * Bd) / alpha

Run: python cutout.py            (all shots in SHOTS that have raw pairs)
     python cutout.py S1 S2      (some)
Writes S*.png (RGBA, trimmed with padding) and contact.png beside this file.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

# shot -> (dark raw, light raw). S4 (three-quarter) is a perspective warp of S4-straight.
# UI shots (the deck) are exact alpha composites over flat frames: no speck or edge cleanup.
UI_SHOTS = {"S4-straight"}
SHOTS = {
    "S1": ("S1-black.jpg", "S1-grey.jpg"),
    "S2": ("S2-black.jpg", "S2-grey.jpg"),
    "S3": ("S3-black.jpg", "S3-grey.jpg"),
    "S1-tight": ("S1-tight-black.jpg", "S1-tight-grey.jpg"),
    "S4-straight": ("S4-black.jpg", "S4-white.jpg"),
    "S5": ("S5-black.jpg", "S5-grey.jpg"),
    "S6": ("S6-black.jpg", "S6-grey.jpg"),
    "S7": ("S7-black.jpg", "S7-grey.jpg"),
    "S8": ("S8-black.jpg", "S8-grey.jpg"),
    "S9": ("S9-black.jpg", "S9-grey.jpg"),
    # S10: front-on Bear, paws raised forward to hold the deck (icon D); S10-paws is the same
    # frame with every part but HandL/HandR hidden, used only as a mask for the paws.
    "S10": ("S10-black.jpg", "S10-grey.jpg"),
    "S10-paws": ("S10-paws-black.jpg", "S10-paws-grey.jpg"),
    # S11: close Rose Bunny (3 rose, beads), turned toward the Bear, same camera as S10 (icon E).
    "S11": ("S11-black.jpg", "S11-grey.jpg"),
    # S12-S14: full-body pets framed to their own bounding box (about 650 px tall) for the
    # 1920x1080 thumbnails and ads. S12 Bear 3/4 standing, S13 Rose Bunny 3/4, S14 Bunny hop pose.
    "S12": ("S12-black.jpg", "S12-grey.jpg"),
    "S13": ("S13-black.jpg", "S13-grey.jpg"),
    "S14": ("S14-black.jpg", "S14-grey.jpg"),
}


def load(name):
    return np.asarray(Image.open(os.path.join(RAW, name)).convert("RGB")).astype(np.float64)


def poly_terms(u, v, deg=4):
    cols = []
    for i in range(deg + 1):
        for j in range(deg + 1 - i):
            cols.append((u ** i) * (v ** j))
    return np.stack(cols, -1)


def fit_backdrop(img, mask, deg=4, step=3):
    """Per-channel smooth fit of img over mask; returns the full-frame estimate."""
    h, w, _ = img.shape
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx / (w - 1)) * 2 - 1
    v = (yy / (h - 1)) * 2 - 1
    sel = mask[::step, ::step]
    A = poly_terms(u[::step, ::step][sel], v[::step, ::step][sel], deg)
    full = poly_terms(u, v, deg)
    out = np.empty_like(img)
    for c in range(3):
        b = img[::step, ::step, c][sel]
        coef, *_ = np.linalg.lstsq(A, b, rcond=None)
        out[..., c] = full @ coef
    return out


def box_blur(x, r):
    """Separable box blur (radius r) with edge padding, numpy only."""
    k = 2 * r + 1
    p = np.pad(x, r, mode="edge")
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def matte(dark, light, ui=False):
    K, G = load(dark), load(light)
    D = (G - K).mean(2)
    span = np.percentile(D, 95)
    # Backdrop = full separation, eroded well away from the subject's edge.
    bg = D > 0.85 * span
    bgimg = Image.fromarray((bg * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(15))
    bg = np.asarray(bgimg) > 128
    Bd, Bl = fit_backdrop(K, bg), fit_backdrop(G, bg)
    sep = Bl - Bd
    a = 1.0 - ((G - K) * sep).sum(2) / np.maximum((sep * sep).sum(2), 1e-6)
    # JPEG noise: snap near-0 and near-1.
    a = np.clip((a - 0.035) / 0.93, 0, 1)
    if ui:
        safe = np.maximum(a, 1e-3)[..., None]
        rgb = np.clip((K - (1 - a[..., None]) * Bd) / safe, 0, 255)
        return Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), "RGBA")
    # Specks: drop alpha islands that are not part of the solid body.
    solid = Image.fromarray((a > 0.5).astype(np.uint8) * 255)
    near = np.asarray(solid.filter(ImageFilter.MaxFilter(9))) > 0
    a = np.where(near, a, 0)
    safe = np.maximum(a, 1e-3)[..., None]
    rgb = np.clip((K - (1 - a[..., None]) * Bd) / safe, 0, 255)
    # Edge colour: below 0.35 alpha the division is noise; borrow the colour of the
    # nearest solid pixels (a blurred, normalised solid-colour field).
    w = (a > 0.6).astype(np.float64)
    blur = lambda x: box_blur(box_blur(x, 4), 4)
    wsum = blur(w)
    field = np.stack([blur(rgb[..., c] * w) for c in range(3)], -1) / np.maximum(wsum, 1e-4)[..., None]
    t = np.clip((a - 0.15) / 0.45, 0, 1)[..., None]
    rgb = np.where(wsum[..., None] > 1e-3, rgb * t + field * (1 - t), rgb)
    out = np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def trim(img, pad=6):
    bbox = img.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    return img.crop((max(0, x0 - pad), max(0, y0 - pad), min(img.width, x1 + pad), min(img.height, y1 + pad)))


def three_quarter(img, yaw=25.0, pitch=10.0, fov=35.0, frame_h=734):
    """S4: the deck is a flat sprite, so a 3D turn of it is exactly a homography.
    The straight-on cut-out is treated as a plane facing a FOV-35 camera at the
    distance where it projects 1:1, then yawed `yaw` degrees to its own left (its
    right-hand edge, on the viewer's right, recedes) and pitched `pitch` degrees with
    the top edge toward the camera. Flip a sign to change either convention."""
    f = (frame_h / 2) / np.tan(np.radians(fov / 2))
    w, h = img.size
    th, ph = np.radians(yaw), np.radians(pitch)
    # Deck plane coords: x right, y up, z away from camera; plane at z = f.
    # right edge (x>0) gets z>0 (recedes): z' = x*sin(th)
    ry = np.array([[np.cos(th), 0, -np.sin(th)], [0, 1, 0], [np.sin(th), 0, np.cos(th)]])
    # top edge (y>0) gets z<0 (comes toward the camera): z' = -y*sin(ph)
    rx = np.array([[1, 0, 0], [0, np.cos(ph), np.sin(ph)], [0, -np.sin(ph), np.cos(ph)]])
    R = ry @ rx
    src = [(0, 0), (w, 0), (w, h), (0, h)]
    dst = []
    for x, y in src:
        p = R @ np.array([x - w / 2, h / 2 - y, 0.0]) + np.array([0, 0, f])
        dst.append((f * p[0] / p[2], -f * p[1] / p[2]))
    dst = np.array(dst)
    off = dst.min(0) - 4
    dst = dst - off
    size = tuple(int(np.ceil(v)) + 4 for v in dst.max(0))
    # Coefficients map output (dst) -> input (src) for PIL's PERSPECTIVE transform.
    A, B = [], []
    for (X, Y), (x, y) in zip(dst, src):
        A.append([X, Y, 1, 0, 0, 0, -x * X, -x * Y]); B.append(x)
        A.append([0, 0, 0, X, Y, 1, -y * X, -y * Y]); B.append(y)
    coef = np.linalg.solve(np.array(A, float), np.array(B, float))
    # Warp premultiplied colour so edges do not pick up black.
    arr = np.asarray(img).astype(np.float64)
    a = arr[..., 3:4] / 255
    pm = np.dstack([arr[..., :3] * a, arr[..., 3:4]]).astype(np.uint8)
    out = Image.fromarray(pm, "RGBA").transform(size, Image.PERSPECTIVE, tuple(coef), Image.BICUBIC)
    o = np.asarray(out).astype(np.float64)
    oa = o[..., 3:4] / 255
    rgb = np.clip(o[..., :3] / np.maximum(oa, 1e-3), 0, 255)
    return trim(Image.fromarray(np.dstack([rgb, o[..., 3:4]]).astype(np.uint8), "RGBA"))


def contact(names):
    tiles = []
    for n in names:
        p = os.path.join(HERE, n + ".png")
        if os.path.exists(p):
            tiles.append((n, Image.open(p)))
    if not tiles:
        return
    th = 420
    cells = []
    for n, im in tiles:
        s = th / im.height
        im2 = im.resize((max(1, int(im.width * s)), th), Image.LANCZOS)
        cells.append((n, im, im2))
    pad = 24
    cols = 3
    rows = (len(cells) + cols - 1) // cols
    cw = max(c[2].width for c in cells) + pad
    sheet = Image.new("RGB", (cols * cw + pad, rows * (th * 2 + 70) + pad), (40, 44, 52))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, (n, im, im2) in enumerate(cells):
        x = pad + (i % cols) * cw
        y = pad + (i // cols) * (th * 2 + 70)
        # Checker and sky-blue swatches show halos on both light and dark.
        for k, bgc in enumerate([None, (120, 190, 255)]):
            yy = y + 30 + k * (th + 10)
            if bgc is None:
                chk = Image.new("RGB", im2.size, (200, 200, 200))
                cd = ImageDraw.Draw(chk)
                for cx in range(0, im2.width, 16):
                    for cy in range(0, im2.height, 16):
                        if (cx // 16 + cy // 16) % 2:
                            cd.rectangle([cx, cy, cx + 15, cy + 15], fill=(150, 150, 150))
                base = chk
            else:
                base = Image.new("RGB", im2.size, bgc)
            base.paste(im2, (0, 0), im2)
            sheet.paste(base, (x, yy))
        d.text((x, y + 2), f"{n}  {im.width}x{im.height}", fill=(255, 255, 255), font=font)
    sheet.save(os.path.join(HERE, "contact.png"))


def main(args):
    names = args or list(SHOTS)
    for n in names:
        dark, light = SHOTS[n]
        if not (os.path.exists(os.path.join(RAW, dark)) and os.path.exists(os.path.join(RAW, light))):
            print(n, "missing raw pair")
            continue
        img = trim(matte(dark, light, ui=n in UI_SHOTS))
        img.save(os.path.join(HERE, n + ".png"))
        print(n, img.size)
        if n == "S4-straight":
            w = three_quarter(img)
            w.save(os.path.join(HERE, "S4.png"))
            print("S4", w.size)
    contact(["S1", "S2", "S3", "S4", "S4-straight", "S5", "S6", "S7", "S8", "S9", "S10", "S11", "S12", "S13", "S14"])


if __name__ == "__main__":
    main(sys.argv[1:])
