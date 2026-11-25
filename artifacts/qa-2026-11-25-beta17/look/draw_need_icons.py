"""Draw the six flat need-bubble icons (beta (17) QA U7, CAPSULE-AND-HUD-LOOK.md section 4).

    python artifacts/qa-2026-11-25-beta17/look/draw_need_icons.py

Writes need-icons/need_icon_{hand,ball,deck,moon,paws,egg}.png (256 px, transparent, straight alpha) beside this
script, and need-icons/contact_sheet.png (each icon on the flat sticker disc at 72 px and at 256 px) for review.
The rule: two flat colours and an ink line (#24304F); no gradient, no gloss, no drop shadow. The bubble is lit by
nothing, so the icon is not either. Upload the six PNGs and put their ids in NeedBubble.IconIds
({hand = id, ball = id, ...}); until then NeedBubble keeps the emoji glyphs.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "need-icons"
SIZE = 256
SS = 4  # supersampling
INK = (36, 48, 79, 255)
FILL = (255, 253, 246, 255)  # the bubble face, #FFFDF6
LINE = 11 * SS  # ink line at 256 px: 11 px, about 2 px on the 46 px icon in the bubble


def rgba(hex_):
    hex_ = hex_.lstrip("#")
    return tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def S(v):
    return v * SS


def ellipse(d, cx, cy, rx, ry, fill, width=LINE):
    d.ellipse([S(cx - rx), S(cy - ry), S(cx + rx), S(cy + ry)], fill=fill, outline=INK, width=width)


def poly(d, pts, fill, width=LINE):
    pts = [(S(x), S(y)) for x, y in pts]
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=INK, width=width, joint="curve")
    for x, y in pts:  # round the joins
        r = width / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=INK)


def arc_line(d, cx, cy, r, a0, a1, width=LINE, color=INK):
    d.arc([S(cx - r), S(cy - r), S(cx + r), S(cy + r)], a0, a1, fill=color, width=width)


def rounded(d, box, radius, fill, width=LINE):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([S(x0), S(y0), S(x1), S(y1)], radius=S(radius), fill=fill, outline=INK, width=width)


GROW = 11  # px at 256: the outline drawn as a grown ink silhouette under the fill (one clean edge round a union)


def capsule(d, p0, p1, w, color, grow=0):
    (x0, y0), (x1, y1) = p0, p1
    r = w / 2 + grow
    d.line([(S(x0), S(y0)), (S(x1), S(y1))], fill=color, width=int(S(2 * r)))
    for x, y in (p0, p1):
        d.ellipse([S(x - r), S(y - r), S(x + r), S(y + r)], fill=color)


def polyfill(d, pts, color, grow=0):
    d.polygon([(S(x), S(y)) for x, y in pts], fill=color)
    if grow:
        d.line([(S(x), S(y)) for x, y in pts + [pts[0]]], fill=color, width=S(2 * grow))
        for x, y in pts:
            d.ellipse([S(x - grow), S(y - grow), S(x + grow), S(y + grow)], fill=color)


def hand(d):
    """A waving open hand: peach, one ink edge round the whole hand, finger lines, two blue wave marks."""
    skin, wave = rgba("#FFCFA3"), rgba("#5BB8F5")
    fingers = [((84, 66), (84, 150)), ((114, 48), (114, 150)), ((144, 52), (144, 150)), ((174, 70), (174, 150))]
    palm = [(68, 128), (190, 128), (194, 180), (172, 212), (104, 216), (70, 186)]
    thumb = ((82, 172), (46, 128))
    for color, grow in ((INK, GROW), (skin, 0)):
        for a, b in fingers:
            capsule(d, a, b, 32, color, grow)
        capsule(d, thumb[0], thumb[1], 32, color, grow)
        polyfill(d, palm, color, grow)
    for x, top in ((99, 78), (129, 64), (159, 80)):  # between the fingers
        d.line([(S(x), S(top)), (S(x), S(132))], fill=INK, width=S(6))
    arc_line(d, 200, 72, 30, 300, 40, color=wave)
    arc_line(d, 200, 72, 50, 300, 40, color=wave)


def ball(d):
    """A tennis ball: lime with two white seams kept inside it, no highlight."""
    lime, seam = rgba("#D6EE4A"), rgba("#FFFFFF")
    r = 92
    d.ellipse([S(128 - r - GROW), S(128 - r - GROW), S(128 + r + GROW), S(128 + r + GROW)], fill=INK)
    d.ellipse([S(128 - r), S(128 - r), S(128 + r), S(128 + r)], fill=lime)
    layer = Image.new("RGBA", (S(SIZE), S(SIZE)), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for sx in (-1, 1):
        cx = 128 + sx * 112
        box = [S(cx - 80), S(128 - 80), S(cx + 80), S(128 + 80)]
        ld.ellipse(box, outline=INK, width=S(18))
        ld.ellipse([box[0] + S(4), box[1] + S(4), box[2] - S(4), box[3] - S(4)], outline=seam, width=S(10))
    clip = Image.new("L", layer.size, 0)
    ImageDraw.Draw(clip).ellipse([S(128 - r), S(128 - r), S(128 + r), S(128 + r)], fill=255)
    from PIL import ImageChops
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    d._image.alpha_composite(layer)


def deck(d):
    """The handheld: blue body, cream screen, ink buttons."""
    body, screen = rgba("#4FC3F7"), rgba("#FFF4DC")
    rounded(d, (28, 70, 228, 190), 48, body)
    rounded(d, (90, 92, 166, 152), 10, screen)
    d.rectangle([S(46), S(124), S(78), S(134)], fill=INK)  # d-pad
    d.rectangle([S(57), S(113), S(67), S(145)], fill=INK)
    for cx, cy in ((192, 112), (206, 140)):
        ellipse(d, cx, cy, 9, 9, screen, width=S(6))
    d.line([(S(116), S(170)), (S(140), S(170))], fill=INK, width=S(7))


def moon(d):
    """A sleepy crescent: yellow, one lilac star."""
    yellow, star = rgba("#FFD84A"), rgba("#B9A4FF")
    big, cut = (118, 132, 86), (156, 104, 70)
    mask = Image.new("L", (S(SIZE), S(SIZE)), 0)
    m = ImageDraw.Draw(mask)
    m.ellipse([S(big[0] - big[2]), S(big[1] - big[2]), S(big[0] + big[2]), S(big[1] + big[2])], fill=255)
    m.ellipse([S(cut[0] - cut[2]), S(cut[1] - cut[2]), S(cut[0] + cut[2]), S(cut[1] + cut[2])], fill=0)
    # outline: grow the crescent by the line width and put ink under it
    from PIL import ImageFilter
    grown = mask.filter(ImageFilter.MaxFilter(LINE // 2 * 2 + 1))
    d._image.paste(Image.new("RGBA", grown.size, INK), (0, 0), grown)
    d._image.paste(Image.new("RGBA", mask.size, yellow), (0, 0), mask)
    pts = []
    cx, cy, r = 196, 70, 28
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * .45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    poly(d, pts, star, width=S(7))


def paws(d):
    """A paw print: pink pads, a paler heel pad."""
    toe, heel = rgba("#FF8FB8"), rgba("#FFC2D8")
    ellipse(d, 128, 166, 54, 44, heel)
    for cx, cy, r in ((66, 112, 22), (102, 72, 24), (154, 72, 24), (190, 112, 22)):
        ellipse(d, cx, cy, r, r * 1.18, toe)


def egg(d):
    """The sleepy egg: pale lilac with a cream band (the nest egg's colours)."""
    lilac, band = rgba("#CDB8FF"), rgba("#FFF4DC")
    pts = []
    cx, cy, r = 128, 130, 92
    for i in range(120):
        t = i / 120 * math.tau
        s = math.sin(t)
        w = r * .78 * (1 - .16 * max(s, 0))
        h = r * (1.06 if s > 0 else .84)
        pts.append((cx + math.cos(t) * w, cy + r * .1 - s * h))
    shape = Image.new("L", (S(SIZE), S(SIZE)), 0)
    ImageDraw.Draw(shape).polygon([(S(x), S(y)) for x, y in pts], fill=255)
    d._image.paste(Image.new("RGBA", shape.size, lilac), (0, 0), shape)
    stripe = Image.new("L", shape.size, 0)
    ImageDraw.Draw(stripe).rectangle([0, S(132), S(SIZE), S(162)], fill=255)
    from PIL import ImageChops
    d._image.paste(Image.new("RGBA", shape.size, band), (0, 0), ImageChops.multiply(shape, stripe))
    for y in (132, 162):
        inside = [x for x, yy in ((x, y) for x in range(SIZE)) if shape.getpixel((S(x), S(y))) > 0]
        if inside:
            d.line([(S(inside[0]), S(y)), (S(inside[-1]), S(y))], fill=INK, width=S(6))
    d.line([(S(x), S(y)) for x, y in pts + [pts[0]]], fill=INK, width=LINE, joint="curve")


DRAW = {"hand": hand, "ball": ball, "deck": deck, "moon": moon, "paws": paws, "egg": egg}


def icon(kind):
    img = Image.new("RGBA", (S(SIZE), S(SIZE)), (0, 0, 0, 0))
    DRAW[kind](ImageDraw.Draw(img))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def sticker(img, px):
    """The bubble as NeedBubble draws it: lip, flat face, 2 px ink outline; the icon at .64 of it."""
    pad = 8
    out = Image.new("RGBA", (px + pad * 2, px + pad * 2 + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    d.ellipse([pad, pad + 3, pad + px, pad + px + 3], fill=INK[:3] + (64,))
    d.ellipse([pad, pad, pad + px, pad + px], fill=FILL, outline=INK, width=max(2, px // 36))
    size = int(px * .64)
    small = img.resize((size, size), Image.LANCZOS)
    out.alpha_composite(small, (pad + (px - size) // 2, pad + int(px * .54) - size // 2))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {}
    for kind in DRAW:
        icons[kind] = icon(kind)
        icons[kind].save(OUT / f"need_icon_{kind}.png")
        print("wrote", OUT / f"need_icon_{kind}.png")
    cell = 300
    sheet = Image.new("RGBA", (cell * len(icons), cell + 110), rgba("#8FB27A"))  # a lawn green behind, as in game
    for i, (kind, img) in enumerate(icons.items()):
        big = sticker(img, 256)
        sheet.alpha_composite(big, (i * cell + (cell - big.width) // 2, 8))
        small = sticker(img, 72)
        sheet.alpha_composite(small, (i * cell + (cell - small.width) // 2, cell + 10))
    sheet.save(OUT / "contact_sheet.png")
    print("wrote", OUT / "contact_sheet.png")


if __name__ == "__main__":
    main()
