"""Mockups for UI-SPEC-REDESIGN-CELEBRATIONS-2026-11-12.md: the hatch reveal and the round results.

Run: python scripts/deck_art/build_redesign_celebration_mockups.py
Output: artifacts/redesign-2026-11-12/celebrations/ (1:1 Roblox pixels, plus @2x).

Both screens are functions of the root size and of a time on the spec's entrance timeline, so the
"mid-way" frames are the timeline evaluated at that millisecond, not separate drawings.
Concept drawings from the spec's numbers, not Studio captures. The Bear is the Blender reference
render, cut out and tinted to the undyed in-game colours (body #FFFFFF, secondary #A8A5AE).
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

import build_compact_frame_mockups as F
import build_compact_mockups as C
import build_mockups as M
import common
from common import ROOT, Cv, contrast, egg_pts, font, hx, icon, mix, star_pts, GOOD, INK, STAR, TEXT

OUT = ROOT / "artifacts" / "redesign-2026-11-12" / "celebrations"
BEAR_SRC = ROOT / "artifacts" / "scope-2026-11-12" / "raw" / "raw-bare-front.png"
common.FONT_FILES["ext"] = common._find(common._RBX + r"\BuilderExtended-Bold.otf") or common.FONT_FILES["xb"]
BL, BI = Image.BILINEAR, Image.BICUBIC

# One row per pet: everything the reveal template needs. `secondary` is the pet's current secondary
# palette colour (PetBaseColors.secondary when undyed).
PETS = {
    "bear": {"name": "Bear", "index": 1, "secondary": "#A8A5AE", "desc": "Soft as a nap. Hugs first, asks questions never."},
    "ovelle": {"name": "Ovelle", "index": 2, "secondary": "#5FD3C4", "desc": "Drifts in sideways and catches whatever you drop."},
    "tikket": {"name": "Tikket", "index": 3, "secondary": "#FF8FB5", "desc": "Always mid-wobble. Has never once fallen over. Probably."},
}
TAGS = {"new": ("A NEW", "LITTLE WONDER!"), "rare": ("RARE", "DISCOVERY!"), "owned": ("ALREADY", "OWNED!"), "saved": ("SAVED FOR", "YOUR GARDEN!")}


# ------------------------------------------------------------------ small maths
def seg(t, a, b):
    return 1.0 if t is None else max(0.0, min(1.0, (t - a) / (b - a)))


def back_out(x, s=1.70158):
    x -= 1
    return 1 + (s + 1) * x ** 3 + s * x ** 2


def quint_out(x):
    return 1 - (1 - x) ** 5


def lerp(a, b, t):
    return a + (b - a) * t


def accent_for(secondary):
    """Template rule: the pet's secondary colour, lifted so it reads on black; Stars gold when it is near grey."""
    r, g, b = [v / 255 for v in hx(secondary)[:3]]
    mx, mn = max(r, g, b), min(r, g, b)
    sat = 0 if mx == 0 else (mx - mn) / mx
    if sat < .12:
        return hx(STAR)
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    r, g, b = colorsys.hsv_to_rgb(h, max(s, .55), max(v, .9))
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def ink_on(c):
    return hx(INK) if contrast(c, hx(INK)) >= 4.5 else (255, 255, 255, 255)


# ------------------------------------------------------------------ raster helpers
def low_mask(size, draw_fn, blur, down=4):
    """An L mask drawn at 1/down size and blurred there (cheap big glows). draw_fn(draw, k): k scales supersampled px."""
    w, h = max(1, size[0] // down), max(1, size[1] // down)
    m = Image.new("L", (w, h), 0)
    draw_fn(ImageDraw.Draw(m), 1 / down)
    if blur > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur / down))
    return m.resize(size, BL)


def glow(cv, mask, color, strength=1.0):
    """Additive light."""
    c = [int(v * strength) for v in color[:3]]
    lay = Image.merge("RGB", [mask.point(lambda v, k=k: int(v * k / 255)) for k in c])
    cv.im = ImageChops.add(cv.im.convert("RGB"), lay)
    cv.refresh()


def shade(cv, mask, strength=.6):
    cv.im.paste((0, 0, 0), (0, 0), mask.point(lambda v: int(v * strength)))
    cv.refresh()


def timg(s, key, px, fill, z, tracking=0.0):
    f = font(key, px * z)
    w = sum(f.getlength(c) for c in s) + tracking * z * (len(s) - 1)
    asc, desc = f.getmetrics()
    pad = int(px * z * .3)
    im = Image.new("RGBA", (int(w) + 2 * pad, asc + desc + 2 * pad), tuple(fill[:3]) + (0,))
    d = ImageDraw.Draw(im)
    x = pad
    for c in s:
        d.text((x, pad), c, font=f, fill=tuple(fill))
        x += f.getlength(c) + tracking * z
    return im.crop(im.getbbox())


def shear(im, k):
    """Lean right: the top edge moves right by k * height."""
    w, h = im.size
    return im.transform((int(w + k * h), h), Image.AFFINE, (1, k, -k * h, 0, 1, 0), BI)


def slam_text(s, px, z, fill, shadow, k=.2, off=.07, key="ext", tracking=0.0):
    """Display type: sheared, with a hard offset shadow."""
    a, b = timg(s, key, px, fill, z, tracking), timg(s, key, px, shadow, z, tracking)
    o = int(px * z * off)
    im = Image.new("RGBA", (a.width + o, a.height + o), (0, 0, 0, 0))
    im.alpha_composite(b, (o, o))
    im.alpha_composite(a, (0, 0))
    return shear(im, k)


def para(w, h, slant, fill, z):
    """Parallelogram leaning right. w, h in output px."""
    im = Image.new("RGBA", (int(w * z), int(h * z)), (0, 0, 0, 0))
    s = slant * z
    ImageDraw.Draw(im).polygon([(s, 0), (w * z, 0), (w * z - s, h * z), (0, h * z)], fill=tuple(fill))
    return im


def fade(im, a):
    if a >= 1:
        return im
    im = im.copy()
    im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
    return im


def put(cv, im, x, y, anchor="lt", alpha=1.0, rot=0.0):
    """Composite a supersampled RGBA sprite at output px (x, y)."""
    if alpha <= 0.01:
        return
    if rot:
        im = im.rotate(rot, BI, expand=True)
    im = fade(im, alpha)
    z = cv.z
    px = x * z - {"l": 0, "m": im.width / 2, "r": im.width}[anchor[0]]
    py = y * z - {"t": 0, "m": im.height / 2, "b": im.height}[anchor[1]]
    cv.paste(im, px, py, raw=True)


def sparkle(cv, cx, cy, r, color):
    pts = []
    for i in range(8):
        a = math.radians(i * 45 - 90)
        rr_ = r if i % 2 == 0 else r * .2
        pts.append((cx + rr_ * math.cos(a), cy + rr_ * math.sin(a)))
    cv.poly(pts, color)


# ------------------------------------------------------------------ the Bear
_bear = {}


def bear():
    """Cut the reference render off its flat grey ground and tint it to the undyed in-game Bear."""
    if "im" in _bear:
        return _bear["im"]
    src = np.asarray(Image.open(BEAR_SRC).convert("RGB")).astype(np.float32)
    bg = src[4, 4]
    dist = np.abs(src - bg).max(axis=2)
    alpha = np.clip((dist - 10) / 14, 0, 1)
    r, g, b = src[..., 0] / 255, src[..., 1] / 255, src[..., 2] / 255
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = .2126 * r + .7152 * g + .0722 * b
    pink = np.clip((b - .35) / .30, 0, 1)                      # yellow has almost no blue, the pink parts do
    def ramp3(t, stops):
        t = np.clip(t, 0, 1)[..., None]
        lo, mid, hi = [np.array(hx(s)[:3], dtype=np.float32) for s in stops]
        return np.where(t < .5, lo + (mid - lo) * t * 2, mid + (hi - mid) * (t * 2 - 1))
    body = ramp3((lum - .50) / .42, ("#8B879C", "#E6E3EE", "#FFFFFF"))
    sec = ramp3((lum - .50) / .36, ("#6C6976", "#A8A5AE", "#D6D3DC"))
    tinted = body * (1 - pink[..., None]) + sec * pink[..., None]
    k = np.clip((sat - .10) / .15, 0, 1)[..., None]
    rgb = src * (1 - k) + tinted * k
    out = np.dstack([rgb, alpha * 255]).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    a = im.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(.8))
    im.putalpha(a)
    _bear["im"] = im.crop(im.getbbox())
    return _bear["im"]


def pet_sprite(h_px, reveal=1.0):
    im = bear()
    w = int(im.width * h_px / im.height)
    im = im.resize((w, int(h_px)), Image.LANCZOS)
    # top light: brighter head, darker feet
    g = np.linspace(1.04, .78, im.height, dtype=np.float32)[:, None, None]
    arr = np.asarray(im).astype(np.float32)
    arr[..., :3] = np.clip(arr[..., :3] * g, 0, 255)
    if reveal < 1:
        sil = np.array([12, 13, 20], dtype=np.float32)
        arr[..., :3] = arr[..., :3] * reveal + sil * (1 - reveal)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ hatch reveal: template sprites
def headline_img(z, tag, acc, big_px, small_px):
    small, big = TAGS[tag]
    ink = ink_on(acc)
    st = timg(small, "xb", small_px, ink, z, tracking=small_px * .08)
    padx, pady = small_px * z * .7, small_px * z * .32
    strip = para((st.width + 2 * padx) / z + small_px * .4, (st.height + 2 * pady) / z, small_px * .4, acc, z)
    strip.alpha_composite(st, (int(padx + small_px * z * .3), int(pady)))
    bt = slam_text(big, big_px, z, hx(TEXT), acc, k=.2, off=.065)
    bar_h = max(3, big_px * .11)
    bar = para(bt.width / z * .86, bar_h, bar_h * .9, acc, z)
    gap = int(big_px * z * .12)
    w = max(strip.width + int(big_px * z * .16), bt.width)
    im = Image.new("RGBA", (w, strip.height + gap + bt.height + gap + bar.height), (0, 0, 0, 0))
    im.alpha_composite(strip, (int(big_px * z * .16), 0))
    im.alpha_composite(bt, (0, strip.height + gap))
    im.alpha_composite(bar, (0, strip.height + gap + bt.height + gap))
    return im


def plate_img(z, pet, acc, w, h, name_px, tag_px, tag_line):
    """The name plate: a slanted accent bar that runs off the right edge, the name in ink, a small tag strip above."""
    ink = ink_on(acc)
    slant = h * .42
    tag = timg(tag_line, "b", tag_px, acc, z, tracking=tag_px * .1)
    th_ = tag.height / z + tag_px * .9
    tag_w = tag.width / z + tag_px * 2.6
    drop = h * .07
    im = Image.new("RGBA", (int(w * z), int((th_ + h + drop) * z)), (0, 0, 0, 0))
    im.alpha_composite(para(w, h, slant, mix(acc, "#000000", .55), z), (0, int((th_ + drop) * z)))
    plate = para(w, h, slant, acc, z)
    # top sheen and a halftone run toward the right end
    d = ImageDraw.Draw(plate)
    d.polygon([(slant * z, 0), (w * z, 0), (w * z, h * z * .12), (slant * z - h * z * .12 * .42, h * z * .12)], fill=(255, 255, 255, 70))
    dots = Image.new("RGBA", plate.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(dots)
    step = h * z / 9
    x0 = w * z * .52
    cols = int((w * z - x0) / step) + 1
    for i in range(cols):
        for j in range(10):
            r = step * .46 * (i / max(1, cols - 1)) ** .8
            cx, cy = x0 + i * step + (step / 2 if j % 2 else 0), j * step
            dd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tuple(mix(acc, "#000000", .32)[:3]) + (150,))
    dots.putalpha(ImageChops.multiply(dots.getchannel("A"), plate.getchannel("A")))
    plate.alpha_composite(dots)
    im.alpha_composite(plate, (int(drop * z * .6), int(th_ * z)))
    name = timg(pet["name"].upper(), "ext", name_px, ink, z, tracking=name_px * .02)
    im.alpha_composite(name, (int((slant + h * .30) * z), int((th_ + h / 2) * z - name.height / 2)))
    strip = para(tag_w, th_, th_ * .42, (10, 11, 16, 255), z)
    strip.alpha_composite(tag, (int(tag_px * 1.3 * z), int((th_ * z - tag.height) / 2)))
    im.alpha_composite(strip, (int((slant + h * .12) * z), 0))
    ImageDraw.Draw(im).line([((slant + h * .12 + th_ * .42) * z, 1), ((slant + h * .12 + tag_w) * z, 1)], fill=tuple(acc[:3]) + (255,), width=max(2, int(z * 1.5)))
    return im


def desc_img(cv, z, text, px, width, acc):
    """Description on a dark strip with an accent tick. Wrapped to two lines at most."""
    f = font("m", px * z)
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if f.getlength(t) <= width * z or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    lh = px * 1.3
    padx, pady = px * 1.1, px * .6
    w = max(f.getlength(l) for l in lines) / z + 2 * padx + px * .5
    h = len(lines) * lh + 2 * pady
    im = Image.new("RGBA", (int(w * z), int(h * z)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w * z - 1, h * z - 1], px * z * .35, fill=(10, 11, 16, 215))
    d.rounded_rectangle([0, 0, px * z * .28, h * z - 1], px * z * .14, fill=tuple(acc))
    for i, l in enumerate(lines):
        d.text(((padx + px * .2) * z, (pady + i * lh + lh / 2) * z), l, font=f, fill=hx(TEXT), anchor="lm")
    return im


# ------------------------------------------------------------------ hatch reveal: the screen
def hatch_geometry(W, H, phone):
    if phone:
        # Stage content starts 60 px down, under the Roblox controls; 24 px side margins (device safe insets).
        return dict(u=.36, cx=268, floor=306, ph=188, rx=120, head=(22, 64), big=27, small=12,
                    plate=(444, 104, 60, 46, 12), desc=(470, 198, 14, 300), btn_y=292, btn_h=48, meet=(W - 24 - 176, 176),
                    again=(W - 24 - 176 - 10 - 150, 150), btn_px=16, hint=(268, 338, 12), next=None, margin=24)
    return dict(u=1.0, cx=800, floor=842, ph=590, rx=350, head=(88, 76), big=80, small=26,
                plate=(1010, 640, 168, 128, 22), desc=(1108, 878, 26, 700), btn_y=968, btn_h=72, meet=(W - 88 - 300, 300),
                again=(W - 88 - 300 - 16 - 240, 240), btn_px=22, hint=(800, 962, 16), next=(88, 1004, 16), margin=88)


def hatch(W, H, th, t=None, phone=False, pet="bear", tag="new"):
    """Hatch reveal at time t (ms on the spec timeline; None = settled)."""
    P = PETS[pet]
    acc = accent_for(P["secondary"])
    g = hatch_geometry(W, H, phone)
    z = 3 if phone else 2
    u = g["u"]
    cv = Cv(W, H, z, bg=(6, 7, 11, 255))
    S = cv.im.size
    cx, floor, ph, rx = g["cx"], g["floor"], g["ph"], g["rx"]
    e_spot = back_out(seg(t, 120, 300)) if t is not None else 1
    e_pet = back_out(seg(t, 120, 420)) if t is not None else 1
    reveal = seg(t, 420, 540)
    flash = 0 if t is None or t < 420 else 1 - seg(t, 420, 700)
    burst = None if t is None or t < 420 or t > 900 else seg(t, 420, 900)
    sweep = seg(t, 300, 520)
    hot = 0 if t is None else 1 - seg(t, 520, 820)
    e_head = back_out(seg(t, 480, 680), 2.2) if t is not None else 1
    e_plate = quint_out(seg(t, 600, 840))
    e_desc = seg(t, 840, 1000)
    e_btn = seg(t, 1000, 1140)

    # 1. room tone
    glow(cv, low_mask(S, lambda d, k: d.ellipse([(cx - W * .6) * z * k, (floor - H * .95) * z * k, (cx + W * .6) * z * k, (floor + H * .35) * z * k], fill=255), 130 * u * z, 8),
         mix(acc, "#2B3A8C", .6), .16)
    # 2. light streaks (behind the pet)
    tan = math.tan(math.radians(16))
    x_to = lerp(-.1 * W, 1.12 * W, sweep)
    def band(yc, thick, strength, color, blur=1.5):
        def draw(d, k):
            pts = []
            for x, s in ((-.1 * W, -1), (x_to, -1), (x_to + thick * .4, 1), (-.1 * W, 1)):
                pts.append((x * z * k, (yc - tan * (x - W / 2) + s * thick / 2) * z * k))
            d.polygon(pts, fill=255)
        glow(cv, low_mask(S, draw, blur * z, 2), color, strength * (1 + 2.2 * hot))
    if sweep > 0:
        band(H * .66, 190 * u, .085, acc)
        band(H * .82, 54 * u, .13, acc)
        band(H * .30, 30 * u, .08, acc)
        band(H * .735, 6 * u, .55, mix(acc, "#FFFFFF", .5), .8)
        band(H * .262, 3 * u, .4, mix(acc, "#FFFFFF", .5), .8)
    # 3. spotlight: cone from above, pool on the floor
    if e_spot > 0:
        rxe = rx * (.25 + .75 * e_spot)
        def cone(d, k):
            d.polygon([((cx - 46 * u) * z * k, -20 * z * k), ((cx + 46 * u) * z * k, -20 * z * k), ((cx + rxe) * z * k, floor * z * k), ((cx - rxe) * z * k, floor * z * k)], fill=255)
        m = low_mask(S, cone, 0, 4)
        fall = Image.fromarray(np.tile(np.linspace(255, 120, S[1] // 4, dtype=np.float32).astype(np.uint8)[:, None], (1, S[0] // 4)), "L").resize(S, BL)
        m = ImageChops.multiply(m.filter(ImageFilter.GaussianBlur(26 * u * z)), fall)
        glow(cv, m, (255, 238, 205), .40 * min(1, e_spot))
        glow(cv, low_mask(S, lambda d, k: d.ellipse([(cx - rxe) * z * k, (floor - rxe * .2) * z * k, (cx + rxe) * z * k, (floor + rxe * .2) * z * k], fill=255), 9 * u * z, 2),
             (255, 240, 212), .55 * min(1, e_spot))
        glow(cv, low_mask(S, lambda d, k: d.ellipse([(cx - rxe * 1.03) * z * k, (floor - rxe * .206) * z * k, (cx + rxe * 1.03) * z * k, (floor + rxe * .206) * z * k], outline=255, width=max(1, int(4 * u * z * k))), 1.5 * z, 2),
             acc, .7 * min(1, e_spot))
    # 4. the pet (a ViewportFrame at runtime), its contact shadow, the reveal flash
    if e_pet > 0:
        sc = lerp(.55, 1, e_pet)
        shade(cv, low_mask(S, lambda d, k: d.ellipse([(cx - ph * .27 * sc) * z * k, (floor - ph * .035) * z * k, (cx + ph * .27 * sc) * z * k, (floor + ph * .075) * z * k], fill=255), 10 * u * z, 2), .62)
        spr = pet_sprite(ph * sc * z, reveal)
        put(cv, spr, cx, floor + ph * .045 * sc, "mb")
    if flash > 0:
        r = ph * (.45 + .5 * (1 - flash))
        glow(cv, low_mask(S, lambda d, k: d.ellipse([(cx - r) * z * k, (floor - ph * .5 - r) * z * k, (cx + r) * z * k, (floor - ph * .5 + r) * z * k], fill=255), 60 * u * z, 8),
             (255, 250, 235), .6 * flash)
    rng = np.random.default_rng(11)
    if burst is not None:
        for i in range(18):
            a = math.radians(i * 20 + rng.random() * 14)
            d_ = ph * (.36 + .52 * quint_out(burst)) * (.8 + .4 * rng.random())
            s = (26 - 14 * burst) * u * (.6 + .8 * rng.random())
            sparkle(cv, cx + d_ * math.cos(a) * 1.15, floor - ph * .5 + d_ * math.sin(a) * .9, s, mix(acc, "#FFFFFF", .55 if i % 2 else .9, int(255 * (1 - burst * .8))))
    if t is None or t >= 700:
        a = seg(t, 700, 1000)
        for i in range(11):                                       # idle twinkles and dust in the beam
            x = cx + (rng.random() - .5) * rx * 1.9
            y = floor - ph * (.08 + rng.random() * 1.15)
            sparkle(cv, x, y, (5 + rng.random() * 13) * u ** .7, mix(acc, "#FFFFFF", .7, int((120 + 120 * rng.random()) * a)))
        for i in range(26):
            x = cx + (rng.random() - .5) * rx * 1.5
            y = floor - rng.random() * ph * 1.25
            cv.ell(x, y, (1.2 + rng.random() * 1.6) * max(.6, u), fill=(255, 244, 220, int((40 + 70 * rng.random()) * a)))
    # 5. headline graphic (top left) and name plate (bottom right)
    hx_, hy = g["head"]
    if e_head > 0:
        put(cv, headline_img(z, tag, acc, g["big"], g["small"]), hx_ - (1 - e_head) * W * .45, hy, "lt", min(1, e_head * 1.6), rot=4)
    px_, py_, ph_, npx, tpx = g["plate"]
    if e_plate > 0:
        pl = plate_img(z, P, acc, W - px_ + 90, ph_, npx, tpx, "No. %02d  ·  NEW FRIEND" % P["index"])
        if e_plate < 1:
            pl = pl.filter(ImageFilter.BoxBlur(18 * u * z * (1 - e_plate)))
        put(cv, pl, px_ + (1 - e_plate) * (W - px_ + 60), py_, "lt", rot=4)
    dx, dy, dpx, dw = g["desc"]
    if e_desc > 0:
        ds = desc_img(cv, z, P["desc"], dpx, dw, acc)
        ds = ds.crop((0, 0, max(1, int(ds.width * quint_out(e_desc))), ds.height))
        put(cv, ds, dx, dy, "lt", e_desc)
    # 6. actions and hints
    if e_btn >= 1:
        ui = cv
        mx, mw = g["meet"]
        ax, aw = g["again"]
        M.button(ui, ax, g["btn_y"], aw, g["btn_h"], "Play again", th, "secondary", key=None if phone else "B", size=g["btn_px"])
        M.button(ui, mx, g["btn_y"], mw, g["btn_h"], "Meet " + P["name"], th, "primary", "focus" if not phone else "idle", key=None if phone else "A", size=g["btn_px"])
        hxx, hyy, hp = g["hint"]
        label = "Drag to spin"
        tw = ui.tw(label, "b", hp)
        w = tw + hp * 3.2
        ui.rr(hxx - w / 2, hyy - hp * .95, w, hp * 1.9, hp, fill=(10, 11, 16, 200))
        ui.rr(hxx - w / 2, hyy - hp * .95, w, hp * 1.9, hp, stroke=(255, 255, 255, 46), sw=1)
        ui.arc(hxx - w / 2 + hp * 1.1, hyy, hp * .45, 30, 330, hx(TEXT), max(1.4, hp * .12))
        ui.poly([(hxx - w / 2 + hp * 1.45, hyy - hp * .55), (hxx - w / 2 + hp * 1.75, hyy - hp * .05), (hxx - w / 2 + hp * 1.2, hyy - hp * .1)], hx(TEXT))
        ui.text(hxx - w / 2 + hp * 2.1, hyy + .5, label, "b", hp, hx(TEXT), "lm")
        if g["next"]:
            nx, ny, npx_ = g["next"]
            ui.rr(nx - 16, ny - 20, 400, 40, 20, fill=(10, 11, 16, 215))
            ui.text(nx, ny, "NEXT", "b", 13, th["dim"], "lm", tracking=.8)
            icon(ui, "egg", nx + 60, ny, 20, hx(TEXT), accent=hx(STAR))
            ui.text(nx + 78, ny + .5, "Toy Egg  ·  6/8 Stars  ·  win quests", "m", npx_, th["soft"], "lm")
    if phone:
        C.roblox_bar(cv)
    return cv


# ------------------------------------------------------------------ results: pieces
def star3d(cv, cx, cy, r, yaw=0.0, hollow=False, lit=1.0):
    """The Star token as the ViewportFrame would show it: a chunky faceted star, turned by `yaw` degrees."""
    z = cv.z
    sx = math.cos(math.radians(yaw))
    side = math.sin(math.radians(yaw)) * r * .26
    pts0 = star_pts(0, 0, r, inner=.54)
    front = [(cx + x * sx + side / 2, cy + y) for x, y in pts0]
    backp = [(cx + x * sx - side / 2, cy + y) for x, y in pts0]
    if hollow:
        cv.poly(front, (255, 255, 255, 16))
        cv.line(front + [front[0]], (255, 255, 255, 110), max(2, r * .07))
        return
    S = cv.im.size
    glow(cv, low_mask(S, lambda d, k: d.ellipse([(cx - r * 1.5) * z * k, (cy - r * 1.5) * z * k, (cx + r * 1.5) * z * k, (cy + r * 1.5) * z * k], fill=255), r * .5 * z, 8), hx(STAR), .34 * lit)
    if abs(side) > .5:
        cv.poly(backp, "#B4660A")
        for i in range(10):
            cv.poly([backp[i], backp[(i + 1) % 10], front[(i + 1) % 10], front[i]], "#C97A0C")
    c = (cx + side / 2, cy)
    light = (-.55, -.83)
    for i in range(10):
        a, b = front[i], front[(i + 1) % 10]
        mxp, myp = (a[0] + b[0]) / 2 - c[0], (a[1] + b[1]) / 2 - c[1]
        n = math.hypot(mxp, myp) or 1
        # the two facets of each arm catch the light differently
        k = .5 + .5 * (mxp / n * light[0] + myp / n * light[1])
        k = min(1, max(0, k * .75 + (.25 if i % 2 == 0 else 0)))
        cv.poly([c, a, b], mix("#E28C10", "#FFE694", k))
    cv.line(front + [front[0]], "#A85C00", max(1.5, r * .05))
    cv.ell(c[0] - r * .30 * sx, cy - r * .36, r * .13 * abs(sx) + 1, r * .08, fill=(255, 255, 255, 190))


def rays(cv, cx, cy, r, rot, strength, color, n=12):
    z = cv.z
    box = int(r * z)
    m = Image.new("L", (box * 2, box * 2), 0)
    d = ImageDraw.Draw(m)
    for i in range(n):
        a0 = rot + i * 360 / n
        d.pieslice([0, 0, box * 2, box * 2], a0, a0 + 360 / n * .46, fill=255)
    ys, xs = np.mgrid[0:box * 2, 0:box * 2].astype(np.float32)
    dist = np.sqrt((xs - box) ** 2 + (ys - box) ** 2) / box
    fall = np.clip(1 - dist, 0, 1) ** 1.1
    m = Image.fromarray((np.asarray(m).astype(np.float32) * fall).astype(np.uint8), "L")
    full = Image.new("L", cv.im.size, 0)
    full.paste(m, (int(cx * z - box), int(cy * z - box)))
    glow(cv, full, color, strength)


def confetti(cv, rect, n, colors, seed=5, hole=None, s=1.0):
    x, y, w, h = rect
    rng = np.random.default_rng(seed)
    z = cv.z
    for i in range(n):
        px, py = x + rng.random() * w, y + rng.random() * h
        if hole and math.hypot(px - hole[0], (py - hole[1])) < hole[2]:
            continue
        col = colors[i % len(colors)]
        kind = i % 3
        if kind == 0:
            cv.poly(star_pts(px, py, (4 + rng.random() * 4) * s, rot=rng.random() * 72), col)
        else:
            a = rng.random() * math.pi
            l, t_ = (5 + rng.random() * 5) * s, (2.2 + rng.random() * 1.2) * s
            dx, dy = math.cos(a) * l, math.sin(a) * l
            cv.line([(px - dx, py - dy), (px + dx, py + dy)], col, t_ * 2)


def banner(cv, cx, cy, text, px, fill, shadow, bars, rot=3):
    """Outcome headline: sheared display type between two sets of speed lines."""
    z = cv.z
    t = slam_text(text, px, z, fill, shadow, k=.2, off=.075)
    lw = px * 1.5
    im = Image.new("RGBA", (int(t.width + 2 * (lw + px * .5) * z), t.height), (0, 0, 0, 0))
    im.alpha_composite(t, (int((lw + px * .5) * z), 0))
    for side in (0, 1):
        for i, (frac, yy) in enumerate(((1, .22), (.62, .48), (.34, .74))):
            bw, bh = lw * frac, px * .13
            p = para(bw, bh, bh * .8, bars, z)
            x = (lw - bw) * z if side == 0 else im.width - int(lw * z)
            im.alpha_composite(p, (int(x + (px * .12 * z * (2 - i) if side == 0 else -px * .12 * z * (2 - i))), int(t.height * yy)))
    put(cv, im, cx, cy, "mm", rot=rot)


def egg_meter(cv, x, cy, w, th, have, cost, px, label_px, ready_text="Ready to hatch!", name="Toy Egg"):
    """NEXT EGG: how close the wallet is to the cheapest egg. The come-back hook."""
    ready = have >= cost
    cv.poly(egg_pts(x + px * .7, cy, px * .62, px * .82), hx(STAR) if ready else th["soft"])
    cv.ell(x + px * .5, cy - px * .3, px * .16, px * .22, fill=(255, 255, 255, 120))
    tx = x + px * 1.8
    cv.text(tx, cy - px * .62, "NEXT EGG", "b", label_px, th["dim"], "lm", tracking=.7)
    right = ready_text if ready else f"{have}/{cost}"
    cv.text(x + w, cy - px * .62, right, "b" if ready else "monob", label_px if ready else label_px + 1, hx(STAR) if ready else th["soft"], "rm")
    bw = x + w - tx
    gap = 3
    sw_ = (bw - gap * (cost - 1)) / cost
    for i in range(cost):
        fx = tx + i * (sw_ + gap)
        on = i < have
        cv.rr(fx, cy + px * .12, sw_, px * .55, px * .16, fill=hx(STAR) if on else th["well"])
        if not on:
            cv.rr(fx, cy + px * .12, sw_, px * .55, px * .16, stroke=M.STROKE, sw=1)


def flying_stars(cv, a, b, n, r, lift):
    """Mini Stars on their arc from a payout row to the big Star, with trails."""
    for i in range(n):
        t = (i + .6) / n
        x = lerp(a[0], b[0], t)
        y = lerp(a[1], b[1], t) - math.sin(t * math.pi) * lift
        for j in range(1, 5):
            tt = t - j * .035
            cv.ell(lerp(a[0], b[0], tt), lerp(a[1], b[1], tt) - math.sin(tt * math.pi) * lift, r * (.5 - j * .08), fill=hx(STAR, 150 - j * 30))
        cv.poly(star_pts(x, y, r, rot=-90 + t * 140), STAR)
        cv.line(star_pts(x, y, r, rot=-90 + t * 140) + [star_pts(x, y, r, rot=-90 + t * 140)[0]], "#A85C00", max(1, r * .1))


WIN = dict(kind="win", head="TIDY WIN!", sub="Creek crossing  ·  Easy", rows=[("Round win", "5"), ("Tidy stack", "+1")], total=6, wallet0=2, cost=8,
           goals=[("Merge II in the centre", "II centre", True), ("Make III on RIGHT", "III right", True)], score="420", best="420", chain="×3",
           quest=("Win 2 rounds", 1, 2), note="Medium pays 6 to 8")
MISS = dict(kind="miss", head="SO CLOSE!", sub="Creek crossing  ·  Easy", rows=[], total=0, wallet0=6, cost=8,
            goals=[("Merge II in the centre", "II centre", True), ("Make III on RIGHT", "III right", False)], score="310", best="420", chain="×2",
            quest=("Finish 3 rounds", 2, 3), note="A win on Easy pays 5 to 6")


def results_state(base, counted=None):
    st = dict(base)
    st["done"] = counted is None
    st["counted"] = st["total"] if counted is None else counted
    st["wallet"] = st["wallet0"] + st["counted"]
    st["shown_rows"] = len(st["rows"]) if st["done"] else (1 if st["counted"] <= 5 else 2)
    st["newbest"] = st["done"] and st["kind"] == "win"
    st["yaw"] = 0 if st["done"] else 52
    return st


def payout_card(cv, rect, th, st, px, lpx, pitch, pad, meter):
    x, y, w, h = rect
    cv.rr(x, y, w, h, 14, fill=th["raised"])
    cv.rr(x, y, w, h, 14, stroke=M.STROKE, sw=1)
    M.label(cv, x + pad, y + pad * .8, "Payout", th, size=lpx)
    ry = y + pad * .8 + lpx + pitch * .75
    anchors = []
    if st["kind"] == "miss":
        cv.text(x + pad, ry, "No Stars this round", "m", px, th["soft"], "lm")
        cv.line([(x + pad, ry + pitch / 2), (x + w - pad, ry + pitch / 2)], (255, 255, 255, 18), 1, False)
        cv.text(x + pad, ry + pitch, st["note"], "r", max(12, px - 2), th["dim"], "lm")
        ty = None
    else:
        for i, (name, amt) in enumerate(st["rows"]):
            yy = ry + i * pitch
            on = i < st["shown_rows"]
            entering = (not st["done"]) and i == st["shown_rows"] - 1
            if on:
                if entering:                                           # the row that is paying out right now
                    cv.rr(x + pad * .4, yy - pitch * .42, w - pad * .8, pitch * .84, 8, fill=mix(th["raised"], STAR, .16))
                cv.text(x + pad, yy, name, "m", px, th["text"], "lm")
                cv.text(x + w - pad, yy, amt, "monob", px + 2, th["star"], "rm")
                anchors.append((x + w - pad - 6, yy))
            cv.line([(x + pad, yy + pitch / 2), (x + w - pad, yy + pitch / 2)], (255, 255, 255, 18), 1, False)
        ty = ry + len(st["rows"]) * pitch + 3
        cv.text(x + pad, ty, "Total", "b", px, th["text"], "lm")
        tot = str(st["counted"])
        tw = cv.tw(tot, "monob", px + 4)
        cv.text(x + w - pad, ty, tot, "monob", px + 4, th["star"], "rm")
        icon(cv, "star", x + w - pad - tw - (px + 4) * .75, ty - .5, px + 4)
    if meter:
        my = y + h - pad - px * .9
        cv.line([(x + pad, my - px * 1.25), (x + w - pad, my - px * 1.25)], (255, 255, 255, 18), 1, False)
        egg_meter(cv, x + pad, my, w - 2 * pad, th, st["wallet"], st["cost"], px, lpx, "Ready!")
    elif st["kind"] == "win":
        cv.text(x + pad, y + h - pad - 4, "Saved to your wallet", "r", max(12, px - 4), th["dim"], "lm")
        cv.text(x + pad, y + h - pad - 4 - px * 1.3, st["note"], "m", max(12, px - 3), th["soft"], "lm")
    return anchors


def goals_card(cv, rect, th, st, px, lpx, pitch, pad, short, metrics, chip=(24, 10)):
    x, y, w, h = rect
    cv.rr(x, y, w, h, 14, fill=th["raised"])
    cv.rr(x, y, w, h, 14, stroke=M.STROKE, sw=1)
    M.label(cv, x + pad, y + pad * .8, "Goals", th, size=lpx)
    done = sum(1 for g_ in st["goals"] if g_[2])
    M.label(cv, x + w - pad, y + pad * .8, f"{done}/{len(st['goals'])}", th, th["soft"], "ra", size=lpx)
    ry = y + pad * .8 + lpx + pitch * .8
    r = px * .62
    for i, (full, sh, ok) in enumerate(st["goals"]):
        yy = ry + i * pitch
        M.check_circle(cv, x + pad + r, yy, ok, th, r)
        cv.text(x + pad + r * 2 + px * .55, yy, C.fit(cv, sh if short else full, w - 2 * pad - r * 2 - px * .55, "m", px), "m", px, th["text"] if ok else th["soft"], "lm")
    if st["kind"] == "miss":
        yy = ry + len(st["goals"]) * pitch - pitch * .12
        cv.text(x + pad + r * 2 + px * .55, yy, "One more III would do it", "r", max(12, px - 3), th["dim"], "lm")
    my = y + h - pad - px * 2.3
    cv.line([(x + pad, my - px * .6), (x + w - pad, my - px * .6)], (255, 255, 255, 18), 1, False)
    vals = {"Score": st["score"], "Best": st["best"], "Chain": st["chain"]}
    for i, k in enumerate(metrics):
        mx = x + pad + i * (w - 2 * pad) / len(metrics)
        M.label(cv, mx, my, k, th, size=lpx)
        cv.text(mx, my + lpx + px * .85, vals[k], "monob", px + 2, th["text"], "lm")
    if st["newbest"]:
        cw_ = cv.tw("NEW BEST", "b", lpx, .6) + 20
        M.chip(cv, x + pad, my - px * .6 - chip[0] - chip[1], "New best", mix(th["well"], STAR, .2), hx(STAR), chip[0], size=lpx)


def hero(cv, th, st, cx, star_cy, r, count_cy, count_px, unit_cy, unit_px, col_w, pay_anchor=None, top=0):
    """The centre column: rays, the 3D Star and the count."""
    if st["kind"] == "miss":
        star3d(cv, cx, star_cy, r * .82, hollow=True)
        for i, (dx, dy, s) in enumerate(((-.9, -.75, .16), (1.0, -.5, .12), (.75, .8, .1))):
            sparkle(cv, cx + dx * r, star_cy + dy * r, r * s, (255, 255, 255, 90))
        cv.text(cx, count_cy - count_px * .16, "No Stars this time", "xb", max(16, count_px * .36), th["text"], "mm")
        cv.text(cx, unit_cy - unit_px * .2, "Bear still thinks you're great.", "m", max(12, unit_px), th["soft"], "mm")
        return
    done = st["done"]
    rays(cv, cx, star_cy, r * (2.5 if done else 2.0), -8 if done else 10, .24 if done else .13, hx(STAR))
    if done:
        confetti(cv, (cx - col_w / 2 + 6, top, col_w - 12, count_cy - count_px * .45 - top), 34, [hx(STAR), th["accent"], hx("#FF8FB5"), hx("#7FC8FF"), hx("#FFFFFF")],
                 hole=(cx, star_cy, r * 1.12), s=max(.75, r / 84))
    elif pay_anchor:
        flying_stars(cv, pay_anchor, (cx - r * .5, star_cy + r * .2), 3, max(6, r * .15), r * .7)
    pop = 1.0 if done else 1.1                                     # mid-count: caught at the top of a squash-pop
    star3d(cv, cx, star_cy, r * pop, st["yaw"])
    s = f"+{st['counted']}"
    t = slam_text(s, count_px, cv.z, hx(STAR) if done else hx("#FFE9B0"), hx("#7A4300"), k=.12, off=.06)
    put(cv, t, cx, count_cy, "mm")
    cv.text(cx, unit_cy, "STARS" if st["counted"] != 1 else "STAR", "ext", unit_px, th["star"], "mm", tracking=unit_px * .28)


# ------------------------------------------------------------------ results: desktop LCD (848 x 608)
def results_lcd(th, st):
    cv = M.lcd(th)
    LW = M.LW
    win = st["kind"] == "win"
    banner(cv, LW / 2, 48, st["head"], 44, hx(TEXT), th["accent"] if win else (90, 96, 108, 255), th["accent"] if win else th["dim"])
    cv.text(LW / 2, 94, st["sub"], "m", 16, th["soft"], "mm")
    M.wallet(cv, LW - 24, 16, st["wallet"], th, 40)
    pay = (24, 124, 248, 276)
    anchors = payout_card(cv, pay, th, st, 18, 13, 40, 18, meter=False)
    goals_card(cv, (LW - 24 - 248, 124, 248, 276), th, st, 17, 13, 38, 18, short=False, metrics=("Score", "Best", "Chain"))
    hero(cv, th, st, LW / 2, 212, 82, 332, 84, 386, 17, 304, anchors[-1] if anchors else None, top=112)
    # come-back strip: next egg and the quest this round moved
    y = 412
    cv.rr(24, y, 800, 56, 12, fill=th["well"])
    ready = st["wallet"] >= st["cost"]
    cv.rr(24, y, 800, 56, 12, stroke=hx(STAR) if ready and st["done"] else M.STROKE, sw=1.5 if ready and st["done"] else 1)
    egg_meter(cv, 40, y + 29, 356, th, st["wallet"], st["cost"], 20, 13)
    cv.line([(424, y + 10), (424, y + 46)], (255, 255, 255, 26), 1, False)
    q, a, b = st["quest"]
    icon(cv, "quests", 452, y + 28, 22, th["soft"])
    cv.text(472, y + 17, "DAILY QUEST", "b", 13, th["dim"], "lm", tracking=.7)
    cv.text(472, y + 39, q, "m", 16, th["text"], "lm")
    M.progress(cv, 640, y + 33, 120, 10, a / b, th)
    cv.text(808, y + 38, f"{a}/{b}", "monob", 16, th["soft"], "rm")
    cv.text(808, y + 17, "+1 this round", "b", 13, th["accent"], "rm")
    # actions
    by = 484
    if win and ready and st["done"]:
        M.button(cv, 24, by, 392, 64, "Replay", th, "primary", "focus", key="A", size=22, ico="replay")
        M.button(cv, 432, by, 216, 64, "Hatch egg", th, "reward", size=22, ico="egg")
        M.button(cv, 664, by, 160, 64, "Leave", th, "secondary", key="B", size=22)
    else:
        M.button(cv, 24, by, 392, 64, "Replay" if win else "Try again", th, "primary", "focus", key="A", size=22, ico="replay")
        M.button(cv, 432, by, 392, 64, "Leave to garden", th, "secondary", key="B", size=22)
    if st["done"]:
        M.hints(cv, 24, 576, [("<>", "Choose"), ("A", "Confirm"), ("B", "Leave")], th, right="Replay keeps Easy. Up on Replay changes difficulty.")
    else:
        M.hints(cv, 24, 576, [("A", "Skip the count")], th, right="Counting 3 of 6")
    return cv


def desk_view(lcd_cv, th, name):
    """The LCD set into the deck on a 1920 x 1080 view (same composition as build_mockups.full_view)."""
    W, H = 1920, 1080
    p = th["plate"]
    lcd_img = lcd_cv.im
    out = M.backdrop(W, H, th)
    deck = M.compose_deck(Image.open(M.ASSETS / "faceplates" / p["texture"]), accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=1.0,
                          lcd=lcd_img, press=None, lcd_fill=M.to_hex_rgba(th["panel"]), engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))
    out.alpha_composite(deck, ((W - 1600) // 2 - M.PAD, (H - 800) // 2 + 10 - M.PAD))
    over = Cv(W, H, z=2)
    M.back_arrow(over, W - 24 - 56, 24, 56, "idle")
    out.alpha_composite(over.out())
    OUT.mkdir(parents=True, exist_ok=True)
    out.convert("RGB").save(OUT / f"{name}-1920x1080.png")
    lcd_img.resize((M.LW * 2, M.LH * 2), Image.LANCZOS).convert("RGB").save(OUT / f"{name}-lcd@2x.png")
    return out


# ------------------------------------------------------------------ results: phone sheet
def results_phone(W, H, th, st=None):
    """Drawn in the sheet's own coordinates. As built, a phone sheet starts at y = kh + 2 = 60 on the root, so H here
    is the root height - 60 (+6 for the rim this canvas draws): 300 for an 812 x 354 root, sheet glass y 8..292."""
    cv = C.sheet(W, H, th)
    win = st["kind"] == "win"
    C.wallet(cv, W - 66, 30, st["wallet"], th)
    cw = (W - 40 - 20) // 3
    ay = H - 8 - 8 - 48
    y0 = 66
    ch = ay - 8 - y0
    pay = (20, y0, cw, ch)
    anchors = payout_card(cv, pay, th, st, 14, 12, 24, 12, meter=True)
    goals_card(cv, (W - 20 - cw, y0, cw, ch), th, st, 14, 12, 26, 12, short=False, metrics=("Score", "Best", "Chain"), chip=(22, 4))
    cx = 20 + cw + 10 + cw / 2
    banner(cv, cx, 25, st["head"], 22, hx(TEXT), th["accent"] if win else (90, 96, 108, 255), th["accent"] if win else th["dim"])
    cv.text(cx, 47, st["sub"], "m", 12, th["soft"], "mm")
    hero(cv, th, st, cx, y0 + 40, 33, y0 + 103, 40, y0 + 143, 12, cw - 6, anchors[-1] if anchors else None, top=y0 + 2)
    # action row (as built: Leave left, Replay right, difficulty beside it, the shortcut between)
    M.button(cv, 20, ay, 160, 48, "Leave to garden", th, "secondary", size=15)
    M.button(cv, W - 20 - cw, ay, cw, 48, "Replay" if win else "Try again", th, "primary", size=16, ico="replay")
    dxx = W - 20 - cw - 58
    cv.rr(dxx, ay, 48, 48, 12, fill=th["raised"])
    cv.rr(dxx, ay, 48, 48, 12, stroke=M.STROKE, sw=1)
    for i, bh in enumerate((10, 16, 22)):
        cv.rr(dxx + 10 + i * 8, ay + 35 - bh, 6, bh, 2, fill=hx(GOOD) if i == 0 else hx(GOOD, 64))
    cv.line([(dxx + 35, ay + 23), (dxx + 38.5, ay + 26.5), (dxx + 42, ay + 23)], th["soft"], 1.6)
    qx, qw = 190, dxx - 10 - 190
    ready = st["wallet"] >= st["cost"]
    if win and ready and st["done"]:
        M.button(cv, qx, ay, qw, 48, "Hatch Toy Egg", th, "reward", size=15, ico="egg")
    else:
        q, a, b = st["quest"]
        cv.rr(qx, ay, qw, 48, 12, stroke=M.STROKE, sw=1)
        icon(cv, "quests", qx + 22, ay + 24, 18, th["text"])
        cv.text(qx + 40, ay + 24.5, C.fit(cv, q, qw - 50 - 40, "b", 14), "b", 14, th["text"], "lm")
        cv.text(qx + qw - 12, ay + 24.5, f"{a}/{b}", "monob", 14, th["accent"], "rm")
    return cv


def phone_view(th, st, name, W=812, H=354, top=60):
    """The sheet set into the framed plate from y = top down (as built: top = kh + 2); the plate shows in the band above."""
    g = F.frame_geometry(W, H)
    off = g["mg"] - 6
    inner = results_phone(W - 2 * off, H - top + 6, th, st)
    cv = F.plate_canvas(W, H, th)
    z = cv.z
    bx, bw = g["sheetBezel"][0], g["sheetBezel"][2]
    by, bh = top, H - top - 6
    cv.shadow(bx, by, bw, bh, 18, blur=8, color=(0, 0, 0, 150), dy=3, spread=2)
    cv.rr(bx - 2, by - 2, bw + 4, bh + 4, 20, stroke=(255, 255, 255, 60), sw=1.5)
    part = inner.im.crop((6 * z, 6 * z, (6 + bw) * z, (6 + bh) * z)).convert("RGBA")
    part.putalpha(common.rounded_mask(bw * z, bh * z, 18 * z, 1))
    cv.paste(part, bx * z, by * z, raw=True)
    F.grips(cv, g, th)
    C.roblox_bar(cv)
    save(cv, f"{name}-{W}x{H}")
    return cv


# ------------------------------------------------------------------ output
def save(cv, name):
    OUT.mkdir(parents=True, exist_ok=True)
    cv.out().convert("RGB").save(OUT / f"{name}.png")
    cv.im.resize((cv.w * 2, cv.h * 2), Image.LANCZOS).convert("RGB").save(OUT / f"{name}@2x.png")


def sheet(images, captions, name, cols=1, gap=16, cap_h=32):
    w, h = max(i.width for i in images), max(i.height for i in images)
    rows = -(-len(images) // cols)
    out = Cv(cols * w + (cols + 1) * gap, rows * (h + cap_h + gap) + gap, z=1, bg=(16, 18, 22, 255))
    for n, (im, cap) in enumerate(zip(images, captions)):
        x, y = gap + (n % cols) * (w + gap), gap + (n // cols) * (h + cap_h + gap)
        out.text(x + 2, y + cap_h / 2 - 1, cap, "b", 15, (230, 233, 238, 255), "lm")
        out.paste(im.convert("RGBA"), x, y + cap_h, raw=True)
    out.out().convert("RGB").save(OUT / f"{name}.png")


def template_variants(th):
    """The reveal template filled from three pets' data and the four headline tags."""
    z = 2
    cv = Cv(1500, 720, z, bg=(8, 9, 13, 255))
    cv.text(30, 30, "NAME PLATE  ·  name, index and accent come from the pet (accent = lifted secondary colour, Stars gold when the secondary is near grey)", "b", 15, (200, 205, 214, 255), "lm")
    for i, key in enumerate(("bear", "ovelle", "tikket")):
        P = PETS[key]
        acc = accent_for(P["secondary"])
        y = 70 + i * 210
        put(cv, plate_img(z, P, acc, 620, 84, 64, 14, "No. %02d  ·  NEW FRIEND" % P["index"]), 30, y, "lt")
        put(cv, desc_img(cv, z, P["desc"], 17, 520, acc), 60, y + 112, "lt")
        cv.rr(30, y + 112, 20, 20, 4, fill=hx(P["secondary"]))
    cv.text(720, 30 + 30, "HEADLINE SPRITES  ·  four fixed strings, drawn once in white + mask, tinted with the accent", "b", 15, (200, 205, 214, 255), "lm")
    for i, tag in enumerate(("new", "rare", "owned", "saved")):
        acc = accent_for(("#A8A5AE", "#B78BFF", "#5FD3C4", "#FF8FB5")[i])
        put(cv, headline_img(z, tag, acc, 44, 15), 720, 100 + i * 150, "lt")
    OUT.mkdir(parents=True, exist_ok=True)
    cv.out().convert("RGB").save(OUT / "hatch-template-variants.png")


def main():
    th = C.kit_theme("sherbet")
    # hatch reveal
    frames = []
    for t, tag in ((360, "t0360-spotlight"), (660, "t0660-reveal"), (None, "settled")):
        cv = hatch(1920, 1080, th, t)
        save(cv, f"hatch-desktop-{tag}-1920x1080")
        frames.append(cv.out().resize((960, 540), Image.LANCZOS))
    sheet(frames, ["360 ms: spotlight on, silhouette rising, streaks sweeping", "660 ms: colour pops, sparkle burst, headline lands, name plate sliding in", "Settled (1140 ms on): idle, drag to spin"],
          "hatch-desktop-storyboard", cols=3)
    for t, tag in ((660, "t0660-reveal"), (None, "settled")):
        save(hatch(812, 354, th, t, phone=True), f"hatch-phone-{tag}-812x354")
    template_variants(th)
    # results
    for st, tag in ((results_state(WIN, 3), "counting"), (results_state(WIN), "settled-win"), (results_state(MISS), "missed")):
        desk_view(results_lcd(th, st), th, f"results-desktop-{tag}")
        phone_view(th, st, f"results-phone-{tag}")


if __name__ == "__main__":
    main()
