"""Levels art data (V3-LEVELS-BUILD-PLAN "Art (Fable)"): writes artifacts/levels-2026-11-22/art.json
and a recolour and ball check sheet, recolours-contact.png.

Run: python scripts/build_level_art_json.py   (after build_level_faceplates.py; it imports its rows)
Data only: nothing here edits WearableVariants.lua, BallThemes.lua or DeckThemes.lua.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
OUT = ROOT / "artifacts" / "levels-2026-11-22"

BEAR, BUNNY = "#FFFFFF", "#F5A9BC"      # white Bear; the Bunny's rose is assumed here (no rose hex is in the rig data)
STAT = {"heart": "#FF86A8", "power": "#FF9D4D", "energy": "#6CCBFF", "jump": "#B9EE5A", "speed": "#8FA8FF", "smarts": "#E58CFF"}
BASE = {"beanie": "#E9574C", "sunhat": "#F3D37E", "flowercrown": "#58B368", "tee": "#33539E", "hoodie": "#8E7BE8", "beads": "#FFF2D6",
        "bellcollar": None, "blush": "#FF9FB2", "partyhat": "#45C2E0", "bowtail": "#F2596B", "bands": "#4FC3C8", "specs": "#FFC240"}
EXISTING = {"beanie": ["#7FE0CF", "#FFD86B", "#9B7BE8"], "tee": ["#D94A7A", "#3F8F6B", "#F08A3C"], "bellcollar": ["#DCE3EE", "#F2A0A8"], "sunhat": ["#A9764F", "#FFB38A"]}

# id, base, name, hex, gate, price, piece, reason
RECOLOURS = [
    ("specs_orchid", "specs", "Orchid Round Specs", "#B45CE6", {"stat": "smarts", "level": 10}, 40, None,
     "Smarts orchid taken deep, because the frames are thin and must hold on white fur."),
    ("beanie_rose", "beanie", "Rose Pom Beanie", "#EC4F8F", {"stat": "heart", "level": 15}, 40, None,
     "Heart pink pushed to a full rose: pinker than the red base, darker than the Bunny."),
    ("tee_sky", "tee", "Sky Stripy Tee", "#35B4F2", {"stat": "energy", "level": 15}, 40, None,
     "Energy sky on the cyan side, so it never reads as the Speed tee."),
    ("partyhat_lime", "partyhat", "Lime Party Hat", "#93D62E", {"stat": "jump", "level": 15}, 40, None,
     "Jump lime with more green in it, so the cone keeps its shape on white."),
    ("tee_periwinkle", "tee", "Periwinkle Stripy Tee", "#8A82F0", {"stat": "speed", "level": 15}, 40, None,
     "Speed periwinkle on the violet side: a clear step from Sky and from the navy base."),
    ("bands_tangerine", "bands", "Tangerine Friendship Bands", "#FF8A2E", {"stat": "power", "level": 20}, 40, None,
     "Power orange at full strength: the bands are tiny, so they get the loudest colour."),
    ("beads_orchid", "beads", "Orchid Pearl Beads", "#CF8DF2", {"stat": "smarts", "level": 20}, 40, None,
     "A paler, pearly orchid than the specs, so the two worn together look like a set."),
    ("bellcollar_blossom", "bellcollar", "Blossom Bell Collar", "#FF5C93", {"stat": "heart", "level": 30}, 100, "Neck_BellCollar_Bell",
     "Hot blossom pink bell: far stronger than the pale Rose bell, and it pops on the Bunny."),
    ("beanie_lime", "beanie", "Lime Pom Beanie", "#A4D93A", {"stat": "jump", "level": 30}, 40, None,
     "Yellower lime than the party hat and nothing like Mint: the Jump hat for cold days."),
    ("bowtail_periwinkle", "bowtail", "Periwinkle Bow Tail", "#7F92F5", {"stat": "speed", "level": 30}, 100, None,
     "The Speed colour a shade deeper, so the bow's folds still show."),
    ("blush_peach", "blush", "Peach Blush Stickers", "#FF8748", {"stat": "power", "level": 35}, 40, None,
     "Warm peach-orange cheeks: the hue is far enough from rose to show on the Bunny."),
    ("sunhat_sky", "sunhat", "Sky Sun Hat", "#5CBEF5", {"stat": "energy", "level": 35}, 100, None,
     "A softer sky than the tee for the big brim, still dark enough to edge against white."),
    ("hoodie_starbloom", "hoodie", "Starbloom Hoodie", "#2F2C7C", {"total": 150}, 250, None,
     "Midnight indigo, no stat's colour: the chest star becomes a star in a night sky."),
    ("flowercrown_golden", "flowercrown", "Golden Flower Crown", "#F0B429", {"total": 300}, 250, None,
     "Stars gold on the crown's main (leaf) colour: the top prize wears the wallet's colour."),
]

# Tangerine Pop (Power 10, 40 Stars): one orange in five strengths, tier I deepest. Redder and juicier than Amber,
# which runs brown to honey yellow; this one runs blood orange to peach cream. Same row shape as BallThemes.
TANGERINE = {
    "id": "tangerine_pop", "name": "Tangerine Pop", "tier": "common", "price": 40, "gate": {"stat": "power", "level": 10},
    "face": "happy", "texture": "none", "ink": "#2B0F04", "mono": True,
    "ramps": [
        {"body": "#D9440F", "deep": "#A32E08", "light": "#FF9360"},
        {"body": "#F05E18", "deep": "#BD4210", "light": "#FFAB74"},
        {"body": "#FF7A26", "deep": "#DB5814", "light": "#FFC08C"},
        {"body": "#FF9C52", "deep": "#EC772C", "light": "#FFD7B0"},
        {"body": "#FFC394", "deep": "#F59E5C", "light": "#FFF0E0"},
    ],
    "pitch": "Juicy orange, deep to bright.", "names": ["Pip", "Zest", "Juice", "Peach", "Fizz"],
}
AMBER = ["#B5541A", "#D4701F", "#EE8F2A", "#FFB347", "#FFD98A"]
LCD_WELL = "#10133A"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(h):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(h)
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return round((max(la, lb) + 0.05) / (min(la, lb) + 0.05), 2)


def lab(h):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in rgb(h))
    x, y, z = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047, 0.2126 * r + 0.7152 * g + 0.0722 * b, (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))


def delta(a, b):
    la, lb = lab(a), lab(b)
    return round(sum((la[i] - lb[i]) ** 2 for i in range(3)) ** 0.5, 1)


def recolour_rows():
    rows, used = [], {}
    for rid, base, name, hexv, gate, price, piece, reason in RECOLOURS:
        others = [c for c in [BASE[base]] + EXISTING.get(base, []) + used.get(base, []) if c]
        row = {"id": rid, "item": base, "name": name, "hex": hexv, "gate": gate, "price": price, "reason": reason,
               "check": {"deltaE_white_bear": delta(hexv, BEAR), "deltaE_rose_bunny": delta(hexv, BUNNY),
                         "contrast_white_bear": contrast(hexv, BEAR), "nearest_same_item_deltaE": min(delta(hexv, c) for c in others) if others else None}}
        if piece:
            row["piece"] = piece
        rows.append(row)
        used.setdefault(base, []).append(hexv)
    return rows


def sheet(rows):
    try:
        font, small = ImageFont.load_default(size=17), ImageFont.load_default(size=14)
    except TypeError:
        font = small = ImageFont.load_default()
    rh, W = 62, 1180
    H = 40 + len(rows) * rh + 250
    im = Image.new("RGB", (W, H), rgb("#FFF4DC"))
    d = ImageDraw.Draw(im)
    ink = rgb("#15143A")
    d.text((14, 10), "new colour on the white Bear, on the rose Bunny (assumed #F5A9BC)   |   base and live recolours of the same item   |   stat colour", fill=ink, font=small)
    for i, r in enumerate(rows):
        y = 40 + i * rh
        for k, fur in enumerate((BEAR, BUNNY)):
            x = 14 + k * 150
            d.rounded_rectangle([x, y, x + 140, y + rh - 8], 14, fill=rgb(fur), outline=ink, width=2)
            d.rounded_rectangle([x + 22, y + 10, x + 118, y + rh - 18], 12, fill=rgb(r["hex"]))             # a hat-sized patch
            d.ellipse([x + 6, y + 6, x + 18, y + 18], fill=rgb(r["hex"]))                                   # a bead-sized dot
            d.line([x + 122, y + 12, x + 134, y + 12], fill=rgb(r["hex"]), width=3)                         # a frame-thin line
        x = 330
        for c in [BASE[r["item"]]] + EXISTING.get(r["item"], []):
            if c:
                d.rounded_rectangle([x, y + 8, x + 40, y + rh - 16], 8, fill=rgb(c), outline=ink, width=1)
            x += 46
        gate = r["gate"]
        key = gate.get("stat")
        if key:
            d.ellipse([530, y + 12, 560, y + 42], fill=rgb(STAT[key]), outline=ink, width=2)
        label = f'{r["name"]}  {r["hex"]}  ' + (f'{key} {gate["level"]}' if key else f'total {gate["total"]}')
        d.text((575, y + 6), label, fill=ink, font=font)
        c = r["check"]
        d.text((575, y + 30), f'dE bear {c["deltaE_white_bear"]}  dE bunny {c["deltaE_rose_bunny"]}  nearest same item {c["nearest_same_item_deltaE"]}', fill=rgb("#4A4972"), font=small)
    # ball ramps on the LCD well: Tangerine Pop above Amber
    y0 = 40 + len(rows) * rh + 10
    d.rounded_rectangle([14, y0, W - 14, y0 + 226], 18, fill=rgb(LCD_WELL))
    radii = [18, 24, 31, 39, 48]
    for row_i, (label, ramps) in enumerate((("Tangerine Pop (new)", TANGERINE["ramps"]), ("Amber (live)", [{"body": b, "deep": b, "light": b} for b in AMBER]))):
        cy, x = y0 + 62 + row_i * 106, 250
        d.text((30, cy - 10), label, fill=(255, 255, 255), font=font)
        for t, rp in enumerate(ramps):
            r_ = radii[t]
            d.ellipse([x - r_, cy - r_, x + r_, cy + r_], fill=rgb(rp["deep"]))
            d.ellipse([x - r_ + 2, cy - r_ + 1, x + r_ - 2, cy + r_ - 5], fill=rgb(rp["body"]))
            d.ellipse([x - r_ * .55, cy - r_ * .70, x - r_ * .05, cy - r_ * .32], fill=rgb(rp["light"]))
            if row_i == 0:                                                                                 # the happy face in the theme ink
                e = max(2, r_ // 7)
                for sx in (-1, 1):
                    d.ellipse([x + sx * r_ * .32 - e, cy - e, x + sx * r_ * .32 + e, cy + e], fill=rgb(TANGERINE["ink"]))
                d.arc([x - r_ * .28, cy, x + r_ * .28, cy + r_ * .42], 20, 160, fill=rgb(TANGERINE["ink"]), width=max(2, r_ // 9))
            x += r_ * 2 + 46
    im.save(OUT / "recolours-contact.png")


def main():
    import build_level_faceplates as plates
    OUT.mkdir(parents=True, exist_ok=True)
    rows = recolour_rows()
    ball = dict(TANGERINE)
    ball["check"] = {"bodyLstar": [round(lab(r["body"])[0], 1) for r in TANGERINE["ramps"]], "amberBodyLstar": [round(lab(c)[0], 1) for c in AMBER],
                     "inkOnBody": [contrast(TANGERINE["ink"], r["body"]) for r in TANGERINE["ramps"]],
                     "bodyOnWell": [contrast(r["body"], LCD_WELL) for r in TANGERINE["ramps"]]}
    doc = {
        "schema": 1, "date": "2026-11-22", "by": "Fable (creative direction); values proposed, not yet in the catalogues",
        "notes": ["Recolour rows map to WearableVariants: {id, base=item, name, color=hex, price, piece?} plus gate.",
                  "Bunny rose is assumed #F5A9BC for the checks; every row still needs the render check on both rigs.",
                  "flowercrown_golden recolours the crown's main own colour (#58B368, the leaves); if the gold should land on the flowers it needs a `piece`."],
        "recolours": rows,
        "ballTheme": ball,
        "ballThemeLua": 'tangerine_pop={name="Tangerine Pop",tier="common",price=40,face="happy",texture="none",ink="#2B0F04",mono=true,\n  ramps={'
                        + ",".join('ramp("%s","%s","%s")' % (r["body"], r["deep"], r["light"]) for r in TANGERINE["ramps"])
                        + '},\n  pitch="Juicy orange, deep to bright.",names={"Pip","Zest","Juice","Peach","Fizz"}},',
        "faceplates": plates.rows(),
        "medals": {"files": "assets/ui/levels/medal-<25|50|75|99>-<tint|trim>.png", "size": 256, "centre": [128, 138], "wellRadius": 52, "iconSize": 92,
                   "use": "tint layer: ImageColor3 = stat colour (multiply). trim layer on top, untinted. Stat icon on top, centred on `centre`.",
                   "unearned": "tint layer coloured ToyShell wellDot, trim at 35% opacity, no icon",
                   "tiers": {"25": "disc", "50": "disc + cream ring", "75": "disc + cream ring + petal ring (the second ring)", "99": "the 75 medal + gold star and two sparkles"}},
    }
    (OUT / "art.json").write_text(json.dumps(doc, indent=1), encoding="utf-8", newline="\n")
    sheet(rows)
    for r in rows:
        print(r["id"], r["hex"], r["check"])
    print(ball["check"])


if __name__ == "__main__":
    main()
