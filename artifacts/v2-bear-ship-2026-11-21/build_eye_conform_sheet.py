"""Lay the eye-conform frames out as one before/after sheet.  python build_eye_conform_sheet.py <frames dir>"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
F = sys.argv[1]; HERE = os.path.dirname(os.path.abspath(__file__))
ROWS = [("Bear, default cute eyes", "bear-default-front", "bear-default-threeq"),
        ("Bear, Sparkle Eyes", "bear-sparkle-front", "bear-sparkle-threeq"),
        ("Bunny, Sparkle Eyes (same meshes, Bunny anchors)", "bunny-sparkle-front", "bunny-sparkle-threeq")]
W, H, PAD, HEAD, LAB = 760, 600, 14, 84, 40
def font(size, bold=False):
    for n in (("segoeuib.ttf",) if bold else ()) + ("segoeui.ttf", "arial.ttf"):
        try: return ImageFont.truetype(n, size)
        except OSError: pass
    return ImageFont.load_default()
sheet = Image.new("RGB", (PAD + 4 * (W + PAD), HEAD + len(ROWS) * (H + LAB + PAD) + PAD), "#FBF8F4"); d = ImageDraw.Draw(sheet)
d.text((PAD, 14), "Eye pieces conformed to the v2 head", font=font(34, True), fill="#2B1A20")
d.text((PAD, 54), "Before: the shipped rigid move.  After: every piece re-seated on the head's curve, same outline from the front.", font=font(20), fill="#6A5A60")
for ri, (title, a, b) in enumerate(ROWS):
    y = HEAD + ri * (H + LAB + PAD)
    for ci, (stem, which) in enumerate(((a, "before"), (a, "after"), (b, "before"), (b, "after"))):
        x = PAD + ci * (W + PAD)
        sheet.paste(Image.open(os.path.join(F, "%s-%s.png" % (stem, which))).convert("RGB"), (x, y + LAB))
        view = "front" if stem.endswith("front") else "three-quarter"
        d.text((x + 4, y + 6), "%s, %s" % (title, view), font=font(19), fill="#2B1A20")
        tag = which.upper(); tw = d.textlength(tag, font=font(19, True))
        d.rounded_rectangle((x + W - tw - 26, y + LAB + 10, x + W - 10, y + LAB + 44), 8, fill="#C0504D" if which == "before" else "#3E8E5A")
        d.text((x + W - tw - 18, y + LAB + 13), tag, font=font(19, True), fill="white")
sheet.save(os.path.join(HERE, "eye-conform.png")); print(sheet.size)
