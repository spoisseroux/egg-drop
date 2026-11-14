"""Collection book thumbnail atlas (v1 track D). One 1024 x 1024 upload for BookView.Art.atlas.

Cells are 128 px, 8 columns. Rows 0..3 hold the full-colour thumbnails, rows 4..7 the same
slots as white "not yet" silhouettes (the client tints them with the line colour and fades
them, like the stamp card outlines). Slot n (1-based) is column (n-1) % 8, row (n-1) // 8 in
the colour half and that row + 4 in the silhouette half.

Sources:
  wardrobe + toys + finishes  Blender renders in assets/ui/book/raw (render_book_icons.py)
  discoveries                  drawn here: house-style medal badges (filled shapes, round
                               ends, one highlight): tier V ball, chain of 5, the six field
                               goal templates and the three difficulties.
Balls and faceplates are not in the atlas: BookView draws them live (the BallShop strip
balls and the Deck style mini deck).

Silhouettes keep their context faint: a wardrobe item is solid white over a 30% Bear, a
badge's icon is solid over a 30% disc, so "missing" still says what goes where.

Outputs:
  assets/ui/book/book-atlas.png                 the upload
  assets/ui/book/book-atlas.json                slot order (mirrors BookView.Art.slots)
  artifacts/overnight-2026-11-14/art/book-atlas-preview.png   review sheet at 128 / 48 px, owned + missing
Usage: python scripts/deck_art/build_book_atlas.py   (run render_book_icons.py first)
"""
from __future__ import annotations

import json
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BOOK = os.path.join(ROOT, "assets", "ui", "book")
RAW = os.path.join(BOOK, "raw")
ART = os.path.join(ROOT, "artifacts", "overnight-2026-11-14", "art")
CELL, COLS, ROWS = 128, 8, 4
SS = 4
N = CELL * SS

# Book item ids (BookCatalog) in slot order.
WARDROBE = ["beanie", "sunhat", "flowercrown", "tee", "hoodie", "beads", "bellcollar", "ring", "starstud", "sparkle", "sleepy", "blep", "heart"]
TOYS = ["ball", "bone", "sparkler"]
FINISHES = ["gloss", "matte", "metal"]
DISCOVERIES = ["tier_five", "chain_five", "win_bank_pair", "win_creek_crossing", "win_lantern_chain", "win_ripple_relay",
               "win_bank_bounce", "win_mirror_marks", "win_easy", "win_medium", "win_hard"]
# Slice A (2026-11-14): face items sold later. Appended after the discoveries so no existing slot
# moves; slots past 32 land on page 2 (book-atlas-2.png, BookView.Art.atlas2).
WARDROBE_LATE = ["round", "happy", "w", "lash"]   # slot 32 was Wide Eyes (never published)
# Overnight 2026-11-14 (slices B and D): appended again, so slots 1..34 never move. Page 2 holds 35..48.
WARDROBE_B = ["blush", "partyhat", "bowtail", "acorn", "bands", "specs"]
TOYS_B = ["wobble_top", "squeaky_carrot"]
DISCOVERIES_B = ["pet_night", "play_date", "full_outfit", "win_each_item", "tidy_25", "rounds_100"]
SLOTS = (["pip:" + i for i in WARDROBE] + ["toy:" + i for i in TOYS] + ["finish:" + i for i in FINISHES] + DISCOVERIES
         + ["pip:" + i for i in WARDROBE_LATE] + ["pip:" + i for i in WARDROBE_B] + ["toy:" + i for i in TOYS_B]
         + DISCOVERIES_B)
PER_PAGE = 32

CREAM = (255, 244, 220, 255)
INK = (14, 15, 18, 255)
TIER = [(46, 139, 255), (255, 138, 26), (34, 224, 106), (255, 77, 166), (166, 107, 255)]  # BallThemes vivid bodies
TIER_DEEP = [(10, 63, 214), (224, 64, 10), (4, 150, 63), (196, 18, 111), (91, 33, 214)]
GOLD, GOLD_RIM = (255, 193, 77), (201, 138, 30)
TEAL, TEAL_RIM = (127, 224, 200), (40, 140, 122)
GOOD, STARS, DANGER = (123, 228, 149), (255, 193, 77), (255, 90, 110)
# Slice D medal families: rose for pet moments, night for after dark, violet for round items.
ROSE, ROSE_RIM = (255, 143, 177), (214, 84, 128)
NIGHT, NIGHT_RIM = (70, 76, 160), (40, 43, 104)
VIOLET, VIOLET_RIM = (166, 107, 255), (91, 33, 214)
CLEAR = (0, 0, 0, 0)          # ImageDraw overwrites in RGBA: drawing with CLEAR cuts a hole in the icon layer
WATER = (110, 196, 255)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


# ------------------------------------------------------------------ 3D renders
def fit(im, box=CELL - 8):
    """Trim to the alpha bounds and fit inside `box`, centred in a CELL square."""
    bb = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if bb:
        im = im.crop(bb)
    k = box / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(im, ((CELL - im.width) // 2, (CELL - im.height) // 2))
    return out


# Wardrobe items shown on their own (render_book_icons.ALONE): the cell is the item alone.
ALONE = {"beads", "bellcollar", "ring", "starstud", "heart"}


def porthole(size):
    """Soft round window: the Bear crops (head, chest) end in a circle, not a hard square,
    matching the round discovery badges."""
    m = Image.new("L", (size * SS, size * SS), 0)
    r = size * SS * 0.49
    c = size * SS / 2
    ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255)
    return m.resize((size, size), Image.LANCZOS)


def render_cell(name, mask_name=None, box=CELL - 8, sparkle=False, round_window=False):
    """Colour cell and silhouette cell from a raw render (and its item mask)."""
    full = Image.open(os.path.join(RAW, name + ".png")).convert("RGBA")
    mask = Image.open(os.path.join(RAW, mask_name + ".png")).convert("RGBA") if mask_name else None
    bb = full.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if mask is not None:
        mb = mask.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        bb = mb and (min(bb[0], mb[0]), min(bb[1], mb[1]), max(bb[2], mb[2]), max(bb[3], mb[3])) or bb
    # Crop square around the content so colour and silhouette share one framing.
    cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
    half = max(bb[2] - bb[0], bb[3] - bb[1]) / 2
    sq = tuple(round(v) for v in (cx - half, cy - half, cx + half, cy + half))
    if round_window:
        sq = (0, 0, full.width, full.height)   # the camera framed it for the window already
    colour = full.crop(sq).resize((box, box), Image.LANCZOS)
    a_full = full.getchannel("A").crop(sq).resize((box, box), Image.LANCZOS)
    if mask is not None:
        a_item = mask.getchannel("A").crop(sq).resize((box, box), Image.LANCZOS)
        sil_a = ImageChops.lighter(a_full.point(lambda v: int(v * 0.30)), a_item)
    else:
        sil_a = a_full
    if round_window:
        win = porthole(box)
        colour.putalpha(ImageChops.multiply(colour.getchannel("A"), win))
        sil_a = ImageChops.multiply(sil_a, win)
    off = (CELL - box) // 2
    c = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    c.alpha_composite(colour, (off, off))
    if sparkle:
        c = add_sparkles(c)
    s = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    sil = Image.new("RGBA", (box, box), (255, 255, 255, 255))
    sil.putalpha(sil_a)
    s.alpha_composite(sil, (off, off))
    return c, s


def add_sparkles(cell):
    """Two four-point glints (the gloss finish's highlight, readable at 48 px)."""
    big = cell.resize((N, N), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    for x, y, r in ((0.80, 0.20, 0.13), (0.92, 0.40, 0.07)):
        star(d, x * N, y * N, r * N, (255, 255, 255, 255), outline=(14, 15, 18, 200))
    return big.resize((CELL, CELL), Image.LANCZOS)


def star(d, cx, cy, r, fill, outline=None, k=0.22):
    pts = []
    for i in range(16):
        a = math.pi / 2 + i * math.pi / 8
        rr = r if i % 4 == 0 else (r * k if i % 2 == 1 else r * 0.42 * k + r * 0.18)
        pts.append((cx + rr * math.cos(a), cy - rr * math.sin(a)))
    if outline:
        d.polygon(pts, fill=fill, outline=outline, width=max(2, int(r * 0.08)))
    else:
        d.polygon(pts, fill=fill)


# ------------------------------------------------------------------ discovery badges
def canvas():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def disc_layer(face, rim):
    """Medal: a rim ring, the face, a soft lower shade and one top highlight arc."""
    im = canvas()
    d = ImageDraw.Draw(im)
    c, R = N / 2, N * 0.46
    d.ellipse([c - R, c - R + N * 0.02, c + R, c + R + N * 0.02], fill=shade(rim, 0.7))       # base lip
    d.ellipse([c - R, c - R, c + R, c + R], fill=rim + (255,))
    r = R * 0.84
    d.ellipse([c - r, c - r, c + r, c + r], fill=face + (255,))
    # lower shade inside the face
    sh = canvas()
    ImageDraw.Draw(sh).ellipse([c - r, c - r * 0.55, c + r, c + r * 1.5], fill=shade(face, 0.88))
    m = canvas()
    ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 255, 255))
    im.alpha_composite(Image.composite(sh, canvas(), m.getchannel("A")))
    # highlight arc on the rim
    hl = canvas()
    ImageDraw.Draw(hl).arc([c - R * 0.93, c - R * 0.93, c + R * 0.93, c + R * 0.93], 200, 290, fill=(255, 255, 255, 150), width=int(N * 0.025))
    im.alpha_composite(hl)
    return im


def ball(d, cx, cy, r, tier, face=True):
    body, deep = TIER[tier - 1], TIER_DEEP[tier - 1]
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=deep + (255,))
    d.ellipse([cx - r * 0.94, cy - r * 0.98, cx + r * 0.9, cy + r * 0.86], fill=body + (255,))
    d.ellipse([cx - r * 0.55, cy - r * 0.72, cx - r * 0.12, cy - r * 0.42], fill=(255, 255, 255, 210))
    if face and r > N * 0.05:
        e = r * 0.12
        for sx in (-1, 1):
            d.ellipse([cx + sx * r * 0.32 - e, cy - e, cx + sx * r * 0.32 + e, cy + e], fill=INK)
        d.arc([cx - r * 0.24, cy - r * 0.02, cx + r * 0.24, cy + r * 0.38], 20, 160, fill=INK, width=max(2, int(r * 0.09)))


def roman_v(d, cx, cy, h, fill):
    w = h * 0.42
    t = h * 0.2
    d.line([(cx - w, cy - h / 2), (cx, cy + h / 2), (cx + w, cy - h / 2)], fill=fill, width=int(t), joint="curve")
    for x in (cx - w, cx + w, cx):
        yy = cy - h / 2 if x != cx else cy + h / 2
        d.ellipse([x - t / 2, yy - t / 2, x + t / 2, yy + t / 2], fill=fill)


def icon_tier_five(d):
    ball(d, N * 0.5, N * 0.53, N * 0.25, 5)
    # a tiny crown-like "V" plate above
    d.rounded_rectangle([N * 0.39, N * 0.12, N * 0.61, N * 0.27], N * 0.04, fill=CREAM, outline=INK, width=int(N * 0.012))
    roman_v(d, N * 0.5, N * 0.195, N * 0.09, (91, 33, 214, 255))


def icon_chain_five(d):
    pts = []
    for i in range(5):
        a = math.radians(200 - i * 55)
        pts.append((N * 0.5 + math.cos(a) * N * 0.24, N * 0.56 - math.sin(a) * N * 0.20))
    # links
    d.line(pts, fill=CREAM, width=int(N * 0.05), joint="curve")
    for i, (x, y) in enumerate(pts):
        ball(d, x, y, N * (0.07 + i * 0.012), i + 1, face=False)
    # "5" tag
    d.ellipse([N * 0.40, N * 0.62, N * 0.60, N * 0.82], fill=CREAM, outline=INK, width=int(N * 0.012))
    five(d, N * 0.5, N * 0.72, N * 0.12)


def five(d, cx, cy, h):
    w, t = h * 0.36, h * 0.18
    f = INK
    d.line([(cx + w, cy - h / 2), (cx - w, cy - h / 2), (cx - w, cy - h * 0.05)], fill=f, width=int(t), joint="curve")
    d.arc([cx - w * 1.1, cy - h * 0.18, cx + w * 1.1, cy + h / 2], 200, 140 + 360, fill=f, width=int(t))


def bank(d, left):
    x0, x1 = (N * 0.16, N * 0.38) if left else (N * 0.62, N * 0.84)
    d.rounded_rectangle([x0, N * 0.62, x1, N * 0.72], N * 0.03, fill=CREAM)


def icon_bank_pair(d):
    bank(d, True)
    bank(d, False)
    ball(d, N * 0.27, N * 0.50, N * 0.11, 3, face=False)
    ball(d, N * 0.73, N * 0.50, N * 0.11, 3, face=False)
    # a pairing tick between them
    d.line([(N * 0.42, N * 0.40), (N * 0.58, N * 0.40)], fill=CREAM, width=int(N * 0.035))
    for x in (N * 0.42, N * 0.58):
        d.ellipse([x - N * 0.02, N * 0.38, x + N * 0.02, N * 0.42], fill=CREAM)


def wave(d, y, amp, color, width):
    pts = [(N * (0.14 + i * 0.72 / 40), y + amp * math.sin(i / 40 * math.pi * 4)) for i in range(41)]
    d.line(pts, fill=color, width=width, joint="curve")


def icon_creek_crossing(d):
    d.rounded_rectangle([N * 0.14, N * 0.58, N * 0.86, N * 0.76], N * 0.06, fill=WATER + (255,))
    wave(d, N * 0.63, N * 0.012, (230, 248, 255, 255), int(N * 0.018))
    wave(d, N * 0.70, N * 0.012, (230, 248, 255, 200), int(N * 0.014))
    # hop arc (dotted) and the ball at its top
    for i in range(9):
        t = i / 8
        x = N * (0.22 + 0.56 * t)
        y = N * 0.52 - math.sin(t * math.pi) * N * 0.22
        r = N * 0.016
        if i not in (3, 4, 5):
            d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM)
    ball(d, N * 0.5, N * 0.30, N * 0.10, 2, face=False)


def lantern(d, cx, top, w, h, glow):
    """A round paper lantern: dark caps, a glowing body with two ribs and a light core."""
    d.line([(cx, top - N * 0.10), (cx, top)], fill=CREAM, width=int(N * 0.014))
    d.rounded_rectangle([cx - w * 0.30, top - N * 0.01, cx + w * 0.30, top + N * 0.035], N * 0.012, fill=INK)
    body = [cx - w / 2, top + N * 0.02, cx + w / 2, top + N * 0.02 + h]
    d.ellipse([body[0] - N * 0.02, body[1] - N * 0.02, body[2] + N * 0.02, body[3] + N * 0.02], fill=glow + (90,))
    d.ellipse(body, fill=glow + (255,))
    for k in (-0.22, 0.22):
        d.arc([cx - w * abs(k) * 2.2, body[1], cx + w * abs(k) * 2.2, body[3]], 270 if k < 0 else 90, 90 if k < 0 else 270, fill=shade(glow, 0.72), width=int(N * 0.012))
    d.ellipse([cx - w * 0.18, body[1] + h * 0.28, cx + w * 0.18, body[3] - h * 0.28], fill=(255, 248, 210, 255))
    d.rounded_rectangle([cx - w * 0.22, body[3] - N * 0.012, cx + w * 0.22, body[3] + N * 0.025], N * 0.01, fill=INK)
    d.line([(cx, body[3] + N * 0.025), (cx, body[3] + N * 0.07)], fill=INK, width=int(N * 0.012))


def icon_lantern_chain(d):
    d.arc([N * 0.06, N * 0.06, N * 0.94, N * 0.50], 25, 155, fill=CREAM, width=int(N * 0.02))
    lantern(d, N * 0.28, N * 0.38, N * 0.20, N * 0.22, (255, 160, 60))
    lantern(d, N * 0.50, N * 0.44, N * 0.22, N * 0.24, (255, 112, 136))
    lantern(d, N * 0.72, N * 0.38, N * 0.20, N * 0.22, (255, 196, 70))


def icon_ripple_relay(d):
    cx, cy = N * 0.5, N * 0.70
    for i, r in enumerate((0.16, 0.25, 0.34)):
        d.arc([cx - N * r, cy - N * r, cx + N * r, cy + N * r], 205, 335, fill=CREAM if i < 2 else (230, 255, 248, 200), width=int(N * 0.032))
    ball(d, cx, cy - N * 0.02, N * 0.09, 1, face=False)
    # relay arrow
    d.line([(N * 0.30, N * 0.24), (N * 0.70, N * 0.24)], fill=INK, width=int(N * 0.03))
    d.polygon([(N * 0.74, N * 0.24), (N * 0.66, N * 0.19), (N * 0.66, N * 0.29)], fill=INK)


def icon_bank_bounce(d):
    d.rounded_rectangle([N * 0.70, N * 0.18, N * 0.80, N * 0.80], N * 0.04, fill=CREAM)
    path = [(N * 0.22, N * 0.70), (N * 0.66, N * 0.46), (N * 0.30, N * 0.26)]
    d.line(path, fill=INK, width=int(N * 0.028), joint="curve")
    d.polygon([(N * 0.26, N * 0.24), (N * 0.36, N * 0.22), (N * 0.33, N * 0.31)], fill=INK)
    for x, y in ((N * 0.66, N * 0.46),):
        for k in (-1, 1):
            d.line([(x - N * 0.02, y + k * N * 0.06), (x - N * 0.07, y + k * N * 0.10)], fill=CREAM, width=int(N * 0.018))
    ball(d, N * 0.22, N * 0.70, N * 0.09, 4, face=False)


def icon_mirror_marks(d):
    for i in range(7):
        y = N * (0.16 + i * 0.1)
        d.line([(N * 0.5, y), (N * 0.5, y + N * 0.05)], fill=CREAM, width=int(N * 0.022))
    for sx in (-1, 1):
        cx = N * 0.5 + sx * N * 0.18
        star(d, cx, N * 0.42, N * 0.11, CREAM + (255,) if len(CREAM) == 3 else CREAM, k=0.5)
        d.ellipse([cx - N * 0.05, N * 0.62, cx + N * 0.05, N * 0.72], fill=INK)
        d.ellipse([cx - N * 0.03, N * 0.64, cx + N * 0.03, N * 0.70], fill=CREAM)


def icon_bars(d, level):
    """The HUD's three difficulty bars (DeckScreen diffBars), `level` of them filled."""
    for i in range(3):
        x0 = N * (0.27 + i * 0.17)
        h = N * (0.18 + i * 0.10)
        d.rounded_rectangle([x0, N * 0.70 - h, x0 + N * 0.12, N * 0.70], N * 0.045, fill=INK if i < level else (14, 15, 18, 70))
    star(d, N * 0.5, N * 0.24, N * 0.08, INK, k=0.45)


# ---- slice D badges (overnight 2026-11-14)
def stroke(d, pts, t, fill):
    """A polyline with round ends and joints, t wide."""
    d.line(pts, fill=fill, width=int(t), joint="curve")
    for x, y in pts:
        d.ellipse([x - t / 2, y - t / 2, x + t / 2, y + t / 2], fill=fill)


def heart(d, cx, cy, size, fill):
    """The wearables' heart_outline formula (build_bear_wearables.py), so 2D and 3D hearts match."""
    pts = []
    for i in range(48):
        t = 2 * math.pi * i / 48
        pts.append((cx + size * 16 * math.sin(t) ** 3 / 17.0,
                    cy - size * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t) + 2.5) / 17.0))
    d.polygon(pts, fill=fill)


def bear_head(d, cx, cy, r, fill, gap=0.0):
    """Round head with two round ears. gap > 0 first clears a halo, so overlapping heads stay apart."""
    for rr, col in (((r + gap), CLEAR), (r, fill)) if gap else ((r, fill),):
        k = rr / r
        for sx in (-1, 1):
            ex, ey, er = cx + sx * r * 0.74, cy - r * 0.72, r * 0.375 * k
            d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=col)
        d.ellipse([cx - rr, cy - rr * 0.94, cx + rr, cy + rr * 0.94], fill=col)


def digit(d, ch, cx, cy, h, t, fill):
    """Rounded numerals 0, 1, 2, 5: h tall, strokes t wide. Returns nothing; widths are in DIGIT_W."""
    w = h * DIGIT_W[ch]
    top, bot = cy - h / 2 + t / 2, cy + h / 2 - t / 2
    x0, x1 = cx - w / 2 + t / 2, cx + w / 2 - t / 2
    if ch == "0":
        d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], w / 2, outline=fill, width=int(t))
    elif ch == "1":
        stroke(d, [(x0, top + h * 0.16), (x1, top), (x1, bot)], t, fill)
    elif ch == "2":
        r = (x1 - x0) / 2
        d.arc([x0 - t / 2, top - t / 2, x1 + t / 2, top + 2 * r + t / 2], 180, 360 + 35, fill=fill, width=int(t))
        ex, ey = cx + r * math.cos(math.radians(35)), top + r + r * math.sin(math.radians(35))
        stroke(d, [(ex, ey), (x0, bot), (x1, bot)], t, fill)
        d.ellipse([x0 - t / 2, top + r - t / 2, x0 + t / 2, top + r + t / 2], fill=fill)
    elif ch == "5":
        mid = cy - h * 0.06
        stroke(d, [(x1, top), (x0, top), (x0, mid)], t, fill)
        r = (bot - mid) / 2
        d.arc([x1 - 2 * r - t / 2, mid - t / 2, x1 + t / 2, bot + t / 2], 270 - 55, 90 + 55, fill=fill, width=int(t))
        d.ellipse([x0 - t / 2, mid - t / 2, x0 + t / 2, mid + t / 2], fill=fill)


DIGIT_W = {"0": 0.62, "1": 0.36, "2": 0.62, "5": 0.62}


def number(d, text, cx, cy, h, t, fill, gap=0.16):
    widths = [h * DIGIT_W[c] for c in text]
    x = cx - (sum(widths) + h * gap * (len(text) - 1)) / 2
    for c, w in zip(text, widths):
        digit(d, c, x + w / 2, cy, h, t, fill)
        x += w + h * gap


def icon_pet_night(d):
    # crescent upper right: a cream disc with a bite cut out of it
    mx, my, mr = N * 0.66, N * 0.31, N * 0.135
    d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=CREAM)
    d.ellipse([mx - mr * 0.45, my - mr * 1.25, mx + mr * 1.55, my + mr * 0.75], fill=CLEAR)
    star(d, N * 0.36, N * 0.25, N * 0.075, CREAM, k=0.42)
    star(d, N * 0.52, N * 0.47, N * 0.045, CREAM, k=0.42)
    # the pet, low left, in cream (ink would vanish on the dark face), asleep
    hx, hy, hr = N * 0.40, N * 0.66, N * 0.19
    bear_head(d, hx, hy, hr, CREAM, gap=N * 0.02)
    for sx in (-1, 1):
        d.arc([hx + sx * hr * 0.42 - hr * 0.2, hy - hr * 0.22, hx + sx * hr * 0.42 + hr * 0.2, hy + hr * 0.14], 20, 160,
              fill=NIGHT_RIM + (255,), width=int(N * 0.022))


def icon_play_date(d):
    bear_head(d, N * 0.615, N * 0.635, N * 0.158, INK)                      # the friend, a little smaller, behind
    bear_head(d, N * 0.395, N * 0.655, N * 0.186, INK, gap=N * 0.024)
    heart(d, N * 0.52, N * 0.31, N * 0.115, CREAM)


def icon_full_outfit(d):
    # T-shirt: rounded body, two short sleeves, a cream star on the chest
    d.rounded_rectangle([N * 0.355, N * 0.47, N * 0.645, N * 0.80], N * 0.05, fill=INK)
    for sx in (-1, 1):
        d.polygon([(N * 0.5 + sx * N * 0.10, N * 0.47), (N * 0.5 + sx * N * 0.27, N * 0.545), (N * 0.5 + sx * N * 0.215, N * 0.655),
                   (N * 0.5 + sx * N * 0.12, N * 0.61)], fill=INK)
        cx, cy, r = N * 0.5 + sx * N * 0.243, N * 0.60, N * 0.058
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)
    d.pieslice([N * 0.43, N * 0.41, N * 0.57, N * 0.53], 0, 180, fill=CLEAR)   # neck scoop
    star(d, N * 0.5, N * 0.645, N * 0.085, CREAM, k=0.5)
    # pom beanie above: dome, cream cuff, pom
    d.pieslice([N * 0.385, N * 0.215, N * 0.615, N * 0.465], 180, 360, fill=INK)
    d.rounded_rectangle([N * 0.365, N * 0.325, N * 0.635, N * 0.385], N * 0.03, fill=CREAM)
    d.ellipse([N * 0.455, N * 0.150, N * 0.545, N * 0.240], fill=CREAM)


def icon_win_each_item(d):
    for (x, y, r), tier in (((0.50, 0.335, 0.150), 4), ((0.335, 0.635, 0.135), 1), ((0.665, 0.635, 0.135), 2)):
        ball(d, N * x, N * y, N * r, tier, face=False)
        star(d, N * x, N * y + N * 0.008, N * r * 0.62, CREAM, k=0.5)


def icon_tidy_25(d):
    star(d, N * 0.335, N * 0.295, N * 0.125, INK, k=0.36)
    star(d, N * 0.665, N * 0.245, N * 0.060, CREAM, k=0.36)
    number(d, "25", N * 0.515, N * 0.60, N * 0.31, N * 0.066, INK)


def icon_rounds_100(d):
    number(d, "100", N * 0.5, N * 0.43, N * 0.29, N * 0.064, INK, gap=0.15)
    ball(d, N * 0.5, N * 0.715, N * 0.088, 1, face=False)


BADGES = {
    "tier_five": (GOLD, GOLD_RIM, icon_tier_five),
    "chain_five": (GOLD, GOLD_RIM, icon_chain_five),
    "win_bank_pair": (TEAL, TEAL_RIM, icon_bank_pair),
    "win_creek_crossing": (TEAL, TEAL_RIM, icon_creek_crossing),
    "win_lantern_chain": (TEAL, TEAL_RIM, icon_lantern_chain),
    "win_ripple_relay": (TEAL, TEAL_RIM, icon_ripple_relay),
    "win_bank_bounce": (TEAL, TEAL_RIM, icon_bank_bounce),
    "win_mirror_marks": (TEAL, TEAL_RIM, icon_mirror_marks),
    "win_easy": (GOOD, (52, 160, 86), lambda d: icon_bars(d, 1)),
    "win_medium": (STARS, GOLD_RIM, lambda d: icon_bars(d, 2)),
    "win_hard": (DANGER, (186, 40, 64), lambda d: icon_bars(d, 3)),
    "pet_night": (NIGHT, NIGHT_RIM, icon_pet_night),
    "play_date": (ROSE, ROSE_RIM, icon_play_date),
    "full_outfit": (ROSE, ROSE_RIM, icon_full_outfit),
    "win_each_item": (VIOLET, VIOLET_RIM, icon_win_each_item),
    "tidy_25": (GOLD, GOLD_RIM, icon_tidy_25),
    "rounds_100": (GOLD, GOLD_RIM, icon_rounds_100),
}


def badge_cell(bid):
    face, rim, draw = BADGES[bid]
    disc = disc_layer(face, rim)
    icon = canvas()
    draw(ImageDraw.Draw(icon))
    # clip the icon to the face so nothing pokes past the rim
    c, r = N / 2, N * 0.46 * 0.84
    clip = canvas()
    ImageDraw.Draw(clip).ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 255, 255))
    icon.putalpha(ImageChops.multiply(icon.getchannel("A"), clip.getchannel("A")))
    colour = disc.copy()
    colour.alpha_composite(icon)
    # silhouette: disc at 30%, icon solid white (the client tints and fades it)
    sil_a = ImageChops.lighter(disc.getchannel("A").point(lambda v: int(v * 0.30)), icon.getchannel("A"))
    # punch the icon a little so it reads as a cut-out against the faint disc
    sil = Image.new("RGBA", (N, N), (255, 255, 255, 255))
    sil.putalpha(sil_a)
    box = CELL - 8
    out_c, out_s = Image.new("RGBA", (CELL, CELL)), Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    out_c.alpha_composite(colour.resize((box, box), Image.LANCZOS), (4, 4))
    out_s.alpha_composite(sil.resize((box, box), Image.LANCZOS), (4, 4))
    return out_c, out_s


# ------------------------------------------------------------------ assembly
def cells():
    out = []
    def wear(item):
        if item in ALONE:
            return render_cell("wear-" + item, box=CELL - 14)
        return render_cell("wear-" + item, "wear-" + item + "-mask", box=CELL - 4, round_window=True)
    for item in WARDROBE:
        out.append(wear(item))
    for toy in TOYS:
        out.append(render_cell("toy-" + toy, box=CELL - 14))
    for fin in FINISHES:
        out.append(render_cell("finish-" + fin, box=CELL - 4, sparkle=fin == "gloss", round_window=True))
    for bid in DISCOVERIES:
        out.append(badge_cell(bid))
    for item in WARDROBE_LATE + WARDROBE_B:
        out.append(wear(item))
    for toy in TOYS_B:
        out.append(render_cell("toy-" + toy, box=CELL - 14))
    for bid in DISCOVERIES_B:
        out.append(badge_cell(bid))
    return out


def preview(atlas, made):
    """Review sheet: each slot at 128 px and at 48 px on the book's well colour, owned and missing."""
    well, raised, line = (14, 21, 23, 255), (34, 47, 51, 255), (145, 182, 183)
    W = 40 + 8 * 200
    rows = (len(SLOTS) + 7) // 8
    sheet = Image.new("RGBA", (W, 120 + rows * 250), (22, 33, 36, 255))
    d = ImageDraw.Draw(sheet)
    try:
        from common import font
        f, fb = font("r", 16), font("b", 26)
    except Exception:
        f = fb = None
    d.text((40, 30), "Collection book atlas: owned (top) and missing (below) at 128 px and 48 px", fill=(243, 244, 246), font=fb)
    for i, (sid, (c, s)) in enumerate(zip(SLOTS, made)):
        x, y = 40 + (i % 8) * 200, 90 + (i // 8) * 250
        d.rounded_rectangle([x, y, x + 180, y + 236], 12, fill=raised)
        d.rounded_rectangle([x + 6, y + 6, x + 134, y + 134], 10, fill=well)
        sheet.alpha_composite(c, (x + 6, y + 6))
        # 48 px owned and missing, as the client shows them
        for j, owned in enumerate((True, False)):
            bx, by = x + 6 + j * 60, y + 144
            d.rounded_rectangle([bx, by, bx + 54, by + 54], 8, fill=well)
            if owned:
                sheet.alpha_composite(c.resize((48, 48), Image.LANCZOS), (bx + 3, by + 3))
            else:
                t = s.resize((48, 48), Image.LANCZOS)
                tint = Image.new("RGBA", (48, 48), line + (0,))
                tint.putalpha(t.getchannel("A").point(lambda v: int(v * 0.55)))
                sheet.alpha_composite(tint, (bx + 3, by + 3))
        d.text((x + 8, y + 206), sid, fill=(195, 200, 208), font=f)
    os.makedirs(ART, exist_ok=True)
    sheet.save(os.path.join(ART, "book-atlas-preview.png"))


def main():
    made = cells()
    assert len(made) == len(SLOTS) and len(made) <= 2 * PER_PAGE, "atlas full: add a page"
    pages = []
    for start in range(0, len(made), PER_PAGE):
        atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS * 2), (0, 0, 0, 0))
        for i, (c, s) in enumerate(made[start:start + PER_PAGE]):
            col, row = i % COLS, i // COLS
            atlas.alpha_composite(c, (col * CELL, row * CELL))
            atlas.alpha_composite(s, (col * CELL, (row + ROWS) * CELL))
        name = "book-atlas.png" if start == 0 else "book-atlas-%d.png" % (start // PER_PAGE + 1)
        atlas.save(os.path.join(BOOK, name), optimize=True)
        pages.append(name)
    doc = {"schema": 1, "cell": CELL, "columns": COLS, "silhouetteRowOffset": ROWS, "size": [atlas.width, atlas.height],
           "perPage": PER_PAGE, "pages": pages,
           "slots": {sid: i + 1 for i, sid in enumerate(SLOTS)}}
    with open(os.path.join(BOOK, "book-atlas.json"), "w", newline="\n") as fh:
        json.dump(doc, fh, indent=1)
    preview(atlas, made)
    lua = ",".join('["%s"]=%d' % (sid, i + 1) for i, sid in enumerate(SLOTS))
    print("BookView.Art.slots = {" + lua + "}")


if __name__ == "__main__":
    main()
