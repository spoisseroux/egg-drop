"""Ways into the stats menu, and feeding a snack (2026-11-19). Proposal screens only: nothing is built.
Hand-drawn with PIL over existing Studio captures (artifacts/store-listing/raw), reusing the kit
drawn in artifacts/v2-scope-2026-11-19/build_mockups.py. No generated art.

Run from the repo root:  python artifacts/v2-pet-snacks-2026-11-19/build_mockups.py
Writes three 1688x780 PNGs (844x390 phone landscape at 2x) and a contact sheet next to this file.
"""
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "v2-scope-2026-11-19"))
import build_mockups as K          # the shared drawn kit (Canvas, panel, pills, buttons)
K.HERE = HERE
from build_mockups import (Canvas, raw, mix, black, xbold, bold, mono, pill, bar, panel, header, hint, primary,
                           secondary, star, PANEL, RAISED, WELL, SELECTED, TEXT, SOFT, DIM, INK, ACCENT, STARS, PINK)

STAT = {"heart": ("Heart", "#FF86A8"), "power": ("Power", "#FF9D4D"), "energy": ("Energy", "#6CCBFF"),
        "jump": ("Jump", "#B9EE5A"), "speed": ("Speed", "#8FA8FF"), "smarts": ("Smarts", "#E58CFF")}
ORDER = list(STAT)
LEVEL = {"heart": 9, "power": 15, "energy": 8, "jump": 4, "speed": 3, "smarts": 2}      # total 41
FRAC = {"heart": .4, "power": .08, "energy": .7, "jump": .55, "speed": .2, "smarts": .85}
BISCUIT, COCOA = "#EFC27A", "#4A2B22"

def mark(c, kind, cx, cy, s, fill=INK):
    """The six marks as on the 3D snacks (heart, paw, bolt, hop, wind, bulb). s = half size."""
    if kind == "heart": K.glyph(c, "heart", cx, cy, s, fill)
    elif kind == "power":
        c.ellipse((cx - s * .6, cy - s * .1, cx + s * .6, cy + s * .85), fill=fill)
        for dx, dy in ((-.68, -.3), (0, -.62), (.68, -.3)): c.ellipse((cx + s * (dx - .27), cy + s * (dy - .3), cx + s * (dx + .27), cy + s * (dy + .3)), fill=fill)
    elif kind == "energy":
        c.poly([(cx + s * x, cy - s * y) for x, y in ((.15, 1), (-.55, -.1), (-.05, -.1), (-.2, -1), (.55, .2), (.05, .2))], fill)
    elif kind == "jump":
        c.poly([(cx, cy - s), (cx - s * .8, cy - s * .05), (cx + s * .8, cy - s * .05)], fill)
        c.rr((cx - s * .22, cy - s * .1, cx + s * .22, cy + s * .45), s * .05, fill=fill); c.rr((cx - s * .65, cy + s * .68, cx + s * .65, cy + s * .95), s * .1, fill=fill)
    elif kind == "speed":
        for x0, x1, y in ((-.9, .45, -.5), (-.45, .9, 0), (-.9, .15, .5)): c.rr((cx + s * x0, cy + s * (y - .14), cx + s * x1, cy + s * (y + .14)), s * .14, fill=fill)
    elif kind == "smarts":
        c.ellipse((cx - s * .58, cy - s * .8, cx + s * .58, cy + s * .36), fill=fill); c.rr((cx - s * .26, cy + s * .3, cx + s * .26, cy + s * .95), s * .1, fill=fill)

def chip(c, kind, x, y, size):
    c.rr((x, y, x + size, y + size), size * .3, fill=STAT[kind][1]); mark(c, kind, x + size / 2, y + size / 2, size * .3)

def snack(c, kind, cx, cy, r, layers):
    """A drawn stand-in for the 3D snack: count the layers, read the mark. cy = the top biscuit."""
    h = r * .42
    for i in range(layers):                      # bottom layer first
        y = cy + (layers - 1 - i) * h
        c.ellipse((cx - r, y - r * .42 + h * .7, cx + r, y + r * .42 + h * .7), fill=mix(BISCUIT, "#7A4A1E", .35))
        if i > 0: c.ellipse((cx - r * .92, y - r * .4 + h * .45, cx + r * .92, y + r * .4 + h * .45), fill=STAT[kind][1])
        c.ellipse((cx - r, y - r * .42, cx + r, y + r * .42), fill=BISCUIT)
    c.ellipse((cx - r * .76, cy - r * .34, cx + r * .76, cy + r * .28), fill=STAT[kind][1])
    mark(c, kind, cx, cy - r * .03, r * .34, COCOA)

def bear_face(): return raw("companions.jpg").crop((640, 243, 772, 375))
def round_paste(c, img, cx, cy, r):
    size = (K.S(r * 2), K.S(r * 2)); img = K.cover(img, size)
    m = Image.new("L", size, 0); ImageDraw.Draw(m).ellipse((0, 0, size[0] - 1, size[1] - 1), fill=255)
    c.im.paste(img, (K.S(cx - r), K.S(cy - r)), m)
def dock_circle(c, cx, cy, kind):
    c.ellipse((cx - 20, cy - 20, cx + 20, cy + 20), fill=(16, 22, 24), outline=mix(PANEL, "#FFFFFF", .3))
    if kind == "menu":
        for dy in (-6, 0, 6): c.line([(cx - 8, cy + dy), (cx + 8, cy + dy)], TEXT, 2)
    else:
        c.rr((cx - 10, cy - 6, cx + 10, cy + 6), 3, outline=TEXT, width=1.6); c.rr((cx - 4, cy - 3, cx + 4, cy + 3), 1, fill=TEXT)
def caption(c, s):
    w = c.width(s, xbold(8.5)) + 20
    c.rr((W2 - w / 2, 366, W2 + w / 2, 384), 9, fill=(12, 16, 18), outline=mix(PANEL, "#FFFFFF", .2)); c.text((W2, 375), s, xbold(8.5), SOFT, "mm")
W2 = 422

# ============================================================
# 1. The garden: a pet chip on the dock, and a level-up line you can tap
# ============================================================
def garden_chip():
    c = Canvas(raw("garden-bear-path.jpg"), shade=.06)
    # the dock (today: Menu and Deck). New: the pet chip, first in the row.
    x1 = 832
    dock_circle(c, x1 - 20, 34, "deck"); dock_circle(c, x1 - 66, 34, "menu")
    cx0, cx1 = x1 - 190, x1 - 92
    c.rr((cx0, 14, cx1, 54), 20, fill=(16, 22, 24), outline=ACCENT, width=1.6)
    round_paste(c, bear_face(), cx0 + 20, 34, 16)
    c.text((cx0 + 42, 26), "BEAR", xbold(7.5), SOFT, "lm"); c.text((cx0 + 42, 40), "Total 41", black(11.5), TEXT, "lm")
    c.ellipse((cx1 - 12, 10, cx1, 22), fill=STARS, outline=(16, 22, 24), width=1.2)     # something waits: a snack or a reward
    # the level-up line on the notification rail
    x0, y0 = 300, 64
    c.rr((x0, y0 + 2, x0 + 244, y0 + 46), 14, fill=(8, 12, 14)); c.rr((x0, y0, x0 + 244, y0 + 44), 14, fill=PANEL, outline=STAT["power"][1], width=1.4)
    chip(c, "power", x0 + 8, y0 + 8, 28)
    c.text((x0 + 44, y0 + 13), "LEVEL UP", xbold(7.5), STAT["power"][1], "lm"); c.text((x0 + 44, y0 + 28), "Power 15", black(13), TEXT, "lm")
    c.text((x0 + 118, y0 + 28), "New: Fizz merge pop", bold(9), SOFT, "lm")
    c.text((x0 + 232, y0 + 13), "See stats  ›", xbold(8), ACCENT, "rm")
    # the burst over the Bear, in the stat's colour
    for dx, dy, s in ((-34, -18, 6), (30, -26, 7), (44, 6, 5), (-46, 10, 5), (0, -40, 6)):
        mark(c, "power", 466 + dx, 292 + dy, s, STAT["power"][1])
    c.text((466, 240), "+12", mono(11), STAT["power"][1], "mm")
    # callouts
    c.line([(cx0 + 30, 58), (cx0 + 30, 108)], TEXT, 1); pill(c, cx0 - 86, 108, "Tap: Bear's stats, one tap from the garden", bold(8.5), (12, 16, 18), TEXT, h=20)
    pill(c, cx0 - 86, 132, "PC: C     Gamepad: D-pad up", bold(8.5), (12, 16, 18), SOFT, h=20)
    caption(c, "WAY IN 1 AND 3 · the pet chip on the dock, and the level-up line")
    c.save("03-way-in-garden-chip-844x390@2x.png")

# ============================================================
# 2. Pet focus: Stats, Snacks, Dress; the snack tray open and a snack offered
# ============================================================
def focus_feed():
    c = Canvas(raw("pet-focus-a.jpg"), shade=.10)
    # the stats card replaces today's bond card (top right)
    x0, y0, x1 = 664, 12, 832
    c.rr((x0, y0, x1, y0 + 64), 14, fill=PANEL, outline=mix(PANEL, "#FFFFFF", .22))
    c.text((x0 + 12, y0 + 14), "BEAR", xbold(7.5), SOFT, "lm"); c.text((x0 + 12, y0 + 30), "Total 41", black(14), TEXT, "lm")
    c.text((x1 - 12, y0 + 14), "Stats  ›", xbold(8.5), ACCENT, "rm")
    for i, k in enumerate(ORDER):
        bx = x0 + 12 + i * 25
        c.rr((bx, y0 + 44, bx + 21, y0 + 56), 4, fill=WELL); c.rr((bx, y0 + 44, bx + 21 * max(.25, LEVEL[k] / 20), y0 + 56), 4, fill=STAT[k][1])
    # the offered snack beside the Bear's cheek, and the boost it will give
    snack(c, "jump", 508, 226, 17, 2)
    c.line([(526, 224), (560, 210)], TEXT, 1)
    c.rr((560, 190, 742, 244), 12, fill=PANEL, outline=STAT["jump"][1], width=1.4)
    chip(c, "jump", 568, 198, 22); c.text((596, 203), "Jump Snack", black(11.5), TEXT, "lm"); c.text((596, 217), "2x for your next 120 Jump XP", bold(8.5), SOFT, "lm")
    c.text((568, 234), "Bear's Jump boost: none yet", bold(8), DIM, "lm")
    # the snack tray
    ty = 262
    c.rr((182, ty, 662, ty + 62), 16, fill=PANEL, outline=mix(PANEL, "#FFFFFF", .22))
    c.text((196, ty + 12), "SNACK POUCH", xbold(7.5), PINK, "lm"); c.text((196, ty + 26), "5 / 12", mono(10), SOFT, "lm")
    tiles = [("jump", 2, 1, True), ("heart", 3, 1, False), ("power", 1, 2, False), ("smarts", 1, 1, False)]
    for i, (k, layers, count, sel) in enumerate(tiles):
        tx = 268 + i * 59
        c.rr((tx, ty + 7, tx + 54, ty + 55), 10, fill=SELECTED if sel else RAISED, outline=ACCENT if sel else mix(RAISED, "#FFFFFF", .14), width=1.6 if sel else 1)
        snack(c, k, tx + 27, ty + 28 - (layers - 1) * 3, 12, layers)
        c.rr((tx + 36, ty + 40, tx + 52, ty + 53), 6, fill=WELL); c.text((tx + 44, ty + 46.5), "x%d" % count, mono(7.5), TEXT, "mm")
    primary(c, (512, ty + 11, 650, ty + 51), "Feed Bear", "A")
    # the action row
    ry = 334
    for i, (label, key, sel) in enumerate((("Stats", "Y", False), ("Snacks  5", "X", True), ("Dress", "", False))):
        bx = 262 + i * 110
        c.rr((bx, ry, bx + 100, ry + 28), 14, fill=SELECTED if sel else PANEL, outline=ACCENT if sel else mix(PANEL, "#FFFFFF", .22), width=1.4 if sel else 1)
        tw = c.width(label, black(10.5)); sx = bx + 50 - (tw + (18 if key else 0)) / 2
        if key:
            c.ellipse((sx, ry + 7, sx + 14, ry + 21), fill=mix(PANEL, "#FFFFFF", .16)); c.text((sx + 7, ry + 14), key, xbold(7), SOFT, "mm"); sx += 18
        c.text((sx, ry + 14), label, black(10.5), TEXT, "lm")
    caption(c, "WAY IN 2 · tap your pet: Stats, Snacks and Dress live on the pet")
    c.save("04-pet-focus-feed-844x390@2x.png")

# ============================================================
# 3. Stats panel: where snacks and Stat Eggs are reached from
# ============================================================
def stats_pouch():
    c = Canvas(raw("garden-vista.jpg"), shade=.55, blur=1.5)
    box = (12, 8, 832, 382); panel(c, box); header(c, box, "COMPANIONS", "Bear's stats", "142")
    c.text((150, 36), "Total 41 / 594", mono(11), SOFT, "lm")
    # six compact rows
    for i, k in enumerate(ORDER):
        x = 28 + (i % 2) * 222; y = 70 + (i // 2) * 62
        c.card((x, y, x + 214, y + 54)); chip(c, k, x + 8, y + 9, 26)
        c.text((x + 42, y + 15), STAT[k][0], black(12), TEXT, "lm"); c.text((x + 204, y + 15), str(LEVEL[k]), mono(15), TEXT, "rm")
        bar(c, (x + 42, y + 27, x + 204, y + 34), FRAC[k], STAT[k][1])
        boost = {"power": "2x BOOST · 80 XP left", "heart": "2x BONUS today"}.get(k)
        if boost: c.text((x + 42, y + 44), boost, xbold(7.5), STAT[k][1] if "BOOST" in boost else STARS, "lm")
        else: c.text((x + 42, y + 44), "No boost. Feed a %s snack." % STAT[k][0], bold(7.5), DIM, "lm")
    # right column: pouch and eggs
    x0, x1 = 480, 818
    c.card((x0, 70, x1, 232), fill=RAISED)
    c.text((x0 + 12, 84), "SNACK POUCH", xbold(8), PINK, "lm"); c.text((x1 - 12, 84), "5 / 12", mono(10), SOFT, "rm")
    for i, (k, layers, count) in enumerate((("jump", 2, 1), ("heart", 3, 1), ("power", 1, 2), ("smarts", 1, 1))):
        tx = x0 + 12 + i * 80
        c.rr((tx, 96, tx + 72, 176), 10, fill=WELL, outline=mix(WELL, "#FFFFFF", .14))
        snack(c, k, tx + 36, 124 - (layers - 1) * 5, 15, layers)
        c.text((tx + 36, 156), STAT[k][0], xbold(8), TEXT, "mm"); c.text((tx + 36, 167), ("Nibble", "Snack", "Feast")[layers - 1] + " x%d" % count, bold(7.5), SOFT, "mm")
    primary(c, (x0 + 12, 186, x1 - 12, 222), "Feed Bear", "A")
    c.card((x0, 240, x1, 348), fill=RAISED)
    c.text((x0 + 12, 253), "STAT EGGS", xbold(8), PINK, "lm")
    c.ellipse((x0 + 16, 264, x0 + 48, 306), fill=mix("#FFFFFF", STAT["energy"][1], .35), outline=mix(RAISED, "#FFFFFF", .3)); star(c, x0 + 32, 286, 6, "#FFFFFF")
    c.text((x0 + 62, 270), "2 free eggs to hatch", black(11.5), TEXT, "lm"); c.text((x0 + 62, 285), "3 left in today's nest · 15 Stars each", bold(8.5), SOFT, "lm")
    c.text((x0 + 62, 299), "An egg hatches one snack. Odds are on the egg.", bold(8), DIM, "lm")
    secondary(c, (x0 + 12, 314, x1 - 12, 338), "Go to Hatch eggs  ›")
    x = 28
    for key, label, filled in (("+", "Browse", False), ("A", "Feed", True), ("X", "Stat guide", False), ("B", "Back", False)): x += hint(c, x, 356, key, label, filled)
    c.text((818, 364), "Levels never go down. Snacks never spoil.", bold(8.5), DIM, "rm")
    c.save("05-stats-panel-pouch-844x390@2x.png")

def contact():
    names = ["03-way-in-garden-chip-844x390@2x.png", "04-pet-focus-feed-844x390@2x.png", "05-stats-panel-pouch-844x390@2x.png"]
    ims = [Image.open(os.path.join(HERE, n)) for n in names]
    w, h = 844, 390; sheet = Image.new("RGB", (w * 3 + 40, h + 20), (20, 24, 26))
    for i, im in enumerate(ims): sheet.paste(im.resize((w, h), Image.LANCZOS), (10 + i * (w + 10), 10))
    sheet.save(os.path.join(HERE, "contact-sheet-ui.png"), optimize=True); print("wrote contact-sheet-ui.png")

if __name__ == "__main__":
    garden_chip(); focus_feed(); stats_pouch(); contact()
