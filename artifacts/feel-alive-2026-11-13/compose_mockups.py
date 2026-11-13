"""Paint the station attract treatment over the Blender renders and lay out the mockups.

    python artifacts/feel-alive-2026-11-13/compose_mockups.py

Reads raw/*.png and anchors.json from render_hub_mockups.py. Mockups only: glow,
shaft, ring, icon and arrow are painted in 2D at the projected station positions.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
A = json.loads((HERE / "anchors.json").read_text())
NAVY = (36, 48, 79)
HUES = {  # station: (main, light, name, icon caption)
    "deck": ((53, 199, 245), (184, 236, 255), "Pocket Deck kiosk", "aqua #35C7F5"),
    "eggs": ((255, 200, 60), (255, 238, 170), "Egg nest (hatching)", "gold #FFC83C"),
    "care": ((255, 111, 174), (255, 201, 220), "Care cradle (pets)", "pink #FF6FAE"),
}


def font(size, bold=False):
    for name in (("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def screen(base, layer):
    """Additive-style light: screen the layer's RGB (premultiplied by alpha) onto base."""
    black = Image.new("RGB", base.size, (0, 0, 0))
    black.paste(layer.convert("RGB"), mask=layer.split()[3])
    lit = ImageChops.screen(base, black)
    # Daylight scenes are already bright, so half of the light is laid over as plain colour.
    veil = layer.copy()
    veil.putalpha(veil.split()[3].point(lambda v: int(v * .3)))
    return Image.alpha_composite(lit.convert("RGBA"), veil).convert("RGB")


def glow(base, xy, radius, color, strength=1.0, squash=1.0):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = xy
    d.ellipse([x - radius, y - radius * squash, x + radius, y + radius * squash], fill=color + (int(255 * strength),))
    return screen(base, layer.filter(ImageFilter.GaussianBlur(radius * 0.45)))


def shaft(base, top, sky, w0, w1, color, strength):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        y0, y1 = top[1] + (sky[1] - top[1]) * t0, top[1] + (sky[1] - top[1]) * t1
        x0, x1 = top[0] + (sky[0] - top[0]) * t0, top[0] + (sky[0] - top[0]) * t1
        a = int(255 * strength * (1 - t0) ** 1.6)
        wa, wb = w0 + (w1 - w0) * t0, w0 + (w1 - w0) * t1
        d.polygon([(x0 - wa, y0), (x0 + wa, y0), (x1 + wb, y1), (x1 - wb, y1)], fill=color + (a,))
    return screen(base, layer.filter(ImageFilter.GaussianBlur(max(2, w0 * 0.35))))


def ring(base, pts, centre, color, light, strength, ripple=True):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    loop = [(p[0], p[1]) for p in pts] + [(pts[0][0], pts[0][1])]
    d.line(loop, fill=color + (int(255 * strength),), width=11, joint="curve")
    if ripple:
        for k, a in ((1.28, 0.5), (0.62, 0.55)):
            rp = [(centre[0] + (x - centre[0]) * k, centre[1] + (y - centre[1]) * k) for x, y in loop]
            d.line(rp, fill=color + (int(255 * strength * a),), width=6, joint="curve")
    soft = screen(base, layer.filter(ImageFilter.GaussianBlur(7)))
    crisp = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(crisp).line(loop, fill=color + (int(255 * strength),), width=7, joint="curve")
    ImageDraw.Draw(crisp).line(loop, fill=(255, 255, 255, int(235 * strength)), width=3, joint="curve")
    return Image.alpha_composite(soft.convert("RGBA"), crisp).convert("RGB")


def sparkle(d, x, y, r, color):
    d.polygon([(x, y - r), (x + r * .26, y - r * .26), (x + r, y), (x + r * .26, y + r * .26), (x, y + r),
               (x - r * .26, y + r * .26), (x - r, y), (x - r * .26, y - r * .26)], fill=color)


def glyph(d, kind, cx, cy, r, hue):
    if kind == "deck":
        w, h = r * 1.25, r * .78
        d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=h * .55, fill=(59, 74, 120))
        d.rounded_rectangle([cx - w * .42, cy - h * .58, cx + w * .42, cy + h * .58], radius=h * .14, fill=(143, 232, 255))
        a = h * .2
        d.rectangle([cx - w * .82, cy - a * .45, cx - w * .52, cy + a * .45], fill=(255, 255, 255))
        d.rectangle([cx - w * .67 - a * .45, cy - a * 1.2, cx - w * .67 + a * .45, cy + a * 1.2], fill=(255, 255, 255))
        d.ellipse([cx + w * .55, cy - h * .5, cx + w * .55 + a * 1.3, cy - h * .5 + a * 1.3], fill=(255, 216, 74))
        d.ellipse([cx + w * .62, cy + h * .08, cx + w * .62 + a * 1.3, cy + h * .08 + a * 1.3], fill=(255, 111, 174))
    elif kind == "eggs":
        pts = []
        for i in range(48):
            t = i / 48 * math.tau
            k = 1.0 if math.sin(t) > 0 else 1.28          # taller on top
            pts.append((cx + math.cos(t) * r * .82, cy + r * .12 - math.sin(t) * r * .86 * k))
        d.polygon(pts, fill=(255, 249, 240), outline=NAVY)
        d.line(pts + [pts[0]], fill=NAVY, width=max(2, int(r * .09)))
        zig = [(cx - r * .8, cy + r * .1), (cx - r * .45, cy - r * .12), (cx - r * .15, cy + r * .16), (cx + r * .15, cy - r * .12),
               (cx + r * .45, cy + r * .16), (cx + r * .8, cy + r * .02)]
        d.line(zig, fill=hue, width=max(3, int(r * .16)), joint="curve")
        sparkle(d, cx + r * .2, cy - r * .62, r * .26, hue)
    else:
        s = r * .96
        pts = []
        for i in range(60):
            t = i / 60 * math.tau
            x = 16 * math.sin(t) ** 3
            y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
            pts.append((cx + x / 17 * s, cy - y / 17 * s + r * .06))
        d.polygon(pts, fill=hue)
        d.line(pts + [pts[0]], fill=NAVY, width=max(2, int(r * .09)))
        d.ellipse([cx - s * .55, cy - s * .5, cx - s * .25, cy - s * .2], fill=(255, 255, 255))


def bubble(img, kind, xy, r, hue, light, ghost=True, alpha=1.0):
    S = 3
    size = int(r * 3.4)
    layer = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = size * S / 2
    R = r * S
    d.ellipse([c - R, c - R + R * .1, c + R, c + R + R * .1], fill=NAVY + (70,))
    d.ellipse([c - R, c - R, c + R, c + R], fill=NAVY)
    d.ellipse([c - R * .9, c - R * .9, c + R * .9, c + R * .9], fill=hue)
    d.ellipse([c - R * .74, c - R * .74, c + R * .74, c + R * .74], fill=(255, 255, 255) if kind != "eggs" else (255, 240, 190))
    glyph(d, kind, c, c, R * (.56 if kind != "eggs" else .6), hue if kind != "eggs" else (236, 150, 30))
    layer = layer.resize((size, size), Image.LANCZOS)
    out = img.convert("RGBA")
    if ghost:                                              # bob echo: where the icon sits at the bottom of its float
        g = layer.copy()
        g.putalpha(g.split()[3].point(lambda v: int(v * .22)))
        out.alpha_composite(g, (int(xy[0] - size / 2), int(xy[1] - size / 2 + r * .42)))
    if alpha < 1:
        layer.putalpha(layer.split()[3].point(lambda v: int(v * alpha)))
    out.alpha_composite(layer, (int(xy[0] - size / 2), int(xy[1] - size / 2)))
    return out.convert("RGB")


def chevron(img, xy, w, hue):
    out = img.convert("RGBA")
    S = 3
    for k, a in ((-1.5, 60), (-0.75, 120), (0, 255)):       # two echoes above = the bounce path
        layer = Image.new("RGBA", (int(w * 3) * S, int(w * 3) * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        c = layer.size[0] / 2
        W = w * S
        pts = [(c - W, c - W * .45), (c - W * .55, c - W * .45), (c, c + W * .12), (c + W * .55, c - W * .45), (c + W, c - W * .45), (c, c + W * .62)]
        d.polygon(pts, fill=hue + (a,))
        d.line(pts + [pts[0]], fill=NAVY + (a,), width=max(3, int(W * .12)), joint="curve")
        layer = layer.resize((int(w * 3), int(w * 3)), Image.LANCZOS)
        out.alpha_composite(layer, (int(xy[0] - w * 1.5), int(xy[1] - w * 1.5 + k * w * .62)))
    return out.convert("RGB")


def sparkles(img, centre, spread, hue, light, seed, count=7):
    out = img.convert("RGBA")
    d = ImageDraw.Draw(out)
    for i in range(count):
        a = (i * 2.399 + seed) % math.tau
        rr = spread * (0.45 + 0.55 * ((i * 37 + seed * 11) % 10) / 10)
        x, y = centre[0] + math.cos(a) * rr, centre[1] - abs(math.sin(a)) * rr * 1.1
        sparkle(d, x, y, 5 + (i % 3) * 3, light + (235,) if i % 2 else (255, 255, 255, 240))
    return out.convert("RGB")


def treat(img, cam, key, level, small=False):
    """level 0 = learned/far (glow only), 1 = beckon (icon + shaft + ring), 2 = invite (+ arrow, ripple, sparkles)."""
    st = A[cam]["stations"][key]
    hue, light = HUES[key][0], HUES[key][1]
    pps = st["px_per_stud"]
    base, icon, top, sky = st["base"][:2], st["icon"][:2], st["top"][:2], st["sky"][:2]
    mid = (base[0], (base[1] + top[1]) / 2)
    img = glow(img, mid, pps * 3.2, light, 0.2 if level == 0 else 0.34)
    img = glow(img, base, pps * 5.4, hue, 0.3 if level == 0 else 0.55, squash=0.3)
    if not small:                                          # keep the icon inside the close-up frame
        icon = (icon[0], max(icon[1], pps * 1.25))
    if level >= 1:
        img = shaft(img, (top[0], top[1] + pps * .6), sky, pps * 1.0, pps * 2.0, light, 0.7 if level == 1 else 0.9)
        img = ring(img, st["ring"], base, hue, light, 0.8 if level == 1 else 1.0, ripple=level == 2)
        img = bubble(img, key, icon, pps * (1.25 if small else 1.0), hue, light)
    if level >= 2:
        img = chevron(img, (icon[0], icon[1] + pps * 1.75), pps * .52, hue)
        img = sparkles(img, (mid[0], mid[1]), pps * 3.4, hue, light, seed={"deck": 1, "eggs": 4, "care": 7}[key])
    return img


def label(img, text, xy=(18, 14), size=26, pad=10):
    d = ImageDraw.Draw(img, "RGBA")
    f = font(size, True)
    box = d.textbbox(xy, text, font=f)
    d.rounded_rectangle([box[0] - pad, box[1] - pad * .6, box[2] + pad, box[3] + pad * .8], radius=10, fill=NAVY + (225,))
    d.text(xy, text, font=f, fill=(255, 255, 255))
    return img


def station_sheet(key, number):
    base = Image.open(RAW / f"{key}-after.png").convert("RGB")
    hue, light, name, hue_name = HUES[key]
    main = label(treat(base.copy(), key, key, 2), f"{name}: Invite (within 14 studs, not used today)", xy=(18, base.size[1] - 52))
    W, H = base.size
    tw, th = 360, int(360 * H / W)
    sheet = Image.new("RGB", (W + tw + 36, H + 44), (247, 244, 236))
    sheet.paste(main, (0, 0))
    rows = [(0, "Learned / far: glow breath only"), (1, "Beckon, within 40 studs: icon + shaft + ring"),
            (2, "Invite, within 14 studs: + arrow, ripple, ping")]
    d = ImageDraw.Draw(sheet)
    y = 14
    for level, text in rows:
        thumb = treat(base.copy(), key, key, level).resize((tw, th), Image.LANCZOS)
        sheet.paste(thumb, (W + 18, y))
        d.text((W + 18, y + th + 4), text, font=font(17, True), fill=NAVY)
        y += th + 34
    d.rounded_rectangle([W + 18, y + 2, W + 18 + 26, y + 28], radius=6, fill=hue, outline=NAVY, width=2)
    d.text((W + 54, y + 2), f"station hue: {hue_name}", font=font(17), fill=NAVY)
    sheet.save(HERE / f"{number:02d}-attract-{key}.png")


def plan_map():
    """Top-down hub plan (Roblox X to the right, Z down): what leaves, what stays, where flowers go."""
    S, ox, oz = 13.0, -68, -38                      # pixels per stud; world origin of the top-left corner
    W, H = int(72 * S), int(74 * S)
    img = Image.new("RGB", (W, H), (126, 200, 106))
    d = ImageDraw.Draw(img, "RGBA")

    def P(x, z): return ((x - ox) * S, (z - oz) * S)

    def disc(x, z, r, fill, outline=None, width=2):
        cx, cy = P(x, z)
        d.ellipse([cx - r * S, cy - r * S, cx + r * S, cy + r * S], fill=fill, outline=outline, width=width)

    def text(x, z, s, size=15, fill=NAVY, bold=False, anchor="mm"):
        d.text(P(x, z), s, font=font(size, bold), fill=fill, anchor=anchor)

    disc(-30, -4, 15.5, (246, 241, 230), (200, 196, 186))
    disc(-30, -4, 11.2, None, (47, 183, 176), 3)
    disc(-30, 17, 7.5, (158, 222, 120), (110, 180, 90))
    text(-30, 17.5, "toy lawn", 15)
    disc(-36.1, -18, 5.2, (58, 150, 70, 140), (40, 110, 55))
    text(-36.1, -20.2, "Hatch Tree", 14, (255, 255, 255))
    for (x, z, r) in ((-46, -9.1, 4.6), (-17, -15, 4.6)):
        disc(x, z, r, (238, 234, 224), (200, 196, 186))
    stations = [(-46, -9, "deck", "Pocket Deck"), (-31, -11, "eggs", "Egg nest"), (-17, -15, "care", "Care cradle")]
    for x, z, key, name in stations:
        disc(x, z, 2.4, HUES[key][0] + (255,), NAVY, 3)
        text(x, z + 3.6, name, 16, NAVY, True)
    for x, z in ((-43, 5), (-17, 5)):
        cx, cy = P(x, z)
        d.rounded_rectangle([cx - 30, cy - 12, cx + 30, cy + 12], radius=5, fill=(170, 120, 70), outline=NAVY, width=2)
        text(x, z + 2.0, "bench", 13)
    keep = [(-48.8, -17.2, "col 02"), (-43.5, -22.6, "col 03"), (-36.7, -26.0, "col 04"), (-29.2, -27.0, "col 05")]
    for x, z, name in keep:
        disc(x, z, 1.4, (255, 255, 255), (150, 150, 150))
        text(x, z - 2.2, name, 12, (70, 80, 90))
    remove = [(-42, 9.5, "egg statue", "Plaza_Ornament_09"), (-18, 9.5, "egg statue", "Plaza_Ornament_10"),
              (-46.5, -17, "urn", "Plaza_Ornament_11"), (-13.5, 5, "urn", "Plaza_Ornament_12"),
              (-41.4, 16.4, "urn", "Stairs_Urn_18"), (-31.9, 23.8, "urn", "Stairs_Urn_19"),
              (-52.1, -10.3, "column + lintel span", "Colonnade_Column_01"), (-12.9, -19.4, "broken col", "Colonnade_Column_06"),
              (-8.7, -12.6, "broken col", "Colonnade_Column_07"), (-10.5, -18.2, "drum", "Colonnade_FallenDrum_08"),
              (-48, -22.1, "empty pad", "Pad_Future_A"), (-13, -3.9, "empty pad", "Pad_Future_B")]
    for x, z, kind, name in remove:
        cx, cy = P(x, z)
        r = 3.6 * S if "pad" in kind else 1.25 * S
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 150), outline=(214, 48, 64), width=3)
        d.line([cx - 11, cy - 11, cx + 11, cy + 11], fill=(214, 48, 64), width=4)
        d.line([cx - 11, cy + 11, cx + 11, cy - 11], fill=(214, 48, 64), width=4)
    for i, (x, z, kind, name) in enumerate(remove):
        cx, cy = P(x, z)
        d.ellipse([cx + 8, cy - 26, cx + 30, cy - 4], fill=(214, 48, 64), outline=(255, 255, 255), width=2)
        d.text((cx + 19, cy - 15), str(i + 1), font=font(13, True), fill=(255, 255, 255), anchor="mm")
    cols = {"D": (255, 255, 255), "T": (255, 111, 174), "L": (168, 139, 255), "Y": (255, 216, 74), "S": (53, 199, 245)}
    patches = [(-42, 9.5, 2.2, "DY"), (-18, 9.5, 2.2, "DT"), (-46.5, -17.5, 2.0, "SD"), (-13.5, 5.5, 2.0, "TL"), (-48, -22, 3.0, "SLD"),
               (-12.5, -4, 3.0, "TYD"), (-41.4, 16.4, 1.8, "YD"), (-33.5, 25, 1.8, "LD"), (-52.5, -5.5, 2.4, "SSD"), (-41.5, -15.5, 2.0, "SD"),
               (-36.5, -15.5, 1.8, "YD"), (-25.5, -15.5, 1.8, "YYD"), (-11.5, -19.5, 2.6, "TTL"), (-20, -21.5, 2.2, "TLD"), (-50, 5, 2.6, "DLY"),
               (-10.5, 12, 2.4, "DS"), (-38, 22, 2.4, "TD"), (-20, 22, 2.6, "YSD"), (-56, -14, 3.0, "LTD"), (-6, -9, 2.6, "YD"),
               (-27, 31, 3.0, "DTYSL"), (-14, 29, 2.6, "LD")]
    for i, (x, z, r, kinds) in enumerate(patches):
        for k in range(7):
            a = k * 2.399 + i
            rr = r * (0.25 + 0.7 * ((k * 5 + i) % 7) / 7)
            cx, cy = P(x + math.cos(a) * rr, z + math.sin(a) * rr)
            d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=cols[kinds[k % len(kinds)]], outline=(30, 90, 50), width=1)
    panel = Image.new("RGB", (W + 400, H), (247, 244, 236))
    panel.paste(img, (0, 0))
    d = ImageDraw.Draw(panel)
    x0 = W + 18
    d.text((x0, 16), "Hub declutter plan", font=font(22, True), fill=NAVY)
    d.text((x0, 46), "Top-down. Roblox X to the right, +Z down.", font=font(14), fill=NAVY)
    d.text((x0, 76), "Remove from the Blender world build:", font=font(15, True), fill=(150, 20, 40))
    y = 102
    for i, (x, z, kind, name) in enumerate(remove):
        d.ellipse([x0, y, x0 + 22, y + 22], fill=(214, 48, 64))
        d.text((x0 + 11, y + 11), str(i + 1), font=font(13, True), fill=(255, 255, 255), anchor="mm")
        d.text((x0 + 30, y - 2), name, font=font(14, True), fill=NAVY)
        d.text((x0 + 30, y + 16), f"{kind}, X {x:g}, Z {z:g}", font=font(13), fill=(70, 80, 100))
        y += 42
    y += 10
    d.text((x0, y), "Keep: columns 02-05 (frame the Hatch Tree),", font=font(14), fill=NAVY)
    d.text((x0, y + 20), "both benches, the toy lawn set, the lantern.", font=font(14), fill=NAVY)
    y += 56
    d.text((x0, y), "Sprite flowers: 22 patches, 112 sprites.", font=font(15, True), fill=NAVY)
    names = [("D", "daisy"), ("T", "tulip"), ("L", "bellflower"), ("Y", "buttercup"), ("S", "starbloom")]
    for k, (c, nm) in enumerate(names):
        d.ellipse([x0, y + 28 + k * 24, x0 + 16, y + 44 + k * 24], fill=cols[c], outline=(30, 90, 50))
        d.text((x0 + 26, y + 26 + k * 24), nm, font=font(14), fill=NAVY)
    y += 28 + 5 * 24 + 8
    d.text((x0, y), "Flowers beside a station echo its hue:", font=font(14), fill=NAVY)
    d.text((x0, y + 20), "aqua deck, gold eggs, pink care.", font=font(14), fill=NAVY)
    img = panel
    img.save(HERE / "09-declutter-plan-map.png")


def main():
    before = Image.open(RAW / "hub-before.png").convert("RGB")
    after = Image.open(RAW / "hub-after.png").convert("RGB")
    label(before.copy(), "BEFORE: today's hub (12 marble props crowd the three stations)").save(HERE / "02-hub-before.png")
    label(after.copy(), "AFTER: props thinned, retro sprite flowers (112 sprites)").save(HERE / "03-hub-after-declutter-flowers.png")
    beacons = after.copy()
    for key in ("deck", "eggs", "care"):
        beacons = treat(beacons, "hub", key, 1, small=True)
    label(beacons, "AFTER + attract: first visit, all three stations beckon").save(HERE / "04-hub-after-attract-beacons.png")
    comp = Image.new("RGB", (1600, 1800 + 12), (247, 244, 236))
    comp.paste(Image.open(HERE / "02-hub-before.png"), (0, 0))
    comp.paste(Image.open(HERE / "04-hub-after-attract-beacons.png"), (0, 912))
    comp.save(HERE / "05-hub-before-after-compare.png")
    for number, key in ((6, "deck"), (7, "eggs"), (8, "care")):
        station_sheet(key, number)
    plan_map()
    # The three attract icons as stand-alone 128 px transparent PNGs (BillboardGui images).
    (HERE / "sprites").mkdir(exist_ok=True)
    for key in ("deck", "eggs", "care"):
        blank = Image.new("RGB", (136, 136), (0, 0, 0))
        tile = Image.new("RGBA", (136, 136), (0, 0, 0, 0))
        on_black = bubble(blank, key, (68, 68), 40, HUES[key][0], HUES[key][1], ghost=False).convert("RGB")
        on_white = bubble(Image.new("RGB", (136, 136), (255, 255, 255)), key, (68, 68), 40, HUES[key][0], HUES[key][1], ghost=False)
        # Recover alpha from the black/white pair, then un-premultiply the colour.
        import numpy as np
        b = np.asarray(on_black, dtype=float); w = np.asarray(on_white, dtype=float)
        alpha = np.clip(1 - (w - b).mean(axis=2) / 255, 0, 1)
        rgbv = np.where(alpha[..., None] > 0.004, b / np.maximum(alpha[..., None], 0.004), 0)
        out = np.dstack([np.clip(rgbv, 0, 255), alpha * 255]).astype("uint8")
        tile = Image.fromarray(out, "RGBA").crop((4, 4, 132, 132))
        tile.save(HERE / "sprites" / f"attract_icon_{key}_128.png")
    print("mockups ->", HERE)


if __name__ == "__main__":
    main()
