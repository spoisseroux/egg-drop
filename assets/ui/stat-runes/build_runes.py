"""Production UI icons for the six stat rune stones, the level-up burst and the "2x BONUS" tag.

Everything is drawn here with PIL from stave coordinates: original art, no AI art, no samples.
The six runes are Elder Futhark letters (public domain); the stone, colours, outline and lip are
ours (V2-FEEDING-RUNES-ONBOARDING-2026-11-19.md section 1, UI-RETRO-RESTYLE-2026-11-19.md 3.2/3.8).
Stat colours mirror src/shared/StatCatalog.lua and must be changed there first.

Run from the repo root:  python assets/ui/stat-runes/build_runes.py
Needs Pillow and numpy. The tag text uses Nunito Black from C:/Windows/Fonts.
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = "C:/Windows/Fonts/Nunito-Black.ttf"

# Toy Shell tokens (UI-RETRO-RESTYLE 3.1)
INK, CREAM, LEMON, LEMON_LIP, WHITE = "#15143A", "#FFF4DC", "#FFE14D", "#D9A31C", "#FFFFFF"

# id, name, colour (StatCatalog.ById), rune
STATS = [("heart", "Heart", "#FF86A8", "wunjo"), ("power", "Power", "#FF9D4D", "uruz"),
         ("energy", "Energy", "#6CCBFF", "dagaz"), ("jump", "Jump", "#B9EE5A", "ehwaz"),
         ("speed", "Speed", "#8FA8FF", "raidho"), ("smarts", "Smarts", "#E58CFF", "ansuz")]
ORDER = [s[0] for s in STATS]
COLOR = {s[0]: s[2] for s in STATS}

# Staves in a unit box (x right, y down, both -1..1). One list of points per stroke.
STAVES = {
    "heart": [[(-.38, -1), (-.38, 1)], [(-.38, -1), (.52, -.42), (-.38, .16)]],
    "power": [[(-.55, 1), (-.55, -1), (.55, -.3), (.55, 1)]],
    "energy": [[(-1.0, -.74), (-1.0, .74)], [(1.0, -.74), (1.0, .74)], [(-1.0, -.74), (1.0, .74)], [(-1.0, .74), (1.0, -.74)]],
    "jump": [[(-.64, 1), (-.64, -1), (0, -.22), (.64, -1), (.64, 1)]],
    "speed": [[(-.45, -1), (-.45, 1)], [(-.45, -1), (.45, -.5), (-.45, 0), (.5, 1)]],
    "smarts": [[(-.4, -1), (-.4, 1)], [(-.4, -1), (.5, -.38)], [(-.4, -.3), (.5, .32)]],
}
# Hinted staves for the 24 px chip: the thick carve needs wider counters, so bowls and branches
# open up and the uprights move out. Same letters, redrawn for the pixel grid.
STAVES_SMALL = {
    "heart": [[(-.5, -1), (-.5, 1)], [(-.5, -1), (.62, -.36), (-.5, .28)]],
    "power": [[(-.62, 1), (-.62, -1), (.62, -.2), (.62, 1)]],
    "energy": [[(-1.24, -.86), (-1.24, .86)], [(1.24, -.86), (1.24, .86)], [(-1.24, -.86), (1.24, .86)], [(-1.24, .86), (1.24, -.86)]],
    "jump": [[(-.74, 1), (-.74, -1), (0, -.1), (.74, -1), (.74, 1)]],
    "speed": [[(-.52, -1), (-.52, 1)], [(-.52, -1), (.5, -.46), (-.52, .08), (.56, 1)]],
    "smarts": [[(-.5, -1), (-.5, 1)], [(-.5, -1), (.6, -.3)], [(-.5, -.02), (.6, .68)]],
}
SMALL_CARVE = {"energy": .112}   # Dagaz has four staves meeting in the middle; a little lighter so the bow tie stays open


def rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def mix(a, b, t):
    a, b = (rgb(a) if isinstance(a, str) else a), (rgb(b) if isinstance(b, str) else b)
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def strokes(d, staves, cx, cy, half, width, fill):
    """Round-ended, round-jointed staves. `half` is half the rune's height in pixels."""
    for stave in staves:
        pts = [(cx + x * half * .86, cy + y * half) for x, y in stave]
        d.line(pts, fill=fill, width=max(1, round(width)), joint="curve")
        for x, y in pts: d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=fill)


def stone_hi(kind, px, small=False, ss=8, pad=1, edge=INK):
    """The stone at `ss` times `px`, with `pad` output pixels left clear on every side."""
    col = COLOR[kind]; S = px * ss; p = pad * ss; s = S - 2 * p
    o = max(1.5, (px - 2 * pad) * .07) * ss                 # house outline: 2 px on a 28 px chip
    lip = s * (.095 if small else .085)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((p, p, S - p - 1, S - p - 1), s * .30, fill=rgb(edge))
    inner = (p + o, p + o, S - p - o - 1, S - p - o - 1); r = s * .30 - o
    d.rounded_rectangle(inner, r, fill=mix(col, INK, .42))                                   # lip
    face = (inner[0], inner[1], inner[2], inner[3] - lip)
    d.rounded_rectangle(face, r, fill=rgb(col))
    # soft top highlight: white fading out over the top 45% of the face, clipped to the face
    fh = face[3] - face[1]
    grad = Image.new("L", (1, S), 0)
    for y in range(S):
        t = (y - face[1]) / (fh * .45); grad.putpixel((0, y), round(255 * .30 * (1 - t) ** 1.6) if 0 <= t <= 1 else 0)
    mask = Image.new("L", (S, S), 0); ImageDraw.Draw(mask).rounded_rectangle(face, r, fill=255)
    hl = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    hl.putalpha(Image.composite(grad.resize((S, S)), Image.new("L", (S, S), 0), mask))
    im = Image.alpha_composite(im, hl); d = ImageDraw.Draw(im)
    cx = S / 2; cy = (face[1] + face[3]) / 2 + s * .012
    if small:
        strokes(d, STAVES_SMALL[kind], cx, cy, s * .255, s * SMALL_CARVE.get(kind, .135), rgb(INK))
    else:
        g = s * .034; gy = face[1] + s * .075; glint = mix(col, WHITE, .6)                   # house glint: line, break, dot
        d.line([(p + s * .24, gy), (p + s * .62, gy)], fill=glint, width=round(g))
        for x in (p + s * .24, p + s * .62, p + s * .72):
            d.ellipse((x - g / 2, gy - g / 2, x + g / 2, gy + g / 2), fill=glint)
        cy += s * .02
        strokes(d, STAVES[kind], cx, cy + s * .024, s * .262, s * .10, mix(col, WHITE, .42))  # chisel light on the lower wall
        strokes(d, STAVES[kind], cx, cy, s * .262, s * .10, rgb(INK))
    return im


def bleed(im, passes=6):
    """Give clear pixels the colour of their nearest neighbours so bilinear filtering in the engine
    never drags in a black or white fringe. Alpha is untouched."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32); col = a[..., :3].copy(); known = a[..., 3] > 0
    for _ in range(passes):
        acc = np.zeros_like(col); n = np.zeros(known.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            k = np.roll(known, (dy, dx), (0, 1)); c = np.roll(col, (dy, dx), (0, 1))
            acc += c * k[..., None]; n += k
        new = (~known) & (n > 0); col[new] = acc[new] / n[new][:, None]; known |= new
    col[~known] = rgb(INK)
    out = np.dstack([col, a[..., 3]]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def stone(kind, px, small=False):
    im = stone_hi(kind, px, small).resize((px, px), Image.LANCZOS)
    a = np.asarray(im).copy(); a[0, :, 3] = a[-1, :, 3] = 0; a[:, 0, 3] = a[:, -1, 3] = 0   # the resample filter leaks a faint edge; keep the 1 px padding truly clear
    return Image.fromarray(a, "RGBA")


def save(im, name):
    bleed(im).save(os.path.join(HERE, name), optimize=True); print("wrote", name, im.size)


def star4(d, cx, cy, R, fill, outline=None, ow=0, rot=0.0):
    pts = []
    for i in range(8):
        a = rot + i * math.pi / 4; r = R if i % 2 == 0 else R * .34
        pts.append((cx + math.sin(a) * r, cy - math.cos(a) * r))
    if outline:
        d.line(pts + pts[:2], fill=outline, width=round(ow * 2), joint="curve")
    d.polygon(pts, fill=fill)


# ---------- the six icons, the small chips, the atlas ----------
def build_icons():
    for k in ORDER:
        save(stone(k, 128), "rune-%s-128.png" % k)
        save(stone(k, 64), "rune-%s-64.png" % k)
        save(stone(k, 24, small=True), "rune-%s-small-24.png" % k)

def build_atlas():
    atlas = Image.new("RGBA", (512, 128), (0, 0, 0, 0)); sprites, small = {}, {}
    for i, (k, name, col, rune) in enumerate(STATS):
        x, y = 8 + i * 72, 8; atlas.paste(stone(k, 64), (x, y)); sprites[k] = {"x": x, "y": y, "w": 64, "h": 64}
        x, y = 8 + i * 32, 80; atlas.paste(stone(k, 24, small=True), (x, y)); small[k] = {"x": x, "y": y, "w": 24, "h": 24}
    save(atlas, "rune-atlas-512x128.png")
    data = {"image": "rune-atlas-512x128.png", "size": [512, 128], "gutter": 8, "padding": 1, "order": ORDER,
            "note": "Rects are ImageRectOffset (x, y) and ImageRectSize (w, h). 'sprites' are 64 px, 'small' are the 24 px chips.",
            "stats": {k: {"name": name, "color": col, "rune": rune} for k, name, col, rune in STATS},
            "sprites": sprites, "small": small}
    with open(os.path.join(HERE, "rune-atlas-512x128.json"), "w", newline="\n") as f: json.dump(data, f, indent=2); f.write("\n")
    print("wrote rune-atlas-512x128.json")


# ---------- level-up burst: 8 frames of 128 px in one 1024x128 strip ----------
def burst_sheet(kinds, ring_col, name):
    F, N, ss = 128, 8, 4; sheet = Image.new("RGBA", (F * N, F), (0, 0, 0, 0))
    base = {k: stone_hi(k, 40, ss=8, pad=0) for k in set(kinds)}
    for i in range(N):
        t = i / N; ease = 1 - (1 - t) ** 2.4
        fr = Image.new("RGBA", (F * ss, F * ss), (0, 0, 0, 0)); d = ImageDraw.Draw(fr); c = F * ss / 2
        fade = 1.0 if t < .5 else max(0.0, 1 - (t - .5) / .5) ** 1.2
        # ring
        rr = (9 + 47 * ease) * ss; rw = max(1.2, 7 * (1 - t) ** 1.5) * ss; ra = round(255 * (1 - t) ** 1.3)
        if i > 0:
            ring = Image.new("RGBA", fr.size, (0, 0, 0, 0))
            ImageDraw.Draw(ring).ellipse((c - rr, c - rr, c + rr, c + rr), outline=mix(WHITE, ring_col, min(1, t * 1.6)) + (ra,), width=round(rw))
            fr = Image.alpha_composite(fr, ring); d = ImageDraw.Draw(fr)
        # sparkles, between the stones and a little ahead of them
        for j in range(6):
            a = math.radians(30 + j * 60 + 14 * t); r = min(57, 12 + 52 * ease) * ss; R = (2.5 + 5.5 * math.sin(math.pi * min(1, t * 1.25))) * ss * (1 if j % 2 else .7)
            if i > 0 and R > ss * 3: star4(d, c + math.sin(a) * r, c - math.cos(a) * r, R, rgb(LEMON), rgb(INK), ss * .9, rot=t * 2)
        # stones
        size = (13 + 19 * min(1, t / .14)) if t < .14 else 32 - 13 * ((t - .14) / .86)
        for j, k in enumerate(kinds):
            a = math.radians(j * 60 - 16 * (1 - ease)); r = (5 + 39 * ease) * ss
            spin = (-1 if j % 2 else 1) * (26 * ease)
            st = base[k].resize((round(size * ss),) * 2, Image.LANCZOS).rotate(spin + (j - 2.5) * -6 * ease, Image.BICUBIC, expand=True)
            if fade < 1: st.putalpha(st.getchannel("A").point(lambda v: round(v * fade)))
            fr.alpha_composite(st, (round(c + math.sin(a) * r - st.width / 2), round(c - math.cos(a) * r - st.height / 2)))
        # centre flash on the first three frames
        if i < 3:
            d = ImageDraw.Draw(fr); star4(d, c, c, (30, 22, 11)[i] * ss, rgb(WHITE), rgb(INK), ss * 1.2, rot=i * .35)
            star4(d, c, c, (14, 9, 0)[i] * ss, rgb(LEMON))
        sheet.paste(fr.resize((F, F), Image.LANCZOS), (i * F, 0))
    save(sheet, name)

def build_bursts():
    burst_sheet(ORDER, CREAM, "levelup-burst-8x128.png")
    for k in ORDER: burst_sheet([k] * 6, COLOR[k], "levelup-burst-%s-8x128.png" % k)
    data = {"frame": [128, 128], "frames": 8, "layout": "one row, left to right", "size": [1024, 128], "fps": 16, "loop": False,
            "rects": [{"x": i * 128, "y": 0, "w": 128, "h": 128} for i in range(8)],
            "sheets": {"all": "levelup-burst-8x128.png", **{k: "levelup-burst-%s-8x128.png" % k for k in ORDER}}}
    with open(os.path.join(HERE, "levelup-burst-8x128.json"), "w", newline="\n") as f: json.dump(data, f, indent=2); f.write("\n")
    print("wrote levelup-burst-8x128.json")


# ---------- "2x BONUS" tag: a Toy Shell sticker (ink outline, cream edge, lemon face, lip, tilt) ----------
def tag(text_parts, w, name, canvas):
    ss = 4; W, H = canvas; im = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    h, lip, o, e = 60, 6, 3, 4; x0 = (W - w) / 2; y0 = (H - h - lip) / 2; R = 20
    box = lambda i, top=0, bot=0: tuple(v * ss for v in (x0 + i, y0 + i + top, x0 + w - i, y0 + h + lip - i + bot))
    d.rounded_rectangle(box(0), R * ss, fill=rgb(INK))
    d.rounded_rectangle(box(o), (R - o) * ss, fill=rgb(LEMON_LIP))
    d.rounded_rectangle(box(o, 0, -lip), (R - o) * ss, fill=rgb(CREAM))
    d.rounded_rectangle(box(o + e, 0, -lip), (R - o - e) * ss, fill=rgb(LEMON))
    gy = (y0 + o + e + 6) * ss; g = 2.5 * ss; gl = mix(LEMON, WHITE, .7)
    d.line([((x0 + 26) * ss, gy), ((x0 + w - 58) * ss, gy)], fill=gl, width=round(g))
    for x in (x0 + 26, x0 + w - 58, x0 + w - 48): d.ellipse((x * ss - g / 2, gy - g / 2, x * ss + g / 2, gy + g / 2), fill=gl)
    fonts = [ImageFont.truetype(FONT, round(sz * ss)) for _, sz in text_parts]
    widths = [d.textlength(t, font=f) for (t, _), f in zip(text_parts, fonts)]; gap = 7 * ss
    x = W * ss / 2 - (sum(widths) + gap * (len(widths) - 1)) / 2; base = (y0 + h / 2 + 15) * ss
    for (t, _), f, tw in zip(text_parts, fonts, widths):
        d.text((x, base), t, font=f, fill=rgb(INK), anchor="ls"); x += tw + gap
    star4(d, (x0 + w - 6) * ss, (y0 + 6) * ss, 15 * ss, rgb(WHITE), rgb(INK), 2.6 * ss, rot=.2)
    im = im.rotate(4, Image.BICUBIC, center=(W * ss / 2, H * ss / 2)).resize((W, H), Image.LANCZOS)
    save(im, name)

def build_tags():
    tag([("2x", 40), ("BONUS", 32)], 216, "tag-2x-bonus.png", (256, 96))
    tag([("2x", 40)], 96, "tag-2x.png", (128, 96))       # no word: for locales where "BONUS" is translated in text beside it


# ---------- a check sheet (not for upload) ----------
def build_preview():
    W, H = 1180, 640; im = Image.new("RGB", (W, H), rgb(CREAM)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 15)
    bgs = [("cream tile", CREAM), ("shell", "#2E55E6"), ("tray", "#1D36A6"), ("well", "#10133A"), ("white", WHITE), ("grass", "#6BBF4A")]
    for r, (label, bg) in enumerate(bgs):
        y = r * 60; d.rectangle((0, y, 600, y + 60), fill=rgb(bg))
        d.text((8, y + 4), label, font=f, fill=rgb(INK) if r in (0, 4, 5) else rgb(WHITE))
        for i, k in enumerate(ORDER):
            st = Image.open(os.path.join(HERE, "rune-%s-small-24.png" % k)); im.paste(st, (110 + i * 30, y + 18), st)
            st = stone(k, 32); im.paste(st, (310 + i * 38, y + 14), st)
    for i, k in enumerate(ORDER):                           # 24 px chips at 6x, hard pixels, colour then grey
        st = Image.open(os.path.join(HERE, "rune-%s-small-24.png" % k)).convert("RGBA"); big = st.resize((96, 96), Image.NEAREST)
        im.paste(big, (610 + i * 94, 6), big)
        a = st.getchannel("A"); g = st.convert("L").convert("RGBA"); g.putalpha(a); big = g.resize((96, 96), Image.NEAREST); im.paste(big, (610 + i * 94, 106), big)
        st = Image.open(os.path.join(HERE, "rune-%s-64.png" % k)); im.paste(st, (610 + i * 94 + 16, 212), st)
    atlas = Image.open(os.path.join(HERE, "rune-atlas-512x128.png")); d.rectangle((610, 288, 610 + 512, 288 + 128), fill=(200, 190, 170)); im.paste(atlas, (610, 288), atlas)
    for i, k in enumerate(ORDER[:4]):
        st = Image.open(os.path.join(HERE, "rune-%s-128.png" % k)); im.paste(st, (8 + i * 136, 366), st)
    for n, y in (("tag-2x-bonus.png", 420), ("tag-2x.png", 420)):
        t = Image.open(os.path.join(HERE, n)); x = 610 if "bonus" in n else 880; d.rectangle((x, y, x + t.width, y + t.height), fill=rgb("#2E55E6")); im.paste(t, (x, y), t)
    d.rectangle((0, 512, W, H), fill=rgb("#1D36A6"))
    b = Image.open(os.path.join(HERE, "levelup-burst-8x128.png")); im.paste(b, (0, 512), b)
    out = os.path.join(HERE, "_preview.png"); im.save(out); print("wrote _preview.png")
    b2 = Image.open(os.path.join(HERE, "levelup-burst-jump-8x128.png")); p2 = Image.new("RGB", (1024, 256), rgb(CREAM)); p2.paste(b, (0, 0), b); p2.paste(b2, (0, 128), b2)
    p2.save(os.path.join(HERE, "_preview-burst.png")); print("wrote _preview-burst.png")


if __name__ == "__main__":
    build_icons(); build_atlas(); build_bursts(); build_tags(); build_preview()
