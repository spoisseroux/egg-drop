"""Shade tweaker mockups (2026-11-19). Proposal only: nothing here is built. No generated art.

Run from the repo root:  python artifacts/v2-shade-tweaker-2026-11-19/build_mockups.py
Needs raw/bear-pass-*.png (render_bear_passes.py: three passes of the live Bear from pet-bear.blend).

  01-bear-shade-steps.png                 the Bear, undyed and dyed, at every shade step of both colours
  02-customize-shade-row-844x390@2x.png   Customize > Hue with the new shade row (phone landscape)
  03-shade-row-states.png                 the row's states, the two drops and the pad / keyboard map

The Bear pictures are colour maths over the three passes, in linear light:
  picture = rest + (primary - rest) * MainColour + (secondary - rest) * SecondColour
The shade maths is the game's own PetPalette.tint (a linear-light mix): lighter mixes towards white,
darker mixes towards black. UI parts are reused from artifacts/v2-scope-2026-11-19/build_mockups.py.
"""
import importlib.util, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("house", os.path.join(HERE, "..", "v2-scope-2026-11-19", "build_mockups.py"))
K = importlib.util.module_from_spec(spec); spec.loader.exec_module(K); K.HERE = HERE
S, mix, rgb = K.S, K.mix, K.rgb

# ---------- the proposal's numbers (V2-SHADE-TWEAKER-2026-11-19.md section 1) ----------
LIGHT = [0, .25, .50, .72]          # mix towards white, steps 1..3
DARK = [0, .18, .34, .48]           # mix towards black, steps 1..3
CAPS = {"main": (3, 2), "secondary": (3, 3)}     # (lighter, darker) steps offered
WHITE, GREY = "#FFFFFF", "#A8A5AE"  # PetBaseColors
ROSE, TIDE, CITRUS, IRIS = "#FF327A", "#008DFF", "#FFCC00", "#9350FF"
DOSE = [0, .44, .65, .84, .93, 1]   # HueCatalog.DoseWeights
FACE_INK = "#2B1A20"

def lin(c): return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)
def srgb(c): return np.where(c <= .0031308, c * 12.92, 1.055 * np.clip(c, 1e-9, None) ** (1 / 2.4) - .055)
def vec(h): return np.array(rgb(h), dtype=np.float64) / 255
def hexa(v): return "#%02X%02X%02X" % tuple(int(round(float(x) * 255)) for x in np.clip(v, 0, 1))
def tint(base, target, w):          # PetPalette.tint
    return hexa(srgb(lin(vec(base)) * (1 - w) + lin(vec(target)) * w))
def shade(colour, step):            # step > 0 lighter, < 0 darker
    return colour if step == 0 else tint(colour, "#FFFFFF", LIGHT[step]) if step > 0 else tint(colour, "#000000", DARK[-step])
def hsv(h):
    r, g, b = vec(h); mx, mn = max(r, g, b), min(r, g, b)
    return (0 if mx == 0 else (mx - mn) / mx), mx
def lum(h): return float(lin(vec(h)) @ np.array([.2126, .7152, .0722]))
def contrast(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True); return (x + .05) / (y + .05)
def same(a, b): return max(abs(x - y) for x, y in zip(rgb(a), rgb(b))) <= 2

# ---------- the Bear ----------
def load(name):
    a = np.asarray(Image.open(os.path.join(HERE, "raw", "bear-pass-%s.png" % name)).convert("RGBA"), dtype=np.float64) / 255
    return lin(a[..., :3]), a[..., 3]
P, ALPHA = load("primary"); SEC, _ = load("secondary"); REST, _ = load("rest")
P, SEC = np.clip(P - REST, 0, None), np.clip(SEC - REST, 0, None)
def bear(main, secondary, height=None):
    out = REST + P * lin(vec(main)) + SEC * lin(vec(secondary))
    im = Image.fromarray((np.dstack([np.clip(srgb(out), 0, 1), ALPHA]) * 255).round().astype(np.uint8), "RGBA")
    im = im.crop(im.getbbox())
    if height: im = im.resize((round(im.width * height / im.height), height), Image.LANCZOS)
    return im
def grounded(im, tone=(40, 30, 34, 80)):
    w, h = im.size; pad = round(h * .06)
    out = Image.new("RGBA", (w + pad * 2, h + pad), (0, 0, 0, 0))
    ImageDraw.Draw(out).ellipse((pad + w * .14, h - pad * .9, pad + w * .86, h + pad * .7), fill=tone)
    out = out.filter(ImageFilter.GaussianBlur(max(2, pad * .35))); out.alpha_composite(im, (pad, 0)); return out

# ---------- drawn icons: readable without colour ----------
def sun(d, cx, cy, r, fill):
    d.ellipse((cx - r * .5, cy - r * .5, cx + r * .5, cy + r * .5), fill=fill)
    for i in range(8):
        a = i * math.pi / 4
        d.line((cx + math.cos(a) * r * .72, cy + math.sin(a) * r * .72, cx + math.cos(a) * r, cy + math.sin(a) * r), fill=fill, width=max(1, round(r * .2)))
def moon(d, cx, cy, r, fill, back):
    d.ellipse((cx - r * .8, cy - r * .8, cx + r * .8, cy + r * .8), fill=fill)
    d.ellipse((cx - r * .25, cy - r * 1.0, cx + r * 1.15, cy + r * .4), fill=back)
def drop(d, cx, cy, r, kind):
    """A round drop: Sun Drop (cream, sun mark) or Moon Drop (indigo, moon mark)."""
    body, mark, edge = (("#FFF1C9", "#E0962A", "#F3C968") if kind == "sun" else ("#4B4A86", "#E8E6FF", "#7C7ACB"))
    d.polygon([(cx, cy - r * 1.55), (cx - r * .84, cy - r * .3), (cx + r * .84, cy - r * .3)], fill=edge)
    d.ellipse((cx - r, cy - r * .85, cx + r, cy + r * 1.15), fill=edge)
    k = .88
    d.polygon([(cx, cy - r * 1.38), (cx - r * .7, cy - r * .3), (cx + r * .7, cy - r * .3)], fill=body)
    d.ellipse((cx - r * k, cy - r * .85 + r * (1 - k), cx + r * k, cy + r * 1.15 - r * (1 - k)), fill=body)
    if kind == "sun": sun(d, cx, cy + r * .15, r * .62, mark)
    else: moon(d, cx - r * .06, cy + r * .15, r * .62, mark, body)

# ============================================================
# 1. The Bear at every step
# ============================================================
def steps_sheet():
    F = K.FONTS
    def black(s): return ImageFont.truetype(F + "Nunito-Black.ttf", s)
    def bold(s): return ImageFont.truetype(F + "Nunito-Bold.ttf", s)
    def mono(s): return ImageFont.truetype(F + "RobotoMono-Bold.ttf", s)
    PAPER, CARD, INK, SOFT, LINE, GOOD, BAD = (241, 236, 230), (250, 247, 243), (38, 32, 36), (120, 110, 112), (214, 205, 196), (46, 140, 96), (196, 72, 72)
    dyed_main, dyed_sec = tint(WHITE, ROSE, DOSE[2]), tint(GREY, TIDE, DOSE[3])
    deep_main, deep_sec = tint(WHITE, IRIS, DOSE[5]), tint(GREY, CITRUS, DOSE[5])
    rows = [
        ("Undyed Bear", "MAIN colour (white)", "main", WHITE, GREY),
        ("Undyed Bear", "SECOND colour (grey)", "secondary", WHITE, GREY),
        ("Dyed Bear: Rose x2, Tide x3", "MAIN colour", "main", dyed_main, dyed_sec),
        ("Dyed Bear: Rose x2, Tide x3", "SECOND colour", "secondary", dyed_main, dyed_sec),
        ("Strongest dye: Iris x5, Citrus x5", "MAIN colour", "main", deep_main, deep_sec),
        ("Strongest dye: Iris x5, Citrus x5", "SECOND colour", "secondary", deep_main, deep_sec),
    ]
    cols = [3, 2, 1, 0, -1, -2, -3]
    CW, CH, LX, TOP = 300, 372, 330, 250
    W, H = LX + CW * 7 + 50, TOP + CH * len(rows) + 150
    s = Image.new("RGBA", (W, H), PAPER + (255,)); d = ImageDraw.Draw(s)
    d.text((50, 36), "Shade Drops: the Bear at every step", font=black(46), fill=INK)
    d.text((50, 96), "Colour maths over three passes of the live Bear (pet-bear.blend). Lighter mixes the colour towards white, darker towards black,", font=bold(23), fill=SOFT)
    d.text((50, 126), "in linear light, with the game's own PetPalette.tint. Each row changes one colour only; the other colour stays as it is.", font=bold(23), fill=SOFT)
    heads = ["3 lighter", "2 lighter", "1 lighter", "Original shade", "1 darker", "2 darker", "3 darker"]
    for i, t in enumerate(heads):
        cx = LX + CW * i + CW / 2
        if i < 3: sun(d, cx - d.textlength(t, font=black(24)) / 2 - 22, TOP - 32, 13, (224, 150, 42))
        if i > 3: moon(d, cx - d.textlength(t, font=black(24)) / 2 - 22, TOP - 32, 13, (75, 74, 134), PAPER)
        d.text((cx, TOP - 32), t, font=black(24), fill=INK, anchor="mm")
    report = []
    for r, (who, what, slot, main, sec) in enumerate(rows):
        y = TOP + CH * r
        d.rounded_rectangle((40, y + 6, W - 40, y + CH - 6), 26, fill=CARD, outline=LINE, width=2)
        d.text((62, y + 40), what, font=black(25), fill=INK)
        for j, line in enumerate(who.split(": ")): d.text((62, y + 78 + j * 30), line, font=bold(21), fill=SOFT)
        base = main if slot == "main" else sec
        s_, v_ = hsv(base); d.text((62, y + 160), base, font=mono(22), fill=INK)
        d.text((62, y + 192), "S %d%%  V %d%%" % (round(s_ * 100), round(v_ * 100)), font=mono(19), fill=SOFT)
        hi, lo = CAPS[slot]
        d.text((62, y + 240), "Offered: %d lighter," % hi, font=bold(21), fill=GOOD); d.text((62, y + 268), "%d darker" % lo, font=bold(21), fill=GOOD)
        for i, step in enumerate(cols):
            cx = LX + CW * i + CW / 2
            offered = (step <= hi) if step > 0 else (-step <= lo)
            c = shade(base, step)
            flat = step != 0 and same(c, shade(base, step - 1 if step > 0 else step + 1))
            im = grounded(bear(c if slot == "main" else main, c if slot == "secondary" else sec, 250))
            if not offered:
                im = Image.blend(Image.new("RGBA", im.size, CARD + (0,)), im, .5)
            s.alpha_composite(im, (int(cx - im.width / 2), y + 22))
            d.ellipse((cx - 62, y + 303, cx - 30, y + 335), fill=rgb(c), outline=LINE, width=2)
            d.text((cx - 20, y + 319), c, font=mono(20), fill=INK if offered else SOFT, anchor="lm")
            if step == 0: d.rounded_rectangle((cx - 138, y + 14, cx + 138, y + CH - 14), 22, outline=INK, width=3)
            tag = None
            if not offered: tag = ("NOT OFFERED: too dark", BAD)
            elif flat: tag = ("no change: already white", SOFT)
            if tag:
                tw = d.textlength(tag[0], font=bold(18)); d.rounded_rectangle((cx - tw / 2 - 12, y + 26, cx + tw / 2 + 12, y + 58), 16, fill=CARD, outline=tag[1], width=2)
                d.text((cx, y + 42), tag[0], font=bold(18), fill=tag[1], anchor="mm")
            report.append((what, who, step, c, offered))
    y = TOP + CH * len(rows) + 18
    d.text((50, y), "Safe range", font=black(28), fill=INK)
    d.text((50, y + 42), "Body (Main): 3 lighter, 2 darker. A body keeps at least 83% of its brightness, so it stays a soft-toy colour and still glows at night.", font=bold(22), fill=SOFT)
    d.text((50, y + 72), "Second colour: 3 lighter, 3 darker. It carries the muzzle, so it stops before the nose and mouth get lost. Nothing reaches pure white or pure black.", font=bold(22), fill=SOFT)
    s.convert("RGB").save(os.path.join(HERE, "01-bear-shade-steps.png"), optimize=True); print("wrote 01", s.size)
    return report

# ============================================================
# shared: one shade row on a house Canvas
# ============================================================
def swatch(c, cx, cy, r, colour, state):
    """state: open | current | locked | focus-open | focus-locked | same"""
    if "focus" in state: c.ellipse((cx - r - 5, cy - r - 5, cx + r + 5, cy + r + 5), outline="#FFFFFF", width=1.8)
    if state == "current": c.ellipse((cx - r - 3.5, cy - r - 3.5, cx + r + 3.5, cy + r + 3.5), outline=K.ACCENT, width=2)
    fill = mix(colour, K.WELL, .78) if state == "same" else colour
    c.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill, outline=mix(fill, "#FFFFFF", .35), width=1)
    if "locked" in state:
        c.ellipse((cx + r * .2, cy + r * .15, cx + r * 1.2, cy + r * 1.15), fill=K.WELL, outline=mix(K.WELL, "#FFFFFF", .35))
        K.lock(c, cx + r * .7, cy + r * .7, r * .3, "#FFFFFF")
    if state == "current":
        c.ellipse((cx + r * .2, cy + r * .15, cx + r * 1.2, cy + r * 1.15), fill=K.ACCENT)
        c.line([(cx + r * .45, cy + r * .66), (cx + r * .64, cy + r * .84), (cx + r * .96, cy + r * .48)], K.INK, 1.5)
    if state == "same": c.line([(cx - r * .45, cy), (cx + r * .45, cy)], K.SOFT, 1.6)

def on_canvas(c, fn, *a):       # draw a pixel-space icon at Canvas scale
    fn(c.d, *[S(v) if isinstance(v, (int, float)) else v for v in a])

def shade_row(c, box, slot, base, at, focus, opened):
    """opened = (lighter steps open, darker steps open). Returns swatch centres by step."""
    x0, y0, x1, y1 = box; hi, lo = CAPS[slot]
    c.rr(box, 12, fill=K.WELL, outline=mix(K.WELL, "#FFFFFF", .14))
    cy = (y0 + y1) / 2 - 6
    steps = list(range(hi, -lo - 1, -1)); gap = 46
    cx0 = (x0 + x1) / 2 - gap * (len(steps) - 1) / 2
    on_canvas(c, sun, cx0 - 42, cy, 9, rgb("#FFD98A"))
    on_canvas(c, moon, cx0 + gap * (len(steps) - 1) + 42, cy, 9, rgb("#B9B6F2"), rgb(K.WELL))
    centres = {}
    for i, st in enumerate(steps):
        cx = cx0 + gap * i; centres[st] = cx
        is_open = (st <= opened[0]) if st > 0 else (-st <= opened[1])
        flat = st != 0 and same(shade(base, st), shade(base, st - 1 if st > 0 else st + 1))
        state = "same" if flat else "current" if st == at else "open" if is_open else "locked"
        if st == focus and st != at: state = "focus-" + ("open" if is_open else "locked")
        swatch(c, cx, cy, 13 if st else 14, shade(base, st), state)
        label = "Original" if st == 0 else str(abs(st))
        c.text((cx, y1 - 9), label, K.xbold(7.5), K.TEXT if st in (at, focus) else K.DIM, "mm")
    return centres

def bear_on(c, im, cx, base_y):
    layer = c.im.convert("RGBA"); layer.alpha_composite(im, (int(S(cx) - im.width / 2), int(S(base_y) - im.height)))
    c.im = layer.convert("RGB"); c.d = ImageDraw.Draw(c.im)

# ============================================================
# 2. Customize > Hue with the shade row
# ============================================================
def customize():
    c = K.Canvas(K.raw("wardrobe-pom-beanie.jpg").crop((0, 0, 1760, 813)), shade=.5, blur=1.5)
    box = (12, 8, 832, 382); K.panel(c, box)
    K.header(c, box, "COMPANIONS", "Customize", "172")
    main, sec = tint(WHITE, ROSE, DOSE[2]), tint(GREY, TIDE, DOSE[3])
    at, focus, opened = 1, 2, (1, 1)
    lx0, lx1 = 28, 520
    c.rr((lx0, 62, lx1, 90), 14, fill=K.WELL, outline=mix(K.WELL, "#FFFFFF", .14))
    tabs = ["Hue", "Charm", "Material"]; tw = (lx1 - lx0) / 3
    c.rr((lx0 + 2, 64, lx0 + tw - 2, 88), 12, fill=K.ACCENT)
    for i, t in enumerate(tabs): c.text((lx0 + tw * (i + .5), 76), t, K.black(10.5), K.INK if i == 0 else K.SOFT, "mm")
    c.rr((lx0, 96, lx1, 120), 12, fill=K.WELL, outline=mix(K.WELL, "#FFFFFF", .14))
    half = (lx1 - lx0) / 2
    c.rr((lx0 + 2, 98, lx0 + half - 2, 118), 10, fill=K.ACCENT)
    c.text((lx0 + half * .5, 108), "Main", K.black(10), K.INK, "mm"); c.text((lx0 + half * 1.5, 108), "Secondary", K.black(10), K.SOFT, "mm")
    # NEW: the shade row
    c.text((lx0 + 4, 133), "SHADE", K.xbold(8), K.PINK, "lm")
    K.pill(c, lx0 + 40, 125, "NEW", K.xbold(7), K.PINK, K.INK, padx=6, h=15)
    c.text((lx1 - 4, 133), "Tap a dot to try it on. The first step each way is free.", K.bold(8.5), K.DIM, "rm")
    shade_row(c, (lx0, 141, lx1, 199), "main", main, at, focus, opened)
    # jar cards
    jars = [("Rose jar", "2 of 5 · ×2", ROSE, 3), ("Tide jar", "0 of 5 · ×3", TIDE, 1), ("Citrus jar", "0 of 5 · ×1", CITRUS, 1), ("Iris jar", "0 of 5 · ×4", IRIS, 1)]
    cw, ch = (lx1 - lx0 - 8) / 2, 44
    for i, (name, sub, col, dose) in enumerate(jars):
        x0 = lx0 + (i % 2) * (cw + 8); y0 = 206 + (i // 2) * (ch + 5)
        c.card((x0, y0, x0 + cw, y0 + ch), 12)
        c.rr((x0 + 6, y0 + 6, x0 + 38, y0 + 38), 8, fill=col)
        bear_on(c, bear(shade(tint(WHITE, col, DOSE[dose]), at), sec, S(27)), x0 + 22, y0 + 36)
        c.text((x0 + 46, y0 + 9), name, K.black(10.5), K.TEXT); c.text((x0 + 46, y0 + 25), sub, K.bold(8.5), K.SOFT)
    y0 = 206 + 2 * (ch + 5)
    c.card((lx0, y0, lx0 + cw, y0 + ch), 12)
    c.rr((lx0 + 6, y0 + 6, lx0 + 38, y0 + 38), 8, fill="#F4F1EE"); bear_on(c, bear(WHITE, sec, S(27)), lx0 + 22, y0 + 36)
    c.text((lx0 + 46, y0 + 9), "Original colour", K.black(10.5), K.TEXT); c.text((lx0 + 46, y0 + 25), "Free · your shade steps stay open", K.bold(8.5), K.SOFT)
    x0 = lx0 + cw + 8
    c.card((x0, y0, x0 + cw, y0 + ch), 12, fill=mix(K.PANEL, K.RAISED, .5))
    on_canvas(c, drop, x0 + 17, y0 + 23, 8.5, "sun"); on_canvas(c, drop, x0 + 37, y0 + 23, 8.5, "moon")
    c.text((x0 + 54, y0 + 9), "Sun Drops ×2 · Moon Drops ×0", K.black(9.5), K.TEXT)
    c.text((x0 + 54, y0 + 25), "More hatch from Customization Eggs ›", K.bold(8.5), K.ACCENT)

    # preview pane
    px0, px1, py0, py1 = 530, 818, 62, 344
    c.card((px0, py0, px1, py1), 14, fill=mix(K.PANEL, K.RAISED, .6))
    c.rr((px0 + 10, py0 + 10, px1 - 10, py0 + 158), 10, fill=K.WELL, outline=mix(K.WELL, "#FFFFFF", .14))
    c.glow((px0 + px1) / 2, py0 + 92, 64, shade(main, focus), .2)
    bear_on(c, grounded(bear(shade(main, focus), sec, S(130)), (0, 0, 0, 130)), (px0 + px1) / 2, py0 + 157)
    K.pill(c, px0 + 18, py0 + 18, "TRY-ON", K.xbold(7.5), mix(K.WELL, "#000000", .1), K.SOFT, h=16, outline=mix(K.WELL, "#FFFFFF", .25))
    for i, (lab, col) in enumerate((("NOW", shade(main, at)), ("TRY", shade(main, focus)))):
        bx = px1 - 58 + i * 30
        c.ellipse((bx - 10, py0 + 18, bx + 10, py0 + 38), fill=col, outline=mix(col, "#FFFFFF", .4))
        c.text((bx, py0 + 46), lab, K.xbold(6.5), K.SOFT, "mm")
    c.text((px0 + 12, py0 + 164), "2 lighter", K.black(15), K.TEXT)
    K.pill(c, px1 - 12, py0 + 168, "LOCKED", K.xbold(7.5), K.WELL, K.SOFT, h=16, anchor="r", outline=mix(K.WELL, "#FFFFFF", .25))
    ry = py0 + 192
    c.rr((px0 + 10, ry, px1 - 10, ry + 38), 10, fill=K.WELL, outline=mix(K.WELL, "#FFD98A", .45))
    on_canvas(c, drop, px0 + 29, ry + 21, 10, "sun")
    c.text((px0 + 48, ry + 7), "Opens with 1 Sun Drop", K.black(10.5), K.TEXT)
    c.text((px0 + 48, ry + 23), "You have 2. Opened steps are yours to keep.", K.bold(8.5), K.SOFT)
    K.primary(c, (px0 + 10, ry + 46, px1 - 10, ry + 80), "Use 1 Sun Drop")
    x = 30
    x += K.hint(c, x, 354, "+", "Move"); x += K.hint(c, x, 354, "LB", "Colour"); x += K.hint(c, x, 354, "A", "Use", True)
    x += K.hint(c, x, 354, "Y", "Original shade"); x += K.hint(c, x, 354, "B", "Back")
    c.text((818, 362), "Trying is free. A drop opens a step for good.", K.bold(9), K.DIM, "rm")
    c.save("02-customize-shade-row-844x390@2x.png")

# ============================================================
# 3. Row states, the two drops, input map
# ============================================================
def states():
    c = K.Canvas(None)
    c.im.paste(rgb(K.PANEL), (0, 0, c.im.width, c.im.height))
    c.text((24, 14), "Shade row: states and input", K.black(16), K.TEXT)
    c.text((24, 40), "One row per colour. Each dot shows the real colour that step gives. Step 1 each way is open for everyone.", K.bold(9.5), K.SOFT)
    main, sec = tint(WHITE, ROSE, DOSE[2]), tint(GREY, TIDE, DOSE[3])
    rows = [
        ("Main, dyed. At Original shade, nothing opened yet.", "main", main, 0, None, (1, 1)),
        ("Main. Wearing 1 lighter, trying 2 lighter (locked).", "main", main, 1, 2, (1, 1)),
        ("Secondary, every step opened, wearing 2 darker.", "secondary", sec, -2, None, (3, 3)),
        ("Main, undyed white: lighter changes nothing, so those dots rest.", "main", WHITE, 0, None, (1, 1)),
    ]
    for i, (label, slot, base, at, focus, opened) in enumerate(rows):
        y = 58 + i * 73
        c.text((24, y + 7), label, K.bold(9), K.SOFT, "lm")
        shade_row(c, (24, y + 15, 440, y + 69), slot, base, at, focus, opened)
    lx = 462
    c.card((lx, 62, 820, 222), 14)
    c.text((lx + 14, 72), "What a dot can be", K.black(11), K.TEXT)
    legend = [("open", "Open: tap to wear it. Free."), ("current", "Wearing now: green ring and tick."), ("locked", "Locked: tap to try it on. A drop opens it."),
              ("focus-locked", "Focus ring: thumb, mouse or pad is here."), ("same", "Resting: this step changes nothing here.")]
    for i, (st, text) in enumerate(legend):
        y = 106 + i * 24; swatch(c, lx + 28, y, 8.5, main, st); c.text((lx + 52, y), text, K.bold(9.5), K.SOFT, "lm")
    c.card((lx, 230, 820, 300), 14)
    on_canvas(c, drop, lx + 34, 266, 16, "sun"); on_canvas(c, drop, lx + 212, 266, 16, "moon")
    c.text((lx + 60, 246), "Sun Drop", K.black(12), K.TEXT); c.text((lx + 60, 265), "Opens the next", K.bold(9), K.SOFT); c.text((lx + 60, 277), "lighter step.", K.bold(9), K.SOFT)
    c.text((lx + 238, 246), "Moon Drop", K.black(12), K.TEXT); c.text((lx + 238, 265), "Opens the next", K.bold(9), K.SOFT); c.text((lx + 238, 277), "darker step.", K.bold(9), K.SOFT)
    c.card((lx, 308, 820, 376), 14)
    c.text((lx + 14, 316), "Input", K.black(11), K.TEXT)
    for i, t in enumerate(["Phone: tap a dot (44 px targets). No dragging.", "PC: click, or arrow keys and Enter. Hover tries it on.", "Pad: D-pad left / right, A wear or use, Y Original shade."]):
        c.text((lx + 14, 339 + i * 12.5), t, K.bold(9), K.SOFT, "lm")
    c.text((24, 366), "Drop icons are drawn placeholders for layout. Final art joins the jar set.", K.bold(9), K.DIM, "lm")
    c.save("03-shade-row-states.png")

if __name__ == "__main__":
    rep = steps_sheet(); customize(); states()
    print("\nrow / step -> colour, S, V, contrast to face ink " + FACE_INK)
    for what, who, step, col, offered in rep:
        s_, v_ = hsv(col)
        print("%-22s %-34s %+d %s S%3d V%3d  c%.2f %s" % (what, who, step, col, s_ * 100, v_ * 100, contrast(col, FACE_INK), "" if offered else "(not offered)"))
