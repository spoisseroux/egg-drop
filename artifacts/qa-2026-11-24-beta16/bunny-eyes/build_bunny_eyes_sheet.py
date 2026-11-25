"""Lay the Bunny eye frames out as one before/after sheet.  python build_bunny_eyes_sheet.py <frames dir>"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
F = sys.argv[1]; HERE = os.path.dirname(os.path.abspath(__file__))
VIEWS = (("front", "front"), ("threeq-left", "three-quarter left"), ("threeq-right", "three-quarter right"))
ROWS = [("At rest", "rest"), ("Curious glance (the eyes look aside)", "curious")]
W, H, PAD, HEAD, LAB, S = 760, 560, 14, 96, 40, .5
w, h = int(W * S), int(H * S)
def font(size, bold=False):
    for n in (("segoeuib.ttf",) if bold else ()) + ("segoeui.ttf", "arial.ttf"):
        try: return ImageFont.truetype(n, size)
        except OSError: pass
    return ImageFont.load_default()
cols = 6
sheet = Image.new("RGB", (PAD + cols * (w + PAD), HEAD + len(ROWS) * (h + LAB + PAD) + (H + LAB + PAD) // 1), "#FBF8F4"); d = ImageDraw.Draw(sheet)
d.text((PAD, 12), "Bunny eyes and blush conformed to its head (beta 16 B4)", font=font(30, True), fill="#2B1A20")
d.text((PAD, 54), "Before: shipped meshes, straight glance slide.  After: conformed meshes, glance turns round the head.", font=font(19), fill="#6A5A60")
def tag(x, y, which):
    t = which.upper(); tw = d.textlength(t, font=font(15, True))
    d.rounded_rectangle((x + w - tw - 20, y + 6, x + w - 6, y + 30), 6, fill="#C0504D" if which == "before" else "#3E8E5A")
    d.text((x + w - tw - 13, y + 7), t, font=font(15, True), fill="white")
for ri, (title, stem) in enumerate(ROWS):
    y = HEAD + ri * (h + LAB + PAD)
    d.text((PAD, y + 8), title, font=font(19, True), fill="#2B1A20")
    for vi, (view, label) in enumerate(VIEWS):
        for wi, which in enumerate(("before", "after")):
            x = PAD + (vi * 2 + wi) * (w + PAD)
            im = Image.open(os.path.join(F, "bunny-%s-%s-%s.png" % (stem, view, which))).convert("RGB").resize((w, h), Image.LANCZOS)
            sheet.paste(im, (x, y + LAB)); tag(x, y + LAB, which)
            if wi == 0: d.text((x + w + PAD // 2 - d.textlength(label, font=font(16)) / 2, y + 12), label, font=font(16), fill="#6A5A60")
y = HEAD + len(ROWS) * (h + LAB + PAD)
d.text((PAD, y + 8), "Curious glance, close on the viewer-right eye (where Spencer saw it)", font=font(19, True), fill="#2B1A20")
for wi, which in enumerate(("before", "after")):
    x = PAD + wi * (W + PAD)
    sheet.paste(Image.open(os.path.join(F, "bunny-curious-eyeR-closeup-%s.png" % which)).convert("RGB"), (x, y + LAB))
    t = which.upper(); tw = d.textlength(t, font=font(19, True))
    d.rounded_rectangle((x + W - tw - 26, y + LAB + 10, x + W - 10, y + LAB + 44), 8, fill="#C0504D" if which == "before" else "#3E8E5A")
    d.text((x + W - tw - 18, y + LAB + 13), t, font=font(19, True), fill="white")
sheet.save(os.path.join(HERE, "bunny-eyes-before-after.png")); print(sheet.size)
