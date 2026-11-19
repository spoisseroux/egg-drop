"""v2 hatch redesign mockups (Fable as Astra, 2026-11-19). PIL only, house method.
Reuses the Toy Shell drawing kit from ../v2-ui-restyle-2026-11-19/build_mockups.py (unedited).
3D content is our own: the egg is cut from a Studio capture, the Bunny and the Stat Snack are
Blender blockout renders, the jar is cut from a Studio capture. The Stat Egg is a drawn placeholder.
No generated art.   python artifacts/v2-hatch-redesign-2026-11-19/build_mockups.py
"""
import importlib.util, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location("toy", os.path.join(ROOT, "artifacts", "v2-ui-restyle-2026-11-19", "build_mockups.py"))
T = importlib.util.module_from_spec(spec); spec.loader.exec_module(T)
S, R, font, mix, rgb = T.S, T.R, T.font, T.mix, T.rgb
INK, CREAM, WHITE, LEMON, GO = T.INK, T.CREAM, T.WHITE, T.LEMON, T.GO
W, H = 844, 390
STAGE, STAGE_DOT, GLOW = "#4A1D3A", "#7A3458", "#FFB26B"
TIER = {"Common": ("#FFF1D6", "#FFFFFF"), "Uncommon": ("#57E08A", "#C8FFD9"), "Rare": ("#8E7CFF", "#5CC8FF")}
CLASSIC = dict(shell="#2E55E6", lip="#1A2F9C", tray="#1D36A6", soft="#DCE5FF", tag="#FF8FC0")
EMBER = dict(shell="#BE2E37", lip="#71171D", tray="#831D24", soft="#FFE0E2", tag="#FF9B70")
STATS = {n: (c, r) for n, c, r in T.STAT}
load = T.load
EGG = BUNNY = SNACK = JAR = STATEGG = None


# ---------- assets ----------
def egg_outline(cx, top, bot, half):
    pts = []
    for i in range(121):
        t = i / 120; a = t * math.pi
        pts.append((cx + half * (math.sin(a) ** .82) * (.80 + .20 * t), top + (bot - top) * (.5 - .5 * math.cos(a))))
    return pts + [(2 * cx - x, y) for x, y in reversed(pts)]

def egg_cut():
    """The live egg from a Studio frame; an egg-shaped mask keeps the floor ring and beam out."""
    src = load("artifacts/reveal-2026-11-15/frames/phone-844x390/pet-bear-844-t0.10.jpg")
    crop = src.crop((226, 196, 340, 340)); w, h = crop.size
    big = crop.resize((w * 8, h * 8), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", big.size, 0)
    ImageDraw.Draw(m).polygon(egg_outline(57 * 8, 4 * 8, 142 * 8, 53 * 8), fill=255)
    big.putalpha(m.filter(ImageFilter.GaussianBlur(3))); return big

def jar_cut():
    """The Citrus jar from a Studio capture, keyed on warm against the teal card behind it (soft: the capture is 1x)."""
    crop = load("artifacts/qa-2026-11-16c-v775/customization-egg/07-reveal-citrus-and-gloss-750x402.png").crop((158, 114, 224, 182))
    a = np.asarray(crop).astype(np.int32); m = np.clip((a[..., 0] - a[..., 2] - 18) * 9, 0, 255).astype(np.uint8)
    mask = Image.fromarray(m, "L").filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    big = crop.resize((crop.width * 8, crop.height * 8), Image.BICUBIC).convert("RGBA")
    big.putalpha(mask.resize(big.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(5)).point(lambda v: max(0, min(255, int((v - 100) * 3)))))
    return big.crop(big.getbbox())

def rgba(rel, box=None):
    im = Image.open(os.path.join(ROOT, rel)).convert("RGBA")
    if box: im = im.crop(box)
    return im.crop(im.getbbox())

def fit(im, h): return im.resize((max(1, round(im.width * S(h) / im.height)), S(h)), Image.LANCZOS)

def silhouette(im, col=INK):
    s = Image.new("RGBA", im.size, rgb(col) + (255,)); s.putalpha(im.getchannel("A")); return s

def paste(c, im, cx, cy, rot=0):
    if rot: im = im.rotate(rot, Image.BICUBIC, expand=True)
    c.im.paste(im, (S(cx) - im.width // 2, S(cy) - im.height // 2), im); c._redraw()

def blank(w, h):
    c = T.Canvas(w, h); c.im = Image.new("RGBA", (S(w), S(h)), (0, 0, 0, 0)); c._redraw(); return c

def stat_egg(h):
    """Drawn placeholder for the Stat Egg: cream shell, a belt of six rune stones."""
    w = h * .76; c = blank(int(w + 8), int(h + 8))
    pts = egg_outline(4 + w / 2, 4, 4 + h, w / 2)
    c.poly(pts, INK)
    c.poly([(4 + w / 2 + (x - 4 - w / 2) * .95, 4 + h / 2 + (y - 4 - h / 2) * .965) for x, y in pts], "#FFF4DC")
    c.ellipse((w * .28, h * .13, w * .46, h * .24), fill="#FFFFFF")
    for i, (n, (col, rune)) in enumerate(STATS.items()):
        x = 4 + w * (.13 + .148 * i); y = 4 + h * (.58 + .04 * math.sin(i / 5 * math.pi))
        T.stone(c, x, y, w * .135, col, rune)
    return c.im


# ---------- drawn parts ----------
def checker(c, off=0, size=16, a=.11):
    yy, xx = np.mgrid[0:c.im.height, 0:c.im.width]
    m = ((((xx - S(off)) // S(size)) + ((yy - S(off)) // S(size))) % 2).astype(np.float32)
    m *= np.linspace(1, .45, c.im.height, dtype=np.float32)[:, None] * 255 * a
    c.im.paste(Image.new("RGB", c.im.size, (255, 255, 255)), (0, 0), Image.fromarray(m.astype(np.uint8), "L")); c._redraw()

def stage(c, box, tier=None, burst=0.0, pool=True, rim=1.0, dim=0.0):
    """The fixed warm stage well: berry glass, dots, apricot pool; the tier lights its rim."""
    x0, y0, x1, y1 = box; r = 22
    c.rr((x0, y0, x1, y1 + 4), r, fill=INK)
    c.rr((x0 + 3, y0 + 3, x1 - 3, y1 + 1), r - 3, fill=mix(STAGE, INK, .5))
    base = mix(STAGE, INK, dim * .55)
    if burst > 0:
        second = TIER[tier][0] if tier == "Rare" else GLOW  # only Rare tints the rays; other tiers light the rim
        c.sunburst((x0, y0, x1, y1), r, (x0 + x1) / 2, (y0 + y1) / 2 + 10, mix(base, GLOW, .10 + .25 * burst), mix(base, second, .22 + .30 * burst), rays=12, o=3)
    else:
        c.rr((x0 + 3, y0 + 3, x1 - 3, y1 - 3), r - 3, fill=base)
        y = y0 + 11; k = 0
        while y < y1 - 6:
            x = x0 + 11 + (4 if k % 2 else 0)
            while x < x1 - 6:
                c.ellipse((x - .8, y - .8, x + .8, y + .8), fill=mix(STAGE_DOT, base, .2 + dim * .5)); x += 8
            y += 8; k += 1
    if pool:
        cx = (x0 + x1) / 2; g = Image.new("RGBA", c.im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(g)
        d.ellipse((S(cx - 92), S(y1 - 66), S(cx + 92), S(y1 - 30)), fill=rgb(GLOW) + (150,))
        g = g.filter(ImageFilter.GaussianBlur(S(7))); c.im.paste(g, (0, 0), g); c._redraw()
        c.ellipse((cx - 70, y1 - 58, cx + 70, y1 - 38), outline=mix(GLOW, WHITE, .3), width=1.6)
    if tier and rim > 0:
        c.rr((x0 + 3, y0 + 3, x1 - 3, y1 - 3), r - 3, outline=mix(base, TIER[tier][0], rim), width=3)

def bloom(c, cx, cy, rad, col, a=200):
    g = Image.new("RGBA", c.im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    d.ellipse((S(cx - rad), S(cy - rad), S(cx + rad), S(cy + rad)), fill=rgb(col) + (a,))
    g = g.filter(ImageFilter.GaussianBlur(S(rad * .32))); c.im.paste(g, (0, 0), g); c._redraw()

def spark(c, x, y, s, col=WHITE):
    T.sparkle(c, x, y, s + 1.8, INK); T.sparkle(c, x, y, s, col)

def confetti(c, cx, cy, n, r0, r1, stat=None, tier="Common", seed=3, sy=.72):
    """Rune stones (the stat's own, or blank pebbles in the tier colour) and four-point sparkles.
    Never Stars gold and never a five-point star: that shape is the wallet's."""
    rnd = random.Random(seed)
    for i in range(n):
        a = i / n * math.tau + rnd.uniform(-.2, .2); d = rnd.uniform(r0, r1)
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d * sy
        if not (10 < x < W - 10 and 10 < y < H - 10): continue
        if i % 3 == 2:
            spark(c, x, y, rnd.uniform(4.5, 7), rnd.choice([CREAM, LEMON, TIER[tier][1]]))
        else:
            size = rnd.uniform(12, 18); t = blank(40, 40)
            if stat: T.stone(t, 20, 20, size, STATS[stat][0], STATS[stat][1])
            else:
                col = rnd.choice([TIER[tier][0], CREAM, LEMON]); h = size / 2
                t.rr((20 - h, 20 - h, 20 + h, 20 + h + 1.6), size * .32, fill=INK)
                t.rr((20 - h + 1.3, 20 - h + 1.3, 20 + h - 1.3, 20 + h - 1.3), size * .28, fill=col)
            paste(c, t.im, x, y, rnd.uniform(-40, 40))

def sticker(c, x, cy, s, face, tilt=-3, size=10.5):
    f = font("xb", size); w = c.tw(s, f) + 26
    c.sticker(x + w / 2, cy, w, 24, s, face=face, tilt=tilt, f=f)

def title(c, x, cy, s, size=30, under=None):
    f = font("disp", size); c.text((x, cy + 2.5), s, f, INK, stroke=3.2); c.text((x, cy), s, f, WHITE, stroke=2.6, stroke_fill=INK)
    if under:
        w = c.tw(s, f); y = cy + size * .64
        c.line([(x, y), (x + w * .72, y)], INK, 5.4); c.line([(x, y - .4), (x + w * .72, y - .4)], under, 2.6)

def chip(c, cx, cy, s, fill=INK, text=CREAM, size=9.5):
    f = font("xb", size); w = c.tw(s, f) + 20; c.chip((cx - w / 2, cy - 10, cx + w / 2, cy + 10), s, fill=fill, text=text, f=f)

def close(c):
    c.round_key(810, 32, 15); c.line([(805, 27), (815, 37)], INK, 2.4); c.line([(815, 27), (805, 37)], INK, 2.4)

def again(c, price, pal, line1, line2):
    c.toy((24, 326, 206, 370), 10, CREAM, T.CREAM_LIP, lip=3)
    f = font("disp", 12.5); c.text((38, 348), "Hatch another", f, INK)
    x = 38 + c.tw("Hatch another", f) + 14; T.star(c, x, 348, 7); c.text((x + 11, 348.5), str(price), font("mono", 12.5), INK)
    c.tray((214, 326, 404, 373), 10, fill=pal["tray"])
    c.text((226, 342), line1, font("b", 12), WHITE); c.text((226, 359), line2, font("m", 12), pal["soft"])

def buttons(c, second, first):
    T.key(c, (420, 326, 616, 370), second, size=14); T.primary(c, (626, 326, 820, 370), first)

def crack(c, cx, cy, w, light=None):
    pts = [(cx - w / 2 + w * i / 8, cy + (0 if i in (0, 8) else (6 if i % 2 else -6))) for i in range(9)]
    if light:
        for x, y in pts[1:-1:2]: c.poly([(x - 3, y), (x + 3, y), (x + (x - cx) * 1.7, y - 74)], mix(STAGE, light, .6))
    c.line(pts, INK, 3.6); c.line(pts, light or WHITE, 1.4)

def arcs(c, cx, cy, rad, side):
    for k, r_ in enumerate((rad, rad + 9)):
        a0 = (-28, 28) if side > 0 else (152, 208)
        c.d.arc((S(cx - r_), S(cy - r_), S(cx + r_), S(cy + r_)), a0[0], a0[1], fill=rgb(WHITE), width=S(2.4 - k * .8))

def shell_bg(pal, off):
    c = T.Canvas(W, H, fill=pal["shell"]); checker(c, off); return c

CENTRE, SEAT = (232, 20, 612, 366), (24, 20, 404, 312)


# ---------- frames ----------
def pet_frames():
    pal = CLASSIC; out = []
    egg = fit(EGG, 150); bun = fit(BUNNY, 196)
    def base(off, box=CENTRE, **k):
        c = shell_bg(pal, off); stage(c, box, **k); return c
    c = base(1); paste(c, egg, 422, 238); chip(c, 96, 36, "A NEW FRIEND?", fill=pal["tag"], text=INK)
    out.append((c, "0.00 to 0.18  SHELL RISE", "The shell slides up, the stage well opens, the egg eases to size. Checker drifts at 8 px/s."))
    c = base(4, tier="Rare", rim=.25); paste(c, egg, 428, 236, -9); arcs(c, 424, 240, 86, 1); arcs(c, 424, 240, 86, -1)
    chip(c, 422, 346, "Tap to skip", fill=INK)
    out.append((c, "0.12 to 0.62  SHAKES", "Two rocks, each with a knock. The camera pushes in 4% and tips 2 degrees with each rock."))
    c = base(8, tier="Rare", rim=.7, dim=.35); paste(c, egg, 422, 238, 6); crack(c, 424, 232, 84, light=TIER["Rare"][0])
    out.append((c, "0.65 to 0.95  CRACKS", "The crack draws in two steps and the tier's light leaks out. The rim takes the tier colour; the dots dim."))
    c = base(20, tier="Rare", rim=1, dim=.6, burst=.25); bloom(c, 422, 222, 80, TIER["Rare"][0], 130); paste(c, egg, 422, 220); crack(c, 424, 214, 96, light=TIER["Rare"][1])
    for i in range(8):
        a = i / 8 * math.tau + .3; T.stone(c, 422 + math.cos(a) * 132, 222 + math.sin(a) * 100, 19, *STATS["Jump"])
    out.append((c, "0.95 to 1.38  RARE ONLY: THE HOLD", "The egg lifts and stops. Rune stones circle it, the checker runs three times faster, the harp rise plays."))
    c = base(26, tier="Rare", rim=1, burst=1, pool=False); bloom(c, 422, 210, 120, WHITE, 215)
    top = egg.crop((0, 0, egg.width, egg.height // 2)); bot = egg.crop((0, egg.height // 2, egg.width, egg.height))
    paste(c, top, 310, 96, 38); paste(c, bot, 540, 300, -28); paste(c, silhouette(fit(BUNNY, 176)), 422, 214)
    confetti(c, 422, 200, 30, 150, 400, stat="Jump", tier="Rare", seed=5)
    out.append((c, "1.38  BURST (0.98 for Common and Uncommon)", "One soft bloom inside the well. Shell halves fly, the pet rises as a silhouette, stones and sparkles jump the frame."))
    c = base(40, box=SEAT, tier="Rare", rim=1, burst=.8); bloom(c, 214, 186, 70, GLOW, 110); paste(c, bun, 214, 172)
    for x, y, s in ((60, 60, 7), (366, 84, 6), (58, 250, 5), (370, 262, 8)): spark(c, x, y, s)
    chip(c, 214, 348, "Drag to spin", fill=INK)
    sticker(c, 420, 52, "RARE  ·  NEW FRIEND", TIER["Rare"][0]); title(c, 420, 100, "BUNNY", 38, under=TIER["Rare"][0])
    c.text((420, 148), "All ears, mostly for snacks.", font("m", 14), WHITE)
    c.tray((420, 172, 820, 226), 12, fill=pal["tray"]); T.stone(c, 448, 199, 26, *STATS["Jump"])
    c.text((472, 191), "Loves Jump", font("disp", 14), WHITE); c.text((472, 209), "Jump snacks make it extra happy.", font("m", 12), pal["soft"])
    buttons(c, "Back", "Meet Bunny"); close(c)
    out.append((c, "2.45  RESULT (2.05 without the hold)", "The well slides to its seat, the sticker stamps, the name slams, the buttons go live. No odds: pets are never random."))
    return out

def cell(c, box, name, pct, got):
    c.toy(box, 8, LEMON if got else CREAM, T.LEMON_LIP if got else T.CREAM_LIP, lip=2, glint=False)
    x0, y0, x1, y1 = box; cy = (y0 + y1) / 2
    c.text((x0 + 9, cy), name, font("disp", 12), INK); c.text((x1 - 9, cy), pct, font("mono", 12), INK, "rm")

def odds_head(c, pal):
    c.tray((420, 152, 820, 312), 12, fill=pal["tray"])
    c.text((434, 172), "IN THIS EGG", font("xb", 12), pal["soft"])
    c.chip((688, 162, 808, 182), "YELLOW = YOU GOT", fill=LEMON, text=INK, f=font("xb", 9))

def snack_card():
    pal = CLASSIC; c = shell_bg(pal, 30); stage(c, SEAT, tier="Uncommon", burst=.7); bloom(c, 214, 186, 64, GLOW, 100)
    paste(c, fit(SNACK, 150), 214, 168)
    for x, y, s in ((66, 70, 7), (360, 96, 6), (70, 244, 5), (356, 250, 7), (120, 44, 4), (310, 288, 4)): spark(c, x, y, s, TIER["Uncommon"][1])
    again(c, 15, pal, "A Feast within 5 eggs", "2 left in today's nest")
    sticker(c, 420, 40, "UNCOMMON  ·  STAT SNACK", TIER["Uncommon"][0]); title(c, 420, 80, "POWER SNACK", 30, under=TIER["Uncommon"][0])
    T.stone(c, 430, 118, 18, *STATS["Power"]); c.text((446, 118), "2x Power XP for your next 120 XP", font("b", 13), WHITE)
    c.text((420, 138), "Two layers. Bear has already noticed.", font("m", 12), pal["soft"])
    odds_head(c, pal)
    for i, (n, p) in enumerate((("Nibble", "60%"), ("Snack", "30%"), ("Feast", "10%"))):
        cell(c, (432 + i * 127, 190, 432 + i * 127 + 121, 218), n, p, i == 1)
    c.text((434, 244), "Each stat 16.7%", font("b", 12), WHITE)
    for i, (n, (col, rune)) in enumerate(STATS.items()):
        x = 562 + i * 27
        if n == "Power": c.rr((x - 13, 230, x + 13, 258), 8, fill=INK); c.rr((x - 11.4, 231.6, x + 11.4, 256.4), 7, fill=LEMON)
        T.stone(c, x, 243, 17, col, rune)
    c.text((736, 244), "Power", font("b", 12), WHITE)
    c.text((434, 270), "After 7 eggs with no Feast, the next one is a Feast.", font("m", 12), pal["soft"])
    c.text((434, 290), "Probabilities are rounded; the total may not equal 100%.", font("m", 12), pal["soft"])
    buttons(c, "Keep", "Feed now"); close(c); return c

def jar_card():
    pal = EMBER; c = shell_bg(pal, 12); stage(c, SEAT, tier="Common", burst=.55); bloom(c, 214, 186, 60, GLOW, 110)
    paste(c, fit(JAR, 150), 214, 166)
    for x, y, s in ((70, 76, 6), (356, 240, 6)): spark(c, x, y, s)
    again(c, 12, pal, "A charm within 9 eggs", "3 charm shapes to find")
    sticker(c, 420, 40, "NEW COLOUR JAR", TIER["Common"][0]); title(c, 420, 80, "CITRUS JAR", 30, under=LEMON)
    c.text((420, 118), "Sunshine, squeezed. Mind the pips.", font("b", 13), WHITE)
    c.text((420, 138), "1 in inventory  ·  choose a pet and a colour", font("m", 12), pal["soft"])
    odds_head(c, pal)
    rows = (("Citrus", "17%"), ("Rose", "17%"), ("Tide", "17%"), ("Iris", "17%"), ("Gloss", "10%"), ("Matte", "10%"), ("Jelly", "6%"), ("Charm", "6%"))
    for i, (n, p) in enumerate(rows):
        x = 432 + (i % 4) * 95; y = 190 + (i // 4) * 34; cell(c, (x, y, x + 90, y + 28), n, p, i == 0)
    c.text((434, 272), "Charm: 2% for each shape you are missing.", font("m", 12), pal["soft"])
    c.text((434, 292), "If 14 eggs pass without a charm, the next one is a charm.", font("m", 12), pal["soft"])
    buttons(c, "Store", "Use now"); close(c); return c

def snack_frames():
    pal = CLASSIC; out = []; egg = STATEGG
    c = shell_bg(pal, 6); stage(c, CENTRE, tier="Uncommon", rim=.7, dim=.3); paste(c, egg, 422, 238, 7)
    crack(c, 420, 206, 78, light=TIER["Uncommon"][0]); arcs(c, 424, 240, 86, 1)
    chip(c, 84, 36, "STAT EGG", fill=pal["tag"], text=INK); chip(c, 422, 346, "Tap to skip", fill=INK)
    out.append((c, "0.70  CRACK", "Today's clock. Rim and leaking light go green for Uncommon. 'Tap to skip' shows from the second Stat Egg on."))
    c = shell_bg(pal, 9); stage(c, CENTRE, tier="Uncommon", burst=1, pool=False); bloom(c, 422, 210, 96, WHITE, 190)
    top = egg.crop((0, 0, egg.width, egg.height // 2)); bot = egg.crop((0, egg.height // 2, egg.width, egg.height))
    paste(c, top, 318, 104, 34); paste(c, bot, 534, 300, -24); paste(c, fit(SNACK, 116), 422, 206, 8)
    confetti(c, 422, 200, 18, 150, 330, stat="Power", tier="Uncommon", seed=11)
    out.append((c, "0.98 to 1.06  BURST AND POP", "The approved Uncommon sting lands here. The snack pops out; Power stones and sparkles jump the frame."))
    c = shell_bg(pal, 12); stage(c, (118, 20, 498, 330), tier="Uncommon", burst=.8); bloom(c, 308, 190, 64, GLOW, 100); paste(c, fit(SNACK, 150), 308, 172)
    for k in range(3): c.line([(512 + k * 10, 110 + k * 50), (538 + k * 10, 110 + k * 50)], WHITE, 2.6 - k * .6)
    f = font("xb", 10.5); s = "UNCOMMON  ·  STAT SNACK"; w = c.tw(s, f) + 26
    c.sticker(566 + w / 2, 56, w, 24, s, face=TIER["Uncommon"][0], tilt=-10, f=f)
    c.tray((566, 190, 900, 330), 12, fill=pal["tray"]); T.key(c, (566, 346, 706, 390), "Keep", size=14); T.primary(c, (716, 346, 900, 390), "Feed now")
    out.append((c, "1.26 to 1.65  SLIDE AND STAMP", "The well slides left while the card rises from the right. The sticker stamps and the name slams at 1.65."))
    return out

def strip(frames, cols, name, head):
    fw, fh = W * 2, H * 2; pad, cap = 28, 100; rows = math.ceil(len(frames) / cols)
    sheet = Image.new("RGB", (pad + cols * (fw + pad), 110 + rows * (fh + cap + pad)), rgb("#15152A")); d = ImageDraw.Draw(sheet)
    d.text((pad, 34), head, font=font("disp", 22, 2), fill=rgb(CREAM))
    for i, (c, t, note) in enumerate(frames):
        x = pad + (i % cols) * (fw + pad); y = 110 + (i // cols) * (fh + cap + pad)
        sheet.paste(c.out(), (x, y)); d.text((x, y + fh + 14), "%d   %s" % (i + 1, t), font=font("disp", 15, 2), fill=rgb(LEMON))
        d.text((x, y + fh + 54), note, font=font("m", 12.5, 2), fill=rgb("#DCE5FF"))
    sheet.save(os.path.join(HERE, name), optimize=True); print("wrote", name, sheet.size); return sheet

def main():
    global EGG, BUNNY, SNACK, JAR, STATEGG
    EGG = egg_cut(); BUNNY = rgba("artifacts/v2-pet-redesign-2026-11-19/raw/solo-bunny-threeq.png")
    SNACK = rgba("artifacts/v2-pet-snacks-2026-11-19/raw/snack-grid.png", (386, 411, 586, 603))
    JAR = jar_cut()
    STATEGG = stat_egg(150)
    a = strip(pet_frames(), 3, "01-rare-pet-hatch-beat-strip.png", "Rare pet hatch, six beats  ·  Toy Shell, Classic deck  ·  phone 844x390 at 2x  ·  a drawing, not a Studio capture")
    b = strip(snack_frames(), 3, "02-stat-snack-hatch-strip.png", "Stat Egg to Power Snack (Uncommon), three beats  ·  phone 844x390 at 2x  ·  the Stat Egg is a drawn placeholder")
    cards = []
    for c, n in ((snack_card(), "03-result-card-stat-snack-844x390@2x.png"), (jar_card(), "04-result-card-colour-jar-ember-deck-844x390@2x.png")):
        im = c.out(); im.save(os.path.join(HERE, n), optimize=True); print("wrote", n, im.size); cards.append(im)
    w = 1500; parts = [s.resize((w, round(s.height * w / s.width)), Image.LANCZOS) for s in (a, b)]
    cw = w // 2 - 6; pair = Image.new("RGB", (w, round(H * cw / W)), rgb("#15152A"))
    for i, im in enumerate(cards): pair.paste(im.resize((cw, pair.height), Image.LANCZOS), (i * (cw + 12), 0))
    parts.append(pair); cs = Image.new("RGB", (w, sum(p.height for p in parts) + 24), rgb("#15152A")); y = 0
    for p in parts: cs.paste(p, (0, y)); y += p.height + 12
    cs.save(os.path.join(HERE, "contact-sheet.png"), optimize=True); print("wrote contact sheet", cs.size)


if __name__ == "__main__":
    main()
