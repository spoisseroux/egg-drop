"""Compositions for the v2 store page. Called by build_v2.py (which builds the layers)."""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

import build_v2 as B

ad = B.ad
W, H = B.W, B.H
HERE = B.HERE
INK, CREAM, GOLD, MINT, WHITE = B.INK, B.CREAM, B.GOLD, B.MINT, B.WHITE
scale, outline, padded, screen, rays, radial, paste_clip = B.scale, B.outline, B.padded, B.screen, B.rays, B.radial, B.paste_clip
place = ad.place

PLATE = None


def plate():
    global PLATE
    if PLATE is None:
        PLATE = Image.open(os.path.join(B.AD, "layers", "bg.png")).convert("RGB")
    return PLATE


def gradient(size, top, bottom, angle=0.0):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip(yy / h + (xx / w - 0.5) * angle, 0, 1)[..., None]
    arr = np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def backdrop(size, top, bottom, burst, burst_color=(255, 226, 150), ray_color=(255, 232, 170), ray_len=None,
             texture=0.45, vignette=0.62, angle=0.25, count=14):
    """Family background: a two-colour sky, the blurred garden as faint texture, one light
    burst with rays behind the subject, and a vignette in the sky's own dark tone."""
    w, h = size
    g = np.asarray(gradient(size, top, bottom, angle)).astype(np.float32)
    lum = np.asarray(plate().resize(size, Image.LANCZOS).convert("L")).astype(np.float32) / 255
    g = g * (1 - texture / 2 + texture * lum[..., None])
    canvas = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    ray_len = ray_len or int(max(w, h) * 0.75)
    screen(canvas, radial(size, burst, int(ray_len * 0.8), burst_color, peak=200, power=1.5), 0, 0)
    screen(canvas, rays(size, burst, ray_len, ray_color, count=count, rotation=6), 0, 0)
    vign = Image.new("L", size, 0)
    ImageDraw.Draw(vign).ellipse((-w * 0.2, -h * 0.3, w * 1.2, h * 1.3), fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(max(w, h) // 11))
    dark = Image.new("RGBA", size, tuple(int(c * 0.35) for c in bottom) + (255,))
    lo = int(255 * vignette)
    return Image.composite(canvas, dark, vign.point(lambda v: int(lo + v * (255 - lo) / 255)))


def sticker(img, s=1.0, white=8, ink=5, rot=0, resample=Image.LANCZOS):
    """The family outline: a white sticker edge, then a thin ink rim."""
    im = scale(img, s, resample) if s != 1.0 else img
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    p = padded(im, white + ink + 6)
    p = outline(p, white, WHITE)
    return outline(p, ink, INK) if ink else p


def put(canvas, img, centre, sh=(18, (10, 18), 0.45)):
    place(canvas, img, centre, with_shadow=sh)


def caption(text, size, tilt=3, max_w=None, underline=True):
    return ad.wordmark(text, size, tilt=tilt, underline=underline, max_w=max_w)


def caption_lines(lines, size, tilt=3, gap=0.98):
    """Stacked caption, left aligned, in the wordmark style; the last line carries the gold rule."""
    marks = [ad.wordmark(t, size, tilt=0, underline=(i == len(lines) - 1)) for i, t in enumerate(lines)]
    step = int(size * gap)
    w = max(m.width for m in marks)
    h = step * (len(marks) - 1) + marks[-1].height
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, m in enumerate(marks):
        layer.alpha_composite(m, (0, i * step))
    return layer.rotate(tilt, resample=Image.BICUBIC, expand=True) if tilt else layer


def put_caption(canvas, lines, size, left=40, top=10, tilt=3):
    cap = caption_lines(lines, size, tilt)
    paste_clip(canvas, cap, left - 40, top)


def brand(canvas, pos, size=40):
    tag = ad.tagline("POCKET PALS", size)
    place(canvas, tag, pos)


def glow(canvas, centre, radius, color=(255, 236, 170), peak=220, power=1.8):
    screen(canvas, radial(canvas.size, centre, radius, color, peak=peak, power=power), 0, 0)


def flying_stars(canvas, L, origin, spots):
    for name, f, c, rot in spots:
        st = scale(L[name], f).rotate(rot, resample=Image.BICUBIC, expand=True)
        dx, dy = c[0] - origin[0], c[1] - origin[1]
        n = math.hypot(dx, dy) or 1
        for i, a in ((3, 0.16), (2, 0.26), (1, 0.4)):
            ghost = st.copy()
            ghost.putalpha(ghost.getchannel("A").point(lambda v, a=a: int(v * a)))
            ghost = ghost.filter(ImageFilter.GaussianBlur(3))
            place(canvas, ghost, (c[0] - dx / n * 34 * i, c[1] - dy / n * 34 * i))
        place(canvas, outline(padded(st, 8), 4, (255, 250, 228)), c, with_shadow=(8, (4, 8), 0.35))


def sparkles(canvas, spots, color=(255, 255, 255)):
    """Four-point glints in the style of the deck faceplates' own sparkles."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x, y, r in spots:
        k = r * 0.16
        d.polygon([(x, y - r), (x + k, y - k), (x + r, y), (x + k, y + k), (x, y + r), (x - k, y + k), (x - r, y), (x - k, y - k)], fill=color + (235,))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))


def grade(canvas, contrast=1.07, color=1.12):
    out = canvas.convert("RGB")
    out = ImageEnhance.Contrast(out).enhance(contrast)
    return ImageEnhance.Color(out).enhance(color)


def lift(img, color=1.3, bright=1.0):
    a = img.getchannel("A")
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(color)
    if bright != 1.0:
        rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def deck_on(canvas, deck, centre, s, angle, rim=(60, 30, 80), sat=1.25):
    """Place a deck matte (shell + its own soft shadow) with an ink rim round the solid shell.
    Returns a function mapping deck-layer coordinates to canvas coordinates."""
    d = lift(scale(deck, s), sat)
    dw, dh = d.size
    rot = d.rotate(angle, resample=Image.BICUBIC, expand=True)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    paste_clip(layer, rot, round(centre[0] - rot.width / 2), round(centre[1] - rot.height / 2))
    sh, (sx, sy) = B.shadow(layer, 26, (16, 28), 0.5, color=(20, 6, 30))
    paste_clip(canvas, sh, sx, sy)
    solid = layer.getchannel("A").point(lambda v: 255 if v > 200 else 0)
    ring = solid.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(1.5))
    rim_layer = Image.new("RGBA", canvas.size, rim + (0,))
    rim_layer.putalpha(ring)
    canvas.alpha_composite(rim_layer)
    canvas.alpha_composite(layer)

    def pt(px, py):
        t = math.radians(angle)
        dx, dy = px * s - dw / 2, py * s - dh / 2
        return (round(centre[0] + math.cos(t) * dx + math.sin(t) * dy), round(centre[1] - math.sin(t) * dx + math.cos(t) * dy))
    return pt


# ---------------------------------------------------------------- thumbnails


def thumb_lead(L):
    """1. The ad's idea, pushed: Prism Flare deck mid-chain, the merge popping out, the white
    and blue Bears, the rainbow Customization Egg cracking."""
    c = backdrop((W, H), (255, 122, 170), (255, 190, 120), (1560, 330), texture=0.5, ray_len=1250)
    c = Image.blend(c, plate().convert("RGBA"), 0.33)
    glow(c, (1560, 330), 620, (255, 214, 130), peak=210)
    screen(c, rays((W, H), (1560, 330), 900, (255, 226, 160), count=14, rotation=4), 0, 0)

    egg = sticker(lift(L["egg_look_open"], 1.15), 0.86, white=9, ink=5, rot=-10)
    put(c, egg, (1640, 300))

    pt = deck_on(c, L["deck_prism"], (600, 725), 1.0, 4.0, rim=(70, 34, 78), sat=1.35)
    m = pt(705, 540)
    pc = (m[0] + 10, m[1] - 70)
    screen(c, rays((W, H), pc, 620, (255, 205, 110)), 0, 0)
    glow(c, pc, 330, (255, 240, 190), peak=230)
    pop = sticker(L["pop_smileys"], 2.0, white=9, ink=0, rot=4, resample=Image.NEAREST)
    put(c, pop, pc, sh=(14, (8, 14), 0.5))
    flying_stars(c, L, pc, [("star_b", 0.62, (pc[0] + 330, pc[1] - 50), -12), ("star_a", 0.42, (pc[0] + 500, pc[1] + 170), 14),
                            ("star_e", 0.34, (pc[0] + 200, pc[1] + 250), -20), ("star_c", 0.30, (pc[0] - 240, pc[1] - 150), 18)])

    put(c, sticker(L["bear_tide"], 0.92, white=9, ink=5), (1735, 800))
    put(c, sticker(L["bear_white"], 1.08, white=10, ink=6), (1420, 790), sh=(22, (12, 22), 0.5))

    place(c, caption("POCKET PALS", 150, tilt=4, max_w=1120), (650, 150))
    place(c, ad.tagline("MERGE · HATCH · DRESS UP", 64, tilt=4), (660, 330))
    return grade(c)


def thumb_hatch(L):
    """2. One egg, cracked, with everything it can hold bursting out, and a Bear amazed."""
    ec = (1290, 670)
    c = backdrop((W, H), (64, 34, 150), (176, 52, 170), ec, burst_color=(255, 214, 120), ray_color=(255, 226, 150), ray_len=1500, texture=0.35, count=16)
    glow(c, ec, 560, (255, 226, 140), peak=235, power=1.5)

    back = sticker(lift(L["egg_toy_open"], 1.1), 0.72, white=7, ink=4, rot=8)
    put(c, back, (1770, 880))

    # What the two eggs hold: the six toys and the Customization jars, on an arc out of the crack.
    arc = [("jar_tide", 0.54, (800, 560), -18), ("toy_deck", 0.95, (960, 430), -14), ("toy_bone", 0.76, (1175, 345), -24),
           ("toy_top", 0.82, (1250, 160), -10), ("jar_citrus", 0.58, (1440, 130), 6), ("toy_ball", 0.76, (1620, 210), 0),
           ("jar_charm", 0.68, (1780, 380), 14), ("toy_carrot", 0.78, (1810, 610), -8), ("toy_sparkler", 0.78, (1590, 440), -22),
           ("jar_iris", 0.5, (1010, 640), -12), ("jar_jelly", 0.5, (1440, 350), 12)]
    for name, s, pos, rot in arc:
        dx, dy = pos[0] - ec[0], pos[1] - (ec[1] - 120)
        n = math.hypot(dx, dy)
        st = sticker(L[name], s, white=6, ink=4, rot=rot)
        ghost = st.copy()
        ghost.putalpha(ghost.getchannel("A").point(lambda v: int(v * 0.22)))
        place(c, ghost.filter(ImageFilter.GaussianBlur(6)), (pos[0] - dx / n * 46, pos[1] - dy / n * 46))
        put(c, st, pos, sh=(10, (6, 10), 0.4))

    egg = sticker(lift(L["egg_look_open"], 1.15), 1.36, white=11, ink=6)
    put(c, egg, ec, sh=(24, (12, 24), 0.5))
    glow(c, (ec[0] - 20, ec[1] - 120), 190, (255, 250, 220), peak=170, power=2.2)
    sparkles(c, [(1090, 560, 40), (1500, 600, 30), (1330, 320, 26), (700, 420, 22), (1700, 110, 30), (1860, 500, 22)])

    put(c, sticker(L["close_rose"], 1.0, white=10, ink=6), (330, 800), sh=(22, (12, 22), 0.5))

    put_caption(c, ["HATCH", "SURPRISE EGGS"], 112)
    brand(c, (1730, 1020))
    return grade(c)


def thumb_dress(L):
    """3. Six Bears, six looks: colour, finish, hats, shirts, eyes."""
    c = backdrop((W, H), (20, 150, 214), (96, 226, 196), (960, 560), burst_color=(220, 255, 240), ray_color=(210, 255, 244), ray_len=1500, texture=0.35, count=18)
    floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(floor).ellipse((-200, 900, W + 200, 1400), fill=(12, 92, 150, 150))
    c.alpha_composite(floor.filter(ImageFilter.GaussianBlur(30)))
    row = [("bear_mint", 0.92, (200, 800)), ("bear_iris", 0.98, (1715, 770)), ("bear_citrus", 1.02, (500, 745)), ("bear_tide", 1.02, (1420, 745)),
           ("bear_rose", 1.14, (800, 775)), ("bear_white", 1.2, (1115, 770))]
    for name, s, pos in row:
        put(c, sticker(L[name], s, white=9, ink=5), pos, sh=(18, (8, 20), 0.42))
    sparkles(c, [(1250, 250, 26), (1830, 330, 30), (1560, 130, 20)])
    put_caption(c, ["DRESS UP", "YOUR BEAR"], 128)
    brand(c, (1710, 1020))
    return grade(c)


def thumb_merge(L):
    """4. The game: a x3 chain on a warm faceplate against a cool sky, and your Bear cheering."""
    c = backdrop((W, H), (36, 30, 120), (120, 48, 190), (860, 620), burst_color=(255, 200, 120), ray_color=(255, 214, 140), ray_len=1500, texture=0.35, count=16)
    pt = deck_on(c, L["deck_sorbet"], (820, 730), 1.12, -4.0, rim=(60, 26, 70), sat=1.3)
    m = pt(674, 498)
    pc = (m[0] + 30, m[1] - 110)
    screen(c, rays((W, H), pc, 700, (255, 210, 120)), 0, 0)
    glow(c, pc, 380, (255, 240, 190), peak=235)
    pop = sticker(L["pop_gems"], 2.9, white=10, ink=0, rot=-4, resample=Image.NEAREST)
    put(c, pop, pc, sh=(16, (8, 16), 0.5))
    flying_stars(c, L, pc, [("star_b", 0.7, (pc[0] + 430, pc[1] - 150), -12), ("star_a", 0.46, (pc[0] + 560, pc[1] + 60), 14),
                            ("star_e", 0.36, (pc[0] - 420, pc[1] + 40), -20), ("star_c", 0.34, (pc[0] - 330, pc[1] - 230), 18),
                            ("star_d", 0.3, (pc[0] + 260, pc[1] + 290), 8)])
    put(c, sticker(L["close_tide"], 0.92, white=10, ink=6), (1640, 780), sh=(22, (12, 22), 0.5))
    put_caption(c, ["MERGE", "BIG CHAINS"], 128)
    brand(c, (1720, 110))
    return grade(c)


def thumb_friends(L):
    """5. One real frame: six Bears in the Pet Park (client-side PetFactory Bears at garden
    scale, in the live park, nothing composited but the caption)."""
    src = Image.open(B.raw("park-friends.jpg")).convert("RGB").crop((110, 0, 1570, 734))
    f = W / src.width
    src = src.resize((W, round(src.height * f)), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 60, 2))
    extra = H - src.height
    top = extra * 2 // 3
    bottom = extra - top
    c = Image.new("RGB", (W, H))
    c.paste(src, (0, top))
    sky = src.crop((0, 0, W, top)).transpose(Image.FLIP_TOP_BOTTOM).filter(ImageFilter.GaussianBlur(10))
    c.paste(sky, (0, 0))
    grass = src.crop((0, src.height - bottom, W, src.height)).transpose(Image.FLIP_TOP_BOTTOM)
    c.paste(grass, (0, top + src.height))
    seam = Image.new("L", (W, H), 0)
    ImageDraw.Draw(seam).rectangle((0, top - 14, W, top + 14), fill=255)
    c = Image.composite(c.filter(ImageFilter.GaussianBlur(6)), c, seam.filter(ImageFilter.GaussianBlur(8)))
    c = c.convert("RGBA")
    shade = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shade).rectangle((0, 0, W, 300), fill=120)
    c = Image.composite(Image.new("RGBA", (W, H), (120, 30, 90, 255)), c, shade.filter(ImageFilter.GaussianBlur(120)).point(lambda v: int(v * 0.55)))
    put_caption(c, ["PLAY WITH", "FRIENDS"], 128)
    brand(c, (1720, 1010))
    return grade(c, 1.08, 1.2)


def thumb_decks(L):
    """6. Faceplates and ball themes: three real rounds on three decks."""
    c = backdrop((W, H), (255, 120, 88), (255, 72, 150), (960, 600), burst_color=(255, 236, 170), ray_color=(255, 232, 170), ray_len=1500, texture=0.35, count=18)
    deck_on(c, L["deck_prism"], (560, 560), 0.70, 9.0, rim=(70, 34, 78), sat=1.35)
    deck_on(c, L["deck_scout"], (1440, 500), 0.72, -8.0, rim=(20, 60, 60), sat=1.25)
    pt = deck_on(c, L["deck_night"], (1000, 790), 0.92, -1.5, rim=(30, 14, 60), sat=1.3)
    m = pt(673, 516)
    pc = (m[0], m[1] - 40)
    glow(c, pc, 260, (200, 255, 220), peak=170)
    pop = sticker(L["pop_kittens"], 2.3, white=8, ink=0, rot=-1.5, resample=Image.NEAREST)
    put(c, pop, pc, sh=(14, (8, 14), 0.5))
    sparkles(c, [(210, 250, 30), (1760, 250, 34), (1700, 900, 26), (230, 880, 24)])
    put_caption(c, ["CUSTOMIZE", "YOUR DECK"], 124)
    brand(c, (240, 1020))
    return grade(c)


# ---------------------------------------------------------------- icons

S = 1024


def icon_title(c, text="POCKET PALS", size=150, centre=(512, 150), max_w=930, tilt=4):
    place(c, caption(text, size, tilt=tilt, max_w=max_w), centre)


def icon_a(L):
    """A. The current icon's identity (white Bear, red Pom Beanie, Bell Collar, Ball, pink
    garden, tilted wordmark), punched up: bigger face, a clean cut-out with the sticker rim,
    a light burst behind the head and a deeper, more saturated sky."""
    bg = plate().crop((500, 0, 1580, 1080)).resize((S, S), Image.LANCZOS)
    bg = ImageEnhance.Color(bg).enhance(1.5)
    c = bg.convert("RGBA")
    tint = gradient((S, S), (255, 70, 150), (70, 200, 190))
    c = Image.blend(c, tint.convert("RGBA"), 0.42)
    glow(c, (512, 600), 560, (255, 236, 170), peak=225, power=1.4)
    screen(c, rays((S, S), (512, 600), 900, (255, 240, 190), count=14, rotation=6), 0, 0)
    vign = Image.new("L", (S, S), 0)
    ImageDraw.Draw(vign).ellipse((-160, -160, S + 160, S + 160), fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(90))
    c = Image.composite(c, Image.new("RGBA", (S, S), (90, 20, 70, 255)), vign.point(lambda v: int(150 + v * 105 / 255)))
    bear = sticker(L["close_white"], 1.42, white=12, ink=8)
    put(c, bear, (500, 730), sh=(26, (12, 24), 0.5))
    icon_title(c, size=160, centre=(512, 140), max_w=960)
    return grade(c, 1.06, 1.1)


def split_egg(egg):
    """Top shell, bottom shell of an open egg cut-out: the flat Neon core between them is found
    by colour, and each column is cut at the core's top and bottom edge."""
    a = np.asarray(egg).astype(np.int32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    core = (al > 200) & (r > 232) & (b > 232) & (g > 160) & (g < 232) & (r - g > 22)
    core = np.asarray(Image.fromarray(np.where(core, 255, 0).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(7))) > 0
    h, w = core.shape
    cols = np.where(core.any(0))[0]
    top_edge = np.full(w, -1.0)
    bot_edge = np.full(w, -1.0)
    for x in cols:
        ys = np.where(core[:, x])[0]
        top_edge[x], bot_edge[x] = ys.min(), ys.max()
    xs = np.arange(w)
    top_edge = np.interp(xs, cols, top_edge[cols])
    bot_edge = np.interp(xs, cols, bot_edge[cols])
    yy = np.mgrid[0:h, 0:w][0]
    top = egg.copy()
    top.putalpha(Image.fromarray(np.where((yy < top_edge[None, :]) & ~core, al, 0).astype(np.uint8)))
    bottom = egg.copy()
    bottom.putalpha(Image.fromarray(np.where((yy > bot_edge[None, :]) & ~core, al, 0).astype(np.uint8)))
    return B.trim(top, 2), B.trim(bottom, 2), int(bot_edge.max())


def icon_b(L, tinted=True):
    """B. Hatch: the blue Bear popping out of the rainbow Customization Egg, top shell flying.
    Cool Bear on a hot gold-to-orange burst. No text."""
    c = backdrop((S, S), (255, 196, 60), (255, 96, 60), (512, 470), burst_color=(255, 250, 200), ray_color=(255, 246, 190), ray_len=950, texture=0.2, vignette=0.7, count=14)
    top, bottom, _ = split_egg(lift(L["egg_look_open"], 1.2))
    bs = 2.25
    bot = sticker(bottom, bs, white=12, ink=8)
    bot_c = (512, 860)
    bear = scale(L["close_tide"], 1.02)
    by = 480
    cut = bot_c[1] - 40
    bx0, by0 = round(512 - bear.width / 2), round(by - bear.height / 2)
    arr = np.asarray(bear).copy()
    limit = max(0, cut - by0)
    arr[limit:, :, 3] = 0
    bear = Image.fromarray(arr, "RGBA")
    put(c, sticker(bear, 1.0, white=12, ink=8), (512, by), sh=(22, (10, 20), 0.45))
    put(c, bot, bot_c, sh=(22, (10, 20), 0.45))
    put(c, sticker(top, 1.05, white=9, ink=6, rot=-32), (890, 150), sh=(14, (8, 14), 0.4))
    sparkles(c, [(120, 190, 44), (900, 540, 34), (130, 640, 28)])
    return grade(c, 1.06, 1.12)


def icon_c(L):
    """C. Pet + deck (Spencer, 2026-11-19: "with a pocket deck at the bottom instead of the
    balls"): the pink Bear with Sparkle Eyes holding the Prism Flare Pocket Deck mid-chain,
    a Star at its ear, on mint-to-teal. Warm subject, cool field. No text."""
    c = backdrop((S, S), (40, 200, 190), (30, 110, 200), (512, 420), burst_color=(220, 255, 236), ray_color=(214, 255, 240), ray_len=950, texture=0.2, vignette=0.7, count=14)
    put(c, sticker(L["close_rose"], 1.04, white=12, ink=8), (512, 412), sh=(24, (12, 22), 0.5))
    deck = L["deck_prism"]
    put(c, sticker(deck, 1010 / deck.width, white=12, ink=8, rot=5), (512, 836), sh=(22, (10, 20), 0.5))
    put(c, sticker(L["star_b"], 0.62, white=8, ink=6, rot=-14), (880, 310), sh=(14, (8, 14), 0.45))
    sparkles(c, [(110, 170, 40), (920, 200, 34), (90, 520, 24)])
    return grade(c, 1.06, 1.12)


# ---------------------------------------------------------------- contact sheet


def contact_sheet(icons, thumbs, path):
    font = ImageFont.truetype(ad.FREDOKA, 30)
    small = ImageFont.truetype(ad.FREDOKA, 22)
    v1_icon = Image.open(os.path.join(B.V1, "UPLOAD-THESE", "ICON-icon-D-title-1024.png")).convert("RGB")
    v1_thumb = Image.open(os.path.join(B.V1, "UPLOAD-THESE", "1-12-merge-lead.png")).convert("RGB")
    ad_img = Image.open(os.path.join(B.AD, "ad-v1-1920x1080.png")).convert("RGB")
    pad = 30
    sw = pad + 4 * (512 + pad)
    tw, th = 480, 270
    sh = 70 + 512 + 50 + 60 + 150 + 60 + 70 + 3 * (th + 56) + pad
    sheet = Image.new("RGB", (sw, sh), (28, 24, 44))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 20), "ICONS at 512 px  (v1 = on the page now)", font=font, fill=(255, 246, 222))
    cells = [("v1 icon D (current)", v1_icon)] + [("v2 icon " + k, icons[k]) for k in "ABC"]
    y = 70
    for i, (label, im) in enumerate(cells):
        x = pad + i * (512 + pad)
        sheet.paste(im.resize((512, 512), Image.LANCZOS), (x, y))
        d.text((x, y + 518), label, font=small, fill=(200, 200, 220))
    y += 512 + 50
    d.text((pad, y), "ICONS at 150 px  (how they show in Roblox grids)", font=font, fill=(255, 246, 222))
    y += 50
    for i, (label, im) in enumerate(cells):
        x = pad + i * (512 + pad)
        sheet.paste(im.resize((150, 150), Image.LANCZOS), (x, y))
        d.text((x + 165, y + 60), label, font=small, fill=(200, 200, 220))
    y += 150 + 50
    d.text((pad, y), "THUMBNAILS at 480x270", font=font, fill=(255, 246, 222))
    y += 56
    tcells = [("v1 thumbnail 1 (current lead)", v1_thumb), ("ad-v1 (approved ad)", ad_img)] + [("v2 %s" % n, im) for n, im in thumbs]
    gap = (sw - 2 * pad - 4 * tw) // 3
    for i, (label, im) in enumerate(tcells):
        x = pad + (i % 4) * (tw + gap)
        yy = y + (i // 4) * (th + 56)
        sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, yy))
        d.text((x, yy + th + 6), label, font=small, fill=(200, 200, 220))
    sheet.save(path, optimize=True)


def main(L):
    os.makedirs(os.path.join(HERE, "icon"), exist_ok=True)
    os.makedirs(os.path.join(HERE, "thumbnails"), exist_ok=True)
    icons = {"A": icon_a(L), "B": icon_b(L), "C": icon_c(L)}
    names = {"A": "icon-A-bear-title", "B": "icon-B-hatch", "C": "icon-C-bear-deck"}
    for k, im in icons.items():
        im.save(os.path.join(HERE, "icon", names[k] + "-1024.png"), optimize=True)
        im.resize((150, 150), Image.LANCZOS).save(os.path.join(HERE, "icon", names[k] + "-150.png"))
    thumbs = [("1-lead-merge-hatch-dress-up", thumb_lead(L)), ("2-hatch-surprise-eggs", thumb_hatch(L)), ("3-dress-up-your-bear", thumb_dress(L)),
              ("4-merge-big-chains", thumb_merge(L)), ("5-play-with-friends", thumb_friends(L)), ("6-customize-your-deck", thumb_decks(L))]
    for n, im in thumbs:
        im.save(os.path.join(HERE, "thumbnails", n + ".png"), optimize=True)
        print("wrote", n)
    contact_sheet(icons, thumbs, os.path.join(HERE, "contact-sheet.png"))
    print("wrote contact sheet")
