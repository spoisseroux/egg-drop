"""Level medals (V3-SCOPE 3.1): Sprout 25, Bloom 50, Full Bloom 75, Starbloom 99.

Run: python scripts/build_level_medals.py
Writes assets/ui/levels/medal-<25|50|75|99>-tint.png and -trim.png (256 px, transparent) and
artifacts/levels-2026-11-22/medals-contact.png. All art is drawn from coordinates (PIL, numpy); no
random numbers, no outside art, no AI art.

Two layers per tier, same registration on every tier (disc centre 128,138; well radius 52):
  -tint  white and grey only. Set ImageColor3 to the stat colour (it multiplies): the grey is the lip.
  -trim  drawn on top, never tinted: ink outlines, the cream well the stat icon sits in, the cream
         ring (50+), the gold star and sparkles (99), the gloss.
The stat icon (assets/ui/stat-icons/icon-<stat>-128.png) goes on top, centred on 128,138, about 92 px.
An unearned slot is the same pair with the tint layer coloured dark and the trim at about 35% opacity.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui" / "levels"
SHEET = ROOT / "artifacts" / "levels-2026-11-22"
ICONS = ROOT / "assets" / "ui" / "stat-icons"

N, SS = 256, 4
G = N * SS
CX, CY = 128, 138
INK, CREAM, CREAM_LIP = "#15143A", "#FFF4DC", "#D6C196"          # stat-icon ink; DeckThemes.ToyFixed cream
GOLD, GOLD_HI, GOLD_LIP = "#FFC14D", "#FFE14D", "#D9A31C"         # ToyFixed stars / selected / selectedLip
STATS = [("heart", "#FF86A8"), ("power", "#FF9D4D"), ("energy", "#6CCBFF"), ("jump", "#B9EE5A"), ("speed", "#8FA8FF"), ("smarts", "#E58CFF")]
TIERS = [(25, "Sprout"), (50, "Bloom"), (75, "Full Bloom"), (99, "Starbloom")]

R_WELL, R_DISC, OUTLINE = 52, 70, 6          # cream well, tinted disc, ink width
R_RING = 86                                  # cream ring outer radius (50+)
PETALS, R_PETAL_AT, R_PETAL = 12, 93, 16     # scalloped petal ring (75+)
STAR_C, STAR_R = (128, 37), 25               # star on top (99)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mask(draw_fn):
    m = Image.new("L", (G, G), 0)
    draw_fn(ImageDraw.Draw(m))
    return np.asarray(m, dtype=np.float32) / 255


def circle(cx, cy, r):
    return mask(lambda d: d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=255))


def petals(r):
    def fn(d):
        for k in range(PETALS):
            a = math.radians(k * 360 / PETALS + 15)     # no petal dead centre at the top: the star sits between two
            x, y = CX + R_PETAL_AT * math.sin(a), CY - R_PETAL_AT * math.cos(a)
            d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=255)
    return mask(fn)


def star(cx, cy, r, fat, inner=0.54):
    """Chunky five-point star: the polygon plus a round-jointed stroke of width `fat`, so every corner is soft."""
    pts = []
    for k in range(10):
        a = math.radians(-90 + k * 36)
        rr = r if k % 2 == 0 else r * inner
        pts.append(((cx + rr * math.cos(a)) * SS, (cy + rr * math.sin(a)) * SS))

    def fn(d):
        d.polygon(pts, fill=255)
        d.line(pts + pts[:2], fill=255, width=int(fat * SS), joint="curve")
        for x, y in pts:
            d.ellipse([x - fat * SS / 2, y - fat * SS / 2, x + fat * SS / 2, y + fat * SS / 2], fill=255)
    return mask(fn)


def sparkle(cx, cy, r, grow=0.0):
    """Four-point twinkle with pinched sides."""
    pts = []
    for k in range(8):
        a = math.radians(k * 45)
        rr = (r + grow) if k % 2 == 0 else (r * 0.34 + grow)
        pts.append(((cx + rr * math.sin(a)) * SS, (cy - rr * math.cos(a)) * SS))
    return mask(lambda d: d.polygon(pts, fill=255))


class Layer:
    def __init__(self):
        self.a = np.zeros((G, G, 4), dtype=np.float32)

    def paint(self, m, color, alpha=1.0):
        c = np.array(rgb(color), dtype=np.float32) / 255 if isinstance(color, str) else np.array([color] * 3, dtype=np.float32)
        m = m * alpha
        oa = self.a[..., 3]
        na = m + oa * (1 - m)
        for i in range(3):
            self.a[..., i] = np.where(na > 1e-6, (c[i] * m + self.a[..., i] * oa * (1 - m)) / np.maximum(na, 1e-6), 0)
        self.a[..., 3] = na

    def erase(self, m):
        self.a[..., 3] *= 1 - m

    def image(self):
        im = Image.fromarray((np.clip(self.a, 0, 1) * 255 + .5).astype(np.uint8), "RGBA")
        return im.resize((N, N), Image.LANCZOS)


def soft(m, px):
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(px * SS)), dtype=np.float32) / 255


def build(tier):
    tint, trim = Layer(), Layer()
    disc = circle(CX, CY, R_DISC)
    # ---- tint layer: white body, grey lip low, a soft top light. Shapes run 2 px under the ink.
    if tier >= 75:
        p = petals(R_PETAL + 2)
        tint.paint(p, 0.80)
        tint.paint(petals(R_PETAL + 2) * np.roll(petals(R_PETAL - 1), -3 * SS, axis=0), 1.0)      # each petal lit from above
    tint.paint(circle(CX, CY, R_DISC + 2), 0.74)
    tint.paint(circle(CX, CY, R_DISC + 2) * circle(CX, CY - 6, R_DISC + 1), 1.0)
    # ---- trim layer, bottom to top; tinted areas are cut out so the layer below shows.
    if tier >= 75:
        trim.paint(petals(R_PETAL + OUTLINE), INK)
        trim.erase(petals(R_PETAL))
    if tier >= 50:
        trim.paint(circle(CX, CY, R_RING + OUTLINE), INK)
        ring = circle(CX, CY, R_RING)
        trim.paint(ring, CREAM_LIP)
        trim.paint(ring * circle(CX, CY - 4, R_RING - 1), CREAM)
    trim.paint(circle(CX, CY, R_DISC + OUTLINE), INK)
    trim.erase(disc)
    # gloss on the tinted rim: one fat arc top left, one dot
    rim = disc * (1 - circle(CX, CY, R_WELL + OUTLINE - 1))
    arc = circle(CX, CY, R_DISC - 4) * (1 - circle(CX, CY, R_DISC - 10))
    yy, xx = np.mgrid[0:G, 0:G].astype(np.float32) / SS
    ang = np.degrees(np.arctan2(xx - CX, -(yy - CY)))                                              # 0 = up, clockwise
    trim.paint(soft(arc * ((ang > -62) & (ang < -18)), 0.6) * rim, "#FFFFFF", 0.80)
    trim.paint(soft(arc * ((ang > -10) & (ang < -2)), 0.6) * rim, "#FFFFFF", 0.80)
    # the cream well the icon sits in: ink line, cream, a pressed-in shadow along the top
    trim.paint(circle(CX, CY, R_WELL + OUTLINE - 1), INK)
    well = circle(CX, CY, R_WELL)
    trim.paint(well, CREAM_LIP)
    trim.paint(well * circle(CX, CY + 5, R_WELL), CREAM)
    if tier >= 99:
        sx, sy = STAR_C
        trim.paint(star(sx, sy, STAR_R, 7 + OUTLINE * 2), INK)
        body = star(sx, sy, STAR_R, 7)
        trim.paint(body, GOLD_LIP)
        trim.paint(body * np.roll(body, -4 * SS, axis=0), GOLD)
        trim.paint(star(sx, sy - 3, STAR_R * 0.50, 3) * body, GOLD_HI)
        trim.paint(soft(circle(sx - 8, sy - 7, 3.2), 0.4) * body, "#FFFFFF", 0.9)
        for (x, y, r) in ((40, 62, 13), (218, 70, 10)):
            trim.paint(sparkle(x, y, r, 4.5), INK)
            trim.paint(sparkle(x, y, r), CREAM)
    return tint.image(), trim.image()


def compose(tint, trim, color, icon=None):
    c = np.array(rgb(color), dtype=np.float32) / 255
    t = np.asarray(tint, dtype=np.float32) / 255
    t[..., :3] *= c
    im = Image.fromarray((t * 255 + .5).astype(np.uint8), "RGBA")
    im = Image.alpha_composite(im, trim)
    if icon is not None:
        ic = icon.resize((92, 92), Image.LANCZOS)
        im.alpha_composite(ic, (CX - 46, CY - 46))
    return im


def contact(layers):
    try:
        font = ImageFont.load_default(size=18)
    except TypeError:
        font = ImageFont.load_default()
    cell, pad, left, top = 200, 14, 150, 44
    cols = [("neutral", "#FFFFFF")] + STATS + [("unearned", "#2A2F6B")]
    Wd = left + len(cols) * (cell + pad) + pad
    Hd = top + len(TIERS) * (cell + pad) + pad + 150
    sheet = Image.new("RGBA", (Wd, Hd), rgb("#1D36A6") + (255,))
    d = ImageDraw.Draw(sheet)
    d.rectangle([0, 0, Wd, top + 2 * (cell + pad) + pad // 2], fill=rgb(CREAM))                     # top half on cream, bottom on tray
    icons = {}
    for sid, _ in STATS:
        p = ICONS / f"icon-{sid}-128.png"
        icons[sid] = Image.open(p).convert("RGBA") if p.exists() else None
    for c, (sid, col) in enumerate(cols):
        d.text((left + c * (cell + pad) + 8, 12), sid, fill=rgb(INK), font=font)
    for r, (tier, name) in enumerate(TIERS):
        y = top + r * (cell + pad)
        d.text((12, y + cell // 2 - 20), f"{tier}", fill=rgb(INK) if r < 2 else (255, 255, 255), font=font)
        d.text((12, y + cell // 2 + 2), name, fill=rgb(INK) if r < 2 else (255, 255, 255), font=font)
        tint, trim = layers[tier]
        for c, (sid, col) in enumerate(cols):
            tr = trim
            if sid == "unearned":
                a = np.asarray(trim, dtype=np.float32).copy()
                a[..., 3] *= 0.35
                tr = Image.fromarray(a.astype(np.uint8), "RGBA")
            im = compose(tint, tr, col, icons.get(sid)).resize((cell, cell), Image.LANCZOS)
            sheet.alpha_composite(im, (left + c * (cell + pad), y))
    # slot size check: six stats x four tiers at 48 px and 32 px on the tray colour
    y = top + len(TIERS) * (cell + pad) + 16
    d.text((12, y + 14), "48 px", fill=(255, 255, 255), font=font)
    d.text((12, y + 78), "32 px", fill=(255, 255, 255), font=font)
    x = left
    for tier, _ in TIERS:
        tint, trim = layers[tier]
        for sid, col in STATS:
            im = compose(tint, trim, col, icons.get(sid))
            sheet.alpha_composite(im.resize((48, 48), Image.LANCZOS), (x, y))
            sheet.alpha_composite(im.resize((32, 32), Image.LANCZOS), (x + 8, y + 68))
            x += 56
        x += 20
    SHEET.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(SHEET / "medals-contact.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    layers = {}
    for tier, _ in TIERS:
        tint, trim = build(tier)
        tint.save(OUT / f"medal-{tier}-tint.png")
        trim.save(OUT / f"medal-{tier}-trim.png")
        layers[tier] = (tint, trim)
        print("medal", tier, tint.size)
    contact(layers)


if __name__ == "__main__":
    main()
