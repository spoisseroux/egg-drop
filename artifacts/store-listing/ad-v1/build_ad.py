"""Pocket Pals: Pet Garden, lead ad / sponsored thumbnail (ad-v1).

Composes 1920x1080 frames from real Roblox Studio captures in raw/ (Play mode, place
96451847774961, 2026-11-18). Cutouts come from difference matting: every subject was
captured twice, once over a black and once over a white backdrop, with the frame frozen
in between, so alpha = 1 - (white - black) / (white_bg - black_bg). Only the game's own
fonts (Builder Extended Bold, Fredoka One, shipped with Roblox) are added. No generated
imagery.

Run: python artifacts/store-listing/ad-v1/build_ad.py
Writes layers/*.png, ad-v1-1920x1080.png (variant A), ad-v1-B-1920x1080.png (variant B)
and a 480x270 preview of each.
"""
import glob
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
LAYERS = os.path.join(HERE, "layers")
W, H = 1920, 1080
POP_SCALE = 1.9

INK = (14, 15, 18)
STARS = (255, 193, 77)
CREAM = (255, 244, 220)
PANEL = (21, 37, 37)
MINT = (118, 246, 176)


def roblox_font(name):
    hits = sorted(glob.glob(os.path.expanduser("~/AppData/Local/Roblox/Versions/*/content/fonts/" + name)))
    if not hits:
        raise SystemExit("Roblox font not found: " + name)
    return hits[-1]


EXTENDED = roblox_font("BuilderExtended-Bold.otf")
FREDOKA = roblox_font("FredokaOne-Regular.ttf")


def load(name):
    return np.asarray(Image.open(os.path.join(RAW, name)).convert("RGB")).astype(np.float32)


def matte(black_name, white_name, box=None, bg_probe=(0, 0, 40, 40)):
    """Difference matte of one subject shot over black and white. Returns RGBA Image."""
    k, w = load(black_name), load(white_name)
    x0, y0, x1, y1 = bg_probe
    kb = np.median(k[y0:y1, x0:x1].reshape(-1, 3), 0)
    wb = np.median(w[y0:y1, x0:x1].reshape(-1, 3), 0)
    if box:
        bx0, by0, bx1, by1 = box
        k, w = k[by0:by1, bx0:bx1], w[by0:by1, bx0:bx1]
    span = float((wb - kb).mean())
    a = 1.0 - (w - k).mean(2) / span
    # JPEG noise: snap near-0 / near-1 values.
    a = np.clip((a - 0.04) / 0.92, 0, 1)
    safe = np.maximum(a, 1e-3)[..., None]
    rgb = (k - (1 - a[..., None]) * kb) / safe
    rgb = np.clip(rgb, 0, 255)
    out = np.dstack([rgb, a * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def trim(img, pad=4):
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    return img.crop((max(0, x0 - pad), max(0, y0 - pad), min(img.width, x1 + pad), min(img.height, y1 + pad)))


def keep_solid(img, threshold=150, grow=5):
    """Drop faint alpha (rays, glow bleed from neighbours) that is not attached to the solid body."""
    a = img.getchannel("A")
    solid = a.point(lambda v: 255 if v > threshold else 0)
    solid = solid.filter(ImageFilter.MaxFilter(grow * 2 + 1)).filter(ImageFilter.GaussianBlur(grow / 2))
    img = img.copy()
    img.putalpha(ImageChops.multiply(a, solid))
    return img


def scale(img, factor, resample=Image.LANCZOS):
    return img.resize((max(1, round(img.width * factor)), max(1, round(img.height * factor))), resample)


def shadow(img, radius, offset, opacity, color=(40, 10, 30)):
    a = img.getchannel("A").point(lambda v: int(v * opacity))
    pad = radius * 3
    layer = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), color + (0,))
    mask = Image.new("L", layer.size, 0)
    mask.paste(a, (pad, pad))
    mask = mask.filter(ImageFilter.GaussianBlur(radius))
    layer.putalpha(mask)
    return layer, (offset[0] - pad, offset[1] - pad)


def outline(img, width, color):
    a = img.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(width * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    ring = Image.new("RGBA", img.size, color + (0,))
    ring.putalpha(grown)
    ring.alpha_composite(img)
    return ring


def padded(img, p):
    out = Image.new("RGBA", (img.width + 2 * p, img.height + 2 * p), (0, 0, 0, 0))
    out.paste(img, (p, p))
    return out


def place(canvas, img, centre, with_shadow=None):
    x = round(centre[0] - img.width / 2)
    y = round(centre[1] - img.height / 2)
    if with_shadow:
        radius, off, opacity = with_shadow
        sh, (dx, dy) = shadow(img, radius, off, opacity)
        canvas.alpha_composite(sh, (x + dx, y + dy)) if x + dx >= 0 and y + dy >= 0 else paste_clip(canvas, sh, x + dx, y + dy)
    paste_clip(canvas, img, x, y)


def paste_clip(canvas, img, x, y):
    """alpha_composite that tolerates negative offsets and overhang."""
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    w = min(img.width - sx0, canvas.width - dx0)
    h = min(img.height - sy0, canvas.height - dy0)
    if w <= 0 or h <= 0:
        return
    canvas.alpha_composite(img.crop((sx0, sy0, sx0 + w, sy0 + h)), (dx0, dy0))


def screen(canvas, img, x, y, mask=None):
    """Screen-blend an RGB light layer (black = no change) onto the canvas."""
    region = canvas.crop((x, y, x + img.width, y + img.height)).convert("RGB")
    light = img.convert("RGB")
    blended = ImageChops.screen(region, light)
    if mask is not None:
        blended = Image.composite(blended, region, mask)
    canvas.paste(blended, (x, y))


def perspective_coeffs(src, dst):
    """Coefficients for Image.transform(PERSPECTIVE) mapping output dst quad back to src quad."""
    m = []
    for (xs, ys), (xd, yd) in zip(src, dst):
        m.append([xd, yd, 1, 0, 0, 0, -xs * xd, -xs * yd])
        m.append([0, 0, 0, xd, yd, 1, -ys * xd, -ys * yd])
    a = np.array(m, dtype=np.float64)
    b = np.array(src, dtype=np.float64).reshape(8)
    return np.linalg.solve(a, b).tolist()


def warp(img, quad, size):
    src = [(0, 0), (img.width, 0), (img.width, img.height), (0, img.height)]
    return img.transform(size, Image.PERSPECTIVE, perspective_coeffs(src, quad), Image.BICUBIC)


def rays(size, centre, length, color, count=12, rotation=8):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = xx - centre[0], yy - centre[1]
    ang = (np.degrees(np.arctan2(dy, dx)) - rotation) % 360
    step = 360 / count
    local = (ang % step) - step / 2  # degrees from the ray's centre line
    idx = (ang // step).astype(int)
    half = np.where(idx % 2 == 0, 7.0, 3.6)
    ray = np.clip(1 - np.abs(local) / half, 0, 1) ** 0.6
    dist = np.sqrt(dx * dx + dy * dy) / length
    fall = np.clip(1 - dist, 0, 1) ** 1.3 * np.clip(dist * 6, 0, 1)
    v = ray * fall * 200
    rgb = np.dstack([v * c / 255 for c in color])
    return Image.fromarray(rgb.astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(2))


def radial(size, centre, radius, color, peak=255, power=1.6):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - centre[0]) ** 2 + (yy - centre[1]) ** 2) / radius
    v = np.clip(1 - d, 0, 1) ** power * peak
    rgb = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        rgb[..., i] = v * color[i] / 255
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


# ---------------------------------------------------------------- layers


def build_layers():
    os.makedirs(LAYERS, exist_ok=True)
    L = {}

    # Background: the dusk garden (arch and floating island), blurred and warmed.
    bg = Image.open(os.path.join(RAW, "garden-arch-dusk.jpg")).convert("RGB")
    f = H / bg.height
    bg = bg.resize((round(bg.width * f), H), Image.LANCZOS)
    x0 = (bg.width - W) // 2
    bg = bg.crop((x0, 0, x0 + W, H)).filter(ImageFilter.GaussianBlur(9))
    bg = ImageEnhance.Color(bg).enhance(1.25)
    bg = ImageEnhance.Brightness(bg).enhance(1.04)
    L["bg"] = bg

    # Pocket Deck at the frozen CHAIN x4 frame (difference matte; the shell's own soft shadow
    # is kept). Crop leaves out Studio's back-arrow button at top right.
    deck = matte("deck-chain4-black.jpg", "deck-chain4-white.jpg", box=(270, 60, 1650, 777))
    rgb = load("deck-chain4-black.jpg")[490:668, 835:1102]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lcd = (g >= np.maximum(r, b) - 4) & (rgb.max(2) < 140)
    a = Image.fromarray(np.where(lcd, 0, 255).astype(np.uint8), "L").filter(ImageFilter.MedianFilter(5))
    pop = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    pop.putalpha(a)
    L["merge_pop"] = trim(keep_solid(pop, threshold=200, grow=1), 1)
    L["deck"] = deck  # untrimmed: layer coords = capture coords - (270, 60)

    # Bears (PetFactory clones, frozen poses): white plush Bear in Pom Beanie, Bell Collar,
    # Happy eyes and Blush holding its Ball; Tide (blue) Bear with Gloss, Sun Hat, Specs,
    # Beads and the "w" mouth, waving.
    L["bear_white"] = trim(matte("bear-white-black.jpg", "bear-white-white.jpg"))
    L["bear_tide"] = trim(matte("bear-tide-black.jpg", "bear-tide-white.jpg"))

    # Egg crack (real hatch cinematic through RevealCaptureFixture at t=0.97 s, white flash
    # and streaks hidden). Solid shell from the matte; the warm light from the black frame.
    egg = matte("egg-crack-black.jpg", "egg-crack-white.jpg", box=(400, 0, 1200, 592))
    # The reveal's light is drawn over the shell, so the matte only gives the shape; the
    # shell colour comes from the black frame (it already carries the warm light).
    shape = keep_solid(egg, threshold=120, grow=2).getchannel("A").point(lambda v: 255 if v > 90 else 0)
    shape = shape.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    shell = Image.open(os.path.join(RAW, "egg-crack-black.jpg")).convert("RGBA").crop((400, 0, 1200, 592))
    oval = Image.new("L", shell.size, 0)
    ImageDraw.Draw(oval).ellipse((285, 300, 540, 600), fill=255)  # the egg only, not the beam
    shell.putalpha(ImageChops.multiply(shape, oval.filter(ImageFilter.GaussianBlur(2))))
    shell = ImageEnhance.Contrast(shell).enhance(1.15)
    L["egg_solid"] = trim(shell, 2)
    glow = Image.open(os.path.join(RAW, "egg-crack-black.jpg")).convert("RGB").crop((400, 0, 1200, 777))
    # Fade out the floor ring and plinth under the egg.
    fade = Image.linear_gradient("L").resize((glow.width, glow.height))
    fade = fade.point(lambda v: 255 if v < 150 else max(0, 255 - (v - 150) * 4))
    glow = Image.composite(glow, Image.new("RGB", glow.size, (0, 0, 0)), fade)
    L["egg_light"] = glow

    # Stars: the game's 3D StarToken (CelebrationKit.star) captured over black and white.
    stars = matte("stars-black.jpg", "stars-white.jpg", bg_probe=(1880, 700, 1915, 770))
    boxes = {"star_a": (600, 95, 965, 455), "star_b": (1000, 95, 1370, 455), "star_c": (640, 440, 940, 730),
             "star_d": (1040, 440, 1340, 730), "star_e": (1410, 210, 1780, 560)}
    for name, box in boxes.items():
        L[name] = trim(keep_solid(stars.crop(box), threshold=180, grow=4))

    for name, img in L.items():
        img.save(os.path.join(LAYERS, name + ".png"))
    return L


# ---------------------------------------------------------------- text


def wordmark(text, size, tilt=4, underline=True, max_w=None):
    font = ImageFont.truetype(EXTENDED, size)
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    stroke = max(6, size // 8)
    bbox = probe.textbbox((0, 0), text, font=font, stroke_width=stroke)
    if max_w and bbox[2] - bbox[0] > max_w:
        return wordmark(text, int(size * max_w / (bbox[2] - bbox[0])), tilt, underline)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = 60
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2 + (size // 5 if underline else 0)), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ox, oy = pad - bbox[0], pad - bbox[1]
    # Drop shadow (ink) then the cream face with a thick ink outline, as icon D.
    d.text((ox + size // 18, oy + size // 11), text, font=font, fill=INK + (190,), stroke_width=stroke, stroke_fill=INK + (190,))
    d.text((ox, oy), text, font=font, fill=CREAM, stroke_width=stroke, stroke_fill=INK)
    if underline:
        uy = pad + h + 6
        th = max(8, size // 9)
        d.rounded_rectangle((pad + 10, uy, pad + w - 10, uy + th), radius=th // 2, fill=STARS, outline=INK, width=max(3, size // 40))
    if tilt:
        layer = layer.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return layer


def tagline(text, size, tilt=0):
    font = ImageFont.truetype(FREDOKA, size)
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    tw = probe.textlength(text, font=font)
    pad_x, pad_y = int(size * 0.7), int(size * 0.32)
    bw, bh = int(tw + pad_x * 2), int(size + pad_y * 2)
    layer = Image.new("RGBA", (bw + 40, bh + 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((26, 30, 26 + bw, 30 + bh), radius=bh // 2, fill=(0, 0, 0, 110))
    d.rounded_rectangle((20, 20, 20 + bw, 20 + bh), radius=bh // 2, fill=PANEL + (245,), outline=MINT, width=max(4, size // 14))
    d.text((20 + bw / 2, 20 + bh / 2 + size * 0.04), text, font=font, fill=(255, 255, 255), anchor="mm",
           stroke_width=0)
    # Gold dots between the words, recoloured in place.
    if tilt:
        layer = layer.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return layer


# ---------------------------------------------------------------- compose


def compose(L, variant="A"):
    canvas = L["bg"].convert("RGBA")

    # Warm light pooled behind the egg and the merge, plus a soft vignette.
    screen(canvas, radial((W, H), (1640, 330), 820, (255, 186, 110), peak=210), 0, 0)
    vign = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vign)
    vd.ellipse((-420, -380, W + 420, H + 380), fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new("RGBA", (W, H), (60, 18, 40, 255))
    canvas = Image.composite(canvas, dark, vign.point(lambda v: int(140 + v * 115 / 255)))

    # ---- Egg (behind everything else), centre-right, cracking with its light beam.
    egg_f = 1.0
    light = scale(L["egg_light"], egg_f)
    ex, ey = 1660, -110
    m = Image.new("L", light.size, 0)
    ImageDraw.Draw(m).ellipse((60, 20, light.width - 60, light.height - 10), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(90))
    boosted = ImageEnhance.Brightness(light).enhance(1.6)
    screen(canvas, boosted, ex - light.width // 2, ey, m)
    egg = scale(L["egg_solid"], 1.1)
    egg_c = (ex + 12, ey + 455)
    screen(canvas, radial((W, H), egg_c, 260, (255, 200, 120), peak=220, power=1.5), 0, 0)
    rim = outline(padded(egg, 14), 11, (120, 60, 40))
    place(canvas, rim, egg_c, with_shadow=(16, (8, 14), 0.4))
    place(canvas, outline(padded(egg, 14), 6, (255, 250, 232)), egg_c)
    # Warm light pouring out of the crack (over the shell's dark gap).
    gap = (egg_c[0] - 2, egg_c[1] + 40)
    gm = Image.new("L", (W, H), 0)
    ex0, ey0 = egg_c
    ImageDraw.Draw(gm).polygon([(ex0 - 22, ey0 - 4), (ex0 + 20, ey0 - 4), (ex0 + 6, ey0 + 160), (ex0 - 10, ey0 + 160)], fill=255)
    gm = gm.filter(ImageFilter.GaussianBlur(5))
    canvas.paste(Image.new("RGBA", (W, H), (255, 214, 130, 255)), (0, 0), gm)
    screen(canvas, radial((W, H), (gap[0], gap[1] + 10), 120, (255, 205, 120), peak=110, power=1.8), 0, 0)
    # Extra warm bloom from the crack.
    screen(canvas, radial((W, H), (egg_c[0] - 6, egg_c[1] + 150), 170, (255, 200, 120), peak=150, power=2.2), 0, 0)

    # ---- Pocket Deck, big on the left, tilted toward the viewer (left edge nearer).
    deck = L["deck"]
    dw, dh = deck.size
    s = 1.0
    quad = [(-60, 400), (dw * s - 90, 320), (dw * s - 60, 320 + dh * s * 0.93), (-140, 400 + dh * s * 1.04)]
    deck_w = warp(deck, quad, (W, H))
    sh, (sx, sy) = shadow(deck_w, 26, (18, 30), 0.55, color=(30, 8, 24))
    paste_clip(canvas, sh, sx, sy)

    # Merge burst: the results Star's rays and a hot glow behind the merge (drawn on the deck
    # layer before the deck so the rays fan out from behind the shell, and again over the LCD).
    canvas.alpha_composite(deck_w)

    # Where the frozen merge sits on the warped deck (big purple ball + pink ball, x4 label).
    def deck_pt(px, py):
        # px,py in the trimmed deck layer -> canvas, via the same perspective.
        coeffs = perspective_coeffs([(0, 0), (dw, 0), (dw, dh), (0, dh)], quad)
        # invert numerically: search on a coarse grid is enough for placement.
        best, bd = None, 1e18
        for yy in range(0, H, 6):
            for xx in range(0, W, 6):
                a, b, c, d, e, f2, g, h = coeffs
                den = g * xx + h * yy + 1
                u, v = (a * xx + b * yy + c) / den, (d * xx + e * yy + f2) / den
                dd = (u - px) ** 2 + (v - py) ** 2
                if dd < bd:
                    best, bd = (xx, yy), dd
        return best

    merge = deck_pt(1030 - 270 + 0, 585 - 60)  # purple ball in the capture
    glow = radial((W, H), merge, 260, (255, 236, 170), peak=210, power=2.0)
    m2 = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m2).ellipse((merge[0] - 300, merge[1] - 300, merge[0] + 300, merge[1] + 300), fill=255)
    screen(canvas, glow, 0, 0, m2.filter(ImageFilter.GaussianBlur(40)))

    # Pop-out: the real merge cluster from the same frame, enlarged (pixel art, nearest) and
    # breaking out of the screen with a sticker outline.
    pop = scale(L["merge_pop"], POP_SCALE, Image.NEAREST)
    pop = outline(padded(pop, 16), 9, (255, 255, 255))
    pop = pop.rotate(-6, resample=Image.BICUBIC, expand=True)
    pc = (merge[0] + 10, merge[1] - 70)
    # Celebration rays behind the pop, in the results Star's style (12 gold rays, alternating
    # widths, fading out), plus a hot core.
    screen(canvas, rays((W, H), pc, 620, (255, 205, 110)), 0, 0)
    screen(canvas, radial((W, H), pc, 330, (255, 240, 190), peak=230, power=1.8), 0, 0)
    place(canvas, pop, pc, with_shadow=(14, (8, 14), 0.5))

    # ---- Stars flying from the merge toward the bears (motion streaks from blurred copies).
    flight = [("star_b", 0.62, (pc[0] + 330, pc[1] - 40), -12), ("star_a", 0.42, (pc[0] + 520, pc[1] + 150), 14),
              ("star_e", 0.34, (pc[0] + 210, pc[1] + 250), -20), ("star_c", 0.30, (pc[0] - 230, pc[1] - 150), 18),
              ("star_d", 0.26, (pc[0] + 640, pc[1] - 120), 8)]
    for name, f, c, rot in flight:
        st = scale(L[name], f).rotate(rot, resample=Image.BICUBIC, expand=True)
        dx, dy = c[0] - pc[0], c[1] - pc[1]
        n = math.hypot(dx, dy) or 1
        for i, a in ((3, 0.18), (2, 0.28), (1, 0.42)):
            ghost = st.copy()
            ghost.putalpha(ghost.getchannel("A").point(lambda v, a=a: int(v * a)))
            ghost = ghost.filter(ImageFilter.GaussianBlur(3))
            place(canvas, ghost, (c[0] - dx / n * 34 * i, c[1] - dy / n * 34 * i))
        place(canvas, outline(padded(st, 6), 3, (255, 247, 220)), c, with_shadow=(8, (4, 8), 0.35))

    # ---- Bears on the right: Tide Bear behind, the white hero Bear in front.
    tide = scale(L["bear_tide"], 0.66)
    tide = outline(padded(tide, 12), 8, (255, 255, 255))
    place(canvas, tide, (1755, 820), with_shadow=(18, (10, 18), 0.45))
    hero = scale(L["bear_white"], 0.8)
    hero = outline(padded(hero, 14), 9, (255, 255, 255))
    # Dark rim first so the white plush separates from the warm sky.
    rim = outline(padded(scale(L["bear_white"], 0.8), 14), 13, (90, 40, 70))
    place(canvas, rim, (1455, 800), with_shadow=(22, (12, 22), 0.5))
    place(canvas, hero, (1455, 800))

    # ---- Text.
    if variant == "A":
        title = wordmark("POCKET PALS", 150, tilt=4, max_w=1120)
        place(canvas, title, (650, 150))
        tag = tagline("MERGE · HATCH · DRESS UP", 64, tilt=4)
        place(canvas, tag, (660, 330))
    else:
        title = wordmark("POCKET PALS", 160, tilt=0, max_w=1250)
        place(canvas, title, (680, 140))
        tag = tagline("MERGE · HATCH · DRESS UP", 70)
        place(canvas, tag, (700, 1005))
    out = canvas.convert("RGB")
    out = ImageEnhance.Contrast(out).enhance(1.06)
    out = ImageEnhance.Color(out).enhance(1.1)
    return out


def main():
    L = build_layers()
    for variant, name in (("A", "ad-v1"), ("B", "ad-v1-B")):
        img = compose(L, variant)
        img.save(os.path.join(HERE, name + "-1920x1080.png"), optimize=True)
        img.resize((480, 270), Image.LANCZOS).save(os.path.join(HERE, name + "-480x270.png"))
        print("wrote", name)


if __name__ == "__main__":
    main()
