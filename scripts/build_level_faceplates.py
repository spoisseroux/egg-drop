"""Level-gated Pocket Deck faceplates (V3-SCOPE 2.1): Sky Fizz (Energy 10, 40 Stars) and Storm Glass (Energy 30, 100 Stars).

Run: python scripts/build_level_faceplates.py
Writes assets/deck/faceplates/sky_fizz.png and storm_glass.png (1024 x 499, rounded alpha baked, the
same format as the other plates) and artifacts/levels-2026-11-22/faceplates-contact.png.
`rows()` returns the catalogue data (accent, deep, `ui`, `toyShell`, overlay, held3d) that
scripts/build_level_art_json.py writes into art.json; nothing here edits faceplates.json or DeckThemes.lua.

The drawing helpers are the shipped ones from scripts/deck_art/build_faceplates.py, so the gloss,
bubbles, shell depth and rim match the Aero plates of 2026-11-21. Seeded numpy only; original art.
"""
from __future__ import annotations

import colorsys
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "deck_art"))

import build_faceplates as bf                                    # noqa: E402
from build_faceplates import (ASPECT, GH, GW, X, XA, Y, aero_shell, blob, bubbles, fbm, finish, glass_band,   # noqa: E402
                              over, ramp3, rim_light, screen, smooth)
from common import contrast, hx, to_hex, ui_theme                # noqa: E402

OUT = ROOT / "assets" / "deck" / "faceplates"
SHEET = ROOT / "artifacts" / "levels-2026-11-22"


def stream(seed, x0, n, y_lo=1.02, y_hi=0.06, rmin=0.006, rmax=0.030, sway=0.030):
    """One fizz stream: bubbles rising from the bottom edge, small and close low down, bigger and further apart as they climb."""
    rng = np.random.default_rng(seed)
    out, y = [], y_lo
    ph = rng.random() * 6.28
    for k in range(n):
        t = k / max(1, n - 1)
        r = rmin + (rmax - rmin) * t ** 1.5 * (0.75 + 0.5 * rng.random())
        y -= r * (2.1 + 1.2 * rng.random())
        if y < y_hi:
            break
        out.append(((x0 + sway * math.sin(ph + y * 9.0) + (rng.random() - .5) * 0.012) * ASPECT, y, r))
    return out


def sky_fizz():
    """Sky Fizz: a glass of sky soda. A soft sun top right, sky to deep blue away from it, fizz streams up both grips, a few pink lemonade bubbles."""
    sun = (0.845 * ASPECT, 0.060)
    d = np.sqrt((XA - sun[0]) ** 2 + (Y - sun[1]) ** 2 * 1.25)
    img = ramp3(d / 1.75, [(0, "#FFFFFF"), (0.05, "#E6F9FF"), (0.15, "#A4E2FF"), (0.40, "#52B8FA"), (0.74, "#2286EA"), (1, "#1560CC")])
    ang = np.arctan2(Y - sun[1], XA - sun[0])
    rays = (0.5 + 0.5 * np.cos(ang * 11 + 0.6)) ** 3 * smooth(1.25, 0.10, d) * smooth(0.02, 0.20, d)   # soft sunbeams, wide and few
    img = screen(img, "#EAFBFF", rays * 0.26)
    img = over(img, "#FFFFFF", blob(sun[0], sun[1], 0.14, 1.6) * 0.95)
    img = over(img, "#C9F6FF", blob(0.10 * ASPECT, 1.10, 0.55, 1.5) * 0.40)                         # cyan pooling low left
    items = []
    for i, (x0, n) in enumerate(((0.040, 15), (0.105, 17), (0.175, 14), (0.825, 14), (0.895, 17), (0.960, 15))):
        items += stream(2210 + i * 7, x0, n, rmin=0.009, rmax=0.050, sway=0.022)
    for i, x0 in enumerate((0.30, 0.42, 0.55, 0.68)):                                               # low fizz along the bottom strip
        items += stream(2290 + i * 5, x0, 6, y_hi=0.87, rmin=0.008, rmax=0.020)
    keep = []
    for it in sorted(items, key=lambda b: -b[2]):
        if all(math.hypot(it[0] - a, it[1] - b) > (it[2] + c) * 1.02 for a, b, c in keep):
            keep.append(it)
    rng = np.random.default_rng(2222)
    pink = [b for b in keep if b[2] > 0.020 and rng.random() < 0.22]
    for b in keep:                                                                                   # a faint blue body, so a bubble still reads in the sun's glow
        img = over(img, "#1E7BE0", smooth(1.0, 0.80, np.sqrt((XA - b[0]) ** 2 + (Y - b[1]) ** 2) / b[2]) * 0.16)
    img = bubbles(img, [b for b in keep if b not in pink], "#FFFFFF")
    for b in pink:
        img = over(img, "#FF9CD2", smooth(1.0, 0.90, np.sqrt((XA - b[0]) ** 2 + (Y - b[1]) ** 2) / b[2]) * 0.34)
    img = bubbles(img, pink, "#FFE3F3")
    img = aero_shell(img, "#0F54C4", 0.36)
    img = glass_band(img, 0.52, 0.18, 0.34, 0.06)
    return finish(rim_light(img), 0.03)


def rain(seed, angle_deg=14, density=0.045):
    """Fine rain on the glass: sparse short streaks leaning a little, each a thin soft line."""
    rng = np.random.default_rng(seed)
    a = math.radians(angle_deg)
    u = XA * math.cos(a) - Y * math.sin(a)                       # across the streaks
    v = XA * math.sin(a) + Y * math.cos(a)                       # along them
    cols, rows = 420, 9
    ci = np.clip(((u + 0.5) / (ASPECT + 1.0) * cols), 0, cols - 1)
    col = ci.astype(np.int32)
    off = rng.random(cols).astype(np.float32)[col]
    on = (rng.random((rows + 2, cols)) < density).astype(np.float32)
    ri = v * rows + off
    row = np.clip(ri.astype(np.int32), 0, rows + 1)
    cell = on[row, col]
    frac_u = ci - col
    frac_v = ri - np.floor(ri)
    line = np.exp(-((frac_u - 0.5) / 0.16) ** 2) * smooth(0.0, 0.25, frac_v) * smooth(1.0, 0.55, frac_v)
    return cell * line


def storm_glass():
    """Storm Glass: deep blue-grey glass. Slow cloud inside, one soft light breaking through top left, beaded rain on the grips."""
    t = np.clip(Y * 0.80 + X * 0.20, 0, 1)
    img = ramp3(t, [(0, "#6C84AC"), (0.30, "#475C82"), (0.66, "#2B3A5A"), (1, "#172038")])
    c1, c2 = fbm(2.2, 3301, 4), fbm(4.0, 3317, 3)
    img = over(img, "#A9BEDF", smooth(0.50, 0.78, c1) * 0.34 * smooth(0.95, 0.15, Y))               # paler cloud tops high up
    img = over(img, "#0E1528", smooth(0.52, 0.22, c2) * 0.42)                                        # heavy cloud bellies
    glow = (0.215 * ASPECT, 0.150)
    img = over(img, "#B8A6FF", blob(glow[0], glow[1], 0.62, 1.8) * 0.26 * (0.6 + 0.4 * c1))          # lilac halo, broken by the cloud
    img = screen(img, "#DCEBFF", blob(glow[0], glow[1], 0.40, 1.5) * 0.70 * (0.55 + 0.45 * c1))
    img = over(img, "#FFFFFF", blob(glow[0], glow[1], 0.13, 1.7) * 0.72)
    img = screen(img, "#7FA8E8", blob(0.86 * ASPECT, 1.08, 0.50, 1.6) * 0.34)                        # cool bounce low right
    img = over(img, "#DDE9FF", np.clip(rain(3331) + rain(3347, 14, 0.03) * 0.7, 0, 1) * 0.20)
    rng = np.random.default_rng(3359)
    drops, tries = [], 0
    while len(drops) < 54 and tries < 8000:
        tries += 1
        x, y = rng.random() * ASPECT, rng.random()
        r = 0.009 + 0.040 * rng.random() ** 2.4
        hidden = 0.24 * ASPECT < x < 0.76 * ASPECT and 0.10 < y < 0.90
        near_glow = math.hypot(x - glow[0], y - glow[1]) < 0.16
        if (hidden and rng.random() < 0.88) or near_glow:
            continue
        if all(math.hypot(x - a, y - b) > (r + c) * 1.25 for a, b, c in drops):
            drops.append((x, y, r))
    for x, y, r in drops:                                                                            # each bead darkens the glass under it, so it sits on the surface
        img = over(img, "#0B1122", smooth(1.0, 0.55, np.sqrt((XA - x) ** 2 + (Y - y - r * 0.18) ** 2) / (r * 1.12)) * 0.34)
    img = bubbles(img, drops, "#CFE0FF")
    img = aero_shell(img, "#0A1020", 0.46, 0.18)
    img = glass_band(img, 0.30, 0.07, 0.34, 0.06)
    return finish(rim_light(img, "#D6E6FF", 0.80), 0.05)


# ------------------------------------------------------------------ catalogue rows
# Toy Shell roles, solved to the same WCAG luminances as artifacts/v2-ui-restyle-2026-11-19/build_revision1.py.
L = dict(shell=.131, shellHi=.36, shellLip=.042, tray=.058, well=.0105, wellDot=.040, ink=.009, inkSoft=.080, onShellSoft=.80)


def _rgb(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def _hex(t):
    return "#%02X%02X%02X" % tuple(int(round(v)) for v in t)


def _lum(c):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = _rgb(c)
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def _hsv(h, s, v):
    return _hex([x * 255 for x in colorsys.hsv_to_rgb((h % 360) / 360, s, v)])


def solve(h, s, target):
    while _lum(_hsv(h, s, 1)) < target and s > 0:
        s = max(0, s - .02)
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if _lum(_hsv(h, s, mid)) < target:
            lo = mid
        else:
            hi = mid
    return _hsv(h, s, hi)


def _mix(a, b, t):
    a, b = _rgb(a), _rgb(b)
    return _hex([a[i] + (b[i] - a[i]) * t for i in range(3)])


def toy_shell(h, s, tag):
    wh = 222 if 140 <= h <= 200 else h
    p = dict(shell=solve(h, s, L["shell"]), shellHi=solve(h, s * .55, L["shellHi"]), shellLip=solve(h, min(1, s * 1.05), L["shellLip"]),
             tray=solve(h, min(1, s * 1.02), L["tray"]), well=solve(wh, .70, L["well"]), wellDot=solve(wh, .58, L["wellDot"]),
             ink=solve(h, .62, L["ink"]), inkSoft=solve(h, .40, L["inkSoft"]), onShellSoft=solve(h, .14, L["onShellSoft"]), tag=tag)
    p["tagLip"] = _mix(tag, p["ink"], .38)
    return p


# id, name, fn, tier, price, gate, accent, deep, band, engrave, finish, material, overlay, (shell hue, shell saturation, tag), note
PLATES = [
    ("sky_fizz", "Sky Fizz", sky_fizz, "common", 40, {"stat": "energy", "level": 10}, "#7FDCFF", "#1766D2", ("silver", "#FFFFFF"), ("#0E0F12", 0.42),
     "sky soda glass, sun and fizz", "Glass", ("gloss", 0.0, 0.45, 4.5), (199, .84, "#FFB3DA"),
     "shell sits between Creek (192) and Aqua Pop (205); pink lemonade tag, picked up by the pink bubbles"),
    ("storm_glass", "Storm Glass", storm_glass, "rare", 100, {"stat": "energy", "level": 30}, "#A9C4F2", "#22304E", ("gunmetal", "#6F7480"), ("#FFFFFF", 0.78),
     "deep storm glass, soft light and rain beads", "Glass", ("water", 0.08, 0.45, 6.0), (220, .58, "#C4B5FF"),
     "slate blue shell, more colour than Liquid Chrome (218, .40); lilac tag from the light's halo"),
]
OVERLAY_FILE = bf.OVERLAY_FILE
OVERLAY_ASSET = {"gloss": "rbxassetid://114031715260538", "water": "rbxassetid://105339906963951"}


def rows(first_order=24):
    out = []
    for i, (pid, name, fn, tier, price, gate, accent, deep, band, engrave, fin, mat, ov, shell, note) in enumerate(PLATES):
        th = ui_theme(accent, deep)
        toy = toy_shell(*shell)
        out.append({
            "id": pid, "name": name, "order": first_order + i, "tier": tier, "priceStars": price, "gate": gate,
            "texture": f"assets/deck/faceplates/{pid}.png", "textureAssetId": None, "finish": fin,
            "accent": accent, "ink": to_hex(th["ink"]), "accentInkContrast": round(contrast(hx(accent), th["ink"]), 2),
            "deep": deep, "band": {"name": band[0], "tint": band[1]}, "engrave": {"color": engrave[0], "opacity": engrave[1]},
            "ui": {k: to_hex(th[k]) for k in ("panel", "raised", "well", "selected", "line")},
            "toyShell": toy,
            "toyShellSource": {"hue": shell[0], "saturation": shell[1], "note": note},
            "toyShellContrast": {"white/shell": round(contrast(hx("#FFFFFF"), hx(toy["shell"])), 2), "ink/tag": round(contrast(hx(toy["ink"]), hx(toy["tag"])), 2),
                                 "ink/cream": round(contrast(hx(toy["ink"]), hx("#FFF4DC")), 2), "lemon/shell": round(contrast(hx("#FFE14D"), hx(toy["shell"])), 2)},
            "overlay": {"texture": OVERLAY_FILE[ov[0]], "image": OVERLAY_ASSET[ov[0]], "kind": ov[0], "min": ov[1], "max": ov[2], "period": ov[3]},
            "held3d": {"material": mat, "reflectance": 0.08, "transparency": 0.25 if mat == "Glass" else 0},
        })
    return out


def contact():
    try:
        font = ImageFont.load_default(size=22)
    except TypeError:
        font = ImageFont.load_default()
    names = [("sky_fizz", "Sky Fizz (new)"), ("cloud_glass", "Cloud Glass (existing)"), ("storm_glass", "Storm Glass (new)"), ("liquid_chrome", "Liquid Chrome (existing)"),
             ("aqua_pop", "Aqua Pop (existing)"), ("tidepool", "Tidepool (existing)")]
    w, h, pad, lab = 760, 370, 22, 34
    cols = 2
    rws = (len(names) + 1) // 2
    sheet = Image.new("RGBA", (pad + cols * (w + pad), pad + rws * (h + lab + pad) + (h + lab + pad)), (30, 32, 44, 255))
    d = ImageDraw.Draw(sheet)
    for i, (pid, label) in enumerate(names):
        x, y = pad + (i % cols) * (w + pad), pad + (i // cols) * (h + lab + pad)
        im = Image.open(OUT / f"{pid}.png").convert("RGBA").resize((w, h), Image.LANCZOS)
        sheet.alpha_composite(im, (x, y))
        d.text((x + 4, y + h + 6), label, fill=(240, 240, 246), font=font)
    # in use: the screen glass hides the middle, so only the grips and the top and bottom strips show
    y = pad + rws * (h + lab + pad)
    for i, pid in enumerate(("sky_fizz", "storm_glass")):
        x = pad + i * (w + pad)
        im = Image.open(OUT / f"{pid}.png").convert("RGBA").resize((w, h), Image.LANCZOS)
        ImageDraw.Draw(im).rounded_rectangle([w * .24, h * .10, w * .76, h * .90], 22, fill=(14, 18, 34, 255), outline=(255, 255, 255, 70), width=2)
        sheet.alpha_composite(im, (x, y))
        d.text((x + 4, y + h + 6), f"{pid}: with the screen area covered (approximate)", fill=(240, 240, 246), font=font)
    SHEET.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(SHEET / "faceplates-contact.png")


def main():
    for pid, _name, fn, *_ in PLATES:
        fn().save(OUT / f"{pid}.png")
        print("plate", pid)
    contact()
    assert toy_shell(205, .92, "#6FE3FF")["shell"] == "#0E69AB", "toyShell solver drifted from Aqua Pop's shipped row"
    for r in rows():
        print(r["id"], r["ui"], r["toyShell"], r["toyShellContrast"])


if __name__ == "__main__":
    main()
