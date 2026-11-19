"""Sheets for the v2 pet redesign (2026-11-19). PIL only: lays out and labels the Blender renders in raw/
(made by build_bunny.py) and the old Kitten frames from artifacts/v2-pet-snacks-2026-11-19/raw. No generated art.

Run from the repo root:  python artifacts/v2-pet-redesign-2026-11-19/build_sheets.py
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OLD = os.path.join(HERE, "..", "v2-pet-snacks-2026-11-19", "raw")
F = "C:/Windows/Fonts/"
def black(s): return ImageFont.truetype(F + "Nunito-Black.ttf", s)
def bold(s): return ImageFont.truetype(F + "Nunito-Bold.ttf", s)
PAPER, CARD, INK, SOFT, LINE, GOOD, BAD = (241, 236, 230), (250, 247, 243), (38, 32, 36), (120, 110, 112), (214, 205, 196), (46, 140, 96), (196, 72, 72)
PPU = 350   # pixels per stud in every solo frame

def raw(name, folder=RAW): return Image.open(os.path.join(folder, name + ".png")).convert("RGBA")
def cut(im):
    return im.crop(im.getbbox())
def grounded(im, blur=9):
    """Crop to the pet and put a soft drawn contact shadow under it (the renders have a transparent film)."""
    im = cut(im); w, h = im.size; pad = 40
    out = Image.new("RGBA", (w + pad * 2, h + pad), (0, 0, 0, 0)); d = ImageDraw.Draw(out)
    d.ellipse((pad + w * .12, h - 8, pad + w * .88, h + 26), fill=(60, 40, 40, 70))
    out = out.filter(ImageFilter.GaussianBlur(blur)); out.alpha_composite(im, (pad, 0)); return out
def sheet(w, h):
    s = Image.new("RGBA", (w, h), PAPER + (255,)); return s, ImageDraw.Draw(s)
def title(d, x, y, big, small):
    d.text((x, y), big, font=black(44), fill=INK); d.text((x, y + 58), small, font=bold(24), fill=SOFT)
def card(d, box): d.rounded_rectangle(box, 28, fill=CARD, outline=LINE, width=2)
def place(s, im, cx, base_y): s.alpha_composite(im, (int(cx - im.width / 2), int(base_y - im.height)))
def lines(d, x, y, rows, font=None, gap=34, fill=SOFT):
    for i, t in enumerate(rows): d.text((x, y + i * gap), t, font=font or bold(22), fill=fill)

VIEWS = [("front", "FRONT"), ("threeq", "THREE-QUARTER"), ("side", "SIDE"), ("back", "BACK")]

def turnaround():
    W, H = 2400, 2230; s, d = sheet(W, H)
    title(d, 60, 40, "Bunny blockout next to the Bear", "Same body, hands, feet and head size as the Bear. Both start white and grey. New: long round ears (one flopped), sparkle eyes, blush, snout pad, pink nose, cotton tail.")
    for i, (name, label) in enumerate(VIEWS):
        x, y = 40 + (i % 2) * 1170, 150 + (i // 2) * 740
        card(d, (x, y, x + 1150, y + 720))
        im = raw("turn-" + name); base = Image.new("RGBA", im.size, (0, 0, 0, 0)); bd = ImageDraw.Draw(base)
        for cx in (460, 1140): bd.ellipse((cx - 150, 868, cx + 150, 912), fill=(60, 40, 40, 70))
        base = base.filter(ImageFilter.GaussianBlur(10)); base.alpha_composite(im)
        s.alpha_composite(base.resize((1150, 719), Image.LANCZOS), (x, y)); d.text((x + 24, y + 18), label, font=black(24), fill=SOFT)
    y0 = 1660
    d.text((60, y0), "Silhouette test at phone size (Bear = 96 px tall)", font=black(30), fill=INK)
    d.text((60, y0 + 40), "No colour, no face. The ears alone must tell the two apart from every side.", font=bold(22), fill=SOFT)
    x = 70; k = 96 / (1.479 * PPU)
    for name, label in VIEWS:
        for tag in ("bear", "bunny"):
            im = cut(raw("solo-%s-%s" % (tag, name))); im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            sil = Image.new("RGBA", im.size, INK + (255,)); sil.putalpha(im.getchannel("A")); place(s, sil, x + 60, y0 + 232); x += 135
        d.text((x - 270 + 135 - d.textlength(label, font=bold(18)) / 2 - 8, y0 + 244), label, font=bold(18), fill=SOFT); x += 30
    d.text((60, y0 + 300), "Hat test", font=black(30), fill=INK)
    lines(d, 60, y0 + 342, ["Ears sit on the EarL/R swap anchors, 13 degrees out.", "With a hat on they tip to 40 degrees, so a Bear-sized", "cap sits on the Bear's HatCrown anchor, unchanged."])
    hat = cut(raw("hat-fit")); hat = hat.resize((round(hat.width * .36), round(hat.height * .36)), Image.LANCZOS); place(s, hat, 820, H - 40)
    px = 1340
    d.text((px, y0), "Starting colours: white and grey, like the Bear", font=black(30), fill=INK)
    for i, (hexc, name, use) in enumerate((("#FFFFFF", "Primary  #FFFFFF", "head, ears, upper body. Undyed; players dye it with Hue jars"), ("#A8A5AE", "Secondary  #A8A5AE", "socks, belly, ear insides, snout pad, tail, charms"),
                                           ("#F58CA5", "Nose  #F58CA5   Blush  #FFB0BC", "fixed, like the eyes and mouth; both read on white"), ("#2B1A20", "Eye  #2B1A20 + two white catchlights", "no white ring; warm near-black, never pure black"))):
        yy = y0 + 62 + i * 78
        d.rounded_rectangle((px, yy, px + 64, yy + 64), 16, fill=hexc, outline=LINE, width=2)
        d.text((px + 84, yy + 4), name, font=black(24), fill=INK); d.text((px + 84, yy + 36), use, font=bold(20), fill=SOFT)
    d.text((px, y0 + 384), "Dyed example: \"Peach Milk\"", font=black(24), fill=INK)
    lines(d, px, y0 + 420, ["#FFC6B8 over #FFF6EC.", "One Hue jar away;", "no longer the start."], bold(20), 28)
    for i, name in enumerate(("front", "threeq")):
        im = cut(raw("solo-bunny-peach-" + name)); im = im.resize((round(im.width * .26), round(im.height * .26)), Image.LANCZOS); place(s, im, px + 400 + i * 190, H - 30)
    lines(d, px + 690, y0 + 384, ["Blockout only: 5,600 triangles.", "Production target: 3,000 or fewer.", "Original geometry built in Blender", "by script (build_bunny.py).", "No generated or imported models."], bold(20), 28)
    s.convert("RGB").save(os.path.join(HERE, "01-bunny-turnaround.png"))

def before_after():
    W, H = 2400, 1500; s, d = sheet(W, H)
    title(d, 60, 40, "Before and after: the Kitten and the Bunny", "Same view, same scale, same shared Bear body. The Kitten frames are the 2026-11-19 originals.")
    for i, (label, col, tag, folder, notes) in enumerate((
        ("BEFORE: Kitten blockout", BAD, "kitten", OLD, ["Pointed cone ears, four cheek spikes, a thin kinked tail: 7 sharp points", "White eye ring on orange: a startled stare", "Orange at 58% saturation", "Faceted highlights on a low-poly head", "Eye line above the middle of the head"]),
        ("AFTER: Bunny blockout", GOOD, "bunny", RAW, ["Every tip is a round cap: 0 sharp points", "Dark eyes with two catchlights, no ring", "Starts white and grey like the Bear; dyes are pastels", "Head and body smoothed one level", "Eye line 41% up the head, blush under the eyes"]))):
        x = 40 + i * 1170; card(d, (x, 150, x + 1150, 1450))
        d.text((x + 28, 172), label, font=black(30), fill=col)
        a, b = grounded(raw("solo-%s-front" % tag, folder)), grounded(raw("solo-%s-threeq" % tag, folder))
        place(s, a, x + 310, 1010); place(s, b, x + 850, 1010)
        d.text((x + 270, 1030), "FRONT", font=black(20), fill=SOFT); d.text((x + 760, 1030), "THREE-QUARTER", font=black(20), fill=SOFT)
        for j, t in enumerate(notes):
            d.ellipse((x + 40, 1100 + j * 62 + 9, x + 56, 1100 + j * 62 + 25), fill=col); d.text((x + 72, 1100 + j * 62), t, font=bold(26), fill=INK)
    s.convert("RGB").save(os.path.join(HERE, "02-before-after-kitten-vs-bunny.png"))

def face_rules():
    W, H = 2000, 1400; s, d = sheet(W, H)
    title(d, 60, 40, "The face, measured", "Front view of the Bunny's head with the CUTE-DESIGN-RULES numbers drawn on it.")
    card(d, (40, 150, 1240, 1350)); im = raw("face-bunny-front"); s.alpha_composite(im, (40, 150))
    def px(X): return 40 + 600 + X * 800
    def py(Z): return 150 + 600 - (Z - 1.12) * 800
    guide = (90, 120, 200)
    for z, label in ((1.39, "crown"), (1.01, "middle"), (.945, "eye line, 41%"), (.63, "chin")):
        y = py(z); dash = z in (1.01,)
        for x0 in range(int(px(-.66)), int(px(.52)), 22 if dash else 1): d.line((x0, y, x0 + (10 if dash else 1), y), fill=guide, width=3)
        d.text((px(.52) + 12, y - 16), label, font=bold(22), fill=guide)
    for X in (-.232, .232): d.line((px(X), py(.945) - 120, px(X), py(.945) + 120), fill=guide, width=3)
    d.line((px(-.232), py(.945) + 112, px(.232), py(.945) + 112), fill=guide, width=3)
    d.text((px(0) - 96, py(.945) + 120), "47% of head width", font=bold(20), fill=guide)
    x = 1290
    d.text((x, 170), "What the numbers are", font=black(32), fill=INK)
    rows = [("Head", "55% of the height to the crown; 1.6x body width"), ("Eye width", "16% of head width (rule: 14 to 18%)"), ("Eye line", "41% up the head (rule: 38 to 46%)"),
            ("Eye spacing", "centres 47% of head width apart"), ("Gap", "1.9 eye widths between the eyes"), ("Nose", "6% of head width, just under the eye line"),
            ("Mouth", "8.5% of head width, right under the nose"), ("Face cluster", "all features in the lower 55%; the top 45% is forehead"), ("Blush", "two soft ovals, outside and below each eye"),
            ("Catchlights", "two per eye, same side on both, 19% and 8.5%"), ("Points", "none: every end is a round cap")]
    for i, (a, b) in enumerate(rows):
        d.text((x, 240 + i * 84), a, font=black(26), fill=INK); d.text((x, 274 + i * 84), b, font=bold(22), fill=SOFT)
    s.convert("RGB").save(os.path.join(HERE, "03-bunny-face-measured.png"))

def bear_tweaks():
    W, H = 2400, 1260; s, d = sheet(W, H)
    title(d, 60, 40, "Bear tweaks (a study, not a change)", "The live Bear, dyed, next to a copy with four small edits. Nothing in the game or in pet-bear.blend was edited.")
    for i, (label, col, tag) in enumerate((("LIVE BEAR", SOFT, "live"), ("TWEAKED COPY", GOOD, "tweak"))):
        x = 40 + i * 1170; card(d, (x, 150, x + 1150, 1000)); d.text((x + 28, 172), label, font=black(30), fill=col)
        place(s, grounded(raw("bear-%s-front" % tag)), x + 310, 950); place(s, grounded(raw("bear-%s-threeq" % tag)), x + 850, 950)
    lines(d, 60, 1030, ["1. Eyes: drop the white ring, add two catchlights. The ring vanishes on a white Bear but turns into a stare on any dyed Bear.",
                        "2. Eye line: 0.055 studs lower (from 52% up the head to 45%). A bigger forehead reads younger.",
                        "3. Muzzle, nose and mouth: 16% smaller and a touch lower (muzzle from 33% of head width to 28%).",
                        "4. Smooth the head and body one level, and add blush. Hats, anchors and the body are untouched.",
                        "Cost: a new eye texture, a blush decal, a head re-export. Risk: every owner's Bear changes face, so this needs Spencer's yes."], bold(26), 42, INK)
    s.convert("RGB").save(os.path.join(HERE, "04-bear-tweaks.png"))

for f in (turnaround, before_after, face_rules, bear_tweaks): f()
print("sheets written")
