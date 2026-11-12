"""Pocket Deck Slim: 2D shell sprites and the shell layout manifest.

Run: python scripts/deck_art/build_shell.py
Writes assets/deck/shell/*.png and shell.json. The sprites are neutral greys so Roblox can tint
them with ImageColor3 (band metal, button cap, d-pad arrows, LED).
"""
from __future__ import annotations

import json
import math

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from common import ASSETS, DECK, Cv, gradient, hx, mix, ramp, rounded_mask, wordmark_cells, WORD_W, WORD_H, egg_pts

OUT = ASSETS / "shell"
METAL = [(0, "#FDFDFF"), (0.07, "#E3E6EC"), (0.45, "#B4B9C3"), (0.9, "#858B97"), (1, "#666B76")]
METAL_IN = [(0, "#D4D8E0"), (0.5, "#C0C5CE"), (1, "#9AA0AB")]


def tint(img, color):
    """Multiply RGB by a colour, like ImageColor3."""
    c = hx(color) if isinstance(color, str) else color
    a = np.asarray(img).astype(np.float32)
    for i in range(3):
        a[..., i] *= c[i] / 255
    return Image.fromarray(np.clip(a + .5, 0, 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ band
def band(wu, hu, k, r=DECK["bandRadius"]):
    cv = Cv(wu * k, hu * k, z=2)
    cv.grad_rr(0, 0, wu * k, hu * k, r * k, METAL)
    cv.grad_rr(5 * k, 5 * k, (wu - 10) * k, (hu - 10) * k, (r - 5) * k, METAL_IN)
    cv.rr(0, 0, wu * k, hu * k, r * k, stroke=(40, 44, 54, 150), sw=max(1, 1.5 * k))
    cv.rr(2 * k, 2 * k, (wu - 4) * k, (hu - 4) * k, (r - 2) * k, stroke=(255, 255, 255, 90), sw=max(1, 1.2 * k))
    # seam where the plate drops in
    t = DECK["bandThickness"]
    cv.rr((t - 3) * k, (t - 3) * k, (wu - 2 * t + 6) * k, (hu - 2 * t + 6) * k, (DECK["plateRadius"] + 3) * k, fill=(22, 24, 30, 255))
    return cv.out()


def shoulder(k, wu=220, hu=24):
    cv = Cv(wu * k, hu * k, z=2)
    cv.grad_rr(0, 0, wu * k, (hu + 14) * k, 13 * k, [(0, "#FFFFFF"), (0.35, "#D0D4DC"), (1, "#8C929D")])
    cv.rr(0, 0, wu * k, (hu + 14) * k, 13 * k, stroke=(40, 44, 54, 140), sw=max(1, 1.5 * k))
    cv.rr(16 * k, 5 * k, (wu - 32) * k, 3 * k, 1.5 * k, fill=(255, 255, 255, 120))
    return cv.out()


# ------------------------------------------------------------------ plate overlay (hardware detail)
def plate_overlay(k):
    px, py, pw, ph = DECK["plate"]
    W, H = round(pw * k), round(ph * k)
    cv = Cv(W, H, z=2)
    U = lambda v: v * k
    X = lambda x: (x - px) * k
    Y = lambda y: (y - py) * k
    # moulded depth: light lip on top, shade below
    cv.paste(gradient(W * 2, int(H * 2 * .30), [(0, (255, 255, 255, 70)), (1, (255, 255, 255, 0))]), 0, 0, raw=True)
    sh = gradient(W * 2, int(H * 2 * .38), [(0, (0, 0, 0, 0)), (1, (0, 0, 0, 78))])
    cv.paste(sh, 0, H * 2 - sh.height, raw=True)
    # one diagonal gloss sweep
    g = Image.new("L", (W * 2, H * 2), 0)
    d = ImageDraw.Draw(g)
    for x0, wd, a in ((0.16, 0.085, 46), (0.27, 0.03, 30)):
        d.polygon([(W * 2 * x0 + H * .7, 0), (W * 2 * (x0 + wd) + H * .7, 0), (W * 2 * (x0 + wd) - H * .5, H * 2), (W * 2 * x0 - H * .5, H * 2)], fill=a)
    g = g.filter(ImageFilter.GaussianBlur(10 * k))
    fade = np.asarray(gradient(W * 2, H * 2, [(0, (255, 255, 255, 255)), (0.75, (255, 255, 255, 50)), (1, (255, 255, 255, 0))]).getchannel("A")).astype(np.float32) / 255
    gl = Image.new("RGBA", (W * 2, H * 2), (255, 255, 255, 0))
    gl.putalpha(Image.fromarray((np.asarray(g) * fade).astype(np.uint8)))
    cv.paste(gl, 0, 0, raw=True)

    # recess under the glass
    gx, gy, gw, gh = DECK["glass"]
    cv.shadow(X(gx), Y(gy), U(gw), U(gh), U(DECK["glassRadius"]), blur=U(16), color=(0, 0, 0, 150), dy=U(5), spread=U(4))
    cv.rr(X(gx - 4), Y(gy - 4), U(gw + 8), U(gh + 8), U(DECK["glassRadius"] + 4), stroke=(255, 255, 255, 60), sw=max(1, U(2)))

    def well(cx, cy, dia):
        r = dia / 2
        cv.shadow(X(cx - r), Y(cy - r), U(dia), U(dia), U(r), blur=U(10), color=(0, 0, 0, 120), dy=U(3))
        cv.ell(X(cx), Y(cy), U(r), fill=(0, 0, 0, 86))
        cv.arc(X(cx), Y(cy), U(r), 20, 160, (255, 255, 255, 96), max(1, U(2.5)))
        cv.arc(X(cx), Y(cy), U(r), 200, 340, (0, 0, 0, 90), max(1, U(2.5)))

    well(*DECK["dpad"]["center"], DECK["dpad"]["well"])
    well(*DECK["buttonA"]["center"], DECK["buttonA"]["diameter"] + 22)
    well(*DECK["buttonB"]["center"], DECK["buttonB"]["diameter"] + 18)
    mx, my, mw, mh = DECK["menu"]
    cv.rr(X(mx - 5), Y(my - 5), U(mw + 10), U(mh + 10), U(mh / 2 + 5), fill=(0, 0, 0, 80))
    cv.rr(X(mx - 5), Y(my - 5), U(mw + 10), U(mh + 10), U(mh / 2 + 5), stroke=(255, 255, 255, 44), sw=max(1, U(1.5)))

    # thumb screws
    for sx, sy in DECK["screws"]:
        cv.ell(X(sx), Y(sy), U(15), fill=(0, 0, 0, 96))
        cv.grad_rr(X(sx - 11), Y(sy - 11), U(22), U(22), U(11), [(0, "#F4F6FA"), (1, "#8E94A0")])
        cv.line([(X(sx - 6), Y(sy + 3)), (X(sx + 6), Y(sy - 3))], (40, 44, 54, 220), max(1, U(2.6)))
    # seed speaker: five seeds in a loose cluster
    cx, cy = DECK["speaker"]["center"]
    for dx, dy, rot in ((-34, -6, -20), (0, -16, 0), (34, -6, 20), (-18, 22, -10), (18, 22, 10)):
        pts = []
        for a, b in egg_pts(0, 0, 9.5, 14):
            c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
            pts.append((X(cx + dx + a * c - b * s), Y(cy + dy + a * s + b * c)))
        cv.poly([(p[0], p[1] + U(2)) for p in pts], (255, 255, 255, 70))
        cv.poly(pts, (10, 11, 14, 215))
    # LED socket
    lx, ly = DECK["led"]["center"]
    cv.ell(X(lx), Y(ly), U(10), fill=(0, 0, 0, 110))
    # plate edge
    cv.rr(0, 0, W, H, U(DECK["plateRadius"]), stroke=(0, 0, 0, 70), sw=max(1, U(2.5)))
    cv.rr(U(3), U(3), W - U(6), H - U(6), U(DECK["plateRadius"] - 3), stroke=(255, 255, 255, 64), sw=max(1, U(1.6)))
    out = cv.out()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), rounded_mask(W, H, round(DECK["plateRadius"] * k))))
    return out


# ------------------------------------------------------------------ glass
def wordmark_sprite(p=8):
    """The pixel wordmark, white on transparent, p pixels per cell (41 x 16 cells). Tint it in Roblox."""
    im = Image.new("RGBA", (WORD_W * p, WORD_H * p), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    for c, r, kind in wordmark_cells():
        if kind != "glint":
            d.rectangle([c * p, r * p, c * p + p - 1, r * p + p - 1], fill=(255, 255, 255, 255))
    return im


def glass(wu, hu, k, r=DECK["glassRadius"]):
    cv = Cv(wu * k, hu * k, z=2)
    cv.grad_rr(0, 0, wu * k, hu * k, r * k, [(0, "#16181D"), (0.5, "#08090B"), (1, "#020203")])
    cv.rr(0, 0, wu * k, hu * k, r * k, stroke=(255, 255, 255, 46), sw=max(1, 1.5 * k))
    cv.rr(2.5 * k, 2.5 * k, (wu - 5) * k, (hu - 5) * k, (r - 2.5) * k, stroke=(0, 0, 0, 200), sw=max(1, 2 * k))
    return cv.out()


def glare(k):
    _, _, wu, hu = DECK["lcd"]
    W, H = round(wu * k), round(hu * k)
    g = Image.new("L", (W * 2, H * 2), 0)
    d = ImageDraw.Draw(g)
    for x0, wd, a in ((0.52, 0.16, 26), (0.72, 0.05, 18)):
        d.polygon([(W * 2 * x0 + H * .8, 0), (W * 2 * (x0 + wd) + H * .8, 0), (W * 2 * (x0 + wd) - H * .6, H * 2), (W * 2 * x0 - H * .6, H * 2)], fill=a)
    g = g.filter(ImageFilter.GaussianBlur(14 * k)).resize((W, H), Image.LANCZOS)
    fade = np.asarray(gradient(W, H, [(0, (0, 0, 0, 255)), (0.6, (0, 0, 0, 40)), (1, (0, 0, 0, 0))]).getchannel("A")).astype(np.float32) / 255
    out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    out.putalpha(ImageChops.multiply(Image.fromarray((np.asarray(g) * fade).astype(np.uint8)), rounded_mask(W, H, round(DECK["lcdRadius"] * k))))
    return out


# ------------------------------------------------------------------ round buttons
LIP = 0.07  # the cap's lower edge, as a share of the diameter


def button_base(d, pressed=False):
    """Neutral glossy dome with a lower edge. Canvas is d wide and d * (1 + LIP) tall."""
    z = 3
    D, Ht = d * z, int(round(d * (1 + LIP) * z))
    ys, xs = np.mgrid[0:Ht, 0:D].astype(np.float32)
    r = D / 2 - z
    top = (LIP * d * z) if pressed else 0
    out = np.zeros((Ht, D, 4), dtype=np.float32)

    def disc(cy, shade):
        dist = np.sqrt((xs - D / 2) ** 2 + (ys - cy) ** 2)
        a = np.clip(r - dist + .5, 0, 1)
        return a, dist
    if not pressed:  # lower edge
        a, _ = disc(D / 2 + LIP * d * z, None)
        for i in range(3):
            out[..., i] = out[..., i] * (1 - a) + 122 * a
        out[..., 3] = np.maximum(out[..., 3], a * 255)
    a, dist = disc(D / 2 + top, None)
    cy = D / 2 + top
    lit = np.clip(1 - np.sqrt((xs - D * .40) ** 2 + (ys - (cy - D * .16)) ** 2) / (r * 1.5), 0, 1)
    v = 168 + 87 * lit ** 0.9
    v *= 1 - 0.22 * np.clip((dist / r) ** 6, 0, 1)
    if pressed:
        v *= 0.86
    for i in range(3):
        out[..., i] = out[..., i] * (1 - a) + v * a
    out[..., 3] = np.maximum(out[..., 3], a * 255)
    return Image.fromarray(np.clip(out + .5, 0, 255).astype(np.uint8), "RGBA").resize((d, int(round(d * (1 + LIP)))), Image.LANCZOS)


def button_gloss(d, pressed=False):
    z = 3
    D, Ht = d * z, int(round(d * (1 + LIP) * z))
    top = (LIP * d * z) if pressed else 0
    ys, xs = np.mgrid[0:Ht, 0:D].astype(np.float32)
    r = D / 2 - z
    cy = D / 2 + top
    inside = np.clip(r * .93 - np.sqrt((xs - D / 2) ** 2 + (ys - cy) ** 2), 0, 1)
    ex = np.clip(1 - (((xs - D / 2) / (r * .66)) ** 2 + ((ys - (cy - r * .47)) / (r * .40)) ** 2), 0, 1)
    a = inside * np.clip(ex * 1.6, 0, 1) * np.clip(1 - (ys - (cy - r * .9)) / (r * .9), 0, 1) * (150 if not pressed else 90)
    rim = np.clip(1 - np.abs(np.sqrt((xs - D / 2) ** 2 + (ys - cy) ** 2) - r * .955) / (z * 1.3), 0, 1) * np.clip((ys - cy) / r * -1 + .1, 0, 1) * 120
    out = np.zeros((Ht, D, 4), dtype=np.float32)
    out[..., :3] = 255
    out[..., 3] = np.clip(a + rim, 0, 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA").resize((d, int(round(d * (1 + LIP)))), Image.LANCZOS)


# ------------------------------------------------------------------ d-pad (a round four-way aim disc)
def dpad_disc(d):
    cv = Cv(d, d, z=3)
    r = d / 2 - 1
    cv.grad_rr(1, 1, d - 2, d - 2, r, [(0, "#3A3E47"), (0.5, "#1D1F25"), (1, "#0D0E11")])
    cv.rr(1, 1, d - 2, d - 2, r, stroke=(255, 255, 255, 40), sw=max(1, d * .008))
    cv.grad_rr(d * .09, d * .09, d * .82, d * .82, d * .41, [(0, "#101115"), (1, "#2A2D35")])
    cv.rr(d * .09, d * .09, d * .82, d * .82, d * .41, stroke=(0, 0, 0, 120), sw=max(1, d * .01))
    cv.ell(d / 2, d / 2, d * .085, fill=(8, 9, 11, 255))
    cv.arc(d / 2, d / 2, d * .085, 20, 160, (255, 255, 255, 50), max(1, d * .008))
    return cv.out()


def dpad_arrows(d):
    cv = Cv(d, d, z=3)
    c, off, s = d / 2, d * .285, d * .085
    for ang in (0, 90, 180, 270):
        a = math.radians(ang)
        ux, uy = math.cos(a), math.sin(a)
        vx, vy = -uy, ux
        tip = (c + ux * (off + s * .75), c + uy * (off + s * .75))
        b1 = (c + ux * (off - s * .55) + vx * s, c + uy * (off - s * .55) + vy * s)
        b2 = (c + ux * (off - s * .55) - vx * s, c + uy * (off - s * .55) - vy * s)
        cv.poly([tip, b1, b2], (255, 255, 255, 255))
        cv.line([tip, b1, b2, tip], (255, 255, 255, 255), d * .022)
    return cv.out()


def dpad_press(d):
    """Highlight wedge for the UP direction. Rotate by 90, 180, 270 for right, down, left."""
    z = 2
    D = d * z
    ys, xs = np.mgrid[0:D, 0:D].astype(np.float32)
    dx, dy = xs - D / 2, ys - D / 2
    dist = np.sqrt(dx ** 2 + dy ** 2)
    ang = np.degrees(np.arctan2(dx, -dy))
    wedge = np.clip((44 - np.abs(ang)) / 6, 0, 1) * np.clip((D * .41 - dist) / (z * 2), 0, 1) * np.clip((dist - D * .10) / (z * 2), 0, 1)
    out = np.zeros((D, D, 4), dtype=np.float32)
    out[..., :3] = 255
    out[..., 3] = wedge * 54
    return Image.fromarray(out.astype(np.uint8), "RGBA").resize((d, d), Image.LANCZOS)


def menu_pill(wu, hu, k):
    cv = Cv(wu * k, hu * k, z=3)
    cv.grad_rr(0, 0, wu * k, hu * k, hu * k / 2, [(0, "#353941"), (1, "#15161A")])
    cv.rr(0, 0, wu * k, hu * k, hu * k / 2, stroke=(255, 255, 255, 46), sw=max(1, 1.5 * k))
    return cv.out()


def led_glow(d=64):
    ys, xs = np.mgrid[0:d, 0:d].astype(np.float32)
    dist = np.sqrt((xs - d / 2 + .5) ** 2 + (ys - d / 2 + .5) ** 2) / (d / 2)
    a = np.clip(1 - dist, 0, 1) ** 2 * 150 + np.clip((0.2 - dist) / 0.04, 0, 1) * 255
    out = np.zeros((d, d, 4), dtype=np.float32)
    out[..., :3] = 255
    out[..., 3] = np.clip(a, 0, 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def soft_shadow(wu, hu, r, k, blur=36, alpha=130, pad=90):
    cv = Cv((wu + 2 * pad) * k, (hu + 2 * pad) * k, z=1)
    cv.shadow(pad * k, pad * k, wu * k, hu * k, r * k, blur=blur * k, color=(0, 0, 0, alpha), dy=0)
    return cv.out()


# ------------------------------------------------------------------ composer (also proves the kit assembles)
PAD = 90  # margin around the deck in a composed image, in deck units


def compose_deck(plate=None, accent="#76F6B0", ink="#0E0F12", band_tint="#FFFFFF", k=1.0, lcd=None, press=None, shadow=True, lcd_fill="#0C0D10", engrave=("#0E0F12", 0.42)):
    """Return the whole deck as RGBA, with PAD units of margin on every side.

    plate: RGBA faceplate texture (any size) or None for a flat grey plate. lcd: RGBA image drawn into the LCD rect.
    """
    Wd, Hd = DECK["size"]
    cv = Cv((Wd + 2 * PAD) * k, (Hd + 2 * PAD) * k, z=1)
    o = PAD * k
    P = lambda img, x, y: cv.paste(img, round(o + x * k), round(o + y * k), raw=True)
    if shadow:
        P(soft_shadow(Wd, Hd, DECK["bandRadius"], k), -PAD, -PAD + 22)
    for key in ("shoulderL", "shoulderR"):
        x, y, w, h = DECK[key]
        P(tint(shoulder(k, w, h), band_tint), x, y)
    P(tint(band(Wd, Hd, k), band_tint), 0, 0)
    px, py, pw, ph = DECK["plate"]
    size = (round(pw * k), round(ph * k))
    if plate is None:
        plate = Image.new("RGBA", size, hx("#8A909A"))
    pl = plate.resize(size, Image.LANCZOS)
    pl.putalpha(ImageChops.multiply(pl.getchannel("A"), rounded_mask(size[0], size[1], round(DECK["plateRadius"] * k))))
    P(pl, px, py)
    P(plate_overlay(k), px, py)
    # engraved wordmark: a soft opposite-tone edge under the main tone
    wp = DECK["wordmark"]["pixel"]
    wsize = (max(1, round(WORD_W * wp * k)), max(1, round(WORD_H * wp * k)))
    wm = wordmark_sprite(8).resize(wsize, Image.LANCZOS if k < 1.3 else Image.NEAREST)
    wx, wy = DECK["wordmark"]["center"][0] - WORD_W * wp / 2, DECK["wordmark"]["center"][1] - WORD_H * wp / 2
    dark = hx(engrave[0])[0] < 128
    for col, alpha, off in ((("#FFFFFF" if dark else "#000000"), 0.30 if dark else 0.45, 2), (engrave[0], engrave[1], 0)):
        layer = tint(wm, col)
        layer.putalpha(layer.getchannel("A").point(lambda v, a=alpha: int(v * a)))
        P(layer, wx + off * 0.8, wy + off)
    gx, gy, gw, gh = DECK["glass"]
    P(glass(gw, gh, k), gx, gy)
    lx, ly, lw, lh = DECK["lcd"]
    lsize = (round(lw * k), round(lh * k))
    screen = Image.new("RGBA", lsize, hx(lcd_fill))
    if lcd is not None:
        screen.alpha_composite(lcd.resize(lsize, Image.LANCZOS).convert("RGBA"))
    screen.putalpha(rounded_mask(lsize[0], lsize[1], round(DECK["lcdRadius"] * k)))
    P(screen, lx, ly)
    P(glare(k), lx, ly)
    # controls
    dc, dd = DECK["dpad"]["center"], DECK["dpad"]["diameter"]
    dpx = round(dd * k)
    P(dpad_disc(dpx), dc[0] - dd / 2, dc[1] - dd / 2)
    P(tint(dpad_arrows(dpx), accent), dc[0] - dd / 2, dc[1] - dd / 2)
    if press in ("up", "right", "down", "left"):
        P(dpad_press(dpx).rotate(-90 * ("up", "right", "down", "left").index(press)), dc[0] - dd / 2, dc[1] - dd / 2)
    mx, my, mw, mh = DECK["menu"]
    P(menu_pill(mw, mh, k), mx, my)
    cv.text(o + (mx + mw / 2) * k, o + (my + mh / 2) * k, "MENU", "b", 19 * k, (230, 233, 238, 255), "mm", tracking=1.6 * k)
    for key, col, letter, lcol in (("buttonA", accent, "A", ink), ("buttonB", "#3A3E47", "B", "#C3C8D0")):
        c, d = DECK[key]["center"], DECK[key]["diameter"]
        dp = round(d * k)
        pressed = press == letter
        P(tint(button_base(dp, pressed), col), c[0] - d / 2, c[1] - d / 2)
        P(button_gloss(dp, pressed), c[0] - d / 2, c[1] - d / 2)
        cv.text(o + c[0] * k, o + (c[1] + (d * LIP if pressed else 0) + d * .02) * k, letter, "xb", d * .46 * k, lcol, "mm")
    lc = DECK["led"]["center"]
    g = tint(led_glow(64), accent).resize((round(34 * k), round(34 * k)), Image.LANCZOS)
    P(g, lc[0] - 17, lc[1] - 17)
    return cv.out()


# ------------------------------------------------------------------ export
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    Wd, Hd = DECK["size"]
    files = {}

    def save(name, img, **meta):
        img.save(OUT / name)
        files[name] = {"size": list(img.size), **meta}

    t, pr = DECK["bandThickness"], DECK["plateRadius"]
    save("band.png", band(Wd, Hd, 0.64), rect=[0, 0, Wd, Hd], z=2, tint="band colour (silver #FFFFFF, gunmetal #6F7480, gold #EBC978, rose #F0B8B0)")
    b9 = band(360, 360, 1.0)
    save("band-9slice.png", b9, rect=[0, 0, Wd, Hd], z=2, sliceCenter=[170, 170, 190, 190], sliceScale="deckWidth / 1600", tint="band colour", note="same art as band.png for decks that are not exactly 2:1")
    save("plate-overlay.png", plate_overlay(1024 / DECK["plate"][2]), rect=DECK["plate"], z=4, note="hardware detail over any faceplate: lip, shade, gloss, glass recess, wells, screws, seed speaker, LED socket. Do not tint.")
    gx, gy, gw, gh = DECK["glass"]
    save("glass.png", glass(gw, gh, 1.0), rect=DECK["glass"], z=5)
    save("glass-9slice.png", glass(120, 120, 1.0), rect=DECK["glass"], z=5, sliceCenter=[50, 50, 70, 70], sliceScale="deckWidth / 1600")
    save("glass-glare.png", glare(1.0), rect=DECK["lcd"], z=40, note="above all LCD content, ImageTransparency 0; hide under Reduced Effects if it hurts contrast")
    for key, d in (("button-base.png", (False, button_base)), ("button-base-pressed.png", (True, button_base)), ("button-gloss.png", (False, button_gloss)), ("button-gloss-pressed.png", (True, button_gloss))):
        save(key, d[1](256, d[0]), z=7 if "base" in key else 8, aspect=[1, 1 + LIP], note="A and B both use this. Rect = centre +- diameter/2, height = diameter * %.2f (the lower edge hangs below). Base: tint with the accent (A) or #3A3E47 (B). Gloss: never tinted." % (1 + LIP))
    save("dpad-disc.png", dpad_disc(256), z=7)
    save("dpad-arrows.png", dpad_arrows(256), z=8, tint="accent")
    save("dpad-press.png", dpad_press(256), z=9, note="UP wedge; set Rotation 90 / 180 / 270 for right / down / left; visible only while held")
    mx, my, mw, mh = DECK["menu"]
    save("menu-pill.png", menu_pill(mw, mh, 2.0), rect=DECK["menu"], z=7, sliceCenter=[44, 43, 204, 45], note="label MENU: BuilderSans Bold 19, tracking +1.6, #E6E9EE")
    for key in ("shoulderL", "shoulderR"):
        x, y, w, h = DECK[key]
        save("shoulder.png" if key == "shoulderL" else "_", shoulder(2.0, w, h), rect=DECK["shoulderL"], z=1, tint="band colour", note="same sprite for L and R (rects shoulderL and shoulderR); sits behind the band") if key == "shoulderL" else None
    wp = DECK["wordmark"]["pixel"]
    save("wordmark.png", wordmark_sprite(8), rect=[DECK["wordmark"]["center"][0] - WORD_W * wp / 2, DECK["wordmark"]["center"][1] - WORD_H * wp / 2, WORD_W * wp, WORD_H * wp], z=4,
         resample="Pixelated", tint="faceplate engrave.color at engrave.opacity", note="41 x 16 cells at 8 px. Engraved look: one copy offset (+1.6, +2) units in the opposite tone (white 30% under a dark engrave, black 45% under a light one), then the main copy on top.")
    save("led-glow.png", led_glow(64), rect=[DECK["led"]["center"][0] - 17, DECK["led"]["center"][1] - 17, 34, 34], z=6, tint="accent")
    sh = soft_shadow(200, 200, 100, 1.0, blur=36, alpha=130, pad=90)
    save("shadow-9slice.png", sh, rect=[-90, -68, Wd + 180, Hd + 180], z=0, sliceCenter=[189, 189, 191, 191], sliceScale="deckWidth / 1600", note="offset 22 units down")
    files.pop("_", None)

    manifest = {
        "schema": 1, "name": "Pocket Deck Slim", "units": "deck units: body = 1600 x 800 (2:1). scale s = deckWidthPx / 1600.",
        "layout": DECK,
        "stack": ["shadow-9slice", "shoulder (L, R)", "band", "faceplate texture (assets/deck/faceplates/<id>.png) in rect plate", "plate-overlay", "wordmark (two copies, see files)",
                  "glass", "LCD Frame (rect lcd, UICorner lcdRadius * s, #0C0D10 leaning 10% to the plate's deep colour; ClipsDescendants)", "glass-glare",
                  "dpad-disc + dpad-arrows (+ dpad-press)", "menu-pill + label", "button-base + button-gloss + letter (A, B)", "led-glow"],
        "letters": {"A": "BuilderSans ExtraBold, size = 0.46 * diameter, colour = faceplate ink", "B": "same, colour #C3C8D0"},
        "press": "swap base and gloss to the -pressed sprites (cap drops by 7% of its diameter, lower edge collapses); the letter moves down the same amount. 60 ms down, 100 ms up.",
        "hitTargets": {"dpad": "four 96 x 96 unit quadrant buttons, never below 44 px each", "A": "diameter + 16 units", "B": "max(diameter + 16 units, 44 px)", "menu": "max(124 x 44 units, 44 px tall)", "shoulders": "220 x 56 units each, extending down over the band"},
        "files": files,
    }
    (OUT / "shell.json").write_text(json.dumps(manifest, indent=1), newline="\n")
    prev = compose_deck(None, k=0.64)
    prev.save(OUT / "preview-neutral.png")
    print("shell sprites:", len(files))


if __name__ == "__main__":
    main()
