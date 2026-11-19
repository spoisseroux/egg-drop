"""Art-study sheets for the v2 pet + snacks scope (2026-11-19). PIL only: lays out and labels
the Blender blockout renders in raw/ (made by build_blockout.py). No generated art.

Run from the repo root:  python artifacts/v2-pet-snacks-2026-11-19/build_sheets.py
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
F = "C:/Windows/Fonts/"
def black(s): return ImageFont.truetype(F + "Nunito-Black.ttf", s)
def bold(s): return ImageFont.truetype(F + "Nunito-Bold.ttf", s)
PAPER, INK, SOFT, LINE = (241, 236, 230), (38, 32, 36), (120, 110, 112), (214, 205, 196)
STATS = [("Heart", "#FF86A8"), ("Power", "#FF9D4D"), ("Energy", "#6CCBFF"), ("Jump", "#B9EE5A"), ("Speed", "#8FA8FF"), ("Smarts", "#E58CFF")]

def raw(name): return Image.open(os.path.join(RAW, name + ".png")).convert("RGBA")
def shadowed(im, feet_y, spots):
    """Soft contact shadows (drawn; the renders have a transparent film)."""
    base = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(base)
    for cx, w in spots: d.ellipse((cx - w, feet_y - w * .16, cx + w, feet_y + w * .16), fill=(60, 40, 40, 70))
    base = base.filter(ImageFilter.GaussianBlur(10)); base.alpha_composite(im); return base
def title(d, x, y, big, small):
    d.text((x, y), big, font=black(44), fill=INK); d.text((x, y + 56), small, font=bold(24), fill=SOFT)

def turnaround():
    W, H = 2400, 2150
    sheet = Image.new("RGBA", (W, H), PAPER + (255,)); d = ImageDraw.Draw(sheet)
    title(d, 60, 40, "Kitten blockout next to the Bear", "Same body, hands, feet and eyes as the Bear. New: head shape, pointed ears, cheek fluff, whisker pads, pink nose, long tail with a dipped tip.")
    views = [("front", "FRONT"), ("threeq", "THREE-QUARTER"), ("side", "SIDE"), ("back", "BACK")]
    for i, (name, label) in enumerate(views):
        im = shadowed(raw("turn-" + name), 838, [(407, 150), (1093, 150)]).resize((1150, 690), Image.LANCZOS)
        x, y = 40 + (i % 2) * 1170, 150 + (i // 2) * 720
        d.rounded_rectangle((x, y, x + 1150, y + 700), 28, fill=(250, 247, 243), outline=LINE, width=2)
        sheet.alpha_composite(im, (x, y + 4)); d.text((x + 24, y + 18), label, font=black(24), fill=SOFT)
    # phone-size silhouettes: each pet 96 px tall, the size it is across the lawn on a phone
    y0 = 1610
    d.text((60, y0), "Silhouette test at phone size (96 px tall)", font=black(30), fill=INK)
    d.text((60, y0 + 40), "The ears, cheek fluff and tail have to tell the two apart with no colour and no face.", font=bold(22), fill=SOFT)
    x = 70
    for name, label in views:
        for tag in ("bear", "kitten"):
            im = raw("solo-%s-%s" % (tag, name)); box = im.getbbox(); im = im.crop(box)
            k = 96 / (im.height if tag == "bear" else im.height * 1.479 / 1.608)   # one scale for both pets
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            sil = Image.new("RGBA", im.size, INK + (255,)); sil.putalpha(im.getchannel("A"))
            sheet.alpha_composite(sil, (x + 60 - im.width // 2, y0 + 210 - im.height))
            x += 135
        d.text((x - 270 + 135 - d.textlength(label, font=bold(18)) / 2 - 8, y0 + 222), label, font=bold(18), fill=SOFT)
        x += 30
    # palette
    px = 1340
    d.text((px, y0), "Starting colours: \"Marmalade\"", font=black(30), fill=INK)
    for i, (hexc, name, use) in enumerate((("#FFB86B", "Primary  #FFB86B", "body, head, ears, tail"), ("#FFF2DD", "Secondary  #FFF2DD", "socks, belly, ear insides, whisker pads, tail tip, charms"), ("#E8879A", "Nose  #E8879A", "fixed, like the eyes and mouth"))):
        yy = y0 + 62 + i * 78
        d.rounded_rectangle((px, yy, px + 64, yy + 64), 16, fill=hexc, outline=LINE, width=2)
        d.text((px + 84, yy + 4), name, font=black(24), fill=INK); d.text((px + 84, yy + 36), use, font=bold(20), fill=SOFT)
    d.text((px, y0 + 310), "Both colours can still be dyed with Hue jars, like the Bear's.", font=bold(20), fill=SOFT)
    d.text((60, H - 150), "Blockout only. 2,032 triangles as built (1,302 for the Bear); the production model is one sculpted fluff piece a side and comes in under 1,800.", font=bold(22), fill=SOFT)
    d.text((60, H - 116), "Honest notes: the cheek fluff is lumpy and needs a real sculpt; the white eye ring reads bigger on a coloured body; the tail must clear the Back slot (capes).", font=bold(22), fill=SOFT)
    d.text((60, H - 70), "Original geometry built in Blender by script (build_blockout.py). No generated or imported models.", font=bold(20), fill=SOFT)
    sheet.convert("RGB").save(os.path.join(HERE, "01-kitten-turnaround.png"), optimize=True); print("wrote 01")

def snacks():
    grid = raw("snack-grid"); feed = shadowed(raw("feed-scale"), 838, [(407, 150), (1093, 150)])
    LM, TOP = 400, 250
    W, H = LM + 1800 + 40, TOP + 1000 + 760
    sheet = Image.new("RGBA", (W, H), PAPER + (255,)); d = ImageDraw.Draw(sheet)
    title(d, 60, 40, "Stat Snacks: one biscuit, six marks, three sizes", "Count the layers for the size. Read the mark for the stat. The colour only helps; nothing depends on it.")
    d.rounded_rectangle((LM - 10, TOP - 80, W - 30, TOP + 990), 28, fill=(250, 247, 243), outline=LINE, width=2)
    sheet.alpha_composite(grid, (LM, TOP))
    for c, (name, col) in enumerate(STATS):
        cx = LM + 900 + (c - 2.5) * 276
        w = d.textlength(name, font=black(30))
        d.rounded_rectangle((cx - w / 2 - 34, TOP - 64, cx + w / 2 + 16, TOP - 16), 24, fill=col)
        d.text((cx - w / 2 - 8, TOP - 62), name, font=black(30), fill=(14, 15, 18))
    rows = [("NIBBLE", "1 layer · 0.20 studs", "2x for your next 50 XP"), ("SNACK", "2 layers · 0.25 studs", "2x for your next 120 XP"), ("FEAST", "3 layers + sugar pearls · 0.30", "3x for your next 120 XP")]
    for r, (name, look, does) in enumerate(rows):
        cy = TOP + 500 - (1 - r) * 303
        d.text((60, cy - 50), name, font=black(40), fill=INK); d.text((60, cy), look, font=bold(22), fill=SOFT); d.text((60, cy + 30), does, font=bold(22), fill=SOFT)
    y = TOP + 1030
    d.text((60, y), "Size next to the pets", font=black(30), fill=INK)
    for i, line in enumerate(("A Feast is under a third of a head wide,", "so a held snack never hides the face.", "", "Offered at the cheek, turned to show its", "mark, then it goes to the mouth and", "shrinks with each bite: 2, 3 or 4 bites.", "", "Bear: Heart Feast. Kitten: Jump Snack.")):
        d.text((60, y + 50 + i * 32), line, font=bold(22), fill=SOFT)
    fim = feed.resize((1250, 750), Image.LANCZOS).crop((0, 40, 1250, 700))
    d.rounded_rectangle((640, y, 640 + 1250, y + 660), 28, fill=(250, 247, 243), outline=LINE, width=2)
    sheet.alpha_composite(fim, (640, y))
    d.text((60, H - 46), "Blockout only, built by script (build_blockout.py). Production budget: Nibble 150, Snack 250, Feast 400 triangles; one shared biscuit texture.", font=bold(20), fill=SOFT)
    sheet.convert("RGB").save(os.path.join(HERE, "02-stat-snacks.png"), optimize=True); print("wrote 02")

if __name__ == "__main__":
    turnaround(); snacks()
