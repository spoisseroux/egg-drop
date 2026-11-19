"""Rune stat stones, feeding mockups, the eating strip and two onboarding moments (2026-11-19).
Proposal art only: nothing here is built. Everything is drawn with PIL; the backdrops and the
Bear are crops of existing Studio captures (artifacts/store-listing/raw). No generated art.
The kit (Canvas, panel, pills, buttons) is the one in artifacts/v2-scope-2026-11-19/build_mockups.py.

The six runes are Elder Futhark letters (public domain, about 150 to 800 CE), drawn here from
their plain stave shapes. They are not RuneScape's rune symbols, which are Jagex's own art.

Run from the repo root:  python artifacts/v2-feeding-runes-2026-11-19/build_art.py
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "v2-scope-2026-11-19"))
import build_mockups as K
K.HERE = HERE
from build_mockups import (Canvas, raw, mix, rgb, S, black, xbold, bold, mono, pill, bar, panel, header, hint, primary,
                           secondary, star, PANEL, RAISED, WELL, SELECTED, TEXT, SOFT, DIM, INK, ACCENT, STARS, PINK)

STAT = {"heart": ("Heart", "#FF86A8"), "power": ("Power", "#FF9D4D"), "energy": ("Energy", "#6CCBFF"),
        "jump": ("Jump", "#B9EE5A"), "speed": ("Speed", "#8FA8FF"), "smarts": ("Smarts", "#E58CFF")}
ORDER = list(STAT)
# Rune name, the meaning in the old rune poems, the kid line, and the staves (unit box, y down).
RUNE = {
    "heart": ("Wunjo", "joy", "The joy rune", [[(-.38, -1), (-.38, 1)], [(-.38, -1), (.52, -.42), (-.38, .16)]]),
    "power": ("Uruz", "the wild ox", "The ox rune", [[(-.55, 1), (-.55, -1), (.55, -.3), (.55, 1)]]),
    "energy": ("Dagaz", "day", "The day rune", [[(-1.0, -.74), (-1.0, .74)], [(1.0, -.74), (1.0, .74)], [(-1.0, -.74), (1.0, .74)], [(-1.0, .74), (1.0, -.74)]]),
    "jump": ("Ehwaz", "horse", "The horse rune", [[(-.64, 1), (-.64, -1), (0, -.22), (.64, -1), (.64, 1)]]),
    "speed": ("Raidho", "ride, journey", "The journey rune", [[(-.45, -1), (-.45, 1)], [(-.45, -1), (.45, -.5), (-.45, 0), (.5, 1)]]),
    "smarts": ("Ansuz", "a god; wise speech", "The wise rune", [[(-.4, -1), (-.4, 1)], [(-.4, -1), (.5, -.38)], [(-.4, -.3), (.5, .32)]]),
}
OLD = {"heart": "heart", "pop": "power", "poise": "energy", "tumble": "jump", "fetch": "speed", "wonder": "smarts"}
LEVEL = {"heart": 9, "power": 15, "energy": 8, "jump": 4, "speed": 3, "smarts": 2}      # total 41
FRAC = {"heart": .4, "power": .08, "energy": .7, "jump": .55, "speed": .2, "smarts": .85}
BISCUIT, COCOA = "#EFC27A", "#4A2B22"
W2 = 422


# ---------- runes and stones, in raw pixels so they can be tested at true size ----------
def rune_px(d, kind, cx, cy, s, fill, width, squash=1.0):
    for stave in RUNE[kind][3]:
        pts = [(cx + x * s * .86, cy + y * s * squash) for x, y in stave]
        d.line(pts, fill=fill, width=max(1, round(width)), joint="curve")
        for x, y in pts: d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=fill)

def stone_px(d, kind, x, y, size, outline="#FFFFFF"):
    """A rounded rune stone in the sticker style: white edge, a darker lip, a flat face, the rune carved in ink."""
    col = STAT[kind][1]; e = size * .055 if outline else 0
    if outline: d.rounded_rectangle((x, y, x + size, y + size), size * .32, fill=outline)
    d.rounded_rectangle((x + e, y + e, x + size - e, y + size - e), size * .28, fill=mix(col, "#3A2230", .42))
    face = (x + e, y + e, x + size - e, y + size - e - size * .085)
    d.rounded_rectangle(face, size * .27, fill=col)
    if size >= 40:   # a soft light on the top edge, and a chisel line under the rune
        d.rounded_rectangle((x + size * .2, y + e + size * .05, x + size * .8, y + e + size * .11), size * .03, fill=mix(col, "#FFFFFF", .35))
        rune_px(d, kind, x + size / 2, y + size * .49 + size * .022, size * .275, mix(col, "#FFFFFF", .3), size * .1)
    rune_px(d, kind, x + size / 2, y + size * .49, size * .275, INK, size * (.1 if size >= 40 else .112))

def stone_image(kind, px, outline="#FFFFFF", ss=12):
    im = Image.new("RGBA", (px * ss, px * ss), (0, 0, 0, 0))
    stone_px(ImageDraw.Draw(im), kind, 0, 0, px * ss, outline)
    return im.resize((px, px), Image.LANCZOS)

def stone(c, kind, x, y, size, outline="#FFFFFF"): stone_px(c.d, kind, S(x), S(y), S(size), outline)
def rune(c, kind, cx, cy, s, fill=INK, width=None, squash=1.0): rune_px(c.d, kind, S(cx), S(cy), S(s), fill, S(width or s * .42), squash)

def snack(c, kind, cx, cy, r, layers, eaten=0.0):
    """Drawn stand-in for the 3D snack, now stamped with the stat's rune. `eaten` 0..1 takes bites out of it."""
    h = r * .42
    for i in range(layers):
        y = cy + (layers - 1 - i) * h
        c.ellipse((cx - r, y - r * .42 + h * .7, cx + r, y + r * .42 + h * .7), fill=mix(BISCUIT, "#7A4A1E", .35))
        if i > 0: c.ellipse((cx - r * .92, y - r * .4 + h * .45, cx + r * .92, y + r * .4 + h * .45), fill=STAT[kind][1])
        c.ellipse((cx - r, y - r * .42, cx + r, y + r * .42), fill=BISCUIT)
    c.ellipse((cx - r * .76, cy - r * .34, cx + r * .76, cy + r * .28), fill=STAT[kind][1])
    rune(c, kind, cx, cy - r * .03, r * .34, COCOA, r * .15, squash=.62)
    return h

def bite_out(c, cx, cy, r, layers, n, bg):
    """Round bites from the left edge, the side nearest the mouth."""
    h = r * .42
    for i in range(n):
        a = math.radians(200 - i * 38); bx, by = cx + math.cos(a) * r * 1.02, cy + (layers - 1) * h * .5 - math.sin(a) * r * .5
        c.ellipse((bx - r * .5, by - r * .5, bx + r * .5, by + r * .5), fill=bg)

def dash(c, p0, p1, color, width=1.4, on=5, off=4):
    (x0, y0), (x1, y1) = p0, p1; length = math.hypot(x1 - x0, y1 - y0); n = int(length // (on + off))
    for i in range(n + 1):
        a, b = i * (on + off) / length, min(1, (i * (on + off) + on) / length)
        c.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], color, width)

def ring(c, cx, cy, r, color, width=1.6, dashed=False):
    if not dashed: c.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=width); return
    for i in range(0, 360, 20): c.d.arc((S(cx - r), S(cy - r), S(cx + r), S(cy + r)), i, i + 12, fill=color, width=S(width))

def finger(c, x, y):
    c.ellipse((x - 13, y - 13, x + 13, y + 13), fill=mix("#FFFFFF", PANEL, .25), outline="#FFFFFF", width=1.6)
    c.ellipse((x - 5, y - 5, x + 5, y + 5), fill="#FFFFFF")

def caption(c, s, y=366):
    w = c.width(s, xbold(8.5)) + 20
    c.rr((W2 - w / 2, y, W2 + w / 2, y + 18), 9, fill=(12, 16, 18), outline=mix(PANEL, "#FFFFFF", .2)); c.text((W2, y + 9), s, xbold(8.5), SOFT, "mm")

def note(c, x, y, s, ink=TEXT, anchor="l"): return pill(c, x, y, s, bold(8.5), (12, 16, 18), ink, h=20, anchor=anchor, outline=mix(PANEL, "#FFFFFF", .2))

def stats_card(c):
    x0, y0, x1 = 664, 12, 832
    c.rr((x0, y0, x1, y0 + 64), 14, fill=PANEL, outline=mix(PANEL, "#FFFFFF", .22))
    c.text((x0 + 12, y0 + 14), "BEAR", xbold(7.5), SOFT, "lm"); c.text((x0 + 12, y0 + 30), "Total 41", black(14), TEXT, "lm")
    c.text((x1 - 12, y0 + 14), "Stats  ›", xbold(8.5), ACCENT, "rm")
    for i, k in enumerate(ORDER): stone(c, k, x0 + 11 + i * 25, y0 + 41, 19, None)

def coach(c, x, y, w, title, line, color=PINK, button="Got it"):
    """A one-time tip, drawn like the rail's first-visit line: eyebrow, short title, one line."""
    c.rr((x, y + 3, x + w, y + 55), 14, fill=(8, 12, 14)); c.rr((x, y, x + w, y + 52), 14, fill=PANEL, outline=color, width=1.4)
    c.ellipse((x + 12, y + 10, x + 17, y + 15), fill=color); c.text((x + 22, y + 12.5), "TIP", xbold(7.5), color, "lm")
    c.text((x + 12, y + 28), title, black(12.5), TEXT, "lm"); c.text((x + 12, y + 42), line, bold(9), SOFT, "lm")
    bw = c.width(button, xbold(8.5)) + 18
    c.rr((x + w - bw - 10, y + 8, x + w - 10, y + 26), 9, fill=RAISED, outline=mix(RAISED, "#FFFFFF", .2)); c.text((x + w - 10 - bw / 2, y + 17), button, xbold(8.5), TEXT, "mm")

def dock(c, dot=True, pulse=None):
    x1 = 832
    for cx, kind in ((x1 - 20, "deck"), (x1 - 66, "menu")):
        c.ellipse((cx - 20, 14, cx + 20, 54), fill=(16, 22, 24), outline=mix(PANEL, "#FFFFFF", .3))
        if kind == "menu":
            for dy in (-6, 0, 6): c.line([(cx - 8, 34 + dy), (cx + 8, 34 + dy)], TEXT, 2)
        else:
            c.rr((cx - 10, 28, cx + 10, 40), 3, outline=TEXT, width=1.6); c.rr((cx - 4, 31, cx + 4, 37), 1, fill=TEXT)
    cx0, cx1 = x1 - 190, x1 - 92
    if pulse:
        for grow, a in ((5, .8), (10, .4)): c.rr((cx0 - grow, 14 - grow, cx1 + grow, 54 + grow), 20 + grow, outline=mix((40, 60, 50), pulse, a), width=1.6)
    c.rr((cx0, 14, cx1, 54), 20, fill=(16, 22, 24), outline=ACCENT, width=1.6)
    face = K.cover(raw("companions.jpg").crop((640, 243, 772, 375)), (S(32), S(32)))
    m = Image.new("L", face.size, 0); ImageDraw.Draw(m).ellipse((0, 0, face.width - 1, face.height - 1), fill=255)
    c.im.paste(face, (S(cx0 + 4), S(18)), m)
    c.text((cx0 + 42, 26), "BEAR", xbold(7.5), SOFT, "lm"); c.text((cx0 + 42, 40), "Total 41", black(11.5), TEXT, "lm")
    if dot: c.ellipse((cx1 - 12, 10, cx1, 22), fill=STARS, outline=(16, 22, 24), width=1.2)
    return cx0, cx1


# ============================================================
# 01. The six stones
# ============================================================
def sheet_stones():
    K.W, K.H = 844, 330
    c = Canvas(); c.rr((0, 0, 844, 330), 0, fill=rgb(PANEL))
    c.text((24, 16), "STAT RUNE STONES", xbold(9), PINK); c.text((24, 28), "Six real Elder Futhark letters, carved on our own stones", black(17), TEXT)
    c.text((24, 54), "Public-domain letters about 1,800 years old. Not RuneScape's symbols. The stone, colours, outline and lip are ours.", bold(9.5), SOFT)
    for i, k in enumerate(ORDER):
        x = 24 + i * 134; name, col = STAT[k]
        c.card((x, 78, x + 126, 252), 14)
        stone(c, k, x + 23, 90, 80)
        c.text((x + 63, 186), name, black(16), TEXT, "mm"); c.text((x + 63, 204), RUNE[k][0].upper(), xbold(8.5), col, "mm")
        c.text((x + 63, 219), "means: " + RUNE[k][1], bold(8.5), SOFT, "mm"); c.text((x + 63, 236), "“%s”" % RUNE[k][2], bold(8.5), DIM, "mm")
    c.text((24, 272), "ONE MARK EVERYWHERE", xbold(8), DIM)
    x = 24
    for k in ORDER: stone(c, k, x, 286, 30, None); x += 36            # flat UI chip (no white edge on dark glass)
    c.text((x + 4, 301), "UI chip, 30 px", bold(8.5), SOFT, "lm"); x += 96
    for k, layers in (("power", 1), ("jump", 2), ("heart", 3)): snack(c, k, x + 20, 298 - (layers - 1) * 4, 16, layers); x += 46
    c.text((x + 2, 301), "stamped on snacks", bold(8.5), SOFT, "lm"); x += 104
    for i, k in enumerate(("energy", "energy", "energy")): stone(c, k, x + i * 20, 292 - (i % 2) * 8, 16 - i * 2);
    c.text((x + 66, 301), "burst particles", bold(8.5), SOFT, "lm"); x += 150
    c.ellipse((x, 284, x + 34, 318), fill=STAT["smarts"][1], outline="#FFFFFF", width=1.4); rune(c, "smarts", x + 17, 301, 9, INK, 3.6)
    c.text((x + 42, 301), "cape patch, medal", bold(8.5), SOFT, "lm")
    c.save("01-rune-stones.png")
    K.W, K.H = 844, 390


# ============================================================
# 02. Legibility at true pixel sizes (this sheet is never resampled)
# ============================================================
def sheet_legibility():
    Wp, Hp = 1280, 880
    im = Image.new("RGB", (Wp, Hp), rgb("#141C1D")); d = ImageDraw.Draw(im)
    f = lambda name, size: ImageFont.truetype(K.FONTS + name, size)
    d.text((28, 20), "24 px legibility test: real pixels, not resampled", font=f("Nunito-Black.ttf", 26), fill=TEXT)
    d.text((28, 56), "Rows 1 to 4 are stones at their true size on four backgrounds. Row 5 is the 24 px stone enlarged 6x with hard pixels. Row 6 is that in grey.", font=f("Nunito-Bold.ttf", 14), fill=SOFT)
    grass = raw("garden-bear-path.jpg").crop((0, 700, 1224, 776))
    rows = (("Dark glass panel", rgb(PANEL), None), ("Raised card", rgb(RAISED), None), ("Garden grass", None, "#FFFFFF"), ("White", (255, 255, 255), "#FFFFFF"))
    y = 92
    for label, bg, edge in rows:
        if bg is None: im.paste(grass.resize((Wp - 56, 76)), (28, y))
        else: d.rounded_rectangle((28, y, Wp - 28, y + 76), 12, fill=bg)
        ink = TEXT if bg in (rgb(PANEL), rgb(RAISED)) else INK
        d.text((44, y + 8), label + ("  (white sticker edge)" if edge else "  (flat chip)"), font=f("Nunito-ExtraBold.ttf", 12), fill=ink)
        x = 44
        for px in (16, 20, 24, 32):
            d.text((x, y + 56), "%d px" % px, font=f("RobotoMono-Bold.ttf", 11), fill=ink)
            for i, k in enumerate(ORDER):
                st = stone_image(k, px, edge); im.paste(st, (x + 52 + i * (px + 6), y + 30 + (40 - px) // 2 - 6), st)
            x += 52 + 6 * (px + 6) + 18
        y += 84
    # the pairing rule at 24 px: stone + name, as on a stat tile
    d.rounded_rectangle((28, y, Wp - 28, y + 52), 12, fill=rgb(PANEL))
    d.text((44, y + 6), "Paired with the name (the rule wherever there is room)", font=f("Nunito-ExtraBold.ttf", 12), fill=TEXT)
    for i, k in enumerate(ORDER):
        x = 44 + i * 200; st = stone_image(k, 24, None); im.paste(st, (x, y + 24), st)
        d.text((x + 32, y + 24), STAT[k][0], font=f("Nunito-Black.ttf", 17), fill=TEXT)
        d.text((x + 32 + d.textlength(STAT[k][0], font=f("Nunito-Black.ttf", 17)) + 8, y + 29), "15", font=f("RobotoMono-Bold.ttf", 14), fill=STAT[k][1])
    y += 62
    for grey in (False, True):
        d.rounded_rectangle((28, y, Wp - 28, y + 168), 12, fill=rgb(PANEL))
        d.text((44, y + 6), "24 px, enlarged 6x" + (", no colour (a colour-blind and a sunlight check)" if grey else ""), font=f("Nunito-ExtraBold.ttf", 12), fill=TEXT)
        for i, k in enumerate(ORDER):
            st = stone_image(k, 24, None)
            if grey: a = st.getchannel("A"); st = st.convert("L").convert("RGBA"); st.putalpha(a)
            big = st.resize((144, 144), Image.NEAREST); im.paste(big, (44 + i * 200, y + 22), big)
        y += 176
    im.save(os.path.join(HERE, "02-rune-legibility-24px.png"), optimize=True); print("wrote 02-rune-legibility-24px.png", im.size)


# ============================================================
# 03. Stats panel: rune stones, and feeding from the pouch without leaving the panel
# ============================================================
def stats_feed():
    c = Canvas(raw("garden-vista.jpg"), shade=.55, blur=1.5)
    box = (12, 8, 832, 382); panel(c, box); header(c, box, "COMPANIONS", "Bear's stats", "142")
    # left: the live preview is where Bear eats
    c.rr((28, 62, 196, 238), 12, fill=WELL, outline=mix(WELL, "#FFFFFF", .14)); c.paste(K.bear_plain(), (29, 63, 195, 237), r=11)
    ring(c, 112, 150, 62, STAT["jump"][1], 1.6, dashed=True)
    c.rr((36, 216, 188, 232), 8, fill=(8, 12, 14)); c.text((112, 224), "Drop a snack on Bear", xbold(7.5), STAT["jump"][1], "mm")
    c.card((28, 244, 196, 344), 12, fill=mix(PANEL, RAISED, .6))
    c.text((40, 256), "TOTAL LEVEL", xbold(8), DIM); c.text((40, 266), "41", mono(26), TEXT); c.text((78, 288), "/ 594", mono(10), DIM, "ls")
    bar(c, (40, 304, 184, 311), 35 / 54, ACCENT); c.text((40, 318), "Sprout Keeper at 60", bold(8.5), SOFT)
    # middle: six stat tiles with rune stones
    for i, k in enumerate(ORDER):
        x = 204 + (i % 2) * 147; y = 62 + (i // 2) * 62; x1 = x + 141
        sel = k == "jump"
        c.rr((x, y, x1, y + 56), 12, fill=SELECTED if sel else RAISED, outline=ACCENT if sel else mix(RAISED, "#FFFFFF", .14), width=1.4 if sel else 1)
        stone(c, k, x + 8, y + 8, 26, None)
        c.text((x + 41, y + 15), STAT[k][0], black(12), TEXT, "lm"); c.text((x1 - 9, y + 15), str(LEVEL[k]), mono(15), TEXT, "rm")
        bar(c, (x + 41, y + 27, x1 - 9, y + 34), FRAC[k], STAT[k][1], track=mix(WELL, PANEL, .2))
        sub = {"power": ("2x BOOST · 80 XP left", STAT[k][1]), "heart": ("2x BONUS today", STARS), "jump": ("Feed the Jump Snack", ACCENT)}.get(k, ("No boost yet", DIM))
        c.text((x + 41, y + 45), sub[0], xbold(7.5), sub[1], "lm")
    c.card((204, 248, 492, 344), 12, fill=mix(PANEL, RAISED, .6))
    c.text((216, 260), "STAT EGGS", xbold(8), PINK, "lm")
    c.ellipse((216, 270, 242, 304), fill=mix("#FFFFFF", STAT["energy"][1], .35), outline=mix(RAISED, "#FFFFFF", .3)); star(c, 229, 288, 5, "#FFFFFF")
    c.text((252, 277), "2 free eggs to hatch", black(11), TEXT, "lm"); c.text((252, 291), "Each egg hatches one snack. Odds are on the egg.", bold(8), SOFT, "lm")
    secondary(c, (216, 310, 480, 334), "Go to Hatch eggs  ›")
    # right: the pouch, a picked snack, Feed
    x0, x1 = 500, 818
    c.card((x0, 62, x1, 344))
    c.text((x0 + 12, 76), "SNACK POUCH", xbold(8), PINK, "lm"); c.text((x1 - 12, 76), "5 / 12", mono(10), SOFT, "rm")
    for i, (k, layers, count) in enumerate((("jump", 2, 1), ("heart", 3, 1), ("power", 1, 2), ("smarts", 1, 1))):
        tx = x0 + 12 + i * 74; sel = i == 0
        c.rr((tx, 88, tx + 68, 164), 10, fill=SELECTED if sel else WELL, outline=ACCENT if sel else mix(WELL, "#FFFFFF", .14), width=1.6 if sel else 1)
        snack(c, k, tx + 34, 116 - (layers - 1) * 5, 15, layers)
        c.text((tx + 34, 144), STAT[k][0], xbold(8), TEXT, "mm"); c.text((tx + 34, 155), ("Nibble", "Snack", "Feast")[layers - 1] + " x%d" % count, bold(7.5), SOFT, "mm")
    c.rr((x0 + 12, 172, x1 - 12, 232), 10, fill=WELL, outline=STAT["jump"][1], width=1.2)
    stone(c, "jump", x0 + 22, 181, 24, None)
    c.text((x0 + 54, 187), "Jump Snack", black(12), TEXT, "lm"); c.text((x0 + 54, 201), "2x for your next 120 Jump XP", bold(8.5), SOFT, "lm")
    c.text((x0 + 22, 220), "Bear's Jump boost: none yet  ·  Bear loves Heart snacks most", bold(7.5), DIM, "lm")
    primary(c, (x0 + 12, 240, x1 - 12, 282), "Feed Bear", "A")
    c.text(((x0 + x1) / 2, 300), "Or drag a snack onto Bear.", bold(9), SOFT, "mm")
    c.text(((x0 + x1) / 2, 316), "One snack at a time. Bear has to be out with you.", bold(8), DIM, "mm")
    # the drag, drawn once: from the picked tile to the preview
    snack(c, "jump", 164, 178, 13, 2); finger(c, 176, 192)
    x = 28
    for key, label, filled in (("+", "Browse", False), ("A", "Feed", True), ("X", "Stat guide", False), ("B", "Back", False)): x += hint(c, x, 356, key, label, filled)
    c.text((818, 364), "Levels never go down. Snacks never spoil.", bold(8.5), DIM, "rm")
    c.save("03-stats-panel-runes-feed-844x390@2x.png")


# ============================================================
# 04. Inspect card with the rune stones (the first scope's card, marks swapped)
# ============================================================
def inspect_runes():
    K.stat_chip = lambda c, kind, x, y, size, r=None: stone(c, OLD[kind], x, y, size, None)
    K.glyph = lambda c, kind, cx, cy, s, fill=INK: rune(c, OLD[kind], cx, cy, s * 1.15, fill, s * .52)
    K.inspect_card()
    os.replace(os.path.join(HERE, "02-inspect-card-844x390@2x.png"), os.path.join(HERE, "04-inspect-card-runes-844x390@2x.png"))


# ============================================================
# 05. Pet focus: drag a snack from the tray onto the pet
# ============================================================
FX = lambda x: x * 0.4797 - 38.5      # pet-focus-a.jpg source pixels to the 844x390 frame
FY = lambda y: y * 0.4797
def open_mouth(c, cx, cy, r):
    c.ellipse((cx - r, cy - r * .8, cx + r, cy + r), fill=rgb("#5A1F2A")); c.ellipse((cx - r * .6, cy + r * .1, cx + r * .6, cy + r * .95), fill=rgb("#FF8FA3"))

def tray(c, ty, lifted=0, key=True):
    c.rr((182, ty, 662, ty + 62), 16, fill=PANEL, outline=mix(PANEL, "#FFFFFF", .22))
    c.text((196, ty + 12), "SNACK POUCH", xbold(7.5), PINK, "lm"); c.text((196, ty + 26), "5 / 12", mono(10), SOFT, "lm"); c.text((196, ty + 44), "Drag to Bear", bold(8), DIM, "lm")
    for i, (k, layers, count) in enumerate((("jump", 2, 1), ("heart", 3, 1), ("power", 1, 2), ("smarts", 1, 1))):
        tx = 268 + i * 59; sel = i == lifted
        c.rr((tx, ty + 7, tx + 54, ty + 55), 10, fill=SELECTED if sel else RAISED, outline=ACCENT if sel else mix(RAISED, "#FFFFFF", .14), width=1.6 if sel else 1)
        if sel: ring(c, tx + 27, ty + 28, 13, mix(SELECTED, "#FFFFFF", .35), 1.2, dashed=True)      # the slot it left
        else: snack(c, k, tx + 27, ty + 28 - (layers - 1) * 3, 12, layers)
        c.rr((tx + 36, ty + 40, tx + 52, ty + 53), 6, fill=WELL); c.text((tx + 44, ty + 46.5), "x%d" % count, mono(7.5), TEXT, "mm")
    primary(c, (512, ty + 11, 650, ty + 51), "Feed Bear", "A" if key else None)

def focus_drag():
    c = Canvas(raw("pet-focus-a.jpg"), shade=.10); stats_card(c)
    mx, my = FX(955), FY(500)
    c.glow(mx, FY(450), 70, STAT["jump"][1], .28)
    ring(c, mx, FY(455), 74, STAT["jump"][1], 2, dashed=True)                     # the drop zone: the whole head and chest
    open_mouth(c, mx, my, 9)
    tray(c, 262)
    dash(c, (295, 286), (452, 262), "#FFFFFF", 1.4); snack(c, "jump", 470, 252, 17, 2); finger(c, 484, 270)
    c.rr((540, 196, 742, 246), 12, fill=PANEL, outline=STAT["jump"][1], width=1.4)
    stone(c, "jump", 548, 204, 22, None); c.text((576, 209), "Jump Snack", black(11.5), TEXT, "lm"); c.text((576, 223), "2x for your next 120 Jump XP", bold(8.5), SOFT, "lm")
    c.text((548, 237), "Let go to feed Bear", xbold(8), STAT["jump"][1], "lm")
    note(c, 20, 150, "Drop zone: the whole pet, never smaller than 96 px. No aiming at the mouth.")
    note(c, 20, 174, "Inside the ring: Bear opens its mouth and the ring fills. Client only.")
    note(c, 20, 198, "Let go outside: the snack floats back. Nothing is sent.", SOFT)
    for i, (label, key, sel) in enumerate((("Stats", "Y", False), ("Snacks  5", "X", True), ("Dress", "", False))):
        bx = 262 + i * 110
        c.rr((bx, 334, bx + 100, 362), 14, fill=SELECTED if sel else PANEL, outline=ACCENT if sel else mix(PANEL, "#FFFFFF", .22), width=1.4 if sel else 1)
        c.text((bx + 50, 348), (key + "  " if key else "") + label, black(10.5), TEXT, "mm")
    caption(c, "FEED IN PET FOCUS · drag a snack onto the pet, or tap it and press Feed", 368)
    c.save("05-pet-focus-drag-feed-844x390@2x.png")


# ============================================================
# 06. The eating sequence, seven frames
# ============================================================
CROP = (815, 305, 1095, 680)          # the Bear in pet-focus-a.jpg
def strip():
    K.W, K.H = 844, 268
    c = Canvas(); c.rr((0, 0, 844, 268), 0, fill=rgb("#141C1D"))
    c.text((16, 12), "EATING A SNACK · a Jump Snack (3 bites), about 3 seconds", xbold(9), PINK)
    bear = raw("pet-focus-a.jpg").crop(CROP); tw, th = 112, 150; k = tw / (CROP[2] - CROP[0]); col = STAT["jump"][1]
    frames = [("1 Sniff", "0.0 s · client only"), ("2 Mouth opens", "waits for the server"), ("3 First bite", "+0.6 s · nom"), ("4 Bites 2 and 3", "+0.9, +1.2 s"),
              ("5 Wiggle and blush", "+1.6 s · gulp, coo"), ("6 Rune burst", "+2.1 s · sparkle"), ("7 Boost line", "+2.3 s · stays 4 s")]
    fur = (252, 248, 252)
    for i, (title, sub) in enumerate(frames):
        x0 = 16 + i * 117; y0 = 46
        P = lambda sx, sy: (x0 + (sx - CROP[0]) * k, y0 + (sy - CROP[1]) * k)
        c.paste(bear, (x0, y0, x0 + tw, y0 + th), r=10)
        mx, my = P(955, 499); sx, sy = P(1040, 500)
        shut = i in (2, 3, 4)
        if shut:                                            # happy closed eyes
            for ex, ey in (P(880, 441), P(1005, 426)):
                c.ellipse((ex - 9, ey - 12.5, ex + 9, ey + 12.5), fill=fur)
                c.d.arc((S(ex - 6.5), S(ey - 3), S(ex + 6.5), S(ey + 9)), 200, 340, fill=rgb("#2A1A1E"), width=S(2.2))
        if i >= 4:                                          # cheeks blush
            for bx, by in (P(858, 487), P(1035, 470)): c.ellipse((bx - 8, by - 5, bx + 8, by + 5), fill=mix(fur, "#FF7FA0", .62 if i == 4 else .45))
        if i == 0:
            snack(c, "jump", sx + 6, sy - 6, 12, 2)
            for j in range(3): c.d.arc((S(mx + 6 + j * 5), S(my - 14), S(mx + 16 + j * 5), S(my - 2)), 250, 70, fill="#FFFFFF", width=S(1.3))
        elif i == 1: open_mouth(c, mx, my + 1, 7.5); snack(c, "jump", sx + 2, sy - 4, 12, 2)
        elif i in (2, 3):
            open_mouth(c, mx, my + 1, 5 if i == 2 else 6.5)
            h = snack(c, "jump", mx + 21, my + 2, 11 if i == 2 else 8, 2 if i == 2 else 1)
            bite_out(c, mx + 21, my + 2, 11 if i == 2 else 8, 2 if i == 2 else 1, 1 if i == 2 else 2, fur)
            for j in range(5 if i == 2 else 9):             # crumbs: biscuit and the stat's colour
                a = j * 2.4 + i; cx, cy = mx + 6 + math.cos(a) * (8 + j * 2.2), my + 14 + abs(math.sin(a * 1.7)) * (6 + j * 2.4)
                c.ellipse((cx - 1.6, cy - 1.6, cx + 1.6, cy + 1.6), fill=col if j % 3 == 0 else BISCUIT)
        elif i == 4:
            for side in (-1, 1):                            # wiggle marks either side of the body
                bx, by = P(950 + side * 118, 395)
                for j in range(2): c.d.arc((S(bx - 5 + side * j * 5), S(by - 12), S(bx + 5 + side * j * 5), S(by + 12)), 300 if side > 0 else 120, 60 if side > 0 else 240, fill=rgb("#2A3A3C"), width=S(1.8))
        if i >= 5:                                          # a ring of the stat's rune stones
            hx, hy = P(950, 470)
            for j in range(8 if i == 5 else 5):
                a = -math.pi / 2 + j * (2 * math.pi / 8) + .3; rad = 44 if i == 5 else 50; size = (15, 11, 13)[j % 3] if i == 5 else 9
                stone(c, "jump", hx + math.cos(a) * rad * 1.02 - size / 2, hy + math.sin(a) * rad * .9 - size / 2, size)
        if i == 6:
            c.rr((x0 + 4, y0 + th - 34, x0 + tw - 4, y0 + th - 4), 9, fill=PANEL, outline=col, width=1.2)
            stone(c, "jump", x0 + 9, y0 + th - 28, 16, None); c.text((x0 + 29, y0 + th - 25), "Jump boost", black(9), TEXT, "lm"); c.text((x0 + 29, y0 + th - 13), "2x · next 120 XP", bold(7.5), SOFT, "lm")
        c.text((x0 + 2, y0 + th + 12), title, black(9.5), TEXT, "lm"); c.text((x0 + 2, y0 + th + 25), sub, bold(8), SOFT, "lm")
    # the line the server draws through the sequence
    lx = 16 + 2 * 117 - 2.5
    dash(c, (lx, 40), (lx, 232), STARS, 1.4, 4, 3); pill(c, lx - 62, 28, "SERVER RECEIPT", xbold(7.5), STARS, INK, h=15)
    c.text((16, 248), "Frames 1 and 2 are for feel and can stop at any moment. Frames 3 to 7 play only after the server has taken the snack and saved the boost.", bold(8.5), SOFT, "lm")
    c.text((16, 260), "Bear capture with drawn overlays (eyes, mouth, blush, crumbs, stones). Not an animation test.", bold(8), DIM, "lm")
    c.save("06-eating-sequence-strip.png")
    K.W, K.H = 844, 390


# ============================================================
# 07, 08. Two onboarding moments
# ============================================================
def tip_chip():
    c = Canvas(raw("garden-bear-path.jpg"), shade=.06)
    cx0, cx1 = dock(c, dot=False, pulse=ACCENT)
    coach(c, cx0 - 196, 66, 300, "Bear has stats", "Tap Bear's badge to see all six.")
    c.line([(cx0 + 40, 58), (cx0 + 40, 66)], ACCENT, 1.4)
    note(c, 24, 300, "Fires once: the first time the badge shows, in the free garden, no menu open.")
    note(c, 24, 324, "Never blocks. Leaves by itself after 7 s. Saved as coach bit statsChip.", SOFT)
    caption(c, "TIP 1 · the first time the stats badge appears")
    c.save("07-tip-stats-chip-844x390@2x.png")

def tip_feed():
    c = Canvas(raw("pet-focus-a.jpg"), shade=.10); stats_card(c)
    mx, my = FX(955), FY(500)
    ring(c, mx, FY(455), 74, STAT["jump"][1], 2, dashed=True)
    tray(c, 262, key=False)
    # the ghost thumb: three fading steps along the drag
    for t, a in ((.0, .25), (.45, .5), (1.0, 1.0)):
        gx, gy = 295 + (mx + 36 - 295) * t, 290 + (my + 6 - 290) * t - math.sin(t * math.pi) * 22
        ghost = Image.new("RGBA", c.im.size, (0, 0, 0, 0)); gc = Canvas.__new__(Canvas); gc.im = ghost; gc.d = ImageDraw.Draw(ghost)
        snack(gc, "jump", gx, gy, 15, 2); finger(gc, gx + 12, gy + 16)
        ghost.putalpha(ghost.getchannel("A").point(lambda p: int(p * a))); c.im.paste(ghost, (0, 0), ghost); c.d = ImageDraw.Draw(c.im)
    coach(c, 24, 66, 290, "Feed Bear", "Drag a snack to Bear. Or tap it, then Feed.", STAT["jump"][1])
    note(c, 24, 130, "The ghost thumb loops until the first drag, then never again.")
    note(c, 24, 154, "PC: \"Drag a snack to Bear, or click Feed.\"   Gamepad: \"Pick a snack. Press A to feed.\"", SOFT)
    caption(c, "TIP 5 · the first time the snack tray opens with a snack in it", 368)
    c.save("08-tip-first-feed-844x390@2x.png")


def contact():
    names = ["03-stats-panel-runes-feed-844x390@2x.png", "04-inspect-card-runes-844x390@2x.png", "05-pet-focus-drag-feed-844x390@2x.png",
             "07-tip-stats-chip-844x390@2x.png", "08-tip-first-feed-844x390@2x.png"]
    w, h = 844, 390; sheet = Image.new("RGB", (w * 3 + 40, h * 2 + 30), (20, 24, 26))
    for i, n in enumerate(names): sheet.paste(Image.open(os.path.join(HERE, n)).resize((w, h), Image.LANCZOS), (10 + (i % 3) * (w + 10), 10 + (i // 3) * (h + 10)))
    sheet.save(os.path.join(HERE, "contact-sheet.png"), optimize=True); print("wrote contact-sheet.png")


if __name__ == "__main__":
    sheet_stones(); sheet_legibility(); stats_feed(); focus_drag(); strip(); tip_chip(); tip_feed(); inspect_runes(); contact()
