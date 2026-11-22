"""Static mocks for the Toy Shell restyle of the Robux store page (Get Stars).
Drawn with PIL only: the garden backdrop is the ref capture, the offer art is the real
pass/product icon PNGs, the faces are Roblox's own Fredoka One and Builder Sans.
  python artifacts/stars-store-2026-11-21/build_store_mock.py
"""
import glob, math, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ICONS = os.path.join(ROOT, "artifacts", "store-listing", "v2-new-look", "passes")
REF = os.path.join(HERE, "ref-hatch-eggs.jpg")
SS = 2  # supersample


def roblox_font(name):
    hits = sorted(glob.glob(os.path.expanduser("~/AppData/Local/Roblox/Versions/*/content/fonts/" + name)))
    if not hits:
        raise FileNotFoundError(name)
    return hits[-1]


FREDOKA = roblox_font("FredokaOne-Regular.ttf")
SANS = {w: roblox_font("BuilderSans-%s.otf" % w) for w in ("Regular", "Medium", "Bold", "ExtraBold")}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# Kit roles (DeckKit Kit.Color + the default deck's toyShell palette in DeckThemes).
C = dict(
    shell=rgb("#0E735B"), shellHi=rgb("#5BB19D"), shellLip=rgb("#054334"), tray=rgb("#084E3D"),
    well=rgb("#0F1A32"), ink=rgb("#0A1B17"), inkSoft=rgb("#34574E"), onShell=rgb("#FFFFFF"),
    onShellSoft=rgb("#CDEFE7"), cream=rgb("#FFF4DC"), lemon=rgb("#FFE14D"), go=rgb("#43DB5F"),
    stars=rgb("#FFC14D"), stage=rgb("#4A1D3A"), walletGold=rgb("#D9A31C"), walletFace2=rgb("#FFE7B0"),
    disabledFace=rgb("#B9B6C9"), disabledLip=rgb("#8C89A3"), disabledText=rgb("#5A5878"),
)
C["creamLip"] = mix(C["cream"], rgb("#7A5A2A"), .38)
C["lemonLip"] = mix(C["lemon"], rgb("#7A4A00"), .45)
C["goLip"] = mix(C["go"], rgb("#0A3A1A"), .5)
C["starsLip"] = mix(C["stars"], rgb("#7A4A00"), .45)

OFFERS = [
    dict(key="doubleStars", kind="pass", name="2× Stars", price=299, sub="Double Stars, forever",
         blurb="Double Stars from every round and quest. Forever.",
         rows=[("Every round and quest", "2× Stars"), ("Keeps working", "Forever")], chip="FOREVER"),
    dict(key="supporter", kind="pass", name="Supporter", price=99, sub="+1 Star every round",
         blurb="+1 Star for every finished round. Thank you!",
         rows=[("Every finished round", "+1 Star"), ("Keeps working", "Forever")], chip="FOREVER"),
    dict(key="starter", kind="pack", name="Starter pack", price=49, stars=40, sub="40 Stars · one per player",
         blurb="40 Stars to get your garden going. One per player."),
    dict(key="handful", kind="pack", name="Handful of Stars", price=39, stars=20, sub="20 Stars",
         blurb="A little top-up for one more egg."),
    dict(key="pouch", kind="pack", name="Pouch of Stars", price=99, stars=60, sub="60 Stars",
         blurb="Enough Stars for a few eggs."),
    dict(key="jar", kind="pack", name="Jar of Stars", price=199, stars=140, sub="140 Stars",
         blurb="Lots of Stars for lots of eggs."),
    dict(key="chest", kind="pack", name="Chest of Stars", price=499, stars=400, sub="400 Stars", best=True,
         blurb="The big one. Most Stars per Robux."),
]


class Canvas:
    """Draws in design units; k = device px per unit (already supersampled)."""

    def __init__(self, img, k, ox, oy):
        self.img, self.k, self.ox, self.oy = img, k, ox, oy
        self.d = ImageDraw.Draw(img)
        self._fonts = {}

    def p(self, v):
        return int(round(v * self.k))

    def X(self, x):
        return int(round((self.ox + x) * self.k))

    def Y(self, y):
        return int(round((self.oy + y) * self.k))

    def font(self, face, size):
        key = (face, round(size * self.k))
        if key not in self._fonts:
            self._fonts[key] = ImageFont.truetype(FREDOKA if face == "display" else SANS[face], key[1])
        return self._fonts[key]

    def box(self, x, y, w, h, r, fill, outline=None, t=2):
        self.d.rounded_rectangle([self.X(x), self.Y(y), self.X(x + w) - 1, self.Y(y + h) - 1], radius=self.p(r),
                                 fill=fill, outline=outline, width=self.p(t) if outline else 0)

    def key(self, x, y, w, h, r, face, lip, depth, t=2):
        """A pressable: ink-outlined lip under an ink-outlined face (Kit.tile / Kit.button)."""
        self.box(x, y + depth, w, h, r, lip, C["ink"], t)
        self.box(x, y, w, h, r, face, C["ink"], t)

    def text(self, x, y, s, face, size, fill, anchor="lm", maxw=None):
        f = self.font(face, size)
        if maxw is not None:
            while self.d.textlength(s, font=f) > maxw * self.k and len(s) > 2:
                s = s[:-2] + "…"
        self.d.text((self.X(x), self.Y(y)), s, font=f, fill=fill, anchor=anchor)
        return self.d.textlength(s, font=f) / self.k

    def width(self, s, face, size):
        return self.d.textlength(s, font=self.font(face, size)) / self.k

    def wrap(self, x, y, s, face, size, fill, maxw, lead=1.3, maxlines=3):
        words, lines, cur = s.split(), [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            if self.width(trial, face, size) <= maxw or not cur:
                cur = trial
            else:
                lines.append(cur); cur = w
        lines.append(cur)
        for i, line in enumerate(lines[:maxlines]):
            self.text(x, y + i * size * lead, line, face, size, fill, "la")
        return len(lines[:maxlines]) * size * lead

    def star(self, cx, cy, r, fill, outline=None, t=1.5, rot=-90):
        pts = []
        for i in range(10):
            a = math.radians(rot + i * 36)
            rr = r if i % 2 == 0 else r * .5
            pts.append((self.X(cx + rr * math.cos(a)), self.Y(cy + rr * math.sin(a))))
        self.d.polygon(pts, fill=fill)
        if outline:
            self.d.line(pts + [pts[0]], fill=outline, width=self.p(t), joint="curve")

    def sparkle(self, cx, cy, r, fill):
        pts = []
        for i in range(8):
            a = math.radians(-90 + i * 45)
            rr = r if i % 2 == 0 else r * .28
            pts.append((self.X(cx + rr * math.cos(a)), self.Y(cy + rr * math.sin(a))))
        self.d.polygon(pts, fill=fill)

    def paste(self, im, x, y):
        self.img.paste(im, (self.X(x), self.Y(y)), im)
        self.d = ImageDraw.Draw(self.img)


_icon_cache = {}


def icon(c, key, size, radius, outline=2):
    px = c.p(size)
    k = (key, px, c.p(radius), c.p(outline))
    if k not in _icon_cache:
        src = Image.open(os.path.join(ICONS, key + ".png")).convert("RGB").resize((px, px), Image.LANCZOS)
        m = Image.new("L", (px, px), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, px - 1, px - 1], radius=c.p(radius), fill=255)
        out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        out.paste(src, (0, 0), m)
        if outline:
            ImageDraw.Draw(out).rounded_rectangle([0, 0, px - 1, px - 1], radius=c.p(radius), outline=C["ink"] + (255,), width=c.p(outline))
        _icon_cache[k] = out
    return _icon_cache[k]


def shell(c, W, H, r):
    """Kit.sheet + Kit.shellPattern: ink-outlined shell with the two-tone checker."""
    px, py = c.p(W), c.p(H)
    tile = Image.new("RGB", (px, py), C["shell"])
    td = ImageDraw.Draw(tile)
    sq, hi = 22, mix(C["shell"], C["shellHi"], .16)
    for j in range(int(H // sq) + 1):
        for i in range(int(W // sq) + 1):
            if (i + j) % 2 == 0:
                td.rectangle([c.p(i * sq), c.p(j * sq), c.p((i + 1) * sq) - 1, c.p((j + 1) * sq) - 1], fill=hi)
    m = Image.new("L", (px, py), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, px - 1, py - 1], radius=c.p(r), fill=255)
    # soft drop shadow, then the shell, then the ink sheet stroke
    sh = Image.new("RGBA", c.img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([c.X(0), c.Y(6), c.X(W), c.Y(H + 8)], radius=c.p(r), fill=(0, 0, 0, 110))
    c.img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(c.p(8))))
    c.img.paste(tile, (c.X(0), c.Y(0)), m)
    c.d = ImageDraw.Draw(c.img)
    c.box(0, 0, W, H, r, None, C["ink"], 3)


def stage(c, x, y, w, h, r):
    """Kit.previewWell / warmWell: plum stage, dot grid, warm glow, ink outline."""
    px, py = c.p(w), c.p(h)
    st = Image.new("RGB", (px, py), C["stage"])
    glow = Image.new("L", (px, py), 0)
    ImageDraw.Draw(glow).ellipse([px * .25, -py * .2, px * .75, py * 1.1], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(px * .09))
    st = Image.composite(Image.new("RGB", (px, py), mix(C["stage"], rgb("#FFB26B"), .38)), st, glow)
    sd = ImageDraw.Draw(st)
    dot = mix(C["stage"], (255, 255, 255), .10)
    step = c.p(7)
    for j in range(0, py, step):
        for i in range(0, px, step):
            sd.ellipse([i, j, i + c.p(1.6), j + c.p(1.6)], fill=dot)
    m = Image.new("L", (px, py), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, px - 1, py - 1], radius=c.p(r), fill=255)
    c.img.paste(st, (c.X(x), c.Y(y)), m)
    c.d = ImageDraw.Draw(c.img)
    c.box(x, y, w, h, r, None, C["ink"], 2)


def hero(c, key, cx, cy, size):
    r = size * .2
    sh = Image.new("RGBA", c.img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([c.X(cx - size * .42), c.Y(cy + size * .5 - 2), c.X(cx + size * .42), c.Y(cy + size * .5 + 9)], fill=(20, 4, 14, 170))
    c.img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(c.p(2.5))))
    c.d = ImageDraw.Draw(c.img)
    c.box(cx - size / 2, cy - size / 2 + 4, size, size, r, C["ink"])  # ink lip under the art
    c.paste(icon(c, key, size, r, 3), cx - size / 2, cy - size / 2)
    c.sparkle(cx - size * .6, cy - size * .34, size * .07, C["stars"])
    c.sparkle(cx + size * .6, cy - size * .16, size * .05, (255, 255, 255))
    c.sparkle(cx + size * .58, cy + size * .36, size * .035, C["stars"])


def wallet(c, x, cy, h, amount):
    """Kit.wallet: cream capsule, gold rim, the dark coin with the 3D Star."""
    tw = c.width(amount, "display", h * .46)
    w = h + 8 + tw + 14
    c.box(x, cy - h / 2 + 3, w, h, h / 2, C["walletGold"], C["ink"], 2)
    c.box(x, cy - h / 2, w, h, h / 2, C["cream"], C["ink"], 2)
    r = h / 2 + 3
    ccx = x + h / 2 - 2
    c.d.ellipse([c.X(ccx - r), c.Y(cy - r), c.X(ccx + r), c.Y(cy + r)], fill=rgb("#2A2233"), outline=C["ink"], width=c.p(2))
    c.d.ellipse([c.X(ccx - r + 2.5), c.Y(cy - r + 2.5), c.X(ccx + r - 2.5), c.Y(cy + r - 2.5)], outline=C["stars"], width=c.p(2))
    c.star(ccx, cy + .5, r * .66, rgb("#E8930C"))
    c.star(ccx, cy - .8, r * .6, C["stars"])
    c.star(ccx - r * .08, cy - r * .12, r * .3, rgb("#FFE08A"))
    for dx in (-.14, .14):
        c.d.ellipse([c.X(ccx + r * dx - r * .05), c.Y(cy - r * .02), c.X(ccx + r * dx + r * .05), c.Y(cy + r * .16)], fill=rgb("#3B2608"))
    c.text(x + h + 6, cy - 1, amount, "display", h * .46, C["ink"])
    return w


def round_key(c, x, cy, h, glyph):
    c.d.ellipse([c.X(x), c.Y(cy - h / 2 + 3), c.X(x + h), c.Y(cy + h / 2 + 3)], fill=C["creamLip"], outline=C["ink"], width=c.p(2))
    c.d.ellipse([c.X(x), c.Y(cy - h / 2), c.X(x + h), c.Y(cy + h / 2)], fill=C["cream"], outline=C["ink"], width=c.p(2))
    mx = x + h / 2
    if glyph == "?":
        c.text(mx, cy, "?", "display", h * .46, C["ink"], "mm")
    else:
        a, t = h * .17, c.p(2.2)
        c.d.line([c.X(mx + a), c.Y(cy), c.X(mx - a), c.Y(cy)], fill=C["ink"], width=t)
        c.d.line([c.X(mx - a * .25), c.Y(cy - a * .7), c.X(mx - a), c.Y(cy), c.X(mx - a * .25), c.Y(cy + a * .7)], fill=C["ink"], width=t, joint="curve")


def header(c, W, compact, balance):
    """Kit.header: eyebrow, tinted title plate with sparkle, help, wallet, back arrow."""
    h, cy, right = (36, 34, W - 20) if compact else (44, 44, W - 24)
    left = 16 if compact else 24
    c.text(left, 12 if compact else 22, "GARDEN", "Bold", 10 if compact else 11, C["onShellSoft"])
    ts = 20 if compact else 26
    tw = c.width("Get Stars", "display", ts)
    ph = 30 if compact else 38
    py = cy - ph / 2 + (4 if compact else 6)
    pw = tw + (40 if compact else 48)
    c.key(left - 8, py, pw, ph, 10, C["stars"], C["starsLip"], 3)
    c.text(left, py + ph / 2 - 1, "Get Stars", "display", ts, C["ink"])
    c.sparkle(left + tw + (13 if compact else 16), py + ph / 2 - 2, 7 if compact else 8, C["ink"])
    round_key(c, right - h, cy, h, "back")
    ww = h + 8 + c.width(balance, "display", h * .46) + 14
    wx = right - h - 8 - ww
    wallet(c, wx, cy, h, balance)
    round_key(c, wx - 10 - h, cy, h, "?")


def chip(c, x, cy, s, h, fill, fg, size=None, check=False, star=False, anchor="l", outline=True):
    size = size or h * .5
    pad = h * .45
    lead = (size * 1.15 if (check or star) else 0)
    w = c.width(s, "ExtraBold", size) + pad * 2 + lead
    if anchor == "r":
        x -= w
    c.box(x, cy - h / 2, w, h, h / 2, fill, C["ink"] if outline else None, 2)
    tx = x + pad
    if check:
        t = c.p(max(1.6, size * .17))
        c.d.line([c.X(tx), c.Y(cy), c.X(tx + size * .28), c.Y(cy + size * .28), c.X(tx + size * .8), c.Y(cy - size * .3)], fill=fg, width=t, joint="curve")
    if star:
        c.star(tx + size * .4, cy, size * .5, fg)
    c.text(tx + lead, cy, s, "ExtraBold", size, fg)
    return w


def sticker(c, cx, cy, s, h):
    """Kit.chip as a sticker (Kit.Sticker tilt -4): the THIS WEEK tag, reused."""
    size = h * .52
    f = c.font("ExtraBold", size)
    w = int(c.d.textlength(s, font=f) + c.p(h * .9))
    hh = c.p(h)
    pad = c.p(6)
    im = Image.new("RGBA", (w + pad * 2, hh + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([pad, pad + c.p(2), pad + w, pad + hh + c.p(2)], radius=hh // 2, fill=C["ink"] + (150,))
    d.rounded_rectangle([pad, pad, pad + w, pad + hh], radius=hh // 2, fill=C["cream"] + (255,), outline=C["ink"] + (255,), width=c.p(1.5))
    d.rounded_rectangle([pad + c.p(2.5), pad + c.p(2.5), pad + w - c.p(2.5), pad + hh - c.p(2.5)], radius=hh // 2, fill=C["stars"] + (255,))
    d.text((pad + w / 2, pad + hh / 2), s, font=f, fill=C["ink"] + (255,), anchor="mm")
    im = im.rotate(4, resample=Image.BICUBIC, expand=True)
    c.img.alpha_composite(im, (c.X(cx) - im.width // 2, c.Y(cy) - im.height // 2))
    c.d = ImageDraw.Draw(c.img)


def glyph(c, cx, cy, r, letter):
    c.d.ellipse([c.X(cx - r), c.Y(cy - r), c.X(cx + r), c.Y(cy + r)], fill=(255, 255, 255), outline=C["ink"], width=c.p(1.6))
    c.text(cx, cy, letter, "ExtraBold", r * 1.05, C["ink"], "mm")


def offer_row(c, o, x, y, w, h, selected, owned, compact, tall=False):
    face, lip = (C["lemon"], C["lemonLip"]) if selected else (C["cream"], C["creamLip"])
    c.key(x, y, w, h, 10, face, lip, 3 if compact else 4)
    isz = h - (10 if compact else 12)
    c.paste(icon(c, o["key"], isz, isz * .22, 1.5 if compact else 2), x + (5 if compact else 6), y + (h - isz) / 2)
    tx = x + isz + (13 if compact else 16)
    right = x + w - (10 if compact else 14)
    if owned:
        rw = chip(c, right, y + h / 2, "OWNED", 20 if compact else 24, C["ink"], C["cream"], check=True, anchor="r", outline=False)
    else:
        rw = c.width("R$ %d" % o["price"], "ExtraBold", 13 if compact else 15)
        c.text(right, y + h / 2, "R$ %d" % o["price"], "ExtraBold", 13 if compact else 15, C["ink"], "rm")
    maxw = right - rw - 8 - tx
    if compact:
        c.text(tx, y + h / 2 - 1, o["name"], "display", 14, C["ink"], maxw=maxw)
    elif tall:
        c.text(tx, y + h / 2 - 12, o["name"], "display", 18, C["ink"], maxw=maxw)
        c.text(tx, y + h / 2 + 13, o["sub"], "Medium", 13, C["inkSoft"], maxw=maxw)
    else:
        c.text(tx, y + h / 2 - 10, o["name"], "display", 16, C["ink"], maxw=maxw)
        c.text(tx, y + h / 2 + 10, o["sub"], "Medium", 12, C["inkSoft"], maxw=maxw)
    if o.get("best"):
        sticker(c, x + w - (46 if compact else 56), y - (1 if compact else 2), "BEST VALUE", 17 if compact else 20)


def primary(c, x, y, w, h, o, owned, show_glyph, compact):
    size = 16 if compact else 19
    if owned:
        c.key(x, y, w, h, 12, C["disabledFace"], C["disabledLip"], 5 if compact else 6)
        s = "Owned"
        tw = c.width(s, "display", size)
        sx = x + w / 2 - tw / 2 + size * .6
        t = c.p(2.6)
        cx0, cy0 = sx - size * 1.15, y + h / 2
        c.d.line([c.X(cx0), c.Y(cy0), c.X(cx0 + size * .28), c.Y(cy0 + size * .28), c.X(cx0 + size * .8), c.Y(cy0 - size * .3)], fill=C["disabledText"], width=t, joint="curve")
        c.text(sx, y + h / 2 - 1, s, "display", size, C["disabledText"])
        return
    c.key(x, y, w, h, 12, C["go"], C["goLip"], 5 if compact else 6)
    # Kit.glint: the light bar along the top of the face
    c.box(x + 10, y + 4, w - 20, 3, 1.5, mix(C["go"], (255, 255, 255), .55))
    s = "Buy · R$ %d" % o["price"]
    tw = c.width(s, "display", size)
    gr = 12 if show_glyph else 0
    total = tw + (gr * 2 + 12 if show_glyph else 0)
    sx = x + w / 2 - total / 2
    if show_glyph:
        glyph(c, sx + gr, y + h / 2, gr, "A")
        sx += gr * 2 + 12
    c.text(sx, y + h / 2 - 1, s, "display", size, C["ink"])


def info_row(c, x, y, w, h, label, value, size):
    c.box(x, y, w, h, 5, C["well"])
    c.text(x + 10, y + h / 2, label, "Medium", size, C["onShellSoft"])
    c.text(x + w - 10, y + h / 2, value, "ExtraBold", size, C["onShell"], "rm")


def detail_rows(o, balance):
    if o["kind"] == "pass":
        return o["rows"]
    rows = [("Stars", "+%d" % o["stars"]), ("Your wallet after", "%d" % (balance + o["stars"]))]
    return rows


def hint(c, x, cy, cap, label, compact=False):
    w = chip(c, x, cy, cap, 22, rgb("#3A4750"), (255, 255, 255), size=9.5)
    c.box(x, cy - 11, w, 22, 11, None, mix(C["ink"], (255, 255, 255), .0), 1.5)
    tw = c.text(x + w + 8, cy, label, "Medium", 12.5, C["onShellSoft"])
    return w + 8 + tw + 22


def desktop(path, selected, owned=(), passes_only=False, balance=20):
    W, H = 1920, 1080
    s = H / 734
    bg = Image.open(REF).convert("RGB")
    bg = bg.resize((round(bg.width * s * SS), H * SS), Image.LANCZOS)
    off = (bg.width - W * SS) // 2
    img = bg.crop((off, 0, off + W * SS, H * SS)).convert("RGBA")
    PW, PH = 888, 637
    c = Canvas(img, s * SS, 381 - off / (s * SS), 77)
    shell(c, PW, PH, 28)
    header(c, PW, False, str(balance))
    offers = [o for o in OFFERS if not (passes_only and o["kind"] == "pack")]
    sel = next(o for o in offers if o["key"] == selected)

    # left: the offer list (Hatch eggs' egg list, same tiles)
    lx, lw, y = 24, 340, 92
    c.text(lx + 4, y + 6, "BOOSTS", "Bold", 11, C["onShellSoft"]); y += 20
    rh, gap = (72, 16) if passes_only else (50, 8)
    for o in offers:
        if o["key"] == "starter":
            y += 8
            c.text(lx + 4, y + 6, "STARS PACKS", "Bold", 11, C["onShellSoft"]); y += 20
        offer_row(c, o, lx, y, lw, rh, o is sel, o["key"] in owned, False, tall=passes_only)
        y += rh + gap
    y += 8
    c.wrap(lx + 4, y, "You can always earn Stars free by playing.", "Medium", 13, C["onShellSoft"], lw - 8)

    # right: the detail tray (Hatch eggs' egg card)
    tx, ty, tw, th = 386, 92, PW - 24 - 386, 478
    c.box(tx, ty, tw, th, 14, C["tray"], C["ink"], 2)
    ix, iw = tx + 16, tw - 32
    stage(c, ix, ty + 16, iw, 196, 12)
    hero(c, sel["key"], ix + iw / 2, ty + 16 + 95, 144)
    y = ty + 16 + 196 + 22
    c.text(ix, y, sel["name"], "display", 23, C["onShell"])
    is_owned = sel["key"] in owned
    if sel["kind"] == "pack":
        chip(c, ix + iw, y, str(sel["stars"]), 26, C["stars"], C["ink"], size=13, star=True, anchor="r")
    else:
        chip(c, ix + iw, y, "OWNED" if is_owned else sel["chip"], 26, C["stars"], C["ink"], size=12, check=is_owned, anchor="r")
    y += 20
    y += c.wrap(ix, y, sel["blurb"], "Medium", 14, C["onShellSoft"], iw, maxlines=2) + 14
    c.text(ix, y, "WHAT YOU GET", "Bold", 11, C["onShell"]); y += 12
    for label, value in detail_rows(sel, balance):
        info_row(c, ix, y, iw, 26, label, value, 13.5); y += 31
    if sel.get("best"):
        info_row(c, ix, y, iw, 26, "Best value", "Most Stars per Robux", 13.5)
    if is_owned:
        c.text(ix + iw / 2, ty + th - 96, "Thank you! This boost is always on.", "Medium", 13, C["onShellSoft"], "mm")
    primary(c, ix, ty + th - 16 - 60, iw, 54, sel, is_owned, True, False)

    # footer: Kit hint chips left, the fair-play line right
    fy, x = PH - 30, 24
    for cap, label in (("WASD", "Browse"), ("ENTER", "Buy"), ("BKSP", "Back")):
        x += hint(c, x, fy, cap, label)
    c.text(PW - 24, fy, "Roblox asks you to confirm every purchase.", "Medium", 12.5, C["onShellSoft"], "rm")
    img.resize((W, H), Image.LANCZOS).convert("RGB").save(path, optimize=True)


def phone(path, selected, owned=(), balance=20):
    W, H = 844, 390
    s = H / 734
    bg = Image.open(REF).convert("RGB")
    bg = bg.resize((round(bg.width * s * SS * 2), H * SS * 2), Image.LANCZOS)
    k = SS * 2  # phone draws at 4x then lands at 844 (2x file kept too)
    off = (bg.width - W * k) // 2
    img = bg.crop((off, 0, off + W * k, H * k)).convert("RGBA")
    PW, PH = 728, 374
    c = Canvas(img, k, 58, 8)
    shell(c, PW, PH, 22)
    header(c, PW, True, str(balance))
    sel = next(o for o in OFFERS if o["key"] == selected)

    lx, lw, y = 16, 268, 64
    rh, gap = 35, 5
    for o in OFFERS:
        if o["key"] == "starter":
            y += 6
        offer_row(c, o, lx, y, lw, rh, o is sel, o["key"] in owned, True)
        y += rh + gap

    tx, ty, tw, th = 296, 64, PW - 16 - 296, 284
    c.box(tx, ty, tw, th, 14, C["tray"], C["ink"], 2)
    ix, iw = tx + 10, tw - 20
    stage(c, ix, ty + 10, 138, 138, 10)
    hero(c, sel["key"], ix + 69, ty + 10 + 66, 100)
    rx, rw = ix + 150, iw - 150
    c.text(rx, ty + 24, sel["name"], "display", 19, C["onShell"], maxw=rw)
    if sel["kind"] == "pack":
        chip(c, rx, ty + 50, str(sel["stars"]), 22, C["stars"], C["ink"], size=11.5, star=True)
    else:
        chip(c, rx, ty + 50, sel["chip"], 22, C["stars"], C["ink"], size=10.5)
    c.wrap(rx, ty + 68, sel["blurb"], "Medium", 12.5, C["onShellSoft"], rw, maxlines=2)
    y = ty + 108
    for label, value in detail_rows(sel, balance):
        info_row(c, rx, y, rw, 20, label, value, 11.5); y += 23
    c.text(ix + iw / 2, ty + 170, "Roblox asks you to confirm every purchase.", "Medium", 11.5, C["onShellSoft"], "mm")
    primary(c, ix, ty + th - 10 - 49 - 40, iw, 44, sel, sel["key"] in owned, False, True)
    # the free-earn line sits under the key, inside the tray, so it never scrolls away
    c.text(ix + iw / 2, ty + th - 22, "You can always earn Stars free by playing.", "Medium", 11.5, C["onShellSoft"], "mm")
    img.resize((W * 2, H * 2), Image.LANCZOS).convert("RGB").save(path.replace(".png", "@2x.png"), optimize=True)
    img.resize((W, H), Image.LANCZOS).convert("RGB").save(path, optimize=True)


if __name__ == "__main__":
    desktop(os.path.join(HERE, "store-redesign-mock.png"), "jar", owned=("doubleStars",))
    desktop(os.path.join(HERE, "store-redesign-mock-passes-only.png"), "doubleStars", owned=("doubleStars",), passes_only=True)
    phone(os.path.join(HERE, "store-redesign-mock-phone.png"), "jar", owned=("doubleStars",))
    print("ok")
