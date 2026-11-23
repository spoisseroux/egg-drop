"""WORLD-PLAN-2026-11-22 slice 9: the world palette at saturation 1.0 for the Aero look.

build_world_v7_assets.py bakes palette-roblox.png with PALETTE_SATURATION 1.1 (a dusk grade: the warm haze greyed the
props). Under the Aero day light that push is no longer wanted, but the island's palette is bound to the native
collision checkpoint, so the Aero look swaps in this map at runtime instead (WorldAero.Surfaces.palette, AeroWorld's
records put the original back). Same swatch layout: slot i at column i % side, row i // side from the bottom.

    python scripts/draw_aero_palette.py          write assets/world/textures/aero/palette-aero.png
    python scripts/draw_aero_palette.py --check  fail when the committed file differs
"""
import colorsys
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "assets" / "world"
OUT = WORLD / "textures" / "aero" / "palette-aero.png"
SATURATION = 1.0


def draw(saturation=SATURATION):
    pal = json.loads((WORLD / "world-v7-palette.json").read_text())
    side, px = pal["side"], pal["px"]
    img = Image.new("RGB", (side * px, side * px), (255, 0, 255))
    for i, name in enumerate(pal["order"]):
        h, sat, val = colorsys.rgb_to_hsv(*pal["srgb"][name])
        if sat > 0.25:
            sat = min(1.0, sat * saturation)
        c = tuple(round(v * 255) for v in colorsys.hsv_to_rgb(h, sat, val))
        sx, sy = i % side, side - 1 - i // side
        for y in range(sy * px, sy * px + px):
            for x in range(sx * px, sx * px + px):
                img.putpixel((x, y), c)
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()


def main(argv):
    data = draw()
    if "--check" in argv:
        ok = OUT.exists() and OUT.read_bytes() == data
        print("palette-aero.png", "matches" if ok else "STALE")
        return 0 if ok else 1
    # The same drawing at 1.1 must be the island's own bound palette, or the layout read here is not the one shipped.
    if draw(1.1) != (WORLD / "textures" / "palette-roblox.png").read_bytes():
        raise RuntimeError("palette layout differs from palette-roblox.png; refusing to draw a mismatched swap")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    print("wrote", OUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
