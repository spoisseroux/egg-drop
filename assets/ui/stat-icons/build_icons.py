"""Production UI icons for the six stats: the "Pocket Buddies" set that replaces the rune stones.

Each stat is a little object with a face: a heart, a paw, a lightning bolt, a spring, a sneaker and a
light bulb. Everything is drawn here with PIL and numpy from coordinates: original art, no AI art,
no samples, no traced references. Design: V2-CUTE-ICONS-AND-NAMES-2026-11-20.md section 1.
Stat colours mirror src/shared/StatCatalog.lua and must be changed there first.

Run from the repo root:  python assets/ui/stat-icons/build_icons.py
Needs Pillow and numpy. Writes the icons, atlas, burst sheets and _preview.png next to this file and
the six snack decals to assets/art-source/snacks/export/icon-decal-<stat>-256.png.
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SNACK_EXPORT = os.path.abspath(os.path.join(HERE, "..", "..", "art-source", "snacks", "export"))

# Toy Shell tokens (UI-RETRO-RESTYLE 3.1)
INK, CREAM, CREAM_LIP, LEMON, WHITE = "#15143A", "#FFF4DC", "#D6C196", "#FFE14D", "#FFFFFF"
COCOA = "#4A2B22"                      # snack decal colour (build_snack_images.py)

# id, name, colour (StatCatalog.ById), icon
STATS = [("heart", "Heart", "#FF86A8", "heart"), ("power", "Power", "#FF9D4D", "paw"),
         ("energy", "Energy", "#6CCBFF", "bolt"), ("jump", "Jump", "#B9EE5A", "spring"),
         ("speed", "Speed", "#8FA8FF", "sneaker"), ("smarts", "Smarts", "#E58CFF", "bulb")]
ORDER = [s[0] for s in STATS]
COLOR = {s[0]: s[2] for s in STATS}

# Outline in output pixels for each drawn size. House rule: 2 px on a 28 px chip.
OUTLINE = {128: 6.0, 64: 3.3, 40: 2.4, 24: 1.5}


def rgb(h):
    if not isinstance(h, str): return tuple(h)
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def mix(a, b, t):
    a, b = rgb(a), rgb(b); return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------- the artboard: unit coordinates (0..1, y down) on a supersampled square ----------
_kern = {}
def dilate(m, r):
    """Exact disc dilation of a boolean mask (FFT convolution with a disc)."""
    if r < .5: return m
    S = m.shape[0]; key = (S, round(r, 2))
    if key not in _kern:
        k = int(math.ceil(r)); y, x = np.ogrid[-k:k + 1, -k:k + 1]; disc = (x * x + y * y <= r * r).astype(np.float32)
        big = np.zeros((S, S), np.float32); big[:2 * k + 1, :2 * k + 1] = disc
        _kern[key] = np.fft.rfft2(np.roll(big, (-k, -k), (0, 1)))
    return np.fft.irfft2(np.fft.rfft2(m.astype(np.float32)) * _kern[key], s=m.shape) > .5


class Board:
    def __init__(self, px, ss, pad=1, outline=None, box=None):
        self.px, self.ss, self.S = px, ss, px * ss
        self.o = (outline if outline is not None else OUTLINE.get(px, px * .05)) * ss      # outline, in board pixels
        if box:                                           # explicit content box (decals)
            self.x0, self.y0, self.w = box[0] * self.S, box[1] * self.S, (box[2] - box[0]) * self.S
        else:
            m = pad * ss + self.o + ss * .15; self.x0 = self.y0 = m; self.w = self.S - 2 * m
    def P(self, x, y): return (self.x0 + x * self.w, self.y0 + y * self.w)
    def L(self, v): return v * self.w
    def _new(self): im = Image.new("L", (self.S, self.S), 0); return im, ImageDraw.Draw(im)
    def poly(self, pts):
        im, d = self._new(); d.polygon([self.P(*p) for p in pts], fill=255); return np.asarray(im) > 127
    def ellipse(self, cx, cy, rx, ry, rot=0.0):
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        return self.poly([(cx + rx * math.cos(t) * c - ry * math.sin(t) * s, cy + rx * math.cos(t) * s + ry * math.sin(t) * c)
                          for t in np.linspace(0, 2 * math.pi, 72, endpoint=False)])
    def line(self, pts, w):
        im, d = self._new(); q = [self.P(*p) for p in pts]; W = self.L(w)
        d.line(q, fill=255, width=max(1, round(W)), joint="curve")
        for x, y in q: d.ellipse((x - W / 2, y - W / 2, x + W / 2, y + W / 2), fill=255)
        return np.asarray(im) > 127
    def rrect(self, x0, y0, x1, y1, r):
        im, d = self._new(); a, b = self.P(x0, y0), self.P(x1, y1); d.rounded_rectangle((a[0], a[1], b[0], b[1]), self.L(r), fill=255)
        return np.asarray(im) > 127
    def arc(self, cx, cy, r, a0, a1, w):
        return self.line([(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in np.linspace(a0, a1, 14)], w)
    def soften(self, m, r):
        """Round every corner (no points: CUTE-DESIGN-RULES 'Tips')."""
        im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(self.L(r)))
        return np.asarray(im) > 127


# ---------- the six buddies ----------
# Each returns (parts, face). A part is (mask, kind): "body" = stat colour with lip and highlight,
# "cream" = cream with lip, "flat" = stat colour, no lip, "white" = white, no lip. Parts are painted back to front and each
# gets its own ink outline. `d` is the detail level: 2 = 128 px, 1 = 64 px, 0 = the 24 px chip.
def face(eyes, mouth, blush, big=1.0): return {"eyes": eyes, "mouth": mouth, "blush": blush, "big": big}

def heart(a, d):
    t = np.linspace(0, 2 * math.pi, 240, endpoint=False)
    x = 16 * np.sin(t) ** 3; y = -(13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t))
    pts = list(zip(.5 + x / 32 * 1.0, .04 + (y - y.min()) / (y.max() - y.min()) * .92))
    return [(a.soften(a.poly(pts), .045), "body")], face([(.325, .43), (.675, .43)], (.5, .53), [(.2, .53), (.8, .53)])

def paw(a, d):
    pad = a.soften(a.ellipse(.5, .665, .335, .275) | a.ellipse(.5, .60, .30, .22), .03)
    toes = [a.ellipse(.165, .335, .125, .15, -18), a.ellipse(.5, .19, .135, .16), a.ellipse(.835, .335, .125, .15, 18)]
    return [(t, "body") for t in toes] + [(pad, "body")], face([(.375, .64), (.625, .64)], (.5, .73), [(.265, .735), (.735, .735)])

def bolt(a, d):
    pts = [(.44, .02), (.84, .02), (.67, .33), (.93, .33), (.30, .98), (.42, .62), (.10, .62)]
    return [(a.soften(a.poly(pts), .05), "body")], face([(.40, .455), (.66, .455)], (.53, .545), [(.28, .54), (.775, .54)], .92)

def spring(a, d):
    """An up arrow riding a spring: 'up' reads at any size, the coil says 'bounce'."""
    w = .105 if d else .12
    zig = [(.345, .685), (.655, .745), (.345, .82), (.655, .88), (.345, .955)] if d else [(.33, .73), (.67, .83), (.33, .94)]
    coil = a.line(zig, w) | a.line([zig[-1], (1 - zig[-1][0], zig[-1][1])], w)
    head = a.soften(a.poly([(.5, -.02), (1.03, .585), (-.03, .585)]), .07)
    return [(coil, "flat"), (head, "body")], face([(.365, .37), (.635, .37)], (.5, .46), [(.25, .465), (.75, .465)])

def sneaker(a, d):
    up = a.rrect(.30, .20, .62, .80, .13) | a.ellipse(.72, .625, .26, .19) | a.poly([(.50, .24), (.86, .50), (.86, .80), (.50, .80)])
    up = a.soften(up, .04)
    sole = a.rrect(.265, .745, .995, .90, .075)
    parts = [(up, "body"), (sole, "cream")]
    lines = [(.06, .30, .15), (.04, .50, .12), (.08, .70, .13)] if d else [(.05, .34, .12), (.05, .60, .10)]
    parts = [(a.line([(x, y), (x + l, y)], .07 if d else .085), "flat") for x, y, l in lines] + parts
    return parts, face([(.60, .545), (.83, .575)], (.715, .645), [(.52, .655), (.90, .675)], .9)

def star_pts(cx, cy, R, rot=0.0):
    return [(cx + math.sin(rot + i * math.pi / 4) * (R if i % 2 == 0 else R * .40), cy - math.cos(rot + i * math.pi / 4) * (R if i % 2 == 0 else R * .40)) for i in range(8)]

def bulb(a, d):
    cx, cy, r = (.44, .46, .32) if d else (.5, .40, .34)
    glass = a.soften(a.ellipse(cx, cy, r, r) | a.poly([(cx - r * .62, cy + r * .6), (cx + r * .62, cy + r * .6), (cx + .115, .80), (cx - .115, .80)]), .03)
    base = a.rrect(cx - .13, .76, cx + .13, .985, .06)
    parts = [(base, "cream"), (glass, "body")]
    if d: parts.append((a.soften(a.poly(star_pts(.87, .15, .15, .12)), .012), "white"))   # the "idea!" sparkle
    ey = cy + .035
    return parts, face([(cx - .12, ey), (cx + .12, ey)], (cx, ey + .09), [(cx - .225, ey + .09), (cx + .225, ey + .09)])

DRAW = {"heart": heart, "power": paw, "energy": bolt, "jump": spring, "speed": sneaker, "smarts": bulb}


def _paste(im, m, col, alpha=255):
    im.paste(Image.new("RGBA", im.size, rgb(col) + (alpha,)), (0, 0), Image.fromarray((m * 255).astype(np.uint8)))

def icon_hi(kind, px, ss=8, pad=1, d=None, grey=False):
    """One buddy at `ss` times `px`, with `pad` output pixels left clear on every side."""
    d = (2 if px >= 100 else 1 if px >= 36 else 0) if d is None else d
    a = Board(px, ss, pad); col = COLOR[kind]; S = a.S
    parts, f = DRAW[kind](a, d)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    lip = a.L(.055 if d else .06); body = np.zeros((S, S), bool)
    for m, k in parts:
        _paste(im, dilate(m, a.o), INK)
        base = CREAM if k == "cream" else WHITE if k == "white" else col
        if k in ("flat", "white"): _paste(im, m, base); continue
        top = m & np.roll(m, -round(lip), 0)                                   # the face of the piece; what is left below is the lip
        _paste(im, m, CREAM_LIP if k == "cream" else mix(col, INK, .40)); _paste(im, top, base)
        ys = np.where(m.any(1))[0]; y0, h = ys[0], max(1, ys[-1] - ys[0])       # soft light over the top 45%
        g = np.clip(1 - (np.arange(S) - y0) / (h * .45), 0, 1) ** 1.6 * .30
        hl = Image.new("RGBA", (S, S), (255, 255, 255, 0)); hl.putalpha(Image.fromarray((top * g[:, None] * 255).astype(np.uint8)))
        im = Image.alpha_composite(im, hl)
        if k == "body": body |= top
    # face: two eyes low and wide, a small smile, blush. No white ring; catchlights only where there is room.
    b = f["big"]; ex, ey = (.062 * b, .078 * b) if d == 0 else (.046 * b, .060 * b)
    if d:
        for bx, by in f["blush"]: _paste(im, a.ellipse(bx, by, .058 * b, .034 * b) & body, mix(col, "#FF4F7B", .55), 235)
        mx, my = f["mouth"]; _paste(im, a.arc(mx, my - .03 * b, .042 * b, 25, 155, .024 * b), INK)
    for x, y in f["eyes"]:
        _paste(im, a.ellipse(x, y, ex, ey), INK)
        if d: _paste(im, a.ellipse(x - ex * .28, y - ey * .36, ex * .36, ex * .36), WHITE)
        if d == 2: _paste(im, a.ellipse(x + ex * .34, y + ey * .40, ex * .17, ex * .17), WHITE)
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
    return Image.fromarray(np.dstack([col, a[..., 3]]).round().astype(np.uint8), "RGBA")


_cache = {}
def icon(kind, px):
    if (kind, px) not in _cache:
        im = icon_hi(kind, px, ss=8 if px >= 64 else 24).resize((px, px), Image.LANCZOS)
        a = np.asarray(im).copy(); a[0, :, 3] = a[-1, :, 3] = 0; a[:, 0, 3] = a[:, -1, 3] = 0   # keep the 1 px padding truly clear
        _cache[(kind, px)] = Image.fromarray(a, "RGBA")
    return _cache[(kind, px)]


def save(im, name, folder=HERE, passes=6):
    bleed(im, passes).save(os.path.join(folder, name), optimize=True); print("wrote", name, im.size)


def star4(d, cx, cy, R, fill, outline=None, ow=0, rot=0.0):
    pts = []
    for i in range(8):
        a = rot + i * math.pi / 4; r = R if i % 2 == 0 else R * .34
        pts.append((cx + math.sin(a) * r, cy - math.cos(a) * r))
    if outline: d.line(pts + pts[:2], fill=outline, width=round(ow * 2), joint="curve")
    d.polygon(pts, fill=fill)


# ---------- the six icons, the small chips, the atlas (same layout as rune-atlas-512x128) ----------
def build_icons():
    for k in ORDER:
        save(icon(k, 128), "icon-%s-128.png" % k)
        save(icon(k, 64), "icon-%s-64.png" % k)
        save(icon(k, 24), "icon-%s-small-24.png" % k)

def build_atlas():
    atlas = Image.new("RGBA", (512, 128), (0, 0, 0, 0)); sprites, small = {}, {}
    for i, (k, name, col, ic) in enumerate(STATS):
        x, y = 8 + i * 72, 8; atlas.paste(icon(k, 64), (x, y)); sprites[k] = {"x": x, "y": y, "w": 64, "h": 64}
        x, y = 8 + i * 32, 80; atlas.paste(icon(k, 24), (x, y)); small[k] = {"x": x, "y": y, "w": 24, "h": 24}
    save(atlas, "icon-atlas-512x128.png")
    data = {"image": "icon-atlas-512x128.png", "size": [512, 128], "gutter": 8, "padding": 1, "order": ORDER,
            "note": "Rects are ImageRectOffset (x, y) and ImageRectSize (w, h). 'sprites' are 64 px, 'small' are the 24 px chips. Same rects as rune-atlas-512x128.json.",
            "stats": {k: {"name": name, "color": col, "icon": ic} for k, name, col, ic in STATS},
            "sprites": sprites, "small": small}
    with open(os.path.join(HERE, "icon-atlas-512x128.json"), "w", newline="\n") as f: json.dump(data, f, indent=2); f.write("\n")
    print("wrote icon-atlas-512x128.json")


# ---------- level-up burst: 8 frames of 128 px in one 1024x128 strip (same timing as the rune burst) ----------
def burst_sheet(kinds, ring_col, name):
    F, N, ss = 128, 8, 4; sheet = Image.new("RGBA", (F * N, F), (0, 0, 0, 0))
    base = {k: icon_hi(k, 40, ss=8, pad=0, d=1) for k in set(kinds)}
    for i in range(N):
        t = i / N; ease = 1 - (1 - t) ** 2.4
        fr = Image.new("RGBA", (F * ss, F * ss), (0, 0, 0, 0)); d = ImageDraw.Draw(fr); c = F * ss / 2
        fade = 1.0 if t < .5 else max(0.0, 1 - (t - .5) / .5) ** 1.2
        rr = (9 + 47 * ease) * ss; rw = max(1.2, 7 * (1 - t) ** 1.5) * ss; ra = round(255 * (1 - t) ** 1.3)
        if i > 0:
            ring = Image.new("RGBA", fr.size, (0, 0, 0, 0))
            ImageDraw.Draw(ring).ellipse((c - rr, c - rr, c + rr, c + rr), outline=mix(WHITE, ring_col, min(1, t * 1.6)) + (ra,), width=round(rw))
            fr = Image.alpha_composite(fr, ring); d = ImageDraw.Draw(fr)
        for j in range(6):                                # sparkles, between the buddies and a little ahead of them
            a = math.radians(30 + j * 60 + 14 * t); r = min(57, 12 + 52 * ease) * ss; R = (2.5 + 5.5 * math.sin(math.pi * min(1, t * 1.25))) * ss * (1 if j % 2 else .7)
            if i > 0 and R > ss * 3: star4(d, c + math.sin(a) * r, c - math.cos(a) * r, R, rgb(LEMON), rgb(INK), ss * .9, rot=t * 2)
        size = (14 + 22 * min(1, t / .14)) if t < .14 else 36 - 14 * ((t - .14) / .86)
        for j, k in enumerate(kinds):                     # buddies stay nearly upright: a gentle rock, so the faces read
            a = math.radians(j * 60 - 16 * (1 - ease)); r = (5 + 37 * ease) * ss
            rock = (-1 if j % 2 else 1) * 12 * math.sin(math.pi * ease)
            st = base[k].resize((round(size * ss),) * 2, Image.LANCZOS).rotate(rock, Image.BICUBIC, expand=True)
            if fade < 1: st.putalpha(st.getchannel("A").point(lambda v: round(v * fade)))
            fr.alpha_composite(st, (round(c + math.sin(a) * r - st.width / 2), round(c - math.cos(a) * r - st.height / 2)))
        if i < 3:                                         # centre flash on the first three frames
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


# ---------- snack decals: 256 px, dark cocoa on clear, eyes and smile cut out so the icing shows ----------
def icon_decal(kind, px=256, ss=4):
    a = Board(px, ss, outline=0, box=(.21, .21, .79, .79)); S = a.S
    parts, f = DRAW[kind](a, 1)
    m = np.zeros((S, S), bool)
    for pm, k in parts: m = (m & ~dilate(pm, a.L(.05))) | pm          # a clear gap where one piece sits on another
    b = f["big"]
    for x, y in f["eyes"]: m &= ~a.ellipse(x, y, .058 * b, .074 * b)
    mx, my = f["mouth"]; m &= ~a.arc(mx, my - .03 * b, .05 * b, 25, 155, .036 * b)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    _paste(im, np.roll(m, round(S * .014), 0), WHITE, 110)             # a soft light under the mark, so it looks pressed in
    _paste(im, m, COCOA)
    return im.resize((px, px), Image.LANCZOS)

def build_decals():
    for k in ORDER:
        im = icon_decal(k); p = im.load()
        assert p[2, 2][3] == 0 and p[253, 253][3] == 0, "corners must stay clear (the cream ring's UVs sit there)"
        save(im, "icon-decal-%s-256.png" % k, SNACK_EXPORT, passes=12)


# ---------- a check sheet (not for upload) ----------
def grey(im):
    g = im.convert("L").convert("RGBA"); g.putalpha(im.getchannel("A")); return g

def build_preview():
    W, H = 1180, 640; im = Image.new("RGB", (W, H), rgb(CREAM))
    d = ImageDraw.Draw(im)
    bgs = [CREAM, "#2E55E6", "#1D36A6", "#10133A", WHITE, "#6BBF4A", LEMON]   # cream tile, shell, tray, well, white, grass, selected
    for r, bg in enumerate(bgs):
        y = r * 52; d.rectangle((0, y, 600, y + 52), fill=rgb(bg))
        for i, k in enumerate(ORDER):
            st = icon(k, 24); im.paste(st, (20 + i * 30, y + 14), st)
            st = icon_hi(k, 32, ss=16).resize((32, 32), Image.LANCZOS); im.paste(st, (230 + i * 38, y + 10), st)
            if i < 4: g = grey(icon(k, 24)); im.paste(g, (480 + i * 30, y + 14), g)
    for i, k in enumerate(ORDER):                         # 24 px chips at 4x, hard pixels, colour then grey; then the 64s
        st = icon(k, 24); big = st.resize((96, 96), Image.NEAREST); im.paste(big, (610 + i * 94, 6), big)
        big = grey(st).resize((96, 96), Image.NEAREST); im.paste(big, (610 + i * 94, 106), big)
        st = icon(k, 64); im.paste(st, (610 + i * 94 + 16, 212), st)
    atlas = Image.open(os.path.join(HERE, "icon-atlas-512x128.png")); d.rectangle((610, 288, 610 + 512, 288 + 128), fill=(200, 190, 170)); im.paste(atlas, (610, 288), atlas)
    for i, k in enumerate(ORDER):
        st = icon(k, 128); im.paste(st, (8 + (i % 4) * 136 + (68 if i > 3 else 0), 368 if i < 4 else 368), st) if i < 4 else None
    for i, k in enumerate(ORDER[4:]):
        st = icon(k, 128).resize((96, 96), Image.LANCZOS); im.paste(st, (620 + i * 104, 420), st)
    for i, k in enumerate(ORDER):
        dc = Image.open(os.path.join(SNACK_EXPORT, "icon-decal-%s-256.png" % k)).resize((72, 72), Image.LANCZOS)
        d.ellipse((836 + i * 56 + 6, 436, 836 + i * 56 + 58, 488), fill=mix(COLOR[k], WHITE, .35)); im.paste(dc, (836 + i * 56 - 4, 426), dc)
    d.rectangle((0, 512, W, H), fill=rgb("#1D36A6"))
    b = Image.open(os.path.join(HERE, "levelup-burst-8x128.png")); im.paste(b, (0, 512), b)
    im.save(os.path.join(HERE, "_preview.png")); print("wrote _preview.png")
    b2 = Image.open(os.path.join(HERE, "levelup-burst-jump-8x128.png")); p2 = Image.new("RGB", (1024, 256), rgb(CREAM)); p2.paste(b, (0, 0), b); p2.paste(b2, (0, 128), b2)
    p2.save(os.path.join(HERE, "_preview-burst.png")); print("wrote _preview-burst.png")


if __name__ == "__main__":
    build_icons(); build_atlas(); build_bursts(); build_decals(); build_preview()
