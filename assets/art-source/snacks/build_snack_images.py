"""Stat Snack 2D art: the shared biscuit texture, the six rune decals and the review sheets.

Everything is drawn here with PIL: original art, no AI art, no samples. The rune staves come from
assets/ui/stat-runes/build_runes.py (Elder Futhark letters, public domain), so the snack and the UI
show the same six marks. Stat colours mirror src/shared/StatCatalog.lua and must be changed there first.

Run from the repo root:
  python assets/art-source/snacks/build_snack_images.py            textures (run before build_snacks.py)
  python assets/art-source/snacks/build_snack_images.py sheets     review sheets (run after build_snacks.py)
Needs Pillow and numpy. Sheet text uses Nunito Black from C:/Windows/Fonts.
"""
import importlib.util, json, math, os, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
EXPORT = os.path.join(HERE, "export"); os.makedirs(EXPORT, exist_ok=True)
OUT = os.path.join(REPO, "artifacts", "v2-snack-production"); RAW = os.path.join(OUT, "raw")
_spec = importlib.util.spec_from_file_location("build_runes", os.path.join(REPO, "assets", "ui", "stat-runes", "build_runes.py"))
runes = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(runes)
STATS, STAVES, rgb, mix, bleed = runes.STATS, runes.STAVES, runes.rgb, runes.mix, runes.bleed

COCOA = "#4A2B22"                      # the mark colour from the scope: dark cocoa, never gold
GOLD, GOLD_HI, TOAST, GROOVE, BASE, DOCK = "#EDBE76", "#F6D495", "#DCA45C", "#C48A49", "#E2AE66", "#C08645"


# ---------- rune decals: 256 px, clear background, the icing top's UVs cover the whole square ----------
def rune_decal(kind, px=256, ss=4):
    S = px * ss; im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    half, width = S * .25, S * .105                      # chunkier than the UI stone: it is read at 0.2 studs
    hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))         # a soft light under each stroke, so the mark looks pressed in
    runes.strokes(ImageDraw.Draw(hi), STAVES[kind], S / 2, S / 2 + S * .014, half, width, (255, 255, 255, 110))
    im = Image.alpha_composite(im, hi); d = ImageDraw.Draw(im)
    runes.strokes(d, STAVES[kind], S / 2, S / 2, half, width, rgb(COCOA) + (255,))
    return im.resize((px, px), Image.LANCZOS)

def build_decals():
    for kind, *_ in STATS:
        im = rune_decal(kind); a = im.load()
        assert a[2, 2][3] == 0 and a[253, 253][3] == 0, "corners must stay clear (the cream ring's UVs sit there)"
        bleed(im, passes=12).save(os.path.join(EXPORT, "rune-decal-%s-256.png" % kind), optimize=True)
        print("wrote rune-decal-%s-256.png" % kind)


# ---------- the shared biscuit texture, 256 px ----------
# Layout (v up):  v 0..0.5   side strip, u = once round the biscuit; v 0.25 is the scalloped rim, ten scallops across
#                 top left   the baked underside (planar, centre 0.25,0.75 radius 0.22) with docker holes
#                 top right  plain biscuit, spare
def build_biscuit(px=256, ss=4):
    S = px * ss; im = Image.new("RGB", (S, S), rgb(GOLD)); p = im.load(); rnd = random.Random(7)
    for y in range(S // 2, S):
        t = (S - 1 - y) / (S / 2)                         # 0 at the bottom edge of the strip, 1 at its top
        rim = max(0.0, 1 - abs(t - .5) / .5)              # 1 at the rim
        row = mix(mix(BASE, GOLD_HI, t), TOAST, rim ** 1.5 * .8)
        for x in range(S):
            g = (1 - math.cos(2 * math.pi * 10 * x / S)) / 2          # 1 in a groove, 0 on a scallop
            p[x, y] = mix(row, GROOVE, g ** 2 * (.16 + .22 * rim))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, S // 2 - 1, S // 2 - 1), fill=rgb(BASE))
    cx = cy = S * .25; R = S * .22
    for i in range(6):                                    # darker toward the edge of the underside
        r = R * (1.12 - i * .04); d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=mix(TOAST, BASE, i / 5))
    for i in range(6):                                    # docker holes: one in the middle, five round it
        a = 2 * math.pi * i / 5 + .3; r0 = 0 if i == 5 else R * .5; hx, hy = cx + r0 * math.cos(a), cy + r0 * math.sin(a); hr = R * .07
        d.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=rgb(DOCK))
    for _ in range(90):                                   # a few baked flecks on the sides
        x, y = rnd.uniform(0, S), rnd.uniform(S * .54, S * .96); r = rnd.uniform(.6, 1.5) * ss
        d.ellipse((x - r, y - r, x + r, y + r), fill=mix(p[int(x), int(y)], rnd.choice((GROOVE, GOLD_HI)), .45))
    im = im.filter(ImageFilter.GaussianBlur(ss * .6)).resize((px, px), Image.LANCZOS)
    im.save(os.path.join(EXPORT, "biscuit.png"), optimize=True); print("wrote biscuit.png")


# ---------- review sheets ----------
def font(size): return ImageFont.truetype(runes.FONT, size)
INK, PAPER, CARD = runes.INK, "#F1ECE6", "#FAF7F2"

def crop_alpha(im, pad=0):
    box = im.getbbox(); return im.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad)))

def build_sheets():
    man = json.load(open(os.path.join(EXPORT, "snack-export-manifest.json")))
    sizes = man["sizes"]
    # 1. the grid: six stats across, three sizes down
    grid = Image.open(os.path.join(RAW, "grid.png")).convert("RGBA")
    W, H = 2400, 1310; sheet = Image.new("RGBA", (W, H), rgb(PAPER) + (255,)); d = ImageDraw.Draw(sheet)
    d.text((60, 44), "Stat Snacks: production models", font=font(54), fill=INK)
    d.text((60, 112), "One scalloped biscuit, the stat's rune on tinted icing. Count the layers for the size; a Feast adds sugar pearls.", font=font(26), fill="#5A5870")
    gx, gy, gw, gh = 420, 190, W - 480, H - 290
    d.rounded_rectangle((gx, gy, gx + gw, gy + gh), 36, fill=rgb(CARD), outline="#DDD6CC", width=3)
    art = grid.resize((gw, round(grid.height * gw / grid.width)), Image.LANCZOS); ay = gy + 110
    sheet.alpha_composite(art, (gx, ay))
    for c, (kind, name, col, rune) in enumerate(STATS):
        x = gx + gw * (c + .5) / 6; t = "%s  (%s)" % (name, rune); f = font(26); w = d.textlength(t, font=f)
        d.rounded_rectangle((x - w / 2 - 20, gy + 34, x + w / 2 + 20, gy + 84), 25, fill=col); d.text((x - w / 2, gy + 41), t, font=f, fill=INK)
    for r, s in enumerate(sizes):
        y = ay + art.height * (r + .5) / 3 - 50
        d.text((60, y), s["id"].upper(), font=font(44), fill=INK)
        d.text((60, y + 58), "%d layer%s%s" % (s["layers"], "" if s["layers"] == 1 else "s", " + pearls" if s["pearls"] else ""), font=font(24), fill="#5A5870")
        d.text((60, y + 90), "%d of %d triangles" % (s["triangles"], s["budget"]), font=font(24), fill="#5A5870")
        d.text((60, y + 122), "%.2f studs wide, %.2f tall" % (s["sizeStuds"][0], s["sizeStuds"][2]), font=font(24), fill="#5A5870")
    d.text((60, H - 70), "Built by script (build_snacks.py), original geometry. Pieces per size: biscuit (shared texture), icing (tinted in game, rune decal on top), pearls (Feast only).", font=font(22), fill="#5A5870")
    sheet.convert("RGB").save(os.path.join(OUT, "01-snack-grid-6x3.png"), optimize=True); print("wrote 01-snack-grid-6x3.png")
    # 2. held at the Bear's cheek
    held = Image.open(os.path.join(RAW, "cheek.png")).convert("RGBA")
    W, H = 1800, 1500; sheet = Image.new("RGBA", (W, H), rgb(PAPER) + (255,)); d = ImageDraw.Draw(sheet)
    d.text((60, 44), "Heart Feast at the Bear's cheek", font=font(54), fill=INK)
    c = man["cheekCheck"]
    d.text((60, 112), "The largest snack is %.2f studs wide: %.0f%% of the Bear's head width (%.2f). The limit is a third." % (c["feastWidth"], c["ratio"] * 100, c["bearHeadWidth"]), font=font(26), fill="#5A5870")
    d.rounded_rectangle((60, 190, W - 60, H - 60), 36, fill=rgb(CARD), outline="#DDD6CC", width=3)
    art = crop_alpha(held, 20); k = min((W - 200) / art.width, (H - 330) / art.height); art = art.resize((round(art.width * k), round(art.height * k)), Image.LANCZOS)
    sheet.alpha_composite(art, ((W - art.width) // 2, 190 + (H - 250 - art.height) // 2))
    sheet.convert("RGB").save(os.path.join(OUT, "02-feast-at-bear-cheek.png"), optimize=True); print("wrote 02-feast-at-bear-cheek.png")


if __name__ == "__main__":
    if "sheets" in sys.argv[1:]: build_sheets()
    else: build_decals(); build_biscuit()
