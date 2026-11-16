"""Ground the Pet Park palette (QA v775 note 15): match the world's darker v735 palette.

  python scripts/build_park_grounded_palette.py

The park equipment is textured by one flat palette image (assets/park/palette-park.png, 8 x 8
swatches of 32 px; scripts/build_park_equipment.py). The v735 world pass
(build_world_v7_grounded_textures.py) took the world's marble to a mid-light grey, its grass
deeper and its wood and earth browner, and left the park at the old dusk values, so the park's
near-white kerb and posts and its neon green inlay glowed against the lawn around them.

This grades each swatch with the world pass's own numbers for the matching material (same hue
shift, saturation and value factors), so park marble equals world marble and so on. The swatch
layout and every UV stay as they are: only the image changes, so no mesh is re-exported.

Writes assets/park/palette-park-grounded.png and prints old -> new per slot. Upload it as an
Image and put the id in ParkPoseData.Texture and assets/park/park-import.json.
"""
from __future__ import annotations

import colorsys
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "park" / "palette-park.png"
OUT = ROOT / "assets" / "park" / "palette-park-grounded.png"
SIDE, PX = 8, 32

# Slot order of build_park_equipment.PALETTE (slot i: column i % 8, row i // 8 from the BOTTOM).
SLOTS = [
    "marble", "marble_d", "white", "wood", "wood_d", "wood_l", "pink", "pink_d",
    "mint", "mint_d", "aqua", "aqua_d", "lilac", "lilac_d", "butter", "butter_d",
    "gold", "sand", "sand_d", "sand_w", "leaf", "leaf_d", "rope", "red",
    "glow", "sand_c", "sand_k",
]
# family: hue shift (degrees), saturation x, value x, multiply tint. The first three rows are
# the world pass's GRADE rows for W1_marble, W1_grass and W1_wood_plank; `toy` is its W1_trim
# row (painted props drop one step); `sand` sits between trim and the dirt path, because the
# sandbox is sand, not earth; `glow` is the gate orb's light and is not graded.
GRADE = {
    "marble": (0, 0.45, 0.75, (0.985, 0.99, 1.0)),
    "leaf": (4, 0.80, 0.70, (1.0, 1.0, 1.0)),
    "wood": (-2, 0.88, 0.78, (1.0, 1.0, 1.0)),
    "sand": (-4, 0.95, 0.78, (1.0, 0.98, 0.95)),
    "toy": (0, 0.92, 0.86, (0.99, 0.99, 1.0)),
    "glow": (0, 1.0, 1.0, (1.0, 1.0, 1.0)),
}
FAMILY = {
    "marble": "marble", "marble_d": "marble", "white": "marble", "rope": "marble",
    "leaf": "leaf", "leaf_d": "leaf",
    "wood": "wood", "wood_d": "wood", "wood_l": "wood",
    "sand": "sand", "sand_d": "sand", "sand_w": "sand", "sand_c": "sand", "sand_k": "sand",
    "glow": "glow",
}


def grade(rgb, family):
    hue, sat, val, tint = GRADE[family]
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    h = (h + hue / 360) % 1
    r, g, b = colorsys.hsv_to_rgb(h, min(1, s * sat), min(1, v * val))
    return tuple(max(0, min(255, round(c * 255 * t))) for c, t in zip((r, g, b), tint))


def main():
    src = Image.open(SRC).convert("RGB")
    assert src.size == (SIDE * PX, SIDE * PX), src.size
    out = Image.new("RGB", src.size)
    report = {}
    for slot in range(SIDE * SIDE):
        col, row = slot % SIDE, slot // SIDE
        x, y = col * PX, (SIDE - 1 - row) * PX  # row 0 is the bottom row of the image
        old = src.getpixel((x + PX // 2, y + PX // 2))
        name = SLOTS[slot] if slot < len(SLOTS) else None
        # Unused slots are the neutral marble fill (stray UVs read as trim): they follow marble.
        new = grade(old, FAMILY.get(name, "toy") if name else "marble")
        out.paste(new, (x, y, x + PX, y + PX))
        if name:
            report[name] = {"old": "#%02X%02X%02X" % old, "new": "#%02X%02X%02X" % new}
    out.save(OUT)
    for name, pair in report.items():
        print(f"{name:9s} {pair['old']} -> {pair['new']}")
    print(json.dumps({"written": str(OUT.relative_to(ROOT)).replace("\\", "/")}))


if __name__ == "__main__":
    main()
