"""Sheets for the Bear restyle (2026-11-19). PIL only: lays out and labels the Blender renders in raw/ (render_bear.py)
and the white Bunny frames from artifacts/v2-pet-redesign-2026-11-19/raw. No generated art.

Run from the repo root:  python artifacts/v2-bear-restyle-2026-11-19/build_bear_sheets.py
"""
import os, json, shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); RAW = os.path.join(HERE, "raw")
BUN = os.path.join(HERE, "..", "v2-pet-redesign-2026-11-19")
REP = json.load(open(os.path.join(HERE, "bear-v2-report.json")))
F = "C:/Windows/Fonts/"
def black(s): return ImageFont.truetype(F + "Nunito-Black.ttf", s)
def bold(s): return ImageFont.truetype(F + "Nunito-Bold.ttf", s)
PAPER, CARD, INK, SOFT, LINE, GOOD = (241, 236, 230), (250, 247, 243), (38, 32, 36), (120, 110, 112), (214, 205, 196), (46, 140, 96)
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
M, T = REP["measures"], REP["tris"]
pct = lambda v: "%d%%" % round(v * 100)

def old_vs_new():
    W, H = 2400, 2270; s, d = sheet(W, H)
    title(d, 60, 40, "The Bear in the new cute style: live Bear and v2 candidate",
          "Left of each pair: the live Bear. Right: pet-bear-v2-cute.blend. Undyed white and grey, same camera, same scale. Nothing live was changed.")
    for i, (name, label) in enumerate(VIEWS):
        x, y = 40 + (i % 2) * 1170, 150 + (i // 2) * 700
        card(d, (x, y, x + 1150, y + 680)); d.text((x + 24, y + 18), label, font=black(24), fill=SOFT)
        place(s, grounded(raw("live-turn-" + name)), x + 300, y + 630); place(s, grounded(raw("v2-turn-" + name)), x + 850, y + 630)
        centred(d, x + 300, y + 636, "LIVE", black(20), SOFT); centred(d, x + 850, y + 636, "V2 CUTE", black(20), GOOD)
    y = 1550; card(d, (40, y, 1210, y + 680)); d.text((64, y + 18), "DYED (the live white eye ring shows on any colour)", font=black(24), fill=SOFT)
    for j, (tag, name) in enumerate((("live", "front"), ("live", "threeq"), ("v2", "front"), ("v2", "threeq"))):
        cx = 40 + 160 + j * 284; place(s, grounded(raw("%s-dyed-%s" % (tag, name)), .78), cx, y + 620)
        centred(d, cx, y + 630, "LIVE" if tag == "live" else "V2 CUTE", black(20), SOFT if tag == "live" else GOOD)
    x = 1260
    d.text((x, y + 6), "What changed", font=black(32), fill=INK)
    lines(d, x, y + 56, [
        "1. Eye line %s up the head (was 52.5%%); eyes %s of head width, %s apart." % (pct(M["E2_eye_line_up_the_head"]), pct(M["E1_eye_width_over_head_width"]), pct(M["E3_eye_centres_over_head_width"])),
        "2. Dark eyes with two catchlights, same side on both. No white ring.",
        "3. Head, body and ears re-meshed round: head outline corners %d degrees (were 30 to 36)." % round(M["S1_head_outline_corner_degrees"]),
        "4. Muzzle narrowed to a snout pad: %s of head width (was 33%%)." % pct(M["F4_pad_width_over_head_width"]),
        "5. Soft small nose (%s of head width, was 9.7%%); the same \"v\" mouth." % pct(M["F2_nose_width_over_head_width"]),
        "6. Blush under the eyes; roughness 0.5 so highlights stay soft.",
    ], bold(24), 40, INK)
    d.text((x, y + 316), "What did not", font=black(32), fill=INK)
    lines(d, x, y + 366, [
        "Round ears, nub tail, white and grey: still a Bear.",
        "Hands, feet, tail and inner ears are the live meshes, untouched.",
        "Head, body and ears stay within 0.005 studs outside the live surface.",
        "%d of %d anchors are identical. The four eye anchors follow the eye line." % (REP["anchors"]["total"] - len(REP["anchors"]["moved"]), REP["anchors"]["total"]),
    ], bold(24), 40, INK)
    d.text((x, y + 546), "Triangles: live %s, v2 %s (ceiling for the Bunny: 3,000)" % (format(T["live_bear"], ","), format(T["v2_total"], ",")), font=black(28), fill=GOOD)
    lines(d, x, y + 590, ["Original geometry, built by script (build_bear_v2.py). No generated or imported models.", "Not exported, not uploaded, no src change. For a private beta first."], bold(20), 30)
    s.convert("RGB").save(os.path.join(HERE, "01-bear-old-vs-new.png"))

OUTFITS = (
    ("a", "Pom Beanie, Stripy Tee, Pearl Beads, Sparkle Eyes", None),
    ("b", "Tiny Sun Hat, Star Hoodie, Bell Collar, Sleepy Eyes, Star Studs", "back"),
    ("c", "Flower Crown, Acorn Pendant, Round Specs, Blush Stickers, Little Hoops, Friendship Bands", "side"),
    ("d", "Party Hat, Happy Eyes, Blep, Bow Tail, Friendship Bands, Wings stage 3", "back"),
    ("e", "Lash Eyes, Kitty W mouth, Heart Tail, Horns stage 5", "back"),
)
def fit_sheet():
    K = .80; RH = 560; W, H = 2600, 200 + RH * len(OUTFITS) + 230; s, d = sheet(W, H)
    fit = REP["wearable_fit"]
    title(d, 60, 40, "Wearable fit: the same items on the live Bear and on the v2 candidate",
          "Every wearable mesh is the live one, on its live anchor. Only the four eye anchors moved (0.058 down), so eye items and glasses follow the new eye line.")
    d.text((70, 150), "LIVE BEAR", font=black(30), fill=SOFT); d.text((1340, 150), "V2 CUTE CANDIDATE", font=black(30), fill=GOOD)
    for i, (key, label, extra) in enumerate(OUTFITS):
        y = 200 + i * RH; card(d, (40, y, 1290, y + RH - 20)); card(d, (1310, y, 2560, y + RH - 20))
        for j, tag in enumerate(("live", "v2")):
            x = 40 + j * 1270; views = ["front", "threeq"] + ([extra] if extra else [])
            for k, v in enumerate(views): place(s, grounded(raw("%s-fit-%s-%s" % (tag, key, v)), K), x + 220 + k * 400, y + RH - 40)
            d.text((x + 24, y + 14), label, font=bold(20), fill=SOFT)
    y = 200 + len(OUTFITS) * RH + 10
    d.text((60, y), "Measured as well as looked at: %d of %d wearable meshes fit" % (fit["ok"], fit["meshes"]), font=black(32), fill=GOOD if fit["ok"] == fit["meshes"] else (196, 72, 72))
    c = REP["containment"]
    wr = max(fit["rows"], key=lambda r: abs(r["mean_shift"]))
    lines(d, 60, y + 52, [
        "Every vertex of all 23 shop items, the horns (5 stages) and the wings (5 stages) was measured against the pet surface, live and v2. Pass = it sits within 0.03 studs of where it sat (the style guide's fit limit).",
        "Largest shift: %.3f studs (%s). The v2 head is never more than %.4f outside the live head, the body %.4f, the ears %.4f; hands and feet are identical."
        % (abs(wr["mean_shift"]), wr["mesh"], c["Head"]["new_surface_outside_live_max"], c["Body"]["new_surface_outside_live_max"], max(c["EarL"]["new_surface_outside_live_max"], c["EarR"]["new_surface_outside_live_max"])),
        "Where the live Bear's low-poly corners stuck out, the round v2 surface is up to %.3f lower (head) and %.3f (body), so a hat or shirt sits that much looser at those spots. All rows: bear-v2-report.json."
        % (c["Head"]["live_corner_above_new_surface_max"], c["Body"]["live_corner_above_new_surface_max"]),
        "Not shown: Round Eyes and Small Wide Eyes. Their meshes sit on the Head anchor in the source file and use the old ringed eye texture, so they need the same 0.058 drop and a look before the beta.",
    ], bold(22), 36, INK)
    s.convert("RGB").save(os.path.join(HERE, "02-bear-wearable-fit.png"))

def silhouettes():
    W, H = 2400, 1180; s, d = sheet(W, H)
    title(d, 60, 40, "Phone-size check (Bear = 96 px tall)", "Rule S4: a pet must be named from its black silhouette at 96 px, front and back. The v2 Bear keeps the live Bear's outline; the Bunny is told apart by its ears.")
    k = 96 / (1.479 * PPU)
    pets = (("live-turn-%s", RAW, "LIVE BEAR"), ("v2-turn-%s", RAW, "V2 BEAR"), ("solo-bunny-%s", os.path.join(BUN, "raw"), "BUNNY"))
    for row, (mode, label) in enumerate((("sil", "Silhouette, actual size"), ("col", "In colour, actual size"), ("big", "In colour, three times size (to inspect)"))):
        y = 170 + (0, 230, 460)[row]; hgt = (210, 210, 520)[row]
        card(d, (40, y, W - 40, y + hgt)); d.text((64, y + 14), label, font=black(22), fill=SOFT)
        x = 150
        for name, vlabel in VIEWS:
            for pat, folder, plabel in pets:
                im = cut(raw(pat % name, folder)); kk = k * (3 if mode == "big" else 1)
                im = im.resize((max(1, round(im.width * kk)), max(1, round(im.height * kk))), Image.LANCZOS)
                if mode == "sil":
                    sil = Image.new("RGBA", im.size, INK + (255,)); sil.putalpha(im.getchannel("A")); im = sil
                place(s, im, x, y + hgt - 44); centred(d, x, y + hgt - 38, plabel, bold(15), SOFT); x += 185
            if row == 0: centred(d, x - 185 * 2, y + 14, vlabel, black(20), INK)
            x += 15
    s.convert("RGB").save(os.path.join(HERE, "03-bear-phone-silhouette.png"))

old_vs_new(); fit_sheet(); silhouettes()
shutil.copyfile(os.path.join(BUN, "01-bunny-turnaround.png"), os.path.join(HERE, "04-bunny-white-grey-turnaround.png"))
print("sheets written")
