"""Scope-only annotated care editor. Pillow primitives; no game/runtime/asset import."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(__file__).resolve().parent
S = 2
W, H = 1600, 1000
INK = "#073B42"
MUTED = "#4E6970"
CYAN = "#13BCD3"
COBALT = "#245CCB"
CREAM = "#FFFDED"
LINE = "#A8CED1"
WEIGHTS = [.44, .65, .84, .93, 1]
HUES = {"Rose": "#FF327A", "Tide": "#008DFF", "Citrus": "#FFCC00", "Iris": "#9350FF", "Garnet": "#8C1835", "Ink": "#17171B"}


def rgb(value):
    if isinstance(value, tuple):
        return value
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def srgb(c):
    return c * 12.92 if c <= .0031308 else 1.055 * c ** (1 / 2.4) - .055


def swatch(hex_color, weight):
    return tuple(round(255 * srgb(1 - weight + linear(c / 255) * weight)) for c in rgb(hex_color))


def hexc(c):
    return "#" + "".join(f"{v:02X}" for v in c)


im = Image.new("RGB", (W * S, H * S), "white")
d = ImageDraw.Draw(im)
for y in range(H * S):
    t = y / (H * S)
    d.line((0, y, W * S, y), fill=(round(227 + 14 * t), round(247 + 2 * t), round(248 - 13 * t)))


def font(size, bold=False):
    return ImageFont.truetype("C:/Windows/Fonts/seguisb.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf", round(size * S))


def box(x, y, w, h, fill, radius=14, outline=None, width=1):
    d.rounded_rectangle((round(x * S), round(y * S), round((x + w) * S), round((y + h) * S)), radius=radius * S, fill=fill, outline=outline, width=width * S)


def text(x, y, value, size=16, color=INK, bold=False, anchor=None):
    d.text((round(x * S), round(y * S)), value, font=font(size, bold), fill=color, anchor=anchor)


def wrap(x, y, value, width, size=15, color=MUTED, bold=False, leading=5):
    words = value.split()
    rows, line = [], ""
    for word in words:
        probe = line + (" " if line else "") + word
        if d.textlength(probe, font=font(size, bold)) > width * S and line:
            rows.append(line)
            line = word
        else:
            line = probe
    if line:
        rows.append(line)
    for i, row in enumerate(rows):
        text(x, y + i * (size + leading), row, size, color, bold)
    return len(rows) * (size + leading)


def ellipse(x, y, w, h, fill, outline=None, width=1):
    d.ellipse((x * S, y * S, (x + w) * S, (y + h) * S), fill=fill, outline=outline, width=width * S)


def line(points, color, width=2):
    d.line([(round(x * S), round(y * S)) for x, y in points], fill=color, width=width * S, joint="curve")


def number(x, y, n):
    ellipse(x - 12, y - 12, 24, 24, INK)
    text(x, y - 1, str(n), 13, "white", True, "mm")


def button(x, y, w, value, active=False, primary=False):
    fill = COBALT if primary else CYAN if active else "#F5FFFF"
    box(x, y, w, 44, fill, 12, COBALT if primary else "#71BEC8", 1)
    if active or primary:
        line([(x + 12, y + 5), (x + w - 12, y + 5)], "#BEEEF5", 2)
    text(x + w / 2, y + 21, value, 17, "white" if primary else INK, True, "mm")


def jar(x, y, color, scale=1):
    box(x, y + 5 * scale, 25 * scale, 28 * scale, "#E2F9F8", 5 * scale, "#649DA7")
    box(x + 4 * scale, y + 14 * scale, 17 * scale, 15 * scale, color, 5 * scale)
    box(x - scale, y, 27 * scale, 7 * scale, "#A3D8DC", 3 * scale, "#6AABB6")
    line([(x + 4 * scale, y + 10 * scale), (x + 4 * scale, y + 22 * scale)], "white", 2)


# One outer sheet and a separate annotation rail; no simulated controls behind notes.
shadow = Image.new("RGBA", im.size)
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((24 * S, 96 * S, 1252 * S, 976 * S), radius=25 * S, fill=(10, 77, 89, 35))
shadow = shadow.filter(ImageFilter.GaussianBlur(12 * S))
im = Image.alpha_composite(im.convert("RGBA"), shadow).convert("RGB")
d = ImageDraw.Draw(im)

box(24, 18, 1552, 56, "#063D48", 15)
text(44, 31, "PREVIEW CONCEPT — NOT IN GAME", 23, "white", True)
text(1548, 46, "Scope only · proposed six-color machine editor", 16, "#BFF4F5", False, "rm")

box(24, 90, 1228, 880, CREAM, 22, "#A1CCD0", 2)
box(25, 91, 1226, 80, "#D8F7F7", 21)
line([(49, 96), (1225, 96)], "white", 3)
box(44, 106, 183, 50, "#FFFFFF", 13, "#9ACFD4")
ellipse(56, 117, 26, 26, "#FFD54B", "#D4A532")
star=[]
for i in range(10):
    angle=-math.pi/2+i*math.pi/5
    radius=9 if i%2==0 else 4
    star.append(((69+math.cos(angle)*radius)*S,(130+math.sin(angle)*radius)*S))
d.polygon(star,fill="#7B5A08")
text(92, 116, "24 Stars", 23, INK, True)
text(244, 108, "Zivvi", 27, INK, True)
button(342, 109, 150, "Change pet")
text(526, 122, "Garden care machine", 20, MUTED)
line([(1191, 119), (1209, 137)], INK, 3)
line([(1209, 119), (1191, 137)], INK, 3)


tabs = ["Hue", "Charm", "Finish", "Features", "Training"]
for i, name in enumerate(tabs):
    x = 44 + i * 236
    button(x, 184, 222, name, active=i == 0)
    if i == 0:
        line([(x + 69, 224), (x + 153, 224)], INK, 3)

box(44, 248, 342, 468, "#E2F6F4", 18, "#BAD8D8")
text(65, 264, "Saved portrait", 21, INK, True)
text(65, 295, "Main: 0 doses · Secondary: untreated", 14, MUTED)
number(356, 275, 1)
ellipse(73, 355, 284, 254, "#C5ECEA")
ellipse(111, 588, 216, 23, "#99C8C6")

# Original simple baby placeholder, not an imported or production pet asset.
ellipse(182, 322, 40, 40, "#C8C8C8", "#9BAAAF", 2)
ellipse(187, 326, 17, 8, "#E6EBED")
ellipse(170, 554, 59, 39, "#C8C8C8", "#9CAFB3", 2)
ellipse(227, 554, 58, 39, "#C8C8C8", "#9CAFB3", 2)
ellipse(167, 473, 101, 109, "#FFFFFF", "#ABC6C9", 2)
ellipse(128, 492, 57, 51, "#C8C8C8", "#9CAFB3", 2)
ellipse(254, 491, 53, 52, "#C8C8C8", "#9CAFB3", 2)
ellipse(111, 368, 210, 155, "#FFFFFF", "#A4C3C6", 2)
ellipse(137, 365, 55, 32, "#FFFFFF")
ellipse(260, 367, 40, 29, "#FFFFFF")
ellipse(151, 427, 22, 29, "#30323C")
ellipse(259, 427, 22, 29, "#30323C")
ellipse(155, 431, 7, 9, "#FFFFFF")
ellipse(263, 431, 7, 9, "#FFFFFF")
ellipse(143, 462, 22, 10, "#E6B8C1")
ellipse(271, 462, 22, 10, "#E6B8C1")
d.arc((190 * S, 450 * S, 243 * S, 481 * S), 0, 180, fill="#57414C", width=3 * S)
text(215, 615, "Illustrative silhouette · not a new pet asset", 12, MUTED, False, "mm")
button(60, 637, 149, "Main", primary=True)
button(217, 637, 149, "Secondary")
wrap(65, 684, "Inspecting a notch keeps the saved portrait unchanged.", 300, 13, MUTED, leading=3)

box(406, 248, 826, 468, "#FFFFF7", 18, "#B5D2D2")
text(426, 264, "Main hue", 22, INK, True)
text(1210, 278, "5 swatches per pigment", 14, MUTED, False, "rm")
text(426, 297, "ISOLATED EXAMPLES ON WHITE · all other pigments = 0", 13, "#42686D", True)
for i in range(5):
    text(629 + 108 * i, 321, f"{i + 1}", 12, MUTED, True, "mm")
text(1177, 321, "SAVED", 11, MUTED, True, "mm")

ramps = {}
for row, (name, target) in enumerate(HUES.items()):
    y = 334 + row * 58
    text(426, y + 1, name, 17, INK, True)
    text(426, y + 25, target, 12, MUTED)
    ramps[name] = [hexc(swatch(target, weight)) for weight in WEIGHTS]
    for stage, weight in enumerate(WEIGHTS):
        x = 580 + stage * 108
        col = swatch(target, weight)
        inspected = name == "Rose" and stage == 3
        if inspected:
            box(x - 4, y - 4, 106, 52, "#F5FFFF", 11, "#0097B6", 3)
        box(x, y, 98, 44, col, 8, "#46626C" if name in ("Citrus", "Ink") else "#8AA8AF")
        # Empty lower markers distinguish unapplied colors from saved fill/checks.
        box(x + 34, y + 46, 30, 4, "#FFFFFF", 2, "#829CA2")
    box(1146, y + 2, 64, 40, "#EAF3F2", 10, "#C2D5D6")
    text(1178, y + 22, "0 / 5", 16, MUTED, True, "mm")
text(426, 695, "Outlined colors are unapplied. Inspect any stage; only Use 1 can spend a jar.", 13, MUTED)

# Stock stays below the bars. Zero stock is present but cannot offer use.
text(46, 728, "Stacked jar inventory", 15, INK, True)
number(1210, 735, 3)
stock = [("Rose", 3), ("Tide", 0), ("Citrus", 2), ("Iris", 1), ("Garnet", 0), ("Ink", 0), ("Reset", 1)]
for i, (name, count) in enumerate(stock):
    x = 44 + i * 170
    selected = name == "Rose"
    box(x, 754, 158, 68, "#D5F5F5" if selected else "#F0F7F1", 12, "#039EB5" if selected else "#CBDAD5", 2 if selected else 1)
    jar(x + 10, 767, HUES.get(name, "#D4F8FF"))
    text(x + 43, 762, name, 15, INK, True)
    text(x + 43, 788, f"{count} jar" + ("s" if count != 1 else "") if count else "0 in inventory", 12, MUTED)

box(44, 842, 1188, 112, "#DCF4F6", 15, "#72BDCA", 2)
text(64, 853, "USE 1 — CONFIRMATION EXAMPLE", 13, "#1C5B68", True)
number(1210, 858, 4)
jar(65, 883, HUES["Rose"], 1.25)
text(112, 879, "Zivvi · Main", 20, INK, True)
text(112, 910, "Rose 0/5 → 1/5", 18, INK, True)
box(335, 884, 48, 44, swatch(HUES["Rose"], .44), 9, "#527B84")
text(398, 879, "Exact next result  #FFC7D2", 15, INK, True)
text(398, 906, "Stock: 3 jars → 2  ·  consumes one Rose fruit", 15, MUTED)
button(938, 895, 116, "Cancel")
button(1066, 895, 142, "Use 1 fruit", primary=True)

# Annotation rail, visibly outside the product sheet.
box(1274, 90, 302, 146, "#D0EDF0", 17, "#AFD3D8")
text(1294, 108, "Concept key", 21, INK, True)
wrap(1294, 144, "All five candidate tabs are shown for review. Only released tabs would appear in the game.", 260, 15)
wrap(1294, 205, "44px+ control targets · one saved pet", 260, 13, "#2F646E")

box(1274, 252, 302, 129, "#FFFFFF", 17, LINE)
number(1296, 277, 1)
text(1318, 264, "Saved ≠ preview", 18, INK, True)
text(1294, 302, "Saved-count notation example: 2/5", 13, MUTED)
for i in range(5):
    box(1294 + i * 47, 329, 38, 13, CYAN if i < 2 else "white", 4, "#2A7A89")
line([(1349,335),(1354,339),(1364,331)],"#FFFFFF",2)
text(1294, 352, "Current white placeholder has 0/5 in every row.", 11, MUTED)

box(1274, 397, 302, 146, "#E3F8FA", 17, "#72C0CD")
number(1296, 421, 2)
text(1318, 409, "Inspecting stage 4", 18, INK, True)
box(1294, 451, 62, 43, swatch(HUES["Rose"], .93), 8, "#058CA7", 2)
text(1370, 450, "Preview only", 16, INK, True)
text(1370, 476, "Unapplied", 14, MUTED)
wrap(1294, 510, "Use 1 advances 0→1, never 0→4.", 260, 14, INK)

box(1274, 559, 302, 178, "#FFF5DD", 17, "#E3CA91")
text(1294, 575, "Features: earned vs shown", 18, INK, True)
text(1294, 610, "Horn buds  ·  earned max 3/5", 15, INK, True)
for i in range(5):
    ellipse(1294 + i * 43, 638, 22, 22, "#E9BC4C" if i < 3 else "#FFFFFF", "#9B824E")
text(1294, 673, "Shown stage: 1  ·  0 = hidden", 15, INK)
wrap(1294, 701, "Choose 0–3 freely; 4–5 are not earned.", 260, 13, MUTED, leading=3)

box(1274, 753, 302, 201, "#E8F0FF", 17, "#AEC1E4")
text(1294, 771, "Training uses level + XP", 18, INK, True)
text(1294, 807, "Movement  Lv 3", 20, "#2856AB", True)
box(1294, 843, 260, 14, "#D2DFF5", 6)
box(1294, 843, 74, 14, "#527DDA", 6)
text(1294, 871, "10 / 35 XP to next level", 15, INK)
wrap(1294, 904, "No five-notch training cap. Stat curve and milestones are proposals.", 260, 13, MUTED, leading=3)

OUT.mkdir(parents=True, exist_ok=True)
im.resize((W, H), Image.Resampling.LANCZOS).save(OUT / "care-machine-ui-concept.png")
(OUT / "care-machine-ui-swatches.json").write_text(json.dumps({
    "scope": "Proposed isolated single-pigment examples on white, other counts zero; not current mixed-coat quotes.",
    "weights": WEIGHTS, "targets": HUES, "srgb8": ramps,
    "currentIllustrativeSavedState": "All Main counts zero; Secondary untreated #C8C8C8; placeholder silhouette only.",
    "inspected": "Rose stage4, unapplied", "confirmation": "Rose0→1; stock3→2; #FFC7D2",
}, indent=2), encoding="utf-8")
print(OUT / "care-machine-ui-concept.png")
