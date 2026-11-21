"""Dewdrop style board. Procedural (numpy + PIL) only; the pet/deck cut-outs are our own
real-capture layers from ../v2/layers. No AI imagery, no third-party images.
Run: python build_style_board.py  ->  style-board.png"""
import glob
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.join(HERE, "..", "v2", "layers")
WIN = "C:/Windows/Fonts/"


def roblox_font(name):
    hits = sorted(glob.glob(os.path.expanduser("~/AppData/Local/Roblox/Versions/*/content/fonts/" + name)))
    return hits[-1] if hits else WIN + "Nunito-Black.ttf"


FREDOKA = roblox_font("FredokaOne-Regular.ttf")
BLACK, ITALIC, XBOLD, QUICK = (
    WIN + n for n in ("Nunito-Black.ttf", "Nunito-BlackItalic.ttf", "Nunito-ExtraBold.ttf", "Quicksand-Bold.ttf")
)


def F(path, size):
    return ImageFont.truetype(path, size)


PALETTE = [
    ("Sky", "#1E9BFF"), ("Deep Sky", "#0A58CA"), ("Aqua", "#27D3E6"), ("Leaf", "#5AD65A"), ("Lime", "#B8F23C"),
    ("Sun", "#FFD23F"), ("Blossom", "#FF7EB6"), ("Grape", "#8B6CFF"), ("Cloud", "#FFFFFF"), ("Ink Navy", "#0C2A4A"),
]
FIELDS = [  # name, top, bottom
    ("Sky", "#0A6BE0", "#6FD0FF"), ("Aqua", "#0FA9C9", "#9AF3F0"), ("Leaf", "#2FB344", "#C6F56A"),
    ("Sun", "#FFB400", "#FFEE8A"), ("Blossom", "#FF5FA2", "#FFC2DC"), ("Grape", "#6747E8", "#C3B2FF"),
]
INK = (12, 42, 74)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rmask(w, h, r):
    m = Image.new("L", (w * 3, h * 3), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * 3 - 1, h * 3 - 1), r * 3, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def field(w, h, top, bottom, floor=0.72):
    """One colour field: vertical gradient, a soft sun glow top-left, a glossy floor band."""
    t, b = np.array(rgb(top), np.float32), np.array(rgb(bottom), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (yy / (h * floor)).clip(0, 1)[..., None]
    img = t + (b - t) * v ** 1.2
    glow = np.exp(-(((xx - w * 0.22) / (w * 0.5)) ** 2 + ((yy - h * 0.12) / (h * 0.55)) ** 2))[..., None]
    img = img + (255 - img) * glow * 0.38
    if floor < 1:
        fl = ((yy - h * floor) / (h * (1 - floor))).clip(0, 1)[..., None]
        on = (yy >= h * floor)[..., None]
        floor_col = b + (255 - b) * 0.55 * (1 - fl) ** 2  # bright lip at the horizon
        floor_col = floor_col * (1 - 0.30 * fl) + t * 0.30 * fl  # deepening toward the viewer
        img = np.where(on, floor_col, img)
    return Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")


def bubble(d, strength=1.0):
    """Glass bubble: thin rim, faint fill, a wet highlight top-left, a bounce crescent bottom-right."""
    yy, xx = (np.mgrid[0:d, 0:d].astype(np.float32) + 0.5) / d * 2 - 1
    r = np.sqrt(xx ** 2 + yy ** 2)
    inside = np.clip((1 - r) * d / 2, 0, 1)
    rim = np.exp(-((r - 0.93) / 0.05) ** 2) * 0.55
    fill = 0.07 + 0.10 * r ** 3
    hi = np.exp(-(((xx + 0.38) / 0.24) ** 2 + ((yy + 0.42) / 0.15) ** 2)) * 0.95
    bounce = np.exp(-((r - 0.74) / 0.07) ** 2) * np.clip((xx + yy) * 0.9 - 0.5, 0, 1) * 0.55
    a = np.clip((rim + fill + hi + bounce) * strength, 0, 1) * inside
    out = np.zeros((d, d, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def gloss(w, h, r, top_a=0.55):
    """Top-half shine for any rounded shape."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cut_y = h * (0.46 + 0.10 * ((xx / w - 0.5) ** 2) * 4)  # curved lower edge
    a = np.clip((cut_y - yy) / 2.0, 0, 1) * (top_a * (1 - yy / (h * 0.62)).clip(0, 1) + 0.06)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (a * 255 * (np.asarray(rmask(w, h, r)) / 255.0)).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def shadow(base, box, r, blur=18, alpha=70, dy=10):
    x0, y0, x1, y1 = box
    s = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(s).rounded_rectangle((x0, y0 + dy, x1, y1 + dy), r, fill=INK + (alpha,))
    base.alpha_composite(s.filter(ImageFilter.GaussianBlur(blur)))


def glossy_tile(base, xy, w, h, r, hx):
    x, y = xy
    shadow(base, (x, y, x + w, y + h), r)
    t = Image.new("RGBA", (w, h), rgb(hx) + (255,))
    t.alpha_composite(gloss(w, h, r))
    base.paste(t, (x, y), rmask(w, h, r))
    edge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, w - 2, h - 2), r, outline=(255, 255, 255, 150), width=3)
    base.alpha_composite(edge, (x, y))
    if hx.upper() == "#FFFFFF":
        ImageDraw.Draw(base).rounded_rectangle((x, y, x + w, y + h), r, outline=(190, 215, 235), width=2)


def glass_tag(base, xy, s, font, pad=(34, 16), fill=(255, 255, 255, 80), ink=(255, 255, 255)):
    x, y = xy
    l, t, r_, b = ImageDraw.Draw(base).textbbox((0, 0), s, font=font)
    w, h = r_ - l + pad[0] * 2, b - t + pad[1] * 2
    shadow(base, (x, y, x + w, y + h), h // 2, blur=10, alpha=50, dy=6)
    g = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(g).rounded_rectangle((0, 0, w - 1, h - 1), h // 2, fill=fill, outline=(255, 255, 255, 210), width=3)
    g.alpha_composite(gloss(w, h, h // 2, 0.45))
    base.alpha_composite(g, (x, y))
    ImageDraw.Draw(base).text((x + pad[0] - l, y + pad[1] - t), s, font=font, fill=ink)


def text(base, xy, s, font, fill=(255, 255, 255), drop=None, anchor="la"):
    if drop:
        sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((xy[0], xy[1] + drop[0]), s, font=font, fill=drop[1], anchor=anchor)
        base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(drop[0] * 0.8)))
    ImageDraw.Draw(base).text(xy, s, font=font, fill=fill, anchor=anchor)


def cut(name, height):
    im = Image.open(os.path.join(V2, name)).convert("RGBA")
    im = im.crop(im.getbbox())
    return im.resize((max(1, round(im.width * height / im.height)), height), Image.LANCZOS)


def place(base, im, cx, foot_y, reflect=0.33, rot=0):
    """Stand a cut-out on the glossy floor with a short fading reflection and a contact shadow."""
    if rot:
        im = im.rotate(rot, Image.BICUBIC, expand=True)
    x, y = int(cx - im.width / 2), int(foot_y - im.height)
    if reflect:
        rh = int(im.height * 0.38)
        ref = im.transpose(Image.FLIP_TOP_BOTTOM).crop((0, 0, im.width, rh))
        fade = np.linspace(reflect, 0, rh)[:, None] ** 1.4
        ref.putalpha(Image.fromarray((np.asarray(ref)[..., 3] * fade).astype(np.uint8)))
        layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        layer.paste(ref, (x, foot_y - 4))
        base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2)))
    s = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(s).ellipse((cx - im.width * 0.42, foot_y - 12, cx + im.width * 0.42, foot_y + 14), fill=INK + (90,))
    base.alpha_composite(s.filter(ImageFilter.GaussianBlur(9)))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(im, (x, y))
    base.alpha_composite(layer)


def slot(base, box, label, font):
    """Dashed placeholder where a new capture goes."""
    x0, y0, x1, y1 = box
    base.alpha_composite(Image.new("RGBA", (x1 - x0, y1 - y0), (255, 255, 255, 46)), (x0, y0))
    d = ImageDraw.Draw(base)
    for x in range(x0, x1, 26):
        for yy in (y0, y1):
            d.line((x, yy, min(x + 14, x1), yy), fill=(255, 255, 255, 235), width=4)
    for y in range(y0, y1, 26):
        for xx in (x0, x1):
            d.line((xx, y, xx, min(y + 14, y1)), fill=(255, 255, 255, 235), width=4)
    d.multiline_text(((x0 + x1) / 2, (y0 + y1) / 2), label, font=font, fill=(255, 255, 255), anchor="mm",
                     align="center", spacing=4)


def bubbles(base, spots):
    for x, y, d, s in spots:
        layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        layer.paste(bubble(d, s), (int(x - d / 2), int(y - d / 2)))
        base.alpha_composite(layer)


def rays(w, h, n=5, alpha=34):
    r = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(r)
    for i in range(n):
        x = -w * 0.2 + i * w * 0.3
        wd = w * (0.05 + 0.03 * (i % 3))
        d.polygon([(x, h), (x + wd, h), (x + wd + h * 0.55, 0), (x + h * 0.55, 0)], fill=(255, 255, 255, alpha))
    return r.filter(ImageFilter.GaussianBlur(10))


def frame(base, im, xy, r, caption, cap_font):
    x, y = xy
    shadow(base, (x, y, x + im.width, y + im.height), r, blur=22, alpha=80, dy=14)
    base.paste(im, (x, y), rmask(im.width, im.height, r))
    text(base, (x, y + im.height + 18), caption, cap_font, fill=INK)


# ---------------------------------------------------------------- board
W, H = 2400, 2230
M = 50
board = field(W, H, "#FFFFFF", "#E3F5FF", floor=2.0)
small, cap, head = F(XBOLD, 26), F(XBOLD, 30), F(BLACK, 40)
GREY = (70, 100, 135)

text(board, (M, 24), "dewdrop", F(BLACK, 120), fill=rgb("#0A58CA"))
text(board, (M + 600, 58), "Pocket Pals: Pet Garden  ·  store icon, thumbnails, ads  ·  new look", F(XBOLD, 36), fill=INK)
text(board, (M + 600, 110), "One hero, one colour field, one wet highlight.  Procedural board; pets and deck are our own real captures.",
     small, fill=GREY)

# 1 palette
y = 210
text(board, (M, y), "1  Palette", head, fill=INK)
sw, gap = 200, 33
for i, (name, hx) in enumerate(PALETTE):
    x = M + i * (sw + gap)
    glossy_tile(board, (x, y + 64), sw, 170, 34, hx)
    text(board, (x + 6, y + 248), name, cap, fill=INK)
    text(board, (x + 6, y + 284), hx, small, fill=GREY)

# 2 fields
y = 570
text(board, (M, y), "2  Colour fields: one per frame, light from top-left, glossy floor, bubbles", head, fill=INK)
fw, fh, fg = 360, 290, 28
for i, (name, top, bot) in enumerate(FIELDS):
    f = field(fw, fh, top, bot)
    f.alpha_composite(rays(fw, fh, 4, 22))
    bubbles(f, [(70, 150, 86, 1.0), (290, 80, 120, 0.9), (240, 180, 40, 1.0), (150, 60, 30, 0.9), (325, 170, 22, 1.0)])
    frame(board, f, (M + i * (fw + fg), y + 64), 30, f"{name}  {top} > {bot}", F(XBOLD, 22))

# 3 type
y = 1010
text(board, (M, y), "3  Type", head, fill=INK)
tp = field(1120, 400, "#0A6BE0", "#6FD0FF")
deep = rgb("#0A58CA")
text(tp, (44, 20), "pocket pals", F(FREDOKA, 118), drop=(8, deep + (190,)))
text(tp, (48, 160), "train your pet", F(ITALIC, 84), drop=(6, deep + (170,)))
glass_tag(tp, (48, 300), "merge  ·  hatch  ·  train", F(QUICK, 40))
text(tp, (640, 312), "Fredoka One  /  Nunito Black Italic", small)
text(tp, (640, 348), "Quicksand Bold.  All SIL OFL 1.1.", small)
frame(board, tp, (M, y + 64), 30, "Lowercase, white, soft drop in the field's deep tone. No outlines, no yellow block caps.", small)

# 4 finish
x0 = M + 1120 + 50
text(board, (x0, y), "4  Finish: gloss, glass, bubbles, shine", head, fill=INK)
fp = field(1130, 400, "#0FA9C9", "#9AF3F0")
fp.alpha_composite(rays(1130, 400, 6, 26))
for i, hx in enumerate(["#1E9BFF", "#5AD65A", "#FFD23F", "#FF7EB6", "#8B6CFF"]):  # colour line-up chips
    glossy_tile(fp, (50 + i * 128, 46), 104, 104, 30, hx)
glass_tag(fp, (50, 196), "glass tag", F(QUICK, 38))
glass_tag(fp, (300, 196), "solid tag", F(QUICK, 38), fill=(255, 255, 255, 240), ink=deep)
bubbles(fp, [(880, 140, 240, 1.0), (1040, 70, 100, 1.0), (1050, 240, 70, 1.0), (735, 70, 54, 1.0), (760, 235, 36, 1.0)])
place(fp, cut("star_a.png", 120), 620, 350)
text(fp, (50, 330), "Chips sit in even rows, like a colour line-up.", small)
frame(board, fp, (x0, y + 64), 30, "Highlight top-left on everything; short floor reflection; white rim on glass.", small)

# 5 layouts
y = 1560
text(board, (M, y), "5  Rough layouts (dashed = new capture needed)", head, fill=INK)
slotf = F(XBOLD, 22)

ic = field(450, 450, "#0A6BE0", "#6FD0FF", floor=0.80)
ic.alpha_composite(rays(450, 450, 4, 24))
bubbles(ic, [(385, 60, 90, 1.0), (50, 90, 46, 1.0), (415, 170, 30, 1.0)])
place(ic, cut("close_white.png", 350), 128, 452, reflect=0)
slot(ic, (262, 96, 428, 400), "BUNNY\nface,\nears up\n(new\ncapture)", slotf)
frame(board, ic, (M, y + 64), 96, "Icon A  Two Pals in the Blue (no text)", small)

tw, th = 880, 495
t1 = field(tw, th, "#0A6BE0", "#6FD0FF")
t1.alpha_composite(rays(tw, th, 5, 22))
bubbles(t1, [(820, 60, 90, 1.0), (500, 60, 44, 1.0), (40, 240, 60, 1.0), (720, 130, 26, 1.0)])
place(t1, cut("deck_sorbet.png", 225), 640, 405, reflect=0.30, rot=-5)
place(t1, cut("bear_white.png", 250), 130, 425)
slot(t1, (232, 215, 362, 420), "BUNNY\n(new)", slotf)
text(t1, (36, 14), "pocket pals", F(FREDOKA, 82), drop=(6, deep + (190,)))
glass_tag(t1, (40, 120), "merge  ·  hatch  ·  train", F(QUICK, 28), pad=(24, 11))
frame(board, t1, (M + 450 + 45, y + 64), 26, "Thumbnail 1 / Ad A  The Line-up: pals + Pocket Deck on the Sky field", small)

t2 = field(tw, th, "#0A6BE0", "#8FDBFF", floor=2.0)
hill = Image.new("L", (tw, th), 0)
ImageDraw.Draw(hill).polygon([(0, th * 0.80), (tw, th * 0.50), (tw, th), (0, th)], fill=255)
t2.paste(field(tw, th, "#C6F56A", "#2FB344", floor=2.0), (0, 0), hill.filter(ImageFilter.GaussianBlur(1.5)))
t2.alpha_composite(rays(tw, th, 6, 30))
bubbles(t2, [(90, 250, 70, 1.0), (300, 200, 36, 1.0), (820, 60, 60, 1.0)])
slot(t2, (590, 70, 800, 310), "BUNNY\nmid-hop\n(new capture)", slotf)
place(t2, cut("bear_tide.png", 240), 400, 420, reflect=0, rot=10)
text(t2, (36, 16), "your pocket pets", F(ITALIC, 70), drop=(6, deep + (180,)))
glass_tag(t2, (40, 108), "pocket pals", F(FREDOKA, 30), pad=(24, 10))
frame(board, t2, (M + 450 + 45 + tw + 45, y + 64), 26, "Ad C  Sky Hop: one diagonal, sky over grass, slanted type", small)

board.convert("RGB").save(os.path.join(HERE, "style-board.png"), optimize=True)
print("ok", board.size)
