"""Sheets for the production Bunny (2026-11-19). PIL only: lays out and labels the Blender renders in raw/
(render_bunny.py) and the Bear v2 frames from artifacts/v2-bear-restyle-2026-11-19/raw. No generated art.

Run from the repo root:  python artifacts/v2-bunny-production/build_sheets.py
"""
import os, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); RAW = os.path.join(HERE, "raw")
BEAR = os.path.join(HERE, "..", "v2-bear-restyle-2026-11-19", "raw")
REP = json.load(open(os.path.join(HERE, "bunny-report.json")))
F = "C:/Windows/Fonts/"
def black(s): return ImageFont.truetype(F + "Nunito-Black.ttf", s)
def bold(s): return ImageFont.truetype(F + "Nunito-Bold.ttf", s)
PAPER, CARD, INK, SOFT, LINE, GOOD, WARN = (241, 236, 230), (250, 247, 243), (38, 32, 36), (120, 110, 112), (214, 205, 196), (46, 140, 96), (190, 110, 40)
PPU = 350

def raw(name, folder=RAW): return Image.open(os.path.join(folder, name + ".png")).convert("RGBA")
def cut(im): return im.crop(im.getbbox())
def grounded(im, k=1.0, blur=9):
    im = cut(im)
    if k != 1.0: im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    w, h = im.size; pad = 40
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
def centred(d, cx, y, t, font, fill): d.text((cx - d.textlength(t, font=font) / 2, y), t, font=font, fill=fill)

VIEWS = [("front", "FRONT"), ("threeq", "THREE-QUARTER"), ("side", "SIDE"), ("back", "BACK")]
M, T, FIT = REP["measures"], REP["tris"], REP["wearable_fit"]
pct = lambda v: "%d%%" % round(v * 100)

def turnaround():
    W, H = 2400, 2330; s, d = sheet(W, H)
    title(d, 60, 40, "Production Bunny: turnaround next to the Bear v2",
          "pet-bunny.blend, undyed white and grey. Left of each pair: the Bear v2 candidate. Same camera, same scale. Body, hands and feet are the same meshes.")
    for i, (name, label) in enumerate(VIEWS):
        x, y = 40 + (i % 2) * 1170, 150 + (i // 2) * 760
        card(d, (x, y, x + 1150, y + 740)); d.text((x + 24, y + 18), label, font=black(24), fill=SOFT)
        place(s, grounded(raw("v2-turn-" + name, BEAR)), x + 300, y + 690); place(s, grounded(raw("bunny-turn-" + name)), x + 850, y + 690)
        centred(d, x + 300, y + 696, "BEAR V2", black(20), SOFT); centred(d, x + 850, y + 696, "BUNNY", black(20), GOOD)
    y = 1680; card(d, (40, y, 1210, y + 620)); d.text((64, y + 18), "MORE ANGLES, THE HAT POSE AND A DYED EXAMPLE", font=black(24), fill=SOFT)
    for j, (name, label) in enumerate((("turn-threeq-left", "FLOP SIDE"), ("turn-threeq-back", "BACK THREE-QUARTER"), ("hatpose-front", "EARS TIPPED FOR A HAT"), ("dyed-threeq", "PEACH MILK (DYED)"))):
        cx = 40 + 160 + j * 284; place(s, grounded(raw("bunny-" + name), .66), cx, y + 560); centred(d, cx, y + 570, label, black(17), SOFT)
    x = 1260
    d.text((x, y + 6), "Triangles: %s of a 3,000 budget" % format(T["total"], ","), font=black(34), fill=GOOD)
    b = T["by_piece"]
    lines(d, x, y + 60, [
        "Head %d, ears %d, inner ears %d, tail %d, face (pad, nose, mouth, eyes, blush) %d." % (b["Head"], b["EarL"] + b["EarR"], b["EarInnerL"] + b["EarInnerR"], b["Tail"], sum(b[k] for k in ("Muzzle", "Nose", "Mouth", "EyeL", "EyeR", "BlushL", "BlushR"))),
        "Shared with the Bear, unchanged: body %d, hands %d, feet %d." % (b["Body"], b["HandL"] + b["HandR"], b["FootL"] + b["FootR"]),
    ], bold(23), 38, INK)
    d.text((x, y + 150), "Measured against the cute rules", font=black(30), fill=INK)
    lines(d, x, y + 198, [
        "Head %s of the height to the crown; %.2f times the body width (Bear v2: 1.71)." % (pct(M["P1_head_over_height_to_crown"]), M["P2_head_width_over_body_width"]),
        "Eye line %s up the head; each eye %s of head width; centres %s apart." % (pct(M["E2_eye_line_up_the_head"]), pct(M["E1_eye_width_over_head_width"]), pct(M["E3_eye_centres_over_head_width"])),
        "Nose %s, mouth %s, snout pad %s of head width; the pad sticks out %.2f." % (pct(M["F2_nose_width_over_head_width"]), pct(M["F3_mouth_glyph_width_over_head_width"]), pct(M["F4_pad_width_over_head_width"]), M["F4_pad_sticks_out"]),
        "Ears %s as wide as long; tip radius %.2f; no points anywhere." % (pct(M["P5_ear_width_over_length"]), M["S2_ear_tip_radius"]),
        "Head outline corners %d degrees (24 round). %.2f studs to the ear tip." % (round(M["S1_head_outline_corner_degrees"]), M["height_to_ear_tip"]),
    ], bold(23), 38, INK)
    d.text((x, y + 400), "Colour roles", font=black(30), fill=INK)
    lines(d, x, y + 448, [
        "Primary #FFFFFF: head, ears, body, hands, feet (gradient to secondary at the tips).",
        "Secondary #A8A5AE: ear insides, snout pad, cotton tail, charm.",
        "Fixed: nose #F58CA5, blush #FFB0BC, eye #2B1A20, mouth ink #5A2F33.",
        "Original geometry, built by script (build_bunny.py). Exported, not uploaded, no src change.",
    ], bold(22), 36, SOFT)
    s.convert("RGB").save(os.path.join(HERE, "01-bunny-turnaround.png"))

OUTFITS = (
    ("a", "Pom Beanie, Stripy Tee, Pearl Beads, Sparkle Eyes", "side"),
    ("b", "Tiny Sun Hat, Star Hoodie, Bell Collar, Sleepy Eyes, Star Studs", "back"),
    ("c", "Flower Crown, Acorn Pendant, Round Specs, Blush Stickers, Little Hoops, Friendship Bands", "side"),
    ("d", "Party Hat, Happy Eyes, Blep, Bow Tail, Friendship Bands, Wings stage 3", "back"),
    ("e", "Lash Eyes, Kitty W mouth, Heart Tail, Horns stage 5", "back"),
)
def fit_sheet():
    K = .74; RH = 600; W, H = 2600, 200 + RH * 3 + 240; s, d = sheet(W, H)
    title(d, 60, 40, "Wearable fit: the Bear's items on the Bunny",
          "The same five outfits as 02-bear-wearable-fit.png. Every wearable mesh is the Bear's, on the same-named anchor. With a full hat on, the ears tip out to 40 degrees.")
    for i, (key, label, extra) in enumerate(OUTFITS):
        x, y = 40 + (i % 2) * 1270, 160 + (i // 2) * RH; card(d, (x, y, x + 1250, y + RH - 20))
        for k, v in enumerate(("front", "threeq", extra)): place(s, grounded(raw("bunny-fit-%s-%s" % (key, v)), K), x + 220 + k * 400, y + RH - 40)
        d.text((x + 24, y + 14), label, font=bold(20), fill=SOFT)
    x, y = 1310, 160 + 2 * RH; card(d, (x, y, x + 1250, y + RH - 20))
    d.text((x + 30, y + 20), "Measured: %d of %d wearable meshes fit" % (FIT["ok"], FIT["meshes"]), font=black(32), fill=GOOD)
    bad = FIT["not_ok"]; a = REP["anchors"]["charm_clearance_to_ears"]
    lines(d, x + 30, y + 76, [
        "Every vertex of each shop item, horn and wing stage was measured against",
        "the pet surface, on the Bear v2 and on the Bunny. Pass = within 0.03 studs",
        "of where it sat on the Bear.",
        "Not passing: " + (", ".join("%s (%.3f deeper; the bigger tail)" % (r["mesh"], -r["deepest_shift"]) for r in bad) or "none"),
        "",
        "Hat, shirt, neck, back, wrist, horn and wing anchors are the Bear's, unmoved.",
        "Moved with the face: EyeL, EyeR, EyeLine, FaceBridge, CheekL, CheekR,",
        "Mouth, Nose. Moved onto the long ears: EarL, EarR, HelixL/R, LobeL/R.",
        "CharmRight moved %.2f out to clear the flopped ear (gap now %.2f)." % (a["CharmRight"]["moved"][0], a["CharmRight"]["gap"]),
        "CharmFloat clears the ears by %.2f, unmoved." % a["CharmFloat"]["gap"],
    ], bold(22), 36, INK)
    y2 = 160 + 3 * RH
    d.text((60, y2), "Needs a look in Studio", font=black(30), fill=WARN)
    lines(d, 60, y2 + 46, [
        "1. The game places wearables from the Bear template with one offset per item. The Bunny needs an offset per anchor (and a turn for the ear piercings): anchorDeltaFromBear in bunny-rig-proposal.lua.",
        "2. The hat pose (ears tip 27 degrees more, with their piercings) is new rig behaviour. Without it, full hats cut through the ear bases.",
        "3. Round Eyes, Small Wide Eyes and Kitty W sit on the Head anchor in the Bear's source, so they do not follow the Bunny's lower face. Kitty W is also the Bunny's own mouth shape.",
        "4. Little Hoops were shaped for the Bear's round ear rim; on the thin long ear they hang a little loose.",
    ], bold(22), 36, INK)
    s.convert("RGB").save(os.path.join(HERE, "02-bunny-wearable-fit.png"))

def silhouettes():
    W, H = 2000, 1260; s, d = sheet(W, H)
    title(d, 60, 40, "Phone-size check (Bear = 96 px tall)", "Rule S4: a pet must be named from its black silhouette at 96 px, front and back. Both pets are white; the ears tell them apart from every side.")
    k = 96 / (1.479 * PPU)
    pets = (("v2-turn-%s", BEAR, "BEAR V2"), ("bunny-turn-%s", RAW, "BUNNY"))
    for row, (mode, label) in enumerate((("sil", "Silhouette, actual size"), ("col", "In colour, actual size"), ("big", "In colour, three times size (to inspect)"))):
        y = 170 + (0, 250, 500)[row]; hgt = (230, 230, 560)[row]
        card(d, (40, y, W - 40, y + hgt)); d.text((64, y + 14), label, font=black(22), fill=SOFT)
        x = 190
        for name, vlabel in VIEWS:
            for pat, folder, plabel in pets:
                im = cut(raw(pat % name, folder)); kk = k * (3 if mode == "big" else 1)
                im = im.resize((max(1, round(im.width * kk)), max(1, round(im.height * kk))), Image.LANCZOS)
                if mode == "sil":
                    sil = Image.new("RGBA", im.size, INK + (255,)); sil.putalpha(im.getchannel("A")); im = sil
                place(s, im, x, y + hgt - 44); centred(d, x, y + hgt - 38, plabel, bold(15), SOFT); x += 215
            if row == 0: centred(d, x - 215 * 1.5, y - 30, vlabel, black(20), INK)
            x += 30
    s.convert("RGB").save(os.path.join(HERE, "03-bunny-phone-silhouette.png"))

turnaround(); fit_sheet(); silhouettes()
print("sheets written")
