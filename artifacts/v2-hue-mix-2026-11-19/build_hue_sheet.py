"""Hue mixing contact sheet (2026-11-19, Spencer: "what does it look like when hues are mixed?").
Uses the game's own maths, ported from src/shared/HueCatalog.lua (resolveTarget, DoseWeights) and
PetPalette.tint, painted on three render passes of the live Bear (see ../v2-shade-tweaker-2026-11-19).
Also compares the second colour mixed from grey (today) with mixed from white (proposal).
Run from the repo root: python artifacts/v2-hue-mix-2026-11-19/build_hue_sheet.py"""
import importlib.util, os, itertools
import numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("shade", os.path.join(HERE, "..", "v2-shade-tweaker-2026-11-19", "build_mockups.py"))
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
lin, srgb, vec, hexa, tint, bear, grounded = M.lin, M.srgb, M.vec, M.hexa, M.tint, M.bear, M.grounded
WHITE, GREY, DOSE = M.WHITE, M.GREY, M.DOSE
ORDER = ["rose", "tide", "citrus", "iris"]
NAMES = {"rose": "Rose", "tide": "Tide", "citrus": "Citrus", "iris": "Iris"}
ANCHOR = {"rose": "#FF327A", "tide": "#008DFF", "citrus": "#FFCC00", "iris": "#9350FF",
          "rose:tide": "#AC4BFA", "citrus:rose": "#FF733A", "iris:rose": "#E333BE", "citrus:tide": "#00BE77",
          "iris:tide": "#5859F1", "citrus:iris": "#EE6997", "citrus:rose:tide": "#F45688", "iris:rose:tide": "#A64FFF",
          "citrus:iris:rose": "#F059A5", "citrus:iris:tide": "#35A9CD", "citrus:iris:rose:tide": "#C963D9"}
def target(counts):                      # Hue.resolveTarget
    acc, total = np.zeros(3), 0
    for level in range(1, 6):
        ids = sorted(h for h in ORDER if counts.get(h, 0) >= level)
        if ids:
            acc += lin(vec(ANCHOR[":".join(ids)])) * len(ids); total += len(ids)
    return None if total == 0 else hexa(srgb(acc / total))
def colour(base, counts):                # PetPalette.resolve, one channel
    t = target(counts)
    return base if t is None else tint(base, t, DOSE[max(counts.values())])

F = "C:/Windows/Fonts/"
def font(name, s):
    for n in (name, "segoeuib.ttf", "arialbd.ttf"):
        try: return ImageFont.truetype(F + n, s)
        except OSError: pass
    return ImageFont.load_default()
TITLE, HEAD, LAB, SMALL = font("segoeuib.ttf", 44), font("segoeuib.ttf", 28), font("segoeuib.ttf", 18), font("segoeui.ttf", 16)
BH, CW = 170, 150                        # bear height, cell width
INK, SOFT, BG, CARD = (36, 28, 32), (110, 100, 104), (242, 238, 234), (250, 248, 245)

def cell(main, sec, top, sub):
    im = grounded(bear(main, sec, BH))
    c = Image.new("RGBA", (CW, BH + 70), CARD + (255,))
    c.alpha_composite(im, ((CW - im.width) // 2, 4))
    d = ImageDraw.Draw(c)
    f = LAB
    for size in (18, 16, 14, 12):
        f = font("segoeuib.ttf", size)
        if d.textlength(top, font=f) <= CW - 8: break
    d.text((CW // 2, BH + 26), top, font=f, fill=INK, anchor="mm")
    d.text((CW // 2, BH + 50), sub, font=SMALL, fill=SOFT, anchor="mm")
    return c

def block(title, note, cells, cols):
    rows = (len(cells) + cols - 1) // cols
    w = cols * (CW + 10) + 30; h = 90 + rows * (BH + 80)
    b = Image.new("RGBA", (w, h), BG + (255,)); d = ImageDraw.Draw(b)
    d.text((16, 14), title, font=HEAD, fill=INK); d.text((16, 52), note, font=SMALL, fill=SOFT)
    for i, c in enumerate(cells):
        b.alpha_composite(c, (16 + (i % cols) * (CW + 10), 84 + (i // cols) * (BH + 80)))
    return b

blocks = []
doses = [1, 2, 3, 5]
# 1. second colour: today (from grey) vs proposal (from white)
for label, base, note in (("Second colour TODAY: jars mix from the grey", GREY, "Body undyed. Few jars give dusty, greyish colours; only 5 jars reach the full colour."),
                          ("Second colour PROPOSED: jars mix from white (grey only when undyed)", WHITE, "Same jars. Clean pastels at 1 jar, full colour at 5, like the body already works.")):
    cells = [cell(WHITE, colour(base, {h: n}), NAMES[h], "%d jar%s" % (n, "" if n == 1 else "s")) for h in ORDER for n in doses]
    blocks.append(block(label, note, cells, 16))
# 2. body, one jar kind
cells = [cell(colour(WHITE, {h: n}), GREY, NAMES[h], "%d jar%s" % (n, "" if n == 1 else "s")) for h in ORDER for n in (1, 3, 5)]
blocks.append(block("Body colour: one kind of jar", "Second colour left grey. The body always mixes from white.", cells, 12))
# 3. body, mixes of two, three, four kinds
cells = []
for k in (2, 3, 4):
    for combo in itertools.combinations(ORDER, k):
        for n in ((2, 5) if k == 2 else (3,)):
            cells.append(cell(colour(WHITE, {h: n for h in combo}), GREY, " + ".join(NAMES[h] for h in combo) if k < 4 else "All four", "%d each" % n))
blocks.append(block("Body colour: jars mixed", "Two kinds at 2 and 5 jars each; three and four kinds at 3 each. Uneven amounts lean toward the bigger pile.", cells, 12))
# 4. uneven mixes
cells = [cell(colour(WHITE, c), GREY, " + ".join("%s %d" % (NAMES[h], n) for h, n in c.items()), "") for c in
         ({"rose": 5, "tide": 1}, {"rose": 3, "tide": 3}, {"rose": 1, "tide": 5}, {"citrus": 5, "iris": 1}, {"citrus": 3, "iris": 3}, {"citrus": 1, "iris": 5},
          {"rose": 5, "citrus": 2}, {"tide": 5, "citrus": 2}, {"iris": 4, "rose": 2}, {"tide": 2, "iris": 4}, {"rose": 1, "citrus": 1}, {"tide": 1, "iris": 1})]
blocks.append(block("Body colour: uneven mixes", "The bigger pile wins; 1 + 1 stays very light.", cells, 12))
# 5. both colours, proposal
pairs = [({"rose": 2}, {"tide": 3}), ({"citrus": 3}, {"iris": 3}), ({"tide": 2}, {"citrus": 5}), ({"iris": 2}, {"rose": 3}),
         ({"rose": 2, "citrus": 2}, {"tide": 2}), ({"tide": 2, "iris": 2}, {"citrus": 2}), ({"rose": 1}, {"rose": 5}), ({"tide": 1}, {"tide": 5})]
cells = []
for main, sec in pairs:
    for base, tag in ((GREY, "today"), (WHITE, "proposed")):
        cells.append(cell(colour(WHITE, main), colour(base, sec), "+".join(NAMES[h][0] + str(n) for h, n in main.items()) + " / " + "+".join(NAMES[h][0] + str(n) for h, n in sec.items()), tag))
blocks.append(block("Both colours dyed: today vs proposed", "Body / second colour (R Rose, T Tide, C Citrus, I Iris; number = jars). Each pair: today, then mixed from white.", cells, 16))

W = max(b.width for b in blocks) + 40
H = 110 + sum(b.height + 24 for b in blocks)
sheet = Image.new("RGBA", (W, H), BG + (255,)); d = ImageDraw.Draw(sheet)
d.text((24, 22), "Hue jars on the Bear: how colours mix", font=TITLE, fill=INK)
d.text((24, 78), "The game's own maths (HueCatalog.resolveTarget, DoseWeights, PetPalette.tint) on render passes of the live Bear. No generated art.", font=SMALL, fill=SOFT)
y = 110
for b in blocks:
    sheet.alpha_composite(b, (20, y)); y += b.height + 24
out = os.path.join(HERE, "hue-mix-contact-sheet.png")
sheet.convert("RGB").save(out, optimize=True); print("wrote", out, sheet.size)
